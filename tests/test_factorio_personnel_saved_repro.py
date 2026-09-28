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
  if old and old.lane_position and j.lane_position and old.state=='walking' and j.state=='walking' then
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
  helpers.write_file('personnel-saved-repro.txt','PASS '..r.delivered..' personnel; '..r.moving_ticks..' smooth movement ticks\n',false)
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
            '--disable-audio','--benchmark',str(save),'--benchmark-ticks','1860','--benchmark-runs','1'],cwd=REPO_ROOT,
            text=True,capture_output=True,timeout=45)
        marker=root/'script-output/personnel-saved-repro.txt'
        assert marker.exists(),(run.stdout+run.stderr)[-6500:]
        print(marker.read_text().strip())
if __name__=='__main__':main()
