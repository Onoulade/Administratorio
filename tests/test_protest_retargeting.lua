local passed, failed, errors = 0, 0, {}

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    errors[#errors + 1] = name .. ": " .. tostring(err)
  end
end

local function assert_true(value, msg)
  if not value then error(msg or "assertion failed", 2) end
end

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or "assertion failed") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

defines = {
  command = {
    stop = 1,
    go_to_location = 2,
    attack = 3,
  },
  distraction = {
    none = 1,
    by_enemy = 2,
    by_anything = 3,
  },
  behavior_result = {
    success = 0,
    fail = 1,
  },
}

local protest_factory = dofile(mod_root .. "scripts/biters_protests.lua")

local function new_test_context(hard_mode_enabled, constant_overrides)
  local state_sets = {
    protesting = {},
    pacified = {},
    returning_home = {},
    waiting = {},
    pathfinding = {},
  }
  local next_unit_number = 100
  local next_request_id = 0
  local last_move_command = nil
  local move_command_count = 0
  local last_attack_command = nil
  local attack_command_count = 0
  local pending_request_id = nil
  local protest_targets = {}
  local protest_obstacles = {}
  local protest_render_count = 0
  local protest_render_destroy_count = 0
  local protest_notify_count = 0
  local adopt_count = 0
  local desk_route_command_count = 0
  local last_desk_route_destination = nil

  local surface
  surface = {
    index = 1,
    valid = true,
    find_entities_filtered = function(opts)
      if opts.position and opts.radius and opts.force == "player" then
        if opts.type == "pipe" then
          return protest_obstacles
        end
        if opts.type or opts.name then
          return protest_targets
        end
        return protest_obstacles
      end
      if opts.force == "player" then
        return protest_targets
      end
      return {}
    end,
    find_non_colliding_position = function(_, pos)
      return {x = pos.x, y = pos.y}
    end,
    request_path = function(_)
      next_request_id = next_request_id + 1
      pending_request_id = next_request_id
      return next_request_id
    end,
    create_entity = function(params)
      next_unit_number = next_unit_number + 1
      local force = params.force
      if type(force) == "string" then
        force = game.forces[force] or {name = force}
      end
      local entity = {
        valid = true,
        name = params.name,
        type = params.type or "unit",
        position = {x = params.position.x, y = params.position.y},
        force = force,
        active = true,
        unit_number = next_unit_number,
        surface = surface,
        prototype = {
          collision_box = {{0, 0}, {0, 0}},
          collision_mask = {layers = {player = true}},
        },
      }
      entity.commandable = {
        set_command = function(command)
          if command.type == defines.command.go_to_location then
            last_move_command = command
            move_command_count = move_command_count + 1
          elseif command.type == defines.command.attack then
            last_attack_command = command
            attack_command_count = attack_command_count + 1
          end
        end,
      }
      entity.destroy = function()
        entity.valid = false
      end
      return entity
    end,
  }

  game = {
    tick = 0,
    connected_players = {},
    surfaces = {[1] = surface},
    forces = {
      neutral = {name = "neutral"},
      player = {name = "player"},
      ["administratorio-hard-mode-biters"] = {name = "administratorio-hard-mode-biters"},
    },
    get_surface = function(index)
      return game.surfaces[index]
    end,
  }

  storage = {
    achievements = {},
    waiting_biters = {},
    waiting_biter_state_index = state_sets,
    waiting_biter_state_index_built = true,
    path_requests = {},
    admin_desks = {},
    desk_biters = {},
  }

  local function set_waiting_biter_state(info, state)
    local old_state = info.state
    local unit_number = info.tracked_unit_number or (info.entity and info.entity.valid and info.entity.unit_number) or nil
    if old_state and unit_number then
      state_sets[old_state][unit_number] = nil
    end
    info.state = state
    if state and unit_number then
      state_sets[state][unit_number] = true
    end
  end

  local test_constants = {
      PROTEST_THRESHOLD = 600,
      HARD_MODE_ENABLED = hard_mode_enabled == true,
      INVALIDATED_BITER_REVIVE_RETRY_TICKS = 60,
      PROTEST_TARGET_RETRY_TICKS = 5 * 60,
      PROTEST_TARGET_CACHE_TICKS = 5 * 60,
      PROTEST_TARGET_PREFILTER_LIMIT = 64,
      PROTEST_TARGET_SEARCH_RADIUS_HIGH_LOAD = 96,
      PROTEST_TARGET_SPATIAL_CELL_SIZE = 96,
      PROTEST_PATH_BUSY_RETRY_TICKS = 60,
      PROTEST_PATH_REQUESTS_MAX_OUTSTANDING_HIGH_LOAD = 1,
      PROTEST_PATH_REQUEST_TIMEOUT_TICKS = 10 * 60,
      PROTEST_TARGET_RETRY_JITTER_TICKS = 0,
      PROTEST_OBSTACLE_ATTACKER_LIMIT = 12,
      PROTEST_OBSTACLE_ATTACKER_LIMIT_HIGH_LOAD = 1,
      PROTEST_PIPE_GAP_ROUTE_LIMIT_HIGH_LOAD = 8,
      PROTEST_OBSTACLE_RETRY_TICKS = 3 * 60,
      PROTEST_OBSTACLE_SEARCH_RADIUS = 4,
      PROTEST_PIPE_BREACH_SEARCH_RADIUS = 128,
      PROTEST_PIPE_BREACH_MAX_LATERAL_DISTANCE = 2,
      PROTEST_PIPE_BREACH_MIN_FORWARD_DISTANCE = 0.1,
      PROTEST_PIPE_LOCAL_RECOVERY_RADIUS = 8,
      PROTEST_PIPE_GAP_SEARCH_RADIUS = 64,
      PROTEST_PIPE_GAP_CROSS_DISTANCE = 1.5,
      PROTEST_PIPE_GAP_RECHECK_TICKS = 2 * 60,
      PROTEST_OBSTACLE_COMMAND_RETRY_TICKS = 60,
      DESK_ROUTE_BREACH_ATTACKER_LIMIT = 2,
      DESK_ROUTE_BREACH_RETRY_TICKS = 2 * 60,
      DESK_ROUTE_STALL_TICKS = 10 * 60,
      DESK_ROUTE_PROGRESS_DISTANCE = 1,
      PROTEST_ROUTE_STALL_TICKS = 10 * 60,
      PROTEST_ROUTE_PROGRESS_DISTANCE = 1,
      PROTEST_ROUTE_HOP_DISTANCE = 64,
      PROTEST_CLEAR_ROUTE_RETRY_TICKS = 60,
      PROTEST_FALSE_ARRIVAL_RECOVERY_DISTANCE = 32,
      PROTEST_TARGET_MAX_PROTESTERS = 5,
      PROTEST_OVERFLOW_WANDER_SEARCH_RADIUS = 12,
      PROTEST_TARGET_LOAD_PENALTY = 2500,
      PROTEST_TARGET_SELECTION_JITTER = 0,
      PROTEST_WANDER_MIN_RADIUS = 0.1,
      PROTEST_WANDER_MAX_RADIUS = 0.35,
      PROTEST_WANDER_MIN_MOVE_DISTANCE = 0.08,
      PROTEST_WANDER_ATTEMPTS = 1,
      PROTEST_WANDER_REISSUE_TICKS = 5 * 60,
      PROTEST_WANDER_REISSUE_JITTER_TICKS = 0,
      PROTEST_STEP_ACTIVE_TICKS = 20,
      PROTEST_MAX_DISTANCE_FROM_TARGET = 3.5,
      PROTEST_ARRIVAL_DISTANCE = 2.25,
      DESK_SLOT_COMMAND_RADIUS = 0.5,
      DESK_SLOT_ARRIVAL_DISTANCE = 1.0,
      PACIFIED_FRUSTRATION_RATIO = 0.5,
      PACIFIED_ROAM_REISSUE_TICKS = 30,
      PACIFIED_ROAM_REISSUE_JITTER_TICKS = 0,
      generate_complaints = function()
        return {"ticket-unemployment"}
      end,
  }
  for key, value in pairs(constant_overrides or {}) do
    test_constants[key] = value
  end

  local deps = {
    constants = test_constants,
    zones = {
      reassign_slot = function() end,
      get_zone_position = function() return nil end,
      get_queue_pos = function() return {x = 0, y = 0} end,
      release_slot = function() end,
      get_available_slots = function() return 0 end,
    },
    working_hours = {
      claim_protest_target = function() return false end,
      release_protest_target = function() return false end,
      transfer_protest_target = function() end,
    },
    render = {
      destroy_protest_rendering = function()
        protest_render_destroy_count = protest_render_destroy_count + 1
      end,
      destroy_protest_chart_tag = function() end,
      ensure_protest_rendering = function()
        protest_render_count = protest_render_count + 1
      end,
      ensure_protest_chart_tag = function() end,
      destroy_pacified_rendering = function() end,
      ensure_pacified_rendering = function() end,
      notify_players_of_protest = function()
        protest_notify_count = protest_notify_count + 1
      end,
    },
    ensure_achievements = function()
      storage.achievements = storage.achievements or {}
    end,
    ensure_desk_biters = function()
      storage.desk_biters = storage.desk_biters or {}
    end,
    ensure_waiting_biter_state_index = function() end,
    get_waiting_biter_state_set = function(state)
      return state_sets[state]
    end,
    set_waiting_biter_state = set_waiting_biter_state,
    find_nearest_available_desk = function() return nil end,
    route_biter_to_desk = function() return false end,
    remember_entity_tracking = function(info, entity)
      info.entity_name = entity.name
      info.last_known_position = {x = entity.position.x, y = entity.position.y}
      info.last_known_surface_index = entity.surface.index
    end,
    replace_tracked_waiting_biter_unit_number = function(old_unit_number, new_unit_number, info)
      storage.waiting_biters[old_unit_number] = nil
      storage.waiting_biters[new_unit_number] = info
      if info.state then
        state_sets[info.state][old_unit_number] = nil
        state_sets[info.state][new_unit_number] = true
      end
      info.tracked_unit_number = new_unit_number
    end,
    mark_desk_circuit_dirty = function() end,
    unindex_biter_from_desk = function() end,
    index_biter_to_desk = function() end,
    get_desk_waiting_destination = function() return {x = 0, y = 0} end,
    issue_desk_route_command = function(_, destination)
      desk_route_command_count = desk_route_command_count + 1
      last_desk_route_destination = destination
      return true
    end,
    get_cached_desks = function() return {} end,
    normalize_case_progress = function() end,
    biter_force_name = "neutral",
    get_biter_force = function() return game.forces["neutral"] end,
    get_hard_mode_attack_force = function()
      return game.forces["administratorio-hard-mode-biters"]
    end,
    format_position = function(pos)
      if not pos then return "[nil]" end
      return "[" .. tostring(pos.x) .. "," .. tostring(pos.y) .. "]"
    end,
    track_waiting_biter = function(unit_number, info)
      storage.waiting_biters[unit_number] = info
      info.tracked_unit_number = unit_number
      if info.state then
        state_sets[info.state][unit_number] = true
      end
    end,
    untrack_waiting_biter = function(unit_number)
      storage.waiting_biters[unit_number] = nil
      for _, set in pairs(state_sets) do
        set[unit_number] = nil
      end
    end,
    finalize_pathfinding_biter_arrival = function() return false end,
    protest_obstacle_building_types = {
      "assembling-machine",
      "container",
      "furnace",
      "gate",
      "lab",
      "mining-drill",
      "wall",
    },
    protest_protected_names = {
      ["admin-station"] = true,
      ["resolution-office"] = true,
    },
    protest_target_names = {"office-desk"},
    protest_target_types = {},
    adopt_redirected_biter = function(_, entity)
      adopt_count = adopt_count + 1
      return entity
    end,
    copy_complaints = function(complaints)
      local copy = {}
      for i, complaint in ipairs(complaints or {}) do
        copy[i] = complaint
      end
      return copy
    end,
    remember_home_spawner = function() end,
    send_biter_to_station_with_targets = function() end,
    start_return_home = function() end,
    background_state_shard_count = 1,
    protest_debug_status_ticks = 10 * 60,
  }

  local controller = protest_factory.new(deps)

  return {
    controller = controller,
    surface = surface,
    set_protest_targets = function(targets)
      protest_targets = targets
    end,
    set_protest_obstacles = function(obstacles)
      protest_obstacles = obstacles
    end,
    get_last_move_command = function()
      return last_move_command
    end,
    get_move_command_count = function()
      return move_command_count
    end,
    get_last_attack_command = function()
      return last_attack_command
    end,
    get_attack_command_count = function()
      return attack_command_count
    end,
    get_pending_request_id = function()
      return pending_request_id
    end,
    get_path_request_count = function()
      return next_request_id
    end,
    get_protest_render_count = function()
      return protest_render_count
    end,
    get_protest_render_destroy_count = function()
      return protest_render_destroy_count
    end,
    get_protest_notify_count = function()
      return protest_notify_count
    end,
    get_adopt_count = function()
      return adopt_count
    end,
    get_desk_route_command_count = function()
      return desk_route_command_count
    end,
    get_last_desk_route_destination = function()
      return last_desk_route_destination
    end,
  }
