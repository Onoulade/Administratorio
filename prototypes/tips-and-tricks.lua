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

  -- The Bullshit Economy (core resource chain — unlocks with first research)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-bullshit-economy",
    category = "administratorio",
    order = "c",
    indent = 1,
    trigger = {
      type = "research",
      technology = "discovery-bullshit"
    }
  },

  -- Regulation & Form Tiers (unlocks with automation)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-regulation",
    category = "administratorio",
    order = "d",
    indent = 1,
    trigger = {
      type = "research",
      technology = "automation"
    }
  },

  -- Machine Operating Paperwork (unlocks when the player first builds a covered machine)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-operating-paperwork",
    category = "administratorio",
    order = "e",
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

  -- Complaints & Admin Desks (unlocks when the first admin station is built)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-biter-complaints",
    category = "administratorio",
    order = "f",
    indent = 1,
    trigger = {
      type = "build-entity",
      entity = "admin-station"
    }
  },

  -- Waiting, Frustration & Protest (unlocks when the first admin station is built)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-frustration",
    category = "administratorio",
    order = "g",
    indent = 1,
    trigger = {
      type = "build-entity",
      entity = "admin-station"
    }
  },

  -- Promises, Protests & Resolution (unlocks when the first admin station is built)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-protest-resolution",
    category = "administratorio",
    order = "h",
    indent = 1,
    trigger = {
      type = "build-entity",
      entity = "admin-station"
    }
  },

  -- Complaint Processing Chains (unlocks when the first admin station is built)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-complaint-chain",
    category = "administratorio",
    order = "i",
    indent = 1,
    trigger = {
      type = "build-entity",
      entity = "admin-station"
    }
  },

  -- Hush Money (unlocks with nest-pacification)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-hush-money",
    category = "administratorio",
    order = "j",
    indent = 1,
    trigger = {
      type = "research",
      technology = "nest-pacification"
    }
  },

  -- Nest Expropriation (unlocks with nest-expropriation technology)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-nest-expropriation",
    category = "administratorio",
    order = "k",
    indent = 1,
    trigger = {
      type = "research",
      technology = "nest-expropriation"
    }
  },

  -- The Propaganda Distillery (unlocks with industrial-propaganda)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-propaganda-distillery",
    category = "administratorio",
    order = "l",
    indent = 1,
    trigger = {
      type = "research",
      technology = "industrial-propaganda"
    }
  },

  -- Pneumatic Form Transport (unlocks with pneumatic-form-transport)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-pneumatic-transport",
    category = "administratorio",
    order = "m",
    indent = 1,
    trigger = {
      type = "research",
      technology = "pneumatic-form-transport"
    }
  },

  -- Transit Authorization (unlocks with railway)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-transit-authorization",
    category = "administratorio",
    order = "n",
    indent = 1,
    trigger = {
      type = "research",
      technology = "railway"
    }
  },

  -- Administrative Science (unlocks with administrative-science-research)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-admin-science",
    category = "administratorio",
    order = "o",
    indent = 1,
    trigger = {
      type = "research",
      technology = "administrative-science-research"
    }
  },

  -- Biter Employment Program (unlocks with biter-employment technology)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-biter-employment",
    category = "administratorio",
    order = "p",
    indent = 1,
    trigger = {
      type = "research",
      technology = "biter-employment"
    }
  },

  -- Biter Workers & Specialists (unlocks with biter-labor-efficiency-1)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-biter-workers",
    category = "administratorio",
    order = "q",
    indent = 1,
    trigger = {
      type = "research",
      technology = "biter-labor-efficiency-1"
    }
  },

  -- Rideable Biter (unlocks with civic-biter-riding)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-rideable-biter",
    category = "administratorio",
    order = "q1",
    indent = 1,
    trigger = {
      type = "research",
      technology = "civic-biter-riding"
    }
  },

  -- Biter Employment Office (unlocks when the first biter station is built)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-biter-station",
    category = "administratorio",
    order = "r",
    indent = 1,
    trigger = {
      type = "build-entity",
      entity = "biter-station"
    }
  },

  -- Labor Efficiency Upgrades (unlocks with biter-labor-efficiency-2)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-labor-efficiency",
    category = "administratorio",
    order = "s",
    indent = 1,
    trigger = {
      type = "research",
      technology = "biter-labor-efficiency-2"
    }
  },
})

if working_hours_enabled then
  data:extend({
    -- Working Hours & Night Shifts (unlocks when office infrastructure is built)
    {
      type = "tips-and-tricks-item",
      name = "administratorio-working-hours",
      category = "administratorio",
      order = "t",
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
