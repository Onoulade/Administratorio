-- Working layouts, like the vanilla Tips scenes. Runtime scripts own transport,
-- visitor routing and traffic; the update file only supplies and clears cargo.
local init = [=[
local s=storage.administratorio_tip_scene
local surface=game.surfaces[1]
s.surface=surface
surface.request_to_generate_chunks({0,0},1)
surface.force_generate_chunk_requests()
for _,entity in ipairs(surface.find_entities_filtered{area={{-32,-24},{32,24}}}) do entity.destroy() end
surface.build_checkerboard{{-32,-24},{32,24}}
surface.always_day=true
if game.simulation then
  game.simulation.camera_position=s.kind=="boarding" and {2,-1} or {0,0.5}
  game.simulation.camera_zoom=s.kind=="path" and 1.1 or s.kind=="tube" and 2 or 1.4
  game.simulation.camera_alt_info=true
  game.simulation.hide_cursor=true
end
game.tick_paused=false
local function build(name,position,direction)
  local e=assert(surface.create_entity{name=name,position=position,direction=direction,
    force="player",snap_to_grid=false,raise_built=true},"Tip scene: "..name)
  assert(e.valid,"Tip scene build rejected: "..name)
  e.destructible=false
  return e
end
local function signal_source(position,item,kind)
  local e=build("constant-combinator",position)
  e.get_or_create_control_behavior().add_section().set_slot(1,{
    value={type=kind or "item",name=item,quality="normal"},min=1})
  return e
end
local function wire(source,target)
  local id=defines.wire_connector_id.circuit_red
  assert(source.get_wire_connector(id,true).connect_to(target.get_wire_connector(id,true)))
end
if s.kind=="tube" then
  game.forces.player.technologies["pneumatic-form-transport"].researched=true
  for name,recipe in pairs(game.forces.player.recipes) do
    if name:find("^pneumatic%-intake%-") then recipe.enabled=true end
  end
  s.sources={build("steel-chest",{-8.5,0.5}),build("steel-chest",{8.5,0.5})}
  s.items={"form-27b-6","work-order"}
  build("inserter",{-7.5,0.5},defines.direction.west)
  build("inserter",{7.5,0.5},defines.direction.east)
  build("tube-intake",{-6.5,0.5})
  build("tube-intake",{6.5,0.5})
  for x=-5.5,5.5 do if x~=0.5 then build("pneumatic-pipe",{x,0.5}) end end
  s.outtake=build("tube-outtake",{0.5,0.5})
  build("inserter",{0.5,1.5},defines.direction.north)
  s.belts={}
  for x=0.5,7.5 do s.belts[#s.belts+1]=build("transport-belt",{x,2.5},defines.direction.east) end
  s.exit=s.belts[#s.belts]
  local power=build("electric-energy-interface",{0,-12})
  power.power_production=10000000
  power.electric_buffer_size=10000000
  power.energy=10000000
  build("substation",{0,-7})
  s.pool=rendering.draw_text{text={"tip-scene.pool-contents",""},surface=surface,
    target={0,-2.5},color={1,1,1},alignment="center",use_rich_text=true}
  for i,chest in ipairs(s.sources) do chest.insert{name=s.items[i],count=2} end
elseif s.kind=="boarding" then
  for x=-10,14,2 do build("straight-rail",{x,-2},defines.direction.east) end
  s.wagon=build("passenger-wagon",{0,-2},defines.direction.east)
  build("locomotive",{7,-2},defines.direction.east).insert{name="coal",count=10}
  s.wagon.train.manual_mode=true
  s.platform=build("boarding-platform",{0.5,0.5},defines.direction.north)
  s.unboarding=build("deboarding-platform",{0.5,-4.5},defines.direction.south)
  -- Hold briefly after boarding, then let the real unboarding code empty it.
  -- This is only loop maintenance; there are no scripted passenger transfers.
  s.hold=signal_source({-4,-4.5},"signal-deboarding-closed","virtual")
  wire(s.hold,s.unboarding)
  s.next_visitor=0
elseif s.kind=="path" then
  game.forces.player.technologies["personnel-routing"].researched=true
  game.forces.player.technologies["personnel-routing-multisign"].researched=true
  s.items={"worker-biter","chemical-operator","middle-management-managing-manager"}
  s.deployment=build("personnel-deployment-office",{-8,0},defines.direction.east)
  s.sign=build("personnel-routing-multisign",{0,0},defines.direction.east)
  s.outputs={build("personnel-reception-office",{0,-6}),
    build("personnel-reception-office",{8,0}),build("personnel-reception-office",{0,6})}
  local ports
  for _,record in ipairs(remote.call("administratorio-personnel-routing","inspect_signals")) do
    if record.id==s.sign.unit_number then ports=record.ports end
  end
  assert(ports,"Tip multisign sockets missing")
  for i,exit in ipairs({"left","straight","right"}) do
    local position=({{-3,-3},{3,-3},{3,3}})[i]
    wire(signal_source(position,s.items[i]),ports[exit])
  end
  s.next_item=1
else error("Unknown tip scene "..tostring(s.kind)) end
]=]
local function scene(kind)
  return {
    init='storage.administratorio_tip_scene={kind="'..kind..'"}\n'..init,
    update_file="__administratorio__/prototypes/tips-and-tricks-simulation-update.lua",
    mods=kind=="path" and {"administratorio","space-age"} or {"administratorio"},
    generate_map=true,
    init_update_count=120,
    length=3600,
    game_view_settings={default_show_value=false},
  }
end
local paths=scene("path")
return {
  ["administratorio-pneumatic-transport"]=scene("tube"),
  ["administratorio-passenger-boarding"]=scene("boarding"),
  ["administratorio-personnel-routing"]=paths,
  ["administratorio-personnel-multisign"]=paths,
}
