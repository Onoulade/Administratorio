-- ADMINISTRATORIO: SHARED CONSTANTS
-- Single source of truth for constants used across data.lua and data-final-fixes.lua.

local shared = {}
local compatibility_rules = require("prototypes.shared.vanilla_rules")

-------------------------------------------------------------------------------
-- CORE DESIGN PRINCIPLES
--
-- 1. FORMS ARE THE CURRENCY OF AUTOMATION
--    Assembling machines use work-orders and combined work-orders.
--    Furnaces, refineries, chemical plants, and centrifuges use their own
--    machine-family operating paperwork.
--
-- 2. BATCH SIZING CONTROLS FORM CONSUMPTION
--    Small items get large batch multipliers (10x copper cable = 0.1 form/item).
--    Big structures get 1x multiplier (1 form per rocket silo).
--    Target rates: 0.1, 0.2, 0.5, or 1.0 forms per item.
--
-- 3. INK ON PAPER = PRINTER ONLY
--    Any recipe where ink is applied to paper/forms must be done in a printer.
--    Blank forms require ink and must be printed (crash-site or T1 printer).
--    Higher-tier printed documents need ink cartridges (Printer T1/T2).
--
-- 4. EVERY FORM HAS A PRINTER STEP
--    All forms trace back to a blank-form (printed with ink) in their
--    production chain. Higher-tier forms require more printing/ink steps.
--
-- 5. HANDCRAFTING IS LIMITED
--    Items unlocked by red science or earlier can be handcrafted.
--    Items past red science (green science+) are hidden from the handcrafter.
--    T1+ handcraftable items require their tier form as ingredient.
--
-- 6. AMs CANNOT CRAFT FORMS
--    Forms are only craftable in administrative buildings (office desk,
--    admin station, printers). AMs only craft regulated vanilla recipes.
--
-- 7. ALL BUILDINGS NEED FORMS
--    Every vanilla building recipe requires a tier-appropriate form:
--    - In the regulated recipe (AM1/AM2/AM3): combined form (tier + work-order, consumed)
--    - In the original recipe (handcraft before green): tier form directly
--    Exception: pipes, belts, poles, and basic intermediates (T0 = work-order only).
--    Machine operation paperwork is handled separately by recipe category.
--
-- 8. TOP-TIER ASSEMBLERS STAY REGULATED
--    AM2 and AM3 keep vanilla fluid capability, but regulated recipes live on
--    the regulated categories instead of the original crafting ones.
--
-- 9. HANDCRAFTING GATED BY TECH TIER
--    Only recipes at red science or below are handcraftable.
--    Past red science → hidden from player crafting entirely.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PAPERWORK ITEMS
-- All bureaucratic form/permit/certificate item names.
-- Used by the regulation system to identify and strip paperwork from recipes
-- before re-adding them in a controlled way.
-------------------------------------------------------------------------------
shared.PAPERWORK_ITEMS = {
  ["work-order"] = true,
  ["form-27b-6"] = true,
  ["research-grant-approval"] = true,
  ["provisional-approval"] = true,
  ["safety-waiver"] = true,
  ["safety-waiver-draft"] = true,
  ["construction-permit"] = true,
  ["construction-permit-draft"] = true,
  ["transit-authorization"] = true,
  ["management-approval-verbal"] = true,
  ["management-verbal-draft"] = true,
  ["management-approval-written"] = true,
  ["management-written-proposal"] = true,
  ["carbon-offset-certificate-basic"] = true,
  ["carbon-offset-certificate-verified"] = true,
  ["environmental-impact-report"] = true,
  ["petrochemical-operating-permit"] = true,
  ["blank-form"] = true,
  ["blank-approval"] = true,
  ["blank-directive"] = true,
  ["treasury-bond"] = true,
  ["government-grant"] = true,
  -- Combined forms (tier form + work-order)
  ["safety-work-order"] = true,
  ["construction-work-order"] = true,
  ["management-verbal-work-order"] = true,
  ["management-written-work-order"] = true,
  ["research-grant-work-order"] = true,
  ["chemical-handling-work-order"] = true,
  ["radiological-work-order"] = true,
}

-------------------------------------------------------------------------------
-- PNEUMATIC TUBE ITEMS
-- All items eligible for transport through the pneumatic tube system.
-- Includes all PAPERWORK_ITEMS plus complaint pipeline items and other
-- administrative goods. Used by both data stage (recipe generation if any)
-- and control stage (intake inserter filter setup).
-------------------------------------------------------------------------------
shared.PNEUMATIC_ITEMS = {}
for name, _ in pairs(shared.PAPERWORK_ITEMS) do
  shared.PNEUMATIC_ITEMS[name] = true
