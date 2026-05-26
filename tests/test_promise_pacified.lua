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
  },
  behavior_result = {
    fail = 1,
  },
}

log = function() end

local protest_factory = dofile(mod_root .. "scripts/biters_protests.lua")

local function new_test_context(opts)
  opts = opts or {}
  local state_sets = {
    protesting = {},
    pacified = {},
    returning_home = {},
    waiting = {},
    pathfinding = {},
    attacking = {},
  }
  local create_calls = 0
  local route_calls = 0
  local finalize_calls = 0
  local release_calls = 0
  local last_stop_command = nil
  local last_move_command = nil
  local last_attack_command = nil
  local last_route_initial_frustration = nil
  local last_released_entity = nil
  local pacified_render_calls = 0
  local protest_render_calls = 0
  local desk_available = false
  local next_unit_number = 100
  local hard_mode_capacity = math.floor(600 / 0.70)

  local surface
  surface = {
    index = 1,
    find_entities_filtered = function()
      return surface.protest_targets or {}
    end,
    find_non_colliding_position = function(_, pos)
      return pos
    end,
    create_entity = function(params)
      create_calls = create_calls + 1
      next_unit_number = next_unit_number + 1
      local entity = {
        valid = true,
        name = params.name,
        position = {x = params.position.x, y = params.position.y},
        force = params.force,
        active = true,
        unit_number = next_unit_number,
        surface = surface,
      }
      entity.commandable = {
        set_command = function(command)
          if command.type == defines.command.stop then
            last_stop_command = command
          elseif command.type == defines.command.go_to_location then
            last_move_command = command
          elseif command.type == defines.command.attack then
            last_attack_command = command
          end
        end,
      }
      entity.destroy = function()
        entity.valid = false
      end
      return entity
    end,
    valid = true,
  }

  local desk = {
    valid = true,
    unit_number = 77,
    position = {x = 10, y = 10},
    surface = surface,
  }

  game = {
    tick = 0,
    connected_players = {},
    surfaces = {[1] = surface},
    forces = {
      neutral = {name = "neutral"},
      player = {name = "player"},
      enemy = {name = "enemy"},
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

  local deps = {
    constants = {
      PROTEST_THRESHOLD = 600,
      HARD_MODE_ENABLED = opts.hard_mode == true,
      HARD_MODE_PROTEST_RATIO = 0.70,
      HARD_MODE_FRUSTRATION_CAPACITY = hard_mode_capacity,
      PROMISE_HOLD_TICKS = 60 * 60,
      INVALIDATED_BITER_REVIVE_RETRY_TICKS = 60,
      PROTEST_TARGET_RETRY_TICKS = 5 * 60,
      PROTEST_TARGET_MAX_PROTESTERS = 5,
      PROTEST_TARGET_LOAD_PENALTY = 2500,
      PROTEST_TARGET_SELECTION_JITTER = 250,
      PROTEST_WANDER_MIN_RADIUS = 0.1,
      PROTEST_WANDER_MAX_RADIUS = 0.35,
      PROTEST_WANDER_MIN_MOVE_DISTANCE = 0.08,
      PROTEST_WANDER_ATTEMPTS = 4,
      PROTEST_WANDER_REISSUE_TICKS = 5 * 60,
      PROTEST_WANDER_REISSUE_JITTER_TICKS = 2 * 60,
      PROTEST_STEP_ACTIVE_TICKS = 20,
      PROTEST_MAX_DISTANCE_FROM_TARGET = 3.5,
      PROTEST_ARRIVAL_DISTANCE = 2.25,
      HARD_MODE_ATTACK_REISSUE_TICKS = 5 * 60,
      HARD_MODE_ATTACK_RADIUS = 1.5,
      DESK_SLOT_COMMAND_RADIUS = 0.5,
      DESK_SLOT_ARRIVAL_DISTANCE = 1.0,
      PACIFIED_FRUSTRATION_RATIO = 0.5,
      PACIFIED_ROAM_REISSUE_TICKS = 30,
      PACIFIED_ROAM_REISSUE_JITTER_TICKS = 0,
      FRUST_GROWTH_RATES = {1.5, 1.2, 1.0, 0.8},
      get_individual_frust_tier = function(info)
        local pct = (info.frustration or 0) / 600
        if pct < 0.25 then return 1
        elseif pct < 0.50 then return 2
        elseif pct < 0.75 then return 3
        else return 4 end
      end,
    },
    zones = {
      reassign_slot = function() end,
      get_zone_position = function() return nil end,
      get_queue_pos = function()
        return {x = 0, y = 0}
      end,
      release_slot = function() end,
      get_available_slots = function()
        return desk_available and 1 or 0
      end,
    },
    working_hours = {
      claim_protest_target = function()
        return false
      end,
      release_protest_target = function()
        return false
      end,
      transfer_protest_target = function() end,
    },
    render = {
      destroy_protest_rendering = function() end,
      destroy_protest_chart_tag = function() end,
      ensure_protest_rendering = function()
        protest_render_calls = protest_render_calls + 1
      end,
      ensure_protest_chart_tag = function() end,
      destroy_pacified_rendering = function() end,
      ensure_pacified_rendering = function()
        pacified_render_calls = pacified_render_calls + 1
      end,
      notify_players_of_protest = function() end,
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
    find_nearest_available_desk = function()
      if desk_available then
        return desk
      end
      return nil
    end,
    route_biter_to_desk = function(info, entity, target_desk, opts)
      route_calls = route_calls + 1
      last_route_initial_frustration = opts and opts.initial_frustration or nil
      info.entity = entity
      info.desk_id = target_desk.unit_number
      if opts and opts.initial_frustration ~= nil then
        info.frustration = opts.initial_frustration
      end
      set_waiting_biter_state(info, "pathfinding")
      return true
    end,
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
    get_desk_waiting_destination = function()
      return {x = 0, y = 0}
    end,
    issue_desk_route_command = function() end,
    get_cached_desks = function()
      local desks = {}
      for _, tracked_desk in pairs(storage.admin_desks or {}) do
        desks[#desks + 1] = tracked_desk
      end
      return desks
    end,
    normalize_case_progress = function() end,
    biter_force_name = "neutral",
    get_biter_force = function() return game.forces["neutral"] end,
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
    finalize_pathfinding_biter_arrival = function(info, target_desk)
      finalize_calls = finalize_calls + 1
      info.desk_id = target_desk.unit_number
      set_waiting_biter_state(info, "waiting")
      return true
    end,
    protest_protected_names = {},
    protest_target_names = {},
    protest_target_types = {},
    adopt_redirected_biter = function(_, entity)
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
    release_as_regular_enemy = function(entity)
      release_calls = release_calls + 1
      last_released_entity = entity
      entity.force = game.forces.enemy
      entity.active = true
      entity.destructible = true
      if entity.commandable then
        entity.commandable.set_command({
          type = defines.command.stop,
          distraction = defines.distraction.none,
        })
      end
      return true
    end,
    background_state_shard_count = 4,
    protest_debug_status_ticks = 10 * 60,
  }

  local controller = protest_factory.new(deps)

  return {
    controller = controller,
    surface = surface,
    desk = desk,
    state_sets = state_sets,
    get_create_calls = function() return create_calls end,
    get_finalize_calls = function() return finalize_calls end,
    get_route_calls = function() return route_calls end,
    get_release_calls = function() return release_calls end,
    get_last_stop_command = function() return last_stop_command end,
    get_last_move_command = function() return last_move_command end,
    get_last_attack_command = function() return last_attack_command end,
    get_last_route_initial_frustration = function() return last_route_initial_frustration end,
    get_last_released_entity = function() return last_released_entity end,
    get_pacified_render_calls = function() return pacified_render_calls end,
    get_protest_render_calls = function() return protest_render_calls end,
    set_desk_available = function(value) desk_available = value end,
    set_protest_targets = function(targets) surface.protest_targets = targets end,
    hard_mode_capacity = hard_mode_capacity,
  }
end

local function new_invalid_entity()
  return setmetatable({}, {
    __index = function(_, key)
      if key == "valid" then
        return false
      end
      error("invalid entity access: " .. tostring(key), 2)
    end,
  })
end

test("pacified invalid biter rematerializes into a parked visible state while waiting", function()
  local ctx = new_test_context()
  local info = {
    state = "pacified",
    entity = nil,
    entity_name = "small-biter",
    last_known_position = {x = 2, y = 3},
    last_known_surface_index = 1,
    promise_retry_until_tick = 60 * 60,
    tracked_unit_number = 4,
  }
  storage.waiting_biters[4] = info
  ctx.state_sets.pacified[4] = true

  game.tick = 0
  ctx.controller.process_frustration_and_protests(ctx.surface)

  assert_eq(ctx.get_create_calls(), 1, "pacified invalid biter should be recreated so it remains visible")
  assert_eq(ctx.get_route_calls(), 0, "pacified invalid biter should not try to route while no desk is available")
  assert_true(ctx.get_pacified_render_calls() > 0, "pacified waiting biter should show a waiting indicator")
  assert_eq(info.state, "pacified", "recreated biter should remain pacified while waiting")
  assert_true(info.entity and info.entity.valid, "pacified biter should have a live entity again")
  assert_true(info.pacified_parked, "pacified biter should be parked so it stays stable while visible")
end)

test("pacified invalid biter does not keep rematerializing every shard with no desk open", function()
  local ctx = new_test_context()
  local info = {
    state = "pacified",
    entity = nil,
    entity_name = "small-biter",
    last_known_position = {x = 2, y = 3},
    last_known_surface_index = 1,
    promise_retry_until_tick = 60 * 60,
    tracked_unit_number = 4,
  }
  storage.waiting_biters[4] = info
  ctx.state_sets.pacified[4] = true

  game.tick = 0
  ctx.controller.process_frustration_and_protests(ctx.surface)

  local revived_unit_number = info.tracked_unit_number
  info.entity.valid = false

  game.tick = 60
  ctx.controller.process_frustration_and_protests(ctx.surface)

  assert_eq(ctx.get_create_calls(), 1, "pacified biter should not be recreated again on the next shard while no desk is available")
  assert_eq(info.tracked_unit_number, revived_unit_number, "tracked unit number should stay stable once rematerialization is suppressed")
  assert_eq(info.state, "pacified", "biter should remain pacified while waiting for desk capacity")
end)

test("invalid pathfinding biter recovers directly into desk waiting state", function()
  local ctx = new_test_context()
  storage.admin_desks[ctx.desk.unit_number] = ctx.desk

  local info = {
    state = "pathfinding",
    entity = nil,
    entity_name = "small-biter",
    last_known_position = {x = 4, y = 5},
    last_known_surface_index = 1,
    desk_id = ctx.desk.unit_number,
    desk_dest = {x = 0, y = 0},
    tracked_unit_number = 4,
    complaints = {"ticket-landscape"},
  }
  storage.waiting_biters[4] = info
  ctx.state_sets.pathfinding[4] = true

  game.tick = 0
  ctx.controller.process_frustration_and_protests(ctx.surface)

  assert_eq(ctx.get_create_calls(), 0, "invalid pathfinding biter should not be recreated and snapped back into place")
  assert_eq(ctx.get_finalize_calls(), 0, "invalid pathfinding biter should not be finalized after engine invalidation")
  assert_true(storage.waiting_biters[4] == nil, "invalid pathfinding biter should be untracked instead of teleported back")
end)

test("pacified biter reroute preserves half-threshold frustration when a desk opens", function()
  local ctx = new_test_context()
  storage.admin_desks[ctx.desk.unit_number] = ctx.desk
  ctx.set_desk_available(true)

  local entity = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 4, y = 5},
    force = "neutral",
  }
  entity.unit_number = 4

  local info = {
    state = "pacified",
    entity = entity,
    entity_name = entity.name,
    last_known_position = {x = 4, y = 5},
    last_known_surface_index = 1,
    promise_retry_until_tick = 60 * 60,
    frustration = 300,
    tracked_unit_number = 4,
  }
  storage.waiting_biters[4] = info
  ctx.state_sets.pacified[4] = true

  game.tick = 0
  ctx.controller.process_frustration_and_protests(ctx.surface)

  assert_eq(ctx.get_route_calls(), 1, "pacified biter should reroute when desk capacity returns")
  assert_eq(ctx.get_last_route_initial_frustration(), 300, "pacified reroute should preserve half-threshold frustration")
  assert_eq(info.state, "pathfinding", "pacified biter should return to pathfinding once rerouted")
end)

test("pacified invalid biter rematerializes only when a desk opens", function()
  local ctx = new_test_context()
  storage.admin_desks[ctx.desk.unit_number] = ctx.desk
  local info = {
    state = "pacified",
    entity = nil,
    entity_name = "small-biter",
    last_known_position = {x = 4, y = 5},
    last_known_surface_index = 1,
    promise_retry_until_tick = 60 * 60,
    tracked_unit_number = 4,
  }
  storage.waiting_biters[4] = info
  ctx.state_sets.pacified[4] = true
  ctx.set_desk_available(true)

  game.tick = 0
  ctx.controller.process_frustration_and_protests(ctx.surface)

  assert_eq(ctx.get_create_calls(), 1, "pacified invalid biter should rematerialize once a desk is available")
  assert_eq(ctx.get_route_calls(), 1, "rematerialized pacified biter should be rerouted to the reopened desk")
  assert_eq(info.state, "pathfinding", "pacified biter should leave pacified state once rerouted")
  assert_true(info.entity and info.entity.valid, "rerouted biter should have a live entity again")
  assert_true(storage.waiting_biters[4] == nil, "old unit number should be replaced after rematerialization")
  assert_true(storage.waiting_biters[info.tracked_unit_number] == info, "tracked biter should move to the replacement unit number")
end)

test("invalid protesting biter rematerializes instead of being untracked", function()
  local ctx = new_test_context()
  local target = {
    valid = true,
    active = false,
    force = {name = "player"},
    unit_number = 91,
    position = {x = 7, y = 7},
    surface = ctx.surface,
    bounding_box = {
      left_top = {x = 6, y = 6},
      right_bottom = {x = 8, y = 8},
    },
  }

  local info = {
    state = "protesting",
    entity = new_invalid_entity(),
    entity_name = "small-biter",
    last_known_position = {x = 4, y = 5},
    last_known_surface_index = 1,
    target_building = target,
    arrived_at_building = true,
    protest_anchor_position = {x = 6, y = 7},
    tracked_unit_number = 16,
    complaints = {"ticket-landscape"},
  }
  storage.waiting_biters[16] = info
  ctx.state_sets.protesting[16] = true

  game.tick = 0
  ctx.controller.process_frustration_and_protests(ctx.surface)

  assert_eq(ctx.get_create_calls(), 1, "invalid protester should be recreated")
  assert_true(storage.waiting_biters[16] == nil, "old protester unit key should be replaced")
  assert_true(info.entity and info.entity.valid, "protester should have a live replacement")
  assert_true(storage.waiting_biters[info.tracked_unit_number] == info, "replacement should remain tracked")
  assert_eq(info.state, "protesting", "replacement should keep protesting")
  assert_eq(info.entity.destructible, false, "replacement protester should be protected")
end)

test("arrived protesting biter parks inactive like desk waiters", function()
  local ctx = new_test_context()
  local target = {
    valid = true,
    active = true,
    force = {name = "player"},
    unit_number = 91,
    position = {x = 7, y = 7},
    surface = ctx.surface,
    bounding_box = {
      left_top = {x = 6, y = 6},
      right_bottom = {x = 8, y = 8},
    },
  }
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
    target_building = target,
    complaints = {"ticket-landscape"},
  }
  storage.waiting_biters[4] = info
  ctx.state_sets.protesting[4] = true

  game.tick = 0
  ctx.controller.process_frustration_and_protests(ctx.surface)

  assert_true(info.arrived_at_building, "nearby protester should be marked arrived")
  assert_true(info.protest_parked, "arrived protester should be parked")
  assert_eq(entity.active, false, "arrived protester should be inactive")
  assert_eq(entity.destructible, false, "arrived protester should be protected")
  assert_eq(ctx.get_last_stop_command().type, defines.command.stop, "arrived protester should receive a stop command")
  assert_eq(target.active, false, "arrived protester should keep the target disabled")
end)

test("promise without desk capacity pacifies and explicitly stops the protester", function()
  local ctx = new_test_context()
  local target = {
    valid = true,
    active = false,
    force = {name = "player"},
    unit_number = 91,
    position = {x = 7, y = 7},
    surface = ctx.surface,
    bounding_box = {
      left_top = {x = 6, y = 6},
      right_bottom = {x = 8, y = 8},
    },
  }
  local entity = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 1, y = 1},
    force = "neutral",
  }
  entity.unit_number = 12
  local info = {
    state = "protesting",
    entity = entity,
    entity_name = entity.name,
    tracked_unit_number = 12,
    target_building = target,
    arrived_at_building = true,
    complaints = {"ticket-landscape"},
  }
  storage.waiting_biters[12] = info
  ctx.state_sets.protesting[12] = true

  game.tick = 120
  ctx.controller.on_script_trigger_effect{
    effect_id = "promise-target",
    target_entity = entity,
  }

  assert_eq(info.state, "pacified", "promise should pacify a protester when no desk is available")
  assert_eq(info.promise_retry_until_tick, 120 + 60 * 60, "promise should preserve the full pacification retry window")
  assert_eq(info.frustration, 300, "promise pacification should only reduce frustration to half threshold")
  assert_true(info.entity == entity, "pacified protester should keep its live entity so it remains visible")
  assert_true(info.pacified_parked, "pacified protester should be parked while remaining visible")
  assert_eq(info.last_known_position.x, 1, "pacified protester should remember its last x position")
  assert_eq(info.last_known_position.y, 1, "pacified protester should remember its last y position")
  assert_true(target.active == true, "promise should release the protested building while the biter is pacified")
  assert_true(ctx.get_last_stop_command() ~= nil, "pacified protester should receive an explicit stop command")
  assert_true(ctx.get_pacified_render_calls() > 0, "pacified protester should show a waiting indicator")
  assert_eq(ctx.get_last_stop_command().type, defines.command.stop, "promise pacification should stop the protester's movement command")
