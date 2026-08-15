-- The Unstaffed Operations Waiver only fits machines that actually need a
-- worker biter dispatched to them.
--
-- A module with no allowed_module_categories restriction goes in anything with
-- a module slot, which would let an AI Server or a printer hold a waiver that
-- does nothing. Every machine except the biter-station managed buildings is
-- therefore restricted to the categories that were already available to it.
--
-- Runs in final fixes so machines added or retuned by earlier stages, and by
-- other mods, are covered too.

local M = {}

local MACHINE_TYPES = {
  "assembling-machine",
  "furnace",
  "rocket-silo",
  "mining-drill",
  "lab",
  "beacon",
}

function M.apply(data, managed_building_names)
  local managed = {}
  for _, name in ipairs(managed_building_names) do
    managed[name] = true
  end

  -- Every module category except the waiver's own, discovered rather than
  -- hardcoded so a category added by another mod is not silently forbidden.
  local permitted = {}
  for name in pairs(data.raw["module-category"] or {}) do
    if name ~= "unstaffed-operations" then
      permitted[#permitted + 1] = name
    end
  end
  table.sort(permitted)
  if #permitted == 0 then return end

  for _, machine_type in ipairs(MACHINE_TYPES) do
    for name, prototype in pairs(data.raw[machine_type] or {}) do
      local slots = prototype.module_slots or 0
      if slots > 0 and not managed[name] and prototype.allowed_module_categories == nil then
        prototype.allowed_module_categories = {}
        for index, category in ipairs(permitted) do
          prototype.allowed_module_categories[index] = category
        end
      end
    end
  end
end

return M
