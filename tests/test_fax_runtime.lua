-------------------------------------------------------------------------------
-- FAX RUNTIME TESTS
-------------------------------------------------------------------------------

local passed, failed, errors = 0, 0, {}

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    errors[#errors + 1] = name .. ": " .. tostring(err)
  end
end

local function assert_true(value, msg)
  if not value then error(msg or "assertion failed", 2) end
end

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or "assertion failed") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

defines = {
  inventory = {
    chest = 1,
    assembling_machine_input = 2,
    assembling_machine_output = 3,
  },
  entity_status_diode = {
    red = 1,
    yellow = 2,
    green = 3,
  },
  wire_connector_id = {
    circuit_red = 1,
    circuit_green = 2,
  },
}

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

package.loaded["scripts.fax_shared"] = nil
package.loaded["scripts.fax"] = nil
local shared = require("scripts.fax_shared")
local fax = require("scripts.fax")

local next_unit_number = 100

local function alloc_unit_number()
  next_unit_number = next_unit_number + 1
  return next_unit_number
end

local function new_stack()
  local data = {
    count = 0,
    valid_for_read = false,
    name = nil,
    quality = nil,
  }

  return setmetatable({}, {
    __index = function(_, key)
      return data[key]
    end,
    __newindex = function(_, key, value)
      if key == "count" then
        if value <= 0 then
          data.count = 0
          data.valid_for_read = false
          data.name = nil
          data.quality = nil
        else
          data.count = value
          data.valid_for_read = true
        end
      else
        data[key] = value
      end
    end,
  })
end

local function set_stack(stack, spec)
  stack.name = spec.name
  stack.quality = spec.quality and {name = spec.quality} or nil
  stack.count = spec.count or 1
end

local function quality_name(stack)
  return stack and stack.quality and stack.quality.name or nil
end

local function new_inventory(size)
  local inventory = {
    force_block_insert = false,
  }

  for index = 1, size do
    inventory[index] = new_stack()
  end

  function inventory.get_item_count(item_name)
    local count = 0
    for index = 1, #inventory do
      local stack = inventory[index]
      if stack.valid_for_read and stack.name == item_name then
        count = count + stack.count
      end
    end
    return count
  end

  function inventory.can_insert(stack_spec)
    if inventory.force_block_insert then return false end
    for index = 1, #inventory do
      local stack = inventory[index]
      if not stack.valid_for_read then
        return true
      end
      if stack.name == stack_spec.name and quality_name(stack) == stack_spec.quality then
        return true
      end
    end
    return false
  end

  function inventory.insert(stack_spec)
    if inventory.force_block_insert then return 0 end
    for index = 1, #inventory do
      local stack = inventory[index]
      if stack.valid_for_read and stack.name == stack_spec.name and quality_name(stack) == stack_spec.quality then
        stack.count = stack.count + (stack_spec.count or 1)
        return stack_spec.count or 1
      end
    end
    for index = 1, #inventory do
      local stack = inventory[index]
      if not stack.valid_for_read then
        set_stack(stack, stack_spec)
        return stack_spec.count or 1
      end
    end
    return 0
  end

  function inventory.remove(stack_spec)
    local remaining = stack_spec.count or 1
    local removed = 0
    for index = 1, #inventory do
      local stack = inventory[index]
      if stack.valid_for_read and stack.name == stack_spec.name then
        local delta = math.min(remaining, stack.count)
        stack.count = stack.count - delta
        removed = removed + delta
        remaining = remaining - delta
        if remaining == 0 then
          break
        end
      end
    end
    return removed
  end

  function inventory.clear()
    for index = 1, #inventory do
      inventory[index].count = 0
    end
  end

  return inventory
end

local function signal_key(signal_id)
  return shared.make_signal_key(signal_id)
end