end)

test("promise with only full desks keeps pacified biters roaming instead of freezing", function()
  local ctx = new_test_context()
  storage.admin_desks[ctx.desk.unit_number] = ctx.desk
  local target = {
    valid = true,
    active = false,
    force = {name = "player"},
    unit_number = 93,
    position = {x = 7, y = 7},
    surface = ctx.surface,
    bounding_box = {
      left_top = {x = 6, y = 6},
      right_bottom = {x = 8, y = 8},
    },
  }
  local entity = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 1, y = 1},
    force = "neutral",
  }
  entity.unit_number = 16
  local info = {
    state = "protesting",
    entity = entity,
    entity_name = entity.name,
    frustration = 600,
    tracked_unit_number = 16,
    target_building = target,
    arrived_at_building = true,
    complaints = {"ticket-landscape"},
  }
  storage.waiting_biters[16] = info
  ctx.state_sets.protesting[16] = true

  game.tick = 120
  ctx.controller.on_script_trigger_effect{
    effect_id = "promise-target",
    target_entity = entity,
  }

  assert_eq(info.state, "pacified", "promise should still pacify protesters when desks are full")
  assert_eq(info.frustration, 300, "pacified roaming should keep frustration at half threshold")
  assert_true(entity.active == true, "pacified biter should keep moving when desks exist but are full")
  assert_true(ctx.get_last_move_command() ~= nil, "pacified biter should receive a roam movement command")
  assert_true(ctx.get_pacified_render_calls() > 0, "pacified roaming biter should still show a waiting indicator")
  local destination = ctx.get_last_move_command().destination
  local desk_dist = (destination.x - ctx.desk.position.x)^2 + (destination.y - ctx.desk.position.y)^2
  local start_dist = (destination.x - 1)^2 + (destination.y - 1)^2
  assert_true(desk_dist < start_dist, "pacified roaming should orbit the desk area, not its old protest spot")