end

local function new_target(surface, unit_number, x, y)
  return {
    valid = true,
    active = false,
    force = {name = "player"},
    unit_number = unit_number,
    name = "office-desk",
    position = {x = x, y = y},
    surface = surface,
    bounding_box = {
      left_top = {x = x - 0.5, y = y - 0.5},
      right_bottom = {x = x + 0.5, y = y + 0.5},
    },
  }
end

local function new_obstacle(surface, unit_number, x, y, obstacle_type, obstacle_name, collision_layers)
  obstacle_type = obstacle_type or "assembling-machine"
  return {
    valid = true,
    destructible = true,
    health = 100,
    force = {name = "player"},
    unit_number = unit_number,
    name = obstacle_name or obstacle_type,
    type = obstacle_type,
    position = {x = x, y = y},
    surface = surface,
    prototype = {
      collision_mask = {layers = collision_layers or {player = true}},
    },
  }
end

test("removing a protested building retargets the biter and resumes movement", function()
  local ctx = new_test_context()
  local old_target = new_target(ctx.surface, 91, 7, 7)
  local replacement_target = new_target(ctx.surface, 92, 18, 18)
  ctx.set_protest_targets({replacement_target})

  local entity = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 7, y = 7},
    force = "neutral",
  }
  entity.unit_number = 4

  local info = {
    state = "protesting",
    entity = entity,
    entity_name = entity.name,
    tracked_unit_number = 4,
    target_building = old_target,
    arrived_at_building = true,
    complaints = {"ticket-landscape"},
  }
  storage.waiting_biters[4] = info
  storage.waiting_biter_state_index.protesting[4] = true
  ctx.controller.on_protest_target_removed(old_target)

  local request_id = ctx.get_pending_request_id()
  assert_true(request_id ~= nil, "removing the protest target should request a new protest path immediately")
  assert_true(info.target_building == nil, "removing the protest target should clear the old assignment before reassignment")

  ctx.controller.on_script_path_request_finished{
    id = request_id,
    path = {{x = 12, y = 12}},
  }

  assert_true(info.target_building == replacement_target, "protester should switch to a new building after its target is removed")
  assert_true(info.arrived_at_building == nil, "reassigned protester should go back to the approach state")
  assert_true(ctx.get_last_move_command() ~= nil, "reassigned protester should receive a fresh movement command")
  assert_true(entity.active == true, "reassigned protester should be active while moving toward the new target")
end)

test("a busy validation pathfinder defers when there is no local obstruction", function()
  local ctx = new_test_context()
  local target = new_target(ctx.surface, 105, 20, 20)
  ctx.set_protest_targets({target})

  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 4},
    force = "player",
  }
  assert_true(ctx.controller.trigger_immediate_protest(entity, ctx.surface, nil, {preserve_entity = true}))

  local info = storage.waiting_biters[entity.unit_number]
  local request_id = ctx.get_pending_request_id()
  local request_count = ctx.get_path_request_count()
  ctx.controller.on_script_path_request_finished{
    id = request_id,
    try_again_later = true,
  }

  assert_eq(ctx.get_path_request_count(), request_count, "busy pathfinder response must not create another request in the same callback")
  assert_true(info.pending_path_request_id == nil, "busy pathfinder response should clear the completed request")
  assert_true(info.pending_protest_candidates == nil, "a saturated validation attempt should release its candidate list")
  assert_true(info.target_building == nil, "an unvalidated long route should not become active native path work")
  assert_true(info.protest_path_retry_deferred == true, "the protester should sleep until its bounded retry")
  assert_true(info.next_protest_target_retry_tick > game.tick, "the saturated attempt should schedule a retry")
end)

test("busy validation routes through a local pipe-wall gap without a long direct path", function()
  local ctx = new_test_context()
  local target = new_target(ctx.surface, 165, 20, 6)
  ctx.set_protest_targets({target})
  ctx.set_protest_obstacles({
    new_obstacle(ctx.surface, 260, 6, 4, "pipe"),
    new_obstacle(ctx.surface, 261, 6, 5, "pipe"),
    new_obstacle(ctx.surface, 262, 6, 7, "pipe"),
    new_obstacle(ctx.surface, 263, 6, 8, "pipe"),
  })
  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 6},
    force = "player",
  }
  assert_true(ctx.controller.trigger_immediate_protest(entity, ctx.surface, nil, {preserve_entity = true}))
  ctx.controller.on_script_path_request_finished{
    id = ctx.get_pending_request_id(),
    try_again_later = true,
  }

  local info = storage.waiting_biters[entity.unit_number]
  assert_eq(ctx.get_attack_command_count(), 0, "busy validation should not attack a pipe when the wall has a gap")
  assert_true(info.protest_pipe_gap_waypoint ~= nil, "busy validation should issue only the short wall-gap waypoint")
  assert_eq(info.target_building, target, "gap recovery should retain the real grievance target")
end)

test("a wall-side protester bypasses a saturated long-path slot for one capped gap route", function()
  local ctx = new_test_context(false, {
    PROTEST_HIGH_LOAD_THRESHOLD = 1,
    PROTEST_PACING_MAX_SHARDS = 12,
    PROTEST_PATH_REQUESTS_MAX_OUTSTANDING_HIGH_LOAD = 1,
    PROTEST_OBSTACLE_ATTACKER_LIMIT_HIGH_LOAD = 1,
    PROTEST_PIPE_GAP_ROUTE_LIMIT_HIGH_LOAD = 1,
  })
  local target = new_target(ctx.surface, 167, 20, 6)
  ctx.set_protest_targets({target})
  ctx.set_protest_obstacles({
    new_obstacle(ctx.surface, 280, 6, 4, "pipe"),
    new_obstacle(ctx.surface, 281, 6, 5, "pipe"),
    new_obstacle(ctx.surface, 282, 6, 7, "pipe"),
    new_obstacle(ctx.surface, 283, 6, 8, "pipe"),
  })

  local occupied = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 0, y = 0},
    force = "neutral",
  }
  storage.waiting_biters[occupied.unit_number] = {
    state = "protesting",
    entity = occupied,
    tracked_unit_number = occupied.unit_number,
    pending_path_request_id = 999,
  }
  storage.waiting_biter_state_index.protesting[occupied.unit_number] = true
  storage.path_requests[999] = {
    kind = "protest_target",
    unit_number = occupied.unit_number,
    requested_tick = game.tick,
  }

  local wall_side = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 0, y = 6},
    force = "player",
  }
  assert_true(ctx.controller.trigger_immediate_protest(wall_side, ctx.surface, nil, {preserve_entity = true}))

  local info = storage.waiting_biters[wall_side.unit_number]
  assert_true(info.pending_path_request_id == nil, "the local repair must not add a long-path validation request")
  assert_true(info.protest_pipe_gap_waypoint ~= nil, "the adjacent wall protester should take the real opening immediately")
  assert_true(info.protest_pipe_gap_route_active == true, "the gap route should occupy the bounded local recovery slot")
