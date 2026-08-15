-------------------------------------------------------------------------------
-- AI SERVER AND AUTOMATION GRIEVANCE RUNTIME TESTS
--
-- Two load-bearing behaviours: an under-cooled AI Server stops outright rather
-- than throttling, and the automation the pass introduces files its own biter
-- grievances through the existing complaint pipeline.
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
package.loaded["scripts.automation_grievances"] = nil
local ai_server = require("scripts.ai_server")
local grievances = require("scripts.automation_grievances")
local C = require("scripts.constants")

-------------------------------------------------------------------------------
-- FAKES
-------------------------------------------------------------------------------

local next_unit_number = 0

local function new_server(status, temperature)
  next_unit_number = next_unit_number + 1
  local core = {valid = true, temperature = temperature or C.AI_SERVER_AMBIENT_TEMPERATURE, destructible = true}
  local entity = {
    valid = true,
    name = C.AI_SERVER_NAME,
    unit_number = next_unit_number,
    position = {x = 0, y = 0},
    active = true,
    status = status or defines.entity_status.working,
    custom_status = nil,
    force = {valid = true, index = 1},
    output = {valid = true, citations = 0},
  }
  entity.surface = {
    valid = true,
    find_entities_filtered = function() return {core} end,
  }
  function entity.get_output_inventory()
    return {
      valid = true,
      get_item_count = function() return entity.output.citations end,
    }
  end
  storage.ai_servers[entity.unit_number] = {entity = entity, core = core}
  return entity, core
end

local function reset()
  storage = {}
  next_unit_number = 0
  ai_server.ensure_storage()
  grievances.ensure_storage()
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

-------------------------------------------------------------------------------
-- GRIEVANCES
-------------------------------------------------------------------------------

local function pressure_ticks_for(count)
  return math.ceil((C.AUTOMATION_GRIEVANCE_THRESHOLD * count) / C.AUTOMATION_PRESSURE_PER_AI_SERVER)
end

test("running AI servers eventually file an automation grievance", function()
  reset()
  new_server(defines.entity_status.working)

  local force = {valid = true, index = 1}
  assert_eq(grievances.consume_pending(force), false, "nothing should be pending yet")

  for tick = 1, pressure_ticks_for(1) do
    grievances.on_tick{tick = tick}
  end
  assert_true(grievances.pending_count(1) >= 1, "a running server should generate grievances")
  assert_eq(grievances.consume_pending(force), true, "a filed grievance should be consumable")
end)

test("an idle AI server files nothing", function()
  reset()
  new_server(defines.entity_status.no_power)

  for tick = 1, pressure_ticks_for(2) do
    grievances.on_tick{tick = tick}
  end
  assert_eq(grievances.pending_count(1), 0, "a server that is not running annoys nobody")
end)

test("unhandled citations feed the grievance thread", function()
  reset()
  local entity = new_server(defines.entity_status.no_power)
  entity.output.citations = C.AUTOMATION_CITATION_BACKLOG

  local ticks = math.ceil(C.AUTOMATION_GRIEVANCE_THRESHOLD / C.AUTOMATION_PRESSURE_PER_CITATION_BACKLOG)
  for tick = 1, ticks do
    grievances.on_tick{tick = tick}
  end
  assert_true(grievances.pending_count(1) >= 1, "ignoring hallucinations should annoy the union")
end)

test("citations below the backlog threshold are tolerated", function()
  reset()
  local entity = new_server(defines.entity_status.no_power)
  entity.output.citations = C.AUTOMATION_CITATION_BACKLOG - 1

  local ticks = math.ceil(C.AUTOMATION_GRIEVANCE_THRESHOLD / C.AUTOMATION_PRESSURE_PER_CITATION_BACKLOG)
  for tick = 1, ticks do
    grievances.on_tick{tick = tick}
  end
  assert_eq(grievances.pending_count(1), 0, "a handled citation stream should file nothing")
end)

test("installed waivers feed the grievance thread", function()
  reset()
  local entity = {
    valid = true,
    unit_number = 900,
    force = {valid = true, index = 1},
    get_module_inventory = function()
      return {valid = true, get_item_count = function() return 1 end}
    end,
  }
  storage.managed_building_registry = {[900] = entity}

  local ticks = math.ceil(C.AUTOMATION_GRIEVANCE_THRESHOLD / C.AUTOMATION_PRESSURE_PER_WAIVER)
  for tick = 1, ticks do
    grievances.on_tick{tick = tick}
  end
  assert_true(grievances.pending_count(1) >= 1, "the union notices a building running unstaffed")
end)

test("the pending backlog is capped so it cannot leak", function()
  reset()
  new_server(defines.entity_status.working)

  for tick = 1, pressure_ticks_for(C.AUTOMATION_GRIEVANCE_MAX_PENDING + 20) do
    grievances.on_tick{tick = tick}
  end
  assert_true(grievances.pending_count(1) <= C.AUTOMATION_GRIEVANCE_MAX_PENDING,
    "a backlog nobody can serve must not grow without bound")
end)

test("consuming a grievance decrements exactly one", function()
  reset()
  storage.automation_pending = {[1] = 3}
  local force = {valid = true, index = 1}
  assert_eq(grievances.consume_pending(force), true, "the first consume should succeed")
  assert_eq(grievances.pending_count(1), 2, "exactly one grievance should be taken")
end)

test("the grievance rides the existing complaint pipeline", function()
  assert_eq(grievances.TICKET, "ticket-automation",
    "the thread should reuse the ordinary complaint item shape")
end)

print(string.format("\n=== AI SERVER AND AUTOMATION GRIEVANCE RUNTIME TESTS ==="))
print(string.format("Passed: %d  Failed: %d  Total: %d", passed, failed, passed + failed))

if #errors > 0 then
  print("\nFAILURES:")
  for i, err in ipairs(errors) do
    print(string.format("  %d) %s", i, err))
  end
  os.exit(1)
end

print("\nAll tests passed!")