end
do
  local extra = {
    "paper", "ink", "blank-form", "blank-approval", "blank-directive",
    "safety-waiver-draft", "construction-permit-draft",
    "management-verbal-draft", "management-written-proposal",
    "ticket-landscape", "ticket-smog", "ticket-noise", "ticket-unemployment",
    "ticket-littering", "ticket-hazmat", "ticket-loitering", "ticket-vagrancy",
    "filing-l", "filing-s", "filing-n", "filing-u",
    "filing-lt", "filing-h", "filing-lo", "filing-v",
    "case-s", "case-n", "case-u",
    "case-h", "case-lo", "case-v",
    "brief-n", "brief-u",
    "brief-lo", "brief-v",
    "resolved-landscape", "resolved-smog", "resolved-noise", "resolved-unemployment",
    "resolved-littering", "resolved-hazmat", "resolved-loitering", "resolved-vagrancy",
    "osha-violation",
    "basic-excuse", "crappy-report", "credentials", "data",
    "good-excuse", "justification", "narrative", "policy", "regulation",
    "white-paper", "administrative-science-pack",
    "watercooler-gossip", "office-drama",
    "taxpayer-money",
    "useless-documentation", "refined-nonsense",
    "job-offer", "biter-worker", "biter-logistics-formation", "union-delegate", "chemical-operator", "nuclear-technician",
  }
  for _, name in ipairs(extra) do
    shared.PNEUMATIC_ITEMS[name] = true
  end
end

-------------------------------------------------------------------------------
-- COMBINED FORMS
-- Maps a tier form to its combined version (tier form + work-order).
-- Used by AM1/AM2/AM3 regulated recipes. The combined form is consumed (no return).
-- work-order has no combined form (it IS the base form for T0 items).
-------------------------------------------------------------------------------
shared.COMBINED_FORMS = {
  ["safety-waiver"] = "safety-work-order",
  ["construction-permit"] = "construction-work-order",
  ["management-approval-verbal"] = "management-verbal-work-order",
  ["management-approval-written"] = "management-written-work-order",
  ["research-grant-approval"] = "research-grant-work-order",
}

-------------------------------------------------------------------------------
-- PAPERWORK BURDEN MODEL
-- Defines per-recipe paperwork requirements for each tier.
-- Keep this intentionally lean: broader paperwork coverage should come from
-- recipe tiering and intermediates, not by stuffing many extra forms into
-- every single recipe.
-------------------------------------------------------------------------------
shared.PAPERWORK_BURDEN_BY_FORM = {
  ["work-order"] = {
    {name = "work-order", amount = 1},
  },
  ["safety-waiver"] = {
    {name = "safety-waiver", amount = 1},
  },
  ["construction-permit"] = {
    {name = "construction-permit", amount = 1},
  },
  ["management-approval-verbal"] = {
    {name = "management-approval-verbal", amount = 1},
  },
  ["management-approval-written"] = {
    {name = "management-approval-written", amount = 1},
  },
  ["research-grant-approval"] = {
    {name = "research-grant-approval", amount = 1},
  },
}

