package.path = "./?.lua;./?/init.lua;" .. package.path

defines = {
  direction = {north = 0, east = 2, south = 4, west = 6},
  inventory = {chest = 1, car_trunk = 2, spider_trunk = 3, cargo_wagon = 4, character_main = 5},
  command = {go_to_location = 1},
  distraction = {none = 0},
}
storage = {}

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function assert_true(value, message)
  if not value then
    error(message or "expected value to be truthy", 2)
  end
end

local function new_inventory(initial_count)
  local inventory = {count = initial_count or 0, valid = true}
  function inventory.get_item_count(name)
    return name == "eviction-notice" and inventory.count or 0
  end
  function inventory.insert(stack)
    if stack.name ~= "eviction-notice" then return 0 end
    inventory.count = inventory.count + stack.count
    return stack.count
  end
  function inventory.remove(stack)
    if stack.name ~= "eviction-notice" then return 0 end
    local removed = math.min(inventory.count, stack.count)
    inventory.count = inventory.count - removed
    return removed
  end
  function inventory.destroy()
    inventory.valid = false
  end
  return inventory
end

game = {
  players = {},
  created_inventories = {},
}

function game.create_inventory(_size)
  local inventory = new_inventory()
  game.created_inventories[#game.created_inventories + 1] = inventory
  return inventory
end

function game.get_player(index)
  return game.players[index]
end

local hired_biter = require("scripts.hired_biter")
local C = require("scripts.constants")

local function new_surface()
  local surface = {
    find_calls = {},
    created_entities = {},
    nests = {},
    click_agent = nil,
    notice_chest = nil,
    network_items = 0,
    index = 1,
  }

  function surface.find_non_colliding_position(name, position, radius, precision)
    surface.find_calls[#surface.find_calls + 1] = {
      name = name,
      position = position,
      radius = radius,
      precision = precision,
    }
    return {x = position.x + 1, y = position.y + 1}
  end

  function surface.find_entities_filtered(params)
    if params.name == "hired-biter-supply-chest" then return {} end
    if params.area then
      local entities = {}
      if surface.click_agent then entities[#entities + 1] = surface.click_agent end
      if surface.notice_chest then entities[#entities + 1] = surface.notice_chest end
      return entities
    end
    return surface.nests
  end

  function surface.find_logistic_network_by_position()
    return {
      remove_item = function(stack)
        local removed = math.min(surface.network_items, stack.count)
        surface.network_items = surface.network_items - removed
        return removed
      end,
    }
  end

  function surface.create_entity(params)
    surface.created_entities[#surface.created_entities + 1] = params
    local entity = {
      valid = true,
      name = params.name,
      unit_number = 42,
      position = params.position,
      surface = surface,
      force = {name = params.force or "player"},
      last_command = nil,
    }
    entity.commandable = {
      set_command = function(command)
        entity.last_command = command
      end,
    }
    return entity
  end

  return surface
end

hired_biter.ensure_storage()

local surface = new_surface()
local deployed = hired_biter.on_deploy(surface, {x = 10, y = 20})

assert_true(deployed, "deploy should report success")
assert_eq(#surface.find_calls, 1, "deploy should request a non-colliding position")
assert_eq(surface.find_calls[1].name, C.HIRED_BITER_UNIT_NAME, "deploy should search for the hired biter collision box")
assert_eq(#surface.created_entities, 1, "deploy should create only the biter field agent")
assert_eq(surface.created_entities[1].position.x, 11, "unit should use the safe position x")
assert_eq(surface.created_entities[1].position.y, 21, "unit should use the safe position y")
assert_eq(storage.hired_biters[42].state, "exploring", "deployed biter should be tracked")
assert_true(storage.hired_biters[42].inventory ~= nil, "field agent should receive hidden notice inventory")

local entry = storage.hired_biters[42]
surface.network_items = 3
surface.nests = {{valid = true, position = {x = 50, y = 60}}}

hired_biter.update(C.HIRED_BITER_SCAN_COOLDOWN)

assert_eq(entry.inventory.get_item_count("eviction-notice"), 3, "agent should refill notices from a logistic network")
assert_eq(entry.state, "moving_to_nest", "agent should move toward a discovered nest")
assert_eq(entry.entity.last_command.destination.x, 50, "agent should command toward nest x")
assert_eq(entry.entity.last_command.destination.y, 60, "agent should command toward nest y")

hired_biter.on_player_selected_area{
  player_index = 1,
  item = C.HIRED_BITER_REMOTE_NAME,
  entities = {entry.entity},
}
assert_eq(storage.hired_biter_selected[1][1], 42, "remote should select the field agent")

game.players[1] = {
  index = 1,
  valid = true,
  surface = surface,
  main_inventory = new_inventory(),
  force = {
    is_chunk_charted = function() return true end,
  },
  cursor_stack = {
    valid_for_read = true,
    name = C.HIRED_BITER_REMOTE_NAME,
  },
  print = function() end,
  create_local_flying_text = function() end,
}
game.players[1].get_main_inventory = function()
  return game.players[1].main_inventory
end

storage.hired_biter_selected[1] = nil
surface.click_agent = entry.entity
hired_biter.on_remote_waypoint_input{
  player_index = 1,
  input_name = "administratorio-field-agent-toggle-select",
  cursor_position = {x = entry.entity.position.x, y = entry.entity.position.y},
}
assert_eq(storage.hired_biter_selected[1][1], 42, "left click should select a field agent under the cursor")

hired_biter.on_remote_waypoint_input{
  player_index = 1,
  input_name = "administratorio-field-agent-toggle-select",
  cursor_position = {x = entry.entity.position.x, y = entry.entity.position.y},
}
assert_true(storage.hired_biter_selected[1] == nil, "left click should unselect a selected field agent")

surface.click_agent = nil
storage.hired_biter_selected[1] = {42}

hired_biter.on_player_reverse_selected_area{
  player_index = 1,
  item = C.HIRED_BITER_REMOTE_NAME,
}
assert_eq(storage.hired_biter_selected[1][1], 42, "right-click reverse-select should not clear selected field agents")

hired_biter.on_remote_waypoint_input{
  player_index = 1,
  input_name = "administratorio-field-agent-set-waypoint",
  cursor_position = {x = 100, y = 120},
}

assert_eq(entry.state, "moving_to_command", "set waypoint should command selected agents")
assert_eq(entry.command_dest.x, 100, "set waypoint should use cursor x")
assert_eq(entry.entity.last_command.destination.y, 120, "set waypoint should command cursor y")

hired_biter.on_remote_waypoint_input{
  player_index = 1,
  input_name = "administratorio-field-agent-append-waypoint",
  cursor_position = {x = 130, y = 140},
}

assert_eq(#entry.waypoints, 1, "append waypoint should queue a later destination")
assert_eq(entry.waypoints[1].destination.x, 130, "append waypoint should preserve queued x")

hired_biter.on_ai_command_completed{unit_number = 42}
assert_eq(entry.command_dest.x, 130, "command completion should advance queued waypoint")
assert_eq(#entry.waypoints, 0, "command completion should consume queued waypoint")

entry.inventory.count = 0
surface.notice_chest = {
  valid = true,
  position = {x = 5, y = 5},
  inventory = new_inventory(7),
}
function surface.notice_chest.get_inventory(index)
  assert_eq(index, defines.inventory.chest, "supply command should inspect chest inventory first")
  return surface.notice_chest.inventory
end

hired_biter.on_remote_waypoint_input{
  player_index = 1,
  input_name = "administratorio-field-agent-set-waypoint",
  cursor_position = {x = 5, y = 5},
}

assert_eq(entry.state, "moving_to_supply", "right click on a chest should command a supply run")
assert_eq(entry.command_dest.x, 5, "supply command should target chest x")
assert_eq(entry.inventory.get_item_count("eviction-notice"), 0, "supply run should wait until arrival before taking notices")

entry.entity.position = {x = 5, y = 5}
hired_biter.on_ai_command_completed{unit_number = 42}

assert_eq(entry.inventory.get_item_count("eviction-notice"), 7, "arrival at chest should move notices into hidden inventory")
assert_eq(surface.notice_chest.inventory.get_item_count("eviction-notice"), 0, "arrival at chest should drain moved notices from chest")

entry.inventory.count = 0
surface.notice_chest.inventory.count = 4
local notice_chest = surface.notice_chest
surface.notice_chest = nil
hired_biter.on_remote_waypoint_input{
  player_index = 1,
  input_name = "administratorio-field-agent-set-waypoint",
  cursor_position = {x = 90, y = 95},
}
surface.notice_chest = notice_chest
hired_biter.on_remote_waypoint_input{
  player_index = 1,
  input_name = "administratorio-field-agent-append-waypoint",
  cursor_position = {x = 5, y = 5},
}
assert_eq(entry.waypoints[1].supply_entity, surface.notice_chest, "shift-right click on a chest should append a supply run")

print("Hired biter tests: passed")
