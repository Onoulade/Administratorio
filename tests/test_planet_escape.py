#!/usr/bin/env python3
"""
Planet escape analysis tool for Administratorio using real Factorio prototype data.

This is primarily an internal analysis tool. It runs Factorio `--dump-data`
with Space Age enabled, derives each planet's local resource graph from the
dumped `planet` prototypes, computes researchable technologies and locally
craftable outputs, then reports what must be imported to satisfy the selected
escape targets and where the bootstrap graph deadlocks.

It exits non-zero only on structural issues in the extracted graph.
"""

from __future__ import annotations

import argparse
import json
import logging
import re
import shutil
import subprocess
import sys
import tempfile
import time
from collections import Counter, defaultdict
from fractions import Fraction
from functools import lru_cache
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Set, Tuple


log = logging.getLogger("planet-escape")

REPO_ROOT = Path(__file__).resolve().parent.parent
ITEM_LIKE_TYPES = (
    "item",
    "tool",
    "repair-tool",
    "module",
    "capsule",
    "ammo",
    "gun",
    "armor",
    "selection-tool",
    "item-with-entity-data",
    "rail-planner",
    "spidertron-remote",
)
MACHINE_TYPES = (
    "assembling-machine",
    "furnace",
    "rocket-silo",
)
ENTITY_OUTPUT_TYPES = (
    "resource",
    "tree",
    "simple-entity",
    "simple-entity-with-owner",
    "simple-entity-with-force",
    "fish",
)
DEFAULT_TARGETS = (
    ("rocket-silo", Fraction(1, 1)),
    ("rocket-part", Fraction(100, 1)),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--factorio-bin",
        required=True,
        help="Path to the Factorio executable.",
    )
    parser.add_argument(
        "--planet",
        action="append",
        dest="planets",
        help="Limit the report to specific planets. May be passed multiple times.",
    )
    parser.add_argument(
        "--target",
        action="append",
        dest="targets",
        metavar="NAME[:AMOUNT]",
        help="Escape target to analyze. Defaults to rocket-silo and 100 rocket-part.",
    )
    parser.add_argument(
        "--keep-temp",
        action="store_true",
        help="Keep the temporary write-data directory after the run.",
    )
    parser.add_argument(
        "--show-steps",
        action="store_true",
        help="Print the chosen dependency steps for each target.",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="count",
        default=0,
        help="Increase logging verbosity. Use -v for INFO, -vv for DEBUG.",
    )
    return parser.parse_args()


def repo_name() -> str:
    return json.loads((REPO_ROOT / "info.json").read_text())["name"]


def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def build_temp_profile(mod_name: str) -> Path:
    tmp_root = Path(tempfile.mkdtemp(prefix="administratorio-planet-escape-"))
    log.info("Created temp profile at %s", tmp_root)
    mods_dir = tmp_root / "mods"
    mods_dir.mkdir(parents=True, exist_ok=True)
    (mods_dir / mod_name).symlink_to(REPO_ROOT)

    write_file(
        mods_dir / "mod-list.json",
        json.dumps(
            {
                "mods": [
                    {"name": "base", "enabled": True},
                    {"name": "elevated-rails", "enabled": True},
                    {"name": "quality", "enabled": True},
                    {"name": "space-age", "enabled": True},
                    {"name": mod_name, "enabled": True},
                ]
            },
            indent=2,
        )
        + "\n",
    )

    write_file(
        tmp_root / "config.ini",
        "[path]\n"
        "read-data=__PATH__system-read-data__\n"
        f"write-data={tmp_root}\n\n"
        "[general]\n"
        "locale=auto\n",
    )
    return tmp_root


def run_dump_data(factorio_bin: Path, tmp_root: Path) -> Path:
    if not factorio_bin.exists():
        raise FileNotFoundError(f"Factorio binary not found at {factorio_bin}")

    command = [
        str(factorio_bin),
        "--config",
        str(tmp_root / "config.ini"),
        "--mod-directory",
        str(tmp_root / "mods"),
        "--disable-audio",
        "--dump-data",
    ]
    log.info("Running dump-data: %s", " ".join(command))
    subprocess.run(command, check=True, cwd=REPO_ROOT)

    dump_path = tmp_root / "script-output" / "data-raw-dump.json"
    if not dump_path.exists():
        raise FileNotFoundError(f"Expected dump not found: {dump_path}")
    log.info("Dump written to %s (%.1f MB)", dump_path, dump_path.stat().st_size / 1_048_576)
    return dump_path


def parse_targets(raw_targets: Optional[Sequence[str]]) -> List[Tuple[str, Fraction]]:
    if not raw_targets:
        return list(DEFAULT_TARGETS)

    targets: List[Tuple[str, Fraction]] = []
    for entry in raw_targets:
        if ":" in entry:
            name, amount_text = entry.split(":", 1)
            amount = Fraction(amount_text)
        else:
            name = entry
            amount = Fraction(1, 1)
        targets.append((name.strip(), amount))
    return targets


