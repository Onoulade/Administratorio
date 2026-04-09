local planets = require("prototypes.shared.space_age_planets")

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

local function surface_limited(recipe, planet_name)
  return planets.apply_planet_surface_conditions(recipe, planet_name)
end

local function not_on_planet(recipe, planet_name)
  local properties = planets.BASIC_PLANET_PROPERTIES[planet_name]
  if not recipe or not properties then return recipe end
  recipe.surface_conditions = {
    {
      property = "pressure",
      max = properties.pressure - 1,
    },
  }
  return recipe
end

local function clone_recipe(source_name, clone_name)
  local source = data.raw.recipe and data.raw.recipe[source_name]
  if not source then return nil end
  local clone
  if table.deepcopy then
    clone = table.deepcopy(source)
  else
    local function copy(value, seen)
      if type(value) ~= "table" then return value end
      if seen[value] then return seen[value] end
      local out = {}
      seen[value] = out
      for key, entry in pairs(value) do
        out[copy(key, seen)] = copy(entry, seen)
      end
      return setmetatable(out, getmetatable(value))
    end
    clone = copy(source, {})
  end
  clone.name = clone_name
  clone.localised_name = source.localised_name or {"recipe-name." .. source_name}
  clone.localised_description = source.localised_description or {"recipe-description." .. source_name}
  return clone
end

local function add_unlock_for_clone(source_name, clone_name)
  for _, technology in pairs(data.raw.technology or {}) do
    local effects = technology.effects or {}
    local should_unlock = false
    for _, effect in ipairs(effects) do
      if effect.type == "unlock-recipe" and effect.recipe == source_name then
        should_unlock = true
        break
      end
    end
    if should_unlock then
      local already_present = false
      for _, effect in ipairs(effects) do
        if effect.type == "unlock-recipe" and effect.recipe == clone_name then
          already_present = true
          break
        end
      end
      if not already_present then
        table.insert(effects, {type = "unlock-recipe", recipe = clone_name})
      end
      technology.effects = effects
    end
  end
end

data:extend({
  {
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
  },
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
      {type = "item", name = "dubious-data", amount = 4},
      {type = "item", name = "construction-work-order", amount = 1},
    },
    results = {{type = "item", name = "chromatic-printer", amount = 1}},
    energy_required = 12
  },
  {
    type = "recipe",
    name = "notary-office",
    enabled = false,
    ingredients = {
      {type = "item", name = "office-desk", amount = 2},
      {type = "item", name = "chromatic-printer", amount = 1},
      {type = "item", name = "licensed-notary", amount = 1},
      {type = "item", name = "steel-plate", amount = 20},
      {type = "item", name = "advanced-circuit", amount = 10},
      {type = "item", name = "permit-draft", amount = 1},
    },
    results = {{type = "item", name = "notary-office", amount = 1}},
    energy_required = 16
  },
  {
    type = "recipe",
    name = "trajectory-compliance-array",
    enabled = false,
    ingredients = {
      {type = "item", name = "radar", amount = 2},
      {type = "item", name = "processing-unit", amount = 10},
      {type = "item", name = "low-density-structure", amount = 10},
      {type = "item", name = "refined-concrete", amount = 20},
      {type = "item", name = "management-approval-written", amount = 1},
      {type = "item", name = "construction-work-order", amount = 1},
    },
    results = {{type = "item", name = "trajectory-compliance-array", amount = 1}},
    energy_required = 20
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
  {
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
      {type = "item", name = "calcite", amount = 1},
      {type = "item", name = "coal", amount = 1},
    },
    results = {
      {type = "item", name = "carbon-offset-certificate-basic", amount = 1},
    },
    energy_required = 1,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "admin-station-vulcanus",
    enabled = false,
    localised_name = {"item-name.admin-station"},
    localised_description = {"item-description.admin-station"},
    ingredients = {
      {type = "item", name = "iron-plate", amount = 20},
      {type = "item", name = "electronic-circuit", amount = 10},
      {type = "item", name = "dubious-data", amount = 1},
    },
    results = {
      {type = "item", name = "admin-station", amount = 1},
    },
    energy_required = 15,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "printer-t1-vulcanus",
    enabled = false,
    localised_name = {"item-name.printer-t1"},
    localised_description = {"item-description.printer-t1"},
    ingredients = {
      {type = "item", name = "iron-plate", amount = 10},
      {type = "item", name = "iron-gear-wheel", amount = 5},
      {type = "item", name = "electronic-circuit", amount = 3},
      {type = "item", name = "dubious-data", amount = 1},
    },
    results = {
      {type = "item", name = "printer-t1", amount = 1},
    },
    energy_required = 5,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "dubious-data-analysis-vulcanus",
    category = "bureaucracy-registration",
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
    name = "research-grant-approval-vulcanus",
    category = "bureaucracy-registration",
    enabled = false,
    localised_name = {"item-name.research-grant-approval"},
    ingredients = {
      {type = "item", name = "blank-form", amount = 1},
      {type = "item", name = "dubious-data", amount = 1},
      {type = "item", name = "verdigris-crust", amount = 1},
    },
    results = {
      {type = "item", name = "research-grant-approval", amount = 1},
    },
    energy_required = 2,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "administrative-science-pack-production-vulcanus",
    category = "bureaucracy-registration",
    enabled = false,
    hide_from_player_crafting = false,
    localised_name = {"recipe-name.administrative-science-pack-production"},
    ingredients = {
      {type = "item", name = "blank-form", amount = 2},
      {type = "item", name = "basic-excuse", amount = 1},
      {type = "item", name = "research-grant-approval", amount = 1},
      {type = "item", name = "dubious-data", amount = 1},
    },
    results = {
      {type = "item", name = "administrative-science-pack", amount = 1},
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
    name = "heatproof-paper-production",
    category = "chemistry",
    enabled = false,
    ingredients = {
      {type = "item", name = "carbon", amount = 1},
      {type = "item", name = "calcite", amount = 1},
      {type = "fluid", name = "sulfuric-acid", amount = 20},
    },
    results = {
      {type = "item", name = "paper", amount = 10},
    },
    energy_required = 4,
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
      {type = "fluid", name = "molten-promises", amount = 60},
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
    name = "good-excuse-vulcanus",
    category = "bureaucracy-certification",
    enabled = false,
    localised_name = {"item-name.good-excuse"},
    ingredients = {
      {type = "item", name = "inspection-docket", amount = 1},
      {type = "fluid", name = "lie", amount = 20},
      {type = "item", name = "dubious-data", amount = 1},
    },
    results = {
      {type = "item", name = "good-excuse", amount = 1},
    },
    energy_required = 4,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "safety-waiver-vulcanus",
    category = "bureaucracy-certification",
    enabled = false,
    localised_name = {"item-name.safety-waiver"},
    ingredients = {
      {type = "item", name = "blank-cyan-form", amount = 1},
      {type = "item", name = "basic-excuse", amount = 1},
      {type = "item", name = "embossed-seal", amount = 1},
    },
    results = {
      {type = "item", name = "safety-waiver", amount = 1},
    },
    energy_required = 5,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "construction-permit-vulcanus",
    category = "bureaucracy-certification",
    enabled = false,
    localised_name = {"item-name.construction-permit"},
    ingredients = {
      {type = "item", name = "permit-draft", amount = 1},
      {type = "item", name = "thermal-process-license", amount = 1},
      {type = "item", name = "embossed-seal", amount = 1},
    },
    results = {
      {type = "item", name = "construction-permit", amount = 1},
    },
    energy_required = 6,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "management-approval-verbal-vulcanus",
    category = "bureaucracy-certification",
    enabled = false,
    localised_name = {"item-name.management-approval-verbal"},
    ingredients = {
      {type = "item", name = "blank-cyan-form", amount = 1},
      {type = "item", name = "good-excuse", amount = 1},
      {type = "fluid", name = "liquid-coffee", amount = 25},
    },
    results = {
      {type = "item", name = "management-approval-verbal", amount = 1},
    },
    energy_required = 5,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "heatproof-filler-documentation",
    category = "bureaucracy-certification",
    enabled = false,
    localised_name = {"item-name.useless-documentation"},
    ingredients = {
      {type = "item", name = "blank-cyan-form", amount = 1},
      {type = "fluid", name = "cyan-slurry", amount = 20},
    },
    results = {
      {type = "item", name = "useless-documentation", amount = 3},
    },
    energy_required = 4,
  }, "vulcanus"),
  surface_limited({
    type = "recipe",
    name = "form-27b-6-vulcanus",
    category = "bureaucracy-certification",
    enabled = false,
    localised_name = {"item-name.form-27b-6"},
    ingredients = {
      {type = "item", name = "blank-form", amount = 1},
      {type = "item", name = "useless-documentation", amount = 1},
      {type = "item", name = "embossed-seal", amount = 1},
    },
    results = {
      {type = "item", name = "form-27b-6", amount = 1},
    },
    energy_required = 4,
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
      {type = "fluid", name = "lie", amount = 180},
      {type = "item", name = "dubious-data", amount = 1},
    },
    main_product = "lie",
    energy_required = 6,
  }, "vulcanus"),
})

