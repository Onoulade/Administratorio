-------------------------------------------------------------------------------
-- PASSENGER PLATFORM ROUTING TESTS
--
-- Covers the availability contract that keeps visitors from becoming stuck at
-- boarding platforms when a train departs or fills up.
-------------------------------------------------------------------------------

local passed, failed, errors = 0, 0, {}
local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then passed = passed + 1 else failed = failed + 1; errors[#errors + 1] = name .. ": " .. tostring(err) end
end
local function assert_true(value, message) if not value then error(message or "assertion failed", 2) end end
local function assert_eq(actual, expected, message)
  if actual ~= expected then error((message or "assertion failed") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)"):gsub("tests/$", "")
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

defines = {
  direction = {north = 0, east = 2, south = 4, west = 6},
  wire_connector_id = {circuit_red = 1, circuit_green = 2},
  command = {go_to_location = 1, stop = 2},
  distraction = {none = 1},
  train_state = {wait_station = 1},
}

local passenger_trains = dofile(mod_root .. "scripts/passenger_trains.lua")
local next_id = 100
local function id() next_id = next_id + 1; return next_id end

local function has_filter(value, filter)
  if type(filter) ~= "table" then return value == filter end
  for _, candidate in ipairs(filter) do if value == candidate then return true end end
  return false
end

local function new_surface()
  local surface = {entities = {}}
  function surface.find_entities_filtered(params)
    local result = {}
    for _, entity in ipairs(surface.entities) do
      local matches = entity.valid ~= false
      if matches and params.name then matches = has_filter(entity.name, params.name) end
      if matches and params.type then matches = has_filter(entity.type, params.type) end
      if matches and params.position and params.radius then
        local dx, dy = entity.position.x - params.position.x, entity.position.y - params.position.y
        matches = dx * dx + dy * dy <= params.radius * params.radius
      end
      if matches then result[#result + 1] = entity end
    end
    return result
  end
  return surface
end

local function new_entity(surface, name, entity_type, x, y)
  local entity = {
    valid = true, name = name, type = entity_type, unit_number = id(),
    position = {x = x, y = y}, force = "enemy", surface = surface,
    signals = {}, active = true,
  }
  function entity.get_circuit_network()
    return {get_signal = function(signal) return entity.signals[signal.name] or 0 end}
  end
  surface.entities[#surface.entities + 1] = entity
  return entity
end

local function setup()
  local surface = new_surface()
  storage = {passenger_registry_ready = true}
  game = {tick = 0, surfaces = {[1] = surface}, connected_players = {}}
  passenger_trains.set_biters_module(nil)
  new_entity(surface, "straight-rail", "straight-rail", 0, 0)
  local platform = new_entity(surface, "boarding-platform", "constant-combinator", 0, 2.5)
  platform.force = "player"
  passenger_trains.on_built(platform)
  return surface, platform
end

test("boarding platforms attract only a stationary passenger train by default", function()
  local surface, platform = setup()
  local visitor = new_entity(surface, "small-biter", "unit", 8, 2.5)
  assert_eq(passenger_trains.find_destination(visitor), nil, "an empty rail-side platform must not attract visitors")

  local wagon = new_entity(surface, "passenger-wagon", "cargo-wagon", 0, 0)
  wagon.force = "player"
  wagon.train = {speed = 0, manual_mode = true, carriages = {wagon}}
  assert_eq(passenger_trains.find_destination(visitor), platform, "a stationary adjacent passenger wagon should open boarding")

  wagon.train.speed = 0.1
  assert_eq(passenger_trains.find_destination(visitor), nil, "a passing train must not attract boarders")
end)

test("Boarding Enabled explicitly opens an incoming-train queue", function()
  local surface, platform = setup()
  local visitor = new_entity(surface, "small-biter", "unit", 8, 2.5)
  platform.signals["signal-boarding-enabled"] = 1
  assert_eq(passenger_trains.find_destination(visitor), platform, "the circuit override should open the platform without a train")
end)

test("highest passenger frustration signal is a clamped percentage", function()
  local surface, platform = setup()
  local slots = {}
  local section = {
    clear_slot = function(slot) slots[slot] = nil end,
    set_slot = function(slot, value) slots[slot] = value end,
  }
  function platform.get_or_create_control_behavior()
    return {get_section = function() return section end}
  end

  local wagon = new_entity(surface, "passenger-wagon", "cargo-wagon", 0, 0)
  wagon.force = "player"
  wagon.train = {speed = 0, manual_mode = true, carriages = {wagon}}
  passenger_trains.on_built(wagon)
  storage.passenger_wagons[wagon.unit_number].passengers = {
    {entity_name = "small-biter", frustration = 300},
  }

  passenger_trains.on_tick({tick = 60})
  assert_eq(slots[5].min, 50, "300 seconds of frustration must emit 50%")
end)

test("departed or closed platforms release queued visitors to the normal rerouter", function()
  local surface, platform = setup()
  local visitor = new_entity(surface, "small-biter", "unit", 2, 2.5)
  local info = {entity = visitor, entity_name = visitor.name, visitor_id = 77, state = "pathfinding"}
  local rerouted_from
  passenger_trains.set_biters_module({
    set_passenger_ground_state = function(entry, state) entry.state = state end,
    reroute_passenger_ground = function(_, excluded_platform_id) rerouted_from = excluded_platform_id; return true end,
  })
  platform.signals["signal-boarding-enabled"] = 1
  assert_true(passenger_trains.reserve_platform(info, visitor, platform), "signal-open platform should reserve the visitor")
  platform.signals["signal-boarding-enabled"] = 0
  passenger_trains.on_tick({tick = 60})
  assert_eq(info.platform_id, nil, "closed platform must release its reservation")
  assert_eq(rerouted_from, platform.unit_number, "rerouting must exclude the platform that just released the visitor")
end)

test("Deboarding Closed holds passengers aboard by default-on platform control", function()
  local surface = new_surface()
  storage = {passenger_registry_ready = true}
  game = {tick = 0, surfaces = {[1] = surface}, connected_players = {}}
  passenger_trains.set_biters_module(nil)
  new_entity(surface, "straight-rail", "straight-rail", 0, 0)
  local stop = new_entity(surface, "train-stop", "train-stop", 0, 4)
  stop.force = "player"
  function stop.get_or_create_control_behavior() return {} end
  local platform = new_entity(surface, "deboarding-platform", "constant-combinator", 0, 2.5)
  platform.force = "player"
  platform.signals["signal-deboarding-closed"] = 1
  local wagon = new_entity(surface, "passenger-wagon", "cargo-wagon", 0, 0)
  wagon.force = "player"
  local train = {speed = 0, state = defines.train_state.wait_station, station = stop, carriages = {wagon}}
  wagon.train = train
  function surface.create_entity(params)
    if params.name ~= "passenger-stop-combinator" then error("unexpected entity creation: " .. params.name) end
    local section = {clear_slot = function() end, set_slot = function() end}
    return {valid = true, get_or_create_control_behavior = function() return {get_section = function() return section end} end}
  end
  passenger_trains.on_built(stop)
  passenger_trains.on_built(platform)
  passenger_trains.on_built(wagon)
  storage.passenger_wagons[wagon.unit_number].passengers = {{entity_name = "small-biter", frustration = 0}}
  passenger_trains.on_train_changed_state({train = train})
  assert_eq(#storage.passenger_wagons[wagon.unit_number].passengers, 1,
    "a positive Deboarding Closed signal must hold the manifest until removed")
end)

test("platform visuals keep one floor asset and tint the state light", function()
  local surface, platform = setup()
  local calls, live = {}, {}
  rendering = {
    draw_sprite = function(spec)
      calls[#calls + 1] = spec
      local id = #calls
      live[id] = {id = id, destroy = function() live[id] = nil end}
      return live[id]
    end,
    get_object_by_id = function(id) return live[id] end,
  }

  assert_true(passenger_trains.set_platform_mode(platform, "off"), "mode change should be accepted")
  passenger_trains.on_tick({tick = 60})
  assert_eq(calls[1].sprite, "administratorio-passenger-platform-boarding-platform-idle-north",
    "an explicitly disabled boarding platform must retain its normal floor art")
  assert_eq(calls[2].tint.r, 1, "inactive platform glow must be red")

  assert_true(passenger_trains.set_platform_mode(platform, "always"), "mode reset should be accepted")
  local wagon = new_entity(surface, "passenger-wagon", "cargo-wagon", 0, 0)
  wagon.force = "player"
  wagon.train = {speed = 0, manual_mode = true, carriages = {wagon}}
  passenger_trains.on_tick({tick = 120})
  assert_eq(calls[3].sprite, "administratorio-passenger-platform-boarding-platform-idle-north",
    "a stationary passenger wagon must retain its normal floor art")
  assert_eq(calls[4].tint.g, 1, "active platform glow must be green")
  rendering = nil
end)

test("idle deboarding platforms use their blue light in every direction", function()
  local surface = new_surface()
  storage = {passenger_registry_ready = true}
  game = {tick = 0, surfaces = {[1] = surface}, connected_players = {}}
  passenger_trains.set_biters_module(nil)
  new_entity(surface, "straight-rail", "straight-rail", 0, 0)
  local platform = new_entity(surface, "deboarding-platform", "constant-combinator", 0, 2.5)
  platform.force, platform.direction = "player", defines.direction.east
  local calls, live = {}, {}
  rendering = {
    draw_sprite = function(spec)
      calls[#calls + 1] = spec
      local id = #calls
      live[id] = {id = id, destroy = function() live[id] = nil end}
      return live[id]
    end,
    get_object_by_id = function(id) return live[id] end,
  }
  passenger_trains.on_built(platform, {})
  assert_eq(calls[1].sprite, "administratorio-passenger-platform-deboarding-platform-idle-east",
    "idle deboarding must draw its east-facing platform layer")
  assert_eq(calls[1].render_layer, "lower-object", "the platform floor must render below walkers")
  assert_eq(calls[2].sprite, "administratorio-passenger-platform-deboarding-platform-light-east",
    "idle deboarding must draw its east-facing lamp overlay")
  assert_eq(calls[2].tint.b, 1, "idle deboarding lamp must be blue")
  rendering = nil
end)

test("off-rail platforms persist as inactive red entities", function()
  local surface = new_surface()
  storage = {passenger_registry_ready = true}
  game = {tick = 0, surfaces = {[1] = surface}, connected_players = {}}
  passenger_trains.set_biters_module(nil)
  local platform = new_entity(surface, "boarding-platform", "constant-combinator", 20, 20)
  platform.force = "player"
  local calls, live = {}, {}
  rendering = {
    draw_sprite = function(spec)
      calls[#calls + 1] = spec
      local id = #calls
      live[id] = {id = id, destroy = function() live[id] = nil end}
      return live[id]
    end,
    get_object_by_id = function(id) return live[id] end,
  }
  assert_true(passenger_trains.on_built(platform, {}), "invalid placement must retain the platform entity")
  assert_true(platform.valid, "invalid platform must not collapse into an item drop")
  assert_eq(calls[1].sprite, "administratorio-passenger-platform-boarding-platform-idle-north",
    "off-rail platform must retain the normal floor asset")
  assert_eq(calls[2].tint.r, 1, "off-rail platform lamp must be red")
  rendering = nil
end)

print(("Passenger train tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then for _, err in ipairs(errors) do print(" - " .. err) end; os.exit(1) end
