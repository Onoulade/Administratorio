local planets = require("prototypes.shared.space_age_planets")

local function on_planet(planet_name, recipe)
  return planets.apply_planet_surface_conditions(recipe, planet_name)
end

data:extend({
  -- Gleba can make the construction permit used by the canonical breakroom
  -- recipe from its biological paperwork supply, instead of owning a second
  -- breakroom construction recipe.
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

  -- Fulgora turns salvage into the ordinary administrative inputs needed to
  -- run a factory. Random archives seed the form portfolio while redundant
  -- rubble provides deterministic low-grade data throughput.
  on_planet("fulgora", {
    type = "recipe",
    name = "liquid-black-ink-fulgora",
    category = "bureaucracy-registration",
    enabled = false,
    localised_name = {"recipe-name.liquid-black-ink-fulgora"},
    ingredients = {
      {type = "item", name = "charged-toner", amount = 2},
      {type = "fluid", name = "electrolyte", amount = 20},
    },
    results = {{type = "fluid", name = "liquid-black-ink", amount = 80}},
    energy_required = 3,
  }),
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

  -- Gleba overproduces low-grade administrative matter. Its challenge is
  -- keeping biological paperwork moving, not importing Nauvis rubble or lies.
  on_planet("gleba", {
    type = "recipe",
    name = "dubious-data-cultivation-gleba",
    category = "bureaucratic-bootstrap",
    enabled = false,
    ingredients = {
      {type = "item", name = "bullshit-ore", amount = 4},
      {type = "fluid", name = "amber-sap", amount = 10},
    },
    results = {{type = "item", name = "dubious-data", amount = 12}},
    energy_required = 2,
  }),
  on_planet("gleba", {
    type = "recipe",
    name = "credentials-cultivation-gleba",
    category = "bureaucracy-registration",
    enabled = false,
    ingredients = {
      {type = "item", name = "dubious-data", amount = 4},
      {type = "item", name = "refined-nonsense", amount = 2},
      {type = "item", name = "electronic-circuit", amount = 2},
    },
    results = {{type = "item", name = "credentials", amount = 1}},
    energy_required = 5,
  }),
  on_planet("gleba", {
    type = "recipe",
    name = "justification-cultivation-gleba",
    category = "organic",
    enabled = false,
    ingredients = {
      {type = "item", name = "refined-nonsense", amount = 3},
      {type = "item", name = "good-excuse", amount = 1},
      {type = "item", name = "dubious-data", amount = 2},
      {type = "fluid", name = "amber-sap", amount = 20},
    },
    results = {{type = "item", name = "justification", amount = 1}},
    energy_required = 6,
  }),
  on_planet("gleba", {
    type = "recipe",
    name = "basic-excuse-cultivation-gleba",
    category = "bureaucratic-bootstrap",
    enabled = false,
    ingredients = {
      {type = "item", name = "dubious-data", amount = 4},
      {type = "item", name = "spoilage", amount = 1},
    },
    results = {{type = "item", name = "basic-excuse", amount = 2}},
    energy_required = 2,
  }),
  on_planet("gleba", {
    type = "recipe",
    name = "good-excuse-cultivation-gleba",
    category = "watercooler-gossip",
    enabled = false,
    ingredients = {
      {type = "item", name = "dubious-data", amount = 4},
      {type = "item", name = "spoilage", amount = 2},
      {type = "item", name = "watercooler-gossip", amount = 1},
    },
    results = {{type = "item", name = "good-excuse", amount = 2}},
    energy_required = 4,
  }),
  on_planet("gleba", {
    type = "recipe",
    name = "refined-nonsense-cultivation-gleba",
    category = "organic",
    enabled = false,
    ingredients = {
      {type = "item", name = "bullshit-ore", amount = 12},
      {type = "item", name = "spoilage", amount = 5},
      {type = "fluid", name = "amber-sap", amount = 20},
    },
    results = {{type = "item", name = "refined-nonsense", amount = 3}},
    energy_required = 4,
    allow_productivity = true,
  }),
  on_planet("gleba", {
    type = "recipe",
    name = "useless-documentation-cultivation-gleba",
    category = "bureaucracy-registration",
    enabled = false,
    ingredients = {
      {type = "item", name = "bullshit-ore", amount = 6},
      {type = "item", name = "paper", amount = 2},
      {type = "item", name = "spoilage", amount = 2},
    },
    results = {{type = "item", name = "useless-documentation", amount = 4}},
    energy_required = 3,
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
    results = {{type = "item", name = "provisional-approval", amount = 2}},
    energy_required = 2,
  }),
})

local seeding = data.raw.recipe and data.raw.recipe["amber-sap-nonsense-seeding"]
if seeding and seeding.results and seeding.results[1] then
  seeding.results[1].amount = 8
end
