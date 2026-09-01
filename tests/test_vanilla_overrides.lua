-------------------------------------------------------------------------------
-- ADMINISTRATORIO VANILLA OVERRIDES TESTS
--
-- Standalone Lua tests for override behavior applied in overrides/vanilla.lua.
-- Run: lua tests/test_vanilla_overrides.lua
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

local function tech_has_prereq(tech, prereq_name)
  if not tech or not tech.prerequisites then return false end
  for _, prereq in ipairs(tech.prerequisites) do
    if prereq == prereq_name then
      return true
    end
  end
  return false
end

local function tech_unlocks_recipe(tech, recipe_name)
  if not tech or not tech.effects then return false end
  for _, effect in ipairs(tech.effects) do
    if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
      return true
    end
  end
  return false
end

local function recipe_ingredient_amount(recipe, item_name)
  if not recipe or not recipe.ingredients then return nil end
  for _, ingredient in ipairs(recipe.ingredients) do
    if (ingredient.name or ingredient[1]) == item_name then
      return ingredient.amount or ingredient[2]
    end
  end
  return nil
end

local technologies = {
  ["laser-weapons-damage-1"] = {name = "laser-weapons-damage-1", enabled = true, hidden = false, unit = {ingredients = {{"automation-science-pack", 1}}}},
  ["laser-weapons-damage-2"] = {name = "laser-weapons-damage-2", enabled = true, hidden = false, prerequisites = {"laser-weapons-damage-1"}, unit = {ingredients = {{"automation-science-pack", 1}}}},
  ["laser-weapons-damage-7"] = {name = "laser-weapons-damage-7", enabled = true, hidden = false, prerequisites = {"laser-weapons-damage-6"}, unit = {ingredients = {{"space-science-pack", 1}}}},
  ["laser-shooting-speed-1"] = {name = "laser-shooting-speed-1", enabled = true, hidden = false, unit = {ingredients = {{"automation-science-pack", 1}}}},
  ["heavy-armor"] = {name = "heavy-armor", prerequisites = {"military"}},
  ["power-armor-mk2"] = {name = "power-armor-mk2", prerequisites = {"military-4"}},
  ["cliff-explosives"] = {name = "cliff-explosives", prerequisites = {"explosives", "military-2"}},
  ["gate"] = {name = "gate", prerequisites = {"automation", "military-2"}},
  ["rocket-fuel"] = {name = "rocket-fuel", prerequisites = {"flammables", "advanced-oil-processing", "environmental-compliance"}},
  ["flammables"] = {name = "flammables"},
  ["military-2"] = {name = "military-2"},
  ["modules"] = {name = "modules", unit = {ingredients = {{"automation-science-pack", 1}}}},
  ["some-tech"] = {name = "some-tech", prerequisites = {"military-science-pack"}, unit = {ingredients = {{"military-science-pack", 1}}}},
  ["steel-processing"] = {name = "steel-processing", effects = {}},
}