function shared.get_paperwork_requirements(base_form, use_combined_forms)
  local burden = shared.PAPERWORK_BURDEN_BY_FORM[base_form]
  if not burden then
    burden = {{name = base_form, amount = 1}}
  end

  local expanded = {}
  local indexed = {}

  local function append_requirement(name, amount)
    if use_combined_forms and shared.COMBINED_FORMS[name] then
      name = shared.COMBINED_FORMS[name]
    end

    local existing = indexed[name]
    if existing then
      existing.amount = existing.amount + amount
      return
    end

    local requirement = {name = name, amount = amount}
    indexed[name] = requirement
    expanded[#expanded + 1] = requirement
  end

  for _, requirement in ipairs(burden) do
    append_requirement(requirement.name, requirement.amount or 1)
  end

  return expanded
end

-------------------------------------------------------------------------------
-- ADMIN BUILDINGS
-- Our mod's buildings. Their recipes are excluded from the regulation system
-- because they handle their own crafting categories and form requirements.
-------------------------------------------------------------------------------
shared.ADMIN_BUILDINGS = {
  ["admin-station"] = true,
  ["resolution-office"] = true,
  ["office-desk"] = true,
  ["field-office"] = true,
  ["greenhouse"] = true,
  ["corporate-breakroom"] = true,
  ["printer-t1"] = true,
  ["printer-t2"] = true,
  ["union-headquarters"] = true,
  ["mechanical-printer"] = true,
  ["tube-intake"] = true,
  ["tube-outtake"] = true,
  ["pneumatic-pipe"] = true,
  ["pneumatic-pipe-to-ground"] = true,
}

-------------------------------------------------------------------------------
-- FORM PRODUCTION RECIPES
-- Maps form item names to the recipe that produces them.
-- Used by is_admin_recipe() and FORM_PRODUCTION_RECIPE_SET for skip logic.
-- Form recipe unlocks are managed explicitly in technology.lua.
-------------------------------------------------------------------------------
shared.FORM_PRODUCTION_RECIPES = {
  ["work-order"] = "work-order-production",
  ["safety-waiver"] = "safety-waiver-printing",
  ["form-27b-6"] = "form-27b-6",
  ["construction-permit"] = "construction-permit-printing",
  ["management-approval-verbal"] = "management-verbal-printing",
  ["management-approval-written"] = "management-written-1st-printing",
  ["provisional-approval"] = "provisional-approval-production",
  ["research-grant-approval"] = "research-grant-approval-production",
  ["petrochemical-operating-permit"] = "petrochemical-operating-permit-production",
  ["blank-form"] = "blank-form-production",
  ["blank-approval"] = "blank-approval-production",
  ["blank-directive"] = "blank-directive-production",
  ["chemical-handling-work-order"] = "chemical-handling-work-order-production",
  ["radiological-work-order"] = "radiological-work-order-production",
}

-------------------------------------------------------------------------------
-- COMBINED FORM PRODUCTION RECIPES
-- Maps combined form names to the recipe that produces them.
-- Unlocks managed explicitly in technology.lua.
-------------------------------------------------------------------------------
shared.COMBINED_FORM_PRODUCTION_RECIPES = {
  ["safety-work-order"] = "safety-work-order-production",
  ["construction-work-order"] = "construction-work-order-production",
  ["management-verbal-work-order"] = "management-verbal-work-order-production",
  ["management-written-work-order"] = "management-written-work-order-production",
  ["research-grant-work-order"] = "research-grant-work-order-production",
}

-------------------------------------------------------------------------------
-- ADMIN RECIPE DETECTION
-- Returns true if a recipe name belongs to our mod and should NOT be processed
-- by the vanilla recipe regulation system.
-------------------------------------------------------------------------------
function shared.is_admin_recipe(name)
  -- Recipes that match admin patterns but should still be regulated
  local NOT_ADMIN = {
    ["paper-production"] = true,
    ["ink-production"] = true,
  }
  if NOT_ADMIN[name] then return false end
  if name:match("%-barrel$") or name:match("%-unbarrel$") then return false end

  -- Explicit building check
  if shared.ADMIN_BUILDINGS[name] then return true end

  -- Explicit form production recipe check
  for _, recipe_name in pairs(shared.FORM_PRODUCTION_RECIPES) do
    if name == recipe_name then return true end
  end

  -- Explicit combined form production recipe check
  for _, recipe_name in pairs(shared.COMBINED_FORM_PRODUCTION_RECIPES) do
    if name == recipe_name then return true end
  end

  -- Pattern-based detection for mod recipe naming conventions.
  local patterns = {
    -- Core admin patterns
    "^admin", "bureau", "^filing%-", "^case%-", "^brief%-",
    "^landscape%-final", "^smog%-final", "^noise%-final", "^unemployment%-final",
    "^littering%-final", "^hazmat%-final", "^loitering%-final", "^vagrancy%-final",
    -- Paperwork production
    "%-production$", "%-refining$", "%-batch$", "^copy%-",
    -- Specific item/recipe names
    "certificate", "form%-27b", "waiver", "approval",
    "permit", "clearance", "provisional",
    "bond", "grant", "slush", "ink", "audit",
    -- Combined forms
    "%-work%-order",
    -- Draft/printing pipeline
    "directive", "%-draft", "%-printing", "%-proposal", "%-review",
    -- BS economy
    "dubious%-data", "excuse", "gossip", "justification",
    "narrative", "white%-paper", "policy%-production", "regulation%-production",
    "promise", "eviction", "osha", "office%-drama",
    -- Rubble derivatives
    "useless%-documentation", "compacted%-rubble", "refined%-nonsense",
    -- Greenhouse & coffee
    "greenhouse", "coffee",
    -- Paper & forms
    "^blank%-form", "^blank%-approval", "^blank%-directive",
    -- Resolution
    "^resolved%-", "waiting%-zone",
    -- Pneumatic
    "^pneumatic%-", "^form%-liquifier", "^form%-solidifier",
    -- Science
    "administrative%-science",
    -- Biter employment
    "job%-offer", "biter%-worker", "biter%-logistics%-formation", "union%-delegate", "chemical%-operator", "nuclear%-technician",
    "specialist%-training",
  }
  for _, pat in ipairs(patterns) do
    if name:find(pat) then return true end
  end
  return false
end

-------------------------------------------------------------------------------
-- BATCH MULTIPLIERS
-- How many items are produced per regulated craft.
-- Determines effective form cost per item:
--   10x = 0.1 forms/item (bulk intermediates)
--    5x = 0.2 forms/item (standard items)
--    2x = 0.5 forms/item (machines, science)
--    1x = 1.0 forms/item (megastructures)
-------------------------------------------------------------------------------
shared.BATCH_MULTIPLIER_DEFAULT = 5
shared.BATCH_MULTIPLIERS = {
  -- Megastructures (1x = 1 form each)
  ["rocket-silo"] = 1,
  ["nuclear-reactor"] = 1,
  ["centrifuge"] = 1,
  ["beacon"] = 1,
  ["assembling-machine-3"] = 1,
  ["locomotive"] = 1,
  -- Machines & science (2x = 0.5 forms each)
  ["lab"] = 2,
  ["assembling-machine-1"] = 2,
  ["assembling-machine-2"] = 2,
  ["chemical-plant"] = 2,
  ["oil-refinery"] = 1,
  ["pumpjack"] = 5,
  ["roboport"] = 2,
  ["solar-panel"] = 5,
  ["accumulator"] = 5,
  ["splitter"] = 5,
  ["fast-splitter"] = 5,
  ["express-splitter"] = 5,
  ["automation-science-pack"] = 5,
  ["logistic-science-pack"] = 5,
  ["chemical-science-pack"] = 2,
  ["production-science-pack"] = 1,
  ["utility-science-pack"] = 1,
  ["space-science-pack"] = 1,
  -- High-volume intermediates (10x = 0.1 forms each)
  ["copper-cable"] = 10,
  ["iron-gear-wheel"] = 10,
  ["pipe"] = 10,
  ["heat-pipe"] = 10,
  ["transport-belt"] = 10,
  ["electronic-circuit"] = 10,
  ["ink"] = 10,
  ["ink-production"] = 10,
  ["pneumatic-pipe"] = 10,
  ["pneumatic-pipe-to-ground"] = 10,
  ["tube-intake"] = 10,
  ["tube-outtake"] = 10,
  ["iron-plate"] = 20,
  ["copper-plate"] = 20,
  ["steel-plate"] = 20,
  ["stone-brick"] = 20,
  ["plastic-bar"] = 10,
  ["sulfur"] = 10,
  ["battery"] = 10,
  ["explosives"] = 10,
  -- Ultra-high-volume (20x = 0.05 forms each)
  ["paper-production"] = 20,
}

-------------------------------------------------------------------------------
-- RULESET
-- Main branch keeps baseline (vanilla) regulation rules in a dedicated file.
-------------------------------------------------------------------------------
shared.COMPATIBILITY_RULESET = "vanilla"

function shared.get_required_form(recipe_name)
  return compatibility_rules.get_required_form(recipe_name)
end

-------------------------------------------------------------------------------
-- MACHINE OPERATION PAPERWORK
-- Recipe categories that do NOT use assembler work-orders.
-- Most machine families are category-wide, but petroleum handling splits:
-- baseline petrochem stays on the basic permit while advanced processing and
-- more demanding chemistry step up to the chemical work order.
-------------------------------------------------------------------------------
shared.OPERATING_FORM_BY_CATEGORY = compatibility_rules.OPERATING_FORM_BY_CATEGORY
shared.OPERATING_FORM_BY_RECIPE = compatibility_rules.OPERATING_FORM_BY_RECIPE

function shared.get_operating_form(recipe_or_name, category)
  local recipe_name = recipe_or_name
  if type(recipe_or_name) == "table" then
    recipe_name = recipe_or_name.name
    category = recipe_or_name.category
  end

  return shared.OPERATING_FORM_BY_RECIPE[recipe_name]
    or shared.OPERATING_FORM_BY_CATEGORY[category or "crafting"]
end

-------------------------------------------------------------------------------
-- TAXPAYER MONEY COSTS
-------------------------------------------------------------------------------
shared.TAXPAYER_MONEY_COSTS = compatibility_rules.TAXPAYER_MONEY_COSTS

return shared
