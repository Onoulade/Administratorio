-------------------------------------------------------------------------------
-- AI SERVER RUNTIME TESTS
--
-- The load-bearing behaviour: an under-cooled AI Server stops outright rather
-- than throttling, and resumes once the heat network draws its core back down.
-------------------------------------------------------------------------------

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

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or "assertion failed") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function assert_true(value, msg)
  if not value then error(msg or "assertion failed", 2) end
end

local function assert_close(actual, expected, tolerance, msg)
  if math.abs(actual - expected) > tolerance then
    error((msg or "assertion failed") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

defines = {
  inventory = {furnace_source = 1, furnace_result = 2, chest = 3},
  entity_status_diode = {red = 1, yellow = 2, green = 3},
  entity_status = {working = 1, no_power = 2, item_ingredient_shortage = 3},
  direction = {north = 0, east = 2, south = 4, west = 6},
  wire_connector_id = {circuit_red = 1, circuit_green = 2},
}
game = {surfaces = {}, tick = 0, connected_players = {}}
storage = {}

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

package.loaded["scripts.ai_server"] = nil
local ai_server = require("scripts.ai_server")
local C = require("scripts.constants")

-------------------------------------------------------------------------------
-- FAKES
-------------------------------------------------------------------------------

local next_unit_number = 0

local function new_server(status, temperature)
  next_unit_number = next_unit_number + 1
  local core = {
    valid = true,
    temperature = temperature or C.AI_SERVER_AMBIENT_TEMPERATURE,
    destructible = true,
  }
  function core.destroy()
    core.valid = false
  end

  local entity = {
    valid = true,
    name = C.AI_SERVER_NAME,
    unit_number = next_unit_number,
    position = {x = 0, y = 0},
    active = true,
    status = status or defines.entity_status.working,
    custom_status = nil,
    force = {valid = true, index = 1},
  }
  local surface = {
    valid = true,
  }
  function surface.find_entities_filtered(opts)
    if opts.name == C.AI_SERVER_NAME then return {entity} end
    if opts.name == C.AI_SERVER_HEAT_CORE_NAME and core.valid then return {core} end
    return {}
  end
  entity.surface = surface
  storage.ai_servers[entity.unit_number] = {entity = entity, core = core}
  return entity, core
end

local function reset()
  storage = {}
  next_unit_number = 0
  ai_server.ensure_storage()
  game.surfaces = {}
end

-------------------------------------------------------------------------------
-- HEAT
-------------------------------------------------------------------------------

test("a working server heats its hidden core", function()
  reset()
  local entity, core = new_server(defines.entity_status.working)
  local before = core.temperature

  ai_server.on_tick{tick = 0}
  assert_true(core.temperature > before, "crafting should push heat into the core")
  assert_eq(entity.custom_status.diode, defines.entity_status_diode.green, "a working server should read green")
end)

test("server heat matches its declared four-megawatt electric draw", function()
  reset()
  local _, core = new_server(defines.entity_status.working)
  local before = core.temperature

  ai_server.on_tick{tick = 0}

  local degrees = core.temperature - before
  local expected = C.AI_SERVER_HEAT_PER_TICK * C.AI_SERVER_CHECK_TICKS
  assert_close(degrees, expected, 1e-9, "the check should integrate the configured heat rate")
  assert_close(expected * 5 * 60 / C.AI_SERVER_CHECK_TICKS, 4, 1e-9,
    "five megajoules per degree must resolve to four megawatts, not a free reactor")
end)

test("an idle server does not heat its core", function()
  reset()
  local entity, core = new_server(defines.entity_status.no_power)
  local before = core.temperature

  ai_server.on_tick{tick = 0}
  assert_eq(core.temperature, before, "an idle server should emit no heat")
  assert_eq(entity.custom_status.diode, defines.entity_status_diode.yellow, "an idle server should read yellow")
end)

test("under-cooling is a hard stop, not a throttle", function()
  reset()
  local entity = new_server(defines.entity_status.working, C.AI_SERVER_STALL_TEMPERATURE)

  ai_server.on_tick{tick = 0}
  assert_eq(entity.active, false, "an under-cooled server stops outright")
  assert_eq(entity.custom_status.diode, defines.entity_status_diode.red, "a stopped server should read red")
end)

test("a server restarts once the heat network draws its core back down", function()
  reset()
  local entity, core = new_server(defines.entity_status.working, C.AI_SERVER_STALL_TEMPERATURE)

  ai_server.on_tick{tick = 0}
  assert_eq(entity.active, false, "the server should be stopped")

  -- A heat exchanger or Heat Exhaust drains the core.
  core.temperature = C.AI_SERVER_AMBIENT_TEMPERATURE
  ai_server.on_tick{tick = 60}
  assert_eq(entity.active, true, "the server should resume once it can dump heat again")
end)

test("core temperature never exceeds the buffer maximum", function()
  reset()
  local _, core = new_server(defines.entity_status.working, C.AI_SERVER_MAX_TEMPERATURE - 1)
  -- Stalling is checked first, so raise the stall bar out of the way for this
  -- test and confirm the clamp itself holds.
  local original_stall = C.AI_SERVER_STALL_TEMPERATURE
  C.AI_SERVER_STALL_TEMPERATURE = C.AI_SERVER_MAX_TEMPERATURE + 1000
  ai_server.on_tick{tick = 0}
  C.AI_SERVER_STALL_TEMPERATURE = original_stall
  assert_true(core.temperature <= C.AI_SERVER_MAX_TEMPERATURE, "the core must not exceed its buffer maximum")
end)

test("a stalled server stops before it reaches the buffer maximum", function()
  assert_true(C.AI_SERVER_STALL_TEMPERATURE < C.AI_SERVER_MAX_TEMPERATURE,
    "the hard stop must trigger below the buffer ceiling so the state is recoverable")
end)

test("registry rebuild preserves the temperature of an existing heat core", function()
  reset()
  local entity, core = new_server(defines.entity_status.working, 650)
  game.surfaces = {entity.surface}

  ai_server.rebuild_registry()

  assert_eq(core.temperature, 650, "configuration rebuilds must not become free cooling resets")
  assert_eq(storage.ai_servers[entity.unit_number].core, core, "the live core should remain registered")
end)

test("removing an AI Server destroys its hidden heat core", function()
  reset()
  local entity, core = new_server(defines.entity_status.working)

  ai_server.on_entity_removed(entity)

  assert_true(not core.valid, "the hidden core must not survive after its parent is gone")
  assert_eq(storage.ai_servers[entity.unit_number], nil, "removed servers must leave no registry entry")
end)

print(string.format("\n=== AI SERVER RUNTIME TESTS ==="))
print(string.format("Passed: %d  Failed: %d  Total: %d", passed, failed, passed + failed))

if #errors > 0 then
  print("\nFAILURES:")
  for i, err in ipairs(errors) do
    print(string.format("  %d) %s", i, err))
  end
  os.exit(1)
end

print("\nAll tests passed!")
