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
    ["ammo-turret"] = {},
    gun = {},
    armor = {},
    ["selection-tool"] = {},
    ["item-with-entity-data"] = {},
    ["rail-planner"] = {},
    ["spidertron-remote"] = {},
    ["space-platform-starter-pack"] = {},
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

mods = {
  ["space-age"] = "2.0.0",
}

data.raw.ammo["middle-management-managing-manager"] = {
  type = "ammo",
  name = "middle-management-managing-manager",
  ammo_category = "orbital-biter-ballistics",
}
data.raw.ammo["orbital-deviation-order"] = {
  type = "ammo",
  name = "orbital-deviation-order",
  ammo_category = "trajectory-compliance",
}
data.raw.ammo["firearm-magazine"] = {
  type = "ammo",
  name = "firearm-magazine",
  ammo_category = "bullet",
}
data.raw["ammo-turret"]["trajectory-compliance-array"] = {
  type = "ammo-turret",
  name = "trajectory-compliance-array",
}
data.raw["ammo-turret"]["senior-trajectory-compliance-array"] = {
  type = "ammo-turret",
  name = "senior-trajectory-compliance-array",
}
data.raw["ammo-turret"]["executive-trajectory-compliance-array"] = {
  type = "ammo-turret",
  name = "executive-trajectory-compliance-array",
}
data.raw["ammo-turret"]["orbital-employment-cannon"] = {
  type = "ammo-turret",
  name = "orbital-employment-cannon",
}
data.raw["ammo-turret"]["gun-turret"] = {
  type = "ammo-turret",
  name = "gun-turret",
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
data.raw.item["rocket-silo"] = {
  type = "item",
  name = "rocket-silo",
  stack_size = 1,
  icon = "__base__/graphics/icons/rocket-silo.png",
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
data.raw.item["cargo-bay"] = {
  type = "item",
  name = "cargo-bay",
  stack_size = 10,
  subgroup = "space-platform",
  place_result = "cargo-bay",
  icon = "__space-age__/graphics/icons/cargo-bay.png",
  icon_size = 64,
}
data.raw.item["asteroid-collector"] = {
  type = "item",
  name = "asteroid-collector",
  stack_size = 10,
  subgroup = "space-platform",
  place_result = "asteroid-collector",
  icon = "__space-age__/graphics/icons/asteroid-collector.png",
  icon_size = 64,
}
data.raw.item["space-platform-foundation"] = {
  type = "item",
  name = "space-platform-foundation",
  stack_size = 100,
  subgroup = "space-platform",
  icon = "__space-age__/graphics/icons/space-platform-foundation.png",
  icon_size = 64,
}
data.raw.item["fusion-reactor"] = {
  type = "item",
  name = "fusion-reactor",
  stack_size = 10,
  subgroup = "energy",
  place_result = "fusion-reactor",
  icon = "__space-age__/graphics/icons/fusion-reactor.png",
  icon_size = 64,
}
data.raw.item["fusion-generator"] = {
  type = "item",
  name = "fusion-generator",
  stack_size = 10,
  subgroup = "energy",
  place_result = "fusion-generator",
  icon = "__space-age__/graphics/icons/fusion-generator.png",
  icon_size = 64,
}
data.raw.item["pentapod-egg"] = {
  type = "item",
  name = "pentapod-egg",
  spoil_to_trigger_result = {
    trigger = {
      type = "direct",
      action_delivery = {
        type = "instant",
        source_effects = {
          {type = "create-entity", entity_name = "small-pentapod-premature"},
        },
      },
    },
  },
}
data.raw.armor["mech-armor"] = {
  type = "armor",
  name = "mech-armor",
  stack_size = 1,
  icon = "__space-age__/graphics/icons/mech-armor.png",
  icon_size = 64,
}
data.raw.tool["promethium-science-pack"] = {
  type = "tool",
  name = "promethium-science-pack",
  stack_size = 200,
  icon = "__space-age__/graphics/icons/promethium-science-pack.png",
  icon_size = 64,
}
data.raw.item["heating-tower"] = {
  type = "item",
  name = "heating-tower",
  stack_size = 20,
  subgroup = "environmental-protection",
  place_result = "heating-tower",
  icon = "__space-age__/graphics/icons/heating-tower.png",
  icon_size = 64,
}
data.raw.item["chromatic-printer"] = {
  type = "item",
  name = "chromatic-printer",
  stack_size = 50,
  subgroup = "admin-printers",
  place_result = "chromatic-printer",
  icon = "__administratorio__/graphics/icons/steel-forge-icon.png",
  icon_size = 64,
}
data.raw["space-platform-starter-pack"]["space-platform-starter-pack"] = {
  type = "space-platform-starter-pack",
  name = "space-platform-starter-pack",
  stack_size = 1,
  subgroup = "space-rocket",
  icon = "__space-age__/graphics/icons/space-platform-starter-pack.png",
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

recipes["rocket-silo"] = {
  type = "recipe",
  name = "rocket-silo",
  category = "advanced-crafting",
  enabled = false,
  ingredients = {
    { type = "item", name = "concrete", amount = 1000 },
    { type = "item", name = "steel-plate", amount = 1000 },
    { type = "item", name = "processing-unit", amount = 200 },
    { type = "item", name = "electric-engine-unit", amount = 200 },
  },
  results = {
    { type = "item", name = "rocket-silo", amount = 1 },
  },
  surface_conditions = {
    { property = "pressure", min = 1000, max = 1000 },
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

recipes["electromagnetic-plant"] = {
  type = "recipe",
  name = "electromagnetic-plant",
  category = "electronics-or-assembling",
  enabled = false,
  ingredients = {
    { type = "item", name = "holmium-plate", amount = 10 },
  },
  results = {
    { type = "item", name = "electromagnetic-plant", amount = 1 },
  },
}

recipes["dual-planet-widget"] = {
  type = "recipe",
  name = "dual-planet-widget",
  category = "advanced-crafting",
  enabled = false,
  ingredients = {
    { type = "item", name = "tungsten-plate", amount = 2 },
    { type = "item", name = "carbon-fiber", amount = 2 },
  },
  results = {
    { type = "item", name = "dual-planet-widget", amount = 1 },
  },
}

recipes["quantum-processor"] = {
  type = "recipe",
  name = "quantum-processor",
  category = "advanced-crafting",
  enabled = false,
  ingredients = {
    { type = "item", name = "tungsten-plate", amount = 2 },
    { type = "item", name = "carbon-fiber", amount = 2 },
    { type = "item", name = "holmium-plate", amount = 2 },
  },
  results = {
    { type = "item", name = "quantum-processor", amount = 1 },
  },
}

recipes["lithium"] = {
  type = "recipe",
  name = "lithium",
  category = "cryogenics",
  enabled = false,
  ingredients = {
    { type = "fluid", name = "lithium-brine", amount = 50 },
    { type = "fluid", name = "ammonia", amount = 50 },
  },
  results = {
    { type = "item", name = "lithium", amount = 5 },
  },
}

recipes["lithium-plate"] = {
  type = "recipe",
  name = "lithium-plate",
  category = "smelting",
  enabled = false,
  ingredients = {
    { type = "item", name = "lithium", amount = 1 },
  },
  results = {
    { type = "item", name = "lithium-plate", amount = 1 },
  },
}

recipes["fluoroketone"] = {
  type = "recipe",
  name = "fluoroketone",
  category = "cryogenics",
  enabled = false,
  ingredients = {
    { type = "fluid", name = "ammonia", amount = 50 },
    { type = "fluid", name = "fluorine", amount = 10 },
    { type = "item", name = "lithium", amount = 1 },
  },
  results = {
    { type = "fluid", name = "fluoroketone-hot", amount = 50 },
  },
}

recipes["fluoroketone-cooling"] = {
  type = "recipe",
  name = "fluoroketone-cooling",
  category = "cryogenics",
  enabled = false,
  ingredients = {
    { type = "fluid", name = "fluoroketone-hot", amount = 10 },
  },
  results = {
    { type = "fluid", name = "fluoroketone-cold", amount = 10 },
  },
}

recipes["cryogenic-plant"] = {
  type = "recipe",
  name = "cryogenic-plant",
  category = "cryogenics-or-assembling",
  enabled = false,
  ingredients = {
    { type = "item", name = "lithium-plate", amount = 20 },
    { type = "item", name = "superconductor", amount = 20 },
  },
  results = {
    { type = "item", name = "cryogenic-plant", amount = 1 },
  },
}

recipes["cargo-bay"] = {
  type = "recipe",
  name = "cargo-bay",
  enabled = false,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 20 },
    { type = "item", name = "low-density-structure", amount = 20 },
    { type = "item", name = "processing-unit", amount = 5 },
  },
  results = {
    { type = "item", name = "cargo-bay", amount = 1 },
  },
}

recipes["asteroid-collector"] = {
  type = "recipe",
  name = "asteroid-collector",
  enabled = false,
  ingredients = {
    { type = "item", name = "low-density-structure", amount = 20 },
    { type = "item", name = "processing-unit", amount = 8 },
    { type = "item", name = "electric-engine-unit", amount = 8 },
  },
  results = {
    { type = "item", name = "asteroid-collector", amount = 1 },
  },
}

recipes["space-platform-starter-pack"] = {
  type = "recipe",
  name = "space-platform-starter-pack",
  enabled = false,
  ingredients = {
    { type = "item", name = "space-platform-foundation", amount = 60 },
    { type = "item", name = "steel-plate", amount = 20 },
    { type = "item", name = "processing-unit", amount = 20 },
  },
  results = {
    { type = "item", name = "space-platform-starter-pack", amount = 1 },
  },
}

recipes["space-platform-foundation"] = {
  type = "recipe",
  name = "space-platform-foundation",
  enabled = false,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 20 },
    { type = "item", name = "copper-cable", amount = 20 },
  },
  results = {
    { type = "item", name = "space-platform-foundation", amount = 1 },
  },
}

recipes["crusher"] = {
  type = "recipe",
  name = "crusher",
  enabled = false,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 10 },
    { type = "item", name = "electronic-circuit", amount = 10 },
  },
  results = {
    { type = "item", name = "crusher", amount = 1 },
  },
}

