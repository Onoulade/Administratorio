local shared = require("scripts.fax_shared")

local M = {}

local RED_WIRE = function()
  return defines.wire_connector_id and defines.wire_connector_id.circuit_red
end

local GREEN_WIRE = function()
  return defines.wire_connector_id and defines.wire_connector_id.circuit_green
end

local function get_quality_name(stack)
  if not stack then return nil end
  local quality = stack.quality
  if type(quality) == "table" then
    return quality.name
  end
  return quality
end

local function ensure_storage()
  storage.fax_receivers = storage.fax_receivers or {}
  storage.fax_receivers_by_planet = storage.fax_receivers_by_planet or {}
  storage.fax_emitters = storage.fax_emitters or {}
  storage.fax_gui_players = storage.fax_gui_players or {}
end

local function is_fax_name(name)
  return name == shared.RECEIVER_NAME or name == shared.EMITTER_NAME
end

local function connect_combinator(entity, combinator)
  if not entity or not entity.valid or not combinator or not combinator.valid then return end
  if not entity.get_wire_connector or not combinator.get_wire_connector then return end

  local entity_red = entity.get_wire_connector(RED_WIRE(), true)
  local entity_green = entity.get_wire_connector(GREEN_WIRE(), true)
  local combinator_red = combinator.get_wire_connector(RED_WIRE(), true)
  local combinator_green = combinator.get_wire_connector(GREEN_WIRE(), true)

  if entity_red and combinator_red then entity_red.connect_to(combinator_red) end
  if entity_green and combinator_green then entity_green.connect_to(combinator_green) end
end

local function ensure_combinator(entity, state)
  if not entity or not entity.valid or not state then return nil end
  local combinator = state.combinator
  if not combinator or not combinator.valid then
    combinator = entity.surface.create_entity{
      name = shared.COMBINATOR_NAME,
      position = entity.position,
      force = entity.force,
    }
    if combinator then
      combinator.destructible = false
      state.combinator = combinator
    end
  end

  connect_combinator(entity, combinator)
  return combinator
end

local function destroy_combinator(state)
  if state and state.combinator and state.combinator.valid then
    state.combinator.destroy()
  end
  if state then
    state.combinator = nil
  end
end

local function get_inventory(entity)
  if not entity or not entity.valid or not entity.get_inventory then return nil end
  return entity.get_inventory(defines.inventory.chest)
end

local function inventory_has_item(inventory, item_name, count)
  if not inventory or not item_name then return false end
  if inventory.get_item_count then
    return (inventory.get_item_count(item_name) or 0) >= (count or 1)
  end

  local remaining = count or 1
  for index = 1, #inventory do
    local stack = inventory[index]
    if stack and stack.valid_for_read and stack.name == item_name then
      remaining = remaining - (stack.count or 0)
      if remaining <= 0 then
        return true
      end
    end
  end
  return false
end

local function remove_one_item(inventory, item_name)
  if not inventory or not item_name then return false end
  if inventory.remove then
    return (inventory.remove{name = item_name, count = 1} or 0) > 0
  end

  for index = 1, #inventory do
    local stack = inventory[index]
    if stack and stack.valid_for_read and stack.name == item_name and (stack.count or 0) > 0 then
      stack.count = stack.count - 1
      return true
    end
  end

  return false
end

local function can_insert_stack(inventory, stack)
  if not inventory or not stack then return false end
  if inventory.can_insert then
    return inventory.can_insert(stack)
  end

  for index = 1, #inventory do
    local existing = inventory[index]
    if not existing or not existing.valid_for_read then
      return true
    end
    if existing.name == stack.name and get_quality_name(existing) == stack.quality then
      return true
    end
  end

  return false
end

local function insert_stack(inventory, stack)
  if not inventory or not inventory.insert or not stack then return 0 end
  return inventory.insert(stack) or 0
end

local function find_first_faxable_stack(inventory)
  if not inventory then return nil, nil end
  for slot = 1, #inventory do
    local stack = inventory[slot]
    if stack and stack.valid_for_read and shared.is_faxable_item_name(stack.name) then
      return slot, stack
    end
  end
  return nil, nil
end

