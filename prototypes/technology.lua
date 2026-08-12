local feature_flags = require("feature_flags")
local shared = require("prototypes.shared")
local building_icons = require("prototypes.shared.building_icons")
local working_hours_enabled = feature_flags.working_hours_enabled()
local space_age_enabled = feature_flags.space_age_enabled()
local tech_icons = "__administratorio__/graphics/technology/"

local function numbered_technology_icon(icon, icon_size, number, tint)
  local badge_shift = icon_size >= 128 and {32, 32} or {8, 8}
  return {
    {icon = icon, icon_size = icon_size, tint = tint},
    {
      icon = "__base__/graphics/icons/signal/signal_" .. number .. ".png",
      icon_size = 64,
      scale = 0.38,
      shift = badge_shift,
    },
  }
end

local function biterport_upgrade_icons(kind, level)
  local kind_icon = kind == "capacity"
    and "__base__/graphics/icons/signal/signal-stack-size.png"
    or "__base__/graphics/icons/signal/signal-speed.png"
  return {
    {icon = "__base__/graphics/icons/small-biter.png", icon_size = 64, tint = {r=0.45, g=0.85, b=0.55, a=1}},
    {icon = "__administratorio__/graphics/icons/biterport.png", icon_size = 64, scale = 0.46, shift = {7, -6}},
    {icon = kind_icon, icon_size = 64, scale = 0.25, shift = {-10, 10}},
    {icon = "__base__/graphics/icons/signal/signal_" .. level .. ".png", icon_size = 64, scale = 0.25, shift = {10, 10}},
  }
end