end)

test("pacified roaming biter parks when its roam command completes", function()
  local ctx = new_test_context()
  storage.admin_desks[ctx.desk.unit_number] = ctx.desk

  local entity = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 12, y = 10},
    force = "neutral",
  }
  entity.unit_number = 18
  local info = {
    state = "pacified",
    entity = entity,
    entity_name = entity.name,
    frustration = 300,
    tracked_unit_number = 18,
    promise_retry_until_tick = 60 * 60,
    next_pacified_roam_tick = 30,
  }
  storage.waiting_biters[18] = info
  ctx.state_sets.pacified[18] = true

  game.tick = 15
  ctx.controller.on_ai_command_completed{
    unit_number = 18,
    result = 0,
  }

  assert_eq(info.state, "pacified", "completed pacified roam should stay pacified")
  assert_true(info.pacified_parked, "completed pacified roam should park the biter between moves")
  assert_true(ctx.get_last_stop_command() ~= nil, "completed pacified roam should issue a stop command while parked")
end)

test("pacified pacing quickly resumes desk loitering after a short idle", function()
  local ctx = new_test_context()
  storage.admin_desks[ctx.desk.unit_number] = ctx.desk

  local entity = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 12, y = 10},
    force = "neutral",
  }
  entity.unit_number = 20
  entity.active = false
  local info = {
    state = "pacified",
    entity = entity,
    entity_name = entity.name,
    frustration = 300,
    tracked_unit_number = 20,
    promise_retry_until_tick = 60 * 60,
    next_pacified_roam_tick = 20,
    pacified_parked = true,
  }
  storage.waiting_biters[20] = info
  ctx.state_sets.pacified[20] = true

  game.tick = 20
  ctx.controller.process_protest_pacing(ctx.surface)

  assert_true(not info.pacified_parked, "pacified pacing should restart desk loitering after the short idle window")
  assert_true(ctx.get_last_move_command() ~= nil, "pacified pacing should issue a new roam command")
  local destination = ctx.get_last_move_command().destination
  local desk_dist = (destination.x - ctx.desk.position.x)^2 + (destination.y - ctx.desk.position.y)^2
  local start_dist = (destination.x - 12)^2 + (destination.y - 10)^2
  assert_true(desk_dist < start_dist, "resumed pacified loitering should head toward a desk area")
