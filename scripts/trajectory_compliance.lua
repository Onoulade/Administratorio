local M = {}

local ARRAY_NAME = "trajectory-compliance-array"
local CANNON_NAME = "orbital-employment-cannon"
local ARRAY_TIERS = {
  ["trajectory-compliance-array"] = 2,
  ["senior-trajectory-compliance-array"] = 3,
  ["executive-trajectory-compliance-array"] = 4,
}
local TARGET_TIERS = {
  ["trajectory-compliance-array"] = 2,
  ["senior-trajectory-compliance-array"] = 3,
  ["executive-trajectory-compliance-array"] = 4,
  [CANNON_NAME] = 4,
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
local ASTEROID_BASE_HEALTH = {
  small = 100,
  medium = 400,
  big = 2000,
  huge = 5000,
}
local ASTEROID_SALVAGE_RADII = {
  small = 0.35,
  medium = 0.75,
  big = 1.25,
  huge = 2.0,
}
local DEVIATION_AMMO = "orbital-deviation-order"
local MANAGEMENT_ITEM = "middle-management-managing-manager"
local RETURNING_CHUNK = "returning-orbital-employee"
local DEVIATION_EFFECT_ID = "administratorio-trajectory-deviation"
local BITER_ASSAULT_EFFECT_ID = "administratorio-asteroid-biter-assault"
local BITER_AMMO_CATEGORY = "orbital-biter-ballistics"
local CAPACITY_TECH_PREFIX = "orbital-employment-capacity-"
local CAPACITY_TECH_LEVELS = 4
local BASE_EMPLOYEE_CAPACITY = 1
local CANNON_RANGE = 48
local BASE_BITER_DAMAGE = 125
local ASSAULT_INTERVAL = 60

local OUTCOME_ATTACHED = "attached"
local OUTCOME_DEVIATED = "deviated"
local OUTCOME_AT_CAPACITY = "at-capacity"

M.ARRAY_NAME = ARRAY_NAME
M.CANNON_NAME = CANNON_NAME
M.ARRAY_TIERS = ARRAY_TIERS
M.TARGET_TIERS = TARGET_TIERS
M.ASTEROID_SIZE_RANKS = ASTEROID_SIZE_RANKS
M.ASTEROID_CHUNK_YIELDS = ASTEROID_CHUNK_YIELDS
M.DEVIATION_AMMO = DEVIATION_AMMO
M.MANAGEMENT_ITEM = MANAGEMENT_ITEM
M.RETURNING_CHUNK = RETURNING_CHUNK
M.DEVIATION_EFFECT_ID = DEVIATION_EFFECT_ID
M.BITER_ASSAULT_EFFECT_ID = BITER_ASSAULT_EFFECT_ID
M.EFFECT_ID = DEVIATION_EFFECT_ID -- Compatibility for older integrations.
M.BITER_AMMO_CATEGORY = BITER_AMMO_CATEGORY
M.CAPACITY_TECH_PREFIX = CAPACITY_TECH_PREFIX
M.CAPACITY_TECH_LEVELS = CAPACITY_TECH_LEVELS
M.BASE_EMPLOYEE_CAPACITY = BASE_EMPLOYEE_CAPACITY
M.CANNON_RANGE = CANNON_RANGE
M.BASE_BITER_DAMAGE = BASE_BITER_DAMAGE
M.ASSAULT_INTERVAL = ASSAULT_INTERVAL
M.RETRY_INTERVAL = ASSAULT_INTERVAL -- Compatibility for older integrations.
M.OUTCOME_ATTACHED = OUTCOME_ATTACHED
M.OUTCOME_DEVIATED = OUTCOME_DEVIATED
M.OUTCOME_AT_CAPACITY = OUTCOME_AT_CAPACITY

local function ensure_storage()
  storage.trajectory_compliance = storage.trajectory_compliance or {}
  local state = storage.trajectory_compliance
  state.assaults = state.assaults or {}
  state.next_assault_id = state.next_assault_id or 1
  state.blocked_cannons = state.blocked_cannons or {}

  -- These belonged to older scanners and random-return queues. New workers
  -- return exclusively as collectible asteroid chunks.
  state.arrays = nil
  state.notified_forces = nil
  state.pending_outputs = nil
end

local function asteroid_identity(name)
  if type(name) ~= "string" then return nil end
  local size, family = name:match("^(%a+)%-(.+)%-asteroid$")
  local rank = size and ASTEROID_SIZE_RANKS[size]
  if not rank or not family then return nil end
  return size, family, rank
end

local function fallback_asteroid_health(size, family)
  local health = ASTEROID_BASE_HEALTH[size]
  if not health then return nil end
  if family == "promethium" then
    health = health * 2
  end
  return health
end

local function chunk_movement(position, destination)
  local toward_x = destination.x - position.x
  local toward_y = destination.y - position.y
  local length = math.sqrt(toward_x * toward_x + toward_y * toward_y)
  if length < 0.001 then
    toward_x, toward_y, length = 1, 0, 1
  end
  return {
    x = toward_x / length * 0.005,
    y = toward_y / length * 0.005,
  }
end

local function salvage_chunks(size, family, target_position, destination)
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
    chunks[index] = {
      name = family .. "-asteroid-chunk",
      position = position,
      movement = chunk_movement(position, destination),
    }
  end
  return chunks
end

local function append_employee_chunks(chunks, workers, target_position, destination)
  local count = #workers
  if count == 0 then return end

  local golden_angle = math.pi * (3 - math.sqrt(5))
  for index, worker in ipairs(workers) do
    local angle = (index - 1) * golden_angle
    local distance = 0.45 + 0.12 * math.sqrt(index)
    local position = {
      x = target_position.x + math.cos(angle) * distance,
      y = target_position.y + math.sin(angle) * distance,
    }
    chunks[#chunks + 1] = {
      name = RETURNING_CHUNK,
      position = position,
      movement = chunk_movement(position, destination),
    }
  end
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

local function force_by_name(force_name)
  if not force_name or not game or not game.forces then return nil end
  local force = game.forces[force_name]
  return force and force.valid and force or nil
end

local function destination_for(platform, fallback)
  local hub = platform and platform.valid and platform.hub
  if hub and hub.valid then
    return {x = hub.position.x, y = hub.position.y}
  end
  return {x = fallback.x, y = fallback.y}
end

local function destroy_worker_visual(worker)
  local visual = worker and worker.visual
  if visual and visual.valid and visual.destroy then
    visual.destroy()
  end
  if worker then worker.visual = nil end
end

local function destroy_worker_visuals(workers)
  for _, worker in ipairs(workers or {}) do
    destroy_worker_visual(worker)
  end
end

local function attach_worker_visual(target, index)
  if not rendering or not rendering.draw_sprite then return nil end
  local angle = (index - 1) * math.pi * (3 - math.sqrt(5))
  local radius = 0.3 + 0.09 * math.sqrt(index)
  return rendering.draw_sprite{
    sprite = "item/" .. MANAGEMENT_ITEM,
    target = {
      entity = target,
      offset = {math.cos(angle) * radius, math.sin(angle) * radius},
    },
    surface = target.surface,
    x_scale = 0.30,
    y_scale = 0.30,
    render_layer = "object",
  }
end

function M.biter_damage(force)
  -- Manager item/entity quality is intentionally absent. MMMMs must perform
  -- identically at every quality because their collectible return chunk mines
  -- back into normal-quality ammunition. Only explicit research may scale them.
  local modifier = 0
  if force and force.get_ammo_damage_modifier then
    modifier = force.get_ammo_damage_modifier(BITER_AMMO_CATEGORY) or 0
  end
  return BASE_BITER_DAMAGE * math.max(0, 1 + modifier)
end

function M.employee_capacity(force)
  local capacity = BASE_EMPLOYEE_CAPACITY
  local technologies = force and force.technologies
  if not technologies then return capacity end

  for level = 1, CAPACITY_TECH_LEVELS do
    local technology = technologies[CAPACITY_TECH_PREFIX .. level]
    if technology and technology.researched then
      capacity = BASE_EMPLOYEE_CAPACITY + level
    end
  end
  return capacity
end

function M.ensure_storage()
  ensure_storage()
end

local function asteroid_prototype_exists(name)
  return not prototypes or not prototypes.entity or prototypes.entity[name] ~= nil
end

function M.configure_array(entity)
  local maximum_size_rank = entity and entity.valid and TARGET_TIERS[entity.name]
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
  for name in pairs(TARGET_TIERS) do names[#names + 1] = name end
  for _, surface in pairs(game.surfaces) do
    for _, entity in ipairs(surface.find_entities_filtered{name = names}) do
      M.configure_array(entity)
    end
  end
end

local function source_from_event(event)
  for _, source in pairs({event.source_entity, event.cause_entity}) do
    if source and source.valid and TARGET_TIERS[source.name] then
      return source
    end
  end
  return nil
end

local function target_from_event(event, source)
  return event.target_entity
    or (source and source.valid and source.shooting_target)
end

local function valid_asteroid_target(source, target)
  local maximum_size_rank = source and source.valid and TARGET_TIERS[source.name]
  if not maximum_size_rank then return nil end
  if not target or not target.valid or target.type ~= "asteroid" then return nil end

  local size, family, rank = asteroid_identity(target.name)
  if not rank or rank > maximum_size_rank then return nil end
  return size, family, rank
end

local function find_assault_for_target(target)
  ensure_storage()
  for assault_id, assault in pairs(storage.trajectory_compliance.assaults) do
    if assault.target == target then
      return assault, assault_id
    end
  end
  return nil
end

local function available_target_for(source, excluded_target)
  if not source or not source.valid then return nil end
  local surface = source.surface
  if not surface or not surface.valid or not surface.find_entities_filtered then return nil end

  local best_target
  local best_distance
  local capacity = M.employee_capacity(source.force)
  for _, candidate in ipairs(surface.find_entities_filtered{
    type = "asteroid",
    position = source.position,
    radius = CANNON_RANGE,
  }) do
    if candidate ~= excluded_target and valid_asteroid_target(source, candidate) then
      local assault = find_assault_for_target(candidate)
      if not assault or #assault.workers < capacity then
        local dx = candidate.position.x - source.position.x
        local dy = candidate.position.y - source.position.y
        local distance = dx * dx + dy * dy
        if not best_distance or distance < best_distance then
          best_target = candidate
          best_distance = distance
        end
      end
    end
  end
  return best_target
end

local function reroute_or_pause_cannon(source, excluded_target)
  if not source or not source.valid or source.name ~= CANNON_NAME then return false end
  ensure_storage()
  local state = storage.trajectory_compliance
  local unit_number = source.unit_number
  local target = available_target_for(source, excluded_target)

  if target then
    source.shooting_target = target
    source.disabled_by_script = false
    if unit_number then state.blocked_cannons[unit_number] = nil end
    return true
  end

  source.disabled_by_script = true
  if unit_number then state.blocked_cannons[unit_number] = source end
  return false
end

local function refresh_blocked_cannons()
  ensure_storage()
  local blocked = storage.trajectory_compliance.blocked_cannons
  for unit_number, cannon in pairs(blocked) do
    if not cannon or not cannon.valid then
      blocked[unit_number] = nil
    else
      reroute_or_pause_cannon(cannon)
    end
  end
end

local function remove_assault(assault_id, assault)
  destroy_worker_visuals(assault and assault.workers)
  storage.trajectory_compliance.assaults[assault_id] = nil
end

local function resolve_deviation(event)
  local source = source_from_event(event)
  if not source or not ARRAY_TIERS[source.name] then return false end
  local target = target_from_event(event, source)
  if not valid_asteroid_target(source, target) then return false end

  -- A deviation wins any race with attached workers. They leave with the rock
  -- and are therefore unrecoverable, which is deterministic and rather HR.
  local assault, assault_id = find_assault_for_target(target)
  if assault then remove_assault(assault_id, assault) end

  -- Runtime has no writable asteroid velocity. Removing the entity represents
  -- redirecting it out of the threat corridor and intentionally yields nothing.
  if not target.destroy() then return false end
  return true, OUTCOME_DEVIATED
end

local function resolve_biter_assault(event)
  local source = source_from_event(event)
  if not source or source.name ~= CANNON_NAME then return false end
  local target = target_from_event(event, source)
  local target_size, target_family = valid_asteroid_target(source, target)
  if not target_size then return false end

  local platform = platform_for_source(source)
  if not platform or not platform.create_asteroid_chunks then return false end

  local assault = find_assault_for_target(target)
  local capacity = M.employee_capacity(source.force)
  if assault and #assault.workers >= capacity then
    -- Another cannon may already have had a projectile in flight when this
    -- asteroid filled its staffing allocation. The rejected employee becomes
    -- a normal collectible return chunk instead of being silently consumed.
    local chunks = {}
    append_employee_chunks(
      chunks,
      {true},
      target.position,
      destination_for(platform, source.position)
    )
    platform.create_asteroid_chunks(chunks)
    reroute_or_pause_cannon(source, target)
    return true, OUTCOME_AT_CAPACITY, 0, false
  end

  if not assault then
    local state = storage.trajectory_compliance
    local assault_id = state.next_assault_id
    state.next_assault_id = assault_id + 1
    assault = {
      target = target,
      size = target_size,
      family = target_family,
      platform_index = platform.index,
      force_name = source.force and source.force.name or nil,
      source_position = {x = source.position.x, y = source.position.y},
      workers = {},
    }
    state.assaults[assault_id] = assault
  end

  local worker = {attached_tick = event.tick or (game and game.tick) or 0}
  assault.workers[#assault.workers + 1] = worker
  worker.visual = attach_worker_visual(target, #assault.workers)

  if #assault.workers >= capacity then
    reroute_or_pause_cannon(source, target)
  end

  -- Impact only attaches the worker. Damage begins on the next one-second work
  -- cycle and stacks linearly when the cannon assigns colleagues to the rock.
  return true, OUTCOME_ATTACHED, M.biter_damage(source.force), false
end

function M.on_script_trigger_effect(event)
  if not event then return false end
  if event.effect_id == DEVIATION_EFFECT_ID then
    return resolve_deviation(event)
  elseif event.effect_id == BITER_ASSAULT_EFFECT_ID then
    return resolve_biter_assault(event)
  end
  return false
end

local function release_employee_chunks(assault, position)
  local platform = platform_by_index(assault.platform_index)
  if not platform or not platform.create_asteroid_chunks then return false end
  local chunks = {}
  append_employee_chunks(
    chunks,
    assault.workers,
    position,
    destination_for(platform, assault.source_position)
  )
  if #chunks == 0 then return false end
  platform.create_asteroid_chunks(chunks)
  return true
end

function M.on_entity_died(event)
  local target = event and event.entity
  if not target or target.type ~= "asteroid" then return false end
  local assault, assault_id = find_assault_for_target(target)
  if not assault then return false end

  local position = {x = target.position.x, y = target.position.y}
  release_employee_chunks(assault, position)
  remove_assault(assault_id, assault)
  return true
end

local function process_assaults(tick)
  ensure_storage()
  for assault_id, assault in pairs(storage.trajectory_compliance.assaults) do
    local target = assault.target
    if not target or not target.valid then
      -- If the platform failed to keep the asteroid in existence long enough
      -- for a death event, the attached workers are simply lost in space.
      remove_assault(assault_id, assault)
    else
      local force = force_by_name(assault.force_name)
      local active_workers = 0
      for _, worker in ipairs(assault.workers) do
        if tick - (worker.attached_tick or 0) >= ASSAULT_INTERVAL then
          active_workers = active_workers + 1
        end
      end
      local damage = M.biter_damage(force) * active_workers
      local health = target.health or fallback_asteroid_health(assault.size, assault.family)
      if damage > 0 and health and health <= damage then
        local position = {x = target.position.x, y = target.position.y}
        local platform = platform_by_index(assault.platform_index)
        local destination = destination_for(platform, assault.source_position)
        local chunks = salvage_chunks(assault.size, assault.family, position, destination) or {}
        append_employee_chunks(chunks, assault.workers, position, destination)

        if target.destroy() then
          if platform and platform.create_asteroid_chunks then
            platform.create_asteroid_chunks(chunks)
          end
          remove_assault(assault_id, assault)
        end
      elseif damage > 0 and health then
        target.health = health - damage
      end
    end
  end
end

function M.on_tick(event)
  if not event or not event.tick or event.tick % ASSAULT_INTERVAL ~= 0 then
    return
  end
  process_assaults(event.tick)
  refresh_blocked_cannons()
end

return M
