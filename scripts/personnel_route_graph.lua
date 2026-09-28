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
local function walk(cells, start, segment)
  local route, seen = {}, {}
  local cell = start
  local dx, dy
  local force_index = start.force_index
  for _ = 1, R.MAX_ROUTE_CELLS do
    if not cell or cell.force_index ~= force_index then
      return not segment and finish_route(route) or nil, "gap"
    end
    if seen[cell.key] then return not segment and finish_route(route) or nil, "cycle" end
    seen[cell.key] = true
    route[#route + 1] = cell
    local node = cell.node
    if node then
      if not node.entity.valid then return nil, "gap" end
      if node.role == "output" or (segment and node.role == "sign" and cell~=start) then return finish_route(route) end
      if node.role == "input" and cell ~= start then return nil, "input" end
      dx, dy = R.vector(node.entity.direction)
      if not dx then return nil, "direction" end
    end
    if not dx then return nil, "direction" end
    cell = cells[R.key(cell.x + dx, cell.y + dy)]
  end
  return not segment and finish_route(route) or nil, "length"
end
function M.compile(cells,start)
  local route,reason=walk(cells,start,true)
  if route then route.segment=true end
  if route and start.node.role=="input" then
    local ahead=walk(cells,start,false)
    if ahead and ahead.serial then route.guards=ahead end
  end
  return route,reason
end
-- A shared cell must keep the same successor for every admitted journey.
-- This protects occupied segments from opposing traffic. Terminal signs may
-- acquire an onward segment when it becomes available.
function M.compatible(route, cells)
  local membership = {}
  for _, cell in ipairs(route) do membership[cell.key] = true end
  for i, cell in ipairs(route) do
    if (cell.refs or 0) > 0 and (route.serial or (cell.serial_refs or 0) > 0) then return false end
    local successor = route[i + 1] and route[i + 1].key
    if successor and cell.flow and cell.flow ~= successor then return false end

  end
  return true
end
return M
