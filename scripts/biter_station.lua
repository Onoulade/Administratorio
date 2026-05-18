local C = require("scripts.constants")
local working_hours = require("scripts.working_hours")

local M = {}

local WORKER_FORCE_NAME = "administratorio-biters"
local STATION_NAME = "biter-station"
local COFFEE_INPUT_NAME = "biter-station-coffee-input"
local WALL_BLOCKER_NAME = "biter-station-wall-blocker"
local WORKER_ITEM_NAME = "biter-worker"
local MONEY_ITEM_NAME = "taxpayer-money"
local COFFEE_FLUID_NAME = "liquid-coffee"
local WORKER_ENTITY_NAME = "small-biter"
local STATION_WALL_OFFSETS = {
  {x = -2, y = -2}, {x = -1, y = -2}, {x = 1, y = -2}, {x = 2, y = -2},
  {x = -2, y = -1}, {x = 2, y = -1},
  {x = -2, y = 1}, {x = 2, y = 1},
  {x = -2, y = 2}, {x = -1, y = 2}, {x = 1, y = 2}, {x = 2, y = 2},
}
local STATION_INTERIOR_SPAWN_OFFSET = {x = 0, y = 0}

local function get_station_slots_for_force(force)
  return C.BITER_STATION_BASE_SLOTS
end

local get_station_inventory

local function apply_station_inventory(station)
  local inv = get_station_inventory(station)
  if not inv then return end
  local target = get_station_slots_for_force(station.force)
  if #inv < target then
    inv.resize(target)
  end
  if inv.set_filter and inv.supports_filters and inv.supports_filters() then
    inv.set_filter(1, {name = MONEY_ITEM_NAME})
    for i = 2, #inv do
      inv.set_filter(i, {name = WORKER_ITEM_NAME})
    end
  end
end

local function get_crafts_tier()
  local crafts = storage and storage.biter_station_crafts_per_visit or C.BITER_STATION_CRAFTS_PER_VISIT
  if crafts >= 5 then return 3
  elseif crafts >= 3 then return 2
  else return 1 end
end

local function get_worker_entity_name()
  local tier = get_crafts_tier()
  if tier == 3 then return "biter-worker-t3"
  elseif tier == 2 then return "biter-worker-t2"
  else return WORKER_ENTITY_NAME end
end

local function get_dispatch_salary()
  return get_crafts_tier()
end
local MIN_PHASE_TRAVEL_DISTANCE = 0.75
local PHASE_STUCK_TIMEOUT_TICKS = 90
local ABANDON_STUCK_TICKS = 1800
local PROGRESS_DISTANCE_SQUARED = 1.0

local maybe_reinsert_worker

local function mark_station_worker_unit(unit_number, station_id)
  if not unit_number then return end
  storage.biter_station_worker_units = storage.biter_station_worker_units or {}
  storage.biter_station_worker_units[unit_number] = station_id or true
end

local function unmark_station_worker_unit(unit_number)
  if not unit_number or not storage.biter_station_worker_units then return end
  storage.biter_station_worker_units[unit_number] = nil
end

local function detach_station_worker_from_waiting_system(unit_number)
  if not unit_number then return false end
  local detached = false

  local waiting = storage.waiting_biters
  local info = waiting and waiting[unit_number] or nil
  if info then
    detached = true
    if storage.waiting_biters_by_state and info.state and storage.waiting_biters_by_state[info.state] then
      storage.waiting_biters_by_state[info.state][unit_number] = nil
    end
    waiting[unit_number] = nil
  end

  if storage.desk_biters then
    for _, set in pairs(storage.desk_biters) do
      if set and set[unit_number] then
        set[unit_number] = nil
        detached = true
      end
    end
  end

  if storage.desk_grid_slots then
    for _, slots in pairs(storage.desk_grid_slots) do
      if slots then
        for slot_idx, occupant in pairs(slots) do
          if occupant == unit_number then
            slots[slot_idx] = nil
            detached = true
          end
        end
      end
    end
  end

  return detached
end

local function sanitize_station_worker_registry_links()
  if not storage.biter_station_worker_units then return end
  for unit_number in pairs(storage.biter_station_worker_units) do
    detach_station_worker_from_waiting_system(unit_number)
  end
end

local function ensure_worker_force()
  local force = game.forces[WORKER_FORCE_NAME]
  if not force then
    force = game.create_force(WORKER_FORCE_NAME)
  end
  if not force then return nil end

  local player = game.forces["player"]
  if player then
    force.set_cease_fire(player, true)
    player.set_cease_fire(force, true)
  end

  local enemy = game.forces["enemy"]
  if enemy then
    force.set_cease_fire(enemy, true)
    enemy.set_cease_fire(force, true)
  end

  local neutral = game.forces["neutral"]
  if neutral then
    force.set_cease_fire(neutral, true)
    neutral.set_cease_fire(force, true)
  end

  return force
end

local function get_biter_force()
  -- Reuse the same non-enemy biter force as the rest of the mod.
  -- This avoids engine/AI edge cases from spawning workers on "enemy".
  local force = ensure_worker_force()
  if force and force.valid and force.name ~= "enemy" then
    return force
  end
  return game.forces["player"] or game.forces["neutral"]
end

get_station_inventory = function(station)
  if not station or not station.valid then return nil end
  return station.get_inventory(defines.inventory.chest)
end

local function rotate_local_offset(offset, direction)
  direction = direction or defines.direction.north
  if direction == defines.direction.east then
    return {x = -offset.y, y = offset.x}
  elseif direction == defines.direction.south then
    return {x = -offset.x, y = -offset.y}
  elseif direction == defines.direction.west then
    return {x = offset.y, y = -offset.x}
  end
  return {x = offset.x, y = offset.y}
end

local function offset_position(entity, offset)
  local position = entity and entity.position or {x = 0, y = 0}
  return {x = position.x + offset.x, y = position.y + offset.y}
end

local function hidden_coffee_input_position(entity)
  return entity and entity.position or {x = 0, y = 0}
end

local function station_interior_position(station)
  return offset_position(station, STATION_INTERIOR_SPAWN_OFFSET)
end

local function station_blocker_area(station)
  local pos = station and station.position or {x = 0, y = 0}
  return {
    {x = pos.x - 2.5, y = pos.y - 2.5},
    {x = pos.x + 2.5, y = pos.y + 2.5},
  }
end

local function destroy_wall_blockers(station)
  if not station or not station.valid then return end
  local blockers = station.surface.find_entities_filtered{
    name = WALL_BLOCKER_NAME,
    area = station_blocker_area(station),
  }
  for _, blocker in ipairs(blockers) do
    if blocker.valid then blocker.destroy() end
  end
end

local function create_wall_blockers(station)
  if not station or not station.valid then return end
  destroy_wall_blockers(station)
  for _, offset in ipairs(STATION_WALL_OFFSETS) do
    local blocker = station.surface.create_entity{
      name = WALL_BLOCKER_NAME,
      position = offset_position(station, offset),
      force = station.force,
      create_build_effect_smoke = false,
    }
    if blocker and blocker.valid then
      blocker.destructible = false
      blocker.minable = false
      blocker.operable = false
    end
  end
