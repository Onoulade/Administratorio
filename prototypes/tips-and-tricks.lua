-- ADMINISTRATORIO: TIPS AND TRICKS
-- In-game tutorial entries for the tips-and-tricks pane.

local feature_flags = require("feature_flags")
local working_hours_enabled = feature_flags.working_hours_enabled()

data:extend({
  -- Category
  {
    type = "tips-and-tricks-item-category",
    name = "administratorio",
    order = "z-a"
  },

  -- Welcome (title, unlocked from start)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-welcome",
    category = "administratorio",
    order = "a",
    is_title = true,
    starting_status = "unlocked",
    indent = 0
  },

  -- Paperwork & Printing (unlocked from start)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-paperwork",
    category = "administratorio",
    order = "b",
    starting_status = "unlocked",
    indent = 1
  },

  -- Regulation & Form Tiers (unlocks with automation)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-regulation",
    category = "administratorio",
    order = "c",
    indent = 1,
    trigger = {
      type = "research",
      technology = "automation"
    }
  },

  -- Machine Operating Paperwork (unlock when the player first builds a covered machine)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-operating-paperwork",
    category = "administratorio",
    order = "c2",
    indent = 1,
    trigger = {
      type = "or",
      triggers = {
        { type = "build-entity", entity = "stone-furnace" },
        { type = "build-entity", entity = "steel-furnace" },
        { type = "build-entity", entity = "electric-furnace" },
        { type = "build-entity", entity = "oil-refinery" },
        { type = "build-entity", entity = "chemical-plant" },
        { type = "build-entity", entity = "centrifuge" },
      }
    }
  },

  -- Biter Complaints (unlock when the first admin station is built)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-biter-complaints",
    category = "administratorio",
    order = "d",
    indent = 1,
    trigger = {
      type = "build-entity",
      entity = "admin-station"
    }
  },

  -- Frustration (unlock when the first admin station is built)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-frustration",
    category = "administratorio",
    order = "e",
    indent = 1,
    trigger = {
      type = "build-entity",
      entity = "admin-station"
    }
  },

  -- Protest & Resolution (unlock when the first admin station is built)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-protest-resolution",
    category = "administratorio",
    order = "f",
    indent = 1,
    trigger = {
      type = "build-entity",
      entity = "admin-station"
    }
  },

  -- Nest Expropriation (unlocks with the actual eviction-notice technology)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-nest-expropriation",
    category = "administratorio",
    order = "g",
    indent = 1,
    trigger = {
      type = "research",
      technology = "nest-expropriation"
    }
  },

  -- Propaganda Distillery (unlocks with industrial-propaganda — distillery unlocked here)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-propaganda-distillery",
    category = "administratorio",
    order = "g2",
    indent = 1,
    trigger = {
      type = "research",
      technology = "industrial-propaganda"
    }
  },

  -- Complaint Chain (unlock when the first admin station is built)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-complaint-chain",
    category = "administratorio",
    order = "h",
    indent = 1,
    trigger = {
      type = "build-entity",
      entity = "admin-station"
    }
  },

  -- Pneumatic Transport (unlocks with pneumatic-form-transport)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-pneumatic-transport",
    category = "administratorio",
    order = "i",
    indent = 1,
    trigger = {
      type = "research",
      technology = "pneumatic-form-transport"
    }
  },

  -- Bullshit Economy (unlocks with discovery-bullshit)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-bullshit-economy",
    category = "administratorio",
    order = "j",
    indent = 1,
    trigger = {
      type = "research",
      technology = "discovery-bullshit"
    }
  },

  -- Transit Authorization (unlocks with railway)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-transit-authorization",
    category = "administratorio",
    order = "k",
    indent = 1,
    trigger = {
      type = "research",
      technology = "railway"
    }
  },

  -- Admin Science (unlocks with administrative-science-research)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-admin-science",
    category = "administratorio",
    order = "m",
    indent = 1,
    trigger = {
      type = "research",
      technology = "administrative-science-research"
    }
  },

})

if working_hours_enabled then
  data:extend({
    {
      type = "tips-and-tricks-item",
      name = "administratorio-working-hours",
      category = "administratorio",
      order = "n",
      indent = 1,
      trigger = {
        type = "or",
        triggers = {
          { type = "build-entity", entity = "office-desk" },
          { type = "build-entity", entity = "corporate-breakroom" },
          { type = "build-entity", entity = "union-headquarters" },
        }
      }
    },
  })
end
