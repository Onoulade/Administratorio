-- Script-side passenger rail transport. Passenger wagons deliberately have no
-- inventory: a visitor is always represented by exactly one ground record,
-- manifest record, or outbreak-recovery record.
local C = require("scripts.constants")
local spawner_population = require("scripts.spawner_population")

local M = {}
local biters
-- Forward declarations let the selection GUI use the same normalization path
-- as boarding, even though manifests are defined later in this module.
local manifest_for
local manifest_count
local attached_passenger_wagon
local boarding_train_state

local PLATFORM_NAMES = {"boarding-platform", "deboarding-platform"}
local PLATFORM_PREVIEW_NAMES = {
  ["boarding-platform-placement-preview"] = "boarding-platform",
  ["deboarding-platform-placement-preview"] = "deboarding-platform",
}
-- A train stop sits at one end of a train. This permits platforms alongside
-- each passenger wagon of a short train while still rejecting distant stops.
local PLATFORM_RADIUS = 24
-- A platform is a 3x3 rail-side apron. Its center may sit two-and-a-half
-- tiles from the track, but it must not be usable as a distant station marker.
local PLATFORM_RAIL_RADIUS = 2.75
-- Boarders must reach the center tile of the 3x3 platform. A small margin
-- accepts the tile corners and minor pathfinding offsets.
local PLATFORM_BOARD_RADIUS = 0.85
local PLATFORM_WAGON_RADIUS = 4
local PLATFORM_CAPACITY = 24
local WAGON_CAPACITY = 24
local MAX_RAIL_LEGS = 3

local function valid(entity)
  return entity and entity.valid
end

local function distance_sq(a, b)
  local x, y = a.x - b.x, a.y - b.y
  return x * x + y * y
end

local function ensure_storage()
  storage.passenger_platforms = storage.passenger_platforms or {}
  storage.passenger_wagons = storage.passenger_wagons or {}
  storage.passenger_wagon_entities = storage.passenger_wagon_entities or {}
  storage.passenger_outbreaks = storage.passenger_outbreaks or {}
  storage.passenger_stopped_trains = storage.passenger_stopped_trains or {}
  storage.passenger_registry_ready = storage.passenger_registry_ready or false
  storage.passenger_visitor_id = storage.passenger_visitor_id or 0
end

function M.ensure_storage()
  ensure_storage()
end

function M.set_biters_module(module)
  biters = module
end

local function next_visitor_id()
  ensure_storage()
  storage.passenger_visitor_id = storage.passenger_visitor_id + 1
  return storage.passenger_visitor_id
end

local function platform_record(entity)
  ensure_storage()
  if not valid(entity) then return nil end
  local id = entity.unit_number
  local record = storage.passenger_platforms[id]
  if not record then
    record = {entity = entity, kind = entity.name, queue = {}, queue_order = {}, mode = "always"}
    storage.passenger_platforms[id] = record
  else
    record.entity = entity
    record.kind = entity.name
    record.queue = record.queue or {}
    record.queue_order = record.queue_order or {}
    record.mode = record.mode or "always"
  end
  return record
end

local function get_platform_stop(record)
  local id = record and record.stop_id
  local stop = id and storage.passenger_stops and storage.passenger_stops[id]
  if valid(stop) then return stop end
  if valid(record and record.stop) then return record.stop end
  return nil
end

local function refresh_stop_index()
  storage.passenger_stops = storage.passenger_stops or {}
  for id, stop in pairs(storage.passenger_stops) do
    if not valid(stop) then storage.passenger_stops[id] = nil end
  end
end

