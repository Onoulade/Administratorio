#!/usr/bin/env python3
"""
Dynamic progression report for Administratorio.

This test uses Factorio's own `--dump-data` output instead of maintaining a
mocked copy of base prototype data in the repo. It creates a temporary
write-data/mod profile, enables only `base` and this mod, runs `--dump-data`,
then analyzes the resulting prototype graph.

Default behavior:
  - always generates a human-readable report under the temporary script-output
  - exits non-zero only on hard structural issues (missing recipes / dump errors)

Strict mode:
  - `--strict` also fails when a direct building/accessory unlock does not
    become immediately craftable at its unlocking technology.
  - `--strict` fails when a recipe still cannot become machine-usable even with
    the full visible tech graph, which indicates a permanent category/provider
    cycle rather than a merely early unlock.
  - `--strict` fails when a building ingredient is only machine-reachable from
    the building itself or from a later provider in that building's branch.
  - `--strict` fails when a child technology drops a science pack already
    required by one of its prerequisite technologies.
  - `--strict` fails when a technology uses a science pack in its research
    ingredients but does not transitively depend on that pack's technology.
  - always fails when a visible recipe-unlock technology has no unique recipe
    unlocks after prototype hooks run, because researching a hollow node gives
    the player nothing.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from collections import defaultdict
from collections import deque
from functools import lru_cache
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Set, Tuple


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
RESOURCE_ROOT_TYPES = (
    "resource",
    "tree",
    "simple-entity",
    "simple-entity-with-owner",
    "simple-entity-with-force",
    "fish",
)
SECONDARY_RECIPE_CATEGORIES = {"pneumatic-intake", "smelting"}
STARTING_PROVIDER_ITEMS = ("mechanical-printer", "office-desk")
STRUCTURAL_EMPTY_TECHS = {
    # Vanilla parent node for the first module branches; it exists to organize
    # prerequisites while speed/productivity/efficiency own the actual recipes.
    "modules",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--factorio-bin",
        required=True,
        help="Path to the Factorio executable.",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit non-zero when direct target unlock viability findings exist.",
    )
    parser.add_argument(
        "--keep-temp",
        action="store_true",
        help="Keep the temporary write-data directory after the run.",
    )
    return parser.parse_args()


def repo_name() -> str:
    return json.loads((REPO_ROOT / "info.json").read_text())["name"]


def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def build_temp_profile(mod_name: str) -> Path:
    tmp_root = Path(tempfile.mkdtemp(prefix="administratorio-techtest-"))
    mods_dir = tmp_root / "mods"
    mods_dir.mkdir(parents=True, exist_ok=True)
    (mods_dir / mod_name).symlink_to(REPO_ROOT)

    write_file(
        mods_dir / "mod-list.json",
        json.dumps(
            {
                "mods": [
                    {"name": "base", "enabled": True},
                    {"name": "elevated-rails", "enabled": False},
                    {"name": "quality", "enabled": False},
                    {"name": "space-age", "enabled": False},
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
        raise FileNotFoundError(
            f"Factorio binary not found at {factorio_bin}. "
            "Pass --factorio-bin or set FACTORIO_BIN."
        )

    command = [
        str(factorio_bin),
        "--config",
        str(tmp_root / "config.ini"),
        "--mod-directory",
        str(tmp_root / "mods"),
        "--disable-audio",
        "--dump-data",
    ]
    subprocess.run(command, check=True, cwd=REPO_ROOT)

    dump_path = tmp_root / "script-output" / "data-raw-dump.json"
    if not dump_path.exists():
        raise FileNotFoundError(f"Expected dump not found: {dump_path}")
    return dump_path


def recipe_level(recipe: Dict) -> Dict:
    return recipe.get("normal", recipe)


def recipe_category(recipe: Dict) -> Optional[str]:
    level = recipe_level(recipe)
    return level.get("category") or recipe.get("category")


def recipe_enabled_from_start(recipe: Dict) -> bool:
    return recipe.get("enabled", True) is not False


def recipe_ingredients(recipe: Dict) -> List[Tuple[str, str]]:
    level = recipe_level(recipe)
    ingredients = []
    for ingredient in level.get("ingredients", []):
        name = ingredient.get("name")
        if name:
            ingredients.append((name, ingredient.get("type", "item")))
    return ingredients


def recipe_results(recipe: Dict) -> List[Tuple[str, str]]:
    level = recipe_level(recipe)
    results = level.get("results")
    if results is None and "result" in level:
        results = [{"name": level["result"], "type": "item"}]

    output = []
    for result in results or []:
        name = result.get("name")
        if name:
            output.append((name, result.get("type", "item")))
    return output


def is_secondary_recipe(name: str, recipe: Dict) -> bool:
    if name.endswith("-regulated"):
        return True
    if recipe_category(recipe) in SECONDARY_RECIPE_CATEGORIES:
        return True
    return False


class ProgressionAnalyzer:
    def __init__(self, data_raw: Dict):
        self.data_raw = data_raw
        self.technologies: Dict[str, Dict] = data_raw["technology"]
        self.recipes: Dict[str, Dict] = {
            name: recipe
            for name, recipe in data_raw["recipe"].items()
            if not is_secondary_recipe(name, recipe)
        }
        self.item_index: Dict[str, Dict] = {}
        self.item_type_by_name: Dict[str, str] = {}
        for proto_type in ITEM_LIKE_TYPES:
            for name, proto in data_raw.get(proto_type, {}).items():
                self.item_index[name] = proto
                self.item_type_by_name[name] = proto_type

        self.root_materials = self._build_root_materials()
        self.root_crafting_categories = self._build_root_crafting_categories()
        self.category_providers = self._build_category_providers()
        self.provider_categories_by_item = self._build_provider_categories_by_item()
        self.starting_provider_items = self._build_starting_provider_items()
        self.starting_provider_categories = self._build_starting_provider_categories()
        self.producing_recipes: Dict[str, List[str]] = defaultdict(list)
        for recipe_name, recipe in self.recipes.items():
            for result_name, _ in recipe_results(recipe):
                self.producing_recipes[result_name].append(recipe_name)

        self.all_recipe_unlocks_by_tech: Dict[str, List[str]] = defaultdict(list)
        self.unlocks_by_tech: Dict[str, List[str]] = defaultdict(list)
        for tech_name, tech in self.technologies.items():
            for effect in tech.get("effects", []) or []:
                if effect.get("type") == "unlock-recipe":
                    recipe_name = effect["recipe"]
                    if recipe_name in data_raw["recipe"]:
                        self.all_recipe_unlocks_by_tech[tech_name].append(recipe_name)
                    if recipe_name in self.recipes:
                        self.unlocks_by_tech[tech_name].append(recipe_name)

        self.tech_dependents: Dict[str, List[str]] = defaultdict(list)
        for tech_name, tech in self.technologies.items():
            for prerequisite in tech.get("prerequisites", []) or []:
                if prerequisite in self.technologies:
                    self.tech_dependents[prerequisite].append(tech_name)

        self.world_trigger_recipe_techs: Dict[str, List[str]] = defaultdict(list)
        for tech_name, tech in self.technologies.items():
            if (
                self.tech_visible(tech_name)
                and (tech.get("research_trigger") or {}).get("type") == "mine-entity"
            ):
                for recipe_name in self.unlocks_by_tech.get(tech_name, []):
                    self.world_trigger_recipe_techs[recipe_name].append(tech_name)
        self.world_trigger_recipes = set(self.world_trigger_recipe_techs)
        self.always_enabled_recipes = {
            name for name, recipe in self.recipes.items() if recipe_enabled_from_start(recipe)
        }
        self.start_enabled_recipes = set(self.always_enabled_recipes) | self.world_trigger_recipes

    def _build_root_materials(self) -> Set[str]:
        roots = {"water", "taxpayer-money", "biter-worker"}
        for proto_type in RESOURCE_ROOT_TYPES:
            for proto in self.data_raw.get(proto_type, {}).values():
                minable = proto.get("minable") or {}
                result = minable.get("result")
                if result:
                    roots.add(result)
                for res in minable.get("results", []) or []:
                    if isinstance(res, dict) and res.get("name"):
                        roots.add(res["name"])
        return roots

    def _build_root_crafting_categories(self) -> Set[str]:
        categories: Set[str] = set()
        for proto in self.data_raw.get("character", {}).values():
            for category in proto.get("crafting_categories", []) or []:
                if category:
                    categories.add(category)
        categories.add("crafting")
        return categories

    def _build_category_providers(self) -> Dict[str, Tuple[str, ...]]:
        providers: Dict[str, Set[str]] = defaultdict(set)
        place_result_items: Dict[str, Set[str]] = defaultdict(set)

        for item_name, item_proto in self.item_index.items():
            if item_proto.get("hidden"):
                continue
            place_result = item_proto.get("place_result")
            if place_result:
                place_result_items[place_result].add(item_name)

        for proto_group in self.data_raw.values():
            if not isinstance(proto_group, dict):
                continue
            for entity_name, proto in proto_group.items():
                categories = proto.get("crafting_categories")
                if categories is None:
                    single_category = proto.get("crafting_category")
                    categories = [single_category] if single_category else []

                if not categories:
                    continue

                provider_items = place_result_items.get(entity_name, set())
                if not provider_items:
                    continue

                for category in categories:
                    if not category:
                        continue
                    providers[category].update(provider_items)

        return {
            category: tuple(sorted(item_names))
            for category, item_names in providers.items()
        }

    def _build_provider_categories_by_item(self) -> Dict[str, Tuple[str, ...]]:
        categories_by_item: Dict[str, Set[str]] = defaultdict(set)
        for category, item_names in self.category_providers.items():
            for item_name in item_names:
                categories_by_item[item_name].add(category)
        return {
            item_name: tuple(sorted(category_names))
            for item_name, category_names in categories_by_item.items()
        }

    def _build_starting_provider_items(self) -> Tuple[str, ...]:
        return tuple(
            sorted(
                item_name
                for item_name in STARTING_PROVIDER_ITEMS
                if item_name in self.item_index
            )
        )

    def _build_starting_provider_categories(self) -> Tuple[str, ...]:
        categories: Set[str] = set()
        for item_name in self.starting_provider_items:
            categories.update(self.provider_categories_by_item.get(item_name, ()))
        return tuple(sorted(categories))

    def tech_visible(self, tech_name: str) -> bool:
        tech = self.technologies[tech_name]
        return tech.get("enabled", True) and not tech.get("hidden", False)

    def is_target_item(self, item_name: str) -> bool:
        proto = self.item_index.get(item_name)
        if not proto or proto.get("hidden"):
            return False
        return "place_result" in proto or self.item_type_by_name[item_name] in {
            "armor",
            "module",
            "capsule",
        }

    def is_building_item(self, item_name: str) -> bool:
        proto = self.item_index.get(item_name)
        return bool(proto) and not proto.get("hidden") and "place_result" in proto

    def is_mod_item(self, item_name: str) -> bool:
        proto = self.item_index.get(item_name)
        subgroup = (proto or {}).get("subgroup") or ""
        return bool(proto) and subgroup.startswith("admin-")

    def is_mod_building_item(self, item_name: str) -> bool:
        return self.is_building_item(item_name) and self.is_mod_item(item_name)

    @lru_cache(maxsize=None)
    def prereq_closure(self, tech_name: str) -> Tuple[str, ...]:
        seen: Set[str] = set()
        stack: List[str] = list(self.technologies[tech_name].get("prerequisites", []) or [])
        while stack:
            current = stack.pop()
            if current in seen or current not in self.technologies:
                continue
            seen.add(current)
            stack.extend(self.technologies[current].get("prerequisites", []) or [])
        return tuple(sorted(seen))

    @lru_cache(maxsize=None)
    def reachable_trigger_key(
        self,
        tech_key: Tuple[str, ...],
        excluded_techs: Tuple[str, ...] = (),
    ) -> Tuple[str, ...]:
        reachable = set(tech_key)
        excluded = set(excluded_techs)

        changed = True
        while changed:
            changed = False
            current_key = tuple(sorted(reachable))
            for tech_name, tech in sorted(self.technologies.items()):
                if tech_name in reachable or tech_name in excluded:
                    continue
                if not self.tech_visible(tech_name):
                    continue

                prerequisites = set(tech.get("prerequisites", []) or [])
                if not prerequisites.issubset(reachable):
                    continue

                trigger = tech.get("research_trigger") or {}
                trigger_type = trigger.get("type")
                if trigger_type == "mine-entity":
                    reachable.add(tech_name)
                    changed = True
                elif trigger_type == "craft-item":
                    item_name = trigger.get("item")
                    if item_name and self.craftable(item_name, current_key):
                        reachable.add(tech_name)
                        changed = True

        return tuple(sorted(reachable))

    @lru_cache(maxsize=None)
    def tech_eval_key(self, tech_name: str, include_self: bool = True) -> Tuple[str, ...]:
        base = set(self.prereq_closure(tech_name))
        excluded: Tuple[str, ...] = ()
        if include_self:
            base.add(tech_name)
        else:
            excluded = (tech_name,)
        return self.reachable_trigger_key(tuple(sorted(base)), excluded)

    @lru_cache(maxsize=None)
    def combined_eval_key(
        self,
        base_key: Tuple[str, ...],
        tech_name: str,
    ) -> Tuple[str, ...]:
        combined = set(base_key)
        combined.update(self.prereq_closure(tech_name))
        combined.add(tech_name)
        return self.reachable_trigger_key(tuple(sorted(combined)))

    @lru_cache(maxsize=None)
    def available_recipes(self, tech_key: Tuple[str, ...]) -> Set[str]:
        available = set(self.start_enabled_recipes)
        for tech_name in tech_key:
            available.update(self.unlocks_by_tech.get(tech_name, []))
        return available

    @lru_cache(maxsize=None)
    def descendants(self, tech_name: str) -> Tuple[str, ...]:
        seen: Set[str] = set()
        queue: deque[str] = deque(self.tech_dependents.get(tech_name, []))
        ordered: List[str] = []
        while queue:
            current = queue.popleft()
            if current in seen:
                continue
            seen.add(current)
            ordered.append(current)
            queue.extend(self.tech_dependents.get(current, []))
        return tuple(ordered)

    @lru_cache(maxsize=None)
    def full_tech_key(self) -> Tuple[str, ...]:
        return tuple(
            sorted(
                tech_name
                for tech_name in self.technologies
                if self.tech_visible(tech_name)
            )
        )

    @lru_cache(maxsize=None)
    def craftable(self, item_name: str, tech_key: Tuple[str, ...]) -> bool:
        available = self.available_recipes(tech_key)
        visiting: Set[str] = set()

        def rec(name: str) -> bool:
            if name in self.root_materials:
                return True
            if name in visiting:
                return False
            producers = self.producing_recipes.get(name)
            if not producers:
                return False

            visiting.add(name)
            for recipe_name in producers:
                if recipe_name not in available:
                    continue
                recipe = self.recipes[recipe_name]
                ok = True
                for ingredient_name, ingredient_type in recipe_ingredients(recipe):
                    if ingredient_type == "item":
                        if not rec(ingredient_name):
                            ok = False
                            break
                    else:
                        if ingredient_name not in self.root_materials and not rec(ingredient_name):
                            ok = False
                            break
                if ok:
                    visiting.remove(name)
                    return True
            visiting.remove(name)
            return False

        return rec(item_name)

    @lru_cache(maxsize=None)
    def always_enabled_craftable(self, item_name: str) -> bool:
        visiting: Set[str] = set()

        def rec(name: str) -> bool:
            if name in self.root_materials:
                return True
            if name in visiting:
                return False
            producers = self.producing_recipes.get(name)
            if not producers:
                return False

            visiting.add(name)
            for recipe_name in producers:
                if recipe_name not in self.always_enabled_recipes:
                    continue
                recipe = self.recipes[recipe_name]
                ok = True
                for ingredient_name, ingredient_type in recipe_ingredients(recipe):
                    if ingredient_type == "item":
                        if not rec(ingredient_name):
                            ok = False
                            break
                    else:
                        if ingredient_name not in self.root_materials and not rec(ingredient_name):
                            ok = False
                            break
                if ok:
                    visiting.remove(name)
                    return True
            visiting.remove(name)
            return False

        return rec(item_name)

    @lru_cache(maxsize=None)
    def machine_state(
        self,
        tech_key: Tuple[str, ...],
        excluded_provider_items: Tuple[str, ...] = (),
    ) -> Tuple[Tuple[str, ...], Tuple[str, ...], Tuple[str, ...]]:
        available = self.available_recipes(tech_key)
        excluded = set(excluded_provider_items)
        craftable_items: Set[str] = set(self.root_materials)
        craftable_recipes: Set[str] = set()
        available_categories: Set[str] = set(self.root_crafting_categories)
        for category_name in self.starting_provider_categories:
            providers = [
                provider_name
                for provider_name in self.category_providers.get(category_name, ())
                if provider_name not in excluded
            ]
            if providers:
                available_categories.add(category_name)

        changed = True
        while changed:
            changed = False
            for recipe_name in sorted(available):
                if recipe_name in craftable_recipes:
                    continue

                recipe = self.recipes[recipe_name]
                category_name = recipe_category(recipe) or "crafting"
                if category_name not in available_categories:
                    continue

                if any(
                    ingredient_name not in craftable_items
                    for ingredient_name, _ in recipe_ingredients(recipe)
                ):
                    continue

                craftable_recipes.add(recipe_name)
                changed = True

                for result_name, _ in recipe_results(recipe):
                    if result_name not in craftable_items:
                        craftable_items.add(result_name)
                        changed = True

                    if result_name in excluded:
                        continue

                    for provided_category in self.provider_categories_by_item.get(result_name, ()):
                        if provided_category not in available_categories:
                            available_categories.add(provided_category)
                            changed = True

        return (
            tuple(sorted(craftable_items)),
            tuple(sorted(craftable_recipes)),
            tuple(sorted(available_categories)),
        )

    @lru_cache(maxsize=None)
    def machine_craftable(
        self,
        item_name: str,
        tech_key: Tuple[str, ...],
        excluded_provider_items: Tuple[str, ...] = (),
    ) -> bool:
        craftable_items, _, _ = self.machine_state(tech_key, excluded_provider_items)
        return item_name in set(craftable_items)

    @lru_cache(maxsize=None)
    def recipe_machine_usable(
        self,
        recipe_name: str,
        tech_key: Tuple[str, ...],
        excluded_provider_items: Tuple[str, ...] = (),
    ) -> bool:
        _, craftable_recipes, _ = self.machine_state(tech_key, excluded_provider_items)
        return recipe_name in set(craftable_recipes)

    def recipe_ingredients_machine_ready(
        self,
        recipe_name: str,
        tech_key: Tuple[str, ...],
        excluded_provider_items: Tuple[str, ...] = (),
    ) -> bool:
        return all(
            ingredient_name in self.root_materials
            or self.machine_craftable(ingredient_name, tech_key, excluded_provider_items)
            for ingredient_name, _ in recipe_ingredients(self.recipes[recipe_name])
        )

    def direct_target_findings(self) -> List[Dict]:
        findings: List[Dict] = []
        for tech_name in sorted(self.technologies):
            if not self.tech_visible(tech_name):
                continue

            before_key = self.tech_eval_key(tech_name, include_self=False)
            after_key = self.tech_eval_key(tech_name, include_self=True)
            for recipe_name in self.unlocks_by_tech.get(tech_name, []):
                output_targets = [
                    result_name
                    for result_name, _ in recipe_results(self.recipes[recipe_name])
                    if self.is_target_item(result_name)
                ]
                if not output_targets:
                    continue

                before_targets = sorted(
                    target for target in output_targets if self.craftable(target, before_key)
                )
                after_targets = sorted(
                    target for target in output_targets if self.craftable(target, after_key)
                )

                if any(target not in before_targets for target in after_targets):
                    continue

                if before_targets and (self.technologies[tech_name].get("research_trigger") or {}).get("type") == "mine-entity":
                    continue

                delayed_resolution = None
                finding_type = "already_accessible_before_unlock" if before_targets else "blocked_after_unlock"
                if not before_targets:
                    delayed_resolution = self.find_reachable_resolution(
                        after_key,
                        tech_name,
                        output_targets,
                    )
                    if delayed_resolution is not None:
                        finding_type = "delayed_until_reachable_tech"
                findings.append(
                    {
                        "type": finding_type,
                        "technology": tech_name,
                        "recipe": recipe_name,
                        "targets": output_targets,
                        "before_targets": before_targets,
                        "after_targets": after_targets,
                        "delayed_resolution": delayed_resolution,
                        "missing_paths": (
                            self.missing_ingredient_paths(recipe_name, after_key)
                            if finding_type == "blocked_after_unlock"
                            else []
                        ),
                    }
                )
        return findings

    def find_reachable_resolution(
        self,
        base_key: Tuple[str, ...],
        source_tech_name: str,
        targets: Sequence[str],
    ) -> Optional[Dict[str, Sequence[str]]]:
        for candidate in sorted(self.technologies):
            if candidate == source_tech_name or not self.tech_visible(candidate):
                continue
            candidate_after = self.combined_eval_key(base_key, candidate)
            craftable_targets = sorted(
                target for target in targets if self.craftable(target, candidate_after)
            )
            if craftable_targets:
                return {
                    "technology": candidate,
                    "targets": craftable_targets,
                }
        return None

    def missing_ingredient_paths(self, recipe_name: str, tech_key: Tuple[str, ...]) -> List[str]:
        recipe = self.recipes[recipe_name]
        paths: List[str] = []
        for ingredient_name, ingredient_type in recipe_ingredients(recipe):
            if ingredient_type == "item":
                if not self.craftable(ingredient_name, tech_key):
                    leaf = self.first_missing_leaf(ingredient_name, tech_key)
                    if leaf:
                        paths.append(f"{ingredient_name} -> {leaf}")
                    else:
                        paths.append(ingredient_name)
            elif ingredient_name not in self.root_materials and not self.craftable(ingredient_name, tech_key):
                paths.append(ingredient_name)
        return sorted(dict.fromkeys(paths))

    def first_missing_leaf(self, item_name: str, tech_key: Tuple[str, ...]) -> Optional[str]:
        available = self.available_recipes(tech_key)
        visiting: Set[str] = set()

        def rec(name: str) -> Optional[str]:
            if name in self.root_materials:
                return None
            if name in visiting:
                return name
            producers = self.producing_recipes.get(name)
            if not producers:
                return name

            visiting.add(name)
            for recipe_name in producers:
                if recipe_name not in available:
                    continue
                bad_leaf = None
                for ingredient_name, ingredient_type in recipe_ingredients(self.recipes[recipe_name]):
                    if ingredient_type == "item":
                        bad_leaf = rec(ingredient_name)
                    elif ingredient_name in self.root_materials:
                        bad_leaf = None
                    else:
                        bad_leaf = rec(ingredient_name)
                    if bad_leaf:
                        break
                if bad_leaf is None:
                    visiting.remove(name)
                    return None
            visiting.remove(name)
            return name

        return rec(item_name)

    @lru_cache(maxsize=None)
    def always_enabled_first_missing_leaf(self, item_name: str) -> Optional[str]:
        visiting: Set[str] = set()

        def rec(name: str) -> Optional[str]:
            if name in self.root_materials:
                return None
            if name in visiting:
                return name
            producers = self.producing_recipes.get(name)
            if not producers:
                return name

            visiting.add(name)
            for recipe_name in producers:
                if recipe_name not in self.always_enabled_recipes:
                    continue
                bad_leaf = None
                for ingredient_name, ingredient_type in recipe_ingredients(self.recipes[recipe_name]):
                    if ingredient_type == "item":
                        bad_leaf = rec(ingredient_name)
                    elif ingredient_name in self.root_materials:
                        bad_leaf = None
                    else:
                        bad_leaf = rec(ingredient_name)
                    if bad_leaf:
                        break
                if bad_leaf is None:
                    visiting.remove(name)
                    return None
            visiting.remove(name)
            return name

        return rec(item_name)

    def enabled_recipe_missing_paths(self, recipe_name: str) -> List[str]:
        recipe = self.recipes[recipe_name]
        paths: List[str] = []
        for ingredient_name, ingredient_type in recipe_ingredients(recipe):
            if ingredient_type == "item":
                if not self.always_enabled_craftable(ingredient_name):
                    leaf = self.always_enabled_first_missing_leaf(ingredient_name)
                    if leaf:
                        paths.append(f"{ingredient_name} -> {leaf}")
                    else:
                        paths.append(ingredient_name)
            elif ingredient_name not in self.root_materials and not self.always_enabled_craftable(ingredient_name):
                paths.append(ingredient_name)
        return sorted(dict.fromkeys(paths))

    def enabled_recipe_gating_findings(self) -> List[Dict]:
        findings = []
        for recipe_name in sorted(self.always_enabled_recipes):
            missing_paths = self.enabled_recipe_missing_paths(recipe_name)
            if not missing_paths:
                continue
            findings.append(
                {
                    "recipe": recipe_name,
                    "missing_paths": missing_paths,
                }
            )
        return findings

    def machine_missing_ingredient_paths(
        self,
        recipe_name: str,
        tech_key: Tuple[str, ...],
        excluded_provider_items: Tuple[str, ...] = (),
    ) -> List[str]:
        recipe = self.recipes[recipe_name]
        paths: List[str] = []
        for ingredient_name, ingredient_type in recipe_ingredients(recipe):
            if ingredient_name in self.root_materials:
                continue
            if self.machine_craftable(ingredient_name, tech_key, excluded_provider_items):
                continue
            blocker = self.first_machine_missing_leaf(
                ingredient_name,
                tech_key,
                excluded_provider_items,
            )
            if blocker:
                paths.append(f"{ingredient_name} -> {blocker}")
            else:
                paths.append(ingredient_name)
        return sorted(dict.fromkeys(paths))

    @lru_cache(maxsize=None)
    def first_machine_missing_leaf(
        self,
        item_name: str,
        tech_key: Tuple[str, ...],
        excluded_provider_items: Tuple[str, ...] = (),
    ) -> Optional[str]:
        available = self.available_recipes(tech_key)
        _, _, available_categories = self.machine_state(tech_key, excluded_provider_items)
        available_category_set = set(available_categories)
        excluded = set(excluded_provider_items)
        visiting: Set[str] = set()

        def rec(name: str) -> Optional[str]:
            if name in self.root_materials:
                return None
            if name in visiting:
                return name

            producers = [
                recipe_name
                for recipe_name in self.producing_recipes.get(name, ())
                if recipe_name in available
            ]
            if not producers:
                return name

            visiting.add(name)
            try:
                first_category_blocker: Optional[str] = None
                for recipe_name in producers:
                    recipe = self.recipes[recipe_name]
                    category_name = recipe_category(recipe) or "crafting"
                    if category_name not in available_category_set:
                        providers = [
                            provider_name
                            for provider_name in self.category_providers.get(category_name, ())
                            if provider_name not in excluded
                        ]
                        if providers:
                            first_category_blocker = (
                                f"{name} needs {category_name} via {', '.join(providers)}"
                            )
                        else:
                            first_category_blocker = (
                                f"{name} needs unavailable category {category_name}"
                            )
                        continue

                    bad_leaf = None
                    for ingredient_name, _ in recipe_ingredients(recipe):
                        if ingredient_name in self.root_materials:
                            continue
                        bad_leaf = rec(ingredient_name)
                        if bad_leaf:
                            break
                    if bad_leaf is None:
                        return None
                    if first_category_blocker is None:
                        first_category_blocker = bad_leaf

                return first_category_blocker or name
            finally:
                visiting.remove(name)

        return rec(item_name)

    def recipe_machine_blockers(
        self,
        recipe_name: str,
        tech_key: Tuple[str, ...],
        excluded_provider_items: Tuple[str, ...] = (),
    ) -> List[str]:
        recipe = self.recipes[recipe_name]
        category_name = recipe_category(recipe) or "crafting"
        _, _, available_categories = self.machine_state(tech_key, excluded_provider_items)
        available_category_set = set(available_categories)
        blockers: List[str] = []

        if category_name not in available_category_set:
            providers = [
                provider_name
                for provider_name in self.category_providers.get(category_name, ())
                if provider_name not in set(excluded_provider_items)
            ]
            if providers:
                blockers.append(
                    f"category {category_name} unavailable; providers not machine-craftable: {', '.join(providers)}"
                )
            else:
                blockers.append(f"category {category_name} unavailable")

        blockers.extend(
            f"ingredient {path}"
            for path in self.machine_missing_ingredient_paths(
                recipe_name,
                tech_key,
                excluded_provider_items,
            )
        )
        return blockers

    def start_accessible_recipe_machine_findings(self) -> List[Dict]:
        findings: List[Dict] = []
        start_key: Tuple[str, ...] = ()
        for recipe_name in sorted(self.start_enabled_recipes):
            recipe = self.recipes[recipe_name]
            if recipe.get("hidden"):
                continue
            if (recipe_category(recipe) or "crafting") == "parameters":
                continue
            if not self.recipe_ingredients_machine_ready(recipe_name, start_key):
                continue
            if self.recipe_machine_usable(recipe_name, start_key):
                continue
            if (
                recipe_name in self.world_trigger_recipes
                and self.find_world_trigger_recipe_machine_resolution(recipe_name)
            ):
                continue
            findings.append(
                {
                    "recipe": recipe_name,
                    "category": recipe_category(recipe) or "crafting",
                    "machine_blockers": self.recipe_machine_blockers(recipe_name, start_key),
                }
            )
        return findings

    def find_world_trigger_recipe_machine_resolution(self, recipe_name: str) -> Optional[Dict[str, str]]:
        for tech_name in sorted(self.world_trigger_recipe_techs.get(recipe_name, [])):
            resolution = self.find_descendant_recipe_machine_resolution(tech_name, recipe_name)
            if resolution is not None:
                return resolution
        return None

    def find_descendant_recipe_machine_resolution(
        self,
        tech_name: str,
        recipe_name: str,
    ) -> Optional[Dict[str, str]]:
        for descendant in self.descendants(tech_name):
            if not self.tech_visible(descendant):
                continue
            descendant_after = self.tech_eval_key(descendant, include_self=True)
            if self.recipe_machine_usable(recipe_name, descendant_after):
                return {"technology": descendant}
        return None

    def unlocked_recipe_machine_findings(self) -> List[Dict]:
        findings: List[Dict] = []
        for tech_name in sorted(self.technologies):
            if not self.tech_visible(tech_name):
                continue

            after_key = self.tech_eval_key(tech_name, include_self=True)
            for recipe_name in sorted(self.unlocks_by_tech.get(tech_name, [])):
                recipe = self.recipes[recipe_name]
                if recipe.get("hidden"):
                    continue
                if not self.recipe_ingredients_machine_ready(recipe_name, after_key):
                    continue
                if self.recipe_machine_usable(recipe_name, after_key):
                    continue

                delayed_resolution = self.find_descendant_recipe_machine_resolution(
                    tech_name,
                    recipe_name,
                )
                findings.append(
                    {
                        "type": (
                            "delayed_until_descendant"
                            if delayed_resolution is not None
                            else "blocked_after_unlock"
                        ),
                        "technology": tech_name,
                        "recipe": recipe_name,
                        "category": recipe_category(recipe) or "crafting",
                        "machine_blockers": self.recipe_machine_blockers(
                            recipe_name,
                            after_key,
                        ),
                        "delayed_resolution": delayed_resolution,
                    }
                )
        return findings

    def permanent_recipe_machine_cycle_findings(self) -> List[Dict]:
        findings: List[Dict] = []
        full_key = self.full_tech_key()
        for recipe_name in sorted(self.recipes):
            recipe = self.recipes[recipe_name]
            if recipe.get("hidden"):
                continue
            if (recipe_category(recipe) or "crafting") == "parameters":
                continue
            if not self.recipe_ingredients_machine_ready(recipe_name, full_key):
                continue
            if self.recipe_machine_usable(recipe_name, full_key):
                continue
            findings.append(
                {
                    "recipe": recipe_name,
                    "category": recipe_category(recipe) or "crafting",
                    "machine_blockers": self.recipe_machine_blockers(recipe_name, full_key),
                }
            )
        return findings

    def find_descendant_machine_resolution(
        self,
        tech_name: str,
        ingredient_name: str,
        excluded_provider_items: Tuple[str, ...] = (),
    ) -> Optional[Dict[str, str]]:
        for descendant in self.descendants(tech_name):
            if not self.tech_visible(descendant):
                continue
            descendant_after = self.tech_eval_key(descendant, include_self=True)
            if self.machine_craftable(
                ingredient_name,
                descendant_after,
                excluded_provider_items,
            ):
                return {"technology": descendant}
        return None

    def building_provider_dependency_findings(self) -> List[Dict]:
        findings: List[Dict] = []
        for tech_name in sorted(self.technologies):
            if not self.tech_visible(tech_name):
                continue

            after_key = self.tech_eval_key(tech_name, include_self=True)
            for recipe_name in self.unlocks_by_tech.get(tech_name, []):
                recipe = self.recipes[recipe_name]
                output_buildings = [
                    result_name
                    for result_name, _ in recipe_results(recipe)
                    if self.is_mod_building_item(result_name)
                ]
                if not output_buildings:
                    continue

                for building_name in output_buildings:
                    for ingredient_name, ingredient_type in recipe_ingredients(recipe):
                        if ingredient_type != "item" or not self.is_mod_item(ingredient_name):
                            continue
                        if self.craftable(ingredient_name, after_key):
                            continue

                        if self.machine_craftable(ingredient_name, after_key):
                            findings.append(
                                {
                                    "type": "requires_self_provider",
                                    "technology": tech_name,
                                    "recipe": recipe_name,
                                    "building": building_name,
                                    "ingredient": ingredient_name,
                                }
                            )
                            continue

                        delayed_resolution = self.find_descendant_machine_resolution(
                            tech_name,
                            ingredient_name,
                            (building_name,),
                        )
                        if delayed_resolution is not None:
                            findings.append(
                                {
                                    "type": "requires_descendant_provider",
                                    "technology": tech_name,
                                    "recipe": recipe_name,
                                    "building": building_name,
                                    "ingredient": ingredient_name,
                                    "delayed_resolution": delayed_resolution,
                                }
                            )
        return findings

    def buildings_without_recipes(self) -> List[str]:
        missing = []
        for item_name in sorted(self.item_index):
            if not self.is_building_item(item_name):
                continue
            if item_name not in self.producing_recipes:
                missing.append(item_name)
        return missing

    def technologies_without_unique_recipe_unlocks(self) -> List[Dict]:
        recipe_unlock_counts: Dict[str, int] = defaultdict(int)
        for tech_name in self.technologies:
            if not self.tech_visible(tech_name):
                continue
            for recipe_name in set(self.all_recipe_unlocks_by_tech.get(tech_name, [])):
                recipe_unlock_counts[recipe_name] += 1

        empty = []
        for tech_name in sorted(self.technologies):
            if not self.tech_visible(tech_name):
                continue
            if tech_name in STRUCTURAL_EMPTY_TECHS:
                continue
            tech = self.technologies[tech_name]
            if tech.get("unit") is None:
                continue
            effects = tech.get("effects", []) or []
            has_non_recipe_effect = any(
                effect.get("type") != "unlock-recipe"
                for effect in effects
            )
            if has_non_recipe_effect:
                continue

            recipe_unlocks = sorted(set(self.all_recipe_unlocks_by_tech.get(tech_name, [])))
            unique_unlocks = [
                recipe_name
                for recipe_name in recipe_unlocks
                if recipe_unlock_counts[recipe_name] == 1
            ]
            if not unique_unlocks:
                empty.append(
                    {
                        "technology": tech_name,
                        "recipe_unlocks": recipe_unlocks,
                    }
                )
        return empty

    def pipeline_only_technologies(self) -> List[str]:
        techs = []
        for tech_name in sorted(self.technologies):
            if not self.tech_visible(tech_name):
                continue
            unlocks = self.unlocks_by_tech.get(tech_name, [])
            if unlocks and not any(
                self.is_target_item(result_name)
                for recipe_name in unlocks
                for result_name, _ in recipe_results(self.recipes[recipe_name])
            ):
                techs.append(tech_name)
        return techs

    def tech_science_packs(self, tech_name: str) -> Set[str]:
        tech = self.technologies[tech_name]
        packs = set()
        for ingredient in (tech.get("unit", {}) or {}).get("ingredients", []) or []:
            pack_name = ingredient[0] if isinstance(ingredient, list) else ingredient.get("name")
            if pack_name:
                packs.add(pack_name)
        return packs

    def parent_pack_gaps(self) -> List[Dict]:
        gaps = []
        for tech_name in sorted(self.technologies):
            if not self.tech_visible(tech_name):
                continue
            child_packs = self.tech_science_packs(tech_name)
            if not child_packs:
                continue
            for prereq_name in self.technologies[tech_name].get("prerequisites", []) or []:
                if prereq_name not in self.technologies or not self.tech_visible(prereq_name):
                    continue
                parent_packs = self.tech_science_packs(prereq_name)
                missing = sorted(parent_packs - child_packs)
                if missing:
                    gaps.append(
                        {
                            "technology": tech_name,
                            "prerequisite": prereq_name,
                            "missing_packs": missing,
                        }
                    )
        return gaps

    def pack_prereq_gaps(self) -> List[Dict]:
        """Find techs that use a science pack without that pack's tech in their
        transitive prerequisite closure.  For example, if a tech requires
        logistic-science-pack in its unit ingredients but never depends on the
        logistic-science-pack technology (directly or transitively), the player
        sees no tech-tree arrow enforcing that ordering."""
        # Only check packs that are also researchable technologies.
        pack_techs = {
            name for name in self.technologies if name.endswith("-science-pack")
        }
        # automation-science-pack is available from the start — no gating needed.
        pack_techs.discard("automation-science-pack")

        gaps = []
        for tech_name in sorted(self.technologies):
            if not self.tech_visible(tech_name):
                continue
            used_packs = self.tech_science_packs(tech_name)
            if not used_packs:
                continue
            closure = set(self.prereq_closure(tech_name))
            for pack_name in sorted(used_packs & pack_techs):
                if pack_name not in closure and pack_name != tech_name:
                    gaps.append(
                        {
                            "technology": tech_name,
                            "pack": pack_name,
                        }
                    )
        return gaps


def render_report(
    analyzer: ProgressionAnalyzer,
    missing_building_recipes: Sequence[str],
    empty_recipe_unlock_techs: Sequence[Dict],
    direct_target_failures: Sequence[Dict],
    parent_pack_gaps: Sequence[Dict],
    pack_prereq_gaps: Sequence[Dict],
    enabled_recipe_gating_failures: Sequence[Dict],
    permanent_recipe_machine_cycle_failures: Sequence[Dict],
    start_accessible_recipe_machine_failures: Sequence[Dict],
    unlocked_recipe_machine_failures: Sequence[Dict],
    building_provider_dependency_failures: Sequence[Dict],
    pipeline_only_techs: Sequence[str],
    dump_path: Path,
) -> str:
    unresolved_failures = [
        finding
        for finding in direct_target_failures
        if finding["type"] == "blocked_after_unlock"
    ]
    delayed_failures = [
        finding
        for finding in direct_target_failures
        if finding["type"].startswith("delayed_until_")
    ]
    premature_failures = [
        finding
        for finding in direct_target_failures
        if finding["type"] == "already_accessible_before_unlock"
    ]
    unresolved_recipe_machine_failures = [
        finding
        for finding in unlocked_recipe_machine_failures
        if finding["type"] == "blocked_after_unlock"
    ]
    delayed_recipe_machine_failures = [
        finding
        for finding in unlocked_recipe_machine_failures
        if finding["type"] == "delayed_until_descendant"
    ]

    lines = [
        "Administratorio Progression Report",
        "================================",
        "",
        f"Prototype dump: {dump_path}",
        f"Root materials discovered: {len(analyzer.root_materials)}",
        f"Filtered recipes analyzed: {len(analyzer.recipes)}",
        f"Visible technologies with unlocks: {sum(1 for name in analyzer.technologies if analyzer.tech_visible(name) and analyzer.unlocks_by_tech.get(name))}",
        "",
        f"Buildings without a recipe: {len(missing_building_recipes)}",
    ]

    if missing_building_recipes:
        for item_name in missing_building_recipes:
            lines.append(f"  - {item_name}")

    lines.extend(
        [
            "",
            "Visible recipe-unlock technologies with no unique recipe unlocks: "
            f"{len(empty_recipe_unlock_techs)}",
        ]
    )
    for finding in empty_recipe_unlock_techs:
        if finding["recipe_unlocks"]:
            lines.append(
                f"  - {finding['technology']} (duplicates: {', '.join(finding['recipe_unlocks'])})"
            )
        else:
            lines.append(f"  - {finding['technology']} (no recipe unlocks)")

    lines.extend(
        [
            "",
            f"Technologies missing science packs required by a parent tech: {len(parent_pack_gaps)}",
        ]
    )
    for gap in parent_pack_gaps:
        lines.append(
            f"  - {gap['technology']} <- {gap['prerequisite']}: {', '.join(gap['missing_packs'])}"
        )

    lines.extend(
        [
            "",
            f"Technologies using a science pack without that pack tech in prerequisites: {len(pack_prereq_gaps)}",
        ]
    )
    for gap in pack_prereq_gaps:
        lines.append(
            f"  - {gap['technology']} uses {gap['pack']} but does not transitively depend on it"
        )

    lines.extend(
        [
            "",
            f"Enabled recipes blocked by tech-gated ingredients: {len(enabled_recipe_gating_failures)}",
        ]
    )
    for finding in enabled_recipe_gating_failures:
        lines.append(f"  - {finding['recipe']}")
        lines.append(f"    Missing from always-enabled graph: {', '.join(finding['missing_paths'])}")

    lines.extend(
        [
            "",
            "Recipes still blocked even with the full visible tech graph: "
            f"{len(permanent_recipe_machine_cycle_failures)}",
        ]
    )
    for finding in permanent_recipe_machine_cycle_failures:
        lines.append(f"  - {finding['recipe']} [{finding['category']}]")
        lines.append(f"    Blocked by: {', '.join(finding['machine_blockers'])}")

    lines.extend(
        [
            "",
            "Start-accessible recipes blocked by machine/category dependencies (informational): "
            f"{len(start_accessible_recipe_machine_failures)}",
        ]
    )
    for finding in start_accessible_recipe_machine_failures:
        lines.append(f"  - {finding['recipe']} [{finding['category']}]")
        lines.append(f"    Blocked by: {', '.join(finding['machine_blockers'])}")

    lines.extend(
        [
            "",
            "Unlocked recipes still blocked at their unlock by machine/category dependencies: "
            f"{len(unresolved_recipe_machine_failures)}",
        ]
    )
    for finding in unresolved_recipe_machine_failures:
        lines.append(
            f"  - {finding['technology']} -> {finding['recipe']} [{finding['category']}]"
        )
        lines.append(f"    Blocked by: {', '.join(finding['machine_blockers'])}")

    lines.extend(
        [
            "",
            "Unlocked recipes blocked at unlock but resolved by a dependent tech: "
            f"{len(delayed_recipe_machine_failures)}",
        ]
    )
    for finding in delayed_recipe_machine_failures:
        lines.append(
            f"  - {finding['technology']} -> {finding['recipe']} [{finding['category']}]"
        )
        lines.append(f"    Blocked by: {', '.join(finding['machine_blockers'])}")
        lines.append(
            "    First machine-usable from dependent tech: "
            f"{finding['delayed_resolution']['technology']}"
        )

    lines.extend(
        [
            "",
            "Building ingredients that depend on the same building or a later provider: "
            f"{len(building_provider_dependency_failures)}",
        ]
    )
    for finding in building_provider_dependency_failures:
        lines.append(
            f"  - {finding['technology']} -> {finding['recipe']} ({finding['building']}) needs {finding['ingredient']}"
        )
        if finding["type"] == "requires_self_provider":
            lines.append(
                f"    Machine-reachable only if {finding['building']} already exists"
            )
        else:
            lines.append(
                "    First machine-reachable from descendant tech: "
                f"{finding['delayed_resolution']['technology']}"
            )

    lines.extend(
        [
            "",
            f"Direct target unlocks still blocked through reachable progression: {len(unresolved_failures)}",
        ]
    )
    for finding in unresolved_failures:
        lines.append(
            f"  - {finding['technology']} -> {finding['recipe']} ({', '.join(finding['targets'])})"
        )
        if finding["missing_paths"]:
            lines.append(f"    Missing after unlock: {', '.join(finding['missing_paths'])}")

    lines.extend(
        [
            "",
            f"Direct target unlocks blocked at unlock but resolved by reachable progression: {len(delayed_failures)}",
        ]
    )
    for finding in delayed_failures:
        resolution = finding["delayed_resolution"]
        lines.append(
            f"  - {finding['technology']} -> {finding['recipe']} ({', '.join(finding['targets'])})"
        )
        lines.append(
            f"    First resolved by reachable tech: {resolution['technology']} ({', '.join(resolution['targets'])})"
        )

    lines.extend(
        [
            "",
            f"Direct target unlocks already accessible before unlock: {len(premature_failures)}",
        ]
    )
    for finding in premature_failures:
        lines.append(
            f"  - {finding['technology']} -> {finding['recipe']} ({', '.join(finding['targets'])})"
        )
        lines.append(f"    Craftable before unlock: {', '.join(finding['before_targets'])}")

    lines.extend(
        [
            "",
            f"Pipeline-only unlock technologies (informational): {len(pipeline_only_techs)}",
        ]
    )
    for tech_name in pipeline_only_techs:
        lines.append(f"  - {tech_name}")

    return "\n".join(lines) + "\n"


def main() -> int:
    args = parse_args()
    mod_name = repo_name()
    tmp_root = build_temp_profile(mod_name)

    try:
        dump_path = run_dump_data(Path(args.factorio_bin), tmp_root)
        analyzer = ProgressionAnalyzer(json.loads(dump_path.read_text()))

        missing_building_recipes = analyzer.buildings_without_recipes()
        empty_recipe_unlock_techs = analyzer.technologies_without_unique_recipe_unlocks()
        direct_target_failures = analyzer.direct_target_findings()
        parent_pack_gaps = analyzer.parent_pack_gaps()
        pack_prereq_gaps = analyzer.pack_prereq_gaps()
        enabled_recipe_gating_failures = analyzer.enabled_recipe_gating_findings()
        permanent_recipe_machine_cycle_failures = (
            analyzer.permanent_recipe_machine_cycle_findings()
        )
        start_accessible_recipe_machine_failures = (
            analyzer.start_accessible_recipe_machine_findings()
        )
        unlocked_recipe_machine_failures = analyzer.unlocked_recipe_machine_findings()
        building_provider_dependency_failures = analyzer.building_provider_dependency_findings()
        pipeline_only_techs = analyzer.pipeline_only_technologies()
        hard_target_failures = [
            finding
            for finding in direct_target_failures
            if finding["type"] in {"blocked_after_unlock", "already_accessible_before_unlock"}
        ]

        report_text = render_report(
            analyzer=analyzer,
            missing_building_recipes=missing_building_recipes,
            empty_recipe_unlock_techs=empty_recipe_unlock_techs,
            direct_target_failures=direct_target_failures,
            parent_pack_gaps=parent_pack_gaps,
            pack_prereq_gaps=pack_prereq_gaps,
            enabled_recipe_gating_failures=enabled_recipe_gating_failures,
            permanent_recipe_machine_cycle_failures=permanent_recipe_machine_cycle_failures,
            start_accessible_recipe_machine_failures=start_accessible_recipe_machine_failures,
            unlocked_recipe_machine_failures=unlocked_recipe_machine_failures,
            building_provider_dependency_failures=building_provider_dependency_failures,
            pipeline_only_techs=pipeline_only_techs,
            dump_path=dump_path,
        )

        report_path = tmp_root / "script-output" / "administratorio-progression-report.txt"
        write_file(report_path, report_text)
        print(report_text, end="")
        print(f"Report written to {report_path}")

        if missing_building_recipes:
            return 1
        if empty_recipe_unlock_techs:
            return 1
        if args.strict and (
            hard_target_failures
            or parent_pack_gaps
            or pack_prereq_gaps
            or enabled_recipe_gating_failures
            or permanent_recipe_machine_cycle_failures
            or building_provider_dependency_failures
        ):
            return 1
        return 0
    finally:
        if args.keep_temp:
            print(f"Kept temp profile at {tmp_root}")
        else:
            shutil.rmtree(tmp_root, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
