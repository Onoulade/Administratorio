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
  },
  distraction = {
    none = 1,
  },
  behavior_result = {
    fail = 1,
  },
}

local protest_factory = dofile(mod_root .. "scripts/biters_protests.lua")

local function new_test_context()
  local state_sets = {
    protesting = {},
    pacified = {},
    returning_home = {},
    waiting = {},
    pathfinding = {},
  }
  local create_calls = 0
  local route_calls = 0
  local finalize_calls = 0
  local last_stop_command = nil
  local last_move_command = nil
  local last_route_initial_frustration = nil
  local pacified_render_calls = 0
  local protest_render_calls = 0
  local desk_available = false
  local next_unit_number = 100

  local surface
  surface = {
    index = 1,
    find_entities_filtered = function()
      return {}
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
      DESK_SLOT_COMMAND_RADIUS = 0.5,
      DESK_SLOT_ARRIVAL_DISTANCE = 1.0,
      PACIFIED_FRUSTRATION_RATIO = 0.5,
      PACIFIED_ROAM_REISSUE_TICKS = 5 * 60,
      PACIFIED_ROAM_REISSUE_JITTER_TICKS = 0,
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
    background_state_shard_count = 4,
    protest_debug_status_ticks = 10 * 60,
    log_prefix = "[Administratorio] ",
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
    get_last_stop_command = function() return last_stop_command end,
    get_last_move_command = function() return last_move_command end,
    get_last_route_initial_frustration = function() return last_route_initial_frustration end,
    get_pacified_render_calls = function() return pacified_render_calls end,
    get_protest_render_calls = function() return protest_render_calls end,
    set_desk_available = function(value) desk_available = value end,
  }
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
  assert_eq(info.state, "pacified", "recreated biter should remain pacified while waiting")
  assert_true(info.entity and info.entity.valid, "pacified biter should have a live entity again")
  assert_true(info.entity.active == false, "pacified biter should be parked so it stays stable while visible")
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

  assert_eq(ctx.get_create_calls(), 1, "invalid pathfinding biter should be recreated once")
  assert_eq(ctx.get_finalize_calls(), 1, "invalid pathfinding biter should be finalized into desk waiting state")
  assert_eq(info.state, "waiting", "recovered pathfinding biter should enter waiting state")
  assert_true(info.entity and info.entity.valid, "recovered pathfinding biter should have a live entity")
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
  assert_true(entity.active == false, "pacified protester should be parked while remaining visible")
  assert_eq(info.last_known_position.x, 1, "pacified protester should remember its last x position")
  assert_eq(info.last_known_position.y, 1, "pacified protester should remember its last y position")
  assert_true(target.active == true, "promise should release the protested building while the biter is pacified")
  assert_true(ctx.get_last_stop_command() ~= nil, "pacified protester should receive an explicit stop command")
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
