-- Supply and cleanup only. Production code and native entities do every transfer.
local s=storage.administratorio_tip_scene
if s.kind=="tube" then
  if game.tick%10==0 then
    local values={}
    for _,item in ipairs(s.items) do
      local count=s.outtake.get_signal({type="item",name=item,quality="normal"},
        defines.wire_connector_id.circuit_red)
      values[#values+1]="[item="..item.."] "..count
    end
    s.pool.text={"tip-scene.pool-contents",table.concat(values,"   ")}
  end
  if game.tick%180==0 then
    for i,chest in ipairs(s.sources) do
      if chest.get_item_count(s.items[i])==0 then chest.insert{name=s.items[i],count=1} end
    end
  end
  for lane=1,2 do s.exit.get_transport_line(lane).clear() end
elseif s.kind=="boarding" then
  local slot=s.platform.get_control_behavior().get_section(1).get_slot(1)
  local passengers=slot.min or 0
  if passengers>0 then
    s.boarded_tick=s.boarded_tick or game.tick
    s.hold.get_control_behavior().enabled=game.tick-s.boarded_tick<60
  else
    s.boarded_tick=nil
    s.hold.get_control_behavior().enabled=true
  end
  -- Remove visitors only after the real code has unboarded them.
  for _,unit in ipairs(s.surface.find_entities_filtered{type="unit",position={0,-4.5},radius=8}) do
    if unit~=s.visitor then unit.destroy{raise_destroy=true} end
  end
  if (not s.visitor or not s.visitor.valid) and passengers==0 and game.tick>=s.next_visitor then
    s.visitor=assert(s.surface.create_entity{name="small-biter",position={-6.5,0.5},force="enemy"})
    -- Finishing a native group enters the ordinary complaint routing handler.
    -- Production code chooses, reserves, walks to and boards the platform.
    local group=s.surface.create_unit_group{position=s.visitor.position,force="enemy"}
    group.add_member(s.visitor)
    group.start_moving()
    s.next_visitor=game.tick+120
  end
elseif s.kind=="path" then
  for _,output in ipairs(s.outputs) do output.get_inventory(defines.inventory.furnace_result).clear() end
  if game.tick%90==0 then
    local input=s.deployment.get_inventory(defines.inventory.furnace_source)
    if input.is_empty() then
      input.insert{name=s.items[s.next_item],count=1}
      s.next_item=s.next_item%#s.items+1
    end
  end
end