local function remove_stack_from_slot(inventory, slot_index, item_name, quality_name)
  if not inventory or not slot_index then return false end
  local stack = inventory[slot_index]
  if not stack or not stack.valid_for_read then return false end
  if stack.name ~= item_name or get_quality_name(stack) ~= quality_name then
    return false
  end
  stack.count = stack.count - 1
  return true
end

local function spill_document(entity, buffer, entry)
  if not entity or not entity.valid or not entry then return end
  local stack = {
    name = entry.name,
    count = 1,
    quality = entry.quality_name,
  }

  if buffer and buffer.insert then
    local inserted = buffer.insert(stack) or 0
    if inserted > 0 then
      return
    end
  end

  entity.surface.spill_item_stack{
    position = entity.position,
    stack = stack,
    enable_looted = true,
    force = entity.force,
  }
end

local function get_receiver_total_load(state)
  if not state then return 0 end
  return #(state.queue or {}) + (state.active_print and 1 or 0)
end

local function build_reserved_counts()
  local reserved = {}
  for _, emitter_state in pairs(storage.fax_emitters or {}) do
    local job = emitter_state.current_job
    if emitter_state.entity and emitter_state.entity.valid and job and job.destination_planet then
      reserved[job.destination_planet] = (reserved[job.destination_planet] or 0) + 1
    end
  end
  return reserved
end

local function get_receiver_state_for_planet(planet_name)
  local unit_number = storage.fax_receivers_by_planet[planet_name]
  local state = unit_number and storage.fax_receivers[unit_number] or nil
  if state and state.entity and state.entity.valid then
    return state
  end
  return nil
end

local function clear_output_section(state)
  if not state or not state.combinator or not state.combinator.valid then return end
  local behavior = state.combinator.get_or_create_control_behavior and state.combinator.get_or_create_control_behavior()
  if not behavior then return end
  local section = behavior.get_section and behavior.get_section(1) or nil
  if not section and behavior.add_section then
    section = behavior.add_section()
  end
  if not section then return end
  for slot = 1, 4 do
    section.clear_slot(slot)
  end
  state.output_counts = {}
end

local function set_output_section(state, slots)
  if not state or not state.combinator or not state.combinator.valid then return end
  local behavior = state.combinator.get_or_create_control_behavior and state.combinator.get_or_create_control_behavior()
  if not behavior then return end
  local section = behavior.get_section and behavior.get_section(1) or nil
  if not section and behavior.add_section then
    section = behavior.add_section()
  end
  if not section then return end

  state.output_counts = {}
  for index = 1, 4 do
    local slot = slots[index]
    if slot and slot.signal and slot.count and slot.count > 0 then
      section.set_slot(index, {value = slot.signal, min = slot.count})
      local key = shared.make_signal_key(slot.signal)
      if key then
        state.output_counts[key] = slot.count
      end
    else
      section.clear_slot(index)
    end
  end
end

local function build_receiver_slots(state, reserved_counts)
  local queued = get_receiver_total_load(state)
  local reserved = (reserved_counts and reserved_counts[state.planet_name]) or 0
  local capacity = shared.get_queue_capacity(state.entity.force)
  local free = math.max(0, capacity - queued - reserved)

  return {
    {
      signal = {type = "virtual", name = shared.SIGNAL_QUEUE_SIZE},
      count = queued,
    },
    {
      signal = {type = "virtual", name = shared.SIGNAL_FREE_SLOTS},
      count = free,
    },
    {
      signal = {type = "virtual", name = shared.SIGNAL_RESERVED_SLOTS},
      count = reserved,
    },
    state.current_request_signal and {
      signal = state.current_request_signal,
      count = state.current_request_count,
    } or nil,
  }
end

