local feature_flags = require("feature_flags")
local planets = require("prototypes.shared.space_age_planets")
local space_age_enabled = feature_flags.space_age_enabled()

local function entity_recipe(name, recipe)
  recipe.name = name
  recipe.localised_name = {"item-name." .. name}
  recipe.localised_description = {"item-description." .. name}
  return recipe
end

local shared = require("prototypes.shared")

local function set_recipe_icon_from_item(recipe, item_name)
  local item_proto = (data.raw.item and data.raw.item[item_name])
    or (data.raw.tool and data.raw.tool[item_name])
    or (data.raw.module and data.raw.module[item_name])
    or (data.raw.capsule and data.raw.capsule[item_name])

  if item_proto and item_proto.icons then
    recipe.icons = table.deepcopy(item_proto.icons)
  elseif item_proto and item_proto.icon then
    recipe.icon = item_proto.icon
    recipe.icon_size = item_proto.icon_size
    recipe.icon_mipmaps = item_proto.icon_mipmaps
  else
    recipe.icon = "__core__/graphics/empty.png"
    recipe.icon_size = 1
  end
end

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

local function only_on_vulcanus(recipe)
  if not space_age_enabled then return nil end
  recipe.surface_conditions = planets.surface_conditions_for_planet("vulcanus")
  return recipe
end

local function not_in_space(recipe)
  if not space_age_enabled then
    return recipe
  end
  return planets.require_non_vacuum_surface(recipe)
end

