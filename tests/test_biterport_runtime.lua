-------------------------------------------------------------------------------
-- ADMINISTRATORIO BITERPORT RUNTIME TESTS
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

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function assert_true(value, message)
  if not value then error(message or "assertion failed", 2) end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

storage = {}
defines = {
  direction = {north = 0, east = 2, south = 4, west = 6},
  entity_status_diode = {red = 1, yellow = 2, green = 3},
  inventory = {
    chest = 1,
    car_trunk = 2,
    spider_trunk = 3,
    cargo_wagon = 4,
    character_main = 5,
    character_trash = 6,
  },
  command = {go_to_location = 1},
  distraction = {none = 0},
}

package.loaded["scripts.working_hours"] = nil
package.preload["scripts.working_hours"] = function()
  return {
    is_enabled = function() return false end,
    is_night = function() return false end,
  }
end

local function new_inventory(size, initial_items)
  local inventory = {size = size or 8, items = {}}

  local function rebuild_slots()
    for i = 1, inventory.size do inventory[i] = nil end
    local slot = 1
    for name, count in pairs(inventory.items) do
      if count > 0 then
        inventory[slot] = {valid_for_read = true, name = name, count = count}
        slot = slot + 1
      end
    end
  end

  function inventory.get_item_count(name)
    if name then return inventory.items[name] or 0 end
    local total = 0
    for _, count in pairs(inventory.items) do total = total + count end
    return total
  end

  function inventory.can_insert(stack)
    return stack and stack.name ~= nil and (stack.count or 0) > 0
  end

  function inventory.insert(stack)
    if not stack or not stack.name then return 0 end
    inventory.items[stack.name] = (inventory.items[stack.name] or 0) + (stack.count or 0)
    rebuild_slots()
    return stack.count or 0
  end

  function inventory.remove(stack)
    if not stack or not stack.name then return 0 end
    local available = inventory.items[stack.name] or 0
    local removed = math.min(available, stack.count or 0)
    inventory.items[stack.name] = available - removed
    if inventory.items[stack.name] <= 0 then inventory.items[stack.name] = nil end
    rebuild_slots()
    return removed
  end

  function inventory.resize(new_size)
    inventory.size = new_size
    rebuild_slots()
  end

  function inventory.supports_filters()
    return true
  end

  function inventory.set_filter() end

  setmetatable(inventory, {
    __len = function(self) return self.size end,
  })

  for name, count in pairs(initial_items or {}) do
    inventory.items[name] = count
  end
  rebuild_slots()
  return inventory
end

local function within(area, position)
  return position.x >= area.left_top.x
    and position.x <= area.right_bottom.x
    and position.y >= area.left_top.y
    and position.y <= area.right_bottom.y
end

