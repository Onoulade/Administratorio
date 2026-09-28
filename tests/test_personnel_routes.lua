local passed = 0
local function test(name, fn)
  local ok, err = pcall(fn)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end
local function check(value, message) assert(value, message) end
defines = {direction = {north = 0, east = 4, south = 8, west = 12}}
local R = require("prototypes.shared.personnel_routing")
local G = require("scripts.personnel_route_graph")
local function cell(x,y,role,direction,force)
  local c = {x=x,y=y,key=R.key(x,y),force_index=force or 1}
  if role then c.node={role=role,entity={valid=true,direction=direction}} end
  return c
end
local function layout(...)
  local cells={}
  for _, c in ipairs({...}) do cells[c.key]=c end
  return cells
end
local start = cell(0,0,"input",defines.direction.east)
test("straight delivery", function()
  local route=G.compile(layout(start,cell(2,0),cell(4,0,"output")),start)
  check(route and #route==3)
end)
test("signs turn along cardinal pavement", function()
  local route=G.compile(layout(start,cell(2,0,"sign",defines.direction.south),cell(2,2),cell(2,4,"output")),start)
  check(route and #route==4)
end)
test("roads never silently turn", function()
  check(not G.compile(layout(start,cell(2,0),cell(2,2,"output")),start))
end)
test("gaps reject dispatch", function()
  check(not G.compile(layout(start,cell(4,0,"output")),start))
end)
test("dead end signs reject dispatch", function()
  check(not G.compile(layout(start,cell(2,0,"sign",defines.direction.north)),start))
end)
test("cycles reject dispatch", function()
  check(not G.compile(layout(start,cell(2,0,"sign",defines.direction.west)),start))
end)
test("second input cannot be a destination", function()
  check(not G.compile(layout(start,cell(2,0,"input",defines.direction.east),cell(4,0,"output")),start))
end)
test("different forces cannot share routes", function()
  check(not G.compile(layout(start,cell(2,0,nil,nil,2),cell(4,0,"output")),start))
end)
test("diagonal signs cannot route", function()
  check(not G.compile(layout(start,cell(2,0,"sign",2)),start))
end)
test("deleted destination is invalid", function()
  local dest=cell(2,0,"output");dest.node.entity.valid=false
  check(not G.compile(layout(start,dest),start))
end)
test("route walk is bounded", function()
  local cells=layout(start)
  for x=2,R.MAX_ROUTE_CELLS*2,2 do local c=cell(x,0);cells[c.key]=c end
  check(not G.compile(cells,start))
end)
test("same-direction convoys are compatible", function()
  local route=G.compile(layout(start,cell(2,0),cell(4,0,"output")),start)
  route[2].flow=route[3].key
  check(G.compatible(route))
end)
test("opposing or crossing journeys wait before admission", function()
  local route=G.compile(layout(start,cell(2,0),cell(4,0,"output")),start)
  route[2].flow=R.key(2,2)
  check(not G.compatible(route))
end)
test("personnel roster excludes field agents and mounts", function()
  for _,name in ipairs({"enrolled-biter","worker-biter","biter-worker","biter-logistics-formation",
    "union-delegate","chemical-operator","licensed-notary","missionary-manager","voluntary-exploration-space-miner"}) do check(R.cargo[name],name) end
  check(not R.cargo["hired-biter-capsule"] and not R.cargo["rideable-biter"] and not R.cargo["biter-egg"] and not R.cargo["iron-plate"])
end)
test("independent adjacent lanes wait for full-footprint clearance", function()
  local neighbor=cell(2,2);neighbor.flow=R.key(4,2)
  local cells=layout(start,cell(2,0),cell(4,0,"output"),neighbor)
  check(not G.compatible(G.compile(cells,start),cells))
end)
test("same-route neighboring cells remain convoy-compatible", function()
  local cells=layout(start,cell(2,0),cell(4,0,"output"))
  cells[R.key(2,0)].flow=R.key(4,0)
  check(G.compatible(G.compile(cells,start),cells))
end)
test("offset parallel lanes also protect their full envelopes", function()
  local neighbor=cell(1,2);neighbor.flow=R.key(3,2)
  local cells=layout(start,cell(2,0),cell(4,0,"output"),neighbor)
  check(not G.compatible(G.compile(cells,start),cells))
end)
test("tight folded routes serialize traffic rather than deadlock", function()
  local cells=layout(start,cell(2,0),cell(4,0,"sign",defines.direction.south),
    cell(4,2,"sign",defines.direction.west),cell(2,2),cell(0,2,"output"))
  local route=G.compile(cells,start)
  check(route and route.serial)
  route[4].refs=1
  check(not G.compatible(route,cells))
end)
test("a serialized journey blocks overlapping ordinary routes", function()
  local route=G.compile(layout(start,cell(2,0),cell(4,0,"output")),start)
  check(not route.serial)
  route[2].refs=1;route[2].serial_refs=1
  check(not G.compatible(route))
end)
print("Personnel route tests: " .. passed .. " passed")
