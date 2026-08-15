local planets = require("prototypes.shared.space_age_planets")
local bureaucracy_categories = require("prototypes.shared.bureaucracy_categories")
local manager_briefings = require("prototypes.shared.manager_briefings")

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

local function add_item_result(recipe, result_name, amount, ignored_by_productivity, ignored_by_stats)
  if not recipe then return end

  local function apply_to_variant(target)
    if not target then return end
    target.results = target.results or {}

    for _, result in ipairs(target.results) do
      if (result.name or result[1]) == result_name then
        return
      end
    end

    if not target.main_product then
      local first_result = target.results[1]
      target.main_product = first_result and (first_result.name or first_result[1]) or nil
    end

    table.insert(target.results, {
      type = "item",
      name = result_name,
      amount = amount,
      ignored_by_productivity = ignored_by_productivity,
      ignored_by_stats = ignored_by_stats,
    })
  end

  apply_to_variant(recipe)
  apply_to_variant(recipe.normal)
  apply_to_variant(recipe.expensive)
end

local function add_manager_requirements(recipe_name, briefing_keys)
  local recipe = data.raw.recipe and data.raw.recipe[recipe_name]
  if not recipe then return end

  for _, key in ipairs(briefing_keys) do
    local briefing = assert(manager_briefings.BY_KEY[key], "unknown manager briefing: " .. tostring(key))
    add_item_ingredient(recipe, briefing.item, 1)

    local function mark_ingredient(target)
      for _, ingredient in ipairs((target and target.ingredients) or {}) do
        if (ingredient.name or ingredient[1]) == briefing.item then
          ingredient.ignored_by_stats = 1
        end
      end
    end
    mark_ingredient(recipe)
    mark_ingredient(recipe.normal)
    mark_ingredient(recipe.expensive)
  end

  add_item_result(
    recipe,
    manager_briefings.REGULAR_MANAGER,
    #briefing_keys,
    #briefing_keys,
    #briefing_keys
  )
end

local function remove_ingredient(recipe, ingredient_name)
  if not recipe then return end

  local function apply_to_variant(target)
    if not target or not target.ingredients then return end

    local filtered = {}
    for _, ingredient in ipairs(target.ingredients) do
      if (ingredient.name or ingredient[1]) ~= ingredient_name then
        filtered[#filtered + 1] = ingredient
      end
    end
    target.ingredients = filtered
  end

  apply_to_variant(recipe)
  apply_to_variant(recipe.normal)
  apply_to_variant(recipe.expensive)
end

local function surface_limited(recipe, planet_name)
  return planets.apply_planet_surface_conditions(recipe, planet_name)
end

-- Keep Space Age's one canonical space-science recipe, but make the
-- Administrative Space Station its machine. Besides matching the orbital
-- paperwork theme, this keeps the generic regulated-assembler pass from
-- generating a second hidden science recipe.
local native_space_science_recipe = data.raw.recipe and data.raw.recipe["space-science-pack"]
if native_space_science_recipe then
  native_space_science_recipe.category = "orbital-bureaucracy"
end

-- Creating a new biter profession remains a Nauvis institution. Space Age
-- only makes the short-lived MMMM briefing recipes portable between planets.
for _, recipe in pairs(data.raw.recipe or {}) do
  if recipe.category == "biter-training" then
    surface_limited(recipe, "nauvis")
  end
end

local function add_scrap_recycling_result(item_name, amount, probability)
  local recipe = data.raw.recipe and data.raw.recipe["scrap-recycling"]
  if not recipe then return end

  local function apply_to_variant(target)
    if not target then return end
    target.results = target.results or {}
    for _, result in ipairs(target.results) do
      if (result.name or result[1]) == item_name then
        return
      end
    end
    table.insert(target.results, {
      type = "item",
      name = item_name,
      amount = amount,
      probability = probability,
    })
  end

  apply_to_variant(recipe)
  apply_to_variant(recipe.normal)
  apply_to_variant(recipe.expensive)
end

local function sync_scrap_recycler_output_slots()
  local recipe = data.raw.recipe and data.raw.recipe["scrap-recycling"]
  local recycler = data.raw.furnace and data.raw.furnace["recycler"]
  if not recipe or not recycler then return end

  local required_slots = 0
  local function count_item_results(target)
    if not target or not target.results then return end
    local slots = 0
    for _, result in ipairs(target.results) do
      if (result.type or "item") == "item" then
        slots = slots + 1
      end
    end
    required_slots = math.max(required_slots, slots)
  end

  count_item_results(recipe)
  count_item_results(recipe.normal)
  count_item_results(recipe.expensive)

  if required_slots > 0 then
    recycler.result_inventory_size = math.max(recycler.result_inventory_size or 0, required_slots)
  end
end

local function not_on_planet(recipe, planet_name)
  local properties = planets.BASIC_PLANET_PROPERTIES[planet_name]
  if not recipe or not properties then return recipe end
  if planet_name == "aquilo" then
    recipe.surface_conditions = {
      {
        property = "pressure",
        min = properties.pressure + 1,
      },
    }
  else
    recipe.surface_conditions = {
      {
        property = "pressure",
        max = properties.pressure - 1,
      },
    }
  end
  return recipe
end

add_scrap_recycling_result("charged-toner", 1, 0.12)
add_scrap_recycling_result("redundant-rubble", 2, 0.35)
add_scrap_recycling_result("useless-documentation", 1, 0.08)
add_scrap_recycling_result("old-archive", 1, 0.06)
sync_scrap_recycler_output_slots()

local function not_in_space(recipe)
  return planets.require_non_vacuum_surface(recipe)
end

local function vacuum_only(recipe)
  recipe.surface_conditions = {
    {property = "pressure", min = 0, max = 0},
  }
  return recipe
end

local manager_meeting_recipes = {}
for _, briefing in ipairs(manager_briefings.BRIEFINGS) do
  manager_meeting_recipes[#manager_meeting_recipes + 1] = not_in_space({
    type = "recipe",
    name = briefing.recipe,
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {
        type = "item",
        name = manager_briefings.REGULAR_MANAGER,
        amount = 1,
        ignored_by_stats = 1,
      },
      {type = "item", name = briefing.material, amount = briefing.material_amount},
      {type = "fluid", name = "liquid-coffee", amount = 5},
    },
    results = {
      {
        type = "item",
        name = briefing.item,
        amount = 1,
        ignored_by_productivity = 1,
        ignored_by_stats = 1,
      },
    },
    energy_required = 5,
    allow_productivity = false,
    allow_decomposition = false,
    auto_recycle = false,
  })
end
data:extend(manager_meeting_recipes)