end)

test("a stale saved path request detaches into an explicit building attack", function()
  local ctx = new_test_context(false, {
    PROTEST_PATH_REQUEST_TIMEOUT_TICKS = 60,
  })
  local target = new_target(ctx.surface, 108, 20, 20)
  local obstacle = new_obstacle(ctx.surface, 208, 6, 6, "furnace", "stone-furnace")
  ctx.set_protest_targets({target})
  ctx.set_protest_obstacles({obstacle})

  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 4},
    force = "player",
  }
  assert_true(ctx.controller.trigger_immediate_protest(entity, ctx.surface, nil, {preserve_entity = true}))

  local info = storage.waiting_biters[entity.unit_number]
  local request_id = info.pending_path_request_id
  game.tick = 59
  ctx.controller.process_protest_pacing(ctx.surface)
  assert_true(info.protest_obstacle_attacking ~= true, "a request should retain its full timeout window")

  game.tick = 60
  ctx.controller.process_protest_pacing(ctx.surface)
  assert_true(info.pending_path_request_id == nil, "timed-out request should detach from the protester")
  assert_true(storage.path_requests[request_id].abandoned == true, "native work should remain marked abandoned until its callback arrives")
  assert_true(info.protest_obstacle_attacking == true, "timed-out path validation should switch to obstruction clearing")
  assert_eq(ctx.get_last_attack_command().target, obstacle, "stale-path recovery should attack the nearby blocking building")
end)

test("high protest load caps path requests created in the same tick", function()
  local ctx = new_test_context(false, {
    PROTEST_HIGH_LOAD_THRESHOLD = 1,
    PROTEST_PACING_MAX_SHARDS = 12,
    PROTEST_PATH_REQUESTS_PER_TICK_HIGH_LOAD = 1,
  })
  local target = new_target(ctx.surface, 106, 20, 20)
  ctx.set_protest_targets({target})

  for unit_number = 10, 11 do
    local dummy = ctx.surface.create_entity{
      name = "small-biter",
      position = {x = unit_number, y = 0},
      force = "neutral",
    }
    dummy.unit_number = unit_number
    storage.waiting_biters[unit_number] = {
      state = "protesting",
      entity = dummy,
      tracked_unit_number = unit_number,
    }
    storage.waiting_biter_state_index.protesting[unit_number] = true
  end

  local first = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 2, y = 2},
    force = "player",
  }
  local second = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 3, y = 3},
    force = "player",
  }
  assert_true(ctx.controller.trigger_immediate_protest(first, ctx.surface, nil, {preserve_entity = true}))
  assert_true(ctx.controller.trigger_immediate_protest(second, ctx.surface, nil, {preserve_entity = true}))

  local second_info = storage.waiting_biters[second.unit_number]
  assert_eq(ctx.get_path_request_count(), 1, "high-load path request budget should cap requests per tick")
  assert_true(second_info.pending_path_request_id == nil, "request over budget should remain deferred")
  assert_true(second_info.next_protest_target_retry_tick > game.tick, "request over budget should schedule a retry")
  assert_eq(ctx.get_move_command_count(), 1, "deferred protester should not receive a fallback wander command")
  assert_true(second.active == false, "deferred protester should remain inactive until its path retry")
end)

test("high-load protesters outside the local radius still find distant buildings", function()
  local ctx = new_test_context(false, {
    PROTEST_HIGH_LOAD_THRESHOLD = 1,
    PROTEST_PACING_MAX_SHARDS = 12,
    PROTEST_PATH_REQUESTS_PER_TICK_HIGH_LOAD = 1,
  })
  local distant_target = new_target(ctx.surface, 160, 1200, 0)
  ctx.set_protest_targets({distant_target})

  local original_find_entities_filtered = ctx.surface.find_entities_filtered
  ctx.surface.find_entities_filtered = function(opts)
    if opts.position and opts.radius and opts.force == "player" and opts.type ~= "pipe" then
      return {}
    end
    return original_find_entities_filtered(opts)
  end

  local existing = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 0, y = 0},
    force = "neutral",
  }
  existing.unit_number = 10
  storage.waiting_biters[10] = {
    state = "protesting",
    entity = existing,
    tracked_unit_number = 10,
  }
  storage.waiting_biter_state_index.protesting[10] = true

  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 0, y = 0},
    force = "player",
  }
  assert_true(ctx.controller.trigger_immediate_protest(entity, ctx.surface, nil, {preserve_entity = true}))

  local info = storage.waiting_biters[entity.unit_number]
  assert_true(info.pending_path_request_id ~= nil, "the cached spatial fallback should validate a route beyond the local search radius")
  assert_eq(info.pending_protest_reserved_target, distant_target, "the distant eligible building should remain the real protest target")
end)

test("high-load target caps become soft when every building is already claimed", function()
  local ctx = new_test_context(false, {
    PROTEST_HIGH_LOAD_THRESHOLD = 1,
    PROTEST_PACING_MAX_SHARDS = 12,
    PROTEST_PATH_REQUESTS_PER_TICK_HIGH_LOAD = 1,
  })
  local target = new_target(ctx.surface, 162, 1200, 0)
  ctx.set_protest_targets({target})

  for unit_number = 10, 14 do
    local claimed = ctx.surface.create_entity{
      name = "small-biter",
      position = {x = target.position.x, y = target.position.y},
      force = "neutral",
    }
    claimed.unit_number = unit_number
    storage.waiting_biters[unit_number] = {
      state = "protesting",
      entity = claimed,
      tracked_unit_number = unit_number,
      target_building = target,
      arrived_at_building = true,
    }
    storage.waiting_biter_state_index.protesting[unit_number] = true
  end

  local overflow = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 0, y = 0},
    force = "player",
  }
  assert_true(ctx.controller.trigger_immediate_protest(overflow, ctx.surface, nil, {preserve_entity = true}))

  local info = storage.waiting_biters[overflow.unit_number]
  assert_true(info.pending_path_request_id ~= nil, "a saturated small base should still admit a bounded overflow protester")
  assert_eq(info.pending_protest_reserved_target, target, "overflow should share the least-loaded real building instead of freezing at the wall")
end)

test("a targetless protester that finds no position refunds the per-tick path budget", function()
  local ctx = new_test_context(false, {
    PROTEST_HIGH_LOAD_THRESHOLD = 1,
    PROTEST_PACING_MAX_SHARDS = 12,
    PROTEST_PATH_REQUESTS_PER_TICK_HIGH_LOAD = 1,
  })
  local target = new_target(ctx.surface, 164, 20, 20)
  ctx.set_protest_targets({target})
  for unit_number = 10, 14 do
    storage.waiting_biters[unit_number] = {
      state = "protesting",
      tracked_unit_number = unit_number,
      target_building = target,
      arrived_at_building = true,
    }
    storage.waiting_biter_state_index.protesting[unit_number] = true
  end

  local position_attempts = 0
  ctx.surface.find_non_colliding_position = function(_, pos)
    position_attempts = position_attempts + 1
    if position_attempts <= 3 then return nil end
    return {x = pos.x, y = pos.y}
  end

  local blocked = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 0, y = 0},
    force = "player",
  }
  local admitted = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 1, y = 0},
    force = "player",
  }
  assert_true(ctx.controller.trigger_immediate_protest(blocked, ctx.surface, nil, {preserve_entity = true}))
  assert_true(ctx.controller.trigger_immediate_protest(admitted, ctx.surface, nil, {preserve_entity = true}))

  assert_true(storage.waiting_biters[blocked.unit_number].pending_path_request_id == nil, "the first protester should have no usable position")
  assert_true(storage.waiting_biters[admitted.unit_number].pending_path_request_id ~= nil, "the second protester should reuse the refunded budget in the same tick")
end)

