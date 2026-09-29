#!/usr/bin/env python3
"""Validate the multisign GUI, persistence and settings copies in Factorio itself."""
from __future__ import annotations
import argparse
import json
import subprocess
import tempfile
import time
from pathlib import Path
from test_factorio_runtime_smoke import prepare_profile, REPO_ROOT, MOD_NAME, SMOKE_MOD_NAME

# Test-only entry points call the real handlers in an isolated copy of control.lua.
INSTRUMENTATION = r'''
remote.add_interface("multisign-gui-qa", {
 open=function(index,entity) personnel_routing.on_gui_opened{player_index=index,entity=entity} end,
 change=function(index,element) personnel_routing.on_gui_changed{player_index=index,element=element} end,
 close=function(index,element) personnel_routing.on_gui_closed{player_index=index,element=element} end,
 paste=function(source,destination) personnel_routing.on_settings_pasted{source=source,destination=destination} end,
 blueprint=function(index,mapping)
  personnel_routing.on_setup_blueprint{player_index=index,mapping={get=function() return mapping end}}
 end,
})
'''
CONTROL = r'''
local function check(v,m) if not v then error("Multisign GUI: "..m) end end
local function qa(name,...) return remote.call("multisign-gui-qa",name,...) end
local function record(e)
 for _,r in ipairs(remote.call("administratorio-personnel-routing","inspect_signals")) do
  if r.id==e.unit_number then return r end
 end
end
local function build(name,x,y,tags)
 local e=game.surfaces[1].create_entity{name=name,position={x,y},force="player",direction=defines.direction.east,snap_to_grid=false}
 check(e,"creation failed")
 script.raise_script_built{entity=e,tags=tags}
 check(e.valid,"build rejected")
 return e
end
local function change(p,element,value)
 if element.type=="switch" then element.switch_state=value else element.elem_value=value end
 qa("change",p.index,element)
end
local function setup()
 local s=game.surfaces[1]
 s.request_to_generate_chunks({0,0},2);s.force_generate_chunk_requests()
 for _,e in ipairs(s.find_entities()) do e.destroy() end
 local tiles={}
 for x=-20,35 do for y=-20,25 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
 s.set_tiles(tiles)
 s.always_day=true
 storage.sign=build("personnel-routing-multisign",0,0)
 storage.copy=build("personnel-routing-multisign",12,0)
 local source=s.create_entity{name="constant-combinator",position={-4,0},force="player"}
 local section=source.get_or_create_control_behavior().add_section()
 section.filters={{value={type="item",name="management-trainee",quality="rare"},min=1}}
 local id=defines.wire_connector_id.circuit_red
 source.get_wire_connector(id,true).connect_to(record(storage.sign).ports.right.get_wire_connector(id,true))
 storage.p=game.players[1]
 storage.p.set_controller{type=defines.controllers.god}
 storage.p.teleport({0,0})
 storage.p.zoom=1.2
 storage.p2=storage.p
end
script.on_event(defines.events.on_tick,function(event)
 if event.tick==1 then setup() end
 if event.tick==10 and not storage.saved then
  local p,p2=storage.p,storage.p2
  qa("open",p.index,storage.sign)
  local root=p.gui.screen["administratorio-personnel-multisign"]
  check(root and root.valid and p.opened==root,"panel did not open")
  qa("open",p2.index,record(storage.sign).ports.left)
  local other=p2.opened
  check(other==root,"socket recreated the already open owner panel")
  for _,exit in ipairs({"left","straight","right"}) do
   check(#root.body[exit].slots.children==5,"not exactly five slots")
   check(root.body[exit].heading.mode.switch_state=="right","legacy circuit default lost")
   check(not root.body[exit].slots.slot1.enabled,"circuit mode leaves manual slots enabled")
  end
  change(p,root.body.left.heading.mode,"left")
  change(p,root.body.left.slots.slot5,"worker-biter")
  check(record(storage.sign).filters.left["worker-biter"],"fifth manual filter ignored")
  check(other.body.left.slots.slot5.elem_value=="worker-biter","concurrent viewer stale")
  check(record(storage.sign).filters.right["management-trainee"],"independent circuit exit lost signals")
  change(p,root.body.left.heading.mode,"right")
  check(not next(record(storage.sign).filters.left),"manual filters remained active in circuit mode")
  change(p,root.body.left.heading.mode,"left")
  check(root.body.left.slots.slot5.elem_value=="worker-biter","mode switch discarded manual filters")
  change(p,root.body.left.slots.slot5,nil)
  check(not next(record(storage.sign).filters.left),"clearing last slot did not close exit")
  change(p,root.body.left.slots.slot1,"worker-biter")
  change(p,root.body.straight.heading.mode,"left")
  for slot,name in ipairs({"management-trainee","chemical-operator","licensed-notary","worker-biter","biter-logistics-formation"}) do
   change(p,root.body.straight.slots["slot"..slot],name)
  end
  check(not root.body.right.slots.slot1.enabled,"right circuit mode unexpectedly changed")
  qa("paste",storage.sign,storage.copy)
  check(record(storage.copy).configuration.manual_filters.straight[5]=="biter-logistics-formation","settings paste lost fifth slot")
  local clone=storage.sign.clone{position={24,0},surface=storage.sign.surface,force="player"}
  check(clone and record(clone).configuration.manual_filters.left[1]=="worker-biter","clone lost manual configuration")
  p.cursor_stack.set_stack{name="blueprint"}
  local mapping=p.cursor_stack.create_blueprint{surface=storage.sign.surface,force="player",area={{-2,-2},{2,2}}}
  qa("blueprint",p.index,mapping)
  local tags
  for index,e in pairs(mapping) do if e==storage.sign then tags=p.cursor_stack.get_blueprint_entity_tags(index) end end
  check(tags and tags.personnel_multisign,"blueprint missing settings tag")
  local bp=build("personnel-routing-multisign",0,16,tags)
  check(record(bp).configuration.manual_filters.straight[5]=="biter-logistics-formation","blueprint tag restore lost fifth slot")
  check(record(bp).configuration.filter_modes.left=="manual","blueprint mode restore failed")
  p.cursor_stack.clear()
  qa("close",p2.index,other)
  check(not other.valid and not p2.opened,"Escape close leaked GUI")
  qa("open",p2.index,storage.copy)
  storage.copy.destroy{raise_destroy=true}
  check(not p2.gui.screen["administratorio-personnel-multisign"],"removed sign leaked GUI")
  storage.saved=true
  qa("open",p.index,storage.sign)
  game.auto_save("multisign-ui-preview")
 elseif event.tick==12 and not game.is_multiplayer() then
  storage.p.gui.screen["administratorio-personnel-multisign"].location={x=20,y=20}
  game.take_screenshot{player=storage.p,path="multisign-ui.png",resolution={1040,1180},show_gui=true}
 elseif event.tick==30 then
  local r=record(storage.sign)
  check(r.configuration.manual_filters.straight[5]=="biter-logistics-formation","saved fifth filter lost")
  check(r.configuration.filter_modes.right=="circuit" and r.filters.right["management-trainee"],"saved circuit mode lost")
  qa("open",storage.p.index,storage.sign)
  check(storage.p.opened.body.straight.slots.slot5.elem_value=="biter-logistics-formation","saved GUI filter value lost")
  helpers.write_file("multisign-gui-qa.txt","PASS\n",false)
 end
end)
'''

