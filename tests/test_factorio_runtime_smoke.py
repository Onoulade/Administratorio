#!/usr/bin/env python3
"""Exercise Administratorio control-stage event wiring in the real Factorio engine."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import tempfile
import time
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
MOD_NAME = json.loads((REPO_ROOT / "info.json").read_text(encoding="utf-8"))["name"]
SMOKE_MOD_NAME = "administratorio-runtime-smoke"

SCENARIO_CONTROL = r'''
local regular_stop
local public_stop
local worker_station
local worker_inserter
local worker_belt
local worker_pole
local worker_tree
local worker_machine
local worker_special_blockers = {}
local rideable
local rider

local function fail(message)
  error("Administratorio runtime smoke failure: " .. message)
end

script.on_init(function()
  local surface = game.surfaces[1]
  local force = game.forces.player

  regular_stop = surface.create_entity{
    name = "train-stop",
    position = {0, 0},
    force = force,
    direction = defines.direction.north,
  }
  public_stop = surface.create_entity{
    name = "public-train-stop",
    position = {12, 0},
    force = force,
    direction = defines.direction.north,
  }
  if not regular_stop or not regular_stop.valid then fail("could not create regular train stop") end
  if not public_stop or not public_stop.valid then fail("could not create public train stop") end

  worker_station = surface.create_entity{
    name = "biter-station",
    position = {24, 0},
    force = force,
  }
  if not worker_station or not worker_station.valid then fail("could not create Biter Employment Office") end

  worker_inserter = surface.create_entity{
    name = "inserter",
    position = {30, 0},
    force = force,
  }
  worker_belt = surface.create_entity{
    name = "transport-belt",
    position = {32, 0},
    force = force,
  }
  worker_pole = surface.create_entity{
    name = "small-electric-pole",
    position = {34, 0},
    force = force,
  }
  worker_tree = surface.create_entity{
    name = "tree-01",
    position = {36, 0},
    force = game.forces.neutral,
  }
  if not worker_inserter or not worker_inserter.valid then fail("could not create worker-path inserter") end
  if not worker_belt or not worker_belt.valid then fail("could not create worker-path belt") end
  if not worker_pole or not worker_pole.valid then fail("could not create worker-path power pole") end
  if not worker_tree or not worker_tree.valid then fail("could not create rideable-biter tree obstacle") end

  local water_tiles = {}
  for x = 38, 42 do
    for y = -2, 2 do
      water_tiles[#water_tiles + 1] = {name = "water", position = {x, y}}
    end
  end
  surface.set_tiles(water_tiles)

  worker_machine = surface.create_entity{
    name = "assembling-machine-1",
    position = {46, 0},
    force = force,
  }
  if not worker_machine or not worker_machine.valid then fail("could not create worker-path machine") end

  for index, blocker_name in ipairs({
    "admin-station-corner-blocker",
    "biter-station-wall-blocker",
    "biterport-wall-blocker",
  }) do
    worker_special_blockers[#worker_special_blockers + 1] = {
      name = blocker_name,
      position = {48 + index * 2, 0},
    }
  end

  regular_stop.trains_limit = 7
  public_stop.trains_limit = 7
  script.raise_script_built{entity = regular_stop}
  script.raise_script_built{entity = public_stop}

  rideable = surface.create_entity{
    name = "rideable-biter",
    position = {60, 0},
    force = force,
  }
  rider = surface.create_entity{
    name = "character",
    position = {60, 0},
    force = force,
  }
  if not rideable or not rideable.valid then fail("could not create rideable biter") end
  if not rider or not rider.valid then fail("could not create rideable-biter rider") end
  script.raise_script_built{entity = rideable}
  rideable.set_driver(rider)
end)

script.on_nth_tick(30, function()
  local surface = game.surfaces[1]
  if game.tick == 90 then
    local mounted = surface.find_entities_filtered{
      name = "rideable-biter-mounted",
      position = {60, 0},
      radius = 1,
    }
    if #mounted ~= 1 then fail("occupied rideable biter did not swap to mounted art") end
    if mounted[1].get_driver() ~= rider then fail("rideable-biter visual swap lost its driver") end
    mounted[1].set_driver(nil)
    rideable = mounted[1]
    return
  elseif game.tick == 150 then
    local empty = surface.find_entities_filtered{
      name = "rideable-biter",
      position = {60, 0},
      radius = 1,
    }
    if #empty ~= 1 then fail("empty rideable biter did not restore ordinary art") end
    if empty[1].get_driver() ~= nil then fail("empty rideable biter retained a driver") end
    helpers.write_file("administratorio-runtime-smoke.txt", "PASS\n", false)
    return
  elseif game.tick ~= 30 then
    return
  end

  local regular_chests = surface.find_entities_filtered{
    name = "transit-permit-chest",
    position = regular_stop.position,
    radius = 4,
  }
  local public_chests = surface.find_entities_filtered{
    name = "transit-permit-chest",
    position = public_stop.position,
    radius = 4,
  }

  if #regular_chests ~= 1 then
    fail("regular stop should own exactly one permit chest, got " .. #regular_chests)
  end
  if regular_stop.trains_limit ~= 0 then
    fail("empty regular stop should be closed")
  end
  if #public_chests ~= 0 then
    fail("public stop acquired a permit chest")
  end
  if public_stop.trains_limit ~= 7 then
    fail("public stop train limit was overwritten")
  end

  local worker_names = {
    "biter-worker-t1",
    "biter-worker-t2",
    "biter-worker-t3",
    "biterport-worker",
    "biterport-worker-fast",
    "biterport-worker-express",
    "field-office-worker",
  }
  for _, blocker_spec in ipairs(worker_special_blockers) do
    local blocker = surface.create_entity{
      name = blocker_spec.name,
      position = blocker_spec.position,
      force = game.forces.player,
    }
    if not blocker or not blocker.valid then fail("could not create " .. blocker_spec.name) end
    blocker_spec.entity = blocker
  end
  for _, worker_name in ipairs(worker_names) do
    local prototype = prototypes.entity[worker_name]
    if not prototype or not prototype.has_belt_immunity then
      fail(worker_name .. " is not belt-immune")
    end
    if not prototype.collision_mask.layers.administratorio_worker_obstacle then
      fail(worker_name .. " lacks the worker obstacle collision layer")
    end
    if not worker_machine.prototype.collision_mask.layers.administratorio_worker_obstacle then
      fail(worker_machine.name .. " lacks the worker obstacle collision layer")
    end
    local spawn = surface.find_non_colliding_position(worker_name, worker_station.position, 1, 0.25)
    if not spawn then
      fail(worker_name .. " cannot spawn inside the Biter Employment Office")
    end
    if surface.can_place_entity{name = worker_name, position = {40.5, 0.5}, force = game.forces.player} then
      fail(worker_name .. " can cross water")
    end
    if not surface.can_place_entity{name = worker_name, position = worker_inserter.position, force = game.forces.player} then
      fail(worker_name .. " cannot walk over inserters")
    end
    if not surface.can_place_entity{name = worker_name, position = worker_belt.position, force = game.forces.player} then
      fail(worker_name .. " cannot walk over belts")
    end
    if not surface.can_place_entity{name = worker_name, position = worker_pole.position, force = game.forces.player} then
      fail(worker_name .. " cannot walk over power poles")
    end
    if surface.find_non_colliding_position(worker_name, worker_machine.position, 0.1, 0.05) then
      fail(worker_name .. " can walk through machines")
    end
    for _, blocker_spec in ipairs(worker_special_blockers) do
      if surface.find_non_colliding_position(worker_name, blocker_spec.position, 0.1, 0.05) then
        fail(worker_name .. " can walk through " .. blocker_spec.name)
      end
    end
  end

  for _, rideable_name in ipairs({"rideable-biter", "rideable-biter-mounted"}) do
    local prototype = prototypes.entity[rideable_name]
    if not prototype then fail(rideable_name .. " prototype is missing") end
    if prototype.terrain_friction_modifier ~= 0 then
      fail(rideable_name .. " is still affected by terrain friction")
    end
    if not prototype.collision_mask.layers.administratorio_rideable_biter_collision then
      fail(rideable_name .. " lacks its selective collision layer")
    end
    if not surface.can_place_entity{name = rideable_name, position = worker_tree.position, force = force} then
      fail(rideable_name .. " cannot walk over trees")
    end
    if not surface.can_place_entity{name = rideable_name, position = worker_inserter.position, force = force} then
      fail(rideable_name .. " cannot walk over inserters")
    end
    if not surface.can_place_entity{name = rideable_name, position = worker_pole.position, force = force} then
      fail(rideable_name .. " cannot walk over power poles")
    end
    if surface.can_place_entity{name = rideable_name, position = worker_machine.position, force = force} then
      fail(rideable_name .. " can walk through solid machines")
    end
    if surface.can_place_entity{name = rideable_name, position = {40.5, 0.5}, force = force} then
      fail(rideable_name .. " can cross water")
    end
  end
end)
'''


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factorio-bin", help="Path to the Factorio executable.")
    return parser.parse_args()


def prepare_profile(root: Path) -> None:
    mods_dir = root / "mods"
    mods_dir.mkdir(parents=True)
    (mods_dir / MOD_NAME).symlink_to(REPO_ROOT, target_is_directory=True)

    smoke_mod = mods_dir / SMOKE_MOD_NAME
    scenario_dir = smoke_mod / "scenarios" / "runtime-smoke"
    scenario_dir.mkdir(parents=True)
    (smoke_mod / "info.json").write_text(
        json.dumps(
            {
                "name": SMOKE_MOD_NAME,
                "version": "1.0.0",
                "title": "Administratorio Runtime Smoke",
                "author": "Administratorio test suite",
                "factorio_version": "2.0",
                "dependencies": ["base", "space-age", MOD_NAME],
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    (scenario_dir / "control.lua").write_text(SCENARIO_CONTROL, encoding="utf-8")
    (scenario_dir / "description.json").write_text(
        json.dumps({"name": "Administratorio runtime smoke", "description": "Automated test"})
        + "\n",
        encoding="utf-8",
    )

    enabled = ("base", "elevated-rails", "quality", "space-age", MOD_NAME, SMOKE_MOD_NAME)
    (mods_dir / "mod-list.json").write_text(
        json.dumps({"mods": [{"name": name, "enabled": True} for name in enabled]}, indent=2)
        + "\n",
        encoding="utf-8",
    )
    (root / "config.ini").write_text(
        "[path]\n"
        "read-data=__PATH__system-read-data__\n"
        f"write-data={root}\n\n"
        "[general]\n"
        "locale=auto\n",
        encoding="utf-8",
    )


def main() -> None:
    args = parse_args()
    if not args.factorio_bin:
        print("Skipping Factorio runtime smoke test; --factorio-bin was not provided.")
        return

    factorio_bin = Path(args.factorio_bin)
    if not factorio_bin.exists():
        raise FileNotFoundError(f"Factorio binary not found: {factorio_bin}")

    with tempfile.TemporaryDirectory(prefix="administratorio-runtime-smoke-") as temp:
        root = Path(temp)
        prepare_profile(root)
        server_settings_source = (
            factorio_bin.parent.parent / "data" / "server-settings.example.json"
        )
        server_settings = json.loads(server_settings_source.read_text(encoding="utf-8"))
        server_settings["auto_pause"] = False
        (root / "server-settings.json").write_text(
            json.dumps(server_settings, indent=2) + "\n",
            encoding="utf-8",
        )
        command = [
            str(factorio_bin),
            "--config",
            str(root / "config.ini"),
            "--mod-directory",
            str(root / "mods"),
            "--disable-audio",
            "--server-settings",
            str(root / "server-settings.json"),
            "--start-server-load-scenario",
            f"{SMOKE_MOD_NAME}/runtime-smoke",
            "--until-tick",
            "180",
        ]
        marker = root / "script-output" / "administratorio-runtime-smoke.txt"
        process = subprocess.Popen(
            command,
            cwd=REPO_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        deadline = time.monotonic() + 30
        while not marker.exists() and process.poll() is None and time.monotonic() < deadline:
            time.sleep(0.05)

        if marker.exists():
            process.terminate()
        elif process.poll() is None:
            process.kill()

        output, _ = process.communicate(timeout=10)
        assert marker.exists(), (
            "Factorio exited or timed out without completing the runtime smoke assertions:\n"
            + output
        )
        assert marker.read_text(encoding="utf-8") == "PASS\n"

    print("Factorio control-stage runtime smoke passed")


if __name__ == "__main__":
    main()