data:extend({
  surface_limited({
    type = "recipe",
    name = "job-offer-production",
    category = "bureaucracy-policy",
    enabled = false,
    ingredients = {
      {type = "item", name = "treasury-bond", amount = 2},
      {type = "item", name = "taxpayer-money", amount = 50},
      {type = "item", name = "credentials", amount = 1},
      {type = "item", name = "good-excuse", amount = 1},
      {type = "item", name = "narrative", amount = 1},
      {type = "item", name = "paper", amount = 10},
    },
    results = {{type = "item", name = "job-offer", amount = 1}},
    energy_required = 30
  }, "nauvis"),
  surface_limited({
    type = "recipe",
    name = "worker-biter-formation",
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {type = "item", name = "enrolled-biter", amount = 1},
      {type = "item", name = "credentials", amount = 1},
      {type = "item", name = "good-excuse", amount = 1},
    },
    results = {{type = "item", name = "worker-biter", amount = 1}},
    energy_required = 10
  }, "nauvis"),
  surface_limited({
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
  }, "nauvis"),
  surface_limited({
    type = "recipe",
    name = "management-trainee-formation",
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {type = "item", name = "worker-biter", amount = 1},
      {type = "item", name = "narrative", amount = 1},
      {type = "item", name = "management-approval-verbal", amount = 1},
    },
    results = {{type = "item", name = "management-trainee", amount = 1}},
    energy_required = 20
  }, "nauvis"),
  surface_limited({
    type = "recipe",
    name = "astronaut-formation",
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {type = "item", name = "management-trainee", amount = 1},
      {type = "item", name = "transit-authorization", amount = 1},
      {type = "item", name = "low-density-structure", amount = 2},
      {type = "item", name = "processing-unit", amount = 2},
    },
    results = {{type = "item", name = "astronaut", amount = 1}},
    energy_required = 25
  }, "nauvis"),
  surface_limited({
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
  }, "nauvis"),
  surface_limited({
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
  }, "nauvis"),
  surface_limited({
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
  }, "nauvis"),
  surface_limited({
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
  }, "nauvis"),
  surface_limited({
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
  }, "nauvis"),
  surface_limited({
    type = "recipe",
    name = "voluntary-exploration-space-miner-formation",
    category = "workforce-formation",
    enabled = false,
    ingredients = {
      {type = "item", name = "astronaut", amount = 1},
      {type = "item", name = "electric-mining-drill", amount = 1},
      {
        type = "item",
        name = manager_briefings.BY_KEY.training.item,
        amount = 1,
        ignored_by_stats = 1,
      },
      {
        type = "item",
        name = manager_briefings.BY_KEY.compliance.item,
        amount = 1,
        ignored_by_stats = 1,
      },
      {
        type = "item",
        name = manager_briefings.BY_KEY.orbital.item,
        amount = 1,
        ignored_by_stats = 1,
      },
    },
    results = {
      {type = "item", name = manager_briefings.VESM, amount = 1},
      {
        type = "item",
        name = manager_briefings.REGULAR_MANAGER,
        amount = 3,
        ignored_by_productivity = 3,
        ignored_by_stats = 3,
      },
    },
    main_product = manager_briefings.VESM,
    energy_required = 60,
    auto_recycle = false,
  }, "nauvis"),
  not_on_planet({
    type = "recipe",
    name = "chromatic-printer",
    enabled = false,
    ingredients = {
      {type = "item", name = "printer-t2", amount = 1},
      {type = "item", name = "steel-plate", amount = 20},
      {type = "item", name = "advanced-circuit", amount = 20},
      {type = "item", name = "processing-unit", amount = 8},
      {type = "item", name = "dubious-data", amount = 4},
      {type = "item", name = "construction-work-order", amount = 1},
    },
    results = {{type = "item", name = "chromatic-printer", amount = 1}},
    energy_required = 12
  }, "aquilo"),
  surface_limited({
    type = "recipe",
    name = "notary-office",
    subgroup = "admin-buildings",
    enabled = false,
    ingredients = {
      {type = "item", name = "office-desk", amount = 2},
      {type = "item", name = "chromatic-printer", amount = 1},
      {type = "item", name = "licensed-notary", amount = 1},
      {type = "item", name = "tungsten-carbide", amount = 4},
      {type = "item", name = "steel-plate", amount = 20},
      {type = "item", name = "advanced-circuit", amount = 10},
      {type = "item", name = "permit-draft", amount = 1},
    },
    results = {{type = "item", name = "notary-office", amount = 1}},
    energy_required = 16
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "territorial-arbitration-post",
    subgroup = "admin-buildings",
    enabled = false,
    ingredients = {
      {type = "item", name = "office-desk", amount = 1},
      {type = "item", name = "licensed-notary", amount = 1},
      {type = "item", name = "steel-plate", amount = 20},
      {type = "item", name = "advanced-circuit", amount = 10},
      {type = "item", name = "tungsten-carbide", amount = 6},
      {type = "item", name = "construction-permit", amount = 1},
      {type = "item", name = "radar", amount = 1},
    },
    results = {{type = "item", name = "territorial-arbitration-post", amount = 1}},
    energy_required = 16
  }, "vulcanus"),
  {
    type = "recipe",
    name = "territorial-arbitration-processing",
    category = "territorial-arbitration",
    enabled = true,
    hidden = true,
    hide_from_player_crafting = true,
    allow_decomposition = false,
    ingredients = {
      {type = "item", name = "territorial-resettlement-order", amount = 1},
      {type = "fluid", name = "lie", amount = 50},
    },
    results = {
      {type = "item", name = "territorial-deed", amount = 1},
    },
    energy_required = 1,
  },
  surface_limited({
    type = "recipe",
    name = "capture-bureau",
    subgroup = "admin-biter-buildings",
    enabled = false,
    localised_name = {"item-name.capture-bureau"},
    localised_description = {"item-description.capture-bureau"},
    ingredients = {
      {type = "item", name = "construction-permit", amount = 1},
      {type = "item", name = "conciliation-officer", amount = 1},
      {type = "item", name = "worker-biter", amount = 1},
      {type = "item", name = "steel-plate", amount = 20},
      {type = "item", name = "advanced-circuit", amount = 10},
      {type = "item", name = "construction-work-order", amount = 1},
    },
    results = {{type = "item", name = "capture-bureau", amount = 1}},
    energy_required = 16
  }, "gleba"),
  surface_limited({
    type = "recipe",
    name = "capture-bureau-workforce",
    category = "hostile-acquisition",
    enabled = false,
    localised_name = {"", "Capture Bureau: Workforce Intake"},
    localised_description = {
      "",
      "Attract nearby Nauvis biters and convert them directly into ",
      {"item-name.worker-biter"},
      ".",
    },
    ingredients = {
      {type = "item", name = "capture-bureau-processing-token", amount = 1},
    },
    results = {
      {type = "item", name = "capture-bureau-processing-token", amount = 1},
    },
    hidden_in_factoriopedia = true,
    allow_as_intermediate = false,
    allow_intermediates = false,
    hide_from_player_crafting = true,
    energy_required = 1,
  }, "nauvis"),
  {
    type = "recipe",
    name = "capture-bureau-spore-diffusion",
    category = "capture-bureau-runtime",
    enabled = true,
    hidden = true,
    hidden_in_factoriopedia = true,
    hide_from_player_crafting = true,
    allow_as_intermediate = false,
    allow_decomposition = false,
    ingredients = {
      {type = "item", name = "capture-bureau-processing-token", amount = 1},
      {type = "fluid", name = "workforce-lure-spores", amount = 1},
      {type = "fluid", name = "tourism-lure-spores", amount = 1},
      {type = "fluid", name = "oviposition-lure-spores", amount = 1},
    },
    results = {
      {type = "item", name = "capture-bureau-processing-token", amount = 1},
    },
    energy_required = 60,
  },
  surface_limited({
    type = "recipe",
    name = "capture-bureau-tourism",
    category = "hostile-acquisition",
    enabled = false,
    localised_name = {"", "Capture Bureau: Spitter Tourism Intake"},
    localised_description = {
      "",
      "Attract nearby Nauvis spitters and itemize them for offworld tourism before they spoil.",
    },
    ingredients = {
      {type = "item", name = "capture-bureau-processing-token", amount = 1},
      {type = "item", name = "cyan-yellow-form", amount = 1},
    },
    results = {
      {type = "item", name = "capture-bureau-processing-token", amount = 1},
    },
    hidden_in_factoriopedia = true,
    allow_as_intermediate = false,
    allow_intermediates = false,
    hide_from_player_crafting = true,
    energy_required = 1,
  }, "nauvis"),
  surface_limited({
    type = "recipe",
    name = "capture-bureau-pentapod-eggs",
    category = "hostile-acquisition",
    enabled = false,
    localised_name = {"", "Capture Bureau: Pentapod Egg Harvest"},
    localised_description = {
      "",
      "Attract nearby Gleba pentapods and process them into fresh ",
      {"item-name.pentapod-egg"},
      ".",
    },
    ingredients = {
      {type = "item", name = "capture-bureau-processing-token", amount = 1},
    },
    results = {
      {type = "item", name = "capture-bureau-processing-token", amount = 1},
    },
    hidden_in_factoriopedia = true,
    allow_as_intermediate = false,
    allow_intermediates = false,
    hide_from_player_crafting = true,
    energy_required = 1,
  }, "gleba"),
  surface_limited({
    type = "recipe",
    name = "conciliation-desk",
    subgroup = "admin-biter-buildings",
    enabled = false,
    ingredients = {
      {type = "item", name = "office-desk", amount = 2},
      {type = "item", name = "chromatic-printer", amount = 1},
      {type = "item", name = "conciliation-officer", amount = 1},
      {type = "item", name = "steel-plate", amount = 20},
      {type = "item", name = "advanced-circuit", amount = 10},
      {type = "item", name = "nutrients", amount = 5},
    },
    results = {{type = "item", name = "conciliation-desk", amount = 1}},
    energy_required = 16
  }, "gleba"),
  surface_limited({
    type = "recipe",
    name = "digital-services-bureau",
    subgroup = "admin-buildings",
    enabled = false,
    ingredients = {
      {type = "item", name = "office-desk", amount = 1},
      {type = "item", name = "relay-clerk", amount = 1},
      {type = "item", name = "processing-unit", amount = 15},
      {type = "item", name = "holmium-plate", amount = 20},
      {type = "item", name = "advanced-circuit", amount = 20},
      {type = "item", name = "construction-work-order", amount = 1},
    },
    results = {{type = "item", name = "digital-services-bureau", amount = 1}},
    energy_required = 20
  }, "fulgora"),
  not_in_space({
    type = "recipe",
    name = "orbital-infrastructure-permit",
    category = "bureaucracy-registration",
    enabled = false,
    ingredients = {
      {type = "item", name = "blank-directive", amount = 1},
      {type = "item", name = "transit-authorization", amount = 1},
      {type = "item", name = "low-density-structure", amount = 1},
      {type = "item", name = "processing-unit", amount = 1},
    },
    results = {{type = "item", name = "orbital-infrastructure-permit", amount = 1}},
    energy_required = 8
  }),
  {
    type = "recipe",
    name = "trajectory-compliance-array",
    subgroup = "admin-space-compliance",
    enabled = false,
    ingredients = {
      {type = "item", name = "radar", amount = 2},
      {type = "item", name = "processing-unit", amount = 10},
      {type = "item", name = "low-density-structure", amount = 10},
      {type = "item", name = "refined-concrete", amount = 20},
      {type = "item", name = "orbital-infrastructure-permit", amount = 1},
    },
    results = {{type = "item", name = "trajectory-compliance-array", amount = 1}},
    energy_required = 20
  },
  {
    type = "recipe",
    name = "senior-trajectory-compliance-array",
    subgroup = "admin-space-compliance",
    enabled = false,
    ingredients = {
      {type = "item", name = "trajectory-compliance-array", amount = 1},
      {type = "item", name = "tungsten-carbide", amount = 10},
      {type = "item", name = "carbon-fiber", amount = 10},
      {type = "item", name = "supercapacitor", amount = 10},
      {type = "item", name = "orbital-infrastructure-permit", amount = 1},
    },
    results = {{type = "item", name = "senior-trajectory-compliance-array", amount = 1}},
    energy_required = 30
  },
  {
    type = "recipe",
    name = "executive-trajectory-compliance-array",
    subgroup = "admin-space-compliance",
    enabled = false,
    ingredients = {
      {type = "item", name = "senior-trajectory-compliance-array", amount = 1},
      {type = "item", name = "quantum-processor", amount = 50},
      {type = "item", name = "lithium-plate", amount = 20},
      {type = "item", name = "tungsten-plate", amount = 20},
      {type = "item", name = "carbon-fiber", amount = 20},
      {type = "item", name = "orbital-infrastructure-permit", amount = 1},
    },
    results = {{type = "item", name = "executive-trajectory-compliance-array", amount = 1}},
    energy_required = 60
  },
  {
    type = "recipe",
    name = "orbital-employment-cannon",
    subgroup = "admin-space-orbital",
    enabled = false,
    ingredients = {
      {type = "item", name = "radar", amount = 4},
      {type = "item", name = "processing-unit", amount = 20},
      {type = "item", name = "low-density-structure", amount = 25},
      {type = "item", name = "electric-engine-unit", amount = 20},
      {type = "item", name = "steel-plate", amount = 25},
      {type = "item", name = "orbital-infrastructure-permit", amount = 1},
    },
    results = {{type = "item", name = "orbital-employment-cannon", amount = 1}},
    energy_required = 45
  },
  {
    type = "recipe",
    name = "administrative-space-station",
    subgroup = "admin-space-buildings",
    enabled = false,
    ingredients = {
      {type = "item", name = "office-desk", amount = 1},
      {type = "item", name = "astronaut", amount = 1},
      {type = "item", name = "processing-unit", amount = 12},
      {type = "item", name = "low-density-structure", amount = 12},
      {type = "item", name = "refined-concrete", amount = 20},
      {type = "item", name = "orbital-infrastructure-permit", amount = 1},
    },
    results = {{type = "item", name = "administrative-space-station", amount = 1}},
    energy_required = 20,
    surface_conditions = {
      {
        property = "pressure",
        min = 0,
        max = 0,
      },
    },
  },
  vacuum_only({
    type = "recipe",
    name = "orbital-paper-production",
    category = "orbital-bureaucracy",
    subgroup = "admin-paper-supplies",
    enabled = false,
    ingredients = {
      {type = "item", name = "carbon", amount = 1},
      {type = "fluid", name = "water", amount = 20},
    },
    results = {{type = "item", name = "paper", amount = 5}},
    energy_required = 2,
    allow_productivity = true,
  }),
  vacuum_only({
    type = "recipe",
    name = "orbital-ink-production",
    category = "orbital-bureaucracy",
    subgroup = "admin-paper-supplies",
    enabled = false,
    ingredients = {
      {type = "item", name = "carbon", amount = 1},
      {type = "item", name = "iron-ore", amount = 1},
      {type = "fluid", name = "water", amount = 10},
    },
    results = {{type = "item", name = "ink", amount = 4}},
    energy_required = 2,
    allow_productivity = true,
  }),
  vacuum_only({
    type = "recipe",
    name = "orbital-operations-form",
    category = "orbital-bureaucracy",
    enabled = false,
    ingredients = {
      {type = "item", name = "paper", amount = 4},
      {type = "item", name = "ink", amount = 1},
    },
    results = {{type = "item", name = "orbital-operations-form", amount = 10}},
    energy_required = 3,
    allow_productivity = true,
  }),
  vacuum_only({
    type = "recipe",
    name = "thermal-process-license-orbital",
    category = "orbital-bureaucracy",
    enabled = false,
    localised_name = {"item-name.thermal-process-license"},
    ingredients = {
      {type = "item", name = "orbital-operations-form", amount = 1},
      {type = "item", name = "calcite", amount = 2},
      {type = "item", name = "sulfur", amount = 1},
    },
    results = {
      {type = "item", name = "thermal-process-license", amount = 2},
    },
    energy_required = 6,
  }),
  vacuum_only({
    type = "recipe",
    name = "calcite-reagent-waiver-orbital",
    category = "orbital-bureaucracy",
    enabled = false,
    localised_name = {"item-name.calcite-reagent-waiver"},
    ingredients = {
      {type = "item", name = "orbital-operations-form", amount = 1},
      {type = "item", name = "calcite", amount = 2},
      {type = "item", name = "iron-ore", amount = 2},
    },
    results = {
      {type = "item", name = "calcite-reagent-waiver", amount = 2},
    },
    energy_required = 2,
  }),
  vacuum_only({
    type = "recipe",
    name = "offworld-metallurgy-charter-orbital",
    category = "orbital-bureaucracy",
    enabled = false,
    localised_name = {"item-name.offworld-metallurgy-charter"},
    ingredients = {
      {type = "item", name = "thermal-process-license", amount = 1},
      {type = "item", name = "calcite-reagent-waiver", amount = 1},
      {type = "item", name = "orbital-operations-form", amount = 1},
      {type = "item", name = "copper-ore", amount = 1},
    },
    results = {
      {type = "item", name = "offworld-metallurgy-charter", amount = 1},
    },
    energy_required = 6,
  }),
  vacuum_only({
    type = "recipe",
    name = "orbital-deviation-order",
    category = "orbital-bureaucracy",
    enabled = false,
    ingredients = {
      {type = "item", name = "orbital-operations-form", amount = 1},
      {type = "item", name = "iron-ore", amount = 1},
    },
    results = {
      {type = "item", name = "orbital-deviation-order", amount = 8},
    },
    energy_required = 6,
  }),
  vacuum_only({
    type = "recipe",
    name = "asteroid-processing-docket",
    category = "orbital-bureaucracy",
    enabled = false,
    ingredients = {
      {type = "item", name = "orbital-operations-form", amount = 1},
      {type = "item", name = "paper", amount = 2},
      {type = "item", name = "ink", amount = 1},
    },
    results = {
      {type = "item", name = "asteroid-processing-docket", amount = 4},
    },
    energy_required = 4,
  }),
  vacuum_only({
    type = "recipe",
    name = "orbital-archival-paper-production",
    category = "orbital-bureaucracy",
    subgroup = "admin-paper-supplies",
    enabled = false,
    ingredients = {
      {type = "item", name = "carbon", amount = 4},
      {type = "item", name = "calcite", amount = 2},
      {type = "fluid", name = "water", amount = 40},
    },
    results = {{type = "item", name = "paper", amount = 30}},
    energy_required = 5,
    allow_productivity = true,
  }),
  vacuum_only({
    type = "recipe",
    name = "orbital-secure-ink-production",
    category = "orbital-bureaucracy",
    subgroup = "admin-paper-supplies",
    enabled = false,
    ingredients = {
      {type = "item", name = "carbon", amount = 2},
      {type = "item", name = "copper-ore", amount = 1},
      {type = "item", name = "sulfur", amount = 1},
      {type = "fluid", name = "water", amount = 10},
    },
    results = {{type = "item", name = "ink", amount = 12}},
    energy_required = 4,
    allow_productivity = true,
  }),
  vacuum_only({
    type = "recipe",
    name = "orbital-operations-form-copying",
    category = "orbital-printing",
    enabled = false,
    ingredients = {
      {type = "item", name = "orbital-operations-form", amount = 1},
      {type = "item", name = "paper", amount = 5},
      {type = "item", name = "ink", amount = 1},
      {type = "item", name = "copper-ore", amount = 1},
    },
    results = {{type = "item", name = "orbital-operations-form", amount = 16}},
    main_product = "orbital-operations-form",
    energy_required = 6,
    allow_productivity = true,
  }),
  vacuum_only({
    type = "recipe",
    name = "asteroid-processing-docket-copying",
    category = "orbital-printing",
    enabled = false,
    ingredients = {
      {type = "item", name = "asteroid-processing-docket", amount = 1},
      {type = "item", name = "paper", amount = 5},
      {type = "item", name = "ink", amount = 1},
      {type = "item", name = "calcite", amount = 1},
    },
    results = {{type = "item", name = "asteroid-processing-docket", amount = 10}},
    main_product = "asteroid-processing-docket",
    energy_required = 6,
    allow_productivity = true,
  }),
  vacuum_only({
    type = "recipe",
    name = "priority-orbital-deviation-order",
    category = "orbital-printing",
    enabled = false,
    ingredients = {
      {type = "item", name = "orbital-deviation-order", amount = 4},
      {type = "item", name = "copper-ore", amount = 2},
      {type = "item", name = "sulfur", amount = 1},
      {type = "item", name = "calcite", amount = 1},
    },
    results = {{type = "item", name = "priority-orbital-deviation-order", amount = 4}},
    energy_required = 8,
    allow_productivity = true,
  }),
  not_on_planet({
    type = "recipe",
    name = "liquid-black-ink",
    category = "bureaucracy-registration",
    enabled = false,
    ingredients = {
      {type = "item", name = "ink", amount = 1},
    },
    results = {
      {type = "fluid", name = "liquid-black-ink", amount = 40},
    },
    energy_required = 2,
  }, "aquilo"),
  surface_limited({
    type = "recipe",
    name = "amber-sap-nonsense-seeding",
    category = bureaucracy_categories.bootstrap_for_planet("gleba"),
    enabled = false,
    localised_name = {"item-name.bullshit-ore"},
    ingredients = {
      {type = "fluid", name = "amber-sap", amount = 20},
      {type = "item", name = "nutrients", amount = 1},
    },
    results = {
      {type = "item", name = "bullshit-ore", amount = 8},
    },
    energy_required = 1,
  }, "gleba"),
  surface_limited({
    type = "recipe",
    name = "ink-production-gleba",
    category = bureaucracy_categories.bootstrap_for_planet("gleba"),
    enabled = false,
    localised_name = {"recipe-name.ink-production"},
    ingredients = {
      {type = "fluid", name = "amber-sap", amount = 10},
      {type = "item", name = "nutrients", amount = 1},
    },
    results = {
      {type = "item", name = "ink", amount = 3},
    },
    energy_required = 2,
  }, "gleba"),
  surface_limited({
    type = "recipe",
    name = "carbon-offset-certificate-basic-gleba",
    category = bureaucracy_categories.bootstrap_for_planet("gleba"),
    enabled = false,
    localised_name = {"recipe-name.carbon-offset-certificate-basic"},
    ingredients = {
      {type = "item", name = "blank-form", amount = 1},
      {type = "fluid", name = "amber-sap", amount = 30},
      {type = "item", name = "nutrients", amount = 2},
    },
    results = {
      {type = "item", name = "carbon-offset-certificate-basic", amount = 1},
    },
    energy_required = 5,
  }, "gleba"),
  surface_limited({
    type = "recipe",
    name = "yellow-ink-production",
    category = bureaucracy_categories.registration_for_planet("gleba"),
    enabled = false,
    localised_name = {"fluid-name.yellow-ink"},
    ingredients = {
      {type = "fluid", name = "amber-sap", amount = 30},
      {type = "item", name = "nutrients", amount = 2},
    },
    results = {
      {type = "fluid", name = "yellow-ink", amount = 40},
    },
    energy_required = 1,
  }, "gleba"),
  surface_limited({
    type = "recipe",
    name = "hostile-spore-culture-production",
    category = "organic-or-chemistry",
    enabled = false,
    localised_name = {"fluid-name.hostile-spore-culture"},
    ingredients = {
      {type = "fluid", name = "amber-sap", amount = 40},
      {type = "item", name = "nutrients", amount = 4},
      {type = "item", name = "spoilage", amount = 10},
    },
    results = {
      {type = "fluid", name = "hostile-spore-culture", amount = 80},
    },
    energy_required = 2,
  }, "gleba"),
  {
    type = "recipe",
    name = "workforce-lure-spores-production",
    category = "organic",
    enabled = false,
    localised_name = {"fluid-name.workforce-lure-spores"},
    ingredients = {
      {type = "fluid", name = "hostile-spore-culture", amount = 20},
      {type = "item", name = "job-offer", amount = 1},
      {type = "item", name = "credentials", amount = 1},
    },
    results = {
      {type = "fluid", name = "workforce-lure-spores", amount = 40},
    },
    energy_required = 1,
  },
  {
    type = "recipe",
    name = "tourism-lure-spores-production",
    category = "organic",
    enabled = false,
    localised_name = {"fluid-name.tourism-lure-spores"},
    ingredients = {
      {type = "fluid", name = "hostile-spore-culture", amount = 20},
      {type = "item", name = "cyan-yellow-form", amount = 1},
      {type = "item", name = "transit-authorization", amount = 1},
    },
    results = {
      {type = "fluid", name = "tourism-lure-spores", amount = 40},
    },
    energy_required = 1,
  },
  {
    type = "recipe",
    name = "oviposition-lure-spores-production",
    category = "organic-or-chemistry",
    enabled = false,
    localised_name = {"fluid-name.oviposition-lure-spores"},
    ingredients = {
      {type = "fluid", name = "hostile-spore-culture", amount = 20},
      {type = "item", name = "nutrients", amount = 8},
      {type = "item", name = "symbiosis-record", amount = 1},
    },
    results = {
      {type = "fluid", name = "oviposition-lure-spores", amount = 40},
    },
    energy_required = 1,
  },
  surface_limited({
    type = "recipe",
    name = "mycelial-form-stock",
    category = "printing-chromatic",
    enabled = false,
    ingredients = {
      {type = "item", name = "paper", amount = 2},
      {type = "fluid", name = "yellow-ink", amount = 10},
    },
    results = {
      {type = "item", name = "mycelial-form-stock", amount = 2},
    },
    energy_required = 3,
  }, "gleba"),
  surface_limited({
    type = "recipe",
    name = "blank-yellow-form-production",
    category = "printing-chromatic",
    enabled = false,
    localised_name = {"item-name.blank-yellow-form"},
    ingredients = {
      {type = "item", name = "mycelial-form-stock", amount = 1},
      {type = "fluid", name = "yellow-ink", amount = 5},
    },
    results = {
      {type = "item", name = "blank-yellow-form", amount = 2},
    },
    energy_required = 2,
  }, "gleba"),
  surface_limited({
    type = "recipe",
    name = "symbiosis-record",
    category = "bureaucracy-conciliation",
    enabled = false,
    ingredients = {
      {type = "item", name = "blank-yellow-form", amount = 1},
      {type = "item", name = "dubious-data", amount = 2},
      {type = "item", name = "nutrients", amount = 2},
    },
    results = {
      {type = "item", name = "symbiosis-record", amount = 1},
    },
    energy_required = 4,
  }, "gleba"),
  surface_limited({
    type = "recipe",
    name = "conciliation-order",
    category = "bureaucracy-conciliation",
    enabled = false,
    ingredients = {
      {type = "item", name = "blank-yellow-form", amount = 1},
      {type = "item", name = "symbiosis-record", amount = 1},
      {type = "fluid", name = "liquid-coffee", amount = 25},
    },
    results = {
      {type = "item", name = "conciliation-order", amount = 1},
    },
    energy_required = 5,
  }, "gleba"),
  surface_limited({
    type = "recipe",
    name = "charged-toner",
    category = bureaucracy_categories.bootstrap_for_planet("fulgora"),
    enabled = false,
    ingredients = {
      {type = "item", name = "scrap", amount = 4},
    },
    results = {
      {type = "item", name = "charged-toner", amount = 2},
    },
    energy_required = 4,
  }, "fulgora"),
  surface_limited({
    type = "recipe",
    name = "archive-rubble-recovery",
    category = bureaucracy_categories.bootstrap_for_planet("fulgora"),
    enabled = false,
    localised_name = {"item-name.redundant-rubble"},
    ingredients = {
      {type = "item", name = "scrap", amount = 4},
    },
    results = {
      {type = "item", name = "redundant-rubble", amount = 6},
    },
    energy_required = 3,
  }, "fulgora"),
  surface_limited({
    type = "recipe",
    name = "archive-documentation-recovery",
    category = bureaucracy_categories.bootstrap_for_planet("fulgora"),
    enabled = false,
    localised_name = {"item-name.useless-documentation"},
    ingredients = {
      {type = "item", name = "scrap", amount = 4},
      {type = "item", name = "charged-toner", amount = 1},
    },
    results = {
      {type = "item", name = "useless-documentation", amount = 4},
      {type = "item", name = "paper", amount = 2},
    },
    main_product = "useless-documentation",
    energy_required = 4,
  }, "fulgora"),
  surface_limited({
    type = "recipe",
    name = "magenta-ink-production",
    category = bureaucracy_categories.registration_for_planet("fulgora"),
    enabled = false,
    localised_name = {"fluid-name.magenta-ink"},
    ingredients = {
      {type = "item", name = "charged-toner", amount = 2},
      {type = "item", name = "useless-documentation", amount = 1},
    },
    results = {
      {type = "fluid", name = "magenta-ink", amount = 40},
    },
    energy_required = 4,
  }, "fulgora"),
  surface_limited({
    type = "recipe",
    name = "signal-form-stock",
    category = "printing-chromatic",
    enabled = false,
    ingredients = {
      {type = "item", name = "paper", amount = 2},
      {type = "fluid", name = "magenta-ink", amount = 10},
    },
    results = {
      {type = "item", name = "signal-form-stock", amount = 2},
    },
    energy_required = 3,
  }, "fulgora"),
  surface_limited({
    type = "recipe",
    name = "blank-magenta-form-production",
    category = "printing-chromatic",
    enabled = false,
    localised_name = {"item-name.blank-magenta-form"},
    ingredients = {
      {type = "item", name = "signal-form-stock", amount = 1},
      {type = "fluid", name = "magenta-ink", amount = 5},
    },
    results = {
      {type = "item", name = "blank-magenta-form", amount = 2},
    },
    energy_required = 2,
  }, "fulgora"),
  surface_limited({
    type = "recipe",
    name = "archive-recovery-permit",
    category = bureaucracy_categories.registration_for_planet("fulgora"),
    enabled = false,
    ingredients = {
      {type = "item", name = "blank-magenta-form", amount = 1},
      {type = "item", name = "charged-toner", amount = 1},
      {type = "item", name = "useless-documentation", amount = 2},
    },
    results = {
      {type = "item", name = "archive-recovery-permit", amount = 1},
    },
    energy_required = 4,
  }, "fulgora"),
  surface_limited({
    type = "recipe",
    name = "digital-processing-certificate",
    category = bureaucracy_categories.registration_for_planet("fulgora"),
    enabled = false,
    ingredients = {
      {type = "item", name = "blank-magenta-form", amount = 1},
      {type = "item", name = "data", amount = 1},
      {type = "item", name = "processing-unit", amount = 1},
    },
    results = {
      {type = "item", name = "digital-processing-certificate", amount = 1},
    },
    energy_required = 5,
  }, "fulgora"),
  surface_limited({
    type = "recipe",
    name = "electromagnetic-operating-license",
    category = bureaucracy_categories.registration_for_planet("fulgora"),
    enabled = false,
    ingredients = {
      {type = "item", name = "blank-magenta-form", amount = 1},
      {type = "item", name = "digital-processing-certificate", amount = 1},
      {type = "item", name = "advanced-circuit", amount = 2},
    },
    results = {
      {type = "item", name = "electromagnetic-operating-license", amount = 1},
    },
    energy_required = 6,
  }, "fulgora"),
  surface_limited({
    type = "recipe",
    name = "data-recovery-order",
    category = bureaucracy_categories.registration_for_planet("fulgora"),
    enabled = false,
    ingredients = {
      {type = "item", name = "blank-magenta-form", amount = 1},
      {type = "item", name = "archive-recovery-permit", amount = 1},
      {type = "item", name = "data", amount = 1},
    },
    results = {
      {type = "item", name = "data-recovery-order", amount = 1},
    },
    energy_required = 5,
  }, "fulgora"),
  surface_limited({
    type = "recipe",
    name = "laser-printer",
    subgroup = "admin-buildings",
    enabled = false,
    ingredients = {
      {type = "item", name = "chromatic-printer", amount = 1},
      {type = "item", name = "cryoprint-technician", amount = 1},
      {type = "item", name = "processing-unit", amount = 15},
      {type = "item", name = "lithium-plate", amount = 20},
      {type = "item", name = "superconductor", amount = 10},
      {type = "item", name = "refined-concrete", amount = 20},
      {type = "item", name = "construction-work-order", amount = 1},
    },
    results = {{type = "item", name = "laser-printer", amount = 1}},
    energy_required = 20,
  }, "aquilo"),
  surface_limited({
    type = "recipe",
    name = "transfer-emulsion-production",
    category = "chemistry-or-cryogenics",
    enabled = false,
    localised_name = {"item-name.transfer-emulsion"},
    ingredients = {
      {type = "fluid", name = "ammonia", amount = 40},
      {type = "item", name = "plastic-bar", amount = 2},
      {type = "item", name = "ice", amount = 2},
    },
    results = {
      {type = "item", name = "transfer-emulsion", amount = 2},
    },
    energy_required = 4,
  }, "aquilo"),
  surface_limited({
    type = "recipe",
    name = "thermal-transfer-sheet-production",
    category = "printing-advanced",
    enabled = false,
    localised_name = {"item-name.thermal-transfer-sheet"},
    ingredients = {
      {type = "item", name = "paper", amount = 2},
      {type = "item", name = "transfer-emulsion", amount = 1},
      {type = "item", name = "plastic-bar", amount = 1},
    },
    results = {
      {type = "item", name = "thermal-transfer-sheet", amount = 2},
    },
    energy_required = 3,
  }, "aquilo"),
  surface_limited({
    type = "recipe",
    name = "composite-chroma-ribbon-production",
    category = "printing-multicolor",
    enabled = false,
    localised_name = {"item-name.composite-chroma-ribbon"},
    ingredients = {
      {type = "item", name = "blank-cyan-form", amount = 1},
      {type = "item", name = "blank-yellow-form", amount = 1},
      {type = "item", name = "blank-magenta-form", amount = 1},
      {type = "item", name = "transfer-emulsion", amount = 1},
    },
    results = {
      {type = "item", name = "composite-chroma-ribbon", amount = 10},
    },
    energy_required = 5,
  }, "aquilo"),
  {
    type = "recipe",
    name = "cyan-yellow-form-production",
    category = "printing-multicolor",
    enabled = false,
    localised_name = {"item-name.cyan-yellow-form"},
    ingredients = {
      {type = "item", name = "paper", amount = 2},
      {type = "fluid", name = "cyan-ink", amount = 10},
      {type = "fluid", name = "yellow-ink", amount = 10},
    },
    results = {
      {type = "item", name = "cyan-yellow-form", amount = 2},
    },
    energy_required = 3,
  },
  {
    type = "recipe",
    name = "cyan-magenta-form-production",
    category = "printing-multicolor",
    enabled = false,
    localised_name = {"item-name.cyan-magenta-form"},
    ingredients = {
      {type = "item", name = "paper", amount = 2},
      {type = "fluid", name = "cyan-ink", amount = 10},
      {type = "fluid", name = "magenta-ink", amount = 10},
    },
    results = {
      {type = "item", name = "cyan-magenta-form", amount = 2},
    },
    energy_required = 3,
  },
  {
    type = "recipe",
    name = "yellow-magenta-form-production",
    category = "printing-multicolor",
    enabled = false,
    localised_name = {"item-name.yellow-magenta-form"},
    ingredients = {
      {type = "item", name = "paper", amount = 2},
      {type = "fluid", name = "yellow-ink", amount = 10},
      {type = "fluid", name = "magenta-ink", amount = 10},
    },
    results = {
      {type = "item", name = "yellow-magenta-form", amount = 2},
    },
    energy_required = 3,
  },
  surface_limited({
    type = "recipe",
    name = "trichromatic-permit-production",
    category = "printing-multicolor",
    enabled = false,
    localised_name = {"item-name.trichromatic-permit"},
    ingredients = {
      {type = "item", name = "blank-cyan-form", amount = 1},
      {type = "item", name = "blank-yellow-form", amount = 1},
      {type = "item", name = "blank-magenta-form", amount = 1},
      {type = "item", name = "composite-chroma-ribbon", amount = 1},
      {type = "item", name = "thermal-transfer-sheet", amount = 1},
    },
    results = {
      {type = "item", name = "trichromatic-permit", amount = 1},
    },
    energy_required = 5,
  }, "aquilo"),
  surface_limited({
    type = "recipe",
    name = "unified-operations-charter-production",
    category = "printing-multicolor",
    enabled = false,
    localised_name = {"item-name.unified-operations-charter"},
    ingredients = {
      {type = "item", name = "trichromatic-permit", amount = 1},
      {type = "item", name = "offworld-metallurgy-charter", amount = 1},
      {type = "item", name = "conciliation-order", amount = 1},
      {type = "item", name = "electromagnetic-operating-license", amount = 1},
    },
    results = {
      {type = "item", name = "unified-operations-charter", amount = 1},
    },
    energy_required = 6,
  }, "aquilo"),
  surface_limited({
    type = "recipe",
    name = "cryogenic-operations-license-production",
    category = "printing-multicolor",
    enabled = false,
    localised_name = {"item-name.cryogenic-operations-license"},
    ingredients = {
      {type = "item", name = "cyan-yellow-form", amount = 1},
      {type = "item", name = "transfer-emulsion", amount = 1},
      {type = "item", name = "thermal-transfer-sheet", amount = 1},
      {type = "item", name = "lithium-plate", amount = 2},
    },
    results = {
      {type = "item", name = "cryogenic-operations-license", amount = 1},
    },
    energy_required = 5,
  }, "aquilo"),
  {
    type = "recipe",
    name = "promethium-research-charter-production",
    category = "orbital-bureaucracy",
    enabled = false,
    localised_name = {"item-name.promethium-research-charter"},
    ingredients = {
      {type = "item", name = "unified-operations-charter", amount = 1},
      {type = "item", name = "cryogenic-operations-license", amount = 1},
      {type = "item", name = "hardened-data-vault", amount = 1},
      {type = "item", name = "asteroid-processing-docket", amount = 1},
    },
    results = {
      {type = "item", name = "promethium-research-charter", amount = 1},
    },
    energy_required = 8,
    surface_conditions = {
      {
        property = "pressure",
        min = 0,
        max = 0,
      },
    },
  },
  surface_limited({
    type = "recipe",
    name = "public-transportation-contract-production",
    category = "printing-multicolor",
    enabled = false,
    localised_name = {"item-name.public-transportation-contract"},
    ingredients = {
      {type = "item", name = "cyan-yellow-form", amount = 1},
      {type = "item", name = "transit-authorization", amount = 1},
    },
    results = {
      {type = "item", name = "public-transportation-contract", amount = 1},
    },
    energy_required = 4,
  }, "nauvis"),
  surface_limited({
    type = "recipe",
    name = "public-train-stop-production",
    subgroup = "admin-infrastructure",
    category = "bureaucracy-registration",
    enabled = false,
    localised_name = {"entity-name.public-train-stop"},
    ingredients = {
      {type = "item", name = "public-transportation-contract", amount = 1},
      {type = "item", name = "steel-plate", amount = 5},
      {type = "item", name = "electronic-circuit", amount = 5},
    },
    results = {
      {type = "item", name = "public-train-stop", amount = 1},
    },
    energy_required = 5,
  }, "nauvis"),
  {
    type = "recipe",
    name = "anecdotal-data-reprocessing",
    category = "bureaucracy-registration",
    enabled = false,
    ingredients = {
      {type = "item", name = "spoilage", amount = 4},
      {type = "item", name = "yellow-magenta-form", amount = 1},
    },
    results = {
      {type = "item", name = "dubious-data", amount = 6},
    },
    energy_required = 2,
  },
  surface_limited({
    type = "recipe",
    name = "paper-production-vulcanus",
    enabled = false,
    localised_name = {"recipe-name.paper-production"},
    ingredients = {
      {type = "item", name = "carbon", amount = 1},
      {type = "item", name = "calcite", amount = 1},
    },
    results = {
      {type = "item", name = "paper", amount = 5},
    },
    energy_required = 1,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "carbon-offset-certificate-basic-vulcanus",
    enabled = false,
    localised_name = {"recipe-name.carbon-offset-certificate-basic"},
    ingredients = {
      {type = "item", name = "blank-form", amount = 1},
      {type = "item", name = "calcite", amount = 1},
      {type = "item", name = "coal", amount = 1},
    },
    results = {
      {type = "item", name = "carbon-offset-certificate-basic", amount = 1},
    },
    energy_required = 3,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "redundant-rubble-recovery-vulcanus",
    category = "smelting-basic",
    enabled = false,
    localised_name = {"item-name.redundant-rubble"},
    ingredients = {
      {type = "item", name = "carbon-offset-certificate-basic", amount = 1},
      {type = "item", name = "calcite", amount = 5},
    },
    results = {
      {type = "item", name = "redundant-rubble", amount = 5},
    },
    energy_required = 16,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "dubious-data-analysis-vulcanus",
    category = bureaucracy_categories.registration_for_planet("vulcanus"),
    enabled = false,
    ingredients = {
      {type = "item", name = "verdigris-crust", amount = 2},
      {type = "item", name = "paper", amount = 1},
    },
    results = {
      {type = "item", name = "dubious-data", amount = 4},
    },
    energy_required = 5,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "cyan-slurry-production",
    category = "propaganda-distillery",
    enabled = false,
    ingredients = {
      {type = "item", name = "verdigris-crust", amount = 4},
    },
    results = {
      {type = "fluid", name = "cyan-slurry", amount = 80},
    },
    energy_required = 4,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "cyan-ink-production",
    category = "propaganda-distillery",
    enabled = false,
    ingredients = {
      {type = "fluid", name = "cyan-slurry", amount = 40},
      {type = "fluid", name = "sulfuric-acid", amount = 20},
    },
    results = {
      {type = "fluid", name = "cyan-ink", amount = 40},
    },
    energy_required = 4,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "heatproof-form-stock",
    category = "printing-chromatic",
    enabled = false,
    ingredients = {
      {type = "item", name = "paper", amount = 2},
      {type = "fluid", name = "cyan-ink", amount = 10},
    },
    results = {
      {type = "item", name = "heatproof-form-stock", amount = 2},
    },
    energy_required = 3,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "blank-cyan-form-production",
    category = "printing-chromatic",
    enabled = false,
    ingredients = {
      {type = "item", name = "heatproof-form-stock", amount = 1},
      {type = "fluid", name = "cyan-ink", amount = 5},
    },
    results = {
      {type = "item", name = "blank-cyan-form", amount = 2},
    },
    energy_required = 2,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "permit-draft",
    category = "printing-chromatic",
    enabled = false,
    ingredients = {
      {type = "item", name = "blank-cyan-form", amount = 1},
      {type = "fluid", name = "cyan-ink", amount = 5},
    },
    results = {
      {type = "item", name = "permit-draft", amount = 1},
    },
    energy_required = 2,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "inspection-docket",
    category = "printing-chromatic",
    enabled = false,
    ingredients = {
      {type = "item", name = "blank-cyan-form", amount = 1},
      {type = "item", name = "dubious-data", amount = 1},
      {type = "fluid", name = "cyan-ink", amount = 5},
    },
    results = {
      {type = "item", name = "inspection-docket", amount = 1},
    },
    energy_required = 3,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "liquid-stimulant-production",
    category = "chemistry",
    enabled = false,
    ingredients = {
      {type = "fluid", name = "cyan-slurry", amount = 30},
      {type = "fluid", name = "sulfuric-acid", amount = 20},
    },
    results = {
      {type = "fluid", name = "liquid-stimulant", amount = 60},
    },
    energy_required = 4,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "liquid-coffee-vulcanus",
    category = "chemistry",
    enabled = false,
    ingredients = {
      {type = "fluid", name = "liquid-stimulant", amount = 40},
      {type = "item", name = "carbon", amount = 1},
    },
    results = {
      {type = "fluid", name = "liquid-coffee", amount = 50},
    },
    energy_required = 3,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "plastic-bar-vulcanus",
    category = "chemistry",
    enabled = false,
    localised_name = {"item-name.plastic-bar"},
    ingredients = {
      {type = "item", name = "carbon", amount = 2},
      {type = "fluid", name = "sulfuric-acid", amount = 20},
    },
    results = {
      {type = "item", name = "plastic-bar", amount = 2},
    },
    energy_required = 3,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "molten-promises-production",
    category = "propaganda-distillery",
    enabled = false,
    ingredients = {
      {type = "fluid", name = "lava", amount = 100},
      {type = "fluid", name = "cyan-slurry", amount = 20},
    },
    results = {
      {type = "fluid", name = "molten-promises", amount = 120},
    },
    energy_required = 4,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "refined-nonsense-production-vulcanus",
    category = "propaganda-distillery",
    enabled = false,
    localised_name = {"recipe-name.refined-nonsense-production"},
    ingredients = {
      {type = "item", name = "calcite", amount = 3},
      {type = "fluid", name = "lie", amount = 100},
    },
    results = {
      {type = "item", name = "refined-nonsense", amount = 1},
    },
    energy_required = 8,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "embossed-seal",
    category = "bureaucracy-certification",
    enabled = false,
    ingredients = {
      {type = "fluid", name = "cyan-slurry", amount = 20},
      {type = "item", name = "useless-documentation", amount = 1},
    },
    results = {
      {type = "item", name = "embossed-seal", amount = 1},
    },
    energy_required = 5,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "industrial-charter",
    category = "bureaucracy-certification",
    enabled = false,
    ingredients = {
      {type = "item", name = "permit-draft", amount = 1},
      {type = "item", name = "inspection-docket", amount = 1},
      {type = "item", name = "embossed-seal", amount = 1},
    },
    results = {
      {type = "item", name = "industrial-charter", amount = 1},
    },
    energy_required = 8,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "territorial-resettlement-order",
    category = "bureaucracy-certification",
    enabled = false,
    ingredients = {
      {type = "item", name = "industrial-charter", amount = 1},
      {type = "item", name = "construction-permit", amount = 1},
      {type = "item", name = "management-approval-verbal", amount = 1},
      {type = "item", name = "form-27b-6", amount = 1},
      {type = "item", name = "embossed-seal", amount = 1},
      {type = "fluid", name = "lie", amount = 60},
    },
    results = {
      {type = "item", name = "territorial-resettlement-order", amount = 1},
    },
    energy_required = 8,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "thermal-process-license",
    category = "bureaucracy-certification",
    enabled = false,
    localised_name = {"item-name.thermal-process-license"},
    ingredients = {
      {type = "item", name = "blank-cyan-form", amount = 1},
      {type = "fluid", name = "lie", amount = 40},
      {type = "item", name = "embossed-seal", amount = 1},
    },
    results = {
      {type = "item", name = "thermal-process-license", amount = 1},
    },
    energy_required = 6,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "calcite-reagent-waiver",
    category = "bureaucracy-certification",
    enabled = false,
    localised_name = {"item-name.calcite-reagent-waiver"},
    ingredients = {
      {type = "item", name = "blank-cyan-form", amount = 1},
      {type = "item", name = "dubious-data", amount = 1},
      {type = "item", name = "embossed-seal", amount = 1},
    },
    results = {
      {type = "item", name = "calcite-reagent-waiver", amount = 1},
    },
    energy_required = 5,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "offworld-metallurgy-charter",
    category = "bureaucracy-certification",
    enabled = false,
    localised_name = {"item-name.offworld-metallurgy-charter"},
    ingredients = {
      {type = "item", name = "thermal-process-license", amount = 1},
      {type = "item", name = "calcite-reagent-waiver", amount = 1},
      {type = "item", name = "industrial-charter", amount = 1},
    },
    results = {
      {type = "item", name = "offworld-metallurgy-charter", amount = 1},
    },
    energy_required = 6,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "vulcanus-lie-distillation",
    category = "bureaucracy-certification",
    enabled = false,
    icon = "__administratorio__/graphics/icons/lie.png",
    icon_size = 64,
    localised_name = {"fluid-name.lie"},
    ingredients = {
      {type = "fluid", name = "molten-promises", amount = 40},
      {type = "item", name = "inspection-docket", amount = 1},
    },
    results = {
      {type = "fluid", name = "lie", amount = 300},
      {type = "item", name = "dubious-data", amount = 1},
    },
    main_product = "lie",
    energy_required = 6,
  }, "vulcanus"),
})