test("high protest load caps globally outstanding path requests without resetting denied protesters", function()
  local ctx = new_test_context(false, {
    PROTEST_HIGH_LOAD_THRESHOLD = 1,
    PROTEST_PACING_MAX_SHARDS = 12,
    PROTEST_PATH_REQUESTS_PER_TICK_HIGH_LOAD = 10,
    PROTEST_PATH_REQUESTS_MAX_OUTSTANDING_HIGH_LOAD = 1,
  })
  local target = new_target(ctx.surface, 107, 20, 20)
  ctx.set_protest_targets({target})

  local dummy = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 10, y = 0},
    force = "neutral",
  }
  dummy.unit_number = 10
  storage.waiting_biters[10] = {
    state = "protesting",
    entity = dummy,
    tracked_unit_number = 10,
  }
  storage.waiting_biter_state_index.protesting[10] = true

  local first = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 2, y = 2},
    force = "player",
  }
  assert_true(ctx.controller.trigger_immediate_protest(first, ctx.surface, nil, {preserve_entity = true}))
  assert_eq(ctx.get_path_request_count(), 1, "the first high-load protester should occupy the global path slot")

  game.tick = 1
  local render_destroys_before = ctx.get_protest_render_destroy_count()
  local second = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 3, y = 3},
    force = "player",
  }
  assert_true(ctx.controller.trigger_immediate_protest(second, ctx.surface, nil, {preserve_entity = true}))

  local second_info = storage.waiting_biters[second.unit_number]
  assert_eq(ctx.get_path_request_count(), 1, "a later tick must not exceed the global outstanding path ceiling")
  assert_true(second_info.protest_path_retry_deferred == true, "a protester denied by the global ceiling should be deferred")
  assert_eq(
    ctx.get_protest_render_destroy_count(),
    render_destroys_before,
    "capacity denial must happen before protest rendering or identity is reset"
  )
end)

test("orphaned saved path requests cannot permanently lock high-load routing", function()
  local ctx = new_test_context(false, {
    PROTEST_HIGH_LOAD_THRESHOLD = 1,
    PROTEST_PACING_MAX_SHARDS = 12,
    PROTEST_PATH_REQUESTS_PER_TICK_HIGH_LOAD = 1,
    PROTEST_PATH_REQUESTS_MAX_OUTSTANDING_HIGH_LOAD = 1,
  })
  local target = new_target(ctx.surface, 163, 1200, 0)
  ctx.set_protest_targets({target})
  storage.path_requests[999] = {
    kind = "protest_target",
    unit_number = 999,
    requested_tick = 0,
  }

  local existing = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 0, y = 0},
    force = "neutral",
  }
  existing.unit_number = 10
  storage.waiting_biters[10] = {
    state = "protesting",
    entity = existing,
    tracked_unit_number = 10,
  }
  storage.waiting_biter_state_index.protesting[10] = true

  game.tick = 100
  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 0, y = 0},
    force = "player",
  }
  assert_true(ctx.controller.trigger_immediate_protest(entity, ctx.surface, nil, {preserve_entity = true}))

  local info = storage.waiting_biters[entity.unit_number]
  assert_true(storage.path_requests[999].abandoned == true, "the orphaned saved request should be retired from admission accounting")
  assert_true(info.pending_path_request_id ~= nil, "retiring the orphan should admit a fresh bounded path request")
end)

test("high protest load processes one deterministic pacing shard at a time", function()
  local ctx = new_test_context(false, {
    PROTEST_HIGH_LOAD_THRESHOLD = 1,
    PROTEST_PACING_MAX_SHARDS = 4,
  })

  for unit_number = 10, 13 do
    local target = new_target(ctx.surface, 200 + unit_number, unit_number, unit_number)
    local entity = ctx.surface.create_entity{
      name = "small-biter",
      position = {x = unit_number, y = unit_number},
      force = "neutral",
    }
    entity.unit_number = unit_number
    storage.waiting_biters[unit_number] = {
      state = "protesting",
      entity = entity,
      tracked_unit_number = unit_number,
      target_building = target,
      arrived_at_building = true,
      protest_anchor_position = {x = unit_number, y = unit_number},
    }
    storage.waiting_biter_state_index.protesting[unit_number] = true
  end

  game.tick = 0 -- shard 0: only unit 12 of 10..13 is fully maintained
  ctx.controller.process_protest_pacing(ctx.surface)

  assert_eq(ctx.get_protest_render_count(), 1, "only the current pacing shard should run expensive protest maintenance")
end)

test("triggering an immediate protest renders even before a target is assigned", function()
  local ctx = new_test_context()
  ctx.set_protest_targets({})

  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 4},
    force = "neutral",
  }

  ctx.controller.trigger_immediate_protest(entity, ctx.surface)

  local info = storage.waiting_biters[entity.unit_number]
  assert_true(info ~= nil, "immediate protest should register the worker as a waiting biter")
  assert_eq(info.state, "protesting", "registered worker should be protesting")
  assert_true(ctx.get_protest_render_count() > 0, "immediate protest should render protest text without a target")
  assert_true(ctx.get_protest_notify_count() > 0, "immediate protest should notify using the protester when no target exists")
end)

test("preserved immediate protest keeps the existing worker entity", function()
  local ctx = new_test_context()
  ctx.set_protest_targets({})

  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 4},
    force = "player",
  }

  assert_true(ctx.controller.trigger_immediate_protest(entity, ctx.surface, nil, {preserve_entity = true}), "preserved protest should succeed")

  local info = storage.waiting_biters[entity.unit_number]
  assert_true(info ~= nil, "preserved protest should track the same unit number")
  assert_true(info.entity == entity, "preserved protest should keep the existing entity")
  assert_true(entity.valid, "preserved protest should not destroy the worker entity")
  assert_eq(ctx.get_adopt_count(), 0, "preserved protest should not use the clone/adopt path")
end)

test("preserved immediate protest wanders when no target is available", function()
  local ctx = new_test_context()
  ctx.set_protest_targets({})

  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 4},
    force = "player",
  }

  assert_true(ctx.controller.trigger_immediate_protest(entity, ctx.surface, nil, {preserve_entity = true}), "preserved protest should succeed")

  local info = storage.waiting_biters[entity.unit_number]
  assert_true(info ~= nil, "preserved targetless protest should still be tracked")
  assert_true(info.target_building == nil, "targetless protest should not claim a missing building")
  assert_true(ctx.get_last_move_command() ~= nil, "targetless protest should receive a wander command")
  assert_true(info.protest_anchor_position ~= nil, "targetless protest should keep a wander anchor")
end)

test("preserved immediate protest starts moving toward a target immediately", function()
  local ctx = new_test_context()
  local target = new_target(ctx.surface, 98, 20, 20)
  ctx.set_protest_targets({target})

  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 4},
    force = "player",
  }

  assert_true(ctx.controller.trigger_immediate_protest(entity, ctx.surface, nil, {preserve_entity = true}), "preserved protest should succeed")

  local info = storage.waiting_biters[entity.unit_number]
  local command = ctx.get_last_move_command()
  assert_true(command ~= nil, "preserved protest should receive a move command before the path callback")
  assert_true(info.target_building == target, "preserved protest should claim the target immediately")
  assert_true(info.pending_path_request_id ~= nil, "preserved protest should still keep the async path validation request")
  assert_eq(command.destination.x, info.protest_anchor_position.x, "move command should use the protest anchor x")
  assert_eq(command.destination.y, info.protest_anchor_position.y, "move command should use the protest anchor y")
end)

test("preserved immediate protest attacks the nearest eligible blocking building", function()
  local ctx = new_test_context()
  local target = new_target(ctx.surface, 99, 20, 20)
  local pipe = new_obstacle(ctx.surface, 198, 4.5, 4.5, "pipe")
  local underground_pipe = new_obstacle(ctx.surface, 197, 5, 5, "pipe-to-ground")
  local belt = new_obstacle(ctx.surface, 196, 5.5, 5.5, "transport-belt")
  local inserter = new_obstacle(ctx.surface, 195, 6, 6, "inserter")
  local admin_station = new_obstacle(ctx.surface, 194, 6.5, 6.5, "container", "admin-station")
  local nonblocking_furnace = new_obstacle(ctx.surface, 193, 6.5, 6.5, "furnace", "stone-furnace", {item = true})
  local farther_building = new_obstacle(ctx.surface, 192, 7, 6.5, "assembling-machine", "assembling-machine-1")
  local obstacle = new_obstacle(ctx.surface, 199, 6.5, 6, "furnace", "stone-furnace")
  ctx.set_protest_targets({target})
  ctx.set_protest_obstacles({
    pipe,
    underground_pipe,
    belt,
    inserter,
    admin_station,
    nonblocking_furnace,
    farther_building,
    obstacle,
  })

  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 4},
    force = "player",
  }

  assert_true(ctx.controller.trigger_immediate_protest(entity, ctx.surface, nil, {preserve_entity = true}), "preserved protest should succeed")

  local request_id = ctx.get_pending_request_id()
  local info = storage.waiting_biters[entity.unit_number]
  assert_true(info.target_building == target, "preserved protest should eagerly claim the target before validation")

  ctx.controller.on_script_path_request_finished{
    id = request_id,
    path = nil,
  }

  assert_true(info.target_building == nil, "failed path validation should clear the eager protest target")
  assert_true(info.protest_obstacle_attacking == true, "failed path validation should start a bounded obstruction attack")
  assert_true(info.protest_anchor_position == nil, "obstruction attack should clear the optimistic protest anchor")
  assert_eq(entity.force, game.forces["administratorio-hard-mode-biters"], "obstruction attacker should temporarily become hostile")
  assert_true(ctx.get_last_attack_command() ~= nil, "failed path validation should issue an explicit attack command")
  assert_eq(ctx.get_last_attack_command().target, obstacle, "the attack command should skip excluded infrastructure and choose the nearest physically blocking building")
  assert_eq(ctx.get_last_attack_command().distraction, defines.distraction.none, "the breach attacker should remain focused on its assigned obstruction")
  assert_eq(ctx.get_move_command_count(), 1, "failed path validation must not issue another unreachable movement command")
  assert_true(info.next_protest_target_retry_tick ~= nil, "failed path validation should schedule another target search")

  local retry_tick = info.next_protest_target_retry_tick
  local path_count = ctx.get_path_request_count()
  game.tick = 1
  ctx.controller.on_ai_command_completed{
    unit_number = entity.unit_number,
    result = 1,
  }
  ctx.controller.process_protest_pacing(ctx.surface)
  assert_eq(ctx.get_path_request_count(), path_count, "a failed attack command must not restart pathfinding immediately")

  game.tick = 70
  ctx.controller.on_protest_target_removed(obstacle)
  assert_true(retry_tick > game.tick, "test setup should begin with a future retry")
  assert_true(info.protest_obstacle_attacking ~= true, "destroying an obstruction should leave attack mode immediately")
  assert_true(info.target_building == target, "destroying an obstruction should preserve the real protest destination")
  obstacle.valid = false
  ctx.controller.process_protest_pacing(ctx.surface)
  assert_eq(ctx.get_path_request_count(), path_count, "the demolished building should resume its validated route without another path request")
  assert_eq(ctx.get_move_command_count(), 2, "the demolished building should immediately issue the preserved destination command")
  assert_eq(entity.force, game.forces.neutral, "route resumption should restore the managed ceasefire force")