end

local function create_hidden_coffee_input(station)
  if not station or not station.valid or not station.unit_number then return nil end
  storage.biter_station_coffee_inputs = storage.biter_station_coffee_inputs or {}
  local input = storage.biter_station_coffee_inputs[station.unit_number]
  if input and input.valid then
    return input
  end

  local created = station.surface.create_entity{
    name = COFFEE_INPUT_NAME,
    position = hidden_coffee_input_position(station),
    direction = defines.direction.north,
    force = station.force,
    create_build_effect_smoke = false,
  }
  if created and created.valid then
    created.destructible = false
    created.minable = false
    created.operable = false
    storage.biter_station_coffee_inputs[station.unit_number] = created
  end
  return created
end

local function destroy_hidden_coffee_input(station_id)
  local input = storage.biter_station_coffee_inputs and storage.biter_station_coffee_inputs[station_id]
  if input and input.valid then
    input.destroy()
  end
  if storage.biter_station_coffee_inputs then
    storage.biter_station_coffee_inputs[station_id] = nil
  end
end

local function dispatch_requires_coffee(station)
  return station and station.valid
    and working_hours.is_enabled()
    and working_hours.is_night(station.surface)
end

local function available_dispatch_coffee(station)
  if not dispatch_requires_coffee(station) then
    return math.huge
  end

  local input = create_hidden_coffee_input(station)
  local fluidbox = input and input.valid and input.fluidbox
  local fluid = fluidbox and fluidbox[1] or nil
  if fluid and fluid.name == COFFEE_FLUID_NAME then
    return fluid.amount or 0
  end
  return 0
end

local function has_dispatch_coffee(station)
  return available_dispatch_coffee(station) >= C.BITER_STATION_NIGHT_COFFEE_PER_DISPATCH
end

local function remove_dispatch_coffee(station)
  if not dispatch_requires_coffee(station) then
    return true
  end

  local input = create_hidden_coffee_input(station)
  if not input or not input.valid or not input.remove_fluid then
    return false
  end

  local ok, removed = pcall(input.remove_fluid, {
    name = COFFEE_FLUID_NAME,
    amount = C.BITER_STATION_NIGHT_COFFEE_PER_DISPATCH,
  })
  return ok and (removed or 0) >= C.BITER_STATION_NIGHT_COFFEE_PER_DISPATCH
end

local function destroy_overlay(active_state)
  if not active_state or not active_state.overlay_id then return end
  local object = rendering.get_object_by_id(active_state.overlay_id)
  if object then
    object.destroy()
  end
  active_state.overlay_id = nil
end

local function create_worker_overlay(biter)
  if not biter or not biter.valid then return nil end
  local render_obj = rendering.draw_text{
    text = {"gui.biter-station-calling"},
    surface = biter.surface,
    target = {entity = biter, offset = {0, -1.8}},
    color = {r = 0.9, g = 0.85, b = 0.5},
    alignment = "center",
    vertical_alignment = "middle",
    scale = 1.0,
    scale_with_zoom = true,
  }
  return render_obj and render_obj.id or nil
end

local function apply_machine_tint(biter)
  if not biter or not biter.valid then return end
  biter.color = {r = 1.0, g = 0.55, b = 0.1}
end

local function set_station_status(station, key)
  if not station or not station.valid then return end

  if key == "biter-station-calling" then
    station.custom_status = {
      diode = defines.entity_status_diode.yellow,
      label = {"gui." .. key},
    }
  elseif key == "biter-station-no-workers"
      or key == "biter-station-no-money"
      or key == "biter-station-no-coffee" then
    station.custom_status = {
      diode = defines.entity_status_diode.red,
      label = {"gui." .. key},
    }
  else
    station.custom_status = {
      diode = defines.entity_status_diode.green,
      label = {"gui.biter-station-idle"},
    }
  end
end

local function has_station_inputs(station)
  local inv = get_station_inventory(station)
  if not inv then return false, false, false end

  local has_worker = inv.get_item_count(WORKER_ITEM_NAME) > 0
  local has_money = inv.get_item_count(MONEY_ITEM_NAME) >= get_dispatch_salary()
  local has_coffee = has_dispatch_coffee(station)
  return has_worker, has_money, has_coffee
end

local function station_has_active_workers(station_id)
  local station_map = storage.biter_station_active_by_station and storage.biter_station_active_by_station[station_id]
  return station_map and next(station_map) ~= nil or false
end

local function refresh_station_status(station)
  if not station or not station.valid then return end

  station.minable = not station_has_active_workers(station.unit_number)

  if station_has_active_workers(station.unit_number) then
    set_station_status(station, "biter-station-calling")
    return
  end

  local has_worker, has_money, has_coffee = has_station_inputs(station)
  if not has_worker then
    set_station_status(station, "biter-station-no-workers")
  elseif not has_money then
    set_station_status(station, "biter-station-no-money")
  elseif not has_coffee then
    set_station_status(station, "biter-station-no-coffee")
  else
    set_station_status(station, "biter-station-idle")
  end
end

local function register_active_biter_state(active_state)
  if not active_state or not active_state.biter_unit_number then return end
  storage.biter_station_biter[active_state.biter_unit_number] = active_state
  local station_id = active_state.station_id
  if station_id then
    storage.biter_station_active_by_station[station_id] = storage.biter_station_active_by_station[station_id] or {}
    storage.biter_station_active_by_station[station_id][active_state.biter_unit_number] = true
  end
end

local function unregister_active_biter_state(active_state)
  if not active_state then return end
  local biter_unit_number = active_state.biter_unit_number
  if biter_unit_number then
    storage.biter_station_biter[biter_unit_number] = nil
  end
  local station_id = active_state.station_id
  if station_id and storage.biter_station_active_by_station then
    local station_map = storage.biter_station_active_by_station[station_id]
    if station_map and biter_unit_number then
      station_map[biter_unit_number] = nil
      if not next(station_map) then
        storage.biter_station_active_by_station[station_id] = nil
      end
    end
  end
end

local function normalize_active_biter_storage()
  storage.biter_station_biter = storage.biter_station_biter or {}
  storage.biter_station_active_by_station = storage.biter_station_active_by_station or {}

  local normalized = {}
  local by_station = {}
  for key, state in pairs(storage.biter_station_biter) do
    if state and type(state) == "table" then
      local unit = state.biter_unit_number
      if not unit and state.biter and state.biter.valid then
        unit = state.biter.unit_number
      end
      if not unit then
        unit = tonumber(key) or key
      end
      state.biter_unit_number = unit
      normalized[unit] = state

      local station_id = state.station_id
      if not station_id and type(key) == "number" and storage.biter_stations and storage.biter_stations[key] then
        station_id = key
        state.station_id = station_id
      end
      if station_id then
        by_station[station_id] = by_station[station_id] or {}
        by_station[station_id][unit] = true
      end
    end
  end

  storage.biter_station_biter = normalized
  storage.biter_station_active_by_station = by_station
end