-- Vanilla owns the availability of Foundry, Biochamber, and their native
-- processes. Do not rewrite those restrictions or clone their recipes merely
-- to make planet-native processes portable.

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

add_item_ingredient(data.raw.recipe and data.raw.recipe["foundry"], "tungsten-carbide", 4)

local SPACE_TOURISM_VARIANTS = {
  {
    spitter = "small-spitter",
    package_item = "small-spitter-tourism-package",
    tourist_item = "small-space-tourist",
    tourism_recipe = "small-spitter-space-tourism",
    bond_payout = 2,
    energy_required = 8,
  },
  {
    spitter = "medium-spitter",
    package_item = "medium-spitter-tourism-package",
    tourist_item = "medium-space-tourist",
    tourism_recipe = "medium-spitter-space-tourism",
    bond_payout = 4,
    energy_required = 10,
  },
  {
    spitter = "big-spitter",
    package_item = "big-spitter-tourism-package",
    tourist_item = "big-space-tourist",
    tourism_recipe = "big-spitter-space-tourism",
    bond_payout = 9,
    energy_required = 12,
  },
  {
    spitter = "behemoth-spitter",
    package_item = "behemoth-spitter-tourism-package",
    tourist_item = "behemoth-space-tourist",
    tourism_recipe = "behemoth-spitter-space-tourism",
    bond_payout = 24,
    energy_required = 16,
  },
}

