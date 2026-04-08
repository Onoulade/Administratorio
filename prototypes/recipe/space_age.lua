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
    name = "formation-center",
    enabled = false,
    ingredients = {
      {type = "item", name = "office-desk", amount = 2},
      {type = "item", name = "printer-t2", amount = 1},
      {type = "item", name = "processing-unit", amount = 10},
      {type = "item", name = "management-approval-written", amount = 1},
      {type = "item", name = "refined-concrete", amount = 20},
    },
    results = {{type = "item", name = "formation-center", amount = 1}},
    energy_required = 30
  },
  {
    type = "recipe",
    name = "worker-biter-formation",
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {type = "item", name = "enrolled-biter", amount = 1},
      {type = "item", name = "credentials", amount = 1},
      {type = "item", name = "good-excuse", amount = 1},
      {type = "item", name = "taxpayer-money", amount = 5},
    },
    results = {{type = "item", name = "worker-biter", amount = 1}},
    energy_required = 10
  },
  {
    type = "recipe",
    name = "clerical-trainee-formation",
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {type = "item", name = "worker-biter", amount = 1},
      {type = "item", name = "credentials", amount = 1},
      {type = "item", name = "paper", amount = 5},
    },
    results = {{type = "item", name = "clerical-trainee", amount = 1}},
    energy_required = 15
  },
  {
    type = "recipe",
    name = "management-trainee-formation",
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {type = "item", name = "worker-biter", amount = 1},
      {type = "item", name = "narrative", amount = 1},
      {type = "item", name = "management-approval-verbal", amount = 1},
      {type = "item", name = "taxpayer-money", amount = 10},
    },
    results = {{type = "item", name = "management-trainee", amount = 1}},
    energy_required = 20
  },
  {
    type = "recipe",
    name = "night-shift-supervisor-formation",
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {type = "item", name = "clerical-trainee", amount = 1},
      {type = "item", name = "regulation", amount = 1},
      {type = "item", name = "productivity-module", amount = 1},
    },
    results = {{type = "item", name = "night-shift-supervisor", amount = 1}},
    energy_required = 20
  },
  {
    type = "recipe",
    name = "licensed-notary-formation",
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {type = "item", name = "clerical-trainee", amount = 1},
      {type = "item", name = "construction-permit", amount = 1},
      {type = "item", name = "management-approval-verbal", amount = 1},
    },
    results = {{type = "item", name = "licensed-notary", amount = 1}},
    energy_required = 20
  },
  {
    type = "recipe",
    name = "conciliation-officer-formation",
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {type = "item", name = "clerical-trainee", amount = 1},
      {type = "item", name = "good-excuse", amount = 1},
      {type = "item", name = "promise", amount = 1},
    },
    results = {{type = "item", name = "conciliation-officer", amount = 1}},
    energy_required = 20
  },
  {
    type = "recipe",
    name = "relay-clerk-formation",
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {type = "item", name = "clerical-trainee", amount = 1},
      {type = "item", name = "data", amount = 1},
      {type = "item", name = "processing-unit", amount = 1},
    },
    results = {{type = "item", name = "relay-clerk", amount = 1}},
    energy_required = 20
  },
  {
    type = "recipe",
    name = "cryoprint-technician-formation",
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {type = "item", name = "clerical-trainee", amount = 1},
      {type = "item", name = "processing-unit", amount = 2},
      {type = "item", name = "management-approval-written", amount = 1},
    },
    results = {{type = "item", name = "cryoprint-technician", amount = 1}},
    energy_required = 25
  },
  {
    type = "recipe",
    name = "field-negotiator-formation",
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {type = "item", name = "management-trainee", amount = 1},
      {type = "item", name = "eviction-notice", amount = 1},
      {type = "item", name = "management-approval-written", amount = 1},
    },
    results = {{type = "item", name = "field-negotiator", amount = 1}},
    energy_required = 25
  },
  {
    type = "recipe",
    name = "middle-management-managing-manager-formation",
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {type = "item", name = "management-trainee", amount = 1},
      {type = "item", name = "policy", amount = 1},
      {type = "item", name = "office-drama", amount = 2},
    },
    results = {{type = "item", name = "middle-management-managing-manager", amount = 1}},
    energy_required = 25
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
  {
    type = "recipe",
    name = "overtime-exemption-staffed",
    category = "union-negotiation",
    enabled = false,
    localised_name = {"recipe-name.overtime-exemption"},
    ingredients = {
      {type = "item", name = "night-shift-supervisor", amount = 1},
      {type = "item", name = "productivity-module", amount = 1},
      {type = "item", name = "processing-unit", amount = 6},
      {type = "item", name = "government-grant", amount = 2},
      {type = "item", name = "regulation", amount = 2},
      {type = "item", name = "management-approval-written", amount = 1},
      {type = "fluid", name = "liquid-coffee", amount = 60},
    },
    results = {
      {type = "item", name = "overtime-exemption", amount = 1},
    },
    energy_required = 20,
  },
  {
    type = "recipe",
    name = "promise-production-negotiated",
    category = "union-negotiation",
    enabled = false,
    localised_name = {"recipe-name.promise-production"},
    ingredients = {
      {type = "item", name = "field-negotiator", amount = 1},
      {type = "item", name = "blank-form", amount = 4},
      {type = "item", name = "good-excuse", amount = 1},
      {type = "item", name = "management-approval-verbal", amount = 1},
      {type = "fluid", name = "liquid-coffee", amount = 50},
    },
    results = {
      {type = "item", name = "promise", amount = 3},
    },
    energy_required = 15,
  },
  {
    type = "recipe",
    name = "eviction-notice-production-negotiated",
    category = "bureaucracy-policy",
    enabled = false,
    localised_name = {"recipe-name.eviction-notice-production"},
    ingredients = {
      {type = "item", name = "field-negotiator", amount = 1},
      {type = "item", name = "good-excuse", amount = 1},
      {type = "item", name = "credentials", amount = 1},
      {type = "item", name = "management-approval-written", amount = 1},
      {type = "fluid", name = "politician-fluid", amount = 50},
      {type = "item", name = "taxpayer-money", amount = 60},
    },
    results = {
      {type = "item", name = "eviction-notice", amount = 2},
    },
    energy_required = 25,
  },
})

for _, recipe_name in ipairs({
  "foundry",
  "biochamber",
  "electromagnetic-plant",
  "cryogenic-plant",
}) do
  local specialist_by_recipe = {
    ["foundry"] = "licensed-notary",
    ["biochamber"] = "conciliation-officer",
    ["electromagnetic-plant"] = "relay-clerk",
    ["cryogenic-plant"] = "cryoprint-technician",
  }
  add_item_ingredient(data.raw.recipe and data.raw.recipe[recipe_name], specialist_by_recipe[recipe_name], 1)
end

for _, recipe_name in ipairs({
  "space-platform-starter-pack",
  "cargo-bay",
  "asteroid-collector",
  "crusher",
}) do
  add_item_ingredient(data.raw.recipe and data.raw.recipe[recipe_name], "middle-management-managing-manager", 1)
end
