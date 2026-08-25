"""Focused regression tests for the progression graph's hard-deadlock checks."""

import importlib.util
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("test_progression_report.py")
SPEC = importlib.util.spec_from_file_location("progression_report", MODULE_PATH)
assert SPEC and SPEC.loader
progression_report = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(progression_report)


def test_building_provider_cycle_is_reported_as_unresolvable():
    data_raw = {
        "item": {
            "office-desk": {
                "type": "item",
                "subgroup": "admin-buildings",
                "place_result": "office-desk",
            },
            "formation-center": {
                "type": "item",
                "subgroup": "admin-buildings",
                "place_result": "formation-center",
            },
            "biter-worker": {"type": "item", "subgroup": "admin-biter-training"},
            "enrolled-biter": {"type": "item", "subgroup": "admin-biter-training"},
        },
        "character": {
            "character": {"crafting_categories": ["crafting"]},
        },
        "assembling-machine": {
            "office-desk": {"crafting_categories": ["bureaucracy-registration"]},
            "formation-center": {"crafting_categories": ["workforce-formation"]},
        },
        "technology": {
            "biter-employment": {
                "effects": [{"type": "unlock-recipe", "recipe": "office-desk"}],
            },
            "formation-center": {
                "prerequisites": ["biter-employment"],
                "effects": [{"type": "unlock-recipe", "recipe": "formation-center"}],
            },
            "worker-formation": {
                "prerequisites": ["formation-center"],
                "effects": [{"type": "unlock-recipe", "recipe": "worker-biter-formation"}],
            },
        },
        "recipe": {
            "office-desk": {
                "enabled": False,
                "ingredients": [{"type": "item", "name": "biter-worker", "amount": 1}],
                "results": [{"type": "item", "name": "office-desk", "amount": 1}],
            },
            "formation-center": {
                "enabled": False,
                "ingredients": [{"type": "item", "name": "office-desk", "amount": 1}],
                "results": [{"type": "item", "name": "formation-center", "amount": 1}],
            },
            "worker-biter-formation": {
                "enabled": False,
                "category": "workforce-formation",
                "ingredients": [{"type": "item", "name": "enrolled-biter", "amount": 1}],
                "results": [{"type": "item", "name": "worker-biter", "amount": 1}],
            },
        },
    }

    analyzer = progression_report.ProgressionAnalyzer(data_raw)
    findings = analyzer.building_provider_dependency_findings()

    assert {
        "type": "unresolvable_provider",
        "technology": "biter-employment",
        "recipe": "office-desk",
        "building": "office-desk",
        "ingredient": "biter-worker",
    } in findings


if __name__ == "__main__":
    test_building_provider_cycle_is_reported_as_unresolvable()
    print("Progression analyzer unit test passed.")