local tourism_recipes = {}

for _, variant in ipairs(SPACE_TOURISM_VARIANTS) do
  tourism_recipes[#tourism_recipes + 1] = {
    type = "recipe",
    name = variant.tourism_recipe,
    category = "orbital-bureaucracy",
    enabled = false,
    localised_name = {"", "Monetize ", {"entity-name." .. variant.spitter}, " Space Tourism"},
    localised_description = {
      "",
      "Convert a captured ",
      {"entity-name." .. variant.spitter},
      " into orbital revenue and a paid-up tourist.",
    },
    ingredients = {
      {type = "item", name = variant.package_item, amount = 1},
      {type = "item", name = "orbital-operations-form", amount = 1},
    },
    results = {
      {type = "item", name = "treasury-bond", amount = variant.bond_payout},
      {type = "item", name = variant.tourist_item, amount = 1},
    },
    main_product = variant.tourist_item,
    energy_required = variant.energy_required,
    surface_conditions = {
      {
        property = "pressure",
        min = 0,
        max = 0,
      },
    },
  }

end

data:extend(tourism_recipes)

-- Briefed managers are single-use administrative catalysts. Every affected
-- process returns the same number of regular managers, who must attend another
-- meeting before they can obstruct useful work again.
local formation_manager_requirements = {
  ["clerical-trainee-formation"] = {"training"},
  ["astronaut-formation"] = {"training", "orbital"},
  ["licensed-notary-formation"] = {"training", "compliance"},
  ["conciliation-officer-formation"] = {"training", "liaison"},
  ["relay-clerk-formation"] = {"training", "liaison"},
  ["cryoprint-technician-formation"] = {"training", "compliance"},
}

local staffed_building_manager_requirements = {
  ["foundry"] = {"staffing"},
  ["biochamber"] = {"staffing"},
  ["electromagnetic-plant"] = {"staffing"},
  ["cryogenic-plant"] = {"staffing"},
  ["notary-office"] = {"staffing"},
  ["territorial-arbitration-post"] = {"staffing", "compliance"},
  ["capture-bureau"] = {"staffing", "liaison"},
  ["conciliation-desk"] = {"staffing"},
  ["digital-services-bureau"] = {"staffing"},
  ["laser-printer"] = {"staffing"},
  ["administrative-space-station"] = {"staffing", "orbital"},
}

for recipe_name, briefing_keys in pairs(formation_manager_requirements) do
  add_manager_requirements(recipe_name, briefing_keys)
end
for recipe_name, briefing_keys in pairs(staffed_building_manager_requirements) do
  add_manager_requirements(recipe_name, briefing_keys)
end
