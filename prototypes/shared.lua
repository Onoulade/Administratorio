-- ADMINISTRATORIO: SHARED CONSTANTS
-- Single source of truth for constants used across data.lua and data-final-fixes.lua.

local shared = {}
local feature_flags = require("feature_flags")
local pneumatic_items = require("prototypes.shared.pneumatic_items")
local space_age_enabled = feature_flags.space_age_enabled()
local compatibility_rules = space_age_enabled
  and require("prototypes.shared.space_age_rules")
  or require("prototypes.shared.non_space_age_rules")

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
  ["blank-form"] = true,
  ["blank-approval"] = true,
  ["blank-directive"] = true,
  ["treasury-bond"] = true,
  ["government-grant"] = true,
  -- Combined forms (tier form + work-order)
  ["provisional-work-order"] = true,
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
shared.PNEUMATIC_ITEMS = pneumatic_items.as_set()

-------------------------------------------------------------------------------
-- COMBINED FORMS
-- Maps a tier form to its combined version (tier form + work-order).
-- Used by AM1/AM2/AM3 regulated recipes. The combined form is consumed (no return).
-- work-order has no combined form (it IS the base form for T0 items).
-------------------------------------------------------------------------------
shared.COMBINED_FORMS = {
  ["provisional-approval"] = "provisional-work-order",
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
  ["formation-center"] = true,
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

if space_age_enabled then
  shared.ADMIN_BUILDINGS["chromatic-printer"] = true
  shared.ADMIN_BUILDINGS["laser-printer"] = true
  shared.ADMIN_BUILDINGS["formation-center"] = true
  shared.ADMIN_BUILDINGS["administrative-space-station"] = true
  shared.ADMIN_BUILDINGS["trajectory-compliance-array"] = true
  shared.ADMIN_BUILDINGS["senior-trajectory-compliance-array"] = true
  shared.ADMIN_BUILDINGS["executive-trajectory-compliance-array"] = true
  shared.ADMIN_BUILDINGS["orbital-employment-catapult"] = true
  shared.ADMIN_BUILDINGS["notary-office"] = true
  shared.ADMIN_BUILDINGS["territorial-arbitration-post"] = true
  shared.ADMIN_BUILDINGS["capture-bureau"] = true
  shared.ADMIN_BUILDINGS["conciliation-desk"] = true
  shared.ADMIN_BUILDINGS["digital-services-bureau"] = true
  shared.ADMIN_BUILDINGS["interplanetary-terminus"] = true
  shared.ADMIN_BUILDINGS["ai-server"] = true
  shared.ADMIN_BUILDINGS["slop-refinery"] = true
  shared.ADMIN_BUILDINGS["synthetic-personnel-bureau"] = true
  shared.ADMIN_BUILDINGS["involuntary-relocation-cannon"] = true
  shared.ADMIN_BUILDINGS["involuntary-relocation-receiver"] = true
  shared.ADMIN_BUILDINGS["heat-exhaust"] = true
end

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
  ["blank-form"] = "blank-form-production",
  ["blank-approval"] = "blank-approval-production",
  ["blank-directive"] = "blank-directive-production",
  ["chemical-handling-work-order"] = "chemical-handling-work-order-production",
  ["radiological-work-order"] = "radiological-work-order-production",
}

