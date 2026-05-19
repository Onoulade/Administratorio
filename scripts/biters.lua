-- Biter routing, registration, resolution, protest logic
local C = require("scripts.constants")
local zones = require("scripts.zones")
local working_hours = require("scripts.working_hours")
local biters_rendering_factory = require("scripts.biters_rendering")
local biters_protests_factory = require("scripts.biters_protests")

local M = {}
local protest_rendering
local protest_system

local PROTEST_TARGET_TYPES = {
  "assembling-machine",
  "furnace",
  "lab",
  "mining-drill",
}
local PROTEST_TARGET_NAMES = {
  "office-desk",
  "greenhouse",
  "corporate-breakroom",
  "union-headquarters",
  "propaganda-distillery",
  "printer-t1",
  "printer-t2",
  "tube-intake",
  "tube-outtake",
}
local PROTEST_PROTECTED_NAMES = {
  ["admin-station"] = true,
  ["resolution-office"] = true,
}
local function protest_slogan(ticket, index)
  return {"gui.protest-slogan-" .. ticket .. "-" .. index}
end

local PROTEST_SLOGANS = {
  ["ticket-landscape"] = {
    protest_slogan("ticket-landscape", 1),
    protest_slogan("ticket-landscape", 2),
    protest_slogan("ticket-landscape", 3),
    protest_slogan("ticket-landscape", 4),
    protest_slogan("ticket-landscape", 5),
    protest_slogan("ticket-landscape", 6),
    protest_slogan("ticket-landscape", 7),
    protest_slogan("ticket-landscape", 8),
    protest_slogan("ticket-landscape", 9),
  },
  ["ticket-smog"] = {
    protest_slogan("ticket-smog", 1),
    protest_slogan("ticket-smog", 2),
    protest_slogan("ticket-smog", 3),
    protest_slogan("ticket-smog", 4),
    protest_slogan("ticket-smog", 5),
    protest_slogan("ticket-smog", 6),
    protest_slogan("ticket-smog", 7),
    protest_slogan("ticket-smog", 8),
    protest_slogan("ticket-smog", 9),
  },
  ["ticket-noise"] = {
    protest_slogan("ticket-noise", 1),
    protest_slogan("ticket-noise", 2),
    protest_slogan("ticket-noise", 3),
    protest_slogan("ticket-noise", 4),
    protest_slogan("ticket-noise", 5),
    protest_slogan("ticket-noise", 6),
    protest_slogan("ticket-noise", 7),
    protest_slogan("ticket-noise", 8),
    protest_slogan("ticket-noise", 9),
  },
  ["ticket-unemployment"] = {
    protest_slogan("ticket-unemployment", 1),
    protest_slogan("ticket-unemployment", 2),
    protest_slogan("ticket-unemployment", 3),
    protest_slogan("ticket-unemployment", 4),
    protest_slogan("ticket-unemployment", 5),
    protest_slogan("ticket-unemployment", 6),
    protest_slogan("ticket-unemployment", 7),
    protest_slogan("ticket-unemployment", 8),
    protest_slogan("ticket-unemployment", 9),
  },
  ["ticket-littering"] = {
    protest_slogan("ticket-littering", 1),
    protest_slogan("ticket-littering", 2),
    protest_slogan("ticket-littering", 3),
    protest_slogan("ticket-littering", 4),
    protest_slogan("ticket-littering", 5),
    protest_slogan("ticket-littering", 6),
    protest_slogan("ticket-littering", 7),
    protest_slogan("ticket-littering", 8),
    protest_slogan("ticket-littering", 9),
  },
  ["ticket-hazmat"] = {
    protest_slogan("ticket-hazmat", 1),
    protest_slogan("ticket-hazmat", 2),
    protest_slogan("ticket-hazmat", 3),
    protest_slogan("ticket-hazmat", 4),
    protest_slogan("ticket-hazmat", 5),
    protest_slogan("ticket-hazmat", 6),
    protest_slogan("ticket-hazmat", 7),
    protest_slogan("ticket-hazmat", 8),
    protest_slogan("ticket-hazmat", 9),
  },
  ["ticket-loitering"] = {
    protest_slogan("ticket-loitering", 1),
    protest_slogan("ticket-loitering", 2),
    protest_slogan("ticket-loitering", 3),
    protest_slogan("ticket-loitering", 4),
    protest_slogan("ticket-loitering", 5),
    protest_slogan("ticket-loitering", 6),
    protest_slogan("ticket-loitering", 7),
    protest_slogan("ticket-loitering", 8),
    protest_slogan("ticket-loitering", 9),
  },
  ["ticket-vagrancy"] = {
    protest_slogan("ticket-vagrancy", 1),
    protest_slogan("ticket-vagrancy", 2),
    protest_slogan("ticket-vagrancy", 3),
    protest_slogan("ticket-vagrancy", 4),
    protest_slogan("ticket-vagrancy", 5),
    protest_slogan("ticket-vagrancy", 6),
    protest_slogan("ticket-vagrancy", 7),
    protest_slogan("ticket-vagrancy", 8),
    protest_slogan("ticket-vagrancy", 9),
  },
}
local PROTEST_TINTS = {
  ["ticket-landscape"] = {r = 0.45, g = 0.95, b = 0.45},
  ["ticket-smog"] = {r = 0.85, g = 0.85, b = 0.9},
  ["ticket-noise"] = {r = 1, g = 0.7, b = 0.2},
  ["ticket-unemployment"] = {r = 1, g = 0.35, b = 0.3},
  ["ticket-littering"] = {r = 0.5, g = 1, b = 0.55},
  ["ticket-hazmat"] = {r = 1, g = 0.55, b = 0.2},
  ["ticket-loitering"] = {r = 0.4, g = 0.95, b = 1},
  ["ticket-vagrancy"] = {r = 1, g = 0.45, b = 0.8},
}
local PROTEST_STOP_TINT = {r = 1, g = 0.1, b = 0.1}
local PROTEST_STOP_TEXT_TINT = {r = 1, g = 0.95, b = 0.95}
local PACIFIED_WAIT_TINT = {r = 1, g = 0.76, b = 0.18}
local PACIFIED_WAIT_TEXT_TINT = {r = 1, g = 0.98, b = 0.85}
local PACIFIED_WAIT_LABEL = {"gui.pacified-wait-no-desk"}
local PROTEST_ALERT_SOUND_PATH = "administratorio-protest-alert"
local PROTEST_ALERT_SOUND_COOLDOWN_TICKS = 6 * 60
local PROTEST_ALERT_SOUND_MAX_DISTANCE = 32
local PROTEST_MAP_TAG_TEXT = {"gui.protest-map-tag"}
local PROTEST_STOP_TEXT = {"gui.protest-stop"}
local WAITING_BITER_STATE_NAMES = {"waiting", "pathfinding", "protesting", "pacified", "returning_home"}
local WAITING_PATHING_PROCESS_SHARD_COUNT = C.FRUST_PROTEST_PROCESS_SHARDS or 4
local BITER_FORCE_NAME = "administratorio-biters"

