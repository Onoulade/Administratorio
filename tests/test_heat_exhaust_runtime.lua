-------------------------------------------------------------------------------
-- HEAT EXHAUST RUNTIME TESTS
--
-- Heat interfaces default to holding a minimum temperature. The exhaust must
-- override that default at placement and after a configuration rebuild.
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
  direction = {north = 0, east = 2, south = 4, west = 6},
}
game = {surfaces = {}}
storage = {}

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

package.loaded["scripts.heat_exhaust"] = nil
local heat_exhaust = require("scripts.heat_exhaust")
local C = require("scripts.constants")

local function new_exhaust()
  local entity = {
    valid = true,
    name = C.HEAT_EXHAUST_NAME,
  }
  function entity.set_heat_setting(setting)
    entity.setting = setting
  end
  return entity
end

test("a placed Heat Exhaust is configured as a true heat sink", function()
  local entity = new_exhaust()

  assert_true(heat_exhaust.on_entity_built(entity), "the exhaust should be configured")
  assert_eq(entity.setting.mode, "at-most", "the exhaust must cap heat rather than maintain a minimum")
  assert_eq(entity.setting.temperature, C.AI_SERVER_AMBIENT_TEMPERATURE,
    "the exhaust should void heat down to ambient temperature")
end)

test("configuration rebuild configures every existing Heat Exhaust", function()
  local first = new_exhaust()
  local second = new_exhaust()
  game.surfaces = {
    {
      valid = true,
      find_entities_filtered = function(opts)
        assert_eq(opts.name, C.HEAT_EXHAUST_NAME, "rebuild should only scan Heat Exhaustes")
        return {first, second}
      end,
    },
  }

  heat_exhaust.rebuild_registry()

  for _, entity in ipairs({first, second}) do
    assert_eq(entity.setting.mode, "at-most", "rebuild must repair the sink setting")
  end
end)

test("other entities are never treated as heat exhausts", function()
  local entity = {valid = true, name = "ai-server"}
  assert_true(not heat_exhaust.configure(entity), "only the exhaust should receive heat-interface settings")
end)

print(string.format("\n=== HEAT EXHAUST RUNTIME TESTS ==="))
print(string.format("Passed: %d  Failed: %d  Total: %d", passed, failed, passed + failed))

if #errors > 0 then
  print("\nFAILURES:")
  for i, err in ipairs(errors) do
    print(string.format("  %d) %s", i, err))
  end
  os.exit(1)
end

print("\nAll tests passed!")
