local icon_tints = require("prototypes.shared.icon_tints")

data:extend({
  {
    type = "recipe",
    name = "unstaffed-operations-waiver",
    category = "union-negotiation",
    enabled = false,
    energy_required = 45,
    crafting_machine_tint = icon_tints.recipe_tint("overtime-exemption"),
    ingredients = {
      {type = "item", name = "processing-unit", amount = 15},
      {type = "item", name = "tungsten-plate", amount = 10},
      {type = "item", name = "bioflux", amount = 10},
      {type = "item", name = "holmium-plate", amount = 10},
      {type = "item", name = "trichromatic-permit", amount = 1},
      {type = "fluid", name = "union-approval", amount = 100},
    },
    results = {
      {type = "item", name = "unstaffed-operations-waiver", amount = 1},
    },
  },
  -- Reactivation is cheaper than a fresh craft, so renewing an expired waiver
  -- is the correct play. No new crafting category is needed: Union HQ already
  -- carries union-negotiation.
  {
    type = "recipe",
    name = "unstaffed-operations-waiver-reactivation",
    category = "union-negotiation",
    enabled = false,
    energy_required = 20,
    crafting_machine_tint = icon_tints.recipe_tint("overtime-exemption"),
    ingredients = {
      {type = "item", name = "expired-waiver", amount = 1},
      {type = "item", name = "processing-unit", amount = 2},
      {type = "fluid", name = "union-approval", amount = 50},
    },
    results = {
      {type = "item", name = "unstaffed-operations-waiver", amount = 1},
    },
  },
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
})