do
  local offworld_clones = {
    {source = "foundry", clone = "foundry-offworld", ingredient = "offworld-metallurgy-charter", amount = 1},
    {source = "tungsten-plate", clone = "tungsten-plate-offworld", ingredient = "thermal-process-license", amount = 1},
    {source = "tungsten-carbide", clone = "tungsten-carbide-offworld", ingredient = "thermal-process-license", amount = 1},
    {source = "molten-iron", clone = "molten-iron-offworld", ingredient = "calcite-reagent-waiver", amount = 1},
    {source = "molten-iron-from-lava", clone = "molten-iron-from-lava-offworld", ingredient = "calcite-reagent-waiver", amount = 1},
    {source = "molten-copper", clone = "molten-copper-offworld", ingredient = "calcite-reagent-waiver", amount = 1},
    {source = "molten-copper-from-lava", clone = "molten-copper-from-lava-offworld", ingredient = "calcite-reagent-waiver", amount = 1},
    {source = "simple-coal-liquefaction", clone = "simple-coal-liquefaction-offworld", ingredient = "calcite-reagent-waiver", amount = 1},
    {source = "acid-neutralisation", clone = "acid-neutralisation-offworld", ingredient = "calcite-reagent-waiver", amount = 1},
    {source = "casting-low-density-structure", clone = "casting-low-density-structure-offworld", ingredient = "offworld-metallurgy-charter", amount = 1},
  }

  local clones = {}
  for _, spec in ipairs(offworld_clones) do
    local source = data.raw.recipe and data.raw.recipe[spec.source]
    if source then
      surface_limited(source, "vulcanus")
      local clone = clone_recipe(spec.source, spec.clone)
      if clone then
        add_item_ingredient(clone, spec.ingredient, spec.amount)
        not_on_planet(clone, "vulcanus")
        table.insert(clones, clone)
      end
    end
  end

  if #clones > 0 then
    data:extend(clones)
    for _, spec in ipairs(offworld_clones) do
      if data.raw.recipe and data.raw.recipe[spec.clone] then
        add_unlock_for_clone(spec.source, spec.clone)
      end
    end
  end
end

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

add_item_ingredient(data.raw.recipe and data.raw.recipe["foundry-offworld"], "licensed-notary", 1)
