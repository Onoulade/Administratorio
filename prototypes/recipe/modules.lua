data:extend({
  {
    type = "recipe",
    name = "overtime-exemption",
    category = "union-negotiation",
    enabled = false,
    energy_required = 30,
    ingredients = {
      {type = "item", name = "productivity-module", amount = 1},
      {type = "item", name = "processing-unit", amount = 10},
      {type = "item", name = "advanced-circuit", amount = 20},
      {type = "item", name = "government-grant", amount = 4},
      {type = "item", name = "regulation", amount = 4},
      {type = "item", name = "taxpayer-money", amount = 50},
      {type = "fluid", name = "liquid-coffee", amount = 100},
    },
    results = {
      {type = "item", name = "overtime-exemption", amount = 1},
    },
  },
})
