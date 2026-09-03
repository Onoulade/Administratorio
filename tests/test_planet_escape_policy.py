#!/usr/bin/env python3

from fractions import Fraction
import importlib.util
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("test_planet_escape.py")
SPEC = importlib.util.spec_from_file_location("planet_escape", MODULE_PATH)
planet_escape = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(planet_escape)


def check(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


check(planet_escape.classify_import("relay-clerk") == "staffing", "relay clerks must classify as staffing")
check(planet_escape.classify_import("territorial-deed") == "conflict-resolution", "deeds must classify as conflict resolution")
check(planet_escape.classify_import("blank-form") == "ordinary-paperwork", "blank forms must classify as ordinary paperwork")
check(planet_escape.classify_import("crude-oil") == "ordinary-resource", "crude oil must classify as an ordinary resource")

check(
    planet_escape.import_policy_violations(
        "fulgora",
        planet_escape.Counter({"relay-clerk": 1, "crude-oil": 2000}),
        {},
    ) == ["crude-oil (2000 required, 0 allowed)"],
    "Fulgora should allow staffing but reject bulk ordinary imports",
)

check(
    planet_escape.import_policy_violations(
        "gleba",
        planet_escape.Counter({"clerical-trainee": 1, "chemical-operator": 1}),
        {},
    ) == [],
    "Gleba should allow its deliberate staffing seeds",
)

check(
    planet_escape.import_policy_violations(
        "vulcanus",
        planet_escape.Counter({"union-delegate": 3}),
        {},
    ) == ["union-delegate (3 required, 2 allowed)"],
    "Vulcanus must reject staffing beyond its finite escape allowance",
)

check(
    planet_escape.recipe_visible({"hide_from_player_crafting": True}),
    "machine-only recipes must remain in the production graph",
)
check(
    not planet_escape.recipe_visible({"hidden": True}),
    "engine-hidden recipes must stay out of the production graph",
)
check(
    planet_escape.recipe_visible(
        {"name": "iron-gear-wheel-recycling", "hidden": True, "category": "recycling"}
    ),
    "engine-generated recycler routes must remain in the production graph",
)

fulgora_targets = planet_escape.add_profile_targets(
    [("rocket-part", Fraction(100))],
    ["bootstrap", "native-machine", "colored-form", "aquilo-automation"],
    ["fulgora"],
)
target_names = {name for name, _ in fulgora_targets}
for required in {
    "printer-t1", "electromagnetic-plant", "blank-magenta-form",
}:
    check(required in target_names, f"missing named-profile target {required}")
check("admin-station" not in target_names, "Fulgora bootstrap must not require a Nauvis Admin Desk")
check("cryogenic-plant" not in target_names, "Fulgora must not inherit Aquilo's native-machine target")

nauvis_targets = planet_escape.add_profile_targets(
    [], ["bootstrap"], ["nauvis"],
)
check("admin-station" in {name for name, _ in nauvis_targets},
      "Nauvis bootstrap must retain the Admin Desk target")


def fixed_point_fixture():
    return {
        "planet": {
            "test": {
                "map_gen_settings": {
                    "autoplace_settings": {
                        "entity": {"settings": {"fruit-tree": {}}}
                    }
                }
            }
        },
        "technology": {
            "planet-discovery-test": {"effects": []},
            "global-research": {
                "prerequisites": ["planet-discovery-test"],
                "unit": {"ingredients": [["impossible-local-pack", 1]]},
                "effects": [{"type": "unlock-recipe", "recipe": "machine"}],
            },
        },
        "recipe": {
            "machine": {
                "enabled": False,
                "ingredients": [],
                "results": [{"name": "machine"}],
            },
            "cycle": {
                "enabled": True,
                "category": "widgets",
                "ingredients": [{"name": "widget"}],
                "results": [{"name": "widget"}],
            },
            "real-widget": {
                "enabled": True,
                "category": "widgets",
                "ingredients": [],
                "results": [{"name": "widget"}],
            },
        },
        "item": {
            "machine": {"place_result": "machine"},
            "widget": {},
            "fruit": {"spoil_result": "spoilage"},
            "spoilage": {},
            "impossible-local-pack": {},
        },
        "assembling-machine": {
            "machine": {
                "minable": {"result": "machine"},
                "crafting_categories": ["widgets"],
            },
        },
        "character": {"character": {"crafting_categories": ["crafting"]}},
        "simple-entity": {
            "fruit-tree": {"minable": {"result": "fruit"}},
        },
        "fluid": {},
    }


fixture_analyzer = planet_escape.PlanetEscapeAnalyzer(
    fixed_point_fixture(), {"test": {"pressure": 1000, "gravity": 10}}
)
check(
    "global-research" in fixture_analyzer.researched_technologies("test"),
    "science research must use the global force frontier, not local pack production",
)
check(
    "widget" in fixture_analyzer.craftable_outputs("test"),
    "material and provider cycles must converge through the machine fixed point",
)
check(
    "spoilage" in fixture_analyzer.craftable_outputs("test"),
    "spoil results must participate in local progression",
)

print("Planet escape import-policy tests passed")