local function build_emitter_slots(state, reserved_counts)
  local receiver_state = get_receiver_state_for_planet(state.destination_planet)
  if not receiver_state then
    return {
      nil,
      nil,
      nil,
      nil,
    }
  end

  local queued = get_receiver_total_load(receiver_state)
  local reserved = (reserved_counts and reserved_counts[state.destination_planet]) or 0
  local capacity = shared.get_queue_capacity(receiver_state.entity.force)
  local free = math.max(0, capacity - queued - reserved)

  return {
    {
      signal = {type = "virtual", name = shared.SIGNAL_QUEUE_SIZE},
      count = queued,
    },
    {
      signal = {type = "virtual", name = shared.SIGNAL_FREE_SLOTS},
      count = free,
    },
    {
      signal = {type = "virtual", name = shared.SIGNAL_RESERVED_SLOTS},
      count = reserved,
    },
    receiver_state.current_request_signal and {
      signal = receiver_state.current_request_signal,
      count = receiver_state.current_request_count,
    } or nil,
  }
end

local function refresh_receiver_request(state)
  if not state or not state.entity or not state.entity.valid or not state.entity.get_signals then
    return
  end

  local signals = state.entity.get_signals(RED_WIRE(), GREEN_WIRE()) or {}
  state.current_request_signal, state.current_request_count = shared.select_request_signal(signals, state.output_counts)
end

local function register_receiver(entity)
  local planet_name = shared.get_planet_name(entity.surface)
  if not planet_name then
    return nil, "This fax receiver can only be placed on a real planet surface."
  end

  local current = get_receiver_state_for_planet(planet_name)
  if current and current.entity.unit_number ~= entity.unit_number then
    return nil, "This planet already has a fax receiver."
  end

  local state = storage.fax_receivers[entity.unit_number]
  if not state then
    state = {
      queue = {},
      output_counts = {},
    }
    storage.fax_receivers[entity.unit_number] = state
  end

  state.entity = entity
  state.planet_name = planet_name
  state.queue = state.queue or {}
  state.output_counts = state.output_counts or {}
  ensure_combinator(entity, state)

  storage.fax_receivers_by_planet[planet_name] = entity.unit_number
  return state
end

local function default_destination_for_entity(entity)
  local source_planet = shared.get_planet_name(entity and entity.surface)
  if source_planet then return source_planet end

  local planets = shared.collect_planet_names(game)
  return planets[1]
end

local function register_emitter(entity)
  local planet_name = shared.get_planet_name(entity.surface)
  if not planet_name then
    return nil, "Fax emitters can only be placed on a real planet surface."
  end

  local state = storage.fax_emitters[entity.unit_number]
  if not state then
    state = {
      output_counts = {},
    }
    storage.fax_emitters[entity.unit_number] = state
  end

  state.entity = entity
  state.planet_name = planet_name
  state.destination_planet = state.destination_planet or default_destination_for_entity(entity)
  state.output_counts = state.output_counts or {}
  ensure_combinator(entity, state)

  return state
end

local function return_item_or_spill(entity, player)
  if not entity or not entity.valid then return end
  local stack = {
    name = entity.name,
    count = 1,
    quality = entity.quality and entity.quality.name or nil,
  }

  if player and player.valid and player.insert then
    local inserted = player.insert(stack) or 0
    if inserted > 0 then
      return
    end
  end

  entity.surface.spill_item_stack{
    position = entity.position,
    stack = stack,
    enable_looted = true,
    force = entity.force,
  }
end

local function destroy_gui(player)
  if not player or not player.valid or not player.gui or not player.gui.left then return end
  local frame = player.gui.left[shared.GUI_FRAME_NAME]
  if frame and frame.valid then
    frame.destroy()
  end
  storage.fax_gui_players[player.index] = nil
end

local function build_emitter_gui(player, state)
  destroy_gui(player)
  if not player or not player.valid or not state or not state.entity or not state.entity.valid then return end

  local frame = player.gui.left.add{
    type = "frame",
    name = shared.GUI_FRAME_NAME,
    direction = "vertical",
    caption = "Fax Emitter",
  }
  frame.add{
    type = "label",
    caption = "Destination planet",
  }

  local planet_names = shared.collect_planet_names(game)
  if #planet_names == 0 then
    planet_names = {state.destination_planet or "nauvis"}
  end

  local captions = {}
  local selected_index = 1
  for index, planet_name in ipairs(planet_names) do
    captions[index] = shared.format_planet_name(planet_name)
    if planet_name == state.destination_planet then
      selected_index = index
    end
  end

  frame.add{
    type = "drop-down",
    name = shared.GUI_DROPDOWN_NAME,
    items = captions,
    selected_index = selected_index,
  }

  storage.fax_gui_players[player.index] = {
    emitter_unit_number = state.entity.unit_number,
    planet_names = planet_names,
  }
