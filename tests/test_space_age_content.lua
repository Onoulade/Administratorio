-------------------------------------------------------------------------------
-- ADMINISTRATORIO SPACE AGE CONTENT TESTS
--
-- Standalone Lua tests for Space Age-specific items, recipes, and tech hooks.
-- Run: lua tests/test_space_age_content.lua
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
}

local items = {}
local technologies = {}

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

test("worker-biter item is defined", function()
  local item = items["worker-biter"]
  assert_true(item ~= nil, "worker-biter item missing")
  assert_eq(item.subgroup, "admin-bs-economy", "worker-biter should live in the admin BS economy subgroup")
end)

test("worker-biter recipe is a union-negotiation process", function()
  local recipe = recipes["worker-biter"]
  assert_true(recipe ~= nil, "worker-biter recipe missing")
  assert_eq(recipe.category, "union-negotiation", "worker-biter should be formed at the union headquarters")
  assert_true(has_ingredient(recipe, "credentials"), "worker-biter should require credentials")
  assert_true(has_ingredient(recipe, "good-excuse"), "worker-biter should require a good excuse")
  assert_true(has_ingredient(recipe, "narrative"), "worker-biter should require narrative")
  assert_true(has_ingredient(recipe, "taxpayer-money"), "worker-biter should require taxpayer money")
end)

test("Space Age native building recipes consume one worker-biter", function()
  for _, recipe_name in ipairs({"foundry", "biochamber", "electromagnetic-plant", "cryogenic-plant"}) do
    assert_true(has_ingredient(recipes[recipe_name], "worker-biter"), recipe_name .. " should require a worker-biter")
  end
end)

test("chromatic-printing unlocks workforce formation", function()
  local technology = technologies["chromatic-printing"]
  assert_true(technology ~= nil, "chromatic-printing missing")
  assert_true(tech_unlocks_recipe(technology, "worker-biter"), "chromatic-printing should unlock worker-biter")
end)

if failed > 0 then
  io.stderr:write(("Failed %d/%d tests\n"):format(failed, passed + failed))
  for _, err in ipairs(errors) do
    io.stderr:write(err, "\n")
  end
  os.exit(1)
end

print(("Passed %d tests"):format(passed))