end)

test("normal-load path failure tries the next historic protest candidate when no obstruction exists", function()
  local ctx = new_test_context()
  local first_target = new_target(ctx.surface, 107, 20, 20)
  local second_target = new_target(ctx.surface, 108, 30, 30)
  ctx.set_protest_targets({first_target, second_target})
  ctx.set_protest_obstacles({})

  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 4},
    force = "player",
  }
  assert_true(ctx.controller.trigger_immediate_protest(entity, ctx.surface, nil, {preserve_entity = true}))

  local first_request_id = ctx.get_pending_request_id()
  ctx.controller.on_script_path_request_finished{
    id = first_request_id,
    path = nil,
  }

  local info = storage.waiting_biters[entity.unit_number]
  assert_true(info.pending_path_request_id ~= nil, "normal load should validate the next candidate instead of parking immediately")
  assert_true(info.pending_path_request_id ~= first_request_id, "the fallback should create a distinct path request")
  assert_eq(info.pending_protest_reserved_target, second_target, "the fallback request should preserve the historic next-candidate order")
  assert_true(info.protest_path_retry_deferred ~= true, "normal-load candidate fallback should not enter high-load deferral")
end)

test("building breach selection never turns around to attack an obstruction behind the route", function()
  local ctx = new_test_context()
  local target = new_target(ctx.surface, 117, 20, 4)
  local behind = new_obstacle(ctx.surface, 226, 3, 4, "furnace", "stone-furnace")
  local forward = new_obstacle(ctx.surface, 227, 6, 4, "furnace", "stone-furnace")
  ctx.set_protest_targets({target})
  ctx.set_protest_obstacles({behind, forward})

  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 4},
    force = "player",
  }
  assert_true(ctx.controller.trigger_immediate_protest(entity, ctx.surface, nil, {preserve_entity = true}))
  ctx.controller.on_script_path_request_finished{
    id = ctx.get_pending_request_id(),
    path = nil,
  }

  assert_eq(ctx.get_last_attack_command().target, forward, "breach selection should remain forward even when a closer building is behind")
end)

test("failed protest paths may breach one aligned regular pipe without retargeting the protest", function()
  local ctx = new_test_context()
  local target = new_target(ctx.surface, 110, 20, 20)
  local pipe = new_obstacle(ctx.surface, 210, 5, 5, "pipe")
  ctx.set_protest_targets({target})
  ctx.set_protest_obstacles({
    pipe,
    new_obstacle(ctx.surface, 211, 6, 6, "pipe-to-ground"),
    new_obstacle(ctx.surface, 212, 7, 7, "transport-belt"),
    new_obstacle(ctx.surface, 213, 8, 8, "inserter"),
    new_obstacle(ctx.surface, 214, 9, 9, "container", "admin-station"),
  })

  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 4},
    force = "player",
  }
  assert_true(ctx.controller.trigger_immediate_protest(entity, ctx.surface, nil, {preserve_entity = true}))
  ctx.controller.on_script_path_request_finished{
    id = ctx.get_pending_request_id(),
    path = nil,
  }

  local info = storage.waiting_biters[entity.unit_number]
  assert_eq(ctx.get_attack_command_count(), 1, "an aligned regular pipe should receive one bounded breach command")
  assert_eq(ctx.get_last_attack_command().target, pipe, "the aligned regular pipe should be the incidental obstruction")
  assert_eq(info.protest_obstacle_target_kind, "pipe-breach", "the pipe must be classified as a breach, not a building target")
  assert_eq(info.protest_obstacle_goal_target, target, "the real protest destination must remain the building beyond the pipe")
  assert_true(info.target_building == nil, "the pipe must never become the protest target")

  ctx.controller.on_ai_command_completed{
    unit_number = entity.unit_number,
    result = defines.behavior_result.success,
  }
  assert_eq(ctx.get_attack_command_count(), 2, "a successful bite should immediately continue attacking a surviving pipe")
  assert_eq(info.protest_obstacle_command_failures, 0, "a successful bite must not consume the path-failure retry budget")
end)

test("failed protest paths use an existing pipe-wall gap before attacking", function()
  local ctx = new_test_context()
  local target = new_target(ctx.surface, 161, 20, 6)
  ctx.set_protest_targets({target})
  ctx.set_protest_obstacles({
    new_obstacle(ctx.surface, 230, 6, 4, "pipe"),
    new_obstacle(ctx.surface, 231, 6, 5, "pipe"),
    new_obstacle(ctx.surface, 232, 6, 7, "pipe"),
    new_obstacle(ctx.surface, 233, 6, 8, "pipe"),
  })
  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 6},
    force = "player",
  }
  assert_true(ctx.controller.trigger_immediate_protest(entity, ctx.surface, nil, {preserve_entity = true}))

  ctx.controller.on_script_path_request_finished{
    id = ctx.get_pending_request_id(),
    path = nil,
  }

  local info = storage.waiting_biters[entity.unit_number]
  assert_eq(ctx.get_attack_command_count(), 0, "an existing wall gap must suppress a redundant pipe attack")
  assert_true(info.protest_pipe_gap_waypoint ~= nil, "the protester should retain the temporary gap waypoint")
  assert_true(info.target_building == target, "gap routing must retain the real building as the protest target")
  assert_true(info.protest_anchor_position == nil, "a temporary gap waypoint must not become the final protest anchor")

  entity.position = {
    x = info.protest_pipe_gap_waypoint.x,
    y = info.protest_pipe_gap_waypoint.y,
  }
  ctx.controller.process_frustration_and_protests(ctx.surface)
  assert_true(info.arrived_at_building ~= true, "reaching only the wall gap must not mark the distant protest as arrived")

  ctx.controller.on_ai_command_completed{
    unit_number = entity.unit_number,
    result = defines.behavior_result.success,
  }
  assert_true(info.protest_pipe_gap_waypoint == nil, "reaching the gap should clear the temporary waypoint")
  assert_eq(ctx.get_move_command_count(), 3, "reaching the gap should continue toward the real target")
  assert_true(
    math.abs(ctx.get_last_move_command().destination.x - target.position.x) < 1,
    "the post-gap route should point near the real target rather than back to the wall gap"
  )
end)

test("saved false arrivals at a wall gap resume toward the real protest target", function()
  local ctx = new_test_context()
  local target = new_target(ctx.surface, 162, 50, 6)
  ctx.set_protest_targets({target})
  ctx.set_protest_obstacles({
    new_obstacle(ctx.surface, 234, 6, 4, "pipe"),
    new_obstacle(ctx.surface, 235, 6, 5, "pipe"),
    new_obstacle(ctx.surface, 236, 6, 7, "pipe"),
    new_obstacle(ctx.surface, 237, 6, 8, "pipe"),
  })
  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 6},
    force = "player",
  }
  assert_true(ctx.controller.trigger_immediate_protest(entity, ctx.surface, nil, {preserve_entity = true}))
  ctx.controller.on_script_path_request_finished{
    id = ctx.get_pending_request_id(),
    path = nil,
  }

  local info = storage.waiting_biters[entity.unit_number]
  local waypoint = info.protest_pipe_gap_waypoint
  entity.position = {x = waypoint.x, y = waypoint.y}
  entity.active = false
  info.arrived_at_building = true
  info.protest_parked = true
  info.protest_anchor_position = {x = waypoint.x, y = waypoint.y}
  info.protest_pipe_gap_goal = {x = waypoint.x, y = waypoint.y}

  ctx.controller.process_protest_pacing(ctx.surface)

  assert_true(info.arrived_at_building ~= true, "the distant wall position must be reopened as a false arrival")
  assert_true(info.protest_parked ~= true, "the recovered protester must leave parked state")
  assert_true(info.protest_pipe_gap_waypoint == nil, "the stale gap transition must be cleared")
  assert_true(info.target_building == target, "recovery must preserve the real grievance target")
  assert_true(
    math.abs(ctx.get_last_move_command().destination.x - target.position.x) < 0.01,
    "the recovered route should head toward the building, not the stale wall waypoint"
  )
end)

