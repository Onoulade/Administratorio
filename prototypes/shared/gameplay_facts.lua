-- Balance and capacity facts shared by the data stage, control stage, tests,
-- and generated documentation. Keep this module free of Factorio globals and
-- side effects so ordinary Lua tooling can load it.

local M = {}

M.biter_sizes = {
  {name = "small", complaint_count = 1, max_tier = 1, payout = 5, worker_yield = 1},
  {name = "medium", complaint_count = 2, max_tier = 2, payout = 15, worker_yield = 2},
  {name = "big", complaint_count = 3, max_tier = 3, payout = 50, worker_yield = 3},
  {name = "behemoth", complaint_count = 4, max_tier = 4, payout = 100, worker_yield = 5},
}

M.admin_station = {
  inventory_size = 20,
  base_waiting_capacity = 4,
  max_waiting_capacity = 12,
  capacity_technology_prefix = "admin-station-capacity-",
}

M.biter_station = {
  inventory_size = 20,
  money_slots = 1,
  range = 30,
  salary_per_dispatch = 1,
  night_coffee_per_dispatch = 5,
  base_visits_per_trip = 1,
  base_worker_entity = "small-biter",
  managed_buildings = {
    "propaganda-distillery",
    "corporate-breakroom",
    "centrifuge",
    "oil-refinery",
    "printer-t2",
  },
  labor_efficiency = {
    {technology = "biter-labor-efficiency-1", visits_per_trip = 3, worker_entity = "biter-worker-t2"},
    {technology = "biter-labor-efficiency-2", visits_per_trip = 5, worker_entity = "biter-worker-t3"},
  },
}
M.biter_station.worker_slots = M.biter_station.inventory_size - M.biter_station.money_slots

M.biterport = {
  worker_slots = 8,
  inventory_extra_slots = 1,
  logistics_radius = 25,
  connection_distance = 50,
  construction_radius = 55,
  salary_per_dispatch = 1,
  night_coffee_per_dispatch = 5,
  base_transport_capacity = 1,
  base_worker_entity = "biterport-worker",
  transport_capacity = {
    {technology = "biterport-transport-capacity-1", items_per_worker = 2},
    {technology = "biterport-transport-capacity-2", items_per_worker = 5},
    {technology = "biterport-transport-capacity-3", items_per_worker = 10},
    {technology = "biterport-transport-capacity-4", items_per_worker = 25},
  },
  worker_speed = {
    {technology = "biterport-worker-speed-1", multiplier = 1.35, worker_entity = "biterport-worker-fast"},
    {technology = "biterport-worker-speed-2", multiplier = 1.70, worker_entity = "biterport-worker-express"},
  },
}
M.biterport.inventory_size = M.biterport.worker_slots + M.biterport.inventory_extra_slots

M.pneumatic = {
  base_capacity = 10,
  capacity = {
    {technology = "pneumatic-capacity-1", bonus = 15, total = 25},
    {technology = "pneumatic-capacity-2", bonus = 25, total = 50},
    {technology = "pneumatic-capacity-3", bonus = 50, total = 100},
    {technology = "pneumatic-capacity-4", bonus = 100, total = 200},
  },
}

M.hired_biter = {
  eviction_notice_capacity = 20,
}

M.working_hours = {
  night_start = 0.35,
  night_end = 0.65,
  managed_buildings = {
    "office-desk",
    "corporate-breakroom",
    "union-headquarters",
  },
}

function M.biter_entity_map(field)
  local values = {}
  for _, size in ipairs(M.biter_sizes) do
    values[size.name .. "-biter"] = size[field]
    values[size.name .. "-spitter"] = size[field]
  end
  return values
end

function M.as_set(names)
  local values = {}
  for _, name in ipairs(names or {}) do
    values[name] = true
  end
  return values
end

return M
