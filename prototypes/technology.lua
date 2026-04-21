local feature_flags = require("feature_flags")
local shared = require("prototypes.shared")
local working_hours_enabled = feature_flags.working_hours_enabled()
local tech_icons = "__administratorio__/graphics/technology/"

local function pneumatic_form_transport_effects()
  local effects = {
    { type = "unlock-recipe", recipe = "pneumatic-pipe" },
    { type = "unlock-recipe", recipe = "pneumatic-pipe-to-ground" },
    { type = "unlock-recipe", recipe = "tube-intake" },
    { type = "unlock-recipe", recipe = "tube-outtake" },
  }

  local pneumatic_item_names = {}
  for item_name in pairs(shared.PNEUMATIC_ITEMS) do
    pneumatic_item_names[#pneumatic_item_names + 1] = item_name
  end
  table.sort(pneumatic_item_names)

  for _, item_name in ipairs(pneumatic_item_names) do
    effects[#effects + 1] = {
      type = "unlock-recipe",
      recipe = "pneumatic-intake-" .. item_name,
    }
  end

  return effects
end

data:extend({
  -- DISCOVERY: BULLSHIT (gate tech — mining bullshit ore unlocks the certificate supply chain)
  {
    type = "technology", name = "discovery-bullshit",
    icon = "__administratorio__/graphics/icons/bullshit-ore.png", icon_size = 64,
    effects = {
      { type = "unlock-recipe", recipe = "dubious-data-refining" },
      { type = "unlock-recipe", recipe = "basic-excuse-production" },
      { type = "unlock-recipe", recipe = "safety-waiver-draft" },
      { type = "unlock-recipe", recipe = "safety-waiver-printing" },
      { type = "unlock-recipe", recipe = "construction-permit-draft" },
      { type = "unlock-recipe", recipe = "construction-permit-printing" }
    },
    research_trigger = { type = "mine-entity", entity = "bullshit-ore" },
    order = "z-b"
  },
  -- DISCOVERY: RED TAPE
  {
    type = "technology", name = "discovery-redundant-rubble",
    icon = tech_icons .. "redundant-rubble.png", icon_size = 128,
    effects = {
      { type = "unlock-recipe", recipe = "provisional-approval-production" },
      { type = "unlock-recipe", recipe = "burner-mining-drill" }
    },
    research_trigger = { type = "mine-entity", entity = "redundant-rubble" },
    order = "z-c"
  },
  -- ADMINISTRATIVE SCIENCE (T0 — unlocks admin science packs)
  {
    type = "technology", name = "administrative-science-research",
    icon = "__administratorio__/graphics/icons/administrative-science-pack.png", icon_size = 256, icon_mipmaps = 4,
    effects = {
      { type = "unlock-recipe", recipe = "administrative-science-pack-production" }
    },
    prerequisites = {"automation"},
    unit = { count = 10, ingredients = {{"automation-science-pack", 1}}, time = 15 },
    order = "a-a"
  },
  -- PRINTING TECHNOLOGY (printer T1 + rubble derivatives for downstream use)
  {
    type = "technology", name = "printing-technology",
    icon = "__administratorio__/graphics/icons/ink-cartridge.png", icon_size = 64,
    effects = {
      { type = "unlock-recipe", recipe = "printer-t1" }
    },
    prerequisites = {"administrative-science-research"},
    unit = { count = 20, ingredients = {{"automation-science-pack", 1}, {"administrative-science-pack", 1}}, time = 15 },
    order = "a-c"
  },

  -- T1: WOOD PRODUCTION (red-science wood bootstrap)
  {
    type = "technology", name = "administrative-bureaucracy",
    icon = tech_icons .. "greenhouse.png", icon_size = 128,
    effects = {
      { type = "unlock-recipe", recipe = "greenhouse" },
      { type = "unlock-recipe", recipe = "greenhouse-wood" }
    },
    prerequisites = {"automation", "discovery-redundant-rubble"},
    unit = { count = 20, ingredients = {{"automation-science-pack", 1}}, time = 15 },
    order = "a"
  },
  -- LITTERING RESOLUTION (standalone — early complaint handling, red + admin only)
  {
    type = "technology", name = "littering-resolution",
    icon = tech_icons .. "littering-resolution.png", icon_size = 128,
    effects = {
      { type = "unlock-recipe", recipe = "crappy-report-production" },
      { type = "unlock-recipe", recipe = "filing-littering" },
      { type = "unlock-recipe", recipe = "littering-final" }
    },
    prerequisites = {"printing-technology"},
    unit = { count = 25, ingredients = {{"automation-science-pack", 1}, {"administrative-science-pack", 1}}, time = 20 },
    order = "a-l"
  },
  -- T2: INDUSTRIAL PRINTING (industrial printer + bulk copy infrastructure)
  {
    type = "technology", name = "industrial-printing",
    icon = "__administratorio__/graphics/icons/steel-forge-icon.png", icon_size = 64,
    effects = {
      { type = "unlock-recipe", recipe = "printer-t2" },
      { type = "unlock-recipe", recipe = "copy-blank-form" },
      { type = "unlock-recipe", recipe = "copy-blank-approval" },
      { type = "unlock-recipe", recipe = "copy-carbon-offset-certificate" },
      { type = "unlock-recipe", recipe = "copy-form-27b-6" },
      { type = "unlock-recipe", recipe = "copy-environmental-impact-report" }
    },
    prerequisites = {"administrative-bureaucracy", "steel-processing", "advanced-circuit", "chemical-science-pack"},
    unit = { count = 90, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "b"
  },
  -- T2b: LOCAL PRECEDENTS (legal boilerplate and standardized requisition forms)
  {
    type = "technology", name = "local-precedents",
    icon = tech_icons .. "local-precedents.png", icon_size = 256,
    effects = {
      { type = "unlock-recipe", recipe = "useless-documentation-production" },
      { type = "unlock-recipe", recipe = "form-27b-6" }
    },
    prerequisites = {"administrative-bureaucracy", "littering-resolution"},
    unit = { count = 60, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "b-b"
  },
  -- T2b2: NEST PACIFICATION (hush money — suppress spawner activity with taxpayer money)
  {
    type = "technology", name = "nest-pacification",
    icon = "__administratorio__/graphics/icons/hush-money-capsule.png", icon_size = 64,
    effects = {
      { type = "unlock-recipe", recipe = "hush-money-production" }
    },
    prerequisites = {"local-precedents"},
    unit = { count = 40, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 20 },
    order = "b-b2"
  },
  -- T2c: RUBBLE COMPACTION (shared processed material for multiple later branches)
  {
    type = "technology", name = "rubble-compaction",
    icon = "__administratorio__/graphics/icons/compacted-rubble.png", icon_size = 64,
    effects = {
      { type = "unlock-recipe", recipe = "compacted-rubble-production" }
    },
    prerequisites = {"printing-technology", "discovery-redundant-rubble"},
    unit = { count = 30, ingredients = {{"automation-science-pack", 1}, {"administrative-science-pack", 1}}, time = 20 },
    order = "b-d"
  },
  -- STREAMLINED WORK ORDERS (direct draft-to-work-order printing at T1/T2 printers)
  {
    type = "technology", name = "streamlined-work-orders",
    icon = tech_icons .. "streamlined-work-orders.png", icon_size = 128,
    effects = {
      { type = "unlock-recipe", recipe = "safety-work-order-printing" },
      { type = "unlock-recipe", recipe = "construction-work-order-printing" }
    },
    prerequisites = {"printing-technology", "logistic-science-pack", "rubble-compaction"},
    unit = { count = 50, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "b-a"
  },
  -- T3a: OFFICE AGRICULTURE (coffee propagation and charcoal built on greenhouse output)
  {
    type = "technology", name = "office-agriculture",
    icon = "__administratorio__/graphics/icons/coffee-bean.png", icon_size = 32,
    effects = {
      { type = "unlock-recipe", recipe = "coffee-plantation" }
    },
    prerequisites = {"corporate-hospitality", "fluid-handling"},
    unit = { count = 60, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "c-a"
  },
  -- T3a2: CHARCOAL PRODUCTION (regulated renewable coal from greenhouse wood)
  {
    type = "technology", name = "charcoal-production",
    icon = tech_icons .. "coal-production.png", icon_size = 179,
    effects = {
      { type = "unlock-recipe", recipe = "charcoal-production" }
    },
    prerequisites = {"corporate-hospitality", "fluid-handling"},
    unit = { count = 60, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "c-a2"
  },
  -- T3b: INDUSTRIAL PROPAGANDA (lies, nonsense, and credentials)
  {
    type = "technology", name = "industrial-propaganda",
    icon = "__administratorio__/graphics/icons/misinformation.png", icon_size = 64,
    effects = {
      { type = "unlock-recipe", recipe = "propaganda-distillery" },
      { type = "unlock-recipe", recipe = "politician-fluid-refining" },
      { type = "unlock-recipe", recipe = "misinformation-production" },
      { type = "unlock-recipe", recipe = "refined-nonsense-production" },
      { type = "unlock-recipe", recipe = "credentials-production" }
    },
    prerequisites = {"littering-resolution", "fluid-handling", "rubble-compaction"},
    unit = { count = 70, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "c-b"
  },
  -- T3c: CORPORATE HOSPITALITY (breakrooms, coffee, gossip, and office drama)
  {
    type = "technology", name = "corporate-hospitality",
    icon = "__administratorio__/graphics/icons/warehouse-icon.png", icon_size = 64,
    effects = {
      { type = "unlock-recipe", recipe = "corporate-breakroom" },
      { type = "unlock-recipe", recipe = "greenhouse-discovery" },
      { type = "unlock-recipe", recipe = "coffee-refining" },
      { type = "unlock-recipe", recipe = "watercooler-gossip-production" },
      { type = "unlock-recipe", recipe = "office-drama-recycling" }
    },
    prerequisites = {"administrative-bureaucracy"},
    unit = { count = 70, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "c-c"
  },
  -- T3d: INFORMATION MANAGEMENT (turn gossip and credentials into useful paperwork)
  {
    type = "technology", name = "information-management",
    icon = "__administratorio__/graphics/icons/data.png", icon_size = 64,
    effects = {
      { type = "unlock-recipe", recipe = "data-production" },
      { type = "unlock-recipe", recipe = "good-excuse-production" }
    },
    prerequisites = {"corporate-hospitality", "industrial-propaganda"},
    unit = { count = 85, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "c-d"
  },
  -- T3e: VERBAL APPROVALS (directives and informal management sign-off)
  {
    type = "technology", name = "verbal-approvals",
    icon = "__administratorio__/graphics/icons/management-approval-verbal.png", icon_size = 64,
    effects = {
      { type = "unlock-recipe", recipe = "blank-directive-production" },
      { type = "unlock-recipe", recipe = "copy-blank-directive" },
      { type = "unlock-recipe", recipe = "management-verbal-work-order-production" },
      { type = "unlock-recipe", recipe = "management-verbal-draft" },
      { type = "unlock-recipe", recipe = "management-verbal-printing" }
    },
    prerequisites = {"corporate-hospitality"},
    unit = { count = 80, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "c-e"
  },
  -- T4a: ENVIRONMENTAL COMPLIANCE
  -- Single environmental gate for reporting, certification, and operating permits.
  {
    type = "technology", name = "environmental-compliance",
    icon = tech_icons .. "environmental-compliance.png", icon_size = 256,
    effects = {
      { type = "unlock-recipe", recipe = "petrochemical-operating-permit-production" },
      { type = "unlock-recipe", recipe = "environmental-impact-report" },
      { type = "unlock-recipe", recipe = "chemical-handling-work-order-production" },
      { type = "unlock-recipe", recipe = "carbon-offset-certificate-verified" }
    },
    prerequisites = {"local-precedents", "fluid-handling", "steel-processing"},
    unit = { count = 95, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "d-a"
  },
  -- T4b: SMOG ABATEMENT (air-pollution complaint chain)
  {
    type = "technology", name = "smog-abatement",
    icon = tech_icons .. "smog-abatement.png", icon_size = 128,
    effects = {
      { type = "unlock-recipe", recipe = "filing-smog" },
      { type = "unlock-recipe", recipe = "case-smog" },
      { type = "unlock-recipe", recipe = "smog-final" }
    },
    prerequisites = {"environmental-compliance"},
    unit = { count = 90, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "d-b"
  },
  -- T4c: HAZMAT RESPONSE (hazard-material complaint chain)
  {
    type = "technology", name = "hazmat-response",
    icon = tech_icons .. "hazmat-response.png", icon_size = 128,
    effects = {
      { type = "unlock-recipe", recipe = "filing-hazmat" },
      { type = "unlock-recipe", recipe = "case-hazmat" },
      { type = "unlock-recipe", recipe = "hazmat-final" }
    },
    prerequisites = {"environmental-compliance"},
    unit = { count = 100, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "d-c"
  },
  -- T4d: NEST EXPROPRIATION (eviction notices for territorial expansion)
  {
    type = "technology", name = "nest-expropriation",
    icon = tech_icons .. "eviction-notice.png", icon_size = 256,
    effects = {
      { type = "unlock-recipe", recipe = "eviction-notice-production" }
    },
    prerequisites = {"information-management", "industrial-propaganda"},
    unit = { count = 90, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "d-d"
  },
  {
    type = "technology", name = "synthetic-stationery",
    icon = "__administratorio__/graphics/icons/paper.png", icon_size = 64,
    effects = {
      { type = "unlock-recipe", recipe = "synthetic-paper-production" }
    },
    prerequisites = {"environmental-compliance", "plastics", "sulfur-processing"},
    unit = { count = 120, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "c-d"
  },
  -- T5a: PUBLIC FINANCE (bonds, grants, and union institutions)
  {
    type = "technology", name = "public-finance",
    icon = tech_icons .. "public-finance.png", icon_size = 256,
    effects = {
      { type = "unlock-recipe", recipe = "treasury-bond-production" },
      { type = "unlock-recipe", recipe = "union-headquarters" },
      { type = "unlock-recipe", recipe = "union-approval-production" },
      { type = "unlock-recipe", recipe = "government-grant-production" }
    },
    prerequisites = {"verbal-approvals", "local-precedents", "advanced-circuit"},
    unit = { count = 145, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"administrative-science-pack", 1}}, time = 45 },
    order = "e-a"
  },
  -- T5b: HEALTH & SAFETY (OSHA cleanup, justification, and narrative control)
  {
    type = "technology", name = "health-and-safety",
    icon = tech_icons .. "health-and-safety.png", icon_size = 256,
    effects = {
      { type = "unlock-recipe", recipe = "justification-production" },
      { type = "unlock-recipe", recipe = "narrative-production" },
      { type = "unlock-recipe", recipe = "osha-scrubbing" },
      { type = "unlock-recipe", recipe = "osha-violation-recycling" }
    },
    prerequisites = {"public-finance", "information-management"},
    unit = { count = 150, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"administrative-science-pack", 1}}, time = 45 },
    order = "e-b"
  },
  -- T5c: BOARD MEETINGS (executive committee layer inside the Union HQ)
  {
    type = "technology", name = "board-meetings",
    icon = tech_icons .. "board-meetings.png", icon_size = 128,
    effects = {
      { type = "unlock-recipe", recipe = "management-written-proposal" },
      { type = "unlock-recipe", recipe = "management-written-1st-printing" }
    },
    prerequisites = {"public-finance", "health-and-safety"},
    unit = { count = 135, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"administrative-science-pack", 1}}, time = 45 },
    order = "e-c"
  },
  -- T6a: EXECUTIVE REVIEW (written approvals and signed directives)
  {
    type = "technology", name = "executive-review",
    icon = tech_icons .. "executive-review.png", icon_size = 128,
    effects = {
      { type = "unlock-recipe", recipe = "management-written-work-order-production" }
    },
    prerequisites = {"board-meetings", "health-and-safety"},
    unit = { count = 175, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"administrative-science-pack", 1}}, time = 45 },
    order = "f-a"
  },
  -- T6b: RADIOLOGICAL COMPLIANCE (centrifuge-family operating paperwork)
  {
    type = "technology", name = "radiological-compliance",
    icon = tech_icons .. "radiological-compliance.png", icon_size = 128,
    effects = {
      { type = "unlock-recipe", recipe = "radiological-work-order-production" }
    },
    prerequisites = {"executive-review", "environmental-compliance"},
    unit = { count = 160, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"administrative-science-pack", 1}}, time = 45 },
    order = "f-b"
  },
  -- T7a: EMINENT DOMAIN & ZONING (policy drafting and slush-fund planning)
  {
    type = "technology", name = "eminent-domain-zoning",
    icon = tech_icons .. "eminent-domain-zoning.png", icon_size = 256,
    effects = {
      { type = "unlock-recipe", recipe = "white-paper-production" },
      { type = "unlock-recipe", recipe = "policy-production" },
      { type = "unlock-recipe", recipe = "slush-fund-production" }
    },
    prerequisites = {"executive-review", "processing-unit"},
    unit = { count = 210, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"production-science-pack", 1}, {"administrative-science-pack", 1}}, time = 60 },
    order = "g-a"
  },
  -- T7b: WORK ORDER DUPLICATION (industrial printer copies every work-order family)
  {
    type = "technology", name = "work-order-duplication",
    icon = tech_icons .. "work-order-duplication.png", icon_size = 128,
    effects = {
      { type = "unlock-recipe", recipe = "copy-work-order" },
      { type = "unlock-recipe", recipe = "copy-safety-work-order" },
      { type = "unlock-recipe", recipe = "copy-construction-work-order" },
      { type = "unlock-recipe", recipe = "copy-management-verbal-work-order" },
      { type = "unlock-recipe", recipe = "copy-management-written-work-order" },
      { type = "unlock-recipe", recipe = "copy-research-grant-work-order" },
      { type = "unlock-recipe", recipe = "copy-chemical-handling-work-order" },
      { type = "unlock-recipe", recipe = "copy-radiological-work-order" }
    },
    prerequisites = {"industrial-printing", "radiological-compliance", "processing-unit", "production-science-pack"},
    unit = { count = 180, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"production-science-pack", 1}, {"administrative-science-pack", 1}}, time = 60 },
    order = "g-b"
  },
  -- T7c: FEDERAL REGULATION (codify policy into formal law)
  {
    type = "technology", name = "federal-regulation",
    icon = tech_icons .. "federal-regulation.png", icon_size = 128,
    effects = {
      { type = "unlock-recipe", recipe = "regulation-production" }
    },
    prerequisites = {"eminent-domain-zoning"},
    unit = { count = 175, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"production-science-pack", 1}, {"administrative-science-pack", 1}}, time = 60 },
    order = "g-c"
  },
  -- T7d: NOISE ORDINANCES (noise complaint resolution)
  {
    type = "technology", name = "noise-ordinances",
    icon = tech_icons .. "noise-ordinances.png", icon_size = 128,
    effects = {
      { type = "unlock-recipe", recipe = "filing-noise" },
      { type = "unlock-recipe", recipe = "case-noise" },
      { type = "unlock-recipe", recipe = "noise-final" }
    },
    prerequisites = {"eminent-domain-zoning", "environmental-compliance"},
    unit = { count = 185, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"production-science-pack", 1}, {"administrative-science-pack", 1}}, time = 60 },
    order = "g-d"
  },
  -- T7e: LOITERING ORDINANCES (loitering complaint resolution)
  {
    type = "technology", name = "loitering-ordinances",
    icon = tech_icons .. "loitering-ordinances.png", icon_size = 128,
    effects = {
      { type = "unlock-recipe", recipe = "filing-loitering" },
      { type = "unlock-recipe", recipe = "case-loitering" },
      { type = "unlock-recipe", recipe = "loitering-final" }
    },
    prerequisites = {"board-meetings"},
    unit = { count = 185, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"utility-science-pack", 1}, {"administrative-science-pack", 1}}, time = 60 },
    order = "g-e"
  },
  {
    type = "technology", name = "creative-accounting",
    icon = tech_icons .. "creative-accounting.png", icon_size = 256,
    effects = {
      { type = "unlock-recipe", recipe = "tax-audit" },
    },
    prerequisites = {"eminent-domain-zoning"},
    unit = { count = 175, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"production-science-pack", 1}, {"administrative-science-pack", 1}}, time = 60 },
    order = "f-y"
  },
  -- T8a: CONSTITUTIONAL LAW (unemployment resolution)
  {
    type = "technology", name = "constitutional-law",
    icon = tech_icons .. "constitutional-law.png", icon_size = 256,
    effects = {
      { type = "unlock-recipe", recipe = "filing-unemployment" },
      { type = "unlock-recipe", recipe = "case-unemployment" },
      { type = "unlock-recipe", recipe = "unemployment-final" }
    },
    prerequisites = {"federal-regulation"},
    unit = { count = 260, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"production-science-pack", 1}, {"administrative-science-pack", 1}}, time = 60 },
    order = "h-a"
  },
  -- T8b: VAGRANCY ORDINANCES (vagrancy complaint resolution)
  {
    type = "technology", name = "vagrancy-ordinances",
    icon = tech_icons .. "vagrancy-ordinances.png", icon_size = 128,
    effects = {
      { type = "unlock-recipe", recipe = "filing-vagrancy" },
      { type = "unlock-recipe", recipe = "case-vagrancy" },
      { type = "unlock-recipe", recipe = "vagrancy-final" }
    },
    prerequisites = {"constitutional-law"},
    unit = { count = 320, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"production-science-pack", 1}, {"utility-science-pack", 1}, {"administrative-science-pack", 1}}, time = 60 },
    order = "h-b"
  },
  -- PNEUMATIC FORM TRANSPORT (first green-science paperwork logistics)
  {
    type = "technology", name = "pneumatic-form-transport",
    icons = {{icon = "__base__/graphics/icons/pipe.png", icon_size = 64, tint = {r=0.85, g=0.75, b=0.55, a=1}}},
    effects = pneumatic_form_transport_effects(),
    prerequisites = {"printing-technology", "logistic-science-pack", "rubble-compaction"},
    unit = { count = 40, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 20 },
    order = "a-p"
  },
  -- BITER EMPLOYMENT (hire resolved biters as workers)
  {
    type = "technology", name = "biter-employment",
    icons = {{icon = "__administratorio__/graphics/icons/credentials.png", icon_size = 64, tint = {r=0.6, g=0.4, b=0.2, a=1}}},
    effects = {
      { type = "unlock-recipe", recipe = "job-offer-production" },
      { type = "unlock-recipe", recipe = "office-desk" },
      { type = "unlock-recipe", recipe = "biter-station" },
      { type = "unlock-recipe", recipe = "union-delegate-training" },
    },
    prerequisites = {"verbal-approvals", "local-precedents"},
    unit = { count = 120, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "c-h"
  },
  {
    type = "technology", name = "biter-labor-efficiency-1",
    icons = {{icon = "__administratorio__/graphics/icons/credentials.png", icon_size = 64, tint = {r=0.55, g=0.75, b=0.45, a=1}}},
    effects = {
      { type = "nothing" },
    },
    prerequisites = {"biter-employment"},
    unit = { count = 140, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "c-h1"
  },
  {
    type = "technology", name = "biter-labor-efficiency-2",
    icons = {{icon = "__administratorio__/graphics/icons/credentials.png", icon_size = 64, tint = {r=0.35, g=0.65, b=0.35, a=1}}},
    effects = {
      { type = "nothing" },
    },
    prerequisites = {"biter-labor-efficiency-1"},
    unit = { count = 220, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"administrative-science-pack", 1}}, time = 45 },
    order = "c-h2"
  },
  -- BITER STATION CAPACITY (unlock more inventory slots per station)
  {
    type = "technology", name = "biter-station-capacity-1",
    icons = {{icon = "__administratorio__/graphics/icons/credentials.png", icon_size = 64, tint = {r=0.7, g=0.5, b=0.9, a=1}}},
    effects = {{ type = "nothing" }},
    prerequisites = {"biter-employment"},
    unit = { count = 100, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 20 },
    order = "c-h3"
  },
  {
    type = "technology", name = "biter-station-capacity-2",
    icons = {{icon = "__administratorio__/graphics/icons/credentials.png", icon_size = 64, tint = {r=0.6, g=0.4, b=0.85, a=1}}},
    effects = {{ type = "nothing" }},
    prerequisites = {"biter-station-capacity-1"},
    unit = { count = 150, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "c-h4"
  },
  {
    type = "technology", name = "biter-station-capacity-3",
    icons = {{icon = "__administratorio__/graphics/icons/credentials.png", icon_size = 64, tint = {r=0.5, g=0.3, b=0.8, a=1}}},
    effects = {{ type = "nothing" }},
    prerequisites = {"biter-station-capacity-2"},
    unit = { count = 200, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"administrative-science-pack", 1}}, time = 40 },
    order = "c-h5"
  },
  {
    type = "technology", name = "biter-station-capacity-4",
    icons = {{icon = "__administratorio__/graphics/icons/credentials.png", icon_size = 64, tint = {r=0.4, g=0.2, b=0.75, a=1}}},
    effects = {{ type = "nothing" }},
    prerequisites = {"biter-station-capacity-3"},
    unit = { count = 300, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"production-science-pack", 1}, {"administrative-science-pack", 1}}, time = 50 },
    order = "c-h6"
  },
  -- SPECIALIST TRAINING (train workers into building-specific specialists)
  {
    type = "technology", name = "specialist-training",
    icons = {{icon = "__administratorio__/graphics/icons/credentials.png", icon_size = 64, tint = {r=0.2, g=0.9, b=0.7, a=1}}},
    effects = {
      { type = "unlock-recipe", recipe = "chemical-operator-training" },
      { type = "unlock-recipe", recipe = "nuclear-technician-training" },
    },
    prerequisites = {"biter-employment", "executive-review"},
    unit = { count = 200, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"production-science-pack", 1}, {"administrative-science-pack", 1}}, time = 60 },
    order = "f-h"
  },
})

