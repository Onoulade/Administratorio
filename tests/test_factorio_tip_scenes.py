#!/usr/bin/env python3
"""Run actual tube, passenger and personnel transport for a minute in Factorio."""
from __future__ import annotations
import argparse
import json
import subprocess
import tempfile
from pathlib import Path

REPO_ROOT=Path(__file__).resolve().parents[1]

MONITOR=r'''
local function count_contents(contents)
 local total=0
 for _,stack in pairs(contents) do total=total+(type(stack)=="number" and stack or stack.count) end
 return total
end
script.on_event(defines.events.on_tick,function(event)
 for index,s in ipairs(storage.scenes) do
  storage.administratorio_tip_scene=s
  if s.kind=="tube" then
   for _,item in ipairs(s.items) do
    if s.outtake.get_signal({type="item",name=item,quality="normal"},defines.wire_connector_id.circuit_red)>0 then s.saw_pool_content=true end
   end
   for lane=1,2 do
    for key,stack in pairs(s.exit.get_transport_line(lane).get_contents()) do
     local item=type(stack)=="number" and key or stack.name
     local count=type(stack)=="number" and stack or stack.count
     s.delivered[item]=(s.delivered[item] or 0)+count
    end
   end
  elseif s.kind=="boarding" then
   local count=s.platform.get_control_behavior().get_section(1).get_slot(1).min or 0
   if count>0 and s.previous_count==0 then s.boardings=s.boardings+1 end
   s.previous_count=count
   if s.visitor and s.visitor.valid and s.visitor.position.x>-5 then s.walked=true end
  elseif s.kind=="path" then
   for i,output in ipairs(s.outputs) do
    local inv=output.get_inventory(defines.inventory.furnace_result)
    local count=inv.get_item_count(s.items[i])
    assert(count_contents(inv.get_contents())==count,"Multisign delivered a type to the wrong exit")
    s.delivered[s.items[i]]=(s.delivered[s.items[i]] or 0)+count
   end
  end
  -- SCENE_UPDATE
 end
 if event.tick==3600 then
  local results={}
  for _,s in ipairs(storage.scenes) do
   results[s.kind]={delivered=s.delivered,boardings=s.boardings,walked=s.walked,
    saw_pool_content=s.saw_pool_content}
  end
  helpers.write_file("tip-scenes-results.json",helpers.table_to_json(results),false)
  for _,s in ipairs(storage.scenes) do
   if s.kind=="boarding" then
    assert(s.walked and s.boardings>=3,"Visitor did not repeatedly walk and board through production code")
   else
    if s.kind=="tube" then assert(s.saw_pool_content,"Tube stock readout never saw real network contents") end
    for _,item in ipairs(s.items) do assert((s.delivered[item] or 0)>=3,s.kind.." failed to deliver "..item) end
   end
  end
  helpers.write_file("tip-scenes-passed.json",helpers.table_to_json(storage.scenes[1].delivered),false)
 end
end)
'''


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factorio-bin",required=True)
    parser.add_argument("--keep-profile",type=Path)
    args=parser.parse_args()
    temporary=None if args.keep_profile else tempfile.TemporaryDirectory(prefix="administratorio-tip-scenes-")
    root=args.keep_profile or Path(temporary.name)
    root.mkdir(parents=True,exist_ok=True)
    mods=root/"mods";mods.mkdir()
    (mods/"administratorio").symlink_to(REPO_ROOT,target_is_directory=True)
    probe=mods/"tip-scene-probe";probe.mkdir()
    (probe/"info.json").write_text(json.dumps({"name":"tip-scene-probe","version":"1.0.0", "title":"Native tip scene validation","author":"QA","factorio_version":"2.0","dependencies":["administratorio","space-age"]}))
    if args.keep_profile:
        # Unlock tips only in the disposable preview profile, never the mod.
        (probe/"data-final-fixes.lua").write_text('''
for name,tip in pairs(data.raw["tips-and-tricks-item"]) do
 if name:find("^administratorio%-") then tip.starting_status="unlocked";tip.trigger=nil end
end
''')
    (mods/"mod-list.json").write_text(json.dumps({"mods":[{"name":name,"enabled":True} for name in ("base","quality","elevated-rails","space-age","administratorio","tip-scene-probe")]}))
    (root/"config.ini").write_text(f"[path]\nread-data=__PATH__system-read-data__\nwrite-data={root}\n")
    scenes=[]
    for index,name in enumerate(("pneumatic-transport","passenger-boarding","personnel-routing"),1):
        export="local s=require('prototypes.tips-and-tricks-simulations');"+f"io.write(s['administratorio-{name}'].init)"
        init=subprocess.check_output(["lua","-e",export],cwd=REPO_ROOT,text=True)
        init=init.replace("local surface=game.surfaces[1]",f'local surface=game.create_surface("tip-{name}",{{autoplace_controls={{}}}})')
        scenes.append(f"do\n{init}\nlocal scene=storage.administratorio_tip_scene\nscene.delivered={{}};scene.boardings=0;scene.previous_count=0\nstorage.scenes[{index}]=scene\nend")
    update=(REPO_ROOT/"prototypes/tips-and-tricks-simulation-update.lua").read_text()
    (probe/"control.lua").write_text("script.on_init(function()\nstorage.scenes={}\n"+"\n".join(scenes)+"\nend)\n"+MONITOR.replace("-- SCENE_UPDATE",update))
    common=[args.factorio_bin,"--config",str(root/"config.ini"),"--mod-directory",str(mods),"--disable-audio"]
    for command in (common+["--create",str(root/"fixture.zip")],common+["--benchmark",str(root/"fixture.zip"),"--benchmark-ticks","3601","--benchmark-runs","1"]):
        result=subprocess.run(command,text=True,capture_output=True,timeout=90)
        assert result.returncode==0,(result.stdout+result.stderr)[-10000:]
    assert (root/"script-output/tip-scenes-passed.json").exists(),"Native scene result missing"
    print("Factorio tip scenes: both tube sources reach the belt, repeat passenger boarding, all three filtered exits deliver correctly")
    if args.keep_profile: print(f"Preview profile: {root}")
    if temporary: temporary.cleanup()


if __name__=="__main__": main()