local function get_biter_force()
  return game.forces[BITER_FORCE_NAME] or game.forces["neutral"]
end

local function ensure_runtime_profile_section(runtime_profile, key)
  if not runtime_profile then return nil end
  local section = runtime_profile[key]
  if not section then
    section = game.create_profiler(true)
    runtime_profile[key] = section
  end
  return section
end

local function record_runtime_profile(runtime_profile, key, profiler)
  if not runtime_profile or not profiler then return end
  profiler.stop()
  local section = ensure_runtime_profile_section(runtime_profile, key)
  if section then
    section.add(profiler)
  end
end

local function remember_entity_tracking(info, entity)
  if not info or not entity or not entity.valid then return end
  info.entity_name = entity.name
  info.last_known_position = {x = entity.position.x, y = entity.position.y}
  info.last_known_surface_index = entity.surface.index
end

local function format_position(pos)
  if not pos then return "[nil]" end
  return "[" .. math.floor(pos.x) .. "," .. math.floor(pos.y) .. "]"
end

-- ============================================================
-- DESK-INDEXED LOOKUP
-- storage.desk_biters[desk_id] = { [unit_number] = true, ... }
-- Maintained alongside storage.waiting_biters for O(1) desk lookups
-- ============================================================

local function ensure_desk_biters()
  if not storage.desk_biters then storage.desk_biters = {} end
end

local function ensure_achievements()
  if not storage.achievements then storage.achievements = {} end
end

local function ensure_desk_circuit_dirty()
  if not storage.desk_circuit_dirty then storage.desk_circuit_dirty = {} end
end

local function is_frustration_tracked_state(state)
  return state == "waiting" or state == "pathfinding"
end

local function rebuild_waiting_biter_state_index()
  storage.waiting_biter_state_index = storage.waiting_biter_state_index or {}
  local index = storage.waiting_biter_state_index

  for key in pairs(index) do
    index[key] = nil
  end
  for _, state in ipairs(WAITING_BITER_STATE_NAMES) do
    index[state] = {}
  end

  for unit_number, info in pairs(storage.waiting_biters or {}) do
    if info then
      local state = info.state
      if state then
        index[state] = index[state] or {}
        index[state][unit_number] = true
      end
      info.tracked_unit_number = unit_number
      if is_frustration_tracked_state(state) then
        info.last_frustration_tick = info.last_frustration_tick or game.tick
      else
        info.last_frustration_tick = nil
      end
    end
  end

  storage.waiting_biter_state_index_built = true
  return index
end

local function ensure_waiting_biter_state_index()
  storage.waiting_biter_state_index = storage.waiting_biter_state_index or {}
  local index = storage.waiting_biter_state_index
  for _, state in ipairs(WAITING_BITER_STATE_NAMES) do
    index[state] = index[state] or {}
  end
  if storage.waiting_biter_state_index_built ~= true then
    return rebuild_waiting_biter_state_index()
  end
  return index
end

local function get_waiting_biter_state_set(state)
  local index = ensure_waiting_biter_state_index()
  index[state] = index[state] or {}
  return index[state]
end

local unindex_biter_from_desk

local function track_waiting_biter(unit_number, info)
  if not unit_number or not info then return end

  storage.waiting_biters[unit_number] = info
  info.tracked_unit_number = unit_number
  if info.entity and info.entity.valid and info.state ~= "returning_home" then
    info.entity.force = get_biter_force()
  end

  local state = info.state
  if state then
    local state_set = get_waiting_biter_state_set(state)
    state_set[unit_number] = true
  end

  if is_frustration_tracked_state(state) and not info.last_frustration_tick then
    info.last_frustration_tick = game.tick
  end
end

local function untrack_waiting_biter(unit_number, info)
  if not unit_number then return end

  local tracked_info = info or storage.waiting_biters[unit_number]
  if tracked_info and tracked_info.desk_id then
    unindex_biter_from_desk(tracked_info.desk_id, unit_number)
  end
  if tracked_info and tracked_info.state then
    local state_set = get_waiting_biter_state_set(tracked_info.state)
    state_set[unit_number] = nil
    if tracked_info.tracked_unit_number == unit_number then
      tracked_info.tracked_unit_number = nil
    end
    tracked_info.last_frustration_tick = nil
  end

  storage.waiting_biters[unit_number] = nil
