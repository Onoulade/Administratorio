-- Biter routing, registration, resolution, protest logic
local C = require("scripts.constants")
local feature_flags = require("feature_flags")
local zones = require("scripts.zones")
local working_hours = require("scripts.working_hours")
local biters_rendering_factory = require("scripts.biters_rendering")
local biters_protests_factory = require("scripts.biters_protests")
local unit_ai_settings = require("scripts.unit_ai_settings")
local protest_targets = require("scripts.protest_targets")
local spawner_population = require("scripts.spawner_population")
local pentapods = require("scripts.pentapods")

local M = {}
local SPACE_AGE_ENABLED = feature_flags.space_age_enabled()
local protest_rendering
local protest_system

local PROTEST_TARGET_TYPES = protest_targets.get_target_types()
local PROTEST_TARGET_NAMES = protest_targets.get_target_names()
local PROTEST_PROTECTED_NAMES = protest_targets.get_protected_names()
local PROTEST_OBSTACLE_BUILDING_TYPES = protest_targets.get_obstacle_building_types
  and protest_targets.get_obstacle_building_types()
  or PROTEST_TARGET_TYPES
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
local WAITING_BITER_STATE_NAMES = {"waiting", "pathfinding", "protesting", "pacified", "returning_home", "attacking"}
local WAITING_PATHING_PROCESS_SHARD_COUNT = C.FRUST_PROTEST_PROCESS_SHARDS or 4
local DESK_CIRCUIT_RECONCILE_TICKS = 60
local BITER_FORCE_NAME = "administratorio-biters"
local HARD_MODE_ATTACK_FORCE_NAME = C.HARD_MODE_ATTACK_FORCE_NAME or "administratorio-hard-mode-biters"

local function get_biter_force()
  return game.forces[BITER_FORCE_NAME] or game.forces["neutral"]
end

local function set_force_cease_fire(left, right, value)
  if left and right and left.set_cease_fire then
    pcall(function() left.set_cease_fire(right, value) end)
  end
end

local function set_force_friend(left, right, value)
  if left and right and left.set_friend then
    pcall(function() left.set_friend(right, value) end)
  end
end

local function configure_hard_mode_attack_force(force)
  if not force then return nil end

  local player = game.forces["player"]
  local enemy = game.forces["enemy"]
  local neutral = game.forces["neutral"]
  local biter_force = get_biter_force()

  set_force_cease_fire(force, player, false)
  set_force_cease_fire(player, force, false)
  set_force_friend(force, player, false)
  set_force_friend(player, force, false)

  set_force_cease_fire(force, enemy, true)
  set_force_cease_fire(enemy, force, true)
  set_force_cease_fire(force, biter_force, true)
  set_force_cease_fire(biter_force, force, true)
  set_force_cease_fire(force, neutral, true)
  set_force_cease_fire(neutral, force, true)

  return force
end

local function get_hard_mode_attack_force()
  local force = game.forces[HARD_MODE_ATTACK_FORCE_NAME]
  if not force and game.create_force then
    local ok, created = pcall(function()
      return game.create_force(HARD_MODE_ATTACK_FORCE_NAME)
    end)
    if ok then force = created end
  end
  return configure_hard_mode_attack_force(force) or get_biter_force()
end

