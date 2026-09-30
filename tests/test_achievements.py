#!/usr/bin/env python3
"""Check achievement goals, locale coverage, and optional-content boundaries."""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

from test_locale_parity import load_locale

REPO_ROOT = Path(__file__).resolve().parents[1]
GOAL_FIELDS = (
    "technology", "research_all", "to_build", "item_product", "fluid_product",
    "to_use", "minimum_distance", "amount", "limited_to_one_game", "limit_quality",
)


def catalogue(*, space_age: bool) -> dict[str, dict]:
    # Execute the definitions rather than parsing Lua tables with regular
    # expressions: optional branches and shared icon helpers must run too.
    script = '''
mods = SPACE_AGE and {["space-age"] = "2.0"} or {}
data = {extend = function(_, entries)
  for _, p in ipairs(entries) do
    local parts = {}
    for k, v in pairs(p) do
      if type(v) == "string" or type(v) == "number" or type(v) == "boolean" then
        local value = type(v) == "string" and string.format("%q", v) or tostring(v)
        parts[#parts + 1] = string.format("%q", k) .. ":" .. value
      end
    end
    print("{" .. table.concat(parts, ",") .. "}")
  end
end}
require("prototypes.achievements")
'''.replace("SPACE_AGE", "true" if space_age else "false")
    result = subprocess.run(
        ["lua", "-"], input=script, cwd=REPO_ROOT,
        text=True, capture_output=True, check=True,
    )
    prototypes = [json.loads(line) for line in result.stdout.splitlines()]
    assert len({p["name"] for p in prototypes}) == len(prototypes), "duplicate achievement ID"
    return {p["name"]: p for p in prototypes}


def assert_achievement_catalogue(data_raw: dict) -> None:
    """Called with real Factorio dumps by the startup configuration matrix."""
    space_age = "aquilo-cryogenic-administration" in data_raw["technology"]
    goals = catalogue(space_age=space_age)
    all_prototypes = {
        name: p for group in data_raw.values() if isinstance(group, dict)
        for name, p in group.items() if isinstance(p, dict)
    }
    recipes = data_raw["recipe"]
    entities = {
        name for group in data_raw.values() if isinstance(group, dict)
        for name, prototype in group.items()
        if isinstance(prototype, dict) and "collision_box" in prototype
    }
    item_types = ("item", "ammo", "capsule", "tool", "module", "item-with-entity-data")
    for name, p in goals.items():
        assert name in data_raw[p["type"]], name
        technology = p.get("technology")
        if technology:
            tech = data_raw["technology"][technology]
            assert not tech.get("hidden") and tech.get("enabled", True), (name, technology)
        for field in ("to_build", "item_product", "fluid_product", "to_use"):
            target = p.get(field)
            if target:
                assert target in all_prototypes, (name, field, target)
        if p.get("to_build"):
            assert p["to_build"] in entities, (name, "build target must be an entity")
        if p.get("to_use"):
            assert p["to_use"] in data_raw["capsule"], (name, "use target must be a capsule")
        if p.get("item_product"):
            product = p["item_product"]
            assert any(product in data_raw.get(t, {}) for t in item_types), (name, "not an item", product)
            assert any(
                any(r.get("name") == product and r.get("ignored_by_stats", 0) < r.get("amount", 1)
                    for r in recipe.get("results", []))
                for recipe in recipes.values()
            ), (name, "product has no counted recipe output", product)


def main() -> None:
    base = catalogue(space_age=False)
    space = catalogue(space_age=True)
    assert set(base) < set(space)
    assert "ink-hoarder" in base, "cartridge ink must not require Space Age"
    assert "middle-management" not in base

    signatures = {}
    for name, p in space.items():
        assert p["allowed_without_fight"], name
        assert not p.get("research_all"), "hidden/disabled research is not a completion goal"
        if p["type"] in ("produce-achievement", "use-item-achievement"):
            assert p["limited_to_one_game"], name
        if p["type"] != "achievement":
            signature = (p["type"], *(p.get(field) for field in GOAL_FIELDS))
            assert signature not in signatures, (name, "duplicates", signatures.get(signature))
            signatures[signature] = name

    locale_keys = set(space) | {"research-with-promethium"}
    for language in ("en", "fr", "ru"):
        locale = load_locale(language)
        for section in ("achievement-name", "achievement-description"):
            actual = {key for s, key in locale if s == section}
            assert actual == locale_keys, (language, section, locale_keys - actual)
        # Removed content must not remain as unimplemented promises in locales.
        assert ("achievement-name", "asteroid-miner-veteran") not in locale
        for name, p in space.items():
            description = locale["achievement-description", name]
            assert ". " in description, (language, name, "needs a goal and a punchline")
            for field, token in (("technology", "TECHNOLOGY"), ("to_build", "ENTITY"),
                                 ("item_product", "ITEM"), ("to_use", "ITEM")):
                if field in p:
                    assert f"__{token}__{p[field]}__" in description, (language, name, field)
            for token, target in re.findall(r"__(ITEM|ENTITY|TECHNOLOGY)__([^_]+)__", description):
                section = {"ITEM": "item-name", "ENTITY": "entity-name", "TECHNOLOGY": "technology-name"}[token]
                # Native objects use the game's own locales; custom objects
                # must have a translated label in all shipped languages.
                if target not in ("train-stop",):
                    assert (section, target) in locale, (language, name, target)
    print(f"Achievement catalogue passed: {len(base)} base, {len(space)} Space Age; en/fr/ru")


if __name__ == "__main__":
    main()
