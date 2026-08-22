local M = {}

function M.apply(entity)
  if not entity or not entity.valid then return end

  -- The capture bureau is a native fluid machine. The regular admin station
  -- has no native fluid boxes and keeps its fixed visual/footprint orientation.
  entity.rotatable = entity.name == "capture-bureau"
end

return M