end

local function replace_tracked_waiting_biter_unit_number(old_unit_number, new_unit_number, info)
  if not old_unit_number or not new_unit_number or not info then return end

  if old_unit_number ~= new_unit_number and info.state then
    local state_set = get_waiting_biter_state_set(info.state)
    state_set[old_unit_number] = nil
    state_set[new_unit_number] = true
  end

  storage.waiting_biters[old_unit_number] = nil
  storage.waiting_biters[new_unit_number] = info
  info.tracked_unit_number = new_unit_number
end

local function set_waiting_biter_state(info, state)
  if not info or info.state == state then return end

  local old_state = info.state
  local unit_number = info.tracked_unit_number or (info.entity and info.entity.valid and info.entity.unit_number) or nil

  if old_state and unit_number then
    local old_state_set = get_waiting_biter_state_set(old_state)
    old_state_set[unit_number] = nil
  end

  info.state = state

  if state and unit_number then
    local new_state_set = get_waiting_biter_state_set(state)
    new_state_set[unit_number] = true
  end

  if is_frustration_tracked_state(state) then
    if not is_frustration_tracked_state(old_state) then
      info.last_frustration_tick = game.tick
    end
  else
    info.last_frustration_tick = nil
  end
end

local function mark_desk_circuit_dirty(desk_id)
  if not desk_id then return end
  ensure_desk_circuit_dirty()
  storage.desk_circuit_dirty[desk_id] = true
end

local function clear_desk_circuit_tracking(desk_id)
  if not desk_id or not storage.desk_circuit_dirty then return end
  storage.desk_circuit_dirty[desk_id] = nil
end

local function mark_all_desk_circuit_dirty()
  ensure_desk_circuit_dirty()
  for desk_id in pairs(storage.admin_desks or {}) do
    storage.desk_circuit_dirty[desk_id] = true
  end
  for desk_id in pairs(storage.desk_combinators or {}) do
    storage.desk_circuit_dirty[desk_id] = true
  end
  for desk_id in pairs(storage.desk_biters or {}) do
    storage.desk_circuit_dirty[desk_id] = true
  end
end

function M.mark_desk_circuit_dirty(desk_id)
  mark_desk_circuit_dirty(desk_id)
end

function M.clear_desk_circuit_tracking(desk_id)
  clear_desk_circuit_tracking(desk_id)
end

function M.mark_all_desk_circuit_dirty()
  mark_all_desk_circuit_dirty()
end

local function index_biter_to_desk(desk_id, unit_number)
  if not desk_id or not unit_number then return end
  ensure_desk_biters()
  if not storage.desk_biters[desk_id] then storage.desk_biters[desk_id] = {} end
  if not storage.desk_biters[desk_id][unit_number] then
    zones.increment_desk_occupants(desk_id)
  end
  storage.desk_biters[desk_id][unit_number] = true
  mark_desk_circuit_dirty(desk_id)
end

unindex_biter_from_desk = function(desk_id, unit_number)
  if not desk_id or not unit_number then return end
  ensure_desk_biters()
  if storage.desk_biters[desk_id] then
    if storage.desk_biters[desk_id][unit_number] then
      zones.decrement_desk_occupants(desk_id)
    end
    storage.desk_biters[desk_id][unit_number] = nil
  end
  mark_desk_circuit_dirty(desk_id)
end

function M.rebuild_desk_index()
  rebuild_waiting_biter_state_index()
  storage.desk_biters = {}
  for b_id, info in pairs(storage.waiting_biters or {}) do
    if info.desk_id then
      if not storage.desk_biters[info.desk_id] then storage.desk_biters[info.desk_id] = {} end
      storage.desk_biters[info.desk_id][b_id] = true
    end
  end
  zones.rebuild_desk_occupant_counts()
  mark_all_desk_circuit_dirty()
end