recipes["thruster"] = {
  type = "recipe",
  name = "thruster",
  enabled = false,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 10 },
    { type = "item", name = "pipe", amount = 10 },
  },
  results = {
    { type = "item", name = "thruster", amount = 1 },
  },
}

recipes["metallic-asteroid-crushing"] = {
  type = "recipe",
  name = "metallic-asteroid-crushing",
  category = "crushing",
  enabled = false,
  ingredients = {
    { type = "item", name = "metallic-asteroid-chunk", amount = 1 },
  },
  results = {
    { type = "item", name = "iron-ore", amount = 10 },
  },
}

recipes["carbonic-asteroid-crushing"] = {
  type = "recipe",
  name = "carbonic-asteroid-crushing",
  category = "crushing",
  enabled = false,
  ingredients = {
    { type = "item", name = "carbonic-asteroid-chunk", amount = 1 },
  },
  results = {
    { type = "item", name = "carbon", amount = 10 },
  },
}

recipes["oxide-asteroid-crushing"] = {
  type = "recipe",
  name = "oxide-asteroid-crushing",
  category = "crushing",
  enabled = false,
  ingredients = {
    { type = "item", name = "oxide-asteroid-chunk", amount = 1 },
  },
  results = {
    { type = "item", name = "ice", amount = 10 },
  },
}

