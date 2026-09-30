-- Recipe-focused data-stage tests do not load building graphics/prototypes.
-- Give the palette pass named entity stubs without replacing existing entity
-- fixtures. Real prototype existence is checked by the Factorio startup matrix.
local M = {}
-- Captured native entity kinds: printer stubs must remain production machines,
-- otherwise the recipe batch classifier mistakes them for tool containers.
local names_by_type = {
  ["ammo-turret"] = {
    "executive-trajectory-compliance-array", "orbital-employment-catapult", "senior-trajectory-compliance-array",
    "trajectory-compliance-array",
  },
  ["assembling-machine"] = {
    "administrative-space-station", "ai-server", "chromatic-printer",
    "conciliation-desk", "corporate-breakroom", "digital-services-bureau",
    "field-office", "formation-center", "greenhouse",
    "laser-printer", "mechanical-printer", "notary-office",
    "office-desk", "printer-t1", "printer-t2",
    "propaganda-distillery", "resolution-office", "slop-refinery",
    "synthetic-personnel-bureau", "territorial-arbitration-post", "union-headquarters",
  },
  ["car"] = {
    "rideable-biter", "rideable-biter-mounted",
  },
  ["cargo-wagon"] = {
    "passenger-wagon",
  },
  ["constant-combinator"] = {
    "administrative-clock", "boarding-platform", "boarding-platform-placement-preview",
    "deboarding-platform", "deboarding-platform-placement-preview",
  },
  ["container"] = {
    "admin-station", "biter-station", "biterport",
    "transit-permit-chest", "tube-outtake",
  },
  ["furnace"] = {
    "archive-recombination-bureau", "capture-bureau", "interplanetary-terminus",
    "involuntary-relocation-cannon", "involuntary-relocation-receiver", "tube-intake",
  },
  ["heat-interface"] = {
    "heat-exhaust",
  },
  ["inserter"] = {
    "tube-pump",
  },
  ["logistic-container"] = {
    "paperwork-provider-chest", "paperwork-requester-chest", "paperwork-storage-chest",
  },
  ["pipe"] = {
    "optical-fibre", "pneumatic-pipe",
  },
  ["pipe-to-ground"] = {
    "pneumatic-pipe-to-ground",
  },
  ["roboport"] = {
    "biterport-placement-preview",
  },
  ["train-stop"] = {
    "public-train-stop",
  },
  ["unit"] = {
    "biter-worker-t1", "biter-worker-t2", "biter-worker-t3",
    "biterport-worker", "biterport-worker-express", "biterport-worker-fast",
    "field-office-worker", "hired-biter-unit",
  },
}
local type_by_name = {}
for kind, names in pairs(names_by_type) do
  for _, name in ipairs(names) do type_by_name[name] = kind end
end

function M.find_entity(raw, name)
  for kind in pairs(names_by_type) do
    if raw[kind] and raw[kind][name] then return raw[kind][name] end
  end
end

function M.add_entities(raw, groups)
  for _, names in pairs(groups) do
    for _, name in ipairs(names) do
      if not M.find_entity(raw, name) then
        local kind = assert(type_by_name[name], "Missing minimap fixture entity kind: " .. name)
        raw[kind] = raw[kind] or {}
        raw[kind][name] = {type = kind, name = name}
      end
    end
  end
end

return M
