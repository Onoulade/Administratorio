-- ADMINISTRATORIO: TIPS AND TRICKS
-- In-game tutorial entries for the tips-and-tricks pane.
--
-- Each major system owns a category instead of contributing to one enormous
-- Administratorio drawer.  Category titles are real overview tips, and child
-- entries unlock when the mechanic they explain first becomes available.

local feature_flags = require("feature_flags")
local working_hours_enabled = feature_flags.working_hours_enabled()
local space_age_enabled = feature_flags.space_age_enabled()

local function category(name, order)
  return {
    type = "tips-and-tricks-item-category",
    name = name,
    order = order,
  }
end

local function tip(name, category_name, order, fields)
  local prototype = {
    type = "tips-and-tricks-item",
    name = name,
    category = category_name,
    order = order,
    indent = 1,
  }
  for key, value in pairs(fields or {}) do prototype[key] = value end
  if prototype.is_title then prototype.indent = 0 end
  return prototype
end

local function research_tip(name, category_name, order, technology, fields)
  fields = fields or {}
  fields.trigger = {type = "research", technology = technology}
  return tip(name, category_name, order, fields)
end

local foundations = "administratorio-welcome"
local citizen_services = "administratorio-biter-complaints"
local workforce = "administratorio-biter-employment"

data:extend({
  category(foundations, "z-a[administratorio-foundations]"),
  category(citizen_services, "z-b[administratorio-citizens]"),
  category(workforce, "z-c[administratorio-workforce]"),
})

data:extend({
  -- Foundations
  tip("administratorio-welcome", foundations, "a", {
    is_title = true,
    starting_status = "unlocked",
  }),
  research_tip("administratorio-work-orders", foundations, "b", "automation"),
  research_tip("administratorio-bullshit-economy", foundations, "c", "discovery-bullshit"),
  research_tip("administratorio-admin-science", foundations, "d", "administrative-science-research"),
  research_tip("administratorio-propaganda-distillery", foundations, "e", "industrial-propaganda"),
  research_tip("administratorio-transit-authorization", foundations, "f", "railway"),
  research_tip("administratorio-pneumatic-transport", foundations, "g", "pneumatic-form-transport"),

  -- Citizen services and territorial control
  tip("administratorio-biter-complaints", citizen_services, "a", {
    is_title = true,
    trigger = {type = "build-entity", entity = "admin-station"},
  }),
  tip("administratorio-frustration", citizen_services, "b", {
    trigger = {type = "build-entity", entity = "admin-station"},
  }),
  tip("administratorio-complaint-chain", citizen_services, "c", {
    trigger = {type = "build-entity", entity = "admin-station"},
  }),
  tip("administratorio-field-office", citizen_services, "d", {
    trigger = {type = "build-entity", entity = "field-office"},
  }),
  research_tip("administratorio-hush-money", citizen_services, "e", "nest-pacification"),
  research_tip("administratorio-nest-expropriation", citizen_services, "f", "nest-expropriation"),

  -- Workforce and logistics
  research_tip("administratorio-biter-employment", workforce, "a", "biter-employment-office", {
    is_title = true,
  }),
  tip("administratorio-biter-workers", workforce, "b", {
    trigger = {type = "build-entity", entity = "formation-center"},
  }),
  tip("administratorio-biter-station", workforce, "c", {
    trigger = {type = "build-entity", entity = "biter-station"},
  }),
  research_tip("administratorio-rideable-biter", workforce, "d", "rideable-biter"),
  research_tip("administratorio-biterport", workforce, "e", "biterport-logistics"),
  research_tip("administratorio-hired-biter", workforce, "f", "hired-biter-fieldwork"),
})

if working_hours_enabled then
  data:extend({
    tip("administratorio-working-hours", foundations, "h", {
      trigger = {
        type = "or",
        triggers = {
          {type = "build-entity", entity = "office-desk"},
          {type = "build-entity", entity = "union-headquarters"},
          {type = "build-entity", entity = "biter-station"},
          {type = "build-entity", entity = "biterport"},
        },
      },
    }),
  })
end

