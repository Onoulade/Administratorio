-- Shared data/control-stage definition for research-gated enemy evolution.
-- Keep this module free of Factorio runtime globals so prototype and unit tests
-- consume exactly the same milestone names and ceilings as control.lua.
local M = {}

M.BASE_CAP = 0.20

M.MILESTONES = {
  {
    id = "medium",
    technology = "administratorio-medium-complaints",
    cap = 0.45,
    legacy_technologies = {"smog-abatement", "hazmat-response"},
    complaints = {"ticket-smog", "ticket-hazmat"},
    recipes = {
      "filing-smog", "case-smog", "smog-final",
      "filing-hazmat", "case-hazmat", "hazmat-final",
    },
  },
  {
    id = "large",
    technology = "administratorio-large-complaints",
    cap = 0.60,
    legacy_technologies = {"noise-ordinances", "loitering-ordinances"},
    complaints = {"ticket-noise", "ticket-loitering"},
    recipes = {
      "filing-noise", "case-noise", "noise-final",
      "filing-loitering", "case-loitering", "loitering-final",
    },
  },
  {
    id = "behemoth",
    technology = "administratorio-behemoth-complaints",
    cap = 1.00,
    legacy_technologies = {"constitutional-law", "vagrancy-ordinances"},
    complaints = {"ticket-unemployment", "ticket-vagrancy"},
    recipes = {
      "filing-unemployment", "case-unemployment", "unemployment-final",
      "filing-vagrancy", "case-vagrancy", "vagrancy-final",
    },
  },
}

M.ENEMY_SIZE_LEVEL = {
  ["small-biter"] = 0,
  ["small-spitter"] = 0,
  ["medium-biter"] = 1,
  ["medium-spitter"] = 1,
  ["big-biter"] = 2,
  ["big-spitter"] = 2,
  ["behemoth-biter"] = 3,
  ["behemoth-spitter"] = 3,
}

return M
