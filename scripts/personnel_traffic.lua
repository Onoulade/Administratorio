-- Transient spatial index: bounded local checks rather than all-pairs traffic.
local M = {GAP = 2.5, BIN = 4}
local function key(x,y) return x .. ':' .. y end
local function bucket(p) return math.floor(p.x/M.BIN),math.floor(p.y/M.BIN) end
function M.new(jobs)
  local index={buckets={},entries={}}
  for id,job in pairs(jobs) do
    if job.state~='recovery' and job.entity and job.entity.valid then
      M.move(index,job,job.position or job.entity.position)
    end
  end
  return index
end
function M.move(index,job,p)
  local old=index.entries[job.id]
  if old then index.buckets[old.key][job.id]=nil end
  local x,y=bucket(p)
  local k=job.surface_index .. '/' .. key(x,y)
  local entry={key=k,x=p.x,y=p.y,id=job.id}
  index.entries[job.id]=entry
  index.buckets[k]=index.buckets[k] or {}
  index.buckets[k][job.id]=entry
end
function M.remove(index,id)
  local old=index.entries[id]
  if old then index.buckets[old.key][id]=nil;index.entries[id]=nil end
end
local function neighbors(index,surface,p,visit)
  local x,y=bucket(p)
  for dx=-1,1 do for dy=-1,1 do
    for _,other in pairs(index.buckets[surface .. '/' .. key(x+dx,y+dy)] or {}) do visit(other) end
  end end
end
function M.free(index,surface,p)
  local free=true
  neighbors(index,surface,p,function(other)
    if math.abs(other.x-p.x)<M.GAP and math.abs(other.y-p.y)<M.GAP then free=false end
  end)
  return free
end
function M.limit(index,job,p,dx,dy,distance)
  neighbors(index,job.surface_index,p,function(other)
    if other.id~=job.id then
      local cross=dx~=0 and math.abs(other.y-p.y) or math.abs(other.x-p.x)
      local forward=(other.x-p.x)*dx+(other.y-p.y)*dy
      if cross<M.GAP and forward>=0 then distance=math.min(distance,math.max(0,forward-M.GAP)) end
    end
  end)
  return distance
end
return M
