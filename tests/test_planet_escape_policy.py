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
    ) == ["crude-oil"],
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

targets = planet_escape.add_profile_targets(
    [("rocket-part", Fraction(100))],
    ["bootstrap", "native-machine", "colored-form", "aquilo-fax"],
    ["fulgora", "aquilo"],
)
target_names = {name for name, _ in targets}
for required in {
    "admin-station", "printer-t1", "electromagnetic-plant", "cryogenic-plant",
    "blank-magenta-form", "thermal-transfer-sheet", "interplanetary-fax-exchange",
}:
    check(required in target_names, f"missing named-profile target {required}")

print("Planet escape import-policy tests passed")