local SPITTER_TOURISM_PACKAGE_ITEMS = {
  ["small-spitter"] = "small-spitter-tourism-package",
  ["medium-spitter"] = "medium-spitter-tourism-package",
  ["big-spitter"] = "big-spitter-tourism-package",
  ["behemoth-spitter"] = "behemoth-spitter-tourism-package",
}
local SPOILED_SPITTER_HATCH_EFFECTS = {
  ["administratorio-small-spitter-tourism-hatch"] = "small-spitter",
  ["administratorio-medium-spitter-tourism-hatch"] = "medium-spitter",
  ["administratorio-big-spitter-tourism-hatch"] = "big-spitter",
  ["administratorio-behemoth-spitter-tourism-hatch"] = "behemoth-spitter",
}
local SPACE_TOURIST_RELEASE_ITEMS = {
  ["small-space-tourist"] = "small-spitter",
  ["medium-space-tourist"] = "medium-spitter",
  ["big-space-tourist"] = "big-spitter",
  ["behemoth-space-tourist"] = "behemoth-spitter",
}
local CAPTURE_BUREAU_LURE_FLUIDS = {
  {name = "workforce-lure-spores", mode = "workforce"},
  {name = "tourism-lure-spores", mode = "tourism"},
  {name = "oviposition-lure-spores", mode = "pentapod-eggs"},
}
local CAPTURE_BUREAU_LURE_RADIUS = C.CAPTURE_BUREAU_LURE_RADIUS or 48
local CAPTURE_BUREAU_SPORE_UPKEEP_TICKS = C.CAPTURE_BUREAU_SPORE_UPKEEP_TICKS or 60
local CAPTURE_BUREAU_SPORE_UPKEEP_AMOUNT = C.CAPTURE_BUREAU_SPORE_UPKEEP_AMOUNT or 1
local CAPTURE_BUREAU_SPORE_VISUAL_TICKS = C.CAPTURE_BUREAU_SPORE_VISUAL_TICKS or 60
local CAPTURE_BUREAU_SMOKE_NAME = "capture-bureau-spore-cloud"
local LEGACY_CAPTURE_BUREAU_SPORE_PORT_NAME = "capture-bureau-spore-port"

local function get_entity_name(entity_or_name)
  if type(entity_or_name) == "string" then
    return entity_or_name
  end
  if entity_or_name and entity_or_name.valid then
    return entity_or_name.name
  end
  return nil
end

local function is_capture_bureau(entity_or_name)
  return get_entity_name(entity_or_name) == "capture-bureau"
end

local function entity_prototype_exists(name)
  if prototypes and prototypes.entity then
    return prototypes.entity[name] ~= nil
  end
  return true
end

