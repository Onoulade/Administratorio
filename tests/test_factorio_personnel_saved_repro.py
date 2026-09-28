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
 end
 if game.tick-r.start==2100 then
  local s=game.create_surface('personnel-live-turn-repro',{autoplace_controls={}})
  s.request_to_generate_chunks({48,12},3);s.force_generate_chunk_requests()
  for _,e in ipairs(s.find_entities()) do e.destroy() end
  local tiles={}
  for x=-4,96 do for y=-20,44 do tiles[#tiles+1]={name='grass-1',position={x,y}} end end
  s.set_tiles(tiles)
  local function build(name,x,y,direction)
   local e=s.create_entity{name=name,position={x,y},direction=direction,force='player',snap_to_grid=false}
   script.raise_script_built{entity=e};check(e and e.valid,'live turn fixture placement failed');return e
  end
  r.live={surface=s,input=build('personnel-deployment-office',0,0,defines.direction.east),
   sign=build('personnel-routing-sign',8,0,defines.direction.south),
   old_output=build('personnel-reception-office',8,40),new_output=build('personnel-reception-office',40,0),
   buffer=game.create_inventory(4)}
  r.live.input.get_inventory(defines.inventory.furnace_source).insert{name='worker-biter',count=1}
  r.live.buffer.insert{name='worker-biter',count=4}
  r.live.all_sides=build('personnel-reception-office',80,0,defines.direction.west)
  r.live.side_inputs={}
  for _,p in ipairs({{80,-12,defines.direction.south},{92,0,defines.direction.west},
    {80,12,defines.direction.north},{68,0,defines.direction.east}}) do
   local departure=build('personnel-deployment-office',p[1],p[2],p[3])
   r.live.side_inputs[#r.live.side_inputs+1]=departure
   departure.get_inventory(defines.inventory.furnace_source).insert{name='worker-biter',count=1}
  end
 end
 if r.live then
  local live=r.live
  check(not live.all_sides.rotatable and not live.all_sides.rotate{},'omnidirectional reception rotates')
  local inv=live.input.get_inventory(defines.inventory.furnace_source)
  if not inv[1].valid_for_read then
   local stack=live.buffer.find_item_stack('worker-biter')
   if stack and inv.insert(stack)==1 then stack.clear() end
  end
  local live_jobs={}
  local n=inv.get_item_count('worker-biter')+live.buffer.get_item_count('worker-biter')
    +live.old_output.get_item_count('worker-biter')+live.new_output.get_item_count('worker-biter')
    +live.all_sides.get_item_count('worker-biter')
  for _,input in ipairs(live.side_inputs) do n=n+input.get_inventory(defines.inventory.furnace_source).get_item_count('worker-biter') end
  for _,j in ipairs(remote.call('administratorio-personnel-routing','inspect')) do
   if j.surface_index==live.surface.index then
    n=n+1;live_jobs[#live_jobs+1]=j
    if not live.early_rotation and j.lane_position.x>5.5 and j.lane_position.x<6 and math.abs(j.lane_position.y)<0.01 then
     -- An approach reservation must not freeze the direction before the
     -- full body actually enters the sign tile.
     live.early_rotation={id=j.id,tick=game.tick}
     check(live.sign.rotate{by_player=game.players[1]},'pre-entry rotation failed')
    end
    if live.early_rotation and not live.early_checked and game.tick-live.early_rotation.tick>=8 and j.id==live.early_rotation.id then
     check(j.state=='stopped' and j.lane_position.x<=6,'pre-entry biter followed a direction frozen too early')
     check(j.position.x+1<7,'pre-entry rotation let the biter body cross the sign tile')
     check(live.sign.rotate{reverse=true,by_player=game.players[1]},'pre-entry queue could not resume')
     live.early_checked=true
    end
    if not live.frozen_id and j.lane_position.x>7 and j.lane_position.x<8 and math.abs(j.lane_position.y)<0.01 then
     -- Rotate with the leader's center physically inside the sign tile. Its
     -- saved SOUTH departure must survive a new, invalid WEST arrow.
     live.frozen_id=j.id
     local player=game.players[1];check(player.teleport({8,-4},live.surface),'live turn player teleport failed')
     player.update_selected_entity(live.sign.position)
     check(player.selected==live.sign,'occupied live sign cannot be selected')
     check(live.sign.rotate{by_player=player},'occupied live sign cannot rotate')
     check(live.sign.direction==defines.direction.west,'occupied rotation reverted')
    end
    if j.id==live.frozen_id and j.lane_position.y>0.01 then
     check(math.abs(j.lane_position.x-8)<0.01,'entered biter followed the rotated arrow')
    end
   end
  end
  check(n==9,'live rotation lost personnel: '..n)
  for i,a in ipairs(live_jobs) do for k=i+1,#live_jobs do
   local p,q=a.position,live_jobs[k].position
   check(math.abs(p.x-q.x)>=2-1/256 or math.abs(p.y-q.y)>=2-1/256,'live rotation overlaps full biter bodies')
  end end
  if game.tick-r.start==2250 then
   check(live.frozen_id,'never rotated with a biter inside the sign tile')
   check(live.early_checked,'never rotated before a biter entered the sign tile')
   check(live.old_output.get_item_count('worker-biter')==0,'old-direction fixture already finished')
   check(live.all_sides.get_item_count('worker-biter')==4,'reception did not accept all four directions: '..serpent.line(live_jobs))
   local waiting=false
   for _,j in ipairs(live_jobs) do
    if j.id~=live.frozen_id and j.lane_position.y==0 and j.lane_position.x<=8 then
     check(j.lane_position.x<=5.5+1/256,'next biter entered an invalid rotated sign')
     waiting=waiting or (j.state=='stopped' and math.abs(j.lane_position.x-5.5)<0.01)
    end
   end
   check(waiting,'next biter did not wait before the newly invalid sign')
   local player=game.players[1]
   check(live.sign.rotate{reverse=true,by_player=player} and live.sign.rotate{reverse=true,by_player=player},'could not redirect waiting followers')
   check(live.sign.direction==defines.direction.east,'live sign failed to choose new valid direction')
  end
  if game.tick-r.start==2280 then
   local old_moving,new_moving=false,false
   for _,j in ipairs(live_jobs) do
    old_moving=old_moving or (j.id==live.frozen_id and j.lane_position.y>5)
    new_moving=new_moving or (j.id~=live.frozen_id and j.lane_position.x>8 and math.abs(j.lane_position.y)<0.01)
   end
   check(old_moving and new_moving,'new direction waits for the entire old leg instead of junction clearance')
  end
  if game.tick-r.start==2750 then
   check(#live_jobs==0,'live turn queues failed to drain: '..serpent.line(live_jobs))
   check(live.old_output.get_item_count('worker-biter')==1 and live.new_output.get_item_count('worker-biter')==4,'live turns changed the entered direction or following queue')
   check(live.sign.minable and live.sign.rotatable,'live junction reservations leaked')
   helpers.write_file('personnel-saved-repro.txt','PASS '..r.delivered..' personnel; '..r.moving_ticks..' smooth movement ticks; native hover/rotation; frozen entered turn; four-sided reception\n',false)
  end
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
            '--disable-audio','--benchmark',str(save),'--benchmark-ticks','2780','--benchmark-runs','1'],cwd=REPO_ROOT,
            text=True,capture_output=True,timeout=45)
        marker=root/'script-output/personnel-saved-repro.txt'
        assert marker.exists(),(run.stdout+run.stderr)[-6500:]
        print(marker.read_text().strip())
if __name__=='__main__':main()
