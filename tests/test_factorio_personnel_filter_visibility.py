#!/usr/bin/env python3
"""Audit personnel filter visibility using Factorio's final prototype data."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from test_factorio_config_matrix import run_case


def assert_filter_visibility(data: dict, *, space_age: bool) -> None:
    items, recipes = data["item"], data["recipe"]
    recruited = "enrolled-biter" if space_age else "worker-biter"
    assert "always-show" in items[recruited].get("flags", []), (
        f"scripted recruitment must make {recruited} selectable without a production recipe"
    )
    if not space_age:
        return

    assert "always-show" not in items["worker-biter"].get("flags", []), (
        "Space Age trained workers must retain their formation unlock"
    )
    loading = [r for r in recipes.values() if r.get("category") == "personnel-routing-cargo"]
    assert loading, "personnel loading recipes are missing"
    for recipe in loading:
        assert recipe.get("unlock_results") is False, (
            f"{recipe['name']} exposes personnel through transport research"
        )
        # Keep these recipes usable by the deployment furnace after routing
        # research; suppressing visibility must not remove its cargo whitelist.
        assert recipe["ingredients"][0]["name"] == recipe["results"][0]["name"]
        assert any(
            effect.get("recipe") == recipe["name"]
            for effect in data["technology"]["personnel-routing"]["effects"]
        ), recipe["name"]

    for size in ("small", "medium", "big", "behemoth"):
        package = size + "-spitter-tourism-package"
        assert "always-show" not in items[package].get("flags", []), package
        package_producers = [
            r for r in recipes.values()
            if r.get("unlock_results", True)
            and any(p.get("name") == package for p in r.get("results", []))
        ]
        assert package_producers, f"{package} is ungated raw-item cargo in filters"
        for recipe in package_producers:
            assert recipe.get("enabled") is False, package
            unlockers = {
                name for name, technology in data["technology"].items()
                if any(e.get("recipe") == recipe["name"] for e in technology.get("effects", []))
            }
            capture_unlockers = {
                name for name, technology in data["technology"].items()
                if any(e.get("recipe") == "capture-bureau-tourism" for e in technology.get("effects", []))
            }
            assert unlockers == capture_unlockers, f"{package} must follow tourism capture research"
            assert recipe.get("hidden") and recipe.get("auto_recycle") is False
            for prototype_type in ("assembling-machine", "furnace", "character"):
                for machine in data.get(prototype_type, {}).values():
                    assert recipe["category"] not in machine.get("crafting_categories", []), (
                        f"{package} visibility metadata must not manufacture cargo"
                    )
        tourist = size + "-space-tourist"
        assert "always-show" not in items[tourist].get("flags", []), tourist
        producers = [
            r for r in recipes.values()
            if r.get("unlock_results", True)
            and any(p.get("name") == tourist for p in r.get("results", []))
        ]
        assert producers and all(r.get("enabled") is False for r in producers), tourist
        assert all(r.get("category") == "orbital-bureaucracy" for r in producers), (
            f"{tourist} must become selectable through orbital fulfillment, not transport"
        )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factorio-bin", type=Path)
    parser.add_argument("--data-raw", type=Path)
    args = parser.parse_args()
    if args.data_raw:
        data = json.loads(args.data_raw.read_text())
        assert_filter_visibility(data, space_age="enrolled-biter" in data["item"])
    elif args.factorio_bin:
        for space_age in (False, True):
            data = run_case(args.factorio_bin, space_age=space_age, working_hours=True)
            assert_filter_visibility(data, space_age=space_age)
    else:
        parser.error("provide --factorio-bin or --data-raw")
    print("Factorio personnel filter visibility passed")


if __name__ == "__main__":
    main()
