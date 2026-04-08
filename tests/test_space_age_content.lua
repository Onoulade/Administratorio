-------------------------------------------------------------------------------
-- ADMINISTRATORIO SPACE AGE CONTENT TESTS
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

local recipes = {
  foundry = {type = "recipe", name = "foundry", ingredients = {{type = "item", name = "steel-plate", amount = 50}}},
  biochamber = {type = "recipe", name = "biochamber", ingredients = {{type = "item", name = "iron-plate", amount = 20}}},
  ["electromagnetic-plant"] = {type = "recipe", name = "electromagnetic-plant", ingredients = {{type = "item", name = "holmium-plate", amount = 150}}},
  ["cryogenic-plant"] = {type = "recipe", name = "cryogenic-plant", ingredients = {{type = "item", name = "lithium-plate", amount = 20}}},
  ["space-platform-starter-pack"] = {type = "recipe", name = "space-platform-starter-pack", ingredients = {{type = "item", name = "space-platform-foundation", amount = 60}}},
  ["cargo-bay"] = {type = "recipe", name = "cargo-bay", ingredients = {{type = "item", name = "steel-plate", amount = 20}}},
  ["asteroid-collector"] = {type = "recipe", name = "asteroid-collector", ingredients = {{type = "item", name = "low-density-structure", amount = 20}}},
  ["crusher"] = {type = "recipe", name = "crusher", ingredients = {{type = "item", name = "low-density-structure", amount = 20}}},
}

local items = {}
local technologies = {
  ["metallurgic-science-pack"] = {type = "technology", name = "metallurgic-science-pack", effects = {}},
  ["agricultural-science-pack"] = {type = "technology", name = "agricultural-science-pack", effects = {}},
  ["electromagnetic-science-pack"] = {type = "technology", name = "electromagnetic-science-pack", effects = {}},
  ["cryogenic-science-pack"] = {type = "technology", name = "cryogenic-science-pack", effects = {}},
  ["after-hours-operations"] = {type = "technology", name = "after-hours-operations", effects = {}},
  ["discovery-redundant-rubble"] = {type = "technology", name = "discovery-redundant-rubble", effects = {}},
  ["nest-expropriation"] = {type = "technology", name = "nest-expropriation", effects = {}},
}

data = {
  raw = {
    recipe = recipes,
    item = items,
    technology = technologies,
  },
}

function data:extend(prototypes)
  for _, proto in ipairs(prototypes) do
    data.raw[proto.type] = data.raw[proto.type] or {}
    data.raw[proto.type][proto.name] = proto
    if proto.type == "recipe" then
      recipes[proto.name] = proto
    elseif proto.type == "item" then
      items[proto.name] = proto
    elseif proto.type == "technology" then
      technologies[proto.name] = proto
    end
  end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end

dofile(mod_root .. "prototypes/item/space_age.lua")
dofile(mod_root .. "prototypes/recipe/space_age.lua")
dofile(mod_root .. "prototypes/technology/space_age.lua")

local function has_ingredient(recipe, item_name)
  if not recipe or not recipe.ingredients then return false end
  for _, ingredient in ipairs(recipe.ingredients) do
    if (ingredient.name or ingredient[1]) == item_name then
      return true
    end
  end
  return false
end

local function tech_unlocks_recipe(technology, recipe_name)
  if not technology or not technology.effects then return false end
  for _, effect in ipairs(technology.effects) do
    if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
      return true
    end
  end
  return false
end

test("worker-biter exists as the enrolled-to-workforce intermediate", function()
  assert_true(items["job-offer"] ~= nil, "job-offer missing")
  assert_true(items["enrolled-biter"] ~= nil, "enrolled-biter missing")
  assert_true(items["worker-biter"] ~= nil, "worker-biter missing")
  assert_true(recipes["job-offer-production"] ~= nil, "job-offer recipe missing")
  assert_eq(recipes["job-offer-production"].category, "bureaucracy-policy", "job-offer should be drafted through policy bureaucracy")
  assert_true(has_ingredient(recipes["job-offer-production"], "treasury-bond"), "job-offer should require treasury-bonds")
  assert_true(has_ingredient(recipes["job-offer-production"], "taxpayer-money"), "job-offer should require taxpayer-money")
  assert_true(has_ingredient(recipes["job-offer-production"], "narrative"), "job-offer should require narrative")
  assert_true(recipes["worker-biter-formation"] ~= nil, "worker-biter formation recipe missing")
  assert_true(has_ingredient(recipes["worker-biter-formation"], "enrolled-biter"), "worker-biter should come from enrolled-biter")
end)

