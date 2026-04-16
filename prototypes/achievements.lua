-- ADMINISTRATORIO: ACHIEVEMENTS
-- Thematic achievements rewarding progression milestones and bureaucratic absurdity.

local icons = "__administratorio__/graphics/icons/"

data:extend({
  -------------------------------------------------------------------------------
  -- TIER 0: GETTING STARTED
  -------------------------------------------------------------------------------
  {
    type = "build-entity-achievement",
    name = "welcome-to-the-department",
    to_build = "admin-station",
    icon = icons .. "admin-desk.png",
    icon_size = 64,
    order = "a[getting-started]-a",
    allowed_without_fight = true,
  },
  {
    type = "research-achievement",
    name = "discovery-of-bullshit",
    technology = "discovery-bullshit",
    icon = icons .. "bullshit-ore.png",
    icon_size = 64,
    order = "a[getting-started]-b",
    allowed_without_fight = true,
  },
  {
    type = "research-achievement",
    name = "ink-stained",
    technology = "printing-technology",
    icon = icons .. "ink-cartridge.png",
    icon_size = 64,
    order = "a[getting-started]-c",
    allowed_without_fight = true,
  },

  -------------------------------------------------------------------------------
  -- TIER 1: BUREAUCRACY BEGINS
  -------------------------------------------------------------------------------
  {
    type = "produce-per-hour-achievement",
    name = "form-27b-6-achievement",
    item_product = "form-27b-6",
    amount = 100,
    icon = icons .. "form-27b-6.png",
    icon_size = 64,
    order = "b[bureaucracy-begins]-a",
    allowed_without_fight = true,
  },
  {
    type = "produce-per-hour-achievement",
    name = "paper-pusher",
    item_product = "blank-form",
    amount = 1000,
    icon = icons .. "blank-form.png",
    icon_size = 64,
    order = "b[bureaucracy-begins]-b",
    allowed_without_fight = true,
  },
  {
    type = "research-achievement",
    name = "safety-first",
    technology = "administrative-bureaucracy",
    icon = icons .. "safety-waiver.png",
    icon_size = 64,
    order = "b[bureaucracy-begins]-c",
    allowed_without_fight = true,
  },
  {
    type = "use-item-achievement",
    name = "capsule-promise",
    to_use = "promise",
    amount = 1,
    limit_quality = "normal",
    icon = icons .. "bureaucratic-promise.png",
    icon_size = 64,
    order = "b[bureaucracy-begins]-d",
    allowed_without_fight = true,
  },

  -------------------------------------------------------------------------------
  -- TIER 2: MID GAME MILESTONES
  -------------------------------------------------------------------------------
  {
    type = "research-achievement",
    name = "its-a-copy-of-a-copy",
    technology = "local-precedents",
    icon = icons .. "useless-documentation.png",
    icon_size = 64,
    order = "c[mid-game]-a",
    allowed_without_fight = true,
  },
  {
    type = "build-entity-achievement",
    name = "permit-denied",
    to_build = "train-stop",
    amount = 10,
    icon = icons .. "transit-authorization.png",
    icon_size = 64,
    order = "c[mid-game]-b",
    allowed_without_fight = true,
  },
  {
    type = "build-entity-achievement",
    name = "coffee-break",
    to_build = "corporate-breakroom",
    icon = icons .. "corporate-breakroom.png",
    icon_size = 64,
    order = "c[mid-game]-c",
    allowed_without_fight = true,
  },
  {
    type = "research-achievement",
    name = "pneumatic-delivery",
    technology = "pneumatic-form-transport",
    icon = icons .. "blank-form.png",
    icon_size = 64,
    order = "c[mid-game]-d",
    allowed_without_fight = true,
  },

  -------------------------------------------------------------------------------
  -- TIER 3: INDUSTRIAL BUREAUCRACY
  -------------------------------------------------------------------------------
  {
    type = "build-entity-achievement",
    name = "propaganda-machine",
    to_build = "propaganda-distillery",
    icons = {{icon = "__base__/graphics/icons/oil-refinery.png", icon_size = 64, tint = {r=0.6, g=0.3, b=0.6, a=1}}},
    order = "d[industrial]-a",
    allowed_without_fight = true,
  },
  {
    type = "research-achievement",
    name = "endless-meetings",
    technology = "board-meetings",
    icon = icons .. "management-written-proposal.png",
    icon_size = 64,
    order = "d[industrial]-b",
    allowed_without_fight = true,
  },
  {
    type = "build-entity-achievement",
    name = "union-strong",
    to_build = "union-headquarters",
    icon = icons .. "government-grant.png",
    icon_size = 64,
    order = "d[industrial]-c",
    allowed_without_fight = true,
  },
  {
    type = "research-achievement",
    name = "environmental-compliance-achievement",
    technology = "environmental-compliance",
    icon = icons .. "environmental-impact-report.png",
    icon_size = 64,
    order = "d[industrial]-d",
    allowed_without_fight = true,
  },

  -------------------------------------------------------------------------------
  -- TIER 4: LATE GAME / MASTERY
  -------------------------------------------------------------------------------
  {
    type = "research-achievement",
    name = "constitutional-scholar",
    technology = "constitutional-law",
    icon = icons .. "regulation.png",
    icon_size = 64,
    order = "e[mastery]-a",
    allowed_without_fight = true,
  },
  {
    type = "research-achievement",
    name = "know-it-all",
    research_all = true,
    icon = icons .. "administrative-science-pack.png",
    icon_size = 256,
    icon_mipmaps = 4,
    order = "e[mastery]-b",
    allowed_without_fight = true,
  },
  {
    type = "use-item-achievement",
    name = "eviction-notice-achievement",
    to_use = "eviction-notice",
    amount = 100,
    limit_quality = "normal",
    icon = icons .. "osha-violation.png",
    icon_size = 64,
    order = "e[mastery]-c",
    allowed_without_fight = true,
  },
  {
    type = "train-path-achievement",
    name = "mass-transit",
    minimum_distance = 2000,
    icon = icons .. "transit-authorization.png",
    icon_size = 64,
    order = "e[mastery]-d",
    allowed_without_fight = true,
  },

  -------------------------------------------------------------------------------
  -- SCRIPTED ACHIEVEMENTS (unlocked via control.lua)
  -------------------------------------------------------------------------------
  {
    type = "achievement",
    name = "first-complaint",
    icon = icons .. "ticket-landscape.png",
    icon_size = 64,
    order = "f[scripted]-a",
    allowed_without_fight = true,
  },
  {
    type = "achievement",
    name = "case-closed",
    icon = icons .. "resolved-landscape.png",
    icon_size = 64,
    order = "f[scripted]-b",
    allowed_without_fight = true,
  },
  {
    type = "achievement",
    name = "protest-suppressed",
    icon = icons .. "basic-excuse.png",
    icon_size = 64,
    order = "f[scripted]-c",
    allowed_without_fight = true,
  },
  {
    type = "achievement",
    name = "department-of-everything",
    icon = icons .. "admin-desk.png",
    icon_size = 64,
    order = "f[scripted]-d",
    allowed_without_fight = true,
  },
  {
    type = "achievement",
    name = "full-resolution",
    icon = icons .. "taxpayer-money.png",
    icon_size = 64,
    order = "f[scripted]-e",
    allowed_without_fight = true,
  },
  {
    type = "achievement",
    name = "behemoth-paperwork",
    icon = icons .. "filing-l.png",
    icon_size = 64,
    order = "f[scripted]-f",
    allowed_without_fight = true,
  },
})
