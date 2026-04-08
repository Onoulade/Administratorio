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

data:extend({
  {
    type = "recipe",
    name = "worker-biter",
    category = "union-negotiation",
    enabled = false,
    ingredients = {
      {type = "item", name = "credentials", amount = 1},
      {type = "item", name = "good-excuse", amount = 1},
      {type = "item", name = "narrative", amount = 1},
      {type = "item", name = "taxpayer-money", amount = 25},
      {type = "fluid", name = "liquid-coffee", amount = 100},
    },
    results = {{type = "item", name = "worker-biter", amount = 1}},
    energy_required = 30
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
})

for _, recipe_name in ipairs({
  "foundry",
  "biochamber",
  "electromagnetic-plant",
  "cryogenic-plant",
}) do
  add_item_ingredient(data.raw.recipe and data.raw.recipe[recipe_name], "worker-biter", 1)
end
