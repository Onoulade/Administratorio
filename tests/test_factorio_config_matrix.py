#!/usr/bin/env python3
"""Load the mod through Factorio under its supported startup configurations."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import tempfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent

CHROMATIC_FAST_TRACKS = (
    "chromatic-landscape-resolution",
    "chromatic-littering-resolution",
    "chromatic-smog-resolution",
    "chromatic-hazmat-resolution",
    "chromatic-noise-resolution",
    "chromatic-loitering-resolution",
    "chromatic-unemployment-resolution",
    "chromatic-vagrancy-resolution",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factorio-bin", help="Path to the Factorio executable.")
    return parser.parse_args()


def mod_name() -> str:
    return json.loads((REPO_ROOT / "info.json").read_text())["name"]


def write_profile(root: Path, *, space_age: bool, working_hours: bool) -> Path:
    mods_dir = root / "mods"
    mods_dir.mkdir(parents=True)
    target = mods_dir / mod_name()

    if working_hours:
        target.symlink_to(REPO_ROOT, target_is_directory=True)
    else:
        shutil.copytree(
            REPO_ROOT,
            target,
            ignore=shutil.ignore_patterns(".git", ".agents", "__pycache__"),
        )
        settings_path = target / "settings.lua"
        settings = settings_path.read_text()
        original = 'name = "administratorio-enable-working-hours",\n    setting_type = "startup",\n    default_value = true,'
        replacement = 'name = "administratorio-enable-working-hours",\n    setting_type = "startup",\n    default_value = false,'
        assert original in settings, "could not locate the Working Hours startup default"
        settings_path.write_text(settings.replace(original, replacement, 1))

    # Built-in expansion mods default to enabled when omitted. Declare their
    # disabled state too, otherwise the base-only case accidentally loads
    # Space Age and validates nothing.
    enabled = {
        "base": True,
        "elevated-rails": space_age,
        "quality": space_age,
        "space-age": space_age,
        mod_name(): True,
    }
    (mods_dir / "mod-list.json").write_text(
        json.dumps(
            {"mods": [{"name": name, "enabled": is_enabled} for name, is_enabled in enabled.items()]},
            indent=2,
        )
        + "\n"
    )
    (root / "config.ini").write_text(
        "[path]\n"
        "read-data=__PATH__system-read-data__\n"
        f"write-data={root}\n\n"
        "[general]\n"
        "locale=auto\n"
    )
    return root


def dump_data(factorio_bin: Path, root: Path) -> dict:
    command = [
        str(factorio_bin),
        "--config",
        str(root / "config.ini"),
        "--mod-directory",
        str(root / "mods"),
        "--disable-audio",
        "--dump-data",
    ]
    result = subprocess.run(command, cwd=REPO_ROOT, text=True, capture_output=True)
    if result.returncode:
        raise AssertionError(
            "Factorio failed to load this startup configuration:\n"
            + result.stdout
            + result.stderr
        )
    return json.loads((root / "script-output" / "data-raw-dump.json").read_text())


def run_case(factorio_bin: Path, *, space_age: bool, working_hours: bool) -> dict:
    with tempfile.TemporaryDirectory(prefix="administratorio-config-matrix-") as temp:
        root = write_profile(Path(temp), space_age=space_age, working_hours=working_hours)
        return dump_data(factorio_bin, root)


def assert_space_age_category_migrations_are_regulated(data_raw: dict) -> None:
    """Audit every Space Age category that can otherwise bypass an assembler."""
    shared_categories = {
        "electronics": "crafting-regulated",
        "pressing": "crafting-regulated",
        "electronics-with-fluid": "advanced-crafting-regulated",
        "metallurgy-or-assembling": "advanced-crafting-regulated",
        "organic-or-hand-crafting": "advanced-crafting-regulated",
        "organic-or-assembling": "advanced-crafting-regulated",
        "electronics-or-assembling": "advanced-crafting-regulated",
        "cryogenics-or-assembling": "advanced-crafting-regulated",
        "crafting-with-fluid-or-metallurgy": "advanced-crafting-regulated",
    }
    recipes = data_raw["recipe"]

    for machine_name, expected_categories in {
        "assembling-machine-1": ["crafting-regulated"],
        "assembling-machine-2": ["crafting-regulated", "advanced-crafting-regulated"],
        "assembling-machine-3": ["crafting-regulated", "advanced-crafting-regulated"],
    }.items():
        actual = data_raw["assembling-machine"][machine_name]["crafting_categories"]
        assert actual == expected_categories, (
            f"{machine_name} retained a Space Age shared category and can bypass paperwork: {actual}"
        )

    audited = 0
    for recipe_name, recipe in recipes.items():
        category = recipe.get("category", "crafting")
        expected_category = shared_categories.get(category)
        if expected_category is None or recipe_name.endswith("-regulated"):
            continue
        audited += 1
        regulated_name = recipe_name + "-regulated"
        regulated = recipes.get(regulated_name)
        assert regulated is not None, (
            f"Space Age shared-category recipe {recipe_name} [{category}] has no regulated assembler copy"
        )
        assert regulated.get("category") == expected_category, (
            f"{regulated_name} should use {expected_category}, got {regulated.get('category')}"
        )
    assert audited > 0, "Space Age shared-category audit did not inspect any recipes"

    for recipe_name, recipe in recipes.items():
        if recipe.get("category", "crafting") in {"electronics", "pressing", "organic-or-hand-crafting"}:
            assert not recipe.get("hide_from_player_crafting", False), (
                f"{recipe_name} disappeared from the Space Age handcrafting menu"
            )

    for recipe_name in ("sulfuric-acid", "plastic-bar", "sulfur", "battery", "heavy-oil-cracking", "light-oil-cracking"):
        ingredients = {ingredient["name"] for ingredient in recipes[recipe_name].get("ingredients", [])}
        assert "chemical-handling-work-order" in ingredients, (
            f"{recipe_name} lost operating paperwork through a Space Age hybrid chemistry category"
        )


def assert_chromatic_fast_tracks_are_space_age_only(base: dict, space_age: dict) -> None:
    """Keep the colored complaint route out of base-only Administratorio."""
    for name in CHROMATIC_FAST_TRACKS:
        assert name not in base.get("technology", {}), (
            f"base-only load must not expose Space Age technology {name}"
        )
        assert name not in base.get("recipe", {}), (
            f"base-only load must not expose Space Age recipe {name}"
        )
        assert name in space_age.get("technology", {}), (
            f"Space Age load must expose technology {name}"
        )
        assert name in space_age.get("recipe", {}), (
            f"Space Age load must expose recipe {name}"
        )


def main() -> None:
    args = parse_args()
    if not args.factorio_bin:
        print("Skipping Factorio startup configuration matrix; --factorio-bin was not provided.")
        return

    factorio_bin = Path(args.factorio_bin)
    if not factorio_bin.exists():
        raise FileNotFoundError(f"Factorio binary not found: {factorio_bin}")

    base = run_case(factorio_bin, space_age=False, working_hours=True)
    space_age = run_case(factorio_bin, space_age=True, working_hours=True)
    assert_chromatic_fast_tracks_are_space_age_only(base, space_age)
    assert "administrative-clock" in base.get("item", {}), "Working Hours should expose the Administrative Clock item"
    assert "administrative-clock" in base.get("constant-combinator", {}), "Working Hours should expose the Administrative Clock entity"
    assert base["item"]["administrative-clock"]["subgroup"] == "circuit-network", "Administrative Clock should be grouped with circuit-network devices"
    assert base["item"]["administrative-clock"]["order"] == "c[combinators]-e[administrative-clock]", "Administrative Clock should appear beside the combinators"
    assert base["recipe"]["administrative-clock"]["subgroup"] == "circuit-network", "Administrative Clock recipe should be grouped with circuit-network devices"
    assert "signal-daytime" in base.get("virtual-signal", {}), "Working Hours should expose the daytime signal"
    assert "signal-day-shift-start" in base.get("virtual-signal", {}), "Working Hours should expose the shift-start signal"
    assert "signal-day-shift-end" in base.get("virtual-signal", {}), "Working Hours should expose the shift-end signal"
    assert "optical-fibre" not in base.get("item", {}), "base-only load must not expose a missing fibre entity"
    assert "inference-token" not in base.get("fluid", {}), "base-only load must not expose orphan AI fluid"
    assert "unstaffed-operations-waiver" not in base.get("module", {}), (
        "base-only load must not expose the Space Age-only waiver module"
    )

    no_working_hours = run_case(factorio_bin, space_age=True, working_hours=False)
    assert "administrative-clock" not in no_working_hours.get("item", {}), "disabled Working Hours must not expose the Administrative Clock item"
    assert "administrative-clock" not in no_working_hours.get("constant-combinator", {}), "disabled Working Hours must not expose the Administrative Clock entity"
    assert "signal-daytime" not in no_working_hours.get("virtual-signal", {}), "disabled Working Hours must not expose the daytime signal"
    assert "signal-day-shift-start" not in no_working_hours.get("virtual-signal", {}), "disabled Working Hours must not expose the shift-start signal"
    assert "signal-day-shift-end" not in no_working_hours.get("virtual-signal", {}), "disabled Working Hours must not expose the shift-end signal"
    assert_space_age_category_migrations_are_regulated(no_working_hours)
    assert "unstaffed-operations" not in no_working_hours.get("technology", {}), (
        "disabled Working Hours must not expose a technology whose recipe does not exist"
    )
    assert "unstaffed-operations-waiver" not in no_working_hours.get("module", {}), (
        "disabled Working Hours must not register its waiver module"
    )

    print("Factorio startup configuration matrix passed")


if __name__ == "__main__":
    main()
