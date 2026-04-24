-- Waiting zone management: bounds, markers, capacity
local C = require("scripts.constants")
local M = {}

-- Grid offsets within a 5x5 zone (relative to zone left_top).
-- Starts at 4 active slots and expands up to 12 through research.
local GRID_OFFSETS = {
  -- Base 4 slots (outer ring, clear of 9x9 corner blockers)
  {1.20, 1.10}, {3.80, 1.10}, {1.20, 2.90}, {3.80, 2.90},
  -- Expansion slots
  {2.00, 1.10}, {3.00, 2.90}, {3.00, 1.10}, {2.00, 2.90},
  {1.20, 2.00}, {3.80, 2.00}, {2.00, 2.00}, {3.00, 2.00},
}
local BASE_ZONE_CAPACITY = 4
local MAX_ZONE_CAPACITY = #GRID_OFFSETS
local CAPACITY_TECH_PREFIX = "admin-station-capacity-"
local DESK_HALF_SIZE = 4.5
local ZONE_HALF_SIZE = 2.5
local CORNER_BLOCKER_NAME = "admin-station-corner-blocker"

-- Compute the centered 5x5 waiting-zone bounds relative to the larger station footprint.
function M.get_zone_bounds(pos)
  local cx, cy = pos.x, pos.y
  return {
    left_top = {x = cx - ZONE_HALF_SIZE, y = cy - ZONE_HALF_SIZE},
    right_bottom = {x = cx + ZONE_HALF_SIZE, y = cy + ZONE_HALF_SIZE},
  }
end

function M.get_desk_footprint_bounds(pos)
  local cx, cy = pos.x, pos.y
  return {
    left_top = {x = cx - DESK_HALF_SIZE, y = cy - DESK_HALF_SIZE},
    right_bottom = {x = cx + DESK_HALF_SIZE, y = cy + DESK_HALF_SIZE},
  }
end

function M.is_in_admin_zone(surface, box)
  for desk_id, zone in pairs(storage.desk_zones) do
    local b = zone.footprint or zone.bounds
    if b and box.left_top.x < b.right_bottom.x and box.right_bottom.x > b.left_top.x
       and box.left_top.y < b.right_bottom.y and box.right_bottom.y > b.left_top.y then
      return true
    end
  end
  return false
end

function M.zone_area_is_clear(surface, bounds, exclude_entity)
  local tiles = surface.find_tiles_filtered{
    area = {bounds.left_top, bounds.right_bottom},
  }
  for _, tile in ipairs(tiles) do
    if tile.valid and (tile.name == "out-of-map" or tile.collides_with("water_tile")) then
      return false
    end
  end

  local entities = surface.find_entities_filtered{
    area = {bounds.left_top, bounds.right_bottom},
  }
  for _, ent in ipairs(entities) do
    if ent.valid and ent ~= exclude_entity
       and ent.name ~= CORNER_BLOCKER_NAME and ent.name ~= "admin-station-combinator"
       and ent.name ~= C.BITERPORT_HIDDEN_ROBOPORT_NAME
       and not C.ZONE_SAFE_TYPES[ent.type] then
      return false
    end
  end
  return true
end

function M.zone_overlaps_existing(bounds, exclude_desk_id)
  for desk_id, zone in pairs(storage.desk_zones) do
    if desk_id ~= exclude_desk_id and zone.bounds then
      local b = zone.footprint or zone.bounds
      if bounds.left_top.x < b.right_bottom.x and bounds.right_bottom.x > b.left_top.x
         and bounds.left_top.y < b.right_bottom.y and bounds.right_bottom.y > b.left_top.y then
        return true
      end
    end
  end
  return false
end