local function distance_squared(pos1, pos2)
  local dx = pos1.x - pos2.x
  local dy = pos1.y - pos2.y
  return dx * dx + dy * dy
end

local function has_arrived(entity, target, radius)
  if not entity or not entity.valid or not target or not target.valid then return false end
  local threshold = (radius or 0) + 0.5
  return distance_squared(entity.position, target.position) < threshold * threshold
end

local function has_arrived_position(entity, target_position, radius)
  if not entity or not entity.valid or not target_position then return false end
  local threshold = (radius or 0) + 0.5
  return distance_squared(entity.position, target_position) < threshold * threshold
end

local function phase_origin_distance_squared(active_state, biter)
  if not active_state or not active_state.phase_origin or not biter or not biter.valid then
    return 0
  end
  return distance_squared(active_state.phase_origin, biter.position)
end

local function phase_has_departed(active_state, biter, tick)
  if not active_state or not biter or not biter.valid then return false end
  if active_state.phase_departed then return true end

  if phase_origin_distance_squared(active_state, biter) >= (MIN_PHASE_TRAVEL_DISTANCE * MIN_PHASE_TRAVEL_DISTANCE) then
    active_state.phase_departed = true
    return true
  end

  local started_tick = active_state.phase_started_tick or tick
  if (tick - started_tick) >= PHASE_STUCK_TIMEOUT_TICKS then
    active_state.phase_departed = true
    return true
  end

  return false
end

local function clear_pending_path_request(active_state)
  if not active_state then return end
  active_state.path_request_id = nil
  active_state.path_points = nil
  active_state.path_index = nil
  active_state.path_destination = nil
end

local function resolve_destination_position(destination)
  if not destination then return nil end
  if destination.valid and destination.position then
    return destination.position
  end
  if destination.x and destination.y then
    return destination
  end
  return nil
end

local function clamp(value, min_value, max_value)
  if value < min_value then return min_value end
  if value > max_value then return max_value end
  return value
end

local function resolve_command_destination(biter, destination, radius)
  local target_position = resolve_destination_position(destination)
  if not target_position then return nil end
  if not biter or not biter.valid then return target_position end

  if destination and destination.valid and destination.bounding_box then
    local box = destination.bounding_box
    local from = biter.position
    local pad = math.max(0.75, (radius or C.BITER_STATION_ARRIVAL_RADIUS) * 0.5)
    local left = box.left_top.x - pad
    local right = box.right_bottom.x + pad
    local top = box.left_top.y - pad
    local bottom = box.right_bottom.y + pad

    local px = clamp(from.x, left, right)
    local py = clamp(from.y, top, bottom)

    if from.x >= left and from.x <= right and from.y >= top and from.y <= bottom then
      local d_left = math.abs(from.x - left)
      local d_right = math.abs(right - from.x)
      local d_top = math.abs(from.y - top)
      local d_bottom = math.abs(bottom - from.y)
      local best_side = math.min(d_left, d_right, d_top, d_bottom)
      if best_side == d_left then
        px = left
      elseif best_side == d_right then
        px = right
      elseif best_side == d_top then
        py = top
      else
        py = bottom
      end
    end

    local mid_x = (left + right) * 0.5
    local mid_y = (top + bottom) * 0.5
    local candidates = {
      {x = px, y = py},
      {x = left, y = mid_y},
      {x = right, y = mid_y},
      {x = mid_x, y = top},
      {x = mid_x, y = bottom},
      {x = left, y = top},
      {x = right, y = top},
      {x = left, y = bottom},
      {x = right, y = bottom},
    }

    local best_pos = nil
    local best_dist = math.huge
    for _, candidate in ipairs(candidates) do
      local approach = biter.surface.find_non_colliding_position(
        biter.name,
        candidate,
        1.0,
        0.25
      )
      if approach then
        local dist = distance_squared(from, approach)
        if dist < best_dist then
          best_dist = dist
          best_pos = approach
        end
      end
    end
    if best_pos then
      return best_pos
    end

    local fallback = biter.surface.find_non_colliding_position(
      WORKER_ENTITY_NAME,
      target_position,
      math.max(2.0, (radius or C.BITER_STATION_ARRIVAL_RADIUS) + 2.0),
      0.25
    )
    if fallback then
      return fallback
    end
  end

  return target_position
end

local function issue_move_command(biter, destination, radius)
  if not biter or not biter.valid or not destination or not biter.commandable then return false end
  biter.force = get_biter_force()
  biter.active = true
  biter.commandable.set_command({
    type = defines.command.go_to_location,
    destination = destination,
    radius = radius or C.BITER_STATION_ARRIVAL_RADIUS,
    distraction = defines.distraction.none,
  })
  return true
end

local function begin_phase_move(active_state, biter, phase, destination, radius, tick)
  if not active_state or not biter or not biter.valid then return end
  local target_position = resolve_destination_position(destination)
  if not target_position then return end
  local command_destination = resolve_command_destination(biter, destination, radius)
  if not command_destination then return end

  active_state.phase = phase
  active_state.phase_started_tick = tick or game.tick
  active_state.phase_origin = {x = biter.position.x, y = biter.position.y}
  active_state.phase_departed = false
  active_state.phase_target_position = {x = target_position.x, y = target_position.y}
  active_state.phase_target_unit_number = destination and destination.valid and destination.unit_number or nil
  active_state.phase_destination = {x = command_destination.x, y = command_destination.y}
  active_state.phase_radius = radius
  active_state.phase_command_radius = math.max(0.5, (radius or 0) * 0.5)
  active_state.phase_arrived_tick = nil
  active_state.last_progress_tick = tick or game.tick
  active_state.last_progress_position = {x = biter.position.x, y = biter.position.y}
  clear_pending_path_request(active_state)
  issue_move_command(biter, command_destination, active_state.phase_command_radius)
end

local function check_and_update_progress(active_state, biter, tick)
  if not active_state or not biter or not biter.valid then return false end
  local last_pos = active_state.last_progress_position
  if not last_pos then
    active_state.last_progress_position = {x = biter.position.x, y = biter.position.y}
    active_state.last_progress_tick = tick
    return false
  end
  if distance_squared(biter.position, last_pos) >= PROGRESS_DISTANCE_SQUARED then
    active_state.last_progress_position = {x = biter.position.x, y = biter.position.y}
    active_state.last_progress_tick = tick
    return false
  end
  local since = tick - (active_state.last_progress_tick or tick)
  return since >= ABANDON_STUCK_TICKS
end

local function phase_is_arrived(active_state, biter, fallback_position, fallback_radius)
  if not active_state or not biter or not biter.valid then return false end
  if active_state.phase_arrived_tick then
    return true
  end

  local destination = active_state.phase_destination or fallback_position
  if not destination then
    return false
  end

  local radius = active_state.phase_command_radius or active_state.phase_radius or fallback_radius or C.BITER_STATION_ARRIVAL_RADIUS
  return has_arrived_position(biter, destination, radius)
end

