-------------------------------------------------------------------------------
-- ADMINISTRATORIO RECIPE TESTS
--
-- Standalone Lua tests that verify the mod's core design invariants.
-- Run: lua tests/test_recipes.lua
--
-- These tests load the actual recipe/shared files through a minimal Factorio
-- data-stage mock, then assert properties about every recipe definition.
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
    error((msg or "") .. " — expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function assert_true(value, msg)
  if not value then error(msg or "assertion failed", 2) end
end

local function assert_false(value, msg)
  if value then error(msg or "assertion failed", 2) end
end

local function assert_nil(value, msg)
  if value ~= nil then error((msg or "expected nil") .. ", got " .. tostring(value), 2) end
end

local function assert_contains(tbl, key, msg)
  if not tbl[key] then error((msg or "missing key") .. ": " .. tostring(key), 2) end
end

-------------------------------------------------------------------------------
-- 1. MOCK FACTORIO DATA STAGE
-------------------------------------------------------------------------------
-- Minimal mock of the Factorio data environment so we can require() mod files.
local recipes = {}
local all_prototypes = {}

-- Mock data table
data = {
  raw = {
    recipe = recipes,
    character = {
      character = {
        crafting_categories = {"crafting"},
      },
    },
    ["assembling-machine"] = {
      ["assembling-machine-1"] = { crafting_categories = {"crafting"} },
      ["assembling-machine-2"] = { crafting_categories = {"crafting", "advanced-crafting", "crafting-with-fluid"} },
      ["assembling-machine-3"] = { crafting_categories = {"crafting", "advanced-crafting", "crafting-with-fluid"} },
    },
    ["recipe-category"] = {},
    ["module-category"] = {},
    ["fuel-category"] = {},
    technology = {},
    fluid = {},
    item = {},
    tool = {},
    module = {},
    capsule = {},
  },
}

function data:extend(prototypes)
  for _, proto in ipairs(prototypes) do
    if proto.type and data.raw[proto.type] then
      data.raw[proto.type][proto.name] = proto
    end
    if proto.type == "recipe" then
      recipes[proto.name] = proto
    elseif proto.type == "recipe-category" then
      data.raw["recipe-category"][proto.name] = proto
    elseif proto.type == "module-category" then
      data.raw["module-category"][proto.name] = proto
    end
    all_prototypes[#all_prototypes + 1] = proto
  end
end

-- Mock util (used by data-final-fixes)
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

-- Also provide table.deepcopy used by some recipe files
if not table.deepcopy then
  table.deepcopy = util.table.deepcopy
end

-------------------------------------------------------------------------------
-- 2. LOAD MOD FILES
-------------------------------------------------------------------------------
-- Adjust package.path so require("prototypes.shared") works
local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

local function load_locale_section(section_name)
  local path = mod_root .. "locale/en/config.cfg"
  local section = nil
  local values = {}

  for line in io.lines(path) do
    local header = line:match("^%[([^%]]+)%]$")
    if header then
      section = header
    elseif section == section_name then
      local key, value = line:match("^([^=]+)=(.*)$")
      if key then
        values[key] = value
      end
    end
  end

  return values
end

local recipe_name_locale = load_locale_section("recipe-name")

-- Load categories first (defines recipe-categories + sets up character)
dofile(mod_root .. "prototypes/categories.lua")

-- Load core item prototypes used by recipe assertions.
dofile(mod_root .. "prototypes/item/economy.lua")

-- Load all recipe files
dofile(mod_root .. "prototypes/recipe/paperwork.lua")
dofile(mod_root .. "prototypes/recipe/buildings.lua")
dofile(mod_root .. "prototypes/recipe/production.lua")
dofile(mod_root .. "prototypes/recipe/economy.lua")
dofile(mod_root .. "prototypes/recipe/resolution.lua")
dofile(mod_root .. "prototypes/recipe/modules.lua")

-- Mirror the recipe loader's post-pass that supplies the printer paper masks.
require("prototypes.shared.printing_tints").apply(recipes)

-- Load shared constants
local shared = require("prototypes.shared")

-- Mirror data.lua's recipe-ownership registration for this focused recipe
-- fixture, which loads Administratorio recipe files directly.
for recipe_name in pairs(recipes) do
  shared.register_admin_recipe(recipe_name)
end

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

local function count_fluid_ingredients(recipe)
  if not recipe or not recipe.ingredients then return 0 end
  local count = 0
  for _, ing in ipairs(recipe.ingredients) do
    if ing.type == "fluid" then
      count = count + 1
    end
  end
  return count
end

local function get_result_name(recipe)
  if recipe.results and recipe.results[1] then
    return recipe.results[1].name or recipe.results[1][1]
  end
  return recipe.result
end

local function get_result_amount(recipe, item_name)
  if not recipe then return nil end
  if not recipe.results then
    if recipe.result == item_name then return recipe.result_count or 1 end
    return nil
  end
  for _, res in ipairs(recipe.results) do
    if (res.name or res[1]) == item_name then
      return res.amount or res[2]
    end
  end
  return nil
end

local function get_result_probability(recipe, item_name)
  if not recipe or not recipe.results then return nil end
  for _, res in ipairs(recipe.results) do
    if (res.name or res[1]) == item_name then
      return res.probability
    end
  end
  return nil
end

-------------------------------------------------------------------------------
-- 3. TESTS
-------------------------------------------------------------------------------

-- =========================================================================
-- PRINCIPLE 1: FORMS ARE THE CURRENCY OF AUTOMATION
-- =========================================================================

test("every printer recipe supplies a crafting-machine tint", function()
  local printing_categories = {
    ["printing"] = true,
    ["printing-advanced"] = true,
    ["printing-workorder"] = true,
  }

  for recipe_name, recipe in pairs(recipes) do
    if printing_categories[recipe.category] then
      local tint = recipe.crafting_machine_tint
      assert_true(tint and tint.primary,
        recipe_name .. " is missing the primary printer-paper tint")
    end
  end
end)

test("selected document families use distinct printer-paper colors", function()
  local function tint_key(recipe_name)
    local color = recipes[recipe_name].crafting_machine_tint.primary
    return string.format("%.4f/%.4f/%.4f", color.r, color.g, color.b)
  end

  local approval = tint_key("blank-approval-production")
  local directive = tint_key("blank-directive-production")
  local construction = tint_key("construction-permit-printing")
  local environmental = tint_key("copy-environmental-impact-report")

  assert_false(approval == directive, "approval and directive paper colors must differ")
  assert_false(directive == construction, "directive and construction paper colors must differ")
  assert_false(construction == environmental, "construction and environmental paper colors must differ")
end)

test("shared.PAPERWORK_ITEMS contains all core forms", function()
  local expected = {
    "work-order", "safety-waiver", "construction-permit",
    "management-approval-verbal", "management-approval-written",
    "research-grant-approval", "provisional-approval",
    "blank-form", "blank-approval", "blank-directive",
    "form-27b-6", "carbon-offset-certificate-basic",
    "chemical-handling-work-order", "radiological-work-order",
  }
  for _, name in ipairs(expected) do
    assert_contains(shared.PAPERWORK_ITEMS, name, "PAPERWORK_ITEMS missing")
  end
end)

test("shared.COMBINED_FORMS maps all tier forms correctly", function()
  assert_eq(shared.COMBINED_FORMS["safety-waiver"], "safety-work-order")
  assert_eq(shared.COMBINED_FORMS["construction-permit"], "construction-work-order")
  assert_eq(shared.COMBINED_FORMS["management-approval-verbal"], "management-verbal-work-order")
  assert_eq(shared.COMBINED_FORMS["management-approval-written"], "management-written-work-order")
  assert_eq(shared.COMBINED_FORMS["research-grant-approval"], "research-grant-work-order")
end)

test("combined form production recipes exist and scale with multiple work-orders", function()
  local combos = {
    {"safety-work-order-production", "safety-waiver", "work-order", 2},
    {"construction-work-order-production", "construction-permit", "work-order", 2},
    {"management-verbal-work-order-production", "management-approval-verbal", "work-order", 2},
    {"management-written-work-order-production", "management-approval-written", "work-order", 2},
    {"research-grant-work-order-production", "research-grant-approval", "work-order", 2},
  }
  for _, combo in ipairs(combos) do
    local r = get_recipe(combo[1])
    assert_true(r ~= nil, combo[1] .. " recipe missing")
    assert_true(has_ingredient(r, combo[2]), combo[1] .. " missing " .. combo[2])
    assert_true(has_ingredient(r, combo[3]), combo[1] .. " missing " .. combo[3])
    assert_eq(get_ingredient_amount(r, combo[3]), combo[4], combo[1] .. " should scale work-order demand")
    assert_eq(r.category, "bureaucracy-registration", combo[1] .. " wrong category")
  end
  assert_true(has_ingredient(get_recipe("management-written-work-order-production"), "management-approval-verbal"),
    "management-written-work-order-production should include the lower-tier verbal approval")
end)

-- =========================================================================
-- PRINCIPLE 2: BATCH SIZING CONTROLS FORM CONSUMPTION
-- =========================================================================

-- =========================================================================
-- PRINCIPLE 3: INK ON PAPER = PRINTER ONLY
-- =========================================================================

test("blank-form-production requires ink and uses printing category", function()
  local r = get_recipe("blank-form-production")
  assert_true(r ~= nil, "recipe missing")
  assert_eq(r.category, "printing")
  assert_true(has_ingredient(r, "ink"), "missing ink")
  assert_true(has_ingredient(r, "paper"), "missing paper")
end)

test("blank-approval-production requires ink and uses printing category", function()
  local r = get_recipe("blank-approval-production")
  assert_eq(r.category, "printing")
  assert_true(has_ingredient(r, "ink"))
  assert_true(has_ingredient(r, "paper"))
end)

test("blank-directive-production requires ink and uses printing category", function()
  local r = get_recipe("blank-directive-production")
  assert_eq(r.category, "printing")
  assert_true(has_ingredient(r, "ink"))
  assert_true(has_ingredient(r, "paper"))
end)

test("all printer recipes contain ink", function()
  for name, recipe in pairs(recipes) do
    local category = recipe.category
    if category == "printing" or category == "printing-workorder" or category == "printing-advanced" then
      assert_true(has_ingredient(recipe, "ink"), name .. " is a printer recipe but has no ink")
    end
  end
end)

test("non-printer recipes do not consume ink", function()
  for name, recipe in pairs(recipes) do
    local category = recipe.category
    if category ~= "printing" and category ~= "printing-workorder" and category ~= "printing-advanced"
      and category ~= "pneumatic-intake" then
      assert_true(not has_ingredient(recipe, "ink"), name .. " should not consume ink outside a printer")
    end
  end
end)

test("all copy recipes use printing-advanced category", function()
  local copies = {
    "copy-blank-form", "copy-blank-approval", "copy-blank-directive",
    "copy-carbon-offset-certificate", "copy-form-27b-6",
    "copy-environmental-impact-report",
    "copy-work-order", "copy-safety-work-order", "copy-construction-work-order",
    "copy-management-verbal-work-order", "copy-management-written-work-order",
    "copy-research-grant-work-order", "copy-chemical-handling-work-order",
    "copy-radiological-work-order",
  }
  for _, name in ipairs(copies) do
    local r = get_recipe(name)
    assert_true(r ~= nil, name .. " missing")
    assert_eq(r.category, "printing-advanced", name .. " wrong category")
    assert_true(has_ingredient(r, "ink"), name .. " missing ink")
    assert_true(has_ingredient(r, "paper"), name .. " missing paper")
  end
end)

test("printer recipes only accept paper forms and ink", function()
  local function allowed_printer_input(name, category)
    if name == "paper" or name == "ink" or shared.PAPERWORK_ITEMS[name] == true then
      return true
    end
    if category == "printing-advanced" and (name == "advanced-circuit" or name == "processing-unit") then
      return true
    end
    return false
  end

  for recipe_name, recipe in pairs(recipes) do
    local category = recipe.category
    if category == "printing" or category == "printing-workorder" or category == "printing-advanced" then
      for _, ingredient in ipairs(recipe.ingredients or {}) do
        local ingredient_name = ingredient.name or ingredient[1]
        assert_true(allowed_printer_input(ingredient_name, category),
          recipe_name .. " should not send " .. ingredient_name .. " through a printer")
      end
    end
  end
end)

test("standard copy recipes require advanced circuits", function()
  local copies = {
    "copy-blank-form", "copy-blank-approval", "copy-blank-directive",
    "copy-carbon-offset-certificate", "copy-form-27b-6",
    "copy-environmental-impact-report",
  }
  for _, name in ipairs(copies) do
    local r = get_recipe(name)
    assert_true(r ~= nil, name .. " missing")
    assert_true(has_ingredient(r, "advanced-circuit"), name .. " missing advanced-circuit")
  end
end)

test("copy recipes define explicit recipe localisation keys", function()
  local copies = {
    "copy-blank-form", "copy-blank-approval", "copy-blank-directive",
    "copy-carbon-offset-certificate", "copy-form-27b-6",
    "copy-environmental-impact-report",
    "copy-work-order", "copy-safety-work-order", "copy-construction-work-order",
    "copy-management-verbal-work-order", "copy-management-written-work-order",
    "copy-research-grant-work-order", "copy-chemical-handling-work-order",
    "copy-radiological-work-order",
  }
  for _, name in ipairs(copies) do
    local r = get_recipe(name)
    assert_true(r ~= nil, name .. " missing")
    assert_true(type(r.localised_name) == "table", name .. " missing localised_name")
    assert_eq(r.localised_name[1], "recipe-name." .. name, name .. " wrong localised_name")
  end
end)

-- =========================================================================
-- PRINCIPLE 4: EVERY FORM HAS A PRINTER STEP
-- =========================================================================

test("safety-waiver requires 2-step printing pipeline", function()
  local draft = get_recipe("safety-waiver-draft")
  assert_true(draft ~= nil)
  assert_eq(draft.category, "bureaucratic-bootstrap", "draft should be handcraftable")
  assert_true(has_ingredient(draft, "blank-approval"))

  local print_step = get_recipe("safety-waiver-printing")
  assert_true(print_step ~= nil)
  assert_eq(print_step.category, "printing")
  assert_true(has_ingredient(print_step, "safety-waiver-draft"))
  assert_true(has_ingredient(print_step, "ink"))
  assert_eq(get_result_amount(print_step, "safety-waiver"), 2)
end)

test("construction-permit requires 2-step printing pipeline", function()
  local draft = get_recipe("construction-permit-draft")
  assert_true(draft ~= nil)
  assert_eq(draft.category, "bureaucratic-bootstrap")
  assert_true(has_ingredient(draft, "blank-approval"))

  local print_step = get_recipe("construction-permit-printing")
  assert_true(print_step ~= nil)
  assert_eq(print_step.category, "printing")
  assert_true(has_ingredient(print_step, "construction-permit-draft"))
  assert_true(has_ingredient(print_step, "ink"))
  assert_eq(get_result_amount(print_step, "construction-permit"), 2)
end)

test("old petition approval recipes are removed", function()
  assert_true(get_recipe("safety-waiver-approval") == nil, "safety approval should be removed")
  assert_true(get_recipe("construction-permit-approval") == nil, "construction approval should be removed")
  assert_true(get_recipe("radiological-work-order-approval") == nil, "radiological approval should be removed")
end)

test("management-approval-verbal requires 2-step pipeline (gossip + printing)", function()
  local draft = get_recipe("management-verbal-draft")
  assert_true(draft ~= nil)
  assert_eq(draft.category, "watercooler-gossip")
  assert_true(has_ingredient(draft, "blank-directive"))

  local print_step = get_recipe("management-verbal-printing")
  assert_eq(print_step.category, "printing")
  assert_true(has_ingredient(print_step, "management-verbal-draft"))
  assert_true(has_ingredient(print_step, "ink"))
  assert_true(has_ingredient(print_step, "paper"))
  assert_true(not has_ingredient(print_step, "form-27b-6"))
end)

test("management-approval-written requires 2-step pipeline", function()
  local proposal = get_recipe("management-written-proposal")
  assert_true(proposal ~= nil)
  assert_eq(proposal.category, "bureaucracy-policy")
  assert_true(has_ingredient(proposal, "blank-directive"))
  assert_true(has_ingredient(proposal, "advanced-circuit"))

  local first = get_recipe("management-written-1st-printing")
  assert_eq(first.category, "printing")
  assert_true(has_ingredient(first, "management-written-proposal"))
  assert_true(has_ingredient(first, "ink"))
  assert_true(has_ingredient(first, "form-27b-6"))
  assert_true(has_ingredient(first, "paper"))
  assert_true(get_result_amount(first, "management-approval-written") == 1)
end)

-- =========================================================================
-- PRINCIPLE 5: HANDCRAFTING IS LIMITED
-- =========================================================================

-- The player character has the "bureaucratic-bootstrap" category.
-- Recipes in that category with enabled=true are hand-craftable from the start.
-- Recipes with enabled=false need a tech unlock first.

test("player character has bureaucratic-bootstrap crafting category", function()
  local cats = data.raw.character.character.crafting_categories
  local found = false
  for _, c in ipairs(cats) do
    if c == "bureaucratic-bootstrap" then found = true end
  end
  assert_true(found, "character missing bureaucratic-bootstrap")
end)

test("only bootstrap-safe handcraft recipes start enabled", function()
  local handcraftable_from_start = {
    "paper-production",
    "ink-production",
    "carbon-offset-certificate-basic",
  }
  for _, name in ipairs(handcraftable_from_start) do
    local r = get_recipe(name)
    assert_true(r ~= nil, name .. " missing")
    assert_true(r.enabled == true, name .. " should be enabled from start")
    -- Must be in a player-accessible category (nil/crafting or bureaucratic-bootstrap)
    local cat = r.category or "crafting"
    assert_true(cat == "crafting" or cat == "bureaucratic-bootstrap",
      name .. " in non-handcraftable category: " .. cat)
  end
end)

test("work-order-production is NOT enabled from start (needs Automation tech)", function()
  local r = get_recipe("work-order-production")
  assert_true(r ~= nil)
  assert_eq(r.enabled, false, "work-order should be disabled by default")
  assert_eq(r.category, "bureaucratic-bootstrap", "work-order should be handcraftable category")
end)

test("provisional-approval requires tech unlock", function()
  local r = get_recipe("provisional-approval-production")
  assert_eq(r.enabled, false)
  assert_eq(r.category, "bureaucracy-registration")
end)

test("management/policy recipes are NOT handcraftable", function()
  local machine_only = {
    "management-verbal-draft",
    "management-written-proposal",
    "treasury-bond-production",
    "government-grant-production",
    "policy-production",
    "regulation-production",
    "narrative-production",
  }
  for _, name in ipairs(machine_only) do
    local r = get_recipe(name)
    assert_true(r ~= nil, name .. " missing")
    local cat = r.category or "crafting"
    assert_true(cat ~= "crafting" and cat ~= "bureaucratic-bootstrap",
      name .. " should NOT be in a handcraftable category, is: " .. cat)
  end
end)

test("blank-directive is NOT enabled (requires tech)", function()
  local r = get_recipe("blank-directive-production")
  assert_eq(r.enabled, false)
end)

-- =========================================================================
-- PRINCIPLE 6: AMs CANNOT CRAFT FORMS
-- =========================================================================

test("form production recipes use admin-only categories", function()
  local admin_categories = {
    ["bureaucracy-registration"] = true,
    ["bureaucratic-bootstrap"] = true,
    ["printing"] = true,
    ["printing-advanced"] = true,
    ["printing-workorder"] = true,
    ["bureaucracy-resolution"] = true,
    ["bureaucracy-policy"] = true,
    ["watercooler-gossip"] = true,
    ["union-negotiation"] = true,
    ["admin-greenhouse"] = true,
    ["propaganda-distillery"] = true,
    ["smelting-basic"] = true,
    ["chemistry"] = true,  -- synthetic paper
  }
  for form_name, recipe_name in pairs(shared.FORM_PRODUCTION_RECIPES) do
    local r = get_recipe(recipe_name)
    assert_true(r ~= nil, recipe_name .. " missing")
    local cat = r.category or "crafting"
    assert_true(admin_categories[cat],
      recipe_name .. " uses AM-accessible category: " .. cat)
  end
end)

-- =========================================================================
-- PRINCIPLE 7: ALL BUILDINGS NEED FORMS (building recipes)
-- =========================================================================

test("admin-station requires provisional-approval", function()
  local r = get_recipe("admin-station")
  assert_true(has_ingredient(r, "provisional-approval"))
end)

test("field-office bootstraps without provisional-approval", function()
  local r = get_recipe("field-office")
  assert_true(has_ingredient(r, "iron-plate"))
  assert_true(has_ingredient(r, "stone-brick"))
  assert_true(has_ingredient(r, "dubious-data"))
  assert_true(not has_ingredient(r, "provisional-approval"))
end)

test("resolution-office requires provisional-approval", function()
  local r = get_recipe("resolution-office")
  assert_true(has_ingredient(r, "provisional-approval"))
end)

test("printer-t1 requires provisional-approval", function()
  local r = get_recipe("printer-t1")
  assert_true(has_ingredient(r, "provisional-approval"))
end)

test("printer-t2 requires construction-permit printer-t1 and advanced-circuits", function()
  local r = get_recipe("printer-t2")
  assert_true(has_ingredient(r, "construction-permit"))
  assert_true(has_ingredient(r, "printer-t1"))
  assert_true(has_ingredient(r, "advanced-circuit"))
  assert_true(not has_ingredient(r, "electronic-circuit"))
end)

test("corporate-breakroom no longer depends on treasury-bonds", function()
  local r = get_recipe("corporate-breakroom")
  assert_true(has_ingredient(r, "construction-permit"))
  assert_true(not has_ingredient(r, "treasury-bond"))
end)

test("union-headquarters preserves paperwork without depending on its own production categories", function()
  local r = get_recipe("union-headquarters")
  local hq_only_categories = {
    ["union-negotiation"] = true,
    ["bureaucracy-policy"] = true,
  }
  local has_paperwork = false

  for _, ingredient in ipairs(r.ingredients or {}) do
    local ingredient_type = ingredient.type or "item"
    local ingredient_name = ingredient.name or ingredient[1]
    if ingredient_type == "item" then
      has_paperwork = has_paperwork or shared.PAPERWORK_ITEMS[ingredient_name] == true

      local has_producer = false
      local has_pre_hq_producer = false
      for _, producer in pairs(recipes) do
        if get_result_amount(producer, ingredient_name) then
          has_producer = true
          local category = producer.category or "crafting"
          if not hq_only_categories[category] then
            has_pre_hq_producer = true
          end
        end
      end

      assert_true(not has_producer or has_pre_hq_producer,
        "union-headquarters depends on its own production chain through " .. ingredient_name)
    end
  end

  assert_true(has_paperwork, "union-headquarters should participate in the paperwork economy")
end)

test("late policy recipes stay within the shared HQ fluid limits", function()
  for _, recipe_name in ipairs({
    "white-paper-production",
    "policy-production",
    "regulation-production",
  }) do
    local recipe = get_recipe(recipe_name)
    assert_true(recipe ~= nil, recipe_name .. " missing")
    assert_true(count_fluid_ingredients(recipe) <= 2,
      recipe_name .. " exceeds the union-headquarters two-fluid limit")
    assert_true(not has_ingredient(recipe, "slush-fund"),
      recipe_name .. " should no longer require slush-fund")
  end
end)

test("white-paper now uses a treasury-bond instead of slush-fund", function()
  local r = get_recipe("white-paper-production")
  assert_true(has_ingredient(r, "treasury-bond"))
  assert_eq(get_ingredient_amount(r, "treasury-bond"), 1)
  assert_true(not has_ingredient(r, "slush-fund"))
end)

-- =========================================================================
-- FORM TIER SYSTEM (get_required_form)
-- =========================================================================

test("T0 items: belts, cables, pipes use work-order", function()
  assert_eq(shared.get_required_form("transport-belt"), "work-order")
  assert_eq(shared.get_required_form("copper-cable"), "work-order")
  assert_eq(shared.get_required_form("pipe"), "work-order")
  assert_eq(shared.get_required_form("iron-plate"), "work-order")
  assert_eq(shared.get_required_form("small-electric-pole"), "work-order")
  assert_eq(shared.get_required_form("burner-inserter"), "work-order")
end)

test("T1 items: inserters, radar, walls use safety-waiver", function()
  assert_eq(shared.get_required_form("inserter"), "safety-waiver")
  assert_eq(shared.get_required_form("long-handed-inserter"), "safety-waiver")
  assert_eq(shared.get_required_form("fast-inserter"), "safety-waiver")
  assert_eq(shared.get_required_form("splitter"), "safety-waiver")
  assert_eq(shared.get_required_form("fast-splitter"), "safety-waiver")
  assert_eq(shared.get_required_form("express-splitter"), "safety-waiver")
  assert_eq(shared.get_required_form("radar"), "safety-waiver")
  assert_eq(shared.get_required_form("stone-wall"), "safety-waiver")
  assert_eq(shared.get_required_form("gate"), "safety-waiver")
  assert_eq(shared.get_required_form("boiler"), "safety-waiver")
  assert_eq(shared.get_required_form("steam-engine"), "safety-waiver")
  assert_eq(shared.get_required_form("assembling-machine-1"), "safety-waiver")
end)

test("T2 items: AM2, chemical-plant, elevated rail supports use construction-permit", function()
  assert_eq(shared.get_required_form("assembling-machine-2"), "construction-permit")
  assert_eq(shared.get_required_form("chemical-plant"), "construction-permit")
  assert_eq(shared.get_required_form("oil-refinery"), "construction-permit")
  assert_eq(shared.get_required_form("underground-belt"), "construction-permit")
  assert_eq(shared.get_required_form("rail"), "construction-permit")
  assert_eq(shared.get_required_form("rail-signal"), "construction-permit")
  assert_eq(shared.get_required_form("rail-chain-signal"), "construction-permit")
  assert_eq(shared.get_required_form("rail-ramp"), "construction-permit")
  assert_eq(shared.get_required_form("rail-support"), "construction-permit")
  assert_eq(shared.get_required_form("fast-transport-belt"), "construction-permit")
  assert_eq(shared.get_required_form("steel-furnace"), "construction-permit")
  assert_eq(shared.get_required_form("pumpjack"), "construction-permit")
end)

test("T2 special: lab and mining-drill use construction-permit", function()
  assert_eq(shared.get_required_form("lab"), "construction-permit")
  assert_eq(shared.get_required_form("electric-mining-drill"), "construction-permit")
  assert_eq(shared.get_required_form("burner-mining-drill"), "construction-permit")
end)

test("locomotive is safety-tier while heavy infrastructure stays management-verbal", function()
  assert_eq(shared.get_required_form("locomotive"), "safety-waiver")
  assert_eq(shared.get_required_form("roboport"), "management-approval-verbal")
  assert_eq(shared.get_required_form("solar-panel"), "management-approval-verbal")
  assert_eq(shared.get_required_form("accumulator"), "management-approval-verbal")
  assert_eq(shared.get_required_form("electric-furnace"), "management-approval-verbal")
end)

test("advanced circuit is elevated while engine unit falls back to baseline paperwork", function()
  assert_eq(shared.get_required_form("advanced-circuit"), "management-approval-verbal")
  assert_eq(shared.get_required_form("engine-unit"), "work-order")
end)

test("T4 items: AM3, centrifuge, rocket-silo, nuclear-reactor use management-approval-written", function()
  assert_eq(shared.get_required_form("assembling-machine-3"), "management-approval-written")
  assert_eq(shared.get_required_form("centrifuge"), "management-approval-written")
  assert_eq(shared.get_required_form("rocket-silo"), "management-approval-written")
  assert_eq(shared.get_required_form("nuclear-reactor"), "management-approval-written")
  assert_eq(shared.get_required_form("beacon"), "management-approval-written")
end)

test("science packs use research-grant-approval", function()
  assert_eq(shared.get_required_form("automation-science-pack"), "research-grant-approval")
  assert_eq(shared.get_required_form("logistic-science-pack"), "research-grant-approval")
  assert_eq(shared.get_required_form("chemical-science-pack"), "research-grant-approval")
end)

-- =========================================================================
-- MACHINE OPERATION PAPERWORK
-- =========================================================================

test("refinery recipes: basic oil-processing is exempt, advanced ops require chemical paperwork", function()
  assert_eq(shared.get_operating_form({name = "oil-processing", category = "oil-processing"}), nil)
  assert_eq(shared.get_operating_form({name = "advanced-oil-processing", category = "oil-processing"}), "chemical-handling-work-order")
  assert_eq(shared.get_operating_form({name = "coal-liquefaction", category = "oil-processing"}), "chemical-handling-work-order")
end)

test("chemistry recipes use chemical-handling-work-order", function()
  assert_eq(shared.get_operating_form({name = "plastic-bar", category = "chemistry"}), "chemical-handling-work-order")
  assert_eq(shared.get_operating_form({name = "sulfur", category = "chemistry"}), "chemical-handling-work-order")
  assert_eq(shared.get_operating_form({name = "sulfuric-acid", category = "chemistry"}), "chemical-handling-work-order")
  assert_eq(shared.get_operating_form({name = "solid-fuel-from-heavy-oil", category = "chemistry"}), "chemical-handling-work-order")
  assert_eq(shared.get_operating_form({name = "solid-fuel-from-light-oil", category = "chemistry"}), "chemical-handling-work-order")
  assert_eq(shared.get_operating_form({name = "solid-fuel-from-petroleum-gas", category = "chemistry"}), "chemical-handling-work-order")
end)

test("chemistry requires chemical-handling-work-order", function()
  assert_eq(shared.OPERATING_FORM_BY_CATEGORY["chemistry"], "chemical-handling-work-order")
end)

test("centrifuging requires radiological-work-order", function()
  assert_eq(shared.OPERATING_FORM_BY_CATEGORY["centrifuging"], "radiological-work-order")
end)

test("operating paperwork chain: chemical < radiological", function()
  local eir = get_recipe("environmental-impact-report")
  assert_eq(eir.category, "bureaucracy-registration")
  assert_true(has_ingredient(eir, "carbon-offset-certificate-verified"), "EIR should require verified carbon certificates")
  assert_true(not has_ingredient(eir, "barrel"), "EIR should no longer require barrels")

  local chem = get_recipe("chemical-handling-work-order-production")
  assert_eq(chem.category, "bureaucracy-registration")
  assert_true(has_ingredient(chem, "safety-waiver"), "chemical needs safety paperwork")
  assert_true(has_ingredient(chem, "environmental-impact-report"), "chemical needs environmental paperwork")
  assert_true(has_ingredient(chem, "form-27b-6"), "chemical needs Form 27B-6")
  assert_true(has_ingredient(chem, "useless-documentation"), "chemical needs useless documentation")
  assert_true(not has_ingredient(chem, "petrochemical-operating-permit"), "petro permits are removed")
  assert_true(not has_ingredient(chem, "barrel"), "chemical should not need barrels")
  assert_true(not has_ingredient(chem, "pipe"), "chemical should not need pipes")
  assert_true(not has_ingredient(chem, "construction-permit"), "chemical should not need construction paperwork")
  assert_true(not has_ingredient(chem, "management-approval-verbal"))
  assert_true(not has_ingredient(chem, "ink"))
  assert_eq(get_result_amount(chem, "chemical-handling-work-order"), 2)

  local radio = get_recipe("radiological-work-order-production")
  assert_eq(radio.category, "bureaucracy-registration")
  assert_true(has_ingredient(radio, "chemical-handling-work-order"), "radio needs chemical work order")
  assert_true(has_ingredient(radio, "management-approval-written"))
  assert_true(has_ingredient(radio, "battery"))
  assert_true(has_ingredient(radio, "steel-plate"))
  assert_true(not has_ingredient(radio, "ink"))
  assert_eq(get_result_amount(radio, "radiological-work-order"), 2)
end)

-- =========================================================================
-- BATCH SMELTING REQUIRES CARBON OFFSET CERTIFICATES
-- =========================================================================

test("all smelting-basic recipes require carbon-offset-certificate-basic", function()
  local smelting_recipes = {
    "iron-plate-batch", "copper-plate-batch", "steel-plate-batch",
    "stone-brick-batch", "dubious-data-batch", "compacted-rubble-production",
  }
  for _, name in ipairs(smelting_recipes) do
    local r = get_recipe(name)
    assert_true(r ~= nil, name .. " missing")
    assert_eq(r.category, "smelting-basic", name .. " wrong category")
    assert_true(has_ingredient(r, "carbon-offset-certificate-basic"),
      name .. " missing carbon offset certificate")
    assert_eq(r.ingredients[1].name, "carbon-offset-certificate-basic",
      name .. " should list the certificate first")
  end
end)

test("electric furnace compacts rubble without a carbon offset certificate", function()
  local r = get_recipe("compacted-rubble-electric")
  assert_true(r ~= nil, "compacted-rubble-electric missing")
  assert_eq(r.category, "smelting", "electric rubble recipe should use electric furnace smelting")
  assert_eq(r.enabled, false, "electric rubble recipe should be technology-gated")
  assert_true(has_ingredient(r, "redundant-rubble"), "electric rubble recipe missing redundant rubble")
  assert_eq(get_ingredient_amount(r, "redundant-rubble"), 1)
  assert_true(not has_ingredient(r, "carbon-offset-certificate-basic"),
    "electric rubble recipe should not require a carbon offset certificate")
  assert_eq(get_result_amount(r, "compacted-rubble"), 1)
  assert_eq(r.energy_required, 3.2)
  assert_eq(r.allow_decomposition, false)
  assert_eq(r.hidden_in_factoriopedia, true)
  assert_eq(r.factoriopedia_alternative, "compacted-rubble")
end)
test("starter furnace recipes are enabled from start", function()
  local starter_smelting_recipes = {
    "iron-plate-batch", "copper-plate-batch", "stone-brick-batch",
    "dubious-data-batch",
  }
  for _, name in ipairs(starter_smelting_recipes) do
    local r = get_recipe(name)
    assert_true(r ~= nil, name .. " missing")
    assert_eq(r.category, "smelting-basic", name .. " wrong category")
    assert_eq(r.enabled, true, name .. " should be enabled from start")
  end
end)

test("steel-plate-batch is locked behind steel-processing", function()
  local r = get_recipe("steel-plate-batch")
  assert_true(r ~= nil, "steel-plate-batch missing")
  assert_eq(r.category, "smelting-basic")
  assert_eq(r.enabled, false, "steel-plate-batch should not be enabled from start")
end)
test("charcoal-production requires carbon offset", function()
  local r = get_recipe("charcoal-production")
  assert_true(r ~= nil)
  assert_eq(r.category, "smelting-basic")
  assert_true(has_ingredient(r, "wood"))
  assert_eq(get_ingredient_amount(r, "wood"), 30)
  assert_eq(get_result_amount(r, "coal"), 8)
  assert_eq(r.energy_required, 30)
  assert_true(has_ingredient(r, "carbon-offset-certificate-basic"),
    "charcoal should need carbon offset")
  assert_eq(r.ingredients[1].name, "carbon-offset-certificate-basic",
    "charcoal should list the certificate first")
end)

test("batch smelting disables decomposition", function()
  local batch_recipes = {"iron-plate-batch", "copper-plate-batch", "stone-brick-batch", "dubious-data-batch"}
  for _, name in ipairs(batch_recipes) do
    local r = get_recipe(name)
    assert_eq(r.allow_decomposition, false, name .. " should disable decomposition")
  end
end)

-- =========================================================================
-- RESOLUTION PIPELINE (filing -> case -> brief -> final)
-- =========================================================================

test("all filing recipes require blank-form and use expected categories", function()
  local filings = {
    {"filing-landscape", "resolution-handcraft"},
    {"filing-smog", "bureaucracy-resolution"},
    {"filing-noise", "bureaucracy-resolution"},
    {"filing-unemployment", "bureaucracy-resolution"},
    {"filing-littering", "bureaucracy-resolution"},
    {"filing-hazmat", "bureaucracy-resolution"},
    {"filing-loitering", "bureaucracy-resolution"},
    {"filing-vagrancy", "bureaucracy-resolution"},
  }
  for _, entry in ipairs(filings) do
    local name = entry[1]
    local expected_category = entry[2]
    local r = get_recipe(name)
    assert_true(r ~= nil, name .. " missing")
    assert_eq(r.category, expected_category, name .. " wrong category")
    assert_true(has_ingredient(r, "blank-form"), name .. " missing blank-form")
  end
end)

test("filing recipes require the correct ticket type", function()
  local ticket_map = {
    ["filing-landscape"] = "ticket-landscape",
    ["filing-smog"] = "ticket-smog",
    ["filing-noise"] = "ticket-noise",
    ["filing-unemployment"] = "ticket-unemployment",
    ["filing-littering"] = "ticket-littering",
    ["filing-hazmat"] = "ticket-hazmat",
    ["filing-loitering"] = "ticket-loitering",
    ["filing-vagrancy"] = "ticket-vagrancy",
  }
  for recipe_name, ticket in pairs(ticket_map) do
    local r = get_recipe(recipe_name)
    assert_true(has_ingredient(r, ticket), recipe_name .. " missing " .. ticket)
  end
end)

test("complaint pipeline escalation times increase with severity", function()
  -- Biter complaints: landscape(5) < smog(10) < noise(15) < unemployment(20)
  local biter_filings = {
    {"filing-landscape", 5}, {"filing-smog", 10},
    {"filing-noise", 15}, {"filing-unemployment", 20},
  }
  for _, pair in ipairs(biter_filings) do
    local r = get_recipe(pair[1])
    assert_eq(r.energy_required, pair[2], pair[1] .. " wrong time")
  end

  -- Spitter complaints: littering(5) < hazmat(10) < loitering(15) < vagrancy(20)
  local spitter_filings = {
    {"filing-littering", 5}, {"filing-hazmat", 10},
    {"filing-loitering", 15}, {"filing-vagrancy", 20},
  }
  for _, pair in ipairs(spitter_filings) do
    local r = get_recipe(pair[1])
    assert_eq(r.energy_required, pair[2], pair[1] .. " wrong time")
  end
end)

test("landscape-final is simple (no case/brief, just filing + excuse)", function()
  local r = get_recipe("landscape-final")
  assert_true(r ~= nil)
  assert_true(has_ingredient(r, "filing-l"))
  assert_true(has_ingredient(r, "basic-excuse"))
  assert_eq(#r.ingredients, 2, "landscape-final should have exactly 2 ingredients")
end)

test("littering-final is simple (no case/brief, just filing + crappy-report)", function()
  local r = get_recipe("littering-final")
  assert_true(has_ingredient(r, "filing-lt"))
  assert_true(has_ingredient(r, "crappy-report"))
  assert_eq(#r.ingredients, 2)
end)

test("smog/hazmat finals require case stage (not brief)", function()
  local r = get_recipe("smog-final")
  assert_true(has_ingredient(r, "case-s"))

  local r2 = get_recipe("hazmat-final")
  assert_true(has_ingredient(r2, "case-h"))
end)

test("noise/loitering finals now resolve directly from the case stage", function()
  assert_true(has_ingredient(get_recipe("noise-final"), "case-n"))
  assert_true(has_ingredient(get_recipe("loitering-final"), "case-lo"))
end)

test("unemployment/vagrancy finals now resolve directly from the case stage", function()
  assert_true(has_ingredient(get_recipe("unemployment-final"), "case-u"))
  assert_true(has_ingredient(get_recipe("vagrancy-final"), "case-v"))
end)

test("final resolution times escalate after folding the brief stage into the final craft", function()
  assert_eq(get_recipe("landscape-final").energy_required, 5)
  assert_eq(get_recipe("littering-final").energy_required, 7)
  assert_eq(get_recipe("smog-final").energy_required, 20)
  assert_eq(get_recipe("hazmat-final").energy_required, 20)
  assert_eq(get_recipe("noise-final").energy_required, 150)
  assert_eq(get_recipe("loitering-final").energy_required, 150)
  assert_eq(get_recipe("unemployment-final").energy_required, 270)
  assert_eq(get_recipe("vagrancy-final").energy_required, 270)
end)

test("all complaint filing and resolution recipes are tech-gated", function()
  local must_be_disabled = {
    "filing-landscape", "landscape-final",
    "filing-smog", "filing-noise", "filing-unemployment",
    "case-smog", "case-noise", "case-unemployment",
    "smog-final", "noise-final", "unemployment-final",
  }
  for _, name in ipairs(must_be_disabled) do
    assert_eq(get_recipe(name).enabled, false, name .. " should be disabled")
  end
end)

-- =========================================================================
-- COFFEE & GREENHOUSE
-- =========================================================================

test("greenhouse recipes use admin-greenhouse category", function()
  local gh_recipes = {"greenhouse-wood", "greenhouse-discovery", "coffee-plantation"}
  for _, name in ipairs(gh_recipes) do
    local r = get_recipe(name)
    assert_true(r ~= nil, name .. " missing")
    assert_eq(r.category, "admin-greenhouse", name .. " wrong category")
  end
end)

test("greenhouse wood growth is moderately accelerated", function()
  local r = get_recipe("greenhouse-wood")
  assert_eq(get_result_amount(r, "wood"), 12)
  assert_eq(r.energy_required, 24)
end)

test("coffee-plantation grows beans without fertilizer", function()
  local r = get_recipe("coffee-plantation")
  assert_true(has_ingredient(r, "coffee-bean"), "coffee plantation needs coffee-bean")
  assert_true(has_ingredient(r, "water"), "coffee plantation needs water")
  assert_true(not has_ingredient(r, "fertilizer"), "coffee plantation should not need fertilizer")
  assert_eq(get_result_amount(r, "coffee-bean"), 5)
  assert_eq(r.energy_required, 30)
end)

test("coffee beans stack to 50", function()
  local bean = data.raw.item["coffee-bean"]
  assert_true(bean ~= nil, "coffee-bean item missing")
  assert_eq(bean.stack_size, 50)
end)

test("coffee-refining does not require work-order", function()
  local r = get_recipe("coffee-refining")
  assert_true(not has_ingredient(r, "work-order"), "coffee refining should not need work-order")
  assert_true(has_ingredient(r, "coffee-bean"), "coffee refining needs coffee-bean")
  assert_true(has_ingredient(r, "water"), "coffee refining needs water")
  assert_eq(r.category, "watercooler-gossip")
end)

test("greenhouse-discovery has probabilistic coffee-bean output", function()
  local r = get_recipe("greenhouse-discovery")
  assert_eq(r.main_product, "coffee-bean")
  local found = false
  for _, res in ipairs(r.results) do
    if res.name == "coffee-bean" then
      assert_eq(res.probability, 0.1)
      found = true
    end
  end
  assert_true(found, "coffee-bean result not found")
end)

-- =========================================================================
-- ECONOMY SYSTEM
-- =========================================================================

test("treasury-bond requires taxpayer-money at the office desk", function()
  local r = get_recipe("treasury-bond-production")
  assert_eq(r.category, "bureaucracy-registration")
  assert_true(has_ingredient(r, "taxpayer-money"))
  assert_eq(get_ingredient_amount(r, "taxpayer-money"), 50)
  assert_eq(r.auto_recycle, false, "treasury bonds must not recycle back into loose taxpayer money")
end)

test("rocket-silo financing uses grants instead of a direct taxpayer-money surcharge", function()
  assert_nil(shared.TAXPAYER_MONEY_COSTS["rocket-silo"])
end)

test("rideable biter uses paperwork and coffee in its assignment recipe", function()
  local r = get_recipe("rideable-biter")
  assert_true(r ~= nil, "rideable-biter recipe missing")
  assert_eq(r.category, "biter-training", "rideable biter should be assigned at the formation center")
  assert_true(has_ingredient(r, "biter-worker"), "rideable biter should require a biter worker")
  assert_true(has_ingredient(r, "management-verbal-work-order"), "rideable biter should require assignment paperwork")
  assert_true(has_ingredient(r, "liquid-coffee"), "rideable biter should require training coffee")
  assert_true(not has_ingredient(r, "taxpayer-money"), "rideable biter training should not directly consume taxpayer money")
  assert_true(not has_ingredient(r, "job-offer"), "rideable biter training should not consume job offers")
  assert_eq(get_result_name(r), "rideable-biter")
end)

test("biterport logistics uses dedicated formations instead of station workers", function()
  local r = get_recipe("biter-logistics-formation")
  assert_true(r ~= nil, "biter-logistics-formation recipe missing")
  assert_eq(r.category, "biter-training", "logistics formations should be organized at the formation center")
  assert_true(has_ingredient(r, "biter-worker"), "formations should be trained from ordinary biter workers")
  assert_eq(get_ingredient_amount(r, "biter-worker"), 1)
  assert_true(has_ingredient(r, "management-verbal-work-order"), "formations should require management paperwork")
  assert_true(has_ingredient(r, "form-27b-6"), "formations should use available standardized paperwork")
  assert_true(has_ingredient(r, "liquid-coffee"), "formations should require training coffee")
  assert_true(not has_ingredient(r, "taxpayer-money"), "formations should not directly consume taxpayer money")
  assert_true(not has_ingredient(r, "job-offer"), "formations should not consume job offers")
  assert_true(not has_ingredient(r, "research-grant-approval"), "formations should not require research grant approvals")
  assert_eq(get_result_name(r), "biter-logistics-formation")
end)

test("data-production now runs through bureaucracy-registration", function()
  local r = get_recipe("data-production")
  assert_eq(r.category, "bureaucracy-registration")
  assert_true(has_ingredient(r, "crappy-report"))
  assert_true(has_ingredient(r, "advanced-circuit"))
  assert_true(not has_ingredient(r, "credentials"),
    "data-production should no longer require credentials intermediary")
end)

test("government-grant requires treasury-bond and union negotiation", function()
  local r = get_recipe("government-grant-production")
  assert_eq(r.category, "union-negotiation")
  assert_true(has_ingredient(r, "treasury-bond"))
  assert_eq(get_ingredient_amount(r, "treasury-bond"), 10)
  assert_true(has_ingredient(r, "management-approval-verbal"))
end)

test("repeatable policy and casework use bonds instead of megaproject grants", function()
  for _, recipe_name in ipairs({
    "policy-production",
    "regulation-production",
    "case-unemployment",
    "hired-biter-capsule",
    "overtime-exemption",
  }) do
    local r = get_recipe(recipe_name)
    assert_true(has_ingredient(r, "treasury-bond"), recipe_name .. " should consume treasury bonds")
    assert_false(has_ingredient(r, "government-grant"), recipe_name .. " should not consume government grants")
  end
end)

test("specialist training bootstraps before the buildings that consume specialists", function()
  local delegate = get_recipe("union-delegate-training")
  assert_eq(delegate.category, "biter-training")
  assert_true(has_ingredient(delegate, "management-verbal-work-order"))
  assert_true(has_ingredient(delegate, "form-27b-6"))
  assert_true(not has_ingredient(delegate, "treasury-bond"))
  assert_true(not has_ingredient(delegate, "government-grant"))

  local chemical = get_recipe("chemical-operator-training")
  assert_eq(chemical.category, "biter-training")
  assert_true(has_ingredient(chemical, "chemical-handling-work-order"))
  assert_true(has_ingredient(chemical, "liquid-coffee"))
  assert_true(not has_ingredient(chemical, "petrochemical-operating-permit"))
  assert_true(not has_ingredient(chemical, "construction-permit"))
  assert_true(not has_ingredient(chemical, "management-approval-written"))
end)

test("all biter training recipes use the formation center category", function()
  for _, recipe_name in ipairs({
    "rideable-biter",
    "biter-logistics-formation",
    "union-delegate-training",
    "chemical-operator-training",
    "nuclear-technician-training",
    "hired-biter-capsule",
  }) do
    local recipe = get_recipe(recipe_name)
    assert_true(recipe ~= nil, recipe_name .. " recipe missing")
    assert_eq(recipe.category, "biter-training", recipe_name .. " should run only in the formation center")
    assert_true(has_ingredient(recipe, "biter-worker"), recipe_name .. " should consume a biter worker")
  end
end)

test("biter training is one worker to one biter output using only paperwork and coffee", function()
  for _, recipe_name in ipairs({
    "rideable-biter",
    "biter-logistics-formation",
    "union-delegate-training",
    "chemical-operator-training",
    "nuclear-technician-training",
    "hired-biter-capsule",
  }) do
    local recipe = get_recipe(recipe_name)
    local result_name = get_result_name(recipe)
    assert_eq(get_ingredient_amount(recipe, "biter-worker"), 1, recipe_name .. " should consume exactly one biter worker")
    assert_eq(get_result_amount(recipe, result_name), 1, recipe_name .. " should produce exactly one trained biter output")

    for _, ingredient in ipairs(recipe.ingredients or {}) do
      local ingredient_type = ingredient.type or "item"
      local ingredient_name = ingredient.name or ingredient[1]
      local allowed = ingredient_name == "biter-worker"
        or (ingredient_type == "fluid" and ingredient_name == "liquid-coffee")
        or (ingredient_type == "item" and shared.PAPERWORK_ITEMS[ingredient_name])
      assert_true(allowed, recipe_name .. " has non-paperwork training ingredient: " .. tostring(ingredient_name))
      assert_true(ingredient_name ~= "taxpayer-money", recipe_name .. " should not directly consume taxpayer money")
      assert_true(ingredient_name ~= "job-offer", recipe_name .. " should not consume job offers")
      assert_true(ingredient_name ~= "research-grant-approval", recipe_name .. " should use immediately available standard paperwork instead of research grant approvals")
      assert_true(not tostring(ingredient_name):find("permit", 1, true), recipe_name .. " should not directly consume permits")
    end
    assert_true(has_ingredient(recipe, "liquid-coffee"), recipe_name .. " should require training coffee")
  end
end)

test("tax-audit converts slush-fund to taxpayer-money (net positive)", function()
  local r = get_recipe("tax-audit")
  assert_true(has_ingredient(r, "slush-fund"))
  local output = get_result_amount(r, "taxpayer-money")
  assert_true(output > 0, "tax-audit should produce taxpayer-money")
end)

test("slush-fund-production uses propaganda-distillery", function()
  local r = get_recipe("slush-fund-production")
  assert_eq(r.category, "propaganda-distillery")
  assert_true(has_ingredient(r, "treasury-bond"))
  assert_eq(get_ingredient_amount(r, "treasury-bond"), 1)
end)

-- =========================================================================
-- BS ECONOMY CHAIN
-- =========================================================================

test("BS economy chain: dubious-data -> basic-excuse -> good-excuse", function()
  local excuse = get_recipe("basic-excuse-production")
  assert_true(has_ingredient(excuse, "dubious-data"))
  assert_eq(excuse.category, "bureaucratic-bootstrap")

  local good = get_recipe("good-excuse-production")
  assert_true(has_ingredient(good, "data"))
  assert_eq(good.category, "watercooler-gossip")
end)

test("credentials require lies and refined-nonsense", function()
  local r = get_recipe("credentials-production")
  assert_true(has_ingredient(r, "dubious-data"))
  assert_true(has_ingredient(r, "refined-nonsense"))
  assert_true(has_ingredient(r, "electronic-circuit"))
end)

test("narrative requires justification and good-excuse and watercooler-gossip", function()
  local r = get_recipe("narrative-production")
  assert_true(has_ingredient(r, "justification"))
  assert_true(has_ingredient(r, "good-excuse"))
  assert_true(has_ingredient(r, "watercooler-gossip"))
  assert_eq(r.category, "union-negotiation")
end)

test("good-excuse has probabilistic office-drama byproduct", function()
  local r = get_recipe("good-excuse-production")
  assert_eq(r.main_product, "good-excuse")
  local found = false
  for _, res in ipairs(r.results) do
    if res.name == "office-drama" then
      assert_eq(res.probability, 0.5)
      found = true
    end
  end
  assert_true(found, "office-drama byproduct missing from good-excuse")
end)

test("office-drama recycling randomly returns gossip, excuses, and work orders", function()
  local r = get_recipe("office-drama-recycling")
  assert_eq(r.category, "watercooler-gossip")
  assert_true(has_ingredient(r, "office-drama"))
  assert_true(has_ingredient(r, "liquid-coffee"))
  assert_eq(#r.results, 3)
  assert_eq(get_result_amount(r, "work-order"), 1)
  assert_eq(get_result_amount(r, "watercooler-gossip"), 1)
  assert_eq(get_result_amount(r, "basic-excuse"), 1)
  assert_eq(get_result_probability(r, "work-order"), 0.5)
  assert_eq(get_result_probability(r, "watercooler-gossip"), 0.5)
  assert_eq(get_result_probability(r, "basic-excuse"), 0.5)
end)

-- =========================================================================
-- ADMIN RECIPE DETECTION (is_admin_recipe)
-- =========================================================================

test("is_admin_recipe returns true for admin buildings", function()
  for name in pairs(shared.ADMIN_BUILDINGS) do
    assert_true(shared.is_admin_recipe(name), name .. " not detected as admin")
  end
end)

test("is_admin_recipe returns true for form production recipes", function()
  for _, recipe_name in pairs(shared.FORM_PRODUCTION_RECIPES) do
    assert_true(shared.is_admin_recipe(recipe_name), recipe_name .. " not detected as admin")
  end
end)

test("is_admin_recipe returns false for paper-production and ink-production", function()
  assert_true(not shared.is_admin_recipe("paper-production"), "paper should not be admin")
  assert_true(not shared.is_admin_recipe("ink-production"), "ink should not be admin")
end)

test("is_admin_recipe returns false for vanilla recipes", function()
  local vanilla = {"transport-belt", "inserter", "iron-plate", "assembling-machine-1"}
  for _, name in ipairs(vanilla) do
    assert_true(not shared.is_admin_recipe(name), name .. " incorrectly detected as admin")
  end
end)

test("is_admin_recipe detects explicitly registered resolution recipes", function()
  local resolution = {"filing-landscape", "case-smog", "noise-final", "unemployment-final"}
  for _, name in ipairs(resolution) do
    assert_true(shared.is_admin_recipe(name), name .. " not detected as admin")
  end
end)

test("is_admin_recipe does not classify third-party recipes by name pattern", function()
  for _, name in ipairs({"advanced-circuit-production", "third-party-basic-excuse-production", "outside-permit"}) do
    assert_false(shared.is_admin_recipe(name), name .. " should not be treated as an admin recipe")
  end
end)

-- =========================================================================
-- BUILDING RECIPE SPECIFICS
-- =========================================================================

test("office-desk keeps its original circuit recipe and is tech-gated", function()
  local r = get_recipe("office-desk")
  assert_eq(r.enabled, false)
  assert_true(has_ingredient(r, "electronic-circuit"))
  assert_true(not has_ingredient(r, "wood"))
end)

test("mechanical-printer is enabled from start (early game printing)", function()
  assert_eq(get_recipe("mechanical-printer").enabled, true)
end)

test("greenhouse is NOT enabled from start", function()
  assert_eq(get_recipe("greenhouse").enabled, false)
end)

-- =========================================================================
-- WORK ORDER SYSTEM
-- =========================================================================

test("work-order recipe: blank-form + dubious-data -> work-order", function()
  local r = get_recipe("work-order-production")
  assert_true(has_ingredient(r, "blank-form"))
  assert_true(has_ingredient(r, "dubious-data"))
  assert_eq(get_result_amount(r, "work-order"), 1)
end)

test("direct draft-to-work-order recipes use printing-workorder category", function()
  local direct = {
    "safety-work-order-printing",
    "construction-work-order-printing",
  }
  for _, name in ipairs(direct) do
    local r = get_recipe(name)
    assert_true(r ~= nil, name .. " missing")
    assert_eq(r.category, "printing-workorder", name .. " wrong category")
    assert_true(has_ingredient(r, "work-order"), name .. " missing work-order")
    assert_true(has_ingredient(r, "ink"), name .. " missing ink")
  end
  assert_true(has_ingredient(get_recipe("safety-work-order-printing"), "safety-waiver"), "safety shortcut should require approved safety waiver")
  assert_true(not has_ingredient(get_recipe("safety-work-order-printing"), "safety-waiver-draft"), "safety shortcut should not use draft")
  assert_true(has_ingredient(get_recipe("construction-work-order-printing"), "construction-permit"), "construction shortcut should require approved permit")
  assert_true(not has_ingredient(get_recipe("construction-work-order-printing"), "construction-permit-draft"), "construction shortcut should not use draft")
end)

test("only draft-backed work-order printing produces 2x output", function()
  assert_eq(get_result_amount(get_recipe("safety-work-order-printing"), "safety-work-order"), 2)
  assert_eq(get_result_amount(get_recipe("construction-work-order-printing"), "construction-work-order"), 2)
  assert_true(get_recipe("research-grant-work-order-printing") == nil, "research grant work orders should not have a direct printing shortcut")
end)

test("only printer recipes use Print in localized recipe names", function()
  for name, recipe in pairs(recipes) do
    local localized_name = recipe_name_locale[name]
    if localized_name and localized_name:match("^Print ") then
      local category = recipe.category or "crafting"
      local is_printer_recipe = category == "printing"
        or category == "printing-advanced"
        or category == "printing-workorder"
      assert_true(is_printer_recipe, name .. " is labeled as Print but uses " .. category)
    end
  end
end)

test("industrial printer copy recipes exist for every work-order family", function()
  local copies = {
    {"copy-work-order", "work-order"},
    {"copy-safety-work-order", "safety-work-order"},
    {"copy-construction-work-order", "construction-work-order"},
    {"copy-management-verbal-work-order", "management-verbal-work-order"},
    {"copy-management-written-work-order", "management-written-work-order"},
    {"copy-research-grant-work-order", "research-grant-work-order"},
    {"copy-chemical-handling-work-order", "chemical-handling-work-order"},
    {"copy-radiological-work-order", "radiological-work-order"},
  }
  for _, copy in ipairs(copies) do
    local recipe_name = copy[1]
    local product_name = copy[2]
    local recipe = get_recipe(recipe_name)
    assert_true(recipe ~= nil, recipe_name .. " missing")
    assert_true(has_ingredient(recipe, product_name), recipe_name .. " missing original form")
    assert_true(has_ingredient(recipe, "processing-unit"), recipe_name .. " missing processing-unit")
    assert_eq(get_result_amount(recipe, product_name), 6, recipe_name .. " should output 6 copies")
  end
end)

-- =========================================================================
-- MODULES
-- =========================================================================

test("overtime-exemption requires union-negotiation category", function()
  local r = get_recipe("overtime-exemption")
  assert_eq(r.category, "union-negotiation")
  assert_true(has_ingredient(r, "processing-unit"))
  assert_eq(get_ingredient_amount(r, "treasury-bond"), 4)
  assert_false(has_ingredient(r, "government-grant"))
  assert_true(has_ingredient(r, "management-approval-written"))
  assert_false(has_ingredient(r, "taxpayer-money"))
  assert_false(has_ingredient(r, "regulation"))
  assert_false(has_ingredient(r, "productivity-module"))
end)

-- =========================================================================
-- OSHA SYSTEM
-- =========================================================================

test("osha-scrubbing converts violations to justifications via union", function()
  local r = get_recipe("osha-scrubbing")
  assert_eq(r.category, "union-negotiation")
  assert_true(has_ingredient(r, "osha-violation"))
  assert_true(has_ingredient(r, "refined-nonsense"))
  assert_eq(get_result_name(r), "justification")
end)

test("osha-violation-recycling has probabilistic outputs", function()
  local r = get_recipe("osha-violation-recycling")
  assert_true(#r.results >= 5, "osha recycling should have many outputs")
  assert_true(has_ingredient(r, "osha-violation"))
end)

-- =========================================================================
-- ADMINISTRATIVE SCIENCE PACK
-- =========================================================================

test("admin science pack requires office desk and specific forms", function()
  local r = get_recipe("administrative-science-pack-production")
  assert_eq(r.category, "bureaucracy-registration")
  assert_true(has_ingredient(r, "provisional-approval"))
  assert_true(has_ingredient(r, "basic-excuse"))
  assert_true(has_ingredient(r, "research-grant-approval"))
  assert_eq(get_result_amount(r, "administrative-science-pack"), 5)
end)

-- =========================================================================
-- CATEGORY DEFINITIONS
-- =========================================================================

test("all custom recipe categories are defined", function()
  local expected = {
    "bureaucracy-registration", "bureaucratic-bootstrap", "bureaucracy-resolution",
    "bureaucracy-policy", "admin-greenhouse", "watercooler-gossip",
    "union-negotiation", "smelting-basic", "printing", "printing-advanced",
    "printing-workorder", "propaganda-distillery", "pneumatic-intake",
  }
  for _, name in ipairs(expected) do
    assert_true(data.raw["recipe-category"][name] ~= nil, "missing category: " .. name)
  end
end)

test("pneumatic intake recipes accept every transportable item without outputs", function()
  for item_name in pairs(shared.PNEUMATIC_ITEMS) do
    local recipe = get_recipe("pneumatic-intake-" .. item_name)
    assert_true(recipe ~= nil, "missing pneumatic intake recipe for " .. item_name)
    assert_eq(recipe.category, "pneumatic-intake", recipe.name .. " wrong category")
    assert_eq(recipe.enabled, false, recipe.name .. " should be unlocked by pneumatic transport tech")
    assert_eq(#recipe.ingredients, 1, recipe.name .. " should have one ingredient")
    assert_eq(recipe.ingredients[1].name, item_name, recipe.name .. " wrong ingredient")
    assert_eq(#recipe.results, 0, recipe.name .. " should not output anything")
  end
end)

test("data-stage and runtime pneumatic payload sets stay identical", function()
  local runtime_items = require("prototypes.shared.pneumatic_items").names
  local runtime_set = {}
  for _, item_name in ipairs(runtime_items) do
    runtime_set[item_name] = true
    assert_true(shared.PNEUMATIC_ITEMS[item_name], item_name .. " is missing from data-stage pneumatic items")
  end
  for item_name in pairs(shared.PNEUMATIC_ITEMS) do
    assert_true(runtime_set[item_name], item_name .. " is missing from runtime pneumatic items")
  end
end)

-- =========================================================================
-- PROMISE & EVICTION
-- =========================================================================

test("promise stays handcraftable but is tech-gated", function()
  local r = get_recipe("promise-production")
  assert_eq(r.category, "bureaucratic-bootstrap")
  assert_eq(r.enabled, false)
  assert_true(has_ingredient(r, "blank-form"))
  assert_true(has_ingredient(r, "dubious-data"))
  assert_true(has_ingredient(r, "provisional-approval"))
end)

test("eviction-notice requires office desk and expensive ingredients", function()
  local r = get_recipe("eviction-notice-production")
  assert_eq(r.category, "bureaucracy-registration")
  assert_true(has_ingredient(r, "good-excuse"))
  assert_true(has_ingredient(r, "credentials"))
  assert_true(has_ingredient(r, "taxpayer-money"))
  assert_eq(get_ingredient_amount(r, "taxpayer-money"), 100)
end)

-- =========================================================================
-- PNEUMATIC TRANSPORT PREREQUISITES
-- =========================================================================

test("pneumatic-pipe requires compacted-rubble", function()
  local r = get_recipe("pneumatic-pipe")
  assert_true(has_ingredient(r, "compacted-rubble"))
  assert_true(has_ingredient(r, "pipe"))
end)

test("pneumatic-pipe-to-ground requires construction-permit", function()
  local r = get_recipe("pneumatic-pipe-to-ground")
  assert_true(has_ingredient(r, "construction-permit"))
  assert_true(has_ingredient(r, "pneumatic-pipe"))
end)

test("tube intake and outtake require compacted-rubble", function()
  assert_true(has_ingredient(get_recipe("tube-intake"), "compacted-rubble"))
  assert_true(has_ingredient(get_recipe("tube-outtake"), "compacted-rubble"))
  assert_true(has_ingredient(get_recipe("tube-intake"), "pipe"))
  assert_true(has_ingredient(get_recipe("tube-outtake"), "pipe"))
end)

-- =========================================================================
-- RECIPE INGREDIENT COUNTS (regression guards)
-- =========================================================================

test("environmental compliance bootstrap does not require union-headquarters", function()
  local verified = get_recipe("carbon-offset-certificate-verified")
  local report = get_recipe("environmental-impact-report")
  assert_eq(verified.category, "bureaucracy-registration", "verified carbon certificate should be office-desk craftable")
  assert_eq(report.category, "bureaucracy-registration", "environmental impact report should be office-desk craftable")
  assert_true(get_recipe("petrochemical-operating-permit-production") == nil, "petrochemical permits should stay removed")
end)

-- =========================================================================
-- EVERY RECIPE HAS REQUIRED FIELDS
-- =========================================================================

test("all recipes have ingredients and results", function()
  for name, recipe in pairs(recipes) do
    assert_true(recipe.ingredients ~= nil, name .. " missing ingredients")
    assert_true(recipe.results ~= nil or recipe.result ~= nil, name .. " missing results")
  end
end)

test("all recipes have energy_required", function()
  for name, recipe in pairs(recipes) do
    assert_true(recipe.energy_required ~= nil, name .. " missing energy_required")
    assert_true(recipe.energy_required > 0, name .. " energy_required must be positive")
  end
end)

-- =========================================================================
-- BOOTSTRAP DEADLOCK DETECTION
-- Verifies that the power bootstrap chain (boiler/steam-engine) can be
-- completed without electricity. Every item in the chain must be producible
-- using only: handcrafting (crafting, bureaucratic-bootstrap), the burner
-- mechanical-printer (printing), or the burner stone-furnace (smelting-basic).
-- =========================================================================

-- Categories available without electricity (burner or handcraft)
local PRE_ELECTRICITY_CATEGORIES = {
  ["crafting"] = true,              -- player handcraft (default)
  ["bureaucratic-bootstrap"] = true, -- player handcraft (admin)
  ["printing"] = true,               -- mechanical-printer (burner)
  ["smelting-basic"] = true,         -- stone-furnace (burner)
}

-- Raw resources that are mined/gathered, not crafted
local RAW_RESOURCES = {
  ["wood"] = true, ["coal"] = true, ["stone"] = true,
  ["iron-ore"] = true, ["copper-ore"] = true,
  ["bullshit-ore"] = true, ["redundant-rubble"] = true,
  ["water"] = true,
  -- Vanilla intermediates (recipes not in mod files, but craftable in-game)
  ["iron-gear-wheel"] = true, ["iron-stick"] = true,
  ["copper-cable"] = true, ["electronic-circuit"] = true,
  ["pipe"] = true,
}

-- Find a recipe that produces the given item (prefer primary production over
-- copy recipes, byproducts, and alternative recipes)
local function find_recipe_for_item(item_name)
  local best = nil
  local best_score = -1
  for _, recipe in pairs(recipes) do
    local produces = false
    local is_primary = false
    if recipe.results then
      for _, res in ipairs(recipe.results) do
        if (res.name or res[1]) == item_name then
          produces = true
          if recipe.main_product == item_name or not res.probability then
            is_primary = true
          end
          break
        end
      end
    elseif recipe.result == item_name then
      produces = true
      is_primary = true
    end
    if produces then
      -- Score: higher is better
      -- 0 = byproduct/copy, 1 = primary but unrelated name, 2 = name matches item
      local score = 0
      if is_primary and not recipe.name:find("^copy%-") then
        score = 1
        if recipe.name:find(item_name, 1, true) then
          score = 2
        end
      end
      if score > best_score
        or (score == best_score and best and (
          -- Tiebreaker 1: prefer pre-electricity category
          (PRE_ELECTRICITY_CATEGORIES[recipe.category or "crafting"] and not PRE_ELECTRICITY_CATEGORIES[best.category or "crafting"])
          -- Tiebreaker 2: alphabetical for full determinism
          or (PRE_ELECTRICITY_CATEGORIES[recipe.category or "crafting"] == PRE_ELECTRICITY_CATEGORIES[best.category or "crafting"]
              and recipe.name < best.name)
        )) then
        best = recipe
        best_score = score
      end
    end
  end
  return best
end

-- Recursively check that every item in a production chain can be produced
-- without electricity. Returns nil on success or an error string on failure.
-- visited prevents infinite loops from recipe cycles.
local function check_pre_electricity_chain(item_name, visited, path)
  if RAW_RESOURCES[item_name] then return nil end
  if visited[item_name] then return nil end  -- already validated or in progress
  visited[item_name] = true

  local recipe = find_recipe_for_item(item_name)
  if not recipe then
    return "no recipe found for '" .. item_name .. "' (path: " .. path .. ")"
  end

  local cat = recipe.category or "crafting"
  if not PRE_ELECTRICITY_CATEGORIES[cat] then
    return "'" .. item_name .. "' requires category '" .. cat
      .. "' which needs electricity (path: " .. path .. ")"
  end

  -- Recurse into ingredients
  if recipe.ingredients then
    for _, ing in ipairs(recipe.ingredients) do
      local ing_name = ing.name or ing[1]
      local ing_type = ing.type or "item"
      if ing_type == "item" then
        local err = check_pre_electricity_chain(
          ing_name, visited, path .. " -> " .. ing_name)
        if err then return err end
      end
    end
  end

  return nil
end

test("safety-waiver remains pre-electricity craftable through direct printing", function()
  local visited = {}
  local err = check_pre_electricity_chain("safety-waiver", visited, "safety-waiver")
  assert_true(err == nil, "safety-waiver should stay pre-electricity craftable")
end)

test("boiler bootstrap: carbon-offset-certificate-basic chain requires no electricity", function()
  -- carbon-offset-certificate-basic is injected into the boiler recipe
  local visited = {}
  local err = check_pre_electricity_chain(
    "carbon-offset-certificate-basic", visited, "carbon-offset-certificate-basic")
  assert_true(err == nil, "DEADLOCK: " .. (err or ""))
end)

test("boiler bootstrap: all vanilla boiler/steam-engine ingredients are pre-electricity", function()
  -- The vanilla ingredients for boiler (stone-furnace, pipe, iron-plate) and
  -- steam-engine (iron-gear-wheel, pipe, iron-plate) must be producible too
  local vanilla_bootstrap_items = {
    "iron-plate", "copper-plate", "iron-gear-wheel", "pipe",
    "stone-brick", "electronic-circuit", "copper-cable",
  }
  for _, item_name in ipairs(vanilla_bootstrap_items) do
    local visited = {}
    local err = check_pre_electricity_chain(item_name, visited, item_name)
    assert_true(err == nil, "DEADLOCK for " .. item_name .. ": " .. (err or ""))
  end
end)

test("basic-excuse is handcraftable (bureaucratic-bootstrap category)", function()
  -- basic-excuse remains a critical bootstrap item for early draft paperwork.
  local r = get_recipe("basic-excuse-production")
  assert_true(r ~= nil, "basic-excuse-production missing")
  assert_eq(r.category, "bureaucratic-bootstrap",
    "basic-excuse MUST be handcraftable — electric-only would deadlock power bootstrap")
end)

test("no recipe cycle exists in the pre-electricity production chain", function()
  -- Build the full dependency graph for pre-electricity items and verify
  -- there are no cycles that would make production impossible.
  -- Uses DFS with 3-color marking: nil=unvisited, "gray"=in progress, "black"=done
  local color = {}
  local cycle_path = nil

  local function dfs(item_name, path)
    if cycle_path then return end  -- already found a cycle
    if RAW_RESOURCES[item_name] then return end
    if color[item_name] == "black" then return end
    if color[item_name] == "gray" then
      cycle_path = path .. " -> " .. item_name .. " (CYCLE)"
      return
    end

    local recipe = find_recipe_for_item(item_name)
    if not recipe then return end

    local cat = recipe.category or "crafting"
    if not PRE_ELECTRICITY_CATEGORIES[cat] then return end  -- not in bootstrap chain

    color[item_name] = "gray"
    if recipe.ingredients then
      for _, ing in ipairs(recipe.ingredients) do
        local ing_type = ing.type or "item"
        if ing_type == "item" then
          dfs(ing.name or ing[1], path .. " -> " .. (ing.name or ing[1]))
        end
      end
    end
    color[item_name] = "black"
  end

  -- Check all items producible by pre-electricity recipes
  for _, recipe in pairs(recipes) do
    local cat = recipe.category or "crafting"
    if PRE_ELECTRICITY_CATEGORIES[cat] and recipe.results then
      for _, res in ipairs(recipe.results) do
        local res_name = res.name or res[1]
        dfs(res_name, res_name)
      end
    end
  end

  assert_true(cycle_path == nil,
    "Recipe cycle in pre-electricity chain: " .. (cycle_path or ""))
end)

-- =========================================================================
-- ADMIN BUILDING AM REGULATION
-- Admin buildings get "-regulated" copies in data-final-fixes so they can
-- be crafted in assembling machines. These tests verify the prerequisites.
-- =========================================================================

test("all admin buildings with recipes use crafting category (AM-regulatable)", function()
  for name, _ in pairs(shared.ADMIN_BUILDINGS) do
    local r = get_recipe(name)
    if r then
      local cat = r.category or "crafting"
      assert_true(cat == "crafting" or cat == "advanced-crafting",
        name .. " has category '" .. cat .. "', must be crafting/advanced-crafting for AM regulation")
    end
  end
end)

test("only bootstrap-safe admin buildings start enabled", function()
  local early_buildings = {"mechanical-printer"}
  for _, name in ipairs(early_buildings) do
    local r = get_recipe(name)
    assert_true(r ~= nil, name .. " recipe missing")
    local cat = r.category or "crafting"
    assert_eq(cat, "crafting", name .. " must use crafting category for handcrafting")
    assert_eq(r.enabled, true, name .. " must be enabled from start")
  end
end)

test("bootstrap structures that consume gated paperwork are tech-gated", function()
  local gated_buildings = {"office-desk", "admin-station", "resolution-office"}
  for _, name in ipairs(gated_buildings) do
    local r = get_recipe(name)
    assert_true(r ~= nil, name .. " recipe missing")
    local cat = r.category or "crafting"
    assert_eq(cat, "crafting", name .. " must stay handcraftable once unlocked")
    assert_eq(r.enabled, false, name .. " should not be enabled before its gating tech exists")
  end
end)

test("recipes that consume discovery-gated paperwork are not enabled from start", function()
  local must_be_gated = {
    "promise-production",
    "safety-waiver-draft",
    "safety-waiver-printing",
    "construction-permit-draft",
    "construction-permit-printing",
    "filing-landscape",
    "landscape-final",
  }
  for _, name in ipairs(must_be_gated) do
    local recipe = get_recipe(name)
    assert_true(recipe ~= nil, name .. " recipe missing")
    assert_eq(recipe.enabled, false, name .. " should not be enabled from start")
  end
end)

test("greenhouse is handcraftable (crafting category) but tech-gated", function()
  local r = get_recipe("greenhouse")
  assert_true(r ~= nil)
  local cat = r.category or "crafting"
  assert_eq(cat, "crafting", "greenhouse must use crafting category for handcrafting")
  assert_eq(r.enabled, false, "greenhouse should be tech-gated")
end)

test("ADMIN_BUILDINGS includes all expected building names", function()
  local expected = {
    "office-desk", "admin-station", "resolution-office", "greenhouse",
    "corporate-breakroom", "printer-t1", "printer-t2",
    "mechanical-printer", "union-headquarters",
    "tube-intake", "tube-outtake", "pneumatic-pipe", "pneumatic-pipe-to-ground",
  }
  for _, name in ipairs(expected) do
    assert_true(shared.ADMIN_BUILDINGS[name], name .. " missing from ADMIN_BUILDINGS")
  end
end)

test("admin building recipes are detected by is_admin_recipe (skipped by vanilla regulation)", function()
  for name, _ in pairs(shared.ADMIN_BUILDINGS) do
    assert_true(shared.is_admin_recipe(name),
      name .. " not detected as admin — would be incorrectly regulated by vanilla loop")
  end
end)

-------------------------------------------------------------------------------
-- 4. REPORT
-------------------------------------------------------------------------------
print(string.format("\n=== ADMINISTRATORIO RECIPE TESTS ==="))
print(string.format("Passed: %d  Failed: %d  Total: %d", passed, failed, passed + failed))

if #errors > 0 then
  print("\nFAILURES:")
  for i, err in ipairs(errors) do
    print(string.format("  %d) %s", i, err))
  end
  os.exit(1)
else
  print("\nAll tests passed!")
  os.exit(0)
end
