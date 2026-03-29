-------------------------------------------------------------------------------
-- ADMINISTRATORIO FINAL FIXES TESTS
--
-- Standalone Lua tests that verify post-processing done in data-final-fixes.
-- Run: lua tests/test_final_fixes.lua
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- 0. MINI TEST FRAMEWORK
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
    error((msg or "") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function assert_true(value, msg)
  if not value then error(msg or "assertion failed", 2) end
end

-------------------------------------------------------------------------------
-- 1. MOCK FACTORIO DATA STAGE
-------------------------------------------------------------------------------
local recipes = {}
local technologies = {}

data = {
  raw = {
    recipe = recipes,
    technology = technologies,
    character = {
      character = {
        crafting_categories = {"crafting"},
      },
    },
    ["assembling-machine"] = {
      ["assembling-machine-1"] = { name = "assembling-machine-1", type = "assembling-machine", crafting_categories = {"crafting"} },
      ["assembling-machine-2"] = { name = "assembling-machine-2", type = "assembling-machine", crafting_categories = {"crafting", "advanced-crafting"} },
      ["assembling-machine-3"] = { name = "assembling-machine-3", type = "assembling-machine", crafting_categories = {"crafting", "advanced-crafting", "crafting-with-fluid"} },
    },
    ["module-category"] = {},
    fluid = {},
    item = {},
    tool = {},
    module = {},
    capsule = {},
    ammo = {},
    gun = {},
    armor = {},
    ["selection-tool"] = {},
    ["item-with-entity-data"] = {},
    ["rail-planner"] = {},
    ["spidertron-remote"] = {},
  },
}

function data:extend(prototypes)
  for _, proto in ipairs(prototypes) do
    local proto_type = proto.type
    if proto_type then
      data.raw[proto_type] = data.raw[proto_type] or {}
      data.raw[proto_type][proto.name] = proto
      if proto_type == "recipe" then
        recipes[proto.name] = proto
      elseif proto_type == "technology" then
        technologies[proto.name] = proto
      end
    end
  end
end

util = {
  table = {
    deepcopy = function(tbl)
      if type(tbl) ~= "table" then return tbl end
      local copy = {}
      for k, v in pairs(tbl) do
        copy[util.table.deepcopy(k)] = util.table.deepcopy(v)
      end
      return setmetatable(copy, getmetatable(tbl))
    end,
  },
}

-- Minimal vanilla coverage so final-fixes can exercise the Factoriopedia
-- redirection path for regulated non-admin recipes.
data.raw.item["iron-plate"] = { type = "item", name = "iron-plate", stack_size = 100 }
data.raw.item["electric-furnace"] = { type = "item", name = "electric-furnace", stack_size = 50 }
data.raw.item["transport-belt"] = { type = "item", name = "transport-belt", stack_size = 100 }
recipes["transport-belt"] = {
  type = "recipe",
  name = "transport-belt",
  enabled = true,
  ingredients = {
    { type = "item", name = "iron-plate", amount = 1 },
  },
  results = {
    { type = "item", name = "transport-belt", amount = 2 },
  },
}

recipes["iron-plate"] = {
  type = "recipe",
  name = "iron-plate",
  category = "smelting",
  enabled = true,
  ingredients = {
    { type = "item", name = "iron-ore", amount = 1 },
  },
  results = {
    { type = "item", name = "iron-plate", amount = 1 },
  },
}

recipes["electric-furnace"] = {
  type = "recipe",
  name = "electric-furnace",
  category = "advanced-crafting",
  enabled = false,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 10 },
    { type = "item", name = "advanced-circuit", amount = 10 },
    { type = "item", name = "stone-brick", amount = 10 },
  },
  results = {
    { type = "item", name = "electric-furnace", amount = 1 },
  },
}

technologies["advanced-material-processing-2"] = {
  type = "technology",
  name = "advanced-material-processing-2",
  effects = {
    { type = "unlock-recipe", recipe = "electric-furnace" },
  },
  unit = {
    count = 1,
    ingredients = {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
    },
    time = 1,
  },
}

if not table.deepcopy then
  table.deepcopy = util.table.deepcopy
end

-------------------------------------------------------------------------------
-- 2. LOAD MOD FILES
-------------------------------------------------------------------------------
local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

dofile(mod_root .. "prototypes/categories.lua")

