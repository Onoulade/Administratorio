local demolishers = require("scripts.demolishers")
local feature_flags = require("feature_flags")

local M = {}

local POST_NAME = "territorial-arbitration-post"
local ORDER_ITEM = "territorial-resettlement-order"
local PROPAGANDA_FLUID = "lie"
local PROCESS_INTERVAL = 60

local function ensure_storage()
  storage.territorial_arbitration = storage.territorial_arbitration or {}
  local runtime = storage.territorial_arbitration
  runtime.posts = runtime.posts or {}
  runtime.territories = runtime.territories or {}
  runtime.next_territory_id = runtime.next_territory_id or 1
end

local function get_runtime()
  ensure_storage()
  return storage.territorial_arbitration
end

local function chunk_key(chunk)
  return tostring(chunk.x) .. ":" .. tostring(chunk.y)
end

local function copy_chunk(chunk)
  return {x = chunk.x, y = chunk.y}
end

local function extract_chunk_position(chunk)
  if not chunk then return nil end
  local position = chunk.position or chunk
  local x = position.x or position[1]
  local y = position.y or position[2]
  if x == nil or y == nil then return nil end
  return {x = x, y = y}
end

local function chunk_center(chunk)
  return {
    x = chunk.x * 32 + 16,
    y = chunk.y * 32 + 16,
  }
end

