#!/usr/bin/env python3
"""Verify native crafting/desk statistics and actual Milestones completions."""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]

PROBE = r'''
local function key(kind, name, quantity)
  return kind .. ":" .. name .. ":" .. quantity
end
local function machine(surface, force, entity_name, recipe_name, x, quality)
  local recipe = prototypes.recipe[recipe_name]
  assert(recipe, "missing recipe " .. recipe_name)
  force.recipes[recipe_name].enabled = true
  local entity = surface.create_entity{name=entity_name, position={x, 0}, force=force}
  assert(entity, "could not create " .. entity_name)
  assert(entity.set_recipe(recipe_name, quality), "could not select " .. recipe_name)
  for _, ingredient in pairs(recipe.ingredients) do
    if ingredient.type == "fluid" then
      assert(entity.insert_fluid{name=ingredient.name, amount=ingredient.amount} == ingredient.amount)
    else
      local inventory = entity.get_inventory(defines.inventory.assembling_machine_input)
      assert(inventory.insert{name=ingredient.name, count=ingredient.amount, quality=quality} == ingredient.amount)
    end
  end
  storage.machines[#storage.machines+1] = {entity=entity, recipe=recipe_name, quality=quality or "normal"}
end

script.on_init(function()
  storage.reached = {}
  storage.machines = {}
  storage.closed = {}
  local surface = game.surfaces[1]
  local force = game.forces.player
  force.set_evolution_factor(0, surface)
  surface.always_day = true
  surface.request_to_generate_chunks({100, 0}, 5)
  surface.force_generate_chunk_requests()
  local ground = {}
  for x=-20,210 do for y=-20,20 do ground[#ground+1]={name="grass-1",position={x,y}} end end
  surface.set_tiles(ground)
  for _, entity in pairs(surface.find_entities_filtered{area={{-20,-20},{210,20}}, force="neutral"}) do
    entity.destroy()
  end

  local presets = remote.call("administratorio-milestones", "milestones_presets")
  local preset_name, preset = next(presets)
  storage.preset_name = preset_name
  local names, entries = {}, {}
  local current_group
  for _, milestone in ipairs(preset.milestones) do
    assert(type(milestone.name)=="string")
    if milestone.type == "group" then
      current_group = milestone.name
    else
      assert(current_group and milestone.quantity >= 1)
      local kind = milestone.type:gsub("_consumption$", "")
      assert(prototypes[kind][milestone.name], "unknown milestone " .. milestone.name)
      assert(milestone.type ~= "kill", "bureaucratic preset should track resolutions")
      local id = key(milestone.type, milestone.name, milestone.quantity) .. ":" .. (milestone.quality or "all")
      assert(not entries[id], "duplicate milestone " .. id)
      entries[id] = true
      names[milestone.name] = true
    end
  end
  for _, name in ipairs({"solar-panel", "petroleum-gas", "administrative-science-pack",
      "worker-biter", "taxpayer-money", "ticket-landscape", "resolved-landscape",
      "pneumatic-pipe", "passenger-wagon", "rocket-silo"}) do
    assert(names[name], "missing core milestone " .. name)
  end
  if script.active_mods["space-age"] then
    assert(preset_name == "Administratorio (Space Age)")
    for _, name in ipairs({"promethium-science-pack", "blank-cyan-form", "blank-yellow-form",
        "blank-magenta-form", "chromatic-printer", "laser-printer", "ai-server", "interplanetary-terminus",
        "personnel-deployment-office", "personnel-reception-office", "small-space-tourist"}) do
      assert(names[name], "missing expansion milestone " .. name)
    end
  else
    assert(preset_name == "Administratorio")
    for _, name in ipairs({"promethium-science-pack", "ai-server", "capture-bureau", "small-space-tourist"}) do
      assert(not names[name], "base preset includes unavailable expansion goal " .. name)
    end
  end
  machine(surface, force, "assembling-machine-3", "solar-panel-regulated", 0)
  machine(surface, force, "assembling-machine-3", "admin-station-regulated", 8)
  machine(surface, force, "oil-refinery", "basic-oil-processing", 16)
  if script.active_mods.quality then
    machine(surface, force, "office-desk", "quality-module", 24, "rare")
  end
  storage.desks = {}
  for i=1,2 do
    local desk = surface.create_entity{name="admin-station", position={60+(i-1)*35,0}, force=force, raise_built=true}
    assert(desk)
    storage.desks[i] = desk
    if i == 2 then desk.get_inventory(defines.inventory.chest).insert{name="job-offer",count=50} end
    for j=1,5 do
      local citizen = surface.create_entity{name="small-biter", position={desk.position.x+(j-3)*0.8,7}, force="enemy"}
      assert(citizen)
    end
  end
end)

script.on_event(defines.events.on_tick, function(event)
  -- Finish ordinary desk visits before adding a Bureau: its active capture
  -- mode gives wildlife priority over normal walk-in administration.
  if event.tick == 1800 and script.active_mods["space-age"] then
    local surface, force = game.surfaces[1], game.forces.player
    local bureau = surface.create_entity{name="capture-bureau", position={190,0}, force=force, raise_built=true}
    assert(bureau)
    assert(bureau.insert_fluid{name="workforce-lure-spores",amount=500} > 0)
    assert(surface.create_entity{name="small-biter",position={190,7},force="enemy"})
    storage.bureau = bureau
  end
  for _, fixture in ipairs(storage.machines) do
    fixture.entity.active = true
    fixture.entity.energy = 1000000000
  end
  for _, desk in ipairs(storage.desks) do
    local inv = desk.get_inventory(defines.inventory.chest)
    -- Submit real resolved documents for whatever the visitors actually file.
    for _, stack in ipairs(inv.get_contents()) do
      if stack.name:find("^ticket%-") then
        local removed = inv.remove{name=stack.name,count=stack.count}
        local resolved = stack.name:gsub("^ticket", "resolved")
        inv.insert{name=resolved,count=removed}
        storage.closed[resolved] = (storage.closed[resolved] or 0)+removed
      end
    end
  end
  if event.tick == 3600 then
    local force, surface = game.forces.player, game.surfaces[1]
    local stats = force.get_item_production_statistics(surface)
    local fluids = force.get_fluid_production_statistics(surface)
    for _, fixture in ipairs(storage.machines) do
      assert(fixture.entity.products_finished == 1, fixture.recipe .. " did not craft exactly once")
      for _, product in pairs(prototypes.recipe[fixture.recipe].products) do
        local count = product.type == "fluid" and fluids.get_input_count(product.name)
          or stats.get_input_count{name=product.name,quality=fixture.quality}
        assert(count == product.amount, fixture.recipe .. " incorrect native production count " .. tostring(count))
      end
    end
    local tracked = remote.call("milestones-qa-inspect", "read")
    assert(tracked.preset == storage.preset_name, "Milestones selected the wrong preset")
    for _, milestone in pairs(tracked.completed) do
      storage.reached[key(milestone.type,milestone.name,milestone.quantity)] = true
    end
    for _, id in ipairs({"item:solar-panel:1", "item:admin-station:1", "fluid:petroleum-gas:1",
        "item:ticket-landscape:1", "item:taxpayer-money:1",
        "item:worker-biter:1", "item_consumption:resolved-landscape:1"}) do
      assert(storage.reached[id], "Milestones did not complete " .. id .. "; reached=" .. helpers.table_to_json(storage.reached)
        .. "; closed=" .. helpers.table_to_json(storage.closed) .. "; tickets=" .. stats.get_input_count("ticket-landscape"))
    end
    if script.active_mods.quality then
      assert(storage.reached["item:quality-module:1"], "rare certification craft was not completed")
    end
    for name, count in pairs(storage.closed) do
      assert(stats.get_output_count(name) == count, "desk consumption missing/doubled: " .. name)
    end
    assert(stats.get_output_count("job-offer") > 0, "offers not consumed in native statistics")
    if storage.bureau then
      assert(stats.get_input_count("worker-biter") == storage.bureau.get_inventory(defines.inventory.assembling_machine_output).get_item_count("worker-biter"),
        "capture output missing/doubled")
    end
    helpers.write_file("milestones-qa.json", helpers.table_to_json{
      preset=storage.preset_name, reached=storage.reached, closed=storage.closed,
    }, false)
  end
end)
'''


