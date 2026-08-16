local icon_tints = require("prototypes.shared.icon_tints")
local feature_flags = require("feature_flags")

local recipes = {
  -- The overtime exemption remains a separate permanent night-work module.
  -- Union HQ already carries the union-negotiation category it requires.
  {
    type = "recipe",
    name = "overtime-exemption",
    category = "union-negotiation",
    enabled = false,
    energy_required = 30,
    crafting_machine_tint = icon_tints.recipe_tint("overtime-exemption"),
    ingredients = {
      {type = "item", name = "processing-unit", amount = 10},
      {type = "item", name = "advanced-circuit", amount = 20},
      {type = "item", name = "treasury-bond", amount = 4},
      {type = "item", name = "management-approval-written", amount = 1},
      {type = "fluid", name = "liquid-coffee", amount = 100},
    },
    results = {
      {type = "item", name = "overtime-exemption", amount = 1},
    },
  },
}

if feature_flags.space_age_enabled() then
  table.insert(recipes, 1, {
    type = "recipe",
    name = "unstaffed-operations-waiver",
    category = "union-negotiation",
    enabled = false,
    energy_required = 120,
    crafting_machine_tint = icon_tints.recipe_tint("unstaffed-operations-waiver"),
    ingredients = {
      {type = "item", name = "quantum-processor", amount = 20},
      {type = "item", name = "tungsten-plate", amount = 40},
      {type = "item", name = "bioflux", amount = 40},
      {type = "item", name = "holmium-plate", amount = 40},
      {type = "item", name = "trichromatic-permit", amount = 4},
      {type = "fluid", name = "union-approval", amount = 400},
    },
    results = {
      {type = "item", name = "unstaffed-operations-waiver", amount = 1},
    },
  })
end

data:extend(recipes)
