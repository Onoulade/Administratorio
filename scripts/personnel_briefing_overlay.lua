-- A persistent, entity-attached badge and freshness bar, refreshed once a
-- second. Read the escrow stack: the walking proxy cannot own spoilage.
local M = {}
local materials = {}
for _, briefing in ipairs(require("prototypes.shared.manager_briefings").BRIEFINGS) do
  materials[briefing.item] = briefing.material
end
local fields = {"briefing_icon", "briefing_background", "briefing_bar"}
local function object(id)
  local render = id and rendering.get_object_by_id(id)
  return render and render.valid and render or nil
end
function M.clear(job)
  for _, field in ipairs(fields) do
    local render = object(job[field])
    if render then render.destroy() end
    job[field] = nil
  end
  job.briefing_item, job.briefing_refresh = nil, nil
end
function M.update(job, tick)
  local stack = job.cargo[1]
  local item = stack.valid_for_read and stack.name
  if not materials[item] then
    if job.briefing_item then M.clear(job) end
    return
  end
  if item == job.briefing_item and tick < (job.briefing_refresh or 0) then return end
  local unit = job.entity
  local function target(x, y) return {entity = unit, offset = {x, y}} end
  if item ~= job.briefing_item or not object(job.briefing_icon)
      or not object(job.briefing_background) or not object(job.briefing_bar) then
    M.clear(job)
    job.briefing_icon = rendering.draw_sprite{
      sprite = "item/" .. materials[item], surface = unit.surface,
      target = target(0, -1.35), x_scale = 0.30, y_scale = 0.30,
      render_layer = "air-object",
    }.id
    job.briefing_background = rendering.draw_line{
      surface = unit.surface, from = target(-0.30, -0.98), to = target(0.30, -0.98),
      width = 4, color = {r = 0.12, g = 0.12, b = 0.12, a = 0.9},
    }.id
    job.briefing_bar = rendering.draw_line{
      surface = unit.surface, from = target(-0.30, -0.98), to = target(0.30, -0.98),
      width = 2, color = {r = 0.25, g = 0.85, b = 0.35},
    }.id
    job.briefing_item = item
  end
  local remaining = math.max(0, math.min(1, 1 - stack.spoil_percent))
  local bar = object(job.briefing_bar)
  bar.to = target(-0.30 + 0.60 * remaining, -0.98)
  bar.color = remaining > 0.5 and {r = 0.25, g = 0.85, b = 0.35}
    or remaining > 0.2 and {r = 0.95, g = 0.70, b = 0.20}
    or {r = 0.95, g = 0.25, b = 0.20}
  job.briefing_refresh = tick + 60
end
function M.inspect(job)
  if not job.briefing_item then return nil end
  local bar = object(job.briefing_bar)
  return {item = job.briefing_item, icon = job.briefing_icon, bar = job.briefing_bar,
    valid = object(job.briefing_icon) ~= nil and object(job.briefing_background) ~= nil and bar ~= nil,
    remaining = job.cargo[1].valid_for_read and 1 - job.cargo[1].spoil_percent}
end
return M
