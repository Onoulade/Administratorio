local M = {}

local ARRAY_NAME = "trajectory-compliance-array"
local CANNON_NAME = "orbital-employment-cannon"
local ARRAY_TIERS = {
  ["trajectory-compliance-array"] = 2,
  ["senior-trajectory-compliance-array"] = 3,
  ["executive-trajectory-compliance-array"] = 4,
}
local ARRAY_RANGES = {
  ["trajectory-compliance-array"] = 20,
  ["senior-trajectory-compliance-array"] = 30,
  ["executive-trajectory-compliance-array"] = 40,
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
local EXPLORER_ITEM = "voluntary-exploration-space-miner"
local RETURNING_CHUNK = "returning-orbital-employee"
local RETURNING_CHUNK_DIRECTIONS = 16
local DEVIATION_EFFECT_ID = "administratorio-trajectory-deviation"
local BITER_LAUNCH_EFFECT_ID = "administratorio-asteroid-biter-launched"
local BITER_ASSAULT_EFFECT_ID = "administratorio-asteroid-biter-assault"
local BITER_AMMO_CATEGORY = "orbital-biter-ballistics"
local CAPACITY_TECH_PREFIX = "orbital-employment-capacity-"
local CAPACITY_TECH_LEVELS = 4
local BASE_EMPLOYEE_CAPACITY = 1
local CANNON_RANGE = 48
local CANNON_TURN_RANGE = 0.10
local BASE_BITER_DAMAGE = 125
local ASSAULT_INTERVAL = 60
local ASSIGNMENT_RESERVATION_LIFETIME = 600
local DEVIATION_PUSH_LIFETIME = 330
local DEVIATION_FORCE_PER_PULSE = 0.025
local DEVIATION_MAX_SPEED = 0.04
-- Arrays otherwise retain their engine-selected target indefinitely. Recheck
-- often enough to follow the nearest incoming threat, without scanning every
-- tick on platforms with many arrays.
local ARRAY_RETARGET_INTERVAL = 30
local DEVIATION_MASS_FACTORS = {
  small = 1,
  medium = 1.25,
  big = 2.5,
  huge = 5,
}
-- Mirrors Space Age's asteroid graphics_set.rotation_speed values. Asteroid
-- sprite rotation is not exposed through LuaEntity.orientation, so attached
-- manager rendering and release direction must accumulate it explicitly.
local ASTEROID_ROTATION_SPEEDS = {
  small = 0.0012,
  medium = 0.0009,
  big = 0.0006,
  huge = 0.0003,
}
local MANAGER_ATTACHMENT_RADII = {
  small = 0.32,
  medium = 0.75,
  big = 1.5,
  huge = 3.3,
}
local MANAGER_ATTACK_ANIMATION = "orbital-manager-attack"
local MANAGER_ANIMATION_SPEED = 0.24
local MANAGER_ORIENTATION_INTERVAL = 4
local MANAGER_VISUAL_VERSION = 7
local MANAGER_RENDER_LAYER = "186"

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
M.EXPLORER_ITEM = EXPLORER_ITEM
M.MANAGEMENT_ITEM = EXPLORER_ITEM -- Compatibility for older integrations.
M.RETURNING_CHUNK = RETURNING_CHUNK
M.RETURNING_CHUNK_DIRECTIONS = RETURNING_CHUNK_DIRECTIONS
M.DEVIATION_EFFECT_ID = DEVIATION_EFFECT_ID
M.BITER_LAUNCH_EFFECT_ID = BITER_LAUNCH_EFFECT_ID
M.BITER_ASSAULT_EFFECT_ID = BITER_ASSAULT_EFFECT_ID
M.EFFECT_ID = DEVIATION_EFFECT_ID -- Compatibility for older integrations.
M.BITER_AMMO_CATEGORY = BITER_AMMO_CATEGORY
M.CAPACITY_TECH_PREFIX = CAPACITY_TECH_PREFIX
M.CAPACITY_TECH_LEVELS = CAPACITY_TECH_LEVELS
M.BASE_EMPLOYEE_CAPACITY = BASE_EMPLOYEE_CAPACITY
M.CANNON_RANGE = CANNON_RANGE
M.CANNON_TURN_RANGE = CANNON_TURN_RANGE
M.BASE_BITER_DAMAGE = BASE_BITER_DAMAGE
M.ASSAULT_INTERVAL = ASSAULT_INTERVAL
M.ASSIGNMENT_RESERVATION_LIFETIME = ASSIGNMENT_RESERVATION_LIFETIME
M.DEVIATION_PUSH_LIFETIME = DEVIATION_PUSH_LIFETIME
M.DEVIATION_FORCE_PER_PULSE = DEVIATION_FORCE_PER_PULSE
M.DEVIATION_MAX_SPEED = DEVIATION_MAX_SPEED
M.ARRAY_RETARGET_INTERVAL = ARRAY_RETARGET_INTERVAL
M.DEVIATION_MASS_FACTORS = DEVIATION_MASS_FACTORS
M.ASTEROID_ROTATION_SPEEDS = ASTEROID_ROTATION_SPEEDS
M.MANAGER_ORIENTATION_INTERVAL = MANAGER_ORIENTATION_INTERVAL
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
  state.pending_assignments = state.pending_assignments or {}
  state.next_assignment_id = state.next_assignment_id or 1
  state.blocked_arrays = state.blocked_arrays or {}
  state.deviations = state.deviations or {}
  state.next_deviation_id = state.next_deviation_id or 1

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

local function returning_chunk_name(orientation)
  local normalized = (orientation or 0) % 1
  local direction = math.floor(normalized * RETURNING_CHUNK_DIRECTIONS + 0.5)
    % RETURNING_CHUNK_DIRECTIONS
  if direction == 0 then return RETURNING_CHUNK end
  return string.format("%s-orientation-%02d", RETURNING_CHUNK, direction)
end

M.returning_chunk_name = returning_chunk_name

local function append_employee_chunks(chunks, workers, target_position, destination)
  local count = #workers
  if count == 0 then return end

  for _, worker in ipairs(workers) do
    local angle = math.random() * 2 * math.pi
    local distance = 0.45 + 0.55 * math.sqrt(math.random())
    local position = {
      x = target_position.x + math.cos(angle) * distance,
      y = target_position.y + math.sin(angle) * distance,
    }
    chunks[#chunks + 1] = {
      name = returning_chunk_name(type(worker) == "table"
        and (worker.final_orientation or worker.arrival_orientation)
        or math.random()),
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

local function release_pending_employee(assignment, position)
  if not assignment then return false end
  local platform = platform_by_index(assignment.platform_index)
  if not platform or not platform.create_asteroid_chunks then return false end
  position = position or assignment.target_position or assignment.source_position
  if not position then return false end

  local chunks = {}
  append_employee_chunks(
    chunks,
    {true},
    position,
    destination_for(platform, assignment.source_position or position)
  )
  platform.create_asteroid_chunks(chunks)
  return true
end

local function destroy_render_object(object)
  if object and object.valid and object.destroy then object.destroy() end
end

local function destroy_worker_visual(worker)
  local visual = worker and worker.visual
  destroy_render_object(visual)
  if worker then
    worker.visual = nil
    worker.visual_version = nil
  end
end

local function destroy_worker_visuals(workers)
  for _, worker in ipairs(workers or {}) do
    destroy_worker_visual(worker)
  end
end

local function ensure_worker_rotation(worker, tick)
  tick = tick or (game and game.tick) or 0
  if worker.arrival_orientation == nil then
    worker.arrival_orientation = math.random()
    worker.rotation_start_tick = tick
  end
  if worker.rotation_start_tick == nil then
    worker.rotation_start_tick = worker.attached_tick or tick
  end
end

local function current_worker_orientation(worker, target, tick)
  tick = tick or (game and game.tick) or 0
  ensure_worker_rotation(worker, tick)
  local size = asteroid_identity(target.name)
  local rotation_speed = ASTEROID_ROTATION_SPEEDS[size] or 0
  local elapsed = math.max(0, tick - worker.rotation_start_tick)
  local accumulated = elapsed * rotation_speed
  return (worker.arrival_orientation + accumulated) % 1
end

local function snapshot_worker_orientations(workers, target, tick)
  for _, worker in ipairs(workers or {}) do
    worker.final_orientation = current_worker_orientation(worker, target, tick)
  end
end

local function attach_worker_visual(worker, target, index)
  if not rendering or not rendering.draw_animation then return nil end
  local tick = (game and game.tick) or worker.attached_tick or 0
  ensure_worker_rotation(worker, tick)
  local angle = (index - 1) * math.pi * (3 - math.sqrt(5))
  local size = asteroid_identity(target.name)
  local surface_radius = MANAGER_ATTACHMENT_RADII[size] or 0.75
  local radius = surface_radius * (0.55 + 0.08 * math.sqrt(index))
  return rendering.draw_animation{
    animation = MANAGER_ATTACK_ANIMATION,
    target = {
      entity = target,
      offset = {math.cos(angle) * radius, math.sin(angle) * radius},
    },
    orientation = current_worker_orientation(worker, target, tick),
    surface = target.surface,
    animation_speed = MANAGER_ANIMATION_SPEED,
    animation_offset = (index - 1) * 2.75,
    -- Keep the actual biter animation above every ordinary world and air
    -- object, but below Factorio's selection-box layers (which begin at 187).
    -- A numeric RenderLayer avoids implying that this is an item/info icon.
    render_layer = MANAGER_RENDER_LAYER,
  }
end

local function ensure_worker_visual(worker, target, index)
  local visual = worker and worker.visual
  if worker.visual_version == MANAGER_VISUAL_VERSION and visual and visual.valid then return end
  destroy_worker_visual(worker)
  worker.visual = attach_worker_visual(worker, target, index)
  worker.visual_version = MANAGER_VISUAL_VERSION
end

local function update_worker_visual_orientation(worker, target, tick)
  local visual = worker and worker.visual
  if visual and visual.valid then
    visual.orientation = current_worker_orientation(worker, target, tick)
  end
end

function M.biter_damage(force)
  -- VESM item/entity quality is intentionally absent. Returning chunks mine
  -- back into normal-quality ammunition, so only explicit research may scale
  -- their asteroid work.
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

local reconcile_array_target

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
  if ARRAY_TIERS[entity.name] and reconcile_array_target then
    reconcile_array_target(entity)
  end
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

local function pending_assignment_count(target)
  ensure_storage()
  local count = 0
  for _, assignment in pairs(storage.trajectory_compliance.pending_assignments) do
    if assignment.target == target then count = count + 1 end
  end
  return count
end

local function target_has_assigned_workers(target)
  return find_assault_for_target(target) ~= nil
    or pending_assignment_count(target) > 0
end

local function consume_pending_assignment(target, source)
  ensure_storage()
  local pending = storage.trajectory_compliance.pending_assignments
  local source_unit_number = source and source.unit_number
  local fallback_id
  for assignment_id, assignment in pairs(pending) do
    if assignment.target == target then
      fallback_id = fallback_id or assignment_id
      if source_unit_number and assignment.source_unit_number == source_unit_number then
        pending[assignment_id] = nil
        return true
      end
    end
  end
  -- Projectile cause identity is stable for cannon shots. Never let a second
  -- cannon steal the first cannon's reservation merely because both selected
  -- the same asteroid before native targeting reacted to the reroute.
  if not source_unit_number and fallback_id then
    pending[fallback_id] = nil
    return true
  end
  return false
end

local function take_pending_assignments_for_target(target)
  ensure_storage()
  local removed = {}
  for assignment_id, assignment in pairs(storage.trajectory_compliance.pending_assignments) do
    if assignment.target == target then
      storage.trajectory_compliance.pending_assignments[assignment_id] = nil
      removed[#removed + 1] = assignment
    end
  end
  return removed
end

local function atan2(y, x)
  if math.atan2 then return math.atan2(y, x) end
  if x > 0 then return math.atan(y / x) end
  if x < 0 then
    return math.atan(y / x) + (y >= 0 and math.pi or -math.pi)
  end
  if y > 0 then return math.pi / 2 end
  if y < 0 then return -math.pi / 2 end
  return 0
end

local function cannon_target_within_arc(source, target)
  -- Direction is the placed railgun base direction (0..15 around a circle).
  -- If an older mock or unusual integration cannot provide it, native turret
  -- targeting still enforces the prototype's turn_range.
  if not source or source.direction == nil then return true end
  local dx = target.position.x - source.position.x
  local dy = target.position.y - source.position.y
  if math.abs(dx) < 0.001 and math.abs(dy) < 0.001 then return true end

  local target_orientation = (atan2(dx, -dy) / (2 * math.pi)) % 1
  local base_orientation = (source.direction / 16) % 1
  local difference = math.abs(((target_orientation - base_orientation + 0.5) % 1) - 0.5)
  return difference <= CANNON_TURN_RANGE / 2 + 1e-9
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
    if candidate ~= excluded_target
      and valid_asteroid_target(source, candidate)
      and cannon_target_within_arc(source, candidate)
    then
      local assault = find_assault_for_target(candidate)
      local occupied = (assault and #assault.workers or 0)
        + pending_assignment_count(candidate)
      if occupied < capacity then
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

local function reroute_cannons_targeting(target)
  local surface = target and target.valid and target.surface
  if not surface or not surface.valid or not surface.find_entities_filtered then return end
  for _, cannon in ipairs(surface.find_entities_filtered{name = CANNON_NAME}) do
    if cannon.shooting_target == target then
      reroute_or_pause_cannon(cannon, target)
    end
  end
end

local function remove_assault(assault_id, assault)
  destroy_worker_visuals(assault and assault.workers)
  storage.trajectory_compliance.assaults[assault_id] = nil
end

local function find_deviation_for_target(target)
  ensure_storage()
  for deviation_id, deviation in pairs(storage.trajectory_compliance.deviations) do
    if deviation.target == target then
      return deviation, deviation_id
    end
  end
  return nil
end

local function remove_deviation(deviation_id)
  storage.trajectory_compliance.deviations[deviation_id] = nil
end

local function available_deviation_target_for(source, excluded_target)
  if not source or not source.valid then return nil end
  local range = ARRAY_RANGES[source.name]
  local surface = source.surface
  if not range or not surface or not surface.valid or not surface.find_entities_filtered then
    return nil
  end

  local best_target
  local best_distance
  for _, candidate in ipairs(surface.find_entities_filtered{
    type = "asteroid",
    position = source.position,
    radius = range,
  }) do
    if candidate ~= excluded_target
      and valid_asteroid_target(source, candidate)
      and not target_has_assigned_workers(candidate)
    then
      local dx = candidate.position.x - source.position.x
      local dy = candidate.position.y - source.position.y
      local distance = dx * dx + dy * dy
      if not best_distance or distance < best_distance then
        best_target = candidate
        best_distance = distance
      end
    end
  end
  return best_target
end

local function reroute_or_pause_array(source, excluded_target)
  if not source or not source.valid or not ARRAY_TIERS[source.name] then return false end
  ensure_storage()
  local state = storage.trajectory_compliance
  local unit_number = source.unit_number
  local target = available_deviation_target_for(source, excluded_target)

  if target then
    source.shooting_target = target
    source.disabled_by_script = false
    if unit_number then state.blocked_arrays[unit_number] = nil end
    return true
  end

  source.disabled_by_script = true
  if unit_number then state.blocked_arrays[unit_number] = source end
  return false
end

reconcile_array_target = reroute_or_pause_array

local function reroute_arrays_targeting(target)
  local surface = target and target.valid and target.surface
  if not surface or not surface.valid or not surface.find_entities_filtered then return end
  local names = {}
  for name in pairs(ARRAY_TIERS) do names[#names + 1] = name end
  for _, array in ipairs(surface.find_entities_filtered{name = names}) do
    if array.shooting_target == target then
      reroute_or_pause_array(array, target)
    end
  end
end

local function refresh_blocked_arrays()
  ensure_storage()
  local blocked = storage.trajectory_compliance.blocked_arrays
  for unit_number, array in pairs(blocked) do
    if not array or not array.valid then
      blocked[unit_number] = nil
    else
      reroute_or_pause_array(array)
    end
  end
end

local function refresh_array_targets()
  if not game or not game.surfaces then return end
  local names = {}
  for name in pairs(ARRAY_TIERS) do names[#names + 1] = name end
  for _, surface in pairs(game.surfaces) do
    for _, array in ipairs(surface.find_entities_filtered{name = names}) do
      -- Set the explicit closest eligible target instead of merely clearing
      -- shooting_target and relying on Factorio's cached target selection.
      reroute_or_pause_array(array)
    end
  end
end

local function resolve_biter_launch(event)
  local source = source_from_event(event)
  if not source or source.name ~= CANNON_NAME then return false end
  local target = target_from_event(event, source)
  if not valid_asteroid_target(source, target) then return false end

  local assault = find_assault_for_target(target)
  local occupied = (assault and #assault.workers or 0)
    + pending_assignment_count(target)
  local capacity = M.employee_capacity(source.force)
  if occupied >= capacity then
    reroute_or_pause_cannon(source, target)
    return false
  end

  local state = storage.trajectory_compliance
  local assignment_id = state.next_assignment_id
  local platform = platform_for_source(source)
  state.next_assignment_id = assignment_id + 1
  state.pending_assignments[assignment_id] = {
    target = target,
    source_unit_number = source.unit_number,
    platform_index = platform and platform.index or nil,
    source_position = {x = source.position.x, y = source.position.y},
    target_position = {x = target.position.x, y = target.position.y},
    created_tick = event.tick or (game and game.tick) or 0,
  }

  -- A launched employee owns the asteroid just as firmly as an attached one.
  -- Stop any older push immediately and prevent arrays from issuing new
  -- deviation orders while the projectile is in flight.
  local deviation, deviation_id = find_deviation_for_target(target)
  if deviation then remove_deviation(deviation_id) end
  reroute_arrays_targeting(target)

  if occupied + 1 >= capacity then
    -- Reserve the slot at launch, before this or another cannon can dispatch a
    -- second manager that would merely be rejected and drift home on impact.
    reroute_cannons_targeting(target)
  end
  return true
end

local function resolve_deviation(event)
  local source = source_from_event(event)
  if not source or not ARRAY_TIERS[source.name] then return false end
  local target = target_from_event(event, source)
  local size = valid_asteroid_target(source, target)
  if not size then return false end
  if target_has_assigned_workers(target) then
    reroute_or_pause_array(source, target)
    return false
  end

  local platform = platform_for_source(source)
  if not platform then return false end

  local deviation = find_deviation_for_target(target)
  if not deviation then
    local state = storage.trajectory_compliance
    local deviation_id = state.next_deviation_id
    state.next_deviation_id = deviation_id + 1
    deviation = {
      target = target,
      size = size,
      platform_index = platform.index,
      pushes = {},
    }
    state.deviations[deviation_id] = deviation
  end

  local tick = event.tick or (game and game.tick) or 0
  deviation.pushes[#deviation.pushes + 1] = {
    source = source,
    expires_tick = tick + DEVIATION_PUSH_LIFETIME,
  }

  -- Each order creates one fixed-duration outward push. Faster firing research
  -- and additional arrays overlap more pushes; asteroid mass dilutes them.
  -- The entity remains alive, visible, and fully available to attached workers.
  return true, OUTCOME_DEVIATED
end

local function resolve_biter_assault(event)
  local source = source_from_event(event)
  if not source or source.name ~= CANNON_NAME then return false end
  local target = target_from_event(event, source)
  local target_size, target_family = valid_asteroid_target(source, target)
  if not target_size then return false end
  local consumed_reservation = consume_pending_assignment(target, source)

  local platform = platform_for_source(source)
  if not platform or not platform.create_asteroid_chunks then return false end

  local assault = find_assault_for_target(target)
  local capacity = M.employee_capacity(source.force)
  if (not consumed_reservation and pending_assignment_count(target) > 0)
    or (assault and #assault.workers >= capacity)
  then
    -- Another cannon may already have had a projectile in flight when this
    -- asteroid's staffing allocation was reserved or filled. The rejected
    -- employee becomes a normal collectible return chunk instead of stealing
    -- the other launch's reservation or being silently consumed.
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

  local worker = {
    attached_tick = event.tick or (game and game.tick) or 0,
    arrival_orientation = math.random(),
  }
  worker.rotation_start_tick = worker.attached_tick
  assault.workers[#assault.workers + 1] = worker
  ensure_worker_visual(worker, target, #assault.workers)

  -- Managers have claimed this asteroid for demolition. Cancel any older
  -- displacement order and make every array currently aiming at it choose a
  -- manager-free target instead.
  local deviation, deviation_id = find_deviation_for_target(target)
  if deviation then remove_deviation(deviation_id) end
  reroute_arrays_targeting(target)
  assault.deviation_exclusion_version = 1

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
  elseif event.effect_id == BITER_LAUNCH_EFFECT_ID then
    return resolve_biter_launch(event)
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
  local handled = false

  local pending_assignments = take_pending_assignments_for_target(target)
  if #pending_assignments > 0 then
    -- A projectile loses its native impact when the tracked asteroid dies.
    -- Return every airborne employee as a collectible chunk at the death
    -- position instead of silently deleting the ammunition.
    local position = {x = target.position.x, y = target.position.y}
    for _, assignment in ipairs(pending_assignments) do
      release_pending_employee(assignment, position)
    end
    handled = true
  end

  local deviation, deviation_id = find_deviation_for_target(target)
  if deviation then
    remove_deviation(deviation_id)
    handled = true
  end

  local assault, assault_id = find_assault_for_target(target)
  if not assault then return handled end

  local position = {x = target.position.x, y = target.position.y}
  snapshot_worker_orientations(assault.workers, target, event.tick)
  release_employee_chunks(assault, position)
  remove_assault(assault_id, assault)
  return true
end

local function process_deviations(tick)
  local state = storage.trajectory_compliance
  if not state or not state.deviations or not next(state.deviations) then return end
  for deviation_id, deviation in pairs(state.deviations) do
    local target = deviation.target
    if not target or not target.valid then
      remove_deviation(deviation_id)
    elseif target_has_assigned_workers(target) then
      -- Covers projectiles already in flight when an employee claimed the
      -- target, as well as employees that have already landed.
      remove_deviation(deviation_id)
    else
      local active_pushes = 0
      for index = #deviation.pushes, 1, -1 do
        local push = deviation.pushes[index]
        if tick > (push.expires_tick or 0) or not push.source or not push.source.valid then
          table.remove(deviation.pushes, index)
        else
          active_pushes = active_pushes + 1
        end
      end

      if active_pushes == 0 then
        remove_deviation(deviation_id)
      else
        local platform = target.surface and target.surface.platform
          or platform_by_index(deviation.platform_index)
        local hub = platform and platform.valid and platform.hub
        local mass_factor = DEVIATION_MASS_FACTORS[deviation.size]
        if hub and hub.valid and mass_factor and target.teleport then
          local away_x = target.position.x - hub.position.x
          local away_y = target.position.y - hub.position.y
          local distance = math.sqrt(away_x * away_x + away_y * away_y)
          if distance < 0.001 then
            away_x, away_y, distance = 0, -1, 1
          end

          local speed = math.min(
            DEVIATION_MAX_SPEED,
            DEVIATION_FORCE_PER_PULSE * active_pushes / mass_factor
          )
          target.teleport({
            x = target.position.x + away_x / distance * speed,
            y = target.position.y + away_y / distance * speed,
          })
        end
      end
    end
  end
end

local function process_pending_assignments(tick)
  local state = storage.trajectory_compliance
  if not state or not state.pending_assignments then return end
  for assignment_id, assignment in pairs(state.pending_assignments) do
    local target = assignment.target
    local expired = tick - (assignment.created_tick or 0) > ASSIGNMENT_RESERVATION_LIFETIME
    if not target or not target.valid or expired then
      state.pending_assignments[assignment_id] = nil
      release_pending_employee(
        assignment,
        target and target.valid and target.position or assignment.target_position
      )
    end
  end
end

local function process_manager_visuals(tick)
  local state = storage.trajectory_compliance
  if not state or not state.assaults or not next(state.assaults) then return end
  for _, assault in pairs(state.assaults) do
    local target = assault.target
    if target and target.valid then
      for index, worker in ipairs(assault.workers) do
        ensure_worker_visual(worker, target, index)
        update_worker_visual_orientation(worker, target, tick)
      end
    end
  end
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
      if assault.deviation_exclusion_version ~= 1 then
        -- Refresh assaults created by older saves before arrays knew how to
        -- exclude staffed asteroids during configuration.
        reroute_arrays_targeting(target)
        assault.deviation_exclusion_version = 1
      end
      local force = force_by_name(assault.force_name)
      local active_workers = 0
      for _, worker in ipairs(assault.workers) do
        if tick - (worker.attached_tick or 0) >= ASSAULT_INTERVAL then
          active_workers = active_workers + 1
        end
      end
      local damage = M.biter_damage(force) * active_workers
      local health = target.health or fallback_asteroid_health(assault.size, assault.family)
      if damage > 0
        and health
        and health <= damage
        and pending_assignment_count(target) > 0
      then
        -- Do not destroy the projectile's tracked entity underneath an
        -- employee that already owns a reserved slot. Hold it at the brink
        -- until all launched coworkers have arrived.
        target.health = math.min(health, 1)
      elseif damage > 0 and health and health <= damage then
        local position = {x = target.position.x, y = target.position.y}
        local platform = platform_by_index(assault.platform_index)
        local destination = destination_for(platform, assault.source_position)
        local chunks = salvage_chunks(assault.size, assault.family, position, destination) or {}
        snapshot_worker_orientations(assault.workers, target, tick)
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
  if not event or not event.tick then return end
  process_pending_assignments(event.tick)
  process_deviations(event.tick)
  if event.tick % ARRAY_RETARGET_INTERVAL == 0 then
    refresh_array_targets()
  end
  if event.tick % MANAGER_ORIENTATION_INTERVAL == 0 then
    process_manager_visuals(event.tick)
  end
  if event.tick % ASSAULT_INTERVAL ~= 0 then return end
  process_assaults(event.tick)
  refresh_blocked_cannons()
  refresh_blocked_arrays()
end

return M
