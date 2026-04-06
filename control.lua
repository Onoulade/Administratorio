-- ADMINISTRATORIO: RUNTIME ORCHESTRATOR
-- Requires script modules and registers all event handlers.

local C = require("scripts.constants")
local pneumatic = require("scripts.pneumatic")
local frustration = require("scripts.frustration")
local zones = require("scripts.zones")
local biters = require("scripts.biters")
local trains = require("scripts.trains")
local working_hours = require("scripts.working_hours")
local runtime_debug = require("scripts.control_runtime_debug")
local control_event_router = require("scripts.control_event_router")
local control_resolution_processing_factory = require("scripts.control_resolution_processing")
local regulated_unlocks = require("scripts.regulated_unlocks")
local feature_flags = require("feature_flags")

local ADMIN_STATION_NAMES = {
  "admin-station",
  "admin-station-north",
  "admin-station-east",
  "admin-station-west",
}

local ADMIN_STATION_NAME_SET = {}
for _, name in ipairs(ADMIN_STATION_NAMES) do
  ADMIN_STATION_NAME_SET[name] = true
end

local UNIT_GROUP_DEBUG_SCAN_INTERVAL = 180
local UNIT_GROUP_GATHER_REDIRECT_TICKS = 300
local WORKING_HOURS_ENABLED = feature_flags.working_hours_enabled()
local needs_unit_group_scan = false
local resolution_processing
local enable_regulated_variants_for_technology = regulated_unlocks.enable_regulated_variants_for_technology

local function get_entity_name(entity_or_name)
  if type(entity_or_name) == "string" then
    return entity_or_name
  end
  if entity_or_name and entity_or_name.name then
    return entity_or_name.name
  end
  return nil
end

local function is_admin_station(entity_or_name)
  local name = get_entity_name(entity_or_name)
  return name and ADMIN_STATION_NAME_SET[name] == true
end

local function normalize_admin_station_inventory(inventory)
  if not inventory then return end
  for i = 1, #inventory do
    local stack = inventory[i]
    if stack and stack.valid_for_read and is_admin_station(stack.name) and stack.name ~= "admin-station" then
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
    if filter and filter.name and is_admin_station(filter.name) and filter.name ~= "admin-station" then
      player.set_quick_bar_slot(slot, {name = "admin-station", quality = filter.quality})
    end
  end
end

local function freeze_admin_station_rotation(desk)
  if not desk or not desk.valid then return end
  desk.rotatable = false
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

  for _, info in pairs(storage.waiting_biters or {}) do
    if info.desk_id == old_desk_id then
      info.desk_id = new_desk_id
    end
  end
end

local function normalize_admin_station_entity(desk, player)
  if not desk or not desk.valid then return nil end
  if desk.name == "admin-station" then
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
    for _, desk in ipairs(surface.find_entities_filtered{name = ADMIN_STATION_NAMES}) do
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
      desks[#desks + 1] = refresh_cached_desk(desk)
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
    biters = 0,
    waiting = 0,
    pathfinding = 0,
    protesting = 0,
    pacified = 0,
    returning_home = 0,
  }

  for _, station_data in pairs(storage.stations or {}) do
    if station_data and station_data.station and station_data.station.valid then
      counts.stations = counts.stations + 1
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
    elseif info.state == "pacified" then
      counts.pacified = counts.pacified + 1
    elseif info.state == "returning_home" then
      counts.returning_home = counts.returning_home + 1
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
  storage.desk_circuit_dirty = storage.desk_circuit_dirty or {}
  storage.evolution_complaint_warnings = storage.evolution_complaint_warnings or {}
  storage.stations = storage.stations or {}
  storage.achievements = storage.achievements or {}
  storage.path_requests = storage.path_requests or {}
  storage.pending_group_redirects = storage.pending_group_redirects or {}
  storage.runtime_debug_players = storage.runtime_debug_players or {}
  storage.stats = storage.stats or {
    cases_resolved = 0,
    money_earned = 0,
    protests_suppressed = 0,
    nests_evicted = 0,
  }
  if WORKING_HOURS_ENABLED then
    working_hours.ensure_storage()
  end

  -- Ensure all existing locomotives and pneumatic buildings are properly initialized.
  for _, surface in pairs(game.surfaces) do
    for _, loco in ipairs(surface.find_entities_filtered{type = "locomotive"}) do
      initialize_bureaucratic_filters(loco)
    end
    for building_name, _ in pairs(C.PNEUMATIC_BUILDINGS) do
      for _, building in ipairs(surface.find_entities_filtered{name = building_name}) do
        local existing = surface.find_entities_filtered{
          type = "inserter",
          name = {"pneumatic-hidden-intake", "pneumatic-hidden-outtake"},
          position = building.position,
          radius = 0.5
        }
        if #existing == 0 then
          pneumatic.add_pneumatic_inserter(building)
        end
      end
    end
  end
