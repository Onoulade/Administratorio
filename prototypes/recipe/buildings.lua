local feature_flags = require("feature_flags")
local planets = require("prototypes.shared.space_age_planets")
local space_age_enabled = feature_flags.space_age_enabled()
local worker_item_name = space_age_enabled and "worker-biter" or "biter-worker"

local function entity_recipe(name, recipe)
  recipe.name = name
  recipe.localised_name = {"item-name." .. name}
  recipe.localised_description = {"item-description." .. name}
  return recipe
end

local shared = require("prototypes.shared")

local recipe_icons = require("prototypes.shared.recipe_icons")

local function not_on_vulcanus(recipe)
  if not space_age_enabled then
    return recipe
  end
  recipe.surface_conditions = {
    {
      property = "pressure",
      max = planets.BASIC_PLANET_PROPERTIES.vulcanus.pressure - 1,
    },
  }
  return recipe
end

local function not_in_space(recipe)
  if not space_age_enabled then
    return recipe
  end
  return planets.require_non_vacuum_surface(recipe)
end

local function nauvis_only(recipe)
  if not space_age_enabled then
    return recipe
  end
  return planets.apply_planet_surface_conditions(recipe, "nauvis")
end

-- There is one construction recipe per building.  Space Age changes the
-- formation center's canonical cost, rather than defining the same recipe a
-- second time later in the data stage.
local formation_center_recipe
if space_age_enabled then
  formation_center_recipe = not_in_space(entity_recipe("formation-center", {
    type = "recipe",
    subgroup = "admin-biter-buildings", order = "a-f",
    enabled = false,
    ingredients = {
      {type="item", name="office-desk", amount=2},
      {type="item", name="printer-t1", amount=1},
      {type="item", name="electronic-circuit", amount=20},
      {type="item", name="construction-permit", amount=2},
      {type="item", name="steel-plate", amount=20},
      {type="item", name="stone-brick", amount=20},
    },
    results = {{type="item", name="formation-center", amount=1}},
    energy_required = 30,
  }))
else
  formation_center_recipe = entity_recipe("formation-center", {
    type = "recipe",
    subgroup = "admin-biter-buildings", order = "a-f",
    enabled = false,
    ingredients = {
      {type="item", name="iron-plate", amount=30},
      {type="item", name="electronic-circuit", amount=15},
      {type="item", name="construction-permit", amount=1},
      {type="item", name="taxpayer-money", amount=25},
    },
    results = {{type="item", name="formation-center", amount=1}},
    energy_required = 15,
  })
end

