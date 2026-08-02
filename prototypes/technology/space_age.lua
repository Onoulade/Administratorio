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
  table.insert(technology.prerequisites, prerequisite_name)
end

data:extend({
  -- ============================================================
  -- TIER 0: CHROMATIC LANDING PREP (pre-planet, Nauvis research)
  -- Unlocks the chromatic printer and basic ink/form infrastructure
  -- ============================================================
  {
    type = "technology",
    name = "chromatic-printing",
    icon = "__administratorio__/graphics/icons/space-age/chromatic-printer.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "chromatic-printer"},
      {type = "unlock-recipe", recipe = "liquid-black-ink"},
      {type = "unlock-recipe", recipe = "heatproof-form-stock"},
      {type = "unlock-recipe", recipe = "blank-cyan-form-production"},
    },
    prerequisites = {"industrial-printing", "executive-review", "production-science-pack"},
    unit = {
      count = 220,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"production-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-a",
  },

  -- ============================================================
  -- TIER 1: VULCANUS CERTIFICATION (cyan/magenta bureaucracy)
  -- Requires chromatic printing + metallurgic science
  -- ============================================================
  {
    type = "technology",
    name = "vulcanus-certification",
    icon = "__administratorio__/graphics/icons/space-age/notary-office.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "notary-office"},
      {type = "unlock-recipe", recipe = "territorial-arbitration-post"},
      {type = "unlock-recipe", recipe = "embossed-seal"},
      {type = "unlock-recipe", recipe = "industrial-charter"},
      {type = "unlock-recipe", recipe = "territorial-resettlement-order"},
      {type = "unlock-recipe", recipe = "vulcanus-lie-distillation"},
    },
    prerequisites = {"chromatic-printing", "metallurgic-science-pack"},
    unit = {
      count = 260,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"metallurgic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-b",
  },

  {
    type = "technology",
    name = "vulcanus-export-charters",
    icon = "__administratorio__/graphics/icons/space-age/territorial-arbitration-post.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "thermal-process-license"},
      {type = "unlock-recipe", recipe = "calcite-reagent-waiver"},
      {type = "unlock-recipe", recipe = "offworld-metallurgy-charter"},
    },
    prerequisites = {"vulcanus-certification"},
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
    order = "h-b2",
  },

  -- ============================================================
  -- TIER 1b: CYAN/MAGENTA INK & FORMS (Vulcanus-specific printing)
  -- ============================================================
  {
    type = "technology",
    name = "cyan-ink-production",
    icon = "__administratorio__/graphics/icons/signal-form-stock.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "cyan-slurry-production"},
      {type = "unlock-recipe", recipe = "cyan-ink-production"},
      {type = "unlock-recipe", recipe = "magenta-ink-production"},
      {type = "unlock-recipe", recipe = "signal-form-stock"},
      {type = "unlock-recipe", recipe = "blank-magenta-form-production"},
      {type = "unlock-recipe", recipe = "permit-draft"},
      {type = "unlock-recipe", recipe = "inspection-docket"},
    },
    prerequisites = {"chromatic-printing", "metallurgic-science-pack"},
    unit = {
      count = 180,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"metallurgic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 40,
    },
    order = "h-b3",
  },

  -- ============================================================
  -- TIER 2: GLEBA AMBER-SAP BOOTSTRAP
  -- The local recipes remain unknown until the player pumps the native seep.
  -- ============================================================
  {
    type = "technology",
    name = "amber-sap-processing",
    icon = "__administratorio__/graphics/icons/coffee.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "amber-sap-nonsense-seeding"},
      {type = "unlock-recipe", recipe = "ink-production-gleba"},
      {type = "unlock-recipe", recipe = "carbon-offset-certificate-basic-gleba"},
      {type = "unlock-recipe", recipe = "provisional-approval-cultivation-gleba"},
      {type = "unlock-recipe", recipe = "construction-permit-gleba"},
    },
    prerequisites = {"planet-discovery-gleba"},
    research_trigger = {
      type = "mine-entity",
      entity = "amber-sap-seep",
    },
    order = "h-b4",
  },

  -- ============================================================
  -- TIER 2a: GLEBA CONCILIATION (yellow bureaucracy, agricultural science)
  -- ============================================================
  {
    type = "technology",
    name = "gleba-conciliation",
    icon = "__administratorio__/graphics/icons/space-age/conciliation-desk.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "capture-bureau"},
      {type = "unlock-recipe", recipe = "conciliation-desk"},
      {type = "unlock-recipe", recipe = "yellow-ink-production"},
      {type = "unlock-recipe", recipe = "hostile-spore-culture-production"},
      {type = "unlock-recipe", recipe = "oviposition-lure-spores-production"},
      {type = "unlock-recipe", recipe = "mycelial-form-stock"},
      {type = "unlock-recipe", recipe = "blank-yellow-form-production"},
      {type = "unlock-recipe", recipe = "symbiosis-record"},
      {type = "unlock-recipe", recipe = "conciliation-order"},
      {type = "unlock-recipe", recipe = "management-approval-written-gleba"},
      {type = "unlock-recipe", recipe = "composted-rubble-recovery-gleba"},
    },
    prerequisites = {"amber-sap-processing", "executive-review", "agricultural-science-pack"},
    research_trigger = {
      type = "craft-item",
      item = "pentapod-egg",
      count = 10,
    },
    order = "h-c",
  },

  -- ============================================================
  -- TIER 2b: GLEBA PENTAPOD FORMATIONS (requires gleba-conciliation)
  -- ============================================================
  {
    type = "technology",
    name = "gleba-pentapod-formations",
    icon = "__administratorio__/graphics/icons/symbiosis-record.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "capture-bureau-pentapod-eggs"},
      {type = "unlock-recipe", recipe = "conciliation-officer-formation-gleba"},
    },
    prerequisites = {"gleba-conciliation", "worker-formation"},
    unit = {
      count = 200,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-c2",
  },

  -- ============================================================
  -- TIER 3: FULGORA DIGITAL SERVICES (electromagnetic science)
  -- Triggered by crafting charged toner (from chromatic printing)
  -- ============================================================
  {
    type = "technology",
    name = "fulgora-digital-services",
    icon = "__administratorio__/graphics/icons/space-age/digital-services-bureau.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "digital-services-bureau"},
      {type = "unlock-recipe", recipe = "archive-recovery-permit"},
      {type = "unlock-recipe", recipe = "digital-processing-certificate"},
      {type = "unlock-recipe", recipe = "electromagnetic-operating-license"},
      {type = "unlock-recipe", recipe = "data-recovery-order"},
    },
    prerequisites = {"chromatic-printing", "electromagnetic-science-pack"},
    research_trigger = {
      type = "craft-item",
      item = "charged-toner",
      count = 20,
    },
    order = "h-d",
  },

  -- ============================================================
  -- TIER 4: COMBINED BUREAUCRACIES (pairwise planet science packs)
  -- ============================================================
  {
    type = "technology",
    name = "cyan-yellow-bureaucracy",
    icon = "__administratorio__/graphics/icons/cyan-yellow-form.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "capture-bureau-tourism"},
      {type = "unlock-recipe", recipe = "public-transportation-contract-production"},
      {type = "unlock-recipe", recipe = "cyan-yellow-form-production"},
    },
    prerequisites = {"vulcanus-certification", "vulcanus-export-charters", "gleba-conciliation", "gleba-pentapod-formations", "cyan-ink-production", "metallurgic-science-pack", "agricultural-science-pack"},
    unit = {
      count = 380,
      ingredients = {
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-e",
  },

  {
    type = "technology",
    name = "cyan-magenta-bureaucracy",
    icon = "__administratorio__/graphics/icons/cyan-magenta-form.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "cyan-magenta-form-production"},
      {type = "unlock-recipe", recipe = "hardened-data-vault-production"},
    },
    prerequisites = {"vulcanus-certification", "vulcanus-export-charters", "fulgora-digital-services", "cyan-ink-production", "metallurgic-science-pack", "electromagnetic-science-pack"},
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
    icon = "__administratorio__/graphics/icons/yellow-magenta-form.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "yellow-magenta-form-production"},
      {type = "unlock-recipe", recipe = "anecdotal-data-reprocessing"},
    },
    prerequisites = {"gleba-conciliation", "gleba-pentapod-formations", "fulgora-digital-services", "archive-recombination", "agricultural-science-pack", "electromagnetic-science-pack"},
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

  -- ============================================================
  -- TIER 5: AQUILO FAX NETWORK (cryogenic science, all 3 planet pairs)
  -- ============================================================
  {
    type = "technology",
    name = "aquilo-fax-network",
    icon = "__administratorio__/graphics/icons/space-age/interplanetary-fax-exchange.png",
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
    icon = "__administratorio__/graphics/icons/space-age/fax-emitter.png",
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

  -- ============================================================
  -- TIER 5b: FAX QUEUE CAPACITY UPGRADES
  -- ============================================================
  {
    type = "technology",
    name = "fax-queue-capacity-1",
    icon = "__administratorio__/graphics/icons/cryogenic-operations-license.png",
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
    name = "fax-queue-capacity-2",
    icon = "__administratorio__/graphics/icons/trichromatic-permit.png",
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
    icon = "__administratorio__/graphics/icons/unified-operations-charter.png",
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

  -- ============================================================
  -- TIER 5c: BUREAUCRATIC TRANSCENDENCE (orbital train stops)
  -- ============================================================
  {
    type = "technology",
    name = "bureaucratic-transcendence",
    icon = "__administratorio__/graphics/icons/public-transportation-contract.png",
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

  -- ============================================================
  -- WORKFORCE FORMATION SPLIT: workers, management, specialists, orbital
  -- ============================================================

  -- T1: Basic Worker Formations (worker, clerical).  The existing
  -- formation-center technology remains the building gate: delaying it to
  -- executive review would cycle through union-delegate-training.
  {
    type = "technology",
    name = "worker-formation",
    icon = "__base__/graphics/technology/worker-robots-speed.png",
    icon_size = 256,
    effects = {
      {type = "unlock-recipe", recipe = "job-offer-production"},
      {type = "unlock-recipe", recipe = "worker-biter-formation"},
      {type = "unlock-recipe", recipe = "clerical-trainee-formation"},
    },
    prerequisites = {"formation-center", "space-science-pack"},
    unit = {
      count = 240,
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
    order = "h-j1",
  },

  -- T2: Management Formations (management trainee, middle-management)
  {
    type = "technology",
    name = "management-formation",
    icons = {
      {icon = "__base__/graphics/icons/medium-biter.png", icon_size = 64, tint = {r=0.45, g=0.55, b=1.0, a=1}},
      {icon = "__base__/graphics/icons/big-biter.png", icon_size = 64, scale = 0.4, shift = {8, 8}},
    },
    effects = {
      {type = "unlock-recipe", recipe = "management-trainee-formation"},
      {type = "unlock-recipe", recipe = "middle-management-managing-manager-formation"},
    },
    prerequisites = {"worker-formation", "union-delegate-training"},
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
    order = "h-j2",
  },

  -- T3: Specialized Formations (astronaut, licensed notary)
  {
    type = "technology",
    name = "specialized-formation",
    icons = {
      {icon = "__base__/graphics/icons/behemoth-biter.png", icon_size = 64, tint = {r=0.35, g=1.0, b=0.85, a=1}},
      {icon = "__administratorio__/graphics/icons/management-approval-written.png", icon_size = 64, scale = 0.4, shift = {8, 8}},
    },
    effects = {
      {type = "unlock-recipe", recipe = "astronaut-formation"},
      {type = "unlock-recipe", recipe = "licensed-notary-formation"},
    },
    prerequisites = {"management-formation", "vulcanus-certification"},
    unit = {
      count = 320,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"utility-science-pack", 1},
        {"space-science-pack", 1},
        {"metallurgic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-j3",
  },

  -- T4: Orbital Infrastructure (station, cannon, orbital forms, orbital science)
  {
    type = "technology",
    name = "orbital-employment-infrastructure",
    icon = "__administratorio__/graphics/icons/space-age/administrative-space-station.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "administrative-space-station"},
      {type = "unlock-recipe", recipe = "orbital-employment-cannon"},
      {type = "unlock-recipe", recipe = "trajectory-compliance-array"},
      {type = "unlock-recipe", recipe = "voluntary-exploration-space-miner-formation"},
      {type = "unlock-recipe", recipe = "orbital-operations-form"},
      {type = "unlock-recipe", recipe = "orbital-paper-production"},
      {type = "unlock-recipe", recipe = "orbital-ink-production"},
      {type = "unlock-recipe", recipe = "space-science-pack-orbital"},
      {type = "unlock-recipe", recipe = "orbital-deviation-order"},
      {type = "unlock-recipe", recipe = "asteroid-processing-docket"},
      {type = "unlock-recipe", recipe = "thermal-process-license-orbital"},
      {type = "unlock-recipe", recipe = "calcite-reagent-waiver-orbital"},
      {type = "unlock-recipe", recipe = "offworld-metallurgy-charter-orbital"},
    },
    prerequisites = {"specialized-formation", "cyan-yellow-bureaucracy", "cyan-magenta-bureaucracy", "yellow-magenta-bureaucracy"},
    unit = {
      count = 400,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"utility-science-pack", 1},
        {"space-science-pack", 1},
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 60,
    },
    order = "h-j4",
  },

  -- ============================================================
  -- TRAJECTORY COMPLIANCE JURISDICTION (array upgrades)
  -- ============================================================
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
    prerequisites = {"orbital-employment-infrastructure", "metallurgic-science-pack", "agricultural-science-pack", "electromagnetic-science-pack"},
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
    prerequisites = {"trajectory-compliance-jurisdiction-2", "quantum-processor"},
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

-- Trajectory compliance speed upgrades
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
    and {"orbital-employment-infrastructure"}
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

-- Orbital employment damage upgrades
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
    and {"orbital-employment-infrastructure"}
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

-- Orbital employment capacity upgrades
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
    and {"orbital-employment-infrastructure"}
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

-- Unlock orbital permit with space platform
add_tech_unlock("space-platform", "orbital-infrastructure-permit")
add_tech_unlock("calcite-processing", "dubious-data-analysis-vulcanus")
add_tech_unlock("calcite-processing", "paper-production-vulcanus")
add_tech_unlock("calcite-processing", "carbon-offset-certificate-basic-vulcanus")
add_tech_unlock("calcite-processing", "liquid-stimulant-production")
add_tech_unlock("calcite-processing", "liquid-coffee-vulcanus")
add_tech_unlock("calcite-processing", "plastic-bar-vulcanus")
add_tech_unlock("calcite-processing", "molten-promises-production")
add_tech_unlock("industrial-propaganda", "redundant-rubble-recovery-vulcanus")
add_tech_unlock("industrial-propaganda", "refined-nonsense-production-vulcanus")
add_tech_unlock("cyan-ink-production", "ink-recovery-fulgora")
add_tech_unlock("cyan-ink-production", "salvaged-data-analysis-fulgora")
add_tech_unlock("cyan-ink-production", "basic-excuse-production")
add_tech_unlock("cyan-ink-production", "carbon-offset-certificate-basic-fulgora")
add_tech_unlock("electromagnetic-plant", "salvage-electrolyte-fulgora")
add_tech_unlock("electromagnetic-plant", "electromagnetic-lubricant-fulgora")
add_tech_unlock("rocket-fuel", "electromagnetic-rocket-fuel-fulgora")
add_tech_unlock("agricultural-science-pack", "conciliation-officer-formation")
add_tech_unlock("electromagnetic-science-pack", "relay-clerk-formation")
add_tech_unlock("cryogenic-science-pack", "cryoprint-technician-formation")
add_tech_unlock("worker-formation", "capture-bureau-workforce")
add_tech_unlock("worker-formation", "workforce-lure-spores-production")
for _, briefing in ipairs(manager_briefings.BRIEFINGS) do
  add_tech_unlock("management-formation", briefing.recipe)
end
add_tech_unlock("cyan-yellow-bureaucracy", "small-spitter-space-tourism")
add_tech_unlock("cyan-yellow-bureaucracy", "medium-spitter-space-tourism")
add_tech_unlock("cyan-yellow-bureaucracy", "big-spitter-space-tourism")
add_tech_unlock("cyan-yellow-bureaucracy", "behemoth-spitter-space-tourism")
add_tech_unlock("cyan-yellow-bureaucracy", "tourism-lure-spores-production")

for _, recipe_name in ipairs({
  "orbital-archival-paper-production",
  "orbital-secure-ink-production",
  "orbital-operations-form-copying",
  "asteroid-processing-docket-copying",
  "priority-orbital-deviation-order",
}) do
  add_tech_unlock("advanced-asteroid-processing", recipe_name)
end

-- Chromatic printing is landing preparation — require it before each planet discovery
for _, planet_name in ipairs({"vulcanus", "gleba", "fulgora"}) do
  add_tech_prerequisite("planet-discovery-" .. planet_name, "chromatic-printing")
end

for item_name in pairs(fax_shared.FAX_DOCUMENTS) do
  add_tech_unlock(
    fax_shared.reconstruction_unlock_technology(item_name),
    fax_shared.reconstruction_recipe_name(item_name)
  )
end

require("prototypes.technology.fulgora_archives")
