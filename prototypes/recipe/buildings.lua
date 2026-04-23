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

data:extend({
  -- Core Admin Buildings
  entity_recipe("field-office",               { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=10}, {type="item", name="paper", amount=5}, {type="item", name="stone-brick", amount=3}, {type="item", name="provisional-approval", amount=1}}, results = {{type="item", name="field-office", amount=1}}, energy_required = 5 }),
  entity_recipe("office-desk",               { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=20}, {type="item", name="iron-gear-wheel", amount=10}, {type="item", name="electronic-circuit", amount=10}, {type="item", name="biter-worker", amount=1}},                                            results = {{type="item", name="office-desk", amount=2}},      energy_required = 10 }),
  entity_recipe("biter-station",             { type = "recipe", category = "bureaucracy-registration", enabled = false, ingredients = {{type="item", name="iron-plate", amount=10}, {type="item", name="electronic-circuit", amount=5}, {type="item", name="job-offer", amount=2}, {type="item", name="taxpayer-money", amount=20}}, results = {{type="item", name="biter-station", amount=1}}, energy_required = 10 }),
  entity_recipe("biterport",                 { type = "recipe", category = "bureaucracy-registration", enabled = false, ingredients = {{type="item", name="iron-plate", amount=20}, {type="item", name="electronic-circuit", amount=10}, {type="item", name="construction-permit", amount=1}, {type="item", name="taxpayer-money", amount=30}}, results = {{type="item", name="biterport", amount=1}}, energy_required = 15 }),
  entity_recipe("admin-station",             { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=20}, {type="item", name="electronic-circuit", amount=10}, {type="item", name="provisional-approval", amount=1}},                                            results = {{type="item", name="admin-station", amount=1}},    energy_required = 15 }),
  entity_recipe("formation-center",          { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=30}, {type="item", name="electronic-circuit", amount=15}, {type="item", name="job-offer", amount=2}, {type="item", name="construction-permit", amount=1}, {type="item", name="taxpayer-money", amount=25}}, results = {{type="item", name="formation-center", amount=1}}, energy_required = 15 }),
  entity_recipe("resolution-office",         { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=30}, {type="item", name="electronic-circuit", amount=20}, {type="item", name="provisional-approval", amount=1}, {type="item", name="biter-worker", amount=1}},                                            results = {{type="item", name="resolution-office", amount=2}},energy_required = 20 }),
  entity_recipe("greenhouse",                { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=10}, {type="item", name="stone-brick", amount=10}, {type="item", name="pipe", amount=2}},                                                 results = {{type="item", name="greenhouse", amount=1}},       energy_required = 10 }),
  entity_recipe("union-headquarters",        { type = "recipe", enabled = false, ingredients = {{type="item", name="steel-plate", amount=45}, {type="item", name="advanced-circuit", amount=18}, {type="item", name="construction-permit", amount=3}, {type="item", name="treasury-bond", amount=3}, {type="item", name="management-approval-verbal", amount=1}, {type="item", name="management-verbal-work-order", amount=1}, {type="item", name="union-delegate", amount=2}}, results = {{type="item", name="union-headquarters", amount=1}}, energy_required = 35 }),
  entity_recipe("propaganda-distillery",     { type = "recipe", enabled = false, ingredients = {{type="item", name="steel-plate", amount=20}, {type="item", name="pipe", amount=10}, {type="item", name="electronic-circuit", amount=10}, {type="item", name="compacted-rubble", amount=5}, {type="item", name="construction-work-order", amount=1}}, results = {{type="item", name="propaganda-distillery", amount=1}}, energy_required = 15 }),

  -- Printers
  entity_recipe("mechanical-printer",        { type = "recipe", enabled = true,  ingredients = {{type="item", name="iron-plate", amount=5}, {type="item", name="stone", amount=5}, {type="item", name="paper", amount=8}},                                                                        results = {{type="item", name="mechanical-printer", amount=1}}, energy_required = 5 }),
  entity_recipe("printer-t1",                { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=10}, {type="item", name="iron-gear-wheel", amount=5}, {type="item", name="electronic-circuit", amount=3}, {type="item", name="provisional-approval", amount=1}}, results = {{type="item", name="printer-t1", amount=1}},    energy_required = 5 }),
  entity_recipe("printer-t2",                { type = "recipe", enabled = false, ingredients = {{type="item", name="steel-plate", amount=12}, {type="item", name="advanced-circuit", amount=8}, {type="item", name="iron-gear-wheel", amount=8}, {type="item", name="printer-t1", amount=1}, {type="item", name="construction-permit", amount=1}, {type="item", name="safety-work-order", amount=1}},   results = {{type="item", name="printer-t2", amount=1}},       energy_required = 10 }),

  -- Pneumatic Form Transport
  entity_recipe("pneumatic-pipe",            { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=2}, {type="item", name="pipe", amount=1}, {type="item", name="compacted-rubble", amount=1}},                               results = {{type="item", name="pneumatic-pipe", amount=2}},            energy_required = 1 }),
  entity_recipe("pneumatic-pipe-to-ground",  { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=5}, {type="item", name="pneumatic-pipe", amount=10}, {type="item", name="construction-permit", amount=1}},   results = {{type="item", name="pneumatic-pipe-to-ground", amount=2}},  energy_required = 3 }),
  entity_recipe("tube-intake",              { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=5}, {type="item", name="pipe", amount=2}, {type="item", name="electronic-circuit", amount=2}, {type="item", name="compacted-rubble", amount=3}}, results = {{type="item", name="tube-intake", amount=1}},              energy_required = 3 }),
  entity_recipe("tube-outtake",             { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=5}, {type="item", name="pipe", amount=2}, {type="item", name="electronic-circuit", amount=2}, {type="item", name="compacted-rubble", amount=3}}, results = {{type="item", name="tube-outtake", amount=1}},             energy_required = 3 }),
})

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
