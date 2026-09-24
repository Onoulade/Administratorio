#!/usr/bin/env python3
"""Check Biterport inbox capacity, network links, delivery, and construction in Factorio."""

from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
import time
from pathlib import Path

from test_factorio_runtime_smoke import REPO_ROOT, SMOKE_MOD_NAME, prepare_profile


SCENARIO_CONTROL = r'''
local port
local peer
local provider
local requester

local function fail(message)
  error("Administratorio Biterport smoke failure: " .. message)
end

script.on_init(function()
  local surface = game.surfaces[1]
  local force = game.forces.player
  surface.request_to_generate_chunks({200, 200}, 4)
  surface.force_generate_chunk_requests()

  local tiles = {}
  for x = 190, 250 do
    for y = 190, 250 do
      tiles[#tiles + 1] = {name = "grass-1", position = {x, y}}
    end
  end
  surface.set_tiles(tiles)
  for _, entity in ipairs(surface.find_entities_filtered{
    area = {{190, 190}, {251, 251}}, type = {"tree", "simple-entity", "resource"},
  }) do entity.destroy() end

  port = surface.create_entity{name = "biterport", position = {200, 200}, force = force}
  peer = surface.create_entity{name = "biterport", position = {240, 240}, force = force}
  provider = surface.create_entity{name = "paperwork-provider-chest", position = {203, 200}, force = force}
  requester = surface.create_entity{name = "paperwork-requester-chest", position = {206, 200}, force = force}
  if not port or not peer or not provider or not requester then fail("could not create test fixtures") end
  script.raise_script_built{entity = port}
  script.raise_script_built{entity = peer}
  port.insert{name = "biter-logistics-formation", count = 1}
  port.insert{name = "taxpayer-money", count = 1}
  provider.insert{name = "iron-plate", count = 5}

  local point = requester.get_requester_point()
  local section = point.get_section(1) or point.add_section()
  if not section then fail("requester has no writable logistic section") end
  section.set_slot(1, {value = {type = "item", name = "iron-plate", quality = "normal"}, min = 5})
  local inbox = requester.get_inventory(defines.inventory.chest)
  for index = 1, #inbox do inbox[index].set_stack{name = "stone", count = 50} end
  if inbox.can_insert{name = "iron-plate", count = 1} then fail("requester fixture is not full") end
end)

script.on_nth_tick(30, function()
  local surface = game.surfaces[1]
  if game.tick == 30 then
    if port.get_item_count("taxpayer-money") ~= 1 then fail("full inbox caused a dispatch") end
    local hidden = surface.find_entities_filtered{
      name = "biterport-hidden-roboport", area = {{195, 195}, {245, 245}},
    }
    if #hidden ~= 2 then fail("ports did not create two hidden coverage previews") end
    if hidden[1].logistic_network.network_id ~= hidden[2].logistic_network.network_id then
      fail("diagonally touching orange squares did not connect")
    end
  elseif game.tick == 90 then
    requester.get_inventory(defines.inventory.chest)[1].clear()
  elseif game.tick == 450 then
    if port.get_item_count("taxpayer-money") ~= 0 then fail("open inbox did not dispatch") end
    if requester.get_item_count("iron-plate") < 1 then fail("worker did not deliver") end
    local filters = requester.get_requester_point().filters
    if not filters or not filters[1] or filters[1].count ~= 5 then
      fail("delivery did not restore the request filter")
    end
    if port.get_item_count("biter-logistics-formation") ~= 1 then
      fail("delivery worker did not return")
    end

    requester.get_requester_point().get_section(1).set_slot(1,
      {value = {type = "item", name = "iron-plate", quality = "normal"}, min = 0})
    port.insert{name = "taxpayer-money", count = 1}
    provider.get_inventory(defines.inventory.chest).clear()
    if provider.insert{name = "transport-belt", count = 1} ~= 1 then
      fail("could not stock the construction material")
    end
    local ghost = surface.create_entity{
      name = "entity-ghost", inner_name = "transport-belt",
      position = {210, 200}, force = game.forces.player,
    }
    if not ghost then fail("could not create the construction ghost") end
    script.raise_script_built{entity = ghost}
  elseif game.tick == 900 then
    local belts = surface.find_entities_filtered{name = "transport-belt", position = {210, 200}, radius = 1.5}
    if #belts ~= 1 then fail("worker did not complete construction") end
    if port.get_item_count("biter-logistics-formation") ~= 1 then
      fail("construction worker did not return")
    end
    helpers.write_file("administratorio-biterport-smoke.txt", "PASS\n", false)
  end
end)
'''


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factorio-bin", help="Path to the Factorio executable.")
    args = parser.parse_args()
    if not args.factorio_bin:
        print("Skipping Factorio Biterport smoke; --factorio-bin was not provided.")
        return

    factorio_bin = Path(args.factorio_bin)
    if not factorio_bin.exists():
        raise FileNotFoundError(factorio_bin)

    with tempfile.TemporaryDirectory(prefix="administratorio-biterport-smoke-") as temp:
        root = Path(temp)
        prepare_profile(root)
        scenario = root / "mods" / SMOKE_MOD_NAME / "scenarios" / "runtime-smoke" / "control.lua"
        scenario.write_text(SCENARIO_CONTROL, encoding="utf-8")
        server_settings_source = factorio_bin.parent.parent / "data" / "server-settings.example.json"
        server_settings = json.loads(server_settings_source.read_text(encoding="utf-8"))
        server_settings["auto_pause"] = False
        (root / "server-settings.json").write_text(
            json.dumps(server_settings, indent=2) + "\n", encoding="utf-8"
        )
        command = [
            str(factorio_bin), "--config", str(root / "config.ini"),
            "--mod-directory", str(root / "mods"), "--disable-audio",
            "--server-settings", str(root / "server-settings.json"),
            "--start-server-load-scenario", f"{SMOKE_MOD_NAME}/runtime-smoke",
            "--until-tick", "960",
        ]
        marker = root / "script-output" / "administratorio-biterport-smoke.txt"
        process = subprocess.Popen(
            command, cwd=REPO_ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT
        )
        deadline = time.monotonic() + 30
        while not marker.exists() and process.poll() is None and time.monotonic() < deadline:
            time.sleep(0.05)
        if marker.exists():
            process.terminate()
        elif process.poll() is None:
            process.kill()
        output, _ = process.communicate(timeout=10)
        assert marker.exists(), "Factorio Biterport smoke failed or timed out:\n" + output
        assert marker.read_text(encoding="utf-8") == "PASS\n"
    print("Factorio Biterport lifecycle smoke passed")


if __name__ == "__main__":
    main()
