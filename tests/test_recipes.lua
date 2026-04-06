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
      ["assembling-machine-2"] = { crafting_categories = {"crafting", "advanced-crafting"} },
      ["assembling-machine-3"] = { crafting_categories = {"crafting", "advanced-crafting", "crafting-with-fluid"} },
    },
    ["recipe-category"] = {},
    ["module-category"] = {},
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

-- Load all recipe files
dofile(mod_root .. "prototypes/recipe/paperwork.lua")
dofile(mod_root .. "prototypes/recipe/buildings.lua")
dofile(mod_root .. "prototypes/recipe/production.lua")
dofile(mod_root .. "prototypes/recipe/economy.lua")
dofile(mod_root .. "prototypes/recipe/resolution.lua")
dofile(mod_root .. "prototypes/recipe/modules.lua")

-- Load shared constants
local shared = require("prototypes.shared")

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

local function get_result_name(recipe)
  if recipe.results and recipe.results[1] then
    return recipe.results[1].name or recipe.results[1][1]
  end
  return recipe.result
end

local function get_result_amount(recipe, item_name)
  if not recipe.results then return recipe.result_count or 1 end
  for _, res in ipairs(recipe.results) do
    if (res.name or res[1]) == item_name then
      return res.amount or res[2]
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

test("shared.PAPERWORK_ITEMS contains all core forms", function()
  local expected = {
    "work-order", "safety-waiver", "construction-permit",
    "management-approval-verbal", "management-approval-written",
    "research-grant-approval", "provisional-approval",
    "blank-form", "blank-approval", "blank-directive",
    "form-27b-6", "carbon-offset-certificate-basic",
    "petrochemical-operating-permit",
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

test("combined form production recipes exist and require tier form + work-order", function()
  local combos = {
    {"safety-work-order-production", "safety-waiver", "work-order"},
    {"construction-work-order-production", "construction-permit", "work-order"},
    {"management-verbal-work-order-production", "management-approval-verbal", "work-order"},
    {"management-written-work-order-production", "management-approval-written", "work-order"},
    {"research-grant-work-order-production", "research-grant-approval", "work-order"},
  }
  for _, combo in ipairs(combos) do
    local r = get_recipe(combo[1])
    assert_true(r ~= nil, combo[1] .. " recipe missing")
    assert_true(has_ingredient(r, combo[2]), combo[1] .. " missing " .. combo[2])
    assert_true(has_ingredient(r, combo[3]), combo[1] .. " missing " .. combo[3])
    assert_eq(r.category, "bureaucracy-registration", combo[1] .. " wrong category")
  end
end)

-- =========================================================================
-- PRINCIPLE 2: BATCH SIZING CONTROLS FORM CONSUMPTION
-- =========================================================================

test("batch multipliers exist for megastructures at 1x", function()
  local megas = {"rocket-silo", "nuclear-reactor", "centrifuge", "beacon", "assembling-machine-3"}
  for _, name in ipairs(megas) do
    assert_eq(shared.BATCH_MULTIPLIERS[name], 1, name .. " should be 1x")
  end
end)

test("batch multipliers for high-volume intermediates are 10x or 20x", function()
  local bulk = {
    ["copper-cable"] = 10, ["iron-gear-wheel"] = 10, ["electronic-circuit"] = 10,
    ["heat-pipe"] = 10, ["ink"] = 10,
    ["pneumatic-pipe"] = 10, ["pneumatic-pipe-to-ground"] = 10,
    ["form-liquifier"] = 10, ["form-solidifier"] = 10,
    ["iron-plate"] = 20, ["copper-plate"] = 20, ["steel-plate"] = 20,
  }
  for name, expected in pairs(bulk) do
    assert_eq(shared.BATCH_MULTIPLIERS[name], expected, name .. " wrong multiplier")
  end
end)

test("equipment recipe multiplier overrides stay narrow", function()
  assert_eq(shared.BATCH_MULTIPLIERS["solar-panel-equipment"], 2)
  assert_eq(shared.BATCH_MULTIPLIERS["battery-equipment"], 2)
  assert_eq(shared.BATCH_MULTIPLIERS["battery-mk2-equipment"], 2)
  assert_true(shared.BATCH_MULTIPLIERS["exoskeleton-equipment"] == nil,
    "non-battery equipment should fall back to the 1x equipment rule, not an explicit override")
end)

test("default batch multiplier is 5", function()
  assert_eq(shared.BATCH_MULTIPLIER_DEFAULT, 5)
end)

test("splitter family batch multipliers are pinned at 5x", function()
  assert_eq(shared.BATCH_MULTIPLIERS["splitter"], 5)
  assert_eq(shared.BATCH_MULTIPLIERS["fast-splitter"], 5)
  assert_eq(shared.BATCH_MULTIPLIERS["express-splitter"], 5)
end)

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
    if category ~= "printing" and category ~= "printing-workorder" and category ~= "printing-advanced" then
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

test("management-approval-written requires 3-step pipeline", function()
  local proposal = get_recipe("management-written-proposal")
  assert_true(proposal ~= nil)
  assert_eq(proposal.category, "bureaucracy-policy")
  assert_true(has_ingredient(proposal, "blank-directive"))
  assert_true(has_ingredient(proposal, "advanced-circuit"))

  local first = get_recipe("management-written-1st-printing")
  assert_eq(first.category, "printing")
  assert_true(has_ingredient(first, "management-written-proposal"))
  assert_true(has_ingredient(first, "ink"))

  local second = get_recipe("management-written-2nd-printing")
  assert_eq(second.category, "printing")
  assert_true(has_ingredient(second, "management-written-review"))
  assert_true(has_ingredient(second, "ink"))
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
  assert_eq(r.category, "bureaucratic-bootstrap")
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

test("union-headquarters requires construction-permit and treasury-bond", function()
  local r = get_recipe("union-headquarters")
  assert_true(has_ingredient(r, "construction-permit"))
  assert_true(has_ingredient(r, "treasury-bond"))
end)

test("meeting-room requires management-approval-verbal and government-grant", function()
  local r = get_recipe("meeting-room")
  assert_true(has_ingredient(r, "management-approval-verbal"))
  assert_true(has_ingredient(r, "government-grant"))
  assert_true(has_ingredient(r, "taxpayer-money"))
  assert_true(has_ingredient(r, "advanced-circuit"))
  assert_true(has_ingredient(r, "steel-plate"))
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

test("T3 items: locomotive, roboport, solar-panel use management-approval-verbal", function()
  assert_eq(shared.get_required_form("locomotive"), "management-approval-verbal")
  assert_eq(shared.get_required_form("roboport"), "management-approval-verbal")
  assert_eq(shared.get_required_form("solar-panel"), "management-approval-verbal")
  assert_eq(shared.get_required_form("accumulator"), "management-approval-verbal")
  assert_eq(shared.get_required_form("electric-furnace"), "management-approval-verbal")
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

test("baseline oil-processing uses petrochemical-operating-permit", function()
  assert_eq(shared.get_operating_form({name = "oil-processing", category = "oil-processing"}), "petrochemical-operating-permit")
end)

test("baseline petrochem recipes stay on petrochemical-operating-permit", function()
  assert_eq(shared.get_operating_form({name = "plastic-bar", category = "chemistry"}), "petrochemical-operating-permit")
  assert_eq(shared.get_operating_form({name = "sulfur", category = "chemistry"}), "petrochemical-operating-permit")
  assert_eq(shared.get_operating_form({name = "sulfuric-acid", category = "chemistry"}), "petrochemical-operating-permit")
  assert_eq(shared.get_operating_form({name = "solid-fuel-from-heavy-oil", category = "chemistry"}), "petrochemical-operating-permit")
  assert_eq(shared.get_operating_form({name = "solid-fuel-from-light-oil", category = "chemistry"}), "petrochemical-operating-permit")
  assert_eq(shared.get_operating_form({name = "solid-fuel-from-petroleum-gas", category = "chemistry"}), "petrochemical-operating-permit")
end)

test("advanced refining recipes use chemical-handling-work-order", function()
  assert_eq(shared.get_operating_form({name = "advanced-oil-processing", category = "oil-processing"}), "chemical-handling-work-order")
  assert_eq(shared.get_operating_form({name = "coal-liquefaction", category = "oil-processing"}), "chemical-handling-work-order")
end)

test("chemistry requires chemical-handling-work-order", function()
  assert_eq(shared.OPERATING_FORM_BY_CATEGORY["chemistry"], "chemical-handling-work-order")
end)

test("centrifuging requires radiological-work-order", function()
  assert_eq(shared.OPERATING_FORM_BY_CATEGORY["centrifuging"], "radiological-work-order")
end)

test("operating paperwork chain: petro < chemical < radiological", function()
  local petro = get_recipe("petrochemical-operating-permit-production")
  assert_eq(petro.category, "bureaucracy-registration")
  assert_true(has_ingredient(petro, "safety-waiver"))
  assert_true(has_ingredient(petro, "environmental-impact-report"))
  assert_true(not has_ingredient(petro, "construction-permit"))
  assert_true(not has_ingredient(petro, "barrel"))
  assert_true(not has_ingredient(petro, "pipe"))
  assert_true(not has_ingredient(petro, "form-27b-6"))
  assert_true(not has_ingredient(petro, "ink"))
  assert_eq(get_result_amount(petro, "petrochemical-operating-permit"), 2)

  local chem = get_recipe("chemical-handling-work-order-production")
  assert_eq(chem.category, "bureaucracy-registration")
  assert_true(has_ingredient(chem, "petrochemical-operating-permit"), "chemical needs petro permit")
  assert_true(has_ingredient(chem, "form-27b-6"), "chemical needs Form 27B-6")
  assert_true(has_ingredient(chem, "barrel"), "chemical needs barrel")
  assert_true(has_ingredient(chem, "pipe"), "chemical needs pipe")
  assert_true(not has_ingredient(chem, "safety-waiver"), "chemical should inherit safety via petro permit")
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

test("charcoal-production requires carbon offset", function()
  local r = get_recipe("charcoal-production")
  assert_true(r ~= nil)
  assert_eq(r.category, "smelting-basic")
  assert_true(has_ingredient(r, "wood"))
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

test("all filing recipes use bureaucracy-resolution and require blank-form", function()
  local filings = {
    "filing-landscape", "filing-smog", "filing-noise", "filing-unemployment",
    "filing-littering", "filing-hazmat", "filing-loitering", "filing-vagrancy",
  }
  for _, name in ipairs(filings) do
    local r = get_recipe(name)
    assert_true(r ~= nil, name .. " missing")
    assert_eq(r.category, "bureaucracy-resolution", name .. " wrong category")
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

test("noise/loitering finals require brief stage", function()
  assert_true(has_ingredient(get_recipe("noise-final"), "brief-n"))
  assert_true(has_ingredient(get_recipe("loitering-final"), "brief-lo"))
end)

test("unemployment/vagrancy finals require brief stage (hardest)", function()
  assert_true(has_ingredient(get_recipe("unemployment-final"), "brief-u"))
  assert_true(has_ingredient(get_recipe("vagrancy-final"), "brief-v"))
end)

test("final resolution times escalate: simple(5-7) < medium(20) < hard(90) < hardest(180)", function()
  assert_eq(get_recipe("landscape-final").energy_required, 5)
  assert_eq(get_recipe("littering-final").energy_required, 7)
  assert_eq(get_recipe("smog-final").energy_required, 20)
  assert_eq(get_recipe("hazmat-final").energy_required, 20)
  assert_eq(get_recipe("noise-final").energy_required, 90)
  assert_eq(get_recipe("loitering-final").energy_required, 90)
  assert_eq(get_recipe("unemployment-final").energy_required, 180)
  assert_eq(get_recipe("vagrancy-final").energy_required, 180)
end)

test("all complaint filing and resolution recipes are tech-gated", function()
  local must_be_disabled = {
    "filing-landscape", "landscape-final",
    "filing-smog", "filing-noise", "filing-unemployment",
    "case-smog", "case-noise", "case-unemployment",
    "brief-noise", "brief-unemployment",
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

test("coffee-plantation grows beans without fertilizer", function()
  local r = get_recipe("coffee-plantation")
  assert_true(has_ingredient(r, "coffee-bean"), "coffee plantation needs coffee-bean")
  assert_true(has_ingredient(r, "water"), "coffee plantation needs water")
  assert_true(not has_ingredient(r, "fertilizer"), "coffee plantation should not need fertilizer")
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
  assert_eq(get_ingredient_amount(r, "taxpayer-money"), 10)
end)

test("data-production now runs through bureaucracy-registration", function()
  local r = get_recipe("data-production")
  assert_eq(r.category, "bureaucracy-registration")
  assert_true(has_ingredient(r, "crappy-report"))
  assert_true(has_ingredient(r, "credentials"))
  assert_true(has_ingredient(r, "advanced-circuit"))
end)

test("government-grant requires treasury-bond and union negotiation", function()
  local r = get_recipe("government-grant-production")
  assert_eq(r.category, "union-negotiation")
  assert_true(has_ingredient(r, "treasury-bond"))
  assert_true(has_ingredient(r, "management-approval-verbal"))
end)

test("tax-audit converts slush-fund to taxpayer-money (net positive)", function()
  local r = get_recipe("tax-audit")
  assert_true(has_ingredient(r, "taxpayer-money"))
  local input = get_ingredient_amount(r, "taxpayer-money")
  local output = get_result_amount(r, "taxpayer-money")
  assert_true(output > input, "tax-audit should produce more money than it costs")
end)

test("slush-fund-production uses propaganda-distillery", function()
  local r = get_recipe("slush-fund-production")
  assert_eq(r.category, "propaganda-distillery")
  assert_true(has_ingredient(r, "treasury-bond"))
end)

test("taxpayer money costs defined for late-game buildings", function()
  assert_eq(shared.TAXPAYER_MONEY_COSTS["roboport"], 25)
  assert_eq(shared.TAXPAYER_MONEY_COSTS["beacon"], 30)
  assert_eq(shared.TAXPAYER_MONEY_COSTS["nuclear-reactor"], 100)
  assert_eq(shared.TAXPAYER_MONEY_COSTS["centrifuge"], 50)
  assert_eq(shared.TAXPAYER_MONEY_COSTS["rocket-silo"], 200)
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

test("is_admin_recipe detects resolution recipes", function()
  local resolution = {"filing-landscape", "case-smog", "brief-noise", "unemployment-final"}
  for _, name in ipairs(resolution) do
    assert_true(shared.is_admin_recipe(name), name .. " not detected as admin")
  end
end)

-- =========================================================================
-- BUILDING RECIPE SPECIFICS
-- =========================================================================

test("office-desk produces 2 per craft", function()
  local r = get_recipe("office-desk")
  assert_eq(get_result_amount(r, "office-desk"), 2)
end)

test("resolution-office produces 2 per craft", function()
  local r = get_recipe("resolution-office")
  assert_eq(get_result_amount(r, "resolution-office"), 2)
end)

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

test("carbon offset certificate recipe: blank-form + stone -> certificate", function()
  local r = get_recipe("carbon-offset-certificate-basic")
  assert_true(has_ingredient(r, "blank-form"))
  assert_eq(get_ingredient_amount(r, "stone"), 1)
  assert_true(not has_ingredient(r, "coal"))
  assert_eq(get_result_amount(r, "carbon-offset-certificate-basic"), 1)
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
  assert_true(has_ingredient(r, "productivity-module"))
  assert_true(has_ingredient(r, "government-grant"))
  assert_true(has_ingredient(r, "regulation"))
  assert_true(has_ingredient(r, "taxpayer-money"))
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
  assert_true(has_ingredient(r, "blank-form"))
  assert_true(has_ingredient(r, "provisional-approval"))
  assert_true(has_ingredient(r, "basic-excuse"))
  assert_true(has_ingredient(r, "research-grant-approval"))
end)

-- =========================================================================
-- CATEGORY DEFINITIONS
-- =========================================================================

test("all 14 custom recipe categories are defined", function()
  local expected = {
    "bureaucracy-registration", "bureaucratic-bootstrap", "bureaucracy-resolution",
    "bureaucracy-policy", "admin-greenhouse", "watercooler-gossip",
    "union-negotiation", "smelting-basic", "printing", "printing-advanced",
    "printing-workorder", "pneumatic-liquify", "pneumatic-solidify",
    "propaganda-distillery",
  }
  for _, name in ipairs(expected) do
    assert_true(data.raw["recipe-category"][name] ~= nil, "missing category: " .. name)
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

test("form-liquifier and form-solidifier require compacted-rubble", function()
  assert_true(has_ingredient(get_recipe("form-liquifier"), "compacted-rubble"))
  assert_true(has_ingredient(get_recipe("form-solidifier"), "compacted-rubble"))
  assert_true(has_ingredient(get_recipe("form-liquifier"), "pipe"))
  assert_true(has_ingredient(get_recipe("form-solidifier"), "pipe"))
end)

test("heavier vanilla integration anchors have exact ingredient counts", function()
  local expectations = {
    {"greenhouse", "stone-brick", 10},
    {"greenhouse", "pipe", 2},
    {"corporate-breakroom", "stone-brick", 10},
    {"corporate-breakroom", "pipe", 4},
    {"meeting-room", "steel-plate", 15},
    {"meeting-room", "advanced-circuit", 5},
    {"pneumatic-pipe", "pipe", 1},
    {"pneumatic-pipe-to-ground", "construction-permit", 1},
    {"form-liquifier", "pipe", 2},
    {"form-solidifier", "pipe", 2},
    {"crappy-report-production", "paper", 2},
    {"credentials-production", "electronic-circuit", 2},
    {"data-production", "advanced-circuit", 2},
    {"management-written-proposal", "advanced-circuit", 2},
    {"environmental-impact-report", "barrel", 1},
    {"chemical-handling-work-order-production", "barrel", 1},
    {"chemical-handling-work-order-production", "pipe", 1},
    {"radiological-work-order-production", "battery", 1},
    {"radiological-work-order-production", "steel-plate", 2},
    {"white-paper-production", "paper", 10},
    {"white-paper-production", "processing-unit", 1},
    {"policy-production", "processing-unit", 2},
    {"regulation-production", "processing-unit", 3},
    {"case-smog", "coal", 2},
    {"case-hazmat", "barrel", 1},
    {"case-noise", "processing-unit", 1},
  }

  for _, expectation in ipairs(expectations) do
    local recipe_name = expectation[1]
    local ingredient_name = expectation[2]
    local amount = expectation[3]
    local recipe = get_recipe(recipe_name)
    assert_true(recipe ~= nil, recipe_name .. " missing")
    assert_eq(get_ingredient_amount(recipe, ingredient_name), amount,
      recipe_name .. " wrong " .. ingredient_name .. " amount")
  end
end)

-- =========================================================================
-- RECIPE INGREDIENT COUNTS (regression guards)
-- =========================================================================

test("paper-production: 1 wood -> 5 paper", function()
  local r = get_recipe("paper-production")
  assert_eq(get_ingredient_amount(r, "wood"), 1)
  assert_eq(get_result_amount(r, "paper"), 5)
end)

test("ink-production: 1 coal -> 2 ink", function()
  local r = get_recipe("ink-production")
  assert_eq(get_ingredient_amount(r, "coal"), 1)
  assert_eq(get_result_amount(r, "ink"), 2)
end)

test("iron-plate-batch: 10 ore + 1 cert -> 10 plates", function()
  local r = get_recipe("iron-plate-batch")
  assert_eq(get_ingredient_amount(r, "iron-ore"), 10)
  assert_eq(get_ingredient_amount(r, "carbon-offset-certificate-basic"), 1)
  assert_eq(get_result_amount(r, "iron-plate"), 10)
end)

test("steel-plate-batch: 50 iron-plate + 1 cert -> 10 steel", function()
  local r = get_recipe("steel-plate-batch")
  assert_eq(get_ingredient_amount(r, "iron-plate"), 50)
  assert_eq(get_result_amount(r, "steel-plate"), 10)
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

test("boiler bootstrap: safety-waiver chain requires no electricity", function()
  -- safety-waiver is the form required to handcraft a boiler or steam-engine
  local visited = {}
  local err = check_pre_electricity_chain("safety-waiver", visited, "safety-waiver")
  assert_true(err == nil, "DEADLOCK: " .. (err or ""))
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
  -- basic-excuse is a critical bootstrap item: safety-waiver-draft needs it,
  -- and safety-waiver is required for boiler/steam-engine. If this recipe
  -- requires an electric machine, players cannot bootstrap power.
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
    "corporate-breakroom", "meeting-room", "printer-t1", "printer-t2",
    "mechanical-printer", "union-headquarters",
    "form-liquifier", "form-solidifier", "pneumatic-pipe", "pneumatic-pipe-to-ground",
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