if space_age_enabled then
  shared.PAPERWORK_ITEMS["heatproof-form-stock"] = true
  shared.PAPERWORK_ITEMS["blank-cyan-form"] = true
  shared.PAPERWORK_ITEMS["mycelial-form-stock"] = true
  shared.PAPERWORK_ITEMS["blank-yellow-form"] = true
  shared.PAPERWORK_ITEMS["signal-form-stock"] = true
  shared.PAPERWORK_ITEMS["blank-magenta-form"] = true
  shared.PAPERWORK_ITEMS["permit-draft"] = true
  shared.PAPERWORK_ITEMS["inspection-docket"] = true
  shared.PAPERWORK_ITEMS["embossed-seal"] = true
  shared.PAPERWORK_ITEMS["industrial-charter"] = true
  shared.PAPERWORK_ITEMS["territorial-resettlement-order"] = true
  shared.PAPERWORK_ITEMS["thermal-process-license"] = true
  shared.PAPERWORK_ITEMS["calcite-reagent-waiver"] = true
  shared.PAPERWORK_ITEMS["offworld-metallurgy-charter"] = true
  shared.PAPERWORK_ITEMS["symbiosis-record"] = true
  shared.PAPERWORK_ITEMS["conciliation-order"] = true
  shared.PAPERWORK_ITEMS["archive-recovery-permit"] = true
  shared.PAPERWORK_ITEMS["digital-processing-certificate"] = true
  shared.PAPERWORK_ITEMS["electromagnetic-operating-license"] = true
  shared.PAPERWORK_ITEMS["data-recovery-order"] = true
  shared.PAPERWORK_ITEMS["hardened-data-vault"] = true
  shared.PAPERWORK_ITEMS["asteroid-processing-docket"] = true
  shared.PAPERWORK_ITEMS["orbital-deviation-order"] = true
  shared.PAPERWORK_ITEMS["priority-orbital-deviation-order"] = true
  shared.PAPERWORK_ITEMS["orbital-operations-form"] = true
  shared.PAPERWORK_ITEMS["orbital-infrastructure-permit"] = true
  shared.PAPERWORK_ITEMS["cyan-yellow-form"] = true
  shared.PAPERWORK_ITEMS["cyan-magenta-form"] = true
  shared.PAPERWORK_ITEMS["yellow-magenta-form"] = true
  shared.PAPERWORK_ITEMS["trichromatic-permit"] = true
  shared.PAPERWORK_ITEMS["unified-operations-charter"] = true
  shared.PAPERWORK_ITEMS["cryogenic-operations-license"] = true
  shared.PAPERWORK_ITEMS["promethium-research-charter"] = true

  shared.FORM_PRODUCTION_RECIPES["heatproof-form-stock"] = "heatproof-form-stock"
  shared.FORM_PRODUCTION_RECIPES["blank-cyan-form"] = "blank-cyan-form-production"
  shared.FORM_PRODUCTION_RECIPES["mycelial-form-stock"] = "mycelial-form-stock"
  shared.FORM_PRODUCTION_RECIPES["blank-yellow-form"] = "blank-yellow-form-production"
  shared.FORM_PRODUCTION_RECIPES["signal-form-stock"] = "signal-form-stock"
  shared.FORM_PRODUCTION_RECIPES["blank-magenta-form"] = "blank-magenta-form-production"
  shared.FORM_PRODUCTION_RECIPES["permit-draft"] = "permit-draft"
  shared.FORM_PRODUCTION_RECIPES["inspection-docket"] = "inspection-docket"
  shared.FORM_PRODUCTION_RECIPES["embossed-seal"] = "embossed-seal"
  shared.FORM_PRODUCTION_RECIPES["industrial-charter"] = "industrial-charter"
  shared.FORM_PRODUCTION_RECIPES["territorial-resettlement-order"] = "territorial-resettlement-order"
  shared.FORM_PRODUCTION_RECIPES["thermal-process-license"] = "thermal-process-license"
  shared.FORM_PRODUCTION_RECIPES["calcite-reagent-waiver"] = "calcite-reagent-waiver"
  shared.FORM_PRODUCTION_RECIPES["offworld-metallurgy-charter"] = "offworld-metallurgy-charter"
  shared.FORM_PRODUCTION_RECIPES["symbiosis-record"] = "symbiosis-record"
  shared.FORM_PRODUCTION_RECIPES["conciliation-order"] = "conciliation-order"
  shared.FORM_PRODUCTION_RECIPES["archive-recovery-permit"] = "archive-recovery-permit"
  shared.FORM_PRODUCTION_RECIPES["digital-processing-certificate"] = "digital-processing-certificate"
  shared.FORM_PRODUCTION_RECIPES["electromagnetic-operating-license"] = "electromagnetic-operating-license"
  shared.FORM_PRODUCTION_RECIPES["data-recovery-order"] = "data-recovery-order"
  shared.FORM_PRODUCTION_RECIPES["hardened-data-vault"] = "hardened-data-vault-production"
  shared.FORM_PRODUCTION_RECIPES["orbital-deviation-order"] = "orbital-deviation-order"
  shared.FORM_PRODUCTION_RECIPES["priority-orbital-deviation-order"] = "priority-orbital-deviation-order"
  shared.FORM_PRODUCTION_RECIPES["orbital-operations-form"] = "orbital-operations-form"
  shared.FORM_PRODUCTION_RECIPES["orbital-infrastructure-permit"] = "orbital-infrastructure-permit"
  shared.FORM_PRODUCTION_RECIPES["cyan-yellow-form"] = "cyan-yellow-form-production"
  shared.FORM_PRODUCTION_RECIPES["cyan-magenta-form"] = "cyan-magenta-form-production"
  shared.FORM_PRODUCTION_RECIPES["yellow-magenta-form"] = "yellow-magenta-form-production"
  shared.FORM_PRODUCTION_RECIPES["trichromatic-permit"] = "trichromatic-permit-production"
  shared.FORM_PRODUCTION_RECIPES["unified-operations-charter"] = "unified-operations-charter-production"
  shared.FORM_PRODUCTION_RECIPES["cryogenic-operations-license"] = "cryogenic-operations-license-production"
  shared.FORM_PRODUCTION_RECIPES["promethium-research-charter"] = "promethium-research-charter-production"
