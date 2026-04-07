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
    ["repair-tool"] = {},
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
data.raw.item["iron-plate"] = {
  type = "item",
  name = "iron-plate",
  stack_size = 100,
  icon = "__base__/graphics/icons/iron-plate.png",
  icon_size = 64,
}
data.raw.item["electric-furnace"] = {
  type = "item",
  name = "electric-furnace",
  stack_size = 50,
  icon = "__base__/graphics/icons/electric-furnace.png",
  icon_size = 64,
}
data.raw.item["nuclear-reactor"] = {
  type = "item",
  name = "nuclear-reactor",
  stack_size = 10,
  icon = "__base__/graphics/icons/nuclear-reactor.png",
  icon_size = 64,
}
data.raw.item["splitter"] = {
  type = "item",
  name = "splitter",
  stack_size = 50,
  icon = "__base__/graphics/icons/splitter.png",
  icon_size = 64,
}
data.raw.item["transport-belt"] = {
  type = "item",
  name = "transport-belt",
  stack_size = 100,
  place_result = "transport-belt",
  icon = "__base__/graphics/icons/transport-belt.png",
  icon_size = 64,
}
data.raw["repair-tool"]["repair-pack"] = {
  type = "repair-tool",
  name = "repair-pack",
  stack_size = 100,
  icon = "__base__/graphics/icons/repair-pack.png",
  icon_size = 64,
}
data.raw.item["heat-pipe"] = {
  type = "item",
  name = "heat-pipe",
  stack_size = 50,
  icon = "__base__/graphics/icons/heat-pipe.png",
  icon_size = 64,
}
data.raw.item["explosives"] = {
  type = "item",
  name = "explosives",
  stack_size = 100,
  icon = "__base__/graphics/icons/explosives.png",
  icon_size = 64,
}
data.raw.item["cliff-explosives"] = {
  type = "item",
  name = "cliff-explosives",
  stack_size = 20,
  icon = "__base__/graphics/icons/cliff-explosives.png",
  icon_size = 64,
}
data.raw.item["rail-ramp"] = {
  type = "item",
  name = "rail-ramp",
  stack_size = 20,
  icon = "__base__/graphics/icons/rail-ramp.png",
  icon_size = 64,
}
data.raw.item["rail-support"] = {
  type = "item",
  name = "rail-support",
  stack_size = 50,
  icon = "__base__/graphics/icons/rail-support.png",
  icon_size = 64,
}
data.raw.item["solar-panel-equipment"] = {
  type = "item",
  name = "solar-panel-equipment",
  stack_size = 20,
  placed_as_equipment_result = "solar-panel-equipment",
  icon = "__base__/graphics/icons/solar-panel-equipment.png",
  icon_size = 64,
}
data.raw.item["battery-equipment"] = {
  type = "item",
  name = "battery-equipment",
  stack_size = 20,
  placed_as_equipment_result = "battery-equipment",
  icon = "__base__/graphics/icons/battery-equipment.png",
  icon_size = 64,
}
data.raw.item["battery-mk2-equipment"] = {
  type = "item",
  name = "battery-mk2-equipment",
  stack_size = 20,
  placed_as_equipment_result = "battery-mk2-equipment",
  icon = "__base__/graphics/icons/battery-mk2-equipment.png",
  icon_size = 64,
}
data.raw.item["exoskeleton-equipment"] = {
  type = "item",
  name = "exoskeleton-equipment",
  stack_size = 20,
  placed_as_equipment_result = "exoskeleton-equipment",
  icon = "__base__/graphics/icons/exoskeleton-equipment.png",
  icon_size = 64,
}
data.raw.item["plastic-bar"] = {
  type = "item",
  name = "plastic-bar",
  stack_size = 100,
  icon = "__base__/graphics/icons/plastic-bar.png",
  icon_size = 64,
}
data.raw.item["solid-fuel"] = {
  type = "item",
  name = "solid-fuel",
  stack_size = 50,
  icon = "__base__/graphics/icons/solid-fuel.png",
  icon_size = 64,
}
data.raw.item["sulfur"] = {
  type = "item",
  name = "sulfur",
  stack_size = 100,
  icon = "__base__/graphics/icons/sulfur.png",
  icon_size = 64,
}
data.raw.fluid["sulfuric-acid"] = {
  type = "fluid",
  name = "sulfuric-acid",
  icon = "__base__/graphics/icons/fluid/sulfuric-acid.png",
  icon_size = 64,
}
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

