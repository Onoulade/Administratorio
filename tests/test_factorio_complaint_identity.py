#!/usr/bin/env python3
"""Verify complaint seekers stay active and retain identity in real Factorio."""

from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
import time
from pathlib import Path

from test_factorio_runtime_smoke import REPO_ROOT, SMOKE_MOD_NAME, prepare_profile


SCENARIO_CONTROL = r'''
local station_x = STATION_X
local seeker_id
local original_ids = {}

local function fail(message)
  error("Complaint identity smoke failure: " .. message)
end

script.on_init(function()
  local surface = game.surfaces[1]
  local tiles = {}
  for x = -20, 170 do
    for y = -20, 20 do
      tiles[#tiles + 1] = {name = "grass-1", position = {x, y}}
    end
  end
  surface.set_tiles(tiles)
  local desk = surface.create_entity{
    name = "admin-station", position = {station_x, 0}, force = "player",
  }
  if not desk then fail("could not create desk") end
  script.raise_script_built{entity = desk}
end)

local function check_seeker()
  local units = game.surfaces[1].find_entities_filtered{
    type = "unit", force = "administratorio-biters", area = {{-30, -30}, {170, 30}},
  }
  if #units ~= 5 then fail("redirect lost or added a biter at tick " .. game.tick) end
  local found = false
  for _, unit in ipairs(units) do
    if not original_ids[unit.unit_number] then
      fail("redirect replaced an original biter at tick " .. game.tick)
    end
    local command = unit.commandable and unit.commandable.command
    local dest = command and command.destination
    if game.tick == 120 and command and command.type == defines.command.go_to_location
       and dest then
      if station_x == 40 then
        local dx, dy = dest.x - station_x, dest.y
        if dx * dx + dy * dy >= 49 and dx * dx + dy * dy <= 100 then
          seeker_id = unit.unit_number
        end
      elseif dest.x < 30 then
        seeker_id = unit.unit_number
      end
    end
    if unit.unit_number == seeker_id then
      found = true
      if not unit.active then fail("seeker became inactive at tick " .. game.tick) end
      if unit.ai_settings.allow_destroy_when_commands_fail then
        fail("native AI may destroy seeker after a failed command at tick " .. game.tick)
      end
      if station_x == 140
         and (math.abs(unit.position.x) > 12 or math.abs(unit.position.y) > 16) then
        fail("patrolling seeker drifted at tick " .. game.tick)
      end
    end
  end
  if not found then fail("seeker identity changed or disappeared at tick " .. game.tick) end
  if game.tick == 900 then
    helpers.write_file("administratorio-complaint-identity.txt", "PASS\n", false)
  end
end

script.on_nth_tick(60, function()
  if game.tick == 60 then
    local surface = game.surfaces[1]
    local group = surface.create_unit_group{position = {0, 0}, force = "enemy"}
    for i = 1, 5 do
      local unit = surface.create_entity{
        name = "small-biter", position = {0, i * 2 - 6}, force = "enemy",
      }
      if not unit then fail("could not create biter") end
      original_ids[unit.unit_number] = true
      group.add_member(unit)
    end
    group.start_moving()
  end
  if game.tick >= 120 and game.tick <= 900 then check_seeker() end
end)
'''


def run_case(factorio_bin: Path, station_x: int) -> None:
    with tempfile.TemporaryDirectory(prefix="administratorio-complaint-identity-") as temp:
        root = Path(temp)
        prepare_profile(root)
        scenario = root / "mods" / SMOKE_MOD_NAME / "scenarios" / "runtime-smoke" / "control.lua"
        scenario.write_text(SCENARIO_CONTROL.replace("STATION_X", str(station_x)), encoding="utf-8")
        server_settings_source = factorio_bin.parent.parent / "data" / "server-settings.example.json"
        server_settings = json.loads(server_settings_source.read_text(encoding="utf-8"))
        server_settings["auto_pause"] = False
        (root / "server-settings.json").write_text(json.dumps(server_settings), encoding="utf-8")
        command = [
            str(factorio_bin), "--config", str(root / "config.ini"),
            "--mod-directory", str(root / "mods"), "--disable-audio",
            "--server-settings", str(root / "server-settings.json"),
            "--start-server-load-scenario", f"{SMOKE_MOD_NAME}/runtime-smoke",
            "--until-tick", "960",
        ]
        process = subprocess.Popen(
            command, cwd=REPO_ROOT, text=True, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        marker = root / "script-output" / "administratorio-complaint-identity.txt"
        deadline = time.monotonic() + 35
        while not marker.exists() and process.poll() is None and time.monotonic() < deadline:
            time.sleep(0.05)
        if marker.exists():
            process.terminate()
        elif process.poll() is None:
            process.kill()
        output, _ = process.communicate(timeout=10)
        assert marker.exists() and marker.read_text(encoding="utf-8") == "PASS\n", (
            f"Station x={station_x}:\n" + output
        )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factorio-bin")
    args = parser.parse_args()
    if not args.factorio_bin:
        print("Skipping complaint identity smoke test; --factorio-bin was not provided.")
        return
    factorio_bin = Path(args.factorio_bin)
    for station_x in (40, 140):
        run_case(factorio_bin, station_x)
    print("Factorio complaint seeker identity smoke passed")


if __name__ == "__main__":
    main()