end

-------------------------------------------------------------------------------
-- COMBINED FORM PRODUCTION RECIPES
-- Maps combined form names to the recipe that produces them.
-- Unlocks managed explicitly in technology.lua.
-------------------------------------------------------------------------------
shared.COMBINED_FORM_PRODUCTION_RECIPES = {
  ["provisional-work-order"] = "provisional-work-order-production",
  ["safety-work-order"] = "safety-work-order-production",
  ["construction-work-order"] = "construction-work-order-production",
  ["management-verbal-work-order"] = "management-verbal-work-order-production",
  ["management-written-work-order"] = "management-written-work-order-production",
  ["research-grant-work-order"] = "research-grant-work-order-production",
}

-- ADMIN RECIPE REGISTRATION
--
-- Recipes are registered while Administratorio loads its own prototype files
-- (see data.lua).  This deliberately avoids name-pattern guessing: a third
-- party recipe named "permit-production" is not ours merely because it has a
-- bureaucratic-sounding name.
-------------------------------------------------------------------------------
shared.ADMIN_RECIPE_REGULATION_EXEMPTIONS = {
  -- These Administratorio recipes intentionally enter the vanilla regulation
  -- path; they are base materials in the automated economy.
  ["paper-production"] = true,
  ["ink-production"] = true,
}

-- These ordinary recipes still need a copy on the regulated assembler
-- category, but automation consumes no paperwork and preserves native recipe
-- quantities. Underground pipe construction is intentionally not exempt.
shared.PAPERWORK_FREE_REGULATED_RECIPES = {
  ["pipe"] = true,
}
shared.ADMIN_RECIPE_NAMES = {}

function shared.register_admin_recipe(name)
  if name and not shared.ADMIN_RECIPE_REGULATION_EXEMPTIONS[name] then
    shared.ADMIN_RECIPE_NAMES[name] = true
  end
end

function shared.register_admin_recipe_prototypes(prototypes)
  for _, prototype in ipairs(prototypes or {}) do
    if prototype.type == "recipe" then
      shared.register_admin_recipe(prototype.name)
    end
  end
end

-- Form-production recipes are declared in this shared module rather than in a
-- single prototype file, so register them directly as well. This keeps the
-- classifier correct for focused tests and for any future loader that does not
-- use data.lua's prototype-registration wrapper.
for _, recipe_name in pairs(shared.FORM_PRODUCTION_RECIPES) do
  shared.register_admin_recipe(recipe_name)
end
for _, recipe_name in pairs(shared.COMBINED_FORM_PRODUCTION_RECIPES) do
  shared.register_admin_recipe(recipe_name)
end

function shared.is_admin_recipe(name)
  if shared.ADMIN_RECIPE_REGULATION_EXEMPTIONS[name] then return false end
  return shared.ADMIN_RECIPE_NAMES[name] == true
    or shared.ADMIN_BUILDINGS[name] == true
end

-------------------------------------------------------------------------------
-- UNBATCHED RESULT SUBGROUPS
-- Space construction outputs should always stay at 1x even when they live in
-- normal crafting categories, so platform infrastructure and launch hardware
-- do not inherit bulk recipe treatment.
-------------------------------------------------------------------------------
shared.UNBATCHED_RESULT_SUBGROUPS = {
  ["space-related"] = true,
  ["space-platform"] = true,
  ["space-rocket"] = true,
  ["space-interactors"] = true,
}

-- Space Age recipes are conservative by default. Explicit multiplier entries
-- may opt true intermediates into larger batches, while new orbital buildings
-- and compatible platform content remain 1x without another name allowlist.
shared.UNBATCHED_RESULT_SUBGROUP_PREFIXES = {
  "space-",
  "admin-space-",
}

