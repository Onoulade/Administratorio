local R = require("prototypes.shared.personnel_routing")
local graph = require("scripts.personnel_route_graph")
local pavement = require("scripts.personnel_pavement")
local traffic = require("scripts.personnel_traffic")
local ai = require("scripts.unit_ai_settings")
local signals = require("scripts.personnel_signals")
local multisign_gui = require("scripts.personnel_multisign_gui")
local briefing_overlay = require("scripts.personnel_briefing_overlay")
local M = {}
local function state()
  storage.personnel_routing = storage.personnel_routing or {
    surfaces = {}, records = {}, inputs = {}, jobs = {}, job_order = {}, units = {}, watches = {}, evacuating = {}, next_id = 1,
  }
  return storage.personnel_routing
end
local function surface_state(index)
  local st = state()
  st.surfaces[index] = st.surfaces[index] or {cells = {}, tiles = {}, revision = 0}
  return st.surfaces[index]
end
local function valid(entity) return entity and entity.valid end
local function status(entity, key, green)
  if valid(entity) and entity.type == "furnace" then
    entity.custom_status = {diode = green and defines.entity_status_diode.green or defines.entity_status_diode.yellow,
      label = {"personnel-routing." .. key}}
  end
end
local function inventory(entity, output)
  if not valid(entity) then return nil end
  return entity.get_inventory(output and defines.inventory.furnace_result or defines.inventory.furnace_source)
end
local function watch(entity, kind, id)
  local registration = script.register_on_object_destroyed(entity)
  state().watches[registration] = {kind = kind, id = id}
  return registration