local function merge_signal_arrays(...)
  local counts = {}
  local ordered = {}

  for array_index = 1, select("#", ...) do
    local signals = select(array_index, ...)
    for _, entry in ipairs(signals or {}) do
      local key = signal_key(entry.signal)
      if key then
        if not counts[key] then
          counts[key] = {
            signal = {
              type = entry.signal.type,
              name = entry.signal.name,
              quality = entry.signal.quality,
            },
            count = 0,
          }
          ordered[#ordered + 1] = counts[key]
        end
        counts[key].count = counts[key].count + (entry.count or 0)
      end
    end
  end

  return ordered
end

local function resolve_signal_value(value)
  if type(value) == "table" then
    return {
      type = value.type or "virtual",
      name = value.name or value,
      quality = value.quality,
    }
  end

  return {
    type = shared.is_faxable_item_name(value) and "item" or "virtual",
    name = value,
    quality = nil,
  }
end

local function new_gui_element(parent, params)
  local element = {
    valid = true,
    parent = parent,
    name = params.name,
    type = params.type,
    style = {},
    items = params.items,
    selected_index = params.selected_index,
    state = params.state,
    enabled = params.enabled ~= false,
    caption = params.caption,
    direction = params.direction,
    column_count = params.column_count,
    elem_type = params.elem_type,
    elem_value = params.elem_value,
    sprite = params.sprite,
    tooltip = params.tooltip,
    children = {},
    children_by_name = {},
  }

  local methods = {}

  function methods.add(spec)
    return new_gui_element(element, spec)
  end

  function methods.destroy()
    if not element.valid then return end
    element.valid = false
    if element.parent then
      if element.name then
        element.parent.children_by_name[element.name] = nil
      end
      for index, child in ipairs(element.parent.children) do
        if child == element then
          table.remove(element.parent.children, index)
          break
        end
      end
    end
  end

  function methods.clear()
    for _, child in ipairs(element.children) do
      child.valid = false
      child.parent = nil
    end
    element.children = {}
    element.children_by_name = {}
  end

  function methods.force_auto_center()
  end

  setmetatable(element, {
    __index = function(tbl, key)
      if methods[key] then return methods[key] end
      if tbl.children_by_name[key] then return tbl.children_by_name[key] end
      return rawget(tbl, key)
    end
  })

  if parent then
    parent.children[#parent.children + 1] = element
    if element.name then
      parent.children_by_name[element.name] = element
    end
  end

  return element
end

local function new_gui_root()
  return new_gui_element(nil, {type = "root", name = "root"})
end

local function new_player(index)
  local player = {
    index = index,
    valid = true,
    printed_messages = {},
    inserted_items = {},
    opened = nil,
    gui = {
      left = new_gui_root(),
      screen = new_gui_root(),
    },
  }

  function player.print(message)
    player.printed_messages[#player.printed_messages + 1] = message
  end

  function player.insert(stack)
    player.inserted_items[stack.name] = (player.inserted_items[stack.name] or 0) + (stack.count or 1)
    return stack.count or 1
  end

  return player
end

local function new_force()
  return {
    valid = true,
    technologies = {
      ["color-faxing"] = {researched = false},
      ["fax-queue-capacity-1"] = {researched = false},
      ["fax-queue-capacity-2"] = {researched = false},
      ["fax-queue-capacity-3"] = {researched = false},
    },
  }
end

local function remove_surface_entity(surface, entity)
  for index, candidate in ipairs(surface.entities) do
    if candidate == entity then
      table.remove(surface.entities, index)
      return
    end
  end
end

local function new_wire_connector(owner)
  return {
    owner = owner,
    connect_to = function(self, other)
      if not other or not other.owner then return end
      if self.owner.name == shared.COMBINATOR_NAME then
        other.owner.combinator_ref = self.owner
      elseif other.owner.name == shared.COMBINATOR_NAME then
        self.owner.combinator_ref = other.owner
      end
    end,
  }
end

local function new_combinator(surface, params)
  local slots = {}
  local combinator = {
    valid = true,
    name = shared.COMBINATOR_NAME,
    force = params.force,
    surface = surface,
    position = {x = params.position.x, y = params.position.y},
    unit_number = alloc_unit_number(),
    output_signals = {},
  }

  local function rebuild_output()
    local signals = {}
    for _, slot in pairs(slots) do
      if slot and slot.value and slot.min and slot.min > 0 then
        local signal = resolve_signal_value(slot.value)
        signals[#signals + 1] = {
          signal = signal,
          count = slot.min,
        }
      end
    end
    combinator.output_signals = merge_signal_arrays(signals)
  end

  local section = {
    set_slot = function(index, spec)
      slots[index] = spec
      rebuild_output()
    end,
    clear_slot = function(index)
      slots[index] = nil
      rebuild_output()
    end,
  }

  local behavior = {
    get_section = function(_, index)
      if index == 1 then
        return section
      end
      return nil
    end,
    add_section = function()
      return section
    end,
  }

  function combinator.get_or_create_control_behavior()
    return behavior
  end

  function combinator.get_wire_connector()
    return new_wire_connector(combinator)
  end

  function combinator.destroy()
    combinator.valid = false
    remove_surface_entity(surface, combinator)
  end

  surface.entities[#surface.entities + 1] = combinator
  return combinator
end

local function new_surface(planet_name)
  local surface = {
    valid = true,
    entities = {},
    spilled_items = {},
    platform = nil,
  }

  surface.planet = {
    valid = true,
    name = planet_name,
    surface = surface,
  }

  function surface.find_entities_filtered(opts)
    local matches = {}
    for _, entity in ipairs(surface.entities) do
      if entity.valid and entity.name == opts.name then
        matches[#matches + 1] = entity
      end
    end
    return matches
  end

  function surface.create_entity(params)
    if params.name == shared.COMBINATOR_NAME then
      return new_combinator(surface, params)
    end
    error("unexpected entity creation: " .. tostring(params.name))
  end

  function surface.spill_item_stack(params)
    surface.spilled_items[#surface.spilled_items + 1] = params
  end

  return surface
end

local function new_fax_entity(surface, force, name, x, y, inventory_size)
  local entity = {
    valid = true,
    name = name,
    type = name == shared.RECEIVER_NAME and "assembling-machine" or "container",
    force = force,
    surface = surface,
    position = {x = x or 0, y = y or 0},
    unit_number = alloc_unit_number(),
    external_signals = {},
  }

  function entity.get_inventory(inventory_id)
    if name == shared.RECEIVER_NAME then
      if inventory_id == defines.inventory.assembling_machine_input then
        return entity.input_inventory
      end
      if inventory_id == defines.inventory.assembling_machine_output then
        return entity.output_inventory
      end
      return nil
    end

    assert_eq(inventory_id, defines.inventory.chest, "emitters should use chest inventory")
    return entity.inventory
  end

  function entity.get_wire_connector()
    return new_wire_connector(entity)
  end

  function entity.get_signals()
    return merge_signal_arrays(entity.external_signals, entity.combinator_ref and entity.combinator_ref.output_signals or nil)
  end

  function entity.destroy()
    entity.valid = false
    remove_surface_entity(surface, entity)
  end

  if name == shared.RECEIVER_NAME then
    entity.input_inventory = new_inventory(inventory_size or 5)
    entity.output_inventory = new_inventory(1)
    entity.fluidbox = {nil, nil, nil, nil}
    entity.recipe = nil
    entity.active = false

    function entity.set_recipe(recipe_name)
      entity.recipe = recipe_name and {name = recipe_name} or nil
      return true
    end

    function entity.get_recipe()
      return entity.recipe
    end
  else
    entity.inventory = new_inventory(inventory_size or 20)
  end

  surface.entities[#surface.entities + 1] = entity
  return entity
end

local function new_context()
  storage = {}
  next_unit_number = 100

  local player = new_player(1)
  local force = new_force()
  local nauvis = new_surface("nauvis")
  local vulcanus = new_surface("vulcanus")
  local gleba = new_surface("gleba")
  local aquilo = new_surface("aquilo")

  game = {
    surfaces = {
      [1] = nauvis,
      [2] = vulcanus,
      [3] = gleba,
      [4] = aquilo,
    },
    players = {
      [1] = player,
    },
    connected_players = {
      [1] = player,
    },
    get_player = function(index)
      return game.players[index]
    end,
  }

  fax.ensure_storage()

  return {
    player = player,
    force = force,
    surfaces = {
      nauvis = nauvis,
      vulcanus = vulcanus,
      gleba = gleba,
      aquilo = aquilo,
    },
  }
end

local function find_signal(signals, signal_name)
  for _, entry in ipairs(signals or {}) do
    if entry.signal and entry.signal.name == signal_name then
      return entry.count, entry.signal
    end
  end
  return nil, nil
end

local function charge_receiver(receiver, item_name_or_multiplier, multiplier)
  local item_name = nil
  if type(item_name_or_multiplier) == "string" then
    item_name = item_name_or_multiplier
    multiplier = multiplier or 1
  else
    multiplier = item_name_or_multiplier or 1
  end

  local requirements = shared.get_reconstruction_requirements(item_name or "work-order")
  receiver.input_inventory.insert{name = shared.RECONSTRUCTION_PAPER_ITEM, count = requirements.sheets * multiplier}
  receiver.input_inventory.insert{name = shared.RECONSTRUCTION_SUBSTRATE_ITEM, count = requirements.substrate * multiplier}
  if requirements.ribbon > 0 then
    receiver.input_inventory.insert{name = shared.RECONSTRUCTION_RIBBON_ITEM, count = requirements.ribbon * multiplier}
  end
end

local function get_fluid_amount(receiver, fluid_name)
  local total = 0
  for _, entry in ipairs(receiver.fluidbox or {}) do
    if entry and entry.name == fluid_name then
      total = total + (entry.amount or 0)
    end
  end
  return total
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

local function gui_contains_caption(root, caption)
  if not root or not root.valid then return false end
  if root.caption == caption then
    return true
  end
  for _, child in ipairs(root.children or {}) do
    if gui_contains_caption(child, caption) then
      return true
    end
  end
  return false
end

local function gui_contains_localised_key(root, key)
  if not root then return false end
  if type(root.caption) == "table" and root.caption[1] == key then return true end
  for _, child in pairs(root.children or {}) do
    if gui_contains_localised_key(child, key) then return true end
  end
  return false
end

local function gui_contains_text(root, needle)
  if not root or not root.valid or not needle then return false end
  if type(root.caption) == "string" and root.caption:find(needle, 1, true) then
    return true
  end
  for _, child in ipairs(root.children or {}) do
    if gui_contains_text(child, needle) then
      return true
    end
  end
  return false
end

test("second receiver on the same planet is rejected", function()
  local ctx = new_context()
  local receiver_a = new_fax_entity(ctx.surfaces.nauvis, ctx.force, shared.RECEIVER_NAME, 0, 0, 20)
  local receiver_b = new_fax_entity(ctx.surfaces.nauvis, ctx.force, shared.RECEIVER_NAME, 2, 0, 20)

  assert_true(fax.on_entity_built(receiver_a, ctx.player), "first receiver should place successfully")
  assert_true(not fax.on_entity_built(receiver_b, ctx.player), "second receiver should be rejected")
  assert_true(not receiver_b.valid, "rejected receiver should be destroyed")
  assert_eq(ctx.player.inserted_items[shared.RECEIVER_NAME], 1, "rejected receiver should be returned to the player")
end)

test("emitter destination persists through the GUI dropdown", function()
  local ctx = new_context()
  local emitter = new_fax_entity(ctx.surfaces.nauvis, ctx.force, shared.EMITTER_NAME, 0, 0, 12)
  assert_true(fax.on_entity_built(emitter, ctx.player), "emitter should place successfully")

  fax.on_gui_opened(ctx.player, emitter)
  local frame = ctx.player.gui.left[shared.GUI_FRAME_NAME]
  assert_true(frame ~= nil and frame.valid, "emitter GUI should open when the emitter is opened")
  local dropdown = frame[shared.GUI_DROPDOWN_NAME]
  assert_true(dropdown ~= nil and dropdown.valid, "destination dropdown should exist")

  dropdown.selected_index = 2
  fax.on_gui_selection_state_changed({
    player_index = ctx.player.index,
    element = dropdown,
  })

  assert_eq(storage.fax_emitters[emitter.unit_number].destination_planet, "vulcanus",
    "dropdown selection should update the emitter destination")

  fax.on_gui_closed(ctx.player)
  fax.on_gui_opened(ctx.player, emitter)
  frame = ctx.player.gui.left[shared.GUI_FRAME_NAME]
  dropdown = frame[shared.GUI_DROPDOWN_NAME]
  assert_eq(dropdown.selected_index, 2, "reopening the GUI should preserve the selected destination")
end)

test("receiver opens a custom screen UI and replaces the vanilla entity window", function()
  local ctx = new_context()
  local receiver = new_fax_entity(ctx.surfaces.vulcanus, ctx.force, shared.RECEIVER_NAME, 0, 0, 20)
  fax.on_entity_built(receiver, ctx.player)
  storage.fax_receivers[receiver.unit_number].queue = {
    {name = "work-order", quality_name = nil, source_planet = "nauvis"},
  }

  ctx.player.opened = receiver
  fax.on_gui_opened(ctx.player, receiver)

  local frame = ctx.player.gui.screen[shared.RECEIVER_GUI_FRAME_NAME]
  assert_true(frame ~= nil and frame.valid, "receiver should open a dedicated screen GUI")
  assert_true(ctx.player.gui.left[shared.GUI_FRAME_NAME] == nil, "receiver should not reuse the emitter side panel")
  assert_true(ctx.player.opened == frame, "opening the receiver should replace the vanilla window with the custom screen GUI")
  assert_true(gui_contains_caption(frame, "Queue"), "receiver queue should expose a dedicated queue section")
  assert_true(gui_contains_localised_key(frame, "gui.fax-required-media"),
    "receiver queue should include a localized column for dry-media requirements")
  assert_true(gui_contains_text(frame, "Queued"),
    "receiver queue rows should include explicit state text")

  fax.on_gui_closed(ctx.player)
  assert_true(frame.valid, "the receiver GUI should survive the synthetic close triggered by replacing the vanilla window")
end)

test("receiver request is mirrored to emitters without gating what can be sent", function()
  local ctx = new_context()
  local receiver = new_fax_entity(ctx.surfaces.vulcanus, ctx.force, shared.RECEIVER_NAME, 0, 0, 20)
  local emitter = new_fax_entity(ctx.surfaces.nauvis, ctx.force, shared.EMITTER_NAME, 0, 0, 12)

  assert_true(fax.on_entity_built(receiver, ctx.player), "receiver should place successfully")
  assert_true(fax.on_entity_built(emitter, ctx.player), "emitter should place successfully")
  storage.fax_emitters[emitter.unit_number].destination_planet = "vulcanus"
  receiver.external_signals = {
    {signal = {type = "item", name = "work-order"}, count = 3},
  }
  emitter.inventory.insert{name = "construction-permit", count = 1}

  fax.on_tick({tick = 60})

  assert_true(storage.fax_emitters[emitter.unit_number].current_job ~= nil,
    "emitter should start a job even when the requested document is different")

  local mirrored_count = find_signal(storage.fax_emitters[emitter.unit_number].combinator.output_signals, "work-order")
  assert_eq(mirrored_count, 3, "emitter should mirror the receiver request signal")
end)

test("colored paperwork requires color faxing research", function()
  local ctx = new_context()
  local receiver = new_fax_entity(ctx.surfaces.vulcanus, ctx.force, shared.RECEIVER_NAME, 0, 0, 20)
  local emitter = new_fax_entity(ctx.surfaces.nauvis, ctx.force, shared.EMITTER_NAME, 0, 0, 12)

  fax.on_entity_built(receiver, ctx.player)
  fax.on_entity_built(emitter, ctx.player)
  storage.fax_emitters[emitter.unit_number].destination_planet = "vulcanus"
  emitter.inventory.insert{name = "blank-cyan-form", count = 1}

  fax.on_tick({tick = 60})

  assert_true(storage.fax_emitters[emitter.unit_number].current_job == nil,
    "colored paperwork should not transmit before color faxing is researched")

  ctx.force.technologies["color-faxing"].researched = true
  fax.on_tick({tick = 120})

  assert_true(storage.fax_emitters[emitter.unit_number].current_job ~= nil,
    "colored paperwork should transmit once color faxing is researched")
end)

test("queue reservations create backpressure across planets", function()
  local ctx = new_context()
  local receiver = new_fax_entity(ctx.surfaces.vulcanus, ctx.force, shared.RECEIVER_NAME, 0, 0, 20)
  fax.on_entity_built(receiver, ctx.player)

  local emitters = {}
  for index = 1, 6 do
    local emitter = new_fax_entity(ctx.surfaces.nauvis, ctx.force, shared.EMITTER_NAME, index * 2, 0, 12)
    fax.on_entity_built(emitter, ctx.player)
    storage.fax_emitters[emitter.unit_number].destination_planet = "vulcanus"
    emitter.inventory.insert{name = "work-order", count = 1}
    emitters[#emitters + 1] = emitter
  end

  fax.on_tick({tick = 60})

  local active_jobs = 0
  local idle_jobs = 0
  for _, emitter in ipairs(emitters) do
    if storage.fax_emitters[emitter.unit_number].current_job then
      active_jobs = active_jobs + 1
    else
      idle_jobs = idle_jobs + 1
    end
  end
  assert_eq(active_jobs, 5, "only five transmissions should reserve queue space at the base cap")
  assert_eq(idle_jobs, 1, "one emitter should wait until queue space opens")
end)

test("queue capacity upgrades raise the exported free slot count to twenty", function()
  local ctx = new_context()
  ctx.force.technologies["fax-queue-capacity-1"].researched = true
  ctx.force.technologies["fax-queue-capacity-2"].researched = true
  ctx.force.technologies["fax-queue-capacity-3"].researched = true

  local receiver = new_fax_entity(ctx.surfaces.vulcanus, ctx.force, shared.RECEIVER_NAME, 0, 0, 20)
  local emitter = new_fax_entity(ctx.surfaces.nauvis, ctx.force, shared.EMITTER_NAME, 0, 0, 12)
  fax.on_entity_built(receiver, ctx.player)
  fax.on_entity_built(emitter, ctx.player)
  storage.fax_emitters[emitter.unit_number].destination_planet = "vulcanus"

  fax.on_tick({tick = 60})

  local free_slots = find_signal(storage.fax_emitters[emitter.unit_number].combinator.output_signals, shared.SIGNAL_FREE_SLOTS)
  assert_eq(free_slots, 20, "fully upgraded fax networks should export twenty free queue slots")
end)

test("faxed documents consume dry transfer media and preserve quality when printed", function()
  local ctx = new_context()
  local receiver = new_fax_entity(ctx.surfaces.vulcanus, ctx.force, shared.RECEIVER_NAME, 0, 0, 20)
  local emitter = new_fax_entity(ctx.surfaces.nauvis, ctx.force, shared.EMITTER_NAME, 0, 0, 12)
  fax.on_entity_built(receiver, ctx.player)
  fax.on_entity_built(emitter, ctx.player)
  storage.fax_emitters[emitter.unit_number].destination_planet = "vulcanus"

  charge_receiver(receiver, "construction-permit", 1)
  emitter.inventory.insert{name = "construction-permit", count = 1, quality = "legendary"}

  fax.on_tick({tick = 60})
  fax.on_tick({tick = 120})
  fax.on_tick({tick = 240})

  assert_eq(receiver.input_inventory.get_item_count(shared.RECONSTRUCTION_PAPER_ITEM), 0,
    "printing should consume one thermal transfer sheet")
  assert_eq(receiver.input_inventory.get_item_count(shared.RECONSTRUCTION_SUBSTRATE_ITEM), 0,
    "printing should consume archival substrate")
  assert_eq(receiver.input_inventory.get_item_count(shared.RECONSTRUCTION_RIBBON_ITEM), 0,
    "black paperwork should not consume a chroma-ribbon charge")
  assert_eq(receiver.output_inventory.get_item_count("construction-permit"), 1, "printed document should be inserted into the receiver output slot")

  local printed_quality = nil
  for slot = 1, #receiver.output_inventory do
    local stack = receiver.output_inventory[slot]
    if stack.valid_for_read and stack.name == "construction-permit" then
      printed_quality = quality_name(stack)
    end
  end
  assert_eq(printed_quality, "legendary", "printed fax output should preserve quality")
end)

test("colored faxing consumes the correct solid-media tier", function()
  local ctx = new_context()
  local receiver = new_fax_entity(ctx.surfaces.vulcanus, ctx.force, shared.RECEIVER_NAME, 0, 0, 20)
  local emitter = new_fax_entity(ctx.surfaces.nauvis, ctx.force, shared.EMITTER_NAME, 0, 0, 12)
  fax.on_entity_built(receiver, ctx.player)
  fax.on_entity_built(emitter, ctx.player)
  storage.fax_emitters[emitter.unit_number].destination_planet = "vulcanus"
  ctx.force.technologies["color-faxing"].researched = true

  charge_receiver(receiver, "cyan-yellow-form", 1)
  emitter.inventory.insert{name = "cyan-yellow-form", count = 1}

  fax.on_tick({tick = 60})
  fax.on_tick({tick = 120})
  fax.on_tick({tick = 240})

  assert_eq(receiver.output_inventory.get_item_count("cyan-yellow-form"), 1,
    "a color document should print once its dry media are available")
  assert_eq(receiver.input_inventory.get_item_count(shared.RECONSTRUCTION_PAPER_ITEM), 0,
    "bicolor paperwork should consume one transfer sheet")
  assert_eq(receiver.input_inventory.get_item_count(shared.RECONSTRUCTION_SUBSTRATE_ITEM), 0,
    "bicolor paperwork should consume two archival substrates")
  assert_eq(receiver.input_inventory.get_item_count(shared.RECONSTRUCTION_RIBBON_ITEM), 0,
    "bicolor paperwork should consume one chroma-ribbon charge")
end)

test("successful faxing consumes the original paperwork at the emitter", function()
  local ctx = new_context()
  local receiver = new_fax_entity(ctx.surfaces.vulcanus, ctx.force, shared.RECEIVER_NAME, 0, 0, 20)
  local emitter = new_fax_entity(ctx.surfaces.nauvis, ctx.force, shared.EMITTER_NAME, 0, 0, 1)
  fax.on_entity_built(receiver, ctx.player)
  fax.on_entity_built(emitter, ctx.player)
  storage.fax_emitters[emitter.unit_number].destination_planet = "vulcanus"

  emitter.inventory.insert{name = "work-order", count = 1}

  fax.on_tick({tick = 60})
  assert_eq(emitter.inventory.get_item_count("work-order"), 0,
    "the emitter should hold the original document out of the slot while transmitting")

  fax.on_tick({tick = 120})
  assert_eq(#ctx.surfaces.nauvis.spilled_items, 0, "successful faxing should consume rather than duplicate the original document")
  assert_eq(emitter.inventory.get_item_count("work-order"), 0, "the original should not be put back into the emitter slot automatically")
end)

test("missing supplies and blocked output stall printing without losing the queued document", function()
  local ctx = new_context()
  local receiver = new_fax_entity(ctx.surfaces.vulcanus, ctx.force, shared.RECEIVER_NAME, 0, 0, 20)
  fax.on_entity_built(receiver, ctx.player)
  storage.fax_receivers[receiver.unit_number].queue = {
    {name = "work-order", quality_name = nil, source_planet = "nauvis"},
  }

  fax.on_tick({tick = 60})
  assert_eq(#storage.fax_receivers[receiver.unit_number].queue, 1, "queue should remain unchanged when supplies are missing")
  assert_true(storage.fax_receivers[receiver.unit_number].active_print == nil, "no print job should start without paper and ink")

  charge_receiver(receiver, 1)
  fax.on_tick({tick = 120})
  assert_true(storage.fax_receivers[receiver.unit_number].active_print ~= nil, "printing should begin once supplies are available")

  receiver.output_inventory.force_block_insert = true
  fax.on_tick({tick = 240})
  assert_true(storage.fax_receivers[receiver.unit_number].active_print ~= nil,
    "blocked output should keep the finished document in progress instead of deleting it")
  assert_eq(receiver.output_inventory.get_item_count("work-order"), 0, "blocked output should not insert the document early")

  receiver.output_inventory.force_block_insert = false
  fax.on_tick({tick = 300})
  assert_true(storage.fax_receivers[receiver.unit_number].active_print == nil, "unblocked output should finish the print job")
  assert_eq(receiver.output_inventory.get_item_count("work-order"), 1, "the stalled document should eventually print")
end)

test("receiver signal toggles suppress request intake and exported outputs", function()
  local ctx = new_context()
  local receiver = new_fax_entity(ctx.surfaces.vulcanus, ctx.force, shared.RECEIVER_NAME, 0, 0, 20)
  fax.on_entity_built(receiver, ctx.player)
  receiver.external_signals = {
    {signal = {type = "item", name = "work-order"}, count = 4},
  }

  fax.on_tick({tick = 60})
  assert_eq(find_signal(storage.fax_receivers[receiver.unit_number].combinator.output_signals, shared.SIGNAL_FREE_SLOTS), 5,
    "receivers should export free queue slots by default")
  assert_eq(find_signal(storage.fax_receivers[receiver.unit_number].combinator.output_signals, "work-order"), 4,
    "receivers should export the top request by default")

  ctx.player.opened = receiver
  fax.on_gui_opened(ctx.player, receiver)
  local frame = ctx.player.gui.screen[shared.RECEIVER_GUI_FRAME_NAME]
  local queue_button = find_gui_element(frame, shared.RECEIVER_GUI_QUEUE_BUTTON_NAME)
  local request_button = find_gui_element(frame, shared.RECEIVER_GUI_TOP_REQUEST_BUTTON_NAME)
  local accept_button = find_gui_element(frame, shared.RECEIVER_GUI_ACCEPT_BUTTON_NAME)

  queue_button.state = false
  fax.on_gui_checked_state_changed({player_index = ctx.player.index, element = queue_button})
  assert_true(find_signal(storage.fax_receivers[receiver.unit_number].combinator.output_signals, shared.SIGNAL_FREE_SLOTS) == nil,
    "disabling queue reads should remove queue visibility signals")
  assert_eq(find_signal(storage.fax_receivers[receiver.unit_number].combinator.output_signals, "work-order"), 4,
    "disabling queue reads should leave top-request reads alone")

  request_button.state = false
  fax.on_gui_checked_state_changed({player_index = ctx.player.index, element = request_button})
  assert_true(find_signal(storage.fax_receivers[receiver.unit_number].combinator.output_signals, "work-order") == nil,
    "disabling top-request reads should remove the request signal output")

  accept_button.state = false
  fax.on_gui_checked_state_changed({player_index = ctx.player.index, element = accept_button})
  assert_true(storage.fax_receivers[receiver.unit_number].current_request_signal == nil,
    "disabling circuit requests should clear the active request")
  assert_true(storage.fax_receivers[receiver.unit_number].request_signals[1] == nil,
    "disabling circuit requests should ignore imported request signals")
  assert_true(gui_contains_caption(frame, "Circuit requests are disabled."),
    "the receiver UI should show that circuit requests are disabled")
end)

test("receiver queue output signals can be remapped from the custom UI", function()
  local ctx = new_context()
  local receiver = new_fax_entity(ctx.surfaces.vulcanus, ctx.force, shared.RECEIVER_NAME, 0, 0, 20)
  fax.on_entity_built(receiver, ctx.player)

  fax.on_tick({tick = 60})
  assert_eq(find_signal(storage.fax_receivers[receiver.unit_number].combinator.output_signals, shared.SIGNAL_FREE_SLOTS), 5,
    "receivers should default to the built-in free-slots signal")

  ctx.player.opened = receiver
  fax.on_gui_opened(ctx.player, receiver)
  local frame = ctx.player.gui.screen[shared.RECEIVER_GUI_FRAME_NAME]
  local selector = find_gui_element(frame, shared.RECEIVER_GUI_FREE_SIGNAL_NAME)
  assert_true(selector ~= nil and selector.valid, "the free-slots signal selector should exist")

  selector.elem_value = {type = "virtual", name = "signal-A"}
  fax.on_gui_elem_changed({
    player_index = ctx.player.index,
    element = selector,
  })

  assert_true(find_signal(storage.fax_receivers[receiver.unit_number].combinator.output_signals, shared.SIGNAL_FREE_SLOTS) == nil,
    "changing the selector should stop exporting the old free-slots signal")
  assert_eq(find_signal(storage.fax_receivers[receiver.unit_number].combinator.output_signals, "signal-A"), 5,
    "changing the selector should export queue free-space on the chosen virtual signal")
end)

test("removing the receiver spills queued documents and keeps in-flight source paperwork intact", function()
  local ctx = new_context()
  local receiver = new_fax_entity(ctx.surfaces.vulcanus, ctx.force, shared.RECEIVER_NAME, 0, 0, 20)
  local emitter = new_fax_entity(ctx.surfaces.nauvis, ctx.force, shared.EMITTER_NAME, 0, 0, 12)
  fax.on_entity_built(receiver, ctx.player)
  fax.on_entity_built(emitter, ctx.player)
  storage.fax_emitters[emitter.unit_number].destination_planet = "vulcanus"
  emitter.inventory.insert{name = "work-order", count = 1}
  storage.fax_receivers[receiver.unit_number].queue = {
    {name = "resolved-noise", quality_name = nil, source_planet = "nauvis"},
  }

  fax.on_tick({tick = 60})
  local buffer = new_inventory(4)
  fax.on_entity_removed(receiver, buffer)
  receiver.destroy()
  fax.on_tick({tick = 120})

  assert_eq(buffer.get_item_count("resolved-noise"), 1, "queued receiver documents should be returned when the receiver is removed")
  assert_eq(emitter.inventory.get_item_count("work-order"), 1, "in-flight sender paperwork should stay at the source if the receiver disappears")
end)

test("registry rebuild skips absent fax prototypes", function()
  local ctx = new_context()
  local stale_combinator = {valid = true, destroyed = false}
  function stale_combinator.destroy()
    stale_combinator.destroyed = true
    stale_combinator.valid = false
  end

  storage.fax_receivers[123] = {
    entity = {valid = false},
    combinator = stale_combinator,
  }

  local old_prototypes = prototypes
  prototypes = {entity = {}}

  local old_find = ctx.surfaces.nauvis.find_entities_filtered
  function ctx.surfaces.nauvis.find_entities_filtered()
    error("find_entities_filtered should not be called for absent fax prototypes")
  end

  local ok, err = pcall(fax.rebuild_registry)
  ctx.surfaces.nauvis.find_entities_filtered = old_find
  prototypes = old_prototypes

  assert_true(ok, err)
  assert_true(storage.fax_receivers[123] == nil, "stale fax receiver state should still be cleaned up")
end)

if failed > 0 then
  io.stderr:write(("Failed %d/%d tests\n"):format(failed, passed + failed))
  for _, err in ipairs(errors) do
    io.stderr:write(err, "\n")
  end
  os.exit(1)
end

print(("Passed %d tests"):format(passed))