end)

test("pacified biter returns to full frustration when promise expires", function()
  local ctx = new_test_context()
  local entity = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 1, y = 1},
    force = "neutral",
  }
  entity.unit_number = 6
  local info = {
    state = "pacified",
    entity = entity,
    entity_name = entity.name,
    frustration = 300,
    promise_retry_until_tick = 60,
    tracked_unit_number = 6,
  }
  storage.waiting_biters[6] = info
  ctx.state_sets.pacified[6] = true

  game.tick = 120
  ctx.controller.process_frustration_and_protests(ctx.surface)

  assert_eq(info.state, "protesting", "expired pacified biter should resume protesting")
  assert_eq(info.frustration, 600, "expired pacified biter should return to full protest frustration")
end)

test("hard mode starts protests at the normal threshold but only 70 percent capacity", function()
  local ctx = new_test_context{hard_mode = true}
  local entity = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 1, y = 1},
    force = "neutral",
  }
  entity.unit_number = 24
  local info = {
    state = "waiting",
    entity = entity,
    entity_name = entity.name,
    frustration = 600,
    tracked_unit_number = 24,
    desk_id = 77,
    complaints = {"ticket-landscape"},
  }
  storage.waiting_biters[24] = info
  ctx.state_sets.waiting[24] = true

  game.tick = 0
  ctx.controller.process_frustration_and_protests(ctx.surface)

  assert_eq(info.state, "protesting", "hard mode should protest at the same frustration threshold as normal mode")
  assert_eq(math.floor(info.frustration / ctx.hard_mode_capacity * 100), 70, "hard mode protest threshold should be 70 percent of the larger capacity")
  assert_eq(ctx.get_release_calls(), 0, "hard mode should not attack at the protest threshold")