def load_planet_properties() -> Dict[str, Dict[str, int]]:
    source = (REPO_ROOT / "prototypes/shared/space_age_planets.lua").read_text()
    matches = re.findall(
        r"([a-z0-9-]+)\s*=\s*\{\s*pressure\s*=\s*(\d+)\s*,\s*gravity\s*=\s*(\d+)\s*\}",
        source,
    )
    if not matches:
        raise ValueError("Failed to parse planet properties from prototypes/shared/space_age_planets.lua")
    return {
        name: {"pressure": int(pressure), "gravity": int(gravity)}
        for name, pressure, gravity in matches
    }


def recipe_level(recipe: Dict) -> Dict:
    return recipe.get("normal", recipe)


def recipe_enabled_from_start(recipe: Dict) -> bool:
    return recipe.get("enabled", True) is not False


def recipe_visible(recipe: Dict) -> bool:
    return not recipe.get("hidden", False) and not recipe.get("hide_from_player_crafting", False)


def recipe_category(recipe: Dict) -> str:
    level = recipe_level(recipe)
    return level.get("category") or recipe.get("category") or "crafting"


def recipe_ingredients(recipe: Dict) -> List[Tuple[str, str, Fraction]]:
    level = recipe_level(recipe)
    ingredients = []
    for ingredient in level.get("ingredients", []) or []:
        if isinstance(ingredient, list):
            if ingredient:
                amount = ingredient[1] if len(ingredient) > 1 else 1
                ingredients.append((ingredient[0], "item", Fraction(amount)))
            continue
        name = ingredient.get("name")
        if not name:
            continue
        amount = ingredient.get("amount")
        if amount is None:
            amount = ingredient.get("amount_min", 1)
        ingredients.append((name, ingredient.get("type", "item"), Fraction(amount)))
    return ingredients


def recipe_results(recipe: Dict) -> List[Tuple[str, str, Fraction]]:
    level = recipe_level(recipe)
    results = level.get("results")
    if results is None and "result" in level:
        result_type = "fluid" if level.get("main_product") in {"water", "steam"} else "item"
        results = [{"name": level["result"], "type": result_type, "amount": level.get("result_count", 1)}]

    output = []
    for result in results or []:
        if isinstance(result, list):
            if result:
                amount = result[1] if len(result) > 1 else 1
                output.append((result[0], "item", Fraction(amount)))
            continue
        name = result.get("name")
        if not name:
            continue
        amount = result.get("amount")
        if amount is None:
            amount = result.get("amount_min", 1)
        output.append((name, result.get("type", "item"), Fraction(amount)))
    return output


def result_names(minable: Dict) -> List[str]:
    names: List[str] = []
    result = minable.get("result")
    if result:
        names.append(result)
    for entry in minable.get("results", []) or []:
        if isinstance(entry, dict) and entry.get("name"):
            names.append(entry["name"])
        elif isinstance(entry, list) and entry:
            names.append(entry[0])
    return names


def condition_matches(surface_conditions: Sequence[Dict], properties: Dict[str, int]) -> bool:
    for condition in surface_conditions or []:
        prop = condition.get("property")
        if prop not in properties:
            continue
        value = properties[prop]
        minimum = condition.get("min")
        maximum = condition.get("max")
        if minimum is not None and value < minimum:
            return False
        if maximum is not None and value > maximum:
            return False
    return True


def format_fraction(value: Fraction) -> str:
    if value.denominator == 1:
        return str(value.numerator)
    rounded = float(value)
    return f"{rounded:.3f}".rstrip("0").rstrip(".")


def sorted_unique(values: Iterable[str]) -> List[str]:
    return sorted(dict.fromkeys(values))


def merge_counter(target: Counter, source: Counter) -> None:
    for key, value in source.items():
        target[key] += value


def render_counter(counter: Counter) -> List[str]:
    return [f"{format_fraction(amount)}x {name}" for name, amount in sorted(counter.items())]


