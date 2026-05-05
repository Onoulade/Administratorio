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

local technologies = {
  ["laser-weapons-damage-1"] = {name = "laser-weapons-damage-1", enabled = true, hidden = false, unit = {ingredients = {{"automation-science-pack", 1}}}},
  ["laser-weapons-damage-2"] = {name = "laser-weapons-damage-2", enabled = true, hidden = false, prerequisites = {"laser-weapons-damage-1"}, unit = {ingredients = {{"automation-science-pack", 1}}}},
  ["laser-weapons-damage-7"] = {name = "laser-weapons-damage-7", enabled = true, hidden = false, prerequisites = {"laser-weapons-damage-6"}, unit = {ingredients = {{"space-science-pack", 1}}}},
  ["laser-shooting-speed-1"] = {name = "laser-shooting-speed-1", enabled = true, hidden = false, unit = {ingredients = {{"automation-science-pack", 1}}}},
  ["heavy-armor"] = {name = "heavy-armor", prerequisites = {"military"}},
  ["power-armor-mk2"] = {name = "power-armor-mk2", prerequisites = {"military-4"}},
  ["cliff-explosives"] = {name = "cliff-explosives", prerequisites = {"explosives", "military-2"}},
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
    unit = {},
    ["unit-spawner"] = {},
    lab = {},
    furnace = {},
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

test("electric poles keep their vanilla supply area", function()
  local poles = data.raw["electric-pole"]
  assert_true(poles["small-electric-pole"].supply_area_distance == 2.5, "small-electric-pole supply area should stay vanilla")
  assert_true(poles["medium-electric-pole"].supply_area_distance == 3.5, "medium-electric-pole supply area should stay vanilla")
  assert_true(poles["big-electric-pole"].supply_area_distance == 2, "big-electric-pole supply area should stay vanilla")
end)

test("cliff explosives research is rewired away from military prerequisites", function()
  local tech = technologies["cliff-explosives"]
  assert_true(tech_has_prereq(tech, "explosives"), "cliff-explosives should still require explosives")
  assert_true(tech_has_prereq(tech, "discovery-bullshit"), "cliff-explosives should require discovery-bullshit")
  assert_true(not tech_has_prereq(tech, "military-2"), "cliff-explosives should no longer require military-2")
  assert_true(not tech_has_prereq(tech, "military"), "cliff-explosives should no longer require military")
end)

test("steel processing unlocks batch steel smelting", function()
  local tech = technologies["steel-processing"]
  assert_true(tech_unlocks_recipe(tech, "steel-plate-batch"), "steel-processing should unlock steel-plate-batch")
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

if failed > 0 then
  io.stderr:write("Vanilla override tests: " .. passed .. " passed, " .. failed .. " failed\n")
  for _, err in ipairs(errors) do
    io.stderr:write(" - " .. err .. "\n")
  end
  os.exit(1)
end

print("Vanilla override tests: " .. passed .. " passed, 0 failed")
