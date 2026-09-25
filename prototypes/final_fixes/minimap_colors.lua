-- Administrative buildings use dark greens, processing machines use blues,
-- tubes use orange, and biter infrastructure uses pale blue-greens.
-- Both fields matter: friendly_map_color takes priority for player-owned entities,
-- while map_color covers neutral/scripted instances and the chart fallback.
local colors = {
  office = {r = 0.20, g = 0.42, b = 0.31},
  office_support = {r = 0.26, g = 0.47, b = 0.34},
  office_technical = {r = 0.19, g = 0.40, b = 0.36},
  printer = {r = 0.34, g = 0.59, b = 0.79},
  processing = {r = 0.31, g = 0.53, b = 0.74},
  working_station = {r = 0.62, g = 0.82, b = 0.68},
  logistics_hub = {r = 0.49, g = 0.77, b = 0.72},
  worker = {r = 0.70, g = 0.83, b = 0.63},
  logistics_biter = {r = 0.43, g = 0.76, b = 0.72},
  tubing = {r = 0.88, g = 0.49, b = 0.20},
  tube_endpoint = {r = 0.78, g = 0.43, b = 0.18},
  passenger = {r = 0.55, g = 0.78, b = 0.75},
  data = {r = 0.43, g = 0.66, b = 0.72},
  provider = {r = 0.80, g = 0.47, b = 0.39},
  storage = {r = 0.84, g = 0.71, b = 0.33},
  requester = {r = 0.40, g = 0.61, b = 0.80},
}

-- Visible entities only. In particular, helper pipes, ports, blockers, hidden
-- combinators, and heat cores must never paint over the actual map footprint.
local common = {
  office = {
    "resolution-office", "office-desk", "formation-center", "field-office",
  },
  office_support = {"corporate-breakroom", "union-headquarters", "greenhouse"},
  printer = {
    "mechanical-printer", "printer-t1", "printer-t2",
  },
  processing = {"propaganda-distillery"},
  working_station = {"biter-station"},
  logistics_hub = {"admin-station", "biterport", "biterport-placement-preview"},
  worker = {"biter-worker-t1", "biter-worker-t2", "biter-worker-t3", "field-office-worker"},
  logistics_biter = {
    "biterport-worker", "biterport-worker-fast", "biterport-worker-express",
    "hired-biter-unit", "rideable-biter", "rideable-biter-mounted",
  },
  tubing = {
    "pneumatic-pipe", "pneumatic-pipe-to-ground", "tube-intake",
    "tube-outtake", "tube-pump",
  },
  passenger = {
    "boarding-platform", "deboarding-platform",
    "boarding-platform-placement-preview", "deboarding-platform-placement-preview",
    "transit-permit-chest", "passenger-wagon",
  },
  provider = {"paperwork-provider-chest"},
  storage = {"paperwork-storage-chest"},
  requester = {"paperwork-requester-chest"},
}

local space_age = {
  office = {
    "notary-office", "territorial-arbitration-post", "conciliation-desk",
  },
  office_technical = {
    "digital-services-bureau", "synthetic-personnel-bureau",
    "archive-recombination-bureau", "administrative-space-station",
  },
  printer = {
    "chromatic-printer", "laser-printer",
  },
  processing = {"slop-refinery"},
  logistics_hub = {"capture-bureau"},
  tube_endpoint = {
    "interplanetary-terminus", "involuntary-relocation-cannon",
    "involuntary-relocation-receiver",
  },
  passenger = {"public-train-stop"},
  data = {
    "optical-fibre", "ai-server", "heat-exhaust",
    "trajectory-compliance-array", "senior-trajectory-compliance-array",
    "executive-trajectory-compliance-array", "orbital-employment-catapult",
  },
}

local entity_types = {
  "ammo-turret", "assembling-machine", "car", "cargo-wagon", "constant-combinator",
  "container", "furnace", "heat-interface", "inserter", "logistic-container",
  "pipe", "pipe-to-ground", "roboport", "train-stop", "unit",
}

local function find_entity(raw, name)
  for _, entity_type in ipairs(entity_types) do
    local prototypes = raw[entity_type]
    if prototypes and prototypes[name] then return prototypes[name] end
  end
end

local function assign(raw, groups, seen)
  for group, names in pairs(groups) do
    local color = assert(colors[group], "Unknown minimap colour group: " .. group)
    for _, name in ipairs(names) do
      assert(not seen[name], "Duplicate minimap colour assignment: " .. name)
      seen[name] = true
      local entity = assert(find_entity(raw, name), "Missing minimap entity: " .. name)
      for _, flag in ipairs(entity.flags or {}) do
        assert(flag ~= "not-on-map", "Hidden helper assigned a minimap colour: " .. name)
      end
      entity.map_color = {r = color.r, g = color.g, b = color.b}
      entity.friendly_map_color = {r = color.r, g = color.g, b = color.b}
    end
  end
end

local function apply(raw, has_space_age, has_working_hours)
  local seen = {}
  assign(raw, common, seen)
  if has_space_age then assign(raw, space_age, seen) end
  if has_working_hours then assign(raw, {data = {"administrative-clock"}}, seen) end
  return seen
end

return {apply = apply, colors = colors, common = common, space_age = space_age}
