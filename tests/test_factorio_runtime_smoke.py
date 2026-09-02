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

  regular_stop.trains_limit = 7
  public_stop.trains_limit = 7
  script.raise_script_built{entity = regular_stop}
  script.raise_script_built{entity = public_stop}
end)

script.on_nth_tick(30, function()
  local surface = game.surfaces[1]
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

  helpers.write_file("administratorio-runtime-smoke.txt", "PASS\n", false)
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
            "60",
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
