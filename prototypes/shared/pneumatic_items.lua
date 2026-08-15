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
  "management-verbal-work-order", "management-written-work-order",
  "research-grant-work-order", "chemical-handling-work-order",
  "radiological-work-order",
  -- Administrative supplies and complaint pipeline
  "paper", "ink",
  "ticket-landscape", "ticket-smog", "ticket-noise", "ticket-unemployment",
  "ticket-littering", "ticket-hazmat", "ticket-loitering", "ticket-vagrancy",
  "ticket-automation",
  "filing-l", "filing-s", "filing-n", "filing-u",
  "filing-lt", "filing-h", "filing-lo", "filing-v", "filing-a",
  "case-s", "case-n", "case-u", "case-h", "case-lo", "case-v", "case-a",
  "brief-n", "brief-u", "brief-lo", "brief-v", "brief-a",
  "resolved-landscape", "resolved-smog", "resolved-noise", "resolved-unemployment",
  "resolved-littering", "resolved-hazmat", "resolved-loitering", "resolved-vagrancy",
  "resolved-automation",
  "osha-violation",
  "basic-excuse", "crappy-report", "credentials", "data",
  "good-excuse", "justification", "narrative", "policy", "regulation",
  "white-paper", "administrative-science-pack",
  "watercooler-gossip", "office-drama", "taxpayer-money",
  "useless-documentation", "refined-nonsense", "job-offer",
}

function M.as_set()
  local set = {}
  for _, name in ipairs(M.names) do
    set[name] = true
  end
  return set
end

return M
