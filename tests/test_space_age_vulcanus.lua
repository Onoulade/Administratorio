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
      ["advanced-circuit"] = {type = "recipe", name = "advanced-circuit", ingredients = {}},
      ["low-density-structure"] = {type = "recipe", name = "low-density-structure", ingredients = {}},
      ["rocket-control-unit"] = {type = "recipe", name = "rocket-control-unit", ingredients = {}},
      ["rocket-silo"] = {type = "recipe", name = "rocket-silo", ingredients = {}},
      ["rocket-fuel-from-jelly"] = {type = "recipe", name = "rocket-fuel-from-jelly", ingredients = {}},
      ["bioplastic"] = {type = "recipe", name = "bioplastic", ingredients = {}},
      ["biosulfur"] = {type = "recipe", name = "biosulfur", ingredients = {}},
      ["biolubricant"] = {type = "recipe", name = "biolubricant", ingredients = {}},
    },
    technology = {
      ["administrative-science-research"] = {type = "technology", name = "administrative-science-research", effects = {}},
      ["printing-technology"] = {type = "technology", name = "printing-technology", effects = {}},
      ["corporate-hospitality"] = {type = "technology", name = "corporate-hospitality", effects = {}},
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
  assert_eq(#(entity.fluid_boxes or {}), 3, "notary-office should expose two inputs and one output")
  assert_eq(entity.fluid_boxes[3].production_type, "output", "notary-office should vent fluid outputs")
end)

test("conciliation desk is the dedicated gleba certification machine", function()
  local entity = data.raw["assembling-machine"]["conciliation-desk"]
  assert_true(entity ~= nil, "conciliation-desk missing")
  assert_eq(entity.placeable_by[1].item, "conciliation-desk", "conciliation-desk should build from the conciliation-desk item")
  local categories = entity.crafting_categories or {}
  assert_eq(#categories, 1, "conciliation-desk should only expose one crafting category")
  assert_eq(categories[1], "bureaucracy-conciliation", "conciliation-desk should only craft conciliation recipes")
  assert_eq(#(entity.fluid_boxes or {}), 3, "conciliation-desk should expose two inputs and one output")
  assert_eq(entity.fluid_boxes[3].production_type, "output", "conciliation-desk should vent fluid outputs")
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

test("vulcanus printer and notary split is present and surface-limited", function()
  local required = {
    "paper-production-vulcanus",
    "carbon-offset-certificate-basic-vulcanus",
    "admin-station-vulcanus",
    "printer-t1-vulcanus",
    "dubious-data-analysis-vulcanus",
    "research-grant-approval-vulcanus",
    "administrative-science-pack-production-vulcanus",
    "plastic-bar-vulcanus",
    "refined-nonsense-production-vulcanus",
    "blank-cyan-form-production",
    "management-approval-verbal-vulcanus",
    "vulcanus-lie-distillation",
    "heatproof-filler-documentation",
    "form-27b-6-vulcanus",
  }

  for _, recipe_name in ipairs(required) do
    local recipe = assert(data.raw.recipe[recipe_name], recipe_name .. " missing")
    assert_true(recipe.surface_conditions ~= nil and #recipe.surface_conditions >= 2, recipe_name .. " should be surface-limited")
    assert_eq(recipe.surface_conditions[1].min, 4000, recipe_name .. " should target Vulcanus pressure")
    assert_eq(recipe.surface_conditions[2].min, 40, recipe_name .. " should target Vulcanus gravity")
  end

  assert_true(data.raw.recipe["management-written-approval-vulcanus"] == nil,
    "management-written-approval-vulcanus should stay import-seeded")
end)

test("chromatic recipes stay printer-only while support-heavy paperwork lives in the notary office", function()
  assert_eq(data.raw.recipe["blank-cyan-form-production"].category, "printing-chromatic", "blank-cyan-form should be printer-made")
  assert_eq(data.raw.recipe["inspection-docket"].category, "printing-chromatic", "inspection-docket should be printer-made")
  assert_eq(data.raw.recipe["management-approval-verbal-vulcanus"].category, "bureaucracy-certification", "verbal approval shortcut should be notary-made")
  assert_eq(data.raw.recipe["offworld-metallurgy-charter"].category, "bureaucracy-certification", "offworld charter should be notary-made")
  assert_true(not has_ingredient(data.raw.recipe["management-approval-verbal-vulcanus"], "cyan-ink"),
    "notary verbal approval should consume support materials, not direct printer ink")
end)

test("offworld recipe variants keep vulcanus paperwork gates off the home planet", function()
  assert_true(data.raw.recipe["foundry"].surface_conditions ~= nil, "foundry should be home-planet limited")
  assert_true(data.raw.recipe["foundry-offworld"].surface_conditions ~= nil, "foundry-offworld should be surface-limited")
  assert_true(has_ingredient(data.raw.recipe["foundry-offworld"], "offworld-metallurgy-charter"),
    "foundry-offworld should require the offworld charter")
  assert_true(not has_ingredient(data.raw.recipe["foundry"], "offworld-metallurgy-charter"),
    "home-planet foundry should not consume the offworld charter")
end)

test("gleba alternates are surface-limited and keep the yellow family compact", function()
  local required = {
    "admin-station-gleba",
    "printer-t1-gleba",
    "corporate-breakroom-gleba",
    "administrative-science-pack-production-gleba",
    "capture-bureau",
    "yellow-ink-production",
    "mycelial-form-stock",
    "blank-yellow-form-production",
    "symbiosis-record",
    "conciliation-order",
    "biochamber-operating-waiver",
  }

  for _, recipe_name in ipairs(required) do
    local recipe = assert(data.raw.recipe[recipe_name], recipe_name .. " missing")
    assert_true(recipe.surface_conditions ~= nil and #recipe.surface_conditions >= 2, recipe_name .. " should be surface-limited")
    assert_eq(recipe.surface_conditions[1].min, 2000, recipe_name .. " should target Gleba pressure")
    assert_eq(recipe.surface_conditions[2].min, 20, recipe_name .. " should target Gleba gravity")
  end

  assert_true(data.raw.recipe["management-approval-written-gleba"] == nil,
    "management-approval-written-gleba should stay absent")
  assert_true(data.raw.recipe["advanced-circuit-gleba"] == nil,
    "advanced-circuit-gleba should stay absent")
  assert_true(data.raw.recipe["low-density-structure-gleba"] == nil,
    "low-density-structure-gleba should stay absent")
  assert_true(data.raw.recipe["rocket-control-unit-gleba"] == nil,
    "rocket-control-unit-gleba should stay absent")
  assert_true(data.raw.recipe["rocket-silo-gleba"] == nil,
    "rocket-silo-gleba should stay absent")
end)

test("gleba offworld bio exports keep paperwork off the home planet", function()
  for _, recipe_name in ipairs({"rocket-fuel-from-jelly", "bioplastic", "biosulfur", "biolubricant"}) do
    local source = assert(data.raw.recipe[recipe_name], recipe_name .. " missing")
    local clone = assert(data.raw.recipe[recipe_name .. "-offworld"], recipe_name .. "-offworld missing")
    assert_true(source.surface_conditions ~= nil, recipe_name .. " should stay home-planet limited")
    assert_true(has_ingredient(clone, "biochamber-operating-waiver"),
      recipe_name .. "-offworld should require biochamber-operating-waiver")
    assert_true(not has_ingredient(source, "biochamber-operating-waiver"),
      recipe_name .. " should not consume biochamber-operating-waiver on Gleba")
  end
end)

if failed > 0 then
  io.stderr:write(("Failed %d/%d tests\n"):format(failed, passed + failed))
  for _, err in ipairs(errors) do
    io.stderr:write(err, "\n")
  end
  os.exit(1)
end

print(("Passed %d tests"):format(passed))