end

local function cleanup_waiting_zone_overlays()
  for _, surface in pairs(game.surfaces) do
    local markers = surface.find_entities_filtered{name = "waiting-zone-marker"}
    for _, marker in ipairs(markers) do
      if marker.valid then
        marker.destroy()
      end
    end
  end
end

-- ============================================================
-- LIFECYCLE EVENTS
-- ============================================================

-- Biters should never attack in Administratorio. They are processed via administrative desks.
local function set_biter_ceasefire()
  local enemy = game.forces["enemy"]
  local player = game.forces["player"]
  if enemy and player then
    enemy.set_cease_fire(player, true)
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
  biters.rebuild_desk_index()
  biters.mark_all_desk_circuit_dirty()
  if WORKING_HOURS_ENABLED then
    working_hours.rebuild_registry()
  end
  set_biter_ceasefire()
  trains.init_all_stations()
  for _, player in pairs(game.players) do
    normalize_player_admin_station_items(player)
    normalize_player_admin_station_quickbar(player)
  end
  sync_all_regulated_recipe_unlocks()
  storage.needs_startup_cleanup = true
  storage.needs_protest_refresh = true
  needs_unit_group_scan = true
end

local function on_configuration_changed()
  init_storage()
  rebuild_desk_cache()
  trains.init_all_stations()
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

  -- Destroy old waiting markers and normalize desks to the single centered station.
  for _, surface in pairs(game.surfaces) do
    local old_markers = surface.find_entities_filtered{name = "waiting-zone-marker"}
    for _, marker in ipairs(old_markers) do marker.destroy() end
    local old_corner_blockers = surface.find_entities_filtered{name = "admin-station-corner-blocker"}
    for _, blocker in ipairs(old_corner_blockers) do blocker.destroy() end

    for _, desk in ipairs(surface.find_entities_filtered{name = ADMIN_STATION_NAMES}) do
      desk = normalize_admin_station_entity(desk, nil) or desk
      local desk_id = desk.unit_number
      storage.desk_zones[desk_id] = {
        bounds = zones.get_zone_bounds(desk.position),
        footprint = zones.get_desk_footprint_bounds(desk.position)
      }
      zones.create_zone_markers(surface, storage.desk_zones[desk_id].bounds)
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
  for _, player in pairs(game.players) do
    normalize_player_admin_station_items(player)
    normalize_player_admin_station_quickbar(player)
  end
  sync_all_regulated_recipe_unlocks()
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
end

local function on_load()
  resolution_processing.on_load()
  needs_unit_group_scan = true
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
    biters.refresh_protest_notifications(player)
  end
end