end)

test("hard mode protesting biter attacks a building while staying in protest mode at full capacity", function()
  local ctx = new_test_context{hard_mode = true}
  local target = {
    valid = true,
    active = false,
    force = {name = "player"},
    unit_number = 91,
    position = {x = 20, y = 20},
    surface = ctx.surface,
    bounding_box = {
      left_top = {x = 19, y = 19},
      right_bottom = {x = 21, y = 21},
    },
  }
  local nearest_target = {
    valid = true,
    active = true,
    force = {name = "player"},
    unit_number = 92,
    position = {x = 8, y = 7},
    surface = ctx.surface,
    bounding_box = {
      left_top = {x = 7, y = 6},
      right_bottom = {x = 9, y = 8},
    },
  }
  ctx.set_protest_targets({target, nearest_target})
  local entity = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 7, y = 7},
    force = "neutral",
  }
  entity.unit_number = 29
  local info = {
    state = "protesting",
    entity = entity,
    entity_name = entity.name,
    frustration = ctx.hard_mode_capacity - 1,
    tracked_unit_number = 29,
    target_building = target,
    arrived_at_building = true,
    last_frustration_tick = 0,
    complaints = {"ticket-landscape"},
  }
  storage.waiting_biters[29] = info
  ctx.state_sets.protesting[29] = true

  game.tick = 5 * 60
  ctx.controller.process_frustration_and_protests(ctx.surface)

  assert_eq(info.state, "protesting", "full hard-mode frustration should keep the biter in protest mode")
  assert_true(info.hard_mode_attacking == true, "full hard-mode frustration should mark the protester as attacking")
  assert_eq(info.frustration, ctx.hard_mode_capacity, "hard-mode attacking protester should sit at full frustration")
  assert_eq(ctx.get_release_calls(), 0, "hard mode escalation should not hand the biter back to regular enemy AI")
  assert_true(entity.force == game.forces.enemy, "hard-mode attacking protester should be hostile to player buildings")
  assert_true(entity.destructible == true, "hard-mode attacking protester should be destructible")
  assert_true(target.active == true, "escalation should release the disabled protest target")
  assert_true(ctx.get_last_attack_command() ~= nil, "hard-mode attacking protester should receive an explicit attack command")
  assert_true(ctx.get_last_attack_command().target == nearest_target, "hard-mode attacking protester should attack the nearest building")