end

local function cleanup_invalid_state()
  for unit_number, state in pairs(storage.fax_receivers) do
    if not state.entity or not state.entity.valid then
      destroy_combinator(state)
      storage.fax_receivers[unit_number] = nil
      if state.planet_name and storage.fax_receivers_by_planet[state.planet_name] == unit_number then
        storage.fax_receivers_by_planet[state.planet_name] = nil
      end
    end
  end

  for unit_number, state in pairs(storage.fax_emitters) do
    if not state.entity or not state.entity.valid then
      destroy_combinator(state)
      storage.fax_emitters[unit_number] = nil
    end
  end
end

local function process_emitter_jobs(tick)
  for _, state in pairs(storage.fax_emitters) do
    local job = state.current_job
    if job and tick >= job.complete_tick then
      local receiver_state = get_receiver_state_for_planet(job.destination_planet)
      local inventory = get_inventory(state.entity)
      if not receiver_state or receiver_state.entity.force ~= state.entity.force then
        state.current_job = nil
      elseif remove_stack_from_slot(inventory, job.slot_index, job.item_name, job.quality_name) then
        receiver_state.queue[#receiver_state.queue + 1] = {
          name = job.item_name,
          quality_name = job.quality_name,
          source_planet = job.source_planet,
        }
        state.current_job = nil
      else
        state.current_job = nil
      end
    end
  end
end

local function process_new_emitter_jobs(tick, reserved_counts)
  for _, state in pairs(storage.fax_emitters) do
    if not state.current_job then
      local receiver_state = get_receiver_state_for_planet(state.destination_planet)
      if receiver_state and receiver_state.entity.force == state.entity.force then
        local capacity = shared.get_queue_capacity(receiver_state.entity.force)
        local total_load = get_receiver_total_load(receiver_state)
        local reserved = reserved_counts[state.destination_planet] or 0
        if total_load + reserved < capacity then
          local inventory = get_inventory(state.entity)
          local slot_index, stack = find_first_faxable_stack(inventory)
          if slot_index and stack then
            state.current_job = {
              slot_index = slot_index,
              item_name = stack.name,
              quality_name = get_quality_name(stack),
              destination_planet = state.destination_planet,
              source_planet = state.planet_name,
              complete_tick = tick + shared.TRANSMIT_TICKS,
            }
            reserved_counts[state.destination_planet] = reserved + 1
          end
        end
      end
    end
  end
end

local function process_receivers(tick)
  for _, state in pairs(storage.fax_receivers) do
    local inventory = get_inventory(state.entity)
    if inventory then
      if state.active_print then
        if tick >= state.active_print.ready_tick then
          local stack = {
            name = state.active_print.name,
            count = 1,
            quality = state.active_print.quality_name,
          }
          if can_insert_stack(inventory, stack) and insert_stack(inventory, stack) > 0 then
            state.active_print = nil
          end
        end
      elseif #(state.queue or {}) > 0 then
        local next_entry = state.queue[1]
        local output_stack = {
          name = next_entry.name,
          count = 1,
          quality = next_entry.quality_name,
        }
        if can_insert_stack(inventory, output_stack)
          and inventory_has_item(inventory, "paper", 1)
          and inventory_has_item(inventory, "ink", 1)
        then
          remove_one_item(inventory, "paper")
          remove_one_item(inventory, "ink")
          state.active_print = table.remove(state.queue, 1)
          state.active_print.ready_tick = tick + shared.PRINT_TICKS
        end
      end
    end
  end
end

local function refresh_outputs(reserved_counts)
  for _, state in pairs(storage.fax_receivers) do
    set_output_section(state, build_receiver_slots(state, reserved_counts))
  end

  for _, state in pairs(storage.fax_emitters) do
    set_output_section(state, build_emitter_slots(state, reserved_counts))
  end
end

function M.ensure_storage()
  ensure_storage()
end