-- Update the biter complaint inspection GUI on the left.
local function on_selected_entity_changed(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  local entity = player.selected
  if entity and entity.valid and entity.type == "unit" and storage.waiting_biters[entity.unit_number] then
    frustration.update_biter_info_gui(player, entity)
  elseif player.gui.left["administratorio-biter-info"] then
    player.gui.left["administratorio-biter-info"].destroy()
  end
end

-- ============================================================
-- ENTITY BUILD / REMOVE HANDLERS
-- ============================================================

local function on_entity_built_inner(event)
  local entity = event.entity or event.created_entity
  if not entity or not entity.valid then return end

  -- Handle Administration Station placement and zone logic
  if is_admin_station(entity) then
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
        player.print("Cannot place here: administrative station footprint would overlap another station.")
        player.insert{name = "admin-station", count = 1, quality = entity.quality and entity.quality.name or nil}
      end
      entity.destroy()
      return
    end

    if not area_clear then
      if player then
        player.print("Cannot place here: station footprint is blocked by terrain or buildings.")
        player.insert{name = "admin-station", count = 1, quality = entity.quality and entity.quality.name or nil}
      end
      entity.destroy()
      return
    end

    storage.desk_zones[desk_id] = {bounds = bounds, footprint = footprint}
    zones.create_zone_markers(surface, bounds)
    zones.create_corner_blockers(surface, footprint, entity.force)
    ensure_desk_combinator(entity)
    storage.desk_reserved_slots[desk_id] = 0
    storage.desk_grid_slots[desk_id] = {}
    storage.admin_desks[desk_id] = entity
    biters.mark_desk_circuit_dirty(desk_id)
  -- Handle Pneumatic Building placement (automatic hidden inserters)
  elseif pneumatic.is_pneumatic_building(entity) then
    pneumatic.add_pneumatic_inserter(entity)

  -- Prevent building on top of biter waiting zones
  elseif entity.name ~= "waiting-zone-marker" and entity.name ~= "admin-station-combinator" then
    if next(storage.desk_zones) then
      local box = entity.bounding_box
      if box and zones.is_in_admin_zone(entity.surface, box) then
        local player = event.player_index and game.get_player(event.player_index)
        if player then
          player.print("Cannot build here: administrative station footprint is reserved.")
          local item_to_return = entity.prototype and entity.prototype.items_to_place_this
          if item_to_return and item_to_return[1] then
            player.insert{name = item_to_return[1].name, count = 1}
          end
        end
        entity.destroy()
        return
      end
    end
    initialize_bureaucratic_filters(entity)
    if WORKING_HOURS_ENABLED then
      working_hours.track_entity(entity)
    end
    trains.on_built(entity) -- Passed directly to script
  end
end

local function on_entity_built(event)
  on_entity_built_inner(event)
end

local function on_entity_removed(event)
  local entity = event.entity
  if not entity or not entity.valid then return end

  biters.on_protest_target_removed(entity)

  if WORKING_HOURS_ENABLED then
    working_hours.untrack_entity(entity)
  end
  
  trains.on_removed(entity)

  if is_admin_station(entity) then
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
    pneumatic.delete_pneumatic_inserters(entity, event.buffer)
  end
end

local function on_player_rotated_entity(event)
  if pneumatic.is_pneumatic_building(event.entity) then
    pneumatic.update_pneumatic_inserter_direction(event.entity)
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

local LOG_PREFIX = "[Administratorio] "

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

local function ensure_pending_group_redirect_storage()
  storage.pending_group_redirects = storage.pending_group_redirects or {}
end

local function queue_pending_group_redirect(members, reason, tick)
  ensure_pending_group_redirect_storage()
  if not members or #members == 0 then return end
  storage.pending_group_redirects[#storage.pending_group_redirects + 1] = {
    members = members,
    reason = reason,
    queued_tick = tick or game.tick,
  }
end

local function process_pending_group_redirects(tick)
  ensure_pending_group_redirect_storage()
  local queue = storage.pending_group_redirects
  if #queue == 0 then return end

  storage.pending_group_redirects = {}
  for _, entry in ipairs(queue) do
    local members = {}
    for _, biter in ipairs(entry.members or {}) do
      if biter
         and biter.valid
         and biter.type == "unit"
         and biter.force
         and biter.force.name == "enemy"
         and not (storage.waiting_biters and storage.waiting_biters[biter.unit_number]) then
        members[#members + 1] = biter
      end
    end

    if #members > 0 then
      local targets = get_cached_desks()
      for _, biter in ipairs(members) do
        if #targets > 0 then
          biters.send_biter_to_station_with_targets(biter, targets)
        else
          biters.trigger_immediate_protest(biter, biter.surface)
        end
      end
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
  if not snapshot then return end
  local line = LOG_PREFIX
    .. "Unit group DEBUG [" .. reason .. "]"
    .. " id=" .. tostring(snapshot.unique_id)
    .. " state=" .. group_state_name(snapshot.state)
    .. " members=" .. tostring(snapshot.member_count)
    .. " spread=" .. string.format("%.1f", snapshot.farthest_member_distance)
    .. " pos=" .. format_debug_position(snapshot.position)
    .. " command=" .. snapshot.command_summary
    .. " spawner=" .. snapshot.spawner_summary
    .. " script_driven=" .. tostring(snapshot.is_script_driven)
  if snapshot.sample_members and snapshot.sample_members ~= "" then
    line = line .. " sample_members=" .. snapshot.sample_members
  end
  if extra and extra ~= "" then
    line = line .. " " .. extra
  end
  -- log(line)
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
    -- log(LOG_PREFIX
    --   .. "Unit group DEBUG [disbanded]"
    --   .. " id=" .. tostring(group_id)
    --   .. " tracked_ticks=" .. tostring(tracked_ticks)
    --   .. " first_seen=" .. tostring(info and info.first_seen_reason or "unknown")
    --   .. " last_state=" .. group_state_name(info and info.last_state)
    --   .. " last_members=" .. tostring(info and info.last_member_count or 0)
    --   .. " last_spread=" .. string.format("%.1f", info and info.last_farthest_member_distance or 0)
    --   .. " last_pos=" .. format_debug_position(info and info.last_position)
    --   .. " last_command=" .. trim_debug_text(info and info.last_command_summary or "none", 220)
    --   .. " spawner=" .. tostring(info and info.spawner_summary or "nil")
    --   .. (info and info.last_sample_members and info.last_sample_members ~= "" and (" sample_members=" .. info.last_sample_members) or "")
    --   .. (member_statuses and (" sample_status=" .. member_statuses) or ""))
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
  ensure_unit_group_debug_storage()

  for _, surface in pairs(game.surfaces) do
    scan_surface_unit_groups(surface, tick)
  end

  for group_id, info in pairs(storage.unit_group_debug) do
    update_unit_group_debug_entry(group_id, info, tick)
  end
end

redirect_enemy_unit_group = function(group, tick, reason)
  if not group or not group.valid or not group.is_unit_group or group.force.name ~= "enemy" then return false end
  if group.is_script_driven then return false end

  local snapshot = snapshot_unit_group(group, tick)
  if not snapshot or snapshot.member_count <= 0 then
    if group.valid then
      storage.unit_group_debug[group.unique_id] = nil
    end
    return false
  end

  local members = {}
  for _, member in ipairs(group.members) do
    if member.valid then
      members[#members + 1] = member
    end
  end
  if #members == 0 then
    storage.unit_group_debug[group.unique_id] = nil
    return false
  end

  local targets = get_cached_desks()
  log_unit_group_snapshot("redirect_" .. reason, snapshot, "desks=" .. tostring(#targets))
  storage.unit_group_debug[group.unique_id] = nil
  group.destroy()
  queue_pending_group_redirect(members, reason, tick)
  return true
end

local function update_tracked_unit_group_debug(tick)
  ensure_unit_group_debug_storage()
  for group_id, info in pairs(storage.unit_group_debug) do
    update_unit_group_debug_entry(group_id, info, tick)
  end
end

-- Biter groups seeking grievances walk to desks instead of attacking.
local function on_unit_group_created(event)
  track_unit_group(event.group, event.tick, "created")
end

local function on_unit_added_to_group(event)
  -- Do NOT redirect or snapshot here. adopt_redirected_biter destroys the original
  -- entity, which corrupts the group's member list while the Commander is still
  -- building the group. Subsequent .members reads find the destroyed entity and
  -- crash (LuaEntity assertion !entity->isToBeDeleted()). The redirect is handled
  -- safely by on_unit_group_finished_gathering once the group is fully formed.
end

local function on_unit_removed_from_group(event)
end

local function on_unit_group_finished_gathering(event)
  local group = event.group
  if group and group.valid and group.force.name == "enemy" then
    track_unit_group(group, event.tick, "finished_gathering")
    local members = {}
    for _, member in ipairs(group.members) do
      if member.valid then
        members[#members + 1] = member
      end
    end
    if #members == 0 then
      local snapshot = snapshot_unit_group(group, event.tick)
      log_unit_group_snapshot("finished_gathering_empty", snapshot)
      if group.valid and group.is_unit_group then
        storage.unit_group_debug[group.unique_id] = nil
      end
      return
    end
    local targets = get_cached_desks()
    local snapshot = snapshot_unit_group(group, event.tick)
    log_unit_group_snapshot("finished_gathering", snapshot, "desks=" .. tostring(#targets))
    if group.valid and group.is_unit_group then
      storage.unit_group_debug[group.unique_id] = nil
    end
    group.destroy()
    queue_pending_group_redirect(members, "finished_gathering", event.tick)
  end
end

local function on_entity_died(event)
  local entity = event.entity
  if entity.type == "unit" then
    biters.on_biter_died(entity)
  else
    biters.on_protest_target_removed(entity)
  end
  if WORKING_HOURS_ENABLED then
    working_hours.untrack_entity(entity)
  end
  if is_admin_station(entity) then
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
    pneumatic.delete_pneumatic_inserters(entity)
  end
  trains.on_removed(entity)
end

local ON_ENTITY_DIED_FILTERS = {
  {filter = "type", type = "unit"},
  {filter = "type", type = "assembling-machine"},
  {filter = "type", type = "furnace"},
  {filter = "type", type = "lab"},
  {filter = "type", type = "mining-drill"},
  {filter = "type", type = "train-stop"},
  {filter = "name", name = "admin-station"},
  {filter = "name", name = "admin-station-north"},
  {filter = "name", name = "admin-station-east"},
  {filter = "name", name = "admin-station-west"},
  {filter = "name", name = "office-desk"},
  {filter = "name", name = "corporate-breakroom"},
  {filter = "name", name = "meeting-room"},
  {filter = "name", name = "union-headquarters"},
}

local function on_script_trigger_effect(event)
  biters.on_script_trigger_effect(event)
end

local function on_ai_command_completed(event)
  local tracked_group = storage.unit_group_debug and storage.unit_group_debug[event.unit_number]
  if tracked_group then
    local snapshot = snapshot_unit_group(tracked_group.group, event.tick)
    local extra = "result=" .. tostring(event.result) .. " distracted=" .. tostring(event.was_distracted)
    if snapshot then
      log_unit_group_snapshot("ai_command_completed", snapshot, extra)
    else
      -- log(LOG_PREFIX .. "Unit group DEBUG [ai_command_completed] id=" .. tostring(event.unit_number) .. " " .. extra)
    end
  end
  biters.on_ai_command_completed(event)
end

local function on_script_path_request_finished(event)
  biters.on_script_path_request_finished(event)
end

local function on_string_translated(event)
  runtime_debug.handle_string_translated(event)
end

-- ============================================================
-- TRAIN EVENTS
-- ============================================================

local function on_train_changed_state(event)
  trains.handle_state_change(event)
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
  "management-written-proposal", "management-written-review", "management-approval-written",
  "transit-authorization", "research-grant-approval",
  "work-order", "form-27b-6",
  "safety-work-order", "construction-work-order",
  "management-verbal-work-order", "management-written-work-order",
  "research-grant-work-order",
  "carbon-offset-certificate-verified", "environmental-impact-report", "white-paper",
}

local function count_forms_crafted(force)
  local total = 0
  local stats = force.item_production_statistics
  for _, item_name in ipairs(PAPERWORK_ITEMS) do
    total = total + stats.get_input_count(item_name)
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
    {{"gui.stat-cases-resolved"},   stats.cases_resolved or 0},
    {{"gui.stat-money-earned"},     stats.money_earned or 0},
    {{"gui.stat-forms-crafted"},    forms_crafted},
    {{"gui.stat-protests-suppressed"}, stats.protests_suppressed or 0},
    {{"gui.stat-nests-evicted"},    stats.nests_evicted or 0},
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


-- ============================================================
-- MAIN LOOP (Runs every 1 second)
-- ============================================================

local function on_protest_pacing_tick(_event)
  biters.process_protest_pacing(game.surfaces[1])
end

local function on_unit_group_debug_tick(event)
  if needs_unit_group_scan then
    needs_unit_group_scan = false
    refresh_unit_group_debug(event.tick)
  else
    update_tracked_unit_group_debug(event.tick)
  end
end

local function on_main_tick(event)
  resolution_processing.on_tick(event)
end

resolution_processing = control_resolution_processing_factory.new({
  biters = biters,
  cleanup_waiting_zone_overlays = cleanup_waiting_zone_overlays,
  collect_runtime_debug_counts = collect_runtime_debug_counts,
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
  on_configuration_changed = on_configuration_changed,
  on_entity_built = on_entity_built,
  on_entity_died = on_entity_died,
  on_entity_died_filters = ON_ENTITY_DIED_FILTERS,
  on_entity_removed = on_entity_removed,
  on_gui_click = on_gui_click,
  on_init = on_init,
  on_load = on_load,
  on_main_tick = on_main_tick,
  on_player_created = on_player_created,
  on_player_joined_game = on_player_joined_game,
  on_player_respawned = on_player_respawned,
  on_research_finished = on_research_finished,
  on_player_rotated_entity = on_player_rotated_entity,
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
  on_unit_removed_from_group = on_unit_removed_from_group,
  unit_group_debug_scan_interval = UNIT_GROUP_DEBUG_SCAN_INTERVAL,
})