data = {
  raw = {
    item = {},
    gun = {},
    tool = {},
    ammo = {},
    armor = {},
    recipe = {
      ["logistic-science-pack"] = {name = "logistic-science-pack"},
      ["speed-module"] = {name = "speed-module"},
      ["speed-module-2"] = {name = "speed-module-2"},
      ["speed-module-3"] = {name = "speed-module-3"},
      ["productivity-module"] = {name = "productivity-module"},
      ["productivity-module-2"] = {name = "productivity-module-2"},
      ["productivity-module-3"] = {name = "productivity-module-3"},
      ["efficiency-module"] = {name = "efficiency-module"},
      ["efficiency-module-2"] = {name = "efficiency-module-2"},
      ["efficiency-module-3"] = {name = "efficiency-module-3"},
    },
    capsule = {},
    technology = technologies,
    turret = {},
    ["autoplace-control"] = {
      ["enemy-base"] = {hidden = true},
    },
    unit = {
      ["small-biter"] = {
        name = "small-biter",
        subgroup = "enemies",
        attack_parameters = {
          ammo_type = {
            action = {
              {
                action_delivery = {
                  {
                    target_effects = {
                      {type = "damage", damage = {amount = 10}},
                    },
                  },
                },
              },
            },
          },
        },
      },
      ["small-wriggler-pentapod-premature"] = {
        name = "small-wriggler-pentapod-premature",
        subgroup = "enemies",
        attack_parameters = {
          ammo_type = {
            action = {
              {
                action_delivery = {
                  {
                    target_effects = {
                      {type = "damage", damage = {amount = 10}},
                    },
                  },
                },
              },
            },
          },
        },
      },
      ["medium-wriggler-pentapod-premature"] = {
        name = "medium-wriggler-pentapod-premature",
        subgroup = "enemies",
        attack_parameters = {
          ammo_type = {
            action = {{action_delivery = {{target_effects = {{type = "damage", damage = {amount = 20}}}}}}},
          },
        },
      },
      ["big-wriggler-pentapod-premature"] = {
        name = "big-wriggler-pentapod-premature",
        subgroup = "enemies",
        attack_parameters = {
          ammo_type = {
            action = {{action_delivery = {{target_effects = {{type = "damage", damage = {amount = 30}}}}}}},
          },
        },
      },
    },
    ["unit-spawner"] = {
      ["biter-spawner"] = {type = "unit-spawner", name = "biter-spawner", subgroup = "enemies"},
      ["gleba-spawner"] = {type = "unit-spawner", name = "gleba-spawner", subgroup = "enemies"},
      ["gleba-spawner-small"] = {type = "unit-spawner", name = "gleba-spawner-small", subgroup = "enemies"},
    },
    lab = {},
    furnace = {
      ["stone-furnace"] = {name = "stone-furnace", type = "furnace"},
      ["steel-furnace"] = {name = "steel-furnace", type = "furnace"},
      ["electric-furnace"] = {name = "electric-furnace", type = "furnace"},
    },
    ["assembling-machine"] = {},
    locomotive = {},
    ["electric-pole"] = {
      ["small-electric-pole"] = {name = "small-electric-pole", supply_area_distance = 2.5},
      ["medium-electric-pole"] = {name = "medium-electric-pole", supply_area_distance = 3.5},
      ["big-electric-pole"] = {name = "big-electric-pole", supply_area_distance = 2},
    },
    planet = {
      nauvis = {
        map_gen_settings = {},
      },
    },
  },
}

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

dofile(mod_root .. "overrides/vanilla.lua")

test("laser weapons damage technologies are disabled and hidden", function()
  for _, name in ipairs({"laser-weapons-damage-1", "laser-weapons-damage-2", "laser-weapons-damage-7"}) do
    local tech = technologies[name]
    assert_true(tech ~= nil, name .. " missing")
    assert_true(tech.enabled == false, name .. " should be disabled")
    assert_true(tech.hidden == true, name .. " should be hidden")
  end
end)

test("laser shooting speed technologies are still disabled by the broader purge", function()
  local tech = technologies["laser-shooting-speed-1"]
  assert_true(tech.enabled == false, "laser-shooting-speed-1 should be disabled")
  assert_true(tech.hidden == true, "laser-shooting-speed-1 should be hidden")
end)

test("cliff explosives research is rewired away from military prerequisites", function()
  local tech = technologies["cliff-explosives"]
  assert_true(tech_has_prereq(tech, "explosives"), "cliff-explosives should still require explosives")
  assert_true(tech_has_prereq(tech, "discovery-bullshit"), "cliff-explosives should require discovery-bullshit")
  assert_true(not tech_has_prereq(tech, "military-2"), "cliff-explosives should no longer require military-2")
  assert_true(not tech_has_prereq(tech, "military"), "cliff-explosives should no longer require military")
end)

