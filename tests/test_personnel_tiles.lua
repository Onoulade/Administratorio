-- Tile events cannot be raised by a Factorio scenario. Exercise their handler
-- with mixed protected/unprotected placements and real refund boundaries.
defines = {inventory = {robot_cargo = 1}}
local restored, refunded, spilled
storage = {personnel_routing = {surfaces = {[1] = {tiles = {["1:1"] = "a", ["1:2"] = "a"}}}}}
local surface = {
  set_tiles = function(tiles) restored = tiles end,
  spill_item_stack = function(args) spilled = args end,
}
game = {surfaces = {[1] = surface}, get_player = function()
  return {insert = function(stack) refunded = stack; return stack.count end}
end}
local routing = require("scripts.personnel_routing")
routing.on_tiles_built{surface_index=1,player_index=1,item={name="concrete"},quality={name="rare"},
  tiles={{position={x=1,y=1}}, {position={x=2,y=2}}}}
assert(#restored==1 and restored[1].name=="personnel-path-concrete")
assert(refunded.name=="concrete" and refunded.count==1 and refunded.quality=="rare")
assert(not spilled, "successful inventory refund must not duplicate a tile")
restored,refunded,spilled=nil,nil,nil
local robot={valid=true,get_inventory=function()
  return {insert=function(stack) refunded=stack;return 1 end}
end}
routing.on_tiles_built{surface_index=1,robot=robot,item={name="refined-concrete"},
  tiles={{position={x=1,y=1}}, {position={x=1,y=2}}}}
assert(#restored==2)
assert(spilled.stack.name=="refined-concrete" and spilled.stack.count==1)
assert(spilled.stack.quality=="normal" and spilled.max_radius==16)
restored,refunded,spilled=nil,nil,nil
routing.on_tiles_built{surface_index=2,tiles={{position={x=1,y=1}}}}
assert(not restored and not refunded and not spilled, "unrelated terrain must stay untouched")
print("Personnel tile event tests: 3 passed")
