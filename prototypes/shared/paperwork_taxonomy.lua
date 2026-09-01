local M = {}

local function document(rank, family, unlock_technology, colors)
  return {
    rank = rank,
    family = family,
    unlock_technology = unlock_technology,
    colors = colors or {},
    recyclable_input = true,
    generatable_output = true,
    restricted = false,
  }
end

-- Keep this list deliberately bounded. Every entry receives one native archive
-- reassignment recipe with three same-rank, color-safe candidate outputs.
M.documents = {
  ["blank-form"] = document(0, "blank"),
  ["blank-approval"] = document(0, "blank"),
  ["carbon-offset-certificate-basic"] = document(0, "compliance"),
  ["provisional-approval"] = document(0, "permit", "discovery-redundant-rubble"),
  ["safety-waiver-draft"] = document(0, "permit", "discovery-bullshit"),
  ["construction-permit-draft"] = document(0, "permit", "discovery-bullshit"),
  ["work-order"] = document(0, "work-order", "automation"),

  ["safety-waiver"] = document(1, "permit", "discovery-bullshit"),
  ["construction-permit"] = document(1, "permit", "discovery-bullshit"),
  ["research-grant-approval"] = document(1, "permit", "automation-science-pack"),
  ["transit-authorization"] = document(1, "permit", "railway"),
  ["form-27b-6"] = document(1, "compliance", "local-precedents"),
  ["safety-work-order"] = document(1, "work-order", "automation"),
  ["construction-work-order"] = document(1, "work-order", "automation"),
  ["research-grant-work-order"] = document(1, "work-order", "automation"),

  ["management-verbal-draft"] = document(2, "management", "verbal-approvals"),
  ["management-approval-verbal"] = document(2, "management", "verbal-approvals"),
  ["management-verbal-work-order"] = document(2, "work-order", "verbal-approvals"),
  ["environmental-impact-report"] = document(2, "compliance", "environmental-compliance"),
  ["carbon-offset-certificate-verified"] = document(2, "compliance", "environmental-compliance"),
  ["chemical-handling-work-order"] = document(2, "work-order", "environmental-compliance"),
  ["blank-cyan-form"] = document(2, "chromatic", "chromatic-printing", {cyan = true}),
  ["blank-yellow-form"] = document(2, "chromatic", "gleba-yellow-administration", {yellow = true}),
  ["blank-magenta-form"] = document(2, "chromatic", "chromatic-printing", {magenta = true}),

  ["management-approval-written"] = document(3, "management", "board-meetings"),
  ["management-written-work-order"] = document(3, "work-order", "executive-review"),
  ["radiological-work-order"] = document(3, "work-order", "radiological-compliance"),
  ["white-paper"] = document(3, "compliance", "eminent-domain-zoning"),
  ["cyan-yellow-form"] = document(3, "chromatic", "cyan-yellow-bureaucracy", {cyan = true, yellow = true}),
  ["cyan-magenta-form"] = document(3, "chromatic", "cyan-magenta-bureaucracy", {cyan = true, magenta = true}),
  ["yellow-magenta-form"] = document(3, "chromatic", "yellow-magenta-bureaucracy", {yellow = true, magenta = true}),
}

M.restricted_documents = {
  ["territorial-deed"] = true,
  ["territorial-resettlement-order"] = true,
  ["industrial-charter"] = true,
  ["thermal-process-license"] = true,
  ["calcite-reagent-waiver"] = true,
  ["offworld-metallurgy-charter"] = true,
  ["conciliation-order"] = true,
  ["archive-recovery-permit"] = true,
  ["digital-processing-certificate"] = true,
  ["electromagnetic-operating-license"] = true,
  ["data-recovery-order"] = true,
  ["trichromatic-permit"] = true,
  ["unified-operations-charter"] = true,
  ["cryogenic-operations-license"] = true,
  ["promethium-research-charter"] = true,
  ["hardened-data-vault"] = true,
}

function M.get(name)
  return name and M.documents[name] or nil
end

function M.is_recyclable(name)
  local entry = M.get(name)
  return entry ~= nil and entry.recyclable_input == true and entry.restricted ~= true
end

function M.is_generatable(name)
  local entry = M.get(name)
  return entry ~= nil and entry.generatable_output == true and entry.restricted ~= true
end

function M.recyclable_names()
  local names = {}
  for name, entry in pairs(M.documents) do
    if entry.recyclable_input and not entry.restricted then
      names[#names + 1] = name
    end
  end
  table.sort(names)
  return names
end

return M