test("trainee formation consumes worker-biter instead of enrolled-biter directly", function()
  assert_true(has_ingredient(recipes["clerical-trainee-formation"], "worker-biter"), "clerical trainee should require worker-biter")
  assert_true(not has_ingredient(recipes["clerical-trainee-formation"], "enrolled-biter"), "clerical trainee should not require enrolled-biter directly")
  assert_true(has_ingredient(recipes["management-trainee-formation"], "worker-biter"), "management trainee should require worker-biter")
  assert_true(not has_ingredient(recipes["management-trainee-formation"], "enrolled-biter"), "management trainee should not require enrolled-biter directly")
end)

test("native Space Age buildings consume planet-specific specialists", function()
  assert_true(has_ingredient(recipes["foundry"], "licensed-notary"), "foundry should require licensed-notary")
  assert_true(has_ingredient(recipes["biochamber"], "conciliation-officer"), "biochamber should require conciliation-officer")
  assert_true(has_ingredient(recipes["electromagnetic-plant"], "relay-clerk"), "electromagnetic-plant should require relay-clerk")
  assert_true(has_ingredient(recipes["cryogenic-plant"], "cryoprint-technician"), "cryogenic-plant should require cryoprint-technician")
end)

test("workforce tech owns the workforce progression unlocks", function()
  local workforce = technologies["workforce-formation"]
  local chromatic = technologies["chromatic-printing"]
  assert_true(workforce ~= nil, "workforce-formation missing")
  assert_true(tech_unlocks_recipe(workforce, "job-offer-production"), "workforce-formation should unlock job-offer-production")
  assert_true(tech_unlocks_recipe(workforce, "worker-biter-formation"), "workforce-formation should unlock worker-biter-formation")
  assert_true(not tech_unlocks_recipe(chromatic, "worker-biter"), "chromatic-printing should not directly unlock worker-biter")
  assert_eq(workforce.prerequisites[1], "space-science-pack", "workforce-formation should unlock after space science")
end)

test("night shift and negotiator roles feed their intended recipes", function()
  assert_true(recipes["overtime-exemption-staffed"] ~= nil, "staffed overtime recipe missing")
  assert_true(has_ingredient(recipes["overtime-exemption-staffed"], "night-shift-supervisor"), "staffed overtime should require night-shift-supervisor")
  assert_true(tech_unlocks_recipe(technologies["after-hours-operations"], "overtime-exemption-staffed"), "after-hours-operations should unlock staffed overtime")

  assert_true(recipes["promise-production-negotiated"] ~= nil, "negotiated promise recipe missing")
  assert_true(has_ingredient(recipes["promise-production-negotiated"], "field-negotiator"), "negotiated promise should require field-negotiator")
  assert_true(tech_unlocks_recipe(technologies["discovery-redundant-rubble"], "promise-production-negotiated"), "discovery-redundant-rubble should unlock negotiated promise")

  assert_true(recipes["eviction-notice-production-negotiated"] ~= nil, "negotiated eviction recipe missing")
  assert_true(has_ingredient(recipes["eviction-notice-production-negotiated"], "field-negotiator"), "negotiated eviction should require field-negotiator")
  assert_true(tech_unlocks_recipe(technologies["nest-expropriation"], "eviction-notice-production-negotiated"), "nest-expropriation should unlock negotiated eviction")
end)

test("MMMM feeds core orbital infrastructure", function()
  for _, recipe_name in ipairs({"space-platform-starter-pack", "cargo-bay", "asteroid-collector", "crusher"}) do
    assert_true(has_ingredient(recipes[recipe_name], "middle-management-managing-manager"), recipe_name .. " should require MMMM")
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