local function eminent_domain_zoning_effects()
  local effects = {
    { type = "unlock-recipe", recipe = "white-paper-production" },
    { type = "unlock-recipe", recipe = "policy-production" },
  }
  if not space_age_enabled then
    effects[#effects + 1] = { type = "unlock-recipe", recipe = "slush-fund-production" }
  end
  return effects
end

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
      { type = "unlock-recipe", recipe = "burner-mining-drill" }
    },
    research_trigger = { type = "mine-entity", entity = "redundant-rubble" },
    order = "z-c"
  },
  -- FIELD OFFICE DEPLOYMENT (triggered when the first field office is crafted)
  {
    type = "technology", name = "field-office-deployment",
    icons = (function()
      local icons = building_icons.field_office()
      icons[#icons + 1] = {icon = "__administratorio__/graphics/icons/provisional-approval.png", icon_size = 64, scale = 0.36, shift = {8, 8}}
      return icons
    end)(),
    effects = {
      { type = "unlock-recipe", recipe = "provisional-approval-production" },
      { type = "unlock-recipe", recipe = "promise-production" },
      { type = "unlock-recipe", recipe = "admin-station" },
    },
    research_trigger = { type = "craft-item", item = "field-office", count = 1 },
    order = "z-d"
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
    icon = "__administratorio__/graphics/icons/printer-t1-v2.png", icon_size = 64,
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
    icon = "__administratorio__/graphics/icons/printer-t2-v2.png", icon_size = 64,
    effects = {
      { type = "unlock-recipe", recipe = "printer-t2" },
      { type = "unlock-recipe", recipe = "copy-blank-form" },
      { type = "unlock-recipe", recipe = "copy-blank-approval" },
      { type = "unlock-recipe", recipe = "copy-carbon-offset-certificate" },
      { type = "unlock-recipe", recipe = "copy-form-27b-6" },
      { type = "unlock-recipe", recipe = "copy-environmental-impact-report" }
    },
    prerequisites = {"administrative-bureaucracy", "steel-processing", "advanced-circuit", "chemical-science-pack", "logistic-science-pack"},
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
    prerequisites = {"administrative-bureaucracy", "littering-resolution", "logistic-science-pack"},
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
    prerequisites = {"local-precedents", "logistic-science-pack"},
    unit = { count = 40, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 20 },
    order = "b-b2"
  },
  -- T2c: RUBBLE COMPACTION (shared processed material for multiple later branches)
  {
    type = "technology", name = "rubble-compaction",
    icon = "__administratorio__/graphics/icons/compacted-rubble.png", icon_size = 64,
    effects = {
      { type = "unlock-recipe", recipe = "compacted-rubble-production" },
      { type = "unlock-recipe", recipe = "compacted-rubble-electric" }
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
    prerequisites = {"corporate-hospitality", "fluid-handling", "logistic-science-pack"},
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
    prerequisites = {"corporate-hospitality", "fluid-handling", "chemical-science-pack"},
    unit = { count = 60, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
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
    prerequisites = {"littering-resolution", "fluid-handling", "rubble-compaction", "corporate-hospitality", "office-agriculture", "logistic-science-pack"},
    unit = { count = 70, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "c-b"
  },
  -- T3c: CORPORATE HOSPITALITY (breakrooms, coffee, gossip, and office drama)
  {
    type = "technology", name = "corporate-hospitality",
    icon = "__administratorio__/graphics/icons/corporate-breakroom-v2.png", icon_size = 64,
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
    prerequisites = {"corporate-hospitality", "industrial-propaganda", "advanced-circuit", "logistic-science-pack"},
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
    prerequisites = {"corporate-hospitality", "logistic-science-pack"},
    unit = { count = 80, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "c-e"
  },
  -- T4a: ENVIRONMENTAL COMPLIANCE
  -- Single environmental gate for reporting, certification, and operating permits.
  {
    type = "technology", name = "environmental-compliance",
    icon = tech_icons .. "environmental-compliance.png", icon_size = 256,
    effects = {
      { type = "unlock-recipe", recipe = "environmental-impact-report" },
      { type = "unlock-recipe", recipe = "chemical-handling-work-order-production" },
      { type = "unlock-recipe", recipe = "carbon-offset-certificate-verified" },
    },
    prerequisites = {"local-precedents", "fluid-handling", "steel-processing", "streamlined-work-orders"},
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
    prerequisites = {"environmental-compliance", "charcoal-production"},
    unit = { count = 90, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
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
    prerequisites = {"environmental-compliance", "chemical-operator-training", "chemical-science-pack"},
    unit = { count = 100, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "d-c"
  },
  -- T4d: NEST EXPROPRIATION (eviction notices for territorial expansion)
  {
    type = "technology", name = "nest-expropriation",
    icon = tech_icons .. "eviction-notice.png", icon_size = 256,
    effects = {
      { type = "unlock-recipe", recipe = "eviction-notice-production" }
    },
    prerequisites = {"information-management", "industrial-propaganda", "nest-pacification"},
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
    order = "d-e"
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
    prerequisites = {"verbal-approvals", "local-precedents", "advanced-circuit", "union-delegate-training", "chemical-science-pack"},
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
    prerequisites = {"public-finance", "health-and-safety", "chemical-science-pack"},
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
    prerequisites = {"board-meetings", "health-and-safety", "chemical-science-pack"},
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
    prerequisites = {"executive-review", "environmental-compliance", "chemical-science-pack", "battery"},
    unit = { count = 160, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"administrative-science-pack", 1}}, time = 45 },
    order = "f-b"
  },
  -- T7a: EMINENT DOMAIN & ZONING (policy drafting; base game also unlocks slush funds)
  {
    type = "technology", name = "eminent-domain-zoning",
    icon = tech_icons .. "eminent-domain-zoning.png", icon_size = 256,
    localised_description = space_age_enabled and {"technology-description.eminent-domain-zoning-space-age"} or nil,
    effects = eminent_domain_zoning_effects(),
    prerequisites = {"executive-review", "processing-unit", "production-science-pack"},
    unit = { count = 210, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"production-science-pack", 1}, {"administrative-science-pack", 1}}, time = 60 },
    order = "g-a"
  },
  -- T7b: WORK ORDER DUPLICATION (industrial printer copies every work-order family)
  {
    type = "technology", name = "work-order-duplication",
    icons = {
      {icon = tech_icons .. "work-order-duplication.png", icon_size = 128},
      {icon = "__base__/graphics/icons/copy-paste-tool.png", icon_size = 64, scale = 0.35, shift = {16, 16}},
    },
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
    prerequisites = {"industrial-printing", "radiological-compliance", "processing-unit", "production-science-pack", "synthetic-stationery"},
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
    prerequisites = {"eminent-domain-zoning", "work-order-duplication", "production-science-pack"},
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
    prerequisites = {"eminent-domain-zoning", "environmental-compliance", "production-science-pack", "smog-abatement", "hazmat-response"},
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
    prerequisites = {"board-meetings", "utility-science-pack", "production-science-pack"},
    unit = { count = 185, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"production-science-pack", 1}, {"utility-science-pack", 1}, {"administrative-science-pack", 1}}, time = 60 },
    order = "g-e"
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
    prerequisites = {"federal-regulation", "production-science-pack"},
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
    prerequisites = {"constitutional-law", "utility-science-pack", "production-science-pack"},
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
  -- BITER EMPLOYMENT (hire resolved biters as workers — red + admin science only)
  {
    type = "technology", name = "biter-employment",
    icon = tech_icons .. "worker-biter.png", icon_size = 256,
    effects = {
      { type = "unlock-recipe", recipe = "job-offer-production" },
      { type = "unlock-recipe", recipe = "office-desk" },
      { type = "unlock-recipe", recipe = "resolution-office" },
    },
    prerequisites = {"administrative-bureaucracy", "rubble-compaction"},
    unit = { count = 120, ingredients = {{"automation-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "c-h"
  },
  -- BITER EMPLOYMENT OFFICE (formal dispatch building — gates managed-building techs)
  {
    type = "technology", name = "biter-employment-office",
    icon = "__administratorio__/graphics/icons/biter-station.png", icon_size = 64,
    effects = {
      { type = "unlock-recipe", recipe = "biter-station" },
    },
    prerequisites = {"biter-employment", "fluid-handling"},
    unit = { count = 140, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "c-h0z"
  },
  -- FORMATION CENTER (unlock the training building — gate tech for all profession training)
  {
    type = "technology", name = "formation-center",
    icon = "__administratorio__/graphics/icons/formation-center.png", icon_size = 64,
    effects = {
      { type = "unlock-recipe", recipe = "formation-center" },
    },
    prerequisites = {"biter-employment", "printing-technology", "steel-processing", "logistic-science-pack"},
    unit = { count = 100, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "c-h0"
  },
  {
    type = "technology", name = "rideable-biter",
    icon = tech_icons .. "rideable biter.png", icon_size = 256,
    effects = {
      { type = "unlock-recipe", recipe = "rideable-biter" },
    },
    prerequisites = {"formation-center", "engine"},
    unit = { count = 110, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "c-h0a"
  },
  {
    type = "technology", name = "biter-labor-efficiency-1",
    icons = numbered_technology_icon(tech_icons .. "worker-biter.png", 256, 1),
    effects = {
      { type = "nothing", effect_description = {"technology-effect.biter-labor-efficiency", "3"} },
    },
    prerequisites = {"biter-employment", "chemical-science-pack"},
    unit = { count = 140, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "c-h1"
  },
  {
    type = "technology", name = "biter-labor-efficiency-2",
    icons = numbered_technology_icon(tech_icons .. "worker-biter.png", 256, 2),
    effects = {
      { type = "nothing", effect_description = {"technology-effect.biter-labor-efficiency", "5"} },
    },
    prerequisites = {"biter-labor-efficiency-1"},
    unit = { count = 220, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"administrative-science-pack", 1}}, time = 45 },
    order = "c-h2"
  },
  -- BITERPORT LOGISTICS (walking construction/logistics before true robots)
  {
    type = "technology", name = "biterport-logistics",
    icons = {
      {icon = "__base__/graphics/icons/small-biter.png", icon_size = 64, tint = {r=0.45, g=0.85, b=0.55, a=1}},
      {icon = "__administratorio__/graphics/icons/biterport.png", icon_size = 64, scale = 0.5, shift = {8, 8}},
    },
    effects = {
      { type = "unlock-recipe", recipe = "biterport" },
      { type = "unlock-recipe", recipe = "biter-logistics-formation" },
      { type = "unlock-recipe", recipe = "paperwork-provider-chest" },
      { type = "unlock-recipe", recipe = "paperwork-storage-chest" },
      { type = "unlock-recipe", recipe = "paperwork-requester-chest" },
    },
    prerequisites = {"formation-center", "steel-processing", "advanced-circuit"},
    unit = { count = 140, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 35 },
    order = "c-h2a"
  },
  -- BITERPORT TRANSPORT CAPACITY (increase items carried per logistics trip)
  {
    type = "technology", name = "biterport-transport-capacity-1",
    icons = biterport_upgrade_icons("capacity", 1),
    effects = {{ type = "nothing", effect_description = {"technology-effect.biterport-transport-capacity", "2"} }},
    prerequisites = {"biterport-logistics"},
    unit = { count = 90, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 20 },
    order = "c-h9b"
  },
  {
    type = "technology", name = "biterport-transport-capacity-2",
    icons = biterport_upgrade_icons("capacity", 2),
    effects = {{ type = "nothing", effect_description = {"technology-effect.biterport-transport-capacity", "5"} }},
    prerequisites = {"biterport-transport-capacity-1"},
    unit = { count = 140, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "c-h9c"
  },
  {
    type = "technology", name = "biterport-transport-capacity-3",
    icons = biterport_upgrade_icons("capacity", 3),
    effects = {{ type = "nothing", effect_description = {"technology-effect.biterport-transport-capacity", "10"} }},
    prerequisites = {"biterport-transport-capacity-2"},
    unit = { count = 220, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 40 },
    order = "c-h9d"
  },
  {
    type = "technology", name = "biterport-transport-capacity-4",
    icons = biterport_upgrade_icons("capacity", 4),
    effects = {{ type = "nothing", effect_description = {"technology-effect.biterport-transport-capacity", "25"} }},
    prerequisites = {"biterport-transport-capacity-3", "chemical-science-pack"},
    unit = { count = 320, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"administrative-science-pack", 1}}, time = 50 },
    order = "c-h9e"
  },
  -- BITERPORT WORKER SPEED (swap dispatched logistics workers to faster unit prototypes)
  {
    type = "technology", name = "biterport-worker-speed-1",
    icons = biterport_upgrade_icons("speed", 1),
    effects = {{ type = "nothing", effect_description = {"technology-effect.biterport-worker-speed", "35%"} }},
    prerequisites = {"biterport-logistics"},
    unit = { count = 140, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 30 },
    order = "c-i1"
  },
  {
    type = "technology", name = "biterport-worker-speed-2",
    icons = biterport_upgrade_icons("speed", 2),
    effects = {{ type = "nothing", effect_description = {"technology-effect.biterport-worker-speed", "70%"} }},
    prerequisites = {"biterport-worker-speed-1", "chemical-science-pack"},
    unit = { count = 240, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"administrative-science-pack", 1}}, time = 45 },
    order = "c-i2"
  },
  -- UNION DELEGATE TRAINING (train union representative specialists)
  {
    type = "technology", name = "union-delegate-training",
    icons = {
      {icon = "__base__/graphics/icons/medium-biter.png", icon_size = 64, tint = {r=0.45, g=0.55, b=1.0, a=1}},
    },
    effects = {
      { type = "unlock-recipe", recipe = "union-delegate-training" },
    },
    prerequisites = {"formation-center", "verbal-approvals", "local-precedents", "chemical-science-pack"},
    unit = { count = 160, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"administrative-science-pack", 1}}, time = 45 },
    order = "e-h1"
  },
  -- CHEMICAL OPERATOR TRAINING (certify workers for chemical plant and hazmat operations)
  {
    type = "technology", name = "chemical-operator-training",
    icons = {
      {icon = "__base__/graphics/icons/medium-biter.png", icon_size = 64, tint = {r=1.0, g=0.75, b=0.25, a=1}},
    },
    effects = {
      { type = "unlock-recipe", recipe = "chemical-operator-training" },
    },
    prerequisites = {"formation-center", "environmental-compliance", "corporate-hospitality"},
    unit = { count = 120, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}}, time = 35 },
    order = "d-h1"
  },
  -- NUCLEAR TECHNICIAN TRAINING (certify workers for nuclear reactor operations)
  {
    type = "technology", name = "nuclear-technician-training",
    icons = {
      {icon = "__base__/graphics/icons/medium-biter.png", icon_size = 64, tint = {r=0.35, g=1.0, b=0.85, a=1}},
    },
    effects = {
      { type = "unlock-recipe", recipe = "nuclear-technician-training" },
    },
    prerequisites = {"formation-center", "radiological-compliance"},
    unit = { count = 200, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"administrative-science-pack", 1}}, time = 45 },
    order = "f-h1"
  },
  {
    type = "technology", name = "hired-biter-fieldwork",
    icon = "__base__/graphics/icons/behemoth-biter.png", icon_size = 64,
    effects = {
      { type = "unlock-recipe", recipe = "hired-biter-capsule" },
      { type = "unlock-recipe", recipe = "hired-biter-command-capsule" },
    },
    prerequisites = {"biter-employment", "loitering-ordinances", "biter-labor-efficiency-2", "executive-review"},
    unit = { count = 500, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"utility-science-pack", 1}, {"administrative-science-pack", 1}}, time = 60 },
    order = "f-i"
  },
})

