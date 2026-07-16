-- ADMINISTRATORIO BATCH CLASSIFICATION TESTS

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

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

local batch_rules = require("prototypes.shared.batch_rules")

local data_raw = {
  fluid = {
    ["test-fluid"] = {type = "fluid", name = "test-fluid"},
  },
  item = {
    ["standard-item"] = {type = "item", name = "standard-item", stack_size = 100},
    ["intermediate"] = {type = "item", name = "intermediate", stack_size = 100},
    ["space-widget"] = {type = "item", name = "space-widget", stack_size = 100},
    ["space-intermediate"] = {type = "item", name = "space-intermediate", stack_size = 100},
    ["factory"] = {type = "item", name = "factory", stack_size = 20, place_result = "factory"},
    ["belt"] = {type = "item", name = "belt", stack_size = 100, place_result = "belt"},
    ["high-end-belt"] = {type = "item", name = "high-end-belt", stack_size = 100, place_result = "high-end-belt"},
    ["equipment"] = {
      type = "item",
      name = "equipment",
      stack_size = 20,
      place_as_equipment_result = "equipment",
    },
    ["unique-item"] = {type = "item", name = "unique-item", stack_size = 1},
    ["biter-worker"] = {type = "item", name = "biter-worker", stack_size = 20},
  },
  module = {
    ["test-module"] = {type = "module", name = "test-module", stack_size = 50},
  },
  ["assembling-machine"] = {
    ["factory"] = {type = "assembling-machine", name = "factory"},
  },
  ["transport-belt"] = {
    ["belt"] = {type = "transport-belt", name = "belt"},
    ["high-end-belt"] = {type = "transport-belt", name = "high-end-belt"},
  },
}

local config = {
  default_multiplier = 5,
  building_multiplier = 2,
  tool_multiplier = 5,
  multipliers = {
    ["fluid-recipe"] = 20,
    ["module-recipe"] = 20,
    ["equipment-recipe"] = 20,
    ["biter-recipe"] = 20,
    ["intermediate-recipe"] = 10,
    ["space-intermediate-recipe"] = 5,
    ["high-end-belt-recipe"] = 2,
  },
  unbatched_result_names = {},
  unbatched_result_subgroups = {},
  space_subgroup_prefixes = {"space-", "admin-space-"},
}

local function recipe(name, result_name, options)
  options = options or {}
  return {
    type = "recipe",
    name = name,
    subgroup = options.subgroup,
    ingredients = options.ingredients or {{type = "item", name = "standard-item", amount = 1}},
    results = result_name and {{type = options.result_type or "item", name = result_name, amount = 1}} or nil,
  }
end

local function assert_resolution(recipe_name, prototype, expected_multiplier, expected_reason)
  local multiplier, reason = batch_rules.resolve(data_raw, recipe_name, prototype, config)
  assert_eq(multiplier, expected_multiplier, recipe_name .. " multiplier")
  assert_eq(reason, expected_reason, recipe_name .. " reason")
end

test("fluid-only recipes are immutable 1x", function()
  local prototype = recipe("fluid-recipe", "test-fluid", {result_type = "fluid"})
  prototype.main_product = "test-fluid"
  prototype.results[#prototype.results + 1] = {
    type = "item",
    name = "standard-item",
    amount = 1,
    probability = 0.5,
  }
  assert_resolution("fluid-recipe", prototype, 1, "fluid-only")
end)

test("modules are immutable 1x", function()
  assert_resolution("module-recipe", recipe("module-recipe", "test-module"), 1, "module")
end)

test("equipment uses Factorio's place_as_equipment_result field", function()
  assert_resolution("equipment-recipe", recipe("equipment-recipe", "equipment"), 1, "equipment")
end)

test("recipes consuming or producing biters are immutable 1x", function()
  local prototype = recipe("biter-recipe", "standard-item", {
    ingredients = {{type = "item", name = "biter-worker", amount = 1}},
  })
  assert_resolution("biter-recipe", prototype, 1, "biter-related")
end)

test("non-stackable results are immutable 1x", function()
  assert_resolution("unique-recipe", recipe("unique-recipe", "unique-item"), 1, "non-stackable")
end)

test("declared Space Age exceptions are immutable 1x", function()
  config.unbatched_result_names["space-widget"] = true
  assert_resolution("space-widget-exception", recipe("space-widget-exception", "space-widget"), 1, "unbatched-result")
  config.unbatched_result_names["space-widget"] = nil
end)

test("explicit intermediate economics override ordinary defaults", function()
  assert_resolution("intermediate-recipe", recipe("intermediate-recipe", "intermediate"), 10, "explicit")
end)

test("Space Age content defaults to 1x but explicit intermediates can opt in", function()
  assert_resolution("space-widget-recipe", recipe("space-widget-recipe", "space-widget", {subgroup = "space-processing"}), 1, "space-default")
  assert_resolution("space-intermediate-recipe", recipe("space-intermediate-recipe", "space-intermediate", {subgroup = "space-processing"}), 5, "explicit")
end)

test("placeable production buildings default to 2x", function()
  assert_resolution("factory-recipe", recipe("factory-recipe", "factory"), 2, "production-building")
end)

test("repeatable tool buildings default to 5x", function()
  assert_resolution("belt-recipe", recipe("belt-recipe", "belt"), 5, "tool-building")
end)

test("high-end tool buildings can opt down to 2x", function()
  assert_resolution("high-end-belt-recipe", recipe("high-end-belt-recipe", "high-end-belt"), 2, "explicit")
end)

test("ordinary items retain the 5x economic default", function()
  assert_resolution("standard-recipe", recipe("standard-recipe", "standard-item"), 5, "standard-item")
end)

test("recipes without products are not multiplied", function()
  assert_resolution("empty-recipe", recipe("empty-recipe"), 1, "no-results")
end)

if failed > 0 then
  io.stderr:write(table.concat(errors, "\n") .. "\n")
  io.stderr:write(string.format("%d passed, %d failed\n", passed, failed))
  os.exit(1)
end

print(string.format("%d batch rule tests passed", passed))