class PlanetEscapeAnalyzer:
    def __init__(self, data_raw: Dict, planet_properties: Dict[str, Dict[str, int]]):
        self.data_raw = data_raw
        self.planet_properties = planet_properties
        self.planets: Dict[str, Dict] = data_raw.get("planet", {})
        self.recipes: Dict[str, Dict] = data_raw.get("recipe", {})
        self.technologies: Dict[str, Dict] = data_raw.get("technology", {})
        log.info("Loaded %d planets, %d recipes, %d technologies from dump",
                 len(self.planets), len(self.recipes), len(self.technologies))
        self.item_index: Dict[str, Dict] = {}
        self.item_type_by_name: Dict[str, str] = {}
        for proto_type in ITEM_LIKE_TYPES:
            for name, proto in data_raw.get(proto_type, {}).items():
                self.item_index[name] = proto
                self.item_type_by_name[name] = proto_type
        self.fluid_index: Dict[str, Dict] = data_raw.get("fluid", {})
        self.known_materials = set(self.item_index) | set(self.fluid_index)
        log.info("Indexed %d items and %d fluids (%d known materials total)",
                 len(self.item_index), len(self.fluid_index), len(self.known_materials))

        self.start_enabled_recipes = {
            name
            for name, recipe in self.recipes.items()
            if recipe_enabled_from_start(recipe) and recipe_visible(recipe)
        }
        log.info("Found %d recipes enabled from start", len(self.start_enabled_recipes))
        self.unlocks_by_tech = self._build_unlocks_by_tech()
        log.info("Built tech unlock map: %d technologies unlock recipes", len(self.unlocks_by_tech))
        self.local_entity_names_by_planet = self._discover_local_entity_names()
        self.local_resources_by_planet = self._discover_local_resources()
        for planet_name in sorted(self.local_resources_by_planet):
            log.info("  %s: %d local entities, %d local resources",
                     planet_name,
                     len(self.local_entity_names_by_planet.get(planet_name, set())),
                     len(self.local_resources_by_planet[planet_name]))
            log.debug("    entities: %s", ", ".join(sorted(self.local_entity_names_by_planet.get(planet_name, set()))))
            log.debug("    resources: %s", ", ".join(self.local_resources_by_planet[planet_name]))
        self.machine_categories_by_item = self._build_machine_categories_by_item()
        self.category_to_buildings = self._build_category_to_buildings()
        log.info("Mapped %d crafting categories across %d building items",
                 len(self.category_to_buildings), len(self.machine_categories_by_item))
        self.hand_crafting_categories = self._discover_hand_crafting_categories()
        log.info("Hand-crafting categories: %s", ", ".join(sorted(self.hand_crafting_categories)))
        self.material_depth = self._compute_material_depth()
        log.info("Computed material depth for %d materials (max depth %d)",
                 len(self.material_depth),
                 max(self.material_depth.values()) if self.material_depth else 0)
        self.fixed_recipes = self._discover_fixed_recipes()
        if self.fixed_recipes:
            log.info("Discovered %d fixed recipes from entities: %s",
                     len(self.fixed_recipes), ", ".join(sorted(self.fixed_recipes)))
        self._log_mine_entity_triggers()

    def _build_unlocks_by_tech(self) -> Dict[str, List[str]]:
        unlocks: Dict[str, List[str]] = defaultdict(list)
        for tech_name, tech in self.technologies.items():
            if tech.get("hidden") or tech.get("enabled", True) is False:
                continue
            for effect in tech.get("effects", []) or []:
                if (
                    effect.get("type") == "unlock-recipe"
                    and effect.get("recipe") in self.recipes
                    and recipe_visible(self.recipes[effect["recipe"]])
                ):
                    unlocks[tech_name].append(effect["recipe"])
        return dict(unlocks)

    def _planet_map_gen_entity_names(self, planet_name: str) -> Set[str]:
        planet = self.planets.get(planet_name, {})
        map_gen = planet.get("map_gen_settings", {}) or {}
        entity_names = set((map_gen.get("autoplace_settings", {}).get("entity", {}).get("settings", {}) or {}).keys())

        for key in (map_gen.get("property_expression_names", {}) or {}):
            if key.startswith("entity:") and key.endswith(":probability"):
                entity_names.add(key.split(":")[1])

        return entity_names

    def _discover_local_entity_names(self) -> Dict[str, Set[str]]:
        local_entities: Dict[str, Set[str]] = {}
        for planet_name in self.planet_properties:
            names = set(self._planet_map_gen_entity_names(planet_name))
            for proto_type in ("resource", "offshore-pump"):
                for name, proto in self.data_raw.get(proto_type, {}).items():
                    if name in names:
                        continue
                    if proto.get("surface_conditions") and condition_matches(
                        proto.get("surface_conditions", []),
                        self.planet_properties[planet_name],
                    ):
                        names.add(name)
            local_entities[planet_name] = names
        return local_entities

    def _discover_local_resources(self) -> Dict[str, List[str]]:
        resources: Dict[str, Set[str]] = {planet: set() for planet in self.planet_properties}

        for planet_name, entity_names in self.local_entity_names_by_planet.items():
            for entity_name in entity_names:
                for proto_type in ENTITY_OUTPUT_TYPES:
                    proto = self.data_raw.get(proto_type, {}).get(entity_name)
                    if not proto:
                        continue
                    resources[planet_name].update(result_names(proto.get("minable") or {}))
                    break

                pump = self.data_raw.get("offshore-pump", {}).get(entity_name)
                if pump:
                    fluid_name = (pump.get("fluid_box") or {}).get("filter")
                    if fluid_name:
                        resources[planet_name].add(fluid_name)

        return {planet: sorted(resources[planet]) for planet in resources}

    def _build_machine_categories_by_item(self) -> Dict[str, Set[str]]:
        by_item: Dict[str, Set[str]] = defaultdict(set)
        for proto_type in MACHINE_TYPES:
            for proto in self.data_raw.get(proto_type, {}).values():
                item_name = (proto.get("minable") or {}).get("result")
                if not item_name:
                    continue
                for category in proto.get("crafting_categories", []) or []:
                    by_item[item_name].add(category)
        return dict(by_item)

    def _build_category_to_buildings(self) -> Dict[str, List[str]]:
        mapping: Dict[str, List[str]] = defaultdict(list)
        for item_name, categories in self.machine_categories_by_item.items():
            for category in categories:
                mapping[category].append(item_name)
        for category in mapping:
            mapping[category] = sorted_unique(mapping[category])
        return dict(mapping)

    def _discover_hand_crafting_categories(self) -> Set[str]:
        character = self.data_raw.get("character", {}).get("character", {})
        categories = set(character.get("crafting_categories", []) or [])
        if categories:
            return categories
        return {"crafting"}

    def _compute_material_depth(self) -> Dict[str, int]:
        """Compute recipe depth for every known material.

        Depth 0 = raw resource (appears as a local resource on any planet, or
        has no visible recipe producing it).  Depth N = min over all visible
        recipes producing the material of (1 + max ingredient depth).

        This is used to penalize importing complex items when simpler
        alternatives exist.
        """
        all_local_resources: Set[str] = set()
        for resources in self.local_resources_by_planet.values():
            all_local_resources.update(resources)

        all_visible_recipes = {
            name
            for name, recipe in self.recipes.items()
            if recipe_visible(recipe)
        }

        produced_by: Dict[str, List[str]] = defaultdict(list)
        for recipe_name in all_visible_recipes:
            for result_name, _, _ in recipe_results(self.recipes[recipe_name]):
                produced_by[result_name].append(recipe_name)

        depth: Dict[str, int] = {}
        for name in all_local_resources:
            depth[name] = 0

        for name in self.known_materials:
            if name not in produced_by and name not in depth:
                depth[name] = 0

        changed = True
        while changed:
            changed = False
            for material_name, recipe_names in produced_by.items():
                for recipe_name in recipe_names:
                    ingredients = recipe_ingredients(self.recipes[recipe_name])
                    if all(ing_name in depth for ing_name, _, _ in ingredients):
                        max_ing = max((depth[ing_name] for ing_name, _, _ in ingredients), default=0)
                        candidate = 1 + max_ing
                        if material_name not in depth or candidate < depth[material_name]:
                            depth[material_name] = candidate
                            changed = True

        return depth

    def _discover_fixed_recipes(self) -> Set[str]:
        """Find hidden recipes referenced by entity fixed_recipe fields.

        Rocket-silos (and potentially other entities) produce items via a
        fixed_recipe that is marked hidden and therefore excluded from normal
        recipe discovery.  We include these so the planner can expand them
        instead of treating their outputs as opaque imports.
        """
        fixed: Set[str] = set()
        for proto_type in ("rocket-silo",):
            for entity_name, proto in self.data_raw.get(proto_type, {}).items():
                recipe_name = proto.get("fixed_recipe")
                if recipe_name and recipe_name in self.recipes:
                    fixed.add(recipe_name)
                    log.debug("Fixed recipe from %s '%s': %s", proto_type, entity_name, recipe_name)
        return fixed

    def _log_mine_entity_triggers(self) -> None:
        for tech_name, tech in self.technologies.items():
            trigger = tech.get("research_trigger") or {}
            if trigger.get("type") == "mine-entity":
                entity = trigger.get("entity", "?")
                prereqs = tech.get("prerequisites", []) or []
                unlocks = self.unlocks_by_tech.get(tech_name, [])
                on_planets = [
                    p for p in self.planet_properties
                    if entity in self.local_entity_names_by_planet.get(p, set())
                ]
                log.debug("mine-entity tech '%s': entity='%s', prereqs=%s, unlocks=%s, available on: %s",
                          tech_name, entity, prereqs, unlocks,
                          ", ".join(on_planets) if on_planets else "(none)")

    def _recipe_available_on_planet(self, recipe: Dict, planet_name: str) -> bool:
        conditions = recipe.get("surface_conditions") or []
        if conditions:
            return condition_matches(conditions, self.planet_properties[planet_name])
        return True

    def _initial_researched_technologies(self, planet_name: str) -> Set[str]:
        seed_name = f"planet-discovery-{planet_name}"
        if seed_name not in self.technologies:
            return set()

        researched: Set[str] = set()
        stack = [seed_name]
        while stack:
            tech_name = stack.pop()
            tech = self.technologies.get(tech_name)
            if not tech or tech_name in researched:
                continue
            if tech.get("hidden") or tech.get("enabled", True) is False:
                continue
            researched.add(tech_name)
            stack.extend(tech.get("prerequisites", []) or [])
        return researched

    def _entity_placeable_item(self, entity_name: str) -> Optional[str]:
        for proto_type in (
            "assembling-machine",
            "furnace",
            "rocket-silo",
            "mining-drill",
            "lab",
            "offshore-pump",
            "boiler",
            "generator",
            "storage-tank",
            "pump",
            "container",
            "logistic-container",
            "straight-rail",
            "rail-signal",
            "rail-chain-signal",
        ):
            proto = self.data_raw.get(proto_type, {}).get(entity_name)
            if not proto:
                continue
            item_name = (proto.get("minable") or {}).get("result")
            if item_name:
                return item_name
        return None

    @lru_cache(maxsize=None)
    def researched_technologies(self, planet_name: str) -> Tuple[str, ...]:
        researched: Set[str] = self._initial_researched_technologies(planet_name)
        log.info("[%s] Starting tech research with %d initial technologies", planet_name, len(researched))
        log.debug("[%s] Initial techs: %s", planet_name, ", ".join(sorted(researched)))

        iteration = 0
        while True:
            iteration += 1
            progress = False
            available_recipes = self.available_recipes_from_research(planet_name, tuple(sorted(researched)))
            available_key = tuple(sorted(available_recipes))
            prev_count = len(researched)

            for tech_name, tech in self.technologies.items():
                if tech_name in researched:
                    continue
                if tech.get("hidden") or tech.get("enabled", True) is False:
                    continue

                prerequisites = [
                    prereq
                    for prereq in tech.get("prerequisites", []) or []
                    if prereq in self.technologies and not self.technologies[prereq].get("hidden")
                ]
                if any(prereq not in researched for prereq in prerequisites):
                    continue

                trigger = tech.get("research_trigger") or {}
                if trigger:
                    # Any non-science-pack research (trigger-based) is considered
                    # unlockable immediately once prerequisites are met — the
                    # player will naturally mine/craft/build things on the planet.
                    researched.add(tech_name)
                    progress = True
                    log.debug("[%s] Unlocked %s via research trigger (%s)",
                              planet_name, tech_name, trigger.get("type", "?"))
                    continue

                unit = tech.get("unit", {}) or {}
                science_packs = []
                for ingredient in unit.get("ingredients", []) or []:
                    if isinstance(ingredient, list):
                        science_packs.append(ingredient[0])
                    elif ingredient.get("name"):
                        science_packs.append(ingredient["name"])

                if not science_packs:
                    continue

                if all(self.craftable_with_recipes(planet_name, pack, available_key) for pack in science_packs):
                    researched.add(tech_name)
                    progress = True

            if not progress:
                log.info("[%s] Tech research converged after %d iterations with %d technologies",
                         planet_name, iteration, len(researched))
                break
            log.debug("[%s] Iteration %d: researched %d -> %d technologies",
                      planet_name, iteration, prev_count, len(researched))

        return tuple(sorted(researched))

    @lru_cache(maxsize=None)
    def available_recipes_from_research(self, planet_name: str, researched_key: Tuple[str, ...]) -> Tuple[str, ...]:
        available = {
            name
            for name in self.start_enabled_recipes
            if self._recipe_available_on_planet(self.recipes[name], planet_name)
        }
        for tech_name in researched_key:
            for recipe_name in self.unlocks_by_tech.get(tech_name, []):
                if self._recipe_available_on_planet(self.recipes[recipe_name], planet_name):
                    available.add(recipe_name)
        for recipe_name in self.fixed_recipes:
            if self._recipe_available_on_planet(self.recipes[recipe_name], planet_name):
                available.add(recipe_name)
        return tuple(sorted(available))

    @lru_cache(maxsize=None)
    def craftable_with_recipes(self, planet_name: str, material_name: str, available_key: Tuple[str, ...]) -> bool:
        local_materials = set(self.local_resources_by_planet[planet_name])
        available = set(available_key)
        producing = [
            recipe_name
            for recipe_name in available
            if any(result_name == material_name for result_name, _, _ in recipe_results(self.recipes[recipe_name]))
        ]
        visiting: Set[str] = set()

        def rec(target: str) -> bool:
            if target in local_materials:
                return True
            if target in visiting:
                return False

            candidate_recipes = [
                recipe_name
                for recipe_name in available
                if any(result_name == target for result_name, _, _ in recipe_results(self.recipes[recipe_name]))
            ]
            if not candidate_recipes:
                return False

            visiting.add(target)
            for recipe_name in candidate_recipes:
                if all(rec(ingredient_name) for ingredient_name, _, _ in recipe_ingredients(self.recipes[recipe_name])):
                    visiting.remove(target)
                    return True
            visiting.remove(target)
            return False

        if material_name in local_materials:
            return True
        if not producing:
            return False
        return rec(material_name)

    def available_recipes(self, planet_name: str) -> Tuple[str, ...]:
        researched = self.researched_technologies(planet_name)
        return self.available_recipes_from_research(planet_name, researched)

    def craftable_outputs(self, planet_name: str) -> List[str]:
        available_key = self.available_recipes(planet_name)
        outputs: Set[str] = set(self.local_resources_by_planet[planet_name])
        for recipe_name in available_key:
            for result_name, _, _ in recipe_results(self.recipes[recipe_name]):
                if self.craftable_with_recipes(planet_name, result_name, available_key):
                    outputs.add(result_name)
        return sorted(outputs)

    def accessible_buildings(self, planet_name: str) -> List[str]:
        outputs = set(self.craftable_outputs(planet_name))
        return sorted(item_name for item_name in outputs if item_name in self.machine_categories_by_item)

    def unknown_resources(self, planet_name: str) -> List[str]:
        return [
            name
            for name in self.local_resources_by_planet[planet_name]
            if name not in self.known_materials
        ]

    def result_amount_for(self, recipe_name: str, material_name: str) -> Fraction:
        for result_name, _, amount in recipe_results(self.recipes[recipe_name]):
            if result_name == material_name:
                return amount
        raise KeyError(f"{recipe_name} does not produce {material_name}")

    def plan_target(self, planet_name: str, target_name: str, amount: Fraction) -> Dict:
        available_key = self.available_recipes(planet_name)
        accessible_buildings = set(self.accessible_buildings(planet_name))
        # Materials proven craftable locally — treat as free for planning even
        # if the recipe graph has cycles (e.g. water ↔ steam).
        locally_craftable = set(self.craftable_outputs(planet_name))
        _rec_calls = [0]
        _rec_cache_hits = [0]
        _rec_max_depth = [0]
        _resolved_materials: Set[str] = set()
        _start_time = time.monotonic()
        _last_log_time = [_start_time]

        def indent_steps(steps: Iterable[str]) -> List[str]:
            return [f"  {step}" for step in steps]

        _rec_memo: Dict[Tuple[str, Fraction], Dict] = {}
        _visiting: Set[str] = set()

        def _copy_plan(plan: Dict) -> Dict:
            return {
                "imports": Counter(plan["imports"]),
                "deadlocks": set(plan["deadlocks"]),
                "recipes": Counter(plan["recipes"]),
                "categories": set(plan["categories"]),
                "building_categories": set(plan["building_categories"]),
                "steps": plan["steps"],
            }

        def rec(material_name: str, required_amount: Fraction) -> Dict:
            memo_key = (material_name, required_amount)
            if memo_key in _rec_memo and material_name not in _visiting:
                _rec_cache_hits[0] += 1
                return _copy_plan(_rec_memo[memo_key])

            _rec_calls[0] += 1
            _resolved_materials.add(material_name)
            depth = len(_visiting)
            if depth > _rec_max_depth[0]:
                _rec_max_depth[0] = depth

            now = time.monotonic()
            if now - _last_log_time[0] >= 2.0:
                elapsed = now - _start_time
                log.info(
                    "[%s] plan %sx %s: %.1fs elapsed | %d calls | %d cache hits | "
                    "depth %d (max %d) | %d unique materials | memo size %d | "
                    "now resolving: %s",
                    planet_name, format_fraction(amount), target_name,
                    elapsed, _rec_calls[0], _rec_cache_hits[0],
                    depth, _rec_max_depth[0], len(_resolved_materials),
                    len(_rec_memo),
                    material_name,
                )
                _last_log_time[0] = now

            log.debug("[%s] rec depth=%d material=%s amount=%s",
                      planet_name, depth, material_name, format_fraction(required_amount))

            if material_name in locally_craftable:
                result = {
                    "imports": Counter(),
                    "deadlocks": set(),
                    "recipes": Counter(),
                    "categories": set(),
                    "building_categories": set(),
                    "steps": (f"use local {format_fraction(required_amount)}x {material_name}",),
                }
                _rec_memo[memo_key] = result
                return _copy_plan(result)

            if material_name in _visiting:
                if material_name in self.known_materials:
                    return {
                        "imports": Counter({material_name: required_amount}),
                        "deadlocks": set(),
                        "recipes": Counter(),
                        "categories": set(),
                        "building_categories": set(),
                        "steps": (f"import {format_fraction(required_amount)}x {material_name} (break cycle)",),
                    }
                return {
                    "imports": Counter(),
                    "deadlocks": {material_name},
                    "recipes": Counter(),
                    "categories": set(),
                    "building_categories": set(),
                    "steps": (f"deadlock cycle on {material_name}",),
                }

            candidate_recipes = [
                recipe_name
                for recipe_name in available_key
                if any(result_name == material_name for result_name, _, _ in recipe_results(self.recipes[recipe_name]))
            ]
            if not candidate_recipes:
                if material_name in self.known_materials:
                    result = {
                        "imports": Counter({material_name: required_amount}),
                        "deadlocks": set(),
                        "recipes": Counter(),
                        "categories": set(),
                        "building_categories": set(),
                        "steps": (f"import {format_fraction(required_amount)}x {material_name}",),
                    }
                    _rec_memo[memo_key] = result
                    return _copy_plan(result)
                result = {
                    "imports": Counter(),
                    "deadlocks": {material_name},
                    "recipes": Counter(),
                    "categories": set(),
                    "building_categories": set(),
                    "steps": (f"deadlock missing prototype or recipe for {material_name}",),
                }
                _rec_memo[memo_key] = result
                return _copy_plan(result)

            _visiting.add(material_name)
            plans = []
            for recipe_name in candidate_recipes:
                produced_amount = self.result_amount_for(recipe_name, material_name)
                if produced_amount == 0:
                    continue
                crafts_needed = required_amount / produced_amount
                imports = Counter()
                deadlocks: Set[str] = set()
                recipes = Counter({recipe_name: crafts_needed})
                categories = {recipe_category(self.recipes[recipe_name])}
                building_categories = set()
                steps: List[str] = [
                    f"craft {format_fraction(crafts_needed)}x {recipe_name} for {format_fraction(required_amount)}x {material_name}"
                ]
                category = recipe_category(self.recipes[recipe_name])
                if category not in self.hand_crafting_categories:
                    building_categories.add(category)

                for ingredient_name, _, ingredient_amount in recipe_ingredients(self.recipes[recipe_name]):
                    ingredient_plan = rec(ingredient_name, ingredient_amount * crafts_needed)
                    merge_counter(imports, ingredient_plan["imports"])
                    deadlocks.update(ingredient_plan["deadlocks"])
                    merge_counter(recipes, ingredient_plan["recipes"])
                    categories.update(ingredient_plan["categories"])
                    building_categories.update(ingredient_plan["building_categories"])
                    steps.extend(indent_steps(ingredient_plan["steps"]))

                missing_building_categories = {
                    cat
                    for cat in building_categories
                    if not any(item in accessible_buildings for item in self.category_to_buildings.get(cat, []))
                }
                for missing_category in sorted(missing_building_categories):
                    steps.append(
                        f"  note: needs building for category {missing_category}: "
                        + (", ".join(self.category_to_buildings.get(missing_category, [])) or "(no building prototype found)")
                    )

                plans.append(
                    {
                        "imports": imports,
                        "deadlocks": deadlocks,
                        "recipes": recipes,
                        "categories": categories,
                        "building_categories": building_categories,
                        "steps": tuple(steps),
                    }
                )
            _visiting.discard(material_name)

            if not plans:
                result = {
                    "imports": Counter(),
                    "deadlocks": {material_name},
                    "recipes": Counter(),
                    "categories": set(),
                    "building_categories": set(),
                    "steps": (f"deadlock no valid production path for {material_name}",),
                }
                _rec_memo[memo_key] = result
                return _copy_plan(result)

            def score(plan: Dict) -> Tuple:
                total_import = sum(plan["imports"].values(), Fraction(0, 1))
                import_complexity = sum(
                    amt * self.material_depth.get(name, 10)
                    for name, amt in plan["imports"].items()
                )
                return (
                    len(plan["deadlocks"]),
                    import_complexity,
                    total_import,
                    len(plan["imports"]),
                    len(plan["recipes"]),
                    sorted(plan["imports"].keys()),
                )

            result = min(plans, key=score)
            _rec_memo[memo_key] = result
            return _copy_plan(result)

        log.info("[%s] Starting plan_target for %sx %s", planet_name, format_fraction(amount), target_name)
        plan = rec(target_name, amount)
        elapsed = time.monotonic() - _start_time
        log.info("[%s] plan_target for %s done in %.1fs: %d rec calls, %d cache hits, max depth %d, %d unique materials",
                 planet_name, target_name, elapsed, _rec_calls[0], _rec_cache_hits[0],
                 _rec_max_depth[0], len(_resolved_materials))
        plan["craftable"] = not plan["imports"] and not plan["deadlocks"]
        plan["target"] = target_name
        plan["amount"] = amount
        return plan


