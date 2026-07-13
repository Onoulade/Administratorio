local planets = require("prototypes.shared.space_age_planets")

local function on_fulgora(recipe)
  return planets.apply_planet_surface_conditions(recipe, "fulgora")
end

data:extend({
  on_fulgora({
    type = "recipe",
    name = "old-archive-recycling",
    category = "recycling",
    icons = {
      {icon = "__administratorio__/graphics/icons/useless-documentation.png", icon_size = 64, tint = {r = 0.72, g = 0.62, b = 0.82, a = 1}},
      {icon = "__administratorio__/graphics/icons/redundant-rubble.png", icon_size = 64, scale = 0.34, shift = {8, 8}},
    },
    enabled = false,
    ingredients = {
      {type = "item", name = "old-archive", amount = 1},
    },
    results = {
      {type = "item", name = "blank-form", amount = 1, probability = 0.125},
      {type = "item", name = "blank-approval", amount = 1, probability = 0.125},
      {type = "item", name = "carbon-offset-certificate-basic", amount = 1, probability = 0.125},
      {type = "item", name = "provisional-approval", amount = 1, probability = 0.125},
      {type = "item", name = "work-order", amount = 1, probability = 0.125},
      {type = "item", name = "safety-waiver-draft", amount = 1, probability = 0.125},
      {type = "item", name = "construction-permit-draft", amount = 1, probability = 0.125},
      {type = "item", name = "research-grant-approval", amount = 1, probability = 0.125},
    },
    energy_required = 0.5,
    allow_productivity = false,
    allow_decomposition = false,
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

-- Paperwork recycling is intentionally lossy and uniform. Defining the
-- canonical <item>-recycling recipe prevents automatic recipe inversion from
-- returning valuable ingredients or creating planet-specific shortcuts.
local form_recycling_recipes = {}
local paperwork_subgroups = {
  ["forms-base"] = true,
  ["forms-permits"] = true,
  ["forms-work-orders"] = true,
  ["forms-printed"] = true,
}
local paperwork_names = {}
for item_name, item in pairs(data.raw.item or {}) do
  if paperwork_subgroups[item.subgroup] then paperwork_names[#paperwork_names + 1] = item_name end
end
table.sort(paperwork_names)

for _, item_name in ipairs(paperwork_names) do
  form_recycling_recipes[#form_recycling_recipes + 1] = {
    type = "recipe",
    name = item_name .. "-recycling",
    category = "recycling",
    enabled = true,
    hidden = true,
    hidden_in_factoriopedia = true,
    hide_from_player_crafting = true,
    auto_recycle = false,
    allow_as_intermediate = false,
    allow_decomposition = false,
    allow_productivity = false,
    ingredients = {
      {type = "item", name = item_name, amount = 1},
    },
    results = {
      {type = "item", name = "paper", amount = 1, probability = 0.25},
    },
    energy_required = 0.5,
  }
end

data:extend(form_recycling_recipes)
