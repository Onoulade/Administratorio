local planets = require("prototypes.shared.space_age_planets")
local rules = require("scripts.archive_recombination_rules")

local function on_fulgora(recipe)
  return planets.apply_planet_surface_conditions(recipe, "fulgora")
end

data:extend({
  on_fulgora({
    type = "recipe",
    name = "old-archive-recycling",
    category = "recycling",
    enabled = false,
    ingredients = {
      {type = "item", name = "old-archive", amount = 1},
    },
    results = {
      {type = "item", name = "redundant-rubble", amount = 2},
      {type = "item", name = "blank-form", amount = 1, probability = 0.10},
      {type = "item", name = "blank-approval", amount = 1, probability = 0.10},
      {type = "item", name = "carbon-offset-certificate-basic", amount = 1, probability = 0.10},
      {type = "item", name = "provisional-approval", amount = 1, probability = 0.10},
      {type = "item", name = "work-order", amount = 1, probability = 0.09},
      {type = "item", name = "safety-waiver-draft", amount = 1, probability = 0.08},
      {type = "item", name = "construction-permit-draft", amount = 1, probability = 0.08},
      {type = "item", name = "research-grant-approval", amount = 1, probability = 0.07},
    },
    main_product = "redundant-rubble",
    energy_required = 2,
    allow_productivity = false,
    allow_decomposition = false,
  }),
  on_fulgora({
    type = "recipe",
    name = "archival-substrate-production",
    category = "bureaucracy-registration",
    enabled = false,
    ingredients = {
      {type = "item", name = "redundant-rubble", amount = 8},
      {type = "item", name = "charged-toner", amount = 1},
      {type = "item", name = "useless-documentation", amount = 1},
    },
    results = {
      {type = "item", name = "archival-substrate", amount = 2},
    },
    energy_required = 4,
    allow_productivity = true,
  }),
  on_fulgora({
    type = "recipe",
    name = "archive-residue-reprocessing",
    category = "bureaucracy-registration",
    enabled = false,
    ingredients = {
      {type = "item", name = "archive-residue", amount = 4},
      {type = "item", name = "redundant-rubble", amount = 2},
    },
    results = {
      {type = "item", name = "archival-substrate", amount = 1},
    },
    energy_required = 3,
    allow_productivity = false,
  }),
  on_fulgora({
    type = "recipe",
    name = "archive-recombination-bureau",
    enabled = false,
    ingredients = {
      {type = "item", name = "recycler", amount = 1},
      {type = "item", name = "relay-clerk", amount = 1},
      {type = "item", name = "processing-unit", amount = 15},
      {type = "item", name = "holmium-plate", amount = 20},
      {type = "item", name = "construction-work-order", amount = 1},
    },
    results = {
      {type = "item", name = "archive-recombination-bureau", amount = 1},
    },
    energy_required = 20,
  }),
})

local generated_pairs, invalid_pairs = rules.generate_all_pairs()
if #invalid_pairs > 0 then
  error("Archive recombination taxonomy contains pairs without enough legal outputs")
end

local pair_keys = {}
for key in pairs(generated_pairs) do pair_keys[#pair_keys + 1] = key end
table.sort(pair_keys)

local recipes = {}
for index, key in ipairs(pair_keys) do
  local pair = generated_pairs[key]
  local recipe = {
    type = "recipe",
    name = string.format("archive-recombination-%03d", index),
    category = "archive-recombination",
    enabled = true,
    hidden = true,
    hidden_in_factoriopedia = true,
    hide_from_player_crafting = true,
    allow_as_intermediate = false,
    allow_decomposition = false,
    allow_productivity = false,
    ingredients = {
      {type = "item", name = pair.left, amount = 1},
      {type = "item", name = pair.right, amount = 1},
      {type = "item", name = "archival-substrate", amount = 1},
    },
    results = {
      {type = "item", name = "archive-attempt-record", amount = 1},
      {type = "item", name = "recombination-envelope", amount = 1, probability = rules.SUCCESS_PERCENT / 100},
    },
    main_product = "archive-attempt-record",
    energy_required = 20,
  }
  recipes[#recipes + 1] = recipe
end

data:extend(recipes)
