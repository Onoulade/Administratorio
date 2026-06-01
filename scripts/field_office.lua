-- Field Office: early-game bureaucratic outpost.
-- Summons biters from nearby nests as one-per-craft-cycle workers.
-- Only operates (1.0x, 0 pollution) while a biter is physically present and working.
-- Completely inactive otherwise. Does not call biters at night (unless overtime-exemption).
local C = require("scripts.constants")
local working_hours = require("scripts.working_hours")
local unit_ai_settings = require("scripts.unit_ai_settings")

local M = {}

local BITER_FORCE_NAME = "administratorio-biters"
local SPAWNER_TYPES = {"unit-spawner"}
local ENTITY_NAME = "field-office"
local CRAFTS_PER_BITER = 2
local PLACEMENT_RANGE_COLOR = {r = 0.25, g = 0.85, b = 0.35, a = 0.75}
local PLACEMENT_NEST_COLOR = {r = 1.0, g = 0.45, b = 0.25, a = 0.9}
local UNREACHABLE_RETRY_TICKS = 10 * 60
local CALLING_PROGRESS_DISTANCE_SQUARED = 0.04
local CALLING_STUCK_TICKS = 5 * 60
local CALLING_TIMEOUT_TICKS = 45 * 60
local release_biter
local set_office_status

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

local function run_profiled(runtime_profile, key, fn)
  if not runtime_profile then
    return fn()
  end

  local profiler = game.create_profiler()
  local result = fn()
  record_runtime_profile(runtime_profile, key, profiler)
  return result
end

local function is_field_office(name)
  return name == ENTITY_NAME
end

local function get_biter_force()
  return game.forces[BITER_FORCE_NAME] or game.forces["neutral"]
end

local function safe_unit_parent_group(unit)
  if not unit or not unit.valid or not unit.commandable then return nil end
  local ok, group = pcall(function() return unit.commandable.parent_group end)
  if ok and group and group.valid then return group end
  return nil
end

local function safe_unit_spawner(unit)
  if not unit or not unit.valid or not unit.commandable then return nil end
  local ok, spawner = pcall(function() return unit.commandable.spawner end)
  if ok and spawner and spawner.valid then return spawner end
  return nil
end

local function release_or_destroy_returned_worker(unit)
  if not unit or not unit.valid then return end
  local group = safe_unit_parent_group(unit)
  local spawner = safe_unit_spawner(unit)
  if group or spawner then
    unit_ai_settings.release_as_regular_enemy(unit)
  else
    unit.destroy()
  end
end

function M.ensure_storage()
  storage.field_offices = storage.field_offices or {}
  storage.field_office_state = storage.field_office_state or {}
  storage.field_office_releasing = storage.field_office_releasing or {}
  storage.field_office_shards = storage.field_office_shards or {}
  storage.field_office_placement_renders = storage.field_office_placement_renders or {}
  storage.field_office_placement_preview_tick = storage.field_office_placement_preview_tick or {}
  storage.field_office_worker_to_office = storage.field_office_worker_to_office or {}
  storage.field_office_path_requests = storage.field_office_path_requests or {}
  storage.field_office_released_units = storage.field_office_released_units or {}
end

local function field_office_shard_for_id(office_id)
  local shards = C.FIELD_OFFICE_UPDATE_SHARDS or 1
  return office_id % shards
end

local function add_office_to_shard(office_id)
  if not office_id then return end
  storage.field_office_shards = storage.field_office_shards or {}
  local shard = field_office_shard_for_id(office_id)
  storage.field_office_shards[shard] = storage.field_office_shards[shard] or {}
  storage.field_office_shards[shard][office_id] = true
end

local function remove_office_from_shard(office_id)
  if not office_id or not storage.field_office_shards then return end
  local shard = field_office_shard_for_id(office_id)
  if storage.field_office_shards[shard] then
    storage.field_office_shards[shard][office_id] = nil
  end
end

local function rebuild_field_office_shards()
  storage.field_office_shards = {}
  for office_id, office in pairs(storage.field_offices or {}) do
    if office and office.valid then
      add_office_to_shard(office_id)
    end
  end
end

