#!/usr/bin/env python3
"""Native circuit filters, speed research, three-way routing and incoming counts."""
from __future__ import annotations
import argparse
import json
import subprocess
import tempfile
import time
from pathlib import Path
from test_factorio_runtime_smoke import prepare_profile, REPO_ROOT, SMOKE_MOD_NAME

CONTROL = r'''
local function check(v,m) if not v then error("Personnel circuits: "..m) end end
local function build(s,name,x,y,direction)
 local e=s.create_entity{name=name,position={x,y},direction=direction,force="player",snap_to_grid=false}
 check(e,"creation failed: "..name)
 script.raise_script_built{entity=e}
 check(e.valid,"placement rejected: "..name)
 return e
end
local function inv(e,out) return e.get_inventory(out and defines.inventory.furnace_result or defines.inventory.furnace_source) end
local function source(s,x,y)
 local e=s.create_entity{name="constant-combinator",position={x,y},force="player"}
 check(e,"signal source not created")
 return e
end
local function set(e,values)
 local c=e.get_or_create_control_behavior()
 local section=c.get_section(1) or c.add_section()
 local filters={}
 for _,v in ipairs(values) do filters[#filters+1]={value={type="item",name=v[1],quality=v[3] or "normal"},min=v[2]} end
 section.filters=filters
end
local function wire(a,b,color)
 local id=color=="green" and defines.wire_connector_id.circuit_green or defines.wire_connector_id.circuit_red
 check(a.get_wire_connector(id,true).connect_to(b.get_wire_connector(id,true)),"wire failed")
end
local function ports(sign)
 for _,r in ipairs(remote.call("administratorio-personnel-routing","inspect_signals")) do if r.id==sign.unit_number then return r.ports end end
 error("multisign ports missing")
end
local function jobs(s)
 local result={}
 for _,j in ipairs(remote.call("administratorio-personnel-routing","inspect")) do if j.surface_index==s.index then result[#result+1]=j end end
 return result
end
local function count(e,item)
 local count=0
 for _,stack in ipairs(inv(e,true).get_contents()) do if stack.name==item then count=count+stack.count end end
 return count
end
local function fixture_surface(name)
 local s=game.create_surface(name,{autoplace_controls={}})
 s.request_to_generate_chunks({0,0},3);s.force_generate_chunk_requests()
 for _,e in ipairs(s.find_entities()) do e.destroy() end
 local tiles={}
 for x=-8,70 do for y=-20,70 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
 s.set_tiles(tiles)
 return s
end
local function new_fixture()
 local f={start=game.tick,s=fixture_surface("personnel-circuits")}
 local force=game.forces.player
 force.technologies["personnel-routing"].researched=true
 force.technologies["personnel-routing-multisign"].researched=true
 force.technologies["personnel-routing-speed-1"].researched=false
 force.technologies["personnel-routing-speed-2"].researched=false
 local s=f.s
 f.input=build(s,"personnel-deployment-office",0,0,defines.direction.east)
 f.sign=build(s,"personnel-routing-multisign",12,0,defines.direction.east)
 f.left=build(s,"personnel-reception-office",12,-12)
 f.straight=build(s,"personnel-reception-office",24,0)
 f.right=build(s,"personnel-reception-office",12,12)
 local p=ports(f.sign)
 check(not f.sign.operable and f.sign.type=="simple-entity-with-owner","multisign body has an ambiguous native signal editor")
 for _,exit in ipairs({"left","straight","right"}) do
  check(p[exit] and p[exit].valid and not p[exit].operable,"missing or editable exit socket: "..exit)
 end
 check(p.left.unit_number~=p.straight.unit_number and p.straight.unit_number~=p.right.unit_number,"exit sockets share one wire target")
 f.lsource=source(s,8,-4);f.rsource=source(s,8,4);f.ssource=source(s,16,4)
 wire(f.lsource,p.left);wire(f.rsource,p.right);wire(f.ssource,p.straight)
 set(f.ssource,{{"iron-plate",10}}) -- Ordinary cargo signals must not open an exit.
 set(f.lsource,{{"worker-biter",1}});set(f.rsource,{{"management-trainee",1}})
 f.buffer=game.create_inventory(4)
 f.buffer.insert{name="worker-biter",count=1,quality="rare"}
 f.buffer.insert{name="worker-biter",count=1,quality="epic"}
 f.buffer.insert{name="management-trainee",count=1,quality="uncommon"}
 -- Three approaches to one regular sign exercise per-type, per-segment sums.
 f.csign=build(s,"personnel-routing-sign",16,40,defines.direction.east)
 f.inputs={build(s,"personnel-deployment-office",0,40,defines.direction.east),
  build(s,"personnel-deployment-office",16,24,defines.direction.south),
  build(s,"personnel-deployment-office",16,56,defines.direction.north)}
 f.cbuffers={game.create_inventory(2),game.create_inventory(2),game.create_inventory(1)}
 for i=1,2 do f.cbuffers[i].insert{name="worker-biter",count=1,quality="rare"};f.cbuffers[i].insert{name="worker-biter",count=1,quality="epic"} end
 f.cbuffers[3].insert{name="management-trainee",count=1}
 f.reader=source(s,20,44);wire(f.reader,f.csign)
 -- Rotation while queued must move side sockets without losing their wires.
 f.rotinput=build(s,"personnel-deployment-office",48,12,defines.direction.north)
 f.rotsign=build(s,"personnel-routing-multisign",48,0,defines.direction.north)
 f.rotwest=build(s,"personnel-reception-office",36,0)
 f.rotnorth=build(s,"personnel-reception-office",48,-12)
 f.rotsource=source(s,44,-4);wire(f.rotsource,ports(f.rotsign).left)
 inv(f.rotinput).insert{name="enrolled-biter",count=1,quality="legendary"}
 return f
end
local function feed(e,buffer)
 if inv(e)[1].valid_for_read then return end
 for i=1,#buffer do if buffer[i].valid_for_read then
  local stack=buffer[i]; if inv(e).insert(stack)==1 then stack.clear() end;return
 end end
end
local function values(e)
 local result={}
 for _,v in ipairs(e.get_signals(defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green) or {}) do
  if (v.signal.type or "item")=="item" then result[v.signal.name]=(result[v.signal.name] or 0)+v.count end
 end
 return result
end
script.on_init(function() game.speed=10 end)
script.on_nth_tick(1,function()
 storage.fixture=storage.fixture or new_fixture()
 local f=storage.fixture
 local t=game.tick-f.start
 feed(f.input,f.buffer)
 for i,e in ipairs(f.inputs) do feed(e,f.cbuffers[i]) end
 local force=game.forces.player
 -- Change a live filter after the first worker's body enters the junction.
 if not f.changed then
  for _,j in ipairs(jobs(f.s)) do
   if j.item=="worker-biter" and j.position.x>10.1 and j.position.x<12 and math.abs(j.position.y)<0.1 then
    set(f.lsource,{})
    set(f.rsource,{{"worker-biter",1},{"management-trainee",1}})
    f.changed=true
   end
  end
 end
 if t==30 or t==95 or t==120 then
  local expected=prototypes.entity["small-biter"].speed*(t==30 and 0.5 or t==95 and 1 or 1.5)
  for _,j in ipairs(jobs(f.s)) do check(math.abs(j.speed-expected)<1e-6,"live research speed wrong: "..serpent.line(j)) end
 end
 if t==80 then force.technologies["personnel-routing-speed-1"].researched=true end
 if t==110 then force.technologies["personnel-routing-speed-2"].researched=true end
 if t==130 then force.technologies["personnel-routing-speed-2"].researched=false end
 if t==300 then
  local c=values(f.reader)
  check(c["worker-biter"]==4 and c["management-trainee"]==1,"incoming lanes/qualities not summed: "..serpent.line(c).." jobs="..serpent.line(jobs(f.s)).." native="..serpent.line(f.csign.get_or_create_control_behavior().get_section(1).filters).." raw="..serpent.line(f.reader.get_signals(defines.wire_connector_id.circuit_red)))
  check(f.rotsign.rotate{by_player=game.players[1]},"multisign would not rotate while queued")
  check(f.rotsign.direction==defines.direction.east,"multisign rotation incorrect")
  set(f.rotsource,{{"enrolled-biter",1}})
 end
 if t==310 then
  local p=ports(f.rotsign)
  check(math.abs(p.left.position.x-48)<1/256 and p.left.position.y<0,"side port did not rotate")
 end
 if t==500 then
  check(f.changed,"entry-time filter change not exercised")
  check(count(f.left,"worker-biter")==1,"committed worker lost its original left exit: left="..count(f.left,"worker-biter").." right="..count(f.right,"worker-biter").." jobs="..serpent.line(jobs(f.s)))
  check(count(f.right,"worker-biter")==1 and count(f.right,"management-trainee")==1,"live filters did not route following types right")
  check(inv(f.left,true).get_item_count{name="worker-biter",quality="rare"}==1,"left worker quality lost")
  check(inv(f.right,true).get_item_count{name="worker-biter",quality="epic"}==1,"right worker quality lost")
  check(count(f.rotnorth,"enrolled-biter")==1 and count(f.rotwest,"enrolled-biter")==0,"rotation lost wiring or relative exit")
  inv(f.input).insert{name="chemical-operator",count=1}
 end
 if t==600 then
  f.coutput=build(f.s,"personnel-reception-office",28,40)
 end
 if t==750 then
  local found=false
  for _,j in ipairs(jobs(f.s)) do
   if j.item=="chemical-operator" then found=true;check(math.abs(j.position.x-9.5)<1/256 and j.state=="stopped","empty straight filter did not clog") end
  end
  check(found,"unmatched chemical operator disappeared")
  set(f.ssource,{{"chemical-operator",2,"rare"}})
  f.negative=source(f.s,16,-4);set(f.negative,{{"chemical-operator",-2,"epic"}});wire(f.negative,ports(f.sign).straight,"green")
 end
 if t==800 then
  for _,j in ipairs(jobs(f.s)) do if j.item=="chemical-operator" then check(math.abs(j.position.x-9.5)<1/256,"negative green signal did not cancel red") end end
  set(f.negative,{})
  game.server_save("personnel-circuits-mid-queue")
 end
 if t==1000 then
  check(count(f.straight,"chemical-operator")==1,"live signal did not release unmatched type")
  check(count(f.coutput,"worker-biter")==4 and count(f.coutput,"management-trainee")==1,"merged approaches failed to drain")
  local c=values(f.reader);check(not c["worker-biter"] and not c["management-trainee"],"counts retained departed personnel")
  f.left.destroy{raise_destroy=true}
  set(f.lsource,{{"licensed-notary",1}})
  inv(f.input).insert{name="licensed-notary",count=1}
 end
 if t==1200 then
  local found=false
  for _,j in ipairs(jobs(f.s)) do if j.item=="licensed-notary" then found=true;check(math.abs(j.position.x-9.5)<1/256,"unavailable allowed exit failed to clog") end end
  check(found,"missing-route personnel disappeared")
  f.left=build(f.s,"personnel-reception-office",12,-12)
 end
 if t==1400 then
  check(count(f.left,"licensed-notary")==1,"repaired filtered lane failed to resume")
  check(#jobs(f.s)==0,"jobs failed to drain")
  f.sign.destroy{raise_destroy=true}
  check(#f.s.find_entities_filtered{name={"personnel-routing-filter-port-left","personnel-routing-filter-port-straight","personnel-routing-filter-port-right"}}==3,"removed multisign left orphan ports")
  helpers.write_file("personnel-circuits.txt","PASS\n",false)
 end
end)
'''


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--factorio-bin', required=True)
    args = parser.parse_args()
    factorio = Path(args.factorio_bin)
    with tempfile.TemporaryDirectory(prefix='administratorio-personnel-circuits-') as temp:
        root = Path(temp)
        prepare_profile(root)
        (root/'saves').mkdir()
        (root/'mods'/SMOKE_MOD_NAME/'scenarios/runtime-smoke/control.lua').write_text(CONTROL)
        settings = json.loads((factorio.parent.parent/'data/server-settings.example.json').read_text())
        settings.update(auto_pause=False, visibility={'public': False, 'lan': False}, require_user_verification=False)
        (root/'server-settings.json').write_text(json.dumps(settings))
        command = [str(factorio), '--config', str(root/'config.ini'), '--mod-directory', str(root/'mods'),
                   '--disable-audio', '--server-settings', str(root/'server-settings.json'),
                   '--start-server-load-scenario', f'{SMOKE_MOD_NAME}/runtime-smoke', '--port', '34217', '--until-tick', '1420']
        log_path = root/'server.log'
        marker = root/'script-output/personnel-circuits.txt'
        with log_path.open('w') as stream:
            process = subprocess.Popen(command, cwd=REPO_ROOT, stdout=stream, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic()+60
                while not marker.exists() and process.poll() is None and time.monotonic()<deadline:
                    time.sleep(.05)
            finally:
                if process.poll() is None:
                    process.terminate() if marker.exists() else process.kill()
                process.wait(timeout=10)
        assert marker.exists(), log_path.read_text()[-6500:]
        assert marker.read_text() == 'PASS\n'
        marker.unlink()
        replay = subprocess.run([str(factorio), '--config', str(root/'config.ini'), '--mod-directory', str(root/'mods'),
            '--disable-audio', '--benchmark', str(root/'saves/personnel-circuits-mid-queue.zip'),
            '--benchmark-ticks', '620', '--benchmark-runs', '1'], cwd=REPO_ROOT, text=True, capture_output=True, timeout=45)
        assert marker.exists(), (replay.stdout+replay.stderr)[-6500:]
        assert marker.read_text() == 'PASS\n'
    print('Personnel live filters, rotated circuit ports, research speeds, incoming counts and saved queues passed')

if __name__ == '__main__':
    main()