-- Placeable structures whose construction is intrinsically tied to a space
-- platform. data-final-fixes also discovers compatible placeable items in the
-- vanilla "space-platform" subgroup so newly added platform buildings inherit
-- the same permit rule automatically. Foundation tiles and starter packs are
-- deliberately absent: they bootstrap the platform rather than build on it.
shared.SPACE_PLATFORM_BUILDING_RECIPES = {
  ["cargo-bay"] = true,
  ["asteroid-collector"] = true,
  ["crusher"] = true,
  ["thruster"] = true,
  ["administrative-space-station"] = true,
  ["trajectory-compliance-array"] = true,
  ["senior-trajectory-compliance-array"] = true,
  ["executive-trajectory-compliance-array"] = true,
  ["orbital-employment-catapult"] = true,
}

shared.UNBATCHED_RESULT_NAMES = {
  -- Vanilla Space Age buildings and launch/space infrastructure.
  ["rocket-silo"] = true,
  ["cargo-landing-pad"] = true,
  ["space-platform-foundation"] = true,
  ["space-platform-starter-pack"] = true,
  ["cargo-bay"] = true,
  ["asteroid-collector"] = true,
  ["crusher"] = true,
  ["thruster"] = true,
  ["foundry"] = true,
  ["big-mining-drill"] = true,
  ["agricultural-tower"] = true,
  ["biochamber"] = true,
  ["biolab"] = true,
  ["captive-biter-spawner"] = true,
  ["lightning-rod"] = true,
  ["lightning-collector"] = true,
  ["heating-tower"] = true,
  ["electromagnetic-plant"] = true,
  ["fusion-reactor"] = true,
  ["fusion-generator"] = true,
  ["cryogenic-plant"] = true,
  ["rocket-turret"] = true,
  ["tesla-turret"] = true,
  ["railgun-turret"] = true,
  ["capture-robot-rocket"] = true,
  ["railgun-ammo"] = true,
  ["foundation"] = true,
  ["ice-platform"] = true,

  -- Space Age editor/debug infrastructure also keeps its native quantities.
  ["heat-interface"] = true,
  ["infinity-chest"] = true,
  ["infinity-pipe"] = true,

  -- Administratorio Space Age buildings.
  ["trajectory-compliance-array"] = true,
  ["formation-center"] = true,
  ["chromatic-printer"] = true,
  ["notary-office"] = true,
  ["territorial-arbitration-post"] = true,
  ["capture-bureau"] = true,
  ["conciliation-desk"] = true,
  ["digital-services-bureau"] = true,
  ["laser-printer"] = true,
  ["interplanetary-terminus"] = true,
  ["ai-server"] = true,
  ["slop-refinery"] = true,
  ["synthetic-personnel-bureau"] = true,
  ["involuntary-relocation-cannon"] = true,
  ["involuntary-relocation-receiver"] = true,
  ["heat-exhaust"] = true,
}

-- Platform construction policy is also a hard 1x batch policy. Derive the
-- batch view from the permit-policy set so these two declarations cannot drift.
for recipe_name in pairs(shared.SPACE_PLATFORM_BUILDING_RECIPES) do
  shared.UNBATCHED_RESULT_NAMES[recipe_name] = true
end