recipes["advanced-metallic-asteroid-crushing"] = {
  type = "recipe",
  name = "advanced-metallic-asteroid-crushing",
  category = "crushing",
  enabled = false,
  ingredients = {
    { type = "item", name = "metallic-asteroid-chunk", amount = 1 },
  },
  results = {
    { type = "item", name = "iron-ore", amount = 20 },
  },
}

recipes["metallic-asteroid-reprocessing"] = {
  type = "recipe",
  name = "metallic-asteroid-reprocessing",
  category = "crushing",
  enabled = false,
  ingredients = {
    { type = "item", name = "metallic-asteroid-chunk", amount = 1 },
  },
  results = {
    { type = "item", name = "carbonic-asteroid-chunk", amount = 1 },
  },
}

recipes["fusion-reactor"] = {
  type = "recipe",
  name = "fusion-reactor",
  enabled = false,
  ingredients = {
    { type = "item", name = "tungsten-plate", amount = 20 },
    { type = "item", name = "carbon-fiber", amount = 20 },
    { type = "item", name = "holmium-plate", amount = 20 },
  },
  results = {
    { type = "item", name = "fusion-reactor", amount = 1 },
  },
}

recipes["fusion-generator"] = {
  type = "recipe",
  name = "fusion-generator",
  enabled = false,
  ingredients = {
    { type = "item", name = "tungsten-plate", amount = 10 },
    { type = "item", name = "carbon-fiber", amount = 10 },
    { type = "item", name = "holmium-plate", amount = 10 },
  },
  results = {
    { type = "item", name = "fusion-generator", amount = 1 },
  },
}

