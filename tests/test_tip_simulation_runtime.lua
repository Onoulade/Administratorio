-- Scene contracts. Native transfers and repeatability are checked by
-- test_factorio_tip_scenes.py; these checks prevent staged animations returning.
local root=(debug.getinfo(1,"S").source:match("@(.*/)") or "./"):gsub("tests/$","")
package.path=root.."?.lua;"..root.."?/init.lua;"..package.path
local simulations=require("prototypes.tips-and-tricks-simulations")
local unique={}
for _,scene in pairs(simulations) do
  assert(scene.mods[1]=="administratorio","production control scripts must run")
  assert(load(scene.init),"scene init must compile")
  unique[scene.init]=true
end
local count=0
for _ in pairs(unique) do count=count+1 end
assert(count==3,"expected three working layouts")
assert(simulations["administratorio-personnel-multisign"]==simulations["administratorio-personnel-routing"],"signed-path guides share their working layout")
local file=assert(io.open(root.."prototypes/tips-and-tricks-simulation-update.lua"))
local update=file:read("*a");file:close()
assert(load(update),"scene maintenance must compile")
for _,forbidden in ipairs({"teleport", "draw_sprite", "phase", "outtake.get_inventory", "reception.get_inventory", "walker"}) do
  assert(not update:find(forbidden,1,true),"scene update must not stage "..forbidden)
end
local locale=require("tests.locale_helpers")
for _,language in ipairs({"en","fr","ru"}) do
  local strings=locale.section(root,language,"tip-scene")
  assert(strings["pool-contents"] and strings["pool-contents"]:find("__1__",1,true),"missing live stock readout")
  for key in pairs(strings) do assert(key=="pool-contents","tutorial captions must stay in the tip text") end
end
print("Tips scene contracts: production runtime, three layouts, no staged motion, localized live stock passed")