local function new_surface()
  local next_unit_number = 1000
  local surface = {
    index = 1,
    chests = {},
    hidden = {},
  }

  function surface.find_non_colliding_position(_, position)
    return {x = position.x, y = position.y}
  end

  function surface.find_entities_filtered(params)
    if params.type == "logistic-container" and params.area then
      local entities = {}
      for _, chest in ipairs(surface.chests) do
        if chest.valid and within(params.area, chest.position) then
          entities[#entities + 1] = chest
        end
      end
      return entities
    end
    if params.name == "biterport-hidden-roboport" then
      return {}
    end
    if params.name == "biterport-coffee-input" then
      return {}
    end
    return {}
  end

  function surface.create_entity(params)
    next_unit_number = next_unit_number + 1
    local entity = {
      valid = true,
      name = params.name,
      position = {x = params.position.x, y = params.position.y},
      surface = surface,
      force = params.force,
      unit_number = next_unit_number,
      bounding_box = {
        left_top = {x = params.position.x - 0.4, y = params.position.y - 0.4},
        right_bottom = {x = params.position.x + 0.4, y = params.position.y + 0.4},
      },
      commandable = {
        has_command = false,
      },
    }
    function entity.commandable.set_command(command)
      entity.last_command = command
      entity.commandable.has_command = true
    end
    function entity.destroy()
      entity.valid = false
      entity.commandable.has_command = false
    end
    if params.name == "biterport-hidden-roboport" or params.name == "biterport-coffee-input" then
      entity.destructible = false
      entity.minable = false
      entity.operable = false
      surface.hidden[#surface.hidden + 1] = entity
    end
    return entity
  end

  function surface.spill_item_stack() end

  return surface
end

local function new_chest(surface, unit_number, position, logistic_mode, items)
  local inventory = new_inventory(8, items)
  local chest = {
    valid = true,
    unit_number = unit_number,
    name = "logistic-chest-" .. logistic_mode,
    type = "logistic-container",
    position = position,
    surface = surface,
    force = nil,
    prototype = {logistic_mode = logistic_mode},
    bounding_box = {
      left_top = {x = position.x - 0.5, y = position.y - 0.5},
      right_bottom = {x = position.x + 0.5, y = position.y + 0.5},
    },
  }
  function chest.get_inventory(index)
    assert_eq(index, defines.inventory.chest, "logistic chest should use chest inventory")
    return inventory
  end
  surface.chests[#surface.chests + 1] = chest
  chest.inventory = inventory
  return chest
end

local function new_port(surface, force, workers, money)
  local inventory = new_inventory(6, {
    ["biter-logistics-formation"] = workers or 1,
    ["taxpayer-money"] = money or 1,
  })
  local port = {
    valid = true,
    unit_number = 10,
    name = "biterport",
    type = "container",
    position = {x = 0, y = 0},
    surface = surface,
    force = force,
    direction = defines.direction.north,
    minable = true,
    bounding_box = {
      left_top = {x = -1, y = -1},
      right_bottom = {x = 1, y = 1},
    },
  }
  function port.get_inventory(index)
    assert_eq(index, defines.inventory.chest, "biterport should use chest inventory")
    return inventory
  end
  port.inventory = inventory
  return port
end

local function new_player(surface, force, request_filters, main_items, trash_items)
  local character = {
    valid = true,
    unit_number = 20,
    position = {x = 4, y = 0},
    bounding_box = {
      left_top = {x = 3.6, y = -0.4},
      right_bottom = {x = 4.4, y = 0.4},
    },
  }
  local main_inventory = new_inventory(20, main_items)
  local trash_inventory = new_inventory(20, trash_items)
  local player = {
    valid = true,
    index = 1,
    surface = surface,
    force = force,
    position = character.position,
    character = character,
  }
  function player.get_requester_point()
    return {
      valid = true,
      enabled = true,
      filters = request_filters or {},
    }
  end
  function player.get_main_inventory()
    return main_inventory
  end
  function player.get_inventory(index)
    if index == defines.inventory.character_main then return main_inventory end
    if index == defines.inventory.character_trash then return trash_inventory end
    return nil
  end
  function player.insert(stack)
    return main_inventory.insert(stack)
  end
  function player.get_item_count(name)
    return main_inventory.get_item_count(name)
  end
  player.main_inventory = main_inventory
  player.trash_inventory = trash_inventory
  setmetatable(player, {
    __index = function(_, key)
      error("LuaPlayer doesn't contain key " .. tostring(key), 2)
    end,
  })
  return player
end

local function first_active_worker()
  for _, active in pairs(storage.biterport_workers or {}) do
    return active
  end
  return nil
end

local function advance_worker_to(active, position, tick, biterport)
  active.biter.position = {x = position.x, y = position.y}
  biterport.on_ai_command_completed{unit_number = active.biter_unit_number, tick = tick}
  biterport.update(tick + 1)
end

test("biterport refills player personal logistics requests", function()
  storage = {}
  local surface = new_surface()
  local force = {
    name = "player",
    technologies = {},
    set_cease_fire = function() end,
  }

  game = {
    tick = 0,
    connected_players = {},
    surfaces = {surface},
    forces = {
      player = force,
      enemy = {name = "enemy", set_cease_fire = function() end},
      neutral = {name = "neutral", set_cease_fire = function() end},
    },
    create_force = function(name)
      local created = {name = name, technologies = {}, valid = true, set_cease_fire = function() end}
      game.forces[name] = created
      return created
    end,
  }

  local biterport = require("scripts.biterport")
  local port = new_port(surface, force, 2, 2)
  local provider = new_chest(surface, 30, {x = 2, y = 0}, "passive-provider", {["iron-plate"] = 3})
  provider.force = force
  local player = new_player(surface, force, {{name = "iron-plate", count = 1}}, {}, {})
  game.connected_players = {player}

  biterport.ensure_storage()
  biterport.track_port(port)
  biterport.update(30)

  local active = first_active_worker()
  assert_true(active ~= nil, "player request should dispatch a logistics worker")
  advance_worker_to(active, provider.position, 30, biterport)
  active = first_active_worker()
  advance_worker_to(active, player.character.position, 31, biterport)

  assert_eq(player.main_inventory.get_item_count("iron-plate"), 1, "player should receive requested item")
  assert_eq(provider.inventory.get_item_count("iron-plate"), 2, "provider chest should lose delivered item")
end)

test("biterport empties player trash into network storage", function()
  storage = {}
  package.loaded["scripts.biterport"] = nil

  local surface = new_surface()
  local force = {
    name = "player",
    technologies = {},
    set_cease_fire = function() end,
  }

  game = {
    tick = 0,
    connected_players = {},
    surfaces = {surface},
    forces = {
      player = force,
      enemy = {name = "enemy", set_cease_fire = function() end},
      neutral = {name = "neutral", set_cease_fire = function() end},
    },
    create_force = function(name)
      local created = {name = name, technologies = {}, valid = true, set_cease_fire = function() end}
      game.forces[name] = created
      return created
    end,
  }

  local biterport = require("scripts.biterport")
  local port = new_port(surface, force, 2, 2)
  local storage_chest = new_chest(surface, 31, {x = 7, y = 0}, "storage", {})
  storage_chest.force = force
  local player = new_player(surface, force, {}, {}, {["stone"] = 1})
  game.connected_players = {player}

  biterport.ensure_storage()
  biterport.track_port(port)
  biterport.update(30)

  local active = first_active_worker()
  assert_true(active ~= nil, "player trash should dispatch a logistics worker")
  advance_worker_to(active, player.character.position, 30, biterport)
  active = first_active_worker()
  advance_worker_to(active, storage_chest.position, 31, biterport)

  assert_eq(player.trash_inventory.get_item_count("stone"), 0, "trash inventory should be emptied")
  assert_eq(storage_chest.inventory.get_item_count("stone"), 1, "storage chest should receive trashed item")
end)

test("biterport ignores players without a character body", function()
  storage = {}
  package.loaded["scripts.biterport"] = nil

  local surface = new_surface()
  local force = {
    name = "player",
    technologies = {},
    set_cease_fire = function() end,
  }

  game = {
    tick = 0,
    connected_players = {},
    surfaces = {surface},
    forces = {
      player = force,
      enemy = {name = "enemy", set_cease_fire = function() end},
      neutral = {name = "neutral", set_cease_fire = function() end},
    },
    create_force = function(name)
      local created = {name = name, technologies = {}, valid = true, set_cease_fire = function() end}
      game.forces[name] = created
      return created
    end,
  }

  local biterport = require("scripts.biterport")
  local port = new_port(surface, force, 2, 2)
  local provider = new_chest(surface, 30, {x = 2, y = 0}, "passive-provider", {["iron-plate"] = 3})
  provider.force = force
  local player = new_player(surface, force, {{name = "iron-plate", count = 1}}, {}, {})
  player.character = nil
  game.connected_players = {player}

  biterport.ensure_storage()
  biterport.track_port(port)
  biterport.update(30)

  assert_true(first_active_worker() == nil, "characterless players should not spawn walking logistics jobs")
end)

print(("Biterport runtime tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