local function box_to_chunks(box)
  if not box or not box.left_top or not box.right_bottom then
    return {}
  end

  local min_x = math.floor(math.min(box.left_top.x, box.right_bottom.x) / 32)
  local min_y = math.floor(math.min(box.left_top.y, box.right_bottom.y) / 32)
  local max_x = math.floor((math.max(box.left_top.x, box.right_bottom.x) - 0.001) / 32)
  local max_y = math.floor((math.max(box.left_top.y, box.right_bottom.y) - 0.001) / 32)

  local chunks = {}
  for x = min_x, max_x do
    for y = min_y, max_y do
      chunks[#chunks + 1] = {x = x, y = y}
    end
  end
  return chunks
end

local function refs_match(a, b)
  return a ~= nil and b ~= nil and a == b
end

local function find_territory_state(runtime, territory)
  if not territory or not territory.valid then return nil end
  for _, state in pairs(runtime.territories) do
    if state.territory and state.territory.valid and refs_match(state.territory, territory) then
      return state
    end
  end
  return nil
end

local function get_territory_chunk_positions(territory)
  local positions = {}
  for _, chunk in ipairs((territory and territory.get_chunks and territory.get_chunks()) or {}) do
    local position = extract_chunk_position(chunk)
    if position then
      positions[#positions + 1] = position
    end
  end
  return positions
end

local function create_territory_state(runtime, territory, anchor_position)
  local chunks = get_territory_chunk_positions(territory)
  if #chunks == 0 then return nil end

  local by_key = {}
  for _, chunk in ipairs(chunks) do
    by_key[chunk_key(chunk)] = chunk
  end

  table.sort(chunks, function(a, b)
    local a_center = chunk_center(a)
    local b_center = chunk_center(b)
    local adx = a_center.x - anchor_position.x
    local ady = a_center.y - anchor_position.y
    local bdx = b_center.x - anchor_position.x
    local bdy = b_center.y - anchor_position.y
    local adist = adx * adx + ady * ady
    local bdist = bdx * bdx + bdy * bdy
    if adist ~= bdist then return adist < bdist end
    if a.x ~= b.x then return a.x < b.x end
    return a.y < b.y
  end)

  local shrink_order = {}
  for _, chunk in ipairs(chunks) do
    shrink_order[#shrink_order + 1] = chunk_key(chunk)
  end

  local id = runtime.next_territory_id
  runtime.next_territory_id = id + 1

  local state = {
    id = id,
    territory = territory,
    original_chunks = chunks,
    original_chunk_by_key = by_key,
    shrink_order = shrink_order,
    current_removed_keys = {},
    posts = {},
    progress = 0,
    applied_steps = 0,
    demolisher_name = demolishers.get_demolisher_name(territory),
    surface = territory.surface,
  }

  runtime.territories[id] = state
  return state
end

local function get_or_create_territory_state(runtime, territory, anchor_position)
  return find_territory_state(runtime, territory) or create_territory_state(runtime, territory, anchor_position)
end

local function get_input_inventory(entity)
  if not entity or not entity.valid or not entity.get_inventory then return nil end
  local inventory_defs = defines and defines.inventory or {}
  for _, inventory_id in ipairs({
    inventory_defs.assembling_machine_input,
    inventory_defs.furnace_source,
    inventory_defs.chest,
  }) do
    if inventory_id ~= nil then
      local inventory = entity.get_inventory(inventory_id)
      if inventory then
        return inventory
      end
    end
  end
  return nil
end

local function inventory_count(inventory, item_name)
  if not inventory or not item_name then return 0 end
  if inventory.get_item_count then
    return inventory.get_item_count(item_name) or 0
  end

  local total = 0
  for index = 1, #inventory do
    local stack = inventory[index]
    if stack and stack.valid_for_read and stack.name == item_name then
      total = total + (stack.count or 0)
    end
  end
  return total
end

local function remove_items(inventory, item_name, amount)
  if not inventory or amount <= 0 then return 0 end
  if inventory.remove then
    return inventory.remove{name = item_name, count = amount} or 0
  end

  local removed = 0
  for index = 1, #inventory do
    local stack = inventory[index]
    if stack and stack.valid_for_read and stack.name == item_name and removed < amount then
      local take = math.min(stack.count or 0, amount - removed)
      stack.count = (stack.count or 0) - take
      removed = removed + take
    end
  end
  return removed
end

local function fluidbox_length(fluidbox)
  if not fluidbox then return 0 end
  return #fluidbox
end

local function fluid_amount(fluidbox, fluid_name)
  if not fluidbox or not fluid_name then return 0 end
  local total = 0
  for index = 1, fluidbox_length(fluidbox) do
    local entry = fluidbox[index]
    if entry and entry.name == fluid_name then
      total = total + (entry.amount or 0)
    end
  end
  return total
end

local function remove_fluid(fluidbox, fluid_name, amount)
  if not fluidbox or amount <= 0 then return 0 end
  local removed = 0
  for index = 1, fluidbox_length(fluidbox) do
    local entry = fluidbox[index]
    if entry and entry.name == fluid_name and removed < amount then
      local take = math.min(entry.amount or 0, amount - removed)
      local remaining = (entry.amount or 0) - take
      removed = removed + take
      if remaining > 0 then
        fluidbox[index] = {
          name = entry.name,
          amount = remaining,
          temperature = entry.temperature,
        }
      else
        fluidbox[index] = nil
      end
    end
  end
  return removed
end

local function mark_starved(entity)
  if not entity or not entity.valid then return end
  if not defines or not defines.entity_status_diode then return end
  entity.custom_status = {
    diode = defines.entity_status_diode.red,
    label = {"gui.territorial-arbitration-status"},
  }
end

local function clear_status(entity)
  if entity and entity.valid then
    entity.custom_status = nil
  end
end

local function set_progress_status(entity, progress, max_steps)
  if not entity or not entity.valid then return end
  if not defines or not defines.entity_status_diode then return end
  if max_steps <= 0 then return end
  if progress >= max_steps then
    entity.custom_status = {
      diode = defines.entity_status_diode.green,
      label = {"gui.territorial-arbitration-complete"},
    }
  else
    local pct = math.floor(progress / max_steps * 100)
    entity.custom_status = {
      diode = defines.entity_status_diode.green,
      label = {"gui.territorial-arbitration-progress", pct},
    }
  end
end

local function entity_is_powered(entity)
  if not entity or not entity.valid then return false end
  if entity.energy == nil then return true end
  return entity.energy > 0
end

local function get_upkeep_for_state(territory_state)
  local size = demolishers.infer_demolisher_size(territory_state.demolisher_name)
  return size, demolishers.SIZE_ORDER_COST[size], demolishers.SIZE_COFFEE_COST[size], demolishers.SIZE_DECAY[size]
end

local function attempt_upkeep(post_state, territory_state)
  local entity = post_state.entity
  if not entity or not entity.valid or not entity_is_powered(entity) then
    mark_starved(entity)
    return false, get_upkeep_for_state(territory_state)
  end

  local inventory = get_input_inventory(entity)
  local fluidbox = entity.fluidbox
  local size, orders_needed, coffee_needed = get_upkeep_for_state(territory_state)

  if inventory_count(inventory, ORDER_ITEM) < orders_needed then
    mark_starved(entity)
    return false, size, orders_needed, coffee_needed
  end

  if fluid_amount(fluidbox, PROPAGANDA_FLUID) < coffee_needed then
    mark_starved(entity)
    return false, size, orders_needed, coffee_needed
  end

  if remove_items(inventory, ORDER_ITEM, orders_needed) < orders_needed then
    mark_starved(entity)
    return false, size, orders_needed, coffee_needed
  end

  if remove_fluid(fluidbox, PROPAGANDA_FLUID, coffee_needed) < coffee_needed then
    mark_starved(entity)
    return false, size, orders_needed, coffee_needed
  end

  clear_status(entity)
  return true, size, orders_needed, coffee_needed
end

local function return_item_or_spill(entity, player)
  if not entity or not entity.valid then return end
  local placeable = entity.prototype and entity.prototype.items_to_place_this
  if not placeable or not placeable[1] then return end
  local stack = {
    name = placeable[1].name,
    count = 1,
    quality = entity.quality and entity.quality.name or nil,
  }
  if player and player.valid and player.insert and (player.insert(stack) or 0) > 0 then
    return
  end
  entity.surface.spill_item_stack{
    position = entity.position,
    stack = stack,
    enable_looted = true,
    force = entity.force,
  }
end

local function unique_territories_for_entity(entity)
  local territories = {}
  local chunks = box_to_chunks(entity.bounding_box or {
    left_top = {x = entity.position.x - 0.5, y = entity.position.y - 0.5},
    right_bottom = {x = entity.position.x + 0.5, y = entity.position.y + 0.5},
  })
  for _, chunk in ipairs(chunks) do
    local territory = entity.surface.get_territory_for_chunk and entity.surface.get_territory_for_chunk(chunk) or nil
    if territory and territory.valid then
      local seen = false
      for _, existing in ipairs(territories) do
        if refs_match(existing, territory) then
          seen = true
          break
        end
      end
      if not seen then
        territories[#territories + 1] = territory
      end
    end
  end
  return territories
end

local function compute_anchor_chunk_keys(post_entity, territory_state)
  local keys = {}
  local seen = {}
  for _, chunk in ipairs(box_to_chunks(post_entity.bounding_box)) do
    local key = chunk_key(chunk)
    if territory_state.original_chunk_by_key[key] and not seen[key] then
      keys[#keys + 1] = key
      seen[key] = true
    end
  end
  if #keys == 0 and territory_state.shrink_order[1] then
    keys[1] = territory_state.shrink_order[1]
  end
  return keys
end

local function post_protects_territory(post_state, territory_state, tick)
  return true
end

local function build_forced_removed_keys(runtime, territory_state, tick)
  local forced = {}
  for unit_number in pairs(territory_state.posts or {}) do
    local post_state = runtime.posts[unit_number]
    if post_state and post_state.entity and post_state.entity.valid and post_protects_territory(post_state, territory_state, tick) then
      for _, key in ipairs((post_state.anchor_chunk_keys_by_territory and post_state.anchor_chunk_keys_by_territory[territory_state.id]) or {}) do
        forced[key] = true
      end
    end
  end
  return forced
end

local function apply_chunk_changes(territory_state, desired_removed_keys)
  local territory = territory_state.territory
  if not territory or not territory.valid then return end
  local surface = territory.surface or territory_state.surface
  if not surface then return end

  local to_remove = {}
  local to_restore = {}

  for key in pairs(desired_removed_keys) do
    if not territory_state.current_removed_keys[key] then
      to_remove[#to_remove + 1] = copy_chunk(territory_state.original_chunk_by_key[key])
    end
  end

  for key in pairs(territory_state.current_removed_keys) do
    if not desired_removed_keys[key] then
      to_restore[#to_restore + 1] = copy_chunk(territory_state.original_chunk_by_key[key])
    end
  end

  if #to_remove > 0 then
    surface.set_territory_for_chunks(to_remove, nil)
  end

  if #to_restore > 0 then
    surface.set_territory_for_chunks(to_restore, territory)
  end

  territory_state.current_removed_keys = desired_removed_keys
  if (#to_remove > 0 or #to_restore > 0) and territory.valid and territory.regenerate_patrol_path then
    territory.regenerate_patrol_path()
  end
end

local function remove_territory_state(runtime, territory_state)
  if not territory_state then return end
  runtime.territories[territory_state.id] = nil
  for unit_number in pairs(territory_state.posts or {}) do
    local post_state = runtime.posts[unit_number]
    if post_state and post_state.territory_ids then
      local filtered = {}
      for _, territory_id in ipairs(post_state.territory_ids) do
        if territory_id ~= territory_state.id then
          filtered[#filtered + 1] = territory_id
        end
      end
      post_state.territory_ids = filtered
      if post_state.anchor_chunk_keys_by_territory then
        post_state.anchor_chunk_keys_by_territory[territory_state.id] = nil
      end
    end
  end
end

local function complete_territory(runtime, territory_state)
  local territory = territory_state.territory
  if territory and territory.valid then
    for _, segmented_unit in ipairs((territory.get_segmented_units and territory.get_segmented_units()) or {}) do
      if segmented_unit and segmented_unit.valid and segmented_unit.destroy then
        segmented_unit.destroy()
      end
    end

    local all_chunks = {}
    for _, chunk in ipairs(territory_state.original_chunks or {}) do
      all_chunks[#all_chunks + 1] = copy_chunk(chunk)
    end
    if #all_chunks > 0 then
      local surface = territory.surface or territory_state.surface
      if surface then
        surface.set_territory_for_chunks(all_chunks, nil)
      end
    end
  end

  remove_territory_state(runtime, territory_state)
end

local function refresh_territory_visuals(runtime, territory_state, tick)
  if not territory_state or not territory_state.territory or not territory_state.territory.valid then
    remove_territory_state(runtime, territory_state)
    return
  end

  local max_steps = #territory_state.shrink_order
  if max_steps == 0 then
    remove_territory_state(runtime, territory_state)
    return
  end

  local progress = territory_state.progress or 0
  if progress >= max_steps then
    complete_territory(runtime, territory_state)
    return
  end

  territory_state.applied_steps = math.max(0, math.min(max_steps, math.floor(progress)))

  local desired_removed_keys = build_forced_removed_keys(runtime, territory_state, tick)
  for index = 1, territory_state.applied_steps do
    local key = territory_state.shrink_order[index]
    if key then
      desired_removed_keys[key] = true
    end
  end

  apply_chunk_changes(territory_state, desired_removed_keys)
end

local function detach_post(runtime, post_state)
  if not post_state then return end
  for _, territory_id in ipairs(post_state.territory_ids or {}) do
    local territory_state = runtime.territories[territory_id]
    if territory_state then
      territory_state.posts[post_state.unit_number] = nil
    end
  end
  runtime.posts[post_state.unit_number] = nil
end

local function cleanup_invalid_state()
  local runtime = get_runtime()

  for unit_number, post_state in pairs(runtime.posts) do
    if not post_state.entity or not post_state.entity.valid then
      detach_post(runtime, post_state)
    end
  end

  for territory_id, territory_state in pairs(runtime.territories) do
    if not territory_state.territory or not territory_state.territory.valid then
      runtime.territories[territory_id] = nil
    elseif not next(territory_state.posts or {}) and (territory_state.progress or 0) <= 0 and not next(territory_state.current_removed_keys or {}) then
      runtime.territories[territory_id] = nil
    end
  end
end

function M.ensure_storage()
  ensure_storage()
end

function M.rebuild_registry()
  local runtime = get_runtime()
  cleanup_invalid_state()

  -- The arbitration post is a Space Age entity. find_entities_filtered
  -- errors on an unknown prototype name, so skip entirely without it.
  if not feature_flags.entity_prototype_exists(POST_NAME) then
    return
  end

  for _, surface in pairs(game.surfaces or {}) do
    for _, entity in ipairs(surface.find_entities_filtered{name = POST_NAME}) do
      if entity.valid and not runtime.posts[entity.unit_number] then
        M.on_entity_built(entity, nil)
      elseif entity.valid then
        runtime.posts[entity.unit_number].entity = entity
      end
    end
  end
end

function M.on_entity_built(entity, player)
  local runtime = get_runtime()
  if not entity or not entity.valid or entity.name ~= POST_NAME then
    return true
  end

  cleanup_invalid_state()

  local territories = unique_territories_for_entity(entity)
  if #territories == 0 then
    if player and player.valid and player.print then
      player.print({"message.territorial-arbitration-invalid-placement"})
    end
    return_item_or_spill(entity, player)
    entity.destroy()
    return false
  end

  local post_state = runtime.posts[entity.unit_number]
  if post_state then
    detach_post(runtime, post_state)
  end

  post_state = {
    unit_number = entity.unit_number,
    entity = entity,
    territory_ids = {},
    anchor_chunk_keys_by_territory = {},
  }
  runtime.posts[entity.unit_number] = post_state

  entity.destructible = false

  for _, territory in ipairs(territories) do
    local territory_state = get_or_create_territory_state(runtime, territory, entity.position)
    if territory_state then
      territory_state.posts[entity.unit_number] = true
      post_state.territory_ids[#post_state.territory_ids + 1] = territory_state.id
      post_state.anchor_chunk_keys_by_territory[territory_state.id] = compute_anchor_chunk_keys(entity, territory_state)
      refresh_territory_visuals(runtime, territory_state, game and game.tick or 0)
    end
  end

  return true
end

function M.on_entity_removed(entity)
  local runtime = get_runtime()
  if not entity or entity.name ~= POST_NAME then return end
  local post_state = runtime.posts[entity.unit_number]
  if not post_state then return end

  local affected_territory_ids = {}
  for _, territory_id in ipairs(post_state.territory_ids or {}) do
    affected_territory_ids[#affected_territory_ids + 1] = territory_id
  end

  detach_post(runtime, post_state)

  for _, territory_id in ipairs(affected_territory_ids) do
    local territory_state = runtime.territories[territory_id]
    if territory_state then
      refresh_territory_visuals(runtime, territory_state, game and game.tick or 0)
    end
  end
end

function M.on_tick(event)
  if not event or not event.tick or event.tick % PROCESS_INTERVAL ~= 0 then
    return
  end

  local runtime = get_runtime()
  cleanup_invalid_state()

  local success_counts = {}
  local touched_territories = {}
  local starved_posts = {}

  for _, post_state in pairs(runtime.posts) do
    if post_state.entity and post_state.entity.valid then
      for _, territory_id in ipairs(post_state.territory_ids or {}) do
        local territory_state = runtime.territories[territory_id]
        if territory_state then
          local success = attempt_upkeep(post_state, territory_state)
          touched_territories[territory_id] = true
          if success then
            success_counts[territory_id] = (success_counts[territory_id] or 0) + 1
          else
            starved_posts[post_state.unit_number] = true
          end
        end
      end
    end
  end

  local deltas = {}
  for territory_id in pairs(touched_territories) do
    local territory_state = runtime.territories[territory_id]
    if territory_state then
      local size = demolishers.infer_demolisher_size(territory_state.demolisher_name)
      local successes = success_counts[territory_id] or 0
      if successes > 0 then
        deltas[territory_id] = successes
      else
        deltas[territory_id] = -(demolishers.SIZE_DECAY[size] or 2)
      end
    end
  end

  for territory_id, territory_state in pairs(runtime.territories) do
    if not touched_territories[territory_id] then
      local size = demolishers.infer_demolisher_size(territory_state.demolisher_name)
      deltas[territory_id] = (deltas[territory_id] or 0) - (demolishers.SIZE_DECAY[size] or 2)
    end
  end

  for territory_id, delta in pairs(deltas) do
    local territory_state = runtime.territories[territory_id]
    if territory_state then
      local max_progress = #territory_state.shrink_order
      territory_state.progress = math.max(0, math.min(max_progress, (territory_state.progress or 0) + delta))
    end
  end

  for _, territory_state in pairs(runtime.territories) do
    refresh_territory_visuals(runtime, territory_state, event.tick)
  end

  for _, post_state in pairs(runtime.posts) do
    if post_state.entity and post_state.entity.valid and not starved_posts[post_state.unit_number] then
      for _, territory_id in ipairs(post_state.territory_ids or {}) do
        local territory_state = runtime.territories[territory_id]
        if territory_state then
          set_progress_status(post_state.entity, territory_state.progress or 0, #territory_state.shrink_order)
          break
        end
      end
    end
  end
end

M.POST_NAME = POST_NAME
M.ORDER_ITEM = ORDER_ITEM
M.PROPAGANDA_FLUID = PROPAGANDA_FLUID
M.COFFEE_FLUID = PROPAGANDA_FLUID -- compatibility for existing saves/tests
M.PROCESS_INTERVAL = PROCESS_INTERVAL

return M
