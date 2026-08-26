local feature_flags = require("feature_flags")
local manager_briefings = require("prototypes.shared.manager_briefings")
local working_hours_enabled = feature_flags.working_hours_enabled()

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

local function remove_tech_unlock(technology_name, recipe_name)
  local technology = data.raw["technology"] and data.raw["technology"][technology_name]
  if not technology or not technology.effects then return end
  for index = #technology.effects, 1, -1 do
    local effect = technology.effects[index]
    if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
      table.remove(technology.effects, index)
    end
  end
end

local function add_tech_science_pack(technology_name, pack_name, amount)
  local technology = data.raw.technology and data.raw.technology[technology_name]
  if not technology or not technology.unit or not technology.unit.ingredients then return end

  for _, ingredient in ipairs(technology.unit.ingredients) do
    if (ingredient.name or ingredient[1]) == pack_name then return end
  end

  table.insert(technology.unit.ingredients, {pack_name, amount or 1})
end

data:extend({
  -- ============================================================
  -- TIER 0: CHROMATIC LANDING PREP (pre-planet, Nauvis research)
  -- Unlocks only the shared printer. Each colored chain belongs to the planet
  -- that supplies its pigment and is deliberately bootstrapped before that
  -- planet's science pack.
  -- ============================================================
  {
    type = "technology",
    name = "chromatic-printing",
    icon = "__administratorio__/graphics/icons/space-age/chromatic-printer.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "chromatic-printer"},
      {type = "unlock-recipe", recipe = "liquid-black-ink"},
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
  -- TIER 1: VULCANUS CERTIFICATION BOOTSTRAP
  -- The notary is required to build the first foundry, so certification must
  -- be completed with pre-planet science after the local cyan process exists.
  -- ============================================================
  {
    type = "technology",
    name = "vulcanus-certification",
    icon = "__administratorio__/graphics/icons/space-age/notary-office.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "notary-office"},
      {type = "unlock-recipe", recipe = "territorial-arbitration-post"},
      {type = "unlock-recipe", recipe = "licensed-notary-formation"},
      {type = "unlock-recipe", recipe = "embossed-seal"},
      {type = "unlock-recipe", recipe = "industrial-charter"},
      {type = "unlock-recipe", recipe = "territorial-resettlement-order"},
      {type = "unlock-recipe", recipe = "vulcanus-lie-distillation"},
    },
    prerequisites = {"cyan-ink-production", "tungsten-carbide", "management-formation"},
    unit = {
      count = 260,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"production-science-pack", 1},
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
    name = "vulcanus-export-charters",
    icon = "__administratorio__/graphics/icons/space-age/territorial-arbitration-post.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "thermal-process-license"},
      {type = "unlock-recipe", recipe = "calcite-reagent-waiver"},
      {type = "unlock-recipe", recipe = "offworld-metallurgy-charter"},
      {type = "unlock-recipe", recipe = "thermal-process-license-orbital"},
      {type = "unlock-recipe", recipe = "calcite-reagent-waiver-orbital"},
      {type = "unlock-recipe", recipe = "offworld-metallurgy-charter-orbital"},
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
    order = "h-b2",
  },

  -- ============================================================
  -- TIER 1b: VULCANUS CYAN BOOTSTRAP
  -- Mining the local pigment unlocks everything needed to certify tungsten.
  -- This must precede metallurgic science because tungsten-consuming recipes
  -- receive a cyan-form gate during final fixes.
  -- ============================================================
  {
    type = "technology",
    name = "cyan-ink-production",
    icon = "__administratorio__/graphics/icons/signal-form-stock.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "cyan-slurry-production"},
      {type = "unlock-recipe", recipe = "cyan-ink-production"},
      {type = "unlock-recipe", recipe = "heatproof-form-stock"},
      {type = "unlock-recipe", recipe = "blank-cyan-form-production"},
      {type = "unlock-recipe", recipe = "permit-draft"},
      {type = "unlock-recipe", recipe = "inspection-docket"},
    },
    prerequisites = {"planet-discovery-vulcanus"},
    research_trigger = {
      type = "mine-entity",
      entity = "verdigris-crust",
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
    icon = "__administratorio__/graphics/icons/amber-sap.png",
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
  -- TIER 2a: GLEBA CONCILIATION BOOTSTRAP
  -- Capture Bureau egg harvesting, its lure, and its specialist must all exist
  -- before agricultural science, whose recipe consumes pentapod eggs.
  -- ============================================================
  {
    type = "technology",
    name = "gleba-conciliation",
    icon = "__administratorio__/graphics/icons/space-age/conciliation-desk.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "capture-bureau"},
      {type = "unlock-recipe", recipe = "capture-bureau-pentapod-eggs"},
      {type = "unlock-recipe", recipe = "conciliation-desk"},
      {type = "unlock-recipe", recipe = "conciliation-officer-formation"},
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
    prerequisites = {"amber-sap-processing", "management-formation"},
    unit = {
      count = 220,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"production-science-pack", 1},
        {"utility-science-pack", 1},
        {"space-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-c",
  },

  -- ============================================================
  -- TIER 3a: FULGORA MAGENTA BOOTSTRAP
  -- Scrap yields the first charged toner. The resulting magenta form must be
  -- available before holmium infrastructure and electromagnetic science.
  -- ============================================================
  {
    type = "technology",
    name = "fulgora-salvage-administration",
    icon = "__administratorio__/graphics/icons/blank-magenta-form.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "charged-toner"},
      {type = "unlock-recipe", recipe = "archive-rubble-recovery"},
      {type = "unlock-recipe", recipe = "archive-documentation-recovery"},
      {type = "unlock-recipe", recipe = "magenta-ink-production"},
      {type = "unlock-recipe", recipe = "signal-form-stock"},
      {type = "unlock-recipe", recipe = "blank-magenta-form-production"},
      {type = "unlock-recipe", recipe = "archive-recovery-permit"},
      {type = "unlock-recipe", recipe = "ink-recovery-fulgora"},
      {type = "unlock-recipe", recipe = "salvaged-data-analysis-fulgora"},
      {type = "unlock-recipe", recipe = "carbon-offset-certificate-basic-fulgora"},
      {type = "unlock-recipe", recipe = "relay-clerk-formation"},
    },
    prerequisites = {"planet-discovery-fulgora", "management-formation"},
    research_trigger = {
      type = "craft-item",
      item = "charged-toner",
      count = 1,
    },
    order = "h-c3",
  },

  -- ============================================================
  -- TIER 3b: FULGORA DIGITAL SERVICES (electromagnetic science)
  -- ============================================================
  {
    type = "technology",
    name = "fulgora-digital-services",
    icon = "__administratorio__/graphics/icons/space-age/digital-services-bureau.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "digital-services-bureau"},
      {type = "unlock-recipe", recipe = "digital-processing-certificate"},
      {type = "unlock-recipe", recipe = "electromagnetic-operating-license"},
      {type = "unlock-recipe", recipe = "data-recovery-order"},
    },
    prerequisites = {"fulgora-salvage-administration", "electromagnetic-science-pack"},
    unit = {
      count = 260,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"production-science-pack", 1},
        {"utility-science-pack", 1},
        {"space-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
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
    prerequisites = {"vulcanus-certification", "vulcanus-export-charters", "gleba-conciliation", "cyan-ink-production", "metallurgic-science-pack", "agricultural-science-pack"},
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
    prerequisites = {"gleba-conciliation", "fulgora-digital-services", "archive-recombination", "agricultural-science-pack", "electromagnetic-science-pack"},
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
  -- TIER 5a: AQUILO CRYOGENIC ADMINISTRATION BOOTSTRAP
  -- The laser printer, technician, transfer stock, and operating license are
  -- prerequisites of the staffed Cryogenic Plant, so none may use its science.
  -- ============================================================
  {
    type = "technology",
    name = "aquilo-cryogenic-administration",
    icon = "__administratorio__/graphics/icons/cryogenic-operations-license.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "laser-printer"},
      {type = "unlock-recipe", recipe = "transfer-emulsion-production"},
      {type = "unlock-recipe", recipe = "thermal-transfer-sheet-production"},
      {type = "unlock-recipe", recipe = "cryogenic-operations-license-production"},
      {type = "unlock-recipe", recipe = "cryoprint-technician-formation"},
    },
    prerequisites = {"lithium-processing", "cyan-yellow-bureaucracy", "management-formation"},
    unit = {
      count = 360,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"production-science-pack", 1},
        {"utility-science-pack", 1},
        {"space-science-pack", 1},
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 60,
    },
    order = "h-f0",
  },

  -- ============================================================
  -- TIER 5b: AQUILO CHROMATIC TUBE TIER (cryogenic science, all 3 planet pairs)
  -- ============================================================
  {
    type = "technology",
    name = "interplanetary-tube-chromatic",
    icon = "__administratorio__/graphics/entities/pneumatic/outtake-icon.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "composite-chroma-ribbon-production"},
      {type = "unlock-recipe", recipe = "trichromatic-permit-production"},
      {type = "unlock-recipe", recipe = "unified-operations-charter-production"},
      {type = "unlock-recipe", recipe = "promethium-research-charter-production"},
    },
    prerequisites = {"aquilo-cryogenic-administration", "cyan-magenta-bureaucracy", "yellow-magenta-bureaucracy", "cryogenic-science-pack", "interplanetary-tube-network"},
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
    prerequisites = {"interplanetary-tube-chromatic"},
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

  -- T1: Basic Worker Formation.  The existing
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
    },
    -- Basic workers are the bootstrap for specialist training and must be
    -- available before the bureaucracy/oil chain.  Keeping this at the
    -- Formation Center plus the credential chain.  The first formation uses
    -- basic-excuse rather than the later good-excuse chain so this remains a
    -- finite bootstrap.
    prerequisites = {"formation-center", "industrial-propaganda"},
    unit = {
      count = 240,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
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
      {type = "unlock-recipe", recipe = "clerical-trainee-formation"},
      {type = "unlock-recipe", recipe = "management-trainee-formation"},
      {type = "unlock-recipe", recipe = "middle-management-managing-manager-formation"},
    },
    -- The orbital briefing is one of this tech's unlocks, so its rocket-fuel
    -- input must be researched before the card becomes available.
    prerequisites = {"worker-formation", "union-delegate-training", "eminent-domain-zoning", "rocket-fuel"},
    unit = {
      count = 280,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"production-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-j2",
  },

  -- T3: Orbital Specialist Formation. Planet specialists live with the
  -- matching planet technology instead of making basic spaceflight depend on
  -- a completed planetary branch.
  {
    type = "technology",
    name = "specialized-formation",
    icons = {
      {icon = "__base__/graphics/icons/behemoth-biter.png", icon_size = 64, tint = {r=0.35, g=1.0, b=0.85, a=1}},
      {icon = "__administratorio__/graphics/icons/management-approval-written.png", icon_size = 64, scale = 0.4, shift = {8, 8}},
    },
    effects = {
      {type = "unlock-recipe", recipe = "astronaut-formation"},
    },
    prerequisites = {"management-formation", "space-platform"},
    unit = {
      count = 320,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"production-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-j3",
  },

  -- T4: Orbital Administration. This is the first platform office and must
  -- remain researchable before either utility or space science. Native space
  -- science consumes research approvals imported from a planet.
  {
    type = "technology",
    name = "orbital-employment-infrastructure",
    icon = "__administratorio__/graphics/icons/space-age/administrative-space-station.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "administrative-space-station"},
      {type = "unlock-recipe", recipe = "orbital-operations-form"},
      {type = "unlock-recipe", recipe = "orbital-paper-production"},
      {type = "unlock-recipe", recipe = "orbital-ink-production"},
      {type = "unlock-recipe", recipe = "asteroid-processing-docket"},
    },
    prerequisites = {"specialized-formation"},
    unit = {
      count = 400,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"production-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 60,
    },
    order = "h-j4",
  },

  -- T5: Platform Compliance and Employment. These systems are deliberately
  -- separate from the station bootstrap and are mandatory before propulsion.
  {
    type = "technology",
    name = "orbital-compliance-systems",
    icon = "__base__/graphics/icons/radar.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "trajectory-compliance-array"},
      {type = "unlock-recipe", recipe = "orbital-deviation-order"},
      {type = "unlock-recipe", recipe = "orbital-employment-catapult"},
      {type = "unlock-recipe", recipe = "voluntary-exploration-space-miner-formation"},
    },
    prerequisites = {"orbital-employment-infrastructure"},
    unit = {
      count = 300,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"production-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-j5",
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
    prerequisites = {"orbital-compliance-systems", "metallurgic-science-pack", "agricultural-science-pack", "electromagnetic-science-pack", "carbon-fiber"},
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
  {"production-science-pack", 1},
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
    and {"orbital-compliance-systems", "space-science-pack"}
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
    and {"orbital-compliance-systems", "space-science-pack"}
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
    and {"orbital-compliance-systems", "space-science-pack"}
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

-- Keep Space Age's native promethium prototype IDs for compatibility while
-- making the visible Administratorium tier the culmination of Administratorio's
-- interplanetary bureaucracy. The charter travels the Aquilo chromatic tube
-- tier, so the expedition technology must not bypass that administrative branch.
add_tech_prerequisite("promethium-science-pack", "interplanetary-tube-chromatic")
add_tech_science_pack("promethium-science-pack", "administrative-science-pack", 1)

-- Unlock orbital permit with space platform
add_tech_unlock("space-platform", "orbital-infrastructure-permit")

-- Vanilla's coal-synthesis is normally unlocked by rocket-turret, which
-- military_hiding.lua hides along with every other combat technology. Move
-- its unlock onto carbon-fiber instead -- one of rocket-turret's own three
-- prerequisites, so it lands at approximately the same research tier the
-- recipe always sat at, just off a technology this mod actually keeps
-- visible.
add_tech_unlock("carbon-fiber", "coal-synthesis")
add_tech_prerequisite("foundry", "vulcanus-certification")
add_tech_prerequisite("big-mining-drill", "electric-engine")
add_tech_prerequisite("biochamber", "gleba-conciliation")
add_tech_prerequisite("electromagnetic-plant", "fulgora-salvage-administration")
add_tech_prerequisite("space-platform", "electric-engine")
add_tech_prerequisite("space-science-pack", "orbital-employment-infrastructure")
add_tech_prerequisite("orbital-compliance-systems", "radar")
add_tech_prerequisite("orbital-compliance-systems", "electric-mining-drill")
add_tech_prerequisite("space-platform-thruster", "orbital-compliance-systems")
add_tech_prerequisite("management-formation", "repair-pack")
-- Quantum processing and the senior trajectory array both consume carbon
-- fiber. Keep its recipe researchable before either downstream machine path.
add_tech_prerequisite("quantum-processor", "carbon-fiber")
add_tech_prerequisite("metallurgic-science-pack", "cyan-ink-production")
add_tech_prerequisite("agricultural-science-pack", "gleba-conciliation")
add_tech_prerequisite("electromagnetic-science-pack", "fulgora-salvage-administration")
add_tech_prerequisite("cryogenic-plant", "aquilo-cryogenic-administration")
add_tech_unlock("calcite-processing", "dubious-data-analysis-vulcanus")
add_tech_unlock("calcite-processing", "paper-production-vulcanus")
add_tech_unlock("calcite-processing", "carbon-offset-certificate-basic-vulcanus")
add_tech_unlock("calcite-processing", "liquid-stimulant-production")
add_tech_unlock("calcite-processing", "liquid-coffee-vulcanus")
add_tech_unlock("calcite-processing", "plastic-bar-vulcanus")
add_tech_unlock("calcite-processing", "molten-promises-production")
add_tech_unlock("industrial-propaganda", "redundant-rubble-recovery-vulcanus")
add_tech_unlock("industrial-propaganda", "refined-nonsense-production-vulcanus")
add_tech_unlock("electromagnetic-plant", "salvage-electrolyte-fulgora")
add_tech_unlock("electromagnetic-plant", "electromagnetic-lubricant-fulgora")
add_tech_unlock("rocket-fuel", "electromagnetic-rocket-fuel-fulgora")
add_tech_unlock("gleba-conciliation", "capture-bureau-workforce")
add_tech_unlock("biochamber", "workforce-lure-spores-production")
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

require("prototypes.technology.fulgora_archives")

-- ============================================================
-- INTERPLANETARY TUBE TRUNK
--
-- A separate, narrow, slow pool from the local pneumatic network. Two ladders
-- are read together: each tier raises capacity and cuts per-item transit.
-- The base tier opens at capacity 3 rather than 1 on purpose — a single
-- in-flight document empire-wide reads as a broken machine, not as scarcity.
-- ============================================================
local interplanetary_payloads = require("prototypes.shared.interplanetary_payloads")
local trunk_tint = {r = 0.85, g = 0.75, b = 0.55, a = 1}
local trunk_icon = "__administratorio__/graphics/entities/pneumatic/outtake-icon.png"

local function dispatch_unlocks(item_names)
  local effects = {}
  local sorted = {}
  for _, item_name in ipairs(item_names) do sorted[#sorted + 1] = item_name end
  table.sort(sorted)
  for _, item_name in ipairs(sorted) do
    effects[#effects + 1] = {
      type = "unlock-recipe",
      recipe = interplanetary_payloads.dispatch_recipe_name(item_name),
    }
  end
  return effects
end

local base_trunk_effects = {{type = "unlock-recipe", recipe = "interplanetary-terminus"}}
for _, effect in ipairs(dispatch_unlocks(interplanetary_payloads.regular)) do
  base_trunk_effects[#base_trunk_effects + 1] = effect
end

data:extend({
  {
    type = "technology",
    name = "interplanetary-tube-network",
    icon = "__administratorio__/graphics/icons/space-age/interplanetary-terminus.png",
    icon_size = 64,
    effects = base_trunk_effects,
    prerequisites = {"pneumatic-capacity-2", "cyan-yellow-bureaucracy"},
    unit = {
      count = 250,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-t",
  },
})

-- The chromatic tier adds the colored set on Aquilo. Colored paperwork never
-- crosses the base trunk.
for _, effect in ipairs(dispatch_unlocks(interplanetary_payloads.chromatic)) do
  add_tech_unlock("interplanetary-tube-chromatic", effect.recipe)
end

local trunk_capacity_packs = {
  {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"production-science-pack", 1}, {"administrative-science-pack", 1}},
  {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"production-science-pack", 1}, {"utility-science-pack", 1}, {"administrative-science-pack", 1}},
  {{"metallurgic-science-pack", 1}, {"agricultural-science-pack", 1}, {"electromagnetic-science-pack", 1}, {"cryogenic-science-pack", 1}, {"administrative-science-pack", 1}},
  {{"metallurgic-science-pack", 1}, {"agricultural-science-pack", 1}, {"electromagnetic-science-pack", 1}, {"cryogenic-science-pack", 1}, {"promethium-science-pack", 1}, {"administrative-science-pack", 1}},
}
local trunk_capacity_counts = {200, 350, 500, 750}
local trunk_capacity_extra_prereqs = {
  "production-science-pack",
  "utility-science-pack",
  "interplanetary-tube-chromatic",
  "promethium-science-pack",
}
local trunk_capacity_values = {5, 10, 15, 20}
local trunk_transit_seconds = {15, 5, 2, 1}

local trunk_capacity_techs = {}
for level = 2, 5 do
  local index = level - 1
  local prerequisites = {
    level == 2 and "interplanetary-tube-network" or ("interplanetary-tube-capacity-" .. (level - 1)),
    trunk_capacity_extra_prereqs[index],
  }

  trunk_capacity_techs[#trunk_capacity_techs + 1] = {
    type = "technology",
    name = "interplanetary-tube-capacity-" .. level,
    icons = {
      {icon = trunk_icon, icon_size = 64, tint = trunk_tint},
      {icon = "__base__/graphics/icons/signal/signal_" .. level .. ".png", icon_size = 64, scale = 0.35, shift = {8, 8}},
    },
    effects = {
      {type = "nothing", effect_description = {"technology-effect.interplanetary-tube-capacity",
        tostring(trunk_capacity_values[index]), tostring(trunk_transit_seconds[index])}},
    },
    prerequisites = prerequisites,
    unit = {
      count = trunk_capacity_counts[index],
      ingredients = trunk_capacity_packs[index],
      time = 60,
    },
    order = "h-t[" .. string.format("%02d", level) .. "]",
    upgrade = true,
  }
end

data:extend(trunk_capacity_techs)

-- One additional Terminus per planet per step, for players who want more
-- parallel throughput on a single world instead of a wider empire. A three-
-- tier climb -- the three base planet sciences, then all four, then an
-- infinite Administratorium-scale indulgence -- ending in an unbounded tech
-- so the ceiling is deliberately never fixed.
local terminus_additional_tint = trunk_tint
local terminus_additional_icon = trunk_icon

data:extend({
  {
    type = "technology",
    name = "interplanetary-tube-additional-terminus-1",
    icons = {
      {icon = terminus_additional_icon, icon_size = 64, tint = terminus_additional_tint},
      {icon = "__base__/graphics/icons/signal/signal_1.png", icon_size = 64, scale = 0.35, shift = {8, 8}},
    },
    effects = {
      {type = "nothing", effect_description = {"technology-effect.interplanetary-tube-additional-terminus"}},
    },
    prerequisites = {"interplanetary-tube-capacity-5"},
    unit = {
      count = 2000,
      ingredients = {
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"electromagnetic-science-pack", 1},
      },
      time = 90,
    },
    upgrade = true,
    order = "h-t[06]",
  },
  {
    type = "technology",
    name = "interplanetary-tube-additional-terminus-2",
    icons = {
      {icon = terminus_additional_icon, icon_size = 64, tint = terminus_additional_tint},
      {icon = "__base__/graphics/icons/signal/signal_2.png", icon_size = 64, scale = 0.35, shift = {8, 8}},
    },
    effects = {
      {type = "nothing", effect_description = {"technology-effect.interplanetary-tube-additional-terminus"}},
    },
    prerequisites = {"interplanetary-tube-additional-terminus-1"},
    unit = {
      count = 4000,
      ingredients = {
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"cryogenic-science-pack", 1},
      },
      time = 90,
    },
    upgrade = true,
    order = "h-t[07]",
  },
  {
    type = "technology",
    name = "interplanetary-tube-additional-terminus-3",
    icons = {{icon = terminus_additional_icon, icon_size = 64, tint = terminus_additional_tint}},
    effects = {
      {type = "nothing", effect_description = {"technology-effect.interplanetary-tube-additional-terminus"}},
    },
    prerequisites = {"interplanetary-tube-additional-terminus-2"},
    unit = {
      count_formula = "4000*2^(L-3)",
      ingredients = {
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"cryogenic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 90,
    },
    max_level = "infinite",
    upgrade = true,
    order = "h-t[08]",
  },
})

-- ============================================================
-- AI SERVERS AND THE SLOP ECONOMY
--
-- Slop unlocks are read straight from the taxonomy so a document added there is
-- covered without touching this file. Colored paperwork is never producible
-- from slop at any tier: that is what preserves the ink economy, the chromatic
-- printer chain, and the planetary import loop.
-- ============================================================
local slop_rules = require("prototypes.shared.slop_rules")

local function slop_unlocks(tier)
  local effects = {}
  for _, item_name in ipairs(slop_rules.documents_for_tier(tier)) do
    effects[#effects + 1] = {type = "unlock-recipe", recipe = slop_rules.recipe_name(item_name)}
  end
  return effects
end

local ai_inference_effects = {
  {type = "unlock-recipe", recipe = "ai-server"},
  {type = "unlock-recipe", recipe = "slop-refinery"},
  {type = "unlock-recipe", recipe = "heat-exhaust"},
  {type = "unlock-recipe", recipe = "optical-fibre"},
  {type = "unlock-recipe", recipe = "inference-token-production"},
  {type = "unlock-recipe", recipe = "administrative-slop-production"},
  {type = "unlock-recipe", recipe = "fabricated-citations-venting"},
  {type = "unlock-recipe", recipe = "fabricated-citations-fact-check-data"},
  {type = "unlock-recipe", recipe = "fabricated-citations-fact-check-documentation"},
}
for _, effect in ipairs(slop_unlocks("base")) do
  ai_inference_effects[#ai_inference_effects + 1] = effect
end

data:extend({
  {
    type = "technology",
    name = "aquilo-ai-inference",
    icon = "__administratorio__/graphics/icons/ai-server.png",
    icon_size = 64,
    effects = ai_inference_effects,
    prerequisites = {"aquilo-cryogenic-administration", "cryogenic-science-pack"},
    unit = {
      count = 600,
      ingredients = {
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"cryogenic-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 60,
    },
    order = "h-u",
  },
  {
    type = "technology",
    name = "administratorium-slop-synthesis",
    icon = "__administratorio__/graphics/icons/slop-refinery.png",
    icon_size = 64,
    effects = slop_unlocks("advanced"),
    prerequisites = {"aquilo-ai-inference", "promethium-science-pack"},
    unit = {
      count = 1000,
      ingredients = {
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"cryogenic-science-pack", 1},
        {"promethium-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 60,
    },
    order = "h-u[02]",
  },
})

-- ============================================================
-- UNSTAFFED OPERATIONS WAIVER
--
-- Authorises the five biter-station managed buildings to run without a
-- dispatched worker. Gated behind tricolor paperwork, so the authorisation
-- costs one form from every planetary jurisdiction at once.
-- ============================================================
if working_hours_enabled then
  data:extend({
    {
      type = "technology",
      name = "unstaffed-operations",
      icon = "__administratorio__/graphics/technology/unstaffed-operations-waiver.png",
      icon_size = 64,
      effects = {
        {type = "unlock-recipe", recipe = "unstaffed-operations-waiver"},
      },
      prerequisites = {"interplanetary-tube-chromatic", "public-finance", "quantum-processor"},
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
      order = "h-v",
    },
  })
end

-- ============================================================
-- SYNTHETIC PERSONNEL BUREAU
--
-- Unlocks are derived from the same specialist table the planet buildings use,
-- so a profession added there is covered here without touching this file.
-- ============================================================
local synthetic_personnel_effects = {
  {type = "unlock-recipe", recipe = "synthetic-personnel-bureau"},
}
for _, specialist_name in ipairs({
  "conciliation-officer",
  "cryoprint-technician",
  "licensed-notary",
  "relay-clerk",
}) do
  synthetic_personnel_effects[#synthetic_personnel_effects + 1] =
    {type = "unlock-recipe", recipe = specialist_name .. "-synthesis"}
end

data:extend({
  {
    type = "technology",
    name = "synthetic-personnel",
    icon = "__administratorio__/graphics/icons/synthetic-personnel-bureau.png",
    icon_size = 64,
    effects = synthetic_personnel_effects,
    prerequisites = {"aquilo-ai-inference", "promethium-science-pack", "quantum-processor"},
    unit = {
      count = 900,
      ingredients = {
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"cryogenic-science-pack", 1},
        {"promethium-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 60,
    },
    order = "h-w",
  },
})

-- ============================================================
-- EGG COURIERS
--
-- Biter eggs never leave Nauvis. Couriers are trained there and carry the
-- authorisation offworld in their place.
-- ============================================================
local manager_couriers = require("prototypes.shared.manager_couriers")

local courier_effects = {}
for _, courier in ipairs(manager_couriers.COURIERS) do
  courier_effects[#courier_effects + 1] = {type = "unlock-recipe", recipe = courier.recipe}
end

data:extend({
  {
    type = "technology",
    name = "egg-courier-formation",
    icon = "__space-age__/graphics/icons/biter-egg.png",
    icon_size = 64,
    effects = courier_effects,
    prerequisites = {
      "management-formation",
      "planet-discovery-gleba",
      "agricultural-science-pack",
      "biter-egg-handling",
    },
    unit = {
      count = 300,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-x",
  },
})

-- The Administratorium expedition cannot be attempted before couriers exist:
-- its science pack recipe consumes one.
add_tech_prerequisite("promethium-science-pack", "egg-courier-formation")

-- ============================================================
-- INVOLUNTARY RELOCATION CANNON
--
-- Must be available before the captive biter spawner is buildable, so the
-- 30-minute Missionary window is survivable by design rather than by luck.
-- The prerequisite is discovered from whichever technology unlocks the spawner
-- rather than hardcoded, so a vanilla retune cannot silently break the order.
-- ============================================================
local relocation_cargo = require("prototypes.shared.relocation_cargo")

local relocation_effects = {
  {type = "unlock-recipe", recipe = "involuntary-relocation-cannon"},
  {type = "unlock-recipe", recipe = "involuntary-relocation-receiver"},
  {type = "unlock-recipe", recipe = "involuntary-transfer-order-production"},
}
for _, item_name in ipairs(relocation_cargo.loadable_names()) do
  relocation_effects[#relocation_effects + 1] =
    {type = "unlock-recipe", recipe = relocation_cargo.load_recipe_name(item_name)}
end

data:extend({
  {
    type = "technology",
    name = "involuntary-relocation",
    icon = "__administratorio__/graphics/icons/relocation-cannon.png",
    icon_size = 64,
    effects = relocation_effects,
    prerequisites = {
      "egg-courier-formation",
      "vulcanus-certification",
      "tungsten-steel",
      "metallurgic-science-pack",
      "agricultural-science-pack",
    },
    unit = {
      count = 400,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"metallurgic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-y",
  },
})

-- In Space Age the employment office cannot make a resolution office until
-- the Formation Center has produced the first machine-usable worker.  Keep
-- the office unlock aligned with that actual provider instead of exposing a
-- recipe that is impossible to craft at biter-employment.
remove_tech_unlock("biter-employment", "resolution-office")
add_tech_unlock("worker-formation", "resolution-office")

for technology_name, technology in pairs(data.raw.technology or {}) do
  if technology_name ~= "involuntary-relocation" then
    for _, effect in ipairs(technology.effects or {}) do
      if effect.type == "unlock-recipe" and effect.recipe == "captive-biter-spawner" then
        add_tech_prerequisite(technology_name, "involuntary-relocation")
        break
      end
    end
  end
end