test("civilian technologies do not retain disabled military prerequisites", function()
  local gate = technologies["gate"]
  assert_true(tech_has_prereq(gate, "automation"), "gate should retain automation")
  assert_true(tech_has_prereq(gate, "logistic-science-pack"), "gate should require logistic science")
  assert_true(not tech_has_prereq(gate, "military-2"), "gate should not require military-2")

  local rocket_fuel = technologies["rocket-fuel"]
  assert_true(tech_has_prereq(rocket_fuel, "advanced-oil-processing"), "rocket-fuel should retain advanced oil processing")
  assert_true(tech_has_prereq(rocket_fuel, "environmental-compliance"), "rocket-fuel should retain environmental compliance")
  assert_true(not tech_has_prereq(rocket_fuel, "flammables"), "rocket-fuel should not require disabled flammables")
end)

test("steel processing unlocks batch steel smelting", function()
  local tech = technologies["steel-processing"]
  assert_true(tech_unlocks_recipe(tech, "steel-plate-batch"), "steel-processing should unlock steel-plate-batch")
end)

test("electric furnaces support certified batch smelting", function()
  local electric_furnace = data.raw["assembling-machine"]["electric-furnace"]
  assert_true(electric_furnace ~= nil, "electric-furnace should be converted to an assembling machine")

  local categories = {}
  for _, category in ipairs(electric_furnace.crafting_categories) do
    categories[category] = true
  end

  assert_true(categories["smelting"], "electric-furnace should retain vanilla smelting")
  assert_true(categories["smelting-basic"],
    "electric-furnace should support certified batch recipes such as compacted-rubble-production")
end)

test("vanilla module recipes use the dedicated admin module category", function()
  for _, name in ipairs({
    "speed-module", "speed-module-2", "speed-module-3",
    "productivity-module", "productivity-module-2", "productivity-module-3",
    "efficiency-module", "efficiency-module-2", "efficiency-module-3",
  }) do
    local recipe = data.raw.recipe[name]
    assert_true(recipe ~= nil, name .. " recipe missing")
    assert_true(recipe.category == "bureaucracy-modules", name .. " should use bureaucracy-modules")
  end
end)

test("first-tier speed and efficiency modules use two paperwork inputs", function()
  assert_true(recipe_ingredient_amount(data.raw.recipe["speed-module"], "basic-excuse") == 2,
    "speed-module should require two basic excuses")
  assert_true(recipe_ingredient_amount(data.raw.recipe["efficiency-module"], "crappy-report") == 2,
    "efficiency-module should require two crappy reports")
end)

test("premature pentapods of every size keep vanilla attack damage when eggs hatch", function()
  local biter_damage = data.raw.unit["small-biter"].attack_parameters.ammo_type.action[1]
    .action_delivery[1].target_effects[1].damage.amount
  assert_true(biter_damage == 0, "regular biters should still be pacified")

  for _, prefix in ipairs({"small", "medium", "big"}) do
    local entity_name = prefix .. "-wriggler-pentapod-premature"
    local pentapod_damage = data.raw.unit[entity_name].attack_parameters.ammo_type.action[1]
      .action_delivery[1].target_effects[1].damage.amount
    assert_true(pentapod_damage > 0,
      entity_name .. " should remain able to damage buildings after hatching")
  end
end)

test("pentapod egg nests resist impact damage like biter nests", function()
  for _, spawner_name in ipairs({"biter-spawner", "gleba-spawner", "gleba-spawner-small"}) do
    local spawner = data.raw["unit-spawner"][spawner_name]
    local impact_percent = nil
    for _, resistance in ipairs(spawner.resistances or {}) do
      if resistance.type == "impact" then
        impact_percent = resistance.percent
        break
      end
    end
    assert_true(impact_percent == 100,
      spawner_name .. " should be immune to collision and stomping damage")
  end
end)

if failed > 0 then
  io.stderr:write("Vanilla override tests: " .. passed .. " passed, " .. failed .. " failed\n")
  for _, err in ipairs(errors) do
    io.stderr:write(" - " .. err .. "\n")
  end
  os.exit(1)
end

print("Vanilla override tests: " .. passed .. " passed, 0 failed")
