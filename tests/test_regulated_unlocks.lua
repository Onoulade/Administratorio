-------------------------------------------------------------------------------
-- ADMINISTRATORIO REGULATED UNLOCK RUNTIME TESTS
--
-- Standalone Lua tests that verify runtime regulated-recipe mirroring resolves
-- technology effects through runtime technology objects/prototypes.
-- Run: lua tests/test_regulated_unlocks.lua
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

local function assert_true(value, msg)
  if not value then error(msg or "assertion failed", 2) end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

local regulated_unlocks = require("scripts.regulated_unlocks")

local function new_force()
  return {
    recipes = {
      ["transport-belt-regulated"] = {enabled = false},
      ["fast-inserter-regulated"] = {enabled = false},
    },
    technologies = {},
  }
end

test("technology names resolve through force technologies", function()
  local force = new_force()
  force.technologies["logistics"] = {
    prototype = {
      effects = {
        {type = "unlock-recipe", recipe = "transport-belt"},
        {type = "character-logistic-trash-slots", modifier = 5},
      },
    },
  }

  regulated_unlocks.enable_regulated_variants_for_technology(force, "logistics")

  assert_true(force.recipes["transport-belt-regulated"].enabled, "logistics should unlock transport-belt-regulated")
end)

test("research objects from on_research_finished use their prototype", function()
  local force = new_force()
  local research = {
    prototype = {
      effects = {
        {type = "unlock-recipe", recipe = "fast-inserter"},
      },
    },
  }

  regulated_unlocks.enable_regulated_variants_for_technology(force, research)

  assert_true(force.recipes["fast-inserter-regulated"].enabled, "research objects should unlock regulated variants")
end)

test("direct prototypes and missing regulated copies are handled safely", function()
  local force = new_force()

  regulated_unlocks.enable_regulated_variants_for_technology(force, {
    effects = {
      {type = "unlock-recipe", recipe = "missing"},
    },
  })
  regulated_unlocks.enable_regulated_variants_for_technology(force, {valid = false})

  assert_true(not force.recipes["transport-belt-regulated"].enabled, "missing regulated copies should be ignored")
  assert_true(not force.recipes["fast-inserter-regulated"].enabled, "invalid technologies should be ignored")
end)

print(("Regulated unlock runtime tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