-------------------------------------------------------------------------------
-- BATCH MULTIPLIERS
-- Semantic defaults classify production buildings at 2x, repeatable tool
-- infrastructure at 5x, and ordinary items at 5x. This table contains only
-- deliberate balance exceptions and high-volume intermediates.
-- How many items are produced per regulated craft.
-- Determines effective form cost per item:
--   10x = 0.1 forms/item (bulk intermediates)
--    5x = 0.2 forms/item (standard items)
--    2x = 0.5 forms/item (machines, science)
--    1x = 1.0 forms/item (megastructures)
-------------------------------------------------------------------------------
shared.BATCH_MULTIPLIER_DEFAULT = 5
shared.BATCH_MULTIPLIER_BUILDING = 2
shared.BATCH_MULTIPLIER_TOOL = 5
shared.BATCH_MULTIPLIERS = {
  -- Megastructures (1x = 1 form each)
  ["rocket-silo"] = 1,
  ["nuclear-reactor"] = 1,
  ["centrifuge"] = 1,
  ["beacon"] = 1,
  ["assembling-machine-3"] = 1,
  ["locomotive"] = 1,
  ["union-headquarters"] = 1,
  ["electric-furnace"] = 1,
  ["heat-exchanger"] = 1,
  ["steam-turbine"] = 1,
  -- Exceptional production buildings (1x = 1 form each)
  ["oil-refinery"] = 1,
  -- Science remains an explicit economic progression.
  ["automation-science-pack"] = 5,
  ["logistic-science-pack"] = 5,
  ["chemical-science-pack"] = 2,
  ["production-science-pack"] = 1,
  ["utility-science-pack"] = 1,
  ["space-science-pack"] = 1,
  -- High-volume intermediates (10x = 0.1 forms each)
  ["copper-cable"] = 10,
  ["iron-gear-wheel"] = 10,
  ["electronic-circuit"] = 10,
  ["ink"] = 10,
  ["ink-production"] = 10,
  -- Repeatable tool infrastructure (5x = 0.2 forms each). These explicit
  -- entries also document mod prototypes that may not expose a vanilla entity
  -- type to compatibility-test fixtures.
  -- Heat-pipe segments are consumed like intermediates despite being
  -- placeable infrastructure, so their high-volume 10x economics are explicit.
  ["heat-pipe"] = 10,
  ["transport-belt"] = 5,
  ["pipe-to-ground"] = 5,
  ["pneumatic-pipe"] = 5,
  ["pneumatic-pipe-to-ground"] = 5,
  ["tube-intake"] = 5,
  ["tube-outtake"] = 5,
  -- High-end logistics are made in smaller installation lots.
  ["express-transport-belt"] = 2,
  ["express-underground-belt"] = 2,
  ["express-splitter"] = 2,
  ["stack-inserter"] = 2,
  ["bulk-inserter"] = 2,
  ["turbo-transport-belt"] = 2,
  ["turbo-underground-belt"] = 2,
  ["turbo-splitter"] = 2,
  ["turbo-loader"] = 2,
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

-- COMPATIBILITY RULESET
-- Non-Space-Age and Space-Age rules are split into separate files so each
-- mode can evolve independently without mixing conditionals across this file.
-------------------------------------------------------------------------------
shared.SPACE_AGE_ENABLED = space_age_enabled
shared.COMPATIBILITY_RULESET = space_age_enabled and "space-age" or "non-space-age"

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
shared.OPERATING_FORM_CONFIG = compatibility_rules.OPERATING_FORM_CONFIG

-- Compatibility views for consumers that still inspect the old tables. The
-- rule source remains OPERATING_FORM_CONFIG, so category defaults, recipe
-- overrides, and exemptions cannot drift across parallel structures.
shared.OPERATING_FORM_BY_CATEGORY = {}
shared.OPERATING_FORM_BY_RECIPE = {}
shared.OPERATING_FORM_EXEMPT_BY_CATEGORY = {}
shared.OPERATING_FORM_EXEMPT_BY_RECIPE = {}
for category, rule in pairs(shared.OPERATING_FORM_CONFIG.categories or {}) do
  if rule.exempt then
    shared.OPERATING_FORM_EXEMPT_BY_CATEGORY[category] = true
  elseif rule.form then
    shared.OPERATING_FORM_BY_CATEGORY[category] = rule.form
  end
end
for recipe_name, rule in pairs(shared.OPERATING_FORM_CONFIG.recipes or {}) do
  if rule.exempt then
    shared.OPERATING_FORM_EXEMPT_BY_RECIPE[recipe_name] = true
  elseif rule.form then
    shared.OPERATING_FORM_BY_RECIPE[recipe_name] = rule.form
  end
end

function shared.get_operating_form(recipe_or_name, category)
  local recipe_name = recipe_or_name
  if type(recipe_or_name) == "table" then
    recipe_name = recipe_or_name.name
    category = recipe_or_name.category
  end

  local recipe_rule = shared.OPERATING_FORM_CONFIG.recipes[recipe_name]
  if recipe_rule then
    return recipe_rule.exempt and nil or recipe_rule.form
  end

  local category_rule = shared.OPERATING_FORM_CONFIG.categories[category or "crafting"]
  if category_rule then
    return category_rule.exempt and nil or category_rule.form
  end
end

-------------------------------------------------------------------------------
-- TAXPAYER MONEY COSTS
-------------------------------------------------------------------------------
shared.TAXPAYER_MONEY_COSTS = compatibility_rules.TAXPAYER_MONEY_COSTS

return shared