test("a long post-gap route advances in bounded hops and preserves its target on failure", function()
  local ctx = new_test_context()
  local target = new_target(ctx.surface, 164, 200, 6)
  ctx.set_protest_targets({target})
  ctx.set_protest_obstacles({
    new_obstacle(ctx.surface, 274, 6, 4, "pipe"),
    new_obstacle(ctx.surface, 275, 6, 5, "pipe"),
    new_obstacle(ctx.surface, 276, 6, 7, "pipe"),
    new_obstacle(ctx.surface, 277, 6, 8, "pipe"),
  })
  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 6},
    force = "player",
  }
  assert_true(ctx.controller.trigger_immediate_protest(entity, ctx.surface, nil, {preserve_entity = true}))
  ctx.controller.on_script_path_request_finished{
    id = ctx.get_pending_request_id(),
    path = nil,
  }

  local info = storage.waiting_biters[entity.unit_number]
  entity.position = {
    x = info.protest_pipe_gap_waypoint.x,
    y = info.protest_pipe_gap_waypoint.y,
  }
  ctx.controller.on_ai_command_completed{
    unit_number = entity.unit_number,
    result = defines.behavior_result.success,
  }

  assert_true(info.protest_route_hop_waypoint ~= nil, "a distant destination should use a bounded interior hop")
  assert_true(info.target_building == target, "the post-gap hop must retain the real protest target")
  assert_true(
    math.abs(info.protest_anchor_position.x - target.position.x) < 1,
    "the hop must not replace the final protest anchor"
  )
  assert_true(
    ctx.get_last_move_command().destination.x < target.position.x - 20,
    "the first interior command should be a short hop rather than a full-map route"
  )

  ctx.controller.on_ai_command_completed{
    unit_number = entity.unit_number,
    result = defines.behavior_result.fail,
  }
  assert_true(info.protest_route_retry_tick ~= nil, "a failed clear interior hop should schedule a bounded retry")
  assert_true(info.target_building == target, "a failed interior hop must not discard the grievance target")
  assert_eq(ctx.get_attack_command_count(), 0, "the wall behind the crossed gap must not be attacked")

  local move_count = ctx.get_move_command_count()
  game.tick = info.protest_route_retry_tick
  ctx.controller.process_protest_pacing(ctx.surface)
  assert_eq(ctx.get_move_command_count(), move_count + 1, "the bounded retry should resume the interior route")
  assert_true(info.protest_route_hop_waypoint ~= nil, "the retried long route should remain staged")
end)

test("a pipe behind a crossed wall is never selected for another breach", function()
  local ctx = new_test_context()
  local target = new_target(ctx.surface, 163, 20, 6)
  local crossed_pipe = new_obstacle(ctx.surface, 238, 6, 6, "pipe")
  ctx.set_protest_targets({target})
  ctx.set_protest_obstacles({crossed_pipe})
  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 7, y = 6},
    force = "player",
  }
  assert_true(ctx.controller.trigger_immediate_protest(entity, ctx.surface, nil, {preserve_entity = true}))
  ctx.controller.on_script_path_request_finished{
    id = ctx.get_pending_request_id(),
    path = nil,
  }

  local info = storage.waiting_biters[entity.unit_number]
  assert_eq(ctx.get_attack_command_count(), 0, "a segment behind the biter must not receive an attack command")
  assert_true(info.protest_obstacle_attacking ~= true, "crossing the wall must not re-enter breach state")
end)

test("an active pipe breacher notices a newly opened wall gap", function()
  local ctx = new_test_context()
  local target = new_target(ctx.surface, 166, 20, 6)
  local attacked_pipe = new_obstacle(ctx.surface, 270, 6, 5, "pipe")
  ctx.set_protest_targets({target})
  ctx.set_protest_obstacles({attacked_pipe})
  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 5},
    force = "player",
  }
  assert_true(ctx.controller.trigger_immediate_protest(entity, ctx.surface, nil, {preserve_entity = true}))
  ctx.controller.on_script_path_request_finished{
    id = ctx.get_pending_request_id(),
    path = nil,
  }

  local info = storage.waiting_biters[entity.unit_number]
  assert_true(info.protest_obstacle_attacking == true, "the initially solid local segment should enter pipe breach mode")
  ctx.set_protest_obstacles({
    new_obstacle(ctx.surface, 269, 6, 4, "pipe"),
    attacked_pipe,
    new_obstacle(ctx.surface, 271, 6, 7, "pipe"),
    new_obstacle(ctx.surface, 272, 6, 8, "pipe"),
  })
  game.tick = info.protest_pipe_gap_next_check_tick
  ctx.controller.process_protest_pacing(ctx.surface)

  assert_true(info.protest_obstacle_attacking ~= true, "a new wall gap should cancel the hostile pipe breach")
  assert_true(info.protest_pipe_gap_waypoint ~= nil, "the former breacher should route through the new gap")
  assert_eq(ctx.get_attack_command_count(), 1, "gap discovery must not issue another attack command")
  assert_eq(entity.force, game.forces.neutral, "gap discovery should restore the managed ceasefire force")
end)

test("underground pipes and transport infrastructure are never breach targets", function()
  local ctx = new_test_context()
  local target = new_target(ctx.surface, 112, 20, 20)
  ctx.set_protest_targets({target})
  ctx.set_protest_obstacles({
    new_obstacle(ctx.surface, 216, 4, 8, "pipe"),
    new_obstacle(ctx.surface, 217, 6, 6, "pipe-to-ground"),
    new_obstacle(ctx.surface, 218, 7, 7, "transport-belt"),
    new_obstacle(ctx.surface, 219, 8, 8, "inserter"),
    new_obstacle(ctx.surface, 220, 9, 9, "container", "admin-station"),
  })

  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 4},
    force = "player",
  }
  assert_true(ctx.controller.trigger_immediate_protest(entity, ctx.surface, nil, {preserve_entity = true}))
  ctx.controller.on_script_path_request_finished{
    id = ctx.get_pending_request_id(),
    path = nil,
  }

  local info = storage.waiting_biters[entity.unit_number]
  assert_eq(ctx.get_attack_command_count(), 0, "off-route pipes and excluded infrastructure must not receive attack commands")
  assert_true(info.protest_obstacle_attacking ~= true, "no eligible aligned breach should leave the protester non-hostile")
  assert_true(info.protest_path_retry_deferred == true, "the blocked protester should wait for its bounded route retry")
  assert_true(entity.active == false, "a blocked protester with no eligible breach should remain inactive")
end)

test("a failed desk route breaches an aligned pipe then resumes the same desk destination", function()
  local ctx = new_test_context()
  local pipe = new_obstacle(ctx.surface, 221, 6, 6, "pipe")
  ctx.set_protest_obstacles({pipe})
  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 4},
    force = "neutral",
  }
  local destination = {x = 20, y = 20}
  local info = {
    entity = entity,
    tracked_unit_number = entity.unit_number,
    state = "pathfinding",
    desk_id = 999,
    desk_dest = destination,
    frustration = 0,
  }
  storage.waiting_biters[entity.unit_number] = info
  storage.waiting_biter_state_index.pathfinding[entity.unit_number] = true

  ctx.controller.on_ai_command_completed{
    unit_number = entity.unit_number,
    result = defines.behavior_result.fail,
  }

  assert_true(info.desk_route_breach_attacking == true, "the failed desk route should enter controlled breach mode")
  assert_eq(ctx.get_last_attack_command().target, pipe, "desk routing should breach the aligned regular pipe")
  assert_eq(info.desk_id, 999, "breach mode must preserve the administrative destination")

  ctx.controller.on_ai_command_completed{
    unit_number = entity.unit_number,
    result = defines.behavior_result.success,
  }
  assert_eq(ctx.get_attack_command_count(), 2, "a successful desk-route bite should immediately continue on a surviving pipe")
  assert_eq(info.desk_route_breach_command_failures, 0, "a successful bite must not count as a desk-route failure")

  ctx.controller.on_ai_command_completed{
    unit_number = entity.unit_number,
    result = defines.behavior_result.fail,
  }
  assert_eq(ctx.get_attack_command_count(), 3, "a transient desk-route attack failure should continue immediately")
  assert_eq(ctx.get_last_attack_command().target, pipe, "the desk breacher must stay focused on the surviving pipe")

  ctx.controller.on_protest_target_removed(pipe)
  assert_true(info.desk_route_breach_attacking ~= true, "destroying the pipe should leave breach mode")
  assert_eq(ctx.get_desk_route_command_count(), 1, "destroying the pipe should resume the desk route exactly once")
  assert_eq(ctx.get_last_desk_route_destination(), destination, "the resumed command should use the original desk destination")
  assert_eq(entity.force, game.forces.neutral, "the visitor should regain its managed force after the breach")
end)

test("an inactive stalled desk route with no forward wall is reissued", function()
  local ctx = new_test_context()
  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 4},
    force = "neutral",
  }
  entity.active = false
  local destination = {x = 20, y = 4}
  local info = {
    entity = entity,
    tracked_unit_number = entity.unit_number,
    state = "pathfinding",
    desk_id = 1001,
    desk_dest = destination,
    frustration = 0,
    desk_route_started_tick = 0,
    desk_route_last_progress_tick = 0,
    desk_route_best_distance_sq = 256,
  }
  storage.waiting_biters[entity.unit_number] = info
  storage.waiting_biter_state_index.pathfinding[entity.unit_number] = true
  game.tick = 10 * 60

  ctx.controller.process_frustration_and_protests(ctx.surface)

  assert_eq(ctx.get_desk_route_command_count(), 1, "the stalled visitor should receive a fresh desk route")
  assert_eq(ctx.get_last_desk_route_destination(), destination, "the retry must preserve the assigned desk destination")
  assert_true(entity.active == true, "the stalled visitor should be reactivated")
end)

