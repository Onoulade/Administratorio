-- Native rotation must turn multisign bodies/sockets exactly once.
defines = {direction={north=0,east=4,south=8,west=12}}
local R = require("prototypes.shared.personnel_routing")
local routing = require("scripts.personnel_routing")
local signals = require("scripts.personnel_signals")
local sign = {valid=true,name=R.MULTISIGN,unit_number=1,direction=0,
  force={},position={x=0,y=0},surface={},operable=false}
local ports = {}
for _,exit in ipairs(R.exits) do
  ports[exit]={valid=true,name=R.PORT.."-"..exit,position={x=0,y=0},direction=0,
    teleport=function() end,operable=false,rotatable=false}
end
sign.rotate=function(args)
  sign.direction=(sign.direction+(args.reverse and -4 or 4))%16
  return true
end
local cell={refs=2}
local surface={cells={["0:0"]=cell},revision=0}
local record={entity=sign,role="sign",key="0:0",surface_index=1,ports=ports}
storage={personnel_routing={records={[1]=record},surfaces={[1]=surface}}}
local player={opened=sign}
game={get_player=function() return player end}
signals.ensure_ports(record)
assert(sign.operable,"existing multisign remains unusable to native rotation")
local function rotate(entity,reverse)
  local previous=entity.direction
  entity.direction=(previous+(reverse and -4 or 4))%16
  routing.on_rotated{entity=entity,previous_direction=previous,player_index=1}
end
for _,exit in ipairs(R.exits) do
  assert(ports[exit].operable and ports[exit].rotatable,"socket rejects native rotation: "..exit)
  rotate(ports[exit])
  assert(sign.direction==4,"socket did not rotate the occupied owner exactly once: "..exit)
  for _,port in pairs(ports) do assert(port.direction==sign.direction,"socket directions diverged") end
  rotate(ports[exit],true)
  assert(sign.direction==0,"socket did not reverse the occupied owner: "..exit)
end
rotate(sign)
assert(sign.direction==4 and surface.dirty and surface.revision==7)
assert(cell.refs==2,"rotation discarded occupied route reservations")
for _,exit in ipairs(R.exits) do
  player.opened=ports[exit]
  routing.on_gui_opened{entity=ports[exit],player_index=1}
  assert(player.opened==nil,"socket exposed a signal editor: "..exit)
end
local regular={valid=true,name=R.SIGN}
player.opened=regular
routing.on_gui_opened{entity=regular,player_index=1}
assert(player.opened==nil,"regular sign exposed its generated counts for editing")
local chest={valid=true,name="steel-chest"}
player.opened=chest
routing.on_gui_opened{entity=chest,player_index=1}
assert(player.opened==chest,"unrelated GUI was closed")
local revision=surface.revision
rotate({valid=true,name="transport-belt",unit_number=9,direction=0})
assert(surface.revision==revision and sign.direction==4,"unrelated native rotation changed the sign")
print("Personnel rotation: native body/socket rotation, reverse, occupied reservations and GUI boundaries passed")
