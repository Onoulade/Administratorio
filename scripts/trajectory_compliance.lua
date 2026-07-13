local M = {}

local ARRAY_NAME = "trajectory-compliance-array"
local ARRAY_TIERS = {
  ["trajectory-compliance-array"] = 2,
  ["senior-trajectory-compliance-array"] = 3,
  ["executive-trajectory-compliance-array"] = 4,
}
local ASTEROID_SIZE_RANKS = {
  small = 1,
  medium = 2,
  big = 3,
  huge = 4,
}
local ASTEROID_SIZES = {"small", "medium", "big", "huge"}
local ASTEROID_FAMILIES = {"metallic", "carbonic", "oxide", "promethium"}
local ASTEROID_CHUNK_YIELDS = {
  small = 2,
  medium = 6,
  big = 18,
  huge = 54,
}
local ASTEROID_SALVAGE_RADII = {
  small = 0.35,
  medium = 0.75,
  big = 1.25,
  huge = 2.0,
}
local MANAGEMENT_ITEM = "middle-management-managing-manager"
local BURNED_OUT_ITEM = "burned-out-manager"
local EFFECT_ID = "administratorio-trajectory-deviation"
local RETRY_INTERVAL = 60

local OUTCOME_INTACT = "intact"
local OUTCOME_BURNED_OUT = "burned-out"
local OUTCOME_LOST = "lost"

M.ARRAY_NAME = ARRAY_NAME
M.ARRAY_TIERS = ARRAY_TIERS
M.ASTEROID_SIZE_RANKS = ASTEROID_SIZE_RANKS
M.ASTEROID_CHUNK_YIELDS = ASTEROID_CHUNK_YIELDS
M.MANAGEMENT_ITEM = MANAGEMENT_ITEM
M.BURNED_OUT_ITEM = BURNED_OUT_ITEM
M.EFFECT_ID = EFFECT_ID
M.RETRY_INTERVAL = RETRY_INTERVAL
M.OUTCOME_INTACT = OUTCOME_INTACT
M.OUTCOME_BURNED_OUT = OUTCOME_BURNED_OUT
M.OUTCOME_LOST = OUTCOME_LOST

local function ensure_storage()
  storage.trajectory_compliance = storage.trajectory_compliance or {}
  local state = storage.trajectory_compliance
  state.pending_outputs = state.pending_outputs or {}

  -- These belonged to the pre-0.5.6 chunk scanner and can contain LuaEntity
  -- references that no longer serve any purpose.
  state.arrays = nil
  state.notified_forces = nil
end

local function quality_name(quality)
  if type(quality) == "string" then
    return quality
  end
  if quality and quality.name then
    return quality.name
  end
  return nil
end

local function loaded_ammo_quality(source)
  if not source or not source.valid or not source.get_inventory then
    return "normal"
  end

  local inventory = source.get_inventory(defines.inventory.turret_ammo)
  if not inventory or not inventory.valid then
    return "normal"
  end

  for index = 1, #inventory do
    local stack = inventory[index]
    if stack and stack.valid_for_read and stack.name == MANAGEMENT_ITEM then
      return quality_name(stack.quality) or "normal"
    end
  end

  return "normal"
end

local function event_ammo_quality(event, source)
  -- Factorio currently exposes the source entity but not the ammunition stack
  -- on this event. The native turret still has its firing stack while the
  -- instant action is being resolved, so read its quality there. The optional
  -- event fields keep this forward-compatible if the API adds them later.
  return quality_name(event.source_quality)
    or quality_name(event.quality)
    or loaded_ammo_quality(source)
end

local function stack_spec(name, quality)
  return {
    name = name,
    count = 1,
    quality = quality or "normal",
  }
end

local function asteroid_identity(name)
  if type(name) ~= "string" then return nil end
  local size, family = name:match("^(%a+)%-(.+)%-asteroid$")
  local rank = size and ASTEROID_SIZE_RANKS[size]
  if not rank or not family then return nil end
  return size, family, rank
end

local function salvage_chunks(size, family, target_position, source_position)
  local count = ASTEROID_CHUNK_YIELDS[size]
  local radius = ASTEROID_SALVAGE_RADII[size]
  if not count or not radius then return nil end

  local chunks = {}
  local golden_angle = math.pi * (3 - math.sqrt(5))
  for index = 1, count do
    local angle = (index - 1) * golden_angle
    local distance = radius * math.sqrt((index - 0.5) / count)
    local position = {
      x = target_position.x + math.cos(angle) * distance,
      y = target_position.y + math.sin(angle) * distance,
    }
    local toward_x = source_position.x - position.x
    local toward_y = source_position.y - position.y
    local length = math.sqrt(toward_x * toward_x + toward_y * toward_y)
    if length < 0.001 then
      toward_x, toward_y, length = 1, 0, 1
    end
    chunks[index] = {
      name = family .. "-asteroid-chunk",
      position = position,
      movement = {
        x = toward_x / length * 0.005,
        y = toward_y / length * 0.005,
      },
    }
  end
  return chunks
end

local function platform_for_source(source)
  if not source or not source.valid then return nil end
  local surface = source.surface
  if not surface or not surface.valid then return nil end
  local platform = surface.platform
  if platform and platform.valid then
    return platform
  end
  return nil
end

