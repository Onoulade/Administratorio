data:extend({
  -- Greenhouse & Coffee
  { type = "recipe", name = "greenhouse-wood",      category = "admin-greenhouse", enabled = false, ingredients = {{type="fluid", name="water", amount=100}},                                                                      results = {{type="item", name="wood", amount=10}},                                                  energy_required = 30 },
  {
    type = "recipe", name = "greenhouse-discovery", category = "admin-greenhouse", enabled = false,
    icon = "__administratorio__/graphics/icons/coffee-bean.png", icon_size = 32,
    subgroup = "admin-raw", order = "c0",
    ingredients = {{type="item", name="wood", amount=10}, {type="fluid", name="water", amount=50}},
    results = {
      {type="item", name="coffee-bean", amount=1, probability=0.1},
      {type="item", name="wood", amount=5}
    },
    main_product = "coffee-bean",
    energy_required = 10
  },
  { type = "recipe", name = "coffee-plantation",      category = "admin-greenhouse",   enabled = false, ingredients = {{type="item", name="coffee-bean", amount=1}, {type="fluid", name="water", amount=100}}, results = {{type="item", name="coffee-bean", amount=3}},  energy_required = 45 },
  { type = "recipe", name = "coffee-refining",        category = "watercooler-gossip",    enabled = false, subgroup = "admin-raw", order = "c1", ingredients = {{type="item", name="coffee-bean", amount=1}, {type="fluid", name="water", amount=50}}, results = {{type="fluid", name="liquid-coffee", amount=50}}, energy_required = 3 },

  -- Batch Smelting (Stone Furnace - requires carbon offset certificate)
  { type = "recipe", name = "iron-plate-batch",   category = "smelting-basic", enabled = true,  ingredients = {{type="item", name="iron-ore", amount=10},   {type="item", name="carbon-offset-certificate-basic", amount=1}}, results = {{type="item", name="iron-plate", amount=10}},   energy_required = 32,  allow_decomposition = false },
  { type = "recipe", name = "copper-plate-batch", category = "smelting-basic", enabled = true,  ingredients = {{type="item", name="copper-ore", amount=10}, {type="item", name="carbon-offset-certificate-basic", amount=1}}, results = {{type="item", name="copper-plate", amount=10}}, energy_required = 32,  allow_decomposition = false },
  { type = "recipe", name = "steel-plate-batch",  category = "smelting-basic", enabled = false, ingredients = {{type="item", name="iron-plate", amount=50},{type="item", name="carbon-offset-certificate-basic", amount=1}}, results = {{type="item", name="steel-plate", amount=10}},  energy_required = 180, allow_decomposition = false },
  { type = "recipe", name = "stone-brick-batch",  category = "smelting-basic", enabled = true,  ingredients = {{type="item", name="stone", amount=20},      {type="item", name="carbon-offset-certificate-basic", amount=1}}, results = {{type="item", name="stone-brick", amount=10}},  energy_required = 32,  allow_decomposition = false },
  { type = "recipe", name = "dubious-data-batch", category = "smelting-basic", enabled = true,  ingredients = {{type="item", name="bullshit-ore", amount=10},{type="item", name="carbon-offset-certificate-basic", amount=1}}, results = {{type="item", name="dubious-data", amount=10}}, energy_required = 32,  allow_decomposition = false },

  -- Printing / Copy Recipes
  { type = "recipe", name = "copy-blank-form",                    category = "printing-advanced", enabled = false, icon = "__administratorio__/graphics/icons/blank-form.png",       icon_size = 64, ingredients = {{type="item", name="blank-form", amount=1},                    {type="item", name="paper", amount=5}, {type="item", name="ink", amount=1}}, results = {{type="item", name="blank-form", amount=6}}, main_product = "blank-form",                    energy_required = 5 },
  { type = "recipe", name = "copy-blank-approval",                category = "printing-advanced", enabled = false, icon = "__administratorio__/graphics/icons/blank-approval.png",   icon_size = 64, ingredients = {{type="item", name="blank-approval", amount=1},                {type="item", name="paper", amount=5}, {type="item", name="ink", amount=1}}, results = {{type="item", name="blank-approval", amount=6}},                main_product = "blank-approval",                energy_required = 5 },
  { type = "recipe", name = "copy-blank-directive",               category = "printing-advanced", enabled = false, icon = "__administratorio__/graphics/icons/blank-directive.png",  icon_size = 64, ingredients = {{type="item", name="blank-directive", amount=1},               {type="item", name="paper", amount=5}, {type="item", name="ink", amount=1}}, results = {{type="item", name="blank-directive", amount=6}},               main_product = "blank-directive",               energy_required = 5 },
  { type = "recipe", name = "copy-carbon-offset-certificate",     category = "printing-advanced", enabled = false, icon = "__administratorio__/graphics/icons/carbon-offset-certificate-basic.png",  icon_size = 64, ingredients = {{type="item", name="carbon-offset-certificate-basic", amount=1},{type="item", name="paper", amount=5}, {type="item", name="ink", amount=1}}, results = {{type="item", name="carbon-offset-certificate-basic", amount=6}}, main_product = "carbon-offset-certificate-basic", energy_required = 5 },
  { type = "recipe", name = "copy-form-27b-6",                   category = "printing-advanced", enabled = false, icon = "__administratorio__/graphics/icons/blank-form.png",       icon_size = 64, ingredients = {{type="item", name="form-27b-6", amount=1},                   {type="item", name="paper", amount=5}, {type="item", name="ink", amount=1}}, results = {{type="item", name="form-27b-6", amount=6}},                   main_product = "form-27b-6",                   energy_required = 5 },
  { type = "recipe", name = "copy-environmental-impact-report",   category = "printing-advanced", enabled = false, icon = "__administratorio__/graphics/icons/crappy-report.png",    icon_size = 64, ingredients = {{type="item", name="environmental-impact-report", amount=1},   {type="item", name="paper", amount=5}, {type="item", name="ink", amount=1}}, results = {{type="item", name="environmental-impact-report", amount=6}},   main_product = "environmental-impact-report",   energy_required = 8 },

  -- Compacted Rubble (T0 derivative — industrially compressed rubble)
  { type = "recipe", name = "compacted-rubble-production", category = "smelting-basic", enabled = false, ingredients = {{type="item", name="redundant-rubble", amount=5}, {type="item", name="carbon-offset-certificate-basic", amount=1}}, results = {{type="item", name="compacted-rubble", amount=5}}, energy_required = 16 },

  -- Charcoal Production (T3 — burn wood to produce coal)
  { type = "recipe", name = "charcoal-production", category = "smelting-basic", enabled = false, ingredients = {{type="item", name="wood", amount=5}}, results = {{type="item", name="coal", amount=1}}, energy_required = 8 },

})
