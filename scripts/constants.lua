-- Shared runtime constants for control scripts
local feature_flags = require("feature_flags")
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

-- How many biter-worker items a hired biter yields (larger = more workers)
M.BITER_WORKER_YIELD = {
  ["small-biter"] = 1, ["medium-biter"] = 2,
  ["big-biter"] = 3, ["behemoth-biter"] = 5,
  ["small-spitter"] = 1, ["medium-spitter"] = 2,
  ["big-spitter"] = 3, ["behemoth-spitter"] = 5,
}

M.PROTEST_THRESHOLD = 600 -- seconds of waiting before protest (~10 minutes)
M.HARD_MODE_PROTEST_RATIO = 0.70
M.HARD_MODE_FRUSTRATION_CAPACITY = math.floor(M.PROTEST_THRESHOLD / M.HARD_MODE_PROTEST_RATIO)
M.ENROLLMENT_OFFER_LOW_FRUSTRATION_RATIO = 0.25
M.ENROLLMENT_OFFER_MEDIUM_FRUSTRATION_RATIO = 0.50
M.ENROLLMENT_OFFER_LOW_CHANCE = 0.05
M.ENROLLMENT_OFFER_MEDIUM_CHANCE = 0.01
M.PROMISE_HOLD_TICKS = 60 * 60 -- 60 seconds to find an open desk after a promise
M.PACIFIED_FRUSTRATION_RATIO = 0.5
M.PACIFIED_ROAM_REISSUE_TICKS = 30
M.PACIFIED_ROAM_REISSUE_JITTER_TICKS = 0
M.PROTEST_WANDER_MIN_RADIUS = 0.1
M.PROTEST_WANDER_MAX_RADIUS = 0.35
M.PROTEST_WANDER_MIN_MOVE_DISTANCE = 0.08
M.PROTEST_WANDER_ATTEMPTS = 10
M.PROTEST_WANDER_REISSUE_TICKS = 5 * 60
M.PROTEST_WANDER_REISSUE_JITTER_TICKS = 2 * 60
M.PROTEST_TARGET_CANDIDATE_LIMIT = 64
M.PROTEST_TARGET_TOP_K = 10
M.PROTEST_TARGET_PREFILTER_LIMIT = 64
M.PROTEST_TARGET_CACHE_TICKS = 5 * 60
M.PROTEST_TARGET_SEARCH_RADIUS_HIGH_LOAD = 96
M.PROTEST_TARGET_SPATIAL_CELL_SIZE = 96
M.PROTEST_TARGET_RETRY_TICKS = 5 * 60
-- Large protests are maintained in deterministic batches. Below the threshold,
-- protest behavior and path request cadence are unchanged.
M.PROTEST_HIGH_LOAD_THRESHOLD = 250
M.PROTEST_PACING_MAX_SHARDS = 12
M.PROTEST_PATH_REQUESTS_PER_TICK_HIGH_LOAD = 1
M.PROTEST_PATH_REQUESTS_MAX_OUTSTANDING_HIGH_LOAD = 1
M.PROTEST_PATH_REQUEST_TIMEOUT_TICKS = 10 * 60
M.PROTEST_PATH_BUSY_RETRY_TICKS = 60
M.PROTEST_TARGET_RETRY_JITTER_TICKS = 2 * 60
M.PROTEST_OBSTACLE_ATTACKER_LIMIT = 12
M.PROTEST_OBSTACLE_ATTACKER_LIMIT_HIGH_LOAD = 4
M.PROTEST_PIPE_GAP_ROUTE_LIMIT_HIGH_LOAD = 8
M.PROTEST_OBSTACLE_RETRY_TICKS = 3 * 60
M.PROTEST_OBSTACLE_SEARCH_RADIUS = 4
-- A regular pipe may be cleared only as a tightly aligned route obstruction;
-- it is never admitted to the protest-target or building-target sets.
M.PROTEST_PIPE_BREACH_SEARCH_RADIUS = 128
M.PROTEST_PIPE_BREACH_MAX_LATERAL_DISTANCE = 2
M.PROTEST_PIPE_BREACH_MIN_FORWARD_DISTANCE = 0.1
M.PROTEST_PIPE_LOCAL_RECOVERY_RADIUS = 8
M.PROTEST_PIPE_GAP_SEARCH_RADIUS = 64
M.PROTEST_PIPE_GAP_CROSS_DISTANCE = 1.5
M.PROTEST_PIPE_GAP_RECHECK_TICKS = 2 * 60
M.PROTEST_OBSTACLE_COMMAND_RETRY_TICKS = 60
M.DESK_ROUTE_BREACH_ATTACKER_LIMIT = 2
M.DESK_ROUTE_BREACH_RETRY_TICKS = 2 * 60
M.DESK_ROUTE_STALL_TICKS = 10 * 60
M.DESK_ROUTE_PROGRESS_DISTANCE = 1
M.PROTEST_ROUTE_STALL_TICKS = 10 * 60
M.PROTEST_ROUTE_PROGRESS_DISTANCE = 1
M.PROTEST_ROUTE_HOP_DISTANCE = 64
M.PROTEST_CLEAR_ROUTE_RETRY_TICKS = 60
M.PROTEST_TARGET_MAX_PROTESTERS = 5
M.PROTEST_OVERFLOW_WANDER_SEARCH_RADIUS = 12
M.PROTEST_TARGET_LOAD_PENALTY = 2500
M.PROTEST_TARGET_SELECTION_JITTER = 250
M.INVALIDATED_BITER_REVIVE_RETRY_TICKS = 60
M.RAPID_REVIVE_WINDOW_TICKS = 300
M.MAX_RAPID_REVIVES = 3
M.FRUST_PROTEST_PROCESS_SHARDS = 6
M.PROTEST_ARRIVAL_DISTANCE = 2.25
M.PROTEST_MAX_DISTANCE_FROM_TARGET = 3.5
M.PROTEST_FALSE_ARRIVAL_RECOVERY_DISTANCE = 32
M.PROTEST_STEP_ACTIVE_TICKS = 20
M.HARD_MODE_ATTACK_FORCE_NAME = "administratorio-hard-mode-biters"
M.HARD_MODE_ATTACK_REISSUE_TICKS = 5 * 60
M.HARD_MODE_ATTACK_RADIUS = 1.5
M.HARD_MODE_ATTACK_ANIMATION_TICKS = 30
M.HARD_MODE_ATTACK_DAMAGE = 20
M.HARD_MODE_ATTACK_DAMAGE_TICKS = 30
M.DESK_SLOT_COMMAND_RADIUS = 0.5
M.DESK_SLOT_ARRIVAL_DISTANCE = 1.0
M.EVOLUTION_COMPLAINT_WARNING_OFFSET = 0.05
M.GROUP_REDIRECTS_PER_TICK = 8
M.REGISTRATION_WALKIN_SCAN_TICKS = 5
M.ADMIN_STATION_NEST_EXCLUSION_RADIUS = 32
M.CAPTURE_BUREAU_NEST_EXCLUSION_RADIUS = 24
M.CAPTURE_BUREAU_LURE_RADIUS = 24
M.CAPTURE_BUREAU_SPORE_UPKEEP_TICKS = 10 * 60
M.CAPTURE_BUREAU_SPORE_UPKEEP_AMOUNT = 1
M.CAPTURE_BUREAU_SPORE_VISUAL_TICKS = 60
M.HATCHED_PENTAPOD_FORCE_NAME = "administratorio-hatched-pentapods"
M.PENTAPOD_MONEY_BAIT_INTERVAL_TICKS = 2 * 60
M.PENTAPOD_MONEY_BAIT_SCAN_LIMIT = 24
M.PENTAPOD_MONEY_BAIT_LURE_RADIUS = 24
M.PENTAPOD_MONEY_BAIT_PICKUP_RADIUS = 1.75
M.PENTAPOD_MONEY_BAIT_MIN_MONEY_PER_EGG = 10
M.PENTAPOD_MONEY_BAIT_MAX_MONEY_PER_EGG = 20

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
M.FRUST_GROWTH_RATES    = {1.5,  1.2,  1.0,  0.8}   -- individual growth/s per tier

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
  ["construction-robot"] = true, ["logistic-robot"] = true, ["combat-robot"] = true,
  -- Natural map features that vanilla lets you build over
  ["item-entity"] = true, ["resource"] = true,
}