local function platform_by_index(platform_index)
  if not platform_index or not game or not game.forces then return nil end
  for _, force in pairs(game.forces) do
    if force and force.valid and force.platforms then
      for _, platform in pairs(force.platforms) do
        if platform and platform.valid and platform.index == platform_index then
          return platform
        end
      end
    end
  end
  return nil
end

local function insert_into_hub(platform, item)
  if not platform or not platform.valid then return false end
  local hub = platform.hub
  if not hub or not hub.valid or not hub.insert then return false end
  return hub.insert(item) == item.count
end

local function mark_output_blocked(source)
  if not source or not source.valid then return end
  source.disabled_by_script = true
  source.custom_status = {
    diode = defines.entity_status_diode.yellow,
    label = {"gui.trajectory-compliance-output-blocked"},
  }
end

local function clear_output_blocked(source)
  if not source or not source.valid then return end
  source.disabled_by_script = false
  source.custom_status = nil
end

local function queue_output(source, platform, item)
  if not source or not source.valid or not source.unit_number then
    return false
  end

  ensure_storage()
  storage.trajectory_compliance.pending_outputs[source.unit_number] = {
    source = source,
    platform_index = platform and platform.valid and platform.index or nil,
    item = item,
  }
  mark_output_blocked(source)
  return true
end

local function deliver_or_queue(source, platform, item)
  if insert_into_hub(platform, item) then
    clear_output_blocked(source)
    return true
  end
  queue_output(source, platform, item)
  return false
end

function M.classify_outcome(roll)
  if roll < 0.90 then
    return OUTCOME_INTACT
  elseif roll < 0.95 then
    return OUTCOME_BURNED_OUT
  end
  return OUTCOME_LOST
end

function M.ensure_storage()
  ensure_storage()
end

local function asteroid_prototype_exists(name)
  return not prototypes or not prototypes.entity or prototypes.entity[name] ~= nil
end

function M.configure_array(entity)
  local maximum_size_rank = entity and entity.valid and ARRAY_TIERS[entity.name]
  if not maximum_size_rank or not entity.set_priority_target then return false end

  local previous_count = entity.priority_targets and #entity.priority_targets or 0
  local priority_index = 1
  for size_rank, size in ipairs(ASTEROID_SIZES) do
    if size_rank <= maximum_size_rank then
      for _, family in ipairs(ASTEROID_FAMILIES) do
        local asteroid_name = size .. "-" .. family .. "-asteroid"
        if asteroid_prototype_exists(asteroid_name) then
          entity.set_priority_target(priority_index, asteroid_name)
          priority_index = priority_index + 1
        end
      end
    end
  end
  for index = priority_index, previous_count do
    entity.set_priority_target(index, nil)
  end
  entity.ignore_unprioritised_targets = true
  return true
end

function M.configure_existing_arrays()
  if not game or not game.surfaces then return end
  local names = {}
  for name in pairs(ARRAY_TIERS) do names[#names + 1] = name end
  for _, surface in pairs(game.surfaces) do
    for _, entity in ipairs(surface.find_entities_filtered{name = names}) do
      M.configure_array(entity)
    end
  end
end

function M.on_script_trigger_effect(event, forced_roll)
  if not event or event.effect_id ~= EFFECT_ID then
    return false
  end

  local source = event.source_entity
  local target = event.target_entity
    or (source and source.valid and source.shooting_target)
  local maximum_size_rank = source and source.valid and ARRAY_TIERS[source.name]
  if not maximum_size_rank then
    return false
  end
  if not target or not target.valid or target.type ~= "asteroid" then
    return false
  end

  local target_size, target_family, target_size_rank = asteroid_identity(target.name)
  if not target_size_rank or target_size_rank > maximum_size_rank then
    return false
  end

  local quality = event_ammo_quality(event, source)
  local outcome = M.classify_outcome(forced_roll or math.random())
  local platform = platform_for_source(source)

  if not platform or not platform.create_asteroid_chunks then
    return false
  end

  local chunks = salvage_chunks(target_size, target_family, target.position, source.position)
  if not chunks or not target.destroy() then return false end

  -- The vanilla death cascade creates the same 2/6/18/54 theoretical yield,
  -- but intermediate asteroids can drift away or collide before becoming
  -- collectible. Corporate deviation is tidier: the complete yield is issued
  -- immediately as approved salvage parcels moving gently toward the array.
  platform.create_asteroid_chunks(chunks)

  if outcome == OUTCOME_INTACT then
    deliver_or_queue(source, platform, stack_spec(MANAGEMENT_ITEM, quality))
  elseif outcome == OUTCOME_BURNED_OUT then
    deliver_or_queue(source, platform, stack_spec(BURNED_OUT_ITEM, quality))
  end

  return true, outcome
end

function M.on_tick(event)
  if not event or not event.tick or event.tick % RETRY_INTERVAL ~= 0 then
    return
  end

  ensure_storage()
  for unit_number, pending in pairs(storage.trajectory_compliance.pending_outputs) do
    local source = pending.source
    local platform = platform_for_source(source)
      or platform_by_index(pending.platform_index)

    if insert_into_hub(platform, pending.item) then
      clear_output_blocked(source)
      storage.trajectory_compliance.pending_outputs[unit_number] = nil
    elseif source and source.valid then
      mark_output_blocked(source)
    elseif not platform then
      -- The platform and the array are both gone, so there is nowhere left to
      -- deliver the deferred manager. Discard the orphaned queue record.
      storage.trajectory_compliance.pending_outputs[unit_number] = nil
    end
  end
end

return M
