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

-- MMMMs are now meeting catalysts rather than cannon ammunition. Preserve any
-- workers already loaded into an orbital deployment cannon by converting only
-- those turret-ammo stacks into the replacement VESM ammunition. MMMMs stored
-- elsewhere remain managers and enter the new briefing loop unchanged.
-- The cannon is a Space Age entity; find_entities_filtered errors on an
-- unknown prototype name, so skip this block entirely when Space Age (and
-- therefore the cannon prototype) is not present.
if prototypes.entity["orbital-employment-cannon"] then
  for _, surface in pairs(game.surfaces or {}) do
    local cannons = surface.find_entities_filtered{
      name = "orbital-employment-cannon",
    }
    for _, cannon in pairs(cannons or {}) do
      local inventory = cannon.get_inventory(defines.inventory.turret_ammo)
      if inventory and inventory.valid then
        for slot_index = 1, #inventory do
          local stack = inventory[slot_index]
          if stack and stack.valid_for_read
            and stack.name == "middle-management-managing-manager"
          then
            local quality = stack.quality and stack.quality.name or "normal"
            stack.set_stack{
              name = "voluntary-exploration-space-miner",
              count = stack.count,
              quality = quality,
            }
          end
        end
      end
    end
  end
end
