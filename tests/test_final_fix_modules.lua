-------------------------------------------------------------------------------
-- Direct tests for final-fix passes that do not need the full data-stage mock.
-------------------------------------------------------------------------------

local passed, failed, errors = 0, 0, {}
local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then passed = passed + 1 else failed = failed + 1; errors[#errors + 1] = name .. ": " .. tostring(err) end
end
local function assert_true(value, message) if not value then error(message or "assertion failed", 2) end end
local function assert_eq(actual, expected, message)
  if actual ~= expected then error((message or "") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)"):gsub("tests/$", "")
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

util = {table = {deepcopy = function(value)
  if type(value) ~= "table" then return value end
  local copy = {}
  for key, entry in pairs(value) do copy[key] = util.table.deepcopy(entry) end
  return copy
end}}
kg, grams, tons = 1, 0.001, 1000

local function ingredient_names(recipe)
  local names = {}
  for _, ingredient in ipairs(recipe.ingredients or {}) do names[ingredient.name or ingredient[1]] = true end
  return names
end

test("science-pack stripping removes item packs at every recipe level", function()
  local stripping = require("prototypes.final_fixes.science_pack_stripping")
  local data = {raw = {
    item = {}, tool = {science = {name = "science", subgroup = "science-pack"}},
    recipe = {sample = {ingredients = {{type = "item", name = "science"}, {type = "fluid", name = "water"}},
      normal = {ingredients = {{type = "item", name = "science"}}},
      expensive = {ingredients = {{type = "item", name = "science"}}}}},
  }}
  stripping.apply(data, {"item", "tool"})
  assert_eq(#data.raw.recipe.sample.ingredients, 1)
  assert_eq(#data.raw.recipe.sample.normal.ingredients, 0)
  assert_eq(#data.raw.recipe.sample.expensive.ingredients, 0)
  stripping.apply(data, {"item", "tool"})
  assert_eq(#data.raw.recipe.sample.ingredients, 1, "stripping should be idempotent")
end)

test("unstaffed operation gating discovers categories and preserves managed machines", function()
  local gating = require("prototypes.final_fixes.unstaffed_operations_gating")
  local data = {raw = {
    ["module-category"] = {speed = {}, productivity = {}, ["unstaffed-operations"] = {}},
    ["assembling-machine"] = {
      printer = {name = "printer", module_slots = 2},
      managed = {name = "managed", module_slots = 2},
      empty = {name = "empty", module_slots = 0},
    },
  }}
  gating.apply(data, {"managed"})
  assert_eq(#data.raw["assembling-machine"].printer.allowed_module_categories, 2)
  assert_eq(data.raw["assembling-machine"].printer.allowed_module_categories[1], "productivity")
  assert_true(data.raw["assembling-machine"].managed.allowed_module_categories == nil)
  gating.apply(data, {"managed"})
  assert_eq(#data.raw["assembling-machine"].printer.allowed_module_categories, 2, "gating should be idempotent")
end)

test("space platform permits replace all paperwork and are idempotent", function()
  local permits = require("prototypes.final_fixes.space_platform_permits")
  local shared = {SPACE_PLATFORM_BUILDING_RECIPES = {platform = true}, PAPERWORK_ITEMS = {permit = true, order = true}}
  local data = {raw = {
    recipe = {platform = {ingredients = {{type = "item", name = "permit"}, {type = "item", name = "steel"}}}},
    item = {platform = {subgroup = "space-platform", place_result = "platform"}},
  }}
  local helpers = {
    ingredient_name = function(ingredient) return ingredient.name or ingredient[1] end,
    append_or_merge_ingredient = function(list, ingredient)
      for _, existing in ipairs(list) do
        if (existing.name or existing[1]) == (ingredient.name or ingredient[1]) then return end
      end
      list[#list + 1] = ingredient
    end,
  }
  permits.apply(data, shared, {"item"}, helpers)
  local names = ingredient_names(data.raw.recipe.platform)
  assert_true(names["orbital-infrastructure-permit"])
  assert_true(not names.permit)
  permits.apply(data, shared, {"item"}, helpers)
  assert_eq(#data.raw.recipe.platform.ingredients, 2, "platform permit pass should be idempotent")
end)

test("rocket weights apply defaults and explicit overrides", function()
  local weights = require("prototypes.final_fixes.rocket_weights")
  data = {raw = {item = {
    ["blank-form"] = {name = "blank-form", subgroup = "forms-permits"},
    ["construction-work-order"] = {name = "construction-work-order"},
    ["paper"] = {name = "paper"},
    ["biter-worker"] = {name = "biter-worker"},
  }, tool = {}, ammo = {}}}
  weights.apply()
  assert_eq(data.raw.item["blank-form"].weight, 1 * kg)
  assert_eq(data.raw.item["construction-work-order"].weight, 3 * kg)
  assert_eq(data.raw.item.paper.weight, 100 * grams)
  assert_eq(data.raw.item["biter-worker"].weight, 100 * kg)
  weights.apply()
  assert_eq(data.raw.item["construction-work-order"].weight, 3 * kg, "weight pass should be idempotent")
end)

test("collision masks add the admin layer and module categories without duplication", function()
  local masks = require("prototypes.final_fixes.collision_masks")
  data = {raw = {
    item = {}, ["module-category"] = {speed = {}, productivity = {}},
    chest = {box = {name = "box", type = "container", collision_mask = {"item"}, collision_box = {{-1, -1}, {1, 1}}, module_slots = 1}},
    character = {character = {name = "character", collision_mask = {"player"}, collision_box = {{-1, -1}, {1, 1}}}},
  }}
  masks.apply(data, true)
  assert_true(data.raw.chest.box.collision_mask.layers.administratorio_station_footprint)
  assert_eq(#data.raw.chest.box.allowed_module_categories, 2)
  masks.apply(data, true)
  assert_eq(#data.raw.chest.box.allowed_module_categories, 2, "collision pass should be idempotent")
end)

print(("Final-fix module tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then for _, err in ipairs(errors) do print(" - " .. err) end; os.exit(1) end
