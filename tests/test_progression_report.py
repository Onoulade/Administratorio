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
  - `--strict` fails when a child technology drops a science pack already
    required by one of its prerequisite technologies.
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
SECONDARY_RECIPE_CATEGORIES = {"pneumatic-liquify", "pneumatic-solidify"}


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
    if name.startswith("pneumatic-liquify-") or name.startswith("pneumatic-solidify-"):
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
        self.producing_recipes: Dict[str, List[str]] = defaultdict(list)
        for recipe_name, recipe in self.recipes.items():
            for result_name, _ in recipe_results(recipe):
                self.producing_recipes[result_name].append(recipe_name)

        self.unlocks_by_tech: Dict[str, List[str]] = defaultdict(list)
        for tech_name, tech in self.technologies.items():
            for effect in tech.get("effects", []) or []:
                if effect.get("type") == "unlock-recipe" and effect["recipe"] in self.recipes:
                    self.unlocks_by_tech[tech_name].append(effect["recipe"])

        self.tech_dependents: Dict[str, List[str]] = defaultdict(list)
        for tech_name, tech in self.technologies.items():
            for prerequisite in tech.get("prerequisites", []) or []:
                if prerequisite in self.technologies:
                    self.tech_dependents[prerequisite].append(tech_name)

        self.world_trigger_recipes = {
            recipe_name
            for tech_name, tech in self.technologies.items()
            if self.tech_visible(tech_name)
            and (tech.get("research_trigger") or {}).get("type") == "mine-entity"
            for recipe_name in self.unlocks_by_tech.get(tech_name, [])
        }
        self.always_enabled_recipes = {
            name for name, recipe in self.recipes.items() if recipe_enabled_from_start(recipe)
        }
        self.start_enabled_recipes = set(self.always_enabled_recipes) | self.world_trigger_recipes

    def _build_root_materials(self) -> Set[str]:
        roots = {"water", "taxpayer-money"}
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

    def direct_target_findings(self) -> List[Dict]:
        findings: List[Dict] = []
        for tech_name in sorted(self.technologies):
            if not self.tech_visible(tech_name):
                continue

            before_key = self.prereq_closure(tech_name)
            after_key = tuple(sorted(set(before_key) | {tech_name}))
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
                    delayed_resolution = self.find_descendant_resolution(tech_name, output_targets)
                    if delayed_resolution is not None:
                        finding_type = "delayed_until_descendant"
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

    def find_descendant_resolution(
        self, tech_name: str, targets: Sequence[str]
    ) -> Optional[Dict[str, Sequence[str]]]:
        for descendant in self.descendants(tech_name):
            if not self.tech_visible(descendant):
                continue
            descendant_after = tuple(sorted(set(self.prereq_closure(descendant)) | {descendant}))
            craftable_targets = sorted(
                target for target in targets if self.craftable(target, descendant_after)
            )
            if craftable_targets:
                return {
                    "technology": descendant,
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

    def buildings_without_recipes(self) -> List[str]:
        missing = []
        for item_name in sorted(self.item_index):
            if not self.is_building_item(item_name):
                continue
            if item_name not in self.producing_recipes:
                missing.append(item_name)
        return missing

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


def render_report(
    analyzer: ProgressionAnalyzer,
    missing_building_recipes: Sequence[str],
    direct_target_failures: Sequence[Dict],
    parent_pack_gaps: Sequence[Dict],
    enabled_recipe_gating_failures: Sequence[Dict],
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
        if finding["type"] == "delayed_until_descendant"
    ]
    premature_failures = [
        finding
        for finding in direct_target_failures
        if finding["type"] == "already_accessible_before_unlock"
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
            f"Enabled recipes blocked by tech-gated ingredients: {len(enabled_recipe_gating_failures)}",
        ]
    )
    for finding in enabled_recipe_gating_failures:
        lines.append(f"  - {finding['recipe']}")
        lines.append(f"    Missing from always-enabled graph: {', '.join(finding['missing_paths'])}")

    lines.extend(
        [
            "",
            f"Direct target unlocks still blocked through all dependent techs: {len(unresolved_failures)}",
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
            f"Direct target unlocks blocked at unlock but resolved by a dependent tech: {len(delayed_failures)}",
        ]
    )
    for finding in delayed_failures:
        resolution = finding["delayed_resolution"]
        lines.append(
            f"  - {finding['technology']} -> {finding['recipe']} ({', '.join(finding['targets'])})"
        )
        lines.append(
            f"    First resolved by dependent tech: {resolution['technology']} ({', '.join(resolution['targets'])})"
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
        direct_target_failures = analyzer.direct_target_findings()
        parent_pack_gaps = analyzer.parent_pack_gaps()
        enabled_recipe_gating_failures = analyzer.enabled_recipe_gating_findings()
        pipeline_only_techs = analyzer.pipeline_only_technologies()
        hard_target_failures = [
            finding
            for finding in direct_target_failures
            if finding["type"] in {"blocked_after_unlock", "already_accessible_before_unlock"}
        ]

        report_text = render_report(
            analyzer=analyzer,
            missing_building_recipes=missing_building_recipes,
            direct_target_failures=direct_target_failures,
            parent_pack_gaps=parent_pack_gaps,
            enabled_recipe_gating_failures=enabled_recipe_gating_failures,
            pipeline_only_techs=pipeline_only_techs,
            dump_path=dump_path,
        )

        report_path = tmp_root / "script-output" / "administratorio-progression-report.txt"
        write_file(report_path, report_text)
        print(report_text, end="")
        print(f"Report written to {report_path}")

        if missing_building_recipes:
            return 1
        if args.strict and (hard_target_failures or parent_pack_gaps or enabled_recipe_gating_failures):
            return 1
        return 0
    finally:
        if args.keep_temp:
            print(f"Kept temp profile at {tmp_root}")
        else:
            shutil.rmtree(tmp_root, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
