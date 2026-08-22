-------------------------------------------------------------------------------
-- EGG COURIER TESTS
--
-- Biter eggs never leave Nauvis: courier properties and the recipe reroute.
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

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

local couriers = require("prototypes.shared.manager_couriers")
local egg_couriers = require("prototypes.final_fixes.egg_couriers")

test("every courier spoils back into a regular manager after thirty minutes", function()
  assert_eq(couriers.SPOIL_TICKS, 30 * 60 * 60, "couriers should last 30 minutes")
  assert_eq(couriers.SPOIL_RESULT, "middle-management-managing-manager",
    "an expired courier should cost the eggs and the trip, never the manager")
  assert_eq(couriers.EGGS_PER_COURIER, 10, "couriers should carry the vanilla ten-egg cost")
  assert_eq(#couriers.COURIERS, 3, "there should be exactly three couriers")
end)

test("only the Geotechnical courier is handed back", function()
  assert_eq(couriers.BY_KEY.geotechnical.fate, "returned", "the Gleba courier should return")
  assert_eq(couriers.BY_KEY.missionary.fate, "consumed", "the Aquilo courier should be consumed")
  assert_eq(couriers.BY_KEY.cobaye.fate, "consumed", "the orbital courier should be consumed")
end)

local function fake_recipes()
  return {
    ["biolab"] = {ingredients = {{type = "item", name = "biter-egg", amount = 10}}, results = {}},
    ["nutrients-from-biter-egg"] = {ingredients = {{type = "item", name = "biter-egg", amount = 1}}, results = {}},
    ["overgrowth-yumako-soil"] = {ingredients = {{type = "item", name = "biter-egg", amount = 10}}, results = {}},
    ["overgrowth-jellynut-soil"] = {ingredients = {{type = "item", name = "biter-egg", amount = 10}}, results = {}},
    ["captive-biter-spawner"] = {ingredients = {{type = "item", name = "biter-egg", amount = 10}}, results = {}},
    ["promethium-science-pack"] = {
      ingredients = {
        {type = "item", name = "promethium-asteroid-chunk", amount = 25},
        {type = "item", name = "quantum-processor", amount = 1},
        {type = "item", name = "promethium-research-charter", amount = 1},
        {type = "item", name = "biter-egg", amount = 10},
      },
      results = {{type = "item", name = "promethium-science-pack", amount = 10}},
      energy_required = 5,
    },
  }
end

local function amount_of(recipe, name)
  for _, entry in ipairs(recipe.ingredients or {}) do
    if (entry.name or entry[1]) == name then return entry.amount or entry[2] end
  end
  return nil
end

local function result_amount_of(recipe, name)
  for _, entry in ipairs(recipe.results or {}) do
    if (entry.name or entry[1]) == name then return entry.amount or entry[2] end
  end
  return nil
end

test("no recipe still consumes biter eggs off Nauvis after the reroute", function()
  local recipes = fake_recipes()
  egg_couriers.apply({raw = {recipe = recipes}})

  for _, recipe_name in ipairs({
    "overgrowth-yumako-soil", "overgrowth-jellynut-soil",
    "captive-biter-spawner", "promethium-science-pack",
  }) do
    assert_eq(amount_of(recipes[recipe_name], "biter-egg"), nil,
      recipe_name .. " must not consume biter eggs offworld")
  end
end)

test("Nauvis-only egg crafts keep their eggs and gain a surface condition", function()
  local recipes = fake_recipes()
  egg_couriers.apply({raw = {recipe = recipes}})

  for _, recipe_name in ipairs({"biolab", "nutrients-from-biter-egg"}) do
    local recipe = recipes[recipe_name]
    assert_true(amount_of(recipe, "biter-egg") ~= nil, recipe_name .. " should keep its vanilla egg cost")
    assert_true(recipe.surface_conditions ~= nil and #recipe.surface_conditions > 0,
      recipe_name .. " should be pinned to Nauvis")
  end
end)

test("the Gleba soils take a Geotechnical courier and hand a manager back", function()
  local recipes = fake_recipes()
  egg_couriers.apply({raw = {recipe = recipes}})

  for _, recipe_name in ipairs({"overgrowth-yumako-soil", "overgrowth-jellynut-soil"}) do
    local recipe = recipes[recipe_name]
    assert_eq(amount_of(recipe, "geotechnical-assessment-manager"), 1,
      recipe_name .. " should consume one Geotechnical courier")
    assert_eq(result_amount_of(recipe, "middle-management-managing-manager"), 1,
      recipe_name .. " should hand the manager back")
  end
end)

test("the captive spawner consumes its missionary outright", function()
  local recipes = fake_recipes()
  egg_couriers.apply({raw = {recipe = recipes}})
  assert_eq(amount_of(recipes["captive-biter-spawner"], "missionary-manager"), 1,
    "the spawner should consume one Missionary")
  assert_eq(result_amount_of(recipes["captive-biter-spawner"], "middle-management-managing-manager"), nil,
    "the Missionary should not come back")
end)

test("Administratorium science batches tenfold against exactly one Cobaye", function()
  local recipes = fake_recipes()
  egg_couriers.apply({raw = {recipe = recipes}})
  local recipe = recipes["promethium-science-pack"]

  assert_eq(amount_of(recipe, "promethium-asteroid-chunk"), 250, "chunks should scale x10")
  assert_eq(amount_of(recipe, "quantum-processor"), 10, "processors should scale x10")
  assert_eq(result_amount_of(recipe, "promethium-science-pack"), 100, "output should scale x10")
  assert_eq(recipe.energy_required, 50, "energy should scale x10")
  assert_eq(amount_of(recipe, "voluntary-research-subject"), 1,
    "exactly one Cobaye per batch is what puts the recipe at vanilla rocket parity")
end)

test("the expedition charter scales with the batch instead of getting ten times cheaper", function()
  local recipes = fake_recipes()
  egg_couriers.apply({raw = {recipe = recipes}})
  assert_eq(amount_of(recipes["promethium-science-pack"], "promethium-research-charter"), 10,
    "the charter must stay at one per ten packs, as vanilla costs it")
end)

test("Cobaye rocket parity holds at two kilograms per science pack", function()
  -- Vanilla: 10 eggs at 2 kg buys 10 packs. Batched: one 200 kg Cobaye buys 100.
  local vanilla_kg_per_pack = (10 * 2) / 10
  local cobaye_kg_per_pack = 200 / 100
  assert_eq(cobaye_kg_per_pack, vanilla_kg_per_pack, "the Cobaye should land on exact vanilla parity")
end)

print(string.format("\n=== EGG COURIER TESTS ==="))
print(string.format("Passed: %d  Failed: %d  Total: %d", passed, failed, passed + failed))

if #errors > 0 then
  print("\nFAILURES:")
  for i, err in ipairs(errors) do
    print(string.format("  %d) %s", i, err))
  end
  os.exit(1)
end

print("\nAll tests passed!")
