-- Lifetime Administratorio performance metrics shown on the victory screen.
-- Keep the registry centralized so migrations, event writers and the GUI agree
-- on the exact set of durable counters.
local M = {}

M.KEY_GROUPS = {
  department = {
    "rockets_launched",
    "cases_resolved",
    "complaints_resolved",
    "money_earned",
    "biters_hired",
    "tourists_served",
    "field_office_shifts",
    "managed_crafts",
  },
  logistics = {
    "pneumatic_items_delivered",
    "passenger_trips_completed",
    "personnel_routed",
    "biterport_items_delivered",
    "biterport_constructions",
    "biterport_deconstructions",
  },
  enforcement = {
    "protests_suppressed",
    "nests_evicted",
    "nests_calmed",
    "eviction_notices_delivered",
  },
  offworld = {
    "interplanetary_items_delivered",
    "personnel_relocated",
    "territories_arbitrated",
    "trajectory_orders_issued",
    "asteroids_processed",
  },
}

local known_keys = {}
for _, keys in pairs(M.KEY_GROUPS) do
  for _, key in ipairs(keys) do known_keys[key] = true end
end

function M.ensure(stats)
  stats = stats or {}
  for key in pairs(known_keys) do
    if stats[key] == nil then stats[key] = 0 end
  end
  return stats
end

function M.increment(stats, key, amount)
  if not known_keys[key] then error("unknown Administratorio metric: " .. tostring(key)) end
  if not stats then return 0 end
  amount = amount or 1
  stats[key] = (stats[key] or 0) + amount
  return stats[key]
end

function M.record(key, amount)
  if not storage then return 0 end
  storage.stats = M.ensure(storage.stats)
  return M.increment(storage.stats, key, amount)
end

function M.is_known(key)
  return known_keys[key] == true
end

return M