M.RETURN_WALK_DISTANCE = 200     -- how far resolved biters walk before despawning
M.RETURN_DESPAWN_TICKS = 30 * 60 -- despawn after 30 seconds regardless of distance
M.RETURN_MIN_TRAVEL_TICKS = 5 * 60 -- avoid despawning resolved biters at the desk
M.RETURN_ARRIVAL_DISTANCE = 2.5
M.RETURN_EXIT_SEARCH_RADIUS = 24
M.RETURN_EXIT_SEARCH_PRECISION = 2

M.HUSH_MONEY_CALM_TICKS = 3 * 60 * 60 -- 3 minutes of suppressed spawning

-- Field office: proximity check for nearby biter spawners
M.FIELD_OFFICE_SPAWNER_RANGE = 200    -- tiles: max distance to a biter spawner
M.FIELD_OFFICE_PLACEMENT_PREVIEW_TICKS = 30 -- refresh held-item range overlays every 0.5 seconds
M.FIELD_OFFICE_PLACEMENT_PREVIEW_NEST_LIMIT = 32 -- max nest markers to draw while holding a field office
M.FIELD_OFFICE_CHECK_TICKS = 30       -- how often to check state (arrival, craft completion)
M.FIELD_OFFICE_UPDATE_TICKS = 5       -- scheduler cadence for sharded field-office checks
M.FIELD_OFFICE_BITER_DESPAWN_TICKS = 30 * 60 -- stale return command retry cadence
M.FIELD_OFFICE_ARRIVAL_RADIUS = 2.5   -- distance threshold for "biter has arrived"
M.FIELD_OFFICE_APPROACH_OFFSET = 1.5  -- roughly the office's footprint half-width; biases the arrival search toward the side actually facing the worker
M.FIELD_OFFICE_RETURN_SEARCH_RADIUS = 6 -- search radius for a walkable spot near the spawner (its own tile is solid collision)
M.FIELD_OFFICE_SPAWNER_CACHE_TTL = 30 * 60 -- ticks between background spawner cache refreshes
M.FIELD_OFFICE_UPDATE_SHARDS = 6      -- each office is checked once per 30 ticks at a 5-tick cadence

