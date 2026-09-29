#!/usr/bin/env python3
"""Real-engine personnel lanes: automatic pavement, continuous walking, queues and recovery."""
from __future__ import annotations
import argparse
import json
import subprocess
import tempfile
import time
from pathlib import Path
from test_factorio_runtime_smoke import REPO_ROOT, SMOKE_MOD_NAME, prepare_profile

SCENARIO_CONTROL = r'''
local briefings = require("__administratorio__.prototypes.shared.manager_briefings").BRIEFINGS
local couriers = require("__administratorio__.prototypes.shared.manager_couriers").COURIERS
local input, sign, output
local roads = {}
local surface
local function check(value, message)
  if not value then error("Personnel routing smoke: " .. message) end
end
local function build(name, x, y, direction)
  -- Preserve the existing fixture's exact integer centers as a legacy lane.
  local entity = surface.create_entity{name = name, position = {x, y}, force = game.forces.player, direction = direction, snap_to_grid = false}
  check(entity, "could not create " .. name)
  script.raise_script_built{entity = entity}
  check(entity.valid, "placement rejected: " .. name)
  return entity
end
local function proxies(target)
  local units = {}
  for _, entity in ipairs((target or surface).find_entities_filtered{type = "unit", force = game.forces.player}) do
    if entity.name:find("^personnel%-in%-transit%-") then units[#units + 1] = entity end
  end
  return units
end
local function source() return input.get_inventory(defines.inventory.furnace_source) end
local function arrival() return output.get_inventory(defines.inventory.furnace_result) end
local function conservation(expected)
  local count = source().get_item_count{name="worker-biter",quality="rare"} + arrival().get_item_count{name="worker-biter",quality="rare"} + storage.fixture.buffer.get_item_count{name="worker-biter",quality="rare"} + #proxies()
  for _, chest in ipairs(surface.find_entities_filtered{name = "personnel-recovery-crate"}) do count = count + chest.get_item_count{name="worker-biter",quality="rare"} end
  check(count == expected, "accessible items + walking personnel changed: " .. count .. "/" .. expected)
end
local function no_worker_jobs()
  for _,job in ipairs(remote.call("administratorio-personnel-routing","inspect")) do
    if job.item=="worker-biter" and job.surface_index==storage.fixture.aux_index then return false end
  end
  return true
end
local function verify_grid()
  -- Native 2x2 buildings have odd integer centers. Verify both snapping and
  -- the grid value against rails across negative positions and rotations.
  local grid = game.create_surface("personnel-grid-fixture")
  grid.request_to_generate_chunks({0,0}, 2)
  grid.force_generate_chunk_requests()
  local grid_tiles = {}
  for x=-24,24 do for y=-24,24 do grid_tiles[#grid_tiles+1]={name="grass-1",position={x,y}} end end
  grid.set_tiles(grid_tiles)
  for _,entity in ipairs(grid.find_entities()) do entity.destroy() end
  for row,name in ipairs({"personnel-deployment-office","personnel-reception-office","personnel-routing-sign"}) do
    for column,direction in ipairs({defines.direction.north,defines.direction.east,defines.direction.south,defines.direction.west}) do
      local p={x=-24+column*6,y=-24+row*6}
      grid.create_entity{name=name,position=p,direction=direction,force=game.forces.player}
      local built=grid.find_entities_filtered{name=name,position=p,radius=2}
      check(#built==1, "native grid placement failed: " .. name .. " " .. serpent.line(p))
      check(built[1].prototype.building_grid_bit_shift==prototypes.entity["straight-rail"].building_grid_bit_shift, "native placement grid differs from rails: " .. name .. " grid=" .. built[1].prototype.building_grid_bit_shift)
      check(built[1].position.x%2==1 and built[1].position.y%2==1, "native 2x2 building centers did not snap: " .. name .. " " .. serpent.line(built[1].position))
      script.raise_script_built{entity=built[1]}
      check(built[1].valid, "aligned placement was rejected: " .. name)
      if name=="personnel-reception-office" then
        check(not built[1].rotatable and not built[1].rotate{},"reception office rotates")
        check(built[1].direction==defines.direction.north,"reception retained a directional orientation")
      end
    end
  end
  local forced=grid.create_entity{name="personnel-routing-sign",position={13.25,13.25},force=game.forces.player,snap_to_grid=false}
  script.raise_script_built{entity=forced}
  check(not forced.valid and grid.get_tile(13,13).name=="grass-1", "forced off-grid path was accepted")
  local function native_build(name,x)
    local entity=grid.create_entity{name=name,position={x,12},direction=defines.direction.east,force=game.forces.player}
    script.raise_script_built{entity=entity}
    check(entity and entity.valid, "native-grid route placement rejected")
    return entity
  end
  local departure=native_build("personnel-deployment-office",12)
  local reception=native_build("personnel-reception-office",16)
  check(departure.get_inventory(defines.inventory.furnace_source).insert{name="worker-biter",count=1,quality="epic"}==1,"native-grid source rejected personnel")
  storage.fixture.grid={surface=grid,output=reception}
end
script.on_init(function()
  game.speed = 10
  surface = game.surfaces[1]
  surface.request_to_generate_chunks({204, 204}, 3)
  surface.force_generate_chunk_requests()
  local tiles = {}
  for x = 185, 235 do for y = 185, 230 do tiles[#tiles + 1] = {name = "grass-1", position = {x, y}} end end
  surface.set_tiles(tiles)
  for _, e in ipairs(surface.find_entities_filtered{area = {{185,185},{236,231}}, type = {"tree","simple-entity","resource","unit","unit-spawner","cliff"}}) do e.destroy() end
  for _, e in ipairs(surface.find_entities_filtered{type="unit-spawner"}) do e.destroy() end
  game.forces.player.technologies["personnel-routing"].researched = true
  -- Keep existing timing regressions at their original walking speed.
  game.forces.player.technologies["personnel-routing-speed-1"].researched = true
  input = build("personnel-deployment-office", 200,200, defines.direction.east)
  sign = build("personnel-routing-sign", 208,200, defines.direction.south)
  output = build("personnel-reception-office", 208,208)
  check(input.direction == defines.direction.east and input.rotatable, "deployment office cannot point east/rotate")
  check(sign.direction == defines.direction.south and sign.rotatable, "sign cannot point south/rotate")
  check(source().insert{name = "worker-biter", count = 1, quality = "rare"} == 1, "could not stock source")
  local buffer=game.create_inventory(4)
  check(buffer.insert{name="worker-biter",count=4,quality="rare"}==4,"could not stock feeder buffer")
  storage.fixture = {input=input,sign=sign,output=output,roads=roads,surface=surface,buffer=buffer}
end)
script.on_load(function()
  local f=storage.fixture
  input,sign,output,roads,surface=f.input,f.sign,f.output,f.roads,f.surface
end)
local function cargo_lifecycle(tick)
  if tick == 4 then
    local main = surface
    surface = game.create_surface("personnel-cargo-lifecycle", {autoplace_controls={}})
    surface.request_to_generate_chunks({24,36}, 3); surface.force_generate_chunk_requests()
    for _, entity in ipairs(surface.find_entities()) do entity.destroy() end
    local tiles={}
    for x=-4,52 do for y=-4,76 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
    surface.set_tiles(tiles)
    local items={"small-space-tourist", "medium-space-tourist", "big-space-tourist", "behemoth-space-tourist"}
    for _, briefing in ipairs(briefings) do
      items[#items+1]=briefing.item
    end
    for _, courier in ipairs(couriers) do
      items[#items+1]=courier.item
    end
    local fixture={surface=surface, lanes={}}
    for i,item in ipairs(items) do
      local departure=build("personnel-deployment-office",0,(i-1)*6,defines.direction.east)
      local reception=build("personnel-reception-office",48,(i-1)*6)
      local inv=departure.get_inventory(defines.inventory.furnace_source)
      check(inv.insert{name=item,count=1,quality="rare"}==1,"cargo source rejected " .. item)
      if i>4 then inv[1].spoil_tick=tick+100 end
      fixture.lanes[i]={item=item,output=reception}
    end
    local fresh_departure=build("personnel-deployment-office",0,72,defines.direction.east)
    fixture.fresh_output=build("personnel-reception-office",4,72)
    local fresh=fresh_departure.get_inventory(defines.inventory.furnace_source)
    fresh.insert{name=briefings[1].item,count=1,quality="rare"}
    fresh[1].spoil_tick=tick+200
    storage.fixture.cargo_lifecycle=fixture
    surface=main
  elseif tick==160 or tick==220 then
    local fixture=storage.fixture.cargo_lifecycle
    local fresh=fixture.fresh_output.get_inventory(defines.inventory.furnace_result)[1]
    check(fresh.valid_for_read and fresh.quality.name=="rare","short trip lost manager/quality")
    if tick==160 then
      check(fresh.name==briefings[1].item and fresh.spoil_tick>=210 and fresh.spoil_tick<=220,
        "short trip failed to retain half-aged freshness")
    else
      check(fresh.name=="middle-management-managing-manager","spoilage stayed slowed after reception")
    end
    local count=0
    for _,job in ipairs(remote.call("administratorio-personnel-routing","inspect")) do
      if job.surface_index==fixture.surface.index then
        count=count+1
        local lane=fixture.lanes[math.floor(job.position.y/6+0.5)+1]
        check(job.position.x>0 and job.position.x<48,"cargo did not keep walking")
        if not lane.item:find("space-tourist",1,true) then
          if tick==160 then
            check(job.item==lane.item,"manager expired at full speed: " .. lane.item)
            check(job.spoil_tick-tick>=20 and job.spoil_tick-tick<=50,"manager did not age at half speed")
            lane.job_id=job.id
          else
            check(job.item=="middle-management-managing-manager","manager did not expire on path")
            check(job.id==lane.job_id,"expiry replaced the journey")
            check(job.unit_name=="personnel-in-transit-middle-management-managing-manager","expired proxy kept its old role")
            check(not job.briefing,"expired manager kept its briefing badge")
          end
        end
      end
    end
    check(count==12,"tourist/manager journey lost or dispatched late: " .. count)
    check(#fixture.surface.find_entities_filtered{type="unit"}==12,"expiry spawned a loose biter")
  elseif tick==800 then
    local fixture=storage.fixture.cargo_lifecycle
    check(#proxies(fixture.surface)==0,"cargo did not reach reception")
    for i,lane in ipairs(fixture.lanes) do
      local expected=i<=4 and lane.item or "middle-management-managing-manager"
      check(lane.output.get_inventory(defines.inventory.furnace_result).get_item_count{name=expected,quality="rare"}==1,
        "tourist/expired manager lost cargo or quality: " .. lane.item)
    end
  end
end
local saw_walk, saw_turn = false, false
script.on_nth_tick(4, function()
  cargo_lifecycle(game.tick)
  if game.tick<2400 and not source()[1].valid_for_read then
    local stack=storage.fixture.buffer.find_item_stack{name="worker-biter",quality="rare"}
    if stack and source().insert(stack)==1 then stack.clear() end
  end
  if storage.fixture.pending then
    local pending=storage.fixture.pending
    local inv=pending.input.get_inventory(defines.inventory.furnace_source)
    if not inv[1].valid_for_read then
      local stack=pending.buffer.find_item_stack{name="worker-biter",quality="epic"}
      if stack and inv.insert(stack)==1 then stack.clear() end
    end
    local count=inv.get_item_count{name="worker-biter",quality="epic"}+pending.buffer.get_item_count{name="worker-biter",quality="epic"}+#proxies(pending.surface)
    if pending.output then count=count+pending.output.get_inventory(defines.inventory.furnace_result).get_item_count{name="worker-biter",quality="epic"} end
    check(count==8,"incomplete route lost personnel")
    local units=proxies(pending.surface)
    for i,a in ipairs(units) do for j=i+1,#units do
      local p,q=a.position,units[j].position
      check(math.abs(p.x-q.x)>=2-1/256 or math.abs(p.y-q.y)>=2-1/256,"dense incomplete queue overlaps")
    end end
    if game.tick==12 then
      pending.obstruction=pending.surface.create_entity{name="steel-chest",position={6,0},force=game.forces.player}
      check(pending.obstruction,"could not force obstruction fixture")
    elseif game.tick==240 then
      check(#units>=2,"blocked lane never admitted its local traffic")
      for _,unit in ipairs(units) do check(unit.position.x<5,"unit crossed a newly obstructed block") end
      check(#pending.surface.find_entities_filtered{name="personnel-recovery-crate"}==0,"ordinary blockage recovered instead of waiting")
    elseif game.tick==320 then pending.obstruction.destroy()
    elseif game.tick==1160 then
      check(#units>=4,"no reception: biters did not fill the reachable lane")
      local positions={}
      for _,unit in ipairs(units) do positions[#positions+1]=unit.position.x end
      table.sort(positions)
      check(math.abs(positions[#positions]-9.5)<0.02,"leader did not stop before the terminal sign tile")
      for _,unit in ipairs(units) do check(unit.position.x+1<11,"waiting body entered terminal sign tile") end
      for i=2,#positions do check(positions[i]-positions[i-1]<2.8,"queue still has spare-block gaps") end
      check(not pending.sign.minable and pending.sign.rotatable,"stopped terminal sign cannot be redirected safely")
      local player=game.players[1]
      check(pending.sign.rotate{reverse=true,by_player=player},"safe terminal rotation failed")
      check(pending.sign.direction==defines.direction.east,"safe terminal rotation was reverted")
      check(#pending.surface.find_entities_filtered{name="personnel-recovery-crate"}==0,"long queue waiting triggered recovery")
    elseif game.tick==1200 then
      local main=surface;surface=pending.surface
      build("personnel-routing-sign",18,0,defines.direction.south)
      pending.output=build("personnel-reception-office",18,12)
      surface=main
    elseif game.tick==2200 then
      check(#units==0 and pending.output.get_inventory(defines.inventory.furnace_result).get_item_count{name="worker-biter",quality="epic"}==8,"extended route did not resume and deliver its queue")
      check(pending.sign.minable and pending.sign.rotatable,"segment locks leaked after draining")
    end
  end
  if storage.fixture.folded then
    local folded=storage.fixture.folded
    local inv=folded.input.get_inventory(defines.inventory.furnace_source)
    if not inv[1].valid_for_read and folded.spare[1].valid_for_read and inv.insert(folded.spare[1])==1 then folded.spare[1].clear() end
  end
  if game.tick == 4 then
    local main=surface
    surface=game.create_surface("personnel-incomplete-smoke",{autoplace_controls={}})
    surface.request_to_generate_chunks({12,6},2);surface.force_generate_chunk_requests()
    for _,entity in ipairs(surface.find_entities()) do entity.destroy() end
    local tiles={}
    for x=-4,30 do for y=-4,18 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
    surface.set_tiles(tiles)
    local departure=build("personnel-deployment-office",0,0,defines.direction.east)
    local terminal=build("personnel-routing-sign",12,0,defines.direction.south)
    departure.get_inventory(defines.inventory.furnace_source).insert{name="worker-biter",count=1,quality="epic"}
    local buffer=game.create_inventory(7);buffer.insert{name="worker-biter",count=7,quality="epic"}
    storage.fixture.pending={surface=surface,input=departure,sign=terminal,buffer=buffer}
    surface=main
    verify_grid()
    check(prototypes.item["personnel-path"].hidden and not prototypes.item["personnel-path"].place_result, "pavement still placeable")
    check(not game.forces.player.recipes["personnel-path"].enabled, "pavement still craftable")
    for i = 1,#arrival() do check(arrival()[i].set_stack{name = "worker-biter", count = 1}, "could not fill output slot " .. i) end
    check(not arrival().can_insert{name="worker-biter",count=1,quality="rare"}, "output fixture is not full: slots=" .. #arrival() .. " " .. serpent.line(arrival().get_contents()))
  for index, name in ipairs({"transport-belt","inserter","small-electric-pole"}) do
    check(surface.can_place_entity{name=name,position={202.5+index,199.5},force=game.forces.player}, name .. " blocked on path; tile=" .. surface.get_tile(203,199).name)
    build(name,202.5+index,199.5)
  end
  for _, name in ipairs({"steel-chest","assembling-machine-1","stone-wall","pipe","straight-rail","car"}) do
    check(not surface.can_place_entity{name=name,position={205,200},force=game.forces.player}, name .. " buildable on protected path")
  end
  check(not surface.can_place_entity{name="personnel-in-transit-worker-biter",position={210,200},force=game.forces.player}, "unit can leave pavement")
  check(surface.can_place_entity{name="personnel-in-transit-worker-biter",position={204,200},force=game.forces.player}, "unit cannot occupy path center")
  local tree=surface.create_entity{name="tree-01",position={230,200}}
  local obstructed=surface.create_entity{name="personnel-routing-sign",position={230,200},force=game.forces.player}
  script.raise_script_built{entity=obstructed}
  check(not obstructed.valid and surface.get_tile(230,200).name=="grass-1", "path paved over a solid obstacle")
  tree.destroy()
  end
  local units = proxies()
  for i, a in ipairs(units) do
    check(not a.minable and not a.destructible, "walking cargo can be removed/damaged")
    local p = a.position
    if p.x > 200.5 then saw_walk = true end
    if p.y > 201 then saw_turn = true end
    for j = i+1,#units do
      local q = units[j].position
      check(math.abs(p.x-q.x) >= 2-1/256 or math.abs(p.y-q.y) >= 2-1/256, "walking 2x2 footprints overlap")
    end
  end
  if game.tick <= 2400 then conservation(5) end
  if game.tick==40 then
    local entering=false
    for _,unit in ipairs(units) do
      if unit.position.x>205.5 and unit.position.x<208 and math.abs(unit.position.y-200)<0.3 then entering=true end
    end
    check(entering and sign.rotatable,"sign cannot rotate during entry")
    game.server_save("personnel-mid-sign-entry")
  end
  if game.tick == 120 then
    check(#units > 0, "no native unit dispatched")
    check(not sign.minable and sign.rotatable, "reserved sign cannot rotate or lost mining protection")
    check(surface.get_tile(203,199).name=="personnel-path-concrete", "automatic pavement missing")
  elseif game.tick == 480 then
    local grid=storage.fixture.grid
    check(grid.output.get_inventory(defines.inventory.furnace_result).get_item_count{name="worker-biter",quality="epic"}==1,"native-grid route did not deliver personnel")
    check(#proxies(grid.surface)==0,"native-grid route did not drain")
    game.delete_surface(grid.surface)
  elseif game.tick == 840 then
    game.server_save("personnel-mid-queue")
  elseif game.tick == 900 then
    check(saw_walk and saw_turn, "native pathfinding never walked and turned: " .. serpent.line(remote.call("administratorio-personnel-routing","inspect")))
    check(#units >= 2, "full reception lost/stalled cargo: output=" .. serpent.line(arrival().get_contents()) .. " source=" .. serpent.line(source().get_contents()) .. " units=" .. #units .. " " .. serpent.line(remote.call("administratorio-personnel-routing","inspect")))
    check(arrival().get_item_count{name="worker-biter",quality="rare"} == 0, "full output accepted cargo")
    arrival().clear()
  elseif game.tick == 2400 then
    check(#units == 0, "queue failed to drain")
    check(arrival().get_item_count{name="worker-biter",quality="rare"} == 5, "quality/item identity lost")
    check(sign.minable and sign.rotatable, "route locks leaked after arrival")
    arrival().clear()
    source().insert{name="worker-biter",count=1}
  elseif game.tick == 2440 then
    check(#units == 1, "trained biter did not dispatch")
    -- Delete during entry, while the biter still depends on this junction.
    -- No raised event: register_on_object_destroyed must recover the cargo.
    sign.destroy()
  elseif game.tick == 2520 then
    check(#units == 0 and source().get_item_count("worker-biter") == 1, "forced sign deletion lost personnel")
    check(input.minable, "recovery left route locked")
    check(surface.get_tile(203,199).name=="grass-1", "removed sign left orphan automatic pavement")
    -- Broken route must retain its input item, rather than spawning an orphan.
  elseif game.tick == 2640 then
    check(#units == 0 and source().get_item_count("worker-biter") == 1, "gap dispatched an orphan")
    sign = build("personnel-routing-sign",208,200,defines.direction.south)
  elseif game.tick == 2652 then
    check(#units == 1, "repaired route did not restart")
    input.destroy()
  elseif game.tick == 2820 then
    log("Personnel smoke: roster and inserters")
    local recovered = 0
    for _, crate in ipairs(surface.find_entities_filtered{name="personnel-recovery-crate"}) do recovered=recovered+crate.get_item_count("worker-biter") end
    check(#units == 0 and recovered == 1, "origin deletion did not recover to crate")
    local main = surface
    surface = game.create_surface("personnel-roster-smoke", {autoplace_controls={}})
    surface.request_to_generate_chunks({0,70},4)
    surface.force_generate_chunk_requests()
    for _, e in ipairs(surface.find_entities()) do if e.type ~= "character" then e.destroy() end end
    local tiles={}
    for x=-8,12 do for y=-6,168 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
    surface.set_tiles(tiles)
    local names={}
    for name in pairs(prototypes.entity) do
      local item=name:match("^personnel%-in%-transit%-(.+)$")
      if item then names[#names+1]=item end
    end
    table.sort(names)
    check(#names==27, "personnel roster changed; update coverage: " .. #names)
    check(not prototypes.entity["personnel-in-transit-rideable-biter"], "mount admitted into personnel roster")
    check(not prototypes.entity["personnel-in-transit-hired-biter-capsule"] and not prototypes.recipe["personnel-routing-load-hired-biter-capsule"], "Field Agent admitted into personnel roster")
    storage.fixture.roster={}
    storage.fixture.aux=surface
    storage.fixture.aux_index=surface.index
    for index,name in ipairs(names) do
      local y=(index-1)*6
      local departure=build("personnel-deployment-office",0,y,defines.direction.east)
      local reception=build("personnel-reception-office",4,y)
      check(departure.get_inventory(defines.inventory.furnace_source).insert{name=name,count=1,quality="epic"}==1, "source rejected " .. name)
      local stack=departure.get_inventory(defines.inventory.furnace_source)[1]
      stack.health=0.75
      if stack.spoil_tick>0 then stack.spoil_percent=0.25 end
      for i=1,8 do reception.get_inventory(defines.inventory.furnace_result)[i].set_stack{name="worker-biter",count=1,quality="rare"} end
      storage.fixture.roster[index]={name=name,input=departure,output=reception}
    end
    surface=main
    local departure=build("personnel-deployment-office",200,220,defines.direction.east)
    local reception=build("personnel-reception-office",206,220)
    local supply=build("steel-chest",197.5,220.5)
    local result=build("steel-chest",208.5,220.5)
    local arms={}
    for _,x in ipairs({198.5,207.5}) do
      local arm=build("burner-inserter",x,220.5,defines.direction.west)
      arm.get_fuel_inventory().insert{name="coal",count=5}
      arms[#arms+1]=arm
    end
    supply.insert{name="worker-biter",count=2,quality="uncommon"}
    storage.fixture.inserter_result=result
    storage.fixture.inserters={input=departure,output=reception,supply=supply,arms=arms}
    check(departure.get_inventory(defines.inventory.furnace_source).insert{name="rideable-biter",count=1}==0, "source inventory accepts rideable biter")
    check(departure.get_inventory(defines.inventory.furnace_source).insert{name="hired-biter-capsule",count=1}==0, "source inventory accepts Field Agent")
    local folded=build("personnel-deployment-office",220,220,defines.direction.east)
    build("personnel-routing-sign",224,220,defines.direction.south)
    build("personnel-routing-sign",224,222,defines.direction.west)
    local folded_output=build("personnel-reception-office",220,222)
    for i=1,8 do folded_output.get_inventory(defines.inventory.furnace_result)[i].set_stack{name="worker-biter",count=1,quality="rare"} end
    folded.get_inventory(defines.inventory.furnace_source).insert{name="worker-biter",count=1}
    local spare=game.create_inventory(1)
    spare.insert{name="worker-biter",count=1}
    storage.fixture.folded={input=folded,output=folded_output,spare=spare}
  elseif game.tick == 2940 then
    storage.fixture.briefing_renders={}
    local briefings=0
    for _,job in ipairs(remote.call("administratorio-personnel-routing","inspect")) do
      if job.item:find("%-briefed%-") then
        check(job.briefing and job.briefing.valid, "roster briefing badge missing: " .. job.item)
        local icon=rendering.get_object_by_id(job.briefing.icon)
        local bar=rendering.get_object_by_id(job.briefing.bar)
        check(icon and icon.valid and bar and bar.valid and bar.color.g>bar.color.r, "fresh briefing renders/bar missing: " .. job.item)
        storage.fixture.briefing_renders[#storage.fixture.briefing_renders+1]=job.briefing.icon
        storage.fixture.briefing_renders[#storage.fixture.briefing_renders+1]=job.briefing.bar
        briefings=briefings+1
      end
    end
    check(briefings==5, "not all five briefing overlays were exercised")
    for _,row in ipairs(storage.fixture.roster) do row.output.get_inventory(defines.inventory.furnace_result).clear() end
    check(storage.fixture.folded.input.get_inventory(defines.inventory.furnace_source).get_item_count("worker-biter")==1, "tightly folded lane admitted intersecting traffic")
    local count=0
    for _,unit in ipairs(units) do if unit.position.x>=219 and unit.position.x<=225 and unit.position.y>=219 and unit.position.y<=223 then count=count+1 end end
    check(count==1, "folded lane must keep exactly one active journey")
  elseif game.tick == 3240 then
    storage.fixture.folded.output.get_inventory(defines.inventory.furnace_result).clear()
    for _,id in ipairs(storage.fixture.briefing_renders) do
      local render=rendering.get_object_by_id(id)
      check(not render or not render.valid, "reception leaked its briefing overlay")
    end
    log("Personnel smoke: roster complete, validating inserters")
    for _,row in ipairs(storage.fixture.roster) do
      check(row.output.get_inventory(defines.inventory.furnace_result).get_item_count{name=row.name,quality="epic"}==1,
        "roster identity/quality failed: " .. row.name .. " " .. serpent.line(remote.call("administratorio-personnel-routing","inspect")))
      local stack=row.output.get_inventory(defines.inventory.furnace_result).find_item_stack{name=row.name,quality="epic"}
      check(math.abs(stack.health-0.75)<0.001, "cargo health metadata lost: " .. row.name)
      if stack.spoil_tick>0 then check(stack.spoil_percent>=0.25 and stack.spoil_percent<0.30, "cargo freshness metadata lost: " .. row.name) end
      row.output.get_inventory(defines.inventory.furnace_result).clear()
    end
    check(#proxies(storage.fixture.aux)==0, "roster queue failed to drain")
    local ins=storage.fixture.inserters
    local diagnostic={supply=ins.supply.get_inventory(defines.inventory.chest).get_contents(),input=ins.input.get_inventory(defines.inventory.furnace_source).get_contents(),output=ins.output.get_inventory(defines.inventory.furnace_result).get_contents(),result=storage.fixture.inserter_result.get_inventory(defines.inventory.chest).get_contents(),arms={}}
    for _,arm in ipairs(ins.arms) do diagnostic.arms[#diagnostic.arms+1]={status=arm.status,pickup=arm.pickup_position,drop=arm.drop_position,held=arm.held_stack.valid_for_read and arm.held_stack.name} end
    check(storage.fixture.inserter_result.get_item_count{name="worker-biter",quality="uncommon"}>=1, "native inserters did not load and collect personnel: " .. serpent.line(diagnostic))
  elseif game.tick == 3296 then
    storage.fixture.roster[1].input.get_inventory(defines.inventory.furnace_source).insert{name="worker-biter",count=1}
  elseif game.tick == 3304 then
    log("Personnel smoke: clearing surface")
    check(#proxies(storage.fixture.aux)==1, "surface clearing fixture never dispatched")
    storage.fixture.aux.clear()
    log("Personnel smoke: surface cleared")
  elseif game.tick == 3420 then
    local recovered=0
    for _,crate in ipairs(surface.find_entities_filtered{name="personnel-recovery-crate"}) do recovered=recovered+crate.get_item_count("worker-biter") end
    check(recovered==2 and no_worker_jobs(), "surface clearing lost in-flight personnel")
    local main=surface
    surface=storage.fixture.aux
    surface.request_to_generate_chunks({0,0},1)
    surface.force_generate_chunk_requests()
    for _,e in ipairs(surface.find_entities()) do e.destroy() end
    local tiles={}
    for x=-2,6 do for y=-2,2 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
    surface.set_tiles(tiles)
    local departure=build("personnel-deployment-office",0,0,defines.direction.east)
    build("personnel-reception-office",4,0)
    storage.fixture.deletion_input=departure
    surface=main
  elseif game.tick == 3476 then
    check(storage.fixture.deletion_input.get_inventory(defines.inventory.furnace_source).insert{name="worker-biter",count=1}==1, "rebuilt input rejected cargo")
  elseif game.tick == 3484 then
    log("Personnel smoke: deleting surface")
    check(#proxies(storage.fixture.aux)==1, "surface deletion fixture never dispatched: " .. serpent.line(remote.call("administratorio-personnel-routing","inspect")) .. " source=" .. serpent.line(storage.fixture.deletion_input.get_inventory(defines.inventory.furnace_source).get_contents()) .. " status=" .. serpent.line(storage.fixture.deletion_input.custom_status))
    game.delete_surface(storage.fixture.aux)
  elseif game.tick == 3600 then
    local recovered=0
    for _,crate in ipairs(surface.find_entities_filtered{name="personnel-recovery-crate"}) do recovered=recovered+crate.get_item_count("worker-biter") end
    check(recovered==3 and no_worker_jobs(), "surface deletion lost in-flight personnel")
    check(storage.fixture.inserter_result.get_item_count{name="worker-biter",quality="uncommon"}==2, "native inserter queue did not fully drain")
    local departure=build("personnel-deployment-office",200,226,defines.direction.east)
    local reception=build("personnel-reception-office",206,226)
    local buffer=reception.get_inventory(defines.inventory.furnace_result)
    for i=1,#buffer do buffer[i].set_stack{name="worker-biter",count=1} end
    local inv=departure.get_inventory(defines.inventory.furnace_source)
    check(inv.insert{name="training-briefed-middle-management-managing-manager",count=1,quality="rare"}==1, "briefing fixture source rejected cargo")
    inv[1].spoil_tick=game.tick+180
    storage.fixture.expiry_output=reception
  elseif game.tick == 3680 then
    local briefings=0
    for _,job in ipairs(remote.call("administratorio-personnel-routing","inspect")) do
      if job.item=="training-briefed-middle-management-managing-manager" then
        check(job.briefing and job.briefing.valid and job.briefing.remaining>0 and job.briefing.remaining<0.03, "briefing overlay/freshness bar missing")
        local bar=rendering.get_object_by_id(job.briefing.bar)
        check(bar and bar.valid and bar.color.r>bar.color.g and (bar.to.offset.x or bar.to.offset[1])<(bar.from.offset.x or bar.from.offset[1])+0.03, "nearly expired briefing bar is not short/red")
        storage.fixture.expiry_renders={job.briefing.icon,job.briefing.bar}
        briefings=briefings+1
      end
    end
    check(briefings==1, "briefing did not dispatch for overlay test")
    game.server_save("personnel-mid-briefing")
  elseif game.tick == 3900 then
    local jobs=remote.call("administratorio-personnel-routing","inspect")
    check(#jobs==1 and jobs[1].item=="training-briefed-middle-management-managing-manager",
      "queued manager expired before its half-speed deadline")
    check(jobs[1].spoil_tick-game.tick>=20 and jobs[1].spoil_tick-game.tick<=40,
      "queued manager half-speed clock drifted across save/load")
  elseif game.tick == 4140 then
    check(storage.fixture.folded.output.get_inventory(defines.inventory.furnace_result).get_item_count("worker-biter")==2, "serialized folded lane failed to deliver both personnel: " .. serpent.line(remote.call("administratorio-personnel-routing","inspect")) .. " source=" .. serpent.line(storage.fixture.folded.input.get_inventory(defines.inventory.furnace_source).get_contents()) .. " output=" .. serpent.line(storage.fixture.folded.output.get_inventory(defines.inventory.furnace_result).get_contents()))
    local jobs=remote.call("administratorio-personnel-routing","inspect")
    check(#jobs==1 and jobs[1].item=="middle-management-managing-manager", "waiting briefing did not retain its normal spoil result: " .. serpent.line(jobs))
    check(not jobs[1].briefing, "expired briefing badge remained active")
    check(jobs[1].unit_name=="personnel-in-transit-middle-management-managing-manager", "queued expired manager kept its old proxy")
    for _,id in ipairs(storage.fixture.expiry_renders) do
      local render=rendering.get_object_by_id(id)
      check(not render or not render.valid, "expired briefing leaked its overlay")
    end
    storage.fixture.expiry_output.get_inventory(defines.inventory.furnace_result).clear()
  elseif game.tick == 4260 then
    check(#remote.call("administratorio-personnel-routing","inspect")==0, "expired briefing did not finish reception")
    check(storage.fixture.expiry_output.get_inventory(defines.inventory.furnace_result).get_item_count{name="middle-management-managing-manager",quality="rare"}==1, "expired briefing lost personnel/quality")
    helpers.write_file("administratorio-personnel-routing-smoke.txt","PASS\n",false)
  end
end)
'''

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--factorio-bin', required=True)
    args = parser.parse_args()
    factorio = Path(args.factorio_bin)
    with tempfile.TemporaryDirectory(prefix='administratorio-personnel-smoke-') as temp:
        root = Path(temp)
        prepare_profile(root)
        (root/"saves").mkdir()
        (root/'mods'/SMOKE_MOD_NAME/'scenarios/runtime-smoke/control.lua').write_text(SCENARIO_CONTROL)
        config = json.loads((factorio.parent.parent/'data/server-settings.example.json').read_text())
        config['auto_pause'] = False
        config['visibility'] = {'public': False, 'lan': False}
        config['require_user_verification'] = False
        (root/'server-settings.json').write_text(json.dumps(config))
        command = [str(factorio),'--config',str(root/'config.ini'),'--mod-directory',str(root/'mods'),
                   '--disable-audio','--server-settings',str(root/'server-settings.json'),
                   '--start-server-load-scenario',f'{SMOKE_MOD_NAME}/runtime-smoke','--until-tick','4320']
        log_file = root/'server.log'
        stream = log_file.open('w')
        process = subprocess.Popen(command,cwd=REPO_ROOT,text=True,stdout=stream,stderr=subprocess.STDOUT)
        marker = root/'script-output/administratorio-personnel-routing-smoke.txt'
        deadline = time.monotonic()+75
        while not marker.exists() and process.poll() is None and time.monotonic()<deadline:
            time.sleep(.05)
        if process.poll() is None:
            process.terminate() if marker.exists() else process.kill()
        process.wait(timeout=10)
        stream.close()
        output_text=log_file.read_text()
        assert marker.exists(), 'Personnel routing engine smoke failed:\n'+output_text[-7000:]
        assert marker.read_text() == 'PASS\n'
        for filename,ticks in [('personnel-mid-sign-entry.zip',4220),('personnel-mid-queue.zip',3420),('personnel-mid-briefing.zip',580)]:
            save = root/'saves'/filename
            assert save.exists(), f'{filename} was not written'
            marker.unlink()
            replay = subprocess.run([str(factorio),'--config',str(root/'config.ini'),'--mod-directory',str(root/'mods'),
                '--disable-audio','--benchmark',str(save),'--benchmark-ticks',str(ticks),'--benchmark-runs','1'],
                cwd=REPO_ROOT,text=True,capture_output=True,timeout=45)
            assert marker.exists(), f'{filename} replay failed:\n'+(replay.stdout+replay.stderr)[-7000:]
            assert marker.read_text() == 'PASS\n'
    print('Personnel routing engine lifecycle, native grid and saved queue/briefing replays passed')
if __name__ == '__main__': main()