end
local function floor_tiles(cell)
  local tiles = {}
  for x = cell.x - 1, cell.x do for y = cell.y - 1, cell.y do
    tiles[#tiles + 1] = {name = R.TILE, position = {x, y}}
  end end
  return tiles
end
local function paved(surface, cell)
  for x = cell.x - 1, cell.x do for y = cell.y - 1, cell.y do
    local tile=surface.get_tile(x,y)
    if not tile.valid or tile.name~=R.TILE then return false end
  end end
  return true
end
local function clear_block(surface, cell)
  for _, other in ipairs(surface.find_entities_filtered{area = {{cell.x-0.99, cell.y-0.99}, {cell.x+0.99, cell.y+0.99}}}) do
    if not R.is_port(other.name) and not R.roles[other.name] and not R.passable_types[other.type] then
      local box = other.bounding_box
      if box.left_top.x < box.right_bottom.x and box.left_top.y < box.right_bottom.y then return false end
    end
  end
  return true
end
local function lock_entity(record, locked)
  if record and valid(record.entity) then
    record.entity.minable_flag = not locked
    record.entity.rotatable = record.role=="sign" or (not locked and record.role=="input")
    -- Active routes cannot be destroyed by combat. Direct script deletion is
    -- covered by registered destruction callbacks and the saved escrow.
    record.entity.destructible = not locked
  end
end
local function lock_cell(cell)
  lock_entity(cell.node, (cell.refs or 0) > 0)
  lock_entity(cell.road, (cell.refs or 0) > 0)
end
local function reserve_route(route)
  for i, cell in ipairs(route) do
    cell.refs = (cell.refs or 0) + 1
    if route.serial then cell.serial_refs = (cell.serial_refs or 0) + 1 end
    if route[i+1] then
      cell.flow=route[i+1].key
      cell.flow_refs=(cell.flow_refs or 0)+1
    end
    lock_cell(cell)
  end
end
local function drop_route(route,id,first,last)
  for i=first or 1,last or #(route or {}) do
    local cell=route[i]
    if cell.occupant==id then cell.occupant=nil end
    cell.refs=math.max(0,(cell.refs or 0)-1)
    if route.serial then cell.serial_refs=math.max(0,(cell.serial_refs or 0)-1) end
    if route[i+1] then cell.flow_refs=math.max(0,(cell.flow_refs or 0)-1) end
    if (cell.flow_refs or 0)==0 then cell.flow=nil end
    lock_cell(cell)
  end
end
local function release_route(job)
  drop_route(job.route,job.id,job.released_start and 2 or 1)
  drop_route(job.departure,job.id)
  job.departure=nil
  for _,tail in ipairs(job.trailing or {}) do drop_route(tail,job.id) end
  job.trailing=nil
  for _,cell in ipairs(job.entries or {}) do if cell.entry_owner==job.id then cell.entry_owner=nil end end
  job.entries=nil
  local s=surface_state(job.surface_index)
  for _,key in ipairs(job.exclusive or {}) do if s.exclusive and s.exclusive[key]==job.id then s.exclusive[key]=nil end end
  job.exclusive=nil
  if s.deferred then s.dirty=true end
  job.route=nil
end
local function delete_unit(job)
  briefing_overlay.clear(job)
  local st = state()
  if job.unit_id then st.units[job.unit_id] = nil end
  if job.watch then st.watches[job.watch] = nil end
  if valid(job.entity) then job.entity.destroy() end
  job.entity = nil
end
local function finish(job, target)
  if not target or not target.valid then return false end
  local stack = job.cargo[1]
  if not stack.valid_for_read then return false end
  -- The cargo slot owns the original item throughout the journey. Commit the
  -- arrival before releasing that ownership or destroying the walking proxy.
  if target.insert(stack) ~= 1 then return false end
  stack.clear()
  delete_unit(job)
  release_route(job)
  job.cargo.destroy()
  state().jobs[job.id] = nil
  return true
end
local function recovery_surface(job)
  local surface = game.surfaces[job.surface_index]
  if surface and surface.valid and not job.surface_lost then return surface, job.home end
  local force = game.forces[job.force_index]
  surface = game.surfaces.nauvis or game.surfaces[1]
  if surface and state().evacuating[surface.index] then
    surface = nil
    for _, other in pairs(game.surfaces) do
      if other.valid and other.index ~= job.surface_index and not state().evacuating[other.index] then surface = other; break end
    end
  end
  if surface and surface.valid then
    return surface, force and force.get_spawn_position(surface) or {0, 0}
  end
end
local function try_recovery(job)
  local origin = state().records[job.origin]
  if origin and not job.surface_lost and finish(job, inventory(origin.entity, false)) then return true end
  local surface, position = recovery_surface(job)
  if not surface then return false end
  local force = game.forces[job.force_index] or game.forces.player
  for _, crate in ipairs(surface.find_entities_filtered{name = R.RECOVERY, position = position, radius = 16, force = force}) do
    if finish(job, crate.get_inventory(defines.inventory.chest)) then return true end
  end
  local point = surface.find_non_colliding_position(R.RECOVERY, position, 16, 1)
  if not point then return false end
  local crate = surface.create_entity{name = R.RECOVERY, position = point, force = force}
  if not crate then return false end
  crate.destructible = false
  local item = job.cargo[1].name
  if not finish(job, crate.get_inventory(defines.inventory.chest)) then crate.destroy(); return false end
  for _, player in pairs(force.players) do
    player.add_custom_alert(crate, {type = "item", name = item}, {"personnel-routing.recovered"}, true)
  end
  return true
end
local function pending_alert(job)
  local origin = state().records[job.origin]
  if origin then status(origin.entity, "recovery-pending") end
  local force = game.forces[job.force_index]
  if not force then return end
  for _, player in pairs(force.players) do
    local anchor = origin and valid(origin.entity) and origin.entity or player.character
    if valid(anchor) then
      player.add_custom_alert(anchor, {type = "item", name = job.cargo[1].name}, {"personnel-routing.recovery-pending"}, true)
    end
  end
end
local function recover(job, reason)
  job.recovery_reason = reason or "route-removed"
  if job.state ~= "recovery" then
    delete_unit(job)
    release_route(job)
    job.state = "recovery"
    job.retry = game.tick
  end
  if not try_recovery(job) then pending_alert(job) end
end
local function remove_record(id)
  local st = state()
  local record = st.records[id]
  if not record then return end
  signals.remove_ports(record)
  st.records[id], st.inputs[id] = nil, nil
  multisign_gui.refresh_all(st.records)
  st.watches[record.watch] = nil
  local s = st.surfaces[record.surface_index]
  s.revision = s.revision + 1
  s.dirty = true
  local cell = s.cells[record.key]
  -- Clear the broken record before refunding: a removed origin must never
  -- receive a refund that the engine would then silently discard.
  if cell then
    if cell.node == record then cell.node = nil end
    if cell.road == record then cell.road = nil end
    local affected = {}
    for _,job in pairs(st.jobs) do
      local uses=false
      for i,used in ipairs(job.route or {}) do if used==cell and not (i==1 and job.released_start) then uses=true end end
      for _,used in ipairs(job.departure or {}) do if used==cell then uses=true end end
      for _,tail in ipairs(job.trailing or {}) do for _,used in ipairs(tail) do if used==cell then uses=true end end end
      if uses then affected[#affected+1]=job end
    end
    for _, job in ipairs(affected) do recover(job) end
    if not cell.node and not cell.road then
      s.cells[record.key] = nil
      local surface = game.surfaces[record.surface_index]
      if surface and surface.valid then surface.set_tiles(cell.original, true, false, false, false) end
      for _, tile in ipairs(cell.original) do s.tiles[R.key(tile.position[1], tile.position[2])] = nil end
    end
  end
end
local function reject_build(entity, event)
  local item = {name = entity.name, count = 1, quality = entity.quality.name}
  local player = event.player_index and game.get_player(event.player_index)
  local inv = event.robot and event.robot.valid and event.robot.get_inventory(defines.inventory.robot_cargo)
  local inserted = player and player.insert(item) or inv and inv.insert(item) or 0
  if inserted == 0 then
    entity.surface.spill_item_stack{position = entity.position, stack = item, enable_looted = true, allow_belts = false, max_radius = 16}
  end
  if player then player.create_local_flying_text{text = {"personnel-routing.alignment"}, position = entity.position} end
  entity.destroy()
end
function M.on_built(event)
  local entity = event.entity or event.created_entity
  if not valid(entity) or not R.roles[entity.name] then return false end
  if R.roles[entity.name]=="output" then entity.direction=defines.direction.north;entity.rotatable=false end
  if R.roles[entity.name]=="sign" then entity.rotatable=true;entity.operable=true end
  if state().records[entity.unit_number] then signals.ensure_ports(state().records[entity.unit_number]); return true end
  local p, role = entity.position, R.roles[entity.name]
  -- Native player placement uses the shared 2x2 grid. Keep integer-centered
  -- legacy/scripted layouts valid; their non-overlap checks still apply.
  if p.x ~= math.floor(p.x) or p.y ~= math.floor(p.y) then reject_build(entity, event); return true end
  local s = surface_state(entity.surface.index)
  local key = R.key(p.x, p.y)
  local cell = s.cells[key]
  if cell and (cell.force_index ~= entity.force.index or (role == "road" and cell.road)
      or (role ~= "road" and cell.node) or (cell.refs or 0) > 0) then
    reject_build(entity, event); return true
  end
  for x = p.x - 1, p.x do for y = p.y - 1, p.y do
    local owner = s.tiles[R.key(x, y)]
    if owner and owner ~= key then reject_build(entity, event); return true end
    local tile=entity.surface.get_tile(x,y)
    if not tile.valid or tile.collides_with("water_tile") then reject_build(entity,event);return true end
  end end
  if not clear_block(entity.surface, {x=p.x,y=p.y}) then reject_build(entity, event); return true end
  if not cell then
    cell = {key = key, x = p.x, y = p.y, force_index = entity.force.index, original = {}}
    for x = p.x - 1, p.x do for y = p.y - 1, p.y do
      cell.original[#cell.original + 1] = {name = entity.surface.get_tile(x, y).name, position = {x, y}}
      s.tiles[R.key(x, y)] = key
    end end
    s.cells[key] = cell
  end
  local record = {entity = entity, role = role, surface_index = entity.surface.index, key = key}
  if entity.name == R.MULTISIGN and event.tags and event.tags.personnel_multisign then
    signals.configure(record, event.tags.personnel_multisign)
  end
  signals.ensure_ports(record)
  record.watch = watch(entity, "record", entity.unit_number)
  state().records[entity.unit_number] = record
  if role == "road" then cell.road = record else cell.node = record end
  if role == "input" then state().inputs[entity.unit_number] = record end
  if entity.type == "furnace" then entity.active = false end
  entity.surface.set_tiles(floor_tiles(cell), true, false, true, false)
  s.revision = s.revision + 1
  s.dirty = true
  status(entity, "no-route")
  return true
end
function M.on_cloned(event)
  local entity = event.destination
  if valid(entity) and R.roles[entity.name] then
    M.on_built{entity = entity}
    local source = valid(event.source) and state().records[event.source.unit_number]
    local destination = valid(entity) and state().records[entity.unit_number]
    if source and destination and entity.name == R.MULTISIGN then
      signals.configure(destination, source)
      signals.read_filters(destination)
    end
  elseif valid(entity) and R.is_port(entity.name) then
    -- Cloning a sign creates its own ports; separately cloned helpers are
    -- never independent infrastructure.
    entity.destroy()
  elseif valid(entity) and entity.name:find("^personnel%-in%-transit%-") then
    -- A proxy is never cargo ownership: cloning it must not duplicate a biter.
    entity.destroy()
  end
end
function M.on_removed(event)
  local entity = event.entity
  if not valid(entity) then return false end
  local st = state()
  local job = st.jobs[st.units[entity.unit_number]]
  if job then recover(job); return true end
  if st.records[entity.unit_number] then remove_record(entity.unit_number); return true end
  return false
end
function M.on_object_destroyed(event)
  local st = state()
  local entry = st.watches[event.registration_number]
  if not entry then return end
  st.watches[event.registration_number] = nil
  if entry.kind == "record" then remove_record(entry.id)
  elseif st.jobs[entry.id] then recover(st.jobs[entry.id]) end
end
function M.on_rotated(event)
  local entity = event.entity
  if valid(entity) and R.is_port(entity.name) then
    local reverse = (entity.direction - event.previous_direction) % 16 > 8
    entity.direction = event.previous_direction
    for _, owner in pairs(state().records) do
      for _, port in pairs(owner.ports or {}) do
        if port == entity and valid(owner.entity) then
          local previous = owner.entity.direction
          if owner.entity.rotate{reverse=reverse} then
            M.on_rotated{entity=owner.entity,previous_direction=previous}
          end
          return
        end
      end
    end
    return
  end
  local record = valid(entity) and state().records[entity.unit_number]
  if not record then return end
  local s = surface_state(record.surface_index)
  local cell = s.cells[record.key]
  if record.role=="output" or ((cell.refs or 0)>0 and record.role~="sign") then
    entity.direction=event.previous_direction;return
  end
  signals.ensure_ports(record)
  s.revision = s.revision + 1
  s.dirty = true
end
local function multisign_record(entity)
  if not valid(entity) then return end
  if entity.name == R.MULTISIGN then return state().records[entity.unit_number] end
  if R.is_port(entity.name) then
    for _,record in pairs(state().records) do
      for _,port in pairs(record.ports or {}) do if port == entity then return record end end
    end
  end
end
-- The simple-entity body has no native GUI, so link the normal open control.
function M.on_open_multisign(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  local entity = player.selected
  if valid(entity) and entity.name == R.MULTISIGN and player.can_reach_entity(entity) then
    local record = multisign_record(entity)
    if record then multisign_gui.open(player, record) end
  end
end
function M.on_gui_opened(event)
  local entity = event.entity
  local player = game.get_player(event.player_index)
  if not player then return end
  local record = multisign_record(entity)
  if record then
    multisign_gui.open(player, record)
  elseif valid(entity) and (entity.name == R.SIGN or R.is_port(entity.name)) then
    player.opened = nil
  end
end
local function configuration_changed(record)
  if signals.read_filters(record) then
    local s = surface_state(record.surface_index)
    s.revision = s.revision + 1
  end
end
function M.on_gui_changed(event)
  return multisign_gui.on_changed(event, state().records, configuration_changed)
end
M.on_gui_click = multisign_gui.on_click
M.on_gui_closed = multisign_gui.on_closed
function M.on_settings_pasted(event)
  local source, destination = multisign_record(event.source), multisign_record(event.destination)
  if source and destination then
    signals.configure(destination, source)
    configuration_changed(destination)
    multisign_gui.refresh_all(state().records)
  end
end
function M.on_setup_blueprint(event)
  local player = game.get_player(event.player_index)
  local blueprint = player and player.blueprint_to_setup
  if player and (not blueprint or not blueprint.valid_for_read) then blueprint = player.cursor_stack end
  if not blueprint or not blueprint.valid_for_read or not blueprint.is_blueprint then return end
  for index,entity in pairs(event.mapping.get()) do
    local record = valid(entity) and entity.name == R.MULTISIGN and state().records[entity.unit_number]
    if record then blueprint.set_blueprint_entity_tag(index,"personnel_multisign",signals.configuration(record)) end
  end
end
function M.on_tiles_built(event)
  local s = state().surfaces[event.surface_index]
  if not s then return end
  local surface = game.surfaces[event.surface_index]
  local restore = {}
  for _, tile in ipairs(event.tiles) do
    local p = tile.position
    if s.tiles[R.key(p.x, p.y)] then restore[#restore + 1] = {name = R.TILE, position = p} end
  end
  if #restore == 0 then return end
  surface.set_tiles(restore, true, false, false, false)
  local item = event.item and event.item.name
  if item then
    local stack = {name = item, count = #restore, quality = event.quality and event.quality.name or "normal"}
    local player = event.player_index and game.get_player(event.player_index)
    local inv = event.robot and event.robot.valid and event.robot.get_inventory(defines.inventory.robot_cargo)
    local inserted = player and player.insert(stack) or inv and inv.insert(stack) or 0
    if inserted < stack.count then
      stack.count = stack.count - inserted
      surface.spill_item_stack{position = restore[1].position, stack = stack, enable_looted = true, allow_belts = false, max_radius = 16}
    end
  end
end
local function route_for(record)
  local s = surface_state(record.surface_index)
  if record.revision ~= s.revision then
    record.route = graph.compile(s.cells, s.cells[record.key])
    if record.route then
      for _, cell in ipairs(record.route) do
        if not paved(record.entity.surface, cell) then record.route = nil; break end
      end
    end
    record.revision = s.revision
  end
  return record.route
end
local function stop(job)
  job.entity.commandable.set_command{type = defines.command.stop, distraction = defines.distraction.none}
  job.entity.active = false
  if job.dx then job.entity.orientation=job.dx==1 and 0.25 or job.dx==-1 and 0.75 or job.dy==1 and 0.5 or 0 end
end
local function available(route,s,id)
  for _,cell in ipairs(route) do
    if s.exclusive and s.exclusive[cell.key] and s.exclusive[cell.key]~=id then return false end
  end
  if not id and route.guards then
    for _,cell in ipairs(route.guards) do
      if (cell.refs or 0)>0 or (s.exclusive and s.exclusive[cell.key]) then return false end
    end
  end
  return graph.compatible(route,s.cells)
end
local function departure_for(job,cell,tick,index)
  local s=surface_state(job.surface_index)
  local item=job.cargo[1].valid_for_read and job.cargo[1].name
  if job.extension_revision~=s.revision or job.extension_item~=item then
    job.extension=graph.compile(s.cells,cell,item)
    job.extension_item=item
    job.extension_revision=s.revision
    job.extension_validate_after=nil
  end
  local onward=job.extension
  if not onward or not available(onward,s,job.id) then return nil end
  if tick>=(job.extension_validate_after or 0) then
    local next_cell=onward[2]
    job.extension_blocked=not paved(job.entity.surface,next_cell) or not clear_block(job.entity.surface,next_cell)
    job.extension_validate_after=tick+15
  end
  if job.extension_blocked then return nil end
  local dx=(onward[2].x-cell.x)/2
  local dy=(onward[2].y-cell.y)/2
  if traffic.limit(index,job,{x=cell.x,y=cell.y},dx,dy,job.entity.speed)<1/256 then return nil end
  return onward
end
local function dispatch(record, tick, index)
  local entity = record.entity
  if not valid(entity) then return end
  local inv = inventory(entity, false)
  local stack = inv and inv[1]
  if not stack or not stack.valid_for_read then status(entity, "empty"); return end
  if not R.cargo[stack.name] or not prototypes.entity[R.unit_name(stack.name)] then status(entity, "invalid-cargo"); return end
  local route = route_for(record)
  if not route or #route < 2 then status(entity, "no-route"); return end
  if not traffic.free(index,record.surface_index,entity.position) or not available(route,surface_state(record.surface_index)) then status(entity,"queued");return end
  if not clear_block(entity.surface, route[1]) then status(entity, "queued"); return end
  if not entity.surface.can_place_entity{name = R.unit_name(stack.name), position = entity.position, force = entity.force} then
    status(entity, "queued"); return
  end
  local st = state()
  local cargo = game.create_inventory(1)
  cargo[1].set_stack(stack)
  cargo[1].count = 1
  local unit = entity.surface.create_entity{name = R.unit_name(stack.name), position = entity.position, force = entity.force}
  if not unit then cargo.destroy(); return end
  -- No items are consumed until the proxy and exact saved cargo both exist.
  stack.count = stack.count - 1
  local id = st.next_id
  st.next_id = id + 1
  local job = {id = id, cargo = cargo, entity = unit, unit_id = unit.unit_number,
    route = route, index = 1, origin = entity.unit_number, state = "waiting",
    surface_index = entity.surface.index, force_index = entity.force.index,
    home = {x = entity.position.x, y = entity.position.y},
    position={x=entity.position.x,y=entity.position.y}, retry = tick, failures = 0}
  st.jobs[id] = job
  st.job_order[#st.job_order + 1] = id
  st.units[unit.unit_number] = id
  job.watch = watch(unit, "job", id)
  reserve_route(route)
  if route.guards then
    local s=surface_state(job.surface_index)
    s.exclusive=s.exclusive or {}
    job.exclusive={}
    for _,cell in ipairs(route.guards) do s.exclusive[cell.key]=id;job.exclusive[#job.exclusive+1]=cell.key end
  end
  traffic.move(index,job,job.position)
  route[1].occupant = id
  unit.speed = unit.prototype.speed * R.speed_multiplier(entity.force)
  unit.destructible = false
  unit.minable_flag = false
  ai.apply_managed_unit_settings(unit)
  stop(job)
  briefing_overlay.update(job, tick)
  status(entity, "running", true)
end
-- Deterministic lane motion with a native walking proxy. Commands keep its
-- walking animation active; saved lane positions own actual traffic movement.
local function update_job(job, tick, index)
  if job.state == "recovery" then
    if tick >= job.retry then
      job.retry = tick + 300
      if not try_recovery(job) then pending_alert(job) end
    end
    return
  end
  if not valid(job.entity) then recover(job, "invalid"); return end
  briefing_overlay.update(job, tick)
  local route, unit = job.route, job.entity
  unit.speed = unit.prototype.speed * R.speed_multiplier(unit.force)
  local cell, next_cell = route[job.index], route[job.index+1]
  if job.goal then
    local dx,dy = job.dx,job.dy
    local p = job.position or {x=unit.position.x,y=unit.position.y}
    local goal = route[job.goal]
    local remaining = (goal.x-p.x)*dx+(goal.y-p.y)*dy
    -- Position is authoritative: native steering cannot leave the lane or
    -- return cargo halfway through. Native walking supplies sprite animation.
    -- Quantize to the engine's position resolution to avoid fractional drift.
    local step = math.max(1/256, math.floor(unit.speed*256)/256)
    local terminal=route[#route]
    local approaching=job.goal==#route and terminal.node and (terminal.node.role=="sign" or terminal.node.role=="output")
    if approaching and job.departure and not job.departure_committed then
      if remaining<2 then
        -- The full 2x2 body has crossed the sign's 2x2 boundary. Its saved
        -- direction is now immutable, including when loading an older save.
        job.departure_committed=true
      else
        local vx,vy=R.vector(R.direction_for(terminal.node,job.cargo[1].valid_for_read and job.cargo[1].name))
        if not vx or job.departure[2].key~=R.key(terminal.x+vx,terminal.y+vy) then
          -- A reservation outside the tile is still tentative. Recheck the
          -- current arrow rather than sending the next biter along an old one.
          drop_route(job.departure,job.id)
          job.departure=nil
          job.extension_revision=nil
          local s=surface_state(job.surface_index)
          if s.deferred then s.dirty=true end
        end
      end
    end
    -- Keep the complete 2x2 body outside an invalid sign's tile. Reserve the
    -- departure before crossing this stop line. The saved segment freezes
    -- this biter's turn even if the player rotates the arrow during entry.
    if approaching and remaining<=traffic.GAP+step and (not terminal.entry_owner or terminal.entry_owner==job.id) then
      local onward=job.departure or (terminal.node.role=="sign" and departure_for(job,terminal,tick,index))
      if terminal.node.role=="output" or onward then
        if not terminal.entry_owner then
          terminal.entry_owner=job.id
          job.entries=job.entries or {}
          job.entries[#job.entries+1]=terminal
        end
        if onward and not job.departure then job.departure=onward;reserve_route(onward) end
      end
    end
    if next_cell and (job.validated_cell~=next_cell.key or tick>=(job.validate_after or 0)) then
      job.validated_cell=next_cell.key
      job.validate_after=tick+15
      job.blocked=not paved(unit.surface,next_cell) or not clear_block(unit.surface,next_cell)
    end
    if job.blocked then
      if job.state~="stopped" then stop(job);job.state="stopped" end
      unit.teleport(p);return
    end
    local permitted=remaining
    local admitted=terminal.entry_owner==job.id and (terminal.node.role=="output" or job.departure)
    if approaching and not admitted then permitted=remaining-traffic.GAP end
    local distance = traffic.limit(index,job,p,dx,dy,math.min(step,math.max(0,permitted)))
    if distance<1/256 then
      if job.state~="stopped" then stop(job);job.state="stopped" end
      unit.teleport(p)
      return
    end
    if job.state=="stopped" then job.state="walking";unit.active=true;job.animation_goal=nil end
    p = {x=p.x+dx*distance,y=p.y+dy*distance}
    if dx~=0 then p.y=cell.y else p.x=cell.x end
    local arrived = remaining<=distance+1/512
    if arrived then p={x=goal.x,y=goal.y} end
    if not unit.teleport(p) then recover(job,"teleport");return end
    unit.orientation=dx==1 and 0.25 or dx==-1 and 0.75 or dy==1 and 0.5 or 0
    job.position=p
    if approaching and job.departure and remaining-distance<2 then job.departure_committed=true end
    traffic.move(index,job,p)
    while next_cell and job.index<job.goal
      and (p.x-next_cell.x)*dx+(p.y-next_cell.y)*dy >= -1/256 do
      local tail=route[job.index-1]
      if tail and tail.occupant==job.id then tail.occupant=nil end
      job.index=job.index+1
      cell,next_cell=route[job.index],route[job.index+1]
      job.progress_tick=tick
    end
    if approaching and not admitted and remaining-distance<=traffic.GAP+1/512 then
      if job.state~="stopped" then stop(job);job.state="stopped" end
      return
    end
    if arrived then job.goal=nil; job.state="waiting" end
  end
  -- Retain only the last incoming block until the full body clears it.
  local tails={}
  for _,tail in ipairs(job.trailing or {}) do
    local p=job.position or unit.position
    local last=tail[#tail]
    if math.abs(p.x-last.x)>=traffic.GAP or math.abs(p.y-last.y)>=traffic.GAP then drop_route(tail,job.id)
    else tails[#tails+1]=tail end
  end
  job.trailing=tails
  local entries={}
  for _,entry in ipairs(job.entries or {}) do
    local p=job.position or unit.position
    if math.abs(p.x-entry.x)>=traffic.GAP or math.abs(p.y-entry.y)>=traffic.GAP then
      if entry.entry_owner==job.id then entry.entry_owner=nil end
    else entries[#entries+1]=entry end
  end
  job.entries=entries
  local start=route[1]
  local p=job.position or unit.position
  if not job.released_start and start.node and start.node.role=="sign"
    and (math.abs(p.x-start.x)>=traffic.GAP or math.abs(p.y-start.y)>=traffic.GAP) then
    -- The old direction only owns the junction while its body clears it.
    -- Keep the rest of that saved leg protected, and let new entrants follow
    -- the sign's current arrow once the shared tile is physically clear.
    drop_route(route,job.id,1,1)
    job.released_start=true
  end
  if not next_cell then
    local destination=cell.node and cell.node.entity
    if not valid(destination) then recover(job);return end
    if cell.node.role=="output" then
      if job.state~="stopped" then stop(job);job.state="stopped" end
      if finish(job,inventory(destination,true)) then traffic.remove(index,job.id);status(destination,"received",true)
      else status(destination,"output-full") end
      return
    end
    -- Saved pre-stop-line jobs may already be standing on the sign. Retain
    -- their cargo and let a valid departure drain them normally.
    local onward=job.departure or departure_for(job,cell,tick,index)
    if not onward then
      if job.state~="stopped" then stop(job);job.state="stopped" end
      status(destination,"no-route")
      return
    end
    local tail={route[math.max(1,#route-1)],cell}
    if #route==1 then tail={cell} end
    reserve_route(tail)
    drop_route(route,job.id,job.released_start and 2 or 1)
    job.trailing[#job.trailing+1]=tail
    job.route,job.index=onward,1
    job.released_start=false
    if not job.departure then reserve_route(onward) end
    job.departure=nil
    job.departure_committed=nil
    route=onward
    cell,next_cell=route[1],route[2]
    job.extension,job.extension_revision=nil,nil
    job.goal,job.animation_goal,job.checked,job.blocked,job.validated_cell=nil,nil,nil,nil,nil
  end
  local dx=(next_cell.x-cell.x)/2
  local dy=(next_cell.y-cell.y)/2
  local frontier=job.index
  -- A bounded look-ahead keeps commands far ahead at vanilla speed, while
  -- releasing cells behind the body allows convoys to advance continuously.
  for i=job.index+1,math.min(#route,job.index+8) do
    local part=route[i]
    local previous=route[i-1]
    if part.x-previous.x~=dx*2 or part.y-previous.y~=dy*2 then break end
    -- Surface queries occur only when first claiming a block, not each tick.
    job.checked=job.checked or {}
    if not job.checked[part.key] then
      if not paved(unit.surface,part) then break end
      if not clear_block(unit.surface,part) then break end
      job.checked[part.key]=true
    end
    part.occupant=job.id
    frontier=i
    if part.node then break end
  end
  if frontier==job.index then
    if job.state~="stopped" then stop(job);job.state="stopped" end
    return
  end
  if job.goal~=frontier or job.dx~=dx or job.dy~=dy or not job.animation_goal then
    job.goal,job.dx,job.dy=frontier,dx,dy
    job.position=job.position or {x=unit.position.x,y=unit.position.y}
    job.state,job.started,job.progress_tick="walking",tick,tick
    unit.active=true
    -- A turn starts exactly at the sign center, facing the next leg.
    unit.orientation=dx==1 and 0.25 or dx==-1 and 0.75 or dy==1 and 0.5 or 0
    local animation_goal=frontier
    for i=job.index+1,#route do
      local part,previous=route[i],route[i-1]
      if part.x-previous.x~=dx*2 or part.y-previous.y~=dy*2 then break end
      animation_goal=i
      if part.node then break end
    end
    local command=unit.commandable.command
    if job.animation_goal~=animation_goal or not command or command.type~=defines.command.go_to_location then
      job.animation_goal=animation_goal
      local target=route[animation_goal]
      unit.commandable.set_command{type=defines.command.go_to_location,
        destination={target.x,target.y},radius=0.005,distraction=defines.distraction.none,
        pathfind_flags={prefer_straight_paths=true,cache=false}}
    end
  end
end
function M.on_ai_command_completed(event)
  local st = state()
  local job = st.jobs[st.units[event.unit_number]]
  if not job then return false end
  -- Native completion events can refer to a command just replaced by a
  -- new leg. Position and current command are reconciled by the traffic tick.
  return true
end
function M.on_tick(event)
  local st = state()
  if event.tick%R.DISPATCH_TICKS==0 then
    signals.update(st.records,st.jobs,function(record, rotated)
      local s=surface_state(record.surface_index)
      -- Filter changes invalidate routing, but never alter the paved exits.
      s.revision=s.revision+1
      if rotated then s.dirty=true end
    end)
    multisign_gui.refresh_all(st.records)
  end
  for index,s in pairs(st.surfaces) do
    if s.dirty and game.surfaces[index] then pavement.refresh(s, game.surfaces[index], clear_block) end
  end
  -- Physical traffic is indexed once per tick; updates preserve admission order.
  local index=traffic.new(st.jobs)
  for _,id in ipairs(st.job_order) do if st.jobs[id] then update_job(st.jobs[id],event.tick,index) end end
  if event.tick%R.DISPATCH_TICKS==0 then
    local order = {}
    for _, id in ipairs(st.job_order) do if st.jobs[id] then order[#order + 1] = id end end
    st.job_order = order
    local inputs = {}
    for id in pairs(st.inputs) do inputs[#inputs + 1] = id end
    table.sort(inputs)
    for _, id in ipairs(inputs) do
      local record = st.inputs[id]
      if valid(record.entity) then record.entity.active = false; dispatch(record, event.tick, index)
      else remove_record(id) end
    end
  end
end
function M.rebuild()
  local st = state()
  if not prototypes.entity[R.INPUT] then return end
  for _,force in pairs(game.forces) do
    if force.recipes[R.ROAD] then force.recipes[R.ROAD].enabled=false end
  end
  -- Saved jobs/reservations/escrow survive load and configuration changes.
  -- Only previously unregistered infrastructure is discovered here.
  for _, surface in pairs(game.surfaces) do
    for _, entity in ipairs(surface.find_entities_filtered{name = R.names}) do M.on_built{entity = entity} end
  end
  local legacy = {}
  for id,record in pairs(st.records) do if record.role == "road" then legacy[#legacy+1]=id end end
  for _,id in ipairs(legacy) do
    local record=st.records[id]
    local cell=st.surfaces[record.surface_index].cells[record.key]
    st.watches[record.watch]=nil
    st.records[id]=nil
    if cell then cell.road=nil end
    if valid(record.entity) then record.entity.destroy() end
  end
  for _,s in pairs(st.surfaces) do
    s.dirty=true
    for _,cell in pairs(s.cells) do cell.flow_refs=0;cell.flow=nil end
  end
  for _,job in pairs(st.jobs) do
    for i,cell in ipairs(job.route or {}) do
      if job.route[i+1] and not (i==1 and job.released_start) then cell.flow_refs=cell.flow_refs+1;cell.flow=job.route[i+1].key end
    end
    for i,cell in ipairs(job.departure or {}) do
      if job.departure[i+1] then cell.flow_refs=cell.flow_refs+1;cell.flow=job.departure[i+1].key end
    end
    for _,tail in ipairs(job.trailing or {}) do
      for i,cell in ipairs(tail) do if tail[i+1] then cell.flow_refs=cell.flow_refs+1;cell.flow=tail[i+1].key end end
    end
  end
  for _,job in pairs(st.jobs) do
    job.goal=nil
    job.animation_goal=nil
    if valid(job.entity) then job.entity.speed=job.entity.prototype.speed * R.speed_multiplier(job.entity.force) end
  end
  -- A removed cargo permission must return existing saved items safely, even
  -- when Factorio has already removed their obsolete walking prototype.
  local excluded = {}
  for _, job in pairs(st.jobs) do
    if job.cargo[1].valid_for_read and not R.cargo[job.cargo[1].name] then excluded[#excluded + 1] = job end
  end
  for _, job in ipairs(excluded) do recover(job, "cargo-no-longer-supported") end
end
function M.on_pre_surface_removed(event)
  local st = state()
  st.evacuating[event.surface_index] = true
  local affected = {}
  for _, job in pairs(st.jobs) do
    if job.surface_index == event.surface_index then affected[#affected + 1] = job end
  end
  for _, job in ipairs(affected) do job.surface_lost = true; recover(job) end
end
function M.on_surface_removed(event)
  local st = state()
  for id, record in pairs(st.records) do
    if record.surface_index == event.surface_index then
      st.watches[record.watch] = nil
      st.records[id], st.inputs[id] = nil, nil
    end
  end
  st.surfaces[event.surface_index] = nil
  st.evacuating[event.surface_index] = nil
end
function M.on_forces_merged(event)
  local st = state()
  for _, s in pairs(st.surfaces) do
    s.revision = s.revision + 1
  s.dirty = true
    for _, cell in pairs(s.cells) do
      if cell.force_index == event.source_index then cell.force_index = event.destination.index end
    end
  end
  for _,record in pairs(st.records) do
    if valid(record.entity) then
      for _,port in pairs(record.ports or {}) do if port.valid then port.force=record.entity.force end end
    end
  end
  for _, job in pairs(st.jobs) do
    if job.force_index == event.source_index then job.force_index = event.destination.index end
  end
end
function M.inspect_signals()
  local result={}
  for id,record in pairs(state().records) do
    if valid(record.entity) and (record.entity.name==R.MULTISIGN or record.entity.name==R.SIGN) then
      result[#result+1]={id=id,entity=record.entity,ports=record.ports,filters=record.filters,
        configuration=record.entity.name==R.MULTISIGN and signals.configuration(record) or nil}
    end
  end
  return result
end
function M.inspect()
  local result = {}
  for id, job in pairs(state().jobs) do
    local current = job.route and job.route[job.index]
    local next_cell = job.route and job.route[job.index + 1]
    result[#result + 1] = {id = id, state = job.state, index = job.index, surface_index = job.surface_index,
      item = job.cargo[1].valid_for_read and job.cargo[1].name,
      position = valid(job.entity) and job.entity.position,
      current = current and {key = current.key, occupant = current.occupant},
      next_cell = next_cell and {key = next_cell.key, occupant = next_cell.occupant},
      started = job.started, failures = job.failures, lane_position=job.position,
      goal=job.goal, speed=valid(job.entity) and job.entity.speed,
      orientation=valid(job.entity) and job.entity.orientation}
    result[#result].recovery_reason = job.recovery_reason
    result[#result].briefing = briefing_overlay.inspect(job)
  end
  return result
end
return M
