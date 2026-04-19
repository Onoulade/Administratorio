local C = require("scripts.constants")

local M = {}

local PETITION_COUNTER_NAME = "petition-counter"
local DISABLED_TEXT_COLOR = {r = 1, g = 0.35, b = 0.35}

local function ensure_storage()
  storage.petition_counters = storage.petition_counters or {}
end

local function is_petition_counter(entity_or_name)
  if type(entity_or_name) == "string" then
    return entity_or_name == PETITION_COUNTER_NAME
  end
  return entity_or_name and entity_or_name.valid and entity_or_name.name == PETITION_COUNTER_NAME
end

local function destroy_overlay(entry)
  if not entry or not entry.overlay_id then return end
  if rendering.is_valid(entry.overlay_id) then
    rendering.destroy(entry.overlay_id)
  end
  entry.overlay_id = nil
end

local function set_disabled_overlay(entry, disabled)
  if not entry or not entry.entity or not entry.entity.valid then return end
  if not disabled then
    destroy_overlay(entry)
    return
  end

  if entry.overlay_id and rendering.is_valid(entry.overlay_id) then
    return
  end

  entry.overlay_id = rendering.draw_text({
    text = C.PETITION_COUNTER_DISABLED_TEXT,
    surface = entry.entity.surface,
    target = entry.entity,
    target_offset = {0, -1.8},
    color = DISABLED_TEXT_COLOR,
    alignment = "center",
    scale = 1.0,
  })
end

local function evaluate_counter(entry)
  local entity = entry and entry.entity
  if not entity or not entity.valid then
    destroy_overlay(entry)
    return false
  end

  local nearby_nests = entity.surface.count_entities_filtered({
    position = entity.position,
    radius = C.PETITION_COUNTER_NEST_RADIUS,
    type = "unit-spawner",
  })
  local has_nests = nearby_nests > 0

  if entity.active ~= has_nests then
    entity.active = has_nests
  end

  entry.nearby_nests = nearby_nests
  set_disabled_overlay(entry, not has_nests)
  return true
end

local function apply_nest_density_bonus(entry)
  if not entry or not entry.entity or not entry.entity.valid then return end
  local entity = entry.entity
  if not entity.active then return end
  if not entity.is_crafting() then return end

  local extra_nests = math.max(0, (entry.nearby_nests or 0) - 1)
  if extra_nests == 0 then return end

  local bonus = math.min(
    C.PETITION_COUNTER_MAX_BONUS_PROGRESS_PER_SCAN,
    extra_nests * C.PETITION_COUNTER_BONUS_PER_EXTRA_NEST
  )
  if bonus <= 0 then return end

  local ok, current = pcall(function()
    return entity.crafting_progress
  end)
  if not ok or type(current) ~= "number" then return end

  pcall(function()
    entity.crafting_progress = math.min(1, current + bonus)
  end)
end

function M.ensure_storage()
  ensure_storage()
end

function M.rebuild_registry()
  ensure_storage()

  for _, entry in pairs(storage.petition_counters) do
    destroy_overlay(entry)
  end
  storage.petition_counters = {}

  for _, surface in pairs(game.surfaces) do
    for _, entity in ipairs(surface.find_entities_filtered({name = PETITION_COUNTER_NAME})) do
      if entity.valid and entity.unit_number then
        storage.petition_counters[entity.unit_number] = {entity = entity}
      end
    end
  end
end

function M.on_entity_built(entity)
  if not is_petition_counter(entity) or not entity.unit_number then return end
  ensure_storage()
  storage.petition_counters[entity.unit_number] = {entity = entity}
  evaluate_counter(storage.petition_counters[entity.unit_number])
end

function M.on_entity_removed(entity)
  if not is_petition_counter(entity) then return end
  ensure_storage()
  local entry = storage.petition_counters[entity.unit_number]
  if entry then
    destroy_overlay(entry)
    storage.petition_counters[entity.unit_number] = nil
  end
end

function M.on_tick(tick)
  ensure_storage()
  if tick % C.PETITION_COUNTER_SCAN_INTERVAL_TICKS ~= 0 then return end

  for unit_number, entry in pairs(storage.petition_counters) do
    if not evaluate_counter(entry) then
      storage.petition_counters[unit_number] = nil
    else
      apply_nest_density_bonus(entry)
    end
  end
end

return M