def main() -> None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--factorio-bin',required=True)
    parser.add_argument('--keep-profile',type=Path)
    args=parser.parse_args()
    temporary=tempfile.TemporaryDirectory(prefix='administratorio-multisign-gui-') if not args.keep_profile else None
    root=args.keep_profile or Path(temporary.name)
    root.mkdir(parents=True,exist_ok=True)
    prepare_profile(root)
    mod=root/'mods'/MOD_NAME
    mod.unlink()
    mod.mkdir()
    for path in REPO_ROOT.iterdir():
        if path.name in {'.git','control.lua'}: continue
        (mod/path.name).symlink_to(path,target_is_directory=path.is_dir())
    (mod/'control.lua').write_text((REPO_ROOT/'control.lua').read_text()+INSTRUMENTATION)
    (root/'mods'/SMOKE_MOD_NAME/'scenarios/runtime-smoke/control.lua').write_text(CONTROL)
    (root/'saves').mkdir()
    common=[args.factorio_bin,'--config',str(root/'config.ini'),'--mod-directory',str(root/'mods'),'--disable-audio']
    marker=root/'script-output/multisign-gui-qa.txt'
    save=root/'saves/_autosave-multisign-ui-preview.zip'
    log=root/'gui.log'
    with log.open('w') as stream:
        process=subprocess.Popen(common+['--load-scenario',f'{SMOKE_MOD_NAME}/runtime-smoke'],stdout=stream,stderr=subprocess.STDOUT)
        try:
            deadline=time.monotonic()+60
            while (not marker.exists() or not save.exists()) and process.poll() is None and time.monotonic()<deadline:
                time.sleep(.1)
        finally:
            if process.poll() is None: process.terminate()
            process.wait(timeout=10)
    assert marker.exists() and save.exists(),log.read_text()[-6000:]
    marker.unlink()
    result=subprocess.run(common+['--benchmark',str(save),'--benchmark-ticks','30','--benchmark-runs','1'],capture_output=True,text=True,timeout=45)
    assert marker.exists(),(result.stdout+result.stderr)[-6000:]
    print('Factorio multisign GUI controls, manual/circuit sources, cloning, settings paste, blueprints, deletion and save/load passed')
    if args.keep_profile: print(f'Preview profile: {root}')
    if temporary: temporary.cleanup()
if __name__=='__main__': main()
