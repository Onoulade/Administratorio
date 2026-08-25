local function entity_recipe(name, recipe)
  recipe.name = name
  recipe.localised_name = {"item-name." .. name}
  recipe.localised_description = {"item-description." .. name}
  return recipe
end

local icon_tints = require("prototypes.shared.icon_tints")
local space_age_enabled = require("feature_flags").space_age_enabled()
local worker_item_name = space_age_enabled and "worker-biter" or "biter-worker"

local function rgba(r, g, b, a)
  return {r = r, g = g, b = b, a = a or 1}
end

local function clamp01(value)
  return math.min(math.max(value, 0), 1)
end

local function mix_color(a, b, weight)
  local inv = 1 - weight
  return rgba(
    a.r * inv + b.r * weight,
    a.g * inv + b.g * weight,
    a.b * inv + b.b * weight,
    (a.a or 1) * inv + (b.a or 1) * weight
  )
end

local function brighten(color, factor)
  return rgba(
    clamp01(color.r * factor),
    clamp01(color.g * factor),
    clamp01(color.b * factor),
    color.a or 1
  )
end

local DISTILLERY_FLUID_TINTS = {
  ["slush-fund"] = rgba(0.3, 0.5, 0.3, 1),
  ["politician-fluid"] = rgba(0.7, 0.1, 0.1, 1),
  ["lie"] = rgba(1.0, 1.0, 0.0, 1),
  ["misinformation"] = rgba(0.8, 0.8, 0.8, 1),
}

local function distillery_recipe_tint(primary_name, secondary_name)
  local primary = DISTILLERY_FLUID_TINTS[primary_name]
  local secondary = DISTILLERY_FLUID_TINTS[secondary_name] or primary
  return {
    primary = primary,
    secondary = secondary,
    tertiary = brighten(mix_color(primary, secondary, 0.35), 0.85),
    quaternary = brighten(secondary, 1.15),
  }
end

-- In the base game, creative accounting provides a late-game way to turn
-- treasury bonds back into taxpayer money. Space Age deliberately replaces
-- that renewable-money loop with orbital tourism, so neither half of the
-- laundering chain is registered when the expansion is active.
if not space_age_enabled then
  data:extend({
    {
      type = "recipe", name = "tax-audit", category = "bureaucracy-policy", enabled = false,
      subgroup = "admin-money", order = "f-a",
      ingredients = {{type="fluid", name="slush-fund", amount=200}, {type="item", name="blank-form", amount=1}, {type="item", name="data", amount=1}, {type="fluid", name="liquid-coffee", amount=15}},
      results = {{type="item", name="taxpayer-money", amount=30}},
      energy_required = 20,
      crafting_machine_tint = icon_tints.recipe_tint("tax-audit")
    },
    {
      type = "recipe", name = "slush-fund-production", category = "propaganda-distillery", enabled = false,
      icon = "__administratorio__/graphics/icons/slush-fund.png", icon_size = 64,
      subgroup = "admin-fluid-economy", order = "d-g",
      ingredients = {{type="item", name="treasury-bond", amount=1}, {type="fluid", name="lie", amount=50}},
      results = {{type="fluid", name="slush-fund", amount=500}},
      energy_required = 30,
      crafting_machine_tint = distillery_recipe_tint("lie", "slush-fund")
    },
  })
end