def render_planet_section(
    analyzer: PlanetEscapeAnalyzer,
    planet_name: str,
    targets: Sequence[Tuple[str, Fraction]],
    show_steps: bool,
) -> List[str]:
    log.info("[%s] Computing local resources...", planet_name)
    local_resources = analyzer.local_resources_by_planet[planet_name]
    log.info("[%s] Computing researched technologies...", planet_name)
    researched = list(analyzer.researched_technologies(planet_name))
    log.info("[%s] Computing available recipes...", planet_name)
    available_recipes = list(analyzer.available_recipes(planet_name))
    log.info("[%s] Computing craftable outputs...", planet_name)
    accessible_outputs = analyzer.craftable_outputs(planet_name)
    log.info("[%s] Computing accessible buildings...", planet_name)
    accessible_buildings = analyzer.accessible_buildings(planet_name)
    log.info("[%s] Planning %d escape targets...", planet_name, len(targets))
    target_plans = [analyzer.plan_target(planet_name, target_name, amount) for target_name, amount in targets]
    for plan in target_plans:
        status = "craftable" if plan["craftable"] else "needs imports"
        log.info("[%s]   target %sx %s: %s (imports=%d, deadlocks=%d)",
                 planet_name, format_fraction(plan["amount"]), plan["target"],
                 status, len(plan["imports"]), len(plan["deadlocks"]))

    aggregate_imports: Counter = Counter()
    aggregate_deadlocks: Set[str] = set()
    needed_building_categories: Set[str] = set()
    for plan in target_plans:
        merge_counter(aggregate_imports, plan["imports"])
        aggregate_deadlocks.update(plan["deadlocks"])
        needed_building_categories.update(plan["building_categories"])

    lines = [
        "",
        f"[{planet_name}]",
        f"Local resources ({len(local_resources)}): {', '.join(local_resources) if local_resources else '(none)'}",
        f"Researchable technologies ({len(researched)}): {', '.join(researched) if researched else '(none)'}",
        f"Available recipes ({len(available_recipes)}): {', '.join(available_recipes[:40]) if available_recipes else '(none)'}",
    ]
    if len(available_recipes) > 40:
        lines.append(f"... plus {len(available_recipes) - 40} more recipes")

    lines.extend(
        [
            f"Accessible outputs without imports ({len(accessible_outputs)}): {', '.join(accessible_outputs[:60]) if accessible_outputs else '(none)'}",
        ]
    )
    if len(accessible_outputs) > 60:
        lines.append(f"... plus {len(accessible_outputs) - 60} more outputs")

    lines.append(
        f"Accessible buildings without imports ({len(accessible_buildings)}): "
        f"{', '.join(accessible_buildings) if accessible_buildings else '(none)'}"
    )

    lines.append("Escape target analysis:")
    for plan in target_plans:
        status = "craftable locally" if plan["craftable"] else "requires imports/deadlock resolution"
        lines.append(f"  - {format_fraction(plan['amount'])}x {plan['target']}: {status}")
        if plan["imports"]:
            lines.append(f"    Imports: {', '.join(render_counter(plan['imports']))}")
        if plan["deadlocks"]:
            lines.append(f"    Deadlocks: {', '.join(sorted(plan['deadlocks']))}")

        non_hand_categories = sorted(cat for cat in plan["building_categories"] if cat not in analyzer.hand_crafting_categories)
        if non_hand_categories:
            needed = []
            for category in non_hand_categories:
                candidate_buildings = analyzer.category_to_buildings.get(category, [])
                needed.append(f"{category} -> {', '.join(candidate_buildings) if candidate_buildings else '(no building prototype found)'}")
            lines.append(f"    Needed building categories: {'; '.join(needed)}")
        if show_steps:
            lines.append("    Steps:")
            for step in plan["steps"]:
                lines.append(f"      {step}")

    lines.append(
        f"Aggregate imports for selected targets: {', '.join(render_counter(aggregate_imports)) if aggregate_imports else '(none)'}"
    )
    lines.append(
        f"Aggregate deadlocks: {', '.join(sorted(aggregate_deadlocks)) if aggregate_deadlocks else '(none)'}"
    )
    if needed_building_categories:
        lines.append(
            "Buildings needed by selected targets: "
            + "; ".join(
                f"{category} -> {', '.join(analyzer.category_to_buildings.get(category, [])) or '(none)'}"
                for category in sorted(needed_building_categories)
            )
        )

    return lines