end)

test("hard mode protesting biter with missing frustration tick still rises past 70 percent", function()
  local ctx = new_test_context{hard_mode = true}
  local target = {
    valid = true,
    active = false,
    force = {name = "player"},
    unit_number = 94,
    position = {x = 7, y = 7},
    surface = ctx.surface,
    bounding_box = {
      left_top = {x = 6, y = 6},
      right_bottom = {x = 8, y = 8},
    },
  }
  local entity = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 7, y = 7},
    force = "neutral",
  }
  entity.unit_number = 40
  local info = {
    state = "protesting",
    entity = entity,
    entity_name = entity.name,
    frustration = 600,
    tracked_unit_number = 40,
    target_building = target,
    arrived_at_building = true,
    complaints = {"ticket-landscape"},
  }
  storage.waiting_biters[40] = info
  ctx.state_sets.protesting[40] = true

  game.tick = 0
  ctx.controller.process_frustration_and_protests(ctx.surface)
  assert_eq(info.frustration, 600, "first pass should seed the missing frustration timestamp")

  game.tick = 48 * 60
  ctx.controller.process_frustration_and_protests(ctx.surface)

  assert_true(info.frustration > 600, "hard mode protester should keep gaining frustration after timestamp recovery")
  assert_true(math.floor(info.frustration / ctx.hard_mode_capacity * 100) > 70, "recovered hard mode protester should pass the 70 percent display")