dofile(mod_root .. "prototypes/item/groups.lua")
dofile(mod_root .. "prototypes/item/paperwork.lua")
dofile(mod_root .. "prototypes/item/buildings.lua")
dofile(mod_root .. "prototypes/item/economy.lua")
dofile(mod_root .. "prototypes/item/resolution.lua")
dofile(mod_root .. "prototypes/item/modules.lua")
dofile(mod_root .. "prototypes/item/capsules-and-fluids.lua")

dofile(mod_root .. "prototypes/recipe/paperwork.lua")
dofile(mod_root .. "prototypes/recipe/buildings.lua")
dofile(mod_root .. "prototypes/recipe/production.lua")
dofile(mod_root .. "prototypes/recipe/economy.lua")
dofile(mod_root .. "prototypes/recipe/resolution.lua")
dofile(mod_root .. "prototypes/recipe/modules.lua")
dofile(mod_root .. "prototypes/technology.lua")
dofile(mod_root .. "data-final-fixes.lua")

-------------------------------------------------------------------------------
-- HELPERS
-------------------------------------------------------------------------------
local function get_recipe(name)
  return recipes[name]
end

local function has_ingredient(recipe, item_name)
  if not recipe or not recipe.ingredients then return false end
  for _, ing in ipairs(recipe.ingredients) do
    if (ing.name or ing[1]) == item_name then return true end
  end
  return false
end

local function tech_unlocks_recipe(tech_name, recipe_name)
  local tech = technologies[tech_name]
  if not tech or not tech.effects then return false end
  for _, effect in ipairs(tech.effects) do
    if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
      return true
    end
  end
  return false
end

-------------------------------------------------------------------------------
-- 3. TESTS
-------------------------------------------------------------------------------

test("mechanical-printer gets a regulated AM recipe", function()
  local r = get_recipe("mechanical-printer-regulated")
  assert_true(r ~= nil, "mechanical-printer-regulated missing")
  assert_eq(r.category, "crafting-regulated", "mechanical printer regulated category")
  assert_true(has_ingredient(r, "work-order"), "mechanical-printer-regulated missing work-order")
  assert_eq(r.enabled, true, "mechanical-printer-regulated should stay enabled from start")
end)

test("printer-t1 gets a regulated AM recipe", function()
  local r = get_recipe("printer-t1-regulated")
  assert_true(r ~= nil, "printer-t1-regulated missing")
  assert_eq(r.category, "crafting-regulated", "printer-t1 regulated category")
  assert_true(has_ingredient(r, "provisional-approval"), "printer-t1-regulated missing provisional-approval")
  assert_true(has_ingredient(r, "work-order"), "printer-t1-regulated missing work-order")
end)

test("printer-t2 gets a regulated AM recipe", function()
  local r = get_recipe("printer-t2-regulated")
  assert_true(r ~= nil, "printer-t2-regulated missing")
  assert_eq(r.category, "crafting-regulated", "printer-t2 regulated category")
  assert_true(has_ingredient(r, "construction-permit"), "printer-t2-regulated missing construction-permit")
  assert_true(has_ingredient(r, "printer-t1"), "printer-t2-regulated missing printer-t1")
  assert_true(has_ingredient(r, "work-order"), "printer-t2-regulated missing work-order")
end)

test("paper and ink get regulated AM recipes", function()
  local paper = get_recipe("paper-production-regulated")
  assert_true(paper ~= nil, "paper-production-regulated missing")
  assert_eq(paper.category, "crafting-regulated", "paper-production-regulated category")
  assert_true(has_ingredient(paper, "work-order"), "paper-production-regulated missing work-order")
  assert_eq(paper.enabled, true, "paper-production-regulated should stay enabled from start")

  -- Factoriopedia merge canonicalizes ink-production -> ink.
  local ink = get_recipe("ink-regulated")
  assert_true(ink ~= nil, "ink-regulated missing")
  assert_eq(ink.category, "crafting-regulated", "ink-regulated category")
  assert_true(has_ingredient(ink, "work-order"), "ink-regulated missing work-order")
  assert_eq(ink.enabled, true, "ink-regulated should stay enabled from start")
end)

test("smelting recipes get certified steel-furnace variants", function()
  local r = get_recipe("iron-plate-certified")
  assert_true(r ~= nil, "iron-plate-certified missing")
  assert_eq(r.category, "smelting-basic", "iron-plate-certified category")
  assert_true(has_ingredient(r, "iron-ore"), "iron-plate-certified missing iron-ore")
  assert_true(has_ingredient(r, "carbon-offset-certificate-basic"),
    "iron-plate-certified missing carbon-offset-certificate-basic")
  assert_eq(r.hide_from_player_crafting, true, "iron-plate-certified should be hidden from player crafting")
  assert_eq(r.allow_decomposition, false, "iron-plate-certified should disable decomposition")
end)

