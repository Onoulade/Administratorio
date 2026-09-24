#!/usr/bin/env python3
"""Check ore patch placement in the real Factorio engine."""

from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
import time
from pathlib import Path

from test_factorio_runtime_smoke import REPO_ROOT, SMOKE_MOD_NAME, prepare_profile


SCENARIO_CONTROL = r'''
script.on_init(function()
  local surface = game.surfaces[1]
  local force = game.forces.player
  for _, entity in pairs(surface.find_entities_filtered{area = {{96, -4}, {132, 4}}}) do
    entity.destroy()
  end
  local ground = {}
  for x = 96, 131 do
    for y = -4, 3 do
      ground[#ground + 1] = {name = "grass-1", position = {x, y}}
    end
  end
  surface.set_tiles(ground)

  for _, placement in ipairs({
    {name = "electric-mining-drill", x = 100, ore = "iron-ore"},
    {name = "transport-belt", x = 104, ore = "coal"},
    {name = "wooden-chest", x = 108, ore = "copper-ore"},
    {name = "boarding-platform", x = 112},
    {name = "deboarding-platform", x = 116},
    {name = "boarding-platform-placement-preview", x = 120},
    {name = "deboarding-platform-placement-preview", x = 124},
    {name = "burner-mining-drill", x = 128, ore = "bullshit-ore"},
  }) do
    local ore = surface.create_entity{
      name = placement.ore or "iron-ore", position = {placement.x, 0}, amount = 1000,
    }
    if not ore then error("could not create ore for " .. placement.name) end
    if not surface.can_place_entity{
      name = placement.name, position = {placement.x, 0}, force = force,
    } then
      error(placement.name .. " cannot be placed over ore")
    end
  end
  helpers.write_file("administratorio-ore-placement.txt", "PASS\n", false)
end)
'''


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factorio-bin", help="Path to the Factorio executable.")
    args = parser.parse_args()
    if not args.factorio_bin:
        print("Skipping ore placement smoke test; --factorio-bin was not provided.")
        return

    factorio_bin = Path(args.factorio_bin)
    with tempfile.TemporaryDirectory(prefix="administratorio-ore-placement-") as temp:
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
        marker = root / "script-output" / "administratorio-ore-placement.txt"
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

    print("Factorio ore placement smoke passed")


if __name__ == "__main__":
    main()
