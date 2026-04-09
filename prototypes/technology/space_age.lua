local function add_tech_unlock(technology_name, recipe_name)
  local technology = data.raw["technology"] and data.raw["technology"][technology_name]
  if not technology or not recipe_name or not (data.raw.recipe and data.raw.recipe[recipe_name]) then return end
  technology.effects = technology.effects or {}
  for _, effect in ipairs(technology.effects) do
    if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
      return
    end
  end
  table.insert(technology.effects, {type = "unlock-recipe", recipe = recipe_name})
end

data:extend({
  {
    type = "technology",
    name = "chromatic-printing",
    icon = "__administratorio__/graphics/icons/steel-forge-icon.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "chromatic-printer"},
      {type = "unlock-recipe", recipe = "liquid-black-ink"},
      {type = "unlock-recipe", recipe = "dubious-data-analysis-vulcanus"},
      {type = "unlock-recipe", recipe = "cyan-slurry-production"},
      {type = "unlock-recipe", recipe = "cyan-ink-production"},
      {type = "unlock-recipe", recipe = "heatproof-form-stock"},
      {type = "unlock-recipe", recipe = "blank-cyan-form-production"},
      {type = "unlock-recipe", recipe = "permit-draft"},
      {type = "unlock-recipe", recipe = "inspection-docket"},
    },
    prerequisites = {"industrial-printing", "executive-review"},
    unit = {
      count = 220,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-a",
  },
  {
    type = "technology",
    name = "workforce-formation",
    icon = "__base__/graphics/technology/worker-robots-speed.png",
    icon_size = 256,
    effects = {
      {type = "unlock-recipe", recipe = "formation-center"},
      {type = "unlock-recipe", recipe = "trajectory-compliance-array"},
      {type = "unlock-recipe", recipe = "job-offer-production"},
      {type = "unlock-recipe", recipe = "worker-biter-formation"},
      {type = "unlock-recipe", recipe = "clerical-trainee-formation"},
      {type = "unlock-recipe", recipe = "management-trainee-formation"},
      {type = "unlock-recipe", recipe = "night-shift-supervisor-formation"},
      {type = "unlock-recipe", recipe = "field-negotiator-formation"},
      {type = "unlock-recipe", recipe = "middle-management-managing-manager-formation"},
    },
    prerequisites = {"space-science-pack", "executive-review"},
    unit = {
      count = 280,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"utility-science-pack", 1},
        {"space-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-b",
  },
  {
    type = "technology",
    name = "vulcanus-certification",
    icon = "__administratorio__/graphics/icons/management-approval-written.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "notary-office"},
      {type = "unlock-recipe", recipe = "embossed-seal"},
      {type = "unlock-recipe", recipe = "industrial-charter"},
      {type = "unlock-recipe", recipe = "thermal-process-license"},
      {type = "unlock-recipe", recipe = "calcite-reagent-waiver"},
      {type = "unlock-recipe", recipe = "offworld-metallurgy-charter"},
      {type = "unlock-recipe", recipe = "good-excuse-vulcanus"},
      {type = "unlock-recipe", recipe = "safety-waiver-vulcanus"},
      {type = "unlock-recipe", recipe = "construction-permit-vulcanus"},
      {type = "unlock-recipe", recipe = "management-approval-verbal-vulcanus"},
      {type = "unlock-recipe", recipe = "heatproof-filler-documentation"},
      {type = "unlock-recipe", recipe = "form-27b-6-vulcanus"},
      {type = "unlock-recipe", recipe = "vulcanus-lie-distillation"},
    },
    prerequisites = {"chromatic-printing", "metallurgic-science-pack"},
    unit = {
      count = 320,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"metallurgic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-c",
  },
  {
    type = "technology",
    name = "gleba-conciliation",
    icon = "__administratorio__/graphics/icons/promise.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "chromatic-printer"},
      {type = "unlock-recipe", recipe = "conciliation-desk"},
      {type = "unlock-recipe", recipe = "yellow-ink-production"},
      {type = "unlock-recipe", recipe = "mycelial-form-stock"},
      {type = "unlock-recipe", recipe = "blank-yellow-form-production"},
      {type = "unlock-recipe", recipe = "symbiosis-record"},
      {type = "unlock-recipe", recipe = "conciliation-order"},
      {type = "unlock-recipe", recipe = "biochamber-operating-waiver"},
    },
    prerequisites = {"executive-review", "agricultural-science-pack"},
    unit = {
      count = 320,
      ingredients = {
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-d",
  },
})

add_tech_unlock("metallurgic-science-pack", "licensed-notary-formation")
add_tech_unlock("administrative-science-research", "research-grant-approval-vulcanus")
add_tech_unlock("administrative-science-research", "administrative-science-pack-production-vulcanus")
add_tech_unlock("administrative-science-research", "admin-station-gleba")
add_tech_unlock("administrative-science-research", "administrative-science-pack-production-gleba")
add_tech_unlock("calcite-processing", "dubious-data-analysis-vulcanus")
add_tech_unlock("calcite-processing", "paper-production-vulcanus")
add_tech_unlock("calcite-processing", "carbon-offset-certificate-basic-vulcanus")
add_tech_unlock("calcite-processing", "admin-station-vulcanus")
add_tech_unlock("calcite-processing", "liquid-stimulant-production")
add_tech_unlock("calcite-processing", "liquid-coffee-vulcanus")
add_tech_unlock("calcite-processing", "plastic-bar-vulcanus")
add_tech_unlock("calcite-processing", "heatproof-paper-production")
add_tech_unlock("calcite-processing", "molten-promises-production")
add_tech_unlock("printing-technology", "printer-t1-vulcanus")
add_tech_unlock("printing-technology", "printer-t1-gleba")
add_tech_unlock("industrial-propaganda", "propaganda-distillery-vulcanus")
add_tech_unlock("industrial-propaganda", "refined-nonsense-production-vulcanus")
add_tech_unlock("local-precedents", "useless-documentation-production-gleba")
add_tech_unlock("agricultural-science-pack", "conciliation-officer-formation")
add_tech_unlock("corporate-hospitality", "corporate-breakroom-gleba")
add_tech_unlock("electromagnetic-science-pack", "relay-clerk-formation")
add_tech_unlock("cryogenic-science-pack", "cryoprint-technician-formation")
add_tech_unlock("after-hours-operations", "overtime-exemption-staffed")
add_tech_unlock("discovery-redundant-rubble", "promise-production-negotiated")
add_tech_unlock("nest-expropriation", "eviction-notice-production-negotiated")