local function ensure_run_state(entity)
  local unit_number = entity and entity.unit_number
  if not unit_number then return nil end

  local state = storage.managed_building_run[unit_number]
  if not state then
    state = { entity = entity }
    storage.managed_building_run[unit_number] = state
  else
    state.entity = entity
  end
  return state
end

local function clear_run_state_if_idle(unit_number, state)
  if not unit_number or not state then return end
  local crafts_remaining = state.crafts_remaining or 0
  if crafts_remaining <= 0 and not state.claimed_by then
    storage.managed_building_run[unit_number] = nil
  end
end

local function clear_building_claim(unit_number, biter_unit_number)
  if not unit_number then return end

  local state = storage.managed_building_run[unit_number]
  if not state then return end

  if not biter_unit_number or state.claimed_by == biter_unit_number then
    state.claimed_by = nil
  end
  clear_run_state_if_idle(unit_number, state)
end

local function clear_active_queue_claims(active_state)
  if not active_state or not active_state.building_queue then return end

  local biter_unit_number = active_state.biter_unit_number
  if not biter_unit_number and active_state.biter and active_state.biter.valid then
    biter_unit_number = active_state.biter.unit_number
  end
  for _, building in ipairs(active_state.building_queue) do
    if building and building.unit_number then
      clear_building_claim(building.unit_number, biter_unit_number)
    end
  end
end

local function release_biter_for_despawn(biter, station, tick)
  if not biter or not biter.valid then return end

  if station and station.valid then
    local despawn_origin = station_interior_position(station)
    local despawn_pos = station.surface.find_non_colliding_position(biter.name, despawn_origin, 1, 0.25)
    issue_move_command(biter, despawn_pos or despawn_origin, C.BITER_STATION_ARRIVAL_RADIUS)
  end

  storage.biter_station_releasing[biter.unit_number] = {
    entity = biter,
    station = station,
    despawn_tick = tick + C.BITER_STATION_BITER_DESPAWN_TICKS,
  }
end

local function cleanup_active_biter(active_state, tick, release_entity, reason)
  if not active_state then
    return
  end
  local station_id = active_state.station_id

  clear_active_queue_claims(active_state)
  destroy_overlay(active_state)
  unmark_station_worker_unit(active_state.biter_unit_number)
  clear_pending_path_request(active_state)

  if reason == "biter-invalid" or reason == "stuck" then
    local station = storage.biter_stations and storage.biter_stations[station_id] or nil
    if station and station.valid then
      maybe_reinsert_worker(station)
    end
  end

  if active_state.biter and active_state.biter.valid then
    if release_entity then
      local station = storage.biter_stations and storage.biter_stations[station_id] or nil
      release_biter_for_despawn(active_state.biter, station, tick)
    else
      active_state.biter.destroy()
    end
  end

  unregister_active_biter_state(active_state)
end

local function is_building_blocked_by_working_hours(building)
  if not building or not building.valid or not building.unit_number then
    return false
  end

  if working_hours.is_enabled() and working_hours.is_managed_entity(building) then
    working_hours.refresh_entity(building)
  end

  local wh_state = storage.working_hours_state and storage.working_hours_state[building.unit_number]
  return wh_state and wh_state.reason ~= nil or false
end

local function building_has_recipe(building)
  if not building or not building.valid or not building.get_recipe then
    return false
  end
  return building.get_recipe() ~= nil
end

local function get_recipe_name(recipe)
  return recipe and recipe.name or nil
end

local function get_entity_crafting_progress(entity)
  local progress = entity and entity.crafting_progress
  if type(progress) == "number" then
    return progress
  end
  return nil
end

local function activate_building_for_visit(building, biter_unit_number)
  if not building or not building.valid or not building.unit_number then
    return false
  end
  local recipe = building.get_recipe and building.get_recipe() or nil
  if not recipe then
    return false
  end

  local unit_number = building.unit_number
  local run_state = ensure_run_state(building)
  if not run_state then return false end

  if run_state.claimed_by and run_state.claimed_by ~= biter_unit_number then
    return false
  end

  if is_building_blocked_by_working_hours(building) then
    run_state.claimed_by = nil
    clear_run_state_if_idle(unit_number, run_state)
    return false
  end

  local crafts_remaining = run_state.crafts_remaining or 0
  if crafts_remaining > 0 then
    run_state.claimed_by = nil
    return false
  end

  building.active = true
  run_state.crafts_remaining = 1
  run_state.products_at_last_check = building.products_finished or 0
  run_state.recipe_name = get_recipe_name(recipe)
  run_state.crafting_progress_at_last_check = get_entity_crafting_progress(building)
  run_state.claimed_by = nil
  return true
end

local function is_station_in_range_of_building(station, building)
  if not station or not station.valid or not building or not building.valid then
    return false
  end
  if station.surface ~= building.surface or station.force ~= building.force then
    return false
  end
  return distance_squared(station.position, building.position) <= (C.BITER_STATION_RANGE * C.BITER_STATION_RANGE)
end

local function station_is_preferred_for_building(station, building)
  if not station or not station.valid or not station.unit_number then return false end
  if not is_station_in_range_of_building(station, building) then return false end

  local station_distance = distance_squared(station.position, building.position)
  for other_id, other_station in pairs(storage.biter_stations or {}) do
    if other_id ~= station.unit_number and is_station_in_range_of_building(other_station, building) then
      local other_distance = distance_squared(other_station.position, building.position)
      if other_distance < station_distance
         or (other_distance == station_distance and other_station.unit_number < station.unit_number) then
        return false
      end
    end
  end
  return true
end

