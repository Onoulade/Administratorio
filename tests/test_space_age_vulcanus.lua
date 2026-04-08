-------------------------------------------------------------------------------
-- ADMINISTRATORIO VULCANUS SPACE AGE TESTS
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

mods = {
  ["space-age"] = "2.0.0",
}

data = {
  raw = {
    item = {},
    fluid = {},
    recipe = {
      foundry = {type = "recipe", name = "foundry", ingredients = {}},
      biochamber = {type = "recipe", name = "biochamber", ingredients = {}},
      ["electromagnetic-plant"] = {type = "recipe", name = "electromagnetic-plant", ingredients = {}},
      ["cryogenic-plant"] = {type = "recipe", name = "cryogenic-plant", ingredients = {}},
    },
    technology = {
      ["metallurgic-science-pack"] = {type = "technology", name = "metallurgic-science-pack", effects = {}},
      ["agricultural-science-pack"] = {type = "technology", name = "agricultural-science-pack", effects = {}},
      ["electromagnetic-science-pack"] = {type = "technology", name = "electromagnetic-science-pack", effects = {}},
      ["cryogenic-science-pack"] = {type = "technology", name = "cryogenic-science-pack", effects = {}},
      ["after-hours-operations"] = {type = "technology", name = "after-hours-operations", effects = {}},
      ["discovery-redundant-rubble"] = {type = "technology", name = "discovery-redundant-rubble", effects = {}},
      ["nest-expropriation"] = {type = "technology", name = "nest-expropriation", effects = {}},
    },
    ["assembling-machine"] = {
      ["assembling-machine-2"] = {
        type = "assembling-machine",
        name = "assembling-machine-2",
        minable = {result = "assembling-machine-2"},
        placeable_by = {{item = "assembling-machine-2", count = 1}},
        fluid_boxes = {},
        graphics_set = {},
      },
      ["assembling-machine-3"] = {
        type = "assembling-machine",
        name = "assembling-machine-3",
        minable = {result = "assembling-machine-3"},
        placeable_by = {{item = "assembling-machine-3", count = 1}},
        fluid_boxes = {},
        graphics_set = {},
      },
    },
    ["ammo-turret"] = {
      ["gun-turret"] = {
        type = "ammo-turret",
        name = "gun-turret",
        minable = {result = "gun-turret"},
        placeable_by = {{item = "gun-turret", count = 1}},
        attack_parameters = {},
      },
    },
  },
}

function data:extend(prototypes)
  for _, proto in ipairs(prototypes) do
    data.raw[proto.type] = data.raw[proto.type] or {}
    data.raw[proto.type][proto.name] = proto
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
  by_pixel = function(x, y)
    return {x / 32, y / 32}
  end,
}

if not table.deepcopy then
  table.deepcopy = util.table.deepcopy
end

defines = {
  direction = {
    north = 0,
    east = 2,
    south = 4,
    west = 6,
  },
}

function pipecoverspictures()
  return {}
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

dofile(mod_root .. "prototypes/item/capsules-and-fluids.lua")
dofile(mod_root .. "prototypes/item/space_age.lua")
dofile(mod_root .. "prototypes/recipe/space_age.lua")
dofile(mod_root .. "prototypes/entity/space_age.lua")
dofile(mod_root .. "prototypes/technology/space_age.lua")

local planets = require("prototypes.shared.space_age_planets")

local function has_ingredient(recipe, ingredient_name)
  if not recipe or not recipe.ingredients then return false end
  for _, ingredient in ipairs(recipe.ingredients) do
    if ingredient.name == ingredient_name then
      return true
    end
  end
  return false
end

