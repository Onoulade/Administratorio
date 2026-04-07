local function entity_recipe(name, recipe)
  recipe.name = name
  recipe.localised_name = {"item-name." .. name}
  recipe.localised_description = {"item-description." .. name}
  return recipe
end

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

data:extend({
  -- Taxpayer Money System
  { type = "recipe", name = "treasury-bond-production",    category = "bureaucracy-registration", enabled = false, ingredients = {{type="item", name="taxpayer-money", amount=10}, {type="item", name="blank-form", amount=1}, {type="item", name="useless-documentation", amount=1}, {type="fluid", name="liquid-coffee", amount=10}}, results = {{type="item", name="treasury-bond", amount=1}},    energy_required = 5 },
  { type = "recipe", name = "government-grant-production", category = "union-negotiation", enabled = false, ingredients = {{type="item", name="treasury-bond", amount=2},  {type="item", name="crappy-report", amount=1}, {type="item", name="management-approval-verbal", amount=1}},  results = {{type="item", name="government-grant", amount=1}}, energy_required = 15 },
  {
    type = "recipe", name = "tax-audit", category = "bureaucracy-policy", enabled = false,
    ingredients = {{type="fluid", name="slush-fund", amount=100}, {type="item", name="taxpayer-money", amount=10}, {type="item", name="blank-form", amount=1}, {type="item", name="useless-documentation", amount=1}, {type="item", name="data", amount=1}, {type="fluid", name="liquid-coffee", amount=25}},
    results = {{type="item", name="taxpayer-money", amount=30}},
    energy_required = 10
  },
  {
    type = "recipe", name = "slush-fund-production", category = "propaganda-distillery", enabled = false,
    icon = "__administratorio__/graphics/icons/slush-fund.png", icon_size = 64,
    subgroup = "admin-money", order = "d",
    ingredients = {{type="item", name="treasury-bond", amount=5}, {type="fluid", name="lie", amount=50}},
    results = {{type="fluid", name="slush-fund", amount=500}},
    energy_required = 30,
    crafting_machine_tint = distillery_recipe_tint("lie", "slush-fund")
  },

  -- Bullshit Economy
  { type = "recipe", name = "dubious-data-refining",     category = "smelting",        enabled = false, ingredients = {{type="item", name="bullshit-ore", amount=10}},                                                     results = {{type="item", name="dubious-data", amount=20}},     energy_required = 64 },
  { type = "recipe", name = "basic-excuse-production",   category = "bureaucratic-bootstrap", enabled = false, ingredients = {{type="item", name="dubious-data", amount=5}},                                                      results = {{type="item", name="basic-excuse", amount=1}},      energy_required = 5 },
  { type = "recipe", name = "crappy-report-production",  category = "bureaucracy-registration", enabled = false, ingredients = {{type="item", name="dubious-data", amount=10}, {type="item", name="paper", amount=2}},                            results = {{type="item", name="crappy-report", amount=1}},     energy_required = 5 },
  {
    type = "recipe", name = "politician-fluid-refining", category = "propaganda-distillery", enabled = false,
    icon = "__administratorio__/graphics/icons/lie.png", icon_size = 64,
    subgroup = "admin-bs-economy", order = "d1",
    ingredients = {{type="fluid", name="politician-fluid", amount=100}},
    results = {{type="fluid", name="lie", amount=50}},
    energy_required = 5,
    crafting_machine_tint = distillery_recipe_tint("politician-fluid", "lie")
  },
  { type = "recipe", name = "credentials-production", category = "bureaucracy-registration", enabled = false, ingredients = {{type="fluid", name="lie", amount=50}, {type="item", name="dubious-data", amount=5}, {type="item", name="refined-nonsense", amount=1}, {type="item", name="electronic-circuit", amount=2}}, results = {{type="item", name="credentials", amount=1}}, energy_required = 10 },
  { type = "recipe", name = "data-production",           category = "bureaucracy-registration", enabled = false, ingredients = {{type="item", name="crappy-report", amount=1}, {type="item", name="credentials", amount=1}, {type="item", name="advanced-circuit", amount=2}, {type="fluid", name="liquid-coffee", amount=25}},     results = {{type="item", name="data", amount=1}},             energy_required = 10 },
  { type = "recipe", name = "good-excuse-production",    category = "watercooler-gossip",       enabled = false,
    ingredients = {{type="item", name="data", amount=1}, {type="fluid", name="lie", amount=50}, {type="item", name="watercooler-gossip", amount=1}},
    results = {{type="item", name="good-excuse", amount=1}, {type="item", name="office-drama", amount=1, probability=0.5}},
    main_product = "good-excuse",
    energy_required = 10 },
  { type = "recipe", name = "misinformation-production", category = "propaganda-distillery",       enabled = false, subgroup = "admin-bs-economy", order = "f1", ingredients = {{type="fluid", name="lie", amount=50},         {type="item", name="dubious-data", amount=1}},                                              results = {{type="fluid", name="misinformation", amount=50}}, energy_required = 5, crafting_machine_tint = distillery_recipe_tint("lie", "misinformation") },
  { type = "recipe", name = "justification-production",  category = "propaganda-distillery",       enabled = false, ingredients = {{type="fluid", name="misinformation", amount=50}, {type="item", name="credentials", amount=1}, {type="fluid", name="politician-fluid", amount=50}}, results = {{type="item", name="justification", amount=1}},    energy_required = 15, crafting_machine_tint = distillery_recipe_tint("misinformation", "politician-fluid") },
  { type = "recipe", name = "narrative-production",      category = "union-negotiation", enabled = false,
    ingredients = {{type="item", name="justification", amount=1}, {type="item", name="good-excuse", amount=1}, {type="item", name="refined-nonsense", amount=1}, {type="item", name="watercooler-gossip", amount=2}},
    results = {{type="item", name="narrative", amount=1}, {type="item", name="office-drama", amount=1, probability=0.3}},
    main_product = "narrative",
    energy_required = 20 },
  { type = "recipe", name = "white-paper-production",    category = "bureaucracy-policy",       enabled = false, ingredients = {{type="item", name="data", amount=1}, {type="item", name="paper", amount=10}, {type="item", name="processing-unit", amount=1}, {type="fluid", name="lie", amount=50}, {type="fluid", name="slush-fund", amount=25}, {type="fluid", name="liquid-coffee", amount=25}}, results = {{type="item", name="white-paper", amount=1}},      energy_required = 30 },
  { type = "recipe", name = "policy-production",         category = "bureaucracy-policy", enabled = false, ingredients = {{type="item", name="white-paper", amount=1}, {type="fluid", name="misinformation", amount=100}, {type="item", name="data", amount=1}, {type="item", name="government-grant", amount=1}, {type="item", name="processing-unit", amount=2}, {type="fluid", name="slush-fund", amount=50}, {type="fluid", name="liquid-coffee", amount=50}}, results = {{type="item", name="policy", amount=1}},     energy_required = 45 },
  { type = "recipe", name = "regulation-production",     category = "bureaucracy-policy", enabled = false, ingredients = {{type="item", name="data", amount=2}, {type="item", name="credentials", amount=1}, {type="item", name="government-grant", amount=3}, {type="item", name="processing-unit", amount=3}, {type="fluid", name="slush-fund", amount=100}, {type="fluid", name="liquid-coffee", amount=50}}, results = {{type="item", name="regulation", amount=1}}, energy_required = 60 },

  -- Promise & Eviction
  { type = "recipe", name = "promise-production",         category = "bureaucratic-bootstrap", enabled = false, ingredients = {{type="item", name="blank-form", amount=3}, {type="item", name="dubious-data", amount=5}, {type="item", name="provisional-approval", amount=2}, {type="item", name="paper", amount=5}}, results = {{type="item", name="promise", amount=1}},         energy_required = 15 },
  { type = "recipe", name = "eviction-notice-production", category = "bureaucracy-registration", enabled = false, ingredients = {{type="item", name="good-excuse", amount=1}, {type="item", name="credentials", amount=1}, {type="fluid", name="politician-fluid", amount=50}, {type="item", name="taxpayer-money", amount=100}}, results = {{type="item", name="eviction-notice", amount=1}}, energy_required = 30 },

  -- Gossip & Corporate
  entity_recipe("corporate-breakroom", { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=20}, {type="item", name="wood", amount=10}, {type="item", name="stone-brick", amount=10}, {type="item", name="pipe", amount=4}, {type="item", name="electronic-circuit", amount=5}, {type="item", name="construction-permit", amount=1}}, results = {{type="item", name="corporate-breakroom", amount=1}}, energy_required = 10 }),
  entity_recipe("meeting-room",        { type = "recipe", enabled = false, ingredients = {{type="item", name="office-desk", amount=4}, {type="item", name="iron-plate", amount=20}, {type="item", name="steel-plate", amount=15}, {type="item", name="advanced-circuit", amount=5}, {type="item", name="management-approval-verbal", amount=5}, {type="item", name="government-grant", amount=3}, {type="item", name="taxpayer-money", amount=5}}, results = {{type="item", name="meeting-room", amount=1}}, energy_required = 30 }),
  { type = "recipe", name = "watercooler-gossip-production",  category = "watercooler-gossip", enabled = false, ingredients = {{type="fluid", name="liquid-coffee", amount=50}, {type="item", name="dubious-data", amount=2}}, results = {{type="item", name="watercooler-gossip", amount=1}}, energy_required = 5 },
  {
    type = "recipe", name = "office-drama-recycling", category = "watercooler-gossip", enabled = false,
    icon = "__administratorio__/graphics/icons/watercooler-gossip.png", icon_size = 64,
    subgroup = "admin-bs-economy", order = "z2",
    ingredients = {{type="item", name="office-drama", amount=3}, {type="fluid", name="liquid-coffee", amount=25}},
    results = {
      {type="item", name="work-order", amount=1, probability=0.5},
      {type="item", name="watercooler-gossip", amount=1, probability=0.5},
      {type="item", name="basic-excuse", amount=1, probability=0.5},
    },
    energy_required = 6
  },

  -- OSHA Scrubbing
  { type = "recipe", name = "osha-scrubbing", category = "union-negotiation", enabled = false, ingredients = {{type="item", name="osha-violation", amount=1}, {type="item", name="refined-nonsense", amount=2}, {type="fluid", name="union-approval", amount=50}}, results = {{type="item", name="justification", amount=1}}, energy_required = 10 },
  {
    type = "recipe", name = "osha-violation-recycling", category = "union-negotiation", enabled = false,
    icon = "__administratorio__/graphics/icons/osha-violation.png", icon_size = 64,
    subgroup = "admin-bs-economy", order = "m1",
    ingredients = {{type="item", name="osha-violation", amount=5}},
    results = {
      {type="item", name="blank-form", amount=1, probability=0.6},
      {type="item", name="blank-approval", amount=1, probability=0.3},
      {type="item", name="basic-excuse", amount=1, probability=0.5},
      {type="item", name="dubious-data", amount=2, probability=0.7},
      {type="item", name="work-order", amount=1, probability=0.4},
      {type="item", name="provisional-approval", amount=1, probability=0.2},
    },
    energy_required = 8
  },

  -- Refined Nonsense (T3 derivative — compacted rubble + misinformation)
  {
    type = "recipe", name = "refined-nonsense-production", category = "watercooler-gossip", enabled = false,
    ingredients = {{type="item", name="compacted-rubble", amount=3}, {type="fluid", name="misinformation", amount=100}},
    results = {{type="item", name="refined-nonsense", amount=1}},
    energy_required = 10
  },

  -- Union Negotiation
  {
    type = "recipe", name = "union-approval-production", category = "union-negotiation", enabled = false,
    subgroup = "admin-bs-economy", order = "l",
    ingredients = {
      {type="fluid", name="liquid-coffee", amount=100},
      {type="item", name="paper", amount=5},
      {type="item", name="dubious-data", amount=5},
      {type="item", name="taxpayer-money", amount=10}
    },
    results = {{type="fluid", name="union-approval", amount=200}},
    energy_required = 10
  },
})