function M.is_fax_building(entity_or_name)
  local name = type(entity_or_name) == "string" and entity_or_name or (entity_or_name and entity_or_name.name)
  return is_fax_name(name)
end

function M.rebuild_registry()
  ensure_storage()

  local seen_receivers = {}
  local seen_emitters = {}
  storage.fax_receivers_by_planet = {}

  for _, surface in pairs(game.surfaces or {}) do
    for _, entity in ipairs(surface.find_entities_filtered{name = shared.RECEIVER_NAME}) do
      if entity.valid then
        local state = register_receiver(entity)
        if state then
          seen_receivers[entity.unit_number] = true
        end
      end
    end

    for _, entity in ipairs(surface.find_entities_filtered{name = shared.EMITTER_NAME}) do
      if entity.valid then
        local state = register_emitter(entity)
        if state then
          seen_emitters[entity.unit_number] = true
        end
      end
    end
  end

  for unit_number, state in pairs(storage.fax_receivers) do
    if not seen_receivers[unit_number] then
      destroy_combinator(state)
      storage.fax_receivers[unit_number] = nil
    end
  end

  for unit_number, state in pairs(storage.fax_emitters) do
    if not seen_emitters[unit_number] then
      destroy_combinator(state)
      storage.fax_emitters[unit_number] = nil
    end
  end
end

function M.on_entity_built(entity, player)
  ensure_storage()
  if not entity or not entity.valid or not is_fax_name(entity.name) then
    return true
  end

  local ok, reason
  if entity.name == shared.RECEIVER_NAME then
    ok, reason = register_receiver(entity)
  else
    ok, reason = register_emitter(entity)
  end

  if ok then
    return true
  end

  if player and player.valid and player.print then
    player.print(reason)
  end
  return_item_or_spill(entity, player)
  entity.destroy()
  return false
end

function M.on_entity_removed(entity, buffer)
  ensure_storage()
  if not entity or not is_fax_name(entity.name) then return end

  if entity.name == shared.RECEIVER_NAME then
    local state = storage.fax_receivers[entity.unit_number]
    if state then
      for _, entry in ipairs(state.queue or {}) do
        spill_document(entity, buffer, entry)
      end
      if state.active_print then
        spill_document(entity, buffer, state.active_print)
      end
      if state.planet_name and storage.fax_receivers_by_planet[state.planet_name] == entity.unit_number then
        storage.fax_receivers_by_planet[state.planet_name] = nil
      end
      destroy_combinator(state)
      storage.fax_receivers[entity.unit_number] = nil
    end
  else
    local state = storage.fax_emitters[entity.unit_number]
    if state then
      destroy_combinator(state)
      storage.fax_emitters[entity.unit_number] = nil
    end
  end
end

function M.on_tick(event)
  ensure_storage()
  cleanup_invalid_state()

  for _, state in pairs(storage.fax_receivers) do
    refresh_receiver_request(state)
  end

  process_emitter_jobs(event.tick)
  local reserved_counts = build_reserved_counts()
  process_new_emitter_jobs(event.tick, reserved_counts)
  process_receivers(event.tick)
  refresh_outputs(reserved_counts)
end

function M.on_selected_entity_changed(player, entity)
  ensure_storage()
  if not player or not player.valid then return end

  if entity and entity.valid and entity.name == shared.EMITTER_NAME then
    local state = storage.fax_emitters[entity.unit_number]
    if state then
      build_emitter_gui(player, state)
      return
    end
  end

  destroy_gui(player)
end

function M.on_gui_selection_state_changed(event)
  ensure_storage()
  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end
  local element = event.element
  if not element or not element.valid or element.name ~= shared.GUI_DROPDOWN_NAME then return end

  local gui_state = storage.fax_gui_players[player.index]
  if not gui_state then return end

  local emitter_state = storage.fax_emitters[gui_state.emitter_unit_number]
  if not emitter_state or not emitter_state.entity or not emitter_state.entity.valid then
    destroy_gui(player)
    return
  end

  local destination_planet = gui_state.planet_names[element.selected_index]
  if destination_planet then
    emitter_state.destination_planet = destination_planet
  end
end

return M
