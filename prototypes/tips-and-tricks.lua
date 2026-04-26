-- ADMINISTRATORIO: TIPS AND TRICKS
-- In-game tutorial entries for the tips-and-tricks pane.
-- Ordered by mod progression: each tip unlocks when the matching mechanic
-- becomes available to the player.

local feature_flags = require("feature_flags")
local working_hours_enabled = feature_flags.working_hours_enabled()

data:extend({
  -- Category
  {
    type = "tips-and-tricks-item-category",
    name = "administratorio",
    order = "z-a"
  },

  -- ===== TITLE =====

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

  -- ===== RECIPE PAPERWORK PIPELINE =====

  -- Work Orders & Operating Paperwork
  {
    type = "tips-and-tricks-item",
    name = "administratorio-work-orders",
    category = "administratorio",
    order = "ab",
    indent = 1,
    trigger = {
      type = "research",
      technology = "automation"
    }
  },

  -- ===== EARLY-GAME COMPLAINT LOOP (first admin station) =====

  -- Complaints, Office Desk & Taxpayer Money
  {
    type = "tips-and-tricks-item",
    name = "administratorio-biter-complaints",
    category = "administratorio",
    order = "b",
    indent = 1,
    trigger = {
      type = "build-entity",
      entity = "admin-station"
    }
  },

  -- Frustration, Protests & Bureaucratic Promise
  {
    type = "tips-and-tricks-item",
    name = "administratorio-frustration",
    category = "administratorio",
    order = "c",
    indent = 1,
    trigger = {
      type = "build-entity",
      entity = "admin-station"
    }
  },
  
   -- ===== FIELD OFFICE (early biter labor) =====

  {
    type = "tips-and-tricks-item",
    name = "administratorio-field-office",
    category = "administratorio",
    order = "d",
    indent = 1,
    trigger = {
      type = "build-entity",
      entity = "field-office"
    }
  },

  -- ===== TERRITORY TOOLS =====

  -- Hush Money
  {
    type = "tips-and-tricks-item",
    name = "administratorio-hush-money",
    category = "administratorio",
    order = "e",
    indent = 1,
    trigger = {
      type = "research",
      technology = "nest-pacification"
    }
  },

  -- Eviction Notices
  {
    type = "tips-and-tricks-item",
    name = "administratorio-nest-expropriation",
    category = "administratorio",
    order = "f",
    indent = 1,
    trigger = {
      type = "research",
      technology = "nest-expropriation"
    }
  },

  -- ===== BITER EMPLOYMENT =====

  -- Biter Employment Program
  {
    type = "tips-and-tricks-item",
    name = "administratorio-biter-employment",
    category = "administratorio",
    order = "h",
    indent = 1,
    trigger = {
      type = "research",
      technology = "biter-employment-office"
    }
  },

  -- Biter Workers & Specialists (covers Formation Center)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-biter-workers",
    category = "administratorio",
    order = "i",
    indent = 1,
    trigger = {
      type = "build-entity",
      entity = "formation-center"
    }
  },

  -- Biter Station (covers labor efficiency upgrades)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-biter-station",
    category = "administratorio",
    order = "j",
    indent = 1,
    trigger = {
      type = "build-entity",
      entity = "biter-station"
    }
  },

  -- Rideable Biter
  {
    type = "tips-and-tricks-item",
    name = "administratorio-rideable-biter",
    category = "administratorio",
    order = "k",
    indent = 1,
    trigger = {
      type = "research",
      technology = "rideable-biter"
    }
  },

  -- Biterport
  {
    type = "tips-and-tricks-item",
    name = "administratorio-biterport",
    category = "administratorio",
    order = "l",
    indent = 1,
    trigger = {
      type = "research",
      technology = "biterport-logistics"
    }
  },

  -- Field Agent Program (Hired Biter)
  {
    type = "tips-and-tricks-item",
    name = "administratorio-hired-biter",
    category = "administratorio",
    order = "m",
    indent = 1,
    trigger = {
      type = "research",
      technology = "hired-biter-fieldwork"
    }
  },
})

-- ===== NIGHT WORK (only if Working Hours feature is enabled) =====

if working_hours_enabled then
  data:extend({
    {
      type = "tips-and-tricks-item",
      name = "administratorio-working-hours",
      category = "administratorio",
      order = "f",
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