function M.track_entity(entity)
  if not entity or not entity.valid or not is_field_office(entity.name) then return end
  M.ensure_storage()
  storage.field_offices[entity.unit_number] = entity
  add_office_to_shard(entity.unit_number)
  if not storage.field_office_state[entity.unit_number] then
    storage.field_office_state[entity.unit_number] = { phase = "idle", office_id = entity.unit_number }
  else
    storage.field_office_state[entity.unit_number].office_id = entity.unit_number
  end
end

function M.untrack_entity(entity)
  if not entity or not entity.unit_number then return end
  M.ensure_storage()
  local state = storage.field_office_state[entity.unit_number]
  if state then
    release_biter(state, game.tick)
  end
  remove_office_from_shard(entity.unit_number)
  storage.field_office_state[entity.unit_number] = nil
  storage.field_offices[entity.unit_number] = nil
end

local function distance_squared(pos1, pos2)
  local dx = pos1.x - pos2.x
  local dy = pos1.y - pos2.y
  return dx * dx + dy * dy
end

-- find_entities_filtered with limit=1 is not sorted by distance (engine scans chunks
-- northwest-first), so scan candidates and keep the closest valid one.
local function find_nearest_spawner(surface, position, range)
  local spawners = surface.find_entities_filtered{
    type = SPAWNER_TYPES,
    position = position,
    radius = range,
    force = "enemy",
  }

  local nearest = nil
  local nearest_distance = nil
  for _, s in ipairs(spawners) do
    if s.valid then
      local distance = distance_squared(s.position, position)
      if not nearest_distance or distance < nearest_distance then
        nearest = s
        nearest_distance = distance
      end
    end
  end
  return nearest
end