def render_report(
    analyzer: PlanetEscapeAnalyzer,
    planets: Sequence[str],
    dump_path: Path,
    targets: Sequence[Tuple[str, Fraction]],
    show_steps: bool,
) -> str:
    lines = [
        "Administratorio Planet Escape Report",
        "===================================",
        "",
        f"Prototype dump: {dump_path}",
        f"Planets analyzed: {', '.join(planets)}",
        "Escape targets: " + ", ".join(f"{format_fraction(amount)}x {name}" for name, amount in targets),
    ]

    for planet_name in planets:
        lines.extend(render_planet_section(analyzer, planet_name, targets, show_steps))

    return "\n".join(lines) + "\n"


def main() -> int:
    args = parse_args()
    level = logging.WARNING
    if args.verbose >= 2:
        level = logging.DEBUG
    elif args.verbose >= 1:
        level = logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s %(name)s %(levelname)s  %(message)s",
        datefmt="%H:%M:%S",
    )
    targets = parse_targets(args.targets)
    log.info("Targets: %s", ", ".join(f"{format_fraction(a)}x {n}" for n, a in targets))
    tmp_root = build_temp_profile(repo_name())

    try:
        log.info("Loading planet properties from prototypes...")
        planet_properties = load_planet_properties()
        log.info("Found %d planets: %s", len(planet_properties), ", ".join(sorted(planet_properties)))
        requested_planets = args.planets or sorted(planet_properties)
        invalid = sorted(set(requested_planets) - set(planet_properties))
        if invalid:
            raise ValueError(f"Unknown planet(s): {', '.join(invalid)}")

        dump_path = run_dump_data(Path(args.factorio_bin), tmp_root)
        log.info("Parsing dump and building analyzer...")
        analyzer = PlanetEscapeAnalyzer(json.loads(dump_path.read_text()), planet_properties)
        log.info("Analyzer ready. Analyzing %d planet(s)...", len(requested_planets))

        failures: List[str] = []
        for planet_name in requested_planets:
            local_resources = analyzer.local_resources_by_planet[planet_name]
            if not local_resources:
                failures.append(f"{planet_name}: no local resources discovered from dumped prototypes")

            unknown = analyzer.unknown_resources(planet_name)
            if unknown:
                failures.append(
                    f"{planet_name}: extracted unknown materials not present in dumped item/fluid prototypes: "
                    + ", ".join(unknown)
                )

        report_text = render_report(analyzer, requested_planets, dump_path, targets, args.show_steps)
        report_path = tmp_root / "script-output" / "administratorio-planet-escape-report.txt"
        write_file(report_path, report_text)
        print(report_text, end="")
        print(f"Report written to {report_path}")

        if failures:
            for failure in failures:
                print(f"ERROR: {failure}", file=sys.stderr)
            return 1
        return 0
    finally:
        if args.keep_temp:
            print(f"Kept temp profile at {tmp_root}")
        else:
            shutil.rmtree(tmp_root, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
