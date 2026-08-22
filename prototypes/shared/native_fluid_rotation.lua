local M = {}

-- Visible crafting machines with native fluid boxes must be rotatable so their
-- pipe connections can be aligned during placement and after construction.
-- Hidden proxy plumbing uses a singular `fluid_box` and is intentionally not
-- covered by this policy.
function M.enable(entity)
  if entity and type(entity.fluid_boxes) == "table" and next(entity.fluid_boxes) ~= nil then
    entity.rotatable = true
  end
  return entity
end

return M
