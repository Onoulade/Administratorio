-- Pneumatic tube payloads shared by the data stage and runtime.
-- Keep this module dependency-free: Factorio loads it in both contexts.

local M = {}

M.names = {
  -- PAPERWORK_ITEMS
  "work-order", "form-27b-6", "research-grant-approval", "provisional-approval",
  "safety-waiver", "safety-waiver-draft",
  "construction-permit", "construction-permit-draft",
  "transit-authorization",
  "management-approval-verbal", "management-verbal-draft",
  "management-approval-written", "management-written-proposal",
  "carbon-offset-certificate-basic", "carbon-offset-certificate-verified",
  "environmental-impact-report",
  "blank-form", "blank-approval", "blank-directive",
  "treasury-bond", "government-grant",
  "safety-work-order", "construction-work-order",
  "provisional-work-order",
  "management-verbal-work-order", "management-written-work-order",
  "research-grant-work-order", "chemical-handling-work-order",
  "radiological-work-order",
  -- Administrative supplies and complaint pipeline
  "paper", "ink",
  "ticket-landscape", "ticket-smog", "ticket-noise", "ticket-unemployment",
  "ticket-littering", "ticket-hazmat", "ticket-loitering", "ticket-vagrancy",
  "filing-l", "filing-s", "filing-n", "filing-u",
  "filing-lt", "filing-h", "filing-lo", "filing-v",
  "case-s", "case-n", "case-u", "case-h", "case-lo", "case-v",
  "brief-n", "brief-u", "brief-lo", "brief-v",
  "resolved-landscape", "resolved-smog", "resolved-noise", "resolved-unemployment",
  "resolved-littering", "resolved-hazmat", "resolved-loitering", "resolved-vagrancy",
  "osha-violation",
  "basic-excuse", "crappy-report", "credentials", "data",
  "good-excuse", "justification", "narrative", "policy", "regulation",
  "white-paper", "administrative-science-pack",
  "watercooler-gossip", "office-drama", "taxpayer-money",
  "useless-documentation", "refined-nonsense", "job-offer",
}

-- Finished Space Age documents may use local pneumatic networks. Form-stock
-- materials are deliberately absent: heatproof-form-stock,
-- mycelial-form-stock, and signal-form-stock remain ordinary belt cargo.
-- Keep this separate from M.names because the interplanetary trunk uses the
-- core list as its base tier and admits only its explicit chromatic exports.
M.space_age_names = {
  "blank-cyan-form", "blank-yellow-form", "blank-magenta-form",
  "cyan-yellow-form", "cyan-magenta-form", "yellow-magenta-form",
  "permit-draft", "inspection-docket", "symbiosis-record",
  "conciliation-order", "archive-recovery-permit",
  "digital-processing-certificate", "electromagnetic-operating-license",
  "data-recovery-order", "hardened-data-vault", "trichromatic-permit",
  "unified-operations-charter", "public-transportation-contract",
  "cryogenic-operations-license", "promethium-research-charter",
  "embossed-seal", "industrial-charter", "territorial-resettlement-order",
  "territorial-deed", "thermal-process-license", "calcite-reagent-waiver",
  "offworld-metallurgy-charter", "orbital-infrastructure-permit",
}

function M.all(space_age_enabled)
  local names = {}
  for _, name in ipairs(M.names) do names[#names + 1] = name end
  if space_age_enabled then
    for _, name in ipairs(M.space_age_names) do names[#names + 1] = name end
  end
  return names
end

function M.as_set(space_age_enabled)
  local set = {}
  for _, name in ipairs(M.all(space_age_enabled)) do
    set[name] = true
  end
  return set
end

return M
