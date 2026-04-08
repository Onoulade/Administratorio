local planets = require("prototypes.shared.space_age_planets")

local function add_item_ingredient(recipe, ingredient_name, amount)
  if not recipe then return end

  local function apply_to_variant(target)
    if not target or not target.ingredients then return end

    for _, ingredient in ipairs(target.ingredients) do
      if (ingredient.name or ingredient[1]) == ingredient_name then
        return
      end
    end

    table.insert(target.ingredients, {type = "item", name = ingredient_name, amount = amount})
  end

  apply_to_variant(recipe)
  apply_to_variant(recipe.normal)
  apply_to_variant(recipe.expensive)
end

local function surface_limited(recipe, planet_name)
  return planets.apply_planet_surface_conditions(recipe, planet_name)
end

data:extend({
  {
    type = "recipe",
    name = "job-offer-production",
    category = "bureaucracy-policy",
    enabled = false,
    ingredients = {
      {type = "item", name = "treasury-bond", amount = 2},
      {type = "item", name = "taxpayer-money", amount = 50},
      {type = "item", name = "credentials", amount = 1},
      {type = "item", name = "good-excuse", amount = 1},
      {type = "item", name = "narrative", amount = 1},
      {type = "item", name = "paper", amount = 10},
    },
    results = {{type = "item", name = "job-offer", amount = 1}},
    energy_required = 30
  },
  {
    type = "recipe",
    name = "formation-center",
    enabled = false,
    ingredients = {
      {type = "item", name = "office-desk", amount = 2},
      {type = "item", name = "printer-t2", amount = 1},
      {type = "item", name = "processing-unit", amount = 10},
      {type = "item", name = "management-approval-written", amount = 1},
      {type = "item", name = "refined-concrete", amount = 20},
    },
    results = {{type = "item", name = "formation-center", amount = 1}},
    energy_required = 30
  },
  {
    type = "recipe",
    name = "worker-biter-formation",
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {type = "item", name = "enrolled-biter", amount = 1},
      {type = "item", name = "credentials", amount = 1},
      {type = "item", name = "good-excuse", amount = 1},
      {type = "item", name = "taxpayer-money", amount = 5},
    },
    results = {{type = "item", name = "worker-biter", amount = 1}},
    energy_required = 10
  },
  {
    type = "recipe",
    name = "clerical-trainee-formation",
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {type = "item", name = "worker-biter", amount = 1},
      {type = "item", name = "credentials", amount = 1},
      {type = "item", name = "paper", amount = 5},
    },
    results = {{type = "item", name = "clerical-trainee", amount = 1}},
    energy_required = 15
  },
  {
    type = "recipe",
    name = "management-trainee-formation",
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {type = "item", name = "worker-biter", amount = 1},
      {type = "item", name = "narrative", amount = 1},
      {type = "item", name = "management-approval-verbal", amount = 1},
      {type = "item", name = "taxpayer-money", amount = 10},
    },
    results = {{type = "item", name = "management-trainee", amount = 1}},
    energy_required = 20
  },
  {
    type = "recipe",
    name = "night-shift-supervisor-formation",
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {type = "item", name = "clerical-trainee", amount = 1},
      {type = "item", name = "regulation", amount = 1},
      {type = "item", name = "productivity-module", amount = 1},
    },
    results = {{type = "item", name = "night-shift-supervisor", amount = 1}},
    energy_required = 20
  },
  {
    type = "recipe",
    name = "licensed-notary-formation",
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {type = "item", name = "clerical-trainee", amount = 1},
      {type = "item", name = "construction-permit", amount = 1},
      {type = "item", name = "management-approval-verbal", amount = 1},
    },
    results = {{type = "item", name = "licensed-notary", amount = 1}},
    energy_required = 20
  },
  {
    type = "recipe",
    name = "conciliation-officer-formation",
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {type = "item", name = "clerical-trainee", amount = 1},
      {type = "item", name = "good-excuse", amount = 1},
      {type = "item", name = "promise", amount = 1},
    },
    results = {{type = "item", name = "conciliation-officer", amount = 1}},
    energy_required = 20
  },
  {
    type = "recipe",
    name = "relay-clerk-formation",
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {type = "item", name = "clerical-trainee", amount = 1},
      {type = "item", name = "data", amount = 1},
      {type = "item", name = "processing-unit", amount = 1},
    },
    results = {{type = "item", name = "relay-clerk", amount = 1}},
    energy_required = 20
  },
  {
    type = "recipe",
    name = "cryoprint-technician-formation",
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {type = "item", name = "clerical-trainee", amount = 1},
      {type = "item", name = "processing-unit", amount = 2},
      {type = "item", name = "management-approval-written", amount = 1},
    },
    results = {{type = "item", name = "cryoprint-technician", amount = 1}},
    energy_required = 25
  },
  {
    type = "recipe",
    name = "field-negotiator-formation",
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {type = "item", name = "management-trainee", amount = 1},
      {type = "item", name = "eviction-notice", amount = 1},
      {type = "item", name = "management-approval-written", amount = 1},
    },
    results = {{type = "item", name = "field-negotiator", amount = 1}},
    energy_required = 25
  },
  {
    type = "recipe",
    name = "middle-management-managing-manager-formation",
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {type = "item", name = "management-trainee", amount = 1},
      {type = "item", name = "policy", amount = 1},
      {type = "item", name = "office-drama", amount = 2},
    },
    results = {{type = "item", name = "middle-management-managing-manager", amount = 1}},
    energy_required = 25
  },
  {
    type = "recipe",
    name = "chromatic-printer",
    enabled = false,
    ingredients = {
      {type = "item", name = "printer-t2", amount = 1},
      {type = "item", name = "steel-plate", amount = 20},
      {type = "item", name = "advanced-circuit", amount = 20},
      {type = "item", name = "processing-unit", amount = 8},
      {type = "item", name = "management-approval-verbal", amount = 1},
      {type = "item", name = "construction-work-order", amount = 1},
    },
    results = {{type = "item", name = "chromatic-printer", amount = 1}},
    energy_required = 12
  },
  {
    type = "recipe",
    name = "notary-office",
    enabled = false,
    ingredients = {
      {type = "item", name = "office-desk", amount = 2},
      {type = "item", name = "chromatic-printer", amount = 1},
      {type = "item", name = "licensed-notary", amount = 1},
      {type = "item", name = "steel-plate", amount = 20},
      {type = "item", name = "advanced-circuit", amount = 10},
      {type = "item", name = "construction-permit", amount = 1},
    },
    results = {{type = "item", name = "notary-office", amount = 1}},
    energy_required = 16
  },
  {
    type = "recipe",
    name = "trajectory-compliance-array",
    enabled = false,
    ingredients = {
      {type = "item", name = "radar", amount = 2},
      {type = "item", name = "processing-unit", amount = 10},
      {type = "item", name = "low-density-structure", amount = 10},
      {type = "item", name = "refined-concrete", amount = 20},
      {type = "item", name = "management-approval-written", amount = 1},
      {type = "item", name = "construction-work-order", amount = 1},
    },
    results = {{type = "item", name = "trajectory-compliance-array", amount = 1}},
    energy_required = 20
  },
  {
    type = "recipe",
    name = "overtime-exemption-staffed",
    category = "union-negotiation",
    enabled = false,
    localised_name = {"recipe-name.overtime-exemption"},
    ingredients = {
      {type = "item", name = "night-shift-supervisor", amount = 1},
      {type = "item", name = "productivity-module", amount = 1},
      {type = "item", name = "processing-unit", amount = 6},
      {type = "item", name = "government-grant", amount = 2},
      {type = "item", name = "regulation", amount = 2},
      {type = "item", name = "management-approval-written", amount = 1},
      {type = "fluid", name = "liquid-coffee", amount = 60},
    },
    results = {
      {type = "item", name = "overtime-exemption", amount = 1},
    },
    energy_required = 20,
  },
  {
    type = "recipe",
    name = "promise-production-negotiated",
    category = "union-negotiation",
    enabled = false,
    localised_name = {"recipe-name.promise-production"},
    ingredients = {
      {type = "item", name = "field-negotiator", amount = 1},
      {type = "item", name = "blank-form", amount = 4},
      {type = "item", name = "good-excuse", amount = 1},
      {type = "item", name = "management-approval-verbal", amount = 1},
      {type = "fluid", name = "liquid-coffee", amount = 50},
    },
    results = {
      {type = "item", name = "promise", amount = 3},
    },
    energy_required = 15,
  },
  {
    type = "recipe",
    name = "eviction-notice-production-negotiated",
    category = "bureaucracy-policy",
    enabled = false,
    localised_name = {"recipe-name.eviction-notice-production"},
    ingredients = {
      {type = "item", name = "field-negotiator", amount = 1},
      {type = "item", name = "good-excuse", amount = 1},
      {type = "item", name = "credentials", amount = 1},
      {type = "item", name = "management-approval-written", amount = 1},
      {type = "fluid", name = "politician-fluid", amount = 50},
      {type = "item", name = "taxpayer-money", amount = 60},
    },
    results = {
      {type = "item", name = "eviction-notice", amount = 2},
    },
    energy_required = 25,
  },
  {
    type = "recipe",
    name = "liquid-black-ink",
    category = "bureaucracy-registration",
    enabled = false,
    ingredients = {
      {type = "item", name = "ink", amount = 1},
    },
    results = {
      {type = "fluid", name = "liquid-black-ink", amount = 40},
    },
    energy_required = 2,
  },
  surface_limited({
    type = "recipe",
    name = "dubious-data-analysis-vulcanus",
    category = "bureaucracy-registration",
    enabled = false,
    ingredients = {
      {type = "item", name = "verdigris-crust", amount = 2},
      {type = "item", name = "paper", amount = 1},
    },
    results = {
      {type = "item", name = "dubious-data", amount = 4},
    },
    energy_required = 5,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "cyan-slurry-production",
    category = "propaganda-distillery",
    enabled = false,
    ingredients = {
      {type = "item", name = "verdigris-crust", amount = 4},
    },
    results = {
      {type = "fluid", name = "cyan-slurry", amount = 80},
    },
    energy_required = 4,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "cyan-ink-production",
    category = "propaganda-distillery",
    enabled = false,
    ingredients = {
      {type = "fluid", name = "cyan-slurry", amount = 40},
      {type = "fluid", name = "sulfuric-acid", amount = 20},
    },
    results = {
      {type = "fluid", name = "cyan-ink", amount = 40},
    },
    energy_required = 4,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "heatproof-form-stock",
    category = "printing-chromatic",
    enabled = false,
    ingredients = {
      {type = "item", name = "paper", amount = 4},
      {type = "fluid", name = "cyan-ink", amount = 20},
      {type = "fluid", name = "sulfuric-acid", amount = 10},
    },
    results = {
      {type = "item", name = "heatproof-form-stock", amount = 2},
    },
    energy_required = 4,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "permit-draft",
    category = "printing-chromatic",
    enabled = false,
    ingredients = {
      {type = "item", name = "heatproof-form-stock", amount = 1},
      {type = "fluid", name = "liquid-black-ink", amount = 10},
      {type = "fluid", name = "cyan-ink", amount = 10},
    },
    results = {
      {type = "item", name = "permit-draft", amount = 1},
    },
    energy_required = 3,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "inspection-docket",
    category = "printing-chromatic",
    enabled = false,
    ingredients = {
      {type = "item", name = "heatproof-form-stock", amount = 1},
      {type = "item", name = "dubious-data", amount = 1},
      {type = "fluid", name = "liquid-black-ink", amount = 10},
      {type = "fluid", name = "cyan-ink", amount = 10},
    },
    results = {
      {type = "item", name = "inspection-docket", amount = 1},
    },
    energy_required = 4,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "embossed-seal",
    category = "bureaucracy-certification",
    enabled = false,
    ingredients = {
      {type = "fluid", name = "cyan-slurry", amount = 20},
      {type = "item", name = "useless-documentation", amount = 1},
    },
    results = {
      {type = "item", name = "embossed-seal", amount = 1},
    },
    energy_required = 5,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "industrial-charter",
    category = "bureaucracy-certification",
    enabled = false,
    ingredients = {
      {type = "item", name = "permit-draft", amount = 1},
      {type = "item", name = "inspection-docket", amount = 1},
      {type = "item", name = "embossed-seal", amount = 1},
    },
    results = {
      {type = "item", name = "industrial-charter", amount = 1},
    },
    energy_required = 8,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "lava-safety-endorsement",
    category = "bureaucracy-certification",
    enabled = false,
    ingredients = {
      {type = "item", name = "inspection-docket", amount = 1},
      {type = "item", name = "basic-excuse", amount = 1},
      {type = "fluid", name = "cyan-ink", amount = 10},
    },
    results = {
      {type = "item", name = "lava-safety-endorsement", amount = 1},
    },
    energy_required = 6,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "foundry-operating-charter",
    category = "bureaucracy-certification",
    enabled = false,
    ingredients = {
      {type = "item", name = "industrial-charter", amount = 1},
      {type = "item", name = "lava-safety-endorsement", amount = 1},
      {type = "item", name = "embossed-seal", amount = 1},
    },
    results = {
      {type = "item", name = "foundry-operating-charter", amount = 1},
    },
    energy_required = 8,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "vulcanus-lie-fabrication",
    category = "propaganda-distillery",
    enabled = false,
    localised_name = {"fluid-name.lie"},
    ingredients = {
      {type = "item", name = "inspection-docket", amount = 1},
      {type = "item", name = "embossed-seal", amount = 1},
      {type = "fluid", name = "cyan-slurry", amount = 50},
    },
    results = {
      {type = "fluid", name = "lie", amount = 200},
    },
    energy_required = 6,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "research-grant-approval-vulcanus",
    category = "bureaucracy-certification",
    enabled = false,
    localised_name = {"item-name.research-grant-approval"},
    ingredients = {
      {type = "item", name = "permit-draft", amount = 1},
      {type = "item", name = "embossed-seal", amount = 1},
    },
    results = {
      {type = "item", name = "research-grant-approval", amount = 1},
    },
    energy_required = 4,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "management-verbal-approval-vulcanus",
    category = "bureaucracy-certification",
    enabled = false,
    localised_name = {"item-name.management-approval-verbal"},
    ingredients = {
      {type = "item", name = "inspection-docket", amount = 1},
      {type = "item", name = "basic-excuse", amount = 1},
      {type = "fluid", name = "lie", amount = 50},
    },
    results = {
      {type = "item", name = "management-approval-verbal", amount = 1},
    },
    energy_required = 5,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "management-written-approval-vulcanus",
    category = "bureaucracy-certification",
    enabled = false,
    localised_name = {"item-name.management-approval-written"},
    ingredients = {
      {type = "item", name = "industrial-charter", amount = 1},
      {type = "item", name = "management-approval-verbal", amount = 1},
      {type = "item", name = "embossed-seal", amount = 1},
    },
    results = {
      {type = "item", name = "management-approval-written", amount = 1},
    },
    energy_required = 6,
  }, "vulcanus"),
})

for _, recipe_name in ipairs({
  "foundry",
  "biochamber",
  "electromagnetic-plant",
  "cryogenic-plant",
}) do
  local specialist_by_recipe = {
    ["foundry"] = "licensed-notary",
    ["biochamber"] = "conciliation-officer",
    ["electromagnetic-plant"] = "relay-clerk",
    ["cryogenic-plant"] = "cryoprint-technician",
  }
  add_item_ingredient(data.raw.recipe and data.raw.recipe[recipe_name], specialist_by_recipe[recipe_name], 1)
end

add_item_ingredient(data.raw.recipe and data.raw.recipe["foundry"], "foundry-operating-charter", 1)
