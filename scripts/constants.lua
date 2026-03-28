-- Shared runtime constants for control scripts
local M = {}

-- Direct entity name -> complaint count lookup (avoids string.find in hot path)
M.BITER_COMPLAINT_COUNT = {
  ["small-biter"] = 1, ["medium-biter"] = 3,
  ["big-biter"] = 6, ["behemoth-biter"] = 10,
  ["small-spitter"] = 1, ["medium-spitter"] = 3,
  ["big-spitter"] = 6, ["behemoth-spitter"] = 10,
}

-- Direct entity name -> taxpayer payout lookup (avoids string.find in hot path)
M.BITER_PAYOUT = {
  ["small-biter"] = 5, ["medium-biter"] = 15,
  ["big-biter"] = 50, ["behemoth-biter"] = 100,
  ["small-spitter"] = 5, ["medium-spitter"] = 15,
  ["big-spitter"] = 50, ["behemoth-spitter"] = 100,
}

M.PROTEST_THRESHOLD = 600 -- seconds of waiting before protest (~10 minutes)
M.PROMISE_HOLD_TICKS = 60 * 60 -- 60 seconds to find an open desk after a promise
M.PROTEST_WANDER_MIN_RADIUS = 0.1
M.PROTEST_WANDER_MAX_RADIUS = 0.35
M.PROTEST_WANDER_MIN_MOVE_DISTANCE = 0.08
M.PROTEST_WANDER_ATTEMPTS = 10
M.PROTEST_WANDER_REISSUE_TICKS = 5 * 60
M.PROTEST_WANDER_REISSUE_JITTER_TICKS = 2 * 60
M.PROTEST_TARGET_CANDIDATE_LIMIT = 64
M.PROTEST_TARGET_RETRY_TICKS = 5 * 60
M.PROTEST_TARGET_MAX_PROTESTERS = 5
M.PROTEST_TARGET_LOAD_PENALTY = 2500
M.PROTEST_TARGET_SELECTION_JITTER = 250
M.INVALIDATED_BITER_REVIVE_RETRY_TICKS = 60
M.PROTEST_ARRIVAL_DISTANCE = 2.25
M.PROTEST_MAX_DISTANCE_FROM_TARGET = 3.5
M.PROTEST_STEP_ACTIVE_TICKS = 20
M.DESK_SLOT_COMMAND_RADIUS = 0.5
M.DESK_SLOT_ARRIVAL_DISTANCE = 1.0
M.EVOLUTION_COMPLAINT_WARNING_OFFSET = 0.05

-- Biter complaint tiers (landscape/smog/noise/unemployment)
M.COMPLAINT_TIERS = {
  "ticket-landscape", "ticket-smog",
  "ticket-noise", "ticket-unemployment"
}

-- Spitter complaint tiers (littering/hazmat/loitering/vagrancy)
M.SPITTER_COMPLAINT_TIERS = {
  "ticket-littering", "ticket-hazmat",
  "ticket-loitering", "ticket-vagrancy"
}

-- Entity name -> max complaint tier (1-4) based on size
M.BITER_MAX_TIER = {
  ["small-biter"] = 1, ["medium-biter"] = 2,
  ["big-biter"] = 3, ["behemoth-biter"] = 4,
  ["small-spitter"] = 1, ["medium-spitter"] = 2,
  ["big-spitter"] = 3, ["behemoth-spitter"] = 4,
}

-- Entity name -> is spitter (for complaint type selection)
M.IS_SPITTER = {
  ["small-spitter"] = true, ["medium-spitter"] = true,
  ["big-spitter"] = true, ["behemoth-spitter"] = true,
}

-- Individual frustration tier thresholds (fraction of PROTEST_THRESHOLD)
M.FRUST_TIER_THRESHOLDS = {0.25, 0.50, 0.75}
M.FRUST_GROWTH_RATES    = {1.0,  0.6,  0.35, 0.2}   -- individual growth/s per tier

M.ZONE_DIRECTIONS = {
  defines.direction.north,
  defines.direction.east,
  defines.direction.south,
  defines.direction.west,
}

M.ZONE_DIR_NAMES = {
  [defines.direction.north] = "North ↑",
  [defines.direction.east]  = "East →",
  [defines.direction.south] = "South ↓",
  [defines.direction.west]  = "West ←",
}

M.ZONE_SAFE_TYPES = {
  ["character"] = true, ["unit"] = true, ["corpse"] = true, ["particle"] = true,
  ["projectile"] = true, ["smoke"] = true, ["explosion"] = true,
}

M.RETURN_WALK_DISTANCE = 200     -- how far resolved biters walk before despawning
M.RETURN_DESPAWN_TICKS = 30 * 60 -- despawn after 30 seconds regardless of distance

M.PNEUMATIC_BUILDINGS = {
  ["form-liquifier"]  = "pneumatic-hidden-intake",
  ["form-solidifier"] = "pneumatic-hidden-outtake",
}

M.EVOLUTION_COMPLAINT_WARNINGS = {
  {
    id = "smog",
    threshold = 0.20,
    technology = "smog-abatement",
    complaints = {"ticket-smog"},
  },
  {
    id = "littering",
    threshold = 0.25,
    technology = "littering-resolution",
    complaints = {"ticket-littering"},
  },
  {
    id = "hazmat",
    threshold = 0.40,
    technology = "hazmat-response",
    complaints = {"ticket-hazmat"},
  },
  {
    id = "noise",
    threshold = 0.50,
    technology = "noise-ordinances",
    complaints = {"ticket-noise"},
  },
  {
    id = "loitering",
    threshold = 0.50,
    technology = "loitering-ordinances",
    complaints = {"ticket-loitering"},
  },
  {
    id = "unemployment",
    threshold = 0.90,
    technology = "constitutional-law",
    complaints = {"ticket-unemployment"},
  },
  {
    id = "vagrancy",
    threshold = 0.90,
    technology = "vagrancy-ordinances",
    complaints = {"ticket-vagrancy"},
  },
}

function M.get_individual_frust_tier(info)
  local pct = info.frustration / M.PROTEST_THRESHOLD
  if pct < 0.25 then return 1
  elseif pct < 0.50 then return 2
  elseif pct < 0.75 then return 3
  else return 4 end
end

function M.generate_complaints(entity_name)
  local count = M.BITER_COMPLAINT_COUNT[entity_name] or 1
  local max_tier = M.BITER_MAX_TIER[entity_name] or 1
  local is_spitter = M.IS_SPITTER[entity_name]
  local tiers = is_spitter and M.SPITTER_COMPLAINT_TIERS or M.COMPLAINT_TIERS
  local complaints = {}
  for i = 1, count do
    table.insert(complaints, tiers[math.random(1, max_tier)])
  end
  return complaints
end

return M
