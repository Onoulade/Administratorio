local fax_shared = require("scripts.fax_shared")
local manager_briefings = require("prototypes.shared.manager_briefings")

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

local function add_tech_prerequisite(technology_name, prerequisite_name)
  local technology = data.raw.technology and data.raw.technology[technology_name]
  if not technology or not (data.raw.technology and data.raw.technology[prerequisite_name]) then return end
  technology.prerequisites = technology.prerequisites or {}
  for _, existing in ipairs(technology.prerequisites) do
    if existing == prerequisite_name then return end
  end
  technology.prerequisites[#technology.prerequisites + 1] = prerequisite_name
end

data:extend({
  {
    type = "technology",
    name = "chromatic-printing",
    icon = "__administratorio__/graphics/icons/steel-forge-icon.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "worker-biter"},
      {type = "unlock-recipe", recipe = "chromatic-printer"},
      {type = "unlock-recipe", recipe = "liquid-black-ink"},
      {type = "unlock-recipe", recipe = "dubious-data-analysis-vulcanus"},
      {type = "unlock-recipe", recipe = "cyan-slurry-production"},
      {type = "unlock-recipe", recipe = "cyan-ink-production"},
      {type = "unlock-recipe", recipe = "heatproof-form-stock"},
      {type = "unlock-recipe", recipe = "blank-cyan-form-production"},
      {type = "unlock-recipe", recipe = "charged-toner"},
      {type = "unlock-recipe", recipe = "archive-rubble-recovery"},
      {type = "unlock-recipe", recipe = "archive-documentation-recovery"},
      {type = "unlock-recipe", recipe = "magenta-ink-production"},
      {type = "unlock-recipe", recipe = "signal-form-stock"},
      {type = "unlock-recipe", recipe = "blank-magenta-form-production"},
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
      {type = "unlock-recipe", recipe = "orbital-employment-cannon"},
      {type = "unlock-recipe", recipe = "job-offer-production"},
      {type = "unlock-recipe", recipe = "worker-biter-formation"},
      {type = "unlock-recipe", recipe = "clerical-trainee-formation"},
      {type = "unlock-recipe", recipe = "management-trainee-formation"},
      {type = "unlock-recipe", recipe = "astronaut-formation"},
      {type = "unlock-recipe", recipe = "middle-management-managing-manager-formation"},
      {type = "unlock-recipe", recipe = "administrative-space-station"},
      {type = "unlock-recipe", recipe = "thermal-process-license-orbital"},
      {type = "unlock-recipe", recipe = "calcite-reagent-waiver-orbital"},
      {type = "unlock-recipe", recipe = "offworld-metallurgy-charter-orbital"},
      {type = "unlock-recipe", recipe = "orbital-deviation-order"},
      {type = "unlock-recipe", recipe = "asteroid-processing-docket"},
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
      {type = "unlock-recipe", recipe = "territorial-arbitration-post"},
      {type = "unlock-recipe", recipe = "embossed-seal"},
      {type = "unlock-recipe", recipe = "industrial-charter"},
      {type = "unlock-recipe", recipe = "territorial-resettlement-order"},
      {type = "unlock-recipe", recipe = "good-excuse-vulcanus"},
      {type = "unlock-recipe", recipe = "safety-waiver-vulcanus"},
      {type = "unlock-recipe", recipe = "construction-permit-vulcanus"},
      {type = "unlock-recipe", recipe = "management-approval-verbal-vulcanus"},
      {type = "unlock-recipe", recipe = "management-approval-written-vulcanus"},
      {type = "unlock-recipe", recipe = "heatproof-filler-documentation"},
      {type = "unlock-recipe", recipe = "form-27b-6-vulcanus"},
      {type = "unlock-recipe", recipe = "vulcanus-lie-distillation"},
    },
    prerequisites = {"chromatic-printing"},
    unit = {
      count = 260,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-c",
  },
  {
    type = "technology",
    name = "vulcanus-export-charters",
    icon = "__administratorio__/graphics/icons/steel-forge-icon.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "thermal-process-license"},
      {type = "unlock-recipe", recipe = "calcite-reagent-waiver"},
      {type = "unlock-recipe", recipe = "offworld-metallurgy-charter"},
    },
    prerequisites = {"vulcanus-certification", "metallurgic-science-pack"},
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
    order = "h-c2",
  },
  {
    type = "technology",
    name = "gleba-conciliation",
    icon = "__administratorio__/graphics/icons/promise.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "chromatic-printer"},
      {type = "unlock-recipe", recipe = "capture-bureau"},
      {type = "unlock-recipe", recipe = "capture-bureau-pentapod-eggs"},
      {type = "unlock-recipe", recipe = "conciliation-desk"},
      {type = "unlock-recipe", recipe = "yellow-ink-production"},
      {type = "unlock-recipe", recipe = "hostile-spore-culture-production"},
      {type = "unlock-recipe", recipe = "oviposition-lure-spores-production"},
      {type = "unlock-recipe", recipe = "mycelial-form-stock"},
      {type = "unlock-recipe", recipe = "blank-yellow-form-production"},
      {type = "unlock-recipe", recipe = "symbiosis-record"},
      {type = "unlock-recipe", recipe = "conciliation-order"},
    },
    prerequisites = {"executive-review"},
    research_trigger = {
      type = "craft-item",
      item = "bullshit-ore",
      count = 50,
    },
    order = "h-d",
  },
  {
    type = "technology",
    name = "fulgora-digital-services",
    icon = "__administratorio__/graphics/icons/data.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "digital-services-bureau"},
      {type = "unlock-recipe", recipe = "archive-recovery-permit"},
      {type = "unlock-recipe", recipe = "digital-processing-certificate"},
      {type = "unlock-recipe", recipe = "electromagnetic-operating-license"},
      {type = "unlock-recipe", recipe = "data-recovery-order"},
    },
    prerequisites = {"chromatic-printing"},
    research_trigger = {
      type = "craft-item",
      item = "charged-toner",
      count = 20,
    },
    order = "h-e",
  },
  {
    type = "technology",
    name = "cyan-yellow-bureaucracy",
    icon = "__administratorio__/graphics/icons/blank-form.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "capture-bureau-tourism"},
      {type = "unlock-recipe", recipe = "public-transportation-contract-production"},
      {type = "unlock-recipe", recipe = "cyan-yellow-form-production"},
    },
    prerequisites = {"vulcanus-certification", "gleba-conciliation", "metallurgic-science-pack", "agricultural-science-pack"},
    unit = {
      count = 380,
      ingredients = {
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-e1",
  },
  {
    type = "technology",
    name = "cyan-magenta-bureaucracy",
    icon = "__administratorio__/graphics/icons/blank-form.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "cyan-magenta-form-production"},
      {type = "unlock-recipe", recipe = "hardened-data-vault-production"},
    },
    prerequisites = {"vulcanus-certification", "fulgora-digital-services", "metallurgic-science-pack", "electromagnetic-science-pack"},
    unit = {
      count = 380,
      ingredients = {
        {"metallurgic-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-e2",
  },
  {
    type = "technology",
    name = "yellow-magenta-bureaucracy",
    icon = "__administratorio__/graphics/icons/blank-form.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "yellow-magenta-form-production"},
      {type = "unlock-recipe", recipe = "anecdotal-data-reprocessing"},
    },
    prerequisites = {"gleba-conciliation", "fulgora-digital-services", "agricultural-science-pack", "electromagnetic-science-pack"},
    unit = {
      count = 380,
      ingredients = {
        {"agricultural-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-e3",
  },
  {
    type = "technology",
    name = "aquilo-fax-network",
    icon = "__administratorio__/graphics/icons/steel-forge-icon.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "laser-printer"},
      {type = "unlock-recipe", recipe = "fax-emitter"},
      {type = "unlock-recipe", recipe = "interplanetary-fax-exchange"},
      {type = "unlock-recipe", recipe = "transfer-emulsion-production"},
      {type = "unlock-recipe", recipe = "thermal-transfer-sheet-production"},
      {type = "unlock-recipe", recipe = "composite-chroma-ribbon-production"},
      {type = "unlock-recipe", recipe = "trichromatic-permit-production"},
      {type = "unlock-recipe", recipe = "unified-operations-charter-production"},
      {type = "unlock-recipe", recipe = "cryogenic-operations-license-production"},
      {type = "unlock-recipe", recipe = "promethium-research-charter-production"},
    },
    prerequisites = {"cyan-yellow-bureaucracy", "cyan-magenta-bureaucracy", "yellow-magenta-bureaucracy", "cryogenic-science-pack"},
    unit = {
      count = 500,
      ingredients = {
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"cryogenic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 60,
    },
    order = "h-f",
  },
  {
    type = "technology",
    name = "color-faxing",
    icon = "__administratorio__/graphics/icons/ink-cartridge.png",
    icon_size = 64,
    effects = {},
    prerequisites = {"aquilo-fax-network"},
    unit = {
      count = 400,
      ingredients = {
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"cryogenic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 60,
    },
    order = "h-f-b",
  },
  {
    type = "technology",
    name = "fax-queue-capacity-1",
    icon = "__administratorio__/graphics/icons/office-building.png",
    icon_size = 64,
    effects = {
      {type = "nothing", effect_description = {"technology-effect.fax-queue-capacity", "5"}},
    },
    prerequisites = {"aquilo-fax-network"},
    unit = {
      count = 300,
      ingredients = {
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"cryogenic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 60,
    },
    order = "h-g",
    upgrade = true,
  },
  {
    type = "technology",
    name = "bureaucratic-transcendence",
    icon = "__base__/graphics/icons/train-stop.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "public-train-stop-production"},
    },
    prerequisites = {"aquilo-fax-network"},
    unit = {
      count = 400,
      ingredients = {
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"cryogenic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 60,
    },
    order = "h-f-a",
  },
  {
    type = "technology",
    name = "fax-queue-capacity-2",
    icon = "__administratorio__/graphics/icons/office-building.png",
    icon_size = 64,
    effects = {
      {type = "nothing", effect_description = {"technology-effect.fax-queue-capacity", "5"}},
    },
    prerequisites = {"fax-queue-capacity-1"},
    unit = {
      count = 425,
      ingredients = {
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"cryogenic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 60,
    },
    order = "h-h",
    upgrade = true,
  },
  {
    type = "technology",
    name = "fax-queue-capacity-3",
    icon = "__administratorio__/graphics/icons/office-building.png",
    icon_size = 64,
    effects = {
      {type = "nothing", effect_description = {"technology-effect.fax-queue-capacity", "5"}},
    },
    prerequisites = {"fax-queue-capacity-2"},
    unit = {
      count = 550,
      ingredients = {
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"cryogenic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 60,
    },
    order = "h-i",
    upgrade = true,
  },
  {
    type = "technology",
    name = "fulgora-digital-services",
    icon = "__administratorio__/graphics/icons/data.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "digital-services-bureau"},
      {type = "unlock-recipe", recipe = "archive-recovery-permit"},
      {type = "unlock-recipe", recipe = "digital-processing-certificate"},
      {type = "unlock-recipe", recipe = "electromagnetic-operating-license"},
      {type = "unlock-recipe", recipe = "data-recovery-order"},
    },
    prerequisites = {"chromatic-printing", "electromagnetic-science-pack"},
    unit = {
      count = 360,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-e",
  },
  {
    type = "technology",
    name = "cyan-yellow-bureaucracy",
    icon = "__administratorio__/graphics/icons/blank-form.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "orbital-tourism-form-production"},
      {type = "unlock-recipe", recipe = "public-transportation-contract-production"},
      {type = "unlock-recipe", recipe = "composite-form-cyan-yellow-production"},
    },
    prerequisites = {"vulcanus-certification", "gleba-conciliation", "metallurgic-science-pack", "agricultural-science-pack"},
    unit = {
      count = 380,
      ingredients = {
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-e1",
  },
  {
    type = "technology",
    name = "cyan-magenta-bureaucracy",
    icon = "__administratorio__/graphics/icons/blank-form.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "composite-form-cyan-magenta-production"},
    },
    prerequisites = {"vulcanus-certification", "fulgora-digital-services", "metallurgic-science-pack", "electromagnetic-science-pack"},
    unit = {
      count = 380,
      ingredients = {
        {"metallurgic-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-e2",
  },
  {
    type = "technology",
    name = "yellow-magenta-bureaucracy",
    icon = "__administratorio__/graphics/icons/blank-form.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "composite-form-yellow-magenta-production"},
    },
    prerequisites = {"gleba-conciliation", "fulgora-digital-services", "agricultural-science-pack", "electromagnetic-science-pack"},
    unit = {
      count = 380,
      ingredients = {
        {"agricultural-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-e3",
  },
  {
    type = "technology",
    name = "aquilo-fax-network",
    icon = "__administratorio__/graphics/icons/steel-forge-icon.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "laser-printer"},
      {type = "unlock-recipe", recipe = "fax-emitter"},
      {type = "unlock-recipe", recipe = "interplanetary-fax-exchange"},
      {type = "unlock-recipe", recipe = "transfer-emulsion-production"},
      {type = "unlock-recipe", recipe = "thermal-transfer-sheet-production"},
      {type = "unlock-recipe", recipe = "composite-chroma-ribbon-production"},
      {type = "unlock-recipe", recipe = "trichromatic-permit-production"},
      {type = "unlock-recipe", recipe = "unified-operations-charter-production"},
      {type = "unlock-recipe", recipe = "cryogenic-operations-license-production"},
    },
    prerequisites = {"cyan-yellow-bureaucracy", "cyan-magenta-bureaucracy", "yellow-magenta-bureaucracy", "cryogenic-science-pack"},
    unit = {
      count = 500,
      ingredients = {
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"cryogenic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 60,
    },
    order = "h-f",
  },
  {
    type = "technology",
    name = "fax-queue-capacity-1",
    icon = "__administratorio__/graphics/icons/office-building.png",
    icon_size = 64,
    effects = {
      {type = "nothing", effect_description = {"technology-effect.fax-queue-capacity", "5"}},
    },
    prerequisites = {"aquilo-fax-network"},
    unit = {
      count = 300,
      ingredients = {
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"cryogenic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 60,
    },
    order = "h-g",
    upgrade = true,
  },
  {
    type = "technology",
    name = "bureaucratic-transcendence",
    icon = "__base__/graphics/icons/train-stop.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "public-train-stop-production"},
    },
    prerequisites = {"aquilo-fax-network"},
    unit = {
      count = 400,
      ingredients = {
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"cryogenic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 60,
    },
    order = "h-f-a",
  },
  {
    type = "technology",
    name = "fax-queue-capacity-2",
    icon = "__administratorio__/graphics/icons/office-building.png",
    icon_size = 64,
    effects = {
      {type = "nothing", effect_description = {"technology-effect.fax-queue-capacity", "5"}},
    },
    prerequisites = {"fax-queue-capacity-1"},
    unit = {
      count = 425,
      ingredients = {
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"cryogenic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 60,
    },
    order = "h-h",
    upgrade = true,
  },
  {
    type = "technology",
    name = "fax-queue-capacity-3",
    icon = "__administratorio__/graphics/icons/office-building.png",
    icon_size = 64,
    effects = {
      {type = "nothing", effect_description = {"technology-effect.fax-queue-capacity", "5"}},
    },
    prerequisites = {"fax-queue-capacity-2"},
    unit = {
      count = 550,
      ingredients = {
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"cryogenic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 60,
    },
    order = "h-i",
    upgrade = true,
  },
})

data:extend({
  {
    type = "technology",
    name = "trajectory-compliance-jurisdiction-2",
    icons = {
      {icon = "__base__/graphics/technology/weapon-shooting-speed-1.png", icon_size = 256},
      {icon = "__base__/graphics/icons/behemoth-biter.png", icon_size = 64, scale = 0.5, shift = {32, 32}},
    },
    effects = {
      {type = "unlock-recipe", recipe = "senior-trajectory-compliance-array"},
    },
    prerequisites = {
      "workforce-formation",
      "metallurgic-science-pack",
      "agricultural-science-pack",
      "electromagnetic-science-pack",
    },
    unit = {
      count = 1200,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"utility-science-pack", 1},
        {"space-science-pack", 1},
        {"administrative-science-pack", 1},
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"electromagnetic-science-pack", 1},
      },
      time = 60,
    },
    order = "h-b-j[02]",
  },
  {
    type = "technology",
    name = "trajectory-compliance-jurisdiction-3",
    icons = {
      {icon = "__base__/graphics/technology/weapon-shooting-speed-1.png", icon_size = 256},
      {icon = "__space-age__/graphics/icons/quantum-processor.png", icon_size = 64, scale = 0.5, shift = {32, 32}},
    },
    effects = {
      {type = "unlock-recipe", recipe = "executive-trajectory-compliance-array"},
    },
    prerequisites = {
      "trajectory-compliance-jurisdiction-2",
      "quantum-processor",
    },
    unit = {
      count = 3000,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"utility-science-pack", 1},
        {"space-science-pack", 1},
        {"administrative-science-pack", 1},
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"cryogenic-science-pack", 1},
      },
      time = 60,
    },
    order = "h-b-j[03]",
  },
})

local trajectory_speed_seconds = {4.5, 4.0, 3.5, 3.0, 2.5, 2.0, 1.5, 1.0, 0.5}
local trajectory_speed_counts = {200, 350, 550, 800, 1000, 1500, 2250, 3000, 4000}
local trajectory_speed_techs = {}
local previous_speed_modifier = 0

local early_speed_packs = {
  {"automation-science-pack", 1},
  {"logistic-science-pack", 1},
  {"chemical-science-pack", 1},
  {"utility-science-pack", 1},
  {"space-science-pack", 1},
  {"administrative-science-pack", 1},
}

local function copy_science_packs(packs)
  local copy = {}
  for _, pack in ipairs(packs) do
    copy[#copy + 1] = {pack[1], pack[2]}
  end
  return copy
end

for level, seconds in ipairs(trajectory_speed_seconds) do
  local target_ticks = seconds * 60
  local cumulative_modifier = 300 / target_ticks - 1
  local packs = copy_science_packs(early_speed_packs)

  if level >= 5 then
    packs[#packs + 1] = {"metallurgic-science-pack", 1}
    packs[#packs + 1] = {"agricultural-science-pack", 1}
    packs[#packs + 1] = {"electromagnetic-science-pack", 1}
  end
  if level >= 8 then
    packs[#packs + 1] = {"cryogenic-science-pack", 1}
  end
  if level >= 9 then
    packs[#packs + 1] = {"promethium-science-pack", 1}
  end

  local prerequisites = level == 1
    and {"workforce-formation"}
    or {"trajectory-compliance-speed-" .. (level - 1)}
  if level == 5 then
    prerequisites[#prerequisites + 1] = "metallurgic-science-pack"
    prerequisites[#prerequisites + 1] = "agricultural-science-pack"
    prerequisites[#prerequisites + 1] = "electromagnetic-science-pack"
  elseif level == 8 then
    prerequisites[#prerequisites + 1] = "cryogenic-science-pack"
  elseif level == 9 then
    prerequisites[#prerequisites + 1] = "promethium-science-pack"
  end

  trajectory_speed_techs[#trajectory_speed_techs + 1] = {
    type = "technology",
    name = "trajectory-compliance-speed-" .. level,
    icons = {
      {icon = "__base__/graphics/technology/weapon-shooting-speed-1.png", icon_size = 256},
      {icon = "__base__/graphics/icons/behemoth-biter.png", icon_size = 64, scale = 0.45, shift = {32, 32}},
    },
    effects = {
      {
        type = "gun-speed",
        ammo_category = "trajectory-compliance",
        modifier = cumulative_modifier - previous_speed_modifier,
      },
      {
        type = "nothing",
        effect_description = {"technology-effect.trajectory-compliance-speed", string.format("%.1f", seconds)},
      },
    },
    prerequisites = prerequisites,
    unit = {
      count = trajectory_speed_counts[level],
      ingredients = packs,
      time = level <= 4 and 45 or 60,
    },
    order = "h-b-s[" .. string.format("%02d", level) .. "]",
    upgrade = true,
  }

  previous_speed_modifier = cumulative_modifier
end

data:extend(trajectory_speed_techs)

local orbital_employment_damage_counts = {350, 600, 1200, 2200, 4000}
local orbital_employment_damage_techs = {}

for level, count in ipairs(orbital_employment_damage_counts) do
  local packs = copy_science_packs(early_speed_packs)
  if level >= 3 then
    packs[#packs + 1] = {"metallurgic-science-pack", 1}
    packs[#packs + 1] = {"agricultural-science-pack", 1}
    packs[#packs + 1] = {"electromagnetic-science-pack", 1}
  end
  if level >= 4 then
    packs[#packs + 1] = {"cryogenic-science-pack", 1}
  end
  if level >= 5 then
    packs[#packs + 1] = {"promethium-science-pack", 1}
  end

  local prerequisites = level == 1
    and {"workforce-formation"}
    or {"orbital-employment-damage-" .. (level - 1)}
  if level == 3 then
    prerequisites[#prerequisites + 1] = "metallurgic-science-pack"
    prerequisites[#prerequisites + 1] = "agricultural-science-pack"
    prerequisites[#prerequisites + 1] = "electromagnetic-science-pack"
  elseif level == 4 then
    prerequisites[#prerequisites + 1] = "cryogenic-science-pack"
  elseif level == 5 then
    prerequisites[#prerequisites + 1] = "promethium-science-pack"
  end

  orbital_employment_damage_techs[#orbital_employment_damage_techs + 1] = {
    type = "technology",
    name = "orbital-employment-damage-" .. level,
    icons = {
      {icon = "__space-age__/graphics/technology/railgun-damage.png", icon_size = 256},
      {icon = "__base__/graphics/icons/electric-mining-drill.png", icon_size = 64, scale = 0.5, shift = {32, 32}},
    },
    effects = {
      {
        type = "ammo-damage",
        ammo_category = "orbital-biter-ballistics",
        modifier = 0.5,
      },
      {
        type = "nothing",
        effect_description = {"technology-effect.orbital-employment-damage", tostring(125 * (1 + level * 0.5))},
      },
    },
    prerequisites = prerequisites,
    unit = {
      count = count,
      ingredients = packs,
      time = level <= 2 and 45 or 60,
    },
    order = "h-b-d[" .. string.format("%02d", level) .. "]",
    upgrade = true,
  }
end

data:extend(orbital_employment_damage_techs)

-- One VESM per asteroid is the unresearched baseline. These four approvals
-- raise the hard staffing allocation to five without relying on item quality.
local orbital_employment_capacity_counts = {500, 1500, 3000, 6000}
local orbital_employment_capacity_techs = {}

for level, count in ipairs(orbital_employment_capacity_counts) do
  local packs = copy_science_packs(early_speed_packs)
  if level >= 2 then
    packs[#packs + 1] = {"metallurgic-science-pack", 1}
    packs[#packs + 1] = {"agricultural-science-pack", 1}
    packs[#packs + 1] = {"electromagnetic-science-pack", 1}
  end
  if level >= 3 then
    packs[#packs + 1] = {"cryogenic-science-pack", 1}
  end
  if level >= 4 then
    packs[#packs + 1] = {"promethium-science-pack", 1}
  end

  local prerequisites = level == 1
    and {"workforce-formation"}
    or {"orbital-employment-capacity-" .. (level - 1)}
  if level == 2 then
    prerequisites[#prerequisites + 1] = "metallurgic-science-pack"
    prerequisites[#prerequisites + 1] = "agricultural-science-pack"
    prerequisites[#prerequisites + 1] = "electromagnetic-science-pack"
  elseif level == 3 then
    prerequisites[#prerequisites + 1] = "cryogenic-science-pack"
  elseif level == 4 then
    prerequisites[#prerequisites + 1] = "promethium-science-pack"
  end

  orbital_employment_capacity_techs[#orbital_employment_capacity_techs + 1] = {
    type = "technology",
    name = "orbital-employment-capacity-" .. level,
    icons = {
      {icon = "__space-age__/graphics/technology/railgun-damage.png", icon_size = 256},
      {icon = "__base__/graphics/icons/electric-mining-drill.png", icon_size = 64, scale = 0.5, shift = {32, 32}},
    },
    effects = {
      {
        type = "nothing",
        effect_description = {"technology-effect.orbital-employment-capacity", tostring(level + 1)},
      },
    },
    prerequisites = prerequisites,
    unit = {
      count = count,
      ingredients = packs,
      time = level == 1 and 45 or 60,
    },
    order = "h-b-c[" .. string.format("%02d", level) .. "]",
    upgrade = true,
  }
end

data:extend(orbital_employment_capacity_techs)

-- Platform creation unlocks the permit before the first collector and crusher
-- are built, avoiding a circular dependency on space science.
add_tech_unlock("space-platform", "orbital-infrastructure-permit")
add_tech_unlock("workforce-formation", "licensed-notary-formation")
add_tech_unlock("administrative-science-research", "research-grant-approval-vulcanus")
add_tech_unlock("administrative-science-research", "administrative-science-pack-production-vulcanus")
add_tech_unlock("administrative-science-research", "provisional-approval-vulcanus")
add_tech_unlock("administrative-science-research", "administrative-science-pack-production-gleba")
add_tech_unlock("calcite-processing", "dubious-data-analysis-vulcanus")
add_tech_unlock("calcite-processing", "paper-production-vulcanus")
add_tech_unlock("calcite-processing", "carbon-offset-certificate-basic-vulcanus")
add_tech_unlock("calcite-processing", "liquid-stimulant-production")
add_tech_unlock("calcite-processing", "liquid-coffee-vulcanus")
add_tech_unlock("calcite-processing", "plastic-bar-vulcanus")
add_tech_unlock("calcite-processing", "heatproof-paper-production")
add_tech_unlock("calcite-processing", "molten-promises-production")
add_tech_unlock("industrial-propaganda", "compacted-rubble-production-vulcanus")
add_tech_unlock("industrial-propaganda", "refined-nonsense-production-vulcanus")
add_tech_unlock("local-precedents", "useless-documentation-production-gleba")
add_tech_unlock("discovery-bullshit", "dubious-data-cultivation-gleba")
add_tech_unlock("discovery-bullshit", "basic-excuse-cultivation-gleba")
add_tech_unlock("discovery-bullshit", "provisional-approval-cultivation-gleba")
add_tech_unlock("local-precedents", "useless-documentation-cultivation-gleba")
add_tech_unlock("corporate-hospitality", "good-excuse-cultivation-gleba")
add_tech_unlock("gleba-conciliation", "refined-nonsense-cultivation-gleba")
add_tech_unlock("gleba-conciliation", "credentials-cultivation-gleba")
add_tech_unlock("gleba-conciliation", "justification-cultivation-gleba")
add_tech_unlock("chromatic-printing", "liquid-black-ink-fulgora")
add_tech_unlock("chromatic-printing", "ink-recovery-fulgora")
add_tech_unlock("chromatic-printing", "salvaged-data-analysis-fulgora")
add_tech_unlock("chromatic-printing", "basic-excuse-production")
add_tech_unlock("chromatic-printing", "carbon-offset-certificate-basic-fulgora")
add_tech_unlock("electromagnetic-plant", "salvage-electrolyte-fulgora")
add_tech_unlock("electromagnetic-science-pack", "electromagnetic-lubricant-fulgora")
add_tech_unlock("rocket-fuel", "electromagnetic-rocket-fuel-fulgora")
add_tech_unlock("agricultural-science-pack", "conciliation-officer-formation")
add_tech_unlock("corporate-hospitality", "construction-permit-gleba")
add_tech_unlock("electromagnetic-science-pack", "relay-clerk-formation")
add_tech_unlock("cryogenic-science-pack", "cryoprint-technician-formation")
add_tech_unlock("hired-biter-fieldwork", "promise-production-negotiated")
add_tech_unlock("hired-biter-fieldwork", "eviction-notice-production-negotiated")
add_tech_unlock("workforce-formation", "capture-bureau-workforce")
add_tech_unlock("workforce-formation", "workforce-lure-spores-production")
add_tech_unlock("workforce-formation", "voluntary-exploration-space-miner-formation")
for _, briefing in ipairs(manager_briefings.BRIEFINGS) do
  add_tech_unlock("workforce-formation", briefing.recipe)
end
add_tech_unlock("cyan-yellow-bureaucracy", "small-spitter-space-tourism")
add_tech_unlock("cyan-yellow-bureaucracy", "medium-spitter-space-tourism")
add_tech_unlock("cyan-yellow-bureaucracy", "big-spitter-space-tourism")
add_tech_unlock("cyan-yellow-bureaucracy", "behemoth-spitter-space-tourism")
add_tech_unlock("cyan-yellow-bureaucracy", "small-space-tourist-jettison")
add_tech_unlock("cyan-yellow-bureaucracy", "medium-space-tourist-jettison")
add_tech_unlock("cyan-yellow-bureaucracy", "big-space-tourist-jettison")
add_tech_unlock("cyan-yellow-bureaucracy", "behemoth-space-tourist-jettison")
add_tech_unlock("cyan-yellow-bureaucracy", "tourism-lure-spores-production")

-- Chromatic printing is landing preparation, like packing enough belts and
-- power poles. Requiring it before each basic planet prevents an optional
-- Nauvis research omission from becoming an off-world bootstrap deadlock.
for _, planet_name in ipairs({"vulcanus", "gleba", "fulgora"}) do
  add_tech_prerequisite("planet-discovery-" .. planet_name, "chromatic-printing")
end

for item_name in pairs(fax_shared.FAX_DOCUMENTS) do
  add_tech_unlock(
    fax_shared.reconstruction_unlock_technology(item_name),
    fax_shared.reconstruction_recipe_name(item_name))
end

require("prototypes.technology.fulgora_archives")