def run_case(factorio: str, archive: Path, *, space_age: bool, quality: bool, flib: Path | None) -> None:
    with tempfile.TemporaryDirectory(prefix="administratorio-milestones-") as temp:
        root = Path(temp)
        mods = root / "mods"
        mods.mkdir()
        (mods / "administratorio").symlink_to(REPO_ROOT, target_is_directory=True)
        # Benchmark saves have no players. Let the unchanged Milestones
        # tracker initialize the player force in this disposable test copy.
        # Production counts, presets and notifications remain upstream code.
        with zipfile.ZipFile(archive) as zipped:
            zipped.extractall(mods)
        milestone_root = next(path.parent for path in mods.glob("*/info.json")
                              if not path.parent.is_symlink() and json.loads(path.read_text())["name"] == "Milestones")
        info = json.loads((milestone_root / "info.json").read_text())
        target = mods / f"Milestones_{info['version']}"
        if milestone_root != target:
            milestone_root.rename(target)
            milestone_root = target
        if flib:
            shutil.copy2(flib, mods / flib.name)
        initializer = milestone_root / "scripts/storage_init.lua"
        code = initializer.read_text()
        guard = "storage.forces[force.name] == nil and next(force.players) ~= nil"
        assert guard in code, "upstream force initialization changed"
        initializer.write_text(code.replace(guard, 'storage.forces[force.name] == nil and force.name == "player"', 1))
        controller = milestone_root / "control.lua"
        controller.write_text(controller.read_text() + '\nremote.add_interface("milestones-qa-inspect", {read=function() return {preset=storage.current_preset_name, completed=storage.forces.player.complete_milestones} end})\n')
        probe = mods / "milestones-qa"
        probe.mkdir()
        (probe / "info.json").write_text(json.dumps({
            "name": "milestones-qa", "version": "1.0.0", "title": "Milestones QA", "author": "QA",
            "factorio_version": "2.0", "dependencies": ["administratorio", "Milestones"],
        }))
        (probe / "data-final-fixes.lua").write_text("""
local count = 0
for name, recipe in pairs(data.raw.recipe) do
  if name:find("%-regulated$") then
    assert(recipe.hide_from_stats == false, "regulated recipe hides production: " .. name)
    count = count + 1
  end
end
assert(count > 100, "regulated recipes were not generated")
""")
        (probe / "control.lua").write_text(PROBE)
        enabled = {"base": True, "administratorio": True, "Milestones": True, "milestones-qa": True,
                   "space-age": space_age, "quality": quality, "elevated-rails": space_age}
        if flib:
            enabled["flib"] = True
        (mods / "mod-list.json").write_text(json.dumps({"mods": [
            {"name": name, "enabled": value} for name, value in enabled.items()
        ]}))
        (root / "config.ini").write_text(f"[path]\nread-data=__PATH__system-read-data__\nwrite-data={root}\n")
        (root / "map-gen.json").write_text(json.dumps({"seed": 12345, "water": 0,
            "autoplace_controls": {name: {"frequency": 0, "size": 0} for name in ("enemy-base", "trees")}}))
        common = [factorio, "--config", str(root / "config.ini"), "--mod-directory", str(mods), "--disable-audio"]
        for args in (["--create", str(root / "fixture.zip"), "--map-gen-settings", str(root / "map-gen.json")],
                     ["--benchmark", str(root / "fixture.zip"), "--benchmark-ticks", "3601", "--benchmark-runs", "1"]):
            result = subprocess.run(common + args, text=True, capture_output=True, timeout=120)
            assert result.returncode == 0, (result.stdout + result.stderr)[-14000:]
        marker = root / "script-output" / "milestones-qa.json"
        assert marker.exists(), "Milestones runtime assertions did not finish"
        report = json.loads(marker.read_text())
        print(f"PASS {report['preset']}, quality={quality}: {len(report['reached'])} actual completed milestones")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factorio-bin", required=True)
    parser.add_argument("--milestones-mod", type=Path, default=REPO_ROOT.parent / "Milestones_1.5.2.zip")
    parser.add_argument("--flib-mod", type=Path, help="Optional flib ZIP for older Milestones releases")
    args = parser.parse_args()
    if not args.milestones_mod.is_file():
        print("SKIP Milestones engine test: supply --milestones-mod ZIP to enable it")
        return
    with zipfile.ZipFile(args.milestones_mod) as archive:
        manifest = next(name for name in archive.namelist() if name.count("/") == 1 and name.endswith("/info.json"))
        milestones_version = json.loads(archive.read(manifest))["factorio_version"]
    engine_version = subprocess.check_output([args.factorio_bin, "--version"], text=True).split()[1]
    engine_series = ".".join(engine_version.split(".")[:2])
    admin_series = json.loads((REPO_ROOT / "info.json").read_text())["factorio_version"]
    if milestones_version != engine_series or admin_series != engine_series:
        print(f"SKIP incompatible engine versions: Factorio={engine_series}, "
              f"Milestones={milestones_version}, Administratorio={admin_series}; supply a compatible --milestones-mod ZIP")
        return
    for space_age, quality in ((False, False), (False, True), (True, True)):
        run_case(args.factorio_bin, args.milestones_mod, space_age=space_age, quality=quality,
                 flib=args.flib_mod)


if __name__ == "__main__":
    main()
