#!/usr/bin/env python3
"""Diagnose/replay a copied 'bug walk biters' save; never modify the original."""
import argparse
import subprocess
import tempfile
import zipfile
from pathlib import Path
from test_factorio_runtime_smoke import prepare_profile, REPO_ROOT

CONTROL = r'''
local function check(x,msg) if not x then error("Personnel saved repro: "..msg) end end
local function count()
 local n=0
 for _,s in pairs(game.surfaces) do
  for _,e in ipairs(s.find_entities_filtered{name={'personnel-deployment-office','personnel-reception-office','personnel-recovery-crate'}}) do
   n=n+e.get_item_count('management-trainee')
  end
 end
 for _,j in ipairs(remote.call('administratorio-personnel-routing','inspect')) do if j.item=='management-trainee' then n=n+1 end end
 return n+(storage.repro and storage.repro.delivered or 0)
end
script.on_nth_tick(1,function()
 if not storage.repro then
  for _,s in pairs(game.surfaces) do for _,e in ipairs(s.find_entities_filtered{type='inserter'}) do e.active=false end end
  storage.repro={start=game.tick,total=count(),delivered=0,previous={},moving_ticks=0}
  check(storage.repro.total>0,'save has no test personnel')
 end
 local r=storage.repro
 local jobs=remote.call('administratorio-personnel-routing','inspect')
 for _,j in ipairs(jobs) do
  check(not j.recovery_reason,'unexpected cargo recovery: '..serpent.line(j))
  check(j.speed==prototypes.entity['small-biter'].speed,'walking speed is not vanilla')
  local old=r.previous[j.id]
  if j.item=='management-trainee' and old and old.lane_position and j.lane_position and old.state=='walking' and j.state=='walking' then
   local a,b=old.lane_position,j.lane_position
   local d=math.abs(a.x-b.x)+math.abs(a.y-b.y)
   if old.index==j.index and old.goal==j.goal then
    check(d>0.18 and d<0.21,'free-lane speed/stutter: '..d..' '..serpent.line(j))
    r.moving_ticks=r.moving_ticks+1
   end
  end
  r.previous[j.id]=j
 end
 -- Keep reception empty so a full office cannot mask movement failures.
 for _,s in pairs(game.surfaces) do
  check(#s.find_entities_filtered{name='personnel-path'}==0,'old manually placed pavement remains')
  for _,e in ipairs(s.find_entities_filtered{name='personnel-reception-office'}) do
   local inv=e.get_inventory(defines.inventory.furnace_result)
   local n=inv.get_item_count('management-trainee')
   r.delivered=r.delivered+n
   if n>0 then inv.remove{name='management-trainee',count=n} end
  end
  check(#s.find_entities_filtered{name='personnel-recovery-crate'}==0,'unexpected recovery crate')
 end
 check(count()==r.total,'personnel conservation failed at '..game.tick..': '..count()..'/'..r.total)
 if game.tick-r.start==1800 then
  check(#jobs==0,'saved lanes did not drain: '..serpent.line(jobs))
  check(r.delivered==r.total,'cargo returned to deployment halfway: '..r.delivered..'/'..r.total)
  check(r.moving_ticks>100,'continuous movement not exercised')
  local s=game.create_surface('personnel-rotation-repro',{autoplace_controls={}})
  s.request_to_generate_chunks({8,0},2);s.force_generate_chunk_requests()
  for _,e in ipairs(s.find_entities()) do e.destroy() end
  local tiles={}
  for x=-4,20 do for y=-4,4 do tiles[#tiles+1]={name='grass-1',position={x,y}} end end
  s.set_tiles(tiles)
  local function build(name,x,direction)
   local e=s.create_entity{name=name,position={x,0},direction=direction,force='player',snap_to_grid=false}
   script.raise_script_built{entity=e};check(e and e.valid,'rotation fixture placement failed');return e
  end
  local input=build('personnel-deployment-office',0,defines.direction.east)
  r.terminal=build('personnel-routing-sign',8,defines.direction.south)
  r.rotation_output=build('personnel-reception-office',16)
  s.set_tiles{{name='water',position={7,1}},{name='water',position={8,1}},{name='water',position={7,2}},{name='water',position={8,2}}}
  input.get_inventory(defines.inventory.furnace_source).insert{name='worker-biter',count=1}
  r.rotation_surface=s
  r.rotation_input=input
  r.rotation_buffer=game.create_inventory(5)
  check(r.rotation_buffer.insert{name='worker-biter',count=5}==5,'rotation queue buffer failed')
 end
 if r.rotation_input then
  if game.tick-r.start>1805 and not r.rotated then
   check(r.terminal.rotatable,'incoming dispatch re-locked terminal rotation')
   check(not r.terminal.minable,'incoming reservation lost mining protection')
  end
  local inv=r.rotation_input.get_inventory(defines.inventory.furnace_source)
  if not inv[1].valid_for_read then
   local stack=r.rotation_buffer.find_item_stack('worker-biter')
   if stack and inv.insert(stack)==1 then stack.clear() end
  end
  local n=inv.get_item_count('worker-biter')+r.rotation_buffer.get_item_count('worker-biter')+r.rotation_output.get_item_count('worker-biter')
  for _,j in ipairs(remote.call('administratorio-personnel-routing','inspect')) do
   if j.item=='worker-biter' and j.surface_index==r.rotation_surface.index then n=n+1 end
  end
  check(n==6,'redirected queue lost personnel: '..n)
 end
 if r.rotation_input and not r.rotated then
  local waiting,approaching=false,false
  for _,j in ipairs(remote.call('administratorio-personnel-routing','inspect')) do
   if j.item=='worker-biter' then
    waiting=waiting or (j.state=='stopped' and math.abs(j.lane_position.x-5.5)<0.02)
    approaching=approaching or j.state=='walking'
   end
  end
  if waiting and approaching then
  for _,j in ipairs(remote.call('administratorio-personnel-routing','inspect')) do
   if j.surface_index==r.rotation_surface.index then
    check(j.position.x+1<r.terminal.position.x-1,'waiting biter body overlaps the sign tile')
   end
  end
  check(r.terminal.rotatable and not r.terminal.minable,'waiting terminal cannot be redirected')
  check(game.players[1],'saved player missing from rotation repro')
  local player=game.players[1]
  check(player.teleport({8,-4},r.rotation_surface),'could not move player to rotation fixture')
  player.update_selected_entity(r.terminal.position)
  check(player.selected==r.terminal,'hovering the sign selects a walking biter instead')
  -- Existing saves can already have a proxy standing on the sign. Even that
  -- overlap must select infrastructure, not swallow the player's R key.
  local old_proxy=r.rotation_surface.create_entity{name='personnel-in-transit-worker-biter',position=r.terminal.position,force='player'}
  check(old_proxy,'could not create legacy overlap fixture');old_proxy.active=false
  player.update_selected_entity(r.terminal.position)
  check(player.selected==r.terminal,'legacy overlapping proxy hides sign selection')
  old_proxy.destroy()
  check(r.terminal.rotate{reverse=true,by_player=game.players[1]},'native player rotation failed')
  check(r.terminal.direction==defines.direction.east,'safe player rotation was rejected')
  check(not r.terminal.minable,'rotating terminal removed cargo protection')
  r.rotated=true
  end
 end
 if game.tick-r.start==2040 then
  check(r.rotated,'never tested a stopped leader with approaching followers')
  check(r.rotation_output.get_item_count('worker-biter')==6,'redirected queue did not drain: '..r.rotation_output.get_item_count('worker-biter')..' '..serpent.line(remote.call('administratorio-personnel-routing','inspect')))
  check(r.terminal.minable,'redirected terminal locks leaked')
  helpers.write_file('personnel-saved-repro.txt','PASS '..r.delivered..' personnel; '..r.moving_ticks..' smooth movement ticks; native terminal rotation\n',false)
 end
end)
'''

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--factorio-bin',required=True)
    p.add_argument('--save',required=True)
    a=p.parse_args()
    with tempfile.TemporaryDirectory(prefix='personnel-saved-repro-') as temp:
        root=Path(temp);prepare_profile(root)
        save=root/'instrumented-copy.zip'
        with zipfile.ZipFile(a.save) as src, zipfile.ZipFile(save,'w',zipfile.ZIP_DEFLATED) as dst:
            for name in src.namelist():
                dst.writestr(name,CONTROL.encode() if name.endswith('/control.lua') else src.read(name))
        run=subprocess.run([a.factorio_bin,'--config',str(root/'config.ini'),'--mod-directory',str(root/'mods'),
            '--disable-audio','--benchmark',str(save),'--benchmark-ticks','2060','--benchmark-runs','1'],cwd=REPO_ROOT,
            text=True,capture_output=True,timeout=45)
        marker=root/'script-output/personnel-saved-repro.txt'
        assert marker.exists(),(run.stdout+run.stderr)[-6500:]
        print(marker.read_text().strip())
if __name__=='__main__':main()
