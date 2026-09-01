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
            "unavailable-worker": {"type": "item", "subgroup": "admin-biter-training"},
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
                "ingredients": [{"type": "item", "name": "unavailable-worker", "amount": 1}],
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
        "ingredient": "unavailable-worker",
    } in findings


def test_science_pack_bootstrap_gap_is_reported_transitively():
    # This mirrors Factorio's final post-inheritance prototypes: the worker
    # bootstrap's blue-pack requirement also makes the specialist training
    # card blue-gated through its worker-formation prerequisite.
    data_raw = {
        "technology": {
            "chemical-science-pack": {
                "unit": {
                    "ingredients": [
                        {"name": "automation-science-pack"},
                        {"name": "logistic-science-pack"},
                        {"name": "chemical-science-pack"},
                    ]
                },
            },
            "formation-center": {
                "unit": {
                    "ingredients": [
                        {"name": "automation-science-pack"},
                        {"name": "logistic-science-pack"},
                    ]
                },
            },
            "worker-formation": {
                "prerequisites": ["formation-center"],
                "unit": {
                    "ingredients": [
                        {"name": "automation-science-pack"},
                        {"name": "logistic-science-pack"},
                        {"name": "chemical-science-pack"},
                    ]
                },
            },
            "chemical-operator-training": {
                "prerequisites": ["worker-formation"],
                "unit": {
                    "ingredients": [
                        {"name": "automation-science-pack"},
                        {"name": "logistic-science-pack"},
                        {"name": "chemical-science-pack"},
                    ]
                },
            },
        },
        "recipe": {},
        "item": {},
        "tool": {},
    }

    analyzer = progression_report.ProgressionAnalyzer(data_raw)
    findings = {
        (finding["technology"], finding["pack"])
        for finding in analyzer.pack_prereq_gaps()
    }

    assert ("worker-formation", "chemical-science-pack") in findings
    assert ("chemical-operator-training", "chemical-science-pack") in findings


def test_science_ceiling_flags_unnecessary_higher_tier_prerequisites():
    data_raw = {
        "technology": {
            "production-science-pack": {
                "unit": {
                    "ingredients": [
                        {"name": "automation-science-pack"},
                        {"name": "logistic-science-pack"},
                        {"name": "chemical-science-pack"},
                        {"name": "production-science-pack"},
                    ]
                },
            },
            "admin-station-capacity-4": {
                "prerequisites": ["production-science-pack"],
                "unit": {
                    "ingredients": [
                        {"name": "automation-science-pack"},
                        {"name": "logistic-science-pack"},
                    ]
                },
            },
        },
        "recipe": {},
        "item": {},
        "tool": {},
    }

    analyzer = progression_report.ProgressionAnalyzer(data_raw)

    assert analyzer.science_ceiling_findings() == [
        {
            "technology": "admin-station-capacity-4",
            "ceiling": "chemical-science-pack",
            "over_gating_prerequisites": ["production-science-pack"],
        }
    ]


def test_unlocked_recipe_machine_cycles_are_not_masked_by_internal_recipes():
    data_raw = {
        "technology": {
            "desk-tech": {
                "effects": [{"type": "unlock-recipe", "recipe": "desk"}],
            },
        },
        "recipe": {
            "desk": {
                "enabled": False,
                "ingredients": [{"type": "item", "name": "paper", "amount": 1}],
                "results": [{"type": "item", "name": "desk", "amount": 1}],
            },
            # This recipe has no unlock effect and is intentionally not a
            # player route. It must not create a permanent-cycle finding.
            "internal-stage": {
                "enabled": False,
                "category": "missing-machine-category",
                "ingredients": [{"type": "item", "name": "paper", "amount": 1}],
                "results": [{"type": "item", "name": "internal-stage", "amount": 1}],
            },
        },
        "item": {
            "paper": {"type": "item"},
            "desk": {"type": "item"},
            "internal-stage": {"type": "item", "hidden": True},
        },
        "tool": {},
        "character": {"character": {"crafting_categories": ["crafting"]}},
    }

    analyzer = progression_report.ProgressionAnalyzer(data_raw)

    assert analyzer.permanent_recipe_machine_cycle_findings() == []


def test_item_reachability_distinguishes_runtime_and_ui_items_from_orphans():
    data_raw = {
        "technology": {},
        "recipe": {},
        "item": {
            "orphan-item": {"type": "item"},
            "biter-worker": {"type": "item"},
            "red-wire": {"type": "item"},
        },
        "tool": {},
        "character": {"character": {"crafting_categories": ["crafting"]}},
    }

    analyzer = progression_report.ProgressionAnalyzer(data_raw)

    assert analyzer.item_reachability_findings() == [
        {"type": "item", "item": "orphan-item", "producers": []}
    ]


