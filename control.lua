-- ADMINISTRATORIO: RUNTIME ORCHESTRATOR
-- Requires script modules and registers all event handlers.

local C = require("scripts.constants")
local pneumatic = require("scripts.pneumatic")
local frustration = require("scripts.frustration")
local zones = require("scripts.zones")
local biters = require("scripts.biters")
local trains = require("scripts.trains")
local fax = require("scripts.fax")
local working_hours = require("scripts.working_hours")
local field_office = require("scripts.field_office")
local biter_station = require("scripts.biter_station")
local biter_station_hover = require("scripts.biter_station_hover")
local biterport = require("scripts.biterport")
local biterport_hover = require("scripts.biterport_hover")
local trajectory_compliance = require("scripts.trajectory_compliance")
local territorial_arbitration = require("scripts.territorial_arbitration")
local runtime_debug = require("scripts.control_runtime_debug")
local control_event_router = require("scripts.control_event_router")
local control_resolution_processing_factory = require("scripts.control_resolution_processing")
local regulated_unlocks = require("scripts.regulated_unlocks")
local feature_flags = require("feature_flags")
local protest_targets = require("scripts.protest_targets")
local hired_biter = require("scripts.hired_biter")
local rideable_biter = require("scripts.rideable_biter")
local spawner_population = require("scripts.spawner_population")

biter_station.set_biters_module(biters)
biterport.set_biters_module(biters)

local ADMIN_STATION_NAMES = {
  "admin-station",
  "admin-station-north",
  "admin-station-east",
  "admin-station-west",
}
local ADMIN_DESK_NAMES = {
  "admin-station",
  "admin-station-north",
  "admin-station-east",
  "admin-station-west",
  "capture-bureau",
}
local LEGACY_ADMIN_STATION_ITEM_NAMES = {
  "admin-station-north",
  "admin-station-east",
  "admin-station-west",
}

local ADMIN_DESK_NAME_SET = {}
for _, name in ipairs(ADMIN_DESK_NAMES) do
  ADMIN_DESK_NAME_SET[name] = true
end

local LEGACY_ADMIN_STATION_ITEM_SET = {}
for _, name in ipairs(LEGACY_ADMIN_STATION_ITEM_NAMES) do
  LEGACY_ADMIN_STATION_ITEM_SET[name] = true
end

local UNIT_GROUP_DEBUG_SCAN_INTERVAL = 180
local UNIT_GROUP_GATHER_REDIRECT_TICKS = 300
local WORKING_HOURS_ENABLED = feature_flags.working_hours_enabled()
local needs_unit_group_scan = false
local needs_load_bugged_biter_cleanup = false
local resolution_processing
local enable_regulated_variants_for_technology = regulated_unlocks.enable_regulated_variants_for_technology
local FIELD_OFFICE_DEPLOYMENT_TECH = "field-office-deployment"

local function get_entity_name(entity_or_name)
  if type(entity_or_name) == "string" then return entity_or_name end
  if entity_or_name then return entity_or_name.name end
  return nil
end

local function is_admin_desk(entity_or_name)
  local name = get_entity_name(entity_or_name)
  return name and ADMIN_DESK_NAME_SET[name] == true
end

local function is_admin_station(entity_or_name)
  return is_admin_desk(entity_or_name)
end

local function normalize_admin_station_inventory(inventory)
  if not inventory then return end
  for i = 1, #inventory do
    local stack = inventory[i]
    if stack and stack.valid_for_read and LEGACY_ADMIN_STATION_ITEM_SET[stack.name] == true then
      local count = stack.count
      local quality = stack.quality
      stack.set_stack{name = "admin-station", count = count, quality = quality and quality.name or nil}
    end
  end
end

local function normalize_player_admin_station_items(player)
  if not player or not player.valid then return end
  normalize_admin_station_inventory(player.get_main_inventory())
  normalize_admin_station_inventory(player.get_inventory(defines.inventory.character_trash))
  normalize_admin_station_inventory(player.get_inventory(defines.inventory.god_main))
end

local function normalize_player_admin_station_quickbar(player)
  if not player or not player.valid then return end
  for slot = 1, 100 do
    local filter = player.get_quick_bar_slot(slot)
    if filter and filter.name and LEGACY_ADMIN_STATION_ITEM_SET[filter.name] == true then
      player.set_quick_bar_slot(slot, {name = "admin-station", quality = filter.quality})
    end
  end
end

local function freeze_admin_station_rotation(desk)
  if not desk or not desk.valid then return end
  desk.rotatable = false
end

local function find_nearby_enemy_spawner(surface, position)
  if not surface or not position then return nil end
  return surface.find_entities_filtered{
    position = position,
    radius = 32,
    type = "unit-spawner",
    limit = 1
  }[1]
end

local function notify_player_build_denied(player, position)
  if not player then return end
  player.create_local_flying_text{
    text = {"message.build-too-close-nest"},
    position = position,
    color = {r = 1, g = 0, b = 0}
  }
  player.play_sound{path = "utility/cannot_build"}
end

local function remember_recent_prebuild_denial(player_index, position, tick)
  if not player_index or not position then return end
  storage.recent_prebuild_denials = storage.recent_prebuild_denials or {}
  storage.recent_prebuild_denials[player_index] = {
    tick = tick,
    position = {x = position.x, y = position.y}
  }
end

local function was_recent_prebuild_denial(player_index, position, tick)
  if not player_index or not position or not tick then return false end
  local recent_denials = storage.recent_prebuild_denials
  local denial = recent_denials and recent_denials[player_index]
  if not denial then return false end
  if denial.tick ~= tick then return false end
  return denial.position
    and denial.position.x == position.x
    and denial.position.y == position.y
end

local function connect_desk_combinator(desk, combinator)
  if not desk or not desk.valid or not combinator or not combinator.valid then return end
  local desk_red = desk.get_wire_connector(defines.wire_connector_id.circuit_red, true)
  local desk_green = desk.get_wire_connector(defines.wire_connector_id.circuit_green, true)
  local comb_red = combinator.get_wire_connector(defines.wire_connector_id.circuit_red, true)
  local comb_green = combinator.get_wire_connector(defines.wire_connector_id.circuit_green, true)
  if desk_red and comb_red then desk_red.connect_to(comb_red) end
  if desk_green and comb_green then desk_green.connect_to(comb_green) end
end

local function ensure_desk_combinator(desk)
  if not desk or not desk.valid then return nil end
  local desk_id = desk.unit_number
  local combinator = storage.desk_combinators[desk_id]
  local created = false
  if not combinator or not combinator.valid then
    combinator = desk.surface.create_entity{
      name = "admin-station-combinator",
      position = desk.position,
      force = desk.force
    }
    if combinator then
      combinator.destructible = false
      storage.desk_combinators[desk_id] = combinator
      created = true
    end
  end
  connect_desk_combinator(desk, combinator)
  if created then
    biters.mark_desk_circuit_dirty(desk_id)
  end
  return combinator
end

local function migrate_desk_storage(old_desk_id, new_desk)
  if not new_desk or not new_desk.valid then return end
  local new_desk_id = new_desk.unit_number
  if old_desk_id == new_desk_id then
    storage.admin_desks[new_desk_id] = new_desk
    return
  end

  storage.admin_desks[old_desk_id] = nil
  storage.admin_desks[new_desk_id] = new_desk

  if storage.desk_zones[old_desk_id] then
    storage.desk_zones[new_desk_id] = storage.desk_zones[old_desk_id]
    storage.desk_zones[old_desk_id] = nil
  end
  if storage.desk_combinators[old_desk_id] then
    storage.desk_combinators[new_desk_id] = storage.desk_combinators[old_desk_id]
    storage.desk_combinators[old_desk_id] = nil
  end
  if storage.desk_reserved_slots[old_desk_id] then
    storage.desk_reserved_slots[new_desk_id] = storage.desk_reserved_slots[old_desk_id]
    storage.desk_reserved_slots[old_desk_id] = nil
  end
  if storage.desk_circuit_dirty and storage.desk_circuit_dirty[old_desk_id] then
    storage.desk_circuit_dirty[new_desk_id] = true
    storage.desk_circuit_dirty[old_desk_id] = nil
  end
  if storage.desk_grid_slots and storage.desk_grid_slots[old_desk_id] then
    storage.desk_grid_slots[new_desk_id] = storage.desk_grid_slots[old_desk_id]
    storage.desk_grid_slots[old_desk_id] = nil
  end
  if storage.desk_biters and storage.desk_biters[old_desk_id] then
    storage.desk_biters[new_desk_id] = storage.desk_biters[old_desk_id]
    storage.desk_biters[old_desk_id] = nil
  end
  if storage.desk_return_positions and storage.desk_return_positions[old_desk_id] then
    storage.desk_return_positions[new_desk_id] = storage.desk_return_positions[old_desk_id]
    storage.desk_return_positions[old_desk_id] = nil
  end

  for _, info in pairs(storage.waiting_biters or {}) do
    if info.desk_id == old_desk_id then
      info.desk_id = new_desk_id
    end
  end
end

local function normalize_admin_station_entity(desk, player)
  if not desk or not desk.valid then return nil end
  if desk.name == "admin-station" or desk.name == "capture-bureau" then
    freeze_admin_station_rotation(desk)
    storage.admin_desks[desk.unit_number] = desk
    return desk
  end

  local surface = desk.surface
  if not surface.can_fast_replace{
    name = "admin-station",
    position = desk.position,
    direction = desk.direction,
    force = desk.force
  } then
    return desk
  end

  local params = {
    name = "admin-station",
    position = desk.position,
    direction = desk.direction,
    force = desk.force,
    quality = desk.quality and desk.quality.name or nil,
    fast_replace = true,
    spill = false,
    create_build_effect_smoke = false,
  }
  if player then
    params.player = player.index
    params.character = player.character
  end

  local old_desk_id = desk.unit_number
  local new_desk = surface.create_entity(params)
  if not new_desk or not new_desk.valid then return desk end

  freeze_admin_station_rotation(new_desk)
  migrate_desk_storage(old_desk_id, new_desk)
  storage.admin_desks[new_desk.unit_number] = new_desk
  ensure_desk_combinator(new_desk)
  return new_desk
