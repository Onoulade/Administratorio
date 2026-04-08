local function entity_recipe(name, recipe)
  recipe.name = name
  recipe.localised_name = {"item-name." .. name}
  recipe.localised_description = {"item-description." .. name}
  return recipe
end

data:extend({
  -- Core Admin Buildings
  entity_recipe("office-desk",               { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=20}, {type="item", name="iron-gear-wheel", amount=10}, {type="item", name="electronic-circuit", amount=10}},                                            results = {{type="item", name="office-desk", amount=2}},      energy_required = 10 }),
  entity_recipe("admin-station",             { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=20}, {type="item", name="electronic-circuit", amount=10}, {type="item", name="provisional-approval", amount=1}},                                            results = {{type="item", name="admin-station", amount=1}},    energy_required = 15 }),
  entity_recipe("resolution-office",         { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=30}, {type="item", name="electronic-circuit", amount=20}, {type="item", name="provisional-approval", amount=1}},                                            results = {{type="item", name="resolution-office", amount=2}},energy_required = 20 }),
  entity_recipe("greenhouse",                { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=10}, {type="item", name="stone-brick", amount=10}, {type="item", name="pipe", amount=2}},                                                 results = {{type="item", name="greenhouse", amount=1}},       energy_required = 10 }),
  entity_recipe("union-headquarters",        { type = "recipe", enabled = false, ingredients = {{type="item", name="steel-plate", amount=45}, {type="item", name="advanced-circuit", amount=18}, {type="item", name="construction-permit", amount=3}, {type="item", name="treasury-bond", amount=3}, {type="item", name="management-approval-verbal", amount=1}, {type="item", name="government-grant", amount=1}}, results = {{type="item", name="union-headquarters", amount=1}}, energy_required = 35 }),
  entity_recipe("propaganda-distillery",     { type = "recipe", enabled = false, ingredients = {{type="item", name="steel-plate", amount=20}, {type="item", name="pipe", amount=10}, {type="item", name="electronic-circuit", amount=10}, {type="item", name="compacted-rubble", amount=5}}, results = {{type="item", name="propaganda-distillery", amount=1}}, energy_required = 15 }),

  -- Printers
  entity_recipe("mechanical-printer",        { type = "recipe", enabled = true,  ingredients = {{type="item", name="iron-plate", amount=5}, {type="item", name="stone", amount=5}, {type="item", name="paper", amount=8}},                                                                        results = {{type="item", name="mechanical-printer", amount=1}}, energy_required = 5 }),
  entity_recipe("printer-t1",                { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=10}, {type="item", name="iron-gear-wheel", amount=5}, {type="item", name="electronic-circuit", amount=3}, {type="item", name="provisional-approval", amount=1}}, results = {{type="item", name="printer-t1", amount=1}},    energy_required = 5 }),
  entity_recipe("printer-t2",                { type = "recipe", enabled = false, ingredients = {{type="item", name="steel-plate", amount=12}, {type="item", name="advanced-circuit", amount=8}, {type="item", name="iron-gear-wheel", amount=8}, {type="item", name="printer-t1", amount=1}, {type="item", name="construction-permit", amount=1}},   results = {{type="item", name="printer-t2", amount=1}},       energy_required = 10 }),

  -- Pneumatic Form Transport
  entity_recipe("pneumatic-pipe",            { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=2}, {type="item", name="pipe", amount=1}, {type="item", name="compacted-rubble", amount=1}},                               results = {{type="item", name="pneumatic-pipe", amount=2}},            energy_required = 1 }),
  entity_recipe("pneumatic-pipe-to-ground",  { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=5}, {type="item", name="pneumatic-pipe", amount=10}, {type="item", name="construction-permit", amount=1}},   results = {{type="item", name="pneumatic-pipe-to-ground", amount=2}},  energy_required = 3 }),
  entity_recipe("form-liquifier",            { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=5}, {type="item", name="pipe", amount=2}, {type="item", name="electronic-circuit", amount=2}, {type="item", name="compacted-rubble", amount=3}}, results = {{type="item", name="form-liquifier", amount=1}},            energy_required = 3 }),
  entity_recipe("form-solidifier",           { type = "recipe", enabled = false, ingredients = {{type="item", name="iron-plate", amount=5}, {type="item", name="pipe", amount=2}, {type="item", name="electronic-circuit", amount=2}, {type="item", name="compacted-rubble", amount=3}}, results = {{type="item", name="form-solidifier", amount=1}},           energy_required = 3 }),
})