def test_staffing_cycle_blocks_first_worker_and_is_reported():
    # Every recipe exists and the complete technology graph is available, but
    # the worker requires credentials whose inputs are made in two
    # biter-station-managed categories. A plain recipe closure incorrectly
    # accepts this graph; the staffed fixed point must reject it.
    data_raw = {
        "technology": {
            "formation-center": {
                "effects": [{"type": "unlock-recipe", "recipe": "formation-center"}],
            },
            "worker-formation": {
                "prerequisites": ["formation-center"],
                "effects": [{"type": "unlock-recipe", "recipe": "worker-biter-formation"}],
            },
            "industrial-propaganda": {
                "prerequisites": ["worker-formation"],
                "effects": [
                    {"type": "unlock-recipe", "recipe": "corporate-breakroom"},
                    {"type": "unlock-recipe", "recipe": "propaganda-distillery"},
                    {"type": "unlock-recipe", "recipe": "credentials-production"},
                    {"type": "unlock-recipe", "recipe": "lie-production"},
                    {"type": "unlock-recipe", "recipe": "refined-nonsense-production"},
                ],
            },
        },
        "recipe": {
            "formation-center": {
                "enabled": False,
                "ingredients": [],
                "results": [{"name": "formation-center"}],
            },
            "corporate-breakroom": {
                "enabled": False,
                "ingredients": [],
                "results": [{"name": "corporate-breakroom"}],
            },
            "propaganda-distillery": {
                "enabled": False,
                "ingredients": [],
                "results": [{"name": "propaganda-distillery"}],
            },
            "worker-biter-formation": {
                "enabled": False,
                "category": "workforce-formation",
                "ingredients": [
                    {"type": "item", "name": "enrolled-biter", "amount": 1},
                    {"type": "item", "name": "credentials", "amount": 1},
                ],
                "results": [{"name": "worker-biter"}],
            },
            "credentials-production": {
                "enabled": False,
                "category": "bureaucracy-registration",
                "ingredients": [
                    {"type": "item", "name": "lie", "amount": 1},
                    {"type": "item", "name": "refined-nonsense", "amount": 1},
                ],
                "results": [{"name": "credentials"}],
            },
            "lie-production": {
                "enabled": False,
                "category": "propaganda-distillery",
                "ingredients": [],
                "results": [{"name": "lie"}],
            },
            "refined-nonsense-production": {
                "enabled": False,
                "category": "watercooler-gossip",
                "ingredients": [],
                "results": [{"name": "refined-nonsense"}],
            },
        },
        "item": {
            "office-desk": {"place_result": "office-desk"},
            "formation-center": {"place_result": "formation-center"},
            "corporate-breakroom": {"place_result": "corporate-breakroom"},
            "propaganda-distillery": {"place_result": "propaganda-distillery"},
            "worker-biter": {},
            "credentials": {},
            "lie": {},
            "refined-nonsense": {},
            "enrolled-biter": {},
        },
        "assembling-machine": {
            "office-desk": {"crafting_categories": ["bureaucracy-registration"]},
            "formation-center": {"crafting_categories": ["workforce-formation"]},
            "corporate-breakroom": {"crafting_categories": ["watercooler-gossip"]},
            "propaganda-distillery": {"crafting_categories": ["propaganda-distillery"]},
        },
        "character": {"character": {"crafting_categories": ["crafting"]}},
        "tool": {},
    }

    analyzer = progression_report.ProgressionAnalyzer(data_raw)
    full_key = analyzer.full_tech_key()

    assert analyzer.machine_craftable("worker-biter", full_key)
    assert not analyzer.staffed_machine_craftable("worker-biter", full_key)
    assert analyzer.staffing_bootstrap_findings() == [
        {
            "worker": "worker-biter",
            "producers": ["worker-biter-formation"],
            "reason": "no worker-producing route is usable before staffed categories activate",
        }
    ]


if __name__ == "__main__":
    test_building_provider_cycle_is_reported_as_unresolvable()
    test_science_pack_bootstrap_gap_is_reported_transitively()
    test_unlocked_recipe_machine_cycles_are_not_masked_by_internal_recipes()
    test_item_reachability_distinguishes_runtime_and_ui_items_from_orphans()
    test_staffing_cycle_blocks_first_worker_and_is_reported()
    print("Progression analyzer unit test passed.")
