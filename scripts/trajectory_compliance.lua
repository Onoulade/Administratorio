local M = {}

local MANAGEMENT_ITEM = "middle-management-managing-manager"
local ARRAY_NAME = "trajectory-compliance-array"
local RESPONSE_INTERVAL = 60
local RESPONSE_RADIUS = 32

M.MANAGEMENT_ITEM = MANAGEMENT_ITEM
M.ARRAY_NAME = ARRAY_NAME
M.RESPONSE_INTERVAL = RESPONSE_INTERVAL
M.RESPONSE_RADIUS = RESPONSE_RADIUS

local function ensure_storage()
  storage.trajectory_compliance = storage.trajectory_compliance or {}
  storage.trajectory_compliance.arrays = storage.trajectory_compliance.arrays or {}
  storage.trajectory_compliance.notified_forces = storage.trajectory_compliance.notified_forces or {}
end

local function get_state(unit_number)
  local state = storage.trajectory_compliance.arrays[unit_number]
  if not state then
    state = {}
    storage.trajectory_compliance.arrays[unit_number] = state
  end
  return state
end

local function get_ammo_inventory(entity)
  if not entity or not entity.valid or not entity.get_inventory then
    return nil
  end
  return entity.get_inventory(defines.inventory.turret_ammo)
end

local function clear_status(entity, state)
  if entity and entity.valid then
    entity.custom_status = nil
  end
  if state then
    state.blocked = nil
  end
end

local function mark_starved(entity, state)
  entity.custom_status = {
    diode = defines.entity_status_diode.red,
    label = {"gui.trajectory-compliance-status"},
  }
  state.blocked = true

  local force = entity.force
  if force and force.valid and not storage.trajectory_compliance.notified_forces[force.index] then
    storage.trajectory_compliance.notified_forces[force.index] = true
    force.print({"message.trajectory-compliance-starved", entity.backer_name or {"entity-name.trajectory-compliance-array"}})
  end
end

local function asteroid_search_area(position)
  return {
    {position.x - RESPONSE_RADIUS, position.y - RESPONSE_RADIUS},
    {position.x + RESPONSE_RADIUS, position.y + RESPONSE_RADIUS},
  }
end

local function asteroid_search_area_for_entity(entity)
  return asteroid_search_area(entity.position)
end

local function find_threatened_chunks(platform, entity)
  if not platform or not platform.valid or not entity or not entity.valid then
    return {}
  end

  local chunks = platform.find_asteroid_chunks_filtered{
    area = asteroid_search_area_for_entity(entity),
    limit = 1,
  }
  return chunks or {}
end

local function spend_management(entity)
  local inventory = get_ammo_inventory(entity)
  if not inventory or not inventory.valid then
    return false
  end
  if inventory.get_item_count(MANAGEMENT_ITEM) <= 0 then
    return false
  end
  return inventory.remove({name = MANAGEMENT_ITEM, count = 1}) > 0
end

local function process_array(platform, entity, tick)
  if not entity.valid or not entity.unit_number then return end

  local state = get_state(entity.unit_number)
  if tick < (state.next_response_tick or 0) then
    return
  end

  local chunks = find_threatened_chunks(platform, entity)
  if #chunks == 0 then
    clear_status(entity, state)
    state.next_response_tick = tick + RESPONSE_INTERVAL
    return
  end

  local destroyed_any = false

  for _, chunk in ipairs(chunks) do
    if not spend_management(entity) then
      break
    end
    platform.destroy_asteroid_chunks{
      position = chunk.position,
      name = chunk.name,
      limit = 1,
    }
    destroyed_any = true
  end

  if destroyed_any then
    clear_status(entity, state)
  else
    mark_starved(entity, state)
  end

  state.next_response_tick = tick + RESPONSE_INTERVAL
end

function M.ensure_storage()
  ensure_storage()
end

function M.on_tick(event)
  ensure_storage()

  local seen = {}

  for _, force in pairs(game.forces or {}) do
    if force and force.valid and force.platforms then
      for _, platform in pairs(force.platforms) do
        if platform and platform.valid and platform.surface and platform.surface.valid then
          local arrays = platform.surface.find_entities_filtered{name = ARRAY_NAME}
          for _, entity in ipairs(arrays) do
            if entity.valid and entity.unit_number then
              seen[entity.unit_number] = true
              process_array(platform, entity, event.tick)
            end
          end
        end
      end
    end
  end

  for unit_number, _ in pairs(storage.trajectory_compliance.arrays) do
    if not seen[unit_number] then
      storage.trajectory_compliance.arrays[unit_number] = nil
    end
  end
end

return M
