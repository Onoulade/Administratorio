-- Configuration source selection, live signals, GUI lifecycle and concurrent editing.
defines={direction={north=0,east=4,south=8,west=12},wire_connector_id={circuit_red=1,circuit_green=2}}
local R=require('prototypes.shared.personnel_routing')
local signals=require('scripts.personnel_signals')
local gui=require('scripts.personnel_multisign_gui')
local force={}
local record={entity={valid=true,name=R.MULTISIGN,unit_number=1,force=force},ports={}}
local circuit={
 {signal={type='item',name='worker-biter',quality='rare'},count=2},
 {signal={type='item',name='worker-biter',quality='normal'},count=-1},
 {signal={type='item',name='management-trainee'},count=-1},
 {signal={type='item',name='iron-plate'},count=10},
}
for _,exit in ipairs(R.exits) do record.ports[exit]={valid=true,get_signals=function() return circuit end} end
assert(signals.read_filters(record))
assert(signals.mode(record,'left')=='circuit' and record.filters.left['worker-biter'])
assert(not record.filters.left['management-trainee'] and not record.filters.left['iron-plate'])
local function element(args,parent)
 local e={valid=true,type=args.type,name=args.name,tags=args.tags or {},style={},parent=parent,children={}}
 for k,v in pairs(args) do if k~='style' then e[k]=v end end
 e.add=function(a)
  local child=element(a,e);e.children[#e.children+1]=child
  if child.name then e[child.name]=child end
  return child
 end
 e.destroy=function()
  e.valid=false
  if parent and e.name then parent[e.name]=nil end
  for _,child in ipairs(e.children) do child.destroy() end
 end
 return e
end
local function player() return {force=force,gui={screen=element({type='flow'})}} end
local p1,p2=player(),player()
game={players={p1,p2},get_player=function(i) return game.players[i] end}
prototypes={item={}}
for name in pairs(R.cargo) do prototypes.item[name]={} end
local records={[1]=record}
local revisions=0
local function changed(r) if signals.read_filters(r) then revisions=revisions+1 end end
local function change(p,index,e,value)
 if e.type=='switch' then e.switch_state=value else e.elem_value=value end
 gui.on_changed({player_index=index,element=e},records,changed)
end
gui.open(p1,record);gui.open(p2,record)
local f1=p1.opened;local f2=p2.opened
assert(f1 and f1==p1.gui.screen['administratorio-personnel-multisign'])
for _,exit in ipairs(R.exits) do
 assert(#f1.body[exit].slots.children==5)
 assert(not f1.body[exit].slots.slot1.enabled)
end
change(p1,1,f1.body.left.heading.mode,'left')
assert(not next(record.filters.left),'empty manual mode must close exit despite positive wires')
assert(record.filters.right['worker-biter'],'changing left source changed right circuit filters')
assert(f2.body.left.heading.mode.switch_state=='left' and f2.body.left.slots.slot1.enabled)
change(p1,1,f1.body.left.slots.slot5,'management-trainee')
assert(record.filters.left['management-trainee'] and not record.filters.left['worker-biter'])
assert(f2.body.left.slots.slot5.elem_value=='management-trainee')
change(p1,1,f1.body.left.slots.slot1,'iron-plate')
assert(f1.body.left.slots.slot1.elem_value==nil and not record.filters.left['iron-plate'])
change(p1,1,f1.body.left.heading.mode,'right')
assert(record.filters.left['worker-biter'] and not record.filters.left['management-trainee'])
assert(record.manual_filters.left[5]=='management-trainee' and not f2.body.left.slots.slot5.enabled)
change(p1,1,f1.body.left.slots.slot5,'worker-biter')
assert(record.manual_filters.left[5]=='management-trainee','disabled manual filter event overwrote saved slots')
change(p2,2,f2.body.left.heading.mode,'left')
assert(record.filters.left['management-trainee'])
change(p2,2,f2.body.left.slots.slot5,nil)
assert(not next(record.filters.left),'clearing last filter did not close exit')
local copied={}
record.manual_filters.left[5]='worker-biter'
signals.configure(copied,record)
copied.manual_filters.left[5]='management-trainee'
assert(record.manual_filters.left[5]=='worker-biter','configuration copy aliases original slots')
signals.configure(copied,{manual_filters={left={['5']='worker-biter',['6']='management-trainee'}},filter_modes={left='manual'}})
assert(copied.manual_filters.left[5]=='worker-biter' and not copied.manual_filters.left[6])
gui.on_closed{player_index=1,element=f1}
assert(not f1.valid and not p1.opened and f2.valid)
record.entity.valid=false
gui.refresh_all(records)
assert(not f2.valid and not p2.opened)
assert(revisions>=5)
print('Multisign GUI: manual/circuit switching, five slots, type validation, concurrent editing, independent copies and cleanup passed')
