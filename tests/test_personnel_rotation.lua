-- Linked rotate controls must work on non-operable multisign sockets/bodies.
defines = {direction={north=0,east=4,south=8,west=12}}
local R = require("prototypes.shared.personnel_routing")
local routing = require("scripts.personnel_routing")
local force = {}
local sign = {valid=true,name=R.MULTISIGN,unit_number=1,direction=0,
  force=force,position={x=0,y=0},surface={},operable=false}
local ports = {}
for _,exit in ipairs(R.exits) do
  ports[exit]={valid=true,name=R.PORT.."-"..exit,position={x=0,y=0},
    teleport=function() end,operable=false}
end
sign.rotate=function(args)
  sign.direction=(sign.direction+(args.reverse and -4 or 4))%16
  return true
end
local cell={refs=2}
local surface={cells={["0:0"]=cell},revision=0}
local record={entity=sign,role="sign",key="0:0",surface_index=1,ports=ports}
storage={personnel_routing={records={[1]=record},surfaces={[1]=surface}}}
local reachable=true
local player={force=force,surface=sign.surface,cursor_stack={valid_for_read=false},
  can_reach_entity=function() return reachable end}
game={get_player=function() return player end}
local function rotate(entity,reverse,in_gui,cursor)
  player.selected=entity
  routing.on_rotate_input{player_index=1,in_gui=in_gui,cursor_position=cursor,
    input_name=reverse and "administratorio-reverse-rotate-personnel-sign" or "administratorio-rotate-personnel-sign"}
end
for _,exit in ipairs(R.exits) do
  rotate(ports[exit])
  assert(sign.direction==4,"socket did not rotate the occupied owner: "..exit)
  rotate(ports[exit],true)
  assert(sign.direction==0,"socket did not reverse the occupied owner: "..exit)
end
rotate(sign)
assert(sign.direction==4 and surface.dirty and surface.revision==7)
assert(cell.refs==2,"rotation discarded occupied route reservations")
assert(not sign.operable,"rotation opened the signal editor")
rotate(nil,false,false,{x=0,y=0})
assert(sign.direction==8,"protected body disappeared from rotation selection")
rotate({valid=true,name="personnel-in-transit-worker-biter"},true,false,{x=0,y=0})
assert(sign.direction==4,"walking proxy hid the occupied sign from rotation")
rotate({valid=true,name=R.ROAD},true,false,{x=0,y=0})
assert(sign.direction==0,"protected pavement hid the sign from rotation")
local revision=surface.revision
rotate(sign,false,true)
player.cursor_stack.valid_for_read=true;rotate(sign)
player.cursor_stack.valid_for_read=false;reachable=false;rotate(sign)
reachable=true;player.force={};rotate(sign)
player.force=force;rotate({valid=true,name="steel-chest"})
rotate(nil)
rotate(nil,false,false,{x=1.1,y=0})
assert(surface.revision==revision and sign.direction==0,
  "GUI, cursor-item, unreachable, other-force or unrelated rotation changed the sign")
print("Personnel rotation: all sockets, reverse, occupied body and control boundaries passed")
