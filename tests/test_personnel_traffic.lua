local T=require('scripts.personnel_traffic')
local function job(id,x,y,surface) return {id=id,surface_index=surface or 1,state='walking',position={x=x,y=y},entity={valid=true}} end
local a,b=job(1,-1,0),job(2,1.6,0)
local index=T.new({a,b})
assert(math.abs(T.limit(index,a,a.position,1,0,.2)-.1)<1e-8)
assert(not T.free(index,1,{x=0,y=0}))
assert(T.free(index,2,{x=0,y=0}))
T.move(index,b,{x=10,y=0})
assert(T.limit(index,a,a.position,1,0,.2)==.2)
T.remove(index,b.id)
assert(T.free(index,1,{x=10,y=0}))
math.randomseed(240928)
for iteration=1,200 do
 local jobs={}
 for id=1,40 do jobs[id]=job(id,math.random()*24-12,math.random()*24-12,math.random(1,2)) end
 local subject=jobs[1]
 local index=T.new(jobs)
 for _,direction in ipairs({{1,0},{0,1},{-1,0},{0,-1}}) do
  local dx,dy=direction[1],direction[2]
  local expected=.2
  for id,other in ipairs(jobs) do
   if id~=subject.id and subject.surface_index==other.surface_index then
    local p,q=subject.position,other.position
    local cross=dx~=0 and math.abs(q.y-p.y) or math.abs(q.x-p.x)
    local forward=(q.x-p.x)*dx+(q.y-p.y)*dy
    if cross<T.GAP and forward>=0 then expected=math.min(expected,math.max(0,forward-T.GAP)) end
   end
  end
  assert(math.abs(T.limit(index,subject,subject.position,dx,dy,.2)-expected)<1e-8,'spatial index missed a neighboring body')
 end
end
print('Personnel traffic: negative coordinates, surfaces, moving buckets and 800 exhaustive neighbor comparisons passed')