test("a failed desk route uses an existing pipe-wall gap before breaching", function()
  local ctx = new_test_context()
  ctx.set_protest_obstacles({
    new_obstacle(ctx.surface, 240, 6, 4, "pipe"),
    new_obstacle(ctx.surface, 241, 6, 5, "pipe"),
    new_obstacle(ctx.surface, 242, 6, 7, "pipe"),
    new_obstacle(ctx.surface, 243, 6, 8, "pipe"),
  })
  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 6},
    force = "neutral",
  }
  local destination = {x = 20, y = 6}
  local info = {
    entity = entity,
    tracked_unit_number = entity.unit_number,
    state = "pathfinding",
    desk_id = 999,
    desk_dest = destination,
    frustration = 0,
  }
  storage.waiting_biters[entity.unit_number] = info
  storage.waiting_biter_state_index.pathfinding[entity.unit_number] = true

  ctx.controller.on_ai_command_completed{
    unit_number = entity.unit_number,
    result = defines.behavior_result.fail,
  }

  assert_eq(ctx.get_attack_command_count(), 0, "an existing wall gap must suppress a redundant desk-route pipe attack")
  assert_true(info.desk_route_gap_waypoint ~= nil, "the visitor should retain the temporary gap waypoint")
  assert_eq(ctx.get_desk_route_command_count(), 1, "the visitor should receive one route command through the gap")

  ctx.controller.on_ai_command_completed{
    unit_number = entity.unit_number,
    result = defines.behavior_result.success,
  }
  assert_true(info.desk_route_gap_waypoint == nil, "reaching the gap should clear the desk waypoint")
  assert_eq(ctx.get_desk_route_command_count(), 2, "reaching the gap should resume the original desk route")
  assert_eq(ctx.get_last_desk_route_destination(), destination, "the post-gap command should retain the desk destination")
end)

test("a saved desk-route pipe attacker migrates to an existing wall gap", function()
  local ctx = new_test_context()
  local attacked_pipe = new_obstacle(ctx.surface, 250, 6, 5, "pipe")
  ctx.set_protest_obstacles({
    new_obstacle(ctx.surface, 249, 6, 4, "pipe"),
    attacked_pipe,
    new_obstacle(ctx.surface, 251, 6, 7, "pipe"),
    new_obstacle(ctx.surface, 252, 6, 8, "pipe"),
  })
  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 6},
    force = "administratorio-hard-mode-biters",
  }
  local info = {
    entity = entity,
    tracked_unit_number = entity.unit_number,
    state = "pathfinding",
    desk_id = 999,
    desk_dest = {x = 20, y = 6},
    frustration = 0,
    desk_route_breach_attacking = true,
    desk_route_breach_target = attacked_pipe,
    desk_route_breach_target_unit_number = attacked_pipe.unit_number,
    desk_route_breach_gap_checked_target_unit_number = attacked_pipe.unit_number,
  }
  storage.waiting_biters[entity.unit_number] = info
  storage.waiting_biter_state_index.pathfinding[entity.unit_number] = true
  storage.desk_route_breach_attackers = {[entity.unit_number] = true}

  ctx.controller.process_frustration_and_protests(ctx.surface)

  assert_true(info.desk_route_breach_attacking ~= true, "saved breach state should stop attacking once a usable gap is detected")
  assert_true(info.desk_route_gap_waypoint ~= nil, "saved breach state should migrate to the gap waypoint")
  assert_eq(ctx.get_desk_route_command_count(), 1, "migration should issue one neutral route command through the gap")
  assert_eq(entity.force, game.forces.neutral, "the migrated visitor should immediately leave the hostile breach force")
end)

test("protesters saved while protesting a pipe migrate to a real target and breach the old pipe", function()
  local ctx = new_test_context()
  local real_target = new_target(ctx.surface, 113, 20, 20)
  local old_pipe_target = new_obstacle(ctx.surface, 223, 6, 6, "pipe")
  old_pipe_target.active = false
  ctx.set_protest_targets({real_target})
  ctx.set_protest_obstacles({old_pipe_target})
  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 4},
    force = "neutral",
  }
  local info = {
    entity = entity,
    tracked_unit_number = entity.unit_number,
    state = "protesting",
    target_building = old_pipe_target,
    arrived_at_building = true,
    frustration = 600,
    complaints = {"ticket-landscape"},
  }
  storage.waiting_biters[entity.unit_number] = info
  storage.waiting_biter_state_index.protesting[entity.unit_number] = true

  ctx.controller.process_protest_pacing(ctx.surface)

  assert_true(info.target_building == nil, "the obsolete pipe must be cleared as the current protest target")
  assert_eq(info.pending_protest_reserved_target, real_target, "the migrated protester should reserve a legitimate protest building")
  assert_true(old_pipe_target.active == true, "migration should release the obsolete protest shutdown on the pipe")
  assert_true(ctx.get_pending_request_id() ~= nil, "the migrated protester should validate a route to the real building")

  ctx.controller.on_script_path_request_finished{
    id = ctx.get_pending_request_id(),
    path = nil,
  }
  assert_true(info.protest_obstacle_attacking == true, "the migrated protester should breach the aligned old pipe after route failure")
  assert_eq(ctx.get_last_attack_command().target, old_pipe_target, "the old pipe may be breached but must not remain the protest target")
  assert_eq(info.protest_obstacle_goal_target, real_target, "the real building should remain the objective beyond the breach")
end)

test("an existing en-route protester stalled at a pipe enters breach mode", function()
  local ctx = new_test_context()
  local real_target = new_target(ctx.surface, 114, 20, 20)
  local pipe = new_obstacle(ctx.surface, 224, 6, 6, "pipe")
  ctx.set_protest_targets({real_target})
  ctx.set_protest_obstacles({pipe})
  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 4},
    force = "neutral",
  }
  local info = {
    entity = entity,
    tracked_unit_number = entity.unit_number,
    state = "protesting",
    target_building = real_target,
    frustration = 600,
    complaints = {"ticket-landscape"},
  }
  storage.waiting_biters[entity.unit_number] = info
  storage.waiting_biter_state_index.protesting[entity.unit_number] = true
  game.tick = 10 * 60

  ctx.controller.process_protest_pacing(ctx.surface)

  assert_true(info.protest_obstacle_attacking == true, "a legacy protest route without progress metadata should be inspected immediately")
  assert_eq(ctx.get_last_attack_command().target, pipe, "the stalled existing protester should breach the aligned ordinary pipe")
  assert_eq(info.protest_obstacle_goal_target, real_target, "stall recovery must retain the real building as its objective")
end)

test("a stalled desk command starts a bounded aligned pipe breach without an AI failure event", function()
  local ctx = new_test_context()
  local pipe = new_obstacle(ctx.surface, 222, 15, 0, "pipe")
  ctx.set_protest_obstacles({pipe})
  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 14, y = 0},
    force = "neutral",
  }
  local destination = {x = 20, y = 0}
  local info = {
    entity = entity,
    tracked_unit_number = entity.unit_number,
    state = "pathfinding",
    desk_id = 1000,
    desk_dest = destination,
    frustration = 0,
    desk_route_started_tick = 0,
    desk_route_last_progress_tick = 0,
    desk_route_best_distance_sq = 36,
  }
  storage.waiting_biters[entity.unit_number] = info
  storage.waiting_biter_state_index.pathfinding[entity.unit_number] = true
  game.tick = 10 * 60

  ctx.controller.process_frustration_and_protests(ctx.surface)

  assert_true(info.desk_route_breach_attacking == true, "a route with no meaningful progress should enter controlled breach mode")
  assert_eq(ctx.get_last_attack_command().target, pipe, "stall recovery should choose only the aligned ordinary pipe")
  assert_eq(info.desk_id, 1000, "stall recovery must keep the original desk assignment")
end)

test("a surviving obstruction remains under continuous attack after transient command failures", function()
  local ctx = new_test_context()
  local target = new_target(ctx.surface, 111, 20, 20)
  local obstacle = new_obstacle(ctx.surface, 215, 6, 6, "furnace", "stone-furnace")
  ctx.set_protest_targets({target})
  ctx.set_protest_obstacles({obstacle})

  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 4},
    force = "player",
  }
  assert_true(ctx.controller.trigger_immediate_protest(entity, ctx.surface, nil, {preserve_entity = true}))
  ctx.controller.on_script_path_request_finished{
    id = ctx.get_pending_request_id(),
    path = nil,
  }

  local info = storage.waiting_biters[entity.unit_number]
  assert_eq(ctx.get_attack_command_count(), 1, "the first building attack should be issued")

  ctx.controller.on_ai_command_completed{
    unit_number = entity.unit_number,
    result = 1,
  }
  assert_eq(ctx.get_attack_command_count(), 2, "a transient failure should immediately reissue the same attack")
  assert_eq(ctx.get_last_attack_command().target, obstacle, "the retry must retain the surviving obstruction")
  assert_eq(info.protest_obstacle_command_failures, 0, "a live target should not consume a terminal failure budget")

  ctx.controller.on_ai_command_completed{
    unit_number = entity.unit_number,
    result = 1,
  }
  assert_eq(ctx.get_attack_command_count(), 3, "each completed attempt should continue without a pause")
  assert_true(info.protest_obstacle_attacking == true, "the attacker must stay assigned while the target survives")
  assert_true(entity.active == true, "the assigned attacker must remain active")
  assert_eq(entity.force, game.forces["administratorio-hard-mode-biters"], "the active breacher must retain its attack force")
end)