recipes["splitter"] = {
  type = "recipe",
  name = "splitter",
  enabled = false,
  ingredients = {
    { type = "item", name = "electronic-circuit", amount = 1 },
    { type = "item", name = "iron-plate", amount = 1 },
  },
  results = {
    { type = "item", name = "splitter", amount = 1 },
  },
}

recipes["nuclear-reactor"] = {
  type = "recipe",
  name = "nuclear-reactor",
  category = "advanced-crafting",
  enabled = false,
  ingredients = {
    { type = "item", name = "concrete", amount = 500 },
    { type = "item", name = "steel-plate", amount = 500 },
    { type = "item", name = "advanced-circuit", amount = 500 },
    { type = "item", name = "copper-plate", amount = 500 },
  },
  results = {
    { type = "item", name = "nuclear-reactor", amount = 1 },
  },
}

recipes["repair-pack"] = {
  type = "recipe",
  name = "repair-pack",
  enabled = false,
  ingredients = {
    { type = "item", name = "iron-gear-wheel", amount = 2 },
    { type = "item", name = "electronic-circuit", amount = 2 },
  },
  results = {
    { name = "repair-pack", amount = 1 },
  },
}

recipes["heat-pipe"] = {
  type = "recipe",
  name = "heat-pipe",
  category = "advanced-crafting",
  enabled = false,
  ingredients = {
    { type = "item", name = "copper-plate", amount = 10 },
    { type = "item", name = "steel-plate", amount = 5 },
  },
  results = {
    { type = "item", name = "heat-pipe", amount = 1 },
  },
}

recipes["cliff-explosives"] = {
  type = "recipe",
  name = "cliff-explosives",
  enabled = false,
  ingredients = {
    { type = "item", name = "explosives", amount = 10 },
    { type = "item", name = "grenade", amount = 1 },
    { type = "item", name = "empty-barrel", amount = 1 },
  },
  results = {
    { type = "item", name = "cliff-explosives", amount = 1 },
  },
}

recipes["rail-ramp"] = {
  type = "recipe",
  name = "rail-ramp",
  enabled = false,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 4 },
    { type = "item", name = "stone-brick", amount = 4 },
  },
  results = {
    { type = "item", name = "rail-ramp", amount = 1 },
  },
}

recipes["rail-support"] = {
  type = "recipe",
  name = "rail-support",
  enabled = false,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 2 },
    { type = "item", name = "concrete", amount = 2 },
  },
  results = {
    { type = "item", name = "rail-support", amount = 1 },
  },
}

recipes["solar-panel-equipment"] = {
  type = "recipe",
  name = "solar-panel-equipment",
  enabled = false,
  ingredients = {
    { type = "item", name = "solar-panel", amount = 5 },
    { type = "item", name = "electronic-circuit", amount = 2 },
  },
  results = {
    { type = "item", name = "solar-panel-equipment", amount = 1 },
  },
}

recipes["battery-equipment"] = {
  type = "recipe",
  name = "battery-equipment",
  enabled = false,
  ingredients = {
    { type = "item", name = "battery", amount = 5 },
    { type = "item", name = "steel-plate", amount = 2 },
  },
  results = {
    { type = "item", name = "battery-equipment", amount = 1 },
  },
}

recipes["battery-mk2-equipment"] = {
  type = "recipe",
  name = "battery-mk2-equipment",
  enabled = false,
  ingredients = {
    { type = "item", name = "battery-equipment", amount = 10 },
    { type = "item", name = "processing-unit", amount = 5 },
  },
  results = {
    { type = "item", name = "battery-mk2-equipment", amount = 1 },
  },
}

recipes["exoskeleton-equipment"] = {
  type = "recipe",
  name = "exoskeleton-equipment",
  enabled = false,
  ingredients = {
    { type = "item", name = "electric-engine-unit", amount = 10 },
    { type = "item", name = "advanced-circuit", amount = 10 },
  },
  results = {
    { type = "item", name = "exoskeleton-equipment", amount = 1 },
  },
}

recipes["oil-processing"] = {
  type = "recipe",
  name = "oil-processing",
  category = "oil-processing",
  enabled = false,
  ingredients = {
    { type = "fluid", name = "crude-oil", amount = 100 },
  },
  results = {
    { type = "fluid", name = "heavy-oil", amount = 30 },
    { type = "fluid", name = "light-oil", amount = 30 },
    { type = "fluid", name = "petroleum-gas", amount = 40 },
  },
}