-- PNEUMATIC CAPACITY UPGRADES (tube network max forms)
local pneumatic_capacity_techs = {}
local pneumatic_cap_packs = {
  {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}},
  {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"administrative-science-pack", 1}},
  {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"production-science-pack", 1}, {"administrative-science-pack", 1}},
}
local pneumatic_cap_counts = {60, 120, 200}
local pneumatic_cap_times = {20, 30, 45}
local pneumatic_cap_bonuses = {10, 30, 50}

for level = 1, 3 do
  local name = "pneumatic-capacity-" .. level
  local prerequisites = {}
  if level == 1 then
    prerequisites = {"pneumatic-form-transport"}
  else
    prerequisites = {"pneumatic-capacity-" .. (level - 1)}
  end
  if level == 2 then
    prerequisites[#prerequisites + 1] = "chemical-science-pack"
  elseif level == 3 then
    prerequisites[#prerequisites + 1] = "production-science-pack"
  end

  pneumatic_capacity_techs[#pneumatic_capacity_techs + 1] = {
    type = "technology",
    name = name,
    icons = {{icon = "__base__/graphics/icons/pipe.png", icon_size = 64, tint = {r=0.85, g=0.75, b=0.55, a=1}}},
    effects = {
      { type = "nothing", effect_description = {"technology-effect.pneumatic-capacity", tostring(pneumatic_cap_bonuses[level])} }
    },
    prerequisites = prerequisites,
    unit = {
      count = pneumatic_cap_counts[level],
      ingredients = pneumatic_cap_packs[level],
      time = pneumatic_cap_times[level],
    },
    order = "a-p[" .. string.format("%02d", level) .. "]",
    upgrade = true,
  }
end

data:extend(pneumatic_capacity_techs)

local admin_station_capacity_techs = {}
local capacity_pack_sets = {
  {{"automation-science-pack", 1}, {"administrative-science-pack", 1}},
  {{"automation-science-pack", 1}, {"administrative-science-pack", 1}},
  {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}},
  {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}},
  {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"administrative-science-pack", 1}},
  {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"administrative-science-pack", 1}},
  {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"production-science-pack", 1}, {"administrative-science-pack", 1}},
  {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"production-science-pack", 1}, {"utility-science-pack", 1}, {"administrative-science-pack", 1}},
}
local capacity_counts = {40, 60, 90, 130, 180, 240, 320, 420}
local capacity_times = {20, 20, 30, 30, 45, 45, 60, 60}
local capacity_extra_prereqs = {
  nil,
  nil,
  "logistic-science-pack",
  nil,
  "chemical-science-pack",
  nil,
  "production-science-pack",
  "utility-science-pack",
}

