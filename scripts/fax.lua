local shared = require("scripts.fax_shared")

local M = {}

local RED_WIRE = function()
  return defines.wire_connector_id and defines.wire_connector_id.circuit_red
end

local GREEN_WIRE = function()
  return defines.wire_connector_id and defines.wire_connector_id.circuit_green
end

local EMITTER_DELIVERED_STATUS_TICKS = 180
local RECEIVER_REQUEST_LIMIT = 6

local function get_quality_name(stack)
  if not stack then return nil end
  local quality = stack.quality
  if quality and type(quality) ~= "string" and quality.name then
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

local function get_emitter_inventory(entity)
  if not entity or not entity.valid or not entity.get_inventory then return nil end
  return entity.get_inventory(defines.inventory.chest)
end

local function get_entity_inventory(entity, inventory_ids)
  if not entity or not entity.valid or not entity.get_inventory then return nil end
  local inventory_defs = defines and defines.inventory or {}

  for _, inventory_name in ipairs(inventory_ids) do
    local inventory_id = inventory_defs[inventory_name]
    if inventory_id ~= nil then
      local inventory = entity.get_inventory(inventory_id)
      if inventory then
        return inventory
      end
    end
  end

  return nil
end

local function get_receiver_input_inventory(entity)
  return get_entity_inventory(entity, {
    "assembling_machine_input",
    "furnace_source",
    "chest",
  })
end

local function get_receiver_output_inventory(entity)
  return get_entity_inventory(entity, {
    "assembling_machine_output",
    "furnace_result",
    "chest",
  })
end

local function get_receiver_fluidbox(entity)
  if not entity or not entity.valid then return nil end
  return entity.fluidbox
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

local function take_stack_from_slot(inventory, slot_index, item_name, quality_name)
  if remove_stack_from_slot(inventory, slot_index, item_name, quality_name) then
    return {
      name = item_name,
      count = 1,
      quality = quality_name,
    }
  end
  return nil
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

local function spill_job_document(entity, buffer, job)
  if not job then return end
  spill_document(entity, buffer, {
    name = job.item_name,
    quality_name = job.quality_name,
  })
end

local function return_job_document_to_emitter(state, job)
  if not state or not state.entity or not state.entity.valid or not job then return false end
  local inventory = get_emitter_inventory(state.entity)
  local stack = {
    name = job.item_name,
    count = 1,
    quality = job.quality_name,
  }

  if can_insert_stack(inventory, stack) and insert_stack(inventory, stack) > 0 then
    return true
  end

  spill_job_document(state.entity, nil, job)
  return false
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

local function sanitize_output_signal(signal)
  if not signal then return nil end
  if type(signal) == "string" then return signal end
  return signal.name
end

local function clone_signal(signal, fallback_type, fallback_name)
  if type(signal) == "string" then
    return {
      type = fallback_type or "virtual",
      name = signal,
    }
  end
  if signal and signal.name then
    return {
      type = signal.type or fallback_type or "virtual",
      name = signal.name,
      quality = signal.quality,
    }
  end
  if fallback_name then
    return {
      type = fallback_type or "virtual",
      name = fallback_name,
    }
  end
  return nil
end

local function get_receiver_output_signal(state, kind)
  if kind == "queue" then
    return clone_signal(state and state.queue_size_signal, "virtual", shared.SIGNAL_QUEUE_SIZE)
  end
  if kind == "free" then
    return clone_signal(state and state.free_slots_signal, "virtual", shared.SIGNAL_FREE_SLOTS)
  end
  if kind == "reserved" then
    return clone_signal(state and state.reserved_slots_signal, "virtual", shared.SIGNAL_RESERVED_SLOTS)
  end
  return nil
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
      section.set_slot(index, {value = sanitize_output_signal(slot.signal), min = slot.count})
      local key = shared.make_signal_key(slot.signal)
      if key then
        state.output_counts[key] = slot.count
      end
    else
      section.clear_slot(index)
    end
  end
end

local function append_output_slot(slots, signal, count)
  if signal and count and count > 0 then
    slots[#slots + 1] = {
      signal = signal,
      count = count,
    }
  end
end

local function build_receiver_slots(state, reserved_counts)
  local slots = {}
  local queued = get_receiver_total_load(state)
  local reserved = (reserved_counts and reserved_counts[state.planet_name]) or 0
  local capacity = shared.get_queue_capacity(state.entity.force)
  local free = math.max(0, capacity - queued - reserved)

  if state.read_queue_status ~= false then
    append_output_slot(slots, get_receiver_output_signal(state, "queue"), queued)
    append_output_slot(slots, get_receiver_output_signal(state, "free"), free)
    append_output_slot(slots, get_receiver_output_signal(state, "reserved"), reserved)
  end
  if state.read_top_request ~= false then
    append_output_slot(slots, state.current_request_signal, state.current_request_count)
  end

  return slots
end

local function build_emitter_slots(state, reserved_counts)
  local receiver_state = get_receiver_state_for_planet(state.destination_planet)
  if not receiver_state then
    return {}
  end

  local slots = {}
  local queued = get_receiver_total_load(receiver_state)
  local reserved = (reserved_counts and reserved_counts[state.destination_planet]) or 0
  local capacity = shared.get_queue_capacity(receiver_state.entity.force)
  local free = math.max(0, capacity - queued - reserved)

  if receiver_state.read_queue_status ~= false then
    append_output_slot(slots, get_receiver_output_signal(receiver_state, "queue"), queued)
    append_output_slot(slots, get_receiver_output_signal(receiver_state, "free"), free)
    append_output_slot(slots, get_receiver_output_signal(receiver_state, "reserved"), reserved)
  end
  if receiver_state.read_top_request ~= false then
    append_output_slot(slots, receiver_state.current_request_signal, receiver_state.current_request_count)
  end

  return slots
end

local function format_document_label(item_name, quality_name)
  if not item_name then return "Unknown document" end
  local normalized_quality = quality_name
  if normalized_quality and type(normalized_quality) ~= "string" then
    normalized_quality = normalized_quality.name or tostring(normalized_quality)
  end
  local label = item_name:gsub("%-", " "):gsub("^%l", string.upper)
  if normalized_quality and normalized_quality ~= "" and normalized_quality ~= "normal" then
    return ("%s (%s)"):format(label, normalized_quality)
  end
  return label
end

local function get_receiver_active_entry(state)
  if not state then return nil end
  return state.active_print or (state.queue and state.queue[1]) or nil
