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
  local next_unit_number = 100
  local next_request_id = 0
  local last_move_command = nil
  local pending_request_id = nil
  local protest_targets = {}

  local surface
  surface = {
    index = 1,
    valid = true,
    find_entities_filtered = function(opts)
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
        position = {x = params.position.x, y = params.position.y},
        force = force,
        active = true,
        unit_number = next_unit_number,
        surface = surface,
        prototype = {
          collision_box = {{0, 0}, {0, 0}},
          collision_mask = {},
        },
      }
      entity.commandable = {
        set_command = function(command)
          if command.type == defines.command.go_to_location then
            last_move_command = command
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
      INVALIDATED_BITER_REVIVE_RETRY_TICKS = 60,
      PROTEST_TARGET_RETRY_TICKS = 5 * 60,
      PROTEST_TARGET_MAX_PROTESTERS = 5,
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
    },
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
      destroy_protest_rendering = function() end,
      destroy_protest_chart_tag = function() end,
      ensure_protest_rendering = function() end,
      ensure_protest_chart_tag = function() end,
      destroy_pacified_rendering = function() end,
      ensure_pacified_rendering = function() end,
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
    issue_desk_route_command = function() end,
    get_cached_desks = function() return {} end,
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
    finalize_pathfinding_biter_arrival = function() return false end,
    protest_protected_names = {},
    protest_target_names = {"office-desk"},
    protest_target_types = {},
    adopt_redirected_biter = function(_, entity) return entity end,
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
    log_prefix = "[Administratorio] ",
  }

  local controller = protest_factory.new(deps)

  return {
    controller = controller,
    surface = surface,
    set_protest_targets = function(targets)
      protest_targets = targets
    end,
    get_last_move_command = function()
      return last_move_command
    end,
    get_pending_request_id = function()
      return pending_request_id
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