if space_age_enabled then
  local orbit = "administratorio-workforce-formation-title"
  local chromatic = "administratorio-chromatic-printing"
  local vulcanus = "administratorio-vulcanus-certification"
  local gleba = "administratorio-gleba-conciliation"
  local interplanetary = "administratorio-cross-planet-bureaucracy"
  local fulgora = "administratorio-fulgora-digital-services"
  local aquilo = "administratorio-aquilo-tube-network"

  data:extend({
    category(orbit, "z-d[administratorio-orbit]"),
    category(chromatic, "z-e[administratorio-chromatic]"),
    category(vulcanus, "z-f[administratorio-vulcanus]"),
    category(gleba, "z-g[administratorio-gleba]"),
    category(interplanetary, "z-h[administratorio-interplanetary]"),
    category(fulgora, "z-i[administratorio-fulgora]"),
    category(aquilo, "z-j[administratorio-aquilo]"),
  })

  data:extend({
    -- Space Age changes the desk-to-worker conversion before the dedicated
    -- orbital category is relevant, so keep this beside the core hiring tips.
    research_tip("administratorio-space-age-enrollment", workforce, "g", "worker-formation"),

    -- Orbital administration
    research_tip("administratorio-workforce-formation-title", orbit, "a", "space-platform", {
      is_title = true,
    }),
    research_tip("administratorio-offworld-economy", orbit, "b", "space-platform"),
    research_tip("administratorio-orbital-infrastructure-permit", orbit, "c", "space-platform"),
    research_tip("administratorio-workforce-formation", orbit, "d", "worker-formation"),
    research_tip("administratorio-management-briefings", orbit, "e", "management-formation"),
    research_tip("administratorio-orbital-specialists", orbit, "f", "specialized-formation"),
    research_tip("administratorio-administrative-space-station", orbit, "g", "orbital-employment-infrastructure"),
    research_tip("administratorio-trajectory-compliance-arrays", orbit, "h", "orbital-compliance-systems"),
    research_tip("administratorio-senior-trajectory-compliance-array", orbit, "i", "trajectory-compliance-jurisdiction-2"),
    research_tip("administratorio-executive-trajectory-compliance-array", orbit, "j", "trajectory-compliance-jurisdiction-3"),
    research_tip("administratorio-trajectory-compliance-speed", orbit, "k", "trajectory-compliance-speed-1"),
    research_tip("administratorio-orbital-employment-cannon", orbit, "l", "orbital-compliance-systems"),
    research_tip("administratorio-orbital-employment-damage", orbit, "m", "orbital-employment-damage-1"),
    research_tip("administratorio-orbital-employment-capacity", orbit, "n", "orbital-employment-capacity-1"),

    -- Chromatic printing
    research_tip("administratorio-chromatic-printing", chromatic, "a", "chromatic-printing", {
      is_title = true,
    }),
    research_tip("administratorio-chromatic-printer", chromatic, "b", "chromatic-printing"),
    research_tip("administratorio-chromatic-inks", chromatic, "c", "chromatic-printing"),
    research_tip("administratorio-multicolor-forms", chromatic, "d", "cyan-yellow-bureaucracy"),

    -- Vulcanus
    research_tip("administratorio-vulcanus-certification", vulcanus, "a", "vulcanus-certification", {
      is_title = true,
    }),
    research_tip("administratorio-vulcanus-manifest", vulcanus, "b", "vulcanus-certification"),
    research_tip("administratorio-notary-office", vulcanus, "c", "vulcanus-certification"),
    research_tip("administratorio-territorial-arbitration", vulcanus, "d", "vulcanus-certification"),
    research_tip("administratorio-vulcanus-export-charters", vulcanus, "e", "vulcanus-export-charters"),

    -- Gleba
    research_tip("administratorio-gleba-conciliation", gleba, "a", "gleba-conciliation", {
      is_title = true,
    }),
    research_tip("administratorio-gleba-manifest", gleba, "b", "gleba-conciliation"),
    research_tip("administratorio-yellow-paperwork-spoilage", gleba, "c", "gleba-conciliation"),
    research_tip("administratorio-conciliation-desk", gleba, "d", "gleba-conciliation"),
    research_tip("administratorio-capture-bureau", gleba, "e", "gleba-conciliation"),
    research_tip("administratorio-pentapod-bargaining", gleba, "f", "gleba-conciliation"),

    -- Cross-planet paperwork and tourism
    research_tip("administratorio-cross-planet-bureaucracy", interplanetary, "a", "cyan-yellow-bureaucracy", {
      is_title = true,
    }),
    research_tip("administratorio-cyan-yellow-bureaucracy", interplanetary, "b", "cyan-yellow-bureaucracy"),
    research_tip("administratorio-space-tourism", interplanetary, "c", "cyan-yellow-bureaucracy"),
    research_tip("administratorio-cyan-magenta-bureaucracy", interplanetary, "d", "cyan-magenta-bureaucracy"),
    research_tip("administratorio-yellow-magenta-bureaucracy", interplanetary, "e", "yellow-magenta-bureaucracy"),

    -- Fulgora
    research_tip("administratorio-fulgora-digital-services", fulgora, "a", "fulgora-digital-services", {
      is_title = true,
    }),
    research_tip("administratorio-fulgora-archives", fulgora, "b", "archive-recombination"),
    research_tip("administratorio-digital-services-bureau", fulgora, "c", "fulgora-digital-services"),
    research_tip("administratorio-archive-recombination", fulgora, "d", "archive-recombination"),

    -- Aquilo, the chromatic trunk, and the administrative endgame
    research_tip("administratorio-aquilo-tube-network", aquilo, "a", "interplanetary-tube-chromatic", {
      is_title = true,
    }),
    research_tip("administratorio-aquilo-manifest", aquilo, "b", "interplanetary-tube-chromatic"),
    research_tip("administratorio-laser-printer", aquilo, "c", "interplanetary-tube-chromatic"),
    research_tip("administratorio-interplanetary-terminus", interplanetary, "f", "interplanetary-tube-network"),
    research_tip("administratorio-interplanetary-trunk", interplanetary, "g", "interplanetary-tube-network"),
    research_tip("administratorio-relocation-cannon", interplanetary, "h", "involuntary-relocation"),
    research_tip("administratorio-trunk-capacity", aquilo, "d", "interplanetary-tube-capacity-2"),
    research_tip("administratorio-chromatic-trunk", aquilo, "e", "interplanetary-tube-chromatic"),
    research_tip("administratorio-egg-couriers", aquilo, "f", "egg-courier-formation"),
    research_tip("administratorio-promethium-administration", aquilo, "h", "promethium-science-pack"),
    research_tip("administratorio-bureaucratic-transcendence", aquilo, "i", "bureaucratic-transcendence"),
    research_tip("administratorio-public-train-stop", aquilo, "j", "bureaucratic-transcendence"),
  })
end
