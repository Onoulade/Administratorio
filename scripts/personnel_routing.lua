local R = require("prototypes.shared.personnel_routing")
local graph = require("scripts.personnel_route_graph")
local pavement = require("scripts.personnel_pavement")
local ai = require("scripts.unit_ai_settings")
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
    if surface.get_tile(x, y).name ~= R.TILE then return false end
  end end
  return true
end
local function clear_block(surface, cell)
  for _, other in ipairs(surface.find_entities_filtered{area = {{cell.x-0.99, cell.y-0.99}, {cell.x+0.99, cell.y+0.99}}}) do
    if not R.roles[other.name] and not R.passable_types[other.type] then
      local box = other.bounding_box
      if box.left_top.x < box.right_bottom.x and box.left_top.y < box.right_bottom.y then return false end
    end
  end
  return true
end
local function lock_entity(record, locked)
  if record and valid(record.entity) then
    record.entity.minable_flag = not locked
    record.entity.rotatable = not locked and record.role ~= "road"
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
    cell.flow = route[i + 1] and route[i + 1].key or "arrival"
    lock_cell(cell)
  end
end
local function release_route(job)
  for _, cell in ipairs(job.route or {}) do
    if cell.occupant == job.id then cell.occupant = nil end
    cell.refs = math.max(0, (cell.refs or 0) - 1)
    if job.route.serial then cell.serial_refs = math.max(0, (cell.serial_refs or 0) - 1) end
    if cell.refs == 0 then cell.flow = nil end
    lock_cell(cell)
  end
  local s=surface_state(job.surface_index)
  if s.deferred then s.dirty=true end
  job.route = nil
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
  st.records[id], st.inputs[id] = nil, nil
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
    for _, job in pairs(st.jobs) do
      for _, used in ipairs(job.route or {}) do
        if used == cell then affected[#affected + 1] = job; break end
      end
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
  if state().records[entity.unit_number] then return true end
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
    if entity.surface.get_tile(x, y).collides_with("water_tile") then reject_build(entity, event); return true end
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
  local record = valid(entity) and state().records[entity.unit_number]
  if not record then return end
  local s = surface_state(record.surface_index)
  local cell = s.cells[record.key]
  if (cell.refs or 0) > 0 then entity.direction = event.previous_direction; return end
  s.revision = s.revision + 1
  s.dirty = true
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
end
local function dispatch(record, tick)
  local entity = record.entity
  if not valid(entity) then return end
  local inv = inventory(entity, false)
  local stack = inv and inv[1]
  if not stack or not stack.valid_for_read then status(entity, "empty"); return end
  if not R.cargo[stack.name] or not prototypes.entity[R.unit_name(stack.name)] then status(entity, "invalid-cargo"); return end
  local route = route_for(record)
  if not route or #route < 2 then status(entity, "no-route"); return end
  if route[1].occupant or not graph.compatible(route, surface_state(record.surface_index).cells) then status(entity, "queued"); return end
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
    home = {x = entity.position.x, y = entity.position.y}, retry = tick, failures = 0}
  st.jobs[id] = job
  st.job_order[#st.job_order + 1] = id
  st.units[unit.unit_number] = id
  job.watch = watch(unit, "job", id)
  reserve_route(route)
  route[1].occupant = id
  unit.destructible = false
  unit.minable_flag = false
  ai.apply_managed_unit_settings(unit)
  stop(job)
  briefing_overlay.update(job, tick)
  status(entity, "running", true)
end
-- Deterministic lane motion with a native walking proxy. Commands keep its
-- walking animation active; saved lane positions own actual traffic movement.
local function update_job(job, tick)
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
    local distance = math.min(step,math.max(0,remaining))
    p = {x=p.x+dx*distance,y=p.y+dy*distance}
    if dx~=0 then p.y=cell.y else p.x=cell.x end
    local arrived = remaining<=step
    if arrived then p={x=goal.x,y=goal.y} end
    if not unit.teleport(p) then recover(job,"teleport");return end
    unit.orientation=dx==1 and 0.25 or dx==-1 and 0.75 or dy==1 and 0.5 or 0
    job.position=p
    while next_cell and job.index<job.goal
      and (p.x-next_cell.x)*dx+(p.y-next_cell.y)*dy >= -1/256 do
      local tail=route[job.index-1]
      if tail and tail.occupant==job.id then tail.occupant=nil end
      job.index=job.index+1
      cell,next_cell=route[job.index],route[job.index+1]
      job.progress_tick=tick
    end
    if arrived then job.goal=nil; job.state="waiting"
    elseif tick-(job.progress_tick or tick)>=R.STALL_TICKS then recover(job,"stall"); return end
  end
  if not next_cell then
    if job.state~="stopped" then stop(job);job.state="stopped" end
    local destination=cell.node and cell.node.entity
    if not valid(destination) then recover(job);return end
    if finish(job,inventory(destination,true)) then status(destination,"received",true)
    else status(destination,"output-full") end
    return
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
    if part.occupant and part.occupant~=job.id then break end
    -- Surface queries occur only when first claiming a block, not each tick.
    if part.occupant~=job.id then
      if not paved(unit.surface,part) then recover(job,"pavement-removed");return end
      if not clear_block(unit.surface,part) then recover(job,"obstruction");return end
    end
    part.occupant=job.id
    frontier=i
    if part.node then break end
  end
  if frontier==job.index then
    if job.state~="stopped" then stop(job);job.state="stopped" end
    return
  end
  if job.goal~=frontier or job.dx~=dx or job.dy~=dy then
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
  for index,s in pairs(st.surfaces) do
    if s.dirty and game.surfaces[index] then pavement.refresh(s, game.surfaces[index], clear_block) end
  end
  -- Jobs are ordered by admission, giving merges deterministic FIFO priority.
  for _, id in ipairs(st.job_order) do if st.jobs[id] then update_job(st.jobs[id], event.tick) end end
  if event.tick % R.RETRY_TICKS ~= 0 then return end
  local order = {}
  for _, id in ipairs(st.job_order) do if st.jobs[id] then order[#order + 1] = id end end
  st.job_order = order
  local inputs = {}
  for id in pairs(st.inputs) do inputs[#inputs + 1] = id end
  table.sort(inputs)
  for _, id in ipairs(inputs) do
    local record = st.inputs[id]
    if valid(record.entity) then record.entity.active = false; dispatch(record, event.tick)
    else remove_record(id) end
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
  for _,s in pairs(st.surfaces) do s.dirty=true end
  for _,job in pairs(st.jobs) do
    job.goal=nil
    job.animation_goal=nil
    if valid(job.entity) then job.entity.speed=job.entity.prototype.speed end
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
  for _, job in pairs(st.jobs) do
    if job.force_index == event.source_index then job.force_index = event.destination.index end
  end
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
