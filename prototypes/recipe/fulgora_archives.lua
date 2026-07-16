local planets = require("prototypes.shared.space_age_planets")
local reassignment_rules = require("scripts.archive_recombination_rules")
local paperwork_recycling = require("prototypes.shared.paperwork_recycling")
local manager_briefings = require("prototypes.shared.manager_briefings")

local function on_fulgora(recipe)
  return planets.apply_planet_surface_conditions(recipe, "fulgora")
end

data:extend({
  on_fulgora({
    type = "recipe",
    name = "old-archive-recycling",
    category = "recycling",
    subgroup = "admin-recycling",
    order = "old-archive",
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
      {
        type = "item",
        name = manager_briefings.BY_KEY.staffing.item,
        amount = 1,
        ignored_by_stats = 1,
      },
      {type = "item", name = "processing-unit", amount = 15},
      {type = "item", name = "holmium-plate", amount = 20},
      {type = "item", name = "construction-work-order", amount = 1},
    },
    results = {
      {type = "item", name = "archive-recombination-bureau", amount = 1},
      {
        type = "item",
        name = manager_briefings.REGULAR_MANAGER,
        amount = 1,
        ignored_by_productivity = 1,
        ignored_by_stats = 1,
      },
    },
    main_product = "archive-recombination-bureau",
    energy_required = 20,
  }),
})

-- The archive machine is a true Furnace/Recycler variant. Each supported form
-- selects exactly one native recipe from its single input slot. Candidate
-- outputs roll independently, so an operation may return zero to three forms.
local reassignment_recipes = {}
local reassignments, invalid_reassignments = reassignment_rules.generate_all_reassignments()
assert(#invalid_reassignments == 0,
  "Archive reassignment candidates missing for: " .. table.concat(invalid_reassignments, ", "))

for input_name, reassignment in pairs(reassignments) do
  local results = {}
  for _, candidate in ipairs(reassignment.candidates) do
    results[#results + 1] = {
      type = "item",
      name = candidate.name,
      amount = 1,
      probability = reassignment_rules.OUTPUT_PROBABILITY,
    }
  end
  reassignment_recipes[#reassignment_recipes + 1] = {
    type = "recipe",
    name = reassignment_rules.recipe_name(input_name),
    localised_name = {"recipe-name.archive-form-reassignment", {"item-name." .. input_name}},
    localised_description = {"recipe-description.archive-form-reassignment"},
    icon = "__administratorio__/graphics/icons/blank-form.png",
    icon_size = 64,
    category = "archive-reassignment",
    subgroup = "form-reassignment-recipes",
    order = input_name,
    enabled = true,
    hidden = true,
    hidden_in_factoriopedia = false,
    hide_from_player_crafting = true,
    auto_recycle = false,
    allow_as_intermediate = false,
    allow_decomposition = false,
    allow_productivity = false,
    ingredients = {
      {type = "item", name = input_name, amount = 1},
    },
    results = results,
    energy_required = 1,
  }
end
table.sort(reassignment_recipes, function(left, right) return left.name < right.name end)
data:extend(reassignment_recipes)

-- Define these once during data.lua for stable recipe references. The same
-- helper runs again in data-final-fixes because Quality replaces automatic
-- recycling recipes during data-updates.
paperwork_recycling.apply()