end

local function receiver_entry_is_research_ready(state, entry)
  if not state or not entry then return false end
  return shared.can_force_fax_document(state.entity and state.entity.force, entry.name)
end

local function get_receiver_supply_snapshot(state, entry)
  local input_inventory = state and state.entity and get_receiver_input_inventory(state.entity) or nil
  local fluidbox = state and state.entity and get_receiver_fluidbox(state.entity) or nil
  local required_by_name = {}
  for _, fluid in ipairs(shared.get_document_ink_requirements(entry and entry.name or nil)) do
    required_by_name[fluid.name] = fluid
  end

  local snapshot = {
    paper = inventory_has_item(input_inventory, shared.RECONSTRUCTION_PAPER_ITEM, 1),
    paper_required = entry ~= nil,
    paper_count = input_inventory and input_inventory.get_item_count and input_inventory.get_item_count(shared.RECONSTRUCTION_PAPER_ITEM) or 0,
    fluids = {},
    missing_fluids = {},
  }

  for _, fluid in ipairs(shared.RECONSTRUCTION_INK_FLUIDS) do
    local required = required_by_name[fluid.name]
    local available = fluid_amount(fluidbox, fluid.name)
    local is_required = required ~= nil
    local fluid_state = {
      id = fluid.id,
      name = fluid.name,
      label = fluid.label,
      available = available,
      required = required and required.amount or 0,
      is_required = is_required,
      ready = not is_required or available >= (required.amount or 0),
    }
    snapshot.fluids[#snapshot.fluids + 1] = fluid_state
    if fluid_state.is_required and not fluid_state.ready then
      snapshot.missing_fluids[#snapshot.missing_fluids + 1] = fluid_state.label
    end
  end

  return snapshot
end

local function receiver_missing_supplies_text(snapshot)
  if not snapshot then return nil end
  local missing = {}
  if snapshot.paper_required and not snapshot.paper then
    missing[#missing + 1] = "thermal transfer sheet"
  end
  for _, fluid_label in ipairs(snapshot.missing_fluids or {}) do
    missing[#missing + 1] = fluid_label
  end
  if #missing == 0 then
    return nil
  end
  return table.concat(missing, ", ")
end

local function receiver_output_stack(entry)
  return {
    name = entry.name,
    count = 1,
    quality = entry.quality_name,
  }
end

local function receiver_can_output_entry(state, entry)
  if not state or not state.entity or not entry then return false end
  local output_inventory = get_receiver_output_inventory(state.entity)
  return can_insert_stack(output_inventory, receiver_output_stack(entry))
end

local function receiver_has_required_supplies(state, entry)
  local snapshot = get_receiver_supply_snapshot(state, entry)
  local has_paper = (not snapshot.paper_required) or snapshot.paper
  return has_paper and #(snapshot.missing_fluids or {}) == 0, snapshot
end

local function consume_receiver_supplies(state, entry)
  if not entry then return false end
  local input_inventory = state and state.entity and get_receiver_input_inventory(state.entity) or nil
  local fluidbox = state and state.entity and get_receiver_fluidbox(state.entity) or nil
  local has_supplies = receiver_has_required_supplies(state, entry)
  if not has_supplies then return false end
  if not remove_one_item(input_inventory, shared.RECONSTRUCTION_PAPER_ITEM) then
    return false
  end
  for _, fluid in ipairs(shared.get_document_ink_requirements(entry.name)) do
    remove_fluid(fluidbox, fluid.name, fluid.amount)
  end
  return true
end

local function set_receiver_recipe(state, entry)
  local entity = state and state.entity or nil
  if not entity or not entity.valid or not entity.set_recipe then return end
  local recipe_name = nil
  if entry and receiver_entry_is_research_ready(state, entry) then
    recipe_name = shared.reconstruction_recipe_name(entry.name)
  end
  local current_recipe = entity.get_recipe and entity.get_recipe() or nil
  local current_name = current_recipe and current_recipe.name or nil
  if current_name == recipe_name then return end
  entity.set_recipe(recipe_name)
end

local function sync_receiver_recipe(state)
  if not state or not state.entity or not state.entity.valid then return end
  set_receiver_recipe(state, get_receiver_active_entry(state))
  if state.entity.active ~= nil then
    state.entity.active = false
  end
end

local function compute_print_progress(entry, tick)
  if not entry or not tick or not entry.ready_tick then return 0 end
  local start_tick = entry.start_tick or tick
  local duration = math.max(1, entry.ready_tick - start_tick)
  local elapsed = math.max(0, math.min(duration, tick - start_tick))
  return math.floor(elapsed * 100 / duration)
end

local function compute_receiver_feedback(state, tick)
  if not state or not state.entity or not state.entity.valid then
    return {
      gui_label = "Receiver unavailable",
    }
  end

  local queued = #(state.queue or {})
  local capacity = shared.get_queue_capacity(state.entity.force)
  local load = queued + (state.active_print and 1 or 0)

  if state.active_print then
    if tick and state.active_print.ready_tick and tick < state.active_print.ready_tick then
      local pct = compute_print_progress(state.active_print, tick)
      local label = ("Printing %s (%d%%)"):format(
        format_document_label(state.active_print.name, state.active_print.quality_name),
        pct)
      return {
        entity_label = label,
        gui_label = ("%s. Queue %d/%d"):format(label, load, capacity),
        diode = "yellow",
      }
    end

    if not receiver_can_output_entry(state, state.active_print) then
      local label = ("Output blocked for %s"):format(format_document_label(state.active_print.name, state.active_print.quality_name))
      return {
        entity_label = label,
        gui_label = label,
        diode = "red",
      }
    end

    local label = ("Finalizing %s"):format(format_document_label(state.active_print.name, state.active_print.quality_name))
    return {
      entity_label = label,
      gui_label = label,
      diode = "yellow",
    }
  end

  if queued > 0 then
    local next_entry = state.queue[1]
    if not receiver_entry_is_research_ready(state, next_entry) then
      local label = ("Awaiting Color Faxing for %s"):format(format_document_label(next_entry.name, next_entry.quality_name))
      return {
        entity_label = label,
        gui_label = ("%s. Queue %d/%d"):format(label, load, capacity),
        diode = "yellow",
      }
    end

    if not receiver_can_output_entry(state, next_entry) then
      local label = ("Output slot occupied for %s"):format(format_document_label(next_entry.name, next_entry.quality_name))
      return {
        entity_label = label,
        gui_label = label,
        diode = "red",
      }
    end

    local has_supplies, snapshot = receiver_has_required_supplies(state, next_entry)
    if not has_supplies then
      local missing = receiver_missing_supplies_text(snapshot)
      local label = ("Waiting for %s"):format(missing or "supplies")
      return {
        entity_label = label,
        gui_label = ("%s. Queue %d/%d"):format(label, load, capacity),
        diode = "yellow",
      }
    end

    local label = ("Ready to print %s"):format(format_document_label(next_entry.name, next_entry.quality_name))
    return {
      entity_label = label,
      gui_label = ("%s. Queue %d/%d"):format(label, load, capacity),
      diode = "green",
    }
  end

  if state.current_request_signal then
    local label = ("Idle. Requesting %s x%d"):format(
      format_document_label(state.current_request_signal.name, state.current_request_signal.quality),
      state.current_request_count or 0)
    return {
      entity_label = "Idle",
      gui_label = label,
      diode = "green",
    }
  end

  if state.accept_circuit_requests == false then
    return {
      entity_label = "Idle",
      gui_label = "Idle. Circuit requests disabled",
      diode = "yellow",
    }
  end

  return {
    entity_label = "Idle",
    gui_label = "Idle. Queue empty",
    diode = "green",
  }
end

local function get_status_diode(color_name)
  local diodes = defines and defines.entity_status_diode or nil
  if not diodes then return nil end
  return diodes[color_name] or diodes.yellow or diodes.green or diodes.red
end

local function compute_emitter_feedback(state, tick, reserved_counts)
  if not state or not state.entity or not state.entity.valid then
    return {
      gui_label = "Emitter unavailable",
    }
  end

  local destination_name = shared.format_planet_name(state.destination_planet)
  if state.current_job then
    local start_tick = state.current_job.start_tick
      or math.max(0, (state.current_job.complete_tick or tick or 0) - shared.TRANSMIT_TICKS)
    local complete_tick = state.current_job.complete_tick or start_tick
    local duration = math.max(1, complete_tick - start_tick)
    local elapsed = math.max(0, math.min(duration, (tick or complete_tick) - start_tick))
    local pct = math.floor(elapsed * 100 / duration)
    local label = ("Sending to %s (%d%%)"):format(destination_name, pct)
    return {
      entity_label = label,
      gui_label = label,
      diode = "yellow",
    }
  end

  if tick and state.last_delivery_tick and tick - state.last_delivery_tick <= EMITTER_DELIVERED_STATUS_TICKS then
    local label = ("Delivered to %s"):format(destination_name)
    return {
      entity_label = label,
      gui_label = label,
      diode = "green",
    }
  end

  local inventory = get_emitter_inventory(state.entity)
  local slot_index, stack = find_first_faxable_stack(inventory)
  if slot_index then
    if stack and not shared.can_force_fax_document(state.entity.force, stack.name) then
      return {
        entity_label = "Requires Color Faxing research",
        gui_label = ("Requires Color Faxing research for %s"):format(format_document_label(stack.name, get_quality_name(stack))),
        diode = "yellow",
      }
    end

    local receiver_state = get_receiver_state_for_planet(state.destination_planet)
    if not receiver_state then
      local label = ("No receiver on %s"):format(destination_name)
      return {
        entity_label = label,
        gui_label = label,
        diode = "red",
      }
    end

    if receiver_state.entity.force ~= state.entity.force then
      local label = ("Receiver on %s belongs to another force"):format(destination_name)
      return {
        entity_label = label,
        gui_label = label,
        diode = "red",
      }
    end

    local capacity = shared.get_queue_capacity(receiver_state.entity.force)
    local total_load = get_receiver_total_load(receiver_state)
    local reserved = (reserved_counts and reserved_counts[state.destination_planet]) or 0
    if total_load + reserved >= capacity then
      local label = ("Waiting for a free slot on %s"):format(destination_name)
      return {
        entity_label = label,
        gui_label = label,
        diode = "yellow",
      }
    end

    local label = ("Ready to send to %s"):format(destination_name)
    return {
      entity_label = label,
      gui_label = label,
      diode = "green",
    }
  end

  return {
    gui_label = "Insert faxable paperwork",
  }
end

local function apply_emitter_feedback(state, tick, reserved_counts)
  if not state or not state.entity or not state.entity.valid then return end
  local feedback = compute_emitter_feedback(state, tick, reserved_counts)
  if feedback and feedback.entity_label then
    local diode = get_status_diode(feedback.diode)
    if diode then
      state.entity.custom_status = {
        diode = diode,
        label = feedback.entity_label,
      }
    else
      state.entity.custom_status = nil
    end
  else
    state.entity.custom_status = nil
  end
end

local function apply_receiver_feedback(state, tick)
  if not state or not state.entity or not state.entity.valid then return end
  local feedback = compute_receiver_feedback(state, tick)
  if feedback and feedback.entity_label then
    local diode = get_status_diode(feedback.diode)
    if diode then
      state.entity.custom_status = {
        diode = diode,
        label = feedback.entity_label,
      }
    else
      state.entity.custom_status = nil
    end
  else
    state.entity.custom_status = nil
  end
end

local function get_receiver_request_signals(state)
  local entity = state and state.entity or nil
  if not entity or not entity.valid or not entity.get_signals then
    return {}
  end
  return entity.get_signals(RED_WIRE(), GREEN_WIRE()) or {}
end

local function refresh_receiver_request(state)
  if not state or not state.entity or not state.entity.valid or not state.entity.get_signals then
    return
  end

  if state.accept_circuit_requests == false then
    state.request_signals = {}
    state.current_request_signal = nil
    state.current_request_count = nil
    return
  end

  local signals = get_receiver_request_signals(state)
  state.request_signals = shared.collect_request_signals(signals, state.output_counts, RECEIVER_REQUEST_LIMIT)
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
  state.request_signals = state.request_signals or {}
  state.accept_circuit_requests = state.accept_circuit_requests ~= false
  state.read_queue_status = state.read_queue_status ~= false
  state.read_top_request = state.read_top_request ~= false
  state.queue_size_signal = get_receiver_output_signal(state, "queue")
  state.free_slots_signal = get_receiver_output_signal(state, "free")
  state.reserved_slots_signal = get_receiver_output_signal(state, "reserved")
  ensure_combinator(entity, state)
  sync_receiver_recipe(state)

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

local function find_gui_element(root, name)
  if not root or not root.valid or not name then return nil end
  if root.name == name then
    return root
  end
  for _, child in ipairs(root.children or {}) do
    local found = find_gui_element(child, name)
    if found then
      return found
    end
  end
  return nil
end

local function clear_gui_children(element)
  if not element or not element.valid then return end
  if element.clear then
    element.clear()
    return
  end
  for _, child in ipairs(element.children or {}) do
    if child.valid and child.destroy then
      child.destroy()
    end
  end
end

local function get_emitter_gui_frame(player)
  if not player or not player.valid or not player.gui or not player.gui.left then return nil end
  return player.gui.left[shared.GUI_FRAME_NAME]
end

local function get_receiver_gui_frame(player)
  if not player or not player.valid or not player.gui or not player.gui.screen then return nil end
  return player.gui.screen[shared.RECEIVER_GUI_FRAME_NAME]
end

local function destroy_gui(player)
  if not player or not player.valid or not player.gui then return end

  local emitter_frame = get_emitter_gui_frame(player)
  if emitter_frame and emitter_frame.valid then
    emitter_frame.destroy()
  end

  local receiver_frame = get_receiver_gui_frame(player)
  if receiver_frame and receiver_frame.valid then
    if player.opened == receiver_frame then
      player.opened = nil
    end
    receiver_frame.destroy()
  end

  storage.fax_gui_players[player.index] = nil
end

local function set_gui_label(frame, name, caption)
  if not frame or not frame.valid then return end
  local label = find_gui_element(frame, name)
  if label and label.valid then
    label.caption = caption
  end
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

  frame.add{
    type = "label",
    name = shared.GUI_STATUS_NAME,
    caption = "",
  }

  storage.fax_gui_players[player.index] = {
    kind = "emitter",
    unit_number = state.entity.unit_number,
    planet_names = planet_names,
  }
end

local function set_element_size(element, width, height)
  if not element or not element.style then return end
  if width then
    element.style.minimal_width = width
    element.style.maximal_width = width
  end
  if height then
    element.style.minimal_height = height
    element.style.maximal_height = height
  end
end

local function style_section_caption(label)
  if label and label.style then
    label.style.font = "default-semibold"
  end
end

local function add_receiver_section(parent, caption, content_name)
  local section = parent.add{
    type = "frame",
    direction = "vertical",
  }
  if section.style then
    section.style.horizontally_stretchable = true
  end

  local header = section.add{
    type = "flow",
    direction = "horizontal",
  }
  if header.style then
    header.style.horizontally_stretchable = true
  end
  local title = header.add{
    type = "label",
    caption = caption,
  }
  style_section_caption(title)
  section.add{type = "line"}
  return section.add{
    type = "flow",
    direction = "vertical",
    name = content_name,
  }
end

local function add_receiver_scroll_section(parent, caption, content_name, height)
  local section = parent.add{
    type = "frame",
    direction = "vertical",
  }
  if section.style then
    section.style.horizontally_stretchable = true
    section.style.vertically_stretchable = true
  end

  local header = section.add{
    type = "flow",
    direction = "horizontal",
  }
  if header.style then
    header.style.horizontally_stretchable = true
  end
  local title = header.add{
    type = "label",
    caption = caption,
  }
  style_section_caption(title)
  section.add{type = "line"}

  local scroll = section.add{
    type = "scroll-pane",
    direction = "vertical",
    name = content_name,
  }
  if scroll.style then
    scroll.style.horizontally_stretchable = true
    scroll.style.vertically_stretchable = true
    if height then
      scroll.style.maximal_height = height
    end
  end
  return scroll
end

local function add_icon_text_row(parent, icon_text, main_text, detail_text)
  local row = parent.add{
    type = "flow",
    direction = "horizontal",
  }
  if row.style then
    row.style.horizontally_stretchable = true
  end
  local icon = row.add{
    type = "label",
    caption = icon_text,
  }
  set_element_size(icon, 28, nil)

  local text_flow = row.add{
    type = "flow",
    direction = "vertical",
  }
  if text_flow.style then
    text_flow.style.horizontally_stretchable = true
  end
  local main_label = text_flow.add{
    type = "label",
    caption = main_text,
  }
  if main_label.style then
    main_label.style.single_line = false
  end
  if detail_text and detail_text ~= "" then
    local detail_label = text_flow.add{
      type = "label",
      caption = detail_text,
    }
    if detail_label.style then
      detail_label.style.single_line = false
      detail_label.style.font_color = {r = 0.75, g = 0.75, b = 0.75}
    end
  end
  return row
end

local function add_setting_checkbox(parent, name, caption, description)
  local row = parent.add{
    type = "flow",
    direction = "vertical",
  }
  local checkbox = row.add{
    type = "checkbox",
    name = name,
    state = true,
    caption = caption,
  }
  if description and description ~= "" then
    local label = row.add{
      type = "label",
      caption = description,
    }
    if label.style then
      label.style.single_line = false
      label.style.left_margin = 24
      label.style.font_color = {r = 0.75, g = 0.75, b = 0.75}
    end
  end
  return checkbox
end

local function add_signal_selector_row(parent, caption, name)
  local row = parent.add{
    type = "flow",
    direction = "horizontal",
  }
  if row.style then
    row.style.vertical_align = "center"
    row.style.left_margin = 24
  end
  local label = row.add{
    type = "label",
    caption = caption,
  }
  set_element_size(label, 80, nil)
  local selector = row.add{
    type = "choose-elem-button",
    elem_type = "signal",
    name = name,
  }
  return selector
end

local function add_queue_header_row(parent)
  local row = parent.add{
    type = "flow",
    direction = "horizontal",
  }
  local document = row.add{type = "label", caption = "Form"}
  set_element_size(document, 200, nil)
  local state = row.add{type = "label", caption = "State"}
  set_element_size(state, 120, nil)
  local source = row.add{type = "label", caption = "From"}
  set_element_size(source, 80, nil)
  row.add{type = "label", caption = "Required inks"}
  return row
end

local function add_receiver_queue_row(parent, entry, state_text)
  local row = parent.add{
    type = "frame",
    direction = "vertical",
  }
  if row.style then
    row.style.horizontally_stretchable = true
  end
  local body = row.add{
    type = "flow",
    direction = "horizontal",
  }
  if body.style then
    body.style.horizontally_stretchable = true
  end

  local document = body.add{
    type = "flow",
    direction = "horizontal",
  }
  set_element_size(document, 200, nil)
  document.add{
    type = "label",
    caption = ("[img=item.%s]"):format(entry.name),
  }
  local document_text = document.add{
    type = "flow",
    direction = "vertical",
  }
  document_text.add{
    type = "label",
    caption = format_document_label(entry.name, entry.quality_name),
  }
  local quality_name = entry.quality_name
  if quality_name and type(quality_name) ~= "string" then
    quality_name = quality_name.name or tostring(quality_name)
  end
  if quality_name and quality_name ~= "" and quality_name ~= "normal" then
    local quality_label = document_text.add{
      type = "label",
      caption = ("Quality: %s"):format(quality_name),
    }
    if quality_label.style then
      quality_label.style.font_color = {r = 0.75, g = 0.75, b = 0.75}
    end
  end

  local state_label = body.add{
    type = "label",
    caption = state_text,
  }
  set_element_size(state_label, 120, nil)

  local source_label = body.add{
    type = "label",
    caption = shared.format_planet_name(entry.source_planet),
  }
  set_element_size(source_label, 80, nil)

  local inks_label = body.add{
    type = "label",
    caption = shared.format_required_inks(entry.name),
  }
  if inks_label.style then
    inks_label.style.horizontally_stretchable = true
  end
end

local function build_receiver_gui(player, state)
  destroy_gui(player)
  if not player or not player.valid or not player.gui or not player.gui.screen or not state or not state.entity or not state.entity.valid then
    return
  end

  local frame = player.gui.screen.add{
    type = "frame",
    name = shared.RECEIVER_GUI_FRAME_NAME,
    direction = "vertical",
  }
  if frame.style then
    frame.style.minimal_width = 900
    frame.style.maximal_width = 900
    frame.style.minimal_height = 700
    frame.style.maximal_height = 700
  end

  local title_bar = frame.add{
    type = "flow",
    direction = "horizontal",
  }
  if title_bar.style then
    title_bar.style.horizontally_stretchable = true
  end
  title_bar.drag_target = frame

  local title = title_bar.add{
    type = "label",
    caption = "Interplanetary Fax Exchange",
    style = "frame_title",
  }

  local drag_handle = title_bar.add{
    type = "empty-widget",
    style = "draggable_space_header",
  }
  if drag_handle.style then
    drag_handle.style.horizontally_stretchable = true
    drag_handle.style.height = 24
  end
  drag_handle.drag_target = frame

  title_bar.add{
    type = "sprite-button",
    name = shared.RECEIVER_GUI_CLOSE_NAME,
    style = "frame_action_button",
    sprite = "utility/close",
    hovered_sprite = "utility/close_black",
    clicked_sprite = "utility/close_black",
    tooltip = {"gui.close"},
  }

  local body = frame.add{
    type = "flow",
    direction = "vertical",
  }
  if body.style then
    body.style.horizontally_stretchable = true
    body.style.vertically_stretchable = true
  end

  local summary = body.add{
    type = "frame",
    direction = "vertical",
  }
  if summary.style then
    summary.style.horizontally_stretchable = true
  end
  summary.add{
    type = "label",
    name = shared.RECEIVER_GUI_HEADER_NAME,
    caption = "",
  }

  local content = body.add{
    type = "flow",
    direction = "horizontal",
  }
  if content.style then
    content.style.horizontally_stretchable = true
    content.style.vertically_stretchable = true
  end

  local left_column = content.add{
    type = "scroll-pane",
    direction = "vertical",
  }
  if left_column.style then
    left_column.style.minimal_width = 340
    left_column.style.maximal_width = 340
    left_column.style.minimal_height = 580
    left_column.style.maximal_height = 580
  end

  local right_column = content.add{
    type = "flow",
    direction = "vertical",
  }
  if right_column.style then
    right_column.style.horizontally_stretchable = true
    right_column.style.vertically_stretchable = true
  end

  add_receiver_section(left_column, "Status", shared.RECEIVER_GUI_STATUS_BODY_NAME)

  local settings = add_receiver_section(left_column, "Circuit Settings", "administratorio-fax-receiver-settings")
  add_setting_checkbox(settings, shared.RECEIVER_GUI_ACCEPT_BUTTON_NAME, "Accept circuit requests",
    "Reads incoming document item signals from the attached circuit network.")
  settings.add{type = "line"}
  add_setting_checkbox(settings, shared.RECEIVER_GUI_QUEUE_BUTTON_NAME, "Read queue metrics",
    "Exports queued, free, and reserved slot counts on the selected signals.")
  add_signal_selector_row(settings, "Queued", shared.RECEIVER_GUI_QUEUE_SIGNAL_NAME)
  add_signal_selector_row(settings, "Free", shared.RECEIVER_GUI_FREE_SIGNAL_NAME)
  add_signal_selector_row(settings, "Reserved", shared.RECEIVER_GUI_RESERVED_SIGNAL_NAME)
  settings.add{type = "line"}
  add_setting_checkbox(settings, shared.RECEIVER_GUI_TOP_REQUEST_BUTTON_NAME, "Read top request",
    "Exports the currently leading request as the requested document signal itself.")

  add_receiver_section(left_column, "Supplies", shared.RECEIVER_GUI_SUPPLIES_CONTENT_NAME)
  add_receiver_section(right_column, "Requests", shared.RECEIVER_GUI_REQUESTS_CONTENT_NAME)
  local queue_scroll = add_receiver_scroll_section(right_column, "Queue", shared.RECEIVER_GUI_QUEUE_CONTENT_NAME, 400)
  add_queue_header_row(queue_scroll)
  queue_scroll.add{type = "line"}

  if frame.force_auto_center then
    frame.force_auto_center()
  end

  storage.fax_gui_players[player.index] = {
    kind = "receiver",
    unit_number = state.entity.unit_number,
    suppress_close_once = true,
  }

  if player.opened == state.entity then
    player.opened = nil
  end
  player.opened = frame
end

local function update_emitter_gui(player, state, tick, reserved_counts)
  local frame = get_emitter_gui_frame(player)
  if not frame or not frame.valid then return end

  local status = find_gui_element(frame, shared.GUI_STATUS_NAME)
  if not status or not status.valid then return end

  local feedback = compute_emitter_feedback(state, tick, reserved_counts)
  status.caption = feedback and feedback.gui_label or ""
end

local function set_receiver_toggle_checkbox(frame, name, enabled)
  local checkbox = find_gui_element(frame, name)
  if checkbox and checkbox.valid then
    checkbox.state = enabled
  end
end

local function set_receiver_signal_selector(frame, name, signal)
  local selector = find_gui_element(frame, name)
  if selector and selector.valid then
    selector.elem_value = clone_signal(signal)
  end
end

local function set_gui_element_enabled(frame, name, enabled)
  local element = find_gui_element(frame, name)
  if element and element.valid then
    element.enabled = enabled
  end
end

local function add_gui_table_row(table_element, values)
  for _, value in ipairs(values) do
    table_element.add{
      type = "label",
      caption = value,
    }
  end
end

local function populate_receiver_status(frame, state, tick)
  local content = find_gui_element(frame, shared.RECEIVER_GUI_STATUS_BODY_NAME)
  if not content or not content.valid then return end
  clear_gui_children(content)

  local feedback = compute_receiver_feedback(state, tick)
  local current_entry = get_receiver_active_entry(state)
  local overview = content.add{
    type = "flow",
    direction = "vertical",
  }
  local status_label = overview.add{
    type = "label",
    caption = feedback and feedback.gui_label or "Receiver unavailable",
  }
  if status_label.style then
    status_label.style.font = "default-semibold"
  end
  overview.add{
    type = "label",
    caption = current_entry
      and ("Current job: %s"):format(format_document_label(current_entry.name, current_entry.quality_name))
      or "Current job: none",
  }
  overview.add{
    type = "label",
    caption = ("Queue occupancy: %d/%d"):format(
      get_receiver_total_load(state),
      shared.get_queue_capacity(state.entity.force)),
  }
end

local function populate_receiver_supplies(frame, state)
  local content = find_gui_element(frame, shared.RECEIVER_GUI_SUPPLIES_CONTENT_NAME)
  if not content or not content.valid then return end
  clear_gui_children(content)

  local current_entry = get_receiver_active_entry(state)
  local snapshot = get_receiver_supply_snapshot(state, current_entry)
  add_icon_text_row(
    content,
    "[img=item.thermal-transfer-sheet]",
    current_entry and ("Active requirements: %s"):format(shared.format_required_inks(current_entry.name)) or "Active requirements: none",
    current_entry and "Transfer sheets plus only the inks listed below are needed." or "No queued form is currently being evaluated.")

  local table_element = content.add{
    type = "table",
    column_count = 3,
  }
  add_gui_table_row(table_element, {"Supply", "Available", "State"})
  add_gui_table_row(table_element, {
    "Transfer sheet",
    tostring(snapshot.paper_count or 0),
    current_entry and (snapshot.paper and "Ready" or "Missing") or "Idle",
  })

  for _, fluid in ipairs(snapshot.fluids or {}) do
    local state_text
    if not current_entry then
      state_text = "Idle"
    elseif fluid.is_required then
      state_text = fluid.ready and "Ready" or "Missing"
    else
      state_text = "Optional"
    end
    add_gui_table_row(table_element, {
      fluid.label,
      fluid.is_required and ("%.0f/%.0f"):format(fluid.available or 0, fluid.required or 0) or ("%.0f"):format(fluid.available or 0),
      state_text,
    })
  end
end

local function populate_receiver_requests(frame, state)
  local content = find_gui_element(frame, shared.RECEIVER_GUI_REQUESTS_CONTENT_NAME)
  if not content or not content.valid then return end
  clear_gui_children(content)

  if state.accept_circuit_requests == false then
    add_icon_text_row(content, "[img=virtual-signal.signal-red]", "Circuit requests are disabled.", "")
    return
  end

  if state.current_request_signal then
    local top_request = content.add{
      type = "frame",
      direction = "vertical",
    }
    add_icon_text_row(
      top_request,
      ("[img=item.%s]"):format(state.current_request_signal.name),
      ("Top request: %s x%d"):format(
        format_document_label(state.current_request_signal.name, state.current_request_signal.quality),
        state.current_request_count or 0),
      "Highest-count imported request on the receiver circuit network.")
  end

  if not state.request_signals or #state.request_signals == 0 then
    add_icon_text_row(content, "[img=virtual-signal.signal-info]", "No outstanding circuit requests.", "")
    return
  end

  for _, entry in ipairs(state.request_signals) do
    local raw_quality = entry.signal.quality
    if raw_quality and type(raw_quality) ~= "string" then
      raw_quality = raw_quality.name or tostring(raw_quality)
    end
    local quality_suffix = ""
    if raw_quality and raw_quality ~= "normal" then
      quality_suffix = (" | Quality: %s"):format(raw_quality)
    end
    local row = content.add{
      type = "frame",
      direction = "vertical",
    }
    add_icon_text_row(
      row,
      ("[img=item.%s]"):format(entry.signal.name),
      ("%dx %s"):format(entry.count or 0, format_document_label(entry.signal.name, entry.signal.quality)),
      "Imported from circuit network" .. quality_suffix)
  end
end

local function describe_receiver_queue_row(state, entry, is_active, tick)
  if is_active then
    if tick and entry.ready_tick and tick < entry.ready_tick then
      return ("Printing %d%%"):format(compute_print_progress(entry, tick))
    end
    if not receiver_can_output_entry(state, entry) then
      return "Blocked output"
    end
    return "Finalizing"
  end

  if state.queue and state.queue[1] == entry then
    if not receiver_entry_is_research_ready(state, entry) then
      return "Awaiting research"
    end
    if not receiver_can_output_entry(state, entry) then
      return "Blocked output"
    end
    local has_supplies = receiver_has_required_supplies(state, entry)
    if not has_supplies then
      return "Waiting supplies"
    end
    return "Ready"
  end

  return "Queued"
end

local function populate_receiver_queue(frame, state, tick)
  local content = find_gui_element(frame, shared.RECEIVER_GUI_QUEUE_CONTENT_NAME)
  if not content or not content.valid then return end
  clear_gui_children(content)

  add_queue_header_row(content)
  content.add{type = "line"}

  local has_entries = state.active_print ~= nil or (state.queue and #state.queue > 0)
  if not has_entries then
    add_icon_text_row(content, "[img=virtual-signal.signal-info]", "Queue empty.", "Incoming faxes will appear here once reserved.")
    return
  end

  if state.active_print then
    add_receiver_queue_row(
      content,
      state.active_print,
      describe_receiver_queue_row(state, state.active_print, true, tick))
    content.add{type = "line"}
  end

  for _, entry in ipairs(state.queue or {}) do
    add_receiver_queue_row(
      content,
      entry,
      describe_receiver_queue_row(state, entry, false, tick))
    content.add{type = "line"}
  end
end

local function update_receiver_gui(player, state, tick)
  local frame = get_receiver_gui_frame(player)
  if not frame or not frame.valid then return end

  local load = get_receiver_total_load(state)
  local capacity = shared.get_queue_capacity(state.entity.force)
  local top_request = state.current_request_signal
    and ("%s x%d"):format(format_document_label(state.current_request_signal.name, state.current_request_signal.quality), state.current_request_count or 0)
    or (state.accept_circuit_requests == false and "Requests disabled" or "No current request")

  set_gui_label(frame, shared.RECEIVER_GUI_HEADER_NAME,
    ("%s | Queue %d/%d | Top request: %s"):format(
      shared.format_planet_name(state.planet_name),
      load,
      capacity,
      top_request))
  set_receiver_toggle_checkbox(frame, shared.RECEIVER_GUI_ACCEPT_BUTTON_NAME, state.accept_circuit_requests ~= false)
  set_receiver_toggle_checkbox(frame, shared.RECEIVER_GUI_QUEUE_BUTTON_NAME, state.read_queue_status ~= false)
  set_receiver_toggle_checkbox(frame, shared.RECEIVER_GUI_TOP_REQUEST_BUTTON_NAME, state.read_top_request ~= false)
  set_receiver_signal_selector(frame, shared.RECEIVER_GUI_QUEUE_SIGNAL_NAME, state.queue_size_signal)
  set_receiver_signal_selector(frame, shared.RECEIVER_GUI_FREE_SIGNAL_NAME, state.free_slots_signal)
  set_receiver_signal_selector(frame, shared.RECEIVER_GUI_RESERVED_SIGNAL_NAME, state.reserved_slots_signal)
  set_gui_element_enabled(frame, shared.RECEIVER_GUI_QUEUE_SIGNAL_NAME, state.read_queue_status ~= false)
  set_gui_element_enabled(frame, shared.RECEIVER_GUI_FREE_SIGNAL_NAME, state.read_queue_status ~= false)
  set_gui_element_enabled(frame, shared.RECEIVER_GUI_RESERVED_SIGNAL_NAME, state.read_queue_status ~= false)
  populate_receiver_status(frame, state, tick)
  populate_receiver_supplies(frame, state)
  populate_receiver_requests(frame, state)
  populate_receiver_queue(frame, state, tick)
end

local function is_emitter_open(player, entity)
  local opened = entity or (player and player.valid and player.opened) or nil
  return opened
    and opened.valid
    and opened.name == shared.EMITTER_NAME
end

local function is_receiver_open(player, entity)
  local opened = entity or (player and player.valid and player.opened) or nil
  return opened
    and opened.valid
    and opened.name == shared.RECEIVER_NAME
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
    if job and not job.document_held then
      local inventory = get_emitter_inventory(state.entity)
      if job.slot_index then
        local stack = take_stack_from_slot(inventory, job.slot_index, job.item_name, job.quality_name)
        if stack then
          job.document_held = true
        else
          state.current_job = nil
          job = nil
        end
      end
      if job then
        job.start_tick = job.start_tick or math.max(0, (job.complete_tick or tick) - shared.TRANSMIT_TICKS)
      end
    end

    if job and tick >= job.complete_tick then
      local receiver_state = get_receiver_state_for_planet(job.destination_planet)
      if not receiver_state or receiver_state.entity.force ~= state.entity.force then
        return_job_document_to_emitter(state, job)
        state.current_job = nil
      else
        receiver_state.queue[#receiver_state.queue + 1] = {
          name = job.item_name,
          quality_name = job.quality_name,
          source_planet = job.source_planet,
        }
        spill_job_document(state.entity, nil, job)
        state.last_delivery_tick = tick
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
          local inventory = get_emitter_inventory(state.entity)
          local slot_index, stack = find_first_faxable_stack(inventory)
          if slot_index and stack and shared.can_force_fax_document(state.entity.force, stack.name) then
            local removed_stack = take_stack_from_slot(inventory, slot_index, stack.name, get_quality_name(stack))
            if removed_stack then
              state.current_job = {
                item_name = removed_stack.name,
                quality_name = removed_stack.quality,
                destination_planet = state.destination_planet,
                source_planet = state.planet_name,
                slot_index = slot_index,
                start_tick = tick,
                complete_tick = tick + shared.TRANSMIT_TICKS,
                document_held = true,
              }
              reserved_counts[state.destination_planet] = reserved + 1
            end
          end
        end
      end
    end
  end
end

local function process_receivers(tick)
  for _, state in pairs(storage.fax_receivers) do
    sync_receiver_recipe(state)
    local output_inventory = get_receiver_output_inventory(state.entity)
    if output_inventory then
      if state.active_print then
        if tick >= state.active_print.ready_tick then
          local stack = receiver_output_stack(state.active_print)
          if can_insert_stack(output_inventory, stack) and insert_stack(output_inventory, stack) > 0 then
            state.active_print = nil
            sync_receiver_recipe(state)
          end
        end
      elseif #(state.queue or {}) > 0 then
        local next_entry = state.queue[1]
        if receiver_entry_is_research_ready(state, next_entry)
          and receiver_can_output_entry(state, next_entry)
          and consume_receiver_supplies(state, next_entry) then
          state.active_print = table.remove(state.queue, 1)
          state.active_print.start_tick = tick
          state.active_print.ready_tick = tick + shared.PRINT_TICKS
          sync_receiver_recipe(state)
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

local function refresh_emitter_feedbacks(tick, reserved_counts)
  for _, state in pairs(storage.fax_emitters) do
    apply_emitter_feedback(state, tick, reserved_counts)
  end
end

local function refresh_receiver_feedbacks(tick)
  for _, state in pairs(storage.fax_receivers) do
    sync_receiver_recipe(state)
    apply_receiver_feedback(state, tick)
  end
end

local function refresh_open_fax_guis(tick, reserved_counts)
  for player_index, gui_state in pairs(storage.fax_gui_players or {}) do
    local player = game and game.get_player and game.get_player(player_index) or nil
    if not player or not player.valid then
      storage.fax_gui_players[player_index] = nil
    else
      local state = gui_state and gui_state.kind == "receiver"
        and storage.fax_receivers[gui_state.unit_number]
        or gui_state and gui_state.kind == "emitter"
        and storage.fax_emitters[gui_state.unit_number]
        or nil
      if not state or not state.entity or not state.entity.valid then
        destroy_gui(player)
      elseif gui_state.kind == "receiver" then
        update_receiver_gui(player, state, tick)
      else
        update_emitter_gui(player, state, tick, reserved_counts)
      end
    end
  end
end

local function refresh_visual_state(tick)
  local reserved_counts = build_reserved_counts()
  refresh_outputs(reserved_counts)
  refresh_receiver_feedbacks(tick)
  refresh_emitter_feedbacks(tick, reserved_counts)
  refresh_open_fax_guis(tick, reserved_counts)
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
      if state.current_job then
        spill_job_document(entity, buffer, state.current_job)
      end
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
  refresh_receiver_feedbacks(event.tick)
  refresh_emitter_feedbacks(event.tick, reserved_counts)
  refresh_open_fax_guis(event.tick, reserved_counts)
end

function M.on_selected_entity_changed(player, entity)
  ensure_storage()
  if not player or not player.valid then return end
  local gui_state = storage.fax_gui_players[player.index]
  if gui_state and gui_state.kind == "receiver" then
    local receiver_state = storage.fax_receivers[gui_state.unit_number]
    if receiver_state and receiver_state.entity and receiver_state.entity.valid then
      return
    end
  end
  if is_emitter_open(player) or is_receiver_open(player) then return end
  destroy_gui(player)
end

function M.on_gui_opened(player, entity)
  ensure_storage()
  if not player or not player.valid then return end

  -- Setting player.opened = frame in build_receiver_gui fires on_gui_opened
  -- again with entity=nil.  Ignore that re-entrant call so we don't
  -- immediately destroy the frame we just created.
  if not entity then
    local gui_state = storage.fax_gui_players[player.index]
    if gui_state and gui_state.kind == "receiver" then
      return
    end
  end

  if is_emitter_open(player, entity) then
    local state = storage.fax_emitters[entity.unit_number]
    if not state then
      destroy_gui(player)
      return
    end

    build_emitter_gui(player, state)
    update_emitter_gui(player, state, game and game.tick or 0, build_reserved_counts())
    return
  end

  if is_receiver_open(player, entity) then
    local state = storage.fax_receivers[entity.unit_number]
    if not state then
      destroy_gui(player)
      return
    end

    build_receiver_gui(player, state)
    update_receiver_gui(player, state, game and game.tick or 0)
    return
  end

  destroy_gui(player)
end

function M.on_gui_closed(player)
  ensure_storage()
  if not player or not player.valid then return end
  local gui_state = storage.fax_gui_players[player.index]
  if gui_state and gui_state.kind == "receiver" and gui_state.suppress_close_once then
    gui_state.suppress_close_once = false
    return
  end
  destroy_gui(player)
end

function M.on_gui_click(event)
  ensure_storage()
  if not event or not event.element or not event.element.valid then return false end

  local player = game and game.get_player and game.get_player(event.player_index) or nil
  if not player or not player.valid then return false end

  local element_name = event.element.name
  if element_name == shared.RECEIVER_GUI_CLOSE_NAME then
    destroy_gui(player)
    return true
  end

  return false
end

function M.on_gui_selection_state_changed(event)
  ensure_storage()
  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end
  local element = event.element
  if not element or not element.valid then return end

  local gui_state = storage.fax_gui_players[player.index]
  if element.name == shared.GUI_DROPDOWN_NAME then
    if not gui_state or gui_state.kind ~= "emitter" then return end

    local emitter_state = storage.fax_emitters[gui_state.unit_number]
    if not emitter_state or not emitter_state.entity or not emitter_state.entity.valid then
      destroy_gui(player)
      return
    end

    local destination_planet = gui_state.planet_names[element.selected_index]
    if destination_planet then
      emitter_state.destination_planet = destination_planet
      update_emitter_gui(player, emitter_state, game and game.tick or 0, build_reserved_counts())
    end
    return
  end
end

function M.on_gui_checked_state_changed(event)
  ensure_storage()
  if not event or not event.element or not event.element.valid then return end

  local player = game and game.get_player and game.get_player(event.player_index) or nil
  if not player or not player.valid then return end

  local gui_state = storage.fax_gui_players[player.index]
  if not gui_state or gui_state.kind ~= "receiver" then return end

  local receiver_state = storage.fax_receivers[gui_state.unit_number]
  if not receiver_state or not receiver_state.entity or not receiver_state.entity.valid then
    destroy_gui(player)
    return
  end

  local enabled = event.element.state ~= false
  if event.element.name == shared.RECEIVER_GUI_ACCEPT_BUTTON_NAME then
    receiver_state.accept_circuit_requests = enabled
    refresh_receiver_request(receiver_state)
  elseif event.element.name == shared.RECEIVER_GUI_QUEUE_BUTTON_NAME then
    receiver_state.read_queue_status = enabled
  elseif event.element.name == shared.RECEIVER_GUI_TOP_REQUEST_BUTTON_NAME then
    receiver_state.read_top_request = enabled
  else
    return
  end

  refresh_visual_state(game and game.tick or 0)
end

function M.on_gui_elem_changed(event)
  ensure_storage()
  if not event or not event.element or not event.element.valid then return end

  local player = game and game.get_player and game.get_player(event.player_index) or nil
  if not player or not player.valid then return end

  local gui_state = storage.fax_gui_players[player.index]
  if not gui_state or gui_state.kind ~= "receiver" then return end

  local receiver_state = storage.fax_receivers[gui_state.unit_number]
  if not receiver_state or not receiver_state.entity or not receiver_state.entity.valid then
    destroy_gui(player)
    return
  end

  local element = event.element
  if element.name == shared.RECEIVER_GUI_QUEUE_SIGNAL_NAME then
    receiver_state.queue_size_signal = clone_signal(element.elem_value, "virtual", shared.SIGNAL_QUEUE_SIZE)
  elseif element.name == shared.RECEIVER_GUI_FREE_SIGNAL_NAME then
    receiver_state.free_slots_signal = clone_signal(element.elem_value, "virtual", shared.SIGNAL_FREE_SLOTS)
  elseif element.name == shared.RECEIVER_GUI_RESERVED_SIGNAL_NAME then
    receiver_state.reserved_slots_signal = clone_signal(element.elem_value, "virtual", shared.SIGNAL_RESERVED_SLOTS)
  else
    return
  end

  refresh_visual_state(game and game.tick or 0)
end

return M
