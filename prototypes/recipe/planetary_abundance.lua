local planets = require("prototypes.shared.space_age_planets")
local bureaucracy_categories = require("prototypes.shared.bureaucracy_categories")

local function on_planet(planet_name, recipe)
  return planets.apply_planet_surface_conditions(recipe, planet_name)
end

data:extend({
  -- Gleba gets one local building permit so its native capture loop can start
  -- without cloning the building recipes themselves.
  on_planet("gleba", {
    type = "recipe",
    name = "construction-permit-gleba",
    category = bureaucracy_categories.registration_for_planet("gleba"),
    enabled = false,
    localised_name = {"item-name.construction-permit"},
    ingredients = {
      {type = "item", name = "blank-form", amount = 1},
      {type = "item", name = "carbon-offset-certificate-basic", amount = 1},
      {type = "item", name = "dubious-data", amount = 2},
    },
    results = {{type = "item", name = "construction-permit", amount = 1}},
    energy_required = 4,
  }),

  -- Fulgora turns salvage into the small set of generic inputs required for
  -- a local escape. It does not recreate the wider petroleum economy.
  -- This certificate is a deliberately expensive material bridge for the
  -- emission-gated production chain, not a second general paperwork ladder.
  on_planet("fulgora", {
    type = "recipe",
    name = "ink-recovery-fulgora",
    category = bureaucracy_categories.bootstrap_for_planet("fulgora"),
    subgroup = "admin-planet-fulgora", order = "lb-l",
    enabled = false,
    ingredients = {
      {type = "item", name = "charged-toner", amount = 1},
      {type = "item", name = "redundant-rubble", amount = 1},
    },
    results = {{type = "item", name = "ink", amount = 4}},
    energy_required = 2,
  }),
  on_planet("fulgora", {
    type = "recipe",
    name = "salvaged-data-analysis-fulgora",
    category = bureaucracy_categories.bootstrap_for_planet("fulgora"),
    subgroup = "admin-planet-fulgora", order = "lb-m",
    enabled = false,
    ingredients = {
      {type = "item", name = "redundant-rubble", amount = 6},
      {type = "item", name = "charged-toner", amount = 1},
    },
    results = {{type = "item", name = "dubious-data", amount = 4}},
    energy_required = 4,
    allow_productivity = true,
  }),
  on_planet("fulgora", {
    type = "recipe",
    name = "carbon-offset-certificate-basic-fulgora",
    category = bureaucracy_categories.registration_for_planet("fulgora"),
    enabled = false,
    localised_name = {"recipe-name.carbon-offset-certificate-basic-fulgora"},
    ingredients = {
      {type = "item", name = "blank-form", amount = 1},
      {type = "item", name = "solid-fuel", amount = 4},
      {type = "item", name = "redundant-rubble", amount = 4},
    },
    results = {{type = "item", name = "carbon-offset-certificate-basic", amount = 1}},
    energy_required = 8,
  }),
  on_planet("fulgora", {
    type = "recipe",
    name = "salvage-electrolyte-fulgora",
    category = "electromagnetics",
    subgroup = "admin-planet-fulgora", order = "lb-o",
    enabled = false,
    ingredients = {
      {type = "fluid", name = "holmium-solution", amount = 20},
      {type = "fluid", name = "water", amount = 20},
      {type = "item", name = "charged-toner", amount = 2},
      {type = "item", name = "redundant-rubble", amount = 4},
    },
    results = {{type = "fluid", name = "electrolyte", amount = 20}},
    energy_required = 5,
    allow_productivity = true,
  }),
  on_planet("fulgora", {
    type = "recipe",
    name = "electromagnetic-rocket-fuel-fulgora",
    category = "electromagnetics",
    subgroup = "admin-planet-fulgora", order = "lb-p",
    enabled = false,
    ingredients = {
      {type = "item", name = "solid-fuel", amount = 10},
      {type = "fluid", name = "electrolyte", amount = 20},
      {type = "item", name = "charged-toner", amount = 1},
    },
    results = {{type = "item", name = "rocket-fuel", amount = 1}},
    energy_required = 8,
    allow_productivity = true,
  }),
  -- This is the deliberately expensive petroleum exception required for
  -- electric engines and therefore the unchanged rocket-silo recipe. It does
  -- not open an oil chain: crude oil and every other refinery output remain
  -- unavailable on Fulgora.
  on_planet("fulgora", {
    type = "recipe",
    name = "electromagnetic-lubricant-fulgora",
    category = "electromagnetics",
    subgroup = "admin-planet-fulgora", order = "lb-q",
    enabled = false,
    ingredients = {
      {type = "fluid", name = "electrolyte", amount = 30},
      {type = "item", name = "solid-fuel", amount = 2},
      {type = "item", name = "charged-toner", amount = 1},
    },
    results = {{type = "fluid", name = "lubricant", amount = 40}},
    energy_required = 4,
    allow_productivity = true,
  }),
  -- Gleba can grow the few administrative inputs that gate its own escape and
  -- conciliation content. Bullshit ore already feeds the canonical smelting
  -- route to dubious data, so the planet does not duplicate that conversion.
  on_planet("gleba", {
    type = "recipe",
    name = "provisional-approval-cultivation-gleba",
    category = bureaucracy_categories.bootstrap_for_planet("gleba"),
    enabled = false,
    ingredients = {
      {type = "item", name = "blank-form", amount = 1},
      {type = "item", name = "bullshit-ore", amount = 2},
    },
    results = {{type = "item", name = "provisional-approval", amount = 1}},
    energy_required = 4,
  }),
  -- Rocket-part production consumes written approvals in bulk. This is the
  -- one finished-document exception that remains local: it turns perishable
  -- biological records into approval rather than requiring an impractical
  -- interplanetary shipment of twenty executive documents per escape.
  on_planet("gleba", {
    type = "recipe",
    name = "management-approval-written-gleba",
    category = "bureaucracy-conciliation",
    enabled = false,
    localised_name = {"item-name.management-approval-written"},
    ingredients = {
      {type = "item", name = "blank-yellow-form", amount = 2},
      {type = "item", name = "symbiosis-record", amount = 2},
      {type = "item", name = "dubious-data", amount = 10},
      {type = "fluid", name = "amber-sap", amount = 50},
    },
    results = {{type = "item", name = "management-approval-written", amount = 1}},
    energy_required = 24,
  }),
  -- Biological waste is the one slow filler route Gleba needs to feed the
  -- canonical low-density and environmental paperwork chain. It remains a
  -- Conciliation Desk sink rather than a broad replacement paperwork tree.
  on_planet("gleba", {
    type = "recipe",
    name = "composted-rubble-recovery-gleba",
    category = "bureaucracy-conciliation",
    subgroup = "admin-planet-gleba", order = "la-p",
    enabled = false,
    localised_name = {"item-name.redundant-rubble"},
    ingredients = {
      {type = "item", name = "spoilage", amount = 10},
      {type = "item", name = "symbiosis-record", amount = 1},
      {type = "fluid", name = "amber-sap", amount = 30},
    },
    results = {{type = "item", name = "redundant-rubble", amount = 4}},
    energy_required = 12,
  }),
})
