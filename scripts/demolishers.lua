local M = {}

M.SIZE_ORDER_COST = {small = 1, medium = 2, big = 3}
M.SIZE_COFFEE_COST = {small = 25, medium = 50, big = 75}
M.SIZE_DECAY = {small = 2, medium = 3, big = 4}

function M.get_demolisher_name(territory)
  for _, segmented_unit in ipairs((territory and territory.get_segmented_units and territory.get_segmented_units()) or {}) do
    if segmented_unit and segmented_unit.valid and segmented_unit.prototype then
      return segmented_unit.prototype.name
    end
  end
  return nil
end

function M.infer_demolisher_size(name)
  if type(name) ~= "string" then
    return "small"
  end
  if name:find("big%-demolisher", 1, false) then
    return "big"
  end
  if name:find("medium%-demolisher", 1, false) then
    return "medium"
  end
  return "small"
end

return M