-- Space Age recruits an enrolled biter first and only turns it into a usable
-- worker at the Formation Center.  Requiring a worker to build the office
-- desk would therefore make the desk -> formation center -> worker chain
-- circular.  The base game keeps the worker ingredient because its direct
-- hiring path does not use the Space Age enrollment intermediate.
local office_desk_ingredients = {
  {type="item", name="iron-plate", amount=20},
  {type="item", name="iron-gear-wheel", amount=10},
  {type="item", name="electronic-circuit", amount=10},
}
if not space_age_enabled then
  office_desk_ingredients[#office_desk_ingredients + 1] = {type="item", name=worker_item_name, amount=1}
end

local building_recipes = {
  -- Core Admin Buildings -> admin-biter-buildings
  nauvis_only(entity_recipe("field-office",                { type = "recipe", subgroup = "admin-biter-buildings", order = "a-a", enabled = false, ingredients = {{type="item", name="iron-plate", amount=5}, {type="item", name="stone-brick", amount=2}, {type="item", name="dubious-data", amount=1}}, results = {{type="item", name="field-office", amount=1}}, energy_required = 5 })),
  not_in_space(entity_recipe("office-desk", {
    type = "recipe",
    subgroup = "admin-biter-buildings", order = "a-b", enabled = false,
    ingredients = office_desk_ingredients,
    results = {{type="item", name="office-desk", amount=2}},
    energy_required = 10,
  })),
  not_in_space(entity_recipe("biter-station",             { type = "recipe", subgroup = "admin-biter-logistics", order = "b", enabled = false, ingredients = {{type="item", name="iron-plate", amount=10}, {type="item", name="electronic-circuit", amount=5}, {type="item", name="provisional-approval", amount=2}, {type="item", name="taxpayer-money", amount=20}}, results = {{type="item", name="biter-station", amount=1}}, energy_required = 10 })),
  not_in_space(entity_recipe("biterport",                 { type = "recipe", subgroup = "admin-biter-logistics", order = "a", category = "bureaucracy-registration", enabled = false, ingredients = {{type="item", name="iron-plate", amount=20}, {type="item", name="electronic-circuit", amount=10}, {type="item", name="construction-work-order", amount=1}, {type="item", name="taxpayer-money", amount=30}}, results = {{type="item", name="biterport", amount=1}}, energy_required = 15 })),
  entity_recipe("paperwork-provider-chest",  { type = "recipe", subgroup = "admin-biter-logistics", order = "e", enabled = false, ingredients = {{type="item", name="wooden-chest", amount=1}, {type="item", name="paper", amount=2}, {type="item", name="work-order", amount=1}}, results = {{type="item", name="paperwork-provider-chest", amount=1}}, energy_required = 1 }),
  entity_recipe("paperwork-storage-chest",   { type = "recipe", subgroup = "admin-biter-logistics", order = "f", enabled = false, ingredients = {{type="item", name="wooden-chest", amount=1}, {type="item", name="paper", amount=2}, {type="item", name="provisional-approval", amount=1}}, results = {{type="item", name="paperwork-storage-chest", amount=1}}, energy_required = 1 }),
  entity_recipe("paperwork-requester-chest", { type = "recipe", subgroup = "admin-biter-logistics", order = "g", enabled = false, ingredients = {{type="item", name="wooden-chest", amount=1}, {type="item", name="paper", amount=2}, {type="item", name="management-verbal-draft", amount=1}}, results = {{type="item", name="paperwork-requester-chest", amount=1}}, energy_required = 1 }),
  nauvis_only(entity_recipe("admin-station",             { type = "recipe", subgroup = "admin-biter-logistics", order = "c", enabled = false, ingredients = {{type="item", name="iron-plate", amount=20}, {type="item", name="electronic-circuit", amount=10}, {type="item", name="provisional-approval", amount=1}},                                            results = {{type="item", name="admin-station", amount=1}},    energy_required = 15 })),
  formation_center_recipe,
  not_in_space(entity_recipe("resolution-office",         { type = "recipe", subgroup = "admin-biter-buildings", order = "a-g", enabled = false, ingredients = {{type="item", name="iron-plate", amount=30}, {type="item", name="electronic-circuit", amount=20}, {type="item", name="provisional-approval", amount=1}, {type="item", name=worker_item_name, amount=1}},                                            results = {{type="item", name="resolution-office", amount=2}},energy_required = 20 })),
  not_in_space(not_on_vulcanus(entity_recipe("greenhouse",{ type = "recipe", subgroup = "admin-production", order = "a-a", enabled = false, ingredients = {{type="item", name="iron-plate", amount=10}, {type="item", name="stone-brick", amount=10}, {type="item", name="pipe", amount=2}},                                                 results = {{type="item", name="greenhouse", amount=1}},       energy_required = 10 }))),
  not_in_space(entity_recipe("union-headquarters",        { type = "recipe", subgroup = "admin-buildings", order = "h-a", enabled = false, ingredients = {{type="item", name="steel-plate", amount=45}, {type="item", name="advanced-circuit", amount=18}, {type="item", name="construction-permit", amount=3}, {type="item", name="treasury-bond", amount=3}, {type="item", name="management-approval-verbal", amount=1}, {type="item", name="management-verbal-work-order", amount=1}, {type="item", name="union-delegate", amount=2}}, results = {{type="item", name="union-headquarters", amount=1}}, energy_required = 35 })),
  not_in_space(entity_recipe("propaganda-distillery",     { type = "recipe", subgroup = "admin-buildings", order = "h-b", enabled = false, ingredients = {{type="item", name="steel-plate", amount=20}, {type="item", name="pipe", amount=10}, {type="item", name="electronic-circuit", amount=10}, {type="item", name="compacted-rubble", amount=5}, {type="item", name="construction-work-order", amount=1}}, results = {{type="item", name="propaganda-distillery", amount=1}}, energy_required = 15 })),

  -- Printers -> admin-printers
  not_in_space(entity_recipe("mechanical-printer",        { type = "recipe", subgroup = "admin-printers", order = "i-a", enabled = true,  ingredients = {{type="item", name="iron-plate", amount=5}, {type="item", name="stone", amount=5}, {type="item", name="paper", amount=5}},                                                                        results = {{type="item", name="mechanical-printer", amount=1}}, energy_required = 5 })),
  not_in_space(entity_recipe("printer-t1",                { type = "recipe", subgroup = "admin-printers", order = "i-b", enabled = false, ingredients = {{type="item", name="iron-plate", amount=10}, {type="item", name="iron-gear-wheel", amount=5}, {type="item", name="electronic-circuit", amount=3}, {type="item", name="provisional-approval", amount=1}}, results = {{type="item", name="printer-t1", amount=1}},    energy_required = 5 })),
  entity_recipe("printer-t2",                { type = "recipe", subgroup = "admin-printers", order = "i-c", enabled = false, ingredients = {{type="item", name="steel-plate", amount=12}, {type="item", name="advanced-circuit", amount=8}, {type="item", name="iron-gear-wheel", amount=8}, {type="item", name="printer-t1", amount=1}, {type="item", name="construction-permit", amount=1}, {type="item", name="safety-work-order", amount=1}},   results = {{type="item", name="printer-t2", amount=1}},       energy_required = 10 }),

  -- Pneumatic Form Transport -> admin-infrastructure
  not_in_space(entity_recipe("pneumatic-pipe",            { type = "recipe", subgroup = "admin-infrastructure", order = "g-d", enabled = false, allow_quality = false, ingredients = {{type="item", name="iron-plate", amount=2}, {type="item", name="pipe", amount=1}, {type="item", name="compacted-rubble", amount=1}},                               results = {{type="item", name="pneumatic-pipe", amount=2}},            energy_required = 1 })),
  not_in_space(entity_recipe("pneumatic-pipe-to-ground",  { type = "recipe", subgroup = "admin-infrastructure", order = "g-e", enabled = false, allow_quality = false, ingredients = {{type="item", name="iron-plate", amount=5}, {type="item", name="pneumatic-pipe", amount=10}, {type="item", name="construction-permit", amount=1}},   results = {{type="item", name="pneumatic-pipe-to-ground", amount=2}},  energy_required = 3 })),
  not_in_space(entity_recipe("tube-intake",                { type = "recipe", subgroup = "admin-infrastructure", order = "g-f", enabled = false, allow_quality = false, ingredients = {{type="item", name="iron-plate", amount=5}, {type="item", name="pipe", amount=2}, {type="item", name="electronic-circuit", amount=2}, {type="item", name="compacted-rubble", amount=3}}, results = {{type="item", name="tube-intake", amount=1}},              energy_required = 3 })),
  not_in_space(entity_recipe("tube-outtake",               { type = "recipe", subgroup = "admin-infrastructure", order = "g-g", enabled = false, allow_quality = false, ingredients = {{type="item", name="iron-plate", amount=5}, {type="item", name="pipe", amount=2}, {type="item", name="electronic-circuit", amount=2}, {type="item", name="compacted-rubble", amount=3}}, results = {{type="item", name="tube-outtake", amount=1}},             energy_required = 3 })),
}

data:extend(building_recipes)

local pneumatic_intake_recipes = {}
local pneumatic_item_names = {}
for item_name in pairs(shared.PNEUMATIC_ITEMS) do
  pneumatic_item_names[#pneumatic_item_names + 1] = item_name
end
table.sort(pneumatic_item_names)

for _, item_name in ipairs(pneumatic_item_names) do
  local recipe = {
    type = "recipe",
    name = "pneumatic-intake-" .. item_name,
    category = "pneumatic-intake",
    enabled = false,
    hidden = true,
    hidden_in_factoriopedia = true,
    hide_from_player_crafting = true,
    allow_as_intermediate = false,
    allow_decomposition = false,
    allow_productivity = false,
    energy_required = 3600,
    ingredients = {{type = "item", name = item_name, amount = 1}},
    results = {},
  }
  recipe_icons.from_item(recipe, item_name)
  pneumatic_intake_recipes[#pneumatic_intake_recipes + 1] = recipe
end

data:extend(pneumatic_intake_recipes)
