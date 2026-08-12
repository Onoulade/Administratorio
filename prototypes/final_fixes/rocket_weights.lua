-- ADMINISTRATORIO: ROCKET CARGO WEIGHTS
--
-- Cargo rockets measure mass, not stack count.  Keep mass tied to the physical
-- object being shipped: loose paper and envelopes are the only sub-kilogram
-- cargo, registered forms and records start at one kilogram, living creatures
-- and installed machinery weigh far more.  This deliberately avoids making a
-- late-game permit weigh more than its corresponding factory -- administrative
-- prestige is not a dense material, but official paperwork is not weightless.

local M = {}

local function set_weight(prototype_type, name, weight)
  local prototype = data.raw[prototype_type] and data.raw[prototype_type][name]
  if prototype then prototype.weight = weight end
end

local function set_weights(prototype_type, names, weight)
  for _, name in ipairs(names) do
    set_weight(prototype_type, name, weight)
  end
end

function M.apply()
  -- Paperwork is carried in folders, and even a folder of blank sheets starts
  -- at one kilogram.  The weight of a document scales with its authority class:
  -- blank stock and drafts are the floor, stamped instruments gain mass, and
  -- sealed charters and deeds are the heavy institutional records.
  -- This base pass guarantees every forms-*/resolution-* item has a defined
  -- weight; the tier tables below override the higher-authority records.
  for _, item in pairs(data.raw.item or {}) do
    local subgroup = item.subgroup or ""
    if subgroup:match("^forms-") or subgroup:match("^resolution-") then
      item.weight = (item.name:match("^case-") or item.name:match("^brief-")) and 3 * kg or 1 * kg
    end
  end

  -- Complaint paperwork scales with the stage of resolution: a ticket is one
  -- sheet, a filing adds evidence, a case is bound, a brief is a volume, and a
  -- resolved item is the final registered record.
  local resolution_stage = {
    ["ticket-"] = 1 * kg,
    ["filing-"] = 2 * kg,
    ["case-"] = 3 * kg,
    ["brief-"] = 4 * kg,
    ["resolved-"] = 5 * kg,
  }
  for _, item in pairs(data.raw.item or {}) do
    if (item.subgroup or ""):match("^resolution-") then
      for prefix, weight in pairs(resolution_stage) do
        if item.name:sub(1, #prefix) == prefix then
          item.weight = weight
          break
        end
      end
    end
  end
  set_weight("item", "osha-violation", 2 * kg)

  -- Blank sheets, drafts, and templates: the floor of the filing cabinet.
  set_weights("item", {
    "blank-form", "blank-approval", "blank-directive", "carbon-offset-certificate-basic",
    "safety-waiver-draft", "construction-permit-draft", "management-verbal-draft",
    "management-written-proposal",
  }, 1 * kg)

  -- Stamped single instruments: one signature, no witnesses.
  set_weights("item", {
    "provisional-approval", "safety-waiver", "transit-authorization", "work-order",
    "form-27b-6", "research-grant-approval",
  }, 2 * kg)

  -- Authorized instruments: multi-party approvals and the working documents
  -- that actually let machines operate.
  set_weights("item", {
    "construction-permit", "management-approval-verbal", "provisional-work-order",
    "safety-work-order", "construction-work-order", "research-grant-work-order",
  }, 3 * kg)

  -- Certified and heavy institutional paperwork: the near-sealed records.
  set_weights("item", {
    "management-approval-written", "environmental-impact-report",
    "carbon-offset-certificate-verified",
  }, 4 * kg)
  set_weights("item", {
    "management-verbal-work-order", "management-written-work-order",
    "chemical-handling-work-order",
  }, 5 * kg)
  set_weight("item", "radiological-work-order", 10 * kg)

  -- Raw matter and ordinary office supplies.  Refined derivatives are denser
  -- than the loose ore they came from.
  set_weights("item", {"bullshit-ore", "redundant-rubble", "verdigris-crust"}, 1 * kg)
  set_weights("item", {"compacted-rubble", "refined-nonsense"}, 5 * kg)
  set_weights("item", {"useless-documentation", "old-archive"}, 2 * kg)
  set_weights("item", {"paper", "coffee-bean"}, 100 * grams)
  set_weights("item", {"ink", "charged-toner", "transfer-emulsion", "thermal-transfer-sheet"}, 500 * grams)
  set_weight("item", "composite-chroma-ribbon", 1 * kg)

  -- BS-economy paperwork scales with the tier of the lie: raw dubious data is
  -- the lightest real document, and a polished regulation is a hefty file.
  for _, item in pairs(data.raw.item or {}) do
    if item.subgroup == "admin-bs-economy" then item.weight = 1 * kg end
  end
  set_weights("item", {"basic-excuse", "crappy-report", "watercooler-gossip", "office-drama", "dubious-data"}, 1 * kg)
  set_weights("item", {"good-excuse", "data"}, 2 * kg)
  set_weights("item", {"credentials", "justification", "narrative"}, 3 * kg)
  set_weights("item", {"white-paper", "policy"}, 5 * kg)
  set_weight("item", "regulation", 10 * kg)
  set_weight("item", "taxpayer-money", 50 * grams)
  set_weight("item", "treasury-bond", 1 * kg)
  set_weight("item", "government-grant", 5 * kg)

  -- Space-age paperwork follows the same folder tiers as Nauvis paperwork:
  -- blank printed stocks and combined forms are sheets, dockets and records
  -- gain evidence mass, and certified licenses, charters, and deeds carry the
  -- weight of the sealed office.
  set_weights("item", {
    "heatproof-form-stock", "blank-cyan-form", "mycelial-form-stock", "blank-yellow-form",
    "signal-form-stock", "blank-magenta-form", "cyan-yellow-form", "cyan-magenta-form",
    "yellow-magenta-form", "permit-draft", "orbital-operations-form", "orbital-tourism-form",
  }, 1 * kg)
  set_weights("item", {"inspection-docket", "symbiosis-record", "archive-recovery-permit", "conciliation-order"}, 2 * kg)
  set_weights("item", {"embossed-seal", "digital-processing-certificate", "data-recovery-order", "asteroid-processing-docket"}, 3 * kg)
  set_weight("item", "electromagnetic-operating-license", 4 * kg)
  set_weights("item", {
    "trichromatic-permit", "unified-operations-charter", "public-transportation-contract",
    "cryogenic-operations-license", "industrial-charter", "territorial-resettlement-order",
    "thermal-process-license", "calcite-reagent-waiver", "offworld-metallurgy-charter",
  }, 5 * kg)
  set_weights("item", {
    "territorial-deed", "promethium-research-charter", "orbital-infrastructure-permit",
  }, 10 * kg)
  set_weight("item", "hardened-data-vault", 10 * kg)

  -- Buildings follow vanilla's material-scale conventions: compact office
  -- equipment is tens of kg, industrial facilities hundreds, and orbital
  -- installations use tonne-scale shipments.
  set_weights("item", {"pneumatic-pipe", "pneumatic-pipe-to-ground"}, 5 * kg)
  set_weights("item", {"tube-intake", "tube-outtake", "paperwork-provider-chest", "paperwork-storage-chest", "paperwork-requester-chest", "transit-permit-chest"}, 20 * kg)
  set_weights("item", {"office-desk", "field-office", "admin-station", "biter-station", "printer-t1", "printer-t2", "mechanical-printer"}, 50 * kg)
  set_weights("item", {"greenhouse", "formation-center", "resolution-office", "biterport", "propaganda-distillery", "corporate-breakroom", "union-headquarters"}, 200 * kg)
  set_weights("item", {"capture-bureau", "conciliation-desk", "territorial-arbitration-post", "digital-services-bureau", "chromatic-printer", "laser-printer", "notary-office", "public-train-stop", "archive-recombination-bureau"}, 100 * kg)
  set_weights("item", {"trajectory-compliance-array", "senior-trajectory-compliance-array", "executive-trajectory-compliance-array", "orbital-employment-cannon", "administrative-space-station", "interplanetary-fax-exchange", "fax-emitter"}, 1 * tons)

  -- A worker is a shipment of living biomass, not a stack of forms.  Weights
  -- follow the biter class shown in each prototype: small at 100kg, medium at
  -- 200kg, big at 400kg, and behemoth managers at a full tonne.
  set_weights("item", {"job-offer"}, 1 * kg)
  set_weights("item", {"biter-worker", "biter-logistics-formation", "enrolled-biter", "worker-biter", "licensed-notary", "conciliation-officer", "relay-clerk", "cryoprint-technician"}, 100 * kg)
  set_weights("item", {"rideable-biter", "union-delegate", "chemical-operator", "nuclear-technician", "clerical-trainee"}, 200 * kg)
  set_weights("item", {"management-trainee", "astronaut"}, 400 * kg)
  set_weights("item", {"middle-management-managing-manager", "training-briefed-middle-management-managing-manager", "staffing-briefed-middle-management-managing-manager", "compliance-briefed-middle-management-managing-manager", "liaison-briefed-middle-management-managing-manager", "orbital-briefed-middle-management-managing-manager", "hired-biter-capsule"}, 1 * tons)
  set_weight("ammo", "voluntary-exploration-space-miner", 1 * tons)

  -- Live tourism cargo follows the same small-to-behemoth progression as the
  -- underlying spitters.  The captured specimen is a heavy living load.
  set_weight("item", "captured-pentapod-specimen", 20 * kg)
  local tourism_weights = {
    ["small"] = 50 * kg,
    ["medium"] = 100 * kg,
    ["big"] = 200 * kg,
    ["behemoth"] = 500 * kg,
  }
  for size, weight in pairs(tourism_weights) do
    set_weight("item", size .. "-spitter-tourism-package", weight)
    set_weight("item", size .. "-space-tourist", weight)
  end

  -- Weapons, tools, and modules are small manufactured goods.  The
  -- administrative science pack matches vanilla science at one kilogram, so an
  -- orbital lab still needs a real rocket budget instead of shipping research
  -- on cheap paper.
  set_weight("tool", "administrative-science-pack", 1 * kg)
  set_weight("module", "overtime-exemption", 1 * kg)
  set_weight("capsule", "hush-money", 1 * kg)
  set_weight("capsule", "promise", 500 * grams)
  set_weight("capsule", "eviction-notice", 1 * kg)
  set_weight("ammo", "orbital-deviation-order", 1 * kg)
  set_weight("ammo", "priority-orbital-deviation-order", 1 * kg)
  set_weight("selection-tool", "hired-biter-command-capsule", 1 * kg)
end

return M
