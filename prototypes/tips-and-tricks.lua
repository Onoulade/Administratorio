-- ADMINISTRATORIO: TIPS AND TRICKS
-- In-game tutorial entries for the tips-and-tricks pane.
-- Ordered by mod progression: each tip unlocks when the matching mechanic
-- becomes available to the player.

local feature_flags = require("feature_flags")
local simulations = require("prototypes.tips-and-tricks-simulations")
local working_hours_enabled = feature_flags.working_hours_enabled()
local space_age_enabled = feature_flags.space_age_enabled()

local function extend_with_simulations(prototypes)
  for _, prototype in ipairs(prototypes) do
    if prototype.type == "tips-and-tricks-item" then
      prototype.simulation = assert(simulations[prototype.name], "missing simulation for " .. prototype.name)
    end
  end
  data:extend(prototypes)
end

extend_with_simulations({
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

  -- Bullshit ore, rubble derivatives, and public finance
  {
    type = "tips-and-tricks-item",
    name = "administratorio-bullshit-economy",
    category = "administratorio",
    order = "ac",
    indent = 1,
    trigger = {
      type = "research",
      technology = "discovery-bullshit"
    }
  },

  -- Administrative science replaces military science
  {
    type = "tips-and-tricks-item",
    name = "administratorio-admin-science",
    category = "administratorio",
    order = "ad",
    indent = 1,
    trigger = {
      type = "research",
      technology = "administrative-science-research"
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
	  {
	    type = "tips-and-tricks-item",
	    name = "administratorio-complaint-chain",
	    category = "administratorio",
	    order = "cb",
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

  -- Propaganda fluids and industrial misinformation
  {
    type = "tips-and-tricks-item",
    name = "administratorio-propaganda-distillery",
    category = "administratorio",
    order = "g",
    indent = 1,
    trigger = {
      type = "research",
      technology = "industrial-propaganda"
    }
  },

  -- Rail arrivals consume integrated transit paperwork
  {
    type = "tips-and-tricks-item",
    name = "administratorio-transit-authorization",
    category = "administratorio",
    order = "ga",
    indent = 1,
    trigger = {
      type = "research",
      technology = "railway"
    }
  },

  -- Instant paperwork transfer through pneumatic networks
  {
    type = "tips-and-tricks-item",
    name = "administratorio-pneumatic-transport",
    category = "administratorio",
    order = "ma",
    indent = 1,
    trigger = {
      type = "research",
      technology = "pneumatic-form-transport"
    }
  },
})

-- ===== NIGHT WORK (only if Working Hours feature is enabled) =====

if working_hours_enabled then
  extend_with_simulations({
    {
      type = "tips-and-tricks-item",
      name = "administratorio-working-hours",
      category = "administratorio",
      order = "d-a",
      indent = 1,
      trigger = {
        type = "or",
        triggers = {
          { type = "build-entity", entity = "office-desk" },
          { type = "build-entity", entity = "union-headquarters" },
          { type = "build-entity", entity = "biter-station" },
          { type = "build-entity", entity = "biterport" },
        }
      }
    },
  })
end

-- ===== SPACE AGE PLANET MANIFESTS =====

if space_age_enabled then
  local planet_tips = {
    {name = "administratorio-vulcanus-manifest", order = "n-a", technology = "vulcanus-certification"},
    {name = "administratorio-gleba-manifest", order = "n-b", technology = "gleba-conciliation"},
    {name = "administratorio-fulgora-archives", order = "n-c", technology = "archive-recombination"},
    {name = "administratorio-aquilo-manifest", order = "n-d", technology = "aquilo-fax-network"},
  }
  local prototypes_to_add = {}
  for _, tip in ipairs(planet_tips) do
    prototypes_to_add[#prototypes_to_add + 1] = {
      type = "tips-and-tricks-item",
      name = tip.name,
      category = "administratorio",
      order = tip.order,
      indent = 1,
      trigger = {type = "research", technology = tip.technology},
    }
  end
  extend_with_simulations(prototypes_to_add)

  -- ===== WORKFORCE FORMATION & ORBITAL OPERATIONS =====

  extend_with_simulations({
    -- Workforce Formation (title section)
    {
      type = "tips-and-tricks-item",
      name = "administratorio-workforce-formation-title",
      category = "administratorio",
      order = "o",
      is_title = true,
      indent = 0,
      trigger = {type = "research", technology = "worker-formation"},
    },

    -- Workforce Formation overview
    {
      type = "tips-and-tricks-item",
      name = "administratorio-workforce-formation",
      category = "administratorio",
      order = "oa",
      indent = 1,
      trigger = {type = "research", technology = "worker-formation"},
    },

    -- Formation Center (covered by existing tip "administratorio-biter-workers" but we add orbital-specific note)
    {
      type = "tips-and-tricks-item",
      name = "administratorio-orbital-specialists",
      category = "administratorio",
      order = "ob",
      indent = 1,
      trigger = {type = "research", technology = "worker-formation"},
    },

    -- Trajectory Compliance Arrays
    {
      type = "tips-and-tricks-item",
      name = "administratorio-trajectory-compliance-arrays",
      category = "administratorio",
      order = "oc",
      indent = 1,
      trigger = {type = "research", technology = "orbital-employment-infrastructure"},
    },

    -- Senior Trajectory Compliance Array
    {
      type = "tips-and-tricks-item",
      name = "administratorio-senior-trajectory-compliance-array",
      category = "administratorio",
      order = "oc2",
      indent = 1,
      trigger = {type = "research", technology = "trajectory-compliance-jurisdiction-2"},
    },

    -- Executive Trajectory Compliance Array
    {
      type = "tips-and-tricks-item",
      name = "administratorio-executive-trajectory-compliance-array",
      category = "administratorio",
      order = "oc3",
      indent = 1,
      trigger = {type = "research", technology = "trajectory-compliance-jurisdiction-3"},
    },

    -- Orbital Employment Cannon & VESM
    {
      type = "tips-and-tricks-item",
      name = "administratorio-orbital-employment-cannon",
      category = "administratorio",
      order = "od",
      indent = 1,
      trigger = {type = "research", technology = "orbital-employment-infrastructure"},
    },

    -- Orbital Employment Damage upgrades
    {
      type = "tips-and-tricks-item",
      name = "administratorio-orbital-employment-damage",
      category = "administratorio",
      order = "oe",
      indent = 1,
      trigger = {type = "research", technology = "orbital-employment-damage-1"},
    },

    -- Orbital Employment Capacity upgrades
    {
      type = "tips-and-tricks-item",
      name = "administratorio-orbital-employment-capacity",
      category = "administratorio",
      order = "of",
      indent = 1,
      trigger = {type = "research", technology = "orbital-employment-capacity-1"},
    },

    -- Administrative Space Station
    {
      type = "tips-and-tricks-item",
      name = "administratorio-administrative-space-station",
      category = "administratorio",
      order = "og",
      indent = 1,
      trigger = {type = "research", technology = "orbital-employment-infrastructure"},
    },

    -- Orbital Infrastructure Permit
    {
      type = "tips-and-tricks-item",
      name = "administratorio-orbital-infrastructure-permit",
      category = "administratorio",
      order = "oh",
      indent = 1,
      trigger = {type = "research", technology = "space-platform"},
    },

    -- Trajectory Compliance Speed upgrades
    {
      type = "tips-and-tricks-item",
      name = "administratorio-trajectory-compliance-speed",
      category = "administratorio",
      order = "oi",
      indent = 1,
      trigger = {type = "research", technology = "trajectory-compliance-speed-1"},
    },

    -- ===== CHROMATIC PRINTING =====

    {
      type = "tips-and-tricks-item",
      name = "administratorio-chromatic-printing",
      category = "administratorio",
      order = "p",
      is_title = true,
      indent = 0,
      trigger = {type = "research", technology = "chromatic-printing"},
    },

    {
      type = "tips-and-tricks-item",
      name = "administratorio-chromatic-printer",
      category = "administratorio",
      order = "pa",
      indent = 1,
      trigger = {type = "research", technology = "chromatic-printing"},
    },

    {
      type = "tips-and-tricks-item",
      name = "administratorio-chromatic-inks",
      category = "administratorio",
      order = "pb",
      indent = 1,
      trigger = {type = "research", technology = "chromatic-printing"},
    },

    {
      type = "tips-and-tricks-item",
      name = "administratorio-multicolor-forms",
      category = "administratorio",
      order = "pc",
      indent = 1,
      trigger = {type = "research", technology = "chromatic-printing"},
    },

    -- ===== VULCANUS CERTIFICATION =====

    {
      type = "tips-and-tricks-item",
      name = "administratorio-vulcanus-certification",
      category = "administratorio",
      order = "q",
      is_title = true,
      indent = 0,
      trigger = {type = "research", technology = "vulcanus-certification"},
    },

    {
      type = "tips-and-tricks-item",
      name = "administratorio-notary-office",
      category = "administratorio",
      order = "qa",
      indent = 1,
      trigger = {type = "research", technology = "vulcanus-certification"},
    },

    {
      type = "tips-and-tricks-item",
      name = "administratorio-territorial-arbitration",
      category = "administratorio",
      order = "qb",
      indent = 1,
      trigger = {type = "research", technology = "vulcanus-certification"},
    },

    {
      type = "tips-and-tricks-item",
      name = "administratorio-vulcanus-export-charters",
      category = "administratorio",
      order = "qc",
      indent = 1,
      trigger = {type = "research", technology = "vulcanus-export-charters"},
    },

    -- ===== GLEBA CONCILIATION =====

    {
      type = "tips-and-tricks-item",
      name = "administratorio-gleba-conciliation",
      category = "administratorio",
      order = "r",
      is_title = true,
      indent = 0,
      trigger = {type = "research", technology = "gleba-conciliation"},
    },

    {
      type = "tips-and-tricks-item",
      name = "administratorio-conciliation-desk",
      category = "administratorio",
      order = "ra",
      indent = 1,
      trigger = {type = "research", technology = "gleba-conciliation"},
    },

    {
      type = "tips-and-tricks-item",
      name = "administratorio-capture-bureau",
      category = "administratorio",
      order = "rb",
      indent = 1,
      trigger = {type = "research", technology = "gleba-conciliation"},
    },

    -- ===== INTERPLANETARY BUREAUCRACY (CROSS-PLANET) =====

    {
      type = "tips-and-tricks-item",
      name = "administratorio-cross-planet-bureaucracy",
      category = "administratorio",
      order = "s",
      is_title = true,
      indent = 0,
      trigger = {type = "research", technology = "cyan-yellow-bureaucracy"},
    },

    {
      type = "tips-and-tricks-item",
      name = "administratorio-cyan-yellow-bureaucracy",
      category = "administratorio",
      order = "sa",
      indent = 1,
      trigger = {type = "research", technology = "cyan-yellow-bureaucracy"},
    },

    {
      type = "tips-and-tricks-item",
      name = "administratorio-cyan-magenta-bureaucracy",
      category = "administratorio",
      order = "sb",
      indent = 1,
      trigger = {type = "research", technology = "cyan-magenta-bureaucracy"},
    },

    {
      type = "tips-and-tricks-item",
      name = "administratorio-yellow-magenta-bureaucracy",
      category = "administratorio",
      order = "sc",
      indent = 1,
      trigger = {type = "research", technology = "yellow-magenta-bureaucracy"},
    },

    -- ===== FULGORA DIGITAL SERVICES =====

    {
      type = "tips-and-tricks-item",
      name = "administratorio-fulgora-digital-services",
      category = "administratorio",
      order = "t",
      is_title = true,
      indent = 0,
      trigger = {type = "research", technology = "fulgora-digital-services"},
    },

    {
      type = "tips-and-tricks-item",
      name = "administratorio-digital-services-bureau",
      category = "administratorio",
      order = "ta",
      indent = 1,
      trigger = {type = "research", technology = "fulgora-digital-services"},
    },

    {
      type = "tips-and-tricks-item",
      name = "administratorio-archive-recombination",
      category = "administratorio",
      order = "tb",
      indent = 1,
      trigger = {type = "research", technology = "archive-recombination"},
    },

    -- ===== AQUILO FAX NETWORK =====

    {
      type = "tips-and-tricks-item",
      name = "administratorio-aquilo-fax-network",
      category = "administratorio",
      order = "u",
      is_title = true,
      indent = 0,
      trigger = {type = "research", technology = "aquilo-fax-network"},
    },

    {
      type = "tips-and-tricks-item",
      name = "administratorio-fax-emitter",
      category = "administratorio",
      order = "ua",
      indent = 1,
      trigger = {type = "research", technology = "aquilo-fax-network"},
    },

    {
      type = "tips-and-tricks-item",
      name = "administratorio-interplanetary-fax-exchange",
      category = "administratorio",
      order = "ub",
      indent = 1,
      trigger = {type = "research", technology = "aquilo-fax-network"},
    },

    {
      type = "tips-and-tricks-item",
      name = "administratorio-laser-printer",
      category = "administratorio",
      order = "uc",
      indent = 1,
      trigger = {type = "research", technology = "aquilo-fax-network"},
    },

    {
      type = "tips-and-tricks-item",
      name = "administratorio-color-faxing",
      category = "administratorio",
      order = "ud",
      indent = 1,
      trigger = {type = "research", technology = "color-faxing"},
    },

    {
      type = "tips-and-tricks-item",
      name = "administratorio-fax-queue-capacity",
      category = "administratorio",
      order = "ue",
      indent = 1,
      trigger = {type = "research", technology = "fax-queue-capacity-1"},
    },

    -- ===== BUREAUCRATIC TRANSCENDENCE =====

    {
      type = "tips-and-tricks-item",
      name = "administratorio-bureaucratic-transcendence",
      category = "administratorio",
      order = "v",
      is_title = true,
      indent = 0,
      trigger = {type = "research", technology = "bureaucratic-transcendence"},
    },

    {
      type = "tips-and-tricks-item",
      name = "administratorio-public-train-stop",
      category = "administratorio",
      order = "va",
      indent = 1,
      trigger = {type = "research", technology = "bureaucratic-transcendence"},
    },
  })
end
