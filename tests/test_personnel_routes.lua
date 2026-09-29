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
  check(route and #route==2)
  local next_leg=G.compile(layout(route[2],cell(2,2),cell(2,4,"output")),route[2])
  check(next_leg and #next_leg==3)
end)
test("roads never silently turn", function()
  check(not G.compile(layout(start,cell(2,0),cell(2,2,"output")),start))
end)
test("gaps reject dispatch", function()
  check(not G.compile(layout(start,cell(4,0,"output")),start))
end)
test("dead end signs accept the incoming segment", function()
  check(G.compile(layout(start,cell(2,0,"sign",defines.direction.north)),start))
end)
test("local sign arrival does not require a reception", function()
  check(G.compile(layout(start,cell(2,0,"sign",defines.direction.west)),start))
end)
test("second input cannot be a destination", function()
  check(not G.compile(layout(start,cell(2,0,"input",defines.direction.east),cell(4,0,"output")),start))
end)
test("different forces cannot share routes", function()
  check(not G.compile(layout(start,cell(2,0,nil,nil,2),cell(4,0,"output")),start))
end)
test("a reached diagonal sign waits for a valid onward direction", function()
  local dest=cell(2,0,"sign",2)
  check(G.compile(layout(start,dest),start))
  check(not G.compile(layout(start,dest),dest))
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
test("all returned space tourists can travel but transient hatch items cannot", function()
  for _, size in ipairs({"small", "medium", "big", "behemoth"}) do
    check(R.cargo[size .. "-space-tourist"])
    check(not R.cargo[size .. "-departing-space-tourist"])
    check(not R.cargo[size .. "-spitter-tourism-package"])
  end
end)
test("independent adjacent lanes wait for full-footprint clearance", function()
  local neighbor=cell(2,2);neighbor.flow=R.key(4,2)
  local cells=layout(start,cell(2,0),cell(4,0,"output"),neighbor)
  check(G.compatible(G.compile(cells,start),cells))
end)
test("same-route neighboring cells remain convoy-compatible", function()
  local cells=layout(start,cell(2,0),cell(4,0,"output"))
  cells[R.key(2,0)].flow=R.key(4,0)
  check(G.compatible(G.compile(cells,start),cells))
end)
test("offset parallel lanes also protect their full envelopes", function()
  local neighbor=cell(1,2);neighbor.flow=R.key(3,2)
  local cells=layout(start,cell(2,0),cell(4,0,"output"),neighbor)
  check(G.compatible(G.compile(cells,start),cells))
end)
test("tight folded routes serialize traffic rather than deadlock", function()
  local cells=layout(start,cell(2,0),cell(4,0,"sign",defines.direction.south),
    cell(4,2,"sign",defines.direction.west),cell(2,2),cell(0,2,"output"))
  local route=G.compile(cells,start)
  check(route and route.guards and route.guards.serial)
  check(#route==3 and #route.guards==6)
end)
test("a serialized journey blocks overlapping ordinary routes", function()
  local route=G.compile(layout(start,cell(2,0),cell(4,0,"output")),start)
  check(not route.serial)
  route[2].refs=1;route[2].serial_refs=1
  check(not G.compatible(route))
end)
test("multisign filters choose relative exits and keep empty exits closed", function()
  local multi=cell(0,0,"sign",defines.direction.east)
  multi.node.entity.name=R.MULTISIGN
  multi.node.filters={left={["worker-biter"]=true},straight={},right={["management-trainee"]=true}}
  local cells=layout(multi,cell(0,-2),cell(0,-4,"output"),cell(2,0),cell(4,0,"output"),cell(0,2),cell(0,4,"output"))
  check(G.compile(cells,multi,"worker-biter")[3].key==R.key(0,-4))
  check(G.compile(cells,multi,"management-trainee")[3].key==R.key(0,4))
  check(not G.compile(cells,multi,"chemical-operator"),"empty straight exit opened")
  cells[R.key(0,-2)]=nil
  check(not G.compile(cells,multi,"worker-biter"),"unavailable filtered exit fell back to another lane")
end)
test("multisign duplicate filters have stable priority and rotate with the sign", function()
  local node={entity={name=R.MULTISIGN,direction=defines.direction.south},filters={
    left={["worker-biter"]=true},straight={["worker-biter"]=true},right={["worker-biter"]=true}}}
  check(R.direction_for(node,"worker-biter")==defines.direction.east)
  node.entity.direction=defines.direction.west
  check(R.direction_for(node,"worker-biter")==defines.direction.south)
end)
print("Personnel route tests: " .. passed .. " passed")