recipes["advanced-oil-processing"] = {
  type = "recipe",
  name = "advanced-oil-processing",
  category = "oil-processing",
  enabled = false,
  ingredients = {
    { type = "fluid", name = "crude-oil", amount = 100 },
    { type = "fluid", name = "water", amount = 50 },
  },
  results = {
    { type = "fluid", name = "heavy-oil", amount = 25 },
    { type = "fluid", name = "light-oil", amount = 45 },
    { type = "fluid", name = "petroleum-gas", amount = 55 },
  },
}

recipes["coal-liquefaction"] = {
  type = "recipe",
  name = "coal-liquefaction",
  category = "oil-processing",
  enabled = false,
  ingredients = {
    { type = "item", name = "coal", amount = 10 },
    { type = "fluid", name = "steam", amount = 50 },
    { type = "fluid", name = "heavy-oil", amount = 25 },
  },
  results = {
    { type = "fluid", name = "heavy-oil", amount = 90 },
    { type = "fluid", name = "light-oil", amount = 20 },
    { type = "fluid", name = "petroleum-gas", amount = 10 },
  },
}

recipes["plastic-bar"] = {
  type = "recipe",
  name = "plastic-bar",
  category = "chemistry",
  enabled = false,
  ingredients = {
    { type = "fluid", name = "petroleum-gas", amount = 20 },
    { type = "item", name = "coal", amount = 1 },
  },
  results = {
    { type = "item", name = "plastic-bar", amount = 2 },
  },
}

recipes["sulfur"] = {
  type = "recipe",
  name = "sulfur",
  category = "chemistry",
  enabled = false,
  ingredients = {
    { type = "fluid", name = "petroleum-gas", amount = 30 },
    { type = "fluid", name = "water", amount = 30 },
  },
  results = {
    { type = "item", name = "sulfur", amount = 2 },
  },
}

recipes["sulfuric-acid"] = {
  type = "recipe",
  name = "sulfuric-acid",
  category = "chemistry",
  enabled = false,
  ingredients = {
    { type = "item", name = "iron-plate", amount = 1 },
    { type = "item", name = "sulfur", amount = 5 },
    { type = "fluid", name = "water", amount = 100 },
  },
  results = {
    { type = "fluid", name = "sulfuric-acid", amount = 50 },
  },
}

recipes["solid-fuel-from-heavy-oil"] = {
  type = "recipe",
  name = "solid-fuel-from-heavy-oil",
  category = "chemistry",
  enabled = false,
  ingredients = {
    { type = "fluid", name = "heavy-oil", amount = 20 },
  },
  results = {
    { type = "item", name = "solid-fuel", amount = 1 },
  },
}

recipes["solid-fuel-from-light-oil"] = {
  type = "recipe",
  name = "solid-fuel-from-light-oil",
  category = "chemistry",
  enabled = false,
  ingredients = {
    { type = "fluid", name = "light-oil", amount = 10 },
  },
  results = {
    { type = "item", name = "solid-fuel", amount = 1 },
  },
}

recipes["solid-fuel-from-petroleum-gas"] = {
  type = "recipe",
  name = "solid-fuel-from-petroleum-gas",
  category = "chemistry",
  enabled = false,
  ingredients = {
    { type = "fluid", name = "petroleum-gas", amount = 20 },
  },
  results = {
    { type = "item", name = "solid-fuel", amount = 1 },
  },
}