recipes["mech-armor"] = {
  type = "recipe",
  name = "mech-armor",
  enabled = false,
  ingredients = {
    { type = "item", name = "tungsten-plate", amount = 10 },
    { type = "item", name = "carbon-fiber", amount = 10 },
    { type = "item", name = "holmium-plate", amount = 10 },
  },
  results = {
    { type = "item", name = "mech-armor", amount = 1 },
  },
}

recipes["promethium-science-pack"] = {
  type = "recipe",
  name = "promethium-science-pack",
  enabled = false,
  ingredients = {
    { type = "item", name = "promethium-asteroid-chunk", amount = 1 },
    { type = "item", name = "quantum-processor", amount = 1 },
  },
  results = {
    { type = "item", name = "promethium-science-pack", amount = 10 },
  },
}

recipes["heating-tower"] = {
  type = "recipe",
  name = "heating-tower",
  enabled = false,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 15 },
    { type = "item", name = "stone-brick", amount = 20 },
    { type = "item", name = "pipe", amount = 4 },
  },
  results = {
    { type = "item", name = "heating-tower", amount = 1 },
  },
}

recipes["chromatic-printer"] = {
  type = "recipe",
  name = "chromatic-printer",
  enabled = false,
  ingredients = {
    { type = "item", name = "printer-t2", amount = 1 },
    { type = "item", name = "steel-plate", amount = 20 },
    { type = "item", name = "advanced-circuit", amount = 20 },
    { type = "item", name = "processing-unit", amount = 8 },
  },
  results = {
    { type = "item", name = "chromatic-printer", amount = 1 },
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

technologies["rocket-silo"] = {
  type = "technology",
  name = "rocket-silo",
  effects = {
    { type = "unlock-recipe", recipe = "rocket-silo" },
  },
  unit = {
    count = 1,
    ingredients = {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
      {"chemical-science-pack", 1},
      {"utility-science-pack", 1},
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

local planet_specific_paperwork = {
  "blank-cyan-form",
  "blank-yellow-form",
  "blank-magenta-form",
  "cyan-yellow-form",
  "cyan-magenta-form",
  "yellow-magenta-form",
  "trichromatic-permit",
  "unified-operations-charter",
  "cryogenic-operations-license",
  "promethium-research-charter",
  "hardened-data-vault",
}

local function assert_no_planet_specific_paperwork(recipe, label)
  for _, paperwork_name in ipairs(planet_specific_paperwork) do
    assert_true(not has_ingredient(recipe, paperwork_name),
      label .. " should not require " .. paperwork_name .. " before first planet discovery")
  end
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

test("orbital administration weapons survive the military hiding pass", function()
  assert_true(not data.raw.ammo["middle-management-managing-manager"].hidden,
    "MMMM ammo should remain visible")
  assert_true(not data.raw.ammo["orbital-deviation-order"].hidden,
    "deviation order ammo should remain visible")
  assert_true(not data.raw["ammo-turret"]["trajectory-compliance-array"].hidden,
    "trajectory compliance array should remain visible")
  assert_true(not data.raw["ammo-turret"]["senior-trajectory-compliance-array"].hidden,
    "senior trajectory compliance array should remain visible")
  assert_true(not data.raw["ammo-turret"]["executive-trajectory-compliance-array"].hidden,
    "executive trajectory compliance array should remain visible")
  assert_true(not data.raw["ammo-turret"]["orbital-employment-cannon"].hidden,
    "orbital employment cannon should remain visible")
  assert_eq(data.raw.ammo["firearm-magazine"].hidden, true,
    "conventional ammunition should remain hidden")
  assert_eq(data.raw["ammo-turret"]["gun-turret"].hidden, true,
    "conventional ammo turrets should remain hidden")
end)

test("Factoriopedia has a dedicated administrative recycling tab", function()
  local group = assert(data.raw["item-group"]["admin-recycling-group"])
  assert_eq(group.order, "zc")
  for _, subgroup_name in ipairs({
    "archive-recovery-recipes",
    "form-reassignment-recipes",
    "form-paper-recycling-recipes",
  }) do
    local subgroup = assert(data.raw["item-subgroup"][subgroup_name], subgroup_name .. " missing")
    assert_eq(subgroup.group, "admin-recycling-group")
  end
end)

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

test("equipment recipes stay unbatched at 1x", function()
  local solar = get_recipe("solar-panel-equipment")
  assert_true(solar ~= nil, "solar-panel-equipment missing")
  assert_eq(get_result_amount(solar, "solar-panel-equipment"), 1, "solar-panel-equipment should stay 1x")
  assert_true(not has_icon_layer(solar, "__base__/graphics/icons/signal/signal_1.png"),
    "solar-panel-equipment should not show a 1x overlay")
  assert_true(not has_icon_layer(solar, "__base__/graphics/icons/signal/signal_2.png"),
    "solar-panel-equipment should not show a 2x overlay")

  local battery = get_recipe("battery-equipment")
  assert_true(battery ~= nil, "battery-equipment missing")
  assert_eq(get_result_amount(battery, "battery-equipment"), 1, "battery-equipment should stay 1x")
  assert_true(not has_icon_layer(battery, "__base__/graphics/icons/signal/signal_1.png"),
    "battery-equipment should not show a 1x overlay")
  assert_true(not has_icon_layer(battery, "__base__/graphics/icons/signal/signal_2.png"),
    "battery-equipment should not show a 2x overlay")

  local battery_mk2 = get_recipe("battery-mk2-equipment")
  assert_true(battery_mk2 ~= nil, "battery-mk2-equipment missing")
  assert_eq(get_result_amount(battery_mk2, "battery-mk2-equipment"), 1, "battery-mk2-equipment should stay 1x")
  assert_true(not has_icon_layer(battery_mk2, "__base__/graphics/icons/signal/signal_1.png"),
    "battery-mk2-equipment should not show a 1x overlay")
  assert_true(not has_icon_layer(battery_mk2, "__base__/graphics/icons/signal/signal_2.png"),
    "battery-mk2-equipment should not show a 2x overlay")

  local exoskeleton = get_recipe("exoskeleton-equipment")
  assert_true(exoskeleton ~= nil, "exoskeleton-equipment missing")
  assert_eq(get_result_amount(exoskeleton, "exoskeleton-equipment"), 1, "exoskeleton-equipment should stay 1x")
  assert_true(not has_icon_layer(exoskeleton, "__base__/graphics/icons/signal/signal_1.png"),
    "exoskeleton-equipment should not show a 1x overlay")
end)

test("space platform structures stay unbatched at 1x", function()
  local cargo_bay = get_recipe("cargo-bay")
  assert_true(cargo_bay ~= nil, "cargo-bay missing")
  assert_eq(get_result_amount(cargo_bay, "cargo-bay"), 1, "cargo-bay should stay 1x")
  assert_eq(get_ingredient_amount(cargo_bay, "steel-plate"), 20, "cargo-bay ingredients should stay unbatched")
  assert_true(not has_icon_layer(cargo_bay, "__base__/graphics/icons/signal/signal_1.png"),
    "cargo-bay should not show a 1x overlay")
  assert_true(not has_icon_layer(cargo_bay, "__base__/graphics/icons/signal/signal_5.png"),
    "cargo-bay should not show a 5x overlay")
end)

test("space platform starter pack stays unbatched at 1x", function()
  local starter_pack = get_recipe("space-platform-starter-pack")
  assert_true(starter_pack ~= nil, "space-platform-starter-pack missing")
  assert_eq(get_result_amount(starter_pack, "space-platform-starter-pack"), 1,
    "space-platform-starter-pack should stay 1x")
  assert_eq(get_ingredient_amount(starter_pack, "space-platform-foundation"), 60,
    "space-platform-starter-pack ingredients should stay unbatched")
  assert_true(not has_icon_layer(starter_pack, "__base__/graphics/icons/signal/signal_1.png"),
    "space-platform-starter-pack should not show a 1x overlay")
  assert_true(not has_icon_layer(starter_pack, "__base__/graphics/icons/signal/signal_5.png"),
    "space-platform-starter-pack should not show a 5x overlay")
end)

test("vanilla space age buildings stay unbatched at 1x", function()
  local heating_tower = get_recipe("heating-tower")
  assert_true(heating_tower ~= nil, "heating-tower missing")
  assert_eq(get_result_amount(heating_tower, "heating-tower"), 1, "heating-tower should stay 1x")
  assert_eq(get_ingredient_amount(heating_tower, "steel-plate"), 15, "heating-tower ingredients should stay unbatched")
  assert_true(not has_icon_layer(heating_tower, "__base__/graphics/icons/signal/signal_1.png"),
    "heating-tower should not show a 1x overlay")
  assert_true(not has_icon_layer(heating_tower, "__base__/graphics/icons/signal/signal_5.png"),
    "heating-tower should not show a 5x overlay")
end)

test("mod space age buildings stay unbatched at 1x", function()
  local chromatic_printer = get_recipe("chromatic-printer-regulated")
  assert_true(chromatic_printer ~= nil, "chromatic-printer-regulated missing")
  assert_eq(get_result_amount(chromatic_printer, "chromatic-printer"), 1,
    "chromatic-printer-regulated should stay 1x")
  assert_eq(get_ingredient_amount(chromatic_printer, "steel-plate"), 20,
    "chromatic-printer-regulated ingredients should stay unbatched")
  assert_true(not has_icon_layer(chromatic_printer, "__base__/graphics/icons/signal/signal_1.png"),
    "chromatic-printer-regulated should not show a 1x overlay")
  assert_true(not has_icon_layer(chromatic_printer, "__base__/graphics/icons/signal/signal_5.png"),
    "chromatic-printer-regulated should not show a 5x overlay")
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

test("Space Age uses one shared rocket-silo recipe on every planet", function()
  local recipe = get_recipe("rocket-silo")
  assert_true(recipe ~= nil, "rocket-silo missing")
  assert_eq(recipe.surface_conditions, nil, "rocket-silo should be craftable on every planet")
  assert_true(not has_ingredient(recipe, "taxpayer-money"),
    "rocket-silo should not consume loose taxpayer money")
  assert_eq(get_ingredient_amount(recipe, "government-grant"), 1,
    "rocket-silo should consume one financed government grant")
  assert_eq(get_ingredient_amount(recipe, "management-approval-written"), 1,
    "rocket-silo should keep the shared written approval")
  assert_true(not has_ingredient(recipe, "management-written-work-order"),
    "rocket-silo should replace the regulated work order with its shared authorization")

  for _, planet in ipairs({"vulcanus", "gleba", "fulgora", "aquilo"}) do
    local variant_name = "rocket-silo-" .. planet
    assert_eq(get_recipe(variant_name), nil, variant_name .. " should not exist")
    assert_true(not tech_unlocks_recipe("rocket-silo", variant_name),
      variant_name .. " should not be unlocked")
  end
end)

test("Space Age issues loose taxpayer money only on Nauvis", function()
  for _, recipe_name in ipairs({"treasury-bond", "taxpayer-money"}) do
    local recipe = get_recipe(recipe_name)
    assert_true(recipe ~= nil, recipe_name .. " missing")
    assert_true(recipe.surface_conditions ~= nil, recipe_name .. " should be surface-limited")
    assert_eq(recipe.surface_conditions[1].property, "pressure", recipe_name .. " should use Nauvis pressure")
    assert_eq(recipe.surface_conditions[1].min, 1000, recipe_name .. " should require Nauvis pressure")
    assert_eq(recipe.surface_conditions[1].max, 1000, recipe_name .. " should require Nauvis pressure")
    assert_eq(recipe.surface_conditions[2].property, "gravity", recipe_name .. " should use Nauvis gravity")
    assert_eq(recipe.surface_conditions[2].min, 10, recipe_name .. " should require Nauvis gravity")
    assert_eq(recipe.surface_conditions[2].max, 10, recipe_name .. " should require Nauvis gravity")
  end
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

test("admin building regulated recipes batch and show overlays", function()
  local printer = get_recipe("printer-t1-regulated")
  assert_true(printer ~= nil, "printer-t1-regulated missing")
  assert_eq(get_ingredient_amount(printer, "provisional-work-order"), 1, "printer-t1-regulated should keep combined paperwork as a fixed cost")
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

  local intake = get_recipe("tube-intake-regulated")
  assert_true(intake ~= nil, "tube-intake-regulated missing")
  assert_eq(get_result_amount(intake, "tube-intake"), 5, "tube-intake-regulated should batch to 5")
  assert_true(has_icon_layer(intake, "__base__/graphics/icons/signal/signal_5.png"),
    "tube-intake-regulated should show the 5x overlay")
end)

test("space age intermediate recipes gain the expected chromatic and aquilo gates", function()
  local electromagnetic = get_recipe("electromagnetic-plant")
  assert_true(electromagnetic ~= nil, "electromagnetic-plant missing")
  assert_true(has_ingredient(electromagnetic, "blank-magenta-form"),
    "electromagnetic-plant should gain blank-magenta-form for holmium use")

  local asteroid_collector = get_recipe("asteroid-collector")
  assert_true(asteroid_collector ~= nil, "asteroid-collector missing")
  assert_true(not has_ingredient(asteroid_collector, "cyan-magenta-form"),
    "asteroid collectors should stay available before any planet-specific paperwork")

  local cargo_bay = get_recipe("cargo-bay")
  assert_true(cargo_bay ~= nil, "cargo-bay missing")
  assert_true(not has_ingredient(cargo_bay, "cyan-magenta-form"),
    "cargo bays should stay available before any planet-specific paperwork")

  local dual = get_recipe("dual-planet-widget")
  assert_true(dual ~= nil, "dual-planet-widget missing")
  assert_true(has_ingredient(dual, "cyan-yellow-form"),
    "dual-planet-widget should collapse dual-planet paperwork into cyan-yellow-form")
  assert_true(not has_ingredient(dual, "blank-cyan-form"),
    "dual-planet-widget should not keep separate blank-cyan-form once cyan-yellow-form is available")
  assert_true(not has_ingredient(dual, "blank-yellow-form"),
    "dual-planet-widget should not keep separate blank-yellow-form once cyan-yellow-form is available")

  local quantum = get_recipe("quantum-processor")
  assert_true(quantum ~= nil, "quantum-processor missing")
  assert_true(has_ingredient(quantum, "unified-operations-charter"),
    "quantum-processor should gain unified-operations-charter as the top-tier multicolor gate")
  assert_true(not has_ingredient(quantum, "blank-cyan-form"),
    "quantum-processor should not keep separate blank-cyan-form once unified multicolor paperwork is used")
  assert_true(not has_ingredient(quantum, "blank-yellow-form"),
    "quantum-processor should not keep separate blank-yellow-form once unified multicolor paperwork is used")
  assert_true(not has_ingredient(quantum, "blank-magenta-form"),
    "quantum-processor should not keep separate blank-magenta-form once unified multicolor paperwork is used")

  for _, recipe_name in ipairs({"fusion-reactor", "fusion-generator", "mech-armor"}) do
    local recipe = get_recipe(recipe_name)
    assert_true(recipe ~= nil, recipe_name .. " missing")
    assert_true(has_ingredient(recipe, "trichromatic-permit"),
      recipe_name .. " should require trichromatic-permit as a three-planet convergence gate")
    assert_true(not has_ingredient(recipe, "blank-cyan-form"),
      recipe_name .. " should not keep separate blank-cyan-form once trichromatic paperwork is used")
    assert_true(not has_ingredient(recipe, "blank-yellow-form"),
      recipe_name .. " should not keep separate blank-yellow-form once trichromatic paperwork is used")
    assert_true(not has_ingredient(recipe, "blank-magenta-form"),
      recipe_name .. " should not keep separate blank-magenta-form once trichromatic paperwork is used")
  end

  local promethium = get_recipe("promethium-science-pack")
  assert_true(promethium ~= nil, "promethium-science-pack missing")
  assert_true(has_ingredient(promethium, "promethium-research-charter"),
    "promethium science should require a shattered-planet research charter")

  local lithium = get_recipe("lithium")
  assert_true(has_ingredient(lithium, "cyan-yellow-form"),
    "lithium should require cyan-yellow-form as the first Aquilo convergence gate")
  local lithium_plate = get_recipe("lithium-plate")
  assert_true(has_ingredient(lithium_plate, "cyan-yellow-form"),
    "lithium-plate should require cyan-yellow-form")
  local fluoroketone = get_recipe("fluoroketone")
  assert_true(has_ingredient(fluoroketone, "cryogenic-operations-license"),
    "fluoroketone should require cryogenic-operations-license")
  local cooling = get_recipe("fluoroketone-cooling")
  assert_true(has_ingredient(cooling, "cryogenic-operations-license"),
    "fluoroketone-cooling should require cryogenic-operations-license")
  local cryogenic = get_recipe("cryogenic-plant")
  assert_true(has_ingredient(cryogenic, "cryogenic-operations-license"),
    "cryogenic-plant should require cryogenic-operations-license")
end)

test("first platform infrastructure and basic asteroid crushing stay pre-planet", function()
  for _, recipe_name in ipairs({
    "space-platform-foundation",
    "space-platform-starter-pack",
    "cargo-bay",
    "asteroid-collector",
    "crusher",
    "thruster",
    "metallic-asteroid-crushing",
    "carbonic-asteroid-crushing",
    "oxide-asteroid-crushing",
  }) do
    local recipe = get_recipe(recipe_name)
    assert_true(recipe ~= nil, recipe_name .. " missing")
    assert_no_planet_specific_paperwork(recipe, recipe_name)
    assert_true(not has_ingredient(recipe, "asteroid-processing-docket"),
      recipe_name .. " should not require post-space-science asteroid paperwork")
  end

  local advanced_crushing = get_recipe("advanced-metallic-asteroid-crushing")
  assert_true(advanced_crushing ~= nil, "advanced-metallic-asteroid-crushing missing")
  assert_true(has_ingredient(advanced_crushing, "asteroid-processing-docket"),
    "advanced asteroid crushing should require asteroid-processing-docket")

  local reprocessing = get_recipe("metallic-asteroid-reprocessing")
  assert_true(reprocessing ~= nil, "metallic-asteroid-reprocessing missing")
  assert_true(has_ingredient(reprocessing, "asteroid-processing-docket"),
    "asteroid reprocessing should require asteroid-processing-docket")
end)

test("pentapod egg spoil trigger notifies runtime to unpacify hatchlings", function()
  local effects = data.raw.item["pentapod-egg"].spoil_to_trigger_result.trigger.action_delivery.source_effects
  local found = false
  for _, effect in ipairs(effects) do
    if effect.type == "script" and effect.effect_id == "administratorio-pentapod-egg-hatch" then
      found = true
      break
    end
  end
  assert_true(found, "pentapod egg spoil trigger should include the hatchling runtime script effect")
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
