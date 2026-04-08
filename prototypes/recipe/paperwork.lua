data:extend({
  -- Paper & Ink (base materials)
  { type = "recipe", name = "paper-production",      enabled = true, ingredients = {{type="item", name="wood", amount=1}},  results = {{type="item", name="paper", amount=5}}, energy_required = 1 },
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
  { type = "recipe", name = "ink-production",        enabled = true, ingredients = {{type="item", name="coal", amount=1}},  results = {{type="item", name="ink", amount=2}},   energy_required = 1 },

  -- Base Printed Forms (printing category)
  { type = "recipe", name = "blank-form-production",      category = "printing", enabled = true,  ingredients = {{type="item", name="paper", amount=4}, {type="item", name="ink", amount=1}}, results = {{type="item", name="blank-form", amount=2}}, energy_required = 3 },
  { type = "recipe", name = "blank-approval-production",  category = "printing", enabled = true,  ingredients = {{type="item", name="paper", amount=6}, {type="item", name="ink", amount=2}}, results = {{type="item", name="blank-approval", amount=2}}, energy_required = 4 },
  { type = "recipe", name = "blank-directive-production", category = "printing", enabled = false, ingredients = {{type="item", name="paper", amount=8}, {type="item", name="ink", amount=3}}, results = {{type="item", name="blank-directive", amount=2}}, energy_required = 5 },

  -- Provisional Approval (Tier 0)
  { type = "recipe", name = "provisional-approval-production", category = "bureaucratic-bootstrap", enabled = false, ingredients = {{type="item", name="blank-form", amount=1}, {type="item", name="redundant-rubble", amount=1}}, results = {{type="item", name="provisional-approval", amount=1}}, energy_required = 1 },

  -- Carbon Offset Certificates (reworked: desk recipe from blank-form + coal)
  { type = "recipe", name = "carbon-offset-certificate-basic",    category = "bureaucratic-bootstrap", enabled = true,  ingredients = {{type="item", name="blank-form", amount=1}, {type="item", name="coal", amount=1}}, results = {{type="item", name="carbon-offset-certificate-basic", amount=1}}, energy_required = 2 },
  { type = "recipe", name = "carbon-offset-certificate-verified", category = "union-negotiation",          enabled = false, ingredients = {{type="item", name="carbon-offset-certificate-basic", amount=1}, {type="item", name="dubious-data", amount=5}}, results = {{type="item", name="carbon-offset-certificate-verified", amount=1}}, energy_required = 5 },

  -- Form 27b-6
  { type = "recipe", name = "form-27b-6", category = "bureaucracy-registration", enabled = false, ingredients = {{type="item", name="blank-form", amount=1}, {type="item", name="useless-documentation", amount=1}}, results = {{type="item", name="form-27b-6", amount=1}}, energy_required = 3 },

  -- Work Order (Tier 0 - unlocked by Automation tech hook)
  { type = "recipe", name = "work-order-production", category = "bureaucratic-bootstrap", enabled = false, ingredients = {{type="item", name="blank-form", amount=1}, {type="item", name="dubious-data", amount=1}}, results = {{type="item", name="work-order", amount=1}}, energy_required = 1 },

  -- Safety Waiver (Tier 1 — 2 printer passes: blank-approval + finalization)
  { type = "recipe", name = "safety-waiver-draft",    category = "bureaucratic-bootstrap", enabled = false, ingredients = {{type="item", name="blank-approval", amount=1}, {type="item", name="basic-excuse", amount=1}}, results = {{type="item", name="safety-waiver-draft", amount=2}}, energy_required = 2 },
  { type = "recipe", name = "safety-waiver-printing", category = "printing",        enabled = false, ingredients = {{type="item", name="safety-waiver-draft", amount=1}, {type="item", name="ink", amount=1}}, results = {{type="item", name="safety-waiver", amount=1}}, energy_required = 3 },

  -- Transit Authorization (swap blank-form → blank-approval)
  { type = "recipe", name = "transit-authorization-production", category = "bureaucracy-registration", enabled = false, ingredients = {{type="item", name="blank-approval", amount=1}, {type="item", name="form-27b-6", amount=1}}, results = {{type="item", name="transit-authorization", amount=1}}, energy_required = 5 },

  -- Construction Permit (Tier 2 — 2 printer passes: blank-approval + finalization)
  { type = "recipe", name = "construction-permit-draft",    category = "bureaucratic-bootstrap", enabled = false, ingredients = {{type="item", name="blank-approval", amount=1}, {type="item", name="dubious-data", amount=3}, {type="item", name="paper", amount=3}}, results = {{type="item", name="construction-permit-draft", amount=2}}, energy_required = 3 },
  { type = "recipe", name = "construction-permit-printing", category = "printing",        enabled = false, ingredients = {{type="item", name="construction-permit-draft", amount=1}, {type="item", name="ink", amount=2}}, results = {{type="item", name="construction-permit", amount=1}}, energy_required = 4 },

  -- Environmental Impact Report
  { type = "recipe", name = "environmental-impact-report", category = "bureaucracy-registration", enabled = false, ingredients = {{type="item", name="crappy-report", amount=1}, {type="item", name="form-27b-6", amount=1}, {type="item", name="barrel", amount=1}}, results = {{type="item", name="environmental-impact-report", amount=1}}, energy_required = 10 },

  -- Management Approval Verbal (Tier 3 — 2 printer passes: blank-directive + finalization)
  { type = "recipe", name = "management-verbal-draft",   category = "watercooler-gossip", enabled = false, ingredients = {{type="item", name="blank-directive", amount=1}, {type="item", name="basic-excuse", amount=1}, {type="fluid", name="liquid-coffee", amount=50}, {type="item", name="watercooler-gossip", amount=1}}, results = {{type="item", name="management-verbal-draft", amount=1}}, energy_required = 5 },
  { type = "recipe", name = "management-verbal-printing", category = "printing",          enabled = false, ingredients = {{type="item", name="management-verbal-draft", amount=1}, {type="item", name="ink", amount=1}, {type="item", name="paper", amount=1}}, results = {{type="item", name="management-approval-verbal", amount=1}}, energy_required = 5 },

  -- Management Approval Written (Tier 4 — 3 printer passes: blank-directive + 2 finalizations)
  { type = "recipe", name = "management-written-proposal",    category = "bureaucracy-policy", enabled = false, ingredients = {{type="item", name="blank-directive", amount=1}, {type="item", name="good-excuse", amount=1}, {type="item", name="narrative", amount=1}, {type="item", name="advanced-circuit", amount=2}, {type="fluid", name="liquid-coffee", amount=35}}, results = {{type="item", name="management-written-proposal", amount=1}}, energy_required = 12 },
  { type = "recipe", name = "management-written-1st-printing", category = "printing",         enabled = false, ingredients = {{type="item", name="management-written-proposal", amount=1}, {type="item", name="ink", amount=3}, {type="item", name="form-27b-6", amount=1}, {type="item", name="paper", amount=1}}, results = {{type="item", name="management-approval-written", amount=1}}, energy_required = 10 },
  { type = "recipe", name = "management-written-2nd-printing", category = "printing",         enabled = false, ingredients = {{type="item", name="management-written-review", amount=1}, {type="item", name="ink", amount=1}, {type="item", name="paper", amount=1}}, results = {{type="item", name="management-approval-written", amount=1}}, energy_required = 5 },

  -- Research Grant Approval (science packs)
  { type = "recipe", name = "research-grant-approval-production", category = "bureaucratic-bootstrap", enabled = false, ingredients = {{type="item", name="blank-form", amount=1}, {type="item", name="redundant-rubble", amount=1}, {type="item", name="dubious-data", amount=1}}, results = {{type="item", name="research-grant-approval", amount=1}}, energy_required = 2 },

  -- Machine-family operating paperwork
  { type = "recipe", name = "petrochemical-operating-permit-production", category = "bureaucracy-registration", enabled = false, ingredients = {{type="item", name="safety-waiver", amount=1}, {type="item", name="environmental-impact-report", amount=1}}, results = {{type="item", name="petrochemical-operating-permit", amount=2}}, energy_required = 6 },
  { type = "recipe", name = "chemical-handling-work-order-production", category = "bureaucracy-registration", enabled = false, ingredients = {{type="item", name="petrochemical-operating-permit", amount=1}, {type="item", name="form-27b-6", amount=1}, {type="item", name="barrel", amount=1}, {type="item", name="pipe", amount=1}}, results = {{type="item", name="chemical-handling-work-order", amount=2}}, energy_required = 8 },
  { type = "recipe", name = "radiological-work-order-production", category = "bureaucracy-registration", enabled = false, ingredients = {{type="item", name="chemical-handling-work-order", amount=1}, {type="item", name="management-approval-written", amount=1}, {type="item", name="environmental-impact-report", amount=1}, {type="item", name="battery", amount=1}, {type="item", name="steel-plate", amount=2}}, results = {{type="item", name="radiological-work-order", amount=2}}, energy_required = 14 },

  -- Combined Forms (tier form + work-order, consumed by AM regulated recipes)
  { type = "recipe", name = "safety-work-order-production",               category = "bureaucracy-registration", enabled = false, ingredients = {{type="item", name="safety-waiver", amount=1},              {type="item", name="work-order", amount=1}}, results = {{type="item", name="safety-work-order", amount=1}},              energy_required = 2 },
  { type = "recipe", name = "construction-work-order-production",         category = "bureaucracy-registration", enabled = false, ingredients = {{type="item", name="construction-permit", amount=1},        {type="item", name="work-order", amount=1}}, results = {{type="item", name="construction-work-order", amount=1}},        energy_required = 3 },
  { type = "recipe", name = "management-verbal-work-order-production",    category = "bureaucracy-registration", enabled = false, ingredients = {{type="item", name="management-approval-verbal", amount=1}, {type="item", name="work-order", amount=1}}, results = {{type="item", name="management-verbal-work-order", amount=1}},   energy_required = 5 },
  { type = "recipe", name = "management-written-work-order-production",   category = "bureaucracy-registration", enabled = false, ingredients = {{type="item", name="management-approval-written", amount=1},{type="item", name="work-order", amount=1}}, results = {{type="item", name="management-written-work-order", amount=1}},  energy_required = 8 },
  { type = "recipe", name = "research-grant-work-order-production",       category = "bureaucracy-registration", enabled = false, ingredients = {{type="item", name="research-grant-approval", amount=1},    {type="item", name="work-order", amount=1}}, results = {{type="item", name="research-grant-work-order", amount=1}},      energy_required = 2 },

  -- Direct draft-to-work-order printing (draft-backed forms only)
  { type = "recipe", name = "safety-work-order-printing",        category = "printing-workorder", enabled = false, ingredients = {{type="item", name="safety-waiver-draft", amount=1},       {type="item", name="work-order", amount=1}, {type="item", name="ink", amount=1}}, results = {{type="item", name="safety-work-order", amount=2}},       energy_required = 4 },
  { type = "recipe", name = "construction-work-order-printing",  category = "printing-workorder", enabled = false, ingredients = {{type="item", name="construction-permit-draft", amount=1}, {type="item", name="work-order", amount=1}, {type="item", name="ink", amount=1}}, results = {{type="item", name="construction-work-order", amount=2}}, energy_required = 6 },

  -- Administrative Science Pack
  { type = "recipe", name = "administrative-science-pack-production", category = "bureaucracy-registration", enabled = false, hide_from_player_crafting = false, ingredients = {{type="item", name="blank-form", amount=2}, {type="item", name="provisional-approval", amount=1}, {type="item", name="basic-excuse", amount=1}, {type="item", name="research-grant-approval", amount=1}}, results = {{type="item", name="administrative-science-pack", amount=1}}, energy_required = 5 },

  -- Useless Documentation (T1 derivative — rubble wrapped in paper)
  { type = "recipe", name = "useless-documentation-production", category = "bureaucracy-registration", enabled = false, ingredients = {{type="item", name="redundant-rubble", amount=2}, {type="item", name="paper", amount=3}}, results = {{type="item", name="useless-documentation", amount=2}}, energy_required = 3 },
})
