local M = {}

-- Milestones preset group names are plain strings; milestone names/icons are
-- translated by Milestones from the existing item/fluid/technology locales.
function M.presets()
  local milestones = {}
  local function add(kind, name, quantity, next_formula, quality)
    local prototype_kind = kind:gsub("_consumption$", "")
    if not (prototypes[prototype_kind] and prototypes[prototype_kind][name]) then return end
    if quality and not prototypes.quality[quality] then return end
    milestones[#milestones + 1] = {
      type = kind, name = name, quantity = quantity or 1,
      next = next_formula, quality = quality,
    }
  end
  local function group(name, kind, names)
    local start = #milestones
    milestones[start + 1] = {type = "group", name = name}
    for _, item in ipairs(names) do add(kind, item) end
    if #milestones == start + 1 then milestones[start + 1] = nil end
  end

  local science = {
    "automation-science-pack", "logistic-science-pack", "military-science-pack",
    "chemical-science-pack", "administrative-science-pack", "production-science-pack",
    "utility-science-pack", "space-science-pack", "metallurgic-science-pack",
    "agricultural-science-pack", "electromagnetic-science-pack",
    "cryogenic-science-pack", "promethium-science-pack",
  }
  group("Science", "item", science)
  milestones[#milestones + 1] = {type = "group", name = "Science at scale"}
  for _, name in ipairs(science) do add("item", name, 1000, "x10") end

  group("Office supplies", "item", {
    "paper", "ink", "mechanical-printer", "printer-t1", "printer-t2",
    "greenhouse", "office-desk", "resolution-office",
    "dubious-data", "credentials", "white-paper", "regulation",
  })
  group("Paper trail", "item", {
    "blank-form", "work-order", "provisional-approval", "form-27b-6",
    "safety-waiver", "construction-permit", "management-approval-verbal",
    "management-approval-written", "research-grant-approval",
    "radiological-work-order", "carbon-offset-certificate-basic",
    "carbon-offset-certificate-verified", "overtime-exemption",
  })
  add("item", "blank-form", 1000, "x10")
  add("item", "work-order", 1000, "x10")

  local cases = {"landscape", "littering", "smog", "hazmat", "noise", "loitering", "unemployment", "vagrancy"}
  milestones[#milestones + 1] = {type = "group", name = "Complaint inbox"}
  add("item", "admin-station")
  for _, name in ipairs(cases) do add("item", "ticket-" .. name) end
  milestones[#milestones + 1] = {type = "group", name = "Cases closed"}
  for _, name in ipairs(cases) do add("item_consumption", "resolved-" .. name) end
  for _, name in ipairs(cases) do add("item_consumption", "resolved-" .. name, 100, "x10") end

  group("Public finances", "item", {"taxpayer-money", "treasury-bond", "government-grant"})
  add("item", "taxpayer-money", 1000, "x10")
  group("Human resources", "item", {
    "job-offer", "enrolled-biter", "worker-biter", "formation-center", "biter-station",
    "biter-logistics-formation", "union-delegate", "chemical-operator", "nuclear-technician",
    "hired-biter-capsule", "rideable-biter", "clerical-trainee", "management-trainee",
    "middle-management-managing-manager", "night-shift-supervisor", "licensed-notary",
    "conciliation-officer", "relay-clerk", "cryoprint-technician", "field-negotiator", "astronaut",
  })
  add("item", "worker-biter", 100, "x10")

  group("Public transport", "item", {
    "pneumatic-pipe", "pneumatic-pipe-to-ground", "tube-pump", "biterport",
    "locomotive", "transit-authorization", "passenger-wagon", "boarding-platform",
    "deboarding-platform", "public-train-stop", "personnel-deployment-office",
    "personnel-reception-office", "personnel-routing-sign", "personnel-routing-multisign",
  })
  group("Progress", "item", {"construction-robot", "spidertron", "rocket-part", "mech-armor"})
  add("technology", "rocket-silo")
  add("item", "rocket-part", 100)
  add("item_consumption", "space-platform-starter-pack")
  add("item_consumption", "space-platform-starter-pack", 10, "x2")
  group("Power", "item", {"solar-panel", "nuclear-reactor", "fusion-reactor"})
  add("item", "solar-panel", 1000, "x10")
  group("Liquid assets", "fluid", {"petroleum-gas", "liquid-coffee"})

  group("Research approvals", "technology", {
    "administratorio-medium-complaints", "administratorio-large-complaints",
    "administratorio-behemoth-complaints", "bureaucratic-transcendence",
    "planet-discovery-vulcanus", "planet-discovery-gleba", "planet-discovery-fulgora",
    "planet-discovery-aquilo", "interplanetary-tube-chromatic", "administratorium-slop-synthesis",
  })

  -- Expansion content also has placeholder prototypes in some base-only
  -- configurations, so gate the entire section as well as individual names.
  local space_age = script.active_mods["space-age"] ~= nil
  if space_age then
    group("Planetary paperwork", "item", {
      "blank-cyan-form", "industrial-charter", "blank-yellow-form", "conciliation-order",
      "blank-magenta-form", "electromagnetic-operating-license", "cyan-yellow-form",
      "cyan-magenta-form", "yellow-magenta-form", "trichromatic-permit",
      "cryogenic-operations-license", "unified-operations-charter", "promethium-research-charter",
    })
    group("Offworld offices", "item", {
      "chromatic-printer", "laser-printer", "capture-bureau", "captured-pentapod-specimen",
      "pentapod-egg", "foundry", "biochamber",
      "electromagnetic-plant", "cryogenic-plant", "biolab", "archive-recombination-bureau",
      "interplanetary-terminus", "involuntary-relocation-cannon", "synthetic-personnel-bureau",
    })
    group("Orbital employees", "item", {
      "administrative-space-station", "voluntary-exploration-space-miner",
      "orbital-employment-catapult", "trajectory-compliance-array",
      "senior-trajectory-compliance-array", "executive-trajectory-compliance-array",
    })
    group("Space tourism", "item", {
      "small-space-tourist", "medium-space-tourist", "big-space-tourist", "behemoth-space-tourist",
    })
    group("Automated bureaucracy", "item", {
      "ai-server", "heat-exhaust", "optical-fibre", "slop-refinery", "administrative-slop",
      "fabricated-citations", "unstaffed-operations-waiver",
    })
  end

  if script.active_mods.quality then
    group("Accreditation", "technology", {"epic-quality", "legendary-quality"})
    -- Without Space Age, Milestones already appends its Quality addon with
    -- these five module goals. Include them here only when that addon is off.
    if space_age then
      add("item", "quality-module", 1, nil, "rare")
      add("item", "quality-module-2", 1, nil, "rare")
      add("item", "quality-module-3", 1, nil, "epic")
      add("item", "quality-module-3", 1, nil, "legendary")
      add("item", "productivity-module-3", 100, "x10", "legendary")
    end
    for _, quality in ipairs({"rare", "epic", "legendary"}) do
      add("item", "power-armor-mk2", 1, nil, quality)
    end
    if space_age then
      add("item", "mech-armor", 1, nil, "epic")
      add("item", "mech-armor", 1, nil, "legendary")
    end
    add("item", "spidertron", 1, nil, "legendary")
    add("item", "raw-fish", 1, nil, "legendary")
  end

  local name = space_age and "Administratorio (Space Age)" or "Administratorio"
  local required_mods = {"administratorio"}
  if space_age then required_mods[#required_mods + 1] = "space-age" end
  if script.active_mods.quality then required_mods[#required_mods + 1] = "quality" end
  return {[name] = {required_mods = required_mods, milestones = milestones}}
end

return M
