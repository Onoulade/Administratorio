-- Short, task-focused guides to custom behavior. Recipe catalogs, packing
-- lists and research-stat tables belong in Factoriopedia, not this pane.
local features = require("feature_flags")
local space_age = features.space_age_enabled()
local working_hours = features.working_hours_enabled()
local prefix = "administratorio-"
local entries = {}

local function research(technology)
  return {type = "research", technology = technology}
end

local function built(...)
  local triggers = {}
  for _, entity in ipairs({...}) do
    triggers[#triggers + 1] = {type = "build-entity", entity = entity}
  end
  return #triggers == 1 and triggers[1] or {type = "or", triggers = triggers}
end

local function group(id, order, title, trigger)
  local name = prefix .. id
  entries[#entries + 1] = {
    type = "tips-and-tricks-item-category", name = name, order = "z-" .. order,
  }
  entries[#entries + 1] = {
    type = "tips-and-tricks-item", name = name, category = name,
    order = "a", indent = 0, is_title = true, trigger = trigger,
    starting_status = not trigger and "unlocked" or nil,
    localised_name = {"tips-and-tricks-category-name." .. id},
    localised_description = {"tips-and-tricks-item-description." .. prefix .. title},
  }
  return name
end

local function tip(id, category, order, trigger)
  entries[#entries + 1] = {
    type = "tips-and-tricks-item", name = prefix .. id, category = category,
    order = order, indent = 1, trigger = trigger,
  }
end

local basics = group("welcome", "a", "welcome")
tip("work-orders", basics, "b", research("automation"))
tip("field-office", basics, "c", built("field-office"))
if working_hours then
  tip("working-hours", basics, "d", built("office-desk", "union-headquarters", "biter-station", "biterport"))
  tip("administrative-clock", basics, "e", built("administrative-clock"))
end
if features.quality_enabled() then
  tip("quality", basics, "f", research("quality-module"))
end

local citizens = group("biter-complaints", "b", "biter-complaints", built("admin-station"))
tip("visitor-routing", citizens, "b", built("admin-station"))
tip("desk-signals", citizens, "c", built("admin-station"))
tip("frustration", citizens, "d", built("admin-station"))
tip("hard-mode", citizens, "e", built("admin-station"))
tip("evolution-approvals", citizens, "e1", built("admin-station"))
tip("hush-money", citizens, "f", research("nest-pacification"))
tip("nest-expropriation", citizens, "g", research("nest-expropriation"))

local workforce = group("biter-employment", "c", space_age and "space-age-enrollment" or "biter-employment", research("biter-employment"))
tip("biter-station", workforce, "b", built("biter-station"))
tip("worker-machines", workforce, "c", built("biter-station"))
tip("biterport", workforce, "d", research("biterport-logistics"))
tip("biterport-cargo", workforce, "e", research("biterport-logistics"))
tip("orphaned-workers", workforce, "f", built("biter-station", "biterport"))
tip("rideable-biter", workforce, "g", research("rideable-biter"))
tip("hired-biter", workforce, "h", research("hired-biter-fieldwork"))
tip("field-agent-controls", workforce, "i", research("hired-biter-fieldwork"))

local tubes = group("pneumatic-transport", "d", "pneumatic-transport", research("pneumatic-form-transport"))
tip("tube-limits", tubes, "b", research("pneumatic-form-transport"))
tip("tube-circuits", tubes, "c", research("pneumatic-form-transport"))
tip("tube-pump", tubes, "d", research("tube-pump"))

local rail = group("transit-authorization", "e", "transit-authorization", research("railway"))
tip("passenger-rail-service", rail, "b", research("passenger-rail-service"))
tip("passenger-boarding", rail, "c", research("passenger-rail-service"))
tip("passenger-unboarding", rail, "d", research("passenger-rail-service"))
tip("passenger-signals", rail, "e", research("passenger-rail-service"))

if space_age then
  tip("public-train-stop", rail, "f", research("bureaucratic-transcendence"))
  tip("management-briefings", workforce, "j", research("management-formation"))
  tip("specialist-approval", workforce, "k", {type = "or", triggers = {
    research("foundry"), research("biochamber"), research("electromagnetic-plant"), research("cryogenic-plant"),
  }})
  if working_hours then
    tip("unstaffed-operations", workforce, "l", research("unstaffed-operations"))
  end

  local paths = group("personnel-routing", "f", "personnel-routing", research("personnel-routing"))
  tip("personnel-traffic", paths, "b", research("personnel-routing"))
  tip("personnel-counts", paths, "b1", research("personnel-routing"))
  tip("personnel-multisign", paths, "c", research("personnel-routing-multisign"))
  tip("personnel-circuits", paths, "d", research("personnel-routing-multisign"))
  tip("personnel-spoilage", paths, "e", research("personnel-routing"))

  local orbit = group("trajectory-compliance-arrays", "g", "trajectory-compliance-arrays", research("orbital-compliance-systems"))
  tip("orbital-employment-catapult", orbit, "b", research("orbital-compliance-systems"))
  tip("orbital-miner-recovery", orbit, "c", research("orbital-compliance-systems"))

  local planets = group("offworld-economy", "h", "offworld-economy", research("space-platform"))
  tip("territorial-arbitration", planets, "b", research("vulcanus-certification"))
  tip("pentapod-bargaining", planets, "c", research("planet-discovery-gleba"))
  tip("capture-bureau", planets, "d", research("gleba-conciliation"))
  tip("space-tourism", planets, "e", research("cyan-yellow-bureaucracy"))
  tip("archive-recombination", planets, "f", research("archive-recombination"))
  tip("ai-cooling", planets, "g", research("aquilo-ai-inference"))

  local trunk = group("interplanetary-terminus", "i", "interplanetary-terminus", research("interplanetary-tube-network"))
  tip("terminus-circuits", trunk, "b", research("interplanetary-tube-network"))
  tip("interplanetary-trunk", trunk, "c", research("interplanetary-tube-network"))
  tip("relocation-cannon", trunk, "d", research("involuntary-relocation"))
  tip("egg-couriers", trunk, "e", research("egg-courier-formation"))
end

data:extend(entries)