test("destroying a breach route's grievance target stops pointless demolition and retargets", function()
  local ctx = new_test_context()
  local removed_target = new_target(ctx.surface, 115, 20, 20)
  local replacement_target = new_target(ctx.surface, 116, 30, 30)
  local obstacle = new_obstacle(ctx.surface, 225, 6, 6, "furnace", "stone-furnace")
  ctx.set_protest_targets({removed_target, replacement_target})
  ctx.set_protest_obstacles({obstacle})

  local entity = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 4},
    force = "player",
  }
  assert_true(ctx.controller.trigger_immediate_protest(entity, ctx.surface, nil, {preserve_entity = true}))
  ctx.controller.on_script_path_request_finished{
    id = ctx.get_pending_request_id(),
    path = nil,
  }

  local info = storage.waiting_biters[entity.unit_number]
  assert_true(info.protest_obstacle_attacking == true, "the setup should enter breach mode")
  assert_eq(info.protest_obstacle_goal_target, removed_target, "the removed building should be the preserved grievance")

  ctx.controller.on_protest_target_removed(removed_target)

  assert_true(info.protest_obstacle_attacking ~= true, "target loss should cancel demolition of the unrelated obstruction")
  assert_eq(entity.force, game.forces.neutral, "target loss should restore the managed ceasefire force")
  assert_eq(info.pending_protest_reserved_target, replacement_target, "target loss should immediately reserve a replacement grievance")
  assert_true(info.pending_path_request_id ~= nil, "target loss should validate the replacement route")
  assert_eq(ctx.get_attack_command_count(), 1, "target loss must not issue another attack against the obsolete route")
end)

test("obstruction attacks are capped while excess protesters remain deferred", function()
  local ctx = new_test_context(false, {
    PROTEST_OBSTACLE_ATTACKER_LIMIT = 1,
  })
  local target = new_target(ctx.surface, 109, 20, 20)
  local obstacle = new_obstacle(ctx.surface, 209, 6, 6, "furnace", "stone-furnace")
  ctx.set_protest_targets({target})
  ctx.set_protest_obstacles({obstacle})

  local first = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 4, y = 4},
    force = "player",
  }
  assert_true(ctx.controller.trigger_immediate_protest(first, ctx.surface, nil, {preserve_entity = true}))
  ctx.controller.on_script_path_request_finished{
    id = ctx.get_pending_request_id(),
    path = nil,
  }

  local second = ctx.surface.create_entity{
    name = "biterport-worker",
    position = {x = 5, y = 5},
    force = "player",
  }
  assert_true(ctx.controller.trigger_immediate_protest(second, ctx.surface, nil, {preserve_entity = true}))
  ctx.controller.on_script_path_request_finished{
    id = ctx.get_pending_request_id(),
    path = nil,
  }

  local first_info = storage.waiting_biters[first.unit_number]
  local second_info = storage.waiting_biters[second.unit_number]
  assert_true(first_info.protest_obstacle_attacking == true, "the first blocked protester should clear obstructions")
  assert_true(second_info.protest_obstacle_attacking ~= true, "the attacker cap should prevent a second obstruction attack")
  assert_true(second_info.protest_path_retry_deferred == true, "excess blocked protesters should wait for a later path retry")
  assert_true(second.active == false, "deferred blocked protesters should stay inactive")
end)

test("invalid protest targets are cleared during processing so the biter can recover", function()
  local ctx = new_test_context()
  local dead_target = new_target(ctx.surface, 93, 8, 8)
  local fallback_target = new_target(ctx.surface, 94, 20, 20)
  dead_target.valid = false
  ctx.set_protest_targets({fallback_target})

  local entity = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 8, y = 8},
    force = "neutral",
  }
  entity.unit_number = 6

  local info = {
    state = "protesting",
    entity = entity,
    entity_name = entity.name,
    tracked_unit_number = 6,
    target_building = dead_target,
    arrived_at_building = true,
    complaints = {"ticket-landscape"},
  }
  storage.waiting_biters[6] = info
  storage.waiting_biter_state_index.protesting[6] = true

  ctx.controller.process_frustration_and_protests(ctx.surface)

  assert_true(ctx.get_pending_request_id() ~= nil, "processing should re-request a protest target when the current one is invalid")
  assert_true(info.target_building == nil, "processing should clear the invalid protest target before rerouting")
end)

test("stale cached protest targets are filtered before selecting a new target", function()
  local ctx = new_test_context()
  local stale_target = new_target(ctx.surface, 95, 10, 10)
  local fallback_target = new_target(ctx.surface, 96, 24, 24)
  ctx.set_protest_targets({stale_target, fallback_target})

  local first_entity = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 1, y = 1},
    force = "neutral",
  }
  first_entity.unit_number = 10

  local first_info = {
    state = "waiting",
    entity = first_entity,
    entity_name = first_entity.name,
    tracked_unit_number = 10,
    desk_id = 1,
    frustration = 600,
    complaints = {"ticket-landscape"},
  }
  storage.waiting_biters[10] = first_info
  storage.waiting_biter_state_index.waiting[10] = true

  ctx.controller.process_frustration_and_protests(ctx.surface)

  stale_target.valid = false
  ctx.set_protest_targets({fallback_target})

  local second_entity = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 2, y = 2},
    force = "neutral",
  }
  second_entity.unit_number = 11

  local second_info = {
    state = "waiting",
    entity = second_entity,
    entity_name = second_entity.name,
    tracked_unit_number = 11,
    desk_id = 1,
    frustration = 600,
    complaints = {"ticket-landscape"},
  }
  storage.waiting_biters[11] = second_info
  storage.waiting_biter_state_index.waiting[11] = true

  ctx.controller.process_frustration_and_protests(ctx.surface)

  local request_id = ctx.get_pending_request_id()
  assert_true(request_id ~= nil, "rerouting with a stale cached target should still request a path")

  ctx.controller.on_script_path_request_finished{
    id = request_id,
    path = {{x = 18, y = 18}},
  }

  assert_true(second_info.target_building == fallback_target, "stale cached protest targets should be ignored during reassignment")
end)

test("filtering a stale cached target does not duplicate earlier targets", function()
  local ctx = new_test_context(true)
  local retained_target = new_target(ctx.surface, 102, 1, 1)
  local stale_target = new_target(ctx.surface, 103, 12, 12)
  local fallback_target = new_target(ctx.surface, 104, 24, 24)
  ctx.set_protest_targets({retained_target, stale_target, fallback_target})

  local retained_position = retained_target.position
  local retained_position_reads = 0
  retained_target.position = nil
  setmetatable(retained_target, {
    __index = function(target, key)
      if key == "position" then
        retained_position_reads = retained_position_reads + 1
        return retained_position
      end
      return rawget(target, key)
    end,
  })

  local warmup_entity = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 0, y = 0},
    force = "neutral",
  }
  warmup_entity.unit_number = 20
  local warmup_info = {
    state = "waiting",
    entity = warmup_entity,
    entity_name = warmup_entity.name,
    tracked_unit_number = 20,
    desk_id = 1,
    frustration = 600,
    complaints = {"ticket-landscape"},
  }
  storage.waiting_biters[20] = warmup_info
  storage.waiting_biter_state_index.waiting[20] = true
  ctx.controller.process_frustration_and_protests(ctx.surface)

  -- The next target lookup must prune the middle entry from the cached list.
  storage.waiting_biters[20] = nil
  storage.waiting_biter_state_index.waiting[20] = nil
  storage.waiting_biter_state_index.protesting[20] = nil
  stale_target.valid = false
  retained_position_reads = 0

  local attacker = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 24, y = 24},
    force = "neutral",
  }
  attacker.unit_number = 21
  local attacker_info = {
    state = "protesting",
    entity = attacker,
    entity_name = attacker.name,
    tracked_unit_number = 21,
    hard_mode_attacking = true,
    complaints = {"ticket-landscape"},
  }
  storage.waiting_biters[21] = attacker_info
  storage.waiting_biter_state_index.protesting[21] = true

  ctx.controller.process_protest_pacing(ctx.surface)

  assert_eq(retained_position_reads, 2, "cached validity checks and spatial indexing must not retain a duplicate of the first valid target")
end)

test("removing a protested building ends the protest when no live biter remains", function()
  local ctx = new_test_context()
  local old_target = new_target(ctx.surface, 97, 9, 9)

  local info = {
    state = "protesting",
    entity = nil,
    entity_name = "small-biter",
    tracked_unit_number = 12,
    target_building = old_target,
    arrived_at_building = true,
    complaints = {"ticket-landscape"},
  }
  storage.waiting_biters[12] = info
  storage.waiting_biter_state_index.protesting[12] = true

  ctx.controller.on_protest_target_removed(old_target)

  assert_true(storage.waiting_biters[12] == nil, "missing protesters should be untracked when their protest target is removed")
  assert_true(storage.waiting_biter_state_index.protesting[12] == nil, "missing protesters should leave the protesting index when their target disappears")
end)

test("ending a protest preserves a target that was already disabled", function()
  local ctx = new_test_context()
  local target = new_target(ctx.surface, 101, 12, 12)
  target.active = false

  local entity = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 12, y = 12},
    force = "neutral",
  }
  entity.unit_number = 13

  local info = {
    state = "protesting",
    entity = entity,
    entity_name = entity.name,
    tracked_unit_number = 13,
    target_building = target,
    arrived_at_building = true,
    complaints = {"ticket-landscape"},
  }
  storage.waiting_biters[13] = info
  storage.waiting_biter_state_index.protesting[13] = true

  -- Process one protest tick so the target's pre-protest state is captured.
  ctx.controller.process_frustration_and_protests(ctx.surface)
  ctx.controller.reset_protest_targeting(info, 13)

  assert_eq(target.active, false, "a protest must not reactivate a target that was already disabled")
end)

print(string.format("\n=== PROTEST RETARGETING TESTS ==="))
print(string.format("Passed: %d  Failed: %d  Total: %d", passed, failed, passed + failed))

if #errors > 0 then
  print("\nFAILURES:")
  for i, err in ipairs(errors) do
    print(string.format("  %d) %s", i, err))
  end
  os.exit(1)
else
  print("\nAll tests passed!")
  os.exit(0)
end
