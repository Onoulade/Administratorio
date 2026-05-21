local C = require("scripts.constants")
local biters = require("scripts.biters")
local unit_ai_settings = require("scripts.unit_ai_settings")
local M = {}

local SUPPLY_CHEST_NAME = "hired-biter-supply-chest"
local NOTICE_ITEM = "eviction-notice"
local TOGGLE_SELECT_INPUT = "administratorio-field-agent-toggle-select"
local SET_WAYPOINT_INPUT = "administratorio-field-agent-set-waypoint"
local APPEND_WAYPOINT_INPUT = "administratorio-field-agent-append-waypoint"

-- storage.hired_biters[unit_number] = {
--   entity            = LuaEntity (real biter unit on player force),
--   inventory         = LuaInventory (hidden eviction notice storage),
--   state             = "exploring" | "moving_to_command" | "moving_to_supply" | "moving_to_nest",
--   command_dest      = {x, y} | nil,
--   waypoints         = array[{destination = {x, y}, supply_entity = LuaEntity | nil}],
--   supply_entity     = LuaEntity | nil,
--   target_nest       = LuaEntity | nil,
--   last_scan_tick    = int,
--   notices_delivered = int,
-- }

local function copy_position(position)
  return position and {x = position.x, y = position.y} or nil
end

function M.ensure_storage()
  storage.hired_biters = storage.hired_biters or {}
  storage.hired_biter_selected = storage.hired_biter_selected or {}
end

local function create_notice_inventory()
  if game and game.create_inventory then
    return game.create_inventory(C.HIRED_BITER_INVENTORY_SLOTS or 4)
  end
  return nil
end

local function ensure_notice_inventory(entry)
  if not entry then return nil end
  if entry.inventory and (entry.inventory.valid == nil or entry.inventory.valid) then
    return entry.inventory
  end
  entry.inventory = create_notice_inventory()
  return entry.inventory
end

local function get_notice_count(entry)
  local inv = ensure_notice_inventory(entry)
  return inv and inv.get_item_count and inv.get_item_count(NOTICE_ITEM) or 0
end

local function notice_capacity()
  return C.HIRED_BITER_NOTICE_CAPACITY or 20
end

local function consume_notice(entry)
  local inv = ensure_notice_inventory(entry)
  if not inv or not inv.remove then return false end
  return inv.remove({name = NOTICE_ITEM, count = 1}) > 0
end

local function show_notice_feedback(entry, added, player)
  if not entry or not entry.entity or not entry.entity.valid then return end
  local count = get_notice_count(entry)
  local capacity = notice_capacity()
  local text
  if added and added > 0 then
    text = {"message.hired-biter-eviction-added", added, count, capacity}
  else
    text = {"message.hired-biter-eviction-count", count, capacity}
  end

  if player and player.valid and player.create_local_flying_text then
    player.create_local_flying_text{
      text = text,
      position = entry.entity.position,
      create_at_cursor = false,
    }
  elseif entry.entity.surface and entry.entity.surface.create_entity then
    pcall(entry.entity.surface.create_entity, {
      name = "flying-text",
      position = entry.entity.position,
      text = text,
      color = {r = 0.35, g = 0.9, b = 1.0},
    })
  end
end

local function player_holds_remote(player)
  local stack = player and player.cursor_stack
  return stack and stack.valid_for_read and stack.name == C.HIRED_BITER_REMOTE_NAME
end

local function is_position_charted(force, surface, position)
  if not force or not force.is_chunk_charted or not surface or not position then
    return true
  end
  return force.is_chunk_charted(surface, {
    x = math.floor(position.x / 32),
    y = math.floor(position.y / 32),
  })
end

local function set_destination(entry, position)
  entry.state = "moving_to_command"
  entry.command_dest = copy_position(position)
  entry.supply_entity = nil
  entry.target_nest = nil
  M._set_destination(entry.entity, entry.command_dest)
end

