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
    error((msg or "") .. " expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function assert_true(value, msg)
  if not value then
    error(msg or "assertion failed", 2)
  end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

local merge = require("prototypes.factoriopedia_merge")

test("rename map only includes unique canonical product recipes", function()
  local data_raw = {
    recipe = {
      ["paper-production"] = {
        type = "recipe",
        name = "paper-production",
        results = {{type = "item", name = "paper", amount = 5}},
      },
      ["copy-blank-form"] = {
        type = "recipe",
        name = "copy-blank-form",
        main_product = "blank-form",
        results = {
          {type = "item", name = "blank-form", amount = 6},
        },
      },
      ["blank-form-production"] = {
        type = "recipe",
        name = "blank-form-production",
        results = {{type = "item", name = "blank-form", amount = 2}},
      },
      ["good-excuse-production"] = {
        type = "recipe",
        name = "good-excuse-production",
        main_product = "good-excuse",
        results = {
          {type = "item", name = "good-excuse", amount = 1},
          {type = "item", name = "office-drama", amount = 1, probability = 0.5},
        },
      },
      ["good-excuse-recycling"] = {
        type = "recipe",
        name = "good-excuse-recycling",
        results = {{type = "item", name = "good-excuse", amount = 1}},
      },
    },
    technology = {},
    item = {
      paper = {},
      ["blank-form"] = {},
      ["good-excuse"] = {},
      ["office-drama"] = {},
    },
    fluid = {},
    tool = {},
    module = {},
    capsule = {},
    ammo = {},
    gun = {},
    armor = {},
    ["selection-tool"] = {},
    ["item-with-entity-data"] = {},
    ["rail-planner"] = {},
    ["spidertron-remote"] = {},
  }

  local shared = {
    FORM_PRODUCTION_RECIPES = {},
    COMBINED_FORM_PRODUCTION_RECIPES = {},
    is_admin_recipe = function(name)
      return name ~= "paper-production"
    end,
  }

  local rename_map = merge.build_recipe_rename_map(data_raw, shared)

  assert_eq(rename_map["paper-production"], "paper", "paper should merge into its item page")
  assert_eq(rename_map["good-excuse-production"], "good-excuse", "main-product recipe should merge")
  assert_true(rename_map["good-excuse-recycling"] == nil, "Quality recycling must not veto or receive a canonical rename")
  assert_true(rename_map["blank-form-production"] == nil, "blank-form has alternate recipes, so skip rename")
  assert_true(rename_map["copy-blank-form"] == nil, "alternate blank-form recipe should stay separate")
end)

test("apply_recipe_renames updates recipes, technologies, and shared maps", function()
  local data_raw = {
    recipe = {
      ["safety-waiver-printing"] = {
        type = "recipe",
        name = "safety-waiver-printing",
        results = {{type = "item", name = "safety-waiver", amount = 1}},
      },
    },
    technology = {
      automation = {
        effects = {
          {type = "unlock-recipe", recipe = "safety-waiver-printing"},
        },
      },
    },
  }

  local shared = {
    FORM_PRODUCTION_RECIPES = {
      ["safety-waiver"] = "safety-waiver-printing",
    },
    COMBINED_FORM_PRODUCTION_RECIPES = {},
  }

  merge.apply_recipe_renames(data_raw, shared, {
    ["safety-waiver-printing"] = "safety-waiver",
  })

  assert_true(data_raw.recipe["safety-waiver-printing"] == nil, "old recipe key should be removed")
  assert_true(data_raw.recipe["safety-waiver"] ~= nil, "renamed recipe should exist")
  assert_eq(data_raw.recipe["safety-waiver"].name, "safety-waiver", "recipe name should update")
  assert_eq(data_raw.technology.automation.effects[1].recipe, "safety-waiver", "tech unlock should retarget")
  assert_eq(shared.FORM_PRODUCTION_RECIPES["safety-waiver"], "safety-waiver", "shared map should retarget")
end)

print(("Factoriopedia merge tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