end

-- ============================================================
-- CACHED DESK LIST
-- ============================================================
-- storage.admin_desks[unit_number] = entity reference
-- Updated on build/remove/death, rebuilt on init/config_changed.
-- This cache prevents expensive surface searches during the main loop.

local function refresh_cached_desk(desk)
  if not desk or not desk.valid then return nil end
  freeze_admin_station_rotation(desk)
  storage.admin_desks[desk.unit_number] = desk
  zones.ensure_desk_runtime_state(desk)
  ensure_desk_combinator(desk)
  return desk
end

local function rebuild_desk_cache()
  storage.admin_desks = {}
  for _, surface in pairs(game.surfaces) do
    for _, desk in ipairs(surface.find_entities_filtered{name = ADMIN_DESK_NAMES}) do
      if desk.valid then
        refresh_cached_desk(desk)
      end
    end
  end
end

local function sync_force_regulated_recipe_unlocks(force)
  if not force or not force.valid then return end
  for _, technology in pairs(force.technologies) do
    if technology.researched then
      enable_regulated_variants_for_technology(force, technology)
    end
  end
end

local function sync_all_regulated_recipe_unlocks()
  for _, force in pairs(game.forces) do
    sync_force_regulated_recipe_unlocks(force)
  end
end

local function get_cached_desks()
  local desks = {}
  for id, desk in pairs(storage.admin_desks or {}) do
    if desk.valid then
      desks[#desks + 1] = desk
    else
      storage.admin_desks[id] = nil
    end
  end
  return desks
end

local function collect_runtime_debug_counts(desks)
  local counts = {
    desks = #desks,
    working_hours_buildings = 0,
    stations = 0,
    field_offices = 0,
    field_office_idle = 0,
    field_office_calling = 0,
    field_office_working = 0,
    field_office_releasing = 0,
    biters = 0,
    waiting = 0,
    pathfinding = 0,
    protesting = 0,
    pacified = 0,
    returning_home = 0,
    attacking = 0,
    pending_group_redirects = 0,
    pending_path_requests = 0,
    calmed_spawners = 0,
  }

  for _, station_data in pairs(storage.stations or {}) do
    if station_data and station_data.station and station_data.station.valid then
      counts.stations = counts.stations + 1
    end
  end

  for office_id, office in pairs(storage.field_offices or {}) do
    if office and office.valid then
      counts.field_offices = counts.field_offices + 1
      local state = storage.field_office_state and storage.field_office_state[office_id]
      if state and state.phase == "calling" then
        counts.field_office_calling = counts.field_office_calling + 1
      elseif state and state.phase == "working" then
        counts.field_office_working = counts.field_office_working + 1
      else
        counts.field_office_idle = counts.field_office_idle + 1
      end
    end
  end

  for _, info in pairs(storage.field_office_releasing or {}) do
    if info and info.entity and info.entity.valid then
      counts.field_office_releasing = counts.field_office_releasing + 1
    end
  end

  if WORKING_HOURS_ENABLED then
    for unit_number, entity in pairs(storage.working_hours_entities or {}) do
      if entity and entity.valid then
        counts.working_hours_buildings = counts.working_hours_buildings + 1
      else
        storage.working_hours_entities[unit_number] = nil
      end
    end
  end

  for _, info in pairs(storage.waiting_biters or {}) do
    counts.biters = counts.biters + 1
    if info.state == "waiting" then
      counts.waiting = counts.waiting + 1
    elseif info.state == "pathfinding" then
      counts.pathfinding = counts.pathfinding + 1
    elseif info.state == "protesting" then
      counts.protesting = counts.protesting + 1
      if info.hard_mode_attacking then
        counts.attacking = counts.attacking + 1
      end
    elseif info.state == "pacified" then
      counts.pacified = counts.pacified + 1
    elseif info.state == "returning_home" then
      counts.returning_home = counts.returning_home + 1
    elseif info.state == "attacking" then
      counts.attacking = counts.attacking + 1
    end
  end

  local redirect_queue = storage.pending_group_redirects or {}
  local redirect_head = storage.pending_group_redirect_head or 1
  counts.pending_group_redirects = math.max(0, #redirect_queue - redirect_head + 1)

  for _, _ in pairs(storage.path_requests or {}) do
    counts.pending_path_requests = counts.pending_path_requests + 1
  end

  for _, spawner_data in pairs(storage.calmed_spawners or {}) do
    if spawner_data then
      counts.calmed_spawners = counts.calmed_spawners + 1
    end
  end

  return counts
end

-- ============================================================
-- PAPERWORK FILTERS
-- ============================================================

-- Automatically set filters on locomotives to help players automate transit paperwork.
local function initialize_bureaucratic_filters(entity)
  if not entity or not entity.valid then return end
  if entity.type == "locomotive" then
    for i = 1, 2 do
      local inv = entity.get_inventory(i)
      if inv and inv.supports_filters() then
        inv.set_filter(1, "transit-authorization")
      end
    end
  end
end

-- ============================================================
-- STORAGE INITIALIZATION
-- ============================================================

local function init_storage()
  storage.waiting_biters = storage.waiting_biters or {}
  storage.waiting_biter_state_index = storage.waiting_biter_state_index or {}
  if storage.waiting_biter_state_index_built == nil then
    storage.waiting_biter_state_index_built = false
  end
  storage.desk_zones = storage.desk_zones or {}
  storage.desk_combinators = storage.desk_combinators or {}
  storage.desk_reserved_slots = storage.desk_reserved_slots or {}
  storage.desk_grid_slots = storage.desk_grid_slots or {}
  storage.desk_occupant_counts = storage.desk_occupant_counts or {}
  storage.desk_return_positions = storage.desk_return_positions or {}
  storage.desk_circuit_dirty = storage.desk_circuit_dirty or {}
  storage.evolution_complaint_warnings = storage.evolution_complaint_warnings or {}
  storage.stations = storage.stations or {}
  storage.achievements = storage.achievements or {}
  storage.path_requests = storage.path_requests or {}
  storage.pending_group_redirects = storage.pending_group_redirects or {}
  storage.pending_group_redirect_head = storage.pending_group_redirect_head or 1
  storage.unit_group_redirect_watch = storage.unit_group_redirect_watch or {}
  storage.runtime_debug_players = storage.runtime_debug_players or {}
  storage.stats = storage.stats or {}
  storage.stats.cases_resolved = storage.stats.cases_resolved or 0
  storage.stats.money_earned = storage.stats.money_earned or 0
  storage.stats.protests_suppressed = storage.stats.protests_suppressed or 0
  storage.stats.nests_evicted = storage.stats.nests_evicted or 0
  storage.stats.nests_calmed = storage.stats.nests_calmed or 0
  storage.stats.biters_hired = storage.stats.biters_hired or 0
  storage.stats.rockets_launched = storage.stats.rockets_launched or 0
  storage.calmed_spawners = storage.calmed_spawners or {}
  trajectory_compliance.ensure_storage()
  territorial_arbitration.ensure_storage()
  fax.ensure_storage()
  if WORKING_HOURS_ENABLED then
    working_hours.ensure_storage()
  end
  field_office.ensure_storage()
  spawner_population.ensure_storage()
  biter_station.ensure_storage()
  biterport.ensure_storage()
  hired_biter.ensure_storage()
  hired_biter.cleanup_supply_chests()
  rideable_biter.ensure_storage()
  biter_station_hover.ensure_storage()
  biterport_hover.ensure_storage()

  -- Ensure all existing locomotives and pneumatic buildings are properly initialized.
  for _, surface in pairs(game.surfaces) do
    for _, loco in ipairs(surface.find_entities_filtered{type = "locomotive"}) do
      initialize_bureaucratic_filters(loco)
    end
  end
  pneumatic.ensure_storage()
  pneumatic.rebuild_all()
end

-- ============================================================
-- LIFECYCLE EVENTS
-- ============================================================

-- Managed biters normally remain on ceasefire. Hard-mode attackers and the small,
-- bounded set of blocked protesters use the hostile force temporarily.
local function set_biter_ceasefire()
  local enemy = game.forces["enemy"]
  local player = game.forces["player"]
  if enemy and player then
    enemy.set_cease_fire(player, true)
  end

  local biter_force = game.forces["administratorio-biters"]
  if not biter_force then
    biter_force = game.create_force("administratorio-biters")
  end
  biter_force.set_cease_fire(player, true)
  player.set_cease_fire(biter_force, true)
  biter_force.set_cease_fire(enemy, true)
  enemy.set_cease_fire(biter_force, true)
  local neutral = game.forces["neutral"]
  if neutral then
    biter_force.set_cease_fire(neutral, true)
    neutral.set_cease_fire(biter_force, true)
  end

  local hard_mode_force_name = C.HARD_MODE_ATTACK_FORCE_NAME or "administratorio-hard-mode-biters"
  local hard_mode_force = game.forces[hard_mode_force_name]
  if not hard_mode_force then
    hard_mode_force = game.create_force(hard_mode_force_name)
  end
  if hard_mode_force then
    hard_mode_force.set_cease_fire(player, false)
    player.set_cease_fire(hard_mode_force, false)
    if hard_mode_force.set_friend then hard_mode_force.set_friend(player, false) end
    if player.set_friend then player.set_friend(hard_mode_force, false) end

    hard_mode_force.set_cease_fire(enemy, true)
    enemy.set_cease_fire(hard_mode_force, true)
    hard_mode_force.set_cease_fire(biter_force, true)
    biter_force.set_cease_fire(hard_mode_force, true)
    if neutral then
      hard_mode_force.set_cease_fire(neutral, true)
      neutral.set_cease_fire(hard_mode_force, true)
    end
  end
end

local function format_percent_text(value)
  return string.format("%.1f", value * 100)
end

local function build_complaint_warning_caption(complaints)
  if not complaints or #complaints == 0 then
    return {"", "complaints"}
  end
  if #complaints == 1 then
    return {"item-name." .. complaints[1]}
  end
  return {
    "message.evolution-complaint-pair",
    {"item-name." .. complaints[1]},
    {"item-name." .. complaints[2]},
  }
end

local function parse_version(version)
  if type(version) ~= "string" then return nil end
  local major, minor, patch = version:match("^(%d+)%.(%d+)%.(%d+)")
  if not major then return nil end
  return tonumber(major), tonumber(minor), tonumber(patch)
end

local function version_less_than(version, target)
  local major, minor, patch = parse_version(version)
  local target_major, target_minor, target_patch = parse_version(target)
  if not major or not target_major then return false end
  if major ~= target_major then return major < target_major end
  if minor ~= target_minor then return minor < target_minor end
  return patch < target_patch
end

local function version_at_least(version, target)
  local major, minor, patch = parse_version(version)
  local target_major, target_minor, target_patch = parse_version(target)
  if not major or not target_major then return false end
  if major ~= target_major then return major > target_major end
  if minor ~= target_minor then return minor > target_minor end
  return patch >= target_patch
end

local function warn_about_pre_040_save(event)
  local mod_change = event and event.mod_changes and event.mod_changes["administratorio"]
  if not mod_change or not mod_change.old_version then return end
  local new_version = mod_change.new_version or (script.active_mods and script.active_mods["administratorio"])
  if version_less_than(mod_change.old_version, "0.4.0") and version_at_least(new_version, "0.4.0") then
    game.print({"message.pre-040-save-warning", mod_change.old_version})
  end
end

local function warn_force_about_evolution_complaints(force)
  if not force or not force.valid or #force.connected_players == 0 then return end
  local enemy = game.forces["enemy"]
  if not enemy or not enemy.valid then return end

  local evolution = enemy.get_evolution_factor(game.surfaces[1]) or 0
  local force_warnings = storage.evolution_complaint_warnings[force.index]
  if not force_warnings then
    force_warnings = {}
    storage.evolution_complaint_warnings[force.index] = force_warnings
  end

  for _, warning in ipairs(C.EVOLUTION_COMPLAINT_WARNINGS) do
    local warning_threshold = warning.threshold - C.EVOLUTION_COMPLAINT_WARNING_OFFSET
    if evolution >= warning_threshold and not force_warnings[warning.id] then
      local technology = force.technologies[warning.technology]
      if technology and not technology.researched then
        local message_key = evolution >= warning.threshold
          and "message.evolution-complaint-overdue"
          or "message.evolution-complaint-warning"
        force.print({
          message_key,
          format_percent_text(evolution),
          string.format("%.0f", warning.threshold * 100),
          build_complaint_warning_caption(warning.complaints),
          {"technology-name." .. warning.technology},
        })
        force_warnings[warning.id] = true
      end
    end
  end
end

local function on_init()
  init_storage()
  rebuild_desk_cache()
  fax.rebuild_registry()
  territorial_arbitration.rebuild_registry()
  biters.rebuild_desk_index()
  biters.mark_all_desk_circuit_dirty()
  if WORKING_HOURS_ENABLED then
    working_hours.rebuild_registry()
  end
  field_office.rebuild_registry()
  spawner_population.rebuild()
  biter_station.rebuild_registry()
  biterport.rebuild_registry()
  hired_biter.ensure_storage()
  rideable_biter.rebuild_registry()
  storage.biter_station_crafts_per_visit = C.BITER_STATION_CRAFTS_PER_VISIT
  for _, force in pairs(game.forces) do
    biter_station.sync_research(force)
  end
  set_biter_ceasefire()
  trains.on_init()
  for _, player in pairs(game.players) do
    normalize_player_admin_station_items(player)
    normalize_player_admin_station_quickbar(player)
  end
  sync_all_regulated_recipe_unlocks()
  pneumatic.sync_all_intake_recipe_unlocks()
  storage.needs_startup_cleanup = true
  storage.needs_protest_refresh = true
  needs_unit_group_scan = true
end

local function on_configuration_changed(event)
  warn_about_pre_040_save(event)
  init_storage()
  rebuild_desk_cache()
  fax.rebuild_registry()
  territorial_arbitration.rebuild_registry()
  trains.on_init()
  set_biter_ceasefire()
  
  -- Clean up legacy storage from older versions (dead references)
  storage.pod_contents = nil
  storage.tube_stations = nil
  storage.tube_building_ports = nil
  storage.one_way_doors = nil
  storage.global_frustration = nil
  storage.frustration_resolution_accum = nil
  storage.frustration_event_accum = nil
  storage.waiting_zones = nil
  storage.player_zone_preview = nil
  storage.pneumatic_liquifiers = nil -- superseded by tube signal chain

  pneumatic.rebuild_all()

  -- Destroy old waiting markers and normalize desks to the single centered station.
  for _, surface in pairs(game.surfaces) do
    local old_corner_blockers = surface.find_entities_filtered{name = "admin-station-corner-blocker"}
    for _, blocker in ipairs(old_corner_blockers) do blocker.destroy() end

    for _, desk in ipairs(surface.find_entities_filtered{name = ADMIN_DESK_NAMES}) do
      desk = normalize_admin_station_entity(desk, nil) or desk
      local desk_id = desk.unit_number
      storage.desk_zones[desk_id] = {
        bounds = zones.get_zone_bounds(desk.position),
        footprint = zones.get_desk_footprint_bounds(desk.position)
      }
      zones.create_corner_blockers(surface, storage.desk_zones[desk_id].footprint, desk.force)
      ensure_desk_combinator(desk)
      biters.mark_desk_circuit_dirty(desk_id)
      storage.desk_reserved_slots[desk_id] = storage.desk_reserved_slots[desk_id] or 0
      storage.desk_grid_slots[desk_id] = storage.desk_grid_slots[desk_id] or {}

      -- Clean up legacy power entities
      if storage.desk_power and storage.desk_power[desk_id] and storage.desk_power[desk_id].valid then
        storage.desk_power[desk_id].destroy()
      end
    end
  end
  if storage.desk_power then storage.desk_power = nil end
  rebuild_desk_cache()
  biters.rebuild_desk_index()
  biters.mark_all_desk_circuit_dirty()
  working_hours.rebuild_registry()
  field_office.rebuild_registry()
  spawner_population.rebuild()
  biter_station.rebuild_registry()
  biterport.rebuild_registry()
  rideable_biter.rebuild_registry()
  storage.biter_station_crafts_per_visit = C.BITER_STATION_CRAFTS_PER_VISIT
  for _, force in pairs(game.forces) do
    biter_station.sync_research(force)
  end
  for _, player in pairs(game.players) do
    normalize_player_admin_station_items(player)
    normalize_player_admin_station_quickbar(player)
  end
  sync_all_regulated_recipe_unlocks()
  pneumatic.sync_all_intake_recipe_unlocks()
  storage.needs_protest_refresh = true
  needs_unit_group_scan = true

  -- Destroy legacy GUIs
  for _, player in pairs(game.players) do
    if player.gui.top["administratorio-frustration"] then
      player.gui.top["administratorio-frustration"].destroy()
    end
  end
end

local function on_research_finished(event)
  local research = event and event.research
  if not research or not research.valid then return end
  enable_regulated_variants_for_technology(research.force, research)
  biter_station.on_research_finished(research)
  biterport.on_research_finished(research)
  -- Invalidate tube capacity cache when a pneumatic capacity tech is researched.
  if research.name and research.name:find("^pneumatic%-capacity%-") then
    pneumatic.invalidate_capacity_cache()
  end
  if research.name == "pneumatic-form-transport" then
    pneumatic.sync_intake_recipe_unlocks(research.force)
  end
end

local function unlock_field_office_deployment(force)
  if not force or not force.valid then return end
  local technology = force.technologies and force.technologies[FIELD_OFFICE_DEPLOYMENT_TECH]
  if technology and technology.valid and not technology.researched then
    technology.researched = true
  end
end

local function on_player_crafted_item(event)
  local stack = event and event.item_stack
  if not stack or not stack.valid_for_read or stack.name ~= "field-office" then return end
  local player = event.player_index and game.get_player(event.player_index)
  if player then
    unlock_field_office_deployment(player.force)
  end
end

local function on_load()
  resolution_processing.on_load()
  needs_unit_group_scan = true
  needs_load_bugged_biter_cleanup = true
end

-- ============================================================
-- PLAYER EVENTS
-- ============================================================

-- Handguns are banned. Use paperwork.
local function strip_weapons(player)
  local gun_inv = player.get_inventory(defines.inventory.character_guns)
  if gun_inv then gun_inv.clear() end
  local ammo_inv = player.get_inventory(defines.inventory.character_ammo)
  if ammo_inv then ammo_inv.clear() end
  local main_inv = player.get_inventory(defines.inventory.character_main)
  if main_inv then
    for _, item_name in ipairs({"pistol", "submachine-gun", "firearm-magazine", "piercing-rounds-magazine"}) do
      main_inv.remove({name = item_name, count = 1000})
    end
  end
end

local function on_player_created(event)
  storage.needs_startup_cleanup = true
  local player = game.get_player(event.player_index)
  if player then
    biters.refresh_protest_notifications(player)
  end
end

local function on_player_respawned(event)
  local player = game.get_player(event.player_index)
  if player then
    strip_weapons(player)
  end
end

local function on_player_joined_game(event)
  local player = game.get_player(event.player_index)
  if player then
    sync_force_regulated_recipe_unlocks(player.force)
    biters.refresh_protest_notifications(player)
    field_office.update_placement_preview(player, game.tick, true)
  end
end

local function on_player_cursor_stack_changed(event)
  local player = event.player_index and game.get_player(event.player_index)
  if player then
    field_office.update_placement_preview(player, event.tick or game.tick, true)
  end
end

-- Update the biter complaint inspection GUI on the left.
-- Also shows tube network info when hovering tube entities.
-- Also shows biter station zone or building station membership on hover.
local function on_selected_entity_changed(event)
  local player = game.get_player(event.player_index)
  if not player then return end

  biter_station_hover.clear(event.player_index)
  biterport_hover.clear(event.player_index)

  local entity = player.selected
  if entity and entity.valid and biter_station.is_station(entity) then
    biter_station_hover.show_station_zone(player, entity)
  elseif entity and entity.valid and biter_station.is_managed_building(entity) then
    biter_station_hover.show_building_hover(player, entity)
  elseif entity and entity.valid and biterport.is_port(entity) then
    biterport_hover.show_port(player, entity)
  end

  if entity and entity.valid and entity.type == "unit" and storage.waiting_biters[entity.unit_number] then
    pneumatic.destroy_tube_info_gui(player)
    frustration.update_biter_info_gui(player, entity)
  elseif entity and entity.valid and (entity.name == "tube-intake" or entity.name == "tube-outtake") then
    frustration.destroy_biter_info_gui(player)
    pneumatic.update_tube_info_gui(player, entity)
  else
    if player.gui.left["administratorio-biter-info"] then
      player.gui.left["administratorio-biter-info"].destroy()
    end
    pneumatic.destroy_tube_info_gui(player)
  end
  fax.on_selected_entity_changed(player, entity)
end

local function on_player_left_game(event)
  biter_station_hover.clear(event.player_index)
  biterport_hover.clear(event.player_index)
  field_office.clear_placement_preview(event.player_index)
end

local function refresh_selected_biter_info_guis()
  for _, player in pairs(game.connected_players) do
    local entity = player.selected
    if entity
       and entity.valid
       and entity.type == "unit"
       and storage.waiting_biters[entity.unit_number]
       and player.gui.left["administratorio-biter-info"] then
      frustration.update_biter_info_gui(player, entity)
    end
  end
end

-- ============================================================
-- ENTITY BUILD / REMOVE HANDLERS
-- ============================================================

local function swap_biterport_placement_preview(preview, player_index)
  if not preview or not preview.valid then return nil end
  local surface = preview.surface
  local params = {
    name = C.BITERPORT_NAME,
    position = preview.position,
    direction = preview.direction,
    force = preview.force,
    quality = preview.quality and preview.quality.name or nil,
    player = player_index,
    raise_built = false,
    create_build_effect_smoke = false,
  }
  preview.destroy()
  local biterport = surface.create_entity(params)
  if not biterport or not biterport.valid then return nil end
  return biterport
end

local function on_entity_built_inner(event)
  local entity = event.entity or event.created_entity
  if not entity or not entity.valid then return end

  local surface = entity.surface
  local player = event.player_index and game.players[event.player_index]

  -- Only the admin desk is restricted from being placed near nests
  local nearby_spawner = is_admin_station(entity) and find_nearby_enemy_spawner(surface, entity.position)

  if nearby_spawner then
      -- 1. Notify the player
      if player and not was_recent_prebuild_denial(event.player_index, entity.position, event.tick) then
          notify_player_build_denied(player, entity.position)
      end

      -- 2. Refund the item to the player or bot
      local item_to_return = entity.prototype and entity.prototype.items_to_place_this
      local placeable_item = item_to_return and item_to_return[1]
      if player then
          if placeable_item then
              player.insert{
                  name = placeable_item.name,
                  count = 1,
                  quality = entity.quality and entity.quality.name or nil
              }
          end
      elseif event.robot then
          local cargo = event.robot.get_inventory(defines.inventory.robot_cargo)
          if cargo and placeable_item then
              cargo.insert{
                  name = placeable_item.name,
                  count = 1,
                  quality = entity.quality and entity.quality.name or nil
              }
          end
      end

      -- 3. Remove the building immediately
      entity.destroy()
      return
  end

  -- Swap the transient placement-preview roboport to the real biterport container.
  -- The preview entity is only used to drive Factorio's native zone/connection
  -- visualisation while the player holds the biterport item.
  if entity.name == "biterport-placement-preview" then
    entity = swap_biterport_placement_preview(entity, event.player_index)
    if not entity or not entity.valid then return end
  end

  -- Handle Administration Station placement and zone logic
  if is_admin_desk(entity) then
    local player = event.player_index and game.get_player(event.player_index)
    entity = normalize_admin_station_entity(entity, player) or entity
    if not entity or not entity.valid then return end
    freeze_admin_station_rotation(entity)

    local surface = entity.surface
    local desk_id = entity.unit_number
    local bounds = zones.get_zone_bounds(entity.position)
    local footprint = zones.get_desk_footprint_bounds(entity.position)
    local overlaps_existing = zones.zone_overlaps_existing(footprint, desk_id)
    local area_clear = zones.zone_area_is_clear(surface, footprint, entity)

    -- Prevent overlap with other station footprints or existing buildings.
    if overlaps_existing then
      if player then
        player.print({"message.admin-station-overlap"})
        player.insert{name = "admin-station", count = 1, quality = entity.quality and entity.quality.name or nil}
      end
      entity.destroy()
      return
    end

    if not area_clear then
      if player then
        player.print({"message.admin-station-blocked"})
        player.insert{name = "admin-station", count = 1, quality = entity.quality and entity.quality.name or nil}
      end
      entity.destroy()
      return
    end

    -- Sweep dropped items in the footprint into the placing player's inventory,
    -- mirroring vanilla building placement (the admin station's custom collision
    -- mask skips the engine's automatic item sweep).
    local ground_items = surface.find_entities_filtered{
      type = "item-entity",
      area = {footprint.left_top, footprint.right_bottom},
    }
    for _, item_ent in ipairs(ground_items) do
      if item_ent.valid then
        local stack = item_ent.stack
        local remaining = stack.count
        if player and player.valid then
          local inserted = player.insert{name = stack.name, count = stack.count, quality = stack.quality and stack.quality.name or nil}
          remaining = stack.count - inserted
        end
        if remaining > 0 then
          surface.spill_item_stack{
            position = entity.position,
            stack = {name = stack.name, count = remaining, quality = stack.quality and stack.quality.name or nil},
            enable_looted = true,
          }
        end
        item_ent.destroy()
      end
    end

    storage.desk_zones[desk_id] = {bounds = bounds, footprint = footprint}
    zones.create_corner_blockers(surface, footprint, entity.force)
    ensure_desk_combinator(entity)
    storage.desk_reserved_slots[desk_id] = 0
    storage.desk_grid_slots[desk_id] = {}
    storage.admin_desks[desk_id] = entity
    biters.mark_desk_circuit_dirty(desk_id)
  -- Handle pneumatic endpoint support entities.
  elseif pneumatic.is_pneumatic_building(entity) then
    pneumatic.add_pneumatic_supports(entity)
  elseif entity.name == territorial_arbitration.POST_NAME then
    if not territorial_arbitration.on_entity_built(entity, event.player_index and game.get_player(event.player_index)) then
      return
    end

  -- Pipe placement changes tube network topology.
  elseif entity.name == "pneumatic-pipe" or entity.name == "pneumatic-pipe-to-ground" then
    pneumatic.ensure_storage()
    storage.tube_network_dirty = true

  -- Prevent building on top of biter waiting zones
  elseif entity.name ~= "admin-station-combinator" then
    if next(storage.desk_zones) then
      local box = entity.bounding_box
      if box and zones.is_in_admin_zone(entity.surface, box) then
        local player = event.player_index and game.get_player(event.player_index)
        if player then
          player.print({"message.admin-zone-reserved"})
          local item_to_return = entity.prototype and entity.prototype.items_to_place_this
          if item_to_return and item_to_return[1] then
            player.insert{name = item_to_return[1].name, count = 1}
          end
        end
        entity.destroy()
        return
      end
    end
    if fax.is_fax_building(entity) and not fax.on_entity_built(entity, player) then
      return
    end
    if biterport.on_entity_built(event) then
      return
    end
    initialize_bureaucratic_filters(entity)
    if WORKING_HOURS_ENABLED then
      working_hours.track_entity(entity)
    end
    if entity.name == "field-office" then
      unlock_field_office_deployment(entity.force)
      field_office.track_entity(entity)
    end
    if entity.name == C.HIRED_BITER_UNIT_NAME then
      hired_biter.track_entity(entity)
    end
    if biter_station.is_station(entity) then
      biter_station.track_station(entity)
    end
    if biterport.is_port(entity) then
      biterport.track_port(entity)
    end
    if rideable_biter.is_rideable(entity) then
      rideable_biter.track(entity, event.tick or game.tick)
    end
    if biter_station.is_managed_building(entity) then
      biter_station.track_managed_building(entity)
    end
    trains.on_built(entity) -- Passed directly to script
  end
end

local function on_pre_build(event)
  local player = event.player_index and game.get_player(event.player_index)
  if not player or not player.valid then return end

  -- Only warn for admin desk placements
  local cursor = player.cursor_stack
  local placing_admin = cursor and cursor.valid_for_read and is_admin_station(cursor.name)
  if not placing_admin then
    local ghost = player.cursor_ghost
    placing_admin = ghost and is_admin_station(ghost.name)
  end
  if not placing_admin then return end

  if find_nearby_enemy_spawner(player.surface, event.position) then
    notify_player_build_denied(player, event.position)
    remember_recent_prebuild_denial(event.player_index, event.position, event.tick)
  end
end

local function on_entity_built(event)
  on_entity_built_inner(event)
end

local function on_entity_removed(event)
  local entity = event.entity
  if not entity or not entity.valid then return end

  if entity.type == "unit" and biters.on_biter_removed(entity, event) then
    return
  end

  biter_station.on_entity_removed(event)
  biters.on_protest_target_removed(entity)

  if WORKING_HOURS_ENABLED then
    working_hours.untrack_entity(entity)
  end
  if entity.name == "field-office" then
    field_office.untrack_entity(entity)
  end
  if entity.name == C.HIRED_BITER_UNIT_NAME then
    hired_biter.untrack(entity, event)
  end
  biterport.on_entity_removed(event)
  biter_station.untrack_entity(entity, game.tick)
  rideable_biter.untrack(entity)
  if fax.is_fax_building(entity) then
    fax.on_entity_removed(entity, event.buffer)
  end
  territorial_arbitration.on_entity_removed(entity)

  trains.on_removed(entity)

  if is_admin_desk(entity) then
    local desk_id = entity.unit_number
    local surface = entity.surface
    storage.admin_desks[desk_id] = nil
    biters.reroute_desk_biters(desk_id, surface)
    zones.cleanup_desk_zone(desk_id)
    if storage.desk_combinators[desk_id] and storage.desk_combinators[desk_id].valid then
      storage.desk_combinators[desk_id].destroy()
    end
    storage.desk_combinators[desk_id] = nil
    storage.desk_reserved_slots[desk_id] = nil
    if storage.desk_grid_slots then storage.desk_grid_slots[desk_id] = nil end
    biters.clear_desk_circuit_tracking(desk_id)
  elseif pneumatic.is_pneumatic_building(entity) then
    pneumatic.delete_pneumatic_supports(entity)
  elseif entity.name == "pneumatic-pipe" or entity.name == "pneumatic-pipe-to-ground" then
    pneumatic.ensure_storage()
    storage.tube_network_dirty = true
  end
end

local function on_toggle_runtime_debug(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  runtime_debug.toggle(player)
end

-- ============================================================
-- BITER EVENTS
-- ============================================================

local GROUP_STATE_NAMES = {
  [defines.group_state.gathering] = "gathering",
  [defines.group_state.moving] = "moving",
  [defines.group_state.attacking_distraction] = "attacking_distraction",
  [defines.group_state.attacking_target] = "attacking_target",
  [defines.group_state.finished] = "finished",
  [defines.group_state.pathfinding] = "pathfinding",
  [defines.group_state.wander_in_group] = "wander_in_group",
}

local COMMAND_TYPE_NAMES = {
  [defines.command.attack] = "attack",
  [defines.command.attack_area] = "attack_area",
  [defines.command.build_base] = "build_base",
  [defines.command.compound] = "compound",
  [defines.command.flee] = "flee",
  [defines.command.go_to_location] = "go_to_location",
  [defines.command.group] = "group",
  [defines.command.stop] = "stop",
  [defines.command.wander] = "wander",
}

local redirect_enemy_unit_group

local function ensure_unit_group_debug_storage()
  storage.unit_group_debug = storage.unit_group_debug or {}
end

local function unit_group_debug_enabled()
  return runtime_debug.has_active_viewers()
end

local function ensure_unit_group_redirect_watch_storage()
  storage.unit_group_redirect_watch = storage.unit_group_redirect_watch or {}
end

local function ensure_pending_group_redirect_storage()
  storage.pending_group_redirects = storage.pending_group_redirects or {}
  storage.pending_group_redirect_head = storage.pending_group_redirect_head or 1
end

local function queue_pending_group_redirect(members, reason, tick)
  ensure_pending_group_redirect_storage()
  if not members or #members == 0 then return end
  local queue = storage.pending_group_redirects
  for _, member in ipairs(members) do
    if member and member.valid then
      local prepared = biters.prepare_group_redirect(member)
      queue[#queue + 1] = {
        entity = member,
        prepared = prepared,
        reason = reason,
        queued_tick = tick or game.tick,
      }
    end
  end
end

local function group_has_hard_mode_attacker(group)
  if not group or not group.valid or not group.is_unit_group then return false end
  for _, member in ipairs(group.members or {}) do
    if member.valid and biters.is_hard_mode_attacker(member.unit_number) then
      return true
    end
  end
  return false
end

local function process_pending_group_redirects(tick)
  ensure_pending_group_redirect_storage()
  local queue = storage.pending_group_redirects
  local head = storage.pending_group_redirect_head or 1
  if head > #queue then
    storage.pending_group_redirects = {}
    storage.pending_group_redirect_head = 1
    return
  end

  local targets = nil
  local processed = 0
  local budget = C.GROUP_REDIRECTS_PER_TICK or 8
  while head <= #queue and processed < budget do
    local entry = queue[head]
    head = head + 1
    if entry and entry.members then
      queue_pending_group_redirect(entry.members, entry.reason, entry.queued_tick)
      goto continue_redirect
    end
    local biter = entry and entry.entity
    if biter
       and biter.valid
       and biter.type == "unit"
       and biter.force
       and (biter.force.name == "enemy" or entry.prepared == true)
       and not (storage.waiting_biters and storage.waiting_biters[biter.unit_number]) then
      targets = targets or get_cached_desks()
      if #targets > 0 then
        biters.send_biter_to_station_with_targets(biter, targets, {
          prepared_redirect = entry.prepared == true,
        })
      else
        biters.trigger_immediate_protest(biter, biter.surface)
      end
      processed = processed + 1
    end
    ::continue_redirect::
  end

  if head > #queue then
    storage.pending_group_redirects = {}
    storage.pending_group_redirect_head = 1
  else
    storage.pending_group_redirect_head = head
    if head > 64 then
      local compacted = {}
      for i = head, #queue do
        compacted[#compacted + 1] = queue[i]
      end
      storage.pending_group_redirects = compacted
      storage.pending_group_redirect_head = 1
    end
  end
end

local function format_debug_position(pos)
  if not pos then return "[nil]" end
  return "[" .. math.floor(pos.x) .. "," .. math.floor(pos.y) .. "]"
end

local function trim_debug_text(text, max_len)
  if not text then return "none" end
  text = tostring(text):gsub("%s+", " ")
  if #text <= max_len then return text end
  return text:sub(1, max_len - 3) .. "..."
end

local function group_state_name(state)
  return GROUP_STATE_NAMES[state] or ("unknown(" .. tostring(state) .. ")")
end

local function command_type_name(command_type)
  return COMMAND_TYPE_NAMES[command_type] or ("unknown(" .. tostring(command_type) .. ")")
end

local function summarize_target_for_debug(target)
  if not target or not target.valid then return "nil" end

  if target.object_name == "LuaCommandable" then
    if target.is_unit_group then
      return "unit-group#" .. tostring(target.unique_id or "n/a") .. "@" .. format_debug_position(target.position)
    end
    if target.is_entity and target.entity and target.entity.valid then
      target = target.entity
    end
  end

  local name = target.name or target.object_name or "unknown"
  local id = target.unit_number or target.unique_id or "n/a"
  return name .. "#" .. tostring(id) .. "@" .. format_debug_position(target.position)
end

local function summarize_group_command(command, depth)
  if not command then return "none" end
  depth = depth or 0
  if depth >= 2 then
    return command_type_name(command.type)
  end

  local parts = {"type=" .. command_type_name(command.type)}
  if command.destination then
    parts[#parts + 1] = "dest=" .. format_debug_position(command.destination)
  end
  if command.radius then
    parts[#parts + 1] = "radius=" .. tostring(command.radius)
  end
  if command.distraction then
    parts[#parts + 1] = "distraction=" .. tostring(command.distraction)
  end
  if command.target then
    parts[#parts + 1] = "target=" .. summarize_target_for_debug(command.target)
  end
  if command.group then
    parts[#parts + 1] = "group=" .. summarize_target_for_debug(command.group)
  end
  if command.structure_type then
    parts[#parts + 1] = "structure=" .. tostring(command.structure_type)
  end
  if command.commands and #command.commands > 0 then
    local first = summarize_group_command(command.commands[1], depth + 1)
    parts[#parts + 1] = "subcommands=" .. tostring(#command.commands)
    parts[#parts + 1] = "first={" .. first .. "}"
  end
  return trim_debug_text(table.concat(parts, " "), 220)
end

local function safe_unit_parent_group(unit)
  if not unit or not unit.valid or not unit.commandable then return nil end
  local ok, group = pcall(function() return unit.commandable.parent_group end)
  if ok and group and group.valid then return group end
  return nil
end

local function safe_unit_command(unit)
  if not unit or not unit.valid or not unit.commandable then return nil end
  local ok, command = pcall(function() return unit.commandable.command end)
  if ok then return command end
  return nil
end

local function safe_unit_spawner(unit)
  if not unit or not unit.valid or not unit.commandable then return nil end
  local ok, spawner = pcall(function() return unit.commandable.spawner end)
  if ok and spawner and spawner.valid then return spawner end
  return nil
end

local function is_legacy_resolved_biter_release(unit)
  if not unit or not unit.valid or unit.type ~= "unit" then return false end
  if not unit.force or unit.force.name ~= "enemy" then return false end
  if storage.waiting_biters and storage.waiting_biters[unit.unit_number] then return false end
  if storage.field_office_releasing and storage.field_office_releasing[unit.unit_number] then return false end
  if storage.field_office_released_units and storage.field_office_released_units[unit.unit_number] then return false end
  if safe_unit_parent_group(unit) then return false end
  if safe_unit_spawner(unit) then return false end

  local command = safe_unit_command(unit)
  return command and command.type == defines.command.stop
end

local function is_stale_field_office_released_unit(unit)
  if not unit or not unit.valid or unit.type ~= "unit" then return false end
  if not unit.force or unit.force.name ~= "enemy" then return false end
  if not storage.field_office_released_units or not storage.field_office_released_units[unit.unit_number] then return false end
  if storage.field_office_releasing and storage.field_office_releasing[unit.unit_number] then return false end
  if safe_unit_parent_group(unit) then return false end
  if safe_unit_spawner(unit) then return false end

  local command = safe_unit_command(unit)
  return command and command.type == defines.command.stop
end

local function cleanup_legacy_resolved_biter_releases()
  for _, surface in pairs(game.surfaces) do
    for _, unit in ipairs(surface.find_entities_filtered{force = "enemy", type = "unit"}) do
      local unit_number = unit.unit_number
      if is_legacy_resolved_biter_release(unit) then
        unit.destroy()
      elseif is_stale_field_office_released_unit(unit) then
        if storage.field_office_released_units then
          storage.field_office_released_units[unit_number] = nil
        end
        unit.destroy()
      end
    end
  end
end

local function snapshot_unit_group(group, tick)
  if not group or not group.valid or not group.is_unit_group or group.force.name ~= "enemy" then return nil end

  local members = group.members or {}
  local member_count = 0
  local farthest_sq = 0
  local samples = {}

  for index, member in ipairs(members) do
    if member.valid then
      member_count = member_count + 1
      local dx = member.position.x - group.position.x
      local dy = member.position.y - group.position.y
      local dist_sq = dx * dx + dy * dy
      if dist_sq > farthest_sq then
        farthest_sq = dist_sq
      end
      if #samples < 3 then
        samples[#samples + 1] = member.name .. "#" .. tostring(member.unit_number) .. "@" .. format_debug_position(member.position)
      end
    end
  end

  return {
    group = group,
    unique_id = group.unique_id,
    tick = tick,
    state = group.state,
    position = {x = group.position.x, y = group.position.y},
    member_count = member_count,
    farthest_member_distance = math.sqrt(farthest_sq),
    has_command = group.has_command,
    command_summary = summarize_group_command(group.command),
    spawner_summary = summarize_target_for_debug(group.spawner),
    is_script_driven = group.is_script_driven,
    sample_members = table.concat(samples, ", "),
  }
end

local function log_unit_group_snapshot(reason, snapshot, extra)
end

local function summarize_member_statuses_for_debug(member_refs)
  if not member_refs or #member_refs == 0 then return nil end

  local parts = {}
  for _, member in ipairs(member_refs) do
    if member and member.valid then
      local parent_group = member.commandable and member.commandable.parent_group
      local parent_summary = parent_group and parent_group.valid
        and ("unit-group#" .. tostring(parent_group.unique_id))
        or "nil"
      parts[#parts + 1] = member.name
        .. "#" .. tostring(member.unit_number)
        .. "@" .. format_debug_position(member.position)
        .. "(parent=" .. parent_summary .. ")"
    else
      parts[#parts + 1] = "invalid"
    end
  end

  return trim_debug_text(table.concat(parts, ", "), 260)
end

local function remember_unit_group_snapshot(snapshot, created_tick, first_seen_reason)
  if not snapshot then return end
  ensure_unit_group_debug_storage()
  local existing = storage.unit_group_debug[snapshot.unique_id]
  local sample_member_refs = {}
  if snapshot.group and snapshot.group.valid and snapshot.group.is_unit_group then
    for index, member in ipairs(snapshot.group.members) do
      if member.valid then
        sample_member_refs[#sample_member_refs + 1] = member
      end
      if #sample_member_refs >= 3 then break end
    end
  end
  storage.unit_group_debug[snapshot.unique_id] = {
    group = snapshot.group,
    created_tick = created_tick or (existing and existing.created_tick) or snapshot.tick,
    tracked_since_tick = (existing and existing.tracked_since_tick) or snapshot.tick,
    first_seen_reason = (existing and existing.first_seen_reason) or first_seen_reason or "unknown",
    last_tick = snapshot.tick,
    last_state = snapshot.state,
    last_member_count = snapshot.member_count,
    last_position = snapshot.position,
    last_farthest_member_distance = snapshot.farthest_member_distance,
    last_command_summary = snapshot.command_summary,
    last_sample_members = snapshot.sample_members,
    last_sample_member_refs = sample_member_refs,
    spawner_summary = snapshot.spawner_summary,
    is_script_driven = snapshot.is_script_driven,
  }
end

local function track_unit_group(group, tick, reason)
  if not unit_group_debug_enabled() then return end
  local snapshot = snapshot_unit_group(group, tick)
  if not snapshot then return end

  ensure_unit_group_debug_storage()
  local existing = storage.unit_group_debug[snapshot.unique_id]
  if not existing then
    remember_unit_group_snapshot(snapshot, tick, reason)
    log_unit_group_snapshot(reason, snapshot)
    return
  end

  existing.group = snapshot.group
end

local function update_unit_group_debug_entry(group_id, info, tick)
  local group = info and info.group
  if not group or not group.valid then
    local tracked_ticks = info and info.tracked_since_tick and (tick - info.tracked_since_tick) or "unknown"
    local member_statuses = summarize_member_statuses_for_debug(info and info.last_sample_member_refs)
    storage.unit_group_debug[group_id] = nil
    return
  end

  local snapshot = snapshot_unit_group(group, tick)
  if not snapshot then
    storage.unit_group_debug[group_id] = nil
    return
  end

  local changes = {}
  if snapshot.state ~= info.last_state then
    changes[#changes + 1] = "state " .. group_state_name(info.last_state) .. "->" .. group_state_name(snapshot.state)
  end
  if snapshot.member_count ~= info.last_member_count then
    changes[#changes + 1] = "members " .. tostring(info.last_member_count) .. "->" .. tostring(snapshot.member_count)
  end
  if snapshot.command_summary ~= info.last_command_summary then
    changes[#changes + 1] = "command changed"
  end

  if #changes > 0 then
    log_unit_group_snapshot("update", snapshot, table.concat(changes, "; "))
  end

  local tracked_ticks = tick - (info.tracked_since_tick or tick)
  if not snapshot.is_script_driven
     and snapshot.state == defines.group_state.gathering
     and snapshot.command_summary == "none"
     and snapshot.member_count > 0
     and tracked_ticks >= UNIT_GROUP_GATHER_REDIRECT_TICKS then
    redirect_enemy_unit_group(group, tick, "gather_timeout")
    return
  end

  remember_unit_group_snapshot(snapshot, info.created_tick, info.first_seen_reason)
end

local function scan_surface_unit_groups(surface, tick)
  if not unit_group_debug_enabled() then return end
  if not surface then return end
  local discovered = {}

  for _, unit in ipairs(surface.find_entities_filtered{force = "enemy", type = "unit"}) do
    if unit.valid then
      local parent_group = unit.commandable and unit.commandable.parent_group
      if parent_group and parent_group.valid and parent_group.is_unit_group and parent_group.force.name == "enemy" then
        local group_id = parent_group.unique_id
        if not discovered[group_id] then
          discovered[group_id] = true
          track_unit_group(parent_group, tick, "discovered")
        end
      end
    end
  end
end

local function refresh_unit_group_debug(tick)
  if not unit_group_debug_enabled() then return end
  ensure_unit_group_debug_storage()

  for _, surface in pairs(game.surfaces) do
    scan_surface_unit_groups(surface, tick)
  end

  for group_id, info in pairs(storage.unit_group_debug) do
    update_unit_group_debug_entry(group_id, info, tick)
  end
end

local function watch_unit_group_for_redirect(group, tick)
  if not group or not group.valid or not group.is_unit_group or group.force.name ~= "enemy" then return end
  if group.is_script_driven then return end
  if group_has_hard_mode_attacker(group) then return end
  ensure_unit_group_redirect_watch_storage()
  local group_id = group.unique_id
  local existing = storage.unit_group_redirect_watch[group_id]
  storage.unit_group_redirect_watch[group_id] = {
    group = group,
    created_tick = existing and existing.created_tick or tick or game.tick,
  }
end

local function update_unit_group_redirect_watch(tick)
  ensure_unit_group_redirect_watch_storage()
  for group_id, info in pairs(storage.unit_group_redirect_watch) do
    local group = info and info.group
    if not group or not group.valid then
      storage.unit_group_redirect_watch[group_id] = nil
    elseif group.is_script_driven or group.force.name ~= "enemy" then
      storage.unit_group_redirect_watch[group_id] = nil
    elseif group_has_hard_mode_attacker(group) then
      storage.unit_group_redirect_watch[group_id] = nil
    elseif group.state ~= defines.group_state.gathering then
      storage.unit_group_redirect_watch[group_id] = nil
    elseif (tick - (info.created_tick or tick)) >= UNIT_GROUP_GATHER_REDIRECT_TICKS and not group.has_command then
      redirect_enemy_unit_group(group, tick, "gather_timeout")
    end
  end
end

redirect_enemy_unit_group = function(group, tick, reason)
  if not group or not group.valid or not group.is_unit_group or group.force.name ~= "enemy" then return false end
  if group.is_script_driven then return false end
  if group_has_hard_mode_attacker(group) then return false end

  local members = {}
  for _, member in ipairs(group.members) do
    if member.valid then
      members[#members + 1] = member
    end
  end
  if #members == 0 then
    if storage.unit_group_debug then storage.unit_group_debug[group.unique_id] = nil end
    return false
  end

  if unit_group_debug_enabled() then
    local snapshot = snapshot_unit_group(group, tick)
    local targets = get_cached_desks()
    log_unit_group_snapshot("redirect_" .. reason, snapshot, "desks=" .. tostring(#targets))
  end
  if storage.unit_group_debug then storage.unit_group_debug[group.unique_id] = nil end
  if storage.unit_group_redirect_watch then
    storage.unit_group_redirect_watch[group.unique_id] = nil
  end
  group.destroy()
  queue_pending_group_redirect(members, reason, tick)
  return true
end

local function update_tracked_unit_group_debug(tick)
  if not unit_group_debug_enabled() then return end
  ensure_unit_group_debug_storage()
  for group_id, info in pairs(storage.unit_group_debug) do
    update_unit_group_debug_entry(group_id, info, tick)
  end
end

-- Biter groups seeking grievances walk to desks instead of attacking.
local function on_unit_group_created(event)
  watch_unit_group_for_redirect(event.group, event.tick)
  track_unit_group(event.group, event.tick, "created")
end

local function on_unit_added_to_group(event)
  spawner_population.on_unit_added_to_group(event)
  -- Do NOT redirect or snapshot here. adopt_redirected_biter destroys the original
  -- entity, which corrupts the group's member list while the Commander is still
  -- building the group. Subsequent .members reads find the destroyed entity and
  -- crash (LuaEntity assertion !entity->isToBeDeleted()). The redirect is handled
  -- safely by on_unit_group_finished_gathering once the group is fully formed.
end

local function on_entity_spawned(event)
  spawner_population.on_entity_spawned(event)
end

local function on_unit_group_finished_gathering(event)
  local group = event.group
  if group and group.valid and group.force.name == "enemy" then
    if group_has_hard_mode_attacker(group) then
      if storage.unit_group_redirect_watch and group.is_unit_group then
        storage.unit_group_redirect_watch[group.unique_id] = nil
      end
      return
    end
    if storage.unit_group_redirect_watch and group.is_unit_group then
      storage.unit_group_redirect_watch[group.unique_id] = nil
    end
    track_unit_group(group, event.tick, "finished_gathering")
    local members = {}
    for _, member in ipairs(group.members) do
      if member.valid then
        members[#members + 1] = member
      end
    end
    if #members == 0 then
      if unit_group_debug_enabled() then
        local snapshot = snapshot_unit_group(group, event.tick)
        log_unit_group_snapshot("finished_gathering_empty", snapshot)
      end
      if group.valid and group.is_unit_group and storage.unit_group_debug then
        storage.unit_group_debug[group.unique_id] = nil
      end
      return
    end
    if unit_group_debug_enabled() then
      local targets = get_cached_desks()
      local snapshot = snapshot_unit_group(group, event.tick)
      log_unit_group_snapshot("finished_gathering", snapshot, "desks=" .. tostring(#targets))
    end
    if group.valid and group.is_unit_group and storage.unit_group_debug then
      storage.unit_group_debug[group.unique_id] = nil
    end
    group.destroy()
    queue_pending_group_redirect(members, "finished_gathering", event.tick)
  end
end

local function on_entity_died(event)
  local entity = event.entity
  spawner_population.on_entity_died(entity)
  if entity.name == C.HIRED_BITER_UNIT_NAME then
    hired_biter.untrack(entity, event)
  end
  rideable_biter.untrack(entity)
  if entity.type == "unit" and biterport.is_worker_unit(entity.unit_number) then
    biterport.on_entity_died(event)
    return
  end
  if entity.type == "unit" then
    biters.on_biter_died(entity, event)
    biterport.on_entity_died(event)
    biter_station.on_entity_died(event)
  else
    biterport.on_entity_died(event)
    biters.on_protest_target_removed(entity)
  end
  if WORKING_HOURS_ENABLED then
    working_hours.untrack_entity(entity)
  end
  if entity.name == "field-office" then
    field_office.untrack_entity(entity)
  end
  biter_station.untrack_entity(entity, event.tick)
  territorial_arbitration.on_entity_removed(entity)
  if is_admin_desk(entity) then
    local desk_id = entity.unit_number
    local surface = entity.surface
    storage.admin_desks[desk_id] = nil
    biters.reroute_desk_biters(desk_id, surface)
    zones.cleanup_desk_zone(desk_id)
    if storage.desk_combinators[desk_id] and storage.desk_combinators[desk_id].valid then
      storage.desk_combinators[desk_id].destroy()
    end
    storage.desk_combinators[desk_id] = nil
    storage.desk_reserved_slots[desk_id] = nil
    if storage.desk_grid_slots then storage.desk_grid_slots[desk_id] = nil end
    biters.clear_desk_circuit_tracking(desk_id)
  end
  if pneumatic.is_pneumatic_building(entity) then
    pneumatic.delete_pneumatic_supports(entity)
  end
  trains.on_removed(entity)
end

local ON_ENTITY_DIED_FILTERS = {
  {filter = "type", type = "unit"},
  {filter = "type", type = "pipe"},
  {filter = "type", type = "train-stop"},
  {filter = "name", name = "admin-station"},
  {filter = "name", name = "admin-station-north"},
  {filter = "name", name = "admin-station-east"},
  {filter = "name", name = "admin-station-west"},
  {filter = "name", name = "capture-bureau"},
  {filter = "name", name = "biter-station"},
  {filter = "name", name = "biterport"},
  {filter = "name", name = "rideable-biter"},
  {filter = "name", name = "office-desk"},
  {filter = "name", name = "field-office"},
  {filter = "name", name = "corporate-breakroom"},
  {filter = "name", name = "union-headquarters"},
}

-- Keep death-event coverage in lockstep with every configured protest target.
-- In particular, the debug belt/inserter targets need immediate reassignment
-- when they are destroyed rather than waiting for the background recovery pass.
for _, target_type in ipairs(protest_targets.get_target_types()) do
  ON_ENTITY_DIED_FILTERS[#ON_ENTITY_DIED_FILTERS + 1] = {filter = "type", type = target_type}
end

-- Explicit breach targets also need to wake their assigned attacker as soon as
-- they die. Transport infrastructure is absent from this list by design.
for _, building_type in ipairs(protest_targets.get_obstacle_building_types()) do
  ON_ENTITY_DIED_FILTERS[#ON_ENTITY_DIED_FILTERS + 1] = {filter = "type", type = building_type}
end

local function on_script_trigger_effect(event)
  biters.on_script_trigger_effect(event)
  if event.effect_id == "hired-biter-deploy" then
    local pos = event.target_position
    local surface = event.surface_index and game.get_surface(event.surface_index)
      or (event.source_entity and event.source_entity.valid and event.source_entity.surface)
    if pos and surface then
      hired_biter.on_deploy(surface, pos)
    end
  elseif event.effect_id == "hired-biter-command" then
    local pos = event.target_position
    local surface = event.surface_index and game.get_surface(event.surface_index)
      or (event.source_entity and event.source_entity.valid and event.source_entity.surface)
    if pos and surface then
      hired_biter.on_command(surface, pos)
    end
  end
end

local function on_player_selected_area(event)
  hired_biter.on_player_selected_area(event)
end

local function on_player_reverse_selected_area(event)
  hired_biter.on_player_reverse_selected_area(event)
end

local function on_field_agent_waypoint_input(event)
  hired_biter.on_remote_waypoint_input(event)
end

local function on_ai_command_completed(event)
  local tracked_group = unit_group_debug_enabled() and storage.unit_group_debug and storage.unit_group_debug[event.unit_number]
  if tracked_group then
    local snapshot = snapshot_unit_group(tracked_group.group, event.tick)
    local extra = "result=" .. tostring(event.result) .. " distracted=" .. tostring(event.was_distracted)
    if snapshot then
      log_unit_group_snapshot("ai_command_completed", snapshot, extra)
    end
  end
  biter_station.on_ai_command_completed(event)
  if biter_station.is_station_worker_unit(event.unit_number) then
    return
  end
  if field_office.on_ai_command_completed(event) then
    return
  end
  if biterport.on_ai_command_completed(event) then
    return
  end
  if hired_biter.on_ai_command_completed(event) then
    return
  end
  biters.on_ai_command_completed(event)
end

local function on_script_path_request_finished(event)
  if field_office.on_script_path_request_finished(event) then
    return
  end
  biters.on_script_path_request_finished(event)
end

local function on_string_translated(event)
  runtime_debug.handle_string_translated(event)
end

-- ============================================================
-- TRAIN EVENTS
-- ============================================================

local function on_train_changed_state(event)
  trains.on_train_changed_state(event)
end

-- ============================================================
-- ROCKET LAUNCH WIN SCREEN
-- ============================================================

-- All paperwork items to sum for "forms crafted"
local PAPERWORK_ITEMS = {
  "blank-form", "blank-approval", "blank-directive",
  "carbon-offset-certificate-basic", "provisional-approval",
  "safety-waiver-draft", "safety-waiver",
  "construction-permit-draft", "construction-permit",
  "management-verbal-draft", "management-approval-verbal",
  "management-written-proposal", "management-approval-written",
  "transit-authorization", "research-grant-approval",
  "work-order", "form-27b-6",
  "safety-work-order", "construction-work-order",
  "management-verbal-work-order", "management-written-work-order",
  "research-grant-work-order",
  "carbon-offset-certificate-verified", "environmental-impact-report", "white-paper",
}

local function count_forms_crafted(force)
  local total = 0
  for _, surface in pairs(game.surfaces) do
    local stats = force.get_item_production_statistics(surface)
    for _, item_name in ipairs(PAPERWORK_ITEMS) do
      total = total + stats.get_input_count(item_name)
    end
  end
  return total
end

local function format_number(n)
  if n >= 1000000 then
    return string.format("%.1fM", n / 1000000)
  elseif n >= 1000 then
    return string.format("%.1fK", n / 1000)
  end
  return tostring(n)
end

local function build_win_gui(player)
  if player.gui.screen["administratorio-win-screen"] then
    player.gui.screen["administratorio-win-screen"].destroy()
  end

  local stats = storage.stats or {}
  local forms_crafted = count_forms_crafted(player.force)

  local frame = player.gui.screen.add{
    type = "frame",
    name = "administratorio-win-screen",
    direction = "vertical",
    caption = {"gui.win-title"},
  }
  frame.auto_center = true
  frame.style.minimal_width = 400
  frame.style.maximal_width = 500

  local inner = frame.add{type = "frame", direction = "vertical", style = "inside_shallow_frame_with_padding"}
  inner.style.padding = 12

  -- Subtitle
  local subtitle = inner.add{type = "label", caption = {"gui.win-subtitle"}}
  subtitle.style.font = "default-bold"
  subtitle.style.bottom_margin = 12

  -- Stat rows
  local stat_table = inner.add{type = "table", column_count = 2}
  stat_table.style.column_alignments[2] = "right"
  stat_table.style.horizontal_spacing = 24
  stat_table.style.vertical_spacing = 8

  local rows = {
    {{"gui.stat-rockets-launched"},    stats.rockets_launched or 1},
    {{"gui.stat-cases-resolved"},      stats.cases_resolved or 0},
    {{"gui.stat-money-earned"},        stats.money_earned or 0},
    {{"gui.stat-forms-crafted"},       forms_crafted},
    {{"gui.stat-workers-hired"},       stats.biters_hired or 0},
    {{"gui.stat-protests-suppressed"}, stats.protests_suppressed or 0},
    {{"gui.stat-nests-evicted"},       stats.nests_evicted or 0},
    {{"gui.stat-nests-calmed"},        stats.nests_calmed or 0},
  }

  for _, row in ipairs(rows) do
    local label = stat_table.add{type = "label", caption = row[1]}
    label.style.font = "default-semibold"
    local value = stat_table.add{type = "label", caption = format_number(row[2])}
    value.style.font = "default-bold"
    value.style.font_color = {r = 1, g = 0.85, b = 0.2}
  end

  -- Play time
  local ticks = game.tick
  local hours = math.floor(ticks / (60 * 60 * 60))
  local minutes = math.floor((ticks % (60 * 60 * 60)) / (60 * 60))
  local time_flow = inner.add{type = "flow", direction = "horizontal"}
  time_flow.style.top_margin = 16
  time_flow.style.horizontally_stretchable = true
  time_flow.style.horizontal_align = "center"
  local time_label = time_flow.add{type = "label", caption = {"gui.win-time", hours, minutes}}
  time_label.style.font = "default-semibold"
  time_label.style.font_color = {r = 0.7, g = 0.7, b = 0.7}

  -- Close button
  local button_flow = frame.add{type = "flow", direction = "horizontal"}
  button_flow.style.top_margin = 8
  button_flow.style.horizontally_stretchable = true
  button_flow.style.horizontal_align = "center"
  button_flow.add{
    type = "button",
    name = "administratorio-win-close",
    caption = {"gui.win-close"},
    style = "confirm_button",
  }
end

local function on_rocket_launched(event)
  if storage.stats then
    storage.stats.rockets_launched = (storage.stats.rockets_launched or 0) + 1
  end

  -- Show GUI to the player who launched, or all connected players
  local silo = event.rocket_silo
  local players_to_notify = {}
  if silo and silo.valid and silo.last_user then
    players_to_notify[#players_to_notify + 1] = silo.last_user
  else
    for _, p in pairs(game.connected_players) do
      players_to_notify[#players_to_notify + 1] = p
    end
  end

  for _, player in ipairs(players_to_notify) do
    build_win_gui(player)
  end

  game.set_game_state{game_finished = true, player_won = true, can_continue = true}
end

local function on_gui_click(event)
  if not event.element or not event.element.valid then return end

  local player = game.get_player(event.player_index)
  if not player then return end

  if event.element.name == "administratorio-win-close" then
    if player.gui.screen["administratorio-win-screen"] then
      player.gui.screen["administratorio-win-screen"].destroy()
    end
  elseif runtime_debug.handle_gui_click(player, event.element.name) then
    return
  end
end

local function on_gui_selection_state_changed(event)
  fax.on_gui_selection_state_changed(event)
end


-- ============================================================
-- MAIN LOOP (Runs every 1 second)
-- ============================================================

local function on_protest_pacing_tick(_event)
  runtime_debug.run_profiled_external_sections("protest_pacing", function()
    biters.process_protest_pacing(game.surfaces[1])
    refresh_selected_biter_info_guis()
  end)
end

local function on_unit_group_debug_tick(event)
  runtime_debug.run_profiled_external_sections("unit_group_debug_tick", function()
    update_unit_group_redirect_watch(event.tick)
    if unit_group_debug_enabled() and needs_unit_group_scan then
      needs_unit_group_scan = false
      refresh_unit_group_debug(event.tick)
    else
      update_tracked_unit_group_debug(event.tick)
    end
  end)
end

local function on_main_tick(event)
  if needs_load_bugged_biter_cleanup then
    needs_load_bugged_biter_cleanup = false
    cleanup_legacy_resolved_biter_releases()
  end
  runtime_debug.run_profiled_external_sections("biter_station_sanitize", function()
    biter_station.sanitize_external_links()
  end)
  resolution_processing.on_tick(event)
  runtime_debug.run_profiled_external_sections("hired_biter", function()
    hired_biter.update(event.tick)
  end)
  runtime_debug.run_profiled_external_sections("rideable_biter", function()
    rideable_biter.update(event.tick)
  end)
  trajectory_compliance.on_tick(event)
  territorial_arbitration.on_tick(event)
end

local function on_pneumatic_tick(_event)
  runtime_debug.run_profiled_external_sections("pneumatic", function()
    pneumatic.on_pneumatic_tick()
  end)
end

local function on_biter_station_tick(event)
  runtime_debug.run_profiled_external_sections("biter_station", function()
    biter_station.update(event.tick)
  end)
end

local function on_biterport_tick(event)
  runtime_debug.run_profiled_external_sections("biterport", function()
    biterport.update(event.tick)
  end)
end

local function on_field_office_tick(event)
  runtime_debug.run_profiled_external_sections("field_office", function(runtime_profile)
    field_office.update(event.tick, runtime_profile)
  end)
  runtime_debug.run_profiled_external_sections("field_office_placement_preview", function()
    field_office.update_all_placement_previews(event.tick)
  end)
end

resolution_processing = control_resolution_processing_factory.new({
  biters = biters,
  collect_runtime_debug_counts = collect_runtime_debug_counts,
  fax = fax,
  field_office = field_office,
  get_cached_desks = get_cached_desks,
  process_pending_group_redirects = process_pending_group_redirects,
  runtime_debug = runtime_debug,
  strip_weapons = strip_weapons,
  trains = trains,
  update_tracked_unit_group_debug = update_tracked_unit_group_debug,
  warn_force_about_evolution_complaints = warn_force_about_evolution_complaints,
  working_hours = working_hours,
})

control_event_router.register({
  on_ai_command_completed = on_ai_command_completed,
  on_biter_station_tick = on_biter_station_tick,
  on_biterport_tick = on_biterport_tick,
  on_field_office_tick = on_field_office_tick,
  on_configuration_changed = on_configuration_changed,
  on_entity_built = on_entity_built,
  on_entity_died = on_entity_died,
  on_entity_died_filters = ON_ENTITY_DIED_FILTERS,
  on_entity_spawned = on_entity_spawned,
  on_entity_removed = on_entity_removed,
  on_field_agent_waypoint_input = on_field_agent_waypoint_input,
  on_gui_click = on_gui_click,
  on_gui_selection_state_changed = on_gui_selection_state_changed,
  on_init = on_init,
  on_load = on_load,
  on_main_tick = on_main_tick,
  on_pneumatic_tick = on_pneumatic_tick,
  on_player_created = on_player_created,
  on_player_cursor_stack_changed = on_player_cursor_stack_changed,
  on_player_joined_game = on_player_joined_game,
  on_player_left_game = on_player_left_game,
  on_player_crafted_item = on_player_crafted_item,
  on_pre_build = on_pre_build,
  on_player_respawned = on_player_respawned,
  on_player_reverse_selected_area = on_player_reverse_selected_area,
  on_research_finished = on_research_finished,
  on_player_selected_area = on_player_selected_area,
  on_protest_pacing_tick = on_protest_pacing_tick,
  on_rocket_launched = on_rocket_launched,
  on_script_path_request_finished = on_script_path_request_finished,
  on_script_trigger_effect = on_script_trigger_effect,
  on_selected_entity_changed = on_selected_entity_changed,
  on_string_translated = on_string_translated,
  on_toggle_runtime_debug = on_toggle_runtime_debug,
  on_train_changed_state = on_train_changed_state,
  on_unit_added_to_group = on_unit_added_to_group,
  on_unit_group_created = on_unit_group_created,
  on_unit_group_debug_tick = on_unit_group_debug_tick,
  on_unit_group_finished_gathering = on_unit_group_finished_gathering,
  biter_station_check_ticks = C.BITER_STATION_CHECK_TICKS,
  biterport_check_ticks = C.BITERPORT_CHECK_TICKS,
  field_office_update_ticks = C.FIELD_OFFICE_UPDATE_TICKS,
  unit_group_debug_scan_interval = UNIT_GROUP_DEBUG_SCAN_INTERVAL,
})
