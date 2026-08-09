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
      ["assembling-machine-2"] = { name = "assembling-machine-2", type = "assembling-machine", crafting_categories = {"crafting", "advanced-crafting", "crafting-with-fluid"} },
      ["assembling-machine-3"] = { name = "assembling-machine-3", type = "assembling-machine", crafting_categories = {"crafting", "advanced-crafting", "crafting-with-fluid"} },
    },
    furnace = {
      ["stone-furnace"] = { name = "stone-furnace", type = "furnace", energy_source = {type = "burner", fuel_category = "chemical"} },
      ["steel-furnace"] = { name = "steel-furnace", type = "furnace", energy_source = {type = "burner"} },
    },
    boiler = {
      ["boiler"] = { name = "boiler", type = "boiler", energy_source = {type = "burner", fuel_categories = {"chemical"}} },
    },
    car = {
      ["car"] = { name = "car", type = "car", energy_source = {type = "burner", fuel_categories = {"chemical"}} },
      ["rideable-biter"] = {
        name = "rideable-biter",
        type = "car",
        energy_source = {type = "burner", fuel_categories = {"administratorio-taxpayer-money"}, fuel_inventory_size = 1},
        working_sound = {},
      },
    },
    reactor = {
      ["nuclear-reactor"] = { name = "nuclear-reactor", type = "reactor", energy_source = {type = "burner", fuel_category = "nuclear"} },
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
data.raw.item["coal"] = {
  type = "item",
  name = "coal",
  stack_size = 50,
  icon = "__base__/graphics/icons/coal.png",
  icon_size = 64,
}
data.raw.item["wood"] = {
  type = "item",
  name = "wood",
  stack_size = 100,
  icon = "__base__/graphics/icons/wood.png",
  icon_size = 64,
}
data.raw.item["electric-furnace"] = {
  type = "item",
  name = "electric-furnace",
  stack_size = 50,
  icon = "__base__/graphics/icons/electric-furnace.png",
  icon_size = 64,
}
data.raw.item["oil-refinery"] = {
  type = "item",
  name = "oil-refinery",
  stack_size = 10,
  place_result = "oil-refinery",
  icon = "__base__/graphics/icons/oil-refinery.png",
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
data.raw.item["lane-splitter"] = {
  type = "item",
  name = "lane-splitter",
  stack_size = 50,
  icon = "__lane-splitters__/graphics/icons/lane-splitter.png",
  icon_size = 64,
}
data.raw.item["boiler"] = {
  type = "item",
  name = "boiler",
  stack_size = 50,
  icon = "__base__/graphics/icons/boiler.png",
  icon_size = 64,
}
data.raw.item["steam-engine"] = {
  type = "item",
  name = "steam-engine",
  stack_size = 10,
  icon = "__base__/graphics/icons/steam-engine.png",
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
data.raw.item["engine-unit"] = {
  type = "item",
  name = "engine-unit",
  stack_size = 50,
  icon = "__base__/graphics/icons/engine-unit.png",
  icon_size = 64,
}
data.raw.item["electric-engine-unit"] = {
  type = "item",
  name = "electric-engine-unit",
  stack_size = 50,
  icon = "__base__/graphics/icons/electric-engine-unit.png",
  icon_size = 64,
}
data.raw.item["battery"] = {
  type = "item",
  name = "battery",
  stack_size = 200,
  icon = "__base__/graphics/icons/battery.png",
  icon_size = 64,
}
data.raw.item["rocket-fuel"] = {
  type = "item",
  name = "rocket-fuel",
  stack_size = 10,
  icon = "__base__/graphics/icons/rocket-fuel.png",
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

recipes["oil-refinery"] = {
  type = "recipe",
  name = "oil-refinery",
  category = "crafting",
  enabled = false,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 15 },
    { type = "item", name = "iron-gear-wheel", amount = 10 },
    { type = "item", name = "electronic-circuit", amount = 10 },
    { type = "item", name = "pipe", amount = 10 },
  },
  results = {
    { type = "item", name = "oil-refinery", amount = 1 },
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

recipes["lane-splitter"] = {
  type = "recipe",
  name = "lane-splitter",
  enabled = false,
  energy_required = 1,
  ingredients = recipes["splitter"].ingredients,
  results = {
    { type = "item", name = "lane-splitter", amount = 1 },
  },
}

recipes["boiler"] = {
  type = "recipe",
  name = "boiler",
  enabled = true,
  ingredients = {
    { type = "item", name = "stone-furnace", amount = 1 },
    { type = "item", name = "pipe", amount = 4 },
  },
  results = {
    { type = "item", name = "boiler", amount = 1 },
  },
}

recipes["steam-engine"] = {
  type = "recipe",
  name = "steam-engine",
  enabled = true,
  ingredients = {
    { type = "item", name = "iron-gear-wheel", amount = 8 },
    { type = "item", name = "pipe", amount = 5 },
    { type = "item", name = "iron-plate", amount = 10 },
  },
  results = {
    { type = "item", name = "steam-engine", amount = 1 },
  },
}

recipes["engine-unit"] = {
  type = "recipe",
  name = "engine-unit",
  category = "crafting",
  enabled = false,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 1 },
    { type = "item", name = "iron-gear-wheel", amount = 1 },
    { type = "item", name = "pipe", amount = 2 },
  },
  results = {
    { type = "item", name = "engine-unit", amount = 1 },
  },
}

recipes["electric-engine-unit"] = {
  type = "recipe",
  name = "electric-engine-unit",
  category = "crafting-with-fluid",
  enabled = false,
  ingredients = {
    { type = "item", name = "engine-unit", amount = 1 },
    { type = "item", name = "electronic-circuit", amount = 2 },
    { type = "fluid", name = "lubricant", amount = 15 },
  },
  results = {
    { type = "item", name = "electric-engine-unit", amount = 1 },
  },
}

recipes["battery"] = {
  type = "recipe",
  name = "battery",
  category = "chemistry",
  enabled = false,
  ingredients = {
    { type = "item", name = "iron-plate", amount = 1 },
    { type = "item", name = "copper-plate", amount = 1 },
    { type = "fluid", name = "sulfuric-acid", amount = 20 },
  },
  results = {
    { type = "item", name = "battery", amount = 1 },
  },
}

recipes["rocket-fuel"] = {
  type = "recipe",
  name = "rocket-fuel",
  category = "chemistry",
  enabled = false,
  ingredients = {
    { type = "item", name = "solid-fuel", amount = 10 },
    { type = "fluid", name = "light-oil", amount = 10 },
  },
  results = {
    { type = "item", name = "rocket-fuel", amount = 1 },
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

technologies["oil-processing"] = {
  type = "technology",
  name = "oil-processing",
  effects = {
    { type = "unlock-recipe", recipe = "oil-refinery" },
  },
  research_trigger = { type = "mine-entity", entity = "crude-oil" },
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
    { type = "unlock-recipe", recipe = "lane-splitter" },
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
local shared = require("prototypes.shared")
local factoriopedia_merge = require("prototypes.factoriopedia_merge")
local generated_recipe_renames = {}
local apply_recipe_renames = factoriopedia_merge.apply_recipe_renames
factoriopedia_merge.apply_recipe_renames = function(data_raw, shared_constants, rename_map)
  generated_recipe_renames = util.table.deepcopy(rename_map or {})
  return apply_recipe_renames(data_raw, shared_constants, rename_map)
end
-- Regression guard: explicit equipment overrides must be ignored by final-fixes.
shared.BATCH_MULTIPLIERS["battery-equipment"] = 99

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

local function count_ingredient(recipe, item_name)
  if not recipe or not recipe.ingredients then return 0 end
  local count = 0
  for _, ing in ipairs(recipe.ingredients) do
    if (ing.name or ing[1]) == item_name then
      count = count + 1
    end
  end
  return count
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

local function energy_source_accepts(energy_source, fuel_category)
  if not energy_source then return false end
  if energy_source.fuel_category == fuel_category then return true end
  for _, category in ipairs(energy_source.fuel_categories or {}) do
    if category == fuel_category then
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
  assert_true(has_ingredient(r, "provisional-work-order"), "printer-t1-regulated missing provisional-work-order")
  assert_true(not has_ingredient(r, "provisional-approval"), "printer-t1-regulated should combine provisional-approval")
end)

test("regulated admin building outputs follow their declared batch economics", function()
  for building_name in pairs(shared.ADMIN_BUILDINGS) do
    local base = get_recipe(building_name)
    if base then
      local regulated = get_recipe(building_name .. "-regulated")
      assert_true(regulated ~= nil, building_name .. " should have a regulated assembler recipe")

      local base_amount = get_result_amount(base, building_name)
      if base_amount then
        local multiplier = shared.BATCH_MULTIPLIERS[building_name]
          or shared.BATCH_MULTIPLIER_DEFAULT
        assert_eq(
          get_result_amount(regulated, building_name),
          base_amount * multiplier,
          building_name .. " regulated output should match its batch multiplier"
        )
      end
    end
  end
end)

test("printer-t2 gets a regulated AM recipe", function()
  local r = get_recipe("printer-t2-regulated")
  assert_true(r ~= nil, "printer-t2-regulated missing")
  assert_eq(r.category, "crafting-regulated", "printer-t2 regulated category")
  assert_true(has_ingredient(r, "construction-work-order"), "printer-t2-regulated missing construction-work-order")
  assert_true(has_ingredient(r, "printer-t1"), "printer-t2-regulated missing printer-t1")
  assert_true(not has_ingredient(r, "construction-permit"), "printer-t2-regulated should combine construction-permit")
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

test("repair-pack gets a bulked regulated AM recipe", function()
  local regulated = get_recipe("repair-pack-regulated")
  assert_true(regulated ~= nil, "repair-pack-regulated missing")
  assert_eq(regulated.category, "crafting-regulated", "repair-pack-regulated category")
  assert_true(has_ingredient(regulated, "work-order"), "repair-pack-regulated missing work-order")
  assert_eq(get_result_amount(regulated, "repair-pack"), 5, "repair-pack-regulated should batch to 5")
  assert_true(has_icon_layer(regulated, "__base__/graphics/icons/signal/signal_5.png"),
    "repair-pack-regulated should show the 5x overlay")
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

test("electric compacted rubble remains an unlocked alternate to the canonical batch recipe", function()
  local canonical = get_recipe("compacted-rubble")
  assert_true(canonical ~= nil, "canonical compacted-rubble recipe missing")
  assert_eq(canonical.category, "smelting-basic", "canonical compacted rubble should remain the certified batch")
  assert_true(has_ingredient(canonical, "carbon-offset-certificate-basic"),
    "canonical compacted rubble should require a carbon certificate")

  local electric = get_recipe("compacted-rubble-electric")
  assert_true(electric ~= nil, "electric compacted-rubble recipe missing")
  assert_eq(electric.category, "smelting", "electric compacted rubble should use vanilla smelting")
  assert_true(not has_ingredient(electric, "carbon-offset-certificate-basic"),
    "electric compacted rubble should not require a carbon certificate")
  assert_eq(electric.factoriopedia_alternative, "compacted-rubble")
end)

test("electric furnace recipe upgrades to management verbal paperwork", function()
  local r = get_recipe("electric-furnace")
  assert_true(r ~= nil, "electric-furnace missing")
  assert_eq(r.category, "advanced-crafting-regulated", "electric-furnace category")
  assert_true(has_ingredient(r, "management-verbal-work-order"), "electric-furnace missing management-verbal-work-order")
  assert_true(not has_ingredient(r, "construction-work-order"), "electric-furnace should not use construction-work-order")
end)

test("oil refinery is assembler-craftable without specialist or operating paperwork", function()
  local r = get_recipe("oil-refinery")
  assert_true(r ~= nil, "oil-refinery missing")
  assert_eq(r.category, "crafting-regulated", "oil-refinery category")
  assert_true(has_ingredient(r, "construction-work-order"), "oil-refinery missing construction-work-order")
  assert_true(not has_ingredient(r, "chemical-operator"), "oil-refinery should not require chemical-operator")
  assert_true(not has_ingredient(r, "chemical-handling-work-order"), "oil-refinery should not require chemical-handling-work-order")
  assert_true(get_recipe("oil-refinery-regulated") == nil, "oil-refinery should use its canonical recipe as the regulated assembler recipe")
end)

test("engine units use baseline paperwork plus carbon offsets", function()
  local r = get_recipe("engine-unit")
  assert_true(r ~= nil, "engine-unit missing")
  assert_eq(r.category, "crafting-regulated", "engine-unit category")
  assert_true(has_ingredient(r, "work-order"), "engine-unit missing work-order")
  assert_true(has_ingredient(r, "carbon-offset-certificate-basic"), "engine-unit missing carbon-offset-certificate-basic")
  assert_true(not has_ingredient(r, "management-verbal-work-order"), "engine-unit should not use management-verbal-work-order")
end)

test("regulated advanced assembler path stays available to both AM2 and AM3", function()
  local am2 = data.raw["assembling-machine"]["assembling-machine-2"]
  local am3 = data.raw["assembling-machine"]["assembling-machine-3"]

  assert_true(am2 ~= nil, "assembling-machine-2 missing")
  assert_true(am3 ~= nil, "assembling-machine-3 missing")
  assert_eq(am2.crafting_categories[1], "crafting-regulated", "AM2 primary regulated category")
  assert_eq(am2.crafting_categories[2], "advanced-crafting-regulated", "AM2 advanced regulated category")
  assert_eq(am3.crafting_categories[1], "crafting-regulated", "AM3 primary regulated category")
  assert_eq(am3.crafting_categories[2], "advanced-crafting-regulated", "AM3 advanced regulated category")
end)

test("high-energy intermediates require verified carbon certificates", function()
  local electric_engine = get_recipe("electric-engine-unit")
  assert_true(electric_engine ~= nil, "electric-engine-unit missing")
  assert_eq(electric_engine.category, "advanced-crafting-regulated", "electric-engine-unit should be reassigned to the regulated fluid-capable AM2/AM3 path")
  assert_true(has_ingredient(electric_engine, "carbon-offset-certificate-verified"), "electric-engine-unit missing verified carbon certificate")

  local battery = get_recipe("battery")
  assert_true(battery ~= nil, "battery missing")
  assert_true(has_ingredient(battery, "carbon-offset-certificate-verified"), "battery missing verified carbon certificate")

  local rocket_fuel = get_recipe("rocket-fuel")
  assert_true(rocket_fuel ~= nil, "rocket-fuel missing")
  assert_true(has_ingredient(rocket_fuel, "carbon-offset-certificate-verified"), "rocket-fuel missing verified carbon certificate")
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

test("lane-splitters shared ingredient tables do not duplicate splitter paperwork", function()
  local splitter = get_recipe("splitter")
  local lane_splitter = get_recipe("lane-splitter")
  local lane_splitter_regulated = get_recipe("lane-splitter-regulated")

  assert_true(splitter ~= nil, "splitter missing")
  assert_true(lane_splitter ~= nil, "lane-splitter missing")
  assert_true(lane_splitter_regulated ~= nil, "lane-splitter-regulated missing")

  assert_true(splitter.ingredients ~= lane_splitter.ingredients,
    "splitter and lane-splitter should not keep sharing ingredient tables after regulation")
  assert_eq(count_ingredient(splitter, "safety-waiver"), 1, "splitter should have one safety-waiver")
  assert_eq(count_ingredient(lane_splitter, "safety-waiver"), 1, "lane-splitter should have one safety-waiver")
  assert_eq(get_ingredient_amount(splitter, "electronic-circuit"), 5, "splitter should only be batched once")
  assert_eq(get_ingredient_amount(lane_splitter, "electronic-circuit"), 5, "lane-splitter should only be batched once")
  assert_true(has_ingredient(lane_splitter_regulated, "safety-work-order"),
    "lane-splitter-regulated should require safety-work-order")
end)

test("boiler and steam-engine use safety paperwork in 2x batches", function()
  local boiler = get_recipe("boiler")
  local boiler_regulated = get_recipe("boiler-regulated")
  local steam_engine = get_recipe("steam-engine")
  local steam_engine_regulated = get_recipe("steam-engine-regulated")

  assert_true(boiler ~= nil, "boiler missing")
  assert_true(boiler_regulated ~= nil, "boiler-regulated missing")
  assert_true(steam_engine ~= nil, "steam-engine missing")
  assert_true(steam_engine_regulated ~= nil, "steam-engine-regulated missing")

  assert_true(has_ingredient(boiler, "safety-waiver"), "boiler should require safety-waiver when handcrafted")
  assert_true(has_ingredient(boiler_regulated, "safety-work-order"), "boiler-regulated should require safety-work-order")
  assert_eq(get_result_amount(boiler, "boiler"), 2, "boiler should batch handcraft results at 2x")
  assert_eq(get_result_amount(boiler_regulated, "boiler"), 2, "boiler-regulated should produce 2 boilers")

  assert_true(has_ingredient(steam_engine, "safety-waiver"), "steam-engine should require safety-waiver when handcrafted")
  assert_true(has_ingredient(steam_engine_regulated, "safety-work-order"), "steam-engine-regulated should require safety-work-order")
  assert_eq(get_result_amount(steam_engine, "steam-engine"), 2, "steam-engine should batch handcraft results at 2x")
  assert_eq(get_result_amount(steam_engine_regulated, "steam-engine"), 2, "steam-engine-regulated should produce 2 steam engines")
end)

test("taxpayer money is accepted by regular burners", function()
  local taxpayer_money_category = "administratorio-taxpayer-money"

  assert_true(energy_source_accepts(data.raw.furnace["stone-furnace"].energy_source, taxpayer_money_category),
    "stone furnace should accept taxpayer money")
  assert_true(energy_source_accepts(data.raw.furnace["steel-furnace"].energy_source, taxpayer_money_category),
    "steel furnace should accept taxpayer money when chemical fuel is implicit")
  assert_true(energy_source_accepts(data.raw.boiler["boiler"].energy_source, taxpayer_money_category),
    "boiler should accept taxpayer money")
  assert_true(energy_source_accepts(data.raw.car["car"].energy_source, taxpayer_money_category),
    "regular car should accept taxpayer money")

  assert_true(energy_source_accepts(data.raw.furnace["stone-furnace"].energy_source, "chemical"),
    "stone furnace should still accept chemical fuel")
  assert_true(not energy_source_accepts(data.raw.reactor["nuclear-reactor"].energy_source, taxpayer_money_category),
    "nuclear reactor should keep its non-chemical fuel restriction")
end)

test("rideable biter accepts only taxpayer money fuel", function()
  local rideable_source = data.raw.car["rideable-biter"].energy_source

  assert_true(energy_source_accepts(rideable_source, "administratorio-taxpayer-money"),
    "rideable biter should accept taxpayer money")
  assert_true(not energy_source_accepts(rideable_source, "chemical"),
    "rideable biter should not accept ordinary chemical fuel")
  assert_eq(rideable_source.fuel_inventory_size, 1, "rideable biter should keep one fuel slot")
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
  assert_true(tech_unlocks_recipe("pneumatic-form-transport", "tube-intake"), "pneumatic-form-transport missing tube-intake unlock")
  assert_true(not tech_unlocks_recipe("pneumatic-form-transport", "tube-intake-regulated"), "pneumatic-form-transport should not list tube-intake-regulated")
  assert_true(tech_unlocks_recipe("pneumatic-form-transport", "tube-outtake"), "pneumatic-form-transport missing tube-outtake unlock")
  assert_true(not tech_unlocks_recipe("pneumatic-form-transport", "tube-outtake-regulated"), "pneumatic-form-transport should not list tube-outtake-regulated")
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

test("Factoriopedia recipe renames have prototype migrations", function()
  local migration_path = mod_root .. "migrations/0.5.12-factoriopedia-recipe-renames.json"
  local migration_file = assert(io.open(migration_path, "r"))
  local migration_text = migration_file:read("*a")
  migration_file:close()

  local migrated_recipe_renames = {}
  for old_name, new_name in migration_text:gmatch('%[%s*"([^"]+)"%s*,%s*"([^"]+)"%s*%]') do
    assert_true(migrated_recipe_renames[old_name] == nil, "duplicate recipe migration for " .. old_name)
    migrated_recipe_renames[old_name] = new_name
  end

  local generated_count = 0
  for old_name, new_name in pairs(generated_recipe_renames) do
    generated_count = generated_count + 1
    assert_eq(
      migrated_recipe_renames[old_name],
      new_name,
      old_name .. " should migrate to its generated canonical recipe name"
    )
  end

  local migrated_count = 0
  for old_name, new_name in pairs(migrated_recipe_renames) do
    migrated_count = migrated_count + 1
    assert_eq(
      generated_recipe_renames[old_name],
      new_name,
      old_name .. " migration should correspond to a generated recipe rename"
    )
  end

  assert_eq(migrated_count, generated_count, "recipe migration count should match generated rename count")
  assert_eq(migrated_recipe_renames["charcoal-production"], "coal", "coal recipe rename must be migrated")
end)

test("all recipe ingredient lists are duplicate-free", function()
  local function assert_unique(target, label)
    if not target or not target.ingredients then return end

    local seen = {}
    for _, ing in ipairs(target.ingredients) do
      local name = ing.name or ing[1]
      local key = (ing.type or "item") .. ":" .. tostring(name)
      assert_true(not seen[key], label .. " has duplicate ingredient " .. key)
      seen[key] = true
    end
  end

  for name, recipe in pairs(recipes) do
    assert_unique(recipe, name)
    assert_unique(recipe.normal, name .. ".normal")
    assert_unique(recipe.expensive, name .. ".expensive")
  end
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
