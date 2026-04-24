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
  command = {go_to_location = 1, stop = 2},
  distraction = {none = 0},
}

log = function() end

local protest_factory = dofile(mod_root .. "scripts/biters_protests.lua")

test("desk deletion reroutes from canonical waiting data when desk index drifted", function()
  local reroute_calls = 0
  local old_desk_id = 10
  local new_desk_id = 20

  local surface = {
    index = 1,
    find_entities_filtered = function() return {} end,
  }

  local biter = {
    valid = true,
    name = "small-biter",
    unit_number = 101,
    position = {x = 0, y = 0},
    surface = surface,
    force = {name = "administratorio-biters"},
    active = false,
  }
  biter.commandable = {
    set_command = function() end,
  }

  local new_desk = {
    valid = true,
    unit_number = new_desk_id,
    position = {x = 20, y = 0},
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
    path_requests = {},
    admin_desks = {
      [new_desk_id] = new_desk,
    },
    waiting_biters = {
      [biter.unit_number] = {
        entity = biter,
        desk_id = old_desk_id,
        state = "waiting",
      },
    },
    waiting_biter_state_index = {
      waiting = {[biter.unit_number] = true},
      pathfinding = {},
      protesting = {},
      pacified = {},
      returning_home = {},
    },
    waiting_biter_state_index_built = true,
    desk_biters = {
      [old_desk_id] = {},
    },
  }

  local function set_waiting_biter_state(info, state)
    local unit_number = info.entity and info.entity.unit_number
    if info.state and unit_number then
      storage.waiting_biter_state_index[info.state][unit_number] = nil
    end
    info.state = state
    if state and unit_number then
      storage.waiting_biter_state_index[state][unit_number] = true
    end
  end

  local controller = protest_factory.new({
    constants = {
      PROTEST_THRESHOLD = 600,
    },
    zones = {
      release_slot = function() end,
      get_available_slots = function(desk_id)
        if desk_id == new_desk_id then return 1 end
        return 0
      end,
    },
    working_hours = {
      claim_protest_target = function() return false end,
      release_protest_target = function() return false end,
      transfer_protest_target = function() return false end,
    },
    render = {
      destroy_protest_rendering = function() end,
      destroy_protest_chart_tag = function() end,
      destroy_pacified_rendering = function() end,
      ensure_pacified_rendering = function() end,
      ensure_protest_rendering = function() end,
      ensure_protest_chart_tag = function() end,
      notify_players_of_protest = function() end,
    },
    protest_protected_names = {},
    protest_target_types = {},
    protest_target_names = {},
    get_waiting_biter_state_set = function(state)
      return storage.waiting_biter_state_index[state]
    end,
    ensure_desk_biters = function()
      storage.desk_biters = storage.desk_biters or {}
    end,
    unindex_biter_from_desk = function(desk_id, unit_number)
      local desk_set = storage.desk_biters[desk_id]
      if desk_set then
        desk_set[unit_number] = nil
      end
    end,
    route_biter_to_desk = function(info, entity, desk)
      reroute_calls = reroute_calls + 1
      info.entity = entity
      info.desk_id = desk.unit_number
      set_waiting_biter_state(info, "pathfinding")
      return true
    end,
    get_cached_desks = function()
      return {new_desk}
    end,
    set_waiting_biter_state = set_waiting_biter_state,
    get_biter_force = function()
      return game.forces.neutral
    end,
    assign_protest_target = function()
      error("should not fall back to protesting when another desk exists")
    end,
  })

  controller.reroute_desk_biters(old_desk_id, surface)

  local info = storage.waiting_biters[biter.unit_number]
  assert_eq(reroute_calls, 1, "reroute should use waiting_biters fallback when desk index is stale")
  assert_eq(info.desk_id, new_desk_id, "biter should be reassigned to the remaining desk")
  assert_eq(info.state, "pathfinding", "rerouted biter should resume pathfinding")
  assert_true(storage.desk_biters[old_desk_id] == nil, "removed desk index should be cleared")
end)

print(("Admin desk reroute tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