local function existing_entity_names(names)
  local filtered = {}
  for _, name in ipairs(names) do
    if entity_prototype_exists(name) then
      filtered[#filtered + 1] = name
    end
  end
  return filtered
end

function M.delete_capture_bureau_ports(desk)
  storage.capture_bureau_ports = storage.capture_bureau_ports or {}
  storage.capture_bureau_ports[desk and desk.unit_number or 0] = nil
end

function M.ensure_capture_bureau_ports(desk)
  return {}
end

function M.rebuild_capture_bureau_ports()
  storage.capture_bureau_ports = {}
  if prototypes and prototypes.entity and not prototypes.entity[LEGACY_CAPTURE_BUREAU_SPORE_PORT_NAME] then
    return
  end
  for _, surface in pairs(game.surfaces or {}) do
    local ok, ports = pcall(surface.find_entities_filtered, {name = LEGACY_CAPTURE_BUREAU_SPORE_PORT_NAME})
    if ok then
      for _, port in ipairs(ports) do
        port.destroy()
      end
    end
  end
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
  if state == "waiting" or state == "pathfinding" then return true end
  return state == "protesting" and C.hard_mode_enabled and C.hard_mode_enabled()
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
  if info.home_spawner and info.home_spawner.valid then
    spawner_population.restore_detached(unit_number, info.entity, info.home_spawner)
  end
  if info.entity and info.entity.valid and info.state ~= "returning_home" then
    info.entity.force = get_biter_force()
    unit_ai_settings.apply_managed_unit_settings(info.entity)
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
  spawner_population.untrack_unit(unit_number)
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
  spawner_population.rekey_detached(
    old_unit_number,
    new_unit_number,
    info.entity,
    info.home_spawner
  )
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
    local desk_names = existing_entity_names({"admin-station", "capture-bureau"})
    if #desk_names == 0 then return desks end
    for _, surface in pairs(game.surfaces) do
      for _, desk in ipairs(surface.find_entities_filtered{
        name = desk_names,
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

local function get_entity_output_inventory(entity)
  if not entity or not entity.valid or not entity.get_inventory then return nil end
  local inventory_defs = defines and defines.inventory or {}
  for _, inventory_id in ipairs({
    inventory_defs.assembling_machine_output,
    inventory_defs.furnace_result,
    inventory_defs.chest,
  }) do
    if inventory_id ~= nil then
      local inventory = entity.get_inventory(inventory_id)
      if inventory then
        return inventory
      end
    end
  end
  return nil
end

local function get_fluid_amount(entity, fluid_name)
  if not entity or not fluid_name then return 0 end

  local function amount_in_fluidbox(fluidbox)
    local amount = 0
    if not fluidbox then return amount end
    for i = 1, #fluidbox do
      local fluid = fluidbox[i]
      if fluid and fluid.name == fluid_name then
        amount = amount + (fluid.amount or 0)
      end
    end
    return amount
  end

  local amount = amount_in_fluidbox(entity.fluidbox)
  return amount
end

local function remove_fluid_amount(entity, fluid_name, amount)
  if not entity or not fluid_name or amount <= 0 then return 0 end

  local function remove_from(target, remaining)
    if remaining <= 0 or not target then return 0 end
    if target.remove_fluid then
      local ok, removed = pcall(target.remove_fluid, {name = fluid_name, amount = remaining})
      if ok and removed then return removed end
    end

    local fluidbox = target.fluidbox
    if not fluidbox then return 0 end
    local removed = 0
    for i = 1, #fluidbox do
      local fluid = fluidbox[i]
      if fluid and fluid.name == fluid_name and removed < remaining then
        local take = math.min(fluid.amount or 0, remaining - removed)
        removed = removed + take
        local left = (fluid.amount or 0) - take
        if left > 0 then
          fluidbox[i] = {name = fluid.name, amount = left, temperature = fluid.temperature}
        else
          fluidbox[i] = nil
        end
      end
    end
    return removed
  end

  local removed_total = remove_from(entity, amount)
  return removed_total
end

local function get_capture_bureau_lure(desk)
  if not desk or not desk.valid or not is_capture_bureau(desk) then return nil end
  for _, lure in ipairs(CAPTURE_BUREAU_LURE_FLUIDS) do
    local amount = get_fluid_amount(desk, lure.name)
    if amount > 0 then
      return lure.mode, lure.name, amount
    end
  end
  return nil
end

local function get_capture_bureau_mode(desk)
  if not desk or not desk.valid or not is_capture_bureau(desk) then return nil end
  return get_capture_bureau_lure(desk)
end

local function emit_capture_bureau_spore_cloud(desk)
  if not desk or not desk.valid or not desk.surface or not desk.surface.create_entity then return end
  for _ = 1, 20 do
    local angle = math.random() * math.pi * 2
    local radius = math.sqrt(math.random()) * CAPTURE_BUREAU_LURE_RADIUS
    local position = {
      x = desk.position.x + math.cos(angle) * radius,
      y = desk.position.y + math.sin(angle) * radius,
    }
    pcall(desk.surface.create_entity, {
      name = CAPTURE_BUREAU_SMOKE_NAME,
      position = position,
      force = desk.force,
    })
  end
end

local function update_capture_bureau_lure_upkeep(desk)
  if not desk or not desk.valid or not is_capture_bureau(desk) then return nil end
  local mode, fluid_name = get_capture_bureau_lure(desk)
  if not mode then return nil end

  storage.capture_bureau_lure_upkeep = storage.capture_bureau_lure_upkeep or {}
  storage.capture_bureau_lure_visuals = storage.capture_bureau_lure_visuals or {}
  local tick = game and game.tick or 0
  local next_visual_tick = storage.capture_bureau_lure_visuals[desk.unit_number] or 0
  if tick >= next_visual_tick then
    emit_capture_bureau_spore_cloud(desk)
    storage.capture_bureau_lure_visuals[desk.unit_number] = tick + CAPTURE_BUREAU_SPORE_VISUAL_TICKS
  end

  local next_tick = storage.capture_bureau_lure_upkeep[desk.unit_number] or 0
  if tick >= next_tick then
    remove_fluid_amount(desk, fluid_name, CAPTURE_BUREAU_SPORE_UPKEEP_AMOUNT)
    storage.capture_bureau_lure_upkeep[desk.unit_number] = tick + CAPTURE_BUREAU_SPORE_UPKEEP_TICKS
  end

  return get_capture_bureau_lure(desk)
end

local function get_capture_bureau_products(desk, entity_name)
  local mode = get_capture_bureau_mode(desk)
  if mode == "workforce" then
    if entity_name and C.BITER_MAX_TIER[entity_name] ~= nil and not C.IS_SPITTER[entity_name] then
      return {{name = "worker-biter", count = 1}}
    end
    return nil
  end

  if mode == "tourism" then
    local package_item = entity_name and SPITTER_TOURISM_PACKAGE_ITEMS[entity_name] or nil
    if package_item then
      return {{name = package_item, count = 1}}
    end
    return nil
  end

  if mode == "pentapod-eggs" then
    local egg_count = entity_name and pentapods.PENTAPOD_EGG_YIELDS[entity_name] or nil
    if egg_count then
      return {{name = "pentapod-egg", count = egg_count}}
    end
  end

  return nil
end

local function can_insert_all_products(inventory, products)
  if not inventory or not products or #products == 0 then return false end
  if not inventory.can_insert then return true end
  for _, product in ipairs(products) do
    if not inventory.can_insert({name = product.name, count = product.count}) then
      return false
    end
  end
  return true
end

local function capture_bureau_can_accept_entity(desk, entity_name)
  if not desk or not desk.valid or not is_capture_bureau(desk) then return false end
  local products = get_capture_bureau_products(desk, entity_name)
  if not products then return false end
  local output = get_entity_output_inventory(desk)
  return can_insert_all_products(output, products)
end

local function get_preferred_desks_for_entity(entity_name, desks)
  if not entity_name then return desks end

  local capture_desks = {}
  local fallback_desks = {}
  for _, desk in ipairs(desks or {}) do
    if desk and desk.valid and zones.get_available_slots(desk.unit_number) > 0 then
      if is_capture_bureau(desk) then
        if capture_bureau_can_accept_entity(desk, entity_name) then
          capture_desks[#capture_desks + 1] = desk
        end
      elseif not pentapods.is_pentapod(entity_name) then
        fallback_desks[#fallback_desks + 1] = desk
      end
    end
  end

  if #capture_desks > 0 then
    return capture_desks
  end

  if pentapods.is_pentapod(entity_name) then
    return {}
  end

  return fallback_desks
end

local function surface_has_available_capture_bureau(surface, desks, entity_name)
  if not surface then return false end
  for _, desk in ipairs(desks or {}) do
    if desk and desk.valid and desk.surface == surface and zones.get_available_slots(desk.unit_number) > 0
       and is_capture_bureau(desk) and capture_bureau_can_accept_entity(desk, entity_name) then
      return true
    end
  end
  return false
end

local function find_nearest_available_desk(position, entity_name)
  local best = nil
  local best_dist = math.huge
  for _, desk in ipairs(get_preferred_desks_for_entity(entity_name, get_cached_desks())) do
    if zones.get_available_slots(desk.unit_number) > 0 then
      local dx = desk.position.x - position.x
      local dy = desk.position.y - position.y
      local dist = dx * dx + dy * dy
      if dist < best_dist then
        best_dist = dist
        best = desk
      end
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

local function is_offer_recruitable_entity(entity_name)
  return entity_name ~= nil and C.BITER_MAX_TIER[entity_name] ~= nil
end

local function get_nauvis_enrollment_offer_chance(info)
  local frustration = (info and info.frustration) or 0
  if frustration < C.PROTEST_THRESHOLD * (C.ENROLLMENT_OFFER_LOW_FRUSTRATION_RATIO or 0.25) then
    return C.ENROLLMENT_OFFER_LOW_CHANCE or 0.05
  end
  if frustration < C.PROTEST_THRESHOLD * (C.ENROLLMENT_OFFER_MEDIUM_FRUSTRATION_RATIO or 0.50) then
    return C.ENROLLMENT_OFFER_MEDIUM_CHANCE or 0.01
  end
  return 0
end

-- Slot release, desk unindex, and cases_resolved are owned by process_resolutions.
local function finalize_hired_biter_conversion(desk_id, info, inv, item_name, count)
  if not desk_id or not info or not inv then return false end
  local entity = info.entity
  if not entity or not entity.valid then return false end
  if inv.insert({name = item_name, count = count}) < count then return false end

  untrack_waiting_biter(entity.unit_number, info)
  entity.destroy()
  mark_desk_circuit_dirty(desk_id)

  return true
end

local function deliver_capture_bureau_products(desk, entity_name)
  local output = get_entity_output_inventory(desk)
  local products = get_capture_bureau_products(desk, entity_name)
  if not output or not products or not can_insert_all_products(output, products) then return false end

  for _, product in ipairs(products) do
    if output.insert({name = product.name, count = product.count}) <= 0 then
      return false
    end
  end

  return true
end

local function finalize_capture_bureau_conversion(desk, desk_id, info)
  if not desk or not desk_id or not info then return false end
  local entity = info.entity
  if not entity or not entity.valid then return false end
  if not deliver_capture_bureau_products(desk, entity.name) then return false end

  local biter_unit = entity.unit_number
  zones.release_slot(desk_id, biter_unit)
  unindex_biter_from_desk(desk_id, biter_unit)
  untrack_waiting_biter(biter_unit, info)
  entity.destroy()
  mark_desk_circuit_dirty(desk_id)

  if storage.stats then
    storage.stats.cases_resolved = (storage.stats.cases_resolved or 0) + 1
  end

  return true
end

local function maybe_attempt_nauvis_enrollment_offer(desk_id, info, inv)
  if not desk_id or not info or not inv then return false end
  local entity = info.entity
  if not entity or not entity.valid then return false end
  if not is_offer_recruitable_entity(entity.name) then return false end

  -- Base-only Administratorio hires every resolved biter or spitter directly
  -- into the legacy reusable worker pool. Space Age instead enrolls only
  -- biters, then routes them through the explicit workforce-formation chain.
  if not SPACE_AGE_ENABLED then
    local worker_count = (C.BITER_WORKER_YIELD and C.BITER_WORKER_YIELD[entity.name]) or 1
    if not inv.can_insert or not inv.can_insert({name = "biter-worker", count = worker_count}) then
      return false
    end
    if inv.remove({name = "job-offer", count = 1}) <= 0 then return false end
    return finalize_hired_biter_conversion(desk_id, info, inv, "biter-worker", worker_count)
  end

  if C.IS_SPITTER[entity.name] then return false end
  if not inv.can_insert or not inv.can_insert({name = "enrolled-biter", count = 1}) then
    return false
  end
  if inv.remove({name = "job-offer", count = 1}) <= 0 then return false end

  local chance = get_nauvis_enrollment_offer_chance(info)
  if chance > 0 and math.random() < chance then
    return finalize_hired_biter_conversion(desk_id, info, inv, "enrolled-biter", 1)
  end

  mark_desk_circuit_dirty(desk_id)
  return false
end

local function capture_home_spawner(info, entity, should_release)
  if not info or not entity or not entity.valid then return end
  local commandable = entity.commandable
  if not commandable then return end

  local spawner = commandable.spawner or spawner_population.get_home_spawner(entity.unit_number)
  if not spawner or not spawner.valid or spawner.type ~= "unit-spawner" then return nil end

  remember_home_spawner(info, spawner)
  spawner_population.detach_unit(entity, spawner)
  if should_release then
    commandable.release_from_spawner()
  end
  return spawner
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
  unit_ai_settings.apply_managed_unit_settings(replacement)

  local home_spawner = capture_home_spawner(info, entity, false)
  if entity.health and replacement.health then
    replacement.health = entity.health
  end
  remember_entity_tracking(info, replacement)
  spawner_population.rekey_detached(
    entity.unit_number,
    replacement.unit_number,
    replacement,
    home_spawner
  )
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
  unit_ai_settings.apply_managed_unit_settings(entity)
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
  info.desk_route_started_tick = nil
  info.desk_route_last_progress_tick = nil
  info.desk_route_best_distance_sq = nil
  entity.force = get_biter_force()
  unit_ai_settings.apply_managed_unit_settings(entity)
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
  if is_capture_bureau(desk) then
    if finalize_capture_bureau_conversion(desk, desk.unit_number, info) then
      return true
    end
    zones.release_slot(desk.unit_number, b_id)
    unindex_biter_from_desk(desk.unit_number, b_id)
    untrack_waiting_biter(b_id, info)
    M.trigger_immediate_protest(entity, entity.surface, info)
    return true
  end
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
  unit_ai_settings.apply_managed_unit_settings(entity)
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
  info.desk_route_started_tick = game.tick
  info.desk_route_last_progress_tick = game.tick
  info.desk_route_best_distance_sq = (entity.position.x - dest.x)^2
    + (entity.position.y - dest.y)^2
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
  get_hard_mode_attack_force = get_hard_mode_attack_force,
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
  protest_obstacle_building_types = PROTEST_OBSTACLE_BUILDING_TYPES,
  protest_protected_names = PROTEST_PROTECTED_NAMES,
  protest_target_names = PROTEST_TARGET_NAMES,
  protest_target_types = PROTEST_TARGET_TYPES,
  remember_entity_tracking = remember_entity_tracking,
  remember_home_spawner = remember_home_spawner,
  reserve_home_spawner_unit = function(info, entity, spawner)
    if not info or not entity or not entity.valid or not spawner or not spawner.valid then return false end
    remember_home_spawner(info, spawner)
    return spawner_population.detach_unit(entity, spawner)
  end,
  render = protest_rendering,
  apply_managed_unit_settings = unit_ai_settings.apply_managed_unit_settings,
  release_as_regular_enemy = unit_ai_settings.release_as_regular_enemy,
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

function M.trigger_immediate_protest(entity, surface, previous_info, opts)
  storage.waiting_biters = storage.waiting_biters or {}
  storage.waiting_biter_state_index = storage.waiting_biter_state_index or {}
  storage.path_requests = storage.path_requests or {}
  return protest_system.trigger_immediate_protest(entity, surface, previous_info, opts)
end

function M.is_hard_mode_attacker(unit_number)
  local info = storage.waiting_biters and storage.waiting_biters[unit_number]
  return info and (info.hard_mode_attacking == true or info.state == "attacking") or false
end

-- Once Commander has finished assembling a native pollution group, detach its
-- members from enemy autonomy immediately. The heavier adoption/desk lookup is
-- still budgeted by control.lua, but parked members can no longer form another
-- attack group while they wait their turn in that queue.
function M.prepare_group_redirect(entity)
  if not entity or not entity.valid or entity.type ~= "unit" then return false end
  entity.force = get_biter_force()
  unit_ai_settings.apply_managed_unit_settings(entity)
  entity.destructible = false
  entity.active = false
  if entity.commandable and entity.commandable.set_command then
    entity.commandable.set_command({
      type = defines.command.stop,
      distraction = defines.distraction.none,
    })
  end
  return true
end

function M.send_biter_to_station_with_targets(entity, targets, opts)
  opts = opts or {}
  if not entity or not entity.valid or entity.type ~= "unit" then return end
  local prepared_redirect = opts.prepared_redirect == true
    and entity.force == get_biter_force()
  if entity.force.name ~= "enemy" and not prepared_redirect then return end
  if #targets == 0 then
    return
  end
  local initial_frustration = opts.initial_frustration or 0

  local min_dist = math.huge
  local best = nil
  local preferred_targets = get_preferred_desks_for_entity(entity.name, targets)
  if #preferred_targets == 0 then
    if pentapods.is_pentapod(entity.name) then
      return
    end
    M.trigger_immediate_protest(entity, entity.surface)
    return
  end
  for _, desk in ipairs(preferred_targets) do
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
    local lure_mode = update_capture_bureau_lure_upkeep(desk)
    local should_scan_walkins = walkin_scan_ticks <= 1 or (desk.unit_number % walkin_scan_ticks) == walkin_shard
    if should_scan_walkins then
      local remaining_slots = zones.get_available_slots(desk.unit_number)
      local search_pos = desk.position
      local search_radius = lure_mode and CAPTURE_BUREAU_LURE_RADIUS or 10

      for _, biter in ipairs(surface.find_entities_filtered{force = "enemy", type = "unit", position = search_pos, radius = search_radius}) do
        if biter.valid and biter.force.name == "enemy" and not storage.waiting_biters[biter.unit_number] then
          if pentapods.is_pentapod(biter.name) and not is_capture_bureau(desk) then
            goto skip_walkin_biter
          end
          if not is_capture_bureau(desk) and surface_has_available_capture_bureau(surface, desks, biter.name) then
            goto skip_walkin_biter
          end
          if is_capture_bureau(desk) then
            if not capture_bureau_can_accept_entity(desk, biter.name) then
              goto skip_walkin_biter
            end
            local slot = zones.reserve_slot(desk.unit_number)
            if not slot then break end
            local reserved = zones.get_slot_position and zones.get_slot_position(desk.unit_number, slot)
            local pos = reserved and (surface.find_non_colliding_position(biter.name, reserved, 1, 0.25) or reserved)
              or zones.get_biter_placement_pos and zones.get_biter_placement_pos(surface, desk, biter.name)
              or desk.position
            if pos then
              local info = {
                entity = biter,
                desk_id = nil,
                complaints = {},
                complaints_total = 0,
                complaints_filed = true,
                frustration = 0,
                state = "pathfinding",
              }
              info.entity_name = biter.name
              capture_home_spawner(info, biter, true)
              track_waiting_biter(biter.unit_number, info)
              if route_biter_to_desk(info, biter, desk) then
                remaining_slots = remaining_slots - 1
              else
                zones.release_slot_by_index(desk.unit_number, slot)
                untrack_waiting_biter(biter.unit_number, info)
              end
            else
              zones.release_slot_by_index(desk.unit_number, slot)
            end
            goto skip_walkin_biter
          end
          if zones.get_available_slots(desk.unit_number) <= 0 then break end
          local slot = zones.reserve_slot(desk.unit_number)
          if not slot then break end
          local reserved = zones.get_slot_position(desk.unit_number, slot)
          local pos = reserved and (surface.find_non_colliding_position(biter.name, reserved, 1, 0.25) or reserved)
            or zones.get_biter_placement_pos(surface, desk, biter.name)
          if pos then
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
        ::skip_walkin_biter::
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

                      local hired = maybe_attempt_nauvis_enrollment_offer(desk_id, info, inv)
                      if hired then
                        if storage.stats then storage.stats.biters_hired = (storage.stats.biters_hired or 0) + 1 end
                      else
                        start_return_home(info, info.entity)
                        local amount = C.BITER_PAYOUT[biter_name]
                        local payout_surface = info.entity and info.entity.surface
                        local taxpayer_payout_allowed = not SPACE_AGE_ENABLED
                          or (payout_surface and payout_surface.name == "nauvis")
                        if taxpayer_payout_allowed and amount and inv.can_insert({name = "taxpayer-money", count = amount}) then
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

local function release_space_tourist(desk, inv, tourist_item, entity_name)
  if not desk or not desk.valid or not inv or not tourist_item or not entity_name then return false end
  if not desk.surface or desk.surface.name ~= "nauvis" then return false end

  local surface = desk.surface
  local release_anchor = {
    x = desk.position.x,
    y = desk.position.y + 3,
  }
  local position = surface.find_non_colliding_position(entity_name, release_anchor, 8, 0.5) or release_anchor

  if inv.remove({name = tourist_item, count = 1}) <= 0 then return false end

  local entity = surface.create_entity{
    name = entity_name,
    position = position,
    force = "neutral",
  }
  if not entity or not entity.valid then
    inv.insert({name = tourist_item, count = 1})
    return false
  end

  local info = {
    entity = entity,
    complaints = {},
    complaints_total = 0,
    complaints_filed = true,
    frustration = 0,
    state = "waiting",
  }
  info.entity_name = entity.name
  track_waiting_biter(entity.unit_number, info)
  start_return_home(info, entity)
  return true
end

function M.process_space_tourist_returns(desks)
  for _, desk in ipairs(desks or {}) do
    if desk.valid and desk.surface and desk.surface.name == "nauvis" then
      local inv = desk.get_inventory(defines.inventory.chest)
      if inv and not inv.is_empty() then
        for slot = 1, #inv do
          local stack = inv[slot]
          if stack and stack.valid_for_read then
            local entity_name = SPACE_TOURIST_RELEASE_ITEMS[stack.name]
            if entity_name and release_space_tourist(desk, inv, stack.name, entity_name) then
              mark_desk_circuit_dirty(desk.unit_number)
              break
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

local function hatch_spoiled_tourism_package(event)
  local entity_name = event and SPOILED_SPITTER_HATCH_EFFECTS[event.effect_id] or nil
  if not entity_name then return false end

  local source_entity = event.source_entity
  local surface = (source_entity and source_entity.valid and source_entity.surface)
    or (event.surface_index and game.get_surface(event.surface_index))
    or game.surfaces[1]
  if not surface then return true end

  local anchor = (source_entity and source_entity.valid and source_entity.position)
    or event.source_position
    or event.target_position
    or {x = 0, y = 0}
  local spawn_position = surface.find_non_colliding_position(entity_name, anchor, 8, 0.5) or anchor
  local hatched = surface.create_entity{
    name = entity_name,
    position = spawn_position,
    force = "enemy",
  }
  if hatched and hatched.valid then
    local desks = get_preferred_desks_for_entity(entity_name, get_cached_desks())
    if #desks > 0 then
      M.send_biter_to_station_with_targets(hatched, desks, {initial_frustration = C.PROTEST_THRESHOLD})
    end
  end
  return true
end

function M.on_script_trigger_effect(event)
  if pentapods.on_script_trigger_effect(event) then
    return
  end
  if hatch_spoiled_tourism_package(event) then
    return
  end
  protest_system.on_script_trigger_effect(event)
end

function M.on_biter_died(entity, event)
  protest_system.on_biter_died(entity, event)
end

function M.on_biter_removed(entity, event)
  return protest_system.on_biter_removed(entity, event)
end

function M.update_circuit_signals(desks)
  ensure_desk_biters()
  ensure_desk_circuit_dirty()
  for _, desk in ipairs(desks) do
    local desk_id = desk.unit_number
    local reconcile = game and game.tick
      and game.tick % DESK_CIRCUIT_RECONCILE_TICKS == desk_id % DESK_CIRCUIT_RECONCILE_TICKS
    if reconcile then
      storage.desk_circuit_dirty[desk_id] = true
    end
    if storage.desk_circuit_dirty[desk_id] then
      local combinator = storage.desk_combinators[desk_id]
      if combinator and combinator.valid then
        local complaint_counts = {l = 0, s = 0, n = 0, u = 0, lt = 0, h = 0, lo = 0, v = 0}
        local total_waiting = 0
        local function count_waiting_info(info)
          if info and info.desk_id == desk_id and info.state == "waiting"
             and info.entity and info.entity.valid then
            total_waiting = total_waiting + 1
            for _, ticket in ipairs(info.complaints or {}) do
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

        if reconcile then
          for _, info in pairs(storage.waiting_biters or {}) do
            count_waiting_info(info)
          end
        else
          local desk_set = storage.desk_biters[desk_id]
          if desk_set then
            for b_id in pairs(desk_set) do
              count_waiting_info(storage.waiting_biters[b_id])
            end
          end
        end

        local available = zones.get_available_slots(desk_id)
        local behavior = combinator.get_or_create_control_behavior()
        if behavior then
          local section = behavior.get_section(1)
          if not section then section = behavior.add_section() end
          if section then
            local function set_signal(slot, signal, count)
              if count == 0 then
                section.clear_slot(slot)
              else
                section.set_slot(slot, {value = signal, min = count})
              end
            end
            set_signal(1, "signal-complaint-l", complaint_counts.l)
            set_signal(2, "signal-complaint-s", complaint_counts.s)
            set_signal(3, "signal-complaint-n", complaint_counts.n)
            set_signal(4, "signal-complaint-u", complaint_counts.u)
            set_signal(5, "signal-complaint-lt", complaint_counts.lt)
            set_signal(6, "signal-complaint-h", complaint_counts.h)
            set_signal(7, "signal-complaint-lo", complaint_counts.lo)
            set_signal(8, "signal-complaint-v", complaint_counts.v)
            set_signal(9, "signal-available-slots", available)
            set_signal(10, "signal-total-waiting", total_waiting)
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