local building_recipes = {
  -- Core Admin Buildings
  entity_recipe("field-office",               { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=5}, {type="item", name="stone-brick", amount=2}, {type="item", name="dubious-data", amount=1}}, results = {{type="item", name="field-office", amount=1}}, energy_required = 5 }),
  not_in_space(entity_recipe("office-desk",               { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=20}, {type="item", name="iron-gear-wheel", amount=10}, {type="item", name="electronic-circuit", amount=10}, {type="item", name="biter-worker", amount=1}},                                            results = {{type="item", name="office-desk", amount=2}},      energy_required = 10 })),
  entity_recipe("biter-station",             { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=10}, {type="item", name="electronic-circuit", amount=5}, {type="item", name="provisional-approval", amount=2}, {type="item", name="taxpayer-money", amount=20}}, results = {{type="item", name="biter-station", amount=1}}, energy_required = 10 }),
  entity_recipe("biterport",                 { type = "recipe", category = "bureaucracy-registration", enabled = false, ingredients = {{type="item", name="iron-plate", amount=20}, {type="item", name="electronic-circuit", amount=10}, {type="item", name="construction-permit", amount=1}, {type="item", name="taxpayer-money", amount=30}}, results = {{type="item", name="biterport", amount=1}}, energy_required = 15 }),
  entity_recipe("paperwork-provider-chest",  { type = "recipe", enabled = false, ingredients = {{type="item", name="wooden-chest", amount=1}, {type="item", name="paper", amount=2}, {type="item", name="work-order", amount=1}}, results = {{type="item", name="paperwork-provider-chest", amount=1}}, energy_required = 1 }),
  entity_recipe("paperwork-storage-chest",   { type = "recipe", enabled = false, ingredients = {{type="item", name="wooden-chest", amount=1}, {type="item", name="paper", amount=2}, {type="item", name="provisional-approval", amount=1}}, results = {{type="item", name="paperwork-storage-chest", amount=1}}, energy_required = 1 }),
  entity_recipe("paperwork-requester-chest", { type = "recipe", enabled = false, ingredients = {{type="item", name="wooden-chest", amount=1}, {type="item", name="paper", amount=2}, {type="item", name="management-verbal-draft", amount=1}}, results = {{type="item", name="paperwork-requester-chest", amount=1}}, energy_required = 1 }),
  not_in_space(entity_recipe("admin-station",             { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=20}, {type="item", name="electronic-circuit", amount=10}, {type="item", name="provisional-approval", amount=1}},                                            results = {{type="item", name="admin-station", amount=1}},    energy_required = 15 })),
  entity_recipe("formation-center",          { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=30}, {type="item", name="electronic-circuit", amount=15}, {type="item", name="construction-permit", amount=1}, {type="item", name="taxpayer-money", amount=25}}, results = {{type="item", name="formation-center", amount=1}}, energy_required = 15 }),
  not_in_space(entity_recipe("resolution-office",         { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=30}, {type="item", name="electronic-circuit", amount=20}, {type="item", name="provisional-approval", amount=1}, {type="item", name="biter-worker", amount=1}},                                            results = {{type="item", name="resolution-office", amount=2}},energy_required = 20 })),
  not_in_space(not_on_vulcanus(entity_recipe("greenhouse",{ type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=10}, {type="item", name="stone-brick", amount=10}, {type="item", name="pipe", amount=2}},                                                 results = {{type="item", name="greenhouse", amount=1}},       energy_required = 10 }))),
  not_in_space(entity_recipe("union-headquarters",        { type = "recipe", enabled = false, ingredients = {{type="item", name="steel-plate", amount=45}, {type="item", name="advanced-circuit", amount=18}, {type="item", name="construction-permit", amount=3}, {type="item", name="treasury-bond", amount=3}, {type="item", name="management-approval-verbal", amount=1}, {type="item", name="management-verbal-work-order", amount=1}}, results = {{type="item", name="union-headquarters", amount=1}}, energy_required = 35 })),
  not_in_space(entity_recipe("propaganda-distillery",     { type = "recipe", enabled = false, ingredients = {{type="item", name="steel-plate", amount=20}, {type="item", name="pipe", amount=10}, {type="item", name="electronic-circuit", amount=10}, {type="item", name="compacted-rubble", amount=5}, {type="item", name="construction-work-order", amount=1}}, results = {{type="item", name="propaganda-distillery", amount=1}}, energy_required = 15 })),

  -- Printers
  not_in_space(entity_recipe("mechanical-printer",        { type = "recipe", enabled = true,  ingredients = {{type="item", name="iron-plate", amount=5}, {type="item", name="stone", amount=5}, {type="item", name="paper", amount=5}},                                                                        results = {{type="item", name="mechanical-printer", amount=1}}, energy_required = 5 })),
  not_in_space(entity_recipe("printer-t1",                { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=10}, {type="item", name="iron-gear-wheel", amount=5}, {type="item", name="electronic-circuit", amount=3}, {type="item", name="provisional-approval", amount=1}}, results = {{type="item", name="printer-t1", amount=1}},    energy_required = 5 })),
  not_in_space(entity_recipe("printer-t2",                { type = "recipe", enabled = false, ingredients = {{type="item", name="steel-plate", amount=12}, {type="item", name="advanced-circuit", amount=8}, {type="item", name="iron-gear-wheel", amount=8}, {type="item", name="printer-t1", amount=1}, {type="item", name="construction-permit", amount=1}, {type="item", name="safety-work-order", amount=1}},   results = {{type="item", name="printer-t2", amount=1}},       energy_required = 10 })),

  -- Pneumatic Form Transport
  not_in_space(entity_recipe("pneumatic-pipe",            { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=2}, {type="item", name="pipe", amount=1}, {type="item", name="compacted-rubble", amount=1}},                               results = {{type="item", name="pneumatic-pipe", amount=2}},            energy_required = 1 })),
  not_in_space(entity_recipe("pneumatic-pipe-to-ground",  { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=5}, {type="item", name="pneumatic-pipe", amount=10}, {type="item", name="construction-permit", amount=1}},   results = {{type="item", name="pneumatic-pipe-to-ground", amount=2}},  energy_required = 3 })),
  not_in_space(entity_recipe("tube-intake",                { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=5}, {type="item", name="pipe", amount=2}, {type="item", name="electronic-circuit", amount=2}, {type="item", name="compacted-rubble", amount=3}}, results = {{type="item", name="tube-intake", amount=1}},              energy_required = 3 })),
  not_in_space(entity_recipe("tube-outtake",               { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=5}, {type="item", name="pipe", amount=2}, {type="item", name="electronic-circuit", amount=2}, {type="item", name="compacted-rubble", amount=3}}, results = {{type="item", name="tube-outtake", amount=1}},             energy_required = 3 })),
  not_in_space(entity_recipe("form-liquifier",            { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=5}, {type="item", name="pipe", amount=2}, {type="item", name="electronic-circuit", amount=2}, {type="item", name="compacted-rubble", amount=3}}, results = {{type="item", name="form-liquifier", amount=1}},            energy_required = 3 })),
  not_in_space(entity_recipe("form-solidifier",           { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=5}, {type="item", name="pipe", amount=2}, {type="item", name="electronic-circuit", amount=2}, {type="item", name="compacted-rubble", amount=3}}, results = {{type="item", name="form-solidifier", amount=1}},           energy_required = 3 })),
}

local vulcanus_distillery = only_on_vulcanus(entity_recipe("propaganda-distillery-vulcanus", { type = "recipe", enabled = false, ingredients = {{type="item", name="steel-plate", amount=20}, {type="item", name="pipe", amount=10}, {type="item", name="electronic-circuit", amount=10}, {type="item", name="calcite", amount=5}, {type="item", name="construction-work-order", amount=1}}, results = {{type="item", name="propaganda-distillery", amount=1}}, energy_required = 15 }))
if vulcanus_distillery then
  table.insert(building_recipes, vulcanus_distillery)
end

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
  set_recipe_icon_from_item(recipe, item_name)
  pneumatic_intake_recipes[#pneumatic_intake_recipes + 1] = recipe
end

data:extend(pneumatic_intake_recipes)