local function nearby_stops(entity)
  if not valid(entity) then return {} end
  local candidates = entity.surface.find_entities_filtered{
    type = "train-stop", position = entity.position, radius = PLATFORM_RADIUS,
  }
  local result = {}
  for _, stop in ipairs(candidates) do
    if valid(stop) and stop.force == entity.force then result[#result + 1] = stop end
  end
  table.sort(result, function(a, b) return a.unit_number < b.unit_number end)
  return result
end

local function is_rail_adjacent(entity)
  if not valid(entity) then return false end
  for _, nearby in ipairs(entity.surface.find_entities_filtered{
    position = entity.position, radius = PLATFORM_RAIL_RADIUS,
  }) do
    local entity_type = nearby.type
    if entity_type == "straight-rail" or entity_type == "curved-rail"
        or entity_type == "half-diagonal-rail" or entity_type == "elevated-straight-rail"
        or entity_type == "rail-ramp" then
      return true
    end
  end
  return false
end

local function auto_pair(record)
  local entity = record and record.entity
  if not is_rail_adjacent(entity) then return nil end
  local candidates = nearby_stops(entity)
  if #candidates == 1 then
    local stop = candidates[1]
    storage.passenger_stops = storage.passenger_stops or {}
    storage.passenger_stops[stop.unit_number] = stop
    record.stop_id, record.stop = stop.unit_number, stop
    return stop
  end
  return nil
end

function M.pair_platform(platform, stop)
  local record = platform_record(platform)
  if not record or not valid(stop) or stop.type ~= "train-stop" then return false end
  if platform.surface ~= stop.surface or platform.force ~= stop.force then return false end
  if not is_rail_adjacent(platform) then return false end
  if distance_sq(platform.position, stop.position) > PLATFORM_RADIUS * PLATFORM_RADIUS then return false end
  storage.passenger_stops = storage.passenger_stops or {}
  storage.passenger_stops[stop.unit_number] = stop
  record.stop_id, record.stop = stop.unit_number, stop
  return true
end

function M.set_platform_mode(platform, mode)
  local record = platform_record(platform)
  if not record or (mode ~= "always" and mode ~= "circuit" and mode ~= "off") then return false end
  record.mode = mode
  return true
end

local function read_platform_signal(entity, signal_name)
  if not valid(entity) or not entity.get_circuit_network then return false end
  for _, wire in ipairs({defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green}) do
    local ok, network = pcall(entity.get_circuit_network, wire)
    if ok and network and network.get_signal then
      local read_ok, amount = pcall(network.get_signal, {type = "virtual", name = signal_name})
      if read_ok and (amount or 0) > 0 then return true end
    end
  end
  return false
end

local function boarding_signal_open(record)
  return record and read_platform_signal(record.entity, "signal-boarding-enabled")
end

-- Deboarding is open by default. Sending this signal closes the platform and
-- leaves passengers aboard until the signal is removed.
local function deboarding_enabled(record)
  return record and valid(record.entity)
    and not read_platform_signal(record.entity, "signal-deboarding-closed")
end

local function platform_direction_name(direction)
  if direction == defines.direction.east then return "east" end
  if direction == defines.direction.south then return "south" end
  if direction == defines.direction.west then return "west" end
  return "north"
end

local function destroy_platform_visuals(record)
  if not record or not record.platform_render_ids or not rendering then return end
  for _, id in ipairs(record.platform_render_ids) do
    local render = rendering.get_object_by_id(id)
    if render then render.destroy() end
  end
  record.platform_render_ids = nil
end

local function platform_visual_state(record)
  local platform = record and record.entity
  if not valid(platform) or not is_rail_adjacent(platform) then return "inactive" end
  if record.kind == "boarding-platform" then
    local circuit_open = boarding_signal_open(record)
    if record.mode == "off" or (record.mode == "circuit" and not circuit_open) then
      return "inactive"
    end
    local _, _, train_present, has_space = boarding_train_state(record)
    if train_present and has_space then return "active" end
    return "idle"
  end
  if not deboarding_enabled(record) then return "inactive" end
  local wagon = attached_passenger_wagon(record)
  local train = wagon and wagon.train
  if wagon and train and math.abs(train.speed or 0) < 0.000001 then return "active" end
  return "idle"
end

local function update_platform_visuals(record)
  -- Rendering is unavailable in standalone Lua tests. The state calculation
  -- remains fully testable there, while game runtime gets stateful artwork.
  if not rendering or not valid(record and record.entity) then return end
  local state = platform_visual_state(record)
  local existing = record.platform_render_ids
  local intact = existing and #existing > 0
  if intact then
    for _, id in ipairs(existing) do
      if not rendering.get_object_by_id(id) then intact = false break end
    end
  end
  if record.platform_visual_state == state and intact then return end
  destroy_platform_visuals(record)
  record.platform_visual_state = state

  local direction = platform_direction_name(record.entity.direction)
  local prefix = "administratorio-passenger-platform-" .. record.kind
  local renders = {
    rendering.draw_sprite{
      sprite = prefix .. "-idle-" .. direction,
      target = record.entity,
      surface = record.entity.surface,
      render_layer = "lower-object",
    },
  }
  -- The supplied light sprites are white alpha masks. Idle is deliberately
  -- blue, active is green, and disabled/off-rail platforms are red.
  renders[#renders + 1] = rendering.draw_sprite{
    sprite = prefix .. "-light-" .. direction,
    target = record.entity,
    surface = record.entity.surface,
    render_layer = "lower-object",
    tint = state == "active" and {r = 0.22, g = 1, b = 0.32, a = 1}
      or state == "inactive" and {r = 1, g = 0.16, b = 0.10, a = 1}
      or {r = 0.12, g = 0.48, b = 1, a = 1},
  }
  record.platform_render_ids = {}
  for _, render in ipairs(renders) do
    if render then record.platform_render_ids[#record.platform_render_ids + 1] = render.id end
  end
end

local function queue_count(record)
  local count = 0
  for visitor_id in pairs(record.queue or {}) do
    if record.queue[visitor_id] then count = count + 1 end
  end
  return count
end

-- A platform is physically associated with the closest passenger wagon beside
-- it, rather than with whichever carriage happens to be at a paired stop.
-- This lets a manually parked train load in the same intuitive setup used by
-- scheduled service, while keeping the platform's circuit output wagon-local.
attached_passenger_wagon = function(record)
  local platform = record and record.entity
  if not valid(platform) then return nil end
  local best, best_distance
  for _, wagon in ipairs(platform.surface.find_entities_filtered{
    name = "passenger-wagon", position = platform.position, radius = PLATFORM_WAGON_RADIUS,
  }) do
    local distance = distance_sq(platform.position, wagon.position)
    if not best or distance < best_distance or (distance == best_distance and wagon.unit_number < best.unit_number) then
      best, best_distance = wagon, distance
    end
  end
  return best
end

boarding_train_state = function(record)
  local wagon = attached_passenger_wagon(record)
  local train = wagon and wagon.train
  -- Passing trains are never boardable. A train must be stationary beside the
  -- platform, whether it is manual or waiting at a scheduled stop.
  local train_present = train and math.abs(train.speed or 0) < 0.000001
  local has_space = train_present and manifest_count(manifest_for(wagon)) < WAGON_CAPACITY
  return wagon, train, train_present, has_space
end

local function boarding_eligible(record)
  if not record or record.kind ~= "boarding-platform" or not valid(record.entity) then return false end
  if not is_rail_adjacent(record.entity) then return false end
  if record.mode == "off" then return false end
  local circuit_open = boarding_signal_open(record)
  if record.mode == "circuit" and not circuit_open then return false end
  return true
end

local function boarding_routable(record)
  if not boarding_eligible(record) or queue_count(record) >= PLATFORM_CAPACITY then return false end
  local circuit_open = boarding_signal_open(record)
  local _, _, train_present, has_space = boarding_train_state(record)
  -- The circuit signal explicitly reserves a queue for an incoming train.
  -- Without it, an available stationary wagon is the sole attraction.
  return (train_present and has_space) or circuit_open
end

function M.get_platform_status(platform)
  local record = platform_record(platform)
  if not record then return nil end
  local stop = get_platform_stop(record) or auto_pair(record)
  return {
    paired = valid(stop), queue = queue_count(record), capacity = PLATFORM_CAPACITY,
    enabled = boarding_routable(record), mode = record.mode, stop = stop,
  }
end

local WAGON_INSPECTOR = "administratorio-passenger-wagon-inspector"

-- Circuit signals are integers, so expose the passenger's frustration on the
-- familiar 0–100 scale rather than leaking the internal waiting-time counter.
local function frustration_percent(frustration)
  local threshold = math.max(1, C.PROTEST_THRESHOLD or 1)
  return math.max(0, math.min(100, math.floor((frustration or 0) * 100 / threshold)))
end

function M.update_wagon_inspector(player, wagon)
  if not player or not player.valid then return end
  local frame = player.gui.left[WAGON_INSPECTOR]
  if not valid(wagon) or wagon.name ~= "passenger-wagon" then
    if frame then frame.destroy() end
    return
  end
  local manifest = manifest_for(wagon)
  if not frame then
    frame = player.gui.left.add{type = "frame", name = WAGON_INSPECTOR, direction = "vertical"}
    frame.style.minimal_width = 260
  else
    frame.clear()
  end
  frame.add{type = "label", caption = "Passenger Wagon", style = "frame_title"}
  frame.add{type = "label", caption = "Passengers: " .. manifest_count(manifest) .. " / " .. WAGON_CAPACITY}
  if manifest.outbreak_pending then
    frame.add{type = "label", caption = "OUTBREAK: passengers are disembarking", style = "caption_label"}
  end
  if manifest_count(manifest) == 0 then
    frame.add{type = "label", caption = "No passengers aboard."}
  else
    for _, passenger in ipairs(manifest.passengers) do
      frame.add{type = "label", caption = passenger.entity_name .. "  •  frustration " .. frustration_percent(passenger.frustration) .. "%"}
    end
  end
end

function M.on_selected_entity_changed(player, entity)
  M.update_wagon_inspector(player, entity)
end

function M.find_destination(entity, excluded_platforms)
  if not valid(entity) then return nil end
  local best, best_distance
  for id, record in pairs(storage.passenger_platforms or {}) do
    if not (excluded_platforms and (excluded_platforms[id] or (record.stop_id and excluded_platforms[record.stop_id]))) and boarding_routable(record)
        and record.entity.surface == entity.surface then
      local d = distance_sq(entity.position, record.entity.position)
      if not best or d < best_distance or (d == best_distance and id < best.entity.unit_number) then
        best, best_distance = record, d
      end
    end
  end
  return best and best.entity or nil, best_distance
end

-- Include full queues so complaint routing can wait locally instead of
-- walking past a platform to an arbitrarily distant free desk.
function M.find_candidates(entity, excluded_platforms)
  local candidates = {}
  if not valid(entity) then return candidates end
  for id, record in pairs(storage.passenger_platforms or {}) do
    if not (excluded_platforms and (excluded_platforms[id] or (record.stop_id and excluded_platforms[record.stop_id])))
       and boarding_eligible(record) and record.entity.surface == entity.surface then
      candidates[#candidates + 1] = {
        entity = record.entity,
        kind = "platform",
        available = boarding_routable(record),
      }
    end
  end
  return candidates
end

local function issue_route(entity, destination)
  if not valid(entity) or not destination then return false end
  entity.active = true
  if entity.commandable and entity.commandable.set_command then
    entity.commandable.set_command({
      type = defines.command.go_to_location, destination = destination, radius = PLATFORM_BOARD_RADIUS,
      distraction = defines.distraction.none,
    })
  end
  return true
end

function M.reserve_platform(info, entity, platform)
  local record = platform_record(platform)
  if not info or not valid(entity) or not boarding_routable(record) then return false end
  info.visitor_id = info.visitor_id or next_visitor_id()
  if record.queue[info.visitor_id] then return true end
  if queue_count(record) >= PLATFORM_CAPACITY then return false end
  record.queue[info.visitor_id] = info
  record.queue_order[#record.queue_order + 1] = info.visitor_id
  info.platform_id = platform.unit_number
  info.platform_dest = {x = platform.position.x, y = platform.position.y}
  info.platform_route_started_tick = game.tick
  if biters and biters.set_passenger_ground_state then
    biters.set_passenger_ground_state(info, "pathfinding_to_platform")
  else
    info.state = "pathfinding_to_platform"
  end
  return issue_route(entity, info.platform_dest)
end

function M.release_reservation(info)
  if not info or not info.platform_id then return end
  local platform_id = info.platform_id
  local record = storage.passenger_platforms and storage.passenger_platforms[info.platform_id]
  if record and info.visitor_id then record.queue[info.visitor_id] = nil end
  info.platform_id, info.platform_dest = nil, nil
  info.platform_route_started_tick = nil
  return platform_id
end

local function release_and_reroute(info)
  local previous_platform_id = M.release_reservation(info)
  if biters and biters.reroute_passenger_ground then
    return biters.reroute_passenger_ground(info, previous_platform_id)
  end
  return false
end

manifest_for = function(wagon)
  ensure_storage()
  local id = wagon.unit_number
  local manifest = storage.passenger_wagons[id]
  if not manifest then
    manifest = {passengers = {}}
    storage.passenger_wagons[id] = manifest
  end
  -- Old saves and early implementation builds may have created the manifest
  -- shell before the passenger list existed. Normalize it at every entrypoint
  -- so periodic processing can safely treat it as an empty wagon.
  manifest.passengers = manifest.passengers or {}
  storage.passenger_wagon_entities[id] = wagon
  return manifest
end

local function passenger_wagons(train)
  local wagons = {}
  for _, carriage in ipairs(train and train.carriages or {}) do
    if valid(carriage) and carriage.name == "passenger-wagon" then wagons[#wagons + 1] = carriage end
  end
  return wagons
end

manifest_count = function(manifest)
  return #(manifest and manifest.passengers or {})
end

local function copy_case(info, entity, stop_id)
  return {
    visitor_id = info.visitor_id,
    entity_name = entity.name, health = entity.health, force_name = entity.force.name,
    surface_index = entity.surface.index, home_spawner_id = info.home_spawner_unit_number,
    home_position = info.home_position and {x = info.home_position.x, y = info.home_position.y} or nil,
    home_surface_index = info.home_surface_index, frustration = info.frustration or 0,
    frust_accum = info.frust_accum or 0, last_update_tick = game.tick,
    complaints = info.complaints, complaints_total = info.complaints_total,
    complaints_filed = info.complaints_filed, origin_stop = info.origin_stop or stop_id,
    last_stop = stop_id, visited_stops = info.visited_stops or {}, rail_legs = info.rail_legs or 0,
  }
end

local function board_one(wagon, manifest, record, visitor_id, stop_id)
  local info = record.queue[visitor_id]
  local entity = info and info.entity
  if not info or not valid(entity) or info.state ~= "waiting_for_train" or manifest_count(manifest) >= WAGON_CAPACITY
      or entity.surface ~= record.entity.surface
      or distance_sq(entity.position, record.entity.position) > PLATFORM_BOARD_RADIUS * PLATFORM_BOARD_RADIUS then
    return false
  end
  local passenger = copy_case(info, entity, stop_id)
  if biters and biters.detach_for_passenger then
    if not biters.detach_for_passenger(info, passenger.visitor_id) then return false end
  else
    spawner_population.rekey_detached(entity.unit_number, passenger.visitor_id, nil, info.home_spawner)
  end
  entity.destroy()
  record.queue[visitor_id] = nil
  manifest.passengers[#manifest.passengers + 1] = passenger
  wagon.minable = false
  return true
end

local function board_train(train, stop)
  local wagons = passenger_wagons(train)
  if #wagons == 0 then return end
  local platforms = {}
  for _, record in pairs(storage.passenger_platforms or {}) do
    if record.kind == "boarding-platform" and get_platform_stop(record) == stop and boarding_routable(record) then
      platforms[#platforms + 1] = record
    end
  end
  table.sort(platforms, function(a, b) return a.entity.unit_number < b.entity.unit_number end)
  for _, wagon in ipairs(wagons) do
    local manifest = manifest_for(wagon)
    for _, platform in ipairs(platforms) do
      for _, visitor_id in ipairs(platform.queue_order) do
        if manifest_count(manifest) >= WAGON_CAPACITY then break end
        board_one(wagon, manifest, platform, visitor_id, stop.unit_number)
      end
      if manifest_count(manifest) >= WAGON_CAPACITY then break end
    end
  end
end

local function board_platform_wagon(record, wagon)
  if not boarding_routable(record) then return end
  local manifest = manifest_for(wagon)
  for _, visitor_id in ipairs(record.queue_order or {}) do
    if manifest_count(manifest) >= WAGON_CAPACITY then break end
    board_one(wagon, manifest, record, visitor_id, record.entity.unit_number)
  end
end

local function find_deboarding_platform(stop)
  local best
  for _, record in pairs(storage.passenger_platforms or {}) do
    if record.kind == "deboarding-platform" and valid(record.entity) and is_rail_adjacent(record.entity)
        and deboarding_enabled(record)
        and get_platform_stop(record) == stop then
      if not best or record.entity.unit_number < best.entity.unit_number then best = record end
    end
  end
  return best
end

local function find_home_spawner(record)
  local spawner = record.home_spawner_id and game.get_entity_by_unit_number and game.get_entity_by_unit_number(record.home_spawner_id)
  return valid(spawner) and spawner or nil
end

local function spawn_passenger(record, platform, protest)
  if not valid(platform and platform.entity) then return nil end
  local surface = platform.entity.surface
  local pos = surface.find_non_colliding_position(record.entity_name, platform.entity.position, 8, 0.5)
  if not pos then return nil end
  local entity = surface.create_entity{name = record.entity_name, position = pos, force = record.force_name or "enemy"}
  -- LuaEntityPrototype has no max_health property. A freshly spawned unit's
  -- live health is its full health, so use it as the safe upper bound.
  if entity and entity.valid and record.health and entity.health then entity.health = math.min(record.health, entity.health) end
  return entity
end

local function restore_record(record, entity, stop_id)
  record.last_stop = stop_id
  record.visited_stops = record.visited_stops or {}
  record.visited_stops[stop_id] = true
  record.rail_legs = (record.rail_legs or 0) + 1
  if biters and biters.restore_passenger then return biters.restore_passenger(record, entity) end
  local spawner = find_home_spawner(record)
  spawner_population.rekey_detached(record.visitor_id, entity.unit_number, entity, spawner)
  return true
end

local function deboard_train(train, stop)
  local platform = find_deboarding_platform(stop)
  if not platform then return end
  for _, wagon in ipairs(passenger_wagons(train)) do
    local manifest = manifest_for(wagon)
    if manifest.outbreak_pending then goto continue_wagon end
    local retained = {}
    for _, record in ipairs(manifest.passengers) do
      -- A train may wait through several periodic updates. Do not unload a
      -- visitor who just boarded at this same stop on the previous update.
      if record.last_stop == stop.unit_number then
        retained[#retained + 1] = record
      else
        local entity = spawn_passenger(record, platform)
        if entity and restore_record(record, entity, stop.unit_number) then
        -- restored atomically enough for Lua's single event turn: only remove
        -- after entity creation and ground-state registration succeed.
        else
          retained[#retained + 1] = record
        end
      end
    end
    manifest.passengers = retained
    wagon.minable = #retained == 0
    ::continue_wagon::
  end
end

local function deboard_platform_wagon(record, wagon)
  if not deboarding_enabled(record) then return end
  local manifest = manifest_for(wagon)
  if manifest.outbreak_pending then return end
  local retained = {}
  for _, passenger in ipairs(manifest.passengers) do
    local entity = spawn_passenger(passenger, record)
    if entity and restore_record(passenger, entity, record.entity.unit_number) then
      -- Removal occurs only after the visitor is restored to ground state.
    else
      retained[#retained + 1] = passenger
    end
  end
  manifest.passengers = retained
  wagon.minable = #retained == 0
end

local function write_platform_signals(record, passengers, free_seats, waiting, outbreak, highest_frustration)
  local platform = record and record.entity
  if not valid(platform) then return end
  local control = platform.get_or_create_control_behavior and platform.get_or_create_control_behavior()
  local section = control and (control.get_section(1) or control.add_section())
  if not section then return end
  local values = {
    {"signal-train-passengers", passengers}, {"signal-train-free-seats", free_seats},
    {"signal-boarders-waiting", waiting}, {"signal-passenger-outbreak", outbreak and 1 or 0},
    {"signal-passenger-highest-frustration", frustration_percent(highest_frustration)},
  }
  for slot, value in ipairs(values) do
    if value[2] == 0 then section.clear_slot(slot)
    else section.set_slot(slot, {value = value[1], min = value[2], max = value[2]}) end
  end
end

local function update_platform_signals(record)
  local wagon = attached_passenger_wagon(record)
  local manifest = wagon and manifest_for(wagon)
  local passengers = manifest and manifest_count(manifest) or 0
  local highest_frustration = 0
  for _, passenger in ipairs(manifest and manifest.passengers or {}) do
    highest_frustration = math.max(highest_frustration, passenger.frustration or 0)
  end
  write_platform_signals(record, passengers, wagon and WAGON_CAPACITY - passengers or 0,
    queue_count(record), manifest and manifest.outbreak_pending == true, highest_frustration)
end

local function update_stop_signals(train, stop)
  if not valid(stop) then return end
  local passengers, capacity, outbreak, highest_frustration = 0, 0, false, 0
  for _, wagon in ipairs(passenger_wagons(train)) do
    local manifest = manifest_for(wagon)
    passengers = passengers + manifest_count(manifest)
    capacity = capacity + WAGON_CAPACITY
    outbreak = outbreak or manifest.outbreak_pending == true
    for _, passenger in ipairs(manifest.passengers) do
      highest_frustration = math.max(highest_frustration, passenger.frustration or 0)
    end
  end
  local waiting = 0
  for _, record in pairs(storage.passenger_platforms or {}) do
    if record.kind == "boarding-platform" and get_platform_stop(record) == stop then waiting = waiting + queue_count(record) end
  end
  local behavior = stop.get_or_create_control_behavior and stop.get_or_create_control_behavior() or stop.get_control_behavior and stop.get_control_behavior()
  if behavior then
    pcall(function() behavior.send_to_train = true end)
  end
  storage.passenger_stop_combinators = storage.passenger_stop_combinators or {}
  local combinator = storage.passenger_stop_combinators[stop.unit_number]
  if not valid(combinator) then
    combinator = stop.surface.create_entity{name = "passenger-stop-combinator", position = stop.position, force = stop.force}
    if valid(combinator) then
      combinator.destructible = false
      storage.passenger_stop_combinators[stop.unit_number] = combinator
      local function connect(color)
        local stop_connector = stop.get_wire_connector and stop.get_wire_connector(color, true)
        local comb_connector = combinator.get_wire_connector and combinator.get_wire_connector(color, true)
        if stop_connector and comb_connector then pcall(stop_connector.connect_to, stop_connector, comb_connector) end
      end
      connect(defines.wire_connector_id.circuit_red)
      connect(defines.wire_connector_id.circuit_green)
    end
  end
  if valid(combinator) then
    local control = combinator.get_or_create_control_behavior()
    local section = control and (control.get_section(1) or control.add_section())
    if section then
      local values = {
        {"signal-train-passengers", passengers}, {"signal-train-free-seats", capacity - passengers},
        {"signal-boarders-waiting", waiting}, {"signal-passenger-outbreak", outbreak and 1 or 0},
        {"signal-passenger-highest-frustration", frustration_percent(highest_frustration)},
      }
      for slot, value in ipairs(values) do
        if value[2] == 0 then section.clear_slot(slot)
        else section.set_slot(slot, {value = value[1], min = value[2], max = value[2]}) end
      end
    end
  end
  storage.passenger_stop_status = storage.passenger_stop_status or {}
  storage.passenger_stop_status[stop.unit_number] = {
    passengers = passengers, free_seats = capacity - passengers, waiting = waiting,
    outbreak = outbreak and 1 or 0, highest_frustration = highest_frustration,
  }
  for _, record in pairs(storage.passenger_platforms or {}) do
    if get_platform_stop(record) == stop then
      if is_rail_adjacent(record.entity) then
        update_platform_signals(record)
      else
        -- Platforms from an older save can retain a pairing after being moved
        -- away from rail. Clear their output as well as refusing transfers.
        write_platform_signals(record, 0, 0, 0, false)
      end
    end
  end
end

local function process_platform_frustration(record, tick)
  for _, info in pairs(record.queue or {}) do
    if info and info.state == "waiting_for_train" then
      local elapsed = math.max(0, tick - (info.last_frustration_tick or tick))
      info.last_frustration_tick = tick
      local tier = C.get_individual_frust_tier(info)
      info.frust_accum = (info.frust_accum or 0) + (C.FRUST_GROWTH_RATES[tier] or 1) * elapsed / 60
      local whole = math.floor(info.frust_accum)
      info.frust_accum = info.frust_accum - whole
      info.frustration = (info.frustration or 0) + whole
      if info.frustration >= C.PROTEST_THRESHOLD and valid(info.entity) and biters and biters.trigger_immediate_protest then
        M.release_reservation(info)
        biters.trigger_immediate_protest(info.entity, info.entity.surface, info, {allow_obstacle_breach = false})
      end
    end
  end
end

local function trigger_outbreak(wagon, manifest)
  if manifest.outbreak_pending then return end
  manifest.outbreak_pending = true
  storage.passenger_outbreaks[wagon.unit_number] = {wagon = wagon, passengers = manifest.passengers}
end

local function process_wagon(wagon, tick)
  local manifest = manifest_for(wagon)
  local crossed = false
  for _, record in ipairs(manifest.passengers or {}) do
    local elapsed = math.max(0, tick - (record.last_update_tick or tick))
    record.last_update_tick = tick
    local tier = C.get_individual_frust_tier({frustration = record.frustration or 0})
    record.frust_accum = (record.frust_accum or 0) + (C.FRUST_GROWTH_RATES[tier] or 1) * 0.75 * elapsed / 60
    local whole = math.floor(record.frust_accum)
    record.frust_accum = record.frust_accum - whole
    record.frustration = (record.frustration or 0) + whole
    if record.frustration >= C.PROTEST_THRESHOLD then crossed = true end
  end
  if crossed then trigger_outbreak(wagon, manifest) end
end

local function process_outbreak(wagon, manifest)
  if not manifest.outbreak_pending then return end
  local surface = valid(wagon) and wagon.surface
  if not surface then return end
  local retained = {}
  for _, record in ipairs(manifest.passengers) do
    local pos = surface.find_non_colliding_position(record.entity_name, wagon.position, 12, 0.5)
    local entity = pos and surface.create_entity{name = record.entity_name, position = pos, force = record.force_name or "enemy"}
    if entity and entity.valid then
      if entity.health and record.health then entity.health = math.min(entity.health, record.health) end
      if biters and biters.restore_passenger then
        biters.restore_passenger(record, entity, true)
      else
        spawner_population.rekey_detached(record.visitor_id, entity.unit_number, entity, find_home_spawner(record))
      end
    else
      retained[#retained + 1] = record
    end
  end
  manifest.passengers = retained
  if #retained == 0 then
    manifest.outbreak_pending = nil
    storage.passenger_outbreaks[wagon.unit_number] = nil
    wagon.minable = true
  end
end

function M.on_train_changed_state(event)
  local train = event and event.train
  if not train then return end
  if train.state == defines.train_state.wait_station and valid(train.station) then
    local stop = train.station
    storage.passenger_stopped_trains[stop.unit_number] = train
    deboard_train(train, stop) -- disembark before boarding at a mixed stop
    board_train(train, stop)
    update_stop_signals(train, stop)
    return
  end
  for stop_id, stopped_train in pairs(storage.passenger_stopped_trains or {}) do
    if stopped_train == train then storage.passenger_stopped_trains[stop_id] = nil end
  end
end

function M.on_tick(event)
  ensure_storage()
  -- Saves made before passenger trains have no registry, and a source checkout
  -- can be reloaded without a configuration-change event. Rebuild once from
  -- world entities before processing queues so existing platforms work too.
  if not storage.passenger_registry_ready then M.rebuild_registry() end
  local tick = event and event.tick or game.tick
  -- Bounded in normal play by placed platforms/wagons; no surface-wide scans.
  for platform_id, record in pairs(storage.passenger_platforms) do
    local platform = record.entity
    if not valid(platform) then
      storage.passenger_platforms[platform_id] = nil
    elseif not is_rail_adjacent(platform) then
      write_platform_signals(record, 0, 0, 0, false)
      for _, info in pairs(record.queue or {}) do
        if info then release_and_reroute(info) end
      end
    elseif record.kind == "boarding-platform" then
      local _, _, train_present, has_space = boarding_train_state(record)
      local circuit_open = boarding_signal_open(record)
      for visitor_id, info in pairs(record.queue or {}) do
        local entity = info and info.entity
        if not valid(entity) then
          record.queue[visitor_id] = nil
        elseif entity.surface ~= platform.surface then
          release_and_reroute(info)
        -- Full wagons must immediately release visitors, even if an operator
        -- left the explicit boarding signal high. Without this, arrivals were
        -- stopped indefinitely at a platform that could not serve them.
        elseif train_present and not has_space then
          release_and_reroute(info)
        -- The default train-driven queue closes as soon as the train leaves.
        -- A positive Boarding Enabled signal is the one deliberate exception:
        -- it keeps a queue reserved for an incoming train.
        elseif not train_present and not circuit_open then
          release_and_reroute(info)
        elseif info.state == "waiting_for_train"
            and distance_sq(entity.position, platform.position) > PLATFORM_BOARD_RADIUS * PLATFORM_BOARD_RADIUS then
          if biters and biters.set_passenger_ground_state then biters.set_passenger_ground_state(info, "pathfinding_to_platform") else info.state = "pathfinding_to_platform" end
          info.platform_route_started_tick = tick
          issue_route(entity, info.platform_dest or platform.position)
        elseif info.state == "pathfinding_to_platform" and distance_sq(entity.position, platform.position) <= PLATFORM_BOARD_RADIUS * PLATFORM_BOARD_RADIUS then
          if biters and biters.set_passenger_ground_state then biters.set_passenger_ground_state(info, "waiting_for_train") else info.state = "waiting_for_train" end
          entity.active = false
          if entity.commandable and entity.commandable.set_command then entity.commandable.set_command({type = defines.command.stop, distraction = defines.distraction.none}) end
        elseif info.state == "pathfinding_to_platform"
            and tick - (info.platform_route_started_tick or tick) >= (C.DESK_ROUTE_STALL_TICKS or 600) then
          release_and_reroute(info)
        end
      end
      process_platform_frustration(record, tick)
    end
    if valid(platform) and is_rail_adjacent(platform) then
      local wagon = attached_passenger_wagon(record)
      local train = wagon and wagon.train
      -- Manual trains do not enter wait_station, so the stop-based handler
      -- never sees them. A stationary manual train may still use its adjacent
      -- platforms; scheduled trains retain the normal stop transfer flow.
      if wagon and train and train.manual_mode and train.speed == 0 then
        if record.kind == "boarding-platform" then
          board_platform_wagon(record, wagon)
        elseif record.kind == "deboarding-platform" then
          deboard_platform_wagon(record, wagon)
        end
      end
      update_platform_signals(record)
    end
    update_platform_visuals(record)
  end
  for wagon_id, wagon in pairs(storage.passenger_wagon_entities) do
    if valid(wagon) then
      process_wagon(wagon, tick)
      process_outbreak(wagon, manifest_for(wagon))
    else
      storage.passenger_wagon_entities[wagon_id] = nil
    end
  end
  for _, stop in pairs(storage.passenger_stops or {}) do
    if valid(stop) then
      local stopped_train = storage.passenger_stopped_trains[stop.unit_number]
      if not stopped_train and stop.get_stopped_train then stopped_train = stop.get_stopped_train() end
      if stopped_train and stopped_train.state == defines.train_state.wait_station and stopped_train.station == stop then
        deboard_train(stopped_train, stop)
        board_train(stopped_train, stop)
      else
        storage.passenger_stopped_trains[stop.unit_number] = nil
        stopped_train = nil
      end
      update_stop_signals(stopped_train, stop)
    end
  end
  for _, player in pairs(game.connected_players or {}) do
    M.update_wagon_inspector(player, player.selected)
  end
end

function M.on_built(entity, event)
  if not valid(entity) then return end
  local runtime_name = PLATFORM_PREVIEW_NAMES[entity.name]
  if runtime_name then
    local preview = entity
    entity = preview.surface.create_entity{
      name = runtime_name,
      position = preview.position,
      direction = preview.direction,
      force = preview.force,
      quality = preview.quality and preview.quality.name or nil,
      player = event and event.player_index or nil,
      raise_built = false,
      create_build_effect_smoke = false,
    }
    preview.destroy()
    if not valid(entity) then return false end
  end
  if entity.name == "boarding-platform" or entity.name == "deboarding-platform" then
    -- Retain off-rail placements so blueprints and copy/paste do not collapse
    -- into a 1x1 dropped-item marker. They remain visually red and cannot
    -- board, deboard, emit passenger signals, or attract biters until moved
    -- beside rail.
    local record = platform_record(entity)
    auto_pair(record)
    update_platform_visuals(record)
  elseif entity.name == "passenger-wagon" then
    manifest_for(entity)
  elseif entity.type == "train-stop" then
    storage.passenger_stops = storage.passenger_stops or {}
    storage.passenger_stops[entity.unit_number] = entity
    for _, record in pairs(storage.passenger_platforms or {}) do
      if not get_platform_stop(record) then auto_pair(record) end
    end
  end
  return true
end

function M.on_removed(entity)
  if not entity then return end
  ensure_storage()
  if entity.name == "boarding-platform" or entity.name == "deboarding-platform" then
    local record = storage.passenger_platforms[entity.unit_number]
    if record then
      destroy_platform_visuals(record)
      -- Visitors remain real ground entities; releasing their reservation is
      -- safe and lets the normal retry/protest system decide their next step.
      for _, info in pairs(record.queue or {}) do
        if info then release_and_reroute(info) end
      end
      storage.passenger_platforms[entity.unit_number] = nil
    end
  elseif entity.name == "passenger-wagon" then
    local manifest = storage.passenger_wagons[entity.unit_number]
    if manifest and #manifest.passengers > 0 then
      manifest.outbreak_pending = true
      storage.passenger_wagon_entities[entity.unit_number] = entity
      process_outbreak(entity, manifest)
    end
  elseif entity.type == "train-stop" then
    storage.passenger_stops[entity.unit_number] = nil
    for _, record in pairs(storage.passenger_platforms or {}) do
      if record.stop_id == entity.unit_number then record.stop_id, record.stop = nil, nil end
    end
    local combinator = storage.passenger_stop_combinators and storage.passenger_stop_combinators[entity.unit_number]
    if valid(combinator) then combinator.destroy() end
    if storage.passenger_stop_combinators then storage.passenger_stop_combinators[entity.unit_number] = nil end
  end
end

function M.rebuild_registry()
  ensure_storage()
  refresh_stop_index()
  storage.passenger_wagon_entities = {}
  for _, surface in pairs(game.surfaces or {}) do
    for _, stop in ipairs(surface.find_entities_filtered{type = "train-stop"}) do M.on_built(stop) end
    for _, platform in ipairs(surface.find_entities_filtered{name = PLATFORM_NAMES}) do M.on_built(platform) end
    for _, wagon in ipairs(surface.find_entities_filtered{name = "passenger-wagon"}) do
      storage.passenger_wagon_entities[wagon.unit_number] = wagon
      manifest_for(wagon)
    end
  end
  for wagon_id, manifest in pairs(storage.passenger_wagons) do
    local wagon = storage.passenger_wagon_entities[wagon_id]
    if valid(wagon) then wagon.minable = #(manifest.passengers or {}) == 0 end
  end
  storage.passenger_registry_ready = true
end

function M.on_init()
  M.rebuild_registry()
end

return M