local function get_cached_desks()
  storage.admin_desks = storage.admin_desks or {}
  local desks = {}
  for id, desk in pairs(storage.admin_desks or {}) do
    if desk.valid then
      storage.admin_desks[desk.unit_number] = desk
      desks[#desks + 1] = desk
    else
      storage.admin_desks[id] = nil
    end
  end
  if #desks == 0 and game and game.surfaces then
    for _, surface in pairs(game.surfaces) do
      for _, desk in ipairs(surface.find_entities_filtered{
        name = {"admin-station"},
      }) do
        if desk.valid then
          storage.admin_desks[desk.unit_number] = desk
          zones.ensure_desk_runtime_state(desk)
          desks[#desks + 1] = desk
        end
      end
    end
  end
  return desks
end

local function find_nearest_available_desk(position)
  local best = nil
  local best_dist = math.huge
  for _, desk in ipairs(get_cached_desks()) do
    local available = zones.get_available_slots(desk.unit_number)
    local dx = desk.position.x - position.x
    local dy = desk.position.y - position.y
    local dist = dx * dx + dy * dy
    if available > 0 and dist < best_dist then
      best_dist = dist
      best = desk
    end
  end
  return best
end

local function remember_home_spawner(info, spawner)
  if not info or not spawner or not spawner.valid or spawner.type ~= "unit-spawner" then return end
  info.home_spawner = spawner
  info.home_spawner_unit_number = spawner.unit_number
  info.home_position = {x = spawner.position.x, y = spawner.position.y}
  info.home_surface_index = spawner.surface and spawner.surface.index or nil
end

local function remember_home_position(info, entity)
  if not info or not entity or not entity.valid then return end
  if info.home_position then return end
  info.home_position = {x = entity.position.x, y = entity.position.y}
  info.home_surface_index = entity.surface and entity.surface.index or nil
end

local function copy_complaints(complaints)
  local copy = {}
  if not complaints then return copy end
  for i, complaint in ipairs(complaints) do
    copy[i] = complaint
  end
  return copy
end

local function normalize_case_progress(info)
  if not info then return end
  local unresolved = #(info.complaints or {})
  if info.complaints_total == nil or info.complaints_total < unresolved then
    info.complaints_total = unresolved
  end
  if info.state == "waiting" and info.complaints_filed == nil then
    info.complaints_filed = true
  end
end

local function capture_home_spawner(info, entity, should_release)
  if not info or not entity or not entity.valid then return end
  local commandable = entity.commandable
  if not commandable then return end

  local spawner = commandable.spawner
  if not spawner or not spawner.valid or spawner.type ~= "unit-spawner" then return end

  remember_home_spawner(info, spawner)
  if should_release then
    commandable.release_from_spawner()
  end
end

local function adopt_redirected_biter(info, entity, force_name)
  if not entity or not entity.valid then return nil end

  local surface = entity.surface
  local position = surface.find_non_colliding_position(entity.name, entity.position, 2, 0.25)
  if not position then
    capture_home_spawner(info, entity, true)
    return entity
  end

  local replacement = surface.create_entity{
    name = entity.name,
    position = position,
    force = force_name or entity.force.name,
  }
  if not replacement or not replacement.valid then
    capture_home_spawner(info, entity, true)
    return entity
  end

  capture_home_spawner(info, entity, false)
  if entity.health and replacement.health then
    replacement.health = entity.health
  end
  remember_entity_tracking(info, replacement)
  entity.destroy()
  return replacement
end

local function get_desk_waiting_destination(entity, desk, unit_number)
  if not entity or not entity.valid or not desk or not desk.valid then return nil end
  return zones.get_zone_position(entity.surface, desk.unit_number, entity.name, unit_number)
    or zones.get_zone_position(entity.surface, desk.unit_number, entity.name, nil)
    or zones.get_queue_pos(desk)
end

local function issue_desk_route_command(entity, destination)
  if not entity or not entity.valid or not destination then return false end

  entity.force = get_biter_force()
  entity.active = true
  entity.commandable.set_command({
    type = defines.command.go_to_location,
    destination = destination,
    radius = C.DESK_SLOT_COMMAND_RADIUS,
    distraction = defines.distraction.none,
  })
  return true
end

local function park_waiting_biter(info, entity)
  if not info or not entity or not entity.valid then return end

  set_waiting_biter_state(info, "waiting")
  info.desk_dest = nil
  entity.force = get_biter_force()
  entity.commandable.set_command({
    type = defines.command.stop,
    distraction = defines.distraction.none,
  })
  entity.active = false
  remember_entity_tracking(info, entity)
  mark_desk_circuit_dirty(info.desk_id)
end

local function finalize_pathfinding_biter_arrival(info, desk, source)
  if not info or not info.entity or not info.entity.valid or not desk or not desk.valid then return false end

  local entity = info.entity
  local b_id = entity.unit_number
  normalize_case_progress(info)

  local complaints = copy_complaints(info.complaints)
  local complaints_filed = info.complaints_filed == true
  if not complaints_filed and #complaints == 0 then
    complaints = C.generate_complaints(entity.name)
  end
  local complaints_total = info.complaints_total or #complaints
  local inv = desk.get_inventory(defines.inventory.chest)
  local chest_ok = inv ~= nil

  if inv and not complaints_filed then
    local inserted = {}
    for _, c in ipairs(complaints) do
      if inv.insert({name = c, count = 1}) > 0 then
        inserted[#inserted + 1] = c
      else
        for _, ci in ipairs(inserted) do inv.remove({name = ci, count = 1}) end
        chest_ok = false
        break
      end
    end
  end

  if not chest_ok then
    zones.release_slot(desk.unit_number, b_id)
    unindex_biter_from_desk(desk.unit_number, b_id)
    untrack_waiting_biter(b_id, info)
    M.trigger_immediate_protest(entity, entity.surface, info)
    return true
  end

  if complaints_filed then
    --   .. ": " .. tostring(#complaints) .. " unresolved of " .. tostring(complaints_total)
    --   .. " total complaints still tracked in memory")
  end

  info.entity = entity
  info.entity_name = entity.name
  info.desk_id = desk.unit_number
  info.complaints = complaints
  info.complaints_total = complaints_total
  info.complaints_filed = true
  info.frust_accum = info.frust_accum or 0
  park_waiting_biter(info, entity)
  mark_desk_circuit_dirty(desk.unit_number)

  if source then
    --   .. ") at " .. format_position(entity.position) .. " for desk " .. desk.unit_number)
  end

  if not storage.achievements.first_complaint then
    storage.achievements.first_complaint = true
    for _, p in pairs(game.connected_players) do
      p.unlock_achievement("first-complaint")
    end
  end
  if not storage.achievements.behemoth_registered then
    if entity.name == "behemoth-biter" or entity.name == "behemoth-spitter" then
      storage.achievements.behemoth_registered = true
      for _, p in pairs(game.connected_players) do
        p.unlock_achievement("behemoth-paperwork")
      end
    end
  end

  return true
end

local function ensure_desk_return_positions()
  storage.desk_return_positions = storage.desk_return_positions or {}
  return storage.desk_return_positions
end

local function get_return_direction(info, entity)
  local origin = entity.position
  local anchor = info.home_position
  if not anchor and info.home_spawner and info.home_spawner.valid then
    anchor = info.home_spawner.position
  end

  local dx = anchor and (anchor.x - origin.x) or origin.x
  local dy = anchor and (anchor.y - origin.y) or origin.y
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 1 then
    local angle = math.random() * 2 * math.pi
    dx = math.cos(angle)
    dy = math.sin(angle)
    len = 1
  end
  return dx / len, dy / len
end

local function find_desk_return_position(info, entity)
  if not entity.surface then return nil end
  local surface = entity.surface
  local origin = entity.position
  local dx, dy = get_return_direction(info, entity)
  local distances = {
    C.RETURN_WALK_DISTANCE or 200,
    150,
    100,
    60,
    35,
  }

  for _, distance in ipairs(distances) do
    local probe = {x = origin.x + dx * distance, y = origin.y + dy * distance}
    local position = surface.find_non_colliding_position(
      entity.name,
      probe,
      C.RETURN_EXIT_SEARCH_RADIUS or 24,
      C.RETURN_EXIT_SEARCH_PRECISION or 2
    )
    if position then
      return {x = position.x, y = position.y}, distance
    end
  end
  return nil
end

local function get_cached_desk_return_position(info, entity, desk_id)
  if not desk_id or not entity.surface then return nil, false end
  local return_positions = ensure_desk_return_positions()
  local cached = return_positions[desk_id]
  local surface_index = entity.surface.index
  if cached and cached.surface_index == surface_index and cached.position then
    return {x = cached.position.x, y = cached.position.y}, true
  end

  local position, distance = find_desk_return_position(info, entity)
  if not position then return nil, false end
  return_positions[desk_id] = {
    position = {x = position.x, y = position.y},
    surface_index = surface_index,
    distance = distance,
  }
  return {x = position.x, y = position.y}, true
end

local function start_return_home(info, entity, opts)
  if not info or not entity or not entity.valid then return false end
  opts = opts or {}

  local desk_id = info.desk_id
  local spawner = info.home_spawner
  local home_position = info.home_position
  local desk_exit, used_cached_exit = nil, false
  if not opts.force_home_position then
    desk_exit, used_cached_exit = get_cached_desk_return_position(info, entity, desk_id)
  end
  local spawner_dest = spawner and spawner.valid and {x = spawner.position.x, y = spawner.position.y} or nil
  local home_dest = home_position and {x = home_position.x, y = home_position.y} or nil
  local dest = nil
  if opts.force_home_position then
    dest = home_dest or spawner_dest
  else
    dest = desk_exit or spawner_dest or home_dest
  end
  if not dest then return false end

  set_waiting_biter_state(info, "returning_home")
  info.frustration = 0
  info.frust_accum = 0
  protest_system.reset_protest_targeting(info)
  info.promise_retry_until_tick = nil
  info.desk_id = nil
  info.desk_dest = nil
  info.return_spawner = spawner and spawner.valid and spawner or nil
  info.return_dest = dest
  info.return_cached_desk_id = used_cached_exit and desk_id or nil
  info.return_target_kind = used_cached_exit and "desk_exit"
    or (dest == spawner_dest and "spawner" or (dest == home_dest and "home_position" or "unknown"))
  info.return_started_tick = game.tick
  info.return_arrival_check_tick = game.tick + (C.RETURN_MIN_TRAVEL_TICKS or 0)
  info.return_despawn_tick = game.tick + C.RETURN_DESPAWN_TICKS

  entity.force = get_biter_force()
  entity.destructible = false
  entity.active = true
  entity.commandable.set_command({
    type = defines.command.go_to_location,
    destination = dest,
    radius = C.RETURN_ARRIVAL_DISTANCE or 2.5,
    distraction = defines.distraction.none,
  })
  return true
end

local function route_biter_to_desk(info, entity, desk, opts)
  if not info or not entity or not entity.valid or not desk or not desk.valid then return false end
  local slot = zones.reserve_slot(desk.unit_number, entity.unit_number)
  if not slot then return false end
  opts = opts or {}

  info.desk_id = desk.unit_number
  set_waiting_biter_state(info, "pathfinding")
  remember_home_position(info, entity)
  if opts.initial_frustration ~= nil then
    info.frustration = opts.initial_frustration
  else
    info.frustration = 0
  end
  protest_system.reset_protest_targeting(info)
  info.promise_retry_until_tick = nil
  info.return_spawner = nil
  info.return_dest = nil
  info.return_cached_desk_id = nil
  info.return_target_kind = nil
  info.return_failed_once = nil

  index_biter_to_desk(desk.unit_number, entity.unit_number)
  local dest = get_desk_waiting_destination(entity, desk, entity.unit_number)
  if not dest then
    zones.release_slot_by_index(desk.unit_number, slot)
    unindex_biter_from_desk(desk.unit_number, entity.unit_number)
    return false
  end
  info.desk_dest = dest
  if issue_desk_route_command(entity, dest) then return true end
  zones.release_slot_by_index(desk.unit_number, slot)
  unindex_biter_from_desk(desk.unit_number, entity.unit_number)
  return false
end

protest_rendering = biters_rendering_factory.new({
  format_position = format_position,
  pacified_wait_label = PACIFIED_WAIT_LABEL,
  pacified_wait_text_tint = PACIFIED_WAIT_TEXT_TINT,
  pacified_wait_tint = PACIFIED_WAIT_TINT,
  protest_alert_sound_cooldown_ticks = PROTEST_ALERT_SOUND_COOLDOWN_TICKS,
  protest_alert_sound_max_distance = PROTEST_ALERT_SOUND_MAX_DISTANCE,
  protest_alert_sound_path = PROTEST_ALERT_SOUND_PATH,
  protest_map_tag_text = PROTEST_MAP_TAG_TEXT,
  protest_slogans = PROTEST_SLOGANS,
  protest_stop_text = PROTEST_STOP_TEXT,
  protest_stop_text_tint = PROTEST_STOP_TEXT_TINT,
  protest_stop_tint = PROTEST_STOP_TINT,
  protest_tints = PROTEST_TINTS,
})

protest_system = biters_protests_factory.new({
  adopt_redirected_biter = adopt_redirected_biter,
  background_state_shard_count = WAITING_PATHING_PROCESS_SHARD_COUNT,
  biter_force_name = BITER_FORCE_NAME,
  get_biter_force = get_biter_force,
  constants = C,
  copy_complaints = copy_complaints,
  ensure_achievements = ensure_achievements,
  ensure_desk_biters = ensure_desk_biters,
  ensure_waiting_biter_state_index = ensure_waiting_biter_state_index,
  finalize_pathfinding_biter_arrival = finalize_pathfinding_biter_arrival,
  find_nearest_available_desk = find_nearest_available_desk,
  format_position = format_position,
  get_cached_desks = get_cached_desks,
  get_desk_waiting_destination = get_desk_waiting_destination,
  get_waiting_biter_state_set = get_waiting_biter_state_set,
  index_biter_to_desk = index_biter_to_desk,
  issue_desk_route_command = issue_desk_route_command,
  mark_desk_circuit_dirty = mark_desk_circuit_dirty,
  normalize_case_progress = normalize_case_progress,
  protest_protected_names = PROTEST_PROTECTED_NAMES,
  protest_target_names = PROTEST_TARGET_NAMES,
  protest_target_types = PROTEST_TARGET_TYPES,
  remember_entity_tracking = remember_entity_tracking,
  remember_home_spawner = remember_home_spawner,
  render = protest_rendering,
  replace_tracked_waiting_biter_unit_number = replace_tracked_waiting_biter_unit_number,
  route_biter_to_desk = route_biter_to_desk,
  send_biter_to_station_with_targets = function(...)
    return M.send_biter_to_station_with_targets(...)
  end,
  set_waiting_biter_state = set_waiting_biter_state,
  start_return_home = start_return_home,
  track_waiting_biter = track_waiting_biter,
  untrack_waiting_biter = untrack_waiting_biter,
  unindex_biter_from_desk = unindex_biter_from_desk,
  working_hours = working_hours,
  zones = zones,
})

function M.refresh_protest_notifications(player)
  protest_system.refresh_protest_notifications(player)
end

function M.on_protest_target_removed(entity)
  protest_system.on_protest_target_removed(entity)
end

function M.reroute_desk_biters(desk_id, surface)
  protest_system.reroute_desk_biters(desk_id, surface)
end

function M.trigger_immediate_protest(entity, surface, previous_info)
  protest_system.trigger_immediate_protest(entity, surface, previous_info)
end

function M.send_biter_to_station_with_targets(entity, targets, opts)
  if not entity.valid or entity.type ~= "unit" or entity.force.name ~= "enemy" then return end
  if #targets == 0 then
    return
  end
  opts = opts or {}
  local initial_frustration = opts.initial_frustration or 0

  local min_dist = math.huge
  local best = nil
  for _, desk in ipairs(targets) do
    if zones.get_available_slots(desk.unit_number) > 0 then
      local dist = (desk.position.x - entity.position.x)^2 + (desk.position.y - entity.position.y)^2
      if dist < min_dist then
        min_dist = dist
        best = desk
      end
    end
  end

  if best then
    --   .. " at [" .. math.floor(best.position.x) .. "," .. math.floor(best.position.y) .. "], dist=" .. math.floor(math.sqrt(min_dist)))
    local info = {
      entity = entity,
      desk_id = best.unit_number,
      complaints = {},
      complaints_total = 0,
      complaints_filed = false,
      frustration = initial_frustration,
      state = "pathfinding",
    }
    info.entity_name = entity.name
    entity = adopt_redirected_biter(info, entity, BITER_FORCE_NAME)
    if not entity or not entity.valid then return end

    info.entity = entity
    track_waiting_biter(entity.unit_number, info)
    if not route_biter_to_desk(info, entity, best, {initial_frustration = initial_frustration}) then
      untrack_waiting_biter(entity.unit_number, info)
      M.trigger_immediate_protest(entity, entity.surface, info)
    end
  else
    M.trigger_immediate_protest(entity, entity.surface)
  end
end

local function enforce_desk_capacity_limit(desk)
  if not desk or not desk.valid then return end
  ensure_desk_biters()
  local desk_id = desk.unit_number
  local desk_set = storage.desk_biters[desk_id]
  if not desk_set then return end

  local capacity = zones.get_zone_capacity(desk_id)
  local occupants = {}
  for b_id in pairs(desk_set) do
    local info = storage.waiting_biters[b_id]
    if info and info.desk_id == desk_id and (info.state == "waiting" or info.state == "pathfinding")
       and info.entity and info.entity.valid then
      occupants[#occupants + 1] = {b_id = b_id, info = info}
    end
  end

  if #occupants <= capacity then return end
  table.sort(occupants, function(a, b) return a.b_id < b.b_id end)
  for i = capacity + 1, #occupants do
    local entry = occupants[i]
    zones.release_slot(desk_id, entry.b_id)
    unindex_biter_from_desk(desk_id, entry.b_id)
    untrack_waiting_biter(entry.b_id, entry.info)
    M.trigger_immediate_protest(entry.info.entity, desk.surface, entry.info)
  end
  mark_desk_circuit_dirty(desk_id)
end

function M.process_walk_in_registration(surface, desks, runtime_profile)
  ensure_achievements()
  local walkin_scan_ticks = C.REGISTRATION_WALKIN_SCAN_TICKS or 1
  local walkin_shard = math.floor(game.tick / 60) % walkin_scan_ticks

  for _, desk in ipairs(desks) do
    enforce_desk_capacity_limit(desk)
    local walkins_profiler = runtime_profile and game.create_profiler() or nil
    local should_scan_walkins = walkin_scan_ticks <= 1 or (desk.unit_number % walkin_scan_ticks) == walkin_shard
    if should_scan_walkins then
      local remaining_slots = zones.get_available_slots(desk.unit_number)
      local search_pos = desk.position
      local search_radius = 10

      if remaining_slots > 0 then
        for _, biter in ipairs(surface.find_entities_filtered{force = "enemy", type = "unit", position = search_pos, radius = search_radius}) do
          if biter.valid and biter.force.name == "enemy" and not storage.waiting_biters[biter.unit_number] then
            if remaining_slots <= 0 then break end
            local complaints = C.generate_complaints(biter.name)
            local info = {
              entity = biter,
              desk_id = nil,
              complaints = complaints,
              complaints_total = #complaints,
              complaints_filed = false,
              frustration = 0,
              state = "pathfinding",
            }
            info.entity_name = biter.name
            capture_home_spawner(info, biter, true)
            track_waiting_biter(biter.unit_number, info)
            if route_biter_to_desk(info, biter, desk) then
              remaining_slots = remaining_slots - 1
            else
              untrack_waiting_biter(biter.unit_number, info)
              M.trigger_immediate_protest(biter, surface, info)
            end
          end
        end
      end
    end
    record_runtime_profile(runtime_profile, "registration_walkins", walkins_profiler)

    local arrivals_profiler = runtime_profile and game.create_profiler() or nil
    local arrived = {}
    ensure_desk_biters()
    local desk_set = storage.desk_biters[desk.unit_number]
    if desk_set then
      for b_id in pairs(desk_set) do
        local info = storage.waiting_biters[b_id]
        if info and info.state == "pathfinding" and info.entity and info.entity.valid then
          local desired_dest = get_desk_waiting_destination(info.entity, desk, b_id)
          if desired_dest then
            local current_dest = info.desk_dest
            local needs_retarget = not current_dest
            if current_dest then
              local dx = current_dest.x - desired_dest.x
              local dy = current_dest.y - desired_dest.y
              needs_retarget = (dx * dx + dy * dy) > 0.25 * 0.25
            end
            if needs_retarget then
              info.desk_dest = desired_dest
              issue_desk_route_command(info.entity, desired_dest)
            end
          end

          local arrival_dest = info.desk_dest or desired_dest
          if arrival_dest then
            local dx = info.entity.position.x - arrival_dest.x
            local dy = info.entity.position.y - arrival_dest.y
            if dx * dx + dy * dy <= C.DESK_SLOT_ARRIVAL_DISTANCE * C.DESK_SLOT_ARRIVAL_DISTANCE then
              arrived[#arrived + 1] = {b_id = b_id, info = info}
            end
          end
        end
      end
    end
    for _, entry in ipairs(arrived) do
      if entry.info.entity and entry.info.entity.valid then
        finalize_pathfinding_biter_arrival(entry.info, desk, "scan")
      end
    end
    record_runtime_profile(runtime_profile, "registration_arrivals", arrivals_profiler)
  end
end

function M.process_resolutions(desks)
  ensure_desk_biters()
  ensure_achievements()
  for _, desk in ipairs(desks) do
    local inv = desk.get_inventory(defines.inventory.chest)
    if inv and not inv.is_empty() then
      local resolved_count = 0
      local desk_id = desk.unit_number
      local desk_set = storage.desk_biters[desk_id]

      for i = 1, #inv do
        if resolved_count >= 5 then break end
        local stack = inv[i]
        if stack.valid_for_read and stack.name:find("resolved") then
          local item_name = stack.name
          local target_ticket = item_name:gsub("resolved", "ticket")
          local matched = false

          if desk_set then
            for b_id in pairs(desk_set) do
              local info = storage.waiting_biters[b_id]
              if info and info.state == "waiting" and info.entity and info.entity.valid then
                for j, req in ipairs(info.complaints) do
                  if req == target_ticket then
                    table.remove(info.complaints, j)
                    inv.remove({name = item_name, count = 1})
                    resolved_count = resolved_count + 1
                    matched = true
                    mark_desk_circuit_dirty(desk_id)

                    if not storage.achievements.first_resolved then
                      storage.achievements.first_resolved = true
                      for _, player in pairs(game.connected_players) do
                        player.unlock_achievement("case-closed")
                      end
                    end
                    if not storage.achievements.full_resolution then
                      storage.achievements.resolved_types = storage.achievements.resolved_types or {}
                      storage.achievements.resolved_types[item_name] = true
                      local type_count = 0
                      for _ in pairs(storage.achievements.resolved_types) do type_count = type_count + 1 end
                      if type_count >= 8 then
                        storage.achievements.full_resolution = true
                        for _, player in pairs(game.connected_players) do
                          player.unlock_achievement("full-resolution")
                        end
                      end
                    end

                    if #info.complaints == 0 then
                      local biter_name = info.entity.name
                      local biter_unit = info.entity.unit_number
                      zones.release_slot(desk_id, biter_unit)
                      unindex_biter_from_desk(desk_id, b_id)

                      -- Try to hire the biter if a job-offer is in the desk
                      local worker_yield = C.BITER_WORKER_YIELD[biter_name]
                      local hired = false
                      if worker_yield and inv.get_item_count("job-offer") > 0
                         and inv.can_insert({name = "biter-worker", count = worker_yield}) then
                        inv.remove({name = "job-offer", count = 1})
                        inv.insert({name = "biter-worker", count = worker_yield})
                        if info.entity and info.entity.valid then
                          info.entity.destroy()
                        end
                        untrack_waiting_biter(b_id, info)
                        hired = true
                        if storage.stats then storage.stats.biters_hired = (storage.stats.biters_hired or 0) + 1 end
                      end

                      if not hired then
                        start_return_home(info, info.entity)
                        local amount = C.BITER_PAYOUT[biter_name]
                        if amount and inv.can_insert({name = "taxpayer-money", count = amount}) then
                          inv.insert({name = "taxpayer-money", count = amount})
                          if storage.stats then storage.stats.money_earned = (storage.stats.money_earned or 0) + amount end
                        end
                      end

                      if storage.stats then storage.stats.cases_resolved = (storage.stats.cases_resolved or 0) + 1 end
                      mark_desk_circuit_dirty(desk_id)
                    end
                    break
                  end
                end
              end
              if matched then break end
            end
          end
        end
      end
    end
  end
end

function M.process_frustration_and_protests(surface)
  protest_system.process_frustration_and_protests(surface)
end

function M.process_calmed_spawners(tick)
  protest_system.process_calmed_spawners(tick)
end

function M.process_protest_pacing(surface)
  protest_system.process_protest_pacing(surface)
end

function M.on_ai_command_completed(event)
  protest_system.on_ai_command_completed(event)
end

function M.on_script_path_request_finished(event)
  protest_system.on_script_path_request_finished(event)
end

function M.on_script_trigger_effect(event)
  protest_system.on_script_trigger_effect(event)
end

function M.on_biter_died(entity)
  protest_system.on_biter_died(entity)
end

function M.on_biter_removed(entity, event)
  return protest_system.on_biter_removed(entity, event)
end

function M.update_circuit_signals(desks)
  ensure_desk_biters()
  ensure_desk_circuit_dirty()
  for _, desk in ipairs(desks) do
    local desk_id = desk.unit_number
    if storage.desk_circuit_dirty[desk_id] then
      local combinator = storage.desk_combinators[desk_id]
      if combinator and combinator.valid then
        local complaint_counts = {l = 0, s = 0, n = 0, u = 0, lt = 0, h = 0, lo = 0, v = 0}
        local total_waiting = 0
        local desk_set = storage.desk_biters[desk_id]
        if desk_set then
          for b_id in pairs(desk_set) do
            local info = storage.waiting_biters[b_id]
            if info and info.state == "waiting" and info.entity and info.entity.valid then
              total_waiting = total_waiting + 1
              for _, ticket in ipairs(info.complaints) do
                if ticket == "ticket-landscape" then complaint_counts.l = complaint_counts.l + 1
                elseif ticket == "ticket-smog" then complaint_counts.s = complaint_counts.s + 1
                elseif ticket == "ticket-noise" then complaint_counts.n = complaint_counts.n + 1
                elseif ticket == "ticket-unemployment" then complaint_counts.u = complaint_counts.u + 1
                elseif ticket == "ticket-littering" then complaint_counts.lt = complaint_counts.lt + 1
                elseif ticket == "ticket-hazmat" then complaint_counts.h = complaint_counts.h + 1
                elseif ticket == "ticket-loitering" then complaint_counts.lo = complaint_counts.lo + 1
                elseif ticket == "ticket-vagrancy" then complaint_counts.v = complaint_counts.v + 1
                end
              end
            end
          end
        end

        local available = zones.get_available_slots(desk_id)
        local behavior = combinator.get_or_create_control_behavior()
        if behavior then
          local section = behavior.get_section(1)
          if not section then section = behavior.add_section() end
          if section then
            section.set_slot(1, {value = "signal-complaint-l", min = complaint_counts.l})
            section.set_slot(2, {value = "signal-complaint-s", min = complaint_counts.s})
            section.set_slot(3, {value = "signal-complaint-n", min = complaint_counts.n})
            section.set_slot(4, {value = "signal-complaint-u", min = complaint_counts.u})
            section.set_slot(5, {value = "signal-complaint-lt", min = complaint_counts.lt})
            section.set_slot(6, {value = "signal-complaint-h", min = complaint_counts.h})
            section.set_slot(7, {value = "signal-complaint-lo", min = complaint_counts.lo})
            section.set_slot(8, {value = "signal-complaint-v", min = complaint_counts.v})
            section.set_slot(9, {value = "signal-available-slots", min = available})
            section.set_slot(10, {value = "signal-total-waiting", min = total_waiting})
          end
        end
      end
      storage.desk_circuit_dirty[desk_id] = nil
    end
  end
end

function M.evict_target(surface, target)
  if not protest_system then return false end
  return protest_system.evict_target(surface, target)
end

return M
