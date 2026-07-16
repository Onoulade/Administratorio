local planets = require("prototypes.shared.space_age_planets")

local function on_planet(planet_name, recipe)
  return planets.apply_planet_surface_conditions(recipe, planet_name)
end

data:extend({
  -- Gleba gets one local building permit so its native capture loop can start
  -- without cloning the building recipes themselves.
  on_planet("gleba", {
    type = "recipe",
    name = "construction-permit-gleba",
    category = "bureaucracy-registration",
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
  on_planet("fulgora", {
    type = "recipe",
    name = "ink-recovery-fulgora",
    category = "bureaucratic-bootstrap",
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
    category = "bureaucratic-bootstrap",
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
    category = "bureaucracy-registration",
    enabled = false,
    localised_name = {"recipe-name.carbon-offset-certificate-basic-fulgora"},
    ingredients = {
      {type = "item", name = "blank-form", amount = 1},
      {type = "item", name = "solid-fuel", amount = 2},
      {type = "item", name = "redundant-rubble", amount = 2},
    },
    results = {{type = "item", name = "carbon-offset-certificate-basic", amount = 2}},
    energy_required = 3,
  }),
  on_planet("fulgora", {
    type = "recipe",
    name = "salvage-electrolyte-fulgora",
    category = "electromagnetics",
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
  -- Digital paperwork replaces only the final executive approval and grant
  -- needed by the unchanged launch chain. It is intentionally not a second
  -- generic policy, finance, or copy economy.
  on_planet("fulgora", {
    type = "recipe",
    name = "management-approval-written-fulgora",
    category = "bureaucracy-registration",
    enabled = false,
    localised_name = {"item-name.management-approval-written"},
    ingredients = {
      {type = "item", name = "blank-magenta-form", amount = 2},
      {type = "item", name = "digital-processing-certificate", amount = 1},
      {type = "item", name = "old-archive", amount = 2},
      {type = "item", name = "charged-toner", amount = 4},
    },
    results = {{type = "item", name = "management-approval-written", amount = 1}},
    energy_required = 24,
  }),
  on_planet("fulgora", {
    type = "recipe",
    name = "government-grant-fulgora",
    category = "bureaucracy-registration",
    enabled = false,
    localised_name = {"item-name.government-grant"},
    ingredients = {
      {type = "item", name = "management-approval-written", amount = 1},
      {type = "item", name = "data-recovery-order", amount = 1},
      {type = "item", name = "old-archive", amount = 4},
      {type = "item", name = "charged-toner", amount = 6},
    },
    results = {{type = "item", name = "government-grant", amount = 1}},
    energy_required = 36,
  }),
  -- Gleba can grow the few administrative inputs that gate its own escape and
  -- conciliation content. Higher generic paperwork remains an import or fax
  -- concern, preserving the planet's biological-specialist identity.
  on_planet("gleba", {
    type = "recipe",
    name = "dubious-data-cultivation-gleba",
    category = "bureaucratic-bootstrap",
    enabled = false,
    ingredients = {
      {type = "item", name = "bullshit-ore", amount = 4},
      {type = "fluid", name = "amber-sap", amount = 10},
    },
    results = {{type = "item", name = "dubious-data", amount = 8}},
    energy_required = 8,
  }),
  on_planet("gleba", {
    type = "recipe",
    name = "provisional-approval-cultivation-gleba",
    category = "bureaucratic-bootstrap",
    enabled = false,
    ingredients = {
      {type = "item", name = "blank-form", amount = 1},
      {type = "item", name = "bullshit-ore", amount = 2},
    },
    results = {{type = "item", name = "provisional-approval", amount = 1}},
    energy_required = 4,
  }),
  -- The biological branch does not recreate the generic excuse, credential,
  -- or policy ladders. These are the two terminal documents that the
  -- unchanged launch recipes actually consume.
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
  on_planet("gleba", {
    type = "recipe",
    name = "government-grant-gleba",
    category = "bureaucracy-conciliation",
    enabled = false,
    localised_name = {"item-name.government-grant"},
    ingredients = {
      {type = "item", name = "management-approval-written", amount = 1},
      {type = "item", name = "conciliation-order", amount = 1},
      {type = "item", name = "symbiosis-record", amount = 2},
      {type = "fluid", name = "amber-sap", amount = 100},
    },
    results = {{type = "item", name = "government-grant", amount = 1}},
    energy_required = 36,
  }),
  -- Biological waste is the one slow filler route Gleba needs to feed the
  -- canonical low-density and environmental paperwork chain. It remains a
  -- Conciliation Desk sink rather than a broad replacement paperwork tree.
  on_planet("gleba", {
    type = "recipe",
    name = "composted-rubble-recovery-gleba",
    category = "bureaucracy-conciliation",
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

local seeding = data.raw.recipe and data.raw.recipe["amber-sap-nonsense-seeding"]
if seeding and seeding.results and seeding.results[1] then
  seeding.results[1].amount = 8
end