local function build_building_queue(station)
  if not station or not station.valid then return {} end

  local nearby = station.surface.find_entities_filtered{
    name = C.BITER_STATION_MANAGED_BUILDINGS,
    position = station.position,
    radius = C.BITER_STATION_RANGE,
  }

  local filtered = {}
  for _, building in ipairs(nearby) do
    if building.valid
       and building.unit_number
       and building.force
       and building.force == station.force then
      storage.managed_building_registry[building.unit_number] = building

      local run_state = storage.managed_building_run[building.unit_number]
      local is_running = run_state and (run_state.crafts_remaining or 0) > 0
      local is_claimed = run_state and run_state.claimed_by ~= nil
      local is_blocked = is_building_blocked_by_working_hours(building)
      local has_recipe = building_has_recipe(building)
      local is_preferred_station = station_is_preferred_for_building(station, building)

      if has_recipe and not is_running and not is_claimed and not is_blocked and is_preferred_station then
        filtered[#filtered + 1] = building
      end
    end
  end

  table.sort(filtered, function(a, b)
    return distance_squared(a.position, station.position) < distance_squared(b.position, station.position)
  end)

  return filtered
end

local function spawn_station_biter(station)
  if not station or not station.valid then return nil end

  local actual_entity_name = get_worker_entity_name()
  local spawn_origin = station_interior_position(station)
  local spawn_pos = station.surface.find_non_colliding_position(actual_entity_name, spawn_origin, 1, 0.25)
  if not spawn_pos then
    return nil
  end
  local spawn_force = get_biter_force()
  if not spawn_force or not spawn_force.valid or spawn_force.name == "enemy" then
    spawn_force = station.force or game.forces["player"] or game.forces["neutral"]
  end

  local biter = station.surface.create_entity{
    name = actual_entity_name,
    position = spawn_pos,
    force = spawn_force,
  }

  if not biter or not biter.valid then
    return nil
  end
  if biter.force and biter.force.name == "enemy" then
    local safe_force = station.force or game.forces["player"] or game.forces["neutral"]
    if safe_force and safe_force.valid and safe_force.name ~= "enemy" then
      biter.force = safe_force
    end
  end
  return biter
end

local function refresh_active_biter_snapshot(active_state, biter)
  if not active_state or not biter or not biter.valid then return end
  active_state.worker_entity_name = biter.name
  active_state.worker_surface_index = biter.surface and biter.surface.index or nil
  active_state.worker_last_position = {x = biter.position.x, y = biter.position.y}
end

local function rekey_active_biter_state(active_state, old_unit_number, new_unit_number)
  if not active_state or not old_unit_number or not new_unit_number then return end
  if storage.biter_station_biter then
    storage.biter_station_biter[old_unit_number] = nil
    storage.biter_station_biter[new_unit_number] = active_state
  end
  if storage.biter_station_worker_units then
    local station_marker = storage.biter_station_worker_units[old_unit_number]
    storage.biter_station_worker_units[old_unit_number] = nil
    storage.biter_station_worker_units[new_unit_number] = station_marker or active_state.station_id or true
  end
  local station_id = active_state.station_id
  local station_map = station_id and storage.biter_station_active_by_station and storage.biter_station_active_by_station[station_id]
  if station_map then
    station_map[old_unit_number] = nil
    station_map[new_unit_number] = true
  end
  for _, building in ipairs(active_state.building_queue or {}) do
    local run_state = building and building.unit_number and storage.managed_building_run[building.unit_number]
    if run_state and run_state.claimed_by == old_unit_number then
      run_state.claimed_by = new_unit_number
    end
  end
end

local function recreate_missing_active_biter(active_state, station, tick)
  if not active_state or not game or not game.surfaces then return nil end
  station = station or (active_state.station_id and storage.biter_stations and storage.biter_stations[active_state.station_id])
  local surface = active_state.worker_surface_index and game.surfaces[active_state.worker_surface_index] or nil
  surface = surface or (station and station.valid and station.surface) or nil
  if not surface then return nil end

  local position = active_state.worker_last_position
    or (station and station.valid and station_interior_position(station))
    or nil
  if not position then return nil end

  local entity_name = active_state.worker_entity_name or get_worker_entity_name()
  local spawn_pos = surface.find_non_colliding_position(entity_name, position, 2, 0.25) or position
  local force = get_biter_force()
  if (not force or not force.valid or force.name == "enemy") and station and station.valid then
    force = station.force or game.forces["player"] or game.forces["neutral"]
  end
  local biter = surface.create_entity{
    name = entity_name,
    position = spawn_pos,
    force = force,
    create_build_effect_smoke = false,
  }
  if not biter or not biter.valid then return nil end

  apply_machine_tint(biter)
  destroy_overlay(active_state)
  active_state.overlay_id = create_worker_overlay(biter)
  local old_unit_number = active_state.biter_unit_number
  active_state.biter = biter
  active_state.biter_unit_number = biter.unit_number
  rekey_active_biter_state(active_state, old_unit_number, biter.unit_number)
  refresh_active_biter_snapshot(active_state, biter)
  if active_state.phase_destination then
    issue_move_command(biter, active_state.phase_destination, active_state.phase_command_radius)
    active_state.phase_started_tick = tick or game.tick
    active_state.phase_origin = {x = biter.position.x, y = biter.position.y}
    active_state.phase_arrived_tick = nil
    active_state.last_progress_tick = tick or game.tick
    active_state.last_progress_position = {x = biter.position.x, y = biter.position.y}
  end
  return biter
end

local function claim_queue_for_biter(queue, biter_unit_number)
  for _, building in ipairs(queue) do
    if building and building.valid and building.unit_number then
      local run_state = ensure_run_state(building)
      if run_state then
        run_state.claimed_by = biter_unit_number
      end
    end
  end
end

local function get_enablements_per_trip()
  return math.max(1, storage.biter_station_crafts_per_visit or C.BITER_STATION_CRAFTS_PER_VISIT)
end

maybe_reinsert_worker = function(station)
  local inv = get_station_inventory(station)
  if not inv then return end

  if inv.can_insert({name = WORKER_ITEM_NAME, count = 1}) then
    inv.insert({name = WORKER_ITEM_NAME, count = 1})
  else
    station.surface.spill_item_stack{
      position = station.position,
      stack = {name = WORKER_ITEM_NAME, count = 1},
      enable_looted = false,
      force = station.force,
      allow_belts = false,
    }
  end
end

local function dispatch_single_station_biter(station, queue)
  if not station or not station.valid or not station.unit_number then return false end
  if not queue or #queue == 0 then return false end
  if not has_dispatch_coffee(station) then
    set_station_status(station, "biter-station-no-coffee")
    return false
  end

  local inv = get_station_inventory(station)
  if not inv then
    return false
  end

  if inv.remove({name = WORKER_ITEM_NAME, count = 1}) < 1 then
    return false
  end

  local biter = spawn_station_biter(station)
  if not biter then
    maybe_reinsert_worker(station)
    set_station_status(station, "biter-station-no-workers")
    return false
  end

  local salary_paid = false
  if dispatch_requires_coffee(station) then
    local salary = get_dispatch_salary()
    if inv.remove({name = MONEY_ITEM_NAME, count = salary}) < salary then
      biter.destroy()
      maybe_reinsert_worker(station)
      set_station_status(station, "biter-station-no-money")
      return false
    end
    salary_paid = true
  end

  if not remove_dispatch_coffee(station) then
    if salary_paid then
      inv.insert({name = MONEY_ITEM_NAME, count = get_dispatch_salary()})
    end
    biter.destroy()
    maybe_reinsert_worker(station)
    set_station_status(station, "biter-station-no-coffee")
    return false
  end

  claim_queue_for_biter(queue, biter.unit_number)

  apply_machine_tint(biter)
  local active_state = {
    biter = biter,
    biter_unit_number = biter.unit_number,
    station_id = station.unit_number,
    station = station,
    building_queue = queue,
    current_idx = 1,
    salary_paid = salary_paid,
    overlay_id = create_worker_overlay(biter),
    phase = "to_building",
  }
  refresh_active_biter_snapshot(active_state, biter)
  register_active_biter_state(active_state)
  mark_station_worker_unit(biter.unit_number, station.unit_number)
  detach_station_worker_from_waiting_system(biter.unit_number)
  begin_phase_move(active_state, biter, "to_building", queue[1], C.BITER_STATION_ARRIVAL_RADIUS, game.tick)
  refresh_active_biter_snapshot(active_state, biter)

  set_station_status(station, "biter-station-calling")
  return true
end

local function dispatch_station_biters(station)
  if not station or not station.valid or not station.unit_number then return 0 end

  local inv = get_station_inventory(station)
  if not inv then
    refresh_station_status(station)
    return 0
  end

  local worker_count = inv.get_item_count(WORKER_ITEM_NAME)
  local money_count = inv.get_item_count(MONEY_ITEM_NAME)
  if worker_count <= 0 then
    set_station_status(station, "biter-station-no-workers")
    return 0
  end

  if money_count < C.BITER_STATION_SALARY then
    set_station_status(station, "biter-station-no-money")
    return 0
  end

  local coffee_count = available_dispatch_coffee(station)
  if coffee_count < C.BITER_STATION_NIGHT_COFFEE_PER_DISPATCH then
    set_station_status(station, "biter-station-no-coffee")
    return 0
  end

  local queue = build_building_queue(station)
  if #queue == 0 then
    if station_has_active_workers(station.unit_number) then
      set_station_status(station, "biter-station-calling")
    else
      set_station_status(station, "biter-station-idle")
    end
    return 0
  end

  local enablements_per_trip = get_enablements_per_trip()
  local max_by_money = math.floor(money_count / get_dispatch_salary())
  local max_by_coffee = math.floor(coffee_count / C.BITER_STATION_NIGHT_COFFEE_PER_DISPATCH)
  local needed_workers = math.ceil(#queue / enablements_per_trip)
  local worker_dispatches = math.min(worker_count, max_by_money, max_by_coffee, needed_workers)
  if worker_dispatches <= 0 then
    if max_by_money <= 0 then
      set_station_status(station, "biter-station-no-money")
    else
      set_station_status(station, "biter-station-no-coffee")
    end
    return 0
  end

  local queue_idx = 1
  local dispatched = 0
  for _ = 1, worker_dispatches do
    local worker_queue = {}
    for _ = 1, enablements_per_trip do
      local building = queue[queue_idx]
      if not building then break end
      worker_queue[#worker_queue + 1] = building
      queue_idx = queue_idx + 1
    end
    if #worker_queue == 0 then
      break
    end
    if dispatch_single_station_biter(station, worker_queue) then
      dispatched = dispatched + 1
    else
      break
    end
  end

  if dispatched > 0 then
    set_station_status(station, "biter-station-calling")
  else
    refresh_station_status(station)
  end
  return dispatched
end

local function finish_station_circuit(station_id, station, active_state)
  if station and station.valid then
    local inv = get_station_inventory(station)
    if inv then
      if not active_state.salary_paid then
        inv.remove({name = MONEY_ITEM_NAME, count = get_dispatch_salary()})
      end
      maybe_reinsert_worker(station)
    end
  end

  destroy_overlay(active_state)
  unmark_station_worker_unit(active_state and active_state.biter_unit_number)
  clear_pending_path_request(active_state)

  if active_state.biter and active_state.biter.valid then
    active_state.biter.destroy()
  end

  unregister_active_biter_state(active_state)

  if station and station.valid then
    dispatch_station_biters(station)
    refresh_station_status(station)
  end
end

local function advance_running_buildings()
  for unit_number, run_state in pairs(storage.managed_building_run) do
    local entity = run_state.entity
    if not entity or not entity.valid then
      storage.managed_building_run[unit_number] = nil
    else
      local crafts_remaining = run_state.crafts_remaining or 0
      if crafts_remaining > 0 then
        local recipe = entity.get_recipe and entity.get_recipe() or nil
        if not recipe then
          entity.active = false
          run_state.crafts_remaining = 0
          run_state.recipe_name = nil
          run_state.crafting_progress_at_last_check = nil
          clear_run_state_if_idle(unit_number, run_state)
          goto continue
        end
        if run_state.recipe_name and get_recipe_name(recipe) ~= run_state.recipe_name then
          entity.active = false
          run_state.crafts_remaining = 0
          run_state.recipe_name = nil
          run_state.crafting_progress_at_last_check = nil
          clear_run_state_if_idle(unit_number, run_state)
          goto continue
        end

        local current_products = entity.products_finished or 0
        local previous_products = run_state.products_at_last_check or current_products

        if current_products > previous_products then
          local completed_crafts = current_products - previous_products
          run_state.crafts_remaining = math.max(0, crafts_remaining - completed_crafts)
          run_state.products_at_last_check = current_products
        elseif current_products < previous_products then
          run_state.products_at_last_check = current_products
        end

        local current_progress = get_entity_crafting_progress(entity)
        local previous_progress = run_state.crafting_progress_at_last_check
        if (run_state.crafts_remaining or 0) > 0 and current_progress and previous_progress then
          if current_progress < previous_progress then
            run_state.crafts_remaining = math.max(0, (run_state.crafts_remaining or 0) - 1)
          end
          run_state.crafting_progress_at_last_check = current_progress
        elseif current_progress then
          run_state.crafting_progress_at_last_check = current_progress
        end

        if (run_state.crafts_remaining or 0) <= 0 then
          entity.active = false
          run_state.crafts_remaining = 0
          run_state.recipe_name = nil
          run_state.crafting_progress_at_last_check = nil
          clear_run_state_if_idle(unit_number, run_state)
        end
      else
        clear_run_state_if_idle(unit_number, run_state)
      end
    end

    ::continue::
  end
end

local function advance_active_biters(tick)
  local active_states = {}
  for _, active_state in pairs(storage.biter_station_biter) do
    active_states[#active_states + 1] = active_state
  end

  for _, active_state in ipairs(active_states) do
    if not active_state or not storage.biter_station_biter[active_state.biter_unit_number] then
      goto continue
    end
    local station_id = active_state.station_id
    local station = storage.biter_stations[station_id]

    if not station or not station.valid then
      cleanup_active_biter(active_state, tick, true, "station-invalid")
      goto continue
    end

    local biter = active_state.biter
    if not biter or not biter.valid then
      biter = recreate_missing_active_biter(active_state, station, tick)
      if not biter or not biter.valid then
        cleanup_active_biter(active_state, tick, false, "biter-invalid")
        refresh_station_status(station)
        goto continue
      end
    end
    refresh_active_biter_snapshot(active_state, biter)

    if check_and_update_progress(active_state, biter, tick) then
      cleanup_active_biter(active_state, tick, false, "stuck")
      refresh_station_status(station)
      goto continue
    end

    if active_state.phase == "to_building" then
      local queue = active_state.building_queue or {}

      while active_state.current_idx <= #queue do
        local building = queue[active_state.current_idx]

        if not building or not building.valid or not building.unit_number then
          if building and building.unit_number then
            clear_building_claim(building.unit_number, biter.unit_number)
          end
          active_state.current_idx = active_state.current_idx + 1
        else
          local arrived = phase_has_departed(active_state, biter, tick)
            and phase_is_arrived(active_state, biter, building.position, C.BITER_STATION_ARRIVAL_RADIUS)
          if arrived then
            activate_building_for_visit(building, biter.unit_number)
            active_state.current_idx = active_state.current_idx + 1
            local next_building = queue[active_state.current_idx]
            if next_building and next_building.valid then
              begin_phase_move(active_state, biter, "to_building", next_building, C.BITER_STATION_ARRIVAL_RADIUS, tick)
            end
            goto continue_building_queue
          end

          local needs_command = active_state.phase_target_unit_number ~= building.unit_number
            or (biter.commandable and not biter.commandable.has_command)
          if needs_command then
            begin_phase_move(active_state, biter, "to_building", building, C.BITER_STATION_ARRIVAL_RADIUS, tick)
          end
        end

        set_station_status(station, "biter-station-calling")
        goto continue
        ::continue_building_queue::
      end

      begin_phase_move(active_state, biter, "to_station", station_interior_position(station), C.BITER_STATION_ARRIVAL_RADIUS, tick)
      set_station_status(station, "biter-station-calling")

    elseif active_state.phase == "to_station" then
      local station_destination = station_interior_position(station)
      local arrived_station = phase_has_departed(active_state, biter, tick)
        and phase_is_arrived(active_state, biter, station_destination, C.BITER_STATION_ARRIVAL_RADIUS)
      if arrived_station then
        finish_station_circuit(station_id, station, active_state)
        goto continue
      end

      local needs_command = active_state.phase_target_unit_number ~= nil
        or (biter.commandable and not biter.commandable.has_command)
      if needs_command then
        begin_phase_move(active_state, biter, "to_station", station_destination, C.BITER_STATION_ARRIVAL_RADIUS, tick)
      end
      set_station_status(station, "biter-station-calling")
    else
      begin_phase_move(active_state, biter, "to_station", station_interior_position(station), C.BITER_STATION_ARRIVAL_RADIUS, tick)
      set_station_status(station, "biter-station-calling")
    end

    ::continue::
  end
end

local function despawn_released_biters(tick)
  for biter_unit_number, info in pairs(storage.biter_station_releasing) do
    local entity = info.entity
    if not entity or not entity.valid then
      unmark_station_worker_unit(biter_unit_number)
      storage.biter_station_releasing[biter_unit_number] = nil
    elseif tick >= (info.despawn_tick or 0) then
      entity.destroy()
      unmark_station_worker_unit(biter_unit_number)
      storage.biter_station_releasing[biter_unit_number] = nil
    end
  end
end

local function initial_dispatch_check()
  for station_id, station in pairs(storage.biter_stations) do
    if not station or not station.valid then
      local active_units = storage.biter_station_active_by_station and storage.biter_station_active_by_station[station_id] or nil
      if active_units then
        local units_to_cleanup = {}
        for biter_unit_number in pairs(active_units) do
          units_to_cleanup[#units_to_cleanup + 1] = biter_unit_number
        end
        for _, biter_unit_number in ipairs(units_to_cleanup) do
          local active_state = storage.biter_station_biter[biter_unit_number]
          if active_state then
            cleanup_active_biter(active_state, game.tick, true, "initial-dispatch-station-invalid")
          end
        end
      end
      storage.biter_stations[station_id] = nil
    else
      if working_hours.is_enabled()
         and (not storage.biter_station_coffee_inputs[station_id]
           or not storage.biter_station_coffee_inputs[station_id].valid) then
        create_hidden_coffee_input(station)
      end
      dispatch_station_biters(station)
      refresh_station_status(station)
    end
  end
end

function M.ensure_storage()
  ensure_worker_force()
  storage.biter_stations = storage.biter_stations or {}
  storage.biter_station_biter = storage.biter_station_biter or {}
  storage.biter_station_active_by_station = storage.biter_station_active_by_station or {}
  storage.biter_station_releasing = storage.biter_station_releasing or {}
  storage.biter_station_worker_units = storage.biter_station_worker_units or {}
  storage.biter_station_coffee_inputs = storage.biter_station_coffee_inputs or {}
  storage.managed_building_registry = storage.managed_building_registry or {}
  storage.managed_building_run = storage.managed_building_run or {}
  if storage.biter_station_crafts_per_visit == nil then
    storage.biter_station_crafts_per_visit = C.BITER_STATION_CRAFTS_PER_VISIT
  end
  normalize_active_biter_storage()
end

function M.is_station(entity_or_name)
  local name = entity_or_name
  if type(entity_or_name) ~= "string" then
    name = entity_or_name and entity_or_name.name
  end
  return name == STATION_NAME
end

function M.is_managed_building(entity_or_name)
  local name = entity_or_name
  if type(entity_or_name) ~= "string" then
    name = entity_or_name and entity_or_name.name
  end
  return name and C.BITER_STATION_MANAGED_BUILDING_SET[name] == true or false
end

function M.is_station_worker_unit(unit_number)
  if not unit_number then return false end
  return storage
    and storage.biter_station_worker_units
    and storage.biter_station_worker_units[unit_number] ~= nil
    or false
end

function M.track_station(entity)
  M.ensure_storage()
  if not entity or not entity.valid or not M.is_station(entity) or not entity.unit_number then
    return
  end

  storage.biter_stations[entity.unit_number] = entity
  apply_station_inventory(entity)
  create_wall_blockers(entity)
  if working_hours.is_enabled() then
    create_hidden_coffee_input(entity)
  end
  refresh_station_status(entity)
end

function M.untrack_station(entity, tick)
  M.ensure_storage()
  if not entity or not entity.unit_number then return end

  local station_id = entity.unit_number
  local active_units = storage.biter_station_active_by_station and storage.biter_station_active_by_station[station_id] or nil
  if active_units then
    local units_to_cleanup = {}
    for biter_unit_number in pairs(active_units) do
      units_to_cleanup[#units_to_cleanup + 1] = biter_unit_number
    end
    for _, biter_unit_number in ipairs(units_to_cleanup) do
      local active_state = storage.biter_station_biter[biter_unit_number]
      if active_state then
        cleanup_active_biter(active_state, tick or game.tick, true, "untrack-station")
      end
    end
  end

  destroy_hidden_coffee_input(station_id)
  destroy_wall_blockers(entity)
  storage.biter_stations[station_id] = nil
end

function M.track_managed_building(entity)
  M.ensure_storage()
  if not entity or not entity.valid or not M.is_managed_building(entity) or not entity.unit_number then
    return
  end

  storage.managed_building_registry[entity.unit_number] = entity
  entity.active = false

  local run_state = storage.managed_building_run[entity.unit_number]
  if run_state then
    run_state.entity = entity
    run_state.claimed_by = nil
    run_state.crafts_remaining = nil
    run_state.products_at_last_check = nil
    run_state.recipe_name = nil
    run_state.crafting_progress_at_last_check = nil
    clear_run_state_if_idle(entity.unit_number, run_state)
  end
end

function M.untrack_managed_building(entity)
  M.ensure_storage()
  if not entity or not entity.unit_number then return end

  local unit_number = entity.unit_number
  storage.managed_building_registry[unit_number] = nil

  local run_state = storage.managed_building_run[unit_number]
  if run_state then
    run_state.claimed_by = nil
    run_state.crafts_remaining = nil
    run_state.recipe_name = nil
    run_state.crafting_progress_at_last_check = nil
    clear_run_state_if_idle(unit_number, run_state)
  end
end

function M.untrack_entity(entity, tick)
  if not entity then return end

  if M.is_station(entity) then
    M.untrack_station(entity, tick)
  end

  if M.is_managed_building(entity) then
    M.untrack_managed_building(entity)
  end
end

local function find_active_station_by_biter_unit(unit_number)
  if not unit_number then return nil, nil end
  local active_state = storage.biter_station_biter and storage.biter_station_biter[unit_number] or nil
  if active_state then
    return active_state.station_id, active_state
  end
  for _, fallback_state in pairs(storage.biter_station_biter or {}) do
    local biter = fallback_state and fallback_state.biter or nil
    if biter and biter.valid and biter.unit_number == unit_number then
      return fallback_state.station_id, fallback_state
    end
  end
  return nil, nil
end

function M.on_entity_died(event)
  if not event then return end
  local entity = event.entity
  if not entity or not entity.valid then return end
  if entity.name ~= WORKER_ENTITY_NAME then return end

  local station_id = find_active_station_by_biter_unit(entity.unit_number)
  local releasing = storage.biter_station_releasing and storage.biter_station_releasing[entity.unit_number] or nil
  if not station_id and not releasing then return end
  unmark_station_worker_unit(entity.unit_number)
end

function M.on_entity_removed(event)
  if not event then return end
  local entity = event.entity
  if not entity or not entity.valid then return end
  if entity.name == COFFEE_INPUT_NAME and storage.biter_station_coffee_inputs then
    for station_id, input in pairs(storage.biter_station_coffee_inputs) do
      if input == entity then
        storage.biter_station_coffee_inputs[station_id] = nil
        break
      end
    end
    return
  end
  if entity.name ~= WORKER_ENTITY_NAME then return end

  local station_id = find_active_station_by_biter_unit(entity.unit_number)
  local releasing = storage.biter_station_releasing and storage.biter_station_releasing[entity.unit_number] or nil
  if not station_id and not releasing then return end
  unmark_station_worker_unit(entity.unit_number)
end

function M.on_ai_command_completed(event)
  if not event or not event.unit_number then return end

  local station_id, active_state = find_active_station_by_biter_unit(event.unit_number)
  local releasing = storage.biter_station_releasing and storage.biter_station_releasing[event.unit_number] or nil
  if not station_id and not releasing then return end

  local entity = active_state and active_state.biter or (releasing and releasing.entity) or nil
  if not active_state or releasing then return end
  if not entity or not entity.valid then return end
  local destination = active_state.phase_destination
  if not destination then return end

  local retry_radius = active_state.phase_command_radius or active_state.phase_radius or C.BITER_STATION_ARRIVAL_RADIUS
  if has_arrived_position(entity, destination, retry_radius) then
    active_state.phase_arrived_tick = event.tick or game.tick
    return
  end

  issue_move_command(entity, destination, retry_radius)
end

local function get_crafts_per_visit_for_force(force)
  if not force or not force.valid then
    return C.BITER_STATION_CRAFTS_PER_VISIT
  end

  local technologies = force.technologies
  if technologies and technologies["biter-labor-efficiency-2"] and technologies["biter-labor-efficiency-2"].researched then
    return 5
  end
  if technologies and technologies["biter-labor-efficiency-1"] and technologies["biter-labor-efficiency-1"].researched then
    return 3
  end
  return C.BITER_STATION_CRAFTS_PER_VISIT
end

local function sync_station_recipe_unlock(force)
  if not force or not force.valid then return end

  local recipe = force.recipes and force.recipes["biter-station"] or nil
  if not recipe then return end

  local technologies = force.technologies
  local researched = technologies
    and technologies["biter-employment-office"]
    and technologies["biter-employment-office"].researched
  if researched then
    recipe.enabled = true
  end
end

function M.sync_research(force)
  M.ensure_storage()
  sync_station_recipe_unlock(force)

  local force_crafts = get_crafts_per_visit_for_force(force)
  local current = storage.biter_station_crafts_per_visit or C.BITER_STATION_CRAFTS_PER_VISIT
  storage.biter_station_crafts_per_visit = math.max(current, force_crafts)
end

function M.on_research_finished(research)
  if not research or not research.valid then return end
  sync_station_recipe_unlock(research.force)

  local name = research.name
  if name == "biter-employment-office" then
    return
  end

  if name:find("^biter%-station%-capacity%-") then
    for _, station in pairs(storage.biter_stations or {}) do
      if station and station.valid then
        apply_station_inventory(station)
      end
    end
    return
  end

  if name ~= "biter-labor-efficiency-1" and name ~= "biter-labor-efficiency-2" then
    return
  end

  storage.biter_station_crafts_per_visit = C.BITER_STATION_CRAFTS_PER_VISIT
  for _, force in pairs(game.forces) do
    M.sync_research(force)
  end
end

function M.rebuild_registry()
  M.ensure_storage()

  local active_states = {}
  for _, active_state in pairs(storage.biter_station_biter) do
    active_states[#active_states + 1] = active_state
  end
  for _, active_state in ipairs(active_states) do
    cleanup_active_biter(active_state, game.tick, false, "rebuild-registry")
  end

  for biter_unit_number, info in pairs(storage.biter_station_releasing) do
    if info.entity and info.entity.valid then
      info.entity.destroy()
    end
    storage.biter_station_releasing[biter_unit_number] = nil
  end

  for _, surface in pairs(game.surfaces) do
    for _, blocker in ipairs(surface.find_entities_filtered{name = WALL_BLOCKER_NAME}) do
      if blocker.valid then blocker.destroy() end
    end
    for _, input in ipairs(surface.find_entities_filtered{name = COFFEE_INPUT_NAME}) do
      if input.valid then input.destroy() end
    end
  end

  storage.biter_stations = {}
  storage.biter_station_biter = {}
  storage.biter_station_active_by_station = {}
  storage.biter_station_releasing = {}
  storage.biter_station_worker_units = {}
  storage.biter_station_coffee_inputs = {}
  storage.managed_building_registry = {}
  storage.managed_building_run = {}

  for _, surface in pairs(game.surfaces) do
    for _, station in ipairs(surface.find_entities_filtered{name = STATION_NAME}) do
      if station.valid and station.unit_number then
        M.track_station(station)
      end
    end

    for _, building in ipairs(surface.find_entities_filtered{name = C.BITER_STATION_MANAGED_BUILDINGS}) do
      if building.valid and building.unit_number then
        storage.managed_building_registry[building.unit_number] = building
        building.active = false
      end
    end
  end

  for _, station in pairs(storage.biter_stations) do
    if working_hours.is_enabled() then
      create_hidden_coffee_input(station)
    end
    refresh_station_status(station)
  end
end

function M.update(tick)
  M.ensure_storage()

  if tick % C.BITER_STATION_CHECK_TICKS ~= 0 then
    return
  end

  sanitize_station_worker_registry_links()
  advance_running_buildings()
  advance_active_biters(tick)
  despawn_released_biters(tick)
  initial_dispatch_check()
end

function M.sanitize_external_links()
  M.ensure_storage()
  sanitize_station_worker_registry_links()
end

return M