data:extend({
  -- Taxpayer Money System -> admin-money
  { type = "recipe", name = "treasury-bond-production",    category = "bureaucracy-registration", enabled = false, auto_recycle = false, subgroup = "admin-money", order = "f-b", ingredients = {{type="item", name="taxpayer-money", amount=50}, {type="item", name="blank-form", amount=1}, {type="item", name="useless-documentation", amount=1}, {type="fluid", name="liquid-coffee", amount=10}}, results = {{type="item", name="treasury-bond", amount=1}},    energy_required = 5 },
  { type = "recipe", name = "government-grant-production", category = "union-negotiation", enabled = false, subgroup = "admin-money", order = "f-c", ingredients = {{type="item", name="treasury-bond", amount=10}, {type="item", name="crappy-report", amount=1}, {type="item", name="management-approval-verbal", amount=1}}, results = {{type="item", name="government-grant", amount=1}}, energy_required = 15, crafting_machine_tint = icon_tints.recipe_tint("government-grant-production") },

  -- Data Economy -> admin-data-economy
  { type = "recipe", name = "dubious-data-refining",     category = "smelting",        enabled = false, subgroup = "admin-data-economy", order = "c-a", ingredients = {{type="item", name="bullshit-ore", amount=10}},                                                     results = {{type="item", name="dubious-data", amount=20}},     energy_required = 64 },
  { type = "recipe", name = "basic-excuse-production",   category = "bureaucratic-bootstrap", enabled = false, subgroup = "admin-gossip-economy", order = "h-a", ingredients = {{type="item", name="dubious-data", amount=5}},                                                      results = {{type="item", name="basic-excuse", amount=1}},      energy_required = 5 },
  { type = "recipe", name = "crappy-report-production",  category = "bureaucracy-registration", enabled = false, subgroup = "admin-data-economy", order = "c-b", ingredients = {{type="item", name="dubious-data", amount=5}, {type="item", name="paper", amount=2}},                            results = {{type="item", name="crappy-report", amount=1}},     energy_required = 5 },
  {
    type = "recipe", name = "politician-fluid-refining", category = "propaganda-distillery", enabled = false,
    icon = "__administratorio__/graphics/icons/lie.png", icon_size = 64,
    subgroup = "admin-fluid-economy", order = "d-a",
    ingredients = {{type="fluid", name="politician-fluid", amount=100}},
    results = {{type="fluid", name="lie", amount=50}},
    energy_required = 5,
    crafting_machine_tint = distillery_recipe_tint("politician-fluid", "lie")
  },
  { type = "recipe", name = "credentials-production", category = "bureaucracy-registration", enabled = false, subgroup = "admin-data-economy", order = "c-c", ingredients = {{type="fluid", name="lie", amount=35}, {type="item", name="dubious-data", amount=4}, {type="item", name="refined-nonsense", amount=1}, {type="item", name="electronic-circuit", amount=2}}, results = {{type="item", name="credentials", amount=1}}, energy_required = 10 },
  { type = "recipe", name = "data-production",           category = "bureaucracy-registration", enabled = false, subgroup = "admin-data-economy", order = "c-d", ingredients = {{type="item", name="crappy-report", amount=1}, {type="item", name="advanced-circuit", amount=2}, {type="fluid", name="liquid-coffee", amount=15}},     results = {{type="item", name="data", amount=1}},             energy_required = 10 },
  { type = "recipe", name = "good-excuse-production",    category = "watercooler-gossip",       enabled = false, subgroup = "admin-gossip-economy", order = "h-b",
    ingredients = {{type="item", name="data", amount=1}, {type="fluid", name="lie", amount=50}, {type="item", name="watercooler-gossip", amount=1}},
    results = {{type="item", name="good-excuse", amount=1}, {type="item", name="office-drama", amount=1, probability=0.5}},
    main_product = "good-excuse",
    energy_required = 10 },
  { type = "recipe", name = "misinformation-production", category = "propaganda-distillery",       enabled = false, subgroup = "admin-fluid-economy", order = "d-b", ingredients = {{type="fluid", name="lie", amount=50},         {type="item", name="dubious-data", amount=1}},                                              results = {{type="fluid", name="misinformation", amount=50}}, energy_required = 5, crafting_machine_tint = distillery_recipe_tint("lie", "misinformation") },
  { type = "recipe", name = "justification-production",  category = "propaganda-distillery",       enabled = false, subgroup = "admin-fluid-economy", order = "d-c", ingredients = {{type="fluid", name="misinformation", amount=50}, {type="item", name="credentials", amount=1}, {type="fluid", name="politician-fluid", amount=50}}, results = {{type="item", name="justification", amount=1}},    energy_required = 15, crafting_machine_tint = distillery_recipe_tint("misinformation", "politician-fluid") },
  { type = "recipe", name = "narrative-production",      category = "union-negotiation", enabled = false, subgroup = "admin-gossip-economy", order = "h-c",
    ingredients = {{type="item", name="justification", amount=1}, {type="item", name="good-excuse", amount=1}, {type="item", name="watercooler-gossip", amount=1}},
    results = {{type="item", name="narrative", amount=1}, {type="item", name="office-drama", amount=1, probability=0.3}},
    main_product = "narrative",
    energy_required = 20,
    crafting_machine_tint = icon_tints.recipe_tint("narrative-production") },

  -- Policy Economy -> admin-policy-economy
  { type = "recipe", name = "white-paper-production",    category = "bureaucracy-policy",       enabled = false, subgroup = "admin-policy-economy", order = "e-a", ingredients = {{type="item", name="paper", amount=8}, {type="item", name="processing-unit", amount=1}, {type="item", name="treasury-bond", amount=1}, {type="fluid", name="lie", amount=35}, {type="fluid", name="liquid-coffee", amount=20}}, results = {{type="item", name="white-paper", amount=1}},      energy_required = 30, crafting_machine_tint = icon_tints.recipe_tint("white-paper-production") },
  { type = "recipe", name = "policy-production",         category = "bureaucracy-policy", enabled = false, subgroup = "admin-policy-economy", order = "e-b", ingredients = {{type="item", name="white-paper", amount=1}, {type="fluid", name="misinformation", amount=80}, {type="item", name="treasury-bond", amount=1}, {type="item", name="processing-unit", amount=1}, {type="fluid", name="liquid-coffee", amount=30}}, results = {{type="item", name="policy", amount=1}},     energy_required = 45, crafting_machine_tint = icon_tints.recipe_tint("policy-production") },
  { type = "recipe", name = "regulation-production",     category = "bureaucracy-policy", enabled = false, subgroup = "admin-policy-economy", order = "e-c", ingredients = {{type="item", name="policy", amount=1}, {type="item", name="treasury-bond", amount=2}, {type="item", name="processing-unit", amount=2}, {type="fluid", name="liquid-coffee", amount=35}}, results = {{type="item", name="regulation", amount=1}}, energy_required = 60, crafting_machine_tint = icon_tints.recipe_tint("regulation-production") },

  -- Promise, Hush Money & Eviction -> admin-money
  { type = "recipe", name = "hush-money-production",      category = "bureaucratic-bootstrap", enabled = false, subgroup = "admin-money", order = "f-d", ingredients = {{type="item", name="taxpayer-money", amount=50}, {type="item", name="form-27b-6", amount=1}, {type="item", name="useless-documentation", amount=1}}, results = {{type="item", name="hush-money", amount=1}}, energy_required = 10 },
  { type = "recipe", name = "promise-production",         category = "bureaucratic-bootstrap", enabled = false, subgroup = "admin-money", order = "f-e", ingredients = {{type="item", name="blank-form", amount=3}, {type="item", name="dubious-data", amount=5}, {type="item", name="provisional-approval", amount=2}, {type="item", name="paper", amount=5}}, results = {{type="item", name="promise", amount=1}},         energy_required = 15 },
  { type = "recipe", name = "eviction-notice-production", category = "bureaucracy-registration", enabled = false, subgroup = "admin-money", order = "f-f", ingredients = {{type="item", name="good-excuse", amount=1}, {type="item", name="credentials", amount=1}, {type="fluid", name="politician-fluid", amount=50}, {type="item", name="taxpayer-money", amount=100}}, results = {{type="item", name="eviction-notice", amount=1}}, energy_required = 30 },

  -- Gossip & Corporate -> admin-gossip-economy
  entity_recipe("corporate-breakroom", { type = "recipe", enabled = false, subgroup = "admin-buildings", order = "h-c", ingredients = {{type="item", name="iron-plate", amount=16}, {type="item", name="wood", amount=8}, {type="item", name="stone-brick", amount=8}, {type="item", name="pipe", amount=3}, {type="item", name="electronic-circuit", amount=4}, {type="item", name="construction-permit", amount=1}}, results = {{type="item", name="corporate-breakroom", amount=1}}, energy_required = 10 }),
  { type = "recipe", name = "watercooler-gossip-production",  category = "watercooler-gossip", enabled = false, subgroup = "admin-gossip-economy", order = "h-d", ingredients = {{type="fluid", name="liquid-coffee", amount=50}, {type="item", name="dubious-data", amount=2}}, results = {{type="item", name="watercooler-gossip", amount=1}}, energy_required = 5 },
  {
    type = "recipe", name = "office-drama-recycling", category = "watercooler-gossip", enabled = false,
    icon = "__administratorio__/graphics/icons/watercooler-gossip.png", icon_size = 64,
    subgroup = "admin-gossip-economy", order = "h-e",
    ingredients = {{type="item", name="office-drama", amount=3}, {type="fluid", name="liquid-coffee", amount=25}},
    results = {
      {type="item", name="work-order", amount=1, probability=0.5},
      {type="item", name="watercooler-gossip", amount=1, probability=0.5},
      {type="item", name="basic-excuse", amount=1, probability=0.5},
    },
    energy_required = 6
  },

  -- OSHA Scrubbing -> admin-fluid-economy
  { type = "recipe", name = "osha-scrubbing", category = "union-negotiation", enabled = false, subgroup = "admin-fluid-economy", order = "d-e", ingredients = {{type="item", name="osha-violation", amount=1}, {type="item", name="refined-nonsense", amount=2}, {type="fluid", name="union-approval", amount=50}}, results = {{type="item", name="justification", amount=1}}, energy_required = 10, crafting_machine_tint = icon_tints.recipe_tint("osha-scrubbing") },
  {
    type = "recipe", name = "osha-violation-recycling", category = "union-negotiation", enabled = false,
    icon = "__administratorio__/graphics/icons/osha-violation.png", icon_size = 64,
    subgroup = "admin-fluid-economy", order = "d-f",
    ingredients = {{type="item", name="osha-violation", amount=5}, {type="fluid", name="liquid-coffee", amount=50}},
    results = {
      {type="item", name="blank-form", amount=1, probability=0.6},
      {type="item", name="blank-approval", amount=1, probability=0.3},
      {type="item", name="basic-excuse", amount=1, probability=0.5},
      {type="item", name="dubious-data", amount=2, probability=0.7},
      {type="item", name="work-order", amount=1, probability=0.4},
      {type="item", name="provisional-approval", amount=1, probability=0.2},
    },
    energy_required = 8,
    crafting_machine_tint = icon_tints.recipe_tint("osha-violation-recycling")
  },

  -- Refined Nonsense -> admin-gossip-economy
  {
    type = "recipe", name = "refined-nonsense-production", category = "watercooler-gossip", enabled = false, subgroup = "admin-gossip-economy", order = "h-f",
    ingredients = {{type="item", name="compacted-rubble", amount=3}, {type="fluid", name="misinformation", amount=100}},
    results = {{type="item", name="refined-nonsense", amount=1}},
    energy_required = 10
  },

  -- Union Negotiation -> admin-fluid-economy
  {
    type = "recipe", name = "union-approval-production", category = "union-negotiation", enabled = false, subgroup = "admin-fluid-economy", order = "d-d",
    ingredients = {
      {type="fluid", name="liquid-coffee", amount=70},
      {type="item", name="paper", amount=4},
      {type="item", name="dubious-data", amount=4},
      {type="item", name="taxpayer-money", amount=8}
    },
    results = {{type="fluid", name="union-approval", amount=150}},
    energy_required = 10,
    crafting_machine_tint = icon_tints.recipe_tint("union-approval-production")
  },

  -- Biter Employment -> admin-biter-training (renamed from admin-biter-employees)
  {
    type = "recipe", name = "rideable-biter",
    subgroup = "admin-biter-training",
    localised_name = {"item-name.rideable-biter"},
    localised_description = {"item-description.rideable-biter"},
    category = "biter-training", enabled = false,
    order = "b-a",
    ingredients = {
      {type="item", name=worker_item_name, amount=1},
      {type="item", name="blank-approval", amount=2},
      {type="item", name="management-verbal-work-order", amount=1},
      {type="fluid", name="liquid-coffee", amount=25},
    },
    results = {{type="item", name="rideable-biter", amount=1}},
    energy_required = 20
  },
  {
    type = "recipe", name = "job-offer-production", subgroup = "admin-biter-training", category = "bureaucracy-registration", enabled = false, order = "b-b",
    ingredients = {
      {type="item", name="taxpayer-money", amount=50},
      {type="item", name="blank-form", amount=5},
      {type="item", name="provisional-approval", amount=1},
      {type="item", name="redundant-rubble", amount=1},
    },
    results = {{type="item", name="job-offer", amount=1}},
    energy_required = 15
  },
  {
    type = "recipe", name = "biter-logistics-formation", subgroup = "admin-biter-logistics", category = "biter-training", enabled = false, order = "d",
    ingredients = {
      {type="item", name=worker_item_name, amount=1},
      {type="item", name="management-verbal-work-order", amount=1},
      {type="item", name="form-27b-6", amount=1},
      {type="fluid", name="liquid-coffee", amount=35},
    },
    results = {{type="item", name="biter-logistics-formation", amount=1}},
    energy_required = 30
  },

  -- Specialist Training -> admin-biter-management
  {
    type = "recipe", name = "union-delegate-training", subgroup = "admin-biter-management", category = "biter-training", enabled = false, order = "c-a",
    ingredients = {
      {type="item", name=worker_item_name, amount=1},
      {type="item", name="management-verbal-work-order", amount=1},
      {type="item", name="form-27b-6", amount=1},
      {type="fluid", name="liquid-coffee", amount=50},
    },
    results = {{type="item", name="union-delegate", amount=1}},
    energy_required = 20
  },
  {
    type = "recipe", name = "chemical-operator-training", subgroup = "admin-biter-operations", category = "biter-training", enabled = false, order = "d-a",
    ingredients = {
      {type="item", name=worker_item_name, amount=1},
      {type="item", name="chemical-handling-work-order", amount=1},
      {type="item", name="safety-waiver", amount=1},
      {type="fluid", name="liquid-coffee", amount=45},
    },
    results = {{type="item", name="chemical-operator", amount=1}},
    energy_required = 30
  },
  {
    type = "recipe", name = "nuclear-technician-training", subgroup = "admin-biter-operations", category = "biter-training", enabled = false, order = "d-b",
    ingredients = {
      {type="item", name=worker_item_name, amount=1},
      {type="item", name="radiological-work-order", amount=1},
      {type="item", name="management-approval-written", amount=1},
      {type="item", name="environmental-impact-report", amount=1},
      {type="fluid", name="liquid-coffee", amount=60},
    },
    results = {{type="item", name="nuclear-technician", amount=1}},
    energy_required = 30
  },
  {
    type = "recipe", name = "hired-biter-capsule", subgroup = "admin-biter-operations",
    localised_name = {"item-name.hired-biter-capsule"},
    localised_description = {"item-description.hired-biter-capsule"},
    category = "biter-training", enabled = false, order = "d-c",
    ingredients = {
      {type="item", name=worker_item_name,    amount=1},
      {type="item", name="treasury-bond", amount=2},
      {type="item", name="management-written-work-order", amount=2},
      {type="item", name="research-grant-work-order", amount=1},
      {type="fluid", name="liquid-coffee", amount=100},
    },
    results = {{type="item", name="hired-biter-capsule", amount=1}},
    energy_required = 120
  },
  {
    type = "recipe", name = "hired-biter-command-capsule", subgroup = "admin-biter-operations",
    localised_name = {"item-name.hired-biter-command-capsule"},
    localised_description = {"item-description.hired-biter-command-capsule"},
    category = "bureaucracy-registration", enabled = false, order = "d-d",
    ingredients = {
      {type="item", name="processing-unit",  amount=1},
      {type="item", name="advanced-circuit", amount=3},
      {type="item", name="taxpayer-money",   amount=5},
    },
    results = {{type="item", name="hired-biter-command-capsule", amount=1}},
    energy_required = 5
  },
})
