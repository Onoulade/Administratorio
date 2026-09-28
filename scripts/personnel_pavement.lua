-- Rebuild only after infrastructure edits, never in the movement loop.
local R = require("prototypes.shared.personnel_routing")
local M = {}
function M.refresh(s, surface, clear_block)
  local desired, nodes = {}, {}
  for key, cell in pairs(s.cells) do
    if cell.node and cell.node.entity.valid then desired[key] = cell; nodes[#nodes + 1] = cell end
  end
  table.sort(nodes, function(a,b) return a.key < b.key end)
  local claimed = {}
  local function claim(cell)
    for x=cell.x-1,cell.x do for y=cell.y-1,cell.y do claimed[R.key(x,y)]=cell.key end end
  end
  for _,cell in ipairs(nodes) do claim(cell) end
  for _, start in ipairs(nodes) do
    local dx, dy = R.vector(start.node.entity.direction)
    if dx and start.node.role ~= "output" then
      local segment = {}
      for i = 1, R.MAX_ROUTE_CELLS - 1 do
        local x, y = start.x + dx*i, start.y + dy*i
        local key = R.key(x,y)
        local existing = s.cells[key]
        if existing and existing.force_index ~= start.force_index then break end
        local cell = existing or {key=key,x=x,y=y,force_index=start.force_index}
        local clear = clear_block(surface,cell)
        for tx=x-1,x do for ty=y-1,y do
          local owner = claimed[R.key(tx,ty)] or s.tiles[R.key(tx,ty)]
          if surface.get_tile(tx,ty).collides_with("water_tile") or (owner and owner ~= key) then clear=false end
        end end
        if not clear then break end
        segment[#segment+1] = cell
        if cell.node then
          if cell.node.role == "sign" or cell.node.role == "output" then
            for _, part in ipairs(segment) do desired[part.key] = part; claim(part) end
          end
          break
        end
      end
    end
  end
  -- An admitted journey owns its old pavement until it drains/recoveries.
  s.deferred = false
  for key,cell in pairs(s.cells) do
    if (cell.refs or 0)>0 and not desired[key] then desired[key]=cell; s.deferred=true end
  end
  for key,cell in pairs(s.cells) do
    if not desired[key] then
      surface.set_tiles(cell.original,true,false,false,false)
      for _,t in ipairs(cell.original) do s.tiles[R.key(t.position[1],t.position[2])]=nil end
      s.cells[key]=nil
    end
  end
  local paint = {}
  for _,cell in pairs(desired) do
    if not s.cells[cell.key] then
      cell.original = {}
      for x=cell.x-1,cell.x do for y=cell.y-1,cell.y do
        cell.original[#cell.original+1]={name=surface.get_tile(x,y).name,position={x,y}}
      end end
      s.cells[cell.key]=cell
    end
    for x=cell.x-1,cell.x do for y=cell.y-1,cell.y do
      s.tiles[R.key(x,y)]=cell.key
      paint[#paint+1]={name=R.TILE,position={x,y}}
    end end
  end
  surface.set_tiles(paint,true,false,true,false)
  s.dirty = false
  s.revision = s.revision+1
end
return M
