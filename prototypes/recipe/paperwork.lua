local icon_tints = require("prototypes.shared.icon_tints")

data:extend({
  -- Paper & Ink (base materials) -> admin-paper-supplies (Infrastructure tab, alongside the item itself)
  { type = "recipe", name = "paper-production",      enabled = true, subgroup = "admin-paper-supplies", order = "a", ingredients = {{type="item", name="wood", amount=1}},  results = {{type="item", name="paper", amount=5}}, energy_required = 1 },
  {
    type = "recipe", name = "synthetic-paper-production", category = "chemistry", enabled = false,
    icons = {
      { icon = "__administratorio__/graphics/icons/paper.png", icon_size = 64 },
      { icon = "__base__/graphics/icons/plastic-bar.png", icon_size = 64, scale = 0.35, shift = {8, 8} },
    },
    subgroup = "admin-paper-supplies", order = "a1",
    ingredients = {{type="item", name="plastic-bar", amount=2}, {type="item", name="sulfur", amount=1}, {type="fluid", name="water", amount=50}},
    results = {{type="item", name="paper", amount=20}},
    energy_required = 4
  },
  { type = "recipe", name = "ink-production",        enabled = true, subgroup = "admin-paper-supplies", order = "b", ingredients = {{type="item", name="coal", amount=1}},  results = {{type="item", name="ink", amount=3}},   energy_required = 1 },

  -- Base Printed Forms (printing category) -> admin-base-permits
  { type = "recipe", name = "blank-form-production",      category = "printing", enabled = true,  subgroup = "admin-base-permits", order = "b-a", ingredients = {{type="item", name="paper", amount=4}, {type="item", name="ink", amount=1}}, results = {{type="item", name="blank-form", amount=2}}, energy_required = 3 },
  { type = "recipe", name = "blank-approval-production",  category = "printing", enabled = true,  subgroup = "admin-base-permits", order = "b-b", ingredients = {{type="item", name="paper", amount=6}, {type="item", name="ink", amount=2}}, results = {{type="item", name="blank-approval", amount=2}}, energy_required = 4 },
  { type = "recipe", name = "blank-directive-production", category = "printing", enabled = false, subgroup = "admin-base-permits", order = "b-c", ingredients = {{type="item", name="paper", amount=8}, {type="item", name="ink", amount=3}}, results = {{type="item", name="blank-directive", amount=2}}, energy_required = 5 },

  -- Provisional Approval (Tier 0) -> admin-base-permits
  { type = "recipe", name = "provisional-approval-production", category = "bureaucracy-registration", enabled = false, subgroup = "admin-base-permits", order = "b-d", ingredients = {{type="item", name="blank-form", amount=1}, {type="item", name="redundant-rubble", amount=1}}, results = {{type="item", name="provisional-approval", amount=1}}, energy_required = 1 },

  -- Carbon Offset Certificates -> admin-base-permits (basic) / admin-printed-forms (verified)
  { type = "recipe", name = "carbon-offset-certificate-basic",    category = "bureaucratic-bootstrap", enabled = true,  subgroup = "admin-base-permits", order = "b-e", ingredients = {{type="item", name="blank-form", amount=2}, {type="item", name="coal", amount=1}}, results = {{type="item", name="carbon-offset-certificate-basic", amount=2}}, energy_required = 2 },
  { type = "recipe", name = "carbon-offset-certificate-verified", category = "bureaucracy-registration", enabled = false, subgroup = "admin-printed-forms", order = "g-a", ingredients = {{type="item", name="carbon-offset-certificate-basic", amount=4}, {type="item", name="dubious-data", amount=20}, {type="item", name="useless-documentation", amount=1}}, results = {{type="item", name="carbon-offset-certificate-verified", amount=1}}, energy_required = 15 },

  -- Form 27b-6 -> admin-base-permits
  { type = "recipe", name = "form-27b-6", category = "bureaucracy-registration", enabled = false, subgroup = "admin-base-permits", order = "b-f", ingredients = {{type="item", name="blank-form", amount=1}, {type="item", name="useless-documentation", amount=1}}, results = {{type="item", name="form-27b-6", amount=1}}, energy_required = 3 },

  -- Work Order (Tier 0) -> admin-base-permits
  { type = "recipe", name = "work-order-production", category = "bureaucratic-bootstrap", enabled = false, subgroup = "admin-base-permits", order = "b-g", ingredients = {{type="item", name="blank-form", amount=1}, {type="item", name="dubious-data", amount=1}}, results = {{type="item", name="work-order", amount=1}}, energy_required = 1 },

  -- Safety Waiver (Tier 1) -> admin-tier1-permits
  { type = "recipe", name = "safety-waiver-draft",    category = "bureaucratic-bootstrap", enabled = false, subgroup = "admin-tier1-permits", order = "c-a", ingredients = {{type="item", name="blank-approval", amount=1}, {type="item", name="basic-excuse", amount=1}}, results = {{type="item", name="safety-waiver-draft", amount=2}}, energy_required = 2 },
  { type = "recipe", name = "safety-waiver-printing", category = "printing",        enabled = false, subgroup = "admin-tier1-permits", order = "c-b", ingredients = {{type="item", name="safety-waiver-draft", amount=1}, {type="item", name="ink", amount=1}}, results = {{type="item", name="safety-waiver", amount=2}}, energy_required = 3 },

  -- Transit Authorization: single-purpose fuel for the transit permit chest / public train stop -> admin-transit
  { type = "recipe", name = "transit-authorization-production", category = "bureaucracy-registration", enabled = false, subgroup = "admin-transit", order = "c", ingredients = {{type="item", name="blank-approval", amount=1}, {type="item", name="form-27b-6", amount=1}}, results = {{type="item", name="transit-authorization", amount=1}}, energy_required = 5 },

  -- Construction Permit (Tier 2) -> admin-tier2-permits
  { type = "recipe", name = "construction-permit-draft",    category = "bureaucratic-bootstrap", enabled = false, subgroup = "admin-tier2-permits", order = "d-a", ingredients = {{type="item", name="blank-approval", amount=1}, {type="item", name="dubious-data", amount=3}, {type="item", name="paper", amount=3}}, results = {{type="item", name="construction-permit-draft", amount=2}}, energy_required = 3 },
  { type = "recipe", name = "construction-permit-printing", category = "printing",        enabled = false, subgroup = "admin-tier2-permits", order = "d-b", ingredients = {{type="item", name="construction-permit-draft", amount=1}, {type="item", name="ink", amount=2}}, results = {{type="item", name="construction-permit", amount=2}}, energy_required = 4 },

  -- Environmental Impact Report (Tier 3) -> admin-tier3-permits
  { type = "recipe", name = "environmental-impact-report", category = "bureaucracy-registration", enabled = false, subgroup = "admin-tier3-permits", order = "e-a", ingredients = {{type="item", name="crappy-report", amount=1}, {type="item", name="form-27b-6", amount=1}, {type="item", name="carbon-offset-certificate-verified", amount=3}}, results = {{type="item", name="environmental-impact-report", amount=1}}, energy_required = 10 },

  -- Management Approval Verbal (Tier 2/3) -> admin-tier2-permits
  { type = "recipe", name = "management-verbal-draft",   category = "watercooler-gossip", enabled = false, subgroup = "admin-tier2-permits", order = "d-c", ingredients = {{type="item", name="blank-directive", amount=1}, {type="item", name="basic-excuse", amount=1}, {type="fluid", name="liquid-coffee", amount=50}, {type="item", name="watercooler-gossip", amount=1}}, results = {{type="item", name="management-verbal-draft", amount=1}}, energy_required = 5 },
  { type = "recipe", name = "management-verbal-printing", category = "printing",          enabled = false, subgroup = "admin-tier2-permits", order = "d-d", ingredients = {{type="item", name="management-verbal-draft", amount=1}, {type="item", name="ink", amount=1}, {type="item", name="paper", amount=1}}, results = {{type="item", name="management-approval-verbal", amount=1}}, energy_required = 5 },

  -- Management Approval Written (Tier 4) -> admin-tier3-permits
  { type = "recipe", name = "management-written-proposal",    category = "bureaucracy-policy", enabled = false, subgroup = "admin-tier3-permits", order = "e-b", ingredients = {{type="item", name="blank-directive", amount=1}, {type="item", name="good-excuse", amount=1}, {type="item", name="narrative", amount=1}, {type="item", name="advanced-circuit", amount=2}, {type="fluid", name="liquid-coffee", amount=35}}, results = {{type="item", name="management-written-proposal", amount=1}}, energy_required = 12, crafting_machine_tint = icon_tints.recipe_tint("management-written-proposal") },
  { type = "recipe", name = "management-written-1st-printing", category = "printing",         enabled = false, subgroup = "admin-tier3-permits", order = "e-c", ingredients = {{type="item", name="management-written-proposal", amount=1}, {type="item", name="ink", amount=3}, {type="item", name="form-27b-6", amount=1}, {type="item", name="paper", amount=1}}, results = {{type="item", name="management-approval-written", amount=1}}, energy_required = 10 },

  -- Research Grant Approval -> admin-base-permits
  { type = "recipe", name = "research-grant-approval-production", category = "bureaucratic-bootstrap", enabled = false, subgroup = "admin-base-permits", order = "b-h", ingredients = {{type="item", name="blank-form", amount=1}, {type="item", name="redundant-rubble", amount=1}, {type="item", name="dubious-data", amount=1}}, results = {{type="item", name="research-grant-approval", amount=1}}, energy_required = 2 },

  -- Machine-family operating paperwork -> admin-work-orders
  { type = "recipe", name = "chemical-handling-work-order-production", category = "bureaucracy-registration", enabled = false, subgroup = "admin-work-orders", order = "f-g", ingredients = {{type="item", name="safety-waiver", amount=2}, {type="item", name="environmental-impact-report", amount=1}, {type="item", name="form-27b-6", amount=2}, {type="item", name="useless-documentation", amount=1}}, results = {{type="item", name="chemical-handling-work-order", amount=2}}, energy_required = 8 },
  { type = "recipe", name = "radiological-work-order-production", category = "bureaucracy-registration", enabled = false, subgroup = "admin-work-orders", order = "f-h", ingredients = {{type="item", name="chemical-handling-work-order", amount=2}, {type="item", name="management-approval-written", amount=1}, {type="item", name="environmental-impact-report", amount=2}, {type="item", name="battery", amount=1}, {type="item", name="steel-plate", amount=2}}, results = {{type="item", name="radiological-work-order", amount=2}}, energy_required = 14 },

  -- Combined Forms (tier form + work-order) -> admin-work-orders
  { type = "recipe", name = "provisional-work-order-production",            category = "bureaucracy-registration", enabled = false, subgroup = "admin-work-orders", order = "f-a", ingredients = {{type="item", name="provisional-approval", amount=1},        {type="item", name="work-order", amount=2}}, results = {{type="item", name="provisional-work-order", amount=1}},        energy_required = 2 },
  { type = "recipe", name = "safety-work-order-production",               category = "bureaucracy-registration", enabled = false, subgroup = "admin-work-orders", order = "f-b", ingredients = {{type="item", name="safety-waiver", amount=1},              {type="item", name="work-order", amount=2}}, results = {{type="item", name="safety-work-order", amount=1}},              energy_required = 2 },
  { type = "recipe", name = "construction-work-order-production",         category = "bureaucracy-registration", enabled = false, subgroup = "admin-work-orders", order = "f-c", ingredients = {{type="item", name="construction-permit", amount=1},        {type="item", name="work-order", amount=2}}, results = {{type="item", name="construction-work-order", amount=1}},        energy_required = 3 },
  { type = "recipe", name = "management-verbal-work-order-production",    category = "bureaucracy-registration", enabled = false, subgroup = "admin-work-orders", order = "f-d", ingredients = {{type="item", name="management-approval-verbal", amount=1}, {type="item", name="work-order", amount=2}}, results = {{type="item", name="management-verbal-work-order", amount=1}},   energy_required = 5 },
  { type = "recipe", name = "management-written-work-order-production",   category = "bureaucracy-registration", enabled = false, subgroup = "admin-work-orders", order = "f-e", ingredients = {{type="item", name="management-approval-written", amount=1},{type="item", name="management-approval-verbal", amount=1}, {type="item", name="work-order", amount=2}}, results = {{type="item", name="management-written-work-order", amount=1}},  energy_required = 8 },
  { type = "recipe", name = "research-grant-work-order-production",       category = "bureaucracy-registration", enabled = false, subgroup = "admin-work-orders", order = "f-f", ingredients = {{type="item", name="research-grant-approval", amount=1},    {type="item", name="work-order", amount=2}}, results = {{type="item", name="research-grant-work-order", amount=1}},      energy_required = 2 },

  -- Direct draft-to-work-order printing -> admin-work-orders
  { type = "recipe", name = "safety-work-order-printing",        category = "printing-workorder", enabled = false, subgroup = "admin-work-orders", order = "f-i", ingredients = {{type="item", name="safety-waiver-draft", amount=1},       {type="item", name="work-order", amount=1}, {type="item", name="ink", amount=1}}, results = {{type="item", name="safety-work-order", amount=2}},       energy_required = 4 },
  { type = "recipe", name = "construction-work-order-printing",  category = "printing-workorder", enabled = false, subgroup = "admin-work-orders", order = "f-j", ingredients = {{type="item", name="construction-permit-draft", amount=1}, {type="item", name="work-order", amount=1}, {type="item", name="ink", amount=1}}, results = {{type="item", name="construction-work-order", amount=2}}, energy_required = 6 },

  -- Administrative Science Pack -> admin-printed-forms
  { type = "recipe", name = "administrative-science-pack-production", category = "bureaucracy-registration", enabled = false, hide_from_player_crafting = false, subgroup = "admin-printed-forms", order = "g-b", ingredients = {{type="item", name="provisional-approval", amount=5}, {type="item", name="basic-excuse", amount=5}, {type="item", name="research-grant-approval", amount=1}}, results = {{type="item", name="administrative-science-pack", amount=5}}, energy_required = 25 },

  -- Useless Documentation (T1 derivative) -> admin-gossip-economy
  { type = "recipe", name = "useless-documentation-production", category = "bureaucracy-registration", enabled = false, subgroup = "admin-gossip-economy", order = "h-a", ingredients = {{type="item", name="redundant-rubble", amount=2}, {type="item", name="paper", amount=3}}, results = {{type="item", name="useless-documentation", amount=2}}, energy_required = 3 },
})
