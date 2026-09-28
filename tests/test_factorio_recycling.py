#!/usr/bin/env python3
"""Check actual Quality recycling outputs for cheap-material progression bypasses.

Run with --factorio-bin to test Space Age and base + Quality, with Working Hours
on and off. --dump checks an existing Factorio --dump-data file instead.
"""

from __future__ import annotations

import argparse
import json
import tempfile
from pathlib import Path

from test_factorio_config_matrix import dump_data, write_profile


# Only ordinary manufacturing inputs may come back from these cheap materials.
# Smelting and extraction use native 25% self-recycling rather than recover
# their operating paperwork or the ingredients of an alternate supply route.
BASIC_RETURNS = {
    "paper": {"wood"},
    "ink": {"coal"},
    "useless-documentation": {"redundant-rubble", "paper"},
    "refined-nonsense": {"compacted-rubble"},
    "basic-excuse": {"dubious-data"},
    "watercooler-gossip": {"dubious-data"},
    "justification": {"credentials"},
    "rocket-fuel": {"solid-fuel"},
    **{name: {name} for name in (
        "bullshit-ore", "redundant-rubble", "dubious-data", "compacted-rubble",
        "coal", "iron-plate", "copper-plate", "steel-plate", "stone-brick",
    )},
}
SPACE_AGE_RETURNS = {
    "charged-toner": {"charged-toner"},
    "fabricated-citations": {"fabricated-citations"},
    "orbital-operations-form": {"paper", "ink"},
    "asteroid-processing-docket": {"orbital-operations-form", "paper", "ink"},
}


def assert_recycling_routes(data_raw: dict) -> None:
    recipes = data_raw["recipe"]
    expected = dict(BASIC_RETURNS)
    if "charged-toner" in data_raw["item"]:
        expected.update(SPACE_AGE_RETURNS)
    for item, allowed_returns in expected.items():
        recipe = recipes[item + "-recycling"]
        assert recipe["category"] == "recycling", item
        assert [(entry["name"], entry["amount"]) for entry in recipe["ingredients"]] == [(item, 1)], item
        actual = {entry["name"] for entry in recipe["results"]}
        assert actual == allowed_returns, (
            f"{item}: recycler returns {sorted(actual)}, expected {sorted(allowed_returns)}"
        )
        if allowed_returns == {item}:
            assert recipe["results"][0]["probability"] == 0.25, item

    # Check entire generated families, including future additions and recipes
    # whose unsafe reverse route happens to be overwritten in today's load order.
    for name, recipe in recipes.items():
        if name.startswith(("copy-", "slop-synthesis-")) or recipe.get("category") == "smelting-basic":
            assert recipe.get("auto_recycle") is False, name

    # Ordinary machines still recycle into their construction materials.
    machine = recipes["assembling-machine-1-recycling"]
    assert {entry["name"] for entry in machine["results"]} == {
        "iron-plate", "iron-gear-wheel", "electronic-circuit",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factorio-bin", type=Path)
    parser.add_argument("--dump", type=Path)
    args = parser.parse_args()
    if args.dump:
        assert_recycling_routes(json.loads(args.dump.read_text()))
        print("Recycling route assertions passed")
        return
    if not args.factorio_bin:
        parser.error("provide --factorio-bin or --dump")

    for space_age in (False, True):
        for working_hours in (False, True):
            with tempfile.TemporaryDirectory(prefix="administratorio-recycling-") as temp:
                root = write_profile(Path(temp), space_age=space_age, working_hours=working_hours)
                # The shared startup matrix disables Quality in its base-only
                # profile. This audit explicitly covers base + Quality too.
                path = root / "mods" / "mod-list.json"
                mod_list = json.loads(path.read_text())
                for mod in mod_list["mods"]:
                    if mod["name"] == "quality":
                        mod["enabled"] = True
                path.write_text(json.dumps(mod_list))
                assert_recycling_routes(dump_data(args.factorio_bin, root))
            print(f"Passed: {'Space Age' if space_age else 'base + Quality'}, Working Hours={working_hours}")


if __name__ == "__main__":
    main()
