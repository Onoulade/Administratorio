#!/usr/bin/env python3
"""Check nest exclusion for editor fixtures and player buildings in Factorio."""

from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
import time
from pathlib import Path

from test_factorio_runtime_smoke import REPO_ROOT, SMOKE_MOD_NAME, prepare_profile


SCENARIO_CONTROL = r'''
script.on_nth_tick(1, function(event)
  if event.tick ~= 0 then return end
  local surface = game.surfaces[1]
  local ground = {}
  for x = 196, 290 do
    for y = -5, 5 do
      ground[#ground + 1] = {name = "grass-1", position = {x, y}}
    end
  end
  surface.set_tiles(ground)
  for _, entity in pairs(surface.find_entities_filtered{area = {{196, -5}, {291, 6}}}) do
    entity.destroy()
  end

  for _, placement in ipairs({
    {name = "biter-spawner", x = 200, force = game.forces.enemy},
    {name = "spitter-spawner", x = 206, force = game.forces.enemy},
    {name = "medium-worm-turret", x = 212, force = game.forces.enemy},
    {name = "wooden-chest", x = 216, force = game.forces.enemy},
    {name = "wooden-chest", x = 220, force = game.forces.neutral},
    {name = "wooden-chest", x = 224, force = game.forces.player},
    {name = "biter-spawner", x = 230, force = game.forces.player},
    {name = "spitter-spawner", x = 236, force = game.forces.player},
    {name = "biter-spawner", x = 242, force = game.forces.neutral},
    {name = "wooden-chest", x = 246, force = game.forces.player},
    {name = "wooden-chest", x = 280, force = game.forces.player},
  }) do
    local entity = surface.create_entity{
      name = placement.name, position = {placement.x, 0},
      force = placement.force, raise_built = true,
    }
    if placement.x ~= 224 and placement.x ~= 246 and (not entity or not entity.valid) then
      error("could not create " .. placement.name .. " at " .. placement.x)
    end
  end
end)

script.on_nth_tick(2, function()
  if game.tick == 0 then return end
  local surface = game.surfaces[1]
  local function count(name, x, force)
    return surface.count_entities_filtered{
      name = name, position = {x, 0}, radius = 1, force = force,
    }
  end
  if count("biter-spawner", 200, game.forces.enemy) ~= 1 then
    error("first editor nest was removed")
  end
  if count("spitter-spawner", 206, game.forces.enemy) ~= 1 then
    error("second editor nest was removed")
  end
  if count("biter-spawner", 230, game.forces.player) ~= 1 then
    error("player-force nest near another nest was removed")
  end
  if count("spitter-spawner", 236, game.forces.player) ~= 1 then
    error("second player-force nest was removed")
  end
  if count("biter-spawner", 242, game.forces.neutral) ~= 1 then
    error("neutral nest was removed")
  end
  if count("medium-worm-turret", 212, game.forces.enemy) ~= 1 then
    error("editor worm was removed")
  end
  if count("wooden-chest", 216, game.forces.enemy) ~= 1 then
    error("enemy chest was removed")
  end
  if count("wooden-chest", 220, game.forces.neutral) ~= 1 then
    error("neutral chest was removed")
  end
  if count("wooden-chest", 224, game.forces.player) ~= 0 then
    error("player chest near a nest was not denied")
  end
  if count("wooden-chest", 246, game.forces.player) ~= 0 then
    error("player chest near the new nest was not denied")
  end
  if count("wooden-chest", 280, game.forces.player) ~= 1 then
    error("player chest away from nests was removed")
  end
  helpers.write_file("administratorio-nest-placement.txt", "PASS\n", false)
end)
'''


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factorio-bin", help="Path to the Factorio executable.")
    args = parser.parse_args()
    if not args.factorio_bin:
        print("Skipping nest placement smoke test; --factorio-bin was not provided.")
        return

    factorio_bin = Path(args.factorio_bin)
    with tempfile.TemporaryDirectory(prefix="administratorio-nest-placement-") as temp:
        root = Path(temp)
        prepare_profile(root)
        scenario = root / "mods" / SMOKE_MOD_NAME / "scenarios" / "runtime-smoke" / "control.lua"
        scenario.write_text(SCENARIO_CONTROL, encoding="utf-8")
        server_settings = json.loads(
            (factorio_bin.parent.parent / "data" / "server-settings.example.json").read_text()
        )
        server_settings["auto_pause"] = False
        server_settings["visibility"] = {"public": False, "lan": False}
        (root / "server-settings.json").write_text(json.dumps(server_settings), encoding="utf-8")
        command = [
            str(factorio_bin), "--config", str(root / "config.ini"),
            "--mod-directory", str(root / "mods"), "--disable-audio",
            "--server-settings", str(root / "server-settings.json"),
            "--start-server-load-scenario", f"{SMOKE_MOD_NAME}/runtime-smoke",
            "--until-tick", "10",
        ]
        marker = root / "script-output" / "administratorio-nest-placement.txt"
        process = subprocess.Popen(
            command, cwd=REPO_ROOT, text=True, stdout=subprocess.PIPE,
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
        assert marker.exists() and marker.read_text(encoding="utf-8") == "PASS\n", output

    print("Factorio nest placement smoke passed")


if __name__ == "__main__":
    main()
