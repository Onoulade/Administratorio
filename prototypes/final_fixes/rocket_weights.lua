-- ADMINISTRATORIO: ROCKET CARGO WEIGHTS
--
-- Cargo rockets measure mass, not stack count.  Keep mass tied to the physical
-- object being shipped: paperwork is light, minerals and consumables are
-- modest, living creatures are heavy, and installed machinery is heavier still.
-- This deliberately avoids making a late-game permit weigh more than its
-- corresponding factory -- administrative prestige is not a dense material.

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
  -- Paperwork is carried in folders, not crates.  Cases and briefs include a
  -- small file, while the hardened data vault is actual physical equipment.
  for _, item in pairs(data.raw.item or {}) do
    local subgroup = item.subgroup or ""
    if subgroup:match("^forms-") or subgroup:match("^resolution-") then
      item.weight = (item.name:match("^case-") or item.name:match("^brief-")) and 250 * grams or 100 * grams
    end
  end

  -- Raw matter and ordinary office supplies.
  set_weights("item", {"bullshit-ore", "redundant-rubble", "verdigris-crust"}, 1 * kg)
  set_weights("item", {"compacted-rubble", "refined-nonsense"}, 5 * kg)
  set_weights("item", {"useless-documentation", "old-archive"}, 2 * kg)
  set_weights("item", {"paper", "coffee-bean"}, 100 * grams)
  set_weights("item", {"ink", "charged-toner", "transfer-emulsion", "thermal-transfer-sheet"}, 500 * grams)
  set_weight("item", "composite-chroma-ribbon", 1 * kg)

  -- Information and finance travel as small physical records.  A treasury
  -- bond is intentionally denser than loose currency but still not cargo-rich.
  for _, item in pairs(data.raw.item or {}) do
    if item.subgroup == "admin-bs-economy" then item.weight = 100 * grams end
  end
  set_weight("item", "taxpayer-money", 50 * grams)
  set_weight("item", "treasury-bond", 10 * grams)
  set_weight("item", "government-grant", 100 * grams)

  -- Space-age paperwork uses the same folder-sized baseline.  These items are
  -- intentionally explicit because most of them share the regular form groups.
  set_weights("item", {
    "heatproof-form-stock", "blank-cyan-form", "mycelial-form-stock", "blank-yellow-form",
    "signal-form-stock", "blank-magenta-form", "cyan-yellow-form", "cyan-magenta-form",
    "yellow-magenta-form", "permit-draft", "inspection-docket", "symbiosis-record",
    "conciliation-order", "archive-recovery-permit", "digital-processing-certificate",
    "electromagnetic-operating-license", "data-recovery-order", "trichromatic-permit",
    "unified-operations-charter", "public-transportation-contract", "cryogenic-operations-license",
    "promethium-research-charter", "embossed-seal", "industrial-charter",
    "territorial-resettlement-order", "territorial-deed", "thermal-process-license",
    "calcite-reagent-waiver", "offworld-metallurgy-charter", "asteroid-processing-docket",
    "orbital-infrastructure-permit",
  }, 100 * grams)
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

  -- A worker is a shipment of living biomass, not a stack of forms.  Senior
  -- and orbital roles scale with the biter class shown in their prototype.
  set_weights("item", {"job-offer"}, 100 * grams)
  set_weights("item", {"biter-worker", "biter-logistics-formation", "enrolled-biter", "worker-biter", "licensed-notary", "conciliation-officer", "relay-clerk", "cryoprint-technician"}, 100 * kg)
  set_weights("item", {"rideable-biter", "union-delegate", "chemical-operator", "nuclear-technician", "clerical-trainee", "management-trainee", "astronaut"}, 200 * kg)
  set_weights("item", {"middle-management-managing-manager", "training-briefed-middle-management-managing-manager", "staffing-briefed-middle-management-managing-manager", "compliance-briefed-middle-management-managing-manager", "liaison-briefed-middle-management-managing-manager", "orbital-briefed-middle-management-managing-manager", "hired-biter-capsule"}, 1 * tons)
  set_weight("ammo", "voluntary-exploration-space-miner", 1 * tons)

  -- Live tourism cargo follows the same small-to-behemoth progression as the
  -- underlying spitters.  Processing tokens are tiny but still deliberately
  -- weighted so every exported administratorio item has a defined mass.
  set_weight("item", "capture-bureau-processing-token", 100 * grams)
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

  -- Weapons, tools, and modules are small manufactured goods.
  set_weight("tool", "administrative-science-pack", 100 * grams)
  set_weight("module", "overtime-exemption", 1 * kg)
  set_weight("capsule", "hush-money", 1 * kg)
  set_weight("capsule", "promise", 500 * grams)
  set_weight("capsule", "eviction-notice", 1 * kg)
  set_weight("ammo", "orbital-deviation-order", 1 * kg)
  set_weight("ammo", "priority-orbital-deviation-order", 1 * kg)
  set_weight("selection-tool", "hired-biter-command-capsule", 1 * kg)
end

return M