end)

test("hard mode parked protester gains frustration during protest pacing", function()
  local ctx = new_test_context{hard_mode = true}
  local target = {
    valid = true,
    active = false,
    force = {name = "player"},
    unit_number = 95,
    position = {x = 7, y = 7},
    surface = ctx.surface,
    bounding_box = {
      left_top = {x = 6, y = 6},
      right_bottom = {x = 8, y = 8},
    },
  }
  local entity = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 7, y = 7},
    force = "neutral",
  }
  entity.unit_number = 41
  entity.active = false
  local info = {
    state = "protesting",
    entity = entity,
    entity_name = entity.name,
    frustration = 600,
    tracked_unit_number = 41,
    target_building = target,
    arrived_at_building = true,
    last_frustration_tick = 0,
    protest_parked = true,
    complaints = {"ticket-landscape"},
  }
  storage.waiting_biters[41] = info
  ctx.state_sets.protesting[41] = true

  game.tick = 48 * 60
  ctx.controller.process_protest_pacing(ctx.surface)

  assert_true(info.frustration > 600, "hard mode parked protester should gain frustration while inactive")
  assert_true(math.floor(info.frustration / ctx.hard_mode_capacity * 100) > 70, "pacing growth should show above 70 percent")
end)

test("hard mode parked protester escalates during protest pacing", function()
  local ctx = new_test_context{hard_mode = true}
  local target = {
    valid = true,
    active = false,
    force = {name = "player"},
    unit_number = 96,
    position = {x = 7, y = 7},
    surface = ctx.surface,
    bounding_box = {
      left_top = {x = 6, y = 6},
      right_bottom = {x = 8, y = 8},
    },
  }
  local entity = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 7, y = 7},
    force = "neutral",
  }
  entity.unit_number = 42
  entity.active = false
  local info = {
    state = "protesting",
    entity = entity,
    entity_name = entity.name,
    frustration = ctx.hard_mode_capacity - 1,
    tracked_unit_number = 42,
    target_building = target,
    arrived_at_building = true,
    last_frustration_tick = 0,
    protest_parked = true,
    complaints = {"ticket-landscape"},
  }
  storage.waiting_biters[42] = info
  ctx.state_sets.protesting[42] = true

  game.tick = 5 * 60
  ctx.controller.process_protest_pacing(ctx.surface)

  assert_eq(info.state, "protesting", "hard mode parked protester should stay in protest mode during escalation")
  assert_true(info.hard_mode_attacking == true, "hard mode parked protester should escalate during pacing")
  assert_eq(ctx.get_release_calls(), 0, "pacing escalation should not release the biter to regular enemy AI")
  assert_true(target.active == true, "pacing escalation should release the disabled protest target")
  assert_true(ctx.get_last_attack_command() ~= nil, "pacing escalation should issue an explicit attack command")
end)

test("promise sends hard mode attacking protesters back to a desk when capacity exists", function()
  local ctx = new_test_context{hard_mode = true}
  storage.admin_desks[ctx.desk.unit_number] = ctx.desk
  ctx.set_desk_available(true)

  local entity = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 4, y = 5},
    force = "enemy",
  }
  entity.unit_number = 32
  local info = {
    state = "protesting",
    entity = entity,
    entity_name = entity.name,
    frustration = ctx.hard_mode_capacity,
    hard_mode_attacking = true,
    tracked_unit_number = 32,
    complaints = {"ticket-landscape"},
  }
  storage.waiting_biters[32] = info
  ctx.state_sets.protesting[32] = true

  game.tick = 120
  ctx.controller.on_script_trigger_effect{
    effect_id = "promise-target",
    target_entity = entity,
  }

  assert_eq(ctx.get_route_calls(), 1, "promise should route a hard-mode attacker back to an open desk")
  assert_eq(ctx.get_last_route_initial_frustration(), 300, "promise should return hard-mode attackers at half of the protest threshold")
  assert_eq(info.state, "pathfinding", "promised hard-mode attacker should become desk-bound again")
  assert_true(info.hard_mode_attacking ~= true, "promise should clear hard-mode attacking status")
end)