if not space_age_enabled then
  data:extend({
    {
      type = "technology", name = "creative-accounting",
      icon = tech_icons .. "creative-accounting.png", icon_size = 256,
      effects = {
        { type = "unlock-recipe", recipe = "tax-audit" },
      },
      prerequisites = {"eminent-domain-zoning", "production-science-pack"},
      unit = { count = 175, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"production-science-pack", 1}, {"administrative-science-pack", 1}}, time = 60 },
      order = "f-y"
    },
  })
end

-- PNEUMATIC CAPACITY UPGRADES (tube network max forms)
local pneumatic_capacity_techs = {}
local pneumatic_cap_packs = {
  {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"administrative-science-pack", 1}},
  {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"administrative-science-pack", 1}},
  {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"production-science-pack", 1}, {"administrative-science-pack", 1}},
  {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}, {"production-science-pack", 1}, {"utility-science-pack", 1}, {"administrative-science-pack", 1}},
}
local pneumatic_cap_counts = {60, 120, 200, 320}
local pneumatic_cap_times = {20, 30, 45, 60}
local pneumatic_cap_bonuses = {15, 25, 50, 100}

for level = 1, 4 do
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
  elseif level == 4 then
    prerequisites[#prerequisites + 1] = "utility-science-pack"
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
    icons = numbered_technology_icon(tech_icons .. "admin-station-capacity.png", 256, level),
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
    icon = tech_icons .. "filing-cabinet-logistics-1.png",
    icon_size = 128,
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
    icon = tech_icons .. "filing-cabinet-logistics-2.png",
    icon_size = 128,
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
    icon = tech_icons .. "filing-cabinet-logistics-3.png",
    icon_size = 128,
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

local function remove_tech_unlock(technology_name, recipe_name)
  local technology = data.raw["technology"] and data.raw["technology"][technology_name]
  if not technology or not technology.effects or not recipe_name then return end
  for i = #technology.effects, 1, -1 do
    local effect = technology.effects[i]
    if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
      table.remove(technology.effects, i)
    end
  end
end

local automobilism_tech = data.raw["technology"]["automobilism"]
if automobilism_tech then
  add_tech_prerequisite("automobilism", "utility-science-pack")
  automobilism_tech.unit.count = 220
  automobilism_tech.unit.time = 30
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
      prerequisites = {"executive-review", "federal-regulation", "production-science-pack"},
      unit = {
        count = 175,
        ingredients = {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1},
          {"chemical-science-pack", 1},
          {"production-science-pack", 1},
          {"administrative-science-pack", 1},
        },
        time = 45
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

-- The field office is the early-game alternative to the office desk.  The full
-- office desk is gated behind biter-employment.
add_tech_unlock("steam-power", "field-office")

-- Early paperwork that consumes bootstrap resources should unlock only after
-- the matching discovery chain is in play.
add_tech_unlock("discovery-redundant-rubble", "filing-landscape")
add_tech_unlock("discovery-bullshit", "landscape-final")
add_tech_prerequisite("printing-technology", "discovery-bullshit")
add_tech_prerequisite("printing-technology", "discovery-redundant-rubble")
add_tech_prerequisite("field-office-deployment", "electronics")
add_tech_prerequisite("printing-technology", "field-office-deployment")
add_tech_prerequisite("printing-technology", "electronics")
add_tech_prerequisite("biter-employment", "field-office-deployment")
add_tech_prerequisite("industrial-printing", "printing-technology")

-- Regulated vanilla rewards consume paperwork that must already be printable
-- at their technology card. Keep the unlock graph honest instead of relying
-- on a later descendant technology to make the advertised recipe usable.
for _, tech_name in ipairs({
  "advanced-material-processing",
  "electric-energy-distribution-1",
  "logistics-2",
}) do
  add_tech_prerequisite(tech_name, "printing-technology")
end

for _, tech_name in ipairs({"productivity-module-3", "speed-module-3"}) do
  add_tech_prerequisite(tech_name, "board-meetings")
end

remove_tech_unlock("railway", "locomotive")
add_tech_unlock("production-science-pack", "locomotive")

-- Unlock Work Orders with Automation (fuel for AM1)
add_tech_unlock("automation", "work-order-production")
add_tech_unlock("automation", "provisional-work-order-production")
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
add_tech_prerequisite("charcoal-production", "chemical-science-pack")
add_tech_prerequisite("local-precedents", "logistic-science-pack")
add_tech_prerequisite("nest-pacification", "logistic-science-pack")
add_tech_prerequisite("health-and-safety", "chemical-science-pack")
  add_tech_prerequisite("public-finance", "chemical-science-pack")
  add_tech_prerequisite("public-finance", "steel-processing")
  add_tech_prerequisite("public-finance", "biter-employment-office")
  add_tech_prerequisite("public-finance", "union-delegate-training")
  add_tech_prerequisite("corporate-hospitality", "logistic-science-pack")
  add_tech_prerequisite("industrial-printing", "logistic-science-pack")
  add_tech_prerequisite("board-meetings", "chemical-science-pack")
  add_tech_prerequisite("synthetic-stationery", "chemical-science-pack")
  add_tech_prerequisite("biter-labor-efficiency-2", "chemical-science-pack")
  add_tech_prerequisite("admin-station-capacity-3", "chemical-science-pack")
  add_tech_prerequisite("admin-station-capacity-4", "production-science-pack")
  add_tech_prerequisite("nuclear-technician-training", "production-science-pack")
  add_tech_prerequisite("eminent-domain-zoning", "production-science-pack")
  add_tech_prerequisite("constitutional-law", "production-science-pack")
  add_tech_prerequisite("loitering-ordinances", "utility-science-pack")
  add_tech_prerequisite("vagrancy-ordinances", "utility-science-pack")
  add_tech_prerequisite("power-armor-mk2", "utility-science-pack")
  add_tech_prerequisite("robotics", "federal-regulation")

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
add_tech_prerequisite("logistics-3", "bulk-inserter")
add_tech_prerequisite("uranium-processing", "board-meetings")
add_tech_prerequisite("uranium-processing", "nuclear-technician-training")
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

for _, tech_name in ipairs({
  "construction-robotics",
  "logistic-robotics",
  "personal-roboport-equipment",
}) do
  add_tech_prerequisite(tech_name, "utility-science-pack")
end

for _, tech_name in ipairs({
  "construction-robotics",
  "logistic-robotics",
  "personal-roboport-equipment",
  "personal-roboport-mk2-equipment",
}) do
  add_tech_science_pack(tech_name, "utility-science-pack")
end

add_tech_prerequisite("oil-processing", "environmental-compliance")
  add_tech_prerequisite("oil-processing", "chemical-operator-training")
  -- chemical-operator training needs liquid-coffee, so the breakroom/coffee
  -- branch must already be in play before oil-processing exposes chemical
  -- plants as machine-craftable.
  add_tech_prerequisite("oil-processing", "corporate-hospitality")

-- Biterports own a cheap one-slot chest family. True robot logistics keep the
-- real logistic chests as their late-game reward.
for _, tech_name in ipairs({
  "construction-robotics",
  "logistic-system",
}) do
  for _, chest_recipe in ipairs({
    "active-provider-chest",
    "passive-provider-chest",
    "storage-chest",
    "buffer-chest",
    "requester-chest",
  }) do
    remove_tech_unlock(tech_name, chest_recipe)
  end
end
for _, chest_recipe in ipairs({
  "active-provider-chest",
  "passive-provider-chest",
  "storage-chest",
  "buffer-chest",
  "requester-chest",
}) do
  add_tech_unlock("logistic-robotics", chest_recipe)
end

-- Buildings that require biter-workers or specialists need employment tech
  add_tech_prerequisite("rideable-biter", "corporate-hospitality")
  add_tech_prerequisite("rideable-biter", "verbal-approvals")
  add_tech_prerequisite("biter-employment-office", "industrial-propaganda")
  -- refined-nonsense is crafted in the corporate-breakroom (watercooler-gossip
  -- category), so propaganda can't unlock before corporate-hospitality.
  add_tech_prerequisite("industrial-propaganda", "corporate-hospitality")
  add_tech_prerequisite("nuclear-power", "nuclear-technician-training")

for _, tech_name in ipairs({"automation-3", "effect-transmission", "rocket-silo", "nuclear-power"}) do
  add_tech_prerequisite(tech_name, "executive-review")
end

add_tech_prerequisite("uranium-processing", "radiological-compliance")
add_tech_prerequisite("nuclear-power", "production-science-pack")

inherit_parent_science_packs()

if space_age_enabled then
  require("prototypes.technology.space_age")
end