-- Biter station: one active worker biter performs rounds of managed machines.
M.BITER_STATION_RANGE = 30
M.BITER_STATION_BASE_SLOTS = 20
M.BITER_STATION_CHECK_TICKS = 10
M.BITER_STATION_CRAFTS_PER_VISIT = 1
M.BITER_STATION_SALARY = 1
M.BITER_STATION_NIGHT_COFFEE_PER_DISPATCH = 5
M.BITER_STATION_BITER_DESPAWN_TICKS = 5 * 60
M.BITER_STATION_ARRIVAL_RADIUS = 2.5
-- Buildings that idle without a biter dispatched from a biter-station.
-- Note: union-headquarters is intentionally NOT here — it consumes a biter
-- as a recipe ingredient, so it does not also need ongoing dispatch.
M.BITER_STATION_MANAGED_BUILDINGS = {
  "propaganda-distillery",
  "corporate-breakroom",
  "centrifuge",
  "oil-refinery",
  "printer-t2",
}
M.BITER_STATION_MANAGED_BUILDING_SET = {}
for _, name in ipairs(M.BITER_STATION_MANAGED_BUILDINGS) do
  M.BITER_STATION_MANAGED_BUILDING_SET[name] = true
end

-- Biterport: walking-worker construction/logistics network.
M.BITERPORT_NAME = "biterport"
M.BITERPORT_HIDDEN_ROBOPORT_NAME = "biterport-hidden-roboport"
M.BITERPORT_WORKER_ENTITY_NAME = "biterport-worker"
M.BITERPORT_WORKER_FAST_ENTITY_NAME = "biterport-worker-fast"
M.BITERPORT_WORKER_EXPRESS_ENTITY_NAME = "biterport-worker-express"
M.BITERPORT_WORKER_SLOTS = 8
M.BITERPORT_INVENTORY_SLOTS = M.BITERPORT_WORKER_SLOTS + 1
M.BITERPORT_LOGISTICS_RADIUS = 25
M.BITERPORT_LOGISTICS_CONNECTION_DISTANCE = 50
M.BITERPORT_CONSTRUCTION_RADIUS = 55
M.BITERPORT_CHECK_TICKS = 30
M.BITERPORT_WORKER_SALARY = 1
M.BITERPORT_NIGHT_COFFEE_PER_DISPATCH = 5
M.BITERPORT_ARRIVAL_RADIUS = 1.5
M.BITERPORT_WORKER_DESPAWN_TICKS = 5 * 60
M.BITERPORT_RETURN_COOLDOWN_TICKS = 30
M.BITERPORT_DISPATCH_COOLDOWN_TICKS = 30
M.BITERPORT_MAX_GHOSTS_PER_PORT_SCAN = 24
M.BITERPORT_MAX_DECONSTRUCTION_PER_PORT_SCAN = 24
M.BITERPORT_MAX_CHESTS_PER_PORT_SCAN = 64
M.BITERPORT_LOGISTICS_SCAN_SUBDIVISIONS = 3
M.BITERPORT_CONSTRUCTION_SCAN_SUBDIVISIONS = 3
M.BITERPORT_CRAPPY_PASSIVE_PROVIDER_CHEST = "paperwork-provider-chest"
M.BITERPORT_CRAPPY_STORAGE_CHEST = "paperwork-storage-chest"
M.BITERPORT_CRAPPY_REQUESTER_CHEST = "paperwork-requester-chest"

