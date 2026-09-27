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
      ["transport-belt"] = {enabled = false},
      ["transport-belt-regulated"] = {enabled = false},
      ["transport-belt-foundry"] = {enabled = false},
      ["foundry"] = {enabled = false},
      ["foundry-regulated"] = {enabled = false},
      ["foundry-approval"] = {enabled = false},
      ["electronic-circuit"] = {enabled = false},
      ["electronic-circuit-electromagnetic"] = {enabled = false},
      ["fast-inserter"] = {enabled = false},
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

  assert_true(force.recipes["transport-belt"].enabled, "logistics should unlock transport-belt")
  assert_true(force.recipes["transport-belt-regulated"].enabled, "logistics should unlock transport-belt-regulated")
  assert_true(force.recipes["transport-belt-foundry"].enabled, "logistics should unlock the foundry route")
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

  assert_true(force.recipes["fast-inserter"].enabled, "research should unlock fast-inserter")
  assert_true(force.recipes["fast-inserter-regulated"].enabled, "research objects should unlock regulated variants")
end)

test("specialist approval unlocks with its construction research", function()
  local force = new_force()
  local research = {prototype = {effects = {{type = "unlock-recipe", recipe = "foundry"}}}}
  regulated_unlocks.enable_regulated_variants_for_technology(force, research)
  assert_true(force.recipes["foundry"].enabled, "foundry chassis should unlock")
  assert_true(force.recipes["foundry-regulated"].enabled, "assembler chassis route should unlock")
  assert_true(force.recipes["foundry-approval"].enabled, "foundry approval should unlock")
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

test("configuration sync enables default and previously unlocked regulated copies", function()
  local force = new_force()
  force.recipes["transport-belt"].enabled = true
  force.recipes["electronic-circuit"].enabled = true
  force.recipes["fast-inserter"].enabled = true
  force.recipes["foundry"].enabled = true

  regulated_unlocks.sync_enabled_variants(force)

  assert_true(force.recipes["transport-belt-regulated"].enabled,
    "existing saves should enable the new basic-belt regulated copy")
  assert_true(force.recipes["fast-inserter-regulated"].enabled,
    "existing saves should mirror already-researched recipes")
  assert_true(force.recipes["transport-belt-foundry"].enabled,
    "existing saves should enable basic foundry pressing")
  assert_true(force.recipes["electronic-circuit-electromagnetic"].enabled,
    "existing saves should enable basic electromagnetic electronics")
  assert_true(force.recipes["foundry-approval"].enabled,
    "existing saves should enable approval for already researched specialist buildings")
end)

test("configuration sync ignores disabled originals and invalid forces", function()
  local force = new_force()

  regulated_unlocks.sync_enabled_variants(force)
  regulated_unlocks.sync_enabled_variants({valid = false})

  assert_true(not force.recipes["transport-belt-regulated"].enabled,
    "disabled originals must not be unlocked")
  assert_true(not force.recipes["transport-belt-foundry"].enabled,
    "disabled originals must not unlock foundry routes")
  assert_true(not force.recipes["electronic-circuit-electromagnetic"].enabled,
    "disabled originals must not unlock electromagnetic routes")
end)

print(("Regulated unlock runtime tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