recipes["uranium-processing"] = {
  type = "recipe",
  name = "uranium-processing",
  category = "centrifuging",
  enabled = false,
  ingredients = {
    { type = "item", name = "uranium-ore", amount = 10 },
  },
  results = {
    { type = "item", name = "uranium-235", amount = 1, probability = 0.007 },
    { type = "item", name = "uranium-238", amount = 1, probability = 0.993 },
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

technologies["automation"] = {
  type = "technology",
  name = "automation",
  effects = {
    { type = "unlock-recipe", recipe = "repair-pack" },
  },
  unit = {
    count = 1,
    ingredients = {
      {"automation-science-pack", 1},
    },
    time = 1,
  },
}

technologies["nuclear-power"] = {
  type = "technology",
  name = "nuclear-power",
  effects = {
    { type = "unlock-recipe", recipe = "nuclear-reactor" },
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

technologies["logistics"] = {
  type = "technology",
  name = "logistics",
  effects = {
    { type = "unlock-recipe", recipe = "splitter" },
  },
  unit = {
    count = 1,
    ingredients = {
      {"automation-science-pack", 1},
    },
    time = 1,
  },
}

technologies["cliff-explosives"] = {
  type = "technology",
  name = "cliff-explosives",
  prerequisites = {"explosives", "military-2"},
  effects = {
    { type = "unlock-recipe", recipe = "cliff-explosives" },
  },
  unit = {
    count = 1,
    ingredients = {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
      {"chemical-science-pack", 1},
    },
    time = 1,
  },
}

technologies["elevated-rails"] = {
  type = "technology",
  name = "elevated-rails",
  research_trigger = { type = "build-entity", entity = "rail-signal" },
  effects = {
    { type = "unlock-recipe", recipe = "rail-ramp" },
    { type = "unlock-recipe", recipe = "rail-support" },
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

local function get_ingredient_amount(recipe, item_name)
  if not recipe or not recipe.ingredients then return nil end
  for _, ing in ipairs(recipe.ingredients) do
    if (ing.name or ing[1]) == item_name then
      return ing.amount or ing[2]
    end
  end
  return nil
end

local function get_result_amount(recipe, item_name)
  if not recipe or not recipe.results then return nil end
  for _, res in ipairs(recipe.results) do
    if (res.name or res[1]) == item_name then
      return res.amount or res[2]
    end
  end
  return nil
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

local function has_icon_layer(recipe, icon_path)
  if not recipe or not recipe.icons then return false end
  for _, layer in ipairs(recipe.icons) do
    if layer.icon == icon_path then
      return true
    end
  end
  return false
end

local function get_icon_layer(recipe, icon_path)
  if not recipe or not recipe.icons then return nil end
  for _, layer in ipairs(recipe.icons) do
    if layer.icon == icon_path then
      return layer
    end
  end
  return nil
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

test("ink regulated recipe icon matches the base item icon", function()
  local ink = get_recipe("ink-regulated")
  assert_true(ink ~= nil, "ink-regulated missing")
  assert_true(ink.icons ~= nil, "ink-regulated should use layered icons")

  local base_layer = get_icon_layer(ink, "__administratorio__/graphics/icons/ink-cartridge.png")
  assert_true(base_layer ~= nil, "ink-regulated should use the ink cartridge base icon")
  assert_true(base_layer.tint == nil, "ink-regulated should not apply the item's prototype tint to the recipe icon")
end)

test("repair-pack gets a bulked regulated AM recipe", function()
  local regulated = get_recipe("repair-pack-regulated")
  assert_true(regulated ~= nil, "repair-pack-regulated missing")
  assert_eq(regulated.category, "crafting-regulated", "repair-pack-regulated category")
  assert_true(has_ingredient(regulated, "work-order"), "repair-pack-regulated missing work-order")
  assert_eq(get_result_amount(regulated, "repair-pack"), 5, "repair-pack-regulated should batch to 5")
  assert_true(has_icon_layer(regulated, "__base__/graphics/icons/signal/signal_5.png"),
    "repair-pack-regulated should show the 5x overlay")
end)

test("heat-pipe batches at 10x", function()
  local regulated = get_recipe("heat-pipe")
  assert_true(regulated ~= nil, "heat-pipe missing")
  assert_eq(regulated.category, "advanced-crafting-regulated", "heat-pipe category")
  assert_true(has_ingredient(regulated, "work-order"), "heat-pipe missing work-order")
  assert_eq(get_result_amount(regulated, "heat-pipe"), 10, "heat-pipe should batch to 10")
  assert_true(has_icon_layer(regulated, "__base__/graphics/icons/signal/signal_1.png"),
    "heat-pipe should show the 10x overlay")
  assert_true(has_icon_layer(regulated, "__base__/graphics/icons/signal/signal_0.png"),
    "heat-pipe should show the 10x overlay")
end)

test("equipment recipes default to 1x except solar panels and batteries", function()
  local solar = get_recipe("solar-panel-equipment")
  assert_true(solar ~= nil, "solar-panel-equipment missing")
  assert_eq(get_result_amount(solar, "solar-panel-equipment"), 2, "solar-panel-equipment should batch to 2")
  assert_true(has_icon_layer(solar, "__base__/graphics/icons/signal/signal_2.png"),
    "solar-panel-equipment should show the 2x overlay")

  local battery = get_recipe("battery-equipment")
  assert_true(battery ~= nil, "battery-equipment missing")
  assert_eq(get_result_amount(battery, "battery-equipment"), 2, "battery-equipment should batch to 2")
  assert_true(has_icon_layer(battery, "__base__/graphics/icons/signal/signal_2.png"),
    "battery-equipment should show the 2x overlay")

  local battery_mk2 = get_recipe("battery-mk2-equipment")
  assert_true(battery_mk2 ~= nil, "battery-mk2-equipment missing")
  assert_eq(get_result_amount(battery_mk2, "battery-mk2-equipment"), 2, "battery-mk2-equipment should batch to 2")
  assert_true(has_icon_layer(battery_mk2, "__base__/graphics/icons/signal/signal_2.png"),
    "battery-mk2-equipment should show the 2x overlay")

  local exoskeleton = get_recipe("exoskeleton-equipment")
  assert_true(exoskeleton ~= nil, "exoskeleton-equipment missing")
  assert_eq(get_result_amount(exoskeleton, "exoskeleton-equipment"), 1, "exoskeleton-equipment should stay 1x")
  assert_true(not has_icon_layer(exoskeleton, "__base__/graphics/icons/signal/signal_1.png"),
    "exoskeleton-equipment should not show a 1x overlay")
end)

test("smelting-basic keeps only explicit batch recipes", function()
  local batch = get_recipe("iron-plate-batch")
  assert_true(batch ~= nil, "iron-plate-batch missing")
  assert_eq(batch.category, "smelting-basic", "iron-plate-batch category")
  assert_eq(batch.ingredients[1].name, "carbon-offset-certificate-basic",
    "iron-plate-batch should list the carbon certificate first")
  assert_eq(batch.ingredients[2].name, "iron-ore",
    "iron-plate-batch should list the smelting input second")
  assert_true(has_ingredient(batch, "iron-ore"), "iron-plate-batch missing iron-ore")
  assert_true(has_ingredient(batch, "carbon-offset-certificate-basic"),
    "iron-plate-batch missing carbon-offset-certificate-basic")

  local certified = get_recipe("iron-plate-certified")
  assert_true(certified == nil, "iron-plate-certified should not exist")
end)

test("electric furnace recipe upgrades to management verbal paperwork", function()
  local r = get_recipe("electric-furnace")
  assert_true(r ~= nil, "electric-furnace missing")
  assert_eq(r.category, "advanced-crafting-regulated", "electric-furnace category")
  assert_true(has_ingredient(r, "management-verbal-work-order"), "electric-furnace missing management-verbal-work-order")
  assert_true(not has_ingredient(r, "construction-work-order"), "electric-furnace should not use construction-work-order")
end)

test("splitter uses safety waiver by hand and safety work order in regulated 5x batches", function()
  local original = get_recipe("splitter")
  local regulated = get_recipe("splitter-regulated")

  assert_true(original ~= nil, "splitter missing")
  assert_true(regulated ~= nil, "splitter-regulated missing")

  assert_true(has_ingredient(original, "safety-waiver"), "splitter should require safety-waiver when handcrafted")
  assert_true(not has_ingredient(original, "construction-permit"), "splitter should not require construction-permit")
  assert_eq(get_ingredient_amount(original, "electronic-circuit"), 5, "splitter should batch handcraft ingredients at 5x")
  assert_eq(get_result_amount(original, "splitter"), 5, "splitter should batch handcraft results at 5x")

  assert_true(has_ingredient(regulated, "safety-work-order"), "splitter-regulated should require safety-work-order")
  assert_true(not has_ingredient(regulated, "construction-work-order"), "splitter-regulated should not require construction-work-order")
  assert_eq(get_ingredient_amount(regulated, "electronic-circuit"), 5, "splitter-regulated should batch AM ingredients at 5x")
  assert_eq(get_result_amount(regulated, "splitter"), 5, "splitter-regulated should produce 5 splitters")
end)

test("elevated rail ramps and supports require construction paperwork even on research-trigger techs", function()
  local ramp = get_recipe("rail-ramp")
  local ramp_regulated = get_recipe("rail-ramp-regulated")
  local support = get_recipe("rail-support")
  local support_regulated = get_recipe("rail-support-regulated")

  assert_true(ramp ~= nil, "rail-ramp missing")
  assert_true(ramp_regulated ~= nil, "rail-ramp-regulated missing")
  assert_true(support ~= nil, "rail-support missing")
  assert_true(support_regulated ~= nil, "rail-support-regulated missing")

  assert_true(has_ingredient(ramp, "construction-permit"), "rail-ramp should require construction-permit when handcrafted")
  assert_true(not has_ingredient(ramp, "work-order"), "rail-ramp should not fall back to a bare work-order")
  assert_true(has_ingredient(ramp_regulated, "construction-work-order"), "rail-ramp-regulated should require construction-work-order")

  assert_true(has_ingredient(support, "construction-permit"), "rail-support should require construction-permit when handcrafted")
  assert_true(not has_ingredient(support, "work-order"), "rail-support should not fall back to a bare work-order")
  assert_true(has_ingredient(support_regulated, "construction-work-order"), "rail-support-regulated should require construction-work-order")
end)

test("cliff explosives drop grenades but keep construction paperwork", function()
  local recipe = get_recipe("cliff-explosives")

  assert_true(recipe ~= nil, "cliff-explosives missing")
  assert_true(not has_ingredient(recipe, "grenade"), "cliff-explosives should not require grenades")
  assert_true(has_ingredient(recipe, "construction-permit"), "cliff-explosives should require construction-permit")
end)

test("bulk regulated recipe icons show amount overlay", function()
  local regulated = get_recipe("splitter-regulated")
  assert_true(regulated ~= nil, "splitter-regulated missing")
  assert_true(regulated.icons ~= nil, "splitter-regulated should use layered icons")
  assert_true(has_icon_layer(regulated, "__base__/graphics/icons/signal/signal_5.png"),
    "splitter-regulated should overlay the 5x amount")
  assert_true(not has_icon_layer(regulated, "__administratorio__/graphics/icons/safety-work-order.png"),
    "splitter-regulated should not overlay paperwork icon by default")
end)

test("bulk in-place regulated recipe icons show amount overlay", function()
  local regulated = get_recipe("electric-furnace")
  assert_true(regulated ~= nil, "electric-furnace missing")
  assert_true(regulated.icons ~= nil, "electric-furnace should use layered icons")
  assert_true(has_icon_layer(regulated, "__base__/graphics/icons/signal/signal_5.png"),
    "electric-furnace should overlay the 5x amount")
  assert_true(not has_icon_layer(regulated, "__administratorio__/graphics/icons/management-verbal-work-order.png"),
    "electric-furnace should not overlay paperwork icon by default")
end)

test("work-order bulk recipe icons show amount without paperwork icon", function()
  local regulated = get_recipe("transport-belt-regulated")
  assert_true(regulated ~= nil, "transport-belt-regulated missing")
  assert_true(regulated.icons ~= nil, "transport-belt-regulated should use layered icons")
  assert_true(not has_icon_layer(regulated, "__administratorio__/graphics/icons/work-order.png"),
    "transport-belt-regulated should not overlay work-order icon")
  assert_true(has_icon_layer(regulated, "__base__/graphics/icons/signal/signal_1.png"),
    "transport-belt-regulated should overlay the 10x amount")
  assert_true(has_icon_layer(regulated, "__base__/graphics/icons/signal/signal_0.png"),
    "transport-belt-regulated should overlay the 10x amount")
end)

test("1x regulated recipes do not show amount digits", function()
  local regulated = get_recipe("nuclear-reactor")
  assert_true(regulated ~= nil, "nuclear-reactor missing")
  assert_true(regulated.icons ~= nil, "nuclear-reactor should use layered icons")
  assert_true(not has_icon_layer(regulated, "__base__/graphics/icons/signal/signal_1.png"),
    "nuclear-reactor should not overlay a 1x amount digit")
  assert_true(not has_icon_layer(regulated, "__administratorio__/graphics/icons/management-written-work-order.png"),
    "nuclear-reactor should not overlay paperwork icon by default")
end)

test("operating-paperwork recipes batch refinery chemistry and centrifuging families", function()
  local oil = get_recipe("oil-processing")
  assert_true(oil ~= nil, "oil-processing missing")
  assert_true(has_ingredient(oil, "petrochemical-operating-permit"), "oil-processing missing petrochemical-operating-permit")
  assert_eq(get_ingredient_amount(oil, "crude-oil"), 500, "oil-processing should batch crude oil at 5x")
  assert_eq(get_result_amount(oil, "heavy-oil"), 150, "oil-processing should batch heavy oil at 5x")
  assert_eq(get_result_amount(oil, "light-oil"), 150, "oil-processing should batch light oil at 5x")
  assert_eq(get_result_amount(oil, "petroleum-gas"), 200, "oil-processing should batch petroleum gas at 5x")

  local advanced_oil = get_recipe("advanced-oil-processing")
  assert_true(advanced_oil ~= nil, "advanced-oil-processing missing")
  assert_true(has_ingredient(advanced_oil, "chemical-handling-work-order"), "advanced-oil-processing missing chemical-handling-work-order")
  assert_true(not has_ingredient(advanced_oil, "petrochemical-operating-permit"), "advanced-oil-processing should not use the basic petro permit")
  assert_eq(get_ingredient_amount(advanced_oil, "crude-oil"), 500, "advanced-oil-processing should batch crude oil at 5x")
  assert_eq(get_ingredient_amount(advanced_oil, "water"), 250, "advanced-oil-processing should batch water at 5x")
  assert_eq(get_result_amount(advanced_oil, "petroleum-gas"), 275, "advanced-oil-processing should batch petroleum gas at 5x")

  local coal_liq = get_recipe("coal-liquefaction")
  assert_true(coal_liq ~= nil, "coal-liquefaction missing")
  assert_true(has_ingredient(coal_liq, "chemical-handling-work-order"), "coal-liquefaction missing chemical-handling-work-order")
  assert_true(not has_ingredient(coal_liq, "petrochemical-operating-permit"), "coal-liquefaction should not use the basic petro permit")
  assert_eq(get_ingredient_amount(coal_liq, "coal"), 50, "coal-liquefaction should batch coal at 5x")
  assert_eq(get_ingredient_amount(coal_liq, "steam"), 250, "coal-liquefaction should batch steam at 5x")
  assert_eq(get_result_amount(coal_liq, "heavy-oil"), 450, "coal-liquefaction should batch heavy oil at 5x")

  local plastic = get_recipe("plastic-bar")
  assert_true(plastic ~= nil, "plastic-bar missing")
  assert_true(has_ingredient(plastic, "petrochemical-operating-permit"), "plastic-bar missing petrochemical-operating-permit")
  assert_true(not has_ingredient(plastic, "chemical-handling-work-order"), "plastic-bar should stay on the basic petro permit")
  assert_eq(get_ingredient_amount(plastic, "petroleum-gas"), 200, "plastic-bar should batch petroleum gas at 10x")
  assert_eq(get_result_amount(plastic, "plastic-bar"), 20, "plastic-bar should batch output at 10x")

  local sulfur = get_recipe("sulfur")
  assert_true(sulfur ~= nil, "sulfur missing")
  assert_true(has_ingredient(sulfur, "petrochemical-operating-permit"), "sulfur missing petrochemical-operating-permit")
  assert_true(not has_ingredient(sulfur, "chemical-handling-work-order"), "sulfur should stay on the basic petro permit")
  assert_eq(get_ingredient_amount(sulfur, "petroleum-gas"), 300, "sulfur should batch petroleum gas at 10x")
  assert_eq(get_result_amount(sulfur, "sulfur"), 20, "sulfur should batch output at 10x")

  local sulfuric_acid = get_recipe("sulfuric-acid")
  assert_true(sulfuric_acid ~= nil, "sulfuric-acid missing")
  assert_true(has_ingredient(sulfuric_acid, "petrochemical-operating-permit"), "sulfuric-acid missing petrochemical-operating-permit")
  assert_true(not has_ingredient(sulfuric_acid, "chemical-handling-work-order"), "sulfuric-acid should stay on the basic petro permit")
  assert_eq(get_ingredient_amount(sulfuric_acid, "water"), 500, "sulfuric-acid should batch water at 5x")
  assert_eq(get_result_amount(sulfuric_acid, "sulfuric-acid"), 250, "sulfuric-acid should batch output at 5x")

  local solid_fuel_light = get_recipe("solid-fuel-from-light-oil")
  assert_true(solid_fuel_light ~= nil, "solid-fuel-from-light-oil missing")
  assert_true(has_ingredient(solid_fuel_light, "petrochemical-operating-permit"), "solid-fuel-from-light-oil missing petrochemical-operating-permit")
  assert_true(not has_ingredient(solid_fuel_light, "chemical-handling-work-order"), "solid-fuel-from-light-oil should stay on the basic petro permit")
  assert_eq(get_ingredient_amount(solid_fuel_light, "light-oil"), 50, "solid-fuel-from-light-oil should batch light oil at 5x")
  assert_eq(get_result_amount(solid_fuel_light, "solid-fuel"), 5, "solid-fuel-from-light-oil should batch output at 5x")

  local solid_fuel_heavy = get_recipe("solid-fuel-from-heavy-oil")
  assert_true(solid_fuel_heavy ~= nil, "solid-fuel-from-heavy-oil missing")
  assert_true(has_ingredient(solid_fuel_heavy, "petrochemical-operating-permit"), "solid-fuel-from-heavy-oil missing petrochemical-operating-permit")
  assert_true(not has_ingredient(solid_fuel_heavy, "chemical-handling-work-order"), "solid-fuel-from-heavy-oil should stay on the basic petro permit")
  assert_eq(get_ingredient_amount(solid_fuel_heavy, "heavy-oil"), 100, "solid-fuel-from-heavy-oil should batch heavy oil at 5x")

  local solid_fuel_gas = get_recipe("solid-fuel-from-petroleum-gas")
  assert_true(solid_fuel_gas ~= nil, "solid-fuel-from-petroleum-gas missing")
  assert_true(has_ingredient(solid_fuel_gas, "petrochemical-operating-permit"), "solid-fuel-from-petroleum-gas missing petrochemical-operating-permit")
  assert_true(not has_ingredient(solid_fuel_gas, "chemical-handling-work-order"), "solid-fuel-from-petroleum-gas should stay on the basic petro permit")
  assert_eq(get_ingredient_amount(solid_fuel_gas, "petroleum-gas"), 100, "solid-fuel-from-petroleum-gas should batch petroleum gas at 5x")

  local uranium = get_recipe("uranium-processing")
  assert_true(uranium ~= nil, "uranium-processing missing")
  assert_true(has_ingredient(uranium, "radiological-work-order"), "uranium-processing missing radiological-work-order")
  assert_eq(get_ingredient_amount(uranium, "uranium-ore"), 50, "uranium-processing should batch uranium ore at 5x")
  assert_eq(get_result_amount(uranium, "uranium-235"), 5, "uranium-processing should batch uranium-235 at 5x")
  assert_eq(get_result_amount(uranium, "uranium-238"), 5, "uranium-processing should batch uranium-238 at 5x")
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
  assert_true(type(regulated.localised_name) == "table", "transport-belt-regulated missing localised_name")
  assert_eq(regulated.localised_name[1], "entity-name.transport-belt", "transport-belt-regulated should localise from place_result")
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

test("admin building regulated recipes batch and show overlays", function()
  local printer = get_recipe("printer-t1-regulated")
  assert_true(printer ~= nil, "printer-t1-regulated missing")
  assert_eq(get_ingredient_amount(printer, "provisional-approval"), 5, "printer-t1-regulated should batch its paperwork ingredient")
  assert_eq(get_result_amount(printer, "printer-t1"), 5, "printer-t1-regulated should batch to 5")
  assert_true(has_icon_layer(printer, "__base__/graphics/icons/signal/signal_5.png"),
    "printer-t1-regulated should show the 5x overlay")

  local pipe = get_recipe("pneumatic-pipe-regulated")
  assert_true(pipe ~= nil, "pneumatic-pipe-regulated missing")
  assert_eq(get_result_amount(pipe, "pneumatic-pipe"), 20, "pneumatic-pipe-regulated should batch to 20")
  assert_true(has_icon_layer(pipe, "__base__/graphics/icons/signal/signal_1.png"),
    "pneumatic-pipe-regulated should show the 10x overlay")
  assert_true(has_icon_layer(pipe, "__base__/graphics/icons/signal/signal_0.png"),
    "pneumatic-pipe-regulated should show the 10x overlay")

  local liquifier = get_recipe("form-liquifier-regulated")
  assert_true(liquifier ~= nil, "form-liquifier-regulated missing")
  assert_eq(get_result_amount(liquifier, "form-liquifier"), 10, "form-liquifier-regulated should batch to 10")
  assert_true(has_icon_layer(liquifier, "__base__/graphics/icons/signal/signal_1.png"),
    "form-liquifier-regulated should show the 10x overlay")
  assert_true(has_icon_layer(liquifier, "__base__/graphics/icons/signal/signal_0.png"),
    "form-liquifier-regulated should show the 10x overlay")
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