-- Pneumatic tube network capacity (shared items per network).
M.TUBE_BASE_CAPACITY = 10
M.TUBE_CAPACITY_TECHS = {
  ["pneumatic-capacity-1"] = 15,   -- total 25
  ["pneumatic-capacity-2"] = 25,   -- total 50
  ["pneumatic-capacity-3"] = 50,   -- total 100
  ["pneumatic-capacity-4"] = 100,  -- total 200
}
M.TUBE_MAX_NETWORK_RADIUS = 120

-- Tube endpoint entity names.
M.PNEUMATIC_BUILDINGS = {
  ["tube-intake"] = true,
  ["tube-outtake"] = true,
}

-- All items eligible for pneumatic tube transport.
-- Mirrors shared.PNEUMATIC_ITEMS from the data stage.
-- Used at runtime to validate intake contents before adding them to a network.
M.PNEUMATIC_ITEMS = {
  -- PAPERWORK_ITEMS
  "work-order", "form-27b-6", "research-grant-approval", "provisional-approval",
  "safety-waiver", "safety-waiver-draft",
  "construction-permit", "construction-permit-draft",
  "transit-authorization",
  "management-approval-verbal", "management-verbal-draft",
  "management-approval-written", "management-written-proposal",
  "carbon-offset-certificate-basic", "carbon-offset-certificate-verified",
  "environmental-impact-report", "petrochemical-operating-permit",
  "blank-form", "blank-approval", "blank-directive",
  "treasury-bond", "government-grant",
  "safety-work-order", "construction-work-order",
  "management-verbal-work-order", "management-written-work-order",
  "research-grant-work-order", "chemical-handling-work-order",
  "radiological-work-order",
  -- Extra pneumatic items
  "paper", "ink",
  "ticket-landscape", "ticket-smog", "ticket-noise", "ticket-unemployment",
  "ticket-littering", "ticket-hazmat", "ticket-loitering", "ticket-vagrancy",
  "filing-l", "filing-s", "filing-n", "filing-u",
  "filing-lt", "filing-h", "filing-lo", "filing-v",
  "case-s", "case-n", "case-u",
  "case-h", "case-lo", "case-v",
  "brief-n", "brief-u",
  "brief-lo", "brief-v",
  "resolved-landscape", "resolved-smog", "resolved-noise", "resolved-unemployment",
  "resolved-littering", "resolved-hazmat", "resolved-loitering", "resolved-vagrancy",
  "osha-violation",
  "basic-excuse", "crappy-report", "credentials", "data",
  "good-excuse", "justification", "narrative", "policy", "regulation",
  "white-paper", "administrative-science-pack",
  "watercooler-gossip", "office-drama",
  "taxpayer-money",
  "useless-documentation", "refined-nonsense",
  "job-offer",
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

function M.hard_mode_enabled()
  return feature_flags.debug_hard_mode_enabled()
end

function M.get_frustration_capacity()
  if M.hard_mode_enabled() then
    return M.HARD_MODE_FRUSTRATION_CAPACITY
  end
  return M.PROTEST_THRESHOLD
end

function M.get_protest_threshold()
  return M.PROTEST_THRESHOLD
end

function M.get_attack_threshold()
  if M.hard_mode_enabled() then
    return M.get_frustration_capacity()
  end
  return nil
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

-- Hired Biter Field Agent
M.HIRED_BITER_SCAN_RADIUS   = 60   -- tiles: scan radius for enemy nests
M.HIRED_BITER_SCAN_COOLDOWN = 300  -- ticks between nest scans (~5 seconds)
M.HIRED_BITER_ARRIVE_RADIUS = 5    -- tiles: "arrived at position" threshold
M.HIRED_BITER_UNIT_NAME     = "hired-biter-unit"
M.HIRED_BITER_REMOTE_NAME   = "hired-biter-command-capsule"
M.HIRED_BITER_NOTICE_CAPACITY = 20
M.HIRED_BITER_INVENTORY_SLOTS = 4

return M