for level = 1, 8 do
  local name = "admin-station-capacity-" .. level
  local prerequisites = {}
  if level == 1 then
    prerequisites = {"administrative-bureaucracy"}
  else
    prerequisites = {"admin-station-capacity-" .. (level - 1)}
  end

  local extra_prereq = capacity_extra_prereqs[level]
  if extra_prereq then
    prerequisites[#prerequisites + 1] = extra_prereq
  end

  admin_station_capacity_techs[#admin_station_capacity_techs + 1] = {
    type = "technology",
    name = name,
    icon = tech_icons .. "admin-station-capacity.png",
    icon_size = 256,
    effects = {
      { type = "nothing", effect_description = {"technology-effect.admin-station-capacity", tostring(level)} }
    },
    prerequisites = prerequisites,
    unit = {
      count = capacity_counts[level],
      ingredients = capacity_pack_sets[level],
      time = capacity_times[level],
    },
    order = "a-z[" .. string.format("%02d", level) .. "]",
    upgrade = true,
  }
end

data:extend(admin_station_capacity_techs)

data:extend({
  {
    type = "technology",
    name = "filing-cabinet-logistics-1",
    icon = tech_icons .. "filing-cabinet-logistics.png",
    icon_size = 256,
    effects = {
      { type = "character-logistic-requests", modifier = true },
      { type = "character-logistic-trash-slots", modifier = 10 },
    },
    prerequisites = {"information-management", "logistic-robotics"},
    unit = {
      count = 120,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 30,
    },
    order = "e-l1",
    upgrade = true,
  },
  {
    type = "technology",
    name = "filing-cabinet-logistics-2",
    icon = tech_icons .. "filing-cabinet-logistics.png",
    icon_size = 256,
    effects = {
      { type = "character-logistic-requests", modifier = true },
      { type = "character-logistic-trash-slots", modifier = 10 },
    },
    prerequisites = {"filing-cabinet-logistics-1", "public-finance"},
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
    order = "f-l2",
    upgrade = true,
  },
  {
    type = "technology",
    name = "filing-cabinet-logistics-3",
    icon = tech_icons .. "filing-cabinet-logistics.png",
    icon_size = 256,
    effects = {
      { type = "character-logistic-requests", modifier = true },
      { type = "character-logistic-trash-slots", modifier = 10 },
    },
    prerequisites = {"filing-cabinet-logistics-2", "board-meetings", "utility-science-pack"},
    unit = {
      count = 340,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"utility-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 60,
    },
    order = "g-l3",
    upgrade = true,
  },
})

local function add_tech_prerequisite(technology_name, prerequisite_name)
  local technology = data.raw["technology"] and data.raw["technology"][technology_name]
  if not technology or not prerequisite_name then return end
  if not technology.prerequisites then technology.prerequisites = {} end
  for _, prereq in ipairs(technology.prerequisites) do
    if prereq == prerequisite_name then return end
  end
  table.insert(technology.prerequisites, prerequisite_name)
end

local function add_tech_unlock(technology_name, recipe_name)
  local technology = data.raw["technology"] and data.raw["technology"][technology_name]
  if not technology or not recipe_name then return end
  if not technology.effects then technology.effects = {} end
  for _, effect in ipairs(technology.effects) do
    if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
      return
    end
  end
  table.insert(technology.effects, { type = "unlock-recipe", recipe = recipe_name })
end

local science_pack_order = {
  ["automation-science-pack"] = 1,
  ["logistic-science-pack"] = 2,
  ["military-science-pack"] = 3,
  ["chemical-science-pack"] = 4,
  ["production-science-pack"] = 5,
  ["utility-science-pack"] = 6,
  ["space-science-pack"] = 7,
  ["metallurgic-science-pack"] = 8,
  ["electromagnetic-science-pack"] = 9,
  ["agricultural-science-pack"] = 10,
  ["cryogenic-science-pack"] = 11,
  ["promethium-science-pack"] = 12,
  ["administrative-science-pack"] = 13,
}

local function tech_uses_pack(technology, pack_name)
  if not technology or not technology.unit or not technology.unit.ingredients then return false end
  for _, ingredient in ipairs(technology.unit.ingredients) do
    if (ingredient[1] or ingredient.name) == pack_name then
      return true
    end
  end
  return false
end

local function add_tech_science_pack(technology_name, pack_name, amount)
  local technology = data.raw["technology"] and data.raw["technology"][technology_name]
  if not technology or not technology.unit or not technology.unit.ingredients then return false end
  if tech_uses_pack(technology, pack_name) then return false end
  table.insert(technology.unit.ingredients, {pack_name, amount or 1})
  return true
end

local function sort_science_packs(technology)
  if not technology or not technology.unit or not technology.unit.ingredients then return end
  table.sort(technology.unit.ingredients, function(a, b)
    local a_name = a[1] or a.name or ""
    local b_name = b[1] or b.name or ""
    local a_order = science_pack_order[a_name] or 999
    local b_order = science_pack_order[b_name] or 999
    if a_order == b_order then
      return a_name < b_name
    end
    return a_order < b_order
  end)
end

local function dedupe_science_packs(technology)
  if not technology or not technology.unit or not technology.unit.ingredients then return end

  local deduped = {}
  local seen = {}
  for _, ingredient in ipairs(technology.unit.ingredients) do
    local pack_name = ingredient[1] or ingredient.name
    if pack_name and not seen[pack_name] then
      seen[pack_name] = true
      deduped[#deduped + 1] = ingredient
    end
  end
  technology.unit.ingredients = deduped
end

local function inherit_parent_science_packs()
  local technologies = data.raw["technology"] or {}
  local changed = true

  while changed do
    changed = false
    for tech_name, technology in pairs(technologies) do
      if technology.unit and technology.unit.ingredients then
        for _, prereq_name in ipairs(technology.prerequisites or {}) do
          local prereq = technologies[prereq_name]
          if prereq and prereq.unit and prereq.unit.ingredients then
            for _, ingredient in ipairs(prereq.unit.ingredients) do
              local pack_name = ingredient[1] or ingredient.name
              local pack_amount = ingredient[2] or ingredient.amount or 1
              if pack_name and add_tech_science_pack(tech_name, pack_name, pack_amount) then
                changed = true
              end
            end
          end
        end
      end
    end
  end

  for _, technology in pairs(technologies) do
    dedupe_science_packs(technology)
    sort_science_packs(technology)
  end
end

if working_hours_enabled then
  data:extend({
    {
      type = "technology", name = "after-hours-operations",
      icon = tech_icons .. "overtime-module.png",
      icon_size = 64,
      effects = {
        { type = "unlock-recipe", recipe = "overtime-exemption" }
      },
      prerequisites = {"federal-regulation", "productivity-module"},
      unit = {
        count = 250,
        ingredients = {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1},
          {"chemical-science-pack", 1},
          {"utility-science-pack", 1},
          {"administrative-science-pack", 1},
        },
        time = 60
      },
      order = "f-z"
    },
  })
end

-- ============================================================
-- VANILLA TECHNOLOGY HOOKS
-- ============================================================

-- Railway now depends on both the verbal-approval branch and the legal form
-- branch so locomotives and transit paperwork become usable at unlock.
add_tech_unlock("railway", "transit-authorization-production")
add_tech_prerequisite("railway", "verbal-approvals")
add_tech_prerequisite("railway", "local-precedents")

-- The field office is the early-game alternative to the office desk, available
-- with basic electronics.  The full office desk is gated behind biter-employment.
add_tech_unlock("electronics", "field-office")

-- Discovery-triggered bootstrap structures should not appear craftable before
-- their prerequisite paperwork exists.
add_tech_unlock("discovery-redundant-rubble", "admin-station")
add_tech_unlock("discovery-redundant-rubble", "resolution-office")
add_tech_unlock("discovery-redundant-rubble", "promise-production")

-- Early paperwork that consumes bootstrap resources should unlock only after
-- the matching discovery chain is in play.
add_tech_unlock("discovery-redundant-rubble", "filing-landscape")
add_tech_unlock("discovery-bullshit", "landscape-final")
add_tech_prerequisite("printing-technology", "discovery-bullshit")
add_tech_prerequisite("printing-technology", "discovery-redundant-rubble")

-- Unlock Work Orders with Automation (fuel for AM1)
add_tech_unlock("automation", "work-order-production")
add_tech_unlock("automation", "research-grant-work-order-production")
add_tech_unlock("automation", "safety-work-order-production")
add_tech_unlock("automation", "construction-work-order-production")

-- Unlock Research Grant Approval with Automation Science (red science unlock)
add_tech_unlock("automation-science-pack", "research-grant-approval-production")

-- Science-pack tier heads should explicitly depend on the pack tech that
-- introduces the tier, so the tree matches the actual research requirement.
add_tech_prerequisite("industrial-printing", "chemical-science-pack")
add_tech_prerequisite("corporate-hospitality", "logistic-science-pack")
add_tech_prerequisite("office-agriculture", "logistic-science-pack")
add_tech_prerequisite("charcoal-production", "logistic-science-pack")
add_tech_prerequisite("health-and-safety", "chemical-science-pack")
add_tech_prerequisite("public-finance", "chemical-science-pack")
add_tech_prerequisite("public-finance", "steel-processing")
add_tech_prerequisite("board-meetings", "chemical-science-pack")
add_tech_prerequisite("synthetic-stationery", "chemical-science-pack")
add_tech_prerequisite("eminent-domain-zoning", "production-science-pack")
add_tech_prerequisite("constitutional-law", "production-science-pack")
add_tech_prerequisite("loitering-ordinances", "utility-science-pack")
add_tech_prerequisite("vagrancy-ordinances", "utility-science-pack")
add_tech_prerequisite("after-hours-operations", "utility-science-pack")

add_tech_prerequisite("information-management", "advanced-circuit")
add_tech_prerequisite("environmental-compliance", "fluid-handling")
add_tech_prerequisite("environmental-compliance", "steel-processing")
add_tech_prerequisite("radiological-compliance", "battery")

-- Vanilla branches that now consume mod paperwork need matching bureaucracy
-- prerequisites so they unlock only when their recipes are actually usable.
add_tech_prerequisite("engine", "automation")
add_tech_prerequisite("gate", "automation")
add_tech_prerequisite("power-armor-mk2", "low-density-structure")
add_tech_prerequisite("advanced-circuit", "verbal-approvals")
add_tech_prerequisite("processing-unit", "verbal-approvals")
add_tech_prerequisite("battery", "environmental-compliance")
add_tech_prerequisite("electric-engine", "environmental-compliance")
add_tech_prerequisite("rocket-fuel", "environmental-compliance")
add_tech_prerequisite("lubricant", "environmental-compliance")
add_tech_prerequisite("explosives", "environmental-compliance")

for _, tech_name in ipairs({
  "advanced-combinators",
  "after-hours-operations",
  "construction-robotics",
  "effect-transmission",
  "efficiency-module-2",
  "electric-energy-distribution-2",
  "logistic-robotics",
  "logistic-system",
  "logistics-3",
  "nuclear-power",
  "productivity-module-2",
  "speed-module-2",
  "uranium-processing",
}) do
  add_tech_prerequisite(tech_name, "advanced-circuit")
end

for _, tech_name in ipairs({
  "automation-3",
  "effect-transmission",
  "nuclear-power",
  "rocket-silo",
  "uranium-processing",
}) do
  add_tech_prerequisite(tech_name, "environmental-compliance")
end

for _, tech_name in ipairs({
  "after-hours-operations",
  "efficiency-module-3",
  "power-armor-mk2",
  "productivity-module-3",
  "rocket-silo",
  "speed-module-3",
}) do
  add_tech_prerequisite(tech_name, "processing-unit")
end

for _, tech_name in ipairs({
  "power-armor-mk2",
  "rocket-silo",
}) do
  add_tech_prerequisite(tech_name, "electric-engine")
end

add_tech_prerequisite("productivity-module-2", "information-management")
add_tech_prerequisite("speed-module-2", "information-management")
add_tech_prerequisite("speed-module-3", "processing-unit")
add_tech_prerequisite("efficiency-module-3", "processing-unit")
add_tech_prerequisite("productivity-module-3", "processing-unit")
add_tech_prerequisite("uranium-processing", "board-meetings")
add_tech_prerequisite("after-hours-operations", "executive-review")

for _, tech_name in ipairs({
  "advanced-material-processing-2",
  "solar-energy",
  "electric-energy-accumulators",
  "construction-robotics",
  "logistic-robotics",
  "personal-roboport-equipment",
  "personal-roboport-mk2-equipment",
}) do
  add_tech_prerequisite(tech_name, "verbal-approvals")
end

add_tech_prerequisite("oil-processing", "environmental-compliance")

-- Buildings that require biter-workers or specialists need employment tech
add_tech_prerequisite("industrial-propaganda", "biter-employment")
add_tech_prerequisite("nuclear-power", "specialist-training")

for _, tech_name in ipairs({"automation-3", "effect-transmission", "rocket-silo", "nuclear-power"}) do
  add_tech_prerequisite(tech_name, "executive-review")
end

add_tech_prerequisite("uranium-processing", "radiological-compliance")

inherit_parent_science_packs()
