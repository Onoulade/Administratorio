local M = {}

function M.new(deps)
  local C = deps.constants
  local zones = deps.zones
  local working_hours = deps.working_hours
  local render = deps.render

  local controller = {
    last_eviction_tick = 0,
  }

  local protest_target_cache = nil  -- {tick=, surface_index=, targets={}, spatial_buckets={}}
  local protest_path_outstanding_cache_tick = nil
  local protest_path_outstanding_cache_count = 0
  local protest_target_type_set = {}
  local protest_target_name_set = {}
  local protest_obstacle_building_type_set = {}
  for _, target_type in ipairs(deps.protest_target_types or {}) do
    protest_target_type_set[target_type] = true
  end
  for _, target_name in ipairs(deps.protest_target_names or {}) do
    protest_target_name_set[target_name] = true
  end
  for _, building_type in ipairs(deps.protest_obstacle_building_types or {}) do
    protest_obstacle_building_type_set[building_type] = true
  end
  local protest_target_membership_configured = next(protest_target_type_set) ~= nil
    or next(protest_target_name_set) ~= nil
  local HARD_MODE_LOG_PREFIX = "[administratorio-hard-mode]"
  local HARD_MODE_LOG_TICKS = deps.hard_mode_debug_log_ticks or deps.protest_debug_status_ticks or (10 * 60)
  local WORKER_PROTEST_LOG_PREFIX = "[administratorio-worker-protest]"

  local function hard_mode_enabled()
    if C.hard_mode_enabled then return C.hard_mode_enabled() end
    return C.HARD_MODE_ENABLED == true
  end

  local function get_frustration_capacity()
    if C.get_frustration_capacity then return C.get_frustration_capacity() end
    if hard_mode_enabled() then
      return C.HARD_MODE_FRUSTRATION_CAPACITY
        or math.floor(C.PROTEST_THRESHOLD / (C.HARD_MODE_PROTEST_RATIO or 0.70))
    end
    return C.PROTEST_THRESHOLD
  end

  local function get_protest_threshold()
    if C.get_protest_threshold then return C.get_protest_threshold() end
    return C.PROTEST_THRESHOLD
  end

  local function get_attack_threshold()
    if C.get_attack_threshold then return C.get_attack_threshold() end
    if hard_mode_enabled() then return get_frustration_capacity() end
    return nil
  end

  local function hard_mode_pct(value)
    local capacity = get_frustration_capacity()
    if capacity <= 0 then return 0 end
    return math.floor(((value or 0) / capacity) * 100)
  end

  local function hard_mode_bool(value)
    return value and "true" or "false"
  end

  local function hard_mode_event_name(event)
    if not event then return "nil" end
    return event.name or event.event_name or "nil"
  end

  local function hard_mode_force_name(force)
    if not force then return "nil" end
    return force.name or tostring(force)
  end

  local function hard_mode_entity_summary(entity)
    if not entity then return "nil" end
    local ok_valid, valid = pcall(function() return entity.valid end)
    if not ok_valid or not valid then return "invalid" end
    local ok_name, name = pcall(function() return entity.name end)
    local ok_force, force = pcall(function() return entity.force end)
    local ok_active, active = pcall(function() return entity.active end)
    local ok_destructible, destructible = pcall(function() return entity.destructible end)
    local ok_health, health = pcall(function() return entity.health end)
    local ok_command, command = pcall(function()
      return entity.commandable and entity.commandable.command or nil
    end)
    local command_type = ok_command and command and command.type or "nil"
    local ok_group, group = pcall(function()
      return entity.commandable and entity.commandable.parent_group or nil
    end)
    local group_id = ok_group and group and group.valid and (group.unique_id or "valid") or "nil"
    local ok_spawner, spawner = pcall(function()
      return entity.commandable and entity.commandable.spawner or nil
    end)
    local spawner_id = ok_spawner and spawner and spawner.valid and (spawner.unit_number or spawner.name) or "nil"
    return "name=" .. tostring(ok_name and name or "nil")
      .. " force=" .. hard_mode_force_name(ok_force and force or nil)
      .. " active=" .. tostring(ok_active and hard_mode_bool(active) or "n/a")
      .. " destructible=" .. tostring(ok_destructible and hard_mode_bool(destructible) or "n/a")
      .. " health=" .. tostring(ok_health and health or "n/a")
      .. " command=" .. tostring(command_type)
      .. " group=" .. tostring(group_id)
      .. " spawner=" .. tostring(spawner_id)
  end

  local function hard_mode_target_summary(target)
    if not target then return "nil" end
    local ok_valid, valid = pcall(function() return target.valid end)
    if not ok_valid or not valid then return "invalid" end
    local ok_name, name = pcall(function() return target.name end)
    local ok_id, unit_number = pcall(function() return target.unit_number end)
    local ok_force, force = pcall(function() return target.force end)
    local ok_active, active = pcall(function() return target.active end)
    local ok_destructible, destructible = pcall(function() return target.destructible end)
    local ok_health, health = pcall(function() return target.health end)
    local ok_position, position = pcall(function() return target.position end)
    return "name=" .. tostring(ok_name and name or "nil")
      .. " id=" .. tostring(ok_id and unit_number or name or "nil")
      .. " force=" .. hard_mode_force_name(ok_force and force or nil)
      .. " active=" .. tostring(ok_active and hard_mode_bool(active) or "n/a")
      .. " destructible=" .. tostring(ok_destructible and hard_mode_bool(destructible) or "n/a")
      .. " health=" .. tostring(ok_health and health or "n/a")
      .. " pos=" .. tostring(ok_position and position and deps.format_position(position) or "[nil]")
  end

  local function hard_mode_log(info, entity, label, extra, opts)
    if deps.hard_mode_debug_logging ~= true or not hard_mode_enabled() or not log then return end
    opts = opts or {}
    if not opts.force and info then
      info.hard_mode_debug_next_log_tick = info.hard_mode_debug_next_log_tick or {}
      local key = label or "status"
      local next_tick = info.hard_mode_debug_next_log_tick[key] or 0
      if game.tick < next_tick then return end
      info.hard_mode_debug_next_log_tick[key] = game.tick + HARD_MODE_LOG_TICKS
    end

    local unit_number = (entity and entity.valid and entity.unit_number)
      or (info and info.tracked_unit_number)
      or "nil"
    local state = (info and info.state) or "nil"
    local frustration = info and info.frustration or nil
    local target = info and info.target_building or nil
    local target_id = target and target.valid and (target.unit_number or target.name) or "nil"
    local target_valid = target and target.valid or false
    local active = entity and entity.valid and entity.active or false
    local entity_valid = entity and entity.valid or false
    local surface_index = entity and entity.valid and entity.surface and entity.surface.index or "nil"
    local position = entity and entity.valid and entity.position and deps.format_position(entity.position) or "[nil]"

    local parts = {
      HARD_MODE_LOG_PREFIX,
      "tick=" .. tostring(game.tick),
      "label=" .. tostring(label),
      "unit=" .. tostring(unit_number),
      "state=" .. tostring(state),
      "frustration=" .. tostring(frustration),
      "capacity=" .. tostring(get_frustration_capacity()),
      "pct=" .. tostring(hard_mode_pct(frustration)),
      "last_tick=" .. tostring(info and info.last_frustration_tick or nil),
      "accum=" .. tostring(info and info.frust_accum or nil),
      "entity_valid=" .. hard_mode_bool(entity_valid),
      "active=" .. hard_mode_bool(active),
      "parked=" .. hard_mode_bool(info and info.protest_parked),
      "arrived=" .. hard_mode_bool(info and info.arrived_at_building),
      "target_valid=" .. hard_mode_bool(target_valid),
      "target=" .. tostring(target_id),
      "surface=" .. tostring(surface_index),
      "pos=" .. position,
      "force=" .. hard_mode_force_name(entity and entity.valid and entity.force or nil),
      "target_info=" .. hard_mode_target_summary(target),
      "entity_info=" .. hard_mode_entity_summary(entity),
    }
    if extra then parts[#parts + 1] = tostring(extra) end
    log(table.concat(parts, " "))
  end

  local function debug_pos(pos)
    if not pos then return "[nil]" end
    if deps.format_position then return deps.format_position(pos) end
    return "[" .. tostring(pos.x) .. "," .. tostring(pos.y) .. "]"
  end

  local function debug_force_name(force)
    if not force then return "nil" end
    return force.name or tostring(force)
  end

  local function debug_bool(value)
    return value and "true" or "false"
  end

  local function debug_entity_summary(entity)
    if not entity then return "entity=nil" end
    local ok_valid, valid = pcall(function() return entity.valid end)
    if not ok_valid or not valid then return "entity=invalid" end
    local ok_name, name = pcall(function() return entity.name end)
    local ok_unit, unit_number = pcall(function() return entity.unit_number end)
    local ok_force, force = pcall(function() return entity.force end)
    local ok_active, active = pcall(function() return entity.active end)
    local ok_destructible, destructible = pcall(function() return entity.destructible end)
    local ok_position, position = pcall(function() return entity.position end)
    local ok_has_command, has_command = pcall(function()
      return entity.commandable and entity.commandable.has_command or false
    end)
    local ok_command, command = pcall(function()
      return entity.commandable and entity.commandable.command or nil
    end)
    local ok_group, group = pcall(function()
      return entity.commandable and entity.commandable.parent_group or nil
    end)
    local ok_spawner, spawner = pcall(function()
      return entity.commandable and entity.commandable.spawner or nil
    end)
    return "entity_unit=" .. tostring(ok_unit and unit_number or "nil")
      .. " entity_name=" .. tostring(ok_name and name or "nil")
      .. " entity_force=" .. debug_force_name(ok_force and force or nil)
      .. " entity_active=" .. tostring(ok_active and debug_bool(active) or "n/a")
      .. " entity_destructible=" .. tostring(ok_destructible and debug_bool(destructible) or "n/a")
      .. " entity_pos=" .. tostring(ok_position and debug_pos(position) or "[nil]")
      .. " entity_has_command=" .. tostring(ok_has_command and debug_bool(has_command) or "n/a")
      .. " entity_command=" .. tostring(ok_command and command and command.type or "nil")
      .. " entity_group=" .. tostring(ok_group and group and group.valid and (group.unique_id or "valid") or "nil")
      .. " entity_spawner=" .. tostring(ok_spawner and spawner and spawner.valid and (spawner.unit_number or spawner.name) or "nil")
  end

  local function debug_target_summary(target)
    if not target then return "target=nil" end
    local ok_valid, valid = pcall(function() return target.valid end)
    if not ok_valid or not valid then return "target=invalid" end
    local ok_name, name = pcall(function() return target.name end)
    local ok_unit, unit_number = pcall(function() return target.unit_number end)
    local ok_force, force = pcall(function() return target.force end)
    local ok_active, active = pcall(function() return target.active end)
    local ok_position, position = pcall(function() return target.position end)
    return "target_unit=" .. tostring(ok_unit and unit_number or "nil")
      .. " target_name=" .. tostring(ok_name and name or "nil")
      .. " target_force=" .. debug_force_name(ok_force and force or nil)
      .. " target_active=" .. tostring(ok_active and debug_bool(active) or "n/a")
      .. " target_pos=" .. tostring(ok_position and debug_pos(position) or "[nil]")
  end

  local function protest_debug_log(label, info, entity, extra)
    if deps.worker_protest_debug_logging ~= true or not log then return end
    local parts = {
      WORKER_PROTEST_LOG_PREFIX,
      "tick=" .. tostring(game and game.tick or "nil"),
      "label=" .. tostring(label),
      "state=" .. tostring(info and info.state or "nil"),
      "tracked=" .. tostring(info and info.tracked_unit_number or "nil"),
      "pending_path=" .. tostring(info and info.pending_path_request_id or "nil"),
      "pending_candidates=" .. tostring(info and info.pending_protest_candidates and #info.pending_protest_candidates or 0),
      "retry_tick=" .. tostring(info and info.next_protest_target_retry_tick or "nil"),
      "wander_tick=" .. tostring(info and info.next_protest_wander_tick or "nil"),
      "arrived=" .. tostring(info and debug_bool(info.arrived_at_building) or "nil"),
      "anchor=" .. tostring(info and debug_pos(info.protest_anchor_position) or "[nil]"),
      debug_entity_summary(entity),
      debug_target_summary(info and info.target_building or nil),
    }
    if extra then parts[#parts + 1] = tostring(extra) end
    log(table.concat(parts, " "))
  end

  local function is_eligible_protest_target(target)
    if not target or not target.valid then return false end
    if not target.force or target.force.name ~= "player" then return false end
    if deps.protest_protected_names[target.name] then return false end
    return true
  end

  local function build_protest_target_cache(surface, tick, targets)
    local cell_size = math.max(1, C.PROTEST_TARGET_SPATIAL_CELL_SIZE
      or C.PROTEST_TARGET_SEARCH_RADIUS_HIGH_LOAD
      or 96)
    local cache = {
      tick = tick,
      surface_index = surface.index,
      targets = targets,
      spatial_cell_size = cell_size,
      spatial_buckets = {},
    }
    for _, target in ipairs(targets) do
      local cell_x = math.floor(target.position.x / cell_size)
      local cell_y = math.floor(target.position.y / cell_size)
      local key = cell_x .. ":" .. cell_y
      local bucket = cache.spatial_buckets[key]
      if not bucket then
        bucket = {}
        cache.spatial_buckets[key] = bucket
      end
      bucket[#bucket + 1] = target
      cache.min_cell_x = math.min(cache.min_cell_x or cell_x, cell_x)
      cache.max_cell_x = math.max(cache.max_cell_x or cell_x, cell_x)
      cache.min_cell_y = math.min(cache.min_cell_y or cell_y, cell_y)
      cache.max_cell_y = math.max(cache.max_cell_y or cell_y, cell_y)
    end
    protest_target_cache = cache
    return cache
  end

  local function get_cached_protest_targets(surface)
    local tick = game.tick
    if protest_target_cache
       and tick - protest_target_cache.tick < (C.PROTEST_TARGET_CACHE_TICKS or 60)
       and protest_target_cache.surface_index == surface.index then
      return protest_target_cache.targets
    end

    local targets = {}
    local seen = {}

    local function add_if_valid(target)
      if not is_eligible_protest_target(target) then return end
      local key = target.unit_number
      if key and seen[key] then return end

      if key then seen[key] = true end
      targets[#targets + 1] = target
    end

    for _, target in ipairs(surface.find_entities_filtered{
      force = "player",
      type = deps.protest_target_types,
    }) do
      add_if_valid(target)
    end

    for _, target in ipairs(surface.find_entities_filtered{
      force = "player",
      name = deps.protest_target_names,
    }) do
      add_if_valid(target)
    end

    build_protest_target_cache(surface, tick, targets)
    return targets
  end

  -- High-load protesters normally use a small local query, but a wall can be
  -- much farther from the first eligible factory building than that radius.
  -- A cached coarse index lets those protesters find the nearest unclaimed
  -- target without re-scanning every building for every biter.
  local function get_spatial_protest_targets(surface, position, snapshot)
    get_cached_protest_targets(surface)
    local cache = protest_target_cache
    if not cache or not cache.min_cell_x then return {} end

    local cell_size = cache.spatial_cell_size
    local origin_x = math.floor(position.x / cell_size)
    local origin_y = math.floor(position.y / cell_size)
    local max_ring = math.max(
      math.abs(origin_x - cache.min_cell_x),
      math.abs(origin_x - cache.max_cell_x),
      math.abs(origin_y - cache.min_cell_y),
      math.abs(origin_y - cache.max_cell_y)
    )
    local limit = math.max(1, C.PROTEST_TARGET_PREFILTER_LIMIT or 64)
    local result = {}
    local overflow = {}
    local overflow_claimed = math.huge
    local seen_cells = {}

    local function append_bucket(cell_x, cell_y)
      local key = cell_x .. ":" .. cell_y
      if seen_cells[key] then return end
      seen_cells[key] = true
      local bucket = cache.spatial_buckets[key]
      if not bucket then return end
      for _, target in ipairs(bucket) do
        local target_id = target and target.valid and target.unit_number or nil
        local claimed = target_id and snapshot.claimed_counts[target_id] or 0
        if is_eligible_protest_target(target)
           and claimed < C.PROTEST_TARGET_MAX_PROTESTERS then
          result[#result + 1] = target
          if #result >= limit then return true end
        elseif is_eligible_protest_target(target) then
          if claimed < overflow_claimed then
            overflow_claimed = claimed
            overflow = {target}
          elseif claimed == overflow_claimed and #overflow < limit then
            overflow[#overflow + 1] = target
          end
        end
      end
      return false
    end

    for ring = 0, max_ring do
      if ring == 0 then
        if append_bucket(origin_x, origin_y) then break end
      else
        for cell_x = origin_x - ring, origin_x + ring do
          if append_bucket(cell_x, origin_y - ring) then return result end
          if append_bucket(cell_x, origin_y + ring) then return result end
        end
        for cell_y = origin_y - ring + 1, origin_y + ring - 1 do
          if append_bucket(origin_x - ring, cell_y) then return result end
          if append_bucket(origin_x + ring, cell_y) then return result end
        end
      end
      -- One occupied ring already contains the nearest coarse candidates.
      -- Keep expanding only when every target in it is currently claimed.
      if #result > 0 then break end
    end
    return #result > 0 and result or overflow
  end

  local function append_state_unit_numbers(state, ids, seen, shard_index, shard_count)
    for unit_number in pairs(deps.get_waiting_biter_state_set(state) or {}) do
      if (not shard_count or (unit_number % shard_count) == shard_index) and not seen[unit_number] then
        ids[#ids + 1] = unit_number
        seen[unit_number] = true
      end
    end
  end

  local function clear_pending_protest_reservation(info)
    if not info then return end
    info.pending_protest_reserved_target = nil
    info.pending_protest_reserved_position = nil
  end

  local function count_outstanding_protest_path_requests()
    if protest_path_outstanding_cache_tick == game.tick then
      return protest_path_outstanding_cache_count
    end

    local count = 0
    local timeout_ticks = C.PROTEST_PATH_REQUEST_TIMEOUT_TICKS or (10 * 60)
    for request_id, request in pairs(storage.path_requests or {}) do
      if request.kind == "protest_target" and not request.abandoned then
        local info = storage.waiting_biters and storage.waiting_biters[request.unit_number]
        local requested_tick = request.requested_tick
        local is_orphaned = not info
          or info.state ~= "protesting"
          or info.pending_path_request_id ~= request_id
        local is_stale = not requested_tick
          or game.tick - requested_tick >= timeout_ticks
        if is_orphaned or is_stale then
          request.abandoned = true
          request.abandoned_tick = game.tick
        else
          count = count + 1
        end
      end
    end
    protest_path_outstanding_cache_tick = game.tick
    protest_path_outstanding_cache_count = count
    return count
  end

  local function adjust_outstanding_protest_path_requests(delta)
    if protest_path_outstanding_cache_tick == game.tick then
      protest_path_outstanding_cache_count = math.max(0, protest_path_outstanding_cache_count + delta)
    end
  end

  local function clear_pending_path_request(info)
    if not info then return end
    if info.pending_path_request_id and storage.path_requests then
      -- Factorio does not expose cancellation for script path requests. Keep
      -- abandoned requests tracked until their callback arrives so that late
      -- callbacks are ignored safely; only requests still owned by a live
      -- protester count toward the admission ceiling.
      local request = storage.path_requests[info.pending_path_request_id]
      if request and not request.abandoned then
        request.abandoned = true
        request.abandoned_tick = game.tick
        adjust_outstanding_protest_path_requests(-1)
      end
    end
    info.pending_path_request_id = nil
    clear_pending_protest_reservation(info)
  end

  local function clear_pending_protest_candidates(info)
    if not info then return end
    clear_pending_path_request(info)
    info.pending_protest_candidates = nil
    info.next_protest_target_retry_tick = nil
  end

  local count_protesters_on_target
  local clear_protest_obstacle_attack_runtime
  local clear_desk_route_breach_runtime
  local assign_protest_target

  local function protect_protesting_biter(info, entity, reason, opts)
    if not info or info.state ~= "protesting" or not entity or not entity.valid then return false end

    opts = opts or {}
    entity.force = deps.get_biter_force()
    entity.active = opts.active == false and false or true
    entity.destructible = false

    local commandable = entity.commandable
    local spawner = commandable and commandable.spawner or nil
    if spawner and spawner.valid and commandable.release_from_spawner then
      if deps.reserve_home_spawner_unit then
        deps.reserve_home_spawner_unit(info, entity, spawner)
      else
        deps.remember_home_spawner(info, spawner)
      end
      commandable.release_from_spawner()
    end

    return true
  end

  local function disable_protest_target(target, protester_id)
    if not target or not target.valid then return end
    -- Keep the working-hours claim for coordinated release, but do not let its
    -- bookkeeping stand in for the actual shutdown.  In particular, transport
    -- belts need their active flag asserted again while a protest is ongoing:
    -- other updates can reactivate a target between protest pacing passes.
    local working_hours_claimed = working_hours.claim_protest_target(target, protester_id)
    if not working_hours_claimed and target.unit_number then
      storage.protest_target_active_states = storage.protest_target_active_states or {}
      if storage.protest_target_active_states[target.unit_number] == nil then
        storage.protest_target_active_states[target.unit_number] = target.active == true
      end
    end
    target.active = false
  end

  local function release_protest_target(target, protester_id)
    if not target or not target.valid then return end
    if working_hours.release_protest_target(target, protester_id) then
      return
    end
    if count_protesters_on_target(target, protester_id) == 0 then
      local active_states = storage.protest_target_active_states
      local initial_active = active_states and target.unit_number and active_states[target.unit_number]
      if active_states and target.unit_number then
        active_states[target.unit_number] = nil
      end
      -- Existing saves may already contain an active protest without a stored
      -- initial state.  Keep the legacy re-enable behavior for those saves;
      -- new protests always restore the state that they interrupted.
      target.active = initial_active == nil and true or initial_active
    end
  end

  local function reset_protest_targeting(info, exclude_unit_number, opts)
    if not info then return end
    opts = opts or {}
    local preserve_protest_identity = opts.preserve_protest_identity == true
    local target = info.target_building
    if target and target.valid and info.arrived_at_building then
      release_protest_target(target, exclude_unit_number)
    end
    if not preserve_protest_identity then
      render.destroy_protest_rendering(info)
    end
    render.destroy_protest_chart_tag(info)
    clear_pending_protest_candidates(info)
    info.arrived_at_building = nil
    info.target_building = nil
    info.next_protest_wander_tick = nil
    info.protest_anchor_position = nil
    info.protest_last_command_tick = nil
    info.protest_arrival_tick = nil
    info.protest_step_deadline_tick = nil
    info.protest_parked = nil
    info.protest_path_retry_deferred = nil
    info.protest_route_started_tick = nil
    info.protest_route_last_progress_tick = nil
    info.protest_route_best_distance_sq = nil
    info.protest_route_goal_target_unit_number = nil
    info.protest_route_hop_waypoint = nil
    info.protest_route_hop_goal = nil
    info.protest_route_hop_target = nil
    info.protest_route_retry_tick = nil
    info.protest_route_retry_goal = nil
    info.protest_route_retry_target = nil
    info.protest_clear_route_retry_allowed = nil
    info.protest_pipe_gap_waypoint = nil
    info.protest_pipe_gap_goal = nil
    info.protest_pipe_gap_goal_target = nil
    info.protest_pipe_gap_started_tick = nil
    info.protest_pipe_gap_failed_until_tick = nil
    info.protest_pipe_gap_next_check_tick = nil
    info.protest_pipe_gap_route_active = nil
    if clear_protest_obstacle_attack_runtime then
      clear_protest_obstacle_attack_runtime(info, info.entity)
    end
    if clear_desk_route_breach_runtime then
      clear_desk_route_breach_runtime(info, info.entity)
    end
    if preserve_protest_identity then
      render.ensure_protest_rendering(info)
    else
      info.protest_primary_ticket = nil
      info.protest_message = nil
      info.protest_alerted_players = nil
    end
  end

  function controller.reset_protest_targeting(info, exclude_unit_number)
    reset_protest_targeting(info, exclude_unit_number)
  end

  local clear_pacified_runtime
  local clear_hard_mode_attack_runtime

  local function find_nearest_attack_target(surface, position)
    if not surface or not position then return nil end
    local best = nil
    local best_dist = math.huge
    for _, target in ipairs(get_cached_protest_targets(surface)) do
      if target and target.valid then
        local dx = target.position.x - position.x
        local dy = target.position.y - position.y
        local dist = dx * dx + dy * dy
        if dist < best_dist then
          best = target
          best_dist = dist
        end
      end
    end
    return best
  end

  local function issue_hard_mode_attack_command(info, entity, target, reason, opts)
    if not entity or not entity.valid or not target or not target.valid then return false end
    if not entity.commandable or not entity.commandable.set_command then return false end
    opts = opts or {}

    local command_type = defines.command.attack or defines.command.go_to_location
    local command
    if command_type == defines.command.attack then
      command = {
        type = command_type,
        target = target,
        distraction = defines.distraction.none,
      }
    else
      command = {
        type = command_type,
        destination = target.position,
        radius = C.HARD_MODE_ATTACK_RADIUS or 1.5,
        distraction = defines.distraction.none,
      }
    end
    entity.commandable.set_command(command)
    info.hard_mode_attack_target_unit_number = target.unit_number
    info.hard_mode_attack_last_command_tick = game.tick
    local interval = opts.in_range and (C.HARD_MODE_ATTACK_ANIMATION_TICKS or C.HARD_MODE_ATTACK_DAMAGE_TICKS or 30)
      or (C.HARD_MODE_ATTACK_REISSUE_TICKS or (5 * 60))
    info.hard_mode_attack_next_command_tick = game.tick + interval
    hard_mode_log(
      info,
      entity,
      "attack-command",
      "reason=" .. tostring(reason)
        .. " command_type=" .. tostring(command.type)
        .. " interval=" .. tostring(interval)
        .. " in_range=" .. hard_mode_bool(opts.in_range)
        .. " command_target=" .. hard_mode_target_summary(target),
      {force = true}
    )
    return true
  end

  local function clear_hard_mode_attack_runtime_impl(info)
    if not info then return end
    info.hard_mode_attacking = nil
    info.hard_mode_attack_reason = nil
    info.hard_mode_attack_tick = nil
    info.hard_mode_attack_target_unit_number = nil
    info.hard_mode_attack_last_command_tick = nil
    info.hard_mode_attack_next_command_tick = nil
    info.hard_mode_attack_next_damage_tick = nil
  end
  clear_hard_mode_attack_runtime = clear_hard_mode_attack_runtime_impl

  local function prepare_hard_mode_attack_entity(entity)
    if not entity or not entity.valid then return false end
    hard_mode_log(nil, entity, "attack-prepare-before", hard_mode_entity_summary(entity), {force = true})
    if deps.apply_managed_unit_settings then
      deps.apply_managed_unit_settings(entity)
    end
    local attack_force = deps.get_hard_mode_attack_force and deps.get_hard_mode_attack_force() or deps.get_biter_force()
    entity.force = attack_force
    entity.active = true
    entity.destructible = true
    hard_mode_log(nil, entity, "attack-prepare-after", hard_mode_entity_summary(entity), {force = true})
    return true
  end

  local function is_hard_mode_attack_in_range(entity, target)
    if not entity or not entity.valid or not target or not target.valid then return false end
    local radius = C.HARD_MODE_ATTACK_RADIUS or 1.5
    local dx = entity.position.x - target.position.x
    local dy = entity.position.y - target.position.y
    return dx * dx + dy * dy <= radius * radius
  end

  local function damage_hard_mode_attack_target(info, entity, target, reason)
    if not is_hard_mode_attack_in_range(entity, target) then return false end
    if game.tick < (info.hard_mode_attack_next_damage_tick or 0) then return true end

    local damage = C.HARD_MODE_ATTACK_DAMAGE or 10
    local damage_force = entity.force or (game and game.forces and game.forces.enemy)
    local did_damage = false
    if target.damage then
      local ok = pcall(function()
        target.damage(damage, damage_force, "physical")
      end)
      did_damage = ok
    elseif target.health then
      target.health = math.max(0, target.health - damage)
      did_damage = true
    end

    info.hard_mode_attack_next_damage_tick = game.tick + (C.HARD_MODE_ATTACK_DAMAGE_TICKS or 30)
    hard_mode_log(
      info,
      entity,
      "attack-damage",
      "reason=" .. tostring(reason)
        .. " damage=" .. tostring(damage)
        .. " damage_force=" .. hard_mode_force_name(damage_force)
        .. " did_damage=" .. hard_mode_bool(did_damage)
        .. " target_after=" .. hard_mode_target_summary(target),
      {force = true}
    )
    return true
  end

  local function maintain_hard_mode_attack(info, entity, reason)
    if not hard_mode_enabled() or not info or not entity or not entity.valid then
      hard_mode_log(info, entity, "attack-maintain-skip", "reason=" .. tostring(reason), {force = true})
      return false
    end

    if info.state ~= "protesting" then
      hard_mode_log(info, entity, "attack-state-reset", "reason=" .. tostring(reason) .. " state=" .. tostring(info.state), {force = true})
      deps.set_waiting_biter_state(info, "protesting")
    end

    local has_stale_navigation = info.pending_path_request_id
      or info.protest_obstacle_attacking
      or info.protest_pipe_gap_waypoint
      or info.protest_pipe_gap_route_active
      or info.protest_route_hop_waypoint
      or info.protest_route_retry_tick
      or info.desk_route_breach_attacking
      or info.desk_route_gap_waypoint
    if has_stale_navigation then
      local preserved_target = info.target_building
      reset_protest_targeting(
        info,
        info.tracked_unit_number or entity.unit_number,
        {preserve_protest_identity = true}
      )
      if preserved_target and preserved_target.valid then
        info.target_building = preserved_target
        info.arrived_at_building = true
      end
      hard_mode_log(info, entity, "attack-cleared-stale-navigation", "reason=" .. tostring(reason), {force = true})
    end

    info.hard_mode_attacking = true
    info.frustration = get_frustration_capacity()
    info.frust_accum = 0
    info.entity = entity
    deps.remember_entity_tracking(info, entity)

    local target = find_nearest_attack_target(entity.surface, entity.position)
      or (info.target_building and info.target_building.valid and info.target_building)
    if not target or not target.valid then
      hard_mode_log(info, entity, "attack-no-target", "reason=" .. tostring(reason), {force = true})
      return false
    end

    hard_mode_log(
      info,
      entity,
      "attack-maintain",
      "reason=" .. tostring(reason)
        .. " selected_target=" .. hard_mode_target_summary(target)
        .. " next_command_tick=" .. tostring(info.hard_mode_attack_next_command_tick)
        .. " next_damage_tick=" .. tostring(info.hard_mode_attack_next_damage_tick)
    )

    if info.target_building ~= target then
      hard_mode_log(
        info,
        entity,
        "attack-retarget",
        "reason=" .. tostring(reason)
          .. " old_target=" .. hard_mode_target_summary(info.target_building)
          .. " new_target=" .. hard_mode_target_summary(target),
        {force = true}
      )
      if info.target_building and info.target_building.valid and info.arrived_at_building then
        release_protest_target(info.target_building, info.tracked_unit_number or entity.unit_number)
      end
      render.destroy_protest_rendering(info)
      render.destroy_protest_chart_tag(info)
    end
    info.target_building = target
    info.arrived_at_building = true
    info.protest_parked = nil
    info.pending_path_request_id = nil
    info.pending_protest_candidates = nil
    info.next_protest_target_retry_tick = nil

    release_protest_target(target, info.tracked_unit_number or entity.unit_number)
    prepare_hard_mode_attack_entity(entity)
    render.ensure_protest_rendering(info)

    local in_range = is_hard_mode_attack_in_range(entity, target)
    local commandable = entity.commandable
    hard_mode_log(
      info,
      entity,
      "attack-range-check",
      "reason=" .. tostring(reason)
        .. " in_range=" .. hard_mode_bool(in_range)
        .. " commandable=" .. hard_mode_bool(commandable)
        .. " can_command=" .. hard_mode_bool(commandable and commandable.set_command)
        .. " target=" .. hard_mode_target_summary(target)
    )
    if commandable
       and game.tick >= (info.hard_mode_attack_next_command_tick or 0) then
      issue_hard_mode_attack_command(info, entity, target, reason, {in_range = in_range})
    end

    if in_range then
      damage_hard_mode_attack_target(info, entity, target, reason)
    end

    return true
  end

  local function release_hard_mode_attacker(info, entity, reason)
    if not hard_mode_enabled() or not info or not entity or not entity.valid then
      hard_mode_log(info, entity, "release-skip", "reason=" .. tostring(reason), {force = true})
      return false
    end

    local unit_number = info.tracked_unit_number or entity.unit_number
    local previous_target = info.target_building
    local attack_target = find_nearest_attack_target(entity.surface, entity.position)
      or (previous_target and previous_target.valid and previous_target)

    hard_mode_log(info, entity, "release", "reason=" .. tostring(reason), {force = true})
    clear_pacified_runtime(info)
    if info.desk_id then
      deps.unindex_biter_from_desk(info.desk_id, unit_number)
      zones.release_slot(info.desk_id, unit_number)
    end

    deps.set_waiting_biter_state(info, "protesting")
    clear_hard_mode_attack_runtime(info)
    -- Hard-mode combat is a distinct command lifecycle. Clear any pending
    -- protest path, wall-gap hop, or breach attack before issuing its attack
    -- command so an old completion event cannot resume the former route.
    reset_protest_targeting(info, unit_number, {preserve_protest_identity = true})
    info.hard_mode_attacking = true
    info.frustration = get_frustration_capacity()
    info.frust_accum = 0
    info.promise_retry_until_tick = nil
    info.desk_id = nil
    info.desk_dest = nil
    info.hard_mode_attack_reason = reason
    info.hard_mode_attack_tick = game.tick
    info.target_building = attack_target
    info.arrived_at_building = attack_target ~= nil
    info.protest_parked = nil
    info.entity = entity
    deps.remember_entity_tracking(info, entity)

    return maintain_hard_mode_attack(info, entity, reason)
  end

  local function get_pacified_frustration()
    return math.floor(get_protest_threshold() * (C.PACIFIED_FRUSTRATION_RATIO or 0.5))
  end

  function clear_pacified_runtime(info)
    if not info then return end
    render.destroy_pacified_rendering(info)
    info.next_pacified_roam_tick = nil
    info.pacified_visibility_hold = nil
    info.pacified_parked = nil
    info.pacified_roam_step = nil
    info.pacified_queue_anchor_position = nil
  end

  local function get_tracked_position(info)
    if not info then return nil end
    if info.entity and info.entity.valid then
      return info.entity.position
    end
    return info.last_known_position
      or info.protest_anchor_position
      or info.desk_dest
      or info.return_dest
      or (info.target_building and info.target_building.valid and info.target_building.position)
      or nil
  end

  local function get_any_cached_desk()
    for _, desk in ipairs(deps.get_cached_desks()) do
      if desk and desk.valid then
        return desk
      end
    end
    return nil
  end

  local function get_cached_desks_by_distance(info)
    local position = get_tracked_position(info)
    local desks = {}

    for _, desk in ipairs(deps.get_cached_desks()) do
      if desk and desk.valid then
        local dist = 0
        if position then
          local dx = desk.position.x - position.x
          local dy = desk.position.y - position.y
          dist = dx * dx + dy * dy
        end
        desks[#desks + 1] = {desk = desk, dist = dist}
      end
    end

    table.sort(desks, function(a, b)
      if a.dist ~= b.dist then return a.dist < b.dist end
      return (a.desk.unit_number or 0) < (b.desk.unit_number or 0)
    end)

    return desks
  end

  local function find_nearest_cached_desk(info)
    local desks = get_cached_desks_by_distance(info)
    return desks[1] and desks[1].desk or nil
  end

  local function find_available_desk_for_info(info)
    local position = get_tracked_position(info)
    if not position then return nil end
    return deps.find_nearest_available_desk(position)
  end

  local function schedule_next_pacified_roam(info)
    if not info then return end
    info.next_pacified_roam_tick = game.tick
      + (C.PACIFIED_ROAM_REISSUE_TICKS or 5 * 60)
      + math.random(0, C.PACIFIED_ROAM_REISSUE_JITTER_TICKS or 0)
  end

  local function park_pacified_biter(info, entity, opts)
    if not info or not entity or not entity.valid then return false end

    opts = opts or {}
    if not opts.keep_roam_timer then
      info.next_pacified_roam_tick = nil
    end
    info.pacified_visibility_hold = true
    info.pacified_parked = true
    entity.force = deps.get_biter_force()
    entity.commandable.set_command({
      type = defines.command.stop,
      distraction = defines.distraction.none,
    })
    deps.remember_entity_tracking(info, entity)
    render.ensure_pacified_rendering(info)
    return true
  end

  local function issue_pacified_roam_command(info, entity)
    if not info or not entity or not entity.valid then return false end

    local desks = get_cached_desks_by_distance(info)
    local unit_seed = info.tracked_unit_number or entity.unit_number or 0
    local roam_step = (info.pacified_roam_step or 0) + 1
    local anchor_entry = desks[((roam_step - 1) % #desks) + 1]
    local anchor_desk = anchor_entry and anchor_entry.desk or nil
    local origin = (anchor_desk and anchor_desk.position) or get_tracked_position(info) or entity.position
    local angle = ((unit_seed + roam_step * 3) % 16) * (math.pi / 8)
    local radius = anchor_desk and 3.25 or 2.5
    local preferred = {
      x = origin.x + math.cos(angle) * radius,
      y = origin.y + math.sin(angle) * radius,
    }
    local destination = entity.surface.find_non_colliding_position(entity.name, preferred, 6, 0.5)
      or entity.surface.find_non_colliding_position(entity.name, origin, 4, 0.5)
      or preferred

    info.pacified_visibility_hold = nil
    info.pacified_roam_step = roam_step
    info.pacified_queue_anchor_position = anchor_desk and {x = anchor_desk.position.x, y = anchor_desk.position.y} or nil
    schedule_next_pacified_roam(info)
    info.pacified_parked = nil
    entity.force = deps.get_biter_force()
    entity.commandable.set_command({
      type = defines.command.go_to_location,
      destination = destination,
      radius = 2,
      distraction = defines.distraction.none,
    })
    deps.remember_entity_tracking(info, entity)
    render.ensure_pacified_rendering(info)
    return true
  end

  local function maintain_pacified_entity(info, entity)
    if not info or not entity or not entity.valid then return false end

    if not get_any_cached_desk() then
      return park_pacified_biter(info, entity)
    end

    if info.next_pacified_roam_tick == nil then
      return issue_pacified_roam_command(info, entity)
    end

    if info.pacified_parked and game.tick >= info.next_pacified_roam_tick then
      return issue_pacified_roam_command(info, entity)
    end

    info.pacified_visibility_hold = nil
    deps.remember_entity_tracking(info, entity)
    render.ensure_pacified_rendering(info)
    return true
  end

  local function same_protest_target(a, b)
    if not a or not b or not a.valid or not b.valid then return false end
    if a == b then return true end
    if a.unit_number and b.unit_number then
      return a.unit_number == b.unit_number and a.surface == b.surface
    end
    return a.surface == b.surface
      and a.name == b.name
      and a.position.x == b.position.x
      and a.position.y == b.position.y
  end

  local function snapshot_protest_target(target)
    if not target or not target.valid then return nil end

    return {
      unit_number = target.unit_number,
      name = target.name,
      surface_index = target.surface and target.surface.index or nil,
      position = target.position and {x = target.position.x, y = target.position.y} or nil,
    }
  end

  local function same_protest_target_snapshot(target, snapshot)
    if not target or not target.valid or not snapshot then return false end

    local surface = target.surface
    if snapshot.unit_number and target.unit_number then
      return target.unit_number == snapshot.unit_number
        and surface
        and surface.index == snapshot.surface_index
    end

    local position = target.position
    return surface
      and position
      and snapshot.position
      and surface.index == snapshot.surface_index
      and target.name == snapshot.name
      and position.x == snapshot.position.x
      and position.y == snapshot.position.y
  end

  count_protesters_on_target = function(target, exclude_unit_number)
    local total = 0
    for unit_number in pairs(deps.get_waiting_biter_state_set("protesting")) do
      local other_info = storage.waiting_biters and storage.waiting_biters[unit_number]
      if unit_number ~= exclude_unit_number
         and other_info
         and other_info.state == "protesting"
         and not other_info.hard_mode_attacking
         and same_protest_target(other_info.target_building, target) then
        total = total + 1
      end
    end
    return total
  end

  local function get_claimed_protest_target(info)
    if not info or info.state ~= "protesting" then return nil end
    if info.pending_protest_reserved_target and info.pending_protest_reserved_target.valid then
      return info.pending_protest_reserved_target
    end
    if info.target_building and info.target_building.valid then
      return info.target_building
    end
    return nil
  end

  local function count_claimed_protesters_on_target(target, exclude_unit_number)
    local total = 0
    for unit_number in pairs(deps.get_waiting_biter_state_set("protesting")) do
      local other_info = storage.waiting_biters and storage.waiting_biters[unit_number]
      if unit_number ~= exclude_unit_number
         and other_info
         and same_protest_target(get_claimed_protest_target(other_info), target) then
        total = total + 1
      end
    end
    return total
  end

  local function distance_sq(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return dx * dx + dy * dy
  end

  local function get_protest_reference_position(info)
    if not info then return nil end
    if info.protest_anchor_position then
      return info.protest_anchor_position
    end
    if info.entity and info.entity.valid then
      return info.entity.position
    end
    return info.last_known_position
  end

  local function get_protest_claim_position(info)
    if not info then return nil end
    if info.protest_anchor_position then
      return info.protest_anchor_position
    end
    if info.pending_protest_reserved_position then
      return info.pending_protest_reserved_position
    end
    return get_protest_reference_position(info)
  end

  local function get_protest_arrival_position(info)
    if not info then return nil end
    if info.protest_anchor_position then
      return info.protest_anchor_position
    end
    if info.target_building and info.target_building.valid then
      return info.target_building.position
    end
    return nil
  end

  local function get_protest_target_bounds(target)
    local box = target and target.valid and target.bounding_box or nil
    if not box then
      return target.position, 0.5, 0.5
    end

    local center = {
      x = (box.left_top.x + box.right_bottom.x) * 0.5,
      y = (box.left_top.y + box.right_bottom.y) * 0.5,
    }
    local half_width = math.max(0.5, (box.right_bottom.x - box.left_top.x) * 0.5)
    local half_height = math.max(0.5, (box.right_bottom.y - box.left_top.y) * 0.5)
    return center, half_width, half_height
  end

  -- Build per-target protest counts and positions in a single pass over protesting biters.
  -- Returns per-target counts/positions plus the total protester count.
  local function build_protester_snapshot(exclude_unit_number)
    local snapshot = {
      claimed_counts = {},
      protester_counts = {},
      protester_positions = {},
      total_protesters = 0,
    }

    for unit_number in pairs(deps.get_waiting_biter_state_set("protesting")) do
      if unit_number ~= exclude_unit_number then
        local other_info = storage.waiting_biters and storage.waiting_biters[unit_number]
        if other_info and other_info.state == "protesting" then
          snapshot.total_protesters = snapshot.total_protesters + 1
          local claimed_target = get_claimed_protest_target(other_info)
          if claimed_target and claimed_target.valid and claimed_target.unit_number then
            local key = claimed_target.unit_number
            snapshot.claimed_counts[key] = (snapshot.claimed_counts[key] or 0) + 1
            
            local pos = get_protest_claim_position(other_info)
            if pos then
              snapshot.protester_positions[key] = snapshot.protester_positions[key] or {}
              table.insert(snapshot.protester_positions[key], pos)
            end
          end
          if other_info.state == "protesting"
             and other_info.target_building
             and other_info.target_building.valid
             and other_info.target_building.unit_number then
            local key = other_info.target_building.unit_number
            snapshot.protester_counts[key] = (snapshot.protester_counts[key] or 0) + 1
          end
        end
      end
    end

    return snapshot
  end

  local tick_protester_snapshot = nil
  local function get_protester_snapshot(exclude_unit_number)
    if tick_protester_snapshot and tick_protester_snapshot.tick == game.tick then
      return tick_protester_snapshot.snapshot
    end
    
    local snapshot = build_protester_snapshot(nil)
    tick_protester_snapshot = {tick = game.tick, snapshot = snapshot}
    return snapshot
  end

  local function count_protesters()
    local count = 0
    for _ in pairs(deps.get_waiting_biter_state_set("protesting") or {}) do
      count = count + 1
    end
    return count
  end

  local function get_protest_load_factor(protester_count)
    local threshold = math.max(1, C.PROTEST_HIGH_LOAD_THRESHOLD or math.huge)
    if protester_count <= threshold then return 1 end
    return math.min(
      C.PROTEST_PACING_MAX_SHARDS or 1,
      math.ceil(protester_count / threshold)
    )
  end

  local function schedule_protest_target_retry(info, entity, base_ticks, load_factor)
    if not info then return end
    load_factor = load_factor or 1
    local retry_ticks = (base_ticks or C.PROTEST_TARGET_RETRY_TICKS) * load_factor
    local jitter_window = load_factor > 1 and (C.PROTEST_TARGET_RETRY_JITTER_TICKS or 0) or 0
    local unit_number = entity and entity.valid and entity.unit_number
      or info.tracked_unit_number
      or 0
    local jitter = jitter_window > 0 and ((unit_number * 37) % (jitter_window + 1)) or 0
    info.next_protest_target_retry_tick = game.tick + retry_ticks + jitter
  end

  local function defer_protest_target_retry(info, entity, base_ticks, load_factor)
    schedule_protest_target_retry(info, entity, base_ticks, load_factor)
    info.protest_path_retry_deferred = true
    info.next_protest_wander_tick = info.next_protest_target_retry_tick
    if entity and entity.valid then
      entity.active = false
    end
  end

  local function reserve_high_load_path_request(load_factor)
    if load_factor <= 1 then return true end

    local outstanding_limit = math.max(1, C.PROTEST_PATH_REQUESTS_MAX_OUTSTANDING_HIGH_LOAD or 1)
    if count_outstanding_protest_path_requests() >= outstanding_limit then
      return false
    end

    if storage.protest_path_request_budget_tick ~= game.tick then
      storage.protest_path_request_budget_tick = game.tick
      storage.protest_path_requests_this_tick = 0
    end

    local limit = math.max(1, C.PROTEST_PATH_REQUESTS_PER_TICK_HIGH_LOAD or 1)
    local used = storage.protest_path_requests_this_tick or 0
    if used >= limit then return false end
    storage.protest_path_requests_this_tick = used + 1
    return true
  end

  local function release_high_load_path_request_reservation(load_factor)
    if load_factor <= 1 or storage.protest_path_request_budget_tick ~= game.tick then return end
    storage.protest_path_requests_this_tick = math.max(
      0,
      (storage.protest_path_requests_this_tick or 0) - 1
    )
  end

  local function index_protest_obstacle_route(info, entity)
    local unit_number = info and info.tracked_unit_number
      or (entity and entity.valid and entity.unit_number)
    if not unit_number then return end
    storage.protest_obstacle_attackers = storage.protest_obstacle_attackers or {}
    storage.protest_obstacle_attackers[unit_number] = true
  end

  local function unindex_protest_obstacle_route(info, entity)
    local unit_number = info and info.tracked_unit_number
      or (entity and entity.valid and entity.unit_number)
    if unit_number and storage.protest_obstacle_attackers then
      storage.protest_obstacle_attackers[unit_number] = nil
    end
  end

  local function count_active_protest_obstacle_attackers()
    storage.protest_obstacle_attackers = storage.protest_obstacle_attackers or {}
    local count = 0
    for unit_number in pairs(storage.protest_obstacle_attackers) do
      local info = storage.waiting_biters and storage.waiting_biters[unit_number]
      if info
         and (info.protest_obstacle_attacking or info.protest_pipe_gap_route_active)
         and info.entity
         and info.entity.valid then
        if info.protest_obstacle_attacking then count = count + 1 end
      else
        storage.protest_obstacle_attackers[unit_number] = nil
      end
    end
    return count
  end

  local function count_active_protest_pipe_gap_routes()
    storage.protest_obstacle_attackers = storage.protest_obstacle_attackers or {}
    local count = 0
    for unit_number in pairs(storage.protest_obstacle_attackers) do
      local info = storage.waiting_biters and storage.waiting_biters[unit_number]
      if info
         and (info.protest_obstacle_attacking or info.protest_pipe_gap_route_active)
         and info.entity
         and info.entity.valid then
        if info.protest_pipe_gap_route_active then count = count + 1 end
      else
        storage.protest_obstacle_attackers[unit_number] = nil
      end
    end
    return count
  end

  local PROTEST_OBSTACLE_EXCLUDED_TYPES = {
    inserter = true,
    loader = true,
    ["loader-1x1"] = true,
    ["linked-belt"] = true,
    pipe = true,
    ["pipe-to-ground"] = true,
    splitter = true,
    ["transport-belt"] = true,
    ["underground-belt"] = true,
  }

  local function collision_masks_overlap(first_mask, second_mask)
    local first_layers = first_mask and first_mask.layers
    local second_layers = second_mask and second_mask.layers
    if type(first_layers) ~= "table" or type(second_layers) ~= "table" then return false end
    for layer, enabled in pairs(first_layers) do
      if enabled and second_layers[layer] then return true end
    end
    return false
  end

  local function is_attackable_protest_obstacle(candidate, entity, goal_target, excluded_target)
    if not candidate or not candidate.valid or candidate == entity or candidate == goal_target then return false end
    if excluded_target and candidate == excluded_target then return false end
    if not candidate.force or candidate.force.name ~= "player" then return false end
    if deps.protest_protected_names[candidate.name] then return false end
    if PROTEST_OBSTACLE_EXCLUDED_TYPES[candidate.type] then return false end
    if not protest_obstacle_building_type_set[candidate.type] then return false end
    if candidate.destructible == false then return false end
    if candidate.health == nil or candidate.health <= 0 or candidate.position == nil then return false end
    local candidate_prototype = candidate.prototype
    local entity_prototype = entity and entity.prototype
    return candidate_prototype ~= nil
      and entity_prototype ~= nil
      and collision_masks_overlap(candidate_prototype.collision_mask, entity_prototype.collision_mask)
  end

  local function is_attackable_pipe_breach(candidate, entity)
    if not candidate or not candidate.valid or candidate == entity then return false end
    if candidate.type ~= "pipe" then return false end
    if not candidate.force or candidate.force.name ~= "player" then return false end
    if candidate.destructible == false then return false end
    if candidate.health == nil or candidate.health <= 0 or candidate.position == nil then return false end
    local candidate_prototype = candidate.prototype
    local entity_prototype = entity and entity.prototype
    return candidate_prototype ~= nil
      and entity_prototype ~= nil
      and collision_masks_overlap(candidate_prototype.collision_mask, entity_prototype.collision_mask)
  end

  local function find_nearby_attackable_pipe(entity)
    if not entity or not entity.valid or not entity.surface then return nil end
    for _, candidate in ipairs(entity.surface.find_entities_filtered{
      position = entity.position,
      radius = C.PROTEST_PIPE_LOCAL_RECOVERY_RADIUS or 8,
      force = "player",
      type = "pipe",
    }) do
      if is_attackable_pipe_breach(candidate, entity) then return candidate end
    end
    return nil
  end

  -- Choose only a regular pipe that lies in the narrow forward corridor from
  -- the unit to its real destination. This is deliberately separate from the
  -- protest-building selector: the pipe is an incidental breach segment, not
  -- the grievance target. Underground pipes, belts, inserters, and arbitrary
  -- off-route infrastructure never enter this query.
  local function find_aligned_pipe_breach(entity, goal_position)
    if not entity or not entity.valid or not entity.surface or not goal_position then return nil end
    local origin = entity.position
    local goal_dx = goal_position.x - origin.x
    local goal_dy = goal_position.y - origin.y
    local goal_length_sq = goal_dx * goal_dx + goal_dy * goal_dy
    if goal_length_sq < 0.01 then return nil end
    local goal_length = math.sqrt(goal_length_sq)
    local dir_x = goal_dx / goal_length
    local dir_y = goal_dy / goal_length
    local radius = C.PROTEST_PIPE_BREACH_SEARCH_RADIUS or 128
    local max_lateral = C.PROTEST_PIPE_BREACH_MAX_LATERAL_DISTANCE or 2
    local max_lateral_sq = max_lateral * max_lateral
    local nearby = entity.surface.find_entities_filtered{
      position = origin,
      radius = radius,
      force = "player",
      type = "pipe",
    }
    local best = nil
    local best_score = math.huge
    for _, candidate in ipairs(nearby) do
      if is_attackable_pipe_breach(candidate, entity) then
        local dx = candidate.position.x - origin.x
        local dy = candidate.position.y - origin.y
        local forward = dx * dir_x + dy * dir_y
        -- Only breach a segment that is still ahead. The old negative margin
        -- let a unit that had already crossed a gap turn around and attack the
        -- same wall from the inside.
        if forward > (C.PROTEST_PIPE_BREACH_MIN_FORWARD_DISTANCE or 0.1)
           and forward <= math.min(radius, goal_length + 0.5) then
          local distance = dx * dx + dy * dy
          local lateral_sq = math.max(0, distance - forward * forward)
          if lateral_sq <= max_lateral_sq then
            -- Prefer the first segment met along the route; lateral alignment
            -- only breaks close ties so a wall opens from the outside inward.
            local score = forward * forward + lateral_sq * 4
            if score < best_score then
              best = candidate
              best_score = score
            end
          end
        end
      end
    end
    return best
  end

  local function find_pipe_wall_gap_waypoint(entity, goal_position, aligned_pipe)
    if not entity or not entity.valid or not entity.surface then return nil end
    if not goal_position or not is_attackable_pipe_breach(aligned_pipe, entity) then return nil end

    local search_radius = math.max(2, C.PROTEST_PIPE_GAP_SEARCH_RADIUS or 64)
    local nearby = entity.surface.find_entities_filtered{
      position = aligned_pipe.position,
      radius = search_radius,
      force = "player",
      type = "pipe",
    }
    local occupied = {}
    local function position_key(position)
      return math.floor(position.x * 4 + 0.5) .. ":" .. math.floor(position.y * 4 + 0.5)
    end
    for _, pipe in ipairs(nearby) do
      if is_attackable_pipe_breach(pipe, entity) then
        occupied[position_key(pipe.position)] = true
      end
    end

    local pipe_pos = aligned_pipe.position
    local horizontal_neighbors = 0
    local vertical_neighbors = 0
    for _, offset in ipairs({-1, 1}) do
      if occupied[position_key{x = pipe_pos.x + offset, y = pipe_pos.y}] then
        horizontal_neighbors = horizontal_neighbors + 1
      end
      if occupied[position_key{x = pipe_pos.x, y = pipe_pos.y + offset}] then
        vertical_neighbors = vertical_neighbors + 1
      end
    end
    if horizontal_neighbors == 0 and vertical_neighbors == 0 then return nil end

    local goal_dx = goal_position.x - pipe_pos.x
    local goal_dy = goal_position.y - pipe_pos.y
    local tangent_x, tangent_y, normal_x, normal_y
    if vertical_neighbors > horizontal_neighbors
       or (vertical_neighbors == horizontal_neighbors and math.abs(goal_dx) >= math.abs(goal_dy)) then
      tangent_x, tangent_y = 0, 1
      normal_x, normal_y = goal_dx >= 0 and 1 or -1, 0
    else
      tangent_x, tangent_y = 1, 0
      normal_x, normal_y = 0, goal_dy >= 0 and 1 or -1
    end

    local cross_distance = C.PROTEST_PIPE_GAP_CROSS_DISTANCE or 1.5
    for distance = 1, search_radius do
      for _, direction in ipairs({-1, 1}) do
        local gap = {
          x = pipe_pos.x + tangent_x * distance * direction,
          y = pipe_pos.y + tangent_y * distance * direction,
        }
        if not occupied[position_key(gap)] then
          -- Probe beyond the opening, not inside it. Existing protesters can
          -- crowd a perfectly real hole and make find_non_colliding_position
          -- reject the doorway itself; unit movement will resolve that local
          -- crowd once the command targets the free tile across the wall.
          local beyond = {
            x = gap.x + normal_x * cross_distance,
            y = gap.y + normal_y * cross_distance,
          }
          local waypoint = entity.surface.find_non_colliding_position(entity.name, beyond, 2, 0.25)
          if waypoint then
            local crossed = (waypoint.x - pipe_pos.x) * normal_x
              + (waypoint.y - pipe_pos.y) * normal_y
            local tangent_offset = math.abs(
              (waypoint.x - gap.x) * tangent_x
                + (waypoint.y - gap.y) * tangent_y
            )
            if crossed >= cross_distance * 0.5 and tangent_offset <= 2 then
              return waypoint
            end
          end
        end
      end
    end
    return nil
  end

  local function find_nearby_protest_obstacle(entity, goal_position, goal_target, excluded_target)
    if not entity or not entity.valid or not entity.surface then return nil end
    local radius = C.PROTEST_OBSTACLE_SEARCH_RADIUS or 4
    local goal_dx = goal_position and goal_position.x - entity.position.x or nil
    local goal_dy = goal_position and goal_position.y - entity.position.y or nil
    local goal_length = goal_dx and math.sqrt(goal_dx * goal_dx + goal_dy * goal_dy) or 0
    local nearby = entity.surface.find_entities_filtered{
      position = entity.position,
      radius = radius,
      force = "player",
    }
    local best = nil
    local best_distance = math.huge
    local best_goal_distance = math.huge
    for _, candidate in ipairs(nearby) do
      if is_attackable_protest_obstacle(candidate, entity, goal_target, excluded_target) then
        local candidate_distance = distance_sq(entity.position, candidate.position)
        local goal_distance = goal_position and distance_sq(candidate.position, goal_position) or 0
        local forward = goal_length > 0
          and ((candidate.position.x - entity.position.x) * goal_dx
            + (candidate.position.y - entity.position.y) * goal_dy) / goal_length
          or 0
        -- A building already behind the unit cannot be the obstruction that
        -- caused its forward route to fail. This also prevents a post-breach
        -- completion from turning around to demolish the wall it just crossed.
        if (goal_length == 0 or forward > 0)
           and (candidate_distance < best_distance
             or (candidate_distance == best_distance and goal_distance < best_goal_distance)) then
          best = candidate
          best_distance = candidate_distance
          best_goal_distance = goal_distance
        end
      end
    end
    return best
  end

  local function issue_protest_obstacle_attack_command(info, entity)
    local target = info and info.protest_obstacle_target or nil
    local commandable = entity and entity.valid and entity.commandable or nil
    if not target or not target.valid or not commandable or not commandable.set_command then return false end
    commandable.set_command({
      type = defines.command.attack,
      target = target,
      distraction = defines.distraction.none,
    })
    info.protest_obstacle_command_pending = true
    info.next_protest_obstacle_command_tick = game.tick + (C.PROTEST_OBSTACLE_COMMAND_RETRY_TICKS or 60)
    info.protest_obstacle_reselect_tick = game.tick + (C.PROTEST_OBSTACLE_RETRY_TICKS or (3 * 60))
    return true
  end

  clear_protest_obstacle_attack_runtime = function(info, entity)
    if not info then return end
    local unit_number = info.tracked_unit_number
      or (entity and entity.valid and entity.unit_number)
    if unit_number and storage.protest_obstacle_attackers then
      storage.protest_obstacle_attackers[unit_number] = nil
    end

    local was_attacking = info.protest_obstacle_attacking == true
    info.protest_obstacle_attacking = nil
    info.protest_obstacle_goal = nil
    info.protest_obstacle_goal_target = nil
    info.protest_obstacle_target = nil
    info.protest_obstacle_target_kind = nil
    info.protest_obstacle_target_unit_number = nil
    info.protest_obstacle_target_destroyed = nil
    info.protest_obstacle_command_pending = nil
    info.protest_obstacle_command_failures = nil
    info.next_protest_obstacle_command_tick = nil
    info.protest_obstacle_reselect_tick = nil
    info.protest_obstacle_attack_tick = nil
    info.protest_pipe_gap_next_check_tick = nil
    if not was_attacking or not entity or not entity.valid then return end

    if deps.apply_managed_unit_settings then
      deps.apply_managed_unit_settings(entity)
    end
    entity.force = deps.get_biter_force()
    entity.destructible = false
    if entity.commandable and entity.commandable.set_command then
      entity.commandable.set_command({
        type = defines.command.stop,
        distraction = defines.distraction.none,
      })
    end
    entity.active = false
  end

  local function count_active_desk_route_breach_attackers()
    storage.desk_route_breach_attackers = storage.desk_route_breach_attackers or {}
    local count = 0
    for unit_number in pairs(storage.desk_route_breach_attackers) do
      local info = storage.waiting_biters and storage.waiting_biters[unit_number]
      if info
         and (info.desk_route_breach_attacking or info.desk_route_gap_waypoint)
         and info.entity
         and info.entity.valid then
        count = count + 1
      else
        storage.desk_route_breach_attackers[unit_number] = nil
      end
    end
    return count
  end

  clear_desk_route_breach_runtime = function(info, entity)
    if not info then return end
    local unit_number = info.tracked_unit_number
      or (entity and entity.valid and entity.unit_number)
    if unit_number and storage.desk_route_breach_attackers then
      storage.desk_route_breach_attackers[unit_number] = nil
    end

    local was_attacking = info.desk_route_breach_attacking == true
    info.desk_route_breach_attacking = nil
    info.desk_route_breach_target = nil
    info.desk_route_breach_target_unit_number = nil
    info.desk_route_breach_command_pending = nil
    info.desk_route_breach_command_failures = nil
    info.next_desk_route_breach_command_tick = nil
    info.desk_route_breach_reselect_tick = nil
    info.next_desk_route_breach_retry_tick = nil
    info.desk_route_gap_waypoint = nil
    info.desk_route_gap_obstacle = nil
    info.desk_route_gap_started_tick = nil
    info.desk_route_gap_failed_until_tick = nil
    info.desk_route_breach_gap_checked_target_unit_number = nil
    info.desk_route_gap_next_check_tick = nil
    info.desk_route_started_tick = nil
    info.desk_route_last_progress_tick = nil
    info.desk_route_best_distance_sq = nil
    if not was_attacking or not entity or not entity.valid then return end

    if deps.apply_managed_unit_settings then
      deps.apply_managed_unit_settings(entity)
    end
    entity.force = deps.get_biter_force()
    entity.destructible = false
    if entity.commandable and entity.commandable.set_command then
      entity.commandable.set_command({
        type = defines.command.stop,
        distraction = defines.distraction.none,
      })
    end
    entity.active = false
  end

  local function defer_desk_route_breach(info, entity)
    clear_desk_route_breach_runtime(info, entity)
    local retry_ticks = C.DESK_ROUTE_BREACH_RETRY_TICKS or (2 * 60)
    local unit_number = info.tracked_unit_number
      or (entity and entity.valid and entity.unit_number)
      or 0
    info.next_desk_route_breach_retry_tick = game.tick + retry_ticks + (unit_number % 60)
    if entity and entity.valid then
      entity.active = false
    end
    return true
  end

  local function issue_desk_route_breach_command(info, entity)
    local target = info and info.desk_route_breach_target or nil
    local commandable = entity and entity.valid and entity.commandable or nil
    if not target or not target.valid or not commandable or not commandable.set_command then return false end
    commandable.set_command({
      type = defines.command.attack,
      target = target,
      distraction = defines.distraction.none,
    })
    info.desk_route_breach_command_pending = true
    info.next_desk_route_breach_command_tick = game.tick
      + (C.PROTEST_OBSTACLE_COMMAND_RETRY_TICKS or 60)
    info.desk_route_breach_reselect_tick = game.tick
      + (C.DESK_ROUTE_BREACH_RETRY_TICKS or (2 * 60))
    return true
  end

  local function issue_desk_gap_route(info, entity, obstacle, gap_waypoint)
    info.desk_route_gap_waypoint = {x = gap_waypoint.x, y = gap_waypoint.y}
    info.desk_route_gap_obstacle = obstacle
    info.desk_route_gap_started_tick = game.tick
    if deps.issue_desk_route_command(entity, gap_waypoint) then
      local unit_number = entity.unit_number or info.tracked_unit_number
      if unit_number then
        storage.desk_route_breach_attackers = storage.desk_route_breach_attackers or {}
        storage.desk_route_breach_attackers[unit_number] = true
      end
      return true
    end
    info.desk_route_gap_waypoint = nil
    info.desk_route_gap_obstacle = nil
    info.desk_route_gap_started_tick = nil
    return false
  end

  local function begin_desk_route_breach(info, entity, selected_obstacle, opts)
    if not info or info.state ~= "pathfinding" or not info.desk_dest then return false end
    if not entity or not entity.valid then return false end
    opts = opts or {}

    local obstacle = selected_obstacle or find_aligned_pipe_breach(entity, info.desk_dest)
    if not obstacle then
      return defer_desk_route_breach(info, entity)
    end

    local attacker_limit = math.max(1, C.DESK_ROUTE_BREACH_ATTACKER_LIMIT or 2)
    if count_active_desk_route_breach_attackers() >= attacker_limit then
      return defer_desk_route_breach(info, entity)
    end

    if not opts.skip_gap
       and game.tick >= (info.desk_route_gap_failed_until_tick or 0) then
      local gap_waypoint = find_pipe_wall_gap_waypoint(entity, info.desk_dest, obstacle)
      if gap_waypoint then
        if issue_desk_gap_route(info, entity, obstacle, gap_waypoint) then
          return true
        end
      end
    end

    -- Normal mode citizens may use a real opening, but they must never make
    -- one with their teeth.  Destructive route recovery belongs exclusively
    -- to hard mode, just like every other biter attack on player property.
    if not hard_mode_enabled() then
      return defer_desk_route_breach(info, entity)
    end

    info.desk_route_breach_gap_checked_target_unit_number = obstacle.unit_number
    local unit_number = entity.unit_number or info.tracked_unit_number or 0
    info.desk_route_gap_next_check_tick = game.tick
      + (C.PROTEST_PIPE_GAP_RECHECK_TICKS or (2 * 60))
      + (unit_number % 60)

    local attack_force = deps.get_hard_mode_attack_force and deps.get_hard_mode_attack_force()
      or (game.forces and game.forces.enemy)
      or deps.get_biter_force()
    entity.force = attack_force
    entity.destructible = true
    entity.active = true
    info.desk_route_breach_attacking = true
    info.desk_route_breach_target = obstacle
    info.desk_route_breach_target_unit_number = obstacle.unit_number
    info.desk_route_breach_command_failures = 0
    info.next_desk_route_breach_retry_tick = nil
    storage.desk_route_breach_attackers = storage.desk_route_breach_attackers or {}
    storage.desk_route_breach_attackers[unit_number] = true
    if not issue_desk_route_breach_command(info, entity) then
      return defer_desk_route_breach(info, entity)
    end
    return true
  end

  local function resume_desk_route_after_breach(info, entity)
    clear_desk_route_breach_runtime(info, entity)
    if info.state == "pathfinding" and info.desk_id and info.desk_dest then
      local dx = entity.position.x - info.desk_dest.x
      local dy = entity.position.y - info.desk_dest.y
      info.desk_route_started_tick = game.tick
      info.desk_route_last_progress_tick = game.tick
      info.desk_route_best_distance_sq = dx * dx + dy * dy
      return deps.issue_desk_route_command(entity, info.desk_dest) == true
    end
    return false
  end

  local function process_desk_route_breach(info, entity)
    if not info or info.state ~= "pathfinding" or not entity or not entity.valid then return false end
    if info.desk_route_breach_attacking and not hard_mode_enabled() then
      return defer_desk_route_breach(info, entity)
    end
    if info.desk_route_gap_waypoint then
      entity.active = true
      local timeout = C.DESK_ROUTE_STALL_TICKS or (10 * 60)
      if game.tick - (info.desk_route_gap_started_tick or game.tick) < timeout then
        return true
      end
      local obstacle = info.desk_route_gap_obstacle
      info.desk_route_gap_waypoint = nil
      info.desk_route_gap_obstacle = nil
      info.desk_route_gap_started_tick = nil
      info.desk_route_gap_failed_until_tick = game.tick
        + (C.DESK_ROUTE_BREACH_RETRY_TICKS or (2 * 60))
      return begin_desk_route_breach(
        info,
        entity,
        obstacle and obstacle.valid and obstacle or nil,
        {skip_gap = true}
      )
    end
    if info.desk_route_breach_attacking then
      local target = info.desk_route_breach_target
      if not target or not target.valid then
        resume_desk_route_after_breach(info, entity)
        return true
      end
      if not is_attackable_pipe_breach(target, entity) then
        return defer_desk_route_breach(info, entity)
      end

      if info.desk_route_breach_gap_checked_target_unit_number ~= target.unit_number
         or game.tick >= (info.desk_route_gap_next_check_tick or 0) then
        info.desk_route_breach_gap_checked_target_unit_number = target.unit_number
        local unit_number = entity.unit_number or info.tracked_unit_number or 0
        info.desk_route_gap_next_check_tick = game.tick
          + (C.PROTEST_PIPE_GAP_RECHECK_TICKS or (2 * 60))
          + (unit_number % 60)
        local gap_waypoint = find_pipe_wall_gap_waypoint(entity, info.desk_dest, target)
        if gap_waypoint then
          clear_desk_route_breach_runtime(info, entity)
          if not issue_desk_gap_route(info, entity, target, gap_waypoint) then
            return begin_desk_route_breach(info, entity, target, {skip_gap = true})
          end
          return true
        end
      end

      entity.active = true
      if game.tick < (info.next_desk_route_breach_command_tick or 0) then
        return true
      end
      info.desk_route_breach_command_pending = nil
      -- Some unit prototypes perform one bite without completing the command.
      -- Reassert the exact same target on a bounded heartbeat. The global
      -- breach-attacker cap bounds both native path work and combat updates.
      issue_desk_route_breach_command(info, entity)
      return true
    end

    if info.next_desk_route_breach_retry_tick then
      if game.tick < info.next_desk_route_breach_retry_tick then
        entity.active = false
        return true
      end
      info.next_desk_route_breach_retry_tick = nil
      local retry_obstacle = find_aligned_pipe_breach(entity, info.desk_dest)
      if retry_obstacle then
        return begin_desk_route_breach(info, entity, retry_obstacle)
      end
      -- The blocking segment may now be behind us because another visitor
      -- opened the wall. Retry the preserved desk route instead of repeatedly
      -- asking the breach selector to attack a wall that was already crossed.
      entity.active = true
      return resume_desk_route_after_breach(info, entity)
    end

    -- A sealed go_to_location command can remain "in progress" indefinitely
    -- instead of emitting an AI failure. Detect that contour-search without
    -- adding any per-tick work: pathfinding states already visit this sharded
    -- maintenance pass. Genuine progress resets the clock; only a nearby pipe
    -- in the forward destination corridor can turn a stalled route into a
    -- controlled breach.
    local dest = info.desk_dest
    if not dest then return false end
    local dx = entity.position.x - dest.x
    local dy = entity.position.y - dest.y
    local distance = dx * dx + dy * dy
    local stall_ticks = C.DESK_ROUTE_STALL_TICKS or (10 * 60)
    if not info.desk_route_started_tick then
      -- Existing saves predate route timing. Treat those routes as old enough
      -- to inspect immediately, while still requiring a nearby aligned pipe.
      info.desk_route_started_tick = game.tick - stall_ticks
      info.desk_route_last_progress_tick = game.tick - stall_ticks
      info.desk_route_best_distance_sq = distance
    end
    local progress_distance = C.DESK_ROUTE_PROGRESS_DISTANCE or 1
    local progress_sq = progress_distance * progress_distance
    if not info.desk_route_best_distance_sq
       or distance + progress_sq < info.desk_route_best_distance_sq then
      info.desk_route_best_distance_sq = distance
      info.desk_route_last_progress_tick = game.tick
      return false
    end
    if game.tick - (info.desk_route_last_progress_tick or info.desk_route_started_tick)
       < stall_ticks then
      return false
    end
    local attacker_limit = math.max(1, C.DESK_ROUTE_BREACH_ATTACKER_LIMIT or 2)
    if count_active_desk_route_breach_attackers() >= attacker_limit then
      return defer_desk_route_breach(info, entity)
    end
    local obstacle = find_aligned_pipe_breach(entity, dest)
    if obstacle then
      return begin_desk_route_breach(info, entity, obstacle)
    end
    -- A command can become inactive after crossing a newly opened wall
    -- without emitting a failure event. Reissuing only after the normal stall
    -- window keeps this bounded while ensuring the visitor does not freeze at
    -- the first interior waypoint forever.
    info.desk_route_started_tick = game.tick
    info.desk_route_last_progress_tick = game.tick
    info.desk_route_best_distance_sq = distance
    entity.active = true
    deps.issue_desk_route_command(entity, dest)
    return true
  end

  local function get_protest_spacing_score(target, pos, exclude_unit_number, snapshot)
    local nearest_sq = math.huge
    local target_id = target and target.valid and target.unit_number
    if not target_id then return nearest_sq end

    local other_positions = snapshot and snapshot.protester_positions[target_id]
    if not other_positions then return nearest_sq end

    for _, other_pos in ipairs(other_positions) do
      local dist = distance_sq(pos, other_pos)
      if dist < nearest_sq then
        nearest_sq = dist
      end
    end

    return nearest_sq
  end

  local function is_protest_target_allowed(target, entity)
    return target
      and target.valid
      and target ~= entity
      and target.force
      and target.force.name == "player"
      and not deps.protest_protected_names[target.name]
      and (not protest_target_membership_configured
        or protest_target_name_set[target.name]
        or protest_target_type_set[target.type])
  end

  local function pick_protest_wander_position(surface, entity, target, origin, snapshot, attempt_limit)
    if not surface or not entity or not entity.valid or not target or not target.valid then return nil end

    local min_radius = C.PROTEST_WANDER_MIN_RADIUS
    local max_radius = C.PROTEST_WANDER_MAX_RADIUS
    local min_move_sq = C.PROTEST_WANDER_MIN_MOVE_DISTANCE * C.PROTEST_WANDER_MIN_MOVE_DISTANCE
    local center, half_width, half_height = get_protest_target_bounds(target)
    local fallback = nil
    local best = nil
    local best_score = -math.huge
    local best_move_sq = -math.huge
    local exclude_unit_number = entity.unit_number

    for _ = 1, (attempt_limit or C.PROTEST_WANDER_ATTEMPTS) do
      local angle = math.random() * (math.pi * 2)
      local radius = min_radius + math.random() * (max_radius - min_radius)
      local probe = {
        x = center.x + math.cos(angle) * (half_width + radius),
        y = center.y + math.sin(angle) * (half_height + radius),
      }
      local pos = surface.find_non_colliding_position(entity.name, probe, 0.75, 0.25)
      if pos then
        if not fallback then fallback = pos end
        local move_sq = origin and distance_sq(pos, origin) or min_move_sq
        local spacing_sq = get_protest_spacing_score(target, pos, exclude_unit_number, snapshot)
        local score = (spacing_sq == math.huge and 1000000 or spacing_sq) + math.min(move_sq, 1)
        if move_sq < min_move_sq then
          score = score - 0.5
        end

        if score > best_score or (score == best_score and move_sq > best_move_sq) then
          best = pos
          best_score = score
          best_move_sq = move_sq
        end
      end
    end

    return best
      or fallback
      or surface.find_non_colliding_position(entity.name, center, math.max(half_width, half_height) + max_radius + 0.75, 0.25)
  end

  local function schedule_next_protest_step(info)
    if not info then return end
    info.next_protest_wander_tick = game.tick
      + C.PROTEST_WANDER_REISSUE_TICKS
      + math.random(0, C.PROTEST_WANDER_REISSUE_JITTER_TICKS)
  end

  local function park_protester(info, entity)
    if not info or not entity or not entity.valid then return end
    local target = info.target_building
    if not target or not target.valid then return end

    protect_protesting_biter(info, entity, "park-inactive", {active = false})
    info.protest_anchor_position = {x = entity.position.x, y = entity.position.y}
    info.protest_last_command_tick = game.tick
    info.protest_step_deadline_tick = nil
    info.protest_parked = true
    schedule_next_protest_step(info)

    entity.commandable.set_command({
      type = defines.command.stop,
      distraction = defines.distraction.none,
    })
    entity.active = false
  end

  local function issue_protest_wander_command(info, entity, opts)
    if not info or not entity or not entity.valid then
      protest_debug_log("wander-command-skip-invalid-entity", info, entity)
      return false
    end
    local target = info.target_building
    if not target or not target.valid then
      protest_debug_log("wander-command-skip-invalid-target", info, entity)
      return false
    end

    opts = opts or {}
    local snapshot = get_protester_snapshot()
    local pos = opts.destination or pick_protest_wander_position(entity.surface, entity, target, opts.origin or entity.position, snapshot)
    if not pos then
      protest_debug_log("wander-command-skip-no-position", info, entity)
      return false
    end

    schedule_next_protest_step(info)
    -- A wall-gap waypoint is transit state, not the final protest anchor. If
    -- it overwrites the anchor, the generic arrival pass parks the unit at the
    -- hole and declares a protest hundreds of tiles away from its building.
    if not opts.preserve_protest_anchor then
      info.protest_anchor_position = {x = pos.x, y = pos.y}
    end
    info.protest_last_command_tick = game.tick
    info.protest_step_deadline_tick = game.tick + C.PROTEST_STEP_ACTIVE_TICKS
    info.protest_parked = nil
    protect_protesting_biter(info, entity, "wander")

    if not info.arrived_at_building then
      info.protest_route_started_tick = game.tick
      info.protest_route_last_progress_tick = game.tick
      info.protest_route_best_distance_sq = distance_sq(
        entity.position,
        opts.route_goal or pos
      )
      info.protest_route_goal_target_unit_number = target.unit_number
    end

    entity.commandable.set_command({
      type = defines.command.go_to_location,
      destination = pos,
      radius = opts.radius or 0.5,
      distraction = defines.distraction.none,
    })
    protest_debug_log("wander-command-issued", info, entity, "dest=" .. debug_pos(pos) .. " radius=" .. tostring(opts.radius or 0.5))
    return true
  end

  local function issue_targetless_protest_wander_command(info, entity, surface)
    if not info or not entity or not entity.valid then
      protest_debug_log("targetless-wander-skip-invalid-entity", info, entity)
      return false
    end
    surface = surface or entity.surface
    if not surface then
      protest_debug_log("targetless-wander-skip-no-surface", info, entity)
      return false
    end

    local origin = info.protest_anchor_position or entity.position
    local pos = nil
    local min_radius = 3
    local max_radius = 8

    for _ = 1, C.PROTEST_WANDER_ATTEMPTS do
      local angle = math.random() * (math.pi * 2)
      local radius = min_radius + math.random() * (max_radius - min_radius)
      local probe = {
        x = origin.x + math.cos(angle) * radius,
        y = origin.y + math.sin(angle) * radius,
      }
      pos = surface.find_non_colliding_position(entity.name, probe, 2, 0.5)
      if pos and distance_sq(pos, entity.position) > 1 then break end
      pos = nil
    end

    pos = pos or surface.find_non_colliding_position(entity.name, origin, 6, 0.5)
    if not pos then
      protest_debug_log("targetless-wander-skip-no-position", info, entity, "origin=" .. debug_pos(origin))
      return false
    end

    schedule_next_protest_step(info)
    info.protest_anchor_position = {x = pos.x, y = pos.y}
    info.protest_last_command_tick = game.tick
    info.protest_step_deadline_tick = game.tick + C.PROTEST_STEP_ACTIVE_TICKS
    info.protest_parked = nil
    protect_protesting_biter(info, entity, "wander-targetless")

    entity.commandable.set_command({
      type = defines.command.go_to_location,
      destination = pos,
      radius = 0.5,
      distraction = defines.distraction.none,
    })
    protest_debug_log("targetless-wander-command-issued", info, entity, "origin=" .. debug_pos(origin) .. " dest=" .. debug_pos(pos))
    return true
  end

  local function update_arrived_protest(info, entity)
    if not info or not entity or not entity.valid then return end
    if not info.arrived_at_building or not info.target_building or not info.target_building.valid then return end

    protect_protesting_biter(info, entity, "update-arrived", {active = not info.protest_parked})
    disable_protest_target(info.target_building, entity.unit_number)

    local anchor_pos = info.protest_anchor_position or get_protest_arrival_position(info) or info.target_building.position
    local anchor_dist = distance_sq(entity.position, anchor_pos)
    local target_dist = distance_sq(entity.position, info.target_building.position)

    if info.protest_parked then
      entity.active = false
    elseif anchor_dist <= 0.5 * 0.5 or game.tick >= (info.protest_step_deadline_tick or 0) or not entity.active then
      park_protester(info, entity)
    elseif game.tick > math.max(info.protest_arrival_tick or 0, info.protest_last_command_tick or 0)
       and target_dist > C.PROTEST_MAX_DISTANCE_FROM_TARGET * C.PROTEST_MAX_DISTANCE_FROM_TARGET then
      issue_protest_wander_command(info, entity, {
        destination = anchor_pos,
        origin = entity.position,
        radius = 0.1,
      })
    elseif game.tick >= (info.next_protest_wander_tick or 0) then
      issue_protest_wander_command(info, entity, {
        origin = anchor_pos,
        radius = 0.25,
      })
    end

  end

  local function mark_protester_arrived(info, entity)
    if not info or not entity or not entity.valid then return false end
    if not info.target_building or not info.target_building.valid then return false end

    info.arrived_at_building = true
    info.protest_arrival_tick = game.tick
    info.protest_route_started_tick = nil
    info.protest_route_last_progress_tick = nil
    info.protest_route_best_distance_sq = nil
    info.protest_route_goal_target_unit_number = nil
    info.protest_route_hop_waypoint = nil
    info.protest_route_hop_goal = nil
    info.protest_route_hop_target = nil
    info.protest_route_retry_tick = nil
    info.protest_route_retry_goal = nil
    info.protest_route_retry_target = nil
    info.protest_clear_route_retry_allowed = nil
    info.protest_pipe_gap_route_active = nil
    unindex_protest_obstacle_route(info, entity)
    protect_protesting_biter(info, entity, "arrived")
    disable_protest_target(info.target_building, entity.unit_number)
    park_protester(info, entity)
    render.ensure_protest_rendering(info)
    render.notify_players_of_protest(info)
    return true
  end

  local function resume_en_route_protest(info, entity)
    if not info or not entity or not entity.valid then return false end
    if info.arrived_at_building then return false end
    if not info.target_building or not info.target_building.valid then return false end

    protect_protesting_biter(info, entity, "resume")
    local arrival_pos = get_protest_arrival_position(info) or info.target_building.position
    if not arrival_pos then return false end

    if distance_sq(entity.position, arrival_pos) <= C.PROTEST_ARRIVAL_DISTANCE * C.PROTEST_ARRIVAL_DISTANCE then
      return mark_protester_arrived(info, entity)
    end

    return issue_protest_wander_command(info, entity, {
      destination = arrival_pos,
      origin = entity.position,
      radius = 0.5,
    })
  end

  local function begin_protest_approach(info, entity, target, destination, radius, opts)
    if not info or not entity or not entity.valid then
      protest_debug_log("begin-approach-skip-invalid-entity", info, entity, "dest=" .. debug_pos(destination))
      return false
    end
    if not target or not target.valid or not destination then
      protest_debug_log("begin-approach-skip-invalid-target-or-dest", info, entity, debug_target_summary(target) .. " dest=" .. debug_pos(destination))
      return false
    end

    local previous_target = info.target_building
    local previous_arrived = info.arrived_at_building
    local previous_retry_tick = info.next_protest_target_retry_tick

    info.target_building = target
    info.arrived_at_building = nil
    info.next_protest_target_retry_tick = nil

    opts = opts or {}
    if issue_protest_wander_command(info, entity, {
      destination = destination,
      origin = entity.position,
      radius = radius or 2,
      preserve_protest_anchor = opts.preserve_protest_anchor,
      route_goal = opts.route_goal,
    }) then
      protest_debug_log("begin-approach-command-ok", info, entity, debug_target_summary(target) .. " dest=" .. debug_pos(destination))
      return true
    end

    info.target_building = previous_target
    info.arrived_at_building = previous_arrived
    info.next_protest_target_retry_tick = previous_retry_tick
    protest_debug_log("begin-approach-command-failed-restored", info, entity, debug_target_summary(target) .. " dest=" .. debug_pos(destination))
    return false
  end

  local function begin_protest_route_toward_goal(info, entity, target, goal, radius)
    if not info or not entity or not entity.valid or not target or not target.valid or not goal then
      return false
    end
    info.protest_route_retry_tick = nil
    info.protest_route_retry_goal = nil
    info.protest_route_retry_target = nil
    info.protest_clear_route_retry_allowed = true
    info.protest_anchor_position = {x = goal.x, y = goal.y}

    local dx = goal.x - entity.position.x
    local dy = goal.y - entity.position.y
    local distance_squared = dx * dx + dy * dy
    local hop_distance = C.PROTEST_ROUTE_HOP_DISTANCE or 64
    if distance_squared > hop_distance * hop_distance then
      local distance = math.sqrt(distance_squared)
      local probe = {
        x = entity.position.x + dx * hop_distance / distance,
        y = entity.position.y + dy * hop_distance / distance,
      }
      local waypoint = entity.surface.find_non_colliding_position(
        entity.name,
        probe,
        8,
        0.5
      )
      if waypoint
         and distance_sq(waypoint, entity.position) > 4
         and distance_sq(waypoint, goal) < distance_squared
         and begin_protest_approach(
           info,
           entity,
           target,
           waypoint,
           0.5,
           {
             preserve_protest_anchor = true,
             route_goal = goal,
           }
         ) then
        info.protest_route_hop_waypoint = {x = waypoint.x, y = waypoint.y}
        info.protest_route_hop_goal = {x = goal.x, y = goal.y}
        info.protest_route_hop_target = target
        return true
      end
    end

    info.protest_route_hop_waypoint = nil
    info.protest_route_hop_goal = nil
    info.protest_route_hop_target = nil
    return begin_protest_approach(info, entity, target, goal, radius or 2)
  end

  local function defer_clear_protest_route_retry(info, entity, target, goal)
    if not info or not entity or not entity.valid or not target or not target.valid or not goal then
      return false
    end
    local unit_number = entity.unit_number or info.tracked_unit_number or 0
    info.target_building = target
    info.arrived_at_building = nil
    info.protest_parked = nil
    info.protest_anchor_position = {x = goal.x, y = goal.y}
    info.protest_route_hop_waypoint = nil
    info.protest_route_hop_goal = nil
    info.protest_route_hop_target = nil
    info.protest_route_retry_goal = {x = goal.x, y = goal.y}
    info.protest_route_retry_target = target
    info.protest_route_retry_tick = game.tick
      + (C.PROTEST_CLEAR_ROUTE_RETRY_TICKS or 60)
      + (unit_number % 60)
    entity.active = false
    render.ensure_protest_rendering(info)
    return true
  end

  local function process_deferred_protest_route(info, entity)
    local retry_tick = info and info.protest_route_retry_tick or nil
    if not retry_tick then return false end
    if not entity or not entity.valid then return true end
    if game.tick < retry_tick then
      entity.active = false
      return true
    end
    local target = info.protest_route_retry_target
    local goal = info.protest_route_retry_goal
    info.protest_route_retry_tick = nil
    info.protest_route_retry_target = nil
    info.protest_route_retry_goal = nil
    if is_protest_target_allowed(target, entity)
       and goal
       and begin_protest_route_toward_goal(info, entity, target, goal, 2) then
      return true
    end
    if is_protest_target_allowed(target, entity) and goal then
      return defer_clear_protest_route_retry(info, entity, target, goal)
    end
    return false
  end

  local function recover_false_protest_arrival(info, entity)
    if not info or not info.arrived_at_building or not entity or not entity.valid then return false end
    local target = info.target_building
    if not target or not target.valid then return false end
    local max_distance = C.PROTEST_FALSE_ARRIVAL_RECOVERY_DISTANCE or 32
    if distance_sq(entity.position, target.position) <= max_distance * max_distance then
      return false
    end

    -- Builds affected by the old gap-anchor bug saved protesters as arrived at
    -- the wall. Reopen that false claim and continue toward the real building.
    release_protest_target(target, entity.unit_number)
    info.arrived_at_building = nil
    info.protest_arrival_tick = nil
    info.protest_parked = nil
    info.protest_step_deadline_tick = nil
    info.protest_anchor_position = nil
    info.protest_path_retry_deferred = nil

    local goal = info.protest_pipe_gap_goal
    local gap_waypoint = info.protest_pipe_gap_waypoint
    local reasonable_goal_distance = max_distance
    local arrival_distance = C.PROTEST_ARRIVAL_DISTANCE or 2.25
    local goal_is_stale_gap = goal and gap_waypoint
      and distance_sq(goal, gap_waypoint) <= arrival_distance * arrival_distance
    if goal_is_stale_gap
       or not goal
       or distance_sq(goal, target.position) > reasonable_goal_distance * reasonable_goal_distance then
      goal = target.position
    end
    info.protest_pipe_gap_waypoint = nil
    info.protest_pipe_gap_goal = nil
    info.protest_pipe_gap_goal_target = nil
    info.protest_pipe_gap_started_tick = nil
    info.protest_pipe_gap_route_active = nil
    unindex_protest_obstacle_route(info, entity)
    entity.active = true
    return begin_protest_route_toward_goal(info, entity, target, goal, 2)
  end

  local function begin_pending_protest_approach(info, entity)
    return begin_protest_approach(
      info,
      entity,
      info and info.pending_protest_reserved_target,
      info and info.pending_protest_reserved_position,
      2
    )
  end

  local function clear_protest_approach(info, target)
    if not info then return end
    if target and info.target_building and not same_protest_target(info.target_building, target) then return end

    protest_debug_log("clear-approach", info, info.entity, debug_target_summary(target))
    info.target_building = nil
    info.arrived_at_building = nil
    info.next_protest_wander_tick = nil
    info.protest_anchor_position = nil
    info.protest_last_command_tick = nil
    info.protest_arrival_tick = nil
    info.protest_step_deadline_tick = nil
    info.protest_parked = nil
    info.protest_route_started_tick = nil
    info.protest_route_last_progress_tick = nil
    info.protest_route_best_distance_sq = nil
    info.protest_route_goal_target_unit_number = nil
    info.protest_route_hop_waypoint = nil
    info.protest_route_hop_goal = nil
    info.protest_route_hop_target = nil
    info.protest_route_retry_tick = nil
    info.protest_route_retry_goal = nil
    info.protest_route_retry_target = nil
    info.protest_clear_route_retry_allowed = nil
    info.protest_pipe_gap_waypoint = nil
    info.protest_pipe_gap_goal = nil
    info.protest_pipe_gap_goal_target = nil
    info.protest_pipe_gap_started_tick = nil
    info.protest_pipe_gap_next_check_tick = nil
    info.protest_pipe_gap_route_active = nil
    unindex_protest_obstacle_route(info, info.entity)
  end

  local function begin_protest_obstacle_attack(info, entity, candidate, load_factor, opts)
    if not info or not entity or not entity.valid or not candidate or not candidate.pos then return false end
    opts = opts or {}

    info.protest_path_retry_deferred = nil

    local obstacle = find_nearby_protest_obstacle(entity, candidate.pos, candidate.target, nil)
    local obstacle_kind = "building"
    if not obstacle then
      obstacle = find_aligned_pipe_breach(entity, candidate.pos)
      obstacle_kind = obstacle and "pipe-breach" or nil
    end
    if not obstacle then
      if info.protest_clear_route_retry_allowed then
        -- A wall that was just crossed is now behind the unit, so no eligible
        -- forward obstruction is the normal post-gap case. Preserve the real
        -- target and retry it in bounded route hops instead of discarding the
        -- grievance and parking at the opening.
        return defer_clear_protest_route_retry(
          info,
          entity,
          candidate.target,
          candidate.pos
        )
      end
      if opts.try_next_candidate_on_no_obstacle then
        return false
      end
      -- A route that was never validated and has not crossed a known
      -- obstruction remains on the low-cost target retry path.
      info.pending_protest_candidates = nil
      clear_protest_approach(info, candidate.target)
      defer_protest_target_retry(
        info,
        entity,
        C.PROTEST_OBSTACLE_RETRY_TICKS or (3 * 60),
        load_factor
      )
      render.ensure_protest_rendering(info)
      return true
    end

    if obstacle_kind == "pipe-breach"
       and not opts.skip_gap
       and game.tick >= (info.protest_pipe_gap_failed_until_tick or 0) then
      local gap_waypoint = find_pipe_wall_gap_waypoint(entity, candidate.pos, obstacle)
      if gap_waypoint then
        local gap_limit = load_factor > 1
          and (C.PROTEST_PIPE_GAP_ROUTE_LIMIT_HIGH_LOAD or 8)
          or (C.PROTEST_OBSTACLE_ATTACKER_LIMIT or 12)
        if count_active_protest_pipe_gap_routes() >= math.max(1, gap_limit) then
          defer_protest_target_retry(info, entity, C.PROTEST_PATH_BUSY_RETRY_TICKS or 60, load_factor)
          return true
        end
        clear_protest_approach(info, candidate.target)
        if begin_protest_approach(
          info,
          entity,
          candidate.target,
          gap_waypoint,
          0.5,
          {
            preserve_protest_anchor = true,
            route_goal = candidate.pos,
          }
        ) then
          info.pending_protest_candidates = nil
          info.protest_pipe_gap_waypoint = {x = gap_waypoint.x, y = gap_waypoint.y}
          info.protest_pipe_gap_goal = {x = candidate.pos.x, y = candidate.pos.y}
          info.protest_pipe_gap_goal_target = candidate.target
          info.protest_pipe_gap_started_tick = game.tick
          info.protest_pipe_gap_route_active = true
          index_protest_obstacle_route(info, entity)
          return true
        end
      end
    end

    -- Capacity rejection is an administrative failure, not a pathfinding
    -- obstruction. More generally, normal-mode protests only disable their
    -- selected target; destructive route clearing is a hard-mode escalation.
    -- In both cases the biter keeps the grievance and retries harmlessly.
    if info.allow_obstacle_breach == false or not hard_mode_enabled() then
      if not hard_mode_enabled() and opts.try_next_candidate_on_no_obstacle then
        -- In normal mode the nearby building is not a breach candidate at all.
        -- Let the caller validate another protest destination immediately
        -- instead of repeatedly selecting the same unreachable printer row.
        return false
      end
      info.pending_protest_candidates = nil
      clear_protest_approach(info, candidate.target)
      defer_protest_target_retry(
        info,
        entity,
        C.PROTEST_OBSTACLE_RETRY_TICKS or (3 * 60),
        load_factor
      )
      render.ensure_protest_rendering(info)
      return true
    end

    info.pending_protest_candidates = nil
    clear_protest_approach(info, candidate.target)

    local configured_attacker_limit = load_factor > 1
      and (C.PROTEST_OBSTACLE_ATTACKER_LIMIT_HIGH_LOAD or 1)
      or (C.PROTEST_OBSTACLE_ATTACKER_LIMIT or 12)
    local attacker_limit = math.max(1, configured_attacker_limit)
    if count_active_protest_obstacle_attackers() >= attacker_limit then
      defer_protest_target_retry(info, entity, C.PROTEST_PATH_BUSY_RETRY_TICKS or 60, load_factor)
      return true
    end

    local commandable = entity.commandable
    if not commandable or not commandable.set_command then
      defer_protest_target_retry(info, entity, C.PROTEST_PATH_BUSY_RETRY_TICKS or 60, load_factor)
      return true
    end

    local attack_force = deps.get_hard_mode_attack_force and deps.get_hard_mode_attack_force()
      or (game.forces and game.forces.enemy)
      or deps.get_biter_force()
    entity.force = attack_force
    entity.destructible = true
    entity.active = true
    info.protest_obstacle_attacking = true
    info.protest_obstacle_goal = {x = candidate.pos.x, y = candidate.pos.y}
    info.protest_obstacle_goal_target = candidate.target
    info.protest_obstacle_target = obstacle
    info.protest_obstacle_target_kind = obstacle_kind
    info.protest_obstacle_target_unit_number = obstacle.unit_number
    info.protest_obstacle_command_failures = 0
    info.protest_obstacle_attack_tick = game.tick
    local unit_number = entity.unit_number or info.tracked_unit_number or 0
    if obstacle_kind == "pipe-breach" then
      info.protest_pipe_gap_next_check_tick = game.tick
        + (C.PROTEST_PIPE_GAP_RECHECK_TICKS or (2 * 60))
        + (unit_number % 60)
    end
    local retry_ticks = C.PROTEST_OBSTACLE_RETRY_TICKS or (3 * 60)
    info.next_protest_target_retry_tick = game.tick + retry_ticks + (unit_number % 60)
    info.next_protest_wander_tick = info.next_protest_target_retry_tick
    index_protest_obstacle_route(info, entity)
    render.ensure_protest_rendering(info)
    issue_protest_obstacle_attack_command(info, entity)
    return true
  end

  local function resume_protest_route_after_breach(info, entity, surface)
    if not info or not entity or not entity.valid then return false end
    local goal = info.protest_obstacle_goal
    local goal_target = info.protest_obstacle_goal_target
    clear_protest_obstacle_attack_runtime(info, entity)
    if is_protest_target_allowed(goal_target, entity) and goal then
      return begin_protest_route_toward_goal(info, entity, goal_target, goal, 2)
    end
    if assign_protest_target(surface or entity.surface, info, entity) then
      return true
    end
    if not info.protest_path_retry_deferred then
      issue_targetless_protest_wander_command(info, entity, surface or entity.surface)
    end
    return true
  end

  local function process_stalled_protest_route(info, entity, load_factor)
    if not info or info.state ~= "protesting" or info.arrived_at_building then return false end
    if info.pending_path_request_id or info.protest_obstacle_attacking then return false end
    local target = info.target_building
    if not is_protest_target_allowed(target, entity) then return false end
    local destination = get_protest_arrival_position(info) or target.position
    if not destination then return false end

    local distance = distance_sq(entity.position, destination)
    local stall_ticks = C.PROTEST_ROUTE_STALL_TICKS or (10 * 60)
    if not info.protest_route_started_tick
       or info.protest_route_goal_target_unit_number ~= target.unit_number then
      -- Existing protesters have no progress metadata. They are precisely the
      -- population that can remain parked at a pipe forever, so inspect them
      -- immediately while retaining the normal grace period for new routes.
      info.protest_route_started_tick = game.tick - stall_ticks
      info.protest_route_last_progress_tick = game.tick - stall_ticks
      info.protest_route_best_distance_sq = distance
      info.protest_route_goal_target_unit_number = target.unit_number
    end

    local progress_distance = C.PROTEST_ROUTE_PROGRESS_DISTANCE or 1
    local progress_sq = progress_distance * progress_distance
    if not info.protest_route_best_distance_sq
       or distance + progress_sq < info.protest_route_best_distance_sq then
      info.protest_route_best_distance_sq = distance
      info.protest_route_last_progress_tick = game.tick
      return false
    end
    if game.tick - (info.protest_route_last_progress_tick or info.protest_route_started_tick)
       < stall_ticks then
      return false
    end

    local stalled_gap_waypoint = info.protest_pipe_gap_waypoint ~= nil
    if stalled_gap_waypoint then
      info.protest_pipe_gap_failed_until_tick = game.tick
        + (C.PROTEST_OBSTACLE_RETRY_TICKS or (3 * 60))
    end
    return begin_protest_obstacle_attack(info, entity, {
      target = target,
      pos = {x = destination.x, y = destination.y},
    }, load_factor, {skip_gap = stalled_gap_waypoint})
  end

  local function recover_stale_protest_path_request(info, entity, load_factor)
    local request_id = info and info.pending_path_request_id or nil
    if not request_id then return false end
    local request = storage.path_requests and storage.path_requests[request_id] or nil
    if not request or request.kind ~= "protest_target" then
      info.pending_path_request_id = nil
      info.pending_protest_candidates = nil
      clear_pending_protest_reservation(info)
      defer_protest_target_retry(info, entity, C.PROTEST_PATH_BUSY_RETRY_TICKS or 60, load_factor)
      return true
    end

    local timeout_ticks = C.PROTEST_PATH_REQUEST_TIMEOUT_TICKS or (10 * 60)
    -- Requests saved by older builds have no timestamp. They are precisely the
    -- inherited backlog this recovery path exists to detach.
    local requested_tick = request.requested_tick or (game.tick - timeout_ticks)
    if game.tick - requested_tick < timeout_ticks then return false end

    local candidates = info.pending_protest_candidates or {}
    local candidate = candidates[request.candidate_index]
    clear_pending_path_request(info)
    info.pending_protest_candidates = nil

    if candidate and is_protest_target_allowed(candidate.target, entity) then
      return begin_protest_obstacle_attack(info, entity, candidate, load_factor)
    end

    if candidate then
      clear_protest_approach(info, candidate.target)
    end
    defer_protest_target_retry(info, entity, C.PROTEST_PATH_BUSY_RETRY_TICKS or 60, load_factor)
    return true
  end

  local function collect_protest_target_candidates(surface, info, entity, avoid_target, avoid_target_snapshot)
    local top_candidates = {}
    local seen = {}
    local snapshot = get_protester_snapshot()
    local entity_pos = entity.position
    local high_load = get_protest_load_factor(snapshot.total_protesters or 0) > 1
    local top_limit = high_load and 1 or (C.PROTEST_TARGET_TOP_K or 10)
    local position_attempt_limit = high_load and 1 or nil

    local function raw_candidate_is_better(a, b)
      if a.avoided ~= b.avoided then return not a.avoided end
      -- Prefer buildings not already being protested; fall back to protested ones if needed.
      local a_protested = a.claimed > 0
      local b_protested = b.claimed > 0
      if a_protested ~= b_protested then return not a_protested end
      return a.dist < b.dist
    end

    local function insert_top_candidate(candidate)
      local inserted = false
      for index, existing in ipairs(top_candidates) do
        if raw_candidate_is_better(candidate, existing) then
          table.insert(top_candidates, index, candidate)
          inserted = true
          break
        end
      end
      if not inserted and #top_candidates < top_limit then
        top_candidates[#top_candidates + 1] = candidate
      end
      if #top_candidates > top_limit then
        top_candidates[#top_candidates] = nil
      end
    end

    local function scan_target_pool(target_pool)
      for _, target in ipairs(target_pool) do
        local target_id = is_eligible_protest_target(target) and target.unit_number or nil
        if target_id and not seen[target_id] then
          seen[target_id] = true

          local claimed = snapshot.claimed_counts[target_id] or 0
          local allow_overflow = high_load
            and claimed >= C.PROTEST_TARGET_MAX_PROTESTERS
          if claimed < C.PROTEST_TARGET_MAX_PROTESTERS or allow_overflow then
            local dist = distance_sq(target.position, entity_pos)
            local avoided = (avoid_target and same_protest_target(target, avoid_target) or false)
              or same_protest_target_snapshot(target, avoid_target_snapshot)
            insert_top_candidate({
              target = target,
              claimed = claimed,
              dist = dist,
              avoided = avoided,
              allow_overflow = allow_overflow,
            })
          end
        end
      end
    end

    local target_pool = high_load
      and get_spatial_protest_targets(surface, entity_pos, snapshot)
      or get_cached_protest_targets(surface)
    scan_target_pool(target_pool)

    -- Only for the top candidates, try to find a valid wander position.
    -- We limit this severely because find_non_colliding_position is expensive.
    local candidates = {}
    
    for _, raw in ipairs(top_candidates) do
      local target = raw.target
      local pos = pick_protest_wander_position(
        surface,
        entity,
        target,
        entity_pos,
        snapshot,
        position_attempt_limit
      )
      if not pos and raw.allow_overflow then
        pos = surface.find_non_colliding_position(
          entity.name,
          target.position,
          C.PROTEST_OVERFLOW_WANDER_SEARCH_RADIUS or 12,
          0.5
        )
      end
      if pos then
        candidates[#candidates + 1] = {
          target = target,
          pos = pos,
          load = snapshot.protester_counts[raw.target.unit_number] or 0,
          claimed = raw.claimed,
          dist = raw.dist,
          avoided = raw.avoided,
          allow_overflow = raw.allow_overflow,
        }
        if #candidates >= top_limit then break end
      end
    end

    return candidates
  end

  local function request_next_protest_target_path(info, entity, start_index, path_budget_reserved)
    if not info or not entity or not entity.valid then
      protest_debug_log("request-path-skip-invalid-entity", info, entity, "start_index=" .. tostring(start_index))
      return false
    end
    local candidates = info.pending_protest_candidates
    if not candidates then
      protest_debug_log("request-path-skip-no-candidates", info, entity, "start_index=" .. tostring(start_index))
      return false
    end

    clear_pending_path_request(info)
    local snapshot = get_protester_snapshot()
    local load_factor = get_protest_load_factor(snapshot.total_protesters or 0)

    if not path_budget_reserved and not reserve_high_load_path_request(load_factor) then
      info.pending_protest_candidates = nil
      defer_protest_target_retry(info, entity, C.PROTEST_PATH_BUSY_RETRY_TICKS or 60, load_factor)
      protest_debug_log("request-path-deferred-high-load", info, entity, "load_factor=" .. tostring(load_factor))
      return false
    end

    for index = start_index, #candidates do
      local candidate = candidates[index]
      if candidate and candidate.target.valid then
        local target_id = candidate.target.unit_number
        local claimed = target_id
          and (snapshot.claimed_counts[target_id] or 0)
          or 0
        if claimed >= C.PROTEST_TARGET_MAX_PROTESTERS
           and not candidate.allow_overflow then
          goto continue_candidate
        end

        local request_id = entity.surface.request_path{
          bounding_box = entity.prototype.collision_box,
          collision_mask = entity.prototype.collision_mask,
          start = entity.position,
          goal = candidate.pos,
          force = entity.force.name,
          radius = 2,
          can_open_gates = true,
          entity_to_ignore = entity,
          pathfind_flags = {
            cache = false,
            low_priority = true,
          },
        }
        storage.path_requests = storage.path_requests or {}
        storage.path_requests[request_id] = {
          unit_number = entity.unit_number,
          kind = "protest_target",
          candidate_index = index,
          requested_tick = game.tick,
        }
        adjust_outstanding_protest_path_requests(1)
        info.pending_path_request_id = request_id
        info.pending_protest_reserved_target = candidate.target
        info.pending_protest_reserved_position = {x = candidate.pos.x, y = candidate.pos.y}
        protest_debug_log(
          "request-path",
          info,
          entity,
          "request_id=" .. tostring(request_id)
            .. " candidate_index=" .. tostring(index)
            .. " candidate_count=" .. tostring(#candidates)
            .. " claimed=" .. tostring(claimed)
            .. " dest=" .. debug_pos(candidate.pos)
            .. " "
            .. debug_target_summary(candidate.target)
        )
        return true
      end
      ::continue_candidate::
    end

    info.pending_protest_candidates = nil
    release_high_load_path_request_reservation(load_factor)
    if load_factor > 1 then
      defer_protest_target_retry(info, entity, C.PROTEST_TARGET_RETRY_TICKS, load_factor)
    else
      schedule_protest_target_retry(info, entity, C.PROTEST_TARGET_RETRY_TICKS, load_factor)
    end
    protest_debug_log("request-path-no-candidates-left", info, entity, "start_index=" .. tostring(start_index))
    return false
  end

  assign_protest_target = function(surface, info, entity)
    if not surface or not info or not entity or not entity.valid then
      protest_debug_log("assign-target-skip-invalid-input", info, entity, "surface=" .. tostring(surface and surface.index or nil))
      return false
    end
    local snapshot = get_protester_snapshot()
    local load_factor = get_protest_load_factor(snapshot.total_protesters or 0)

    -- Saved wall-side protesters must not wait behind unrelated long-distance
    -- validators forever. Under load, an adjacent ordinary pipe permits only
    -- the same capped local recovery used after a real route failure. This
    -- path does not submit native validation work and cannot exceed the global
    -- bounded local gap/breach slots.
    if load_factor > 1 and not info.target_building and find_nearby_attackable_pipe(entity) then
      local local_candidates = collect_protest_target_candidates(surface, info, entity)
      local local_candidate = local_candidates[1]
      if local_candidate and find_aligned_pipe_breach(entity, local_candidate.pos) then
        info.pending_protest_candidates = nil
        if begin_protest_obstacle_attack(info, entity, local_candidate, load_factor) then
          return true
        end
      end
    end

    if not reserve_high_load_path_request(load_factor) then
      defer_protest_target_retry(info, entity, C.PROTEST_PATH_BUSY_RETRY_TICKS or 60, load_factor)
      protest_debug_log("assign-target-deferred-high-load", info, entity, "load_factor=" .. tostring(load_factor))
      return false
    end

    -- Admission must happen before reset: under load, hundreds of deferred
    -- protesters can become due together. Resetting them first destroyed and
    -- recreated their render objects every pacing pass even though almost all
    -- were immediately denied a path slot.
    local previous_target = info.target_building
    local avoided_target_snapshot = info.retarget_avoid_target_snapshot
    if not avoided_target_snapshot and previous_target and previous_target.valid then
      avoided_target_snapshot = snapshot_protest_target(previous_target)
    end
    info.retarget_avoid_target_snapshot = nil
    reset_protest_targeting(info, nil, {preserve_protest_identity = true})
    info.protest_path_retry_deferred = nil
    info.return_spawner = nil
    info.return_dest = nil

    local candidates = collect_protest_target_candidates(surface, info, entity, previous_target, avoided_target_snapshot)
    if #candidates == 0 then
      release_high_load_path_request_reservation(load_factor)
      if load_factor > 1 then
        defer_protest_target_retry(info, entity, C.PROTEST_TARGET_RETRY_TICKS, load_factor)
      else
        schedule_protest_target_retry(info, entity, C.PROTEST_TARGET_RETRY_TICKS, load_factor)
      end
      protest_debug_log("assign-target-no-candidates", info, entity, "surface=" .. tostring(surface.index))
      return false
    end

    info.pending_protest_candidates = candidates
    protest_debug_log("assign-target-candidates", info, entity, "count=" .. tostring(#candidates) .. " surface=" .. tostring(surface.index))
    return request_next_protest_target_path(info, entity, 1, true)
  end

  local function process_protest_obstacle_attack(surface, info, entity)
    if not info or not info.protest_obstacle_attacking then return false end
    if not entity or not entity.valid then
      clear_protest_obstacle_attack_runtime(info, entity)
      return true
    end
    if info.allow_obstacle_breach == false or not hard_mode_enabled() then
      clear_protest_obstacle_attack_runtime(info, entity)
      defer_protest_target_retry(info, entity, C.PROTEST_OBSTACLE_RETRY_TICKS or (3 * 60))
      return true
    end
    local target = info.protest_obstacle_target
    local target_is_valid = target and target.valid and (
      (info.protest_obstacle_target_kind == "pipe-breach" and is_attackable_pipe_breach(target, entity))
      or (info.protest_obstacle_target_kind ~= "pipe-breach" and is_attackable_protest_obstacle(
        target,
        entity,
        info.protest_obstacle_goal_target,
        nil
      ))
    )
    if target and target.valid and not target_is_valid then
      -- Saved attacks created by older versions may point at pipes or other
      -- infrastructure. Drop them before issuing another command.
      target = nil
      info.protest_obstacle_target = nil
      info.protest_obstacle_target_unit_number = nil
      info.protest_obstacle_command_pending = nil
      info.next_protest_obstacle_command_tick = game.tick
    end
    if target and target.valid then
      if info.protest_obstacle_target_kind == "pipe-breach"
         and game.tick >= (info.protest_pipe_gap_next_check_tick or 0) then
        local unit_number = entity.unit_number or info.tracked_unit_number or 0
        info.protest_pipe_gap_next_check_tick = game.tick
          + (C.PROTEST_PIPE_GAP_RECHECK_TICKS or (2 * 60))
          + (unit_number % 60)
        local goal = info.protest_obstacle_goal
        local goal_target = info.protest_obstacle_goal_target
        local gap_waypoint = find_pipe_wall_gap_waypoint(entity, goal, target)
        if gap_waypoint then
          clear_protest_obstacle_attack_runtime(info, entity)
          if begin_protest_approach(
            info,
            entity,
            goal_target,
            gap_waypoint,
            0.5,
            {
              preserve_protest_anchor = true,
              route_goal = goal,
            }
          ) then
            info.protest_pipe_gap_waypoint = {x = gap_waypoint.x, y = gap_waypoint.y}
            info.protest_pipe_gap_goal = {x = goal.x, y = goal.y}
            info.protest_pipe_gap_goal_target = goal_target
            info.protest_pipe_gap_started_tick = game.tick
            info.protest_pipe_gap_route_active = true
            index_protest_obstacle_route(info, entity)
            return true
          end
          return begin_protest_obstacle_attack(info, entity, {
            target = goal_target,
            pos = goal,
          }, get_protest_load_factor(count_protesters()), {skip_gap = true})
        end
      end
      entity.active = true
      if game.tick < (info.next_protest_obstacle_command_tick or 0) then
        return true
      end
      info.protest_obstacle_command_pending = nil
      issue_protest_obstacle_attack_command(info, entity)
      return true
    end

    if info.protest_obstacle_target_destroyed then
      return resume_protest_route_after_breach(info, entity, surface)
    end

    if not info.protest_obstacle_target_destroyed then
      -- Upgrade obstacle attackers already present in saves made by the first
      -- implementation, which stored only an unreachable destination.
      local obstacle = find_nearby_protest_obstacle(
        entity,
        info.protest_obstacle_goal,
        info.protest_obstacle_goal_target,
        nil
      )
      local obstacle_kind = "building"
      if not obstacle then
        obstacle = find_aligned_pipe_breach(entity, info.protest_obstacle_goal)
        obstacle_kind = obstacle and "pipe-breach" or nil
      end
      if obstacle then
        info.protest_obstacle_target = obstacle
        info.protest_obstacle_target_kind = obstacle_kind
        info.protest_obstacle_target_unit_number = obstacle.unit_number
        info.protest_obstacle_command_failures = 0
        issue_protest_obstacle_attack_command(info, entity)
        return true
      end
    end

    return resume_protest_route_after_breach(info, entity, surface)
  end

  local function reassign_protest_after_target_loss(info, surface, avoid_target_snapshot)
    if not info or info.state ~= "protesting" then return false end

    if avoid_target_snapshot then
      info.retarget_avoid_target_snapshot = avoid_target_snapshot
    end

    if info.entity and info.entity.valid then
      protect_protesting_biter(info, info.entity, "retarget-after-target-loss")
      return assign_protest_target(surface or info.entity.surface, info, info.entity)
    end

    local tracked_unit_number = info.tracked_unit_number
    reset_protest_targeting(info, tracked_unit_number)
    if tracked_unit_number then
      deps.untrack_waiting_biter(tracked_unit_number, info)
    end
    return false
  end

  local function find_revival_surface(info, fallback_surface)
    if info.target_building and info.target_building.valid then
      return info.target_building.surface
    end
    if info.last_known_surface_index then
      return game.get_surface(info.last_known_surface_index)
    end
    if info.desk_id then
      local desk = storage.admin_desks and storage.admin_desks[info.desk_id]
      if desk and desk.valid then
        return desk.surface
      end
    end
    if info.return_spawner and info.return_spawner.valid then
      return info.return_spawner.surface
    end
    if fallback_surface then return fallback_surface end
    return game.surfaces[1]
  end

  local function find_revival_position(b_id, info, surface)
    if not info or not surface then return nil end
    local entity_name = info.entity_name
    if not entity_name then return nil end

    if info.state == "protesting" and info.target_building and info.target_building.valid then
      local preferred = info.protest_anchor_position or info.last_known_position
      return (preferred and surface.find_non_colliding_position(entity_name, preferred, 1, 0.25))
        or pick_protest_wander_position(surface, {valid = true, name = entity_name}, info.target_building, preferred, get_protester_snapshot())
        or surface.find_non_colliding_position(entity_name, info.target_building.position, 6, 0.5)
    end

    if info.state == "waiting" and info.desk_id then
      local desk = storage.admin_desks and storage.admin_desks[info.desk_id]
      local queue_pos = desk and desk.valid and desk.surface == surface and zones.get_queue_pos(desk) or nil
      return zones.get_zone_position(surface, info.desk_id, entity_name, b_id)
        or zones.get_zone_position(surface, info.desk_id, entity_name, nil)
        or (queue_pos and surface.find_non_colliding_position(entity_name, queue_pos, 5, 0.5))
    end

    if info.state == "pathfinding" and info.desk_id then
      local desk = storage.admin_desks and storage.admin_desks[info.desk_id]
      local queue_pos = desk and desk.valid and desk.surface == surface and zones.get_queue_pos(desk) or nil
      return zones.get_zone_position(surface, info.desk_id, entity_name, b_id)
        or zones.get_zone_position(surface, info.desk_id, entity_name, nil)
        or (info.desk_dest and surface.find_non_colliding_position(entity_name, info.desk_dest, 1, 0.25))
        or (queue_pos and surface.find_non_colliding_position(entity_name, queue_pos, 5, 0.5))
        or info.desk_dest
    end

    local anchor = info.last_known_position or info.desk_dest or info.return_dest
    if anchor then
      return surface.find_non_colliding_position(entity_name, anchor, 6, 0.5) or anchor
    end

    return nil
  end

  local function revive_tracked_biter(b_id, info, fallback_surface)
    if not info or info.state == "returning_home" then return false end
    if info.state == "pathfinding" or info.state == "waiting" then
      return false
    end
    local surface = find_revival_surface(info, fallback_surface)
    local position = find_revival_position(b_id, info, surface)
    if not surface or not position or not info.entity_name then
      if info and info.hard_mode_attacking then
        hard_mode_log(
          info,
          info.entity,
          "revive-skip-missing-input",
          "unit=" .. tostring(b_id)
            .. " surface=" .. tostring(surface and surface.index or nil)
            .. " position=" .. tostring(position and deps.format_position(position) or "[nil]")
            .. " entity_name=" .. tostring(info and info.entity_name),
          {force = true}
        )
      end
      return false
    end

    if info.hard_mode_attacking then
      hard_mode_log(
        info,
        info.entity,
        "revive-start",
        "unit=" .. tostring(b_id)
          .. " surface=" .. tostring(surface.index)
          .. " position=" .. tostring(deps.format_position(position))
          .. " entity_name=" .. tostring(info.entity_name),
        {force = true}
      )
    end

    local replacement = surface.create_entity{
      name = info.entity_name,
      position = position,
      force = deps.biter_force_name,
    }
    if not replacement or not replacement.valid then
      if info.hard_mode_attacking then
        hard_mode_log(info, info.entity, "revive-create-failed", "unit=" .. tostring(b_id), {force = true})
      end
      return false
    end
    if deps.apply_managed_unit_settings then
      deps.apply_managed_unit_settings(replacement)
    end

    render.destroy_protest_rendering(info)
    info.entity = replacement
    info.next_revival_retry_tick = nil
    info.last_revive_tick = game.tick
    deps.remember_entity_tracking(info, replacement)
    if info.hard_mode_attacking then
      hard_mode_log(
        info,
        replacement,
        "revive-created",
        "old_unit=" .. tostring(b_id)
          .. " new_unit=" .. tostring(replacement.unit_number)
          .. " replacement=" .. hard_mode_entity_summary(replacement),
        {force = true}
      )
    end

    if info.desk_id then
      zones.reassign_slot(info.desk_id, b_id, replacement.unit_number)
      deps.unindex_biter_from_desk(info.desk_id, b_id)
      deps.index_biter_to_desk(info.desk_id, replacement.unit_number)
    end

    deps.replace_tracked_waiting_biter_unit_number(b_id, replacement.unit_number, info)

    if info.state == "waiting" then
      replacement.force = deps.get_biter_force()
      replacement.active = false
      deps.mark_desk_circuit_dirty(info.desk_id)
    elseif info.state == "pacified" then
      replacement.force = deps.get_biter_force()
      local desk = find_available_desk_for_info(info)
      if desk and deps.route_biter_to_desk(info, replacement, desk, {
        initial_frustration = info.frustration or get_pacified_frustration(),
      }) then
        clear_pacified_runtime(info)
      else
        maintain_pacified_entity(info, replacement)
        deps.mark_desk_circuit_dirty(info.desk_id)
      end
    elseif info.state == "pathfinding" then
      replacement.force = deps.get_biter_force()
      local desk = storage.admin_desks and storage.admin_desks[info.desk_id]
      if desk and desk.valid and deps.finalize_pathfinding_biter_arrival(info, desk, "revive") then
        deps.mark_desk_circuit_dirty(info.desk_id)
      else
        local desk_dest = (desk and desk.valid and deps.get_desk_waiting_destination(replacement, desk, replacement.unit_number)) or info.desk_dest
        if desk_dest then
          info.desk_dest = desk_dest
          deps.issue_desk_route_command(replacement, desk_dest)
        else
          replacement.active = false
        end
        deps.mark_desk_circuit_dirty(info.desk_id)
      end
    elseif info.state == "protesting" then
      clear_pending_path_request(info)
      clear_pacified_runtime(info)
      if info.hard_mode_attacking then
        hard_mode_log(info, replacement, "revive-maintain-attack", "old_unit=" .. tostring(b_id), {force = true})
        maintain_hard_mode_attack(info, replacement, "revive")
        return true
      end
      protect_protesting_biter(info, replacement, "revive")
      if info.target_building and info.target_building.valid then
        if info.arrived_at_building then
          working_hours.transfer_protest_target(info.target_building, b_id, replacement.unit_number)
          disable_protest_target(info.target_building, replacement.unit_number)
          render.ensure_protest_rendering(info)
          park_protester(info, replacement)
        else
          local dest = surface.find_non_colliding_position(info.entity_name, info.target_building.position, 3, 0.5) or info.target_building.position
          replacement.commandable.set_command({
            type = defines.command.go_to_location,
            destination = dest,
            radius = 2,
            distraction = defines.distraction.none,
          })
        end
      else
        assign_protest_target(surface, info, replacement)
      end
    end

    return true
  end

  function controller.refresh_protest_notifications(player)
    storage.protest_alert_sound_tick_by_player = storage.protest_alert_sound_tick_by_player or {}
    if player then
      storage.protest_alert_sound_tick_by_player[player.index] = nil
    else
      storage.protest_alert_sound_tick_by_player = {}
    end

    for unit_number in pairs(deps.get_waiting_biter_state_set("protesting")) do
      local info = storage.waiting_biters and storage.waiting_biters[unit_number]
      if info and info.state == "protesting" then
        if player then
          info.protest_alerted_players = info.protest_alerted_players or {}
          info.protest_alerted_players[player.index] = nil
        else
          info.protest_alerted_players = nil
        end

        if info.target_building and info.target_building.valid then
          if info.arrived_at_building and not info.hard_mode_attacking then
            disable_protest_target(info.target_building, unit_number)
          end
          render.ensure_protest_rendering(info)
          render.ensure_protest_chart_tag(info, player)
          render.notify_players_of_protest(info, player)
        end
      end
    end
  end

  function controller.on_protest_target_removed(target)
    if not target or not target.valid then return end
    local removed_snapshot = snapshot_protest_target(target)
    local fallback_surface = target.surface

    -- Desk-bound visitors keep the desk as their destination. Destroying the
    -- assigned pipe merely resumes that route; it does not convert the pipe
    -- into a protest target or wake unrelated visitors.
    for unit_number in pairs(storage.desk_route_breach_attackers or {}) do
      local info = storage.waiting_biters and storage.waiting_biters[unit_number]
      if info and info.desk_route_breach_attacking then
        local obstacle = info.desk_route_breach_target
        local same_obstacle = obstacle == target
          or (target.unit_number
            and info.desk_route_breach_target_unit_number == target.unit_number)
        if same_obstacle and info.entity and info.entity.valid then
          resume_desk_route_after_breach(info, info.entity)
        end
      else
        storage.desk_route_breach_attackers[unit_number] = nil
      end
    end

    -- Only attackers assigned to the destroyed obstruction wake immediately.
    -- Waking the entire breach crew for every building death recreated the same
    -- synchronized pathfinding burst that this fallback is meant to prevent.
    for unit_number in pairs(storage.protest_obstacle_attackers or {}) do
      local info = storage.waiting_biters and storage.waiting_biters[unit_number]
      if info and info.protest_obstacle_attacking then
        local obstacle = info.protest_obstacle_target
        local goal_target = info.protest_obstacle_goal_target
        local same_obstacle = obstacle == target
          or (target.unit_number
            and info.protest_obstacle_target_unit_number == target.unit_number)
        local same_goal = same_protest_target(goal_target, target)
        if same_obstacle then
          info.protest_obstacle_target = nil
          info.protest_obstacle_target_unit_number = nil
          info.protest_obstacle_target_destroyed = true
          info.protest_obstacle_command_pending = nil
          info.next_protest_obstacle_command_tick = game.tick
          info.next_protest_target_retry_tick = game.tick
          if info.entity and info.entity.valid then
            resume_protest_route_after_breach(info, info.entity, target.surface)
          end
        elseif same_goal then
          -- The obstruction still exists, but the grievance beyond it does
          -- not. Stop the now-pointless demolition and select a live target.
          clear_protest_obstacle_attack_runtime(info, info.entity)
          reassign_protest_after_target_loss(info, fallback_surface, removed_snapshot)
        end
      else
        storage.protest_obstacle_attackers[unit_number] = nil
      end
    end

    if not protest_target_name_set[target.name]
       and not protest_target_type_set[target.type] then
      return
    end

    local impacted = {}
    if target.unit_number and storage.protest_target_active_states then
      storage.protest_target_active_states[target.unit_number] = nil
    end

    for unit_number in pairs(deps.get_waiting_biter_state_set("protesting")) do
      local info = storage.waiting_biters and storage.waiting_biters[unit_number]
      if info
         and info.state == "protesting"
         and same_protest_target(info.target_building, target) then
        impacted[#impacted + 1] = info
      end
    end

    for _, info in ipairs(impacted) do
      if info.hard_mode_attacking and info.entity and info.entity.valid then
        info.target_building = nil
        info.arrived_at_building = nil
        maintain_hard_mode_attack(info, info.entity, "target-removed")
      else
        reassign_protest_after_target_loss(info, fallback_surface, removed_snapshot)
      end
    end
  end

  function controller.reroute_desk_biters(desk_id, surface)
    deps.ensure_desk_biters()
    local biters_to_reroute = {}
    local seen = {}
    local desk_set = storage.desk_biters[desk_id]
    if desk_set then
      for b_id in pairs(desk_set) do
        local info = storage.waiting_biters[b_id]
        if info and info.entity and info.entity.valid then
          biters_to_reroute[#biters_to_reroute + 1] = {b_id = b_id, info = info}
          seen[b_id] = true
        end
      end
    end

    for b_id, info in pairs(storage.waiting_biters or {}) do
      if not seen[b_id]
         and info
         and info.desk_id == desk_id
         and info.entity
         and info.entity.valid then
        biters_to_reroute[#biters_to_reroute + 1] = {b_id = b_id, info = info}
        seen[b_id] = true
      end
    end

    if desk_set then
      for b_id in pairs(desk_set) do
        if not seen[b_id] then
          deps.unindex_biter_from_desk(desk_id, b_id)
        end
      end
    end

    if #biters_to_reroute == 0 then return end

    local other_desks = deps.get_cached_desks()

    for _, entry in ipairs(biters_to_reroute) do
      local info = entry.info
      local biter = info.entity
      zones.release_slot(desk_id, entry.b_id)
      deps.unindex_biter_from_desk(desk_id, entry.b_id)

      local reassigned = false
      for _, other_desk in ipairs(other_desks) do
        if other_desk.valid and other_desk.unit_number ~= desk_id
           and zones.get_available_slots(other_desk.unit_number) > 0 then
          reassigned = deps.route_biter_to_desk(info, biter, other_desk)
          if reassigned then
            break
          end
        end
      end

      if not reassigned then
        info.desk_id = nil
        info.desk_dest = nil
        info.frustration = get_protest_threshold()
        deps.set_waiting_biter_state(info, "protesting")
        protect_protesting_biter(info, biter, "desk-removed")
        assign_protest_target(surface, info, biter)
      end
    end
    storage.desk_biters[desk_id] = nil
  end

  function controller.trigger_immediate_protest(entity, surface, previous_info, opts)
    opts = opts or {}
    protest_debug_log(
      "trigger-immediate-start",
      previous_info,
      entity,
      "preserve=" .. tostring(opts.preserve_entity == true)
        .. " surface=" .. tostring(surface and surface.index or nil)
    )
    deps.normalize_case_progress(previous_info)
    local complaints = C.generate_complaints(entity.name)
    if previous_info and (previous_info.complaints_filed or (previous_info.complaints and #previous_info.complaints > 0)) then
      complaints = deps.copy_complaints(previous_info.complaints)
    end
    local info = {
      entity = entity,
      desk_id = nil,
      complaints = complaints,
      frustration = get_protest_threshold(),
      complaints_total = previous_info and previous_info.complaints_total or #complaints,
      complaints_filed = previous_info and previous_info.complaints_filed == true or false,
      state = "protesting",
    }
    if opts.allow_obstacle_breach ~= nil then
      info.allow_obstacle_breach = opts.allow_obstacle_breach == true
    elseif previous_info and previous_info.allow_obstacle_breach ~= nil then
      info.allow_obstacle_breach = previous_info.allow_obstacle_breach == true
    else
      info.allow_obstacle_breach = true
    end
    info.entity_name = entity.name
    if previous_info then
      deps.remember_home_spawner(info, previous_info.home_spawner)
      info.home_spawner_unit_number = previous_info.home_spawner_unit_number
    end
    if opts.preserve_entity then
      entity.force = deps.get_biter_force()
      if deps.apply_managed_unit_settings then
        deps.apply_managed_unit_settings(entity)
      end
    else
      entity = deps.adopt_redirected_biter(info, entity, deps.biter_force_name)
    end
    if not entity or not entity.valid then
      protest_debug_log("trigger-immediate-adopt-failed", info, entity, "preserve=" .. tostring(opts.preserve_entity == true))
      return false
    end

    info.entity = entity
    deps.track_waiting_biter(entity.unit_number, info)
    protect_protesting_biter(info, entity, "trigger-immediate")
    protest_debug_log("trigger-immediate-tracked", info, entity, "preserve=" .. tostring(opts.preserve_entity == true))

    local assigned = assign_protest_target(surface, info, entity)
    if assigned and opts.preserve_entity then
      begin_pending_protest_approach(info, entity)
    elseif opts.preserve_entity and not info.protest_path_retry_deferred then
      issue_targetless_protest_wander_command(info, entity, surface)
    end
    protest_debug_log("trigger-immediate-finish", info, entity, "assigned=" .. tostring(assigned))
    render.ensure_protest_rendering(info)
    render.notify_players_of_protest(info)
    return true
  end

  local function accumulate_biter_frustration(info, entity, reason)
    local last_tick = info.last_frustration_tick
    if not last_tick then
      info.last_frustration_tick = game.tick
      hard_mode_log(info, entity, "seed-frustration-tick", "reason=" .. tostring(reason), {force = true})
      return false
    end

    local elapsed_ticks = math.max(0, game.tick - last_tick)
    if elapsed_ticks <= 0 then
      hard_mode_log(info, entity, "no-elapsed", "reason=" .. tostring(reason) .. " elapsed_ticks=" .. tostring(elapsed_ticks))
      return false
    end

    info.last_frustration_tick = game.tick

    local before = info.frustration or 0
    local ft = C.get_individual_frust_tier(info)
    local growth = C.FRUST_GROWTH_RATES[ft]
    info.frust_accum = (info.frust_accum or 0) + growth * (elapsed_ticks / 60)
    local whole = 0
    if info.frust_accum >= 1 then
      whole = math.floor(info.frust_accum)
      info.frustration = (info.frustration or 0) + whole
      info.frust_accum = info.frust_accum - whole
    end
    hard_mode_log(
      info,
      entity,
      "accumulate",
      "reason=" .. tostring(reason)
        .. " elapsed_ticks=" .. tostring(elapsed_ticks)
        .. " tier=" .. tostring(ft)
        .. " growth=" .. tostring(growth)
        .. " before=" .. tostring(before)
        .. " whole=" .. tostring(whole)
        .. " after=" .. tostring(info.frustration)
    )
    return whole > 0
  end

  local function process_hard_mode_protest_frustration(info, entity, reason)
    if not hard_mode_enabled() then return false end
    hard_mode_log(info, entity, "process", "reason=" .. tostring(reason))
    accumulate_biter_frustration(info, entity, reason)
    local attack_threshold = get_attack_threshold()
    if attack_threshold and info.frustration >= attack_threshold then
      return release_hard_mode_attacker(info, entity, reason)
    end
    return false
  end

  function controller.process_frustration_and_protests(surface)
    deps.ensure_waiting_biter_state_index()
    local tracked_biter_ids = {}
    local seen_biter_ids = {}
    local shard_count = deps.background_state_shard_count or 4
    local shard_index = math.floor(game.tick / 60) % shard_count

    -- Shard EVERY state to distribute the load when many biters are active.
    append_state_unit_numbers("protesting", tracked_biter_ids, seen_biter_ids, shard_index, shard_count)
    append_state_unit_numbers("pacified", tracked_biter_ids, seen_biter_ids, shard_index, shard_count)
    append_state_unit_numbers("returning_home", tracked_biter_ids, seen_biter_ids, shard_index, shard_count)
    append_state_unit_numbers("waiting", tracked_biter_ids, seen_biter_ids, shard_index, shard_count)
    append_state_unit_numbers("pathfinding", tracked_biter_ids, seen_biter_ids, shard_index, shard_count)
    append_state_unit_numbers("attacking", tracked_biter_ids, seen_biter_ids, shard_index, shard_count)

    for _, b_id in ipairs(tracked_biter_ids) do
      local info = storage.waiting_biters and storage.waiting_biters[b_id]
      if not info then
        goto continue_biter
      end
      deps.normalize_case_progress(info)
      if not info.entity or not info.entity.valid then
        if info.hard_mode_attacking then
          hard_mode_log(
            info,
            info.entity,
            "process-invalid-entity",
            "unit=" .. tostring(b_id)
              .. " next_revival_retry_tick=" .. tostring(info.next_revival_retry_tick)
              .. " last_revive_tick=" .. tostring(info.last_revive_tick)
              .. " revival_failures=" .. tostring(info.revival_failures),
            {force = true}
          )
        end
        if info.state == "returning_home" then
          reset_protest_targeting(info, b_id)
          deps.unindex_biter_from_desk(info.desk_id, b_id)
          zones.release_slot(info.desk_id, b_id)
          deps.untrack_waiting_biter(b_id, info)
          goto continue_biter
        end
        local bypass_retry = false
        if info.state == "pacified" then
          local desk = find_available_desk_for_info(info)
          if desk then
            bypass_retry = true
          elseif game.tick >= (info.promise_retry_until_tick or 0) then
            clear_pacified_runtime(info)
            info.promise_retry_until_tick = nil
            if hard_mode_enabled() then
              info.frustration = get_frustration_capacity()
            else
              deps.set_waiting_biter_state(info, "protesting")
              info.frustration = get_protest_threshold()
            end
            bypass_retry = true
          elseif info.pacified_visibility_hold then
            goto continue_biter
          end
        end

      if not bypass_retry and game.tick < (info.next_revival_retry_tick or 0) then
        goto continue_biter
      end

        if info.state == "pathfinding" or info.state == "waiting" then
          render.destroy_protest_rendering(info)
          render.destroy_pacified_rendering(info)
          clear_pacified_runtime(info)
          deps.unindex_biter_from_desk(info.desk_id, b_id)
          deps.untrack_waiting_biter(b_id, info)
          goto continue_biter
        end

        if info.state == "attacking" then
          deps.set_waiting_biter_state(info, "protesting")
          info.hard_mode_attacking = true
          hard_mode_log(info, info.entity, "process-legacy-attacking-state", "unit=" .. tostring(b_id), {force = true})
        end

        local recovery_attempt = (info.revival_failures or 0) + 1
        local is_rapid_revive = info.last_revive_tick
          and (game.tick - info.last_revive_tick) < C.RAPID_REVIVE_WINDOW_TICKS
        if is_rapid_revive then
          if info.hard_mode_attacking then
            hard_mode_log(
              info,
              info.entity,
              "rapid-revive-check",
              "unit=" .. tostring(b_id)
                .. " recovery_attempt=" .. tostring(recovery_attempt)
                .. " max=" .. tostring(C.MAX_RAPID_REVIVES),
              {force = true}
            )
          end
          if recovery_attempt > C.MAX_RAPID_REVIVES then
            if info.hard_mode_attacking then
              hard_mode_log(
                info,
                info.entity,
                "rapid-revive-abandon",
                "unit=" .. tostring(b_id) .. " recovery_attempt=" .. tostring(recovery_attempt),
                {force = true}
              )
            end
            if info.state == "protesting" then
              reset_protest_targeting(info, b_id)
            end
            render.destroy_protest_rendering(info)
            render.destroy_pacified_rendering(info)
            clear_pacified_runtime(info)
            deps.unindex_biter_from_desk(info.desk_id, b_id)
            deps.untrack_waiting_biter(b_id, info)
            goto continue_biter
          end
        else
          recovery_attempt = 1
        end
        info.revival_failures = recovery_attempt
        if revive_tracked_biter(b_id, info, surface) then
          goto continue_biter
        end
        if info.hard_mode_attacking then
          hard_mode_log(
            info,
            info.entity,
            "revive-failed-scheduled",
            "unit=" .. tostring(b_id)
              .. " retry_tick=" .. tostring(game.tick + C.INVALIDATED_BITER_REVIVE_RETRY_TICKS),
            {force = true}
          )
        end
        info.next_revival_retry_tick = game.tick + C.INVALIDATED_BITER_REVIVE_RETRY_TICKS
        if info.state == "protesting" and info.arrived_at_building and info.target_building and info.target_building.valid then
          disable_protest_target(info.target_building, b_id)
        end
        deps.mark_desk_circuit_dirty(info.desk_id)
      else
        deps.remember_entity_tracking(info, info.entity)
        if info.state == "attacking" then
          deps.set_waiting_biter_state(info, "protesting")
          info.hard_mode_attacking = true
        end

        if info.state == "pathfinding" or info.state == "waiting" then
          if info.state == "pathfinding" then
            process_desk_route_breach(info, info.entity)
          end
          accumulate_biter_frustration(info, info.entity, "waiting-or-pathfinding")

          if info.frustration >= get_protest_threshold() then
            clear_desk_route_breach_runtime(info, info.entity)
            deps.set_waiting_biter_state(info, "protesting")
            protect_protesting_biter(info, info.entity, "frustration-threshold")
            deps.unindex_biter_from_desk(info.desk_id, b_id)
            zones.release_slot(info.desk_id, b_id)
            info.desk_id = nil
            info.desk_dest = nil
            info.promise_retry_until_tick = nil
            if assign_protest_target(surface, info, info.entity) then
            end
          end
        elseif info.state == "pacified" then
          local desk = find_available_desk_for_info(info)
          if desk and deps.route_biter_to_desk(info, info.entity, desk, {
            initial_frustration = info.frustration or get_pacified_frustration(),
          }) then
            clear_pacified_runtime(info)
          elseif game.tick >= (info.promise_retry_until_tick or 0) then
            info.promise_retry_until_tick = nil
            if hard_mode_enabled() then
              release_hard_mode_attacker(info, info.entity, "promise-expired")
            else
              clear_pacified_runtime(info)
              deps.set_waiting_biter_state(info, "protesting")
              info.frustration = get_protest_threshold()
              protect_protesting_biter(info, info.entity, "promise-expired")
              assign_protest_target(surface, info, info.entity)
            end
          else
            maintain_pacified_entity(info, info.entity)
          end
        elseif info.state == "returning_home" then
          -- Resolved Administration Desk biters are complaint visitors, not
          -- borrowed workers. Remove them once their exit walk finishes.
          if info.return_despawn_tick and game.tick >= info.return_despawn_tick then
            info.entity.destroy()
            deps.untrack_waiting_biter(b_id, info)
          else
            local dest = info.return_dest
            if dest and game.tick >= (info.return_arrival_check_tick or 0) then
              local ddx = info.entity.position.x - dest.x
              local ddy = info.entity.position.y - dest.y
              local arrival_distance = C.RETURN_ARRIVAL_DISTANCE or 2.5
              if ddx * ddx + ddy * ddy <= arrival_distance * arrival_distance then
                info.entity.destroy()
                deps.untrack_waiting_biter(b_id, info)
              end
            end
          end
        elseif info.state == "protesting" then
          if info.hard_mode_attacking then
            maintain_hard_mode_attack(info, info.entity, "process")
            goto continue_biter
          end
          if process_deferred_protest_route(info, info.entity) then
            goto continue_biter
          end
          if recover_false_protest_arrival(info, info.entity) then
            goto continue_biter
          end
          if process_protest_obstacle_attack(surface, info, info.entity) then
            goto continue_biter
          end
          if process_hard_mode_protest_frustration(info, info.entity, "frustration-capacity") then
            goto continue_biter
          end
          protect_protesting_biter(info, info.entity, "process")
          local target = info.target_building
          if target and not target.valid then
            reset_protest_targeting(info, b_id)
            target = nil
          elseif target and not is_protest_target_allowed(target, info.entity) then
            -- Migrate protesters saved by versions that admitted pipes or
            -- other infrastructure as the grievance target. Keep their
            -- protest identity, release the old shutdown claim, and route
            -- them toward a real building instead.
            reset_protest_targeting(info, b_id, {preserve_protest_identity = true})
            target = nil
          end

          if not info.target_building then
            if not info.pending_path_request_id and game.tick >= (info.next_protest_target_retry_tick or 0) then
              if not assign_protest_target(surface, info, info.entity)
                 and not info.protest_path_retry_deferred then
                issue_targetless_protest_wander_command(info, info.entity, surface)
              end
            elseif not info.pending_path_request_id
               and not info.protest_path_retry_deferred
               and game.tick >= (info.next_protest_wander_tick or 0) then
              issue_targetless_protest_wander_command(info, info.entity, surface)
            end
            if info.protest_path_retry_deferred then
              info.entity.active = false
            end
            goto continue_biter
          end

          if not info.arrived_at_building and info.target_building and info.target_building.valid and info.entity.valid then
            local arrival_pos = get_protest_arrival_position(info) or info.target_building.position
            local dist = distance_sq(info.entity.position, arrival_pos)
            if dist <= C.PROTEST_ARRIVAL_DISTANCE * C.PROTEST_ARRIVAL_DISTANCE then
              mark_protester_arrived(info, info.entity)
            end
            if not info.arrived_at_building and not info.entity.active and not info.pending_path_request_id then
              if not resume_en_route_protest(info, info.entity) then
                assign_protest_target(surface, info, info.entity)
              end
            end
          end

          if info.arrived_at_building and info.target_building and info.target_building.valid and not info.hard_mode_attacking then
            disable_protest_target(info.target_building, b_id)
          end
        end
      end
      ::continue_biter::
    end
  end

  function controller.process_protest_pacing(surface)
    local refresh_alerts = false
    local last_refresh = storage.protest_alert_refresh_tick or 0
    if game.tick - last_refresh >= 180 then
      refresh_alerts = true
      storage.protest_alert_refresh_tick = game.tick
    end
    local alerted_targets = refresh_alerts and {} or nil
    local protest_load_factor = get_protest_load_factor(count_protesters())
    local protest_shard_index = math.floor(game.tick / 20) % protest_load_factor

    for unit_number in pairs(deps.get_waiting_biter_state_set("protesting")) do
      local info = storage.waiting_biters and storage.waiting_biters[unit_number]
      local entity = info and info.entity or nil
      if not info then
        if hard_mode_enabled() then
          hard_mode_log({tracked_unit_number = unit_number, state = "missing"}, nil, "pacing-skip", "reason=missing-info")
        end
      elseif info.state ~= "protesting" then
        hard_mode_log(info, entity, "pacing-skip", "reason=state-" .. tostring(info.state))
      elseif not entity or not entity.valid then
        hard_mode_log(info, entity, "pacing-skip", "reason=invalid-entity")
      elseif entity.surface ~= surface then
        hard_mode_log(info, entity, "pacing-skip", "reason=surface-mismatch expected="
          .. tostring(surface and surface.index or nil))
      elseif info.hard_mode_attacking then
        maintain_hard_mode_attack(info, info.entity, "pacing")
      elseif process_deferred_protest_route(info, entity) then
        goto continue_protester
      elseif recover_false_protest_arrival(info, entity) then
        goto continue_protester
      elseif process_protest_obstacle_attack(surface, info, entity) then
        goto continue_protester
      elseif protest_load_factor > 1 and (unit_number % protest_load_factor) ~= protest_shard_index then
        -- Keep an arrived protest's gameplay effect asserted while deferring the
        -- expensive movement, rendering, position, and pathfinding maintenance.
        if info.arrived_at_building and info.target_building and info.target_building.valid then
          info.target_building.active = false
          -- Old saves can contain arrived protesters that have not yet received
          -- their first parking pass. Freeze them cheaply so deferred Lua
          -- maintenance does not turn into native unit-update work.
          info.protest_parked = true
          entity.active = false
        elseif info.protest_path_retry_deferred then
          entity.active = false
        end
        goto continue_protester
      elseif recover_stale_protest_path_request(info, entity, protest_load_factor) then
        goto continue_protester
      elseif not info.target_building
         or not info.target_building.valid
         or not is_protest_target_allowed(info.target_building, entity) then
        if info.target_building and info.target_building.valid then
          reset_protest_targeting(info, unit_number, {preserve_protest_identity = true})
        end
        hard_mode_log(info, entity, "pacing-skip", "reason=invalid-target")
        render.ensure_protest_rendering(info)
        if not info.pending_path_request_id and game.tick >= (info.next_protest_target_retry_tick or 0) then
          if not assign_protest_target(surface, info, info.entity)
             and not info.protest_path_retry_deferred then
            issue_targetless_protest_wander_command(info, info.entity, surface)
          end
        elseif not info.pending_path_request_id
           and not info.protest_path_retry_deferred
           and game.tick >= (info.next_protest_wander_tick or 0) then
          issue_targetless_protest_wander_command(info, info.entity, surface)
        end
        if info.protest_path_retry_deferred then
          info.entity.active = false
        end
      else
        if process_stalled_protest_route(info, info.entity, protest_load_factor) then
          goto continue_protester
        end
        if process_hard_mode_protest_frustration(info, info.entity, "pacing-frustration-capacity") then
          goto continue_protester
        end
        protect_protesting_biter(info, info.entity, "pacing")
        render.ensure_protest_rendering(info)
        if not info.arrived_at_building and not info.pending_path_request_id and not info.entity.active then
          if not resume_en_route_protest(info, info.entity) then
            assign_protest_target(surface, info, info.entity)
          end
        end
        if info.arrived_at_building then
          update_arrived_protest(info, info.entity)
        end
        if refresh_alerts then
          local tgt_id = info.target_building.unit_number
          if info.arrived_at_building and not alerted_targets[tgt_id] then
            alerted_targets[tgt_id] = true
            render.notify_players_of_protest(info)
          end
        end
      end
      ::continue_protester::
    end

    for unit_number in pairs(deps.get_waiting_biter_state_set("pacified")) do
      local info = storage.waiting_biters and storage.waiting_biters[unit_number]
      if info
         and info.state == "pacified"
         and info.entity
         and info.entity.valid
         and info.entity.surface == surface then
        local desk = find_available_desk_for_info(info)
        if desk and deps.route_biter_to_desk(info, info.entity, desk, {
          initial_frustration = info.frustration or get_pacified_frustration(),
        }) then
          clear_pacified_runtime(info)
        elseif game.tick >= (info.promise_retry_until_tick or 0) then
          info.promise_retry_until_tick = nil
          if hard_mode_enabled() then
            release_hard_mode_attacker(info, info.entity, "pacing-promise-expired")
          else
            clear_pacified_runtime(info)
            deps.set_waiting_biter_state(info, "protesting")
            info.frustration = get_protest_threshold()
            protect_protesting_biter(info, info.entity, "pacing-promise-expired")
            assign_protest_target(surface, info, info.entity)
          end
        else
          maintain_pacified_entity(info, info.entity)
        end
      end
    end
  end

  function controller.on_ai_command_completed(event)
    if not event.unit_number then return end

    local info = storage.waiting_biters[event.unit_number]
    if not info then return end
    local entity = info.entity
    if not entity or not entity.valid then
      if info.hard_mode_attacking then
        hard_mode_log(
          info,
          entity,
          "command-completed-invalid-entity",
          "event=" .. tostring(hard_mode_event_name(event))
            .. " result=" .. tostring(event.result)
            .. " distracted=" .. tostring(event.was_distracted),
          {force = true}
        )
      end
      return
    end

    if info.hard_mode_attacking then
      hard_mode_log(
        info,
        entity,
        "command-completed",
        "event=" .. tostring(hard_mode_event_name(event))
          .. " result=" .. tostring(event.result)
          .. " distracted=" .. tostring(event.was_distracted)
          .. " entity=" .. hard_mode_entity_summary(entity),
        {force = true}
      )
    end

    if info.state == "pathfinding" and info.desk_route_gap_waypoint then
      local obstacle = info.desk_route_gap_obstacle
      info.desk_route_gap_waypoint = nil
      info.desk_route_gap_obstacle = nil
      info.desk_route_gap_started_tick = nil
      if event.result == defines.behavior_result.success then
        info.desk_route_gap_failed_until_tick = nil
        local dx = entity.position.x - info.desk_dest.x
        local dy = entity.position.y - info.desk_dest.y
        info.desk_route_started_tick = game.tick
        info.desk_route_last_progress_tick = game.tick
        info.desk_route_best_distance_sq = dx * dx + dy * dy
        deps.issue_desk_route_command(entity, info.desk_dest)
      else
        info.desk_route_gap_failed_until_tick = game.tick
          + (C.DESK_ROUTE_BREACH_RETRY_TICKS or (2 * 60))
        begin_desk_route_breach(
          info,
          entity,
          obstacle and obstacle.valid and obstacle or nil,
          {skip_gap = true}
        )
      end
      return
    end

    if info.state == "pathfinding" and info.desk_route_breach_attacking then
      if not hard_mode_enabled() then
        defer_desk_route_breach(info, entity)
        return
      end
      info.desk_route_breach_command_pending = nil
      local obstacle = info.desk_route_breach_target
      if not obstacle or not obstacle.valid then
        resume_desk_route_after_breach(info, entity)
      else
        -- Both success and transient failure can follow one completed bite.
        -- A still-valid assigned obstruction remains the command target until
        -- it is destroyed; do not insert a visible retry pause between bites.
        info.desk_route_breach_command_failures = 0
        entity.active = true
        if not issue_desk_route_breach_command(info, entity) then
          defer_desk_route_breach(info, entity)
        end
      end
      return
    end

    if info.state == "pathfinding" and event.result == defines.behavior_result.fail then
      begin_desk_route_breach(info, entity)
      return
    end

    if info.state == "pathfinding" then
      local desk = storage.admin_desks and storage.admin_desks[info.desk_id]
      if desk and desk.valid then
        deps.finalize_pathfinding_biter_arrival(info, desk, "ai_complete")
      end
      return
    end

    if info.state == "returning_home" then
      if event.result == defines.behavior_result.fail then
        local cached_desk_id = info.return_cached_desk_id
        if info.return_failed_once then return end
        info.return_failed_once = true
        if cached_desk_id and storage.desk_return_positions then
          storage.desk_return_positions[cached_desk_id] = nil
        end
        deps.start_return_home(info, entity, {force_home_position = true})
      end
      return
    end

    if info.state == "pacified" then
      local desk = find_available_desk_for_info(info)
      if desk and deps.route_biter_to_desk(info, entity, desk, {
        initial_frustration = info.frustration or get_pacified_frustration(),
      }) then
        clear_pacified_runtime(info)
      else
        schedule_next_pacified_roam(info)
        park_pacified_biter(info, entity, {keep_roam_timer = true})
      end
      return
    end

    if info.state ~= "protesting" then return end

    -- Attack mode owns the commandable once escalation begins. This guard also
    -- repairs mixed state from saves written while wall-breach routing was
    -- active, where a stale waypoint could otherwise consume attack results.
    if info.hard_mode_attacking then
      if info.target_building and info.target_building.valid and is_hard_mode_attack_in_range(entity, info.target_building) then
        info.hard_mode_attack_next_command_tick = game.tick + (C.HARD_MODE_ATTACK_ANIMATION_TICKS or C.HARD_MODE_ATTACK_DAMAGE_TICKS or 30)
      else
        info.hard_mode_attack_next_command_tick = game.tick
      end
      maintain_hard_mode_attack(info, entity, "command-completed")
      return
    end

    if info.pending_path_request_id then return end

    if info.protest_pipe_gap_waypoint then
      local goal = info.protest_pipe_gap_goal
      local goal_target = info.protest_pipe_gap_goal_target
      info.protest_pipe_gap_waypoint = nil
      info.protest_pipe_gap_goal = nil
      info.protest_pipe_gap_goal_target = nil
      info.protest_pipe_gap_started_tick = nil
      if event.result == defines.behavior_result.success then
        info.protest_pipe_gap_failed_until_tick = nil
        if goal and is_protest_target_allowed(goal_target, entity)
           and begin_protest_route_toward_goal(info, entity, goal_target, goal, 2) then
          return
        end
      elseif goal and is_protest_target_allowed(goal_target, entity) then
        info.protest_pipe_gap_failed_until_tick = game.tick
          + (C.PROTEST_OBSTACLE_RETRY_TICKS or (3 * 60))
        local load_factor = get_protest_load_factor(count_protesters())
        begin_protest_obstacle_attack(info, entity, {
          target = goal_target,
          pos = goal,
        }, load_factor, {skip_gap = true})
        return
      end
    end

    if info.protest_route_hop_waypoint then
      local goal = info.protest_route_hop_goal
      local goal_target = info.protest_route_hop_target
      info.protest_route_hop_waypoint = nil
      info.protest_route_hop_goal = nil
      info.protest_route_hop_target = nil
      if event.result == defines.behavior_result.success then
        if goal and is_protest_target_allowed(goal_target, entity) then
          if begin_protest_route_toward_goal(info, entity, goal_target, goal, 2) then
            return
          end
          defer_clear_protest_route_retry(info, entity, goal_target, goal)
        end
      elseif goal and is_protest_target_allowed(goal_target, entity) then
        local load_factor = get_protest_load_factor(count_protesters())
        begin_protest_obstacle_attack(info, entity, {
          target = goal_target,
          pos = goal,
        }, load_factor)
      end
      return
    end

    if info.protest_obstacle_attacking then
      if not hard_mode_enabled() then
        clear_protest_obstacle_attack_runtime(info, entity)
        defer_protest_target_retry(
          info,
          entity,
          C.PROTEST_OBSTACLE_RETRY_TICKS or (3 * 60)
        )
        return
      end
      info.protest_obstacle_command_pending = nil
      local obstacle = info.protest_obstacle_target
      if not obstacle or not obstacle.valid then
        resume_protest_route_after_breach(info, entity, entity.surface)
      else
        -- A transient command failure is not evidence that the live, assigned
        -- obstruction disappeared. Keep biting it continuously until removal.
        info.protest_obstacle_command_failures = 0
        entity.active = true
        if not issue_protest_obstacle_attack_command(info, entity) then
          local load_factor = get_protest_load_factor(count_protesters())
          clear_protest_obstacle_attack_runtime(info, entity)
          defer_protest_target_retry(
            info,
            entity,
            C.PROTEST_OBSTACLE_RETRY_TICKS or (3 * 60),
            load_factor
          )
        end
      end
      return
    end

    if info.arrived_at_building and info.target_building and info.target_building.valid then
      if event.result == defines.behavior_result.fail then
        info.protest_step_deadline_tick = game.tick
      end
      return
    end

    if event.result ~= defines.behavior_result.fail then
      if resume_en_route_protest(info, entity) then
        return
      end
      if not assign_protest_target(entity.surface, info, entity)
         and not info.protest_path_retry_deferred then
        issue_targetless_protest_wander_command(info, entity, entity.surface)
      end
      return
    end

    -- A direct approach can fail after the script pathfinder declined to
    -- validate it under load. Keep the real grievance target and inspect the
    -- route in place: an existing wall gap wins, then a nearby eligible
    -- blocking building, and only then an aligned ordinary pipe breach.
    local failed_target = info.target_building
    if is_protest_target_allowed(failed_target, entity) then
      local failed_destination = get_protest_arrival_position(info) or failed_target.position
      local load_factor = get_protest_load_factor(count_protesters())
      if failed_destination and begin_protest_obstacle_attack(info, entity, {
        target = failed_target,
        pos = {x = failed_destination.x, y = failed_destination.y},
      }, load_factor) then
        return
      end
    end

    if not assign_protest_target(entity.surface, info, entity)
       and not info.protest_path_retry_deferred then
      issue_targetless_protest_wander_command(info, entity, entity.surface)
    end
  end

  function controller.on_script_path_request_finished(event)
    local request = storage.path_requests and storage.path_requests[event.id]
    if not request then return end
    storage.path_requests[event.id] = nil
    if request.kind == "protest_target" and not request.abandoned then
      adjust_outstanding_protest_path_requests(-1)
    end

    local info = storage.waiting_biters and storage.waiting_biters[request.unit_number]
    if not info then
      if deps.worker_protest_debug_logging == true and log then
        log(WORKER_PROTEST_LOG_PREFIX
          .. " tick=" .. tostring(game and game.tick or "nil")
          .. " label=path-finished-missing-info"
          .. " request_id=" .. tostring(event.id)
          .. " unit=" .. tostring(request.unit_number)
          .. " kind=" .. tostring(request.kind))
      end
      return
    end
    if info.pending_path_request_id ~= event.id then
      protest_debug_log(
        "path-finished-stale",
        info,
        info.entity,
        "request_id=" .. tostring(event.id)
          .. " expected=" .. tostring(info.pending_path_request_id)
          .. " kind=" .. tostring(request.kind)
      )
      return
    end
    info.pending_path_request_id = nil
    clear_pending_protest_reservation(info)

    if request.kind ~= "protest_target" or info.state ~= "protesting" then
      protest_debug_log(
        "path-finished-ignored",
        info,
        info.entity,
        "request_id=" .. tostring(event.id)
          .. " kind=" .. tostring(request.kind)
          .. " event_path_len=" .. tostring(event.path and #event.path or 0)
      )
      return
    end
    if not info.entity or not info.entity.valid then
      info.pending_protest_candidates = nil
      protest_debug_log(
        "path-finished-invalid-entity",
        info,
        info.entity,
        "request_id=" .. tostring(event.id)
          .. " event_path_len=" .. tostring(event.path and #event.path or 0)
      )
      return
    end

    local entity = info.entity
    local candidates = info.pending_protest_candidates or {}
    local candidate = candidates[request.candidate_index]
    protest_debug_log(
      "path-finished",
      info,
      entity,
      "request_id=" .. tostring(event.id)
        .. " candidate_index=" .. tostring(request.candidate_index)
        .. " candidate_exists=" .. tostring(candidate ~= nil)
        .. " try_again=" .. tostring(event.try_again_later == true)
        .. " path_len=" .. tostring(event.path and #event.path or 0)
        .. " "
        .. debug_target_summary(candidate and candidate.target or nil)
    )

    -- `try_again_later` means the low-priority validator is saturated, not
    -- that this route was actually searched. Treat it like an unvalidated
    -- route below: only a capped local gap/obstruction recovery may wake the
    -- unit. This avoids replacing one cheap rejected request with hundreds of
    -- expensive long-distance unit paths.

    local candidate_allowed = candidate and is_protest_target_allowed(candidate.target, entity)
    if candidate_allowed and event.path and #event.path > 0 then
      info.pending_protest_candidates = nil
      if begin_protest_approach(info, entity, candidate.target, candidate.pos, 2) then
        return
      end
    end

    if candidate_allowed then
      local snapshot = get_protester_snapshot()
      local load_factor = get_protest_load_factor(snapshot.total_protesters or 0)
      if begin_protest_obstacle_attack(info, entity, candidate, load_factor, {
        try_next_candidate_on_no_obstacle = load_factor <= 1
          and event.try_again_later ~= true
          and request.candidate_index < #candidates,
      }) then
        return
      end
    end

    if candidate then
      clear_protest_approach(info, candidate.target)
    end
    if not request_next_protest_target_path(info, entity, request.candidate_index + 1)
       and not info.protest_path_retry_deferred then
      issue_targetless_protest_wander_command(info, entity, entity.surface)
    end
  end

  local EVICTION_PRIORITY = {["unit-spawner"] = 1}
  local EVICTION_COMPLAINT_RADIUS = 25
  local function get_eviction_base_frustration()
    return math.floor(get_protest_threshold() * 0.5)
  end

  local function find_best_eviction_target(surface, position, radius)
    local best = nil
    local best_priority = 999
    local best_dist = math.huge
    for _, ent in ipairs(surface.find_entities_filtered{position = position, radius = radius, force = "enemy"}) do
      local prio = EVICTION_PRIORITY[ent.type]
      if prio then
        local dx = ent.position.x - position.x
        local dy = ent.position.y - position.y
        local dist = dx * dx + dy * dy
        if prio < best_priority or (prio == best_priority and dist < best_dist) then
          best = ent
          best_priority = prio
          best_dist = dist
        end
      end
    end
    return best
  end

  local function collect_evicted_biters(target)
    if not target or not target.valid then return {}, nil end
    local surface = target.surface
    local position = target.position
    local biters_to_redirect = {}
    for _, unit in ipairs(surface.find_entities_filtered{
      position = position,
      radius = EVICTION_COMPLAINT_RADIUS,
      force = "enemy",
      type = "unit",
    }) do
      if unit.valid and not storage.waiting_biters[unit.unit_number] then
        local commandable = unit.commandable
        if commandable and commandable.spawner and commandable.spawner.valid and commandable.spawner == target then
          commandable.release_from_spawner()
        end
        biters_to_redirect[#biters_to_redirect + 1] = unit
      end
    end
    return biters_to_redirect, surface
  end

  local function redirect_evicted_biters(surface, biters_to_redirect)
    if not surface or not biters_to_redirect then return end
    if #biters_to_redirect == 0 then return end

    local desks = deps.get_cached_desks()

    if #desks == 0 then
      for _, unit in ipairs(biters_to_redirect) do
        controller.trigger_immediate_protest(unit, surface)
      end
      return
    end

    for _, unit in ipairs(biters_to_redirect) do
      deps.send_biter_to_station_with_targets(unit, desks, {initial_frustration = get_eviction_base_frustration()})
    end
  end

  function controller.on_script_trigger_effect(event)
    deps.ensure_achievements()
    if event.effect_id == "eviction-target" then
      if event.tick == controller.last_eviction_tick then return end
      controller.last_eviction_tick = event.tick

      local ent = event.target_entity
      if not ent or not ent.valid then return end
      local surface = ent.surface
      local center = event.target_position or ent.position

      local target = find_best_eviction_target(surface, center, 5)
      if target and target.valid then
        local displaced_biters, displaced_surface = collect_evicted_biters(target)
        target.destroy()
        if storage.stats then storage.stats.nests_evicted = (storage.stats.nests_evicted or 0) + 1 end
        redirect_evicted_biters(displaced_surface or surface, displaced_biters)
        game.print({"message.eviction-served"})
      end
    elseif event.effect_id == "promise-target" and event.target_entity then
      local biter_entity = event.target_entity
      if biter_entity.valid then
        local info = storage.waiting_biters[biter_entity.unit_number]
        if info and (info.state == "protesting" or info.state == "attacking" or info.hard_mode_attacking) then
          if not storage.achievements.protest_suppressed then
            storage.achievements.protest_suppressed = true
            for _, p in pairs(game.connected_players) do
              p.unlock_achievement("protest-suppressed")
            end
          end
          if storage.stats then storage.stats.protests_suppressed = (storage.stats.protests_suppressed or 0) + 1 end

          local desk = deps.find_nearest_available_desk(biter_entity.position)
          clear_hard_mode_attack_runtime(info)

          if desk and deps.route_biter_to_desk(info, biter_entity, desk, {
            initial_frustration = get_pacified_frustration(),
          }) then
            clear_pacified_runtime(info)
          else
            deps.set_waiting_biter_state(info, "pacified")
            info.frustration = get_pacified_frustration()
            reset_protest_targeting(info)
            clear_pacified_runtime(info)
            info.desk_id = nil
            info.desk_dest = nil
            info.promise_retry_until_tick = game.tick + C.PROMISE_HOLD_TICKS
            maintain_pacified_entity(info, biter_entity)
          end
        end
      end
    elseif event.effect_id == "hush-money-target" then
      local surface = event.source_entity and event.source_entity.surface or game.surfaces[1]
      local center = event.target_position or (event.source_entity and event.source_entity.position)
      if not center then return end

      local spawners = surface.find_entities_filtered{type = "unit-spawner", position = center, radius = 6}
      if #spawners == 0 then return end

      storage.calmed_spawners = storage.calmed_spawners or {}
      local reactivate_tick = game.tick + C.HUSH_MONEY_CALM_TICKS
      local calmed_count = 0

      for _, spawner in ipairs(spawners) do
        if spawner.valid then
          local info = {
            name = spawner.name,
            position = spawner.position,
            force = spawner.force.name,
            direction = spawner.direction,
            surface = surface,
            reactivate_tick = reactivate_tick,
          }
          spawner.destroy()

          local ghost_render = rendering.draw_sprite{
            sprite = "entity/" .. info.name,
            target = info.position,
            surface = surface,
            tint = {r = 0.15, g = 0.85, b = 0.25, a = 0.4},
            x_scale = 6,
            y_scale = 6,
            render_layer = "object",
          }
          info.ghost_render = ghost_render

          local placeholder = surface.create_entity{
            name = "hush-money-placeholder",
            position = info.position,
            force = "neutral",
          }
          info.placeholder = placeholder

          local key = info.position.x .. "," .. info.position.y
          storage.calmed_spawners[key] = info
          calmed_count = calmed_count + 1
        end
      end

      if calmed_count > 0 then
        if storage.stats then storage.stats.nests_calmed = (storage.stats.nests_calmed or 0) + calmed_count end
        game.print({"message.hush-money-served"})
      end
    end
  end

  function controller.evict_target(surface, target)
    if not target or not target.valid then return false end
    local displaced_biters, displaced_surface = collect_evicted_biters(target)
    target.destroy()
    if storage.stats then storage.stats.nests_evicted = (storage.stats.nests_evicted or 0) + 1 end
    redirect_evicted_biters(displaced_surface or surface, displaced_biters)
    game.print({"message.eviction-served"})
    return true
  end

  function controller.on_biter_died(entity, event)
    local info = storage.waiting_biters[entity.unit_number]
    if not info and entity and entity.valid and entity.force and entity.force.name == (C.HARD_MODE_ATTACK_FORCE_NAME or "administratorio-hard-mode-biters") then
      hard_mode_log(
        {tracked_unit_number = entity.unit_number, state = "untracked"},
        entity,
        "biter-died-untracked-hard-force",
        "event=" .. tostring(hard_mode_event_name(event))
          .. " cause=" .. hard_mode_entity_summary(event and event.cause or nil),
        {force = true}
      )
    end
    if info then
      deps.remember_entity_tracking(info, entity)
      clear_protest_obstacle_attack_runtime(info, entity)
      if info.hard_mode_attacking or info.state == "attacking" then
        hard_mode_log(
          info,
          entity,
          "biter-died",
          "event=" .. tostring(hard_mode_event_name(event))
            .. " cause=" .. hard_mode_entity_summary(event and event.cause or nil)
            .. " unit=" .. tostring(entity.unit_number)
            .. " state=" .. tostring(info.state)
            .. " hard_mode_attacking=" .. hard_mode_bool(info.hard_mode_attacking)
            .. " entity=" .. hard_mode_entity_summary(entity),
          {force = true}
        )
      end
      if info.state == "attacking" or info.hard_mode_attacking then
        hard_mode_log(info, entity, "biter-died-untrack", "unit=" .. tostring(entity.unit_number), {force = true})
        deps.untrack_waiting_biter(entity.unit_number, info)
        return
      end
      if info.state ~= "returning_home" then
        render.destroy_protest_rendering(info)
        render.destroy_pacified_rendering(info)
        info.entity = nil
        info.next_revival_retry_tick = game.tick
        info.revival_failures = info.revival_failures or 0
        deps.mark_desk_circuit_dirty(info.desk_id)
        return
      end
      reset_protest_targeting(info, entity.unit_number)
      deps.unindex_biter_from_desk(info.desk_id, entity.unit_number)
      zones.release_slot(info.desk_id, entity.unit_number)
      deps.untrack_waiting_biter(entity.unit_number, info)
    end
  end

  function controller.on_biter_removed(entity, event)
    if not entity or not entity.valid or not entity.unit_number then return false end

    local info = storage.waiting_biters and storage.waiting_biters[entity.unit_number]
    if not info then
      if entity.force and entity.force.name == (C.HARD_MODE_ATTACK_FORCE_NAME or "administratorio-hard-mode-biters") then
        hard_mode_log(
          {tracked_unit_number = entity.unit_number, state = "untracked"},
          entity,
          "biter-removed-untracked-hard-force",
          "event=" .. tostring(hard_mode_event_name(event)) .. " entity=" .. hard_mode_entity_summary(entity),
          {force = true}
        )
      end
      return false
    end

    deps.remember_entity_tracking(info, entity)
    if info.hard_mode_attacking or info.state == "attacking" then
      hard_mode_log(
        info,
        entity,
        "biter-removed",
        "event=" .. tostring(hard_mode_event_name(event))
          .. " unit=" .. tostring(entity.unit_number)
          .. " state=" .. tostring(info.state)
          .. " hard_mode_attacking=" .. hard_mode_bool(info.hard_mode_attacking)
          .. " entity=" .. hard_mode_entity_summary(entity),
        {force = true}
      )
    end

    if info.state == "returning_home" then
      deps.untrack_waiting_biter(entity.unit_number, info)
      return true
    end

    if info.state == "attacking" or info.hard_mode_attacking then
      hard_mode_log(info, entity, "biter-removed-untrack", "unit=" .. tostring(entity.unit_number), {force = true})
      deps.untrack_waiting_biter(entity.unit_number, info)
      return true
    end

    if info.state == "protesting" then
      reset_protest_targeting(info, entity.unit_number)
    end
    render.destroy_protest_rendering(info)
    render.destroy_pacified_rendering(info)
    clear_pacified_runtime(info)
    deps.unindex_biter_from_desk(info.desk_id, entity.unit_number)
    zones.release_slot(info.desk_id, entity.unit_number)
    deps.untrack_waiting_biter(entity.unit_number, info)
    return true
  end

  function controller.process_calmed_spawners(tick)
    if not storage.calmed_spawners then return end
    for key, info in pairs(storage.calmed_spawners) do
      if tick >= info.reactivate_tick then
        if info.ghost_render and info.ghost_render.valid then info.ghost_render.destroy() end
        if info.placeholder and info.placeholder.valid then info.placeholder.destroy() end
        if info.surface and info.surface.valid then
          info.surface.create_entity{
            name = info.name,
            position = info.position,
            force = info.force,
            direction = info.direction,
          }
        end
        storage.calmed_spawners[key] = nil
      end
    end
  end

  return controller
end

return M
