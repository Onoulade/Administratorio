-- Administrative Certification migration.  Older biterport records identify
-- items by name only; those records mean normal Quality, never an arbitrary
-- grade.  control.lua rebuilds the hidden roboports during configuration
-- change after this normalization has completed.
local separator = string.char(31)

local function item_key(name, quality)
  return tostring(name or "") .. separator .. (quality or "normal")
end

for _, reservation in pairs(storage.biterport_logistics_reservations or {}) do
  if reservation and reservation.item_name then
    reservation.item_quality = reservation.item_quality or "normal"
    reservation.item_key = item_key(reservation.item_name, reservation.item_quality)
  end
end

for _, active in pairs(storage.biterport_workers or {}) do
  local job = active and active.job
  if job and job.item_name then
    job.item_quality = job.item_quality or job.quality or "normal"
    job.item_key = item_key(job.item_name, job.item_quality)
  end
  local carried = active and active.carried_stack
  if carried and carried.name then
    carried.quality = carried.quality or "normal"
  end
end

for _, cache in pairs(storage.biterport_storage_target_cache or {}) do
  for name, unit_number in pairs(cache) do
    if type(name) == "string" and not name:find(separator, 1, true) then
      cache[item_key(name, "normal")] = unit_number
      cache[name] = nil
    end
  end
end