test("electric furnace recipe upgrades to management verbal paperwork", function()
  local r = get_recipe("electric-furnace")
  assert_true(r ~= nil, "electric-furnace missing")
  assert_eq(r.category, "advanced-crafting-regulated", "electric-furnace category")
  assert_true(has_ingredient(r, "management-verbal-work-order"), "electric-furnace missing management-verbal-work-order")
  assert_true(not has_ingredient(r, "construction-work-order"), "electric-furnace should not use construction-work-order")
end)

test("all plain crafting recipes have regulated AM copies", function()
  for name, recipe in pairs(recipes) do
    if not name:find("%-regulated$") then
      local cat = recipe.category or "crafting"
      if cat == "crafting" or cat == "advanced-crafting" then
        local regulated = get_recipe(name .. "-regulated")
        assert_true(regulated ~= nil, name .. " missing regulated AM copy")
      end
    end
  end
end)

test("printer regulated recipes are not duplicated in technology unlock effects", function()
  assert_true(tech_unlocks_recipe("printing-technology", "printer-t1"), "printing-technology missing printer-t1 unlock")
  assert_true(not tech_unlocks_recipe("printing-technology", "printer-t1-regulated"), "printing-technology should not list printer-t1-regulated")
  assert_true(tech_unlocks_recipe("industrial-printing", "printer-t2"), "industrial-printing missing printer-t2 unlock")
  assert_true(not tech_unlocks_recipe("industrial-printing", "printer-t2-regulated"), "industrial-printing should not list printer-t2-regulated")
end)

test("pneumatic transport does not duplicate regulated unlocks", function()
  assert_true(tech_unlocks_recipe("pneumatic-form-transport", "form-liquifier"), "pneumatic-form-transport missing form-liquifier unlock")
  assert_true(not tech_unlocks_recipe("pneumatic-form-transport", "form-liquifier-regulated"), "pneumatic-form-transport should not list form-liquifier-regulated")
  assert_true(tech_unlocks_recipe("pneumatic-form-transport", "form-solidifier"), "pneumatic-form-transport missing form-solidifier unlock")
  assert_true(not tech_unlocks_recipe("pneumatic-form-transport", "form-solidifier-regulated"), "pneumatic-form-transport should not list form-solidifier-regulated")
end)

test("vanilla recipes redirect Factoriopedia to regulated copies", function()
  local original = get_recipe("transport-belt")
  local regulated = get_recipe("transport-belt-regulated")

  assert_true(original ~= nil, "transport-belt missing")
  assert_true(regulated ~= nil, "transport-belt-regulated missing")
  assert_eq(original.factoriopedia_alternative, "transport-belt-regulated", "transport-belt should redirect Factoriopedia to the regulated recipe")
  assert_eq(original.hidden_in_factoriopedia, true, "transport-belt should be hidden in Factoriopedia")
  assert_true(not regulated.hidden_in_factoriopedia, "transport-belt-regulated should remain visible in Factoriopedia")
end)

test("admin building recipes redirect Factoriopedia to regulated copies", function()
  local original = get_recipe("printer-t1")
  local regulated = get_recipe("printer-t1-regulated")

  assert_true(original ~= nil, "printer-t1 missing")
  assert_true(regulated ~= nil, "printer-t1-regulated missing")
  assert_eq(original.factoriopedia_alternative, "printer-t1-regulated", "printer-t1 should redirect Factoriopedia to the regulated recipe")
  assert_eq(original.hidden_in_factoriopedia, true, "printer-t1 should be hidden in Factoriopedia")
  assert_true(not regulated.hidden_in_factoriopedia, "printer-t1-regulated should remain visible in Factoriopedia")
end)

-------------------------------------------------------------------------------
-- 4. REPORT
-------------------------------------------------------------------------------
print(string.format("\n=== ADMINISTRATORIO FINAL FIXES TESTS ==="))
print(string.format("Passed: %d  Failed: %d  Total: %d", passed, failed, passed + failed))

if #errors > 0 then
  print("\nFAILURES:")
  for i, err in ipairs(errors) do
    print(string.format("  %d) %s", i, err))
  end
  os.exit(1)
else
  print("\nAll tests passed!")
end
