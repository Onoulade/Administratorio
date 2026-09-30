#!/usr/bin/env python3
"""Compare every tip with actual recipe availability throughout the loaded tree."""
from __future__ import annotations

import argparse
from pathlib import Path

from test_factorio_config_matrix import run_case

PREFIX = "administratorio-"


def audit(data: dict) -> None:
    technologies, recipes = data["technology"], data["recipe"]
    tips = {name.removeprefix(PREFIX): tip for name, tip in data["tips-and-tricks-item"].items()
            if name.startswith(PREFIX)}
    contracts = {}

    # These are the player capabilities each guide teaches, independent of the
    # tip's chosen trigger. The engine dump supplies their real research gates.
    def recipe_guides(recipe: str, *ids: str, circuit: bool = False) -> None:
        for name in ids:
            if name in tips:
                assert recipe in recipes, (name, "missing subject recipe", recipe)
                contracts[name] = lambda techs, enabled, r=recipe, c=circuit: (
                    r in enabled and (not c or "circuit-network" in techs))

    recipe_guides("work-order", "work-orders")
    recipe_guides("field-office", "field-office")
    recipe_guides("administrative-clock", "administrative-clock")
    recipe_guides("admin-station", "biter-complaints", "visitor-routing", "frustration", "hard-mode", "evolution-approvals")
    recipe_guides("admin-station", "desk-signals", circuit=True)
    recipe_guides("hush-money-production", "hush-money")
    recipe_guides("eviction-notice-production", "nest-expropriation")
    recipe_guides("job-offer-production", "biter-employment")
    recipe_guides("biter-station", "biter-station", "worker-machines")
    recipe_guides("biterport", "biterport", "biterport-cargo")
    recipe_guides("rideable-biter", "rideable-biter")
    recipe_guides("hired-biter-capsule", "hired-biter", "field-agent-controls")
    recipe_guides("tube-intake", "pneumatic-transport", "tube-limits")
    recipe_guides("tube-intake", "tube-circuits", circuit=True)
    recipe_guides("tube-pump", "tube-pump")
    recipe_guides("transit-authorization-production", "transit-authorization")
    recipe_guides("passenger-wagon", "passenger-rail-service", "passenger-boarding", "passenger-unboarding")
    recipe_guides("passenger-wagon", "passenger-signals", circuit=True)
    recipe_guides("public-train-stop-production", "public-train-stop")
    recipe_guides("middle-management-training-briefing", "management-briefings")
    recipe_guides("unstaffed-operations-waiver", "unstaffed-operations")
    recipe_guides("personnel-routing-sign", "personnel-routing", "personnel-traffic")
    recipe_guides("personnel-routing-sign", "personnel-counts", circuit=True)
    recipe_guides("personnel-routing-multisign", "personnel-multisign", "personnel-circuits")
    recipe_guides("trajectory-compliance-array", "trajectory-compliance-arrays")
    recipe_guides("orbital-employment-catapult", "orbital-employment-catapult", "orbital-miner-recovery")
    recipe_guides("territorial-arbitration-post", "territorial-arbitration")
    recipe_guides("pentapod-sampling-capsule", "pentapod-bargaining")
    recipe_guides("capture-bureau", "capture-bureau")
    recipe_guides("capture-bureau-tourism", "space-tourism")
    recipe_guides("archive-recombination-bureau", "archive-recombination")
    recipe_guides("ai-server", "ai-cooling")
    recipe_guides("interplanetary-terminus", "interplanetary-terminus", "interplanetary-trunk")
    recipe_guides("interplanetary-terminus", "terminus-circuits", circuit=True)
    recipe_guides("involuntary-relocation-cannon", "relocation-cannon", circuit=True)
    contracts["welcome"] = lambda techs, enabled: True
    contracts["orphaned-workers"] = lambda techs, enabled: bool({"biter-station", "biterport"} & enabled)
    if "working-hours" in tips:
        contracts["working-hours"] = lambda techs, enabled: bool({"office-desk", "union-headquarters", "biter-station", "biterport"} & enabled)
    if "quality" in tips:
        contracts["quality"] = lambda techs, enabled: "quality-module" in techs
    if "offworld-economy" in tips:
        contracts["offworld-economy"] = lambda techs, enabled: any(
            "planet-discovery-" + planet in techs for planet in ("vulcanus", "gleba", "fulgora", "aquilo"))
        contracts["specialist-approval"] = lambda techs, enabled: bool(
            {"foundry", "biochamber", "electromagnetic-plant", "cryogenic-plant"} & enabled)
        contracts["personnel-spoilage"] = lambda techs, enabled: (
            "personnel-routing-sign" in enabled and
            bool({"management-formation", "egg-courier-formation"} & techs))
        contracts["egg-couriers"] = lambda techs, enabled: "egg-courier-formation" in techs
    assert tips.keys() == contracts.keys(), ("unaudited tips", tips.keys() ^ contracts.keys())

    def closure(name: str) -> set[str]:
        result, pending = set(), [name]
        while pending:
            current = pending.pop()
            if current not in result:
                result.add(current)
                pending.extend(technologies[current].get("prerequisites", []))
        return result

    def matches(trigger: dict, techs: set[str], enabled: set[str]) -> bool:
        kind = trigger["type"]
        if kind == "research":
            assert trigger["technology"] in technologies, trigger
            return trigger["technology"] in techs
        if kind == "unlock-recipe":
            assert trigger["recipe"] in recipes, trigger
            return trigger["recipe"] in enabled
        assert kind in ("and", "or"), ("event-only unlock can strand existing saves", trigger)
        children = [matches(child, techs, enabled) for child in trigger["triggers"]]
        return all(children) if kind == "and" else any(children)

    states = [("new game", set()), ("completed tree", set(technologies))]
    for technology in technologies:
        state = closure(technology)
        states.extend([(technology + " before", state - {technology}), (technology + " after", state)])
        if "circuit-network" in technologies:
            states.append((technology + " with circuits", state | closure("circuit-network")))
        if "management-formation" in technologies:
            states.append((technology + " with briefings", state | closure("management-formation")))
    seen = set()
    for label, techs in states:
        enabled = {name for name, recipe in recipes.items() if recipe.get("enabled", True)}
        for name in techs:
            enabled.update(effect["recipe"] for effect in technologies[name].get("effects", [])
                           if effect["type"] == "unlock-recipe")
        for name, tip in tips.items():
            actual = tip.get("starting_status") == "unlocked" or matches(tip["trigger"], techs, enabled)
            expected = contracts[name](techs, enabled)
            assert actual == expected, (label, name, "early" if actual else "late")
            if actual:
                seen.add(name)
                title = data["tips-and-tricks-item"][tip["category"]]
                assert title.get("starting_status") == "unlocked" or matches(title["trigger"], techs, enabled), (
                    label, name, "category still locked")
            assert not tip.get("dependencies"), (name, "requires reading unrelated tips")
    assert seen == tips.keys(), ("unreachable tips", tips.keys() - seen)
    print(f"Audited {len(tips)} tips across {len(states)} progression states")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factorio-bin", type=Path, required=True)
    args = parser.parse_args()
    for space_age, hours in ((False, True), (True, True), (True, False)):
        audit(run_case(args.factorio_bin, space_age=space_age, working_hours=hours))
    print("Factorio tip unlock audit passed")