test("promised hard mode attacking protester escalates again when no desk opens", function()
  local ctx = new_test_context{hard_mode = true}
  local target = {
    valid = true,
    active = true,
    force = {name = "player"},
    unit_number = 97,
    position = {x = 6, y = 5},
    surface = ctx.surface,
    bounding_box = {
      left_top = {x = 5, y = 4},
      right_bottom = {x = 7, y = 6},
    },
  }
  ctx.set_protest_targets({target})
  local entity = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 4, y = 5},
    force = "enemy",
  }
  entity.unit_number = 34
  local info = {
    state = "protesting",
    entity = entity,
    entity_name = entity.name,
    frustration = ctx.hard_mode_capacity,
    hard_mode_attacking = true,
    tracked_unit_number = 34,
    complaints = {"ticket-landscape"},
  }
  storage.waiting_biters[34] = info
  ctx.state_sets.protesting[34] = true

  game.tick = 120
  ctx.controller.on_script_trigger_effect{
    effect_id = "promise-target",
    target_entity = entity,
  }

  assert_eq(info.state, "pacified", "promise should pacify a hard-mode attacker while no desk is open")

  game.tick = 120 + 60 * 60
  ctx.controller.process_frustration_and_protests(ctx.surface)

  assert_eq(info.state, "protesting", "hard-mode attacker should stay in protest mode when the promise expires without desk capacity")
  assert_true(info.hard_mode_attacking == true, "hard-mode attacker should escalate again when the promise expires without desk capacity")
  assert_eq(info.frustration, ctx.hard_mode_capacity, "promise expiry in hard mode should restore full capacity frustration")
  assert_eq(ctx.get_release_calls(), 0, "promise expiry should not release the biter to regular enemy AI")
  assert_true(ctx.get_last_attack_command() ~= nil, "promise expiry should issue an explicit attack command")
  assert_true(ctx.get_last_attack_command().target == target, "promise expiry should attack the nearest available building")
end)

test("protest pacing refreshes protest rendering even before arrival", function()
  local ctx = new_test_context()
  local target = {
    valid = true,
    active = false,
    force = {name = "player"},
    unit_number = 95,
    position = {x = 7, y = 7},
    surface = ctx.surface,
  }
  local entity = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 1, y = 1},
    force = "neutral",
  }
  entity.unit_number = 8
  local info = {
    state = "protesting",
    entity = entity,
    entity_name = entity.name,
    tracked_unit_number = 8,
    target_building = target,
    complaints = {"ticket-landscape"},
  }
  storage.waiting_biters[8] = info
  ctx.state_sets.protesting[8] = true

  game.tick = 20
  ctx.controller.process_protest_pacing(ctx.surface)

  assert_true(ctx.get_protest_render_calls() > 0, "protest pacing should refresh protest rendering before arrival")
end)

test("protesting biter resumes movement when a successful approach command ends before arrival", function()
  local ctx = new_test_context()
  local target = {
    valid = true,
    active = false,
    force = {name = "player"},
    unit_number = 96,
    position = {x = 7, y = 7},
    surface = ctx.surface,
  }
  local entity = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 1, y = 1},
    force = "neutral",
  }
  entity.unit_number = 9
  local info = {
    state = "protesting",
    entity = entity,
    entity_name = entity.name,
    tracked_unit_number = 9,
    target_building = target,
    complaints = {"ticket-landscape"},
  }
  storage.waiting_biters[9] = info
  ctx.state_sets.protesting[9] = true

  game.tick = 20
  ctx.controller.on_ai_command_completed{
    unit_number = 9,
    result = 0,
  }

  assert_true(ctx.get_last_move_command() ~= nil, "protesting biter should receive a follow-up movement command after a premature command completion")
  assert_true(entity.active == true, "protesting biter should stay active while resuming its approach")
end)

test("stale protest path callback ignores invalid target entities", function()
  local ctx = new_test_context()
  local entity = ctx.surface.create_entity{
    name = "small-biter",
    position = {x = 1, y = 1},
    force = "neutral",
  }
  entity.unit_number = 21

  local info = {
    state = "protesting",
    entity = entity,
    entity_name = entity.name,
    tracked_unit_number = 21,
    pending_path_request_id = 55,
    pending_protest_candidates = {
      {
        target = {
          valid = false,
          name = "office-desk",
          position = {x = 7, y = 7},
        },
        pos = {x = 6, y = 6},
      },
    },
  }
  storage.waiting_biters[21] = info
  ctx.state_sets.protesting[21] = true
  storage.path_requests[55] = {
    unit_number = 21,
    kind = "protest_target",
    candidate_index = 1,
  }

  game.tick = 200
  ctx.controller.on_script_path_request_finished{
    id = 55,
    path = {},
  }

  assert_eq(storage.path_requests[55], nil, "completed path request should be cleared")
  assert_eq(info.pending_path_request_id, nil, "stale path request should not stay pending")
  assert_eq(info.pending_protest_candidates, nil, "invalid stale candidate should be discarded after callback")
  assert_eq(info.next_protest_target_retry_tick, 200 + 5 * 60, "stale invalid candidate should fall back to the normal protest retry timer")
end)

print(string.format("\n=== PROMISE PACIFIED TESTS ==="))
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
