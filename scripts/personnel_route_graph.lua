-- Pure, bounded graph walk. A direction continues until a sign or reception
-- office; pavement alone never turns. Cache invalidation belongs to the runtime.
local R = require("prototypes.shared.personnel_routing")
local M = {}
local function finish_route(route)
  local indices = {}
  for i, cell in ipairs(route) do indices[cell.key] = i end
  -- A tightly folded lane puts distant parts of the same journey beside one
  -- another. Serialize it so swept 2x2 bodies cannot intersect at a hairpin.
  for i, cell in ipairs(route) do
    for dx = -2, 2 do for dy = -2, 2 do
      local other = indices[R.key(cell.x + dx, cell.y + dy)]
      if other and math.abs(other - i) > 2 then route.serial = true; route.membership = indices; return route end
    end end
  end
  return route
end
function M.compile(cells, start)
  local route, seen = {}, {}
  local cell = start
  local dx, dy
  local force_index = start.force_index
  for _ = 1, R.MAX_ROUTE_CELLS do
    if not cell or cell.force_index ~= force_index then return nil, "gap" end
    if seen[cell.key] then return nil, "cycle" end
    seen[cell.key] = true
    route[#route + 1] = cell
    local node = cell.node
    if node then
      if not node.entity.valid then return nil, "gap" end
      if node.role == "output" then return finish_route(route) end
      if node.role == "input" and cell ~= start then return nil, "input" end
      dx, dy = R.vector(node.entity.direction)
      if not dx then return nil, "direction" end
    end
    if not dx then return nil, "direction" end
    cell = cells[R.key(cell.x + dx, cell.y + dy)]
  end
  return nil, "length"
end
-- A shared cell must keep the same successor for every admitted journey.
-- This makes the live directed graph acyclic (every journey ends at an output),
-- so merges can queue without opposite-direction or multi-route deadlocks.
function M.compatible(route, cells)
  local membership = {}
  for _, cell in ipairs(route) do membership[cell.key] = true end
  for i, cell in ipairs(route) do
    if (cell.refs or 0) > 0 and (route.serial or (cell.serial_refs or 0) > 0) then return false end
    local successor = route[i + 1] and route[i + 1].key or "arrival"
    if cell.flow and cell.flow ~= successor then return false end
    -- Keep independently routed traffic out of adjacent lanes while this
    -- convoy is admitted, so full bodies cannot intersect at corners.
    if cells then
      for dx = -2, 2 do for dy = -2, 2 do
        local neighbor = cells[R.key(cell.x + dx, cell.y + dy)]
        if neighbor and neighbor.flow and not membership[neighbor.key] then return false end
      end end
    end
  end
  return true
end
return M