local function add_placement_render(player_index, obj)
  if not obj then return end
  local renders = storage.field_office_placement_renders[player_index] or {}
  renders[#renders + 1] = obj.id
  storage.field_office_placement_renders[player_index] = renders
end

local function clear_placement_renders(player_index)
  local ids = storage.field_office_placement_renders[player_index]
  if ids then
    for _, id in ipairs(ids) do
      local obj = rendering.get_object_by_id(id)
      if obj then obj.destroy() end
    end
  end
  storage.field_office_placement_renders[player_index] = nil
end

local function player_holds_field_office(player)
  if not player or not player.valid then return false end
  local stack = player.cursor_stack
  return stack and stack.valid_for_read and stack.name == ENTITY_NAME
end

function M.clear_placement_preview(player_index)
  M.ensure_storage()
  clear_placement_renders(player_index)
  storage.field_office_placement_preview_tick[player_index] = nil
end

function M.update_placement_preview(player, tick, force_refresh)
  M.ensure_storage()
  if not player or not player.valid then return end
  if not player_holds_field_office(player) then
    M.clear_placement_preview(player.index)
    return
  end

  tick = tick or game.tick
  local last_tick = storage.field_office_placement_preview_tick[player.index]
  local refresh_ticks = C.FIELD_OFFICE_PLACEMENT_PREVIEW_TICKS or 30
  if not force_refresh and last_tick and (tick - last_tick) < refresh_ticks then return end
  storage.field_office_placement_preview_tick[player.index] = tick

  clear_placement_renders(player.index)

  local surface = player.surface
  add_placement_render(player.index, rendering.draw_circle{
    color = PLACEMENT_RANGE_COLOR,
    radius = C.FIELD_OFFICE_SPAWNER_RANGE,
    width = 3,
    target = player.position,
    surface = surface,
    players = {player},
    draw_on_ground = true,
  })

  local spawners = surface.find_entities_filtered{
    type = SPAWNER_TYPES,
    position = player.position,
    radius = C.FIELD_OFFICE_SPAWNER_RANGE,
    force = "enemy",
    limit = C.FIELD_OFFICE_PLACEMENT_PREVIEW_NEST_LIMIT or 32,
  }

  for _, spawner in ipairs(spawners) do
    if spawner.valid then
      add_placement_render(player.index, rendering.draw_circle{
        color = PLACEMENT_NEST_COLOR,
        radius = 2.0,
        width = 4,
        target = spawner.position,
        surface = surface,
        players = {player},
        draw_on_ground = true,
      })
    end
  end
end

function M.update_all_placement_previews(tick)
  M.ensure_storage()
  for _, player in pairs(game.connected_players or {}) do
    M.update_placement_preview(player, tick, false)
  end
end

-- Refresh the cached nearest spawner for an office, staggered across offices so
-- the work is spread over multiple ticks rather than happening all at once.
local function try_refresh_spawner_cache(state, office, office_id, tick)
  local ttl = C.FIELD_OFFICE_SPAWNER_CACHE_TTL
  if state.spawner_cache_tick and (tick - state.spawner_cache_tick) < ttl then return end
  state.cached_spawner = find_nearest_spawner(office.surface, office.position, C.FIELD_OFFICE_SPAWNER_RANGE)
  state.spawner_cache_tick = tick
end

-- Return the cached nearest spawner, falling back to an immediate search if the
-- cache is empty or stale (e.g. first call after build / after a spawner was destroyed).
local function get_nearest_spawner(state, office, tick)
  if state.cached_spawner and state.cached_spawner.valid then
    return state.cached_spawner
  end

  local spawner = find_nearest_spawner(office.surface, office.position, C.FIELD_OFFICE_SPAWNER_RANGE)
  state.cached_spawner = spawner
  state.spawner_cache_tick = tick
  return spawner
end

local function find_worker_destination(surface, worker_name, office)
  return surface.find_non_colliding_position(worker_name, office.position, C.FIELD_OFFICE_ARRIVAL_RADIUS, 0.25)
    or office.position
end

local function spawn_worker_biter(office, spawner)
  if not office or not office.valid or not spawner or not spawner.valid then return nil end

  local surface = office.surface
  local spawn_pos = surface.find_non_colliding_position("small-biter", spawner.position, 5, 0.5)
  if not spawn_pos then return nil end

  local biter = surface.create_entity{
    name = "small-biter",
    position = spawn_pos,
    force = get_biter_force(),
  }
  if not biter or not biter.valid then return nil end
  unit_ai_settings.apply_managed_unit_settings(biter)

  local destination = find_worker_destination(surface, biter.name, office)
  biter.commandable.set_command({
    type = defines.command.go_to_location,
    destination = destination,
    radius = 0.5,
    distraction = defines.distraction.none,
  })

  return biter, destination
end

local function biter_has_arrived(biter, office)
  if not biter or not biter.valid or not office or not office.valid then return false end
  local threshold = C.FIELD_OFFICE_ARRIVAL_RADIUS + 0.5
  return distance_squared(biter.position, office.position) < threshold * threshold
end

local function clear_pending_path_request(state)
  if not state or not state.path_request_id then return end
  if storage.field_office_path_requests then
    storage.field_office_path_requests[state.path_request_id] = nil
  end
  state.path_request_id = nil
end

local function request_worker_path_check(state, office, biter, destination)
  if not state or not office or not office.valid or not biter or not biter.valid then return end
  if not office.surface or not office.surface.request_path then return end

  clear_pending_path_request(state)
  destination = destination or office.position
  local request_id = office.surface.request_path{
    bounding_box = biter.prototype and biter.prototype.collision_box,
    collision_mask = biter.prototype and biter.prototype.collision_mask,
    start = biter.position,
    goal = destination,
    force = biter.force and biter.force.name or BITER_FORCE_NAME,
    radius = 0.5,
    can_open_gates = true,
    entity_to_ignore = biter,
    pathfind_flags = {
      cache = false,
      low_priority = true,
    },
  }

  if request_id then
    state.path_request_id = request_id
    storage.field_office_path_requests[request_id] = {
      office_id = state.office_id,
      biter_unit_number = biter.unit_number,
    }
  end
end

local function reset_calling_progress(state, biter, tick)
  if not state or not biter or not biter.valid then return end
  state.calling_started_tick = tick
  state.calling_last_progress_tick = tick
  state.calling_last_position = {x = biter.position.x, y = biter.position.y}
end

local function clear_calling_progress(state)
  if not state then return end
  state.calling_started_tick = nil
  state.calling_last_progress_tick = nil
  state.calling_last_position = nil
end

local function calling_worker_is_stuck(state, biter, tick)
  if not state or not biter or not biter.valid then return false end
  if not state.calling_started_tick or not state.calling_last_position then
    reset_calling_progress(state, biter, tick)
    return false
  end

  if distance_squared(biter.position, state.calling_last_position) >= CALLING_PROGRESS_DISTANCE_SQUARED then
    state.calling_last_position = {x = biter.position.x, y = biter.position.y}
    state.calling_last_progress_tick = tick
    return false
  end

  if tick - state.calling_started_tick >= CALLING_TIMEOUT_TICKS then return true end
  return tick - (state.calling_last_progress_tick or state.calling_started_tick) >= CALLING_STUCK_TICKS
end

local function create_working_overlay(biter)
  if not biter or not biter.valid then return nil end
  local render_obj = rendering.draw_text{
    text = {"gui.field-office-biter-working"},
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

local function refresh_worker_snapshot(state, biter)
  if not state or not biter or not biter.valid then return end
  state.worker_entity_name = biter.name
  state.worker_surface_index = biter.surface and biter.surface.index or nil
  state.worker_last_position = {x = biter.position.x, y = biter.position.y}
end

local function rekey_worker_state(state, old_unit_number, new_unit_number)
  if not state or not old_unit_number or not new_unit_number then return end
  if storage.field_office_worker_to_office then
    local office_id = storage.field_office_worker_to_office[old_unit_number] or state.office_id
    storage.field_office_worker_to_office[old_unit_number] = nil
    storage.field_office_worker_to_office[new_unit_number] = office_id
  end
  for _, request in pairs(storage.field_office_path_requests or {}) do
    if request and request.biter_unit_number == old_unit_number then
      request.biter_unit_number = new_unit_number
    end
  end
end

local function recreate_missing_worker(state, office, tick)
  if not state then return nil end
  local surface = game and game.surfaces and state.worker_surface_index and game.surfaces[state.worker_surface_index] or nil
  surface = surface or (office and office.valid and office.surface) or nil
  if not surface then return nil end

  local position = state.worker_last_position
    or (office and office.valid and office.position)
    or nil
  if not position then return nil end

  local entity_name = state.worker_entity_name or "small-biter"
  local spawn_pos = surface.find_non_colliding_position(entity_name, position, 2, 0.25) or position
  local biter = surface.create_entity{
    name = entity_name,
    position = spawn_pos,
    force = get_biter_force(),
    create_build_effect_smoke = false,
  }
  if not biter or not biter.valid then return nil end
  unit_ai_settings.apply_managed_unit_settings(biter)

  local old_unit_number = state.biter_unit_number
  state.biter = biter
  state.biter_unit_number = biter.unit_number
  rekey_worker_state(state, old_unit_number, biter.unit_number)
  refresh_worker_snapshot(state, biter)
  reset_calling_progress(state, biter, tick or game.tick)
  return biter
end

local function destroy_overlay(state)
  if state.overlay_id then
    local obj = rendering.get_object_by_id(state.overlay_id)
    if obj then obj.destroy() end
    state.overlay_id = nil
  end
end

release_biter = function(state, tick)
  if not state.biter or not state.biter.valid then
    if state.biter_unit_number then
      storage.field_office_worker_to_office[state.biter_unit_number] = nil
      state.biter_unit_number = nil
    end
    clear_pending_path_request(state)
    state.biter = nil
    return
  end

  storage.field_office_worker_to_office[state.biter.unit_number] = nil
  state.biter_unit_number = nil
  clear_pending_path_request(state)

  local return_destination = nil
  -- Command biter to walk back to spawner (or wander if spawner gone)
  if state.spawner and state.spawner.valid then
    return_destination = {x = state.spawner.position.x, y = state.spawner.position.y}
    state.biter.commandable.set_command({
      type = defines.command.go_to_location,
      destination = return_destination,
      radius = 3,
      distraction = defines.distraction.none,
    })
  end
  state.biter.force = get_biter_force()
  state.biter.active = true
  state.biter.destructible = false

  -- Track until the biter actually reaches home. The timeout is only used to
  -- refresh stale movement commands, not to delete a still-travelling worker.
  M.ensure_storage()
  storage.field_office_releasing[state.biter.unit_number] = {
    entity = state.biter,
    return_destination = return_destination,
    arrival_check_tick = tick + (C.RETURN_MIN_TRAVEL_TICKS or 0),
    despawn_tick = tick + C.FIELD_OFFICE_BITER_DESPAWN_TICKS,
  }

  destroy_overlay(state)
  clear_calling_progress(state)
  state.biter = nil
  state.spawner = nil
end

local function mark_worker_unreachable(state, office, tick)
  if not state then return end
  clear_pending_path_request(state)
  if state.biter and state.biter.valid then
    storage.field_office_worker_to_office[state.biter.unit_number] = nil
    state.biter.destroy()
  elseif state.biter_unit_number then
    storage.field_office_worker_to_office[state.biter_unit_number] = nil
  end
  destroy_overlay(state)
  clear_calling_progress(state)
  state.biter = nil
  state.biter_unit_number = nil
  state.spawner = nil
  state.phase = "idle"
  state.unreachable_until = (tick or game.tick) + UNREACHABLE_RETRY_TICKS
  if office and office.valid then
    office.active = false
    set_office_status(state, office, defines.entity_status_diode.red, "gui.field-office-no-workers-reachable")
  end
end

--- Check if the field office is shut down for the night (working hours).
local function is_night_shutdown(office, working_hours_enabled, night_by_surface)
  if not working_hours_enabled then return false end
  local surface_key = office.surface.index or office.surface.name
  if night_by_surface[surface_key] == nil then
    night_by_surface[surface_key] = working_hours.is_night(office.surface)
  end
  if not night_by_surface[surface_key] then return false end
  return not working_hours.entity_has_overtime_exemption(office)
end

set_office_status = function(state, office, diode, label)
  if state.status_diode == diode and state.status_label == label then return end
  office.custom_status = {
    diode = diode,
    label = {label},
  }
  state.status_diode = diode
  state.status_label = label
end

local function clear_office_status(state, office)
  if state.status_diode == nil and state.status_label == nil then return end
  office.custom_status = nil
  state.status_diode = nil
  state.status_label = nil
end

local function is_working_or_power_limited_status(status)
  local entity_status = defines.entity_status or {}
  if status == entity_status.working or status == entity_status.normal then
    return true
  end
  return entity_status.low_power ~= nil and status == entity_status.low_power
end

--- Check if the office's fluidbox has at least `amount` of `fluid_name`.
local function fluidbox_has(office, fluid_name, amount)
  local fluidbox = office.fluidbox
  if not fluidbox then return false end
  for i = 1, #fluidbox do
    local fluid = fluidbox[i]
    if fluid and fluid.name == fluid_name and fluid.amount >= amount then
      return true
    end
  end
  return false
end

--- Determine why the office can or can't craft. Returns "ready" when ready,
--- otherwise one of: "no-recipe", "no-power", "no-ingredients", "full-output".
--- Reads inventories directly: toggling `active` and reading `status` in the same
--- tick returns the stale `disabled_by_script` value because the engine only
--- recomputes status during the entity update.
local function craft_readiness(office)
  if not office or not office.valid then return "no-recipe" end
  local recipe = office.get_recipe()
  if not recipe then return "no-recipe" end

  if office.energy <= 0 then return "no-power" end

  local input_inv = office.get_inventory(defines.inventory.assembling_machine_input)
  for _, ingredient in pairs(recipe.ingredients) do
    if ingredient.type == "item" then
      if not input_inv or input_inv.get_item_count(ingredient.name) < ingredient.amount then
        return "no-ingredients"
      end
    elseif ingredient.type == "fluid" then
      if not fluidbox_has(office, ingredient.name, ingredient.amount) then
        return "no-ingredients"
      end
    end
  end

  local output_inv = office.get_inventory(defines.inventory.assembling_machine_output)
  if output_inv and output_inv.is_full() then return "full-output" end

  return "ready"
end

function M.update(tick, runtime_profile)
  M.ensure_storage()

  -- Field Office workers are only handed back when Factorio still recognizes
  -- a real enemy AI owner. Script-created orphan workers are removed on return.
  run_profiled(runtime_profile, "field_office_releasing", function()
    for biter_id, info in pairs(storage.field_office_releasing) do
      if not info.entity or not info.entity.valid then
        storage.field_office_releasing[biter_id] = nil
      elseif info.return_destination
          and tick >= (info.arrival_check_tick or 0)
          and distance_squared(info.entity.position, info.return_destination) <= (C.RETURN_ARRIVAL_DISTANCE or 2.5) ^ 2 then
        release_or_destroy_returned_worker(info.entity)
        storage.field_office_releasing[biter_id] = nil
      elseif tick >= info.despawn_tick then
        if info.return_destination then
          info.entity.force = get_biter_force()
          info.entity.active = true
          info.entity.destructible = false
          info.entity.commandable.set_command({
            type = defines.command.go_to_location,
            destination = info.return_destination,
            radius = C.RETURN_ARRIVAL_DISTANCE or 2.5,
            distraction = defines.distraction.none,
          })
          info.despawn_tick = tick + C.FIELD_OFFICE_BITER_DESPAWN_TICKS
        else
          release_or_destroy_returned_worker(info.entity)
          storage.field_office_releasing[biter_id] = nil
        end
      end
    end
  end)

  if not next(storage.field_offices) then return end
  if not next(storage.field_office_shards) then
    rebuild_field_office_shards()
  end

  local working_hours_enabled = working_hours.is_enabled()
  local night_by_surface = {}
  local update_ticks = C.FIELD_OFFICE_UPDATE_TICKS or 5
  local shards = C.FIELD_OFFICE_UPDATE_SHARDS or 1
  local shard = math.floor(tick / update_ticks) % shards
  local office_shard = storage.field_office_shards[shard]
  if not office_shard then return end

  for office_id in pairs(office_shard) do
    local office = storage.field_offices[office_id]
    if not office or not office.valid then
      local state = storage.field_office_state[office_id]
      if state then
        clear_pending_path_request(state)
        if state.biter and state.biter.valid then
          storage.field_office_worker_to_office[state.biter.unit_number] = nil
          state.biter.destroy()
        elseif state.biter_unit_number then
          storage.field_office_worker_to_office[state.biter_unit_number] = nil
        end
        destroy_overlay(state)
      end
      remove_office_from_shard(office_id)
      storage.field_office_state[office_id] = nil
      storage.field_offices[office_id] = nil
      goto continue
    end

    local state = storage.field_office_state[office_id]
    if not state then
      state = { phase = "idle", office_id = office_id }
      storage.field_office_state[office_id] = state
    else
      state.office_id = office_id
    end

    local night = run_profiled(runtime_profile, "field_office_night_check", function()
      return is_night_shutdown(office, working_hours_enabled, night_by_surface)
    end)

    if state.phase == "idle" then
      -- Don't summon biters at night
      if night then
        office.active = false
        set_office_status(state, office, defines.entity_status_diode.red, "gui.working-hours-night-status")
        goto continue
      end

      -- Only call for a biter if the building can actually craft. Surface a
      -- specific reason instead of the misleading native "disabled by script".
      local readiness = run_profiled(runtime_profile, "field_office_readiness", function()
        return craft_readiness(office)
      end)
      if readiness ~= "ready" then
        -- Leave unpowered offices active so Factorio can show the native
        -- missing-electricity alert instead of suppressing it as script-disabled.
        office.active = (readiness == "no-power")
        set_office_status(state, office, defines.entity_status_diode.red, "gui.field-office-" .. readiness)
        goto continue
      end

      office.active = false

      if state.unreachable_until and tick < state.unreachable_until then
        set_office_status(state, office, defines.entity_status_diode.red, "gui.field-office-no-workers-reachable")
        goto continue
      end
      state.unreachable_until = nil

      -- Refresh only when the office is otherwise able to summon. This avoids
      -- expensive nest searches for idle/no-recipe/no-ingredient buildings.
      run_profiled(runtime_profile, "field_office_spawner_cache", function()
        try_refresh_spawner_cache(state, office, office_id, tick)
      end)

      -- Summon a biter using the cached nearest spawner.
      local spawner = run_profiled(runtime_profile, "field_office_spawner_lookup", function()
        return get_nearest_spawner(state, office, tick)
      end)
      if spawner then
        local destination = nil
        local biter = run_profiled(runtime_profile, "field_office_spawn_worker", function()
          local spawned_biter, spawned_destination = spawn_worker_biter(office, spawner)
          destination = spawned_destination
          return spawned_biter
        end)
        if biter then
          state.phase = "calling"
          state.biter = biter
          state.biter_unit_number = biter.unit_number
          state.spawner = spawner
          refresh_worker_snapshot(state, biter)
          reset_calling_progress(state, biter, tick)
          storage.field_office_worker_to_office[biter.unit_number] = office_id
          request_worker_path_check(state, office, biter, destination)
          set_office_status(state, office, defines.entity_status_diode.yellow, "gui.field-office-calling")
        else
          mark_worker_unreachable(state, office, tick)
        end
      else
        set_office_status(state, office, defines.entity_status_diode.red, "gui.field-office-no-nest")
      end

    elseif state.phase == "calling" then
      local phase_profiler = runtime_profile and game.create_profiler() or nil

      -- Building is inactive while biter is travelling
      office.active = false

      -- If night falls while biter is en route, release it
      if night then
        if state.biter and state.biter.valid then
          release_biter(state, tick)
        else
          state.biter = nil
        end
        state.phase = "idle"
        clear_calling_progress(state)
        set_office_status(state, office, defines.entity_status_diode.red, "gui.working-hours-night-status")
        record_runtime_profile(runtime_profile, "field_office_calling", phase_profiler)
        goto continue
      end

      -- Check if biter is still alive
      if not state.biter or not state.biter.valid then
        local biter = recreate_missing_worker(state, office, tick)
        if biter and biter.valid then
          local destination = find_worker_destination(office.surface, biter.name, office)
          biter.commandable.set_command({
            type = defines.command.go_to_location,
            destination = destination,
            radius = 0.5,
            distraction = defines.distraction.none,
          })
          request_worker_path_check(state, office, biter, destination)
          set_office_status(state, office, defines.entity_status_diode.yellow, "gui.field-office-calling")
          record_runtime_profile(runtime_profile, "field_office_calling", phase_profiler)
          goto continue
        end
        if state.biter_unit_number then
          storage.field_office_worker_to_office[state.biter_unit_number] = nil
          state.biter_unit_number = nil
        end
        state.biter = nil
        state.phase = "idle"
        clear_calling_progress(state)
        record_runtime_profile(runtime_profile, "field_office_calling", phase_profiler)
        goto continue
      end
      refresh_worker_snapshot(state, state.biter)

      if calling_worker_is_stuck(state, state.biter, tick) then
        mark_worker_unreachable(state, office, tick)
        record_runtime_profile(runtime_profile, "field_office_calling", phase_profiler)
        goto continue
      end

      -- Check if biter has arrived
      if biter_has_arrived(state.biter, office) then
        storage.field_office_worker_to_office[state.biter.unit_number] = nil
        state.biter_unit_number = nil

        -- Stop biter movement
        state.biter.commandable.set_command({
          type = defines.command.stop,
          distraction = defines.distraction.none,
        })

        -- Show working overlay
        state.overlay_id = create_working_overlay(state.biter)

        -- Activate the building
        office.active = true
        state.products_at_arrival = office.products_finished
        state.phase = "working"
        clear_calling_progress(state)

        set_office_status(state, office, defines.entity_status_diode.green, "gui.field-office-working")
      else
        set_office_status(state, office, defines.entity_status_diode.yellow, "gui.field-office-calling")
      end

      record_runtime_profile(runtime_profile, "field_office_calling", phase_profiler)

    elseif state.phase == "working" then
      local phase_profiler = runtime_profile and game.create_profiler() or nil

      -- Check if biter died while working
      if not state.biter or not state.biter.valid then
        local biter = recreate_missing_worker(state, office, tick)
        if biter and biter.valid then
          destroy_overlay(state)
          biter.commandable.set_command({
            type = defines.command.stop,
            distraction = defines.distraction.none,
          })
          state.overlay_id = create_working_overlay(biter)
          office.active = true
        else
          destroy_overlay(state)
          if state.biter_unit_number then
            storage.field_office_worker_to_office[state.biter_unit_number] = nil
            state.biter_unit_number = nil
          end
          state.biter = nil
          state.phase = "idle"
          office.active = false
          set_office_status(state, office, defines.entity_status_diode.red, "gui.field-office-no-nest")
          record_runtime_profile(runtime_profile, "field_office_working", phase_profiler)
          goto continue
        end
      end
      refresh_worker_snapshot(state, state.biter)

      -- If night falls, release biter and shut down
      if night then
        release_biter(state, tick)
        state.phase = "idle"
        office.active = false
        set_office_status(state, office, defines.entity_status_diode.red, "gui.working-hours-night-status")
        record_runtime_profile(runtime_profile, "field_office_working", phase_profiler)
        goto continue
      end

      -- Release if the machine has nothing left to do (office is already active, check status directly)
      local status = office.status
      if not office.get_recipe()
         or not is_working_or_power_limited_status(status) then
        release_biter(state, tick)
        state.phase = "idle"
        office.active = false
        clear_office_status(state, office)
        record_runtime_profile(runtime_profile, "field_office_working", phase_profiler)
        goto continue
      end

      -- Check if the biter has completed its shift.
      if office.products_finished >= (state.products_at_arrival or 0) + CRAFTS_PER_BITER then
        -- Release the biter
        release_biter(state, tick)
        state.phase = "idle"
        office.active = false
        clear_office_status(state, office)
      end

      record_runtime_profile(runtime_profile, "field_office_working", phase_profiler)
    end

    ::continue::
  end
end

function M.on_ai_command_completed(event)
  M.ensure_storage()
  local unit_number = event and event.unit_number
  local office_id = unit_number and storage.field_office_worker_to_office[unit_number]
  if not office_id then return false end

  local state = storage.field_office_state and storage.field_office_state[office_id]
  if not state or state.phase ~= "calling" then return true end
  if defines.behavior_result and event.result ~= defines.behavior_result.fail then return true end

  local office = storage.field_offices and storage.field_offices[office_id]
  mark_worker_unreachable(state, office, event.tick or game.tick)
  return true
end

function M.on_script_path_request_finished(event)
  M.ensure_storage()
  local request = event and event.id and storage.field_office_path_requests[event.id]
  if not request then return false end
  storage.field_office_path_requests[event.id] = nil

  local office_id = request.office_id
  local state = storage.field_office_state and storage.field_office_state[office_id]
  if not state or state.path_request_id ~= event.id then return true end
  state.path_request_id = nil
  if state.phase ~= "calling" then return true end

  if event.try_again_later then
    local office = storage.field_offices and storage.field_offices[office_id]
    if office and office.valid and state.biter and state.biter.valid then
      request_worker_path_check(state, office, state.biter)
    end
    return true
  end

  if not event.path or #event.path == 0 then
    local office = storage.field_offices and storage.field_offices[office_id]
    mark_worker_unreachable(state, office, event.tick or game.tick)
  end
  return true
end

function M.rebuild_registry()
  M.ensure_storage()

  -- Destroy existing worker biters and overlays before rebuild
  for office_id, state in pairs(storage.field_office_state) do
    clear_pending_path_request(state)
    if state.biter and state.biter.valid then state.biter.destroy() end
    destroy_overlay(state)
  end
  for _, info in pairs(storage.field_office_releasing) do
    if info.entity and info.entity.valid then info.entity.destroy() end
  end

  storage.field_offices = {}
  storage.field_office_state = {}
  storage.field_office_releasing = {}
  storage.field_office_shards = {}
  storage.field_office_worker_to_office = {}
  storage.field_office_path_requests = {}
  storage.field_office_released_units = storage.field_office_released_units or {}

  for _, surface in pairs(game.surfaces) do
    for _, entity in ipairs(surface.find_entities_filtered{name = ENTITY_NAME}) do
      if entity.valid and entity.unit_number then
        storage.field_offices[entity.unit_number] = entity
        storage.field_office_state[entity.unit_number] = { phase = "idle", office_id = entity.unit_number }
        add_office_to_shard(entity.unit_number)
      end
    end
  end
end

M.is_field_office = is_field_office

return M