test("chromatic printer is a flippable four-port liquid-fed machine", function()
  local entity = data.raw["assembling-machine"]["chromatic-printer"]
  assert_true(entity ~= nil, "chromatic-printer missing")
  assert_eq(#(entity.fluid_boxes or {}), 4, "chromatic-printer should expose four input ports")

  local expected = {
    {defines.direction.north, 0, -1},
    {defines.direction.east, 1, 0},
    {defines.direction.south, 0, 1},
    {defines.direction.west, -1, 0},
  }

  for index, spec in ipairs(expected) do
    local fluid_box = entity.fluid_boxes[index]
    assert_eq(fluid_box.production_type, "input", "chromatic-printer ports should all be inputs")
    local connection = assert(fluid_box.pipe_connections[1], "chromatic-printer port missing connection")
    assert_eq(connection.flow_direction, "input", "chromatic-printer port should be input-only")
    assert_eq(connection.direction, spec[1], "unexpected pipe direction for chromatic-printer port " .. index)
    assert_eq(connection.position[1], spec[2], "unexpected x position for chromatic-printer port " .. index)
    assert_eq(connection.position[2], spec[3], "unexpected y position for chromatic-printer port " .. index)
  end
end)

test("notary office is the dedicated certification machine", function()
  local entity = data.raw["assembling-machine"]["notary-office"]
  assert_true(entity ~= nil, "notary-office missing")
  assert_eq(entity.placeable_by[1].item, "notary-office", "notary-office should build from the notary-office item")
  local categories = entity.crafting_categories or {}
  assert_eq(#categories, 1, "notary-office should only expose one crafting category")
  assert_eq(categories[1], "bureaucracy-certification", "notary-office should only craft certification recipes")
end)

test("planet helper exposes exact basic-planet conditions and abundance outputs", function()
  local vulcanus = planets.surface_conditions_for_planet("vulcanus")
  local gleba = planets.surface_conditions_for_planet("gleba")
  local fulgora = planets.surface_conditions_for_planet("fulgora")

  assert_eq(vulcanus[1].property, "pressure", "vulcanus first condition should be pressure")
  assert_eq(vulcanus[1].min, 4000, "vulcanus pressure should match Space Age")
  assert_eq(vulcanus[2].property, "gravity", "vulcanus second condition should be gravity")
  assert_eq(vulcanus[2].min, 40, "vulcanus gravity should match Space Age")
  assert_eq(gleba[1].min, 2000, "gleba pressure should match Space Age")
  assert_eq(fulgora[1].min, 800, "fulgora pressure should match Space Age")

  assert_eq(planets.BASIC_PLANET_ABUNDANCE.vulcanus, "lie", "vulcanus abundance should be lie")
  assert_eq(planets.BASIC_PLANET_ABUNDANCE.gleba, "dubious-data", "gleba abundance should be dubious-data")
  assert_eq(planets.BASIC_PLANET_ABUNDANCE.fulgora, "useless-documentation", "fulgora abundance should be useless-documentation")
end)

test("vulcanus fallback launch paperwork is present and surface-limited", function()
  local required = {
    "dubious-data-analysis-vulcanus",
    "research-grant-approval-vulcanus",
    "management-verbal-approval-vulcanus",
    "management-written-approval-vulcanus",
    "vulcanus-lie-fabrication",
  }

  for _, recipe_name in ipairs(required) do
    local recipe = assert(data.raw.recipe[recipe_name], recipe_name .. " missing")
    assert_true(recipe.surface_conditions ~= nil and #recipe.surface_conditions >= 2, recipe_name .. " should be surface-limited")
    assert_eq(recipe.surface_conditions[1].min, 4000, recipe_name .. " should target Vulcanus pressure")
    assert_eq(recipe.surface_conditions[2].min, 40, recipe_name .. " should target Vulcanus gravity")
  end

  assert_true(has_ingredient(data.raw.recipe["management-written-approval-vulcanus"], "management-approval-verbal"),
    "management-written-approval-vulcanus should build on management-approval-verbal")
end)

if failed > 0 then
  io.stderr:write(("Failed %d/%d tests\n"):format(failed, passed + failed))
  for _, err in ipairs(errors) do
    io.stderr:write(err, "\n")
  end
  os.exit(1)
end

print(("Passed %d tests"):format(passed))