function M.create_corner_blockers(surface, footprint, force)
  local blockers = {}
  local left = math.floor(footprint.left_top.x)
  local right = math.floor(footprint.right_bottom.x) - 1
  local top = math.floor(footprint.left_top.y)
  local bottom = math.floor(footprint.right_bottom.y) - 1

  for tx = left, right do
    for ty = top, bottom do
      local in_left_corner = tx < left + 3
      local in_right_corner = tx > right - 3
      local in_top_corner = ty < top + 3
      local in_bottom_corner = ty > bottom - 3
      if (in_left_corner or in_right_corner) and (in_top_corner or in_bottom_corner) then
        local blocker = surface.create_entity{
          name = CORNER_BLOCKER_NAME,
          position = {x = tx + 0.5, y = ty + 0.5},
          force = force or "player",
        }
        if blocker then
          blocker.destructible = false
          blockers[#blockers + 1] = blocker
        end
      end
    end
  end

  return blockers
end

function M.destroy_corner_blockers(surface, footprint)
  local blockers = surface.find_entities_filtered{
    name = CORNER_BLOCKER_NAME,
    area = {footprint.left_top, footprint.right_bottom}
  }
  for _, blocker in ipairs(blockers) do
    if blocker.valid then blocker.destroy() end
  end
end

function M.get_queue_pos(desk)
  return {x = desk.position.x, y = desk.position.y}
end

-------------------------------------------------------------------------------
-- GRID-BASED SLOT MANAGEMENT
-- Each desk has research-scaled grid slots (4 base, up to 12).
-- storage.desk_grid_slots[desk_id] = { [slot_index] = unit_number, ... }
-------------------------------------------------------------------------------

local function ensure_grid(desk_id)
  if not storage.desk_grid_slots then storage.desk_grid_slots = {} end
  if not storage.desk_grid_slots[desk_id] then storage.desk_grid_slots[desk_id] = {} end
end

local function try_repair_desk_runtime_state(desk_id)
  local desks = storage.admin_desks
  if not desks then return false end
  local desk = desks[desk_id]
  if desk and desk.valid then
    return M.ensure_desk_runtime_state(desk)
  end
  desks[desk_id] = nil
  return false
end

function M.ensure_desk_runtime_state(desk)
  if not desk or not desk.valid then return false end
  storage.desk_zones = storage.desk_zones or {}
  storage.desk_reserved_slots = storage.desk_reserved_slots or {}
  if not storage.desk_grid_slots then storage.desk_grid_slots = {} end

  local desk_id = desk.unit_number
  local existing = storage.desk_zones[desk_id]
  local bounds = M.get_zone_bounds(desk.position)
  local footprint = M.get_desk_footprint_bounds(desk.position)
  local repaired = false

  if not existing or not existing.bounds or existing.tiles or not existing.footprint then
    repaired = true
  else
    local old = existing.bounds
    local old_footprint = existing.footprint
    if not old.left_top or not old.right_bottom or not old_footprint.left_top or not old_footprint.right_bottom
       or old.left_top.x ~= bounds.left_top.x or old.left_top.y ~= bounds.left_top.y
       or old.right_bottom.x ~= bounds.right_bottom.x or old.right_bottom.y ~= bounds.right_bottom.y then
      repaired = true
    elseif old_footprint.left_top.x ~= footprint.left_top.x or old_footprint.left_top.y ~= footprint.left_top.y
       or old_footprint.right_bottom.x ~= footprint.right_bottom.x or old_footprint.right_bottom.y ~= footprint.right_bottom.y then
      repaired = true
    end
  end

  storage.desk_zones[desk_id] = {bounds = bounds, footprint = footprint}
  storage.desk_reserved_slots[desk_id] = storage.desk_reserved_slots[desk_id] or 0
  storage.desk_grid_slots[desk_id] = storage.desk_grid_slots[desk_id] or {}
  return repaired
end

local function cleanup_stale_slots(desk_id)
  ensure_grid(desk_id)
  for i, occupant in pairs(storage.desk_grid_slots[desk_id]) do
    if type(occupant) ~= "number" or occupant <= 0 then
      storage.desk_grid_slots[desk_id][i] = nil
    else
      local info = storage.waiting_biters and storage.waiting_biters[occupant]
      if not info or info.desk_id ~= desk_id or not info.entity or not info.entity.valid then
        storage.desk_grid_slots[desk_id][i] = nil
      end
    end
  end
end

local function count_tracked_desk_occupants(desk_id)
  local waiting_biters = storage.waiting_biters
  local desk_biters = storage.desk_biters and storage.desk_biters[desk_id]
  if not waiting_biters then return 0 end

  local occupied = 0
  local seen = {}

  if desk_biters then
    for unit_number in pairs(desk_biters) do
      local info = waiting_biters[unit_number]
      if info and info.desk_id == desk_id and (info.state == "waiting" or info.state == "pathfinding")
         and info.entity and info.entity.valid then
        occupied = occupied + 1
        seen[unit_number] = true
      end
    end
  end

  for unit_number, info in pairs(waiting_biters) do
    if not seen[unit_number]
       and info
       and info.desk_id == desk_id
       and (info.state == "waiting" or info.state == "pathfinding")
       and info.entity
       and info.entity.valid then
      occupied = occupied + 1
      seen[unit_number] = true
    end
  end

  return occupied
end

local function get_desk_force(desk_id)
  local desks = storage and storage.admin_desks
  if not desks then return nil end
  local desk = desks[desk_id]
  if desk and desk.valid and desk.force and desk.force.valid then
    return desk.force
  end
  if desk and desk.valid == false then
    desks[desk_id] = nil
  end
  return nil
end

local function get_capacity_bonus_for_force(force)
  if not force or not force.valid or not force.technologies then return 0 end
  local max_bonus = MAX_ZONE_CAPACITY - BASE_ZONE_CAPACITY
  local bonus = 0
  for level = 1, max_bonus do
    local tech = force.technologies[CAPACITY_TECH_PREFIX .. level]
    if tech and tech.researched then
      bonus = bonus + 1
    else
      break
    end
  end
  return bonus
end

function M.get_zone_capacity(desk_id)
  local zone = storage.desk_zones[desk_id]
  if (not zone or not zone.bounds) and try_repair_desk_runtime_state(desk_id) then
    zone = storage.desk_zones[desk_id]
  end
  if not zone or not zone.bounds then return 0 end
  local force = get_desk_force(desk_id)
  local capacity = BASE_ZONE_CAPACITY + get_capacity_bonus_for_force(force)
  return math.min(capacity, MAX_ZONE_CAPACITY)
end

function M.get_available_slots(desk_id)
  ensure_grid(desk_id)
  cleanup_stale_slots(desk_id)
  local occupied_by_slots = 0
  for _ in pairs(storage.desk_grid_slots[desk_id]) do
    occupied_by_slots = occupied_by_slots + 1
  end
  local occupied = math.max(occupied_by_slots, count_tracked_desk_occupants(desk_id))
  local capacity = M.get_zone_capacity(desk_id)
  return math.max(0, capacity - occupied)
end

-- Claim the next free grid slot for a biter. Returns the slot index, or nil if full.
function M.reserve_slot(desk_id, unit_number)
  ensure_grid(desk_id)
  cleanup_stale_slots(desk_id)
  local capacity = M.get_zone_capacity(desk_id)
  if count_tracked_desk_occupants(desk_id) >= capacity then
    return nil
  end
  -- If no unit_number provided, use a placeholder (for pathfinding biters not yet placed)
  local id = unit_number or -(game.tick * 1000 + math.random(999))
  for i = 1, capacity do
    if not storage.desk_grid_slots[desk_id][i] then
      storage.desk_grid_slots[desk_id][i] = id
      return i
    end
  end
  return nil
end

-- Release the grid slot held by a specific biter (by unit_number) or slot index.
function M.release_slot(desk_id, unit_number)
  if not desk_id then return end
  ensure_grid(desk_id)
  if not unit_number then return end
  for i, occupant in pairs(storage.desk_grid_slots[desk_id]) do
    if occupant == unit_number then
      storage.desk_grid_slots[desk_id][i] = nil
      return
    end
  end
end

-- Reassign a grid slot from one unit_number to another (e.g. when replacing entity)
function M.reassign_slot(desk_id, old_unit_number, new_unit_number)
  if not desk_id then return end
  ensure_grid(desk_id)
  for i, occupant in pairs(storage.desk_grid_slots[desk_id]) do
    if occupant == old_unit_number then
      storage.desk_grid_slots[desk_id][i] = new_unit_number
      return
    end
  end
end

-- Reassign a grid slot by index directly (used when placeholder ID is not tracked)
function M.reassign_slot_by_index(desk_id, slot_index, new_unit_number)
  if not desk_id then return end
  ensure_grid(desk_id)
  storage.desk_grid_slots[desk_id][slot_index] = new_unit_number
end

-- Release a grid slot by index directly (used when placement fails)
function M.release_slot_by_index(desk_id, slot_index)
  if not desk_id then return end
  ensure_grid(desk_id)
  storage.desk_grid_slots[desk_id][slot_index] = nil
end

-- Get the world position for a grid slot at a given desk
function M.get_slot_position(desk_id, slot_index)
  local zone = storage.desk_zones[desk_id]
  if (not zone or not zone.bounds) and try_repair_desk_runtime_state(desk_id) then
    zone = storage.desk_zones[desk_id]
  end
  if not zone or not zone.bounds then return nil end
  local offset = GRID_OFFSETS[slot_index]
  if not offset then return nil end
  local b = zone.bounds
  return {x = b.left_top.x + offset[1], y = b.left_top.y + offset[2]}
end

-- Find which slot index a unit_number occupies at a desk
function M.get_biter_slot(desk_id, unit_number)
  ensure_grid(desk_id)
  for i, occupant in pairs(storage.desk_grid_slots[desk_id]) do
    if occupant == unit_number then return i end
  end
  return nil
end

-- Get a placement position for a biter at its assigned grid slot.
-- Falls back to find_non_colliding_position near the slot center.
function M.get_zone_position(surface, desk_id, entity_name, unit_number)
  if unit_number then
    local slot = M.get_biter_slot(desk_id, unit_number)
    if slot then
      local pos = M.get_slot_position(desk_id, slot)
      if pos then
        local safe = surface.find_non_colliding_position(entity_name, pos, 1, 0.25)
        if safe then return safe end
        return pos
      end
    end
  end
  -- Fallback: find any free slot position
  ensure_grid(desk_id)
  local capacity = M.get_zone_capacity(desk_id)
  for i = 1, capacity do
    if not storage.desk_grid_slots[desk_id][i] then
      local pos = M.get_slot_position(desk_id, i)
      if pos then
        local safe = surface.find_non_colliding_position(entity_name, pos, 1, 0.25)
        if safe then return safe end
      end
    end
  end
  return nil
end

function M.get_biter_placement_pos(surface, desk, entity_name, unit_number)
  local pos = M.get_zone_position(surface, desk.unit_number, entity_name, unit_number)
  if pos then return pos end
  return surface.find_non_colliding_position(entity_name, M.get_queue_pos(desk), 5, 0.5)
end

function M.cleanup_desk_zone(desk_id)
  local zone = storage.desk_zones[desk_id]
  if not zone or not zone.bounds then
    storage.desk_zones[desk_id] = nil
    if storage.desk_grid_slots then storage.desk_grid_slots[desk_id] = nil end
    return
  end
  for _, surface in pairs(game.surfaces) do
    if zone.footprint then
      M.destroy_corner_blockers(surface, zone.footprint)
    end
  end
  storage.desk_zones[desk_id] = nil
  if storage.desk_grid_slots then storage.desk_grid_slots[desk_id] = nil end
end

return M
