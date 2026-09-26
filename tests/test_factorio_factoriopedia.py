#!/usr/bin/env python3
"""Validate navigable recipe routes and acquisition docs in real engine dumps."""
from __future__ import annotations

import argparse
import re
from pathlib import Path

from test_factorio_config_matrix import run_case
from test_locale_parity import load_locale, PLACEHOLDER_RE

PREFIX = "administratorio-factoriopedia."
LINK = re.compile(r"\[(item|fluid|entity|recipe|technology)=([^\]]+)\]")


def audit(raw: dict, space_age: bool) -> None:
    locales = {lang: load_locale(lang) for lang in ("en", "fr", "ru")}
    # Item/entity rich-text IDs span several prototype types. Their names are
    # still required to exist in the current expansion configuration.
    all_names = {name for prototypes in raw.values() for name in prototypes}
    checked = set()

    def check_text(value):
        if isinstance(value, str):
            for kind, name in LINK.findall(value):
                assert name in (raw[kind] if kind in ("recipe", "technology", "fluid") else all_names), (kind, name)
        elif isinstance(value, list):
            key = value[0] if value else ""
            if isinstance(key, str) and key.startswith(PREFIX):
                section, entry = key.split(".", 1)
                english = locales["en"][(section, entry)]
                for lang, locale in locales.items():
                    text = locale[(section, entry)]
                    assert set(PLACEHOLDER_RE.findall(text)) == set(PLACEHOLDER_RE.findall(english)), (lang, key)
                    for placeholder in PLACEHOLDER_RE.findall(text):
                        assert int(placeholder.strip("_")) < len(value), (key, placeholder)
                    check_text(text)
                checked.add(key)
            for child in value[1:]:
                check_text(child)

    pairs = {}
    for name, recipe in raw["recipe"].items():
        if not name.endswith("-regulated"):
            continue
        base_name = name.removesuffix("-regulated")
        original = raw["recipe"].get(base_name)
        if not original or original.get("hidden") or recipe.get("hidden"):
            continue
        pairs[name] = base_name
        assert recipe["localised_name"][0] == PREFIX + "route-regulated", name
        assert original["localised_name"][0].startswith(PREFIX + "route-"), base_name
        assert original.get("factoriopedia_alternative") != name, base_name
        assert not original.get("hidden_in_factoriopedia"), base_name
        assert recipe["always_show_made_in"] and original["always_show_made_in"]

    folded = 0
    for technology in raw["technology"].values():
        effects = technology.get("effects", [])
        visible = {e["recipe"] for e in effects if e["type"] == "unlock-recipe" and not e.get("hidden")}
        for effect in effects:
            if effect["type"] == "unlock-recipe" and pairs.get(effect["recipe"]) in visible:
                assert effect.get("hidden"), (technology["name"], effect["recipe"])
                folded += 1
        check_text(technology.get("localised_description"))

    for prototypes in raw.values():
        for prototype in prototypes.values():
            check_text(prototype.get("localised_name"))
            for field in prototype.get("custom_tooltip_fields", []):
                if isinstance(field["name"], list) and field["name"][0].startswith(PREFIX):
                    assert field["show_in_factoriopedia"] and not field["show_in_tooltip"]
                    check_text(field["name"])
                    check_text(field["value"])

    def acquisition(kind, name, count=1):
        fields = raw[kind][name].get("custom_tooltip_fields", [])
        assert sum(f["name"] == [PREFIX + "obtained-through"] for f in fields) == count, name

    acquisition("item", "worker-biter")
    if space_age:
        acquisition("item", "enrolled-biter")
        acquisition("item", "pentapod-egg", 3)
        for size in ("small", "medium", "big", "behemoth"):
            acquisition("item", size + "-spitter-tourism-package")
        assert len(raw["furnace"]["capture-bureau"]["custom_tooltip_fields"]) == 3
    assert pairs and folded
    print(f"{'Space Age' if space_age else 'Base only'}: {len(pairs)} recipe pairs, "
          f"{folded} folded unlock effects, {len(checked)} translated fields/labels; all links valid")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factorio-bin", type=Path, default=Path("/Applications/factorio.app/Contents/MacOS/factorio"))
    parser.add_argument("--dump", type=Path, help="Audit an existing dump instead of starting the engine")
    parser.add_argument("--base-only", action="store_true", help="The supplied dump has Space Age disabled")
    args = parser.parse_args()
    if args.dump:
        import json
        audit(json.loads(args.dump.read_text()), not args.base_only)
    else:
        for space_age in (True, False):
            audit(run_case(args.factorio_bin, space_age=space_age, working_hours=True), space_age)