local function set_supply_destination(entry, source_entity)
  if not source_entity or not source_entity.valid then return end
  entry.state = "moving_to_supply"
  entry.command_dest = copy_position(source_entity.position)
  entry.supply_entity = source_entity
  entry.target_nest = nil
  M._set_destination(entry.entity, entry.command_dest)
end

local function advance_waypoint(entry)
  if entry.waypoints and #entry.waypoints > 0 then
    local waypoint = table.remove(entry.waypoints, 1)
    if waypoint.supply_entity and waypoint.supply_entity.valid then
      set_supply_destination(entry, waypoint.supply_entity)
    else
      set_destination(entry, waypoint.destination)
    end
  else
    entry.state = "exploring"
    entry.command_dest = nil
    entry.supply_entity = nil
    entry.target_nest = nil
    entry.last_scan_tick = 0
  end
end

local function command_entry(entry, position, append, source_entity)
  local waypoint = {
    destination = copy_position(position),
    supply_entity = source_entity,
  }
  if append then
    entry.waypoints = entry.waypoints or {}
    entry.waypoints[#entry.waypoints + 1] = waypoint
    if (entry.state ~= "moving_to_command" and entry.state ~= "moving_to_supply") or not entry.command_dest then
      advance_waypoint(entry)
    end
  else
    entry.waypoints = {}
    if source_entity and source_entity.valid then
      set_supply_destination(entry, source_entity)
    else
      set_destination(entry, position)
    end
  end
end

local function track_entity(entity)
  if not entity or not entity.valid then return false end
  M.ensure_storage()
  local entry = storage.hired_biters[entity.unit_number] or {
    state = "exploring",
    target_nest = nil,
    command_dest = nil,
    waypoints = {},
    last_scan_tick = 0,
    notices_delivered = 0,
  }
  entry.entity = entity
  entry.unit_number = entity.unit_number
  entry.waypoints = entry.waypoints or {}
  storage.hired_biters[entity.unit_number] = entry
  ensure_notice_inventory(entry)
  return true
end

local function transfer_notice_inventory(entry, target_inventory)
  local inv = ensure_notice_inventory(entry)
  if not inv or not target_inventory or not target_inventory.insert then return end
  local count = inv.get_item_count and inv.get_item_count(NOTICE_ITEM) or 0
  if count <= 0 then return end
  local inserted = target_inventory.insert({name = NOTICE_ITEM, count = count}) or 0
  if inserted > 0 and inv.remove then
    inv.remove({name = NOTICE_ITEM, count = inserted})
  end
end

local function get_entity_notice_inventory(entity)
  if not entity or not entity.valid or not entity.get_inventory then return nil end
  local inventory_ids = defines.inventory and {
    defines.inventory.chest,
    defines.inventory.car_trunk,
    defines.inventory.spider_trunk,
    defines.inventory.cargo_wagon,
  } or {}
  for _, inventory_id in ipairs(inventory_ids) do
    if inventory_id then
      local ok, inventory = pcall(entity.get_inventory, inventory_id)
      if ok and inventory then return inventory end
    end
  end
  return nil
end

local function find_entities_at_position(surface, position, radius)
  if not surface or not surface.find_entities_filtered or not position then return {} end
  radius = radius or 1.0
  return surface.find_entities_filtered{
    area = {
      {position.x - radius, position.y - radius},
      {position.x + radius, position.y + radius},
    },
  }
end

local function find_field_agent_at_position(surface, position)
  for _, entity in ipairs(find_entities_at_position(surface, position, 0.75)) do
    if entity.valid and entity.name == C.HIRED_BITER_UNIT_NAME then
      return entity
    end
  end
  return nil
end

local function find_notice_source_entity(surface, position)
  for _, entity in ipairs(find_entities_at_position(surface, position, 1.0)) do
    local inventory = get_entity_notice_inventory(entity)
    if inventory then
      return inventory, entity
    end
  end
  return nil, nil
end

local function feed_entries_from_inventory(entries, source_inventory, player)
  if not source_inventory or not source_inventory.remove then return 0 end
  local total_moved = 0
  for _, entry in ipairs(entries) do
    local inventory = ensure_notice_inventory(entry)
    if inventory and inventory.insert then
      local current = get_notice_count(entry)
      local needed = notice_capacity() - current
      if needed > 0 then
        local removed = source_inventory.remove({name = NOTICE_ITEM, count = needed}) or 0
        if removed > 0 then
          local inserted = inventory.insert({name = NOTICE_ITEM, count = removed}) or 0
          if inserted < removed and source_inventory.insert then
            source_inventory.insert({name = NOTICE_ITEM, count = removed - inserted})
          end
          if inserted > 0 then
            total_moved = total_moved + inserted
            show_notice_feedback(entry, inserted, player)
          end
        end
      else
        show_notice_feedback(entry, 0, player)
      end
    end
  end
  return total_moved
end

local function feed_entry_from_entity(entry, source_entity, player)
  if not source_entity or not source_entity.valid then return 0 end
  local source_inventory = get_entity_notice_inventory(source_entity)
  if not source_inventory or not source_inventory.get_item_count or source_inventory.get_item_count(NOTICE_ITEM) <= 0 then
    show_notice_feedback(entry, 0, player)
    return 0
  end
  return feed_entries_from_inventory({entry}, source_inventory, player)
end

local function destroy_notice_inventory(entry)
  local inv = entry and entry.inventory
  if inv and (inv.valid == nil or inv.valid) and inv.destroy then
    inv.destroy()
  end
  if entry then entry.inventory = nil end
end

local function refill_from_logistics(entry)
  if not entry.entity or not entry.entity.valid then return end
  local inv = ensure_notice_inventory(entry)
  if not inv or not inv.insert then return end

  local current = inv.get_item_count and inv.get_item_count(NOTICE_ITEM) or 0
  local needed = notice_capacity() - current
  if needed <= 0 then return end

  local surface = entry.entity.surface
  if not surface or not surface.find_logistic_network_by_position then return end
  local network = surface.find_logistic_network_by_position(entry.entity.position, entry.entity.force)
  if not network or not network.remove_item then return end

  local removed = network.remove_item({name = NOTICE_ITEM, count = needed}) or 0
  if removed > 0 then
    inv.insert({name = NOTICE_ITEM, count = removed})
    show_notice_feedback(entry, removed)
  end
end

function M.on_deploy(surface, position)
  if not surface or not position then return false end
  local deploy_position = surface.find_non_colliding_position(C.HIRED_BITER_UNIT_NAME, position, 6, 0.5)
    or position
  local unit = surface.create_entity{
    name = C.HIRED_BITER_UNIT_NAME,
    position = deploy_position,
    force = "player",
    direction = defines.direction.south,
  }
  if not unit then return false end
  unit_ai_settings.apply_managed_unit_settings(unit)
  return track_entity(unit)
end

function M.track_entity(entity)
  if not entity or not entity.valid or entity.name ~= C.HIRED_BITER_UNIT_NAME then return false end
  unit_ai_settings.apply_managed_unit_settings(entity)
  return track_entity(entity)
end

function M.on_command(surface, position)
  local nearest, nearest_dist_sq = nil, math.huge
  for _, entry in pairs(storage.hired_biters or {}) do
    if entry.entity.valid and entry.entity.surface.index == surface.index then
      local dx = entry.entity.position.x - position.x
      local dy = entry.entity.position.y - position.y
      local d = dx * dx + dy * dy
      if d < nearest_dist_sq then
        nearest = entry
        nearest_dist_sq = d
      end
    end
  end
  if nearest then
    command_entry(nearest, position, false)
  end
end

function M.untrack(entity, event)
  if not storage.hired_biters or not entity then return end
  local entry = storage.hired_biters[entity.unit_number]
  if entry then
    transfer_notice_inventory(entry, event and event.buffer)
    destroy_notice_inventory(entry)
  end
  storage.hired_biters[entity.unit_number] = nil

  for player_index, selected in pairs(storage.hired_biter_selected or {}) do
    for i = #selected, 1, -1 do
      if selected[i] == entity.unit_number then
        table.remove(selected, i)
      end
    end
    if #selected == 0 then storage.hired_biter_selected[player_index] = nil end
  end
end

function M.cleanup_supply_chests()
  for _, surface in pairs(game.surfaces) do
    for _, chest in ipairs(surface.find_entities_filtered{name = SUPPLY_CHEST_NAME}) do
      if chest.valid then chest.destroy() end
    end
  end
end

local function remove_selected(player_index, unit_number)
  local selected = storage.hired_biter_selected and storage.hired_biter_selected[player_index]
  if not selected then return false end
  for i = #selected, 1, -1 do
    if selected[i] == unit_number then
      table.remove(selected, i)
      if #selected == 0 then storage.hired_biter_selected[player_index] = nil end
      return true
    end
  end
  return false
end

local function add_selected(player_index, unit_number)
  storage.hired_biter_selected[player_index] = storage.hired_biter_selected[player_index] or {}
  local selected = storage.hired_biter_selected[player_index]
  for _, existing in ipairs(selected) do
    if existing == unit_number then return false end
  end
  selected[#selected + 1] = unit_number
  return true
end

local function toggle_selection(player, surface, position)
  M.ensure_storage()
  local entity = find_field_agent_at_position(surface, position)
  if not entity then
    storage.hired_biter_selected[player.index] = nil
    return
  end

  if not track_entity(entity) then return end
  if remove_selected(player.index, entity.unit_number) then
    return
  else
    add_selected(player.index, entity.unit_number)
    show_notice_feedback(storage.hired_biters[entity.unit_number], 0, player)
  end
end

function M.on_player_selected_area(event)
  if event.item ~= C.HIRED_BITER_REMOTE_NAME then return end
  M.ensure_storage()
  local selected = {}
  for _, entity in ipairs(event.entities or {}) do
    if entity.valid and entity.name == C.HIRED_BITER_UNIT_NAME and track_entity(entity) then
      selected[#selected + 1] = entity.unit_number
    end
  end
  storage.hired_biter_selected[event.player_index] = selected

  if game and game.get_player then
    local player = game.get_player(event.player_index)
    for _, unit_number in ipairs(selected) do
      show_notice_feedback(storage.hired_biters[unit_number], 0, player)
    end
  end
end

function M.on_player_reverse_selected_area(event)
  if event.item ~= C.HIRED_BITER_REMOTE_NAME then return end
  -- Right-click is the command gesture for this remote. Selection is toggled by
  -- left-click/custom input, so reverse-select must not mutate selection.
end

local function selected_entries_for_player(player, surface)
  M.ensure_storage()
  local selected = storage.hired_biter_selected[player.index] or {}
  local entries = {}
  for _, unit_number in ipairs(selected) do
    local entry = storage.hired_biters and storage.hired_biters[unit_number]
    if entry and entry.entity and entry.entity.valid and entry.entity.surface == surface then
      entries[#entries + 1] = entry
    end
  end
  return entries
end

function M.on_remote_waypoint_input(event)
  if event.input_name ~= TOGGLE_SELECT_INPUT
     and event.input_name ~= SET_WAYPOINT_INPUT
     and event.input_name ~= APPEND_WAYPOINT_INPUT then return end
  if event.in_gui or not event.cursor_position then return end
  local player = game.get_player(event.player_index)
  if not player or not player.valid or not player_holds_remote(player) then return end

  local surface = player.surface
  if event.input_name == TOGGLE_SELECT_INPUT then
    toggle_selection(player, surface, event.cursor_position)
    return
  end

  if not is_position_charted(player.force, surface, event.cursor_position) then
    return
  end

  local entries = selected_entries_for_player(player, surface)
  if #entries == 0 then
    return
  end

  local append = event.input_name == APPEND_WAYPOINT_INPUT
  local _source_inventory, source_entity = find_notice_source_entity(surface, event.cursor_position)
  for _, entry in ipairs(entries) do
    command_entry(entry, source_entity and source_entity.position or event.cursor_position, append, source_entity)
  end
end

function M.on_ai_command_completed(event)
  local entry = storage.hired_biters and storage.hired_biters[event.unit_number]
  if not entry then return false end
  if entry.entity and entry.entity.valid and entry.state == "moving_to_command" then
    advance_waypoint(entry)
  elseif entry.entity and entry.entity.valid and entry.state == "moving_to_supply" then
    local source = entry.supply_entity
    local dest = entry.command_dest or (source and source.valid and source.position)
    if dest then
      local dx = entry.entity.position.x - dest.x
      local dy = entry.entity.position.y - dest.y
      if dx * dx + dy * dy <= C.HIRED_BITER_ARRIVE_RADIUS * C.HIRED_BITER_ARRIVE_RADIUS then
        feed_entry_from_entity(entry, source)
        advance_waypoint(entry)
      end
    end
  end
  return true
end

function M._set_destination(entity, position)
  if entity.commandable then
    entity.commandable.set_command{
      type = defines.command.go_to_location,
      destination = position,
      radius = C.HIRED_BITER_ARRIVE_RADIUS,
      distraction = defines.distraction.none,
    }
  end
end

function M.update(tick)
  for unit_number, entry in pairs(storage.hired_biters or {}) do
    if not entry.entity or not entry.entity.valid then
      destroy_notice_inventory(entry)
      storage.hired_biters[unit_number] = nil
    else
      refill_from_logistics(entry)
      M._update_entry(entry, tick)
    end
  end
end

function M._update_entry(entry, tick)
  local state = entry.state

  if state == "exploring" then
    if entry.waypoints and #entry.waypoints > 0 then
      advance_waypoint(entry)
      return
    end
    if tick - entry.last_scan_tick >= C.HIRED_BITER_SCAN_COOLDOWN then
      entry.last_scan_tick = tick
      if get_notice_count(entry) > 0 then
        local nests = entry.entity.surface.find_entities_filtered{
          type = "unit-spawner",
          force = "enemy",
          position = entry.entity.position,
          radius = C.HIRED_BITER_SCAN_RADIUS,
          limit = 1,
        }
        if nests[1] and nests[1].valid then
          entry.state = "moving_to_nest"
          entry.target_nest = nests[1]
          M._set_destination(entry.entity, nests[1].position)
        end
      end
    end

  elseif state == "moving_to_command" then
    local dest = entry.command_dest
    if not dest then
      advance_waypoint(entry)
      return
    end
    local dx = entry.entity.position.x - dest.x
    local dy = entry.entity.position.y - dest.y
    if dx * dx + dy * dy <= C.HIRED_BITER_ARRIVE_RADIUS * C.HIRED_BITER_ARRIVE_RADIUS then
      advance_waypoint(entry)
    end

  elseif state == "moving_to_supply" then
    local source = entry.supply_entity
    if not source or not source.valid then
      advance_waypoint(entry)
      return
    end
    local dest = entry.command_dest or source.position
    local dx = entry.entity.position.x - dest.x
    local dy = entry.entity.position.y - dest.y
    if dx * dx + dy * dy <= C.HIRED_BITER_ARRIVE_RADIUS * C.HIRED_BITER_ARRIVE_RADIUS then
      feed_entry_from_entity(entry, source)
      advance_waypoint(entry)
    end

  elseif state == "moving_to_nest" then
    if not entry.target_nest or not entry.target_nest.valid then
      entry.state = "exploring"
      entry.target_nest = nil
      return
    end
    local dx = entry.entity.position.x - entry.target_nest.position.x
    local dy = entry.entity.position.y - entry.target_nest.position.y
    if dx * dx + dy * dy <= C.HIRED_BITER_ARRIVE_RADIUS * C.HIRED_BITER_ARRIVE_RADIUS then
      if consume_notice(entry) then
        biters.evict_target(entry.entity.surface, entry.target_nest)
        entry.notices_delivered = entry.notices_delivered + 1
      end
      entry.target_nest = nil
      entry.state = "exploring"
      entry.last_scan_tick = tick
    end
  end
end

return M
