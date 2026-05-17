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
local function disabled_working_hours()
  return {
    is_enabled = function() return false end,
    is_night = function() return false end,
  }
end
package.preload["scripts.working_hours"] = disabled_working_hours

local function set_working_hours(enabled, night)
  package.loaded["scripts.working_hours"] = nil
  package.preload["scripts.working_hours"] = function()
    return {
      is_enabled = function() return enabled end,
      is_night = function() return night end,
    }
  end
end

local function reset_working_hours()
  package.loaded["scripts.working_hours"] = nil
  package.preload["scripts.working_hours"] = disabled_working_hours
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
    created = {},
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
      local entities = {}
      for _, entity in ipairs(surface.created) do
        if entity.valid and entity.name == params.name then
          entities[#entities + 1] = entity
        end
      end
      return entities
    end
    if params.name == "biterport-wall-blocker" then
      local entities = {}
      for _, entity in ipairs(surface.created) do
        if entity.valid and entity.name == params.name then
          entities[#entities + 1] = entity
        end
      end
      return entities
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
      direction = params.direction,
      bounding_box = {
        left_top = {x = params.position.x - 0.4, y = params.position.y - 0.4},
        right_bottom = {x = params.position.x + 0.4, y = params.position.y + 0.4},
      },
      fluidbox = {},
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
    function entity.insert_fluid(fluid)
      entity.fluidbox[1] = {name = fluid.name, amount = fluid.amount}
      return fluid.amount
    end
    if params.name == "biterport-hidden-roboport" or params.name == "biterport-coffee-input" then
      entity.destructible = false
      entity.minable = false
      entity.operable = false
      surface.hidden[#surface.hidden + 1] = entity
    end
    surface.created[#surface.created + 1] = entity
    return entity
  end

  function surface.spill_item_stack() end

  return surface
end

local function new_chest(surface, unit_number, position, logistic_mode, items, request_filters)
  local inventory = new_inventory(8, items)
  local section
  if request_filters then
    section = {
      valid = true,
      filters_count = #request_filters,
      filters = {},
    }
    for i, filter in ipairs(request_filters) do
      section.filters[i] = {
        value = filter.value or filter.name,
        min = filter.min or filter.count or 0,
        max = filter.max,
      }
    end
    function section.get_slot(slot_index)
      local filter = section.filters[slot_index]
      if not filter then return nil end
      return {
        value = filter.value,
        min = filter.min,
        max = filter.max,
      }
    end
    function section.set_slot(slot_index, filter)
      section.filters[slot_index] = {
        value = filter.value or filter.name,
        min = filter.min or filter.count or 0,
        max = filter.max,
      }
    end
  end
  local names_by_mode = {
    ["passive-provider"] = "paperwork-provider-chest",
    storage = "paperwork-storage-chest",
    requester = "paperwork-requester-chest",
  }
  local chest = {
    valid = true,
    unit_number = unit_number,
    name = names_by_mode[logistic_mode] or ("logistic-chest-" .. logistic_mode),
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
  if section then
    function chest.get_requester_point()
      return {
        valid = true,
        enabled = true,
        filters = section.filters,
        sections = {section},
        sections_count = 1,
        get_section = function(index)
          if index == 1 then return section end
          return nil
        end,
      }
    end
    chest.request_section = section
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

local function active_worker_count()
  local count = 0
  for _ in pairs(storage.biterport_workers or {}) do
    count = count + 1
  end
  return count
end

local function advance_worker_to(active, position, tick, biterport)
  active.biter.position = {x = position.x, y = position.y}
  biterport.on_ai_command_completed{unit_number = active.biter_unit_number, tick = tick}
  biterport.update(tick + 1)
end

test("biterport uses symmetric entrances and central all-sided coffee input", function()
  storage = {}
  set_working_hours(true, true)
  package.loaded["scripts.biterport"] = nil
  local surface = new_surface()
  local force = {
    name = "player",
    technologies = {},
    set_cease_fire = function() end,
  }
  game = {
    tick = 0,
    forces = {player = force, neutral = force},
    create_force = function() return force end,
  }

  local biterport = require("scripts.biterport")
  local port = new_port(surface, force, 1, 1)
  port.position = {x = 0.5, y = 0.5}
  biterport.track_port(port)

  local blockers = {}
  for _, entity in ipairs(surface.created) do
    if entity.valid and entity.name == "biterport-wall-blocker" then
      blockers[entity.position.x .. "," .. entity.position.y] = true
    end
  end

  assert_true(not blockers["0.5,-1.5"], "north center entrance should stay open")
  assert_true(not blockers["2.5,0.5"], "east center entrance should stay open")
  assert_true(not blockers["0.5,2.5"], "south center entrance should stay open")
  assert_true(not blockers["-1.5,0.5"], "west center entrance should stay open")
  assert_true(blockers["-1.5,-1.5"], "northwest wall segment should be blocked")
  assert_true(blockers["2.5,-1.5"], "northeast wall segment should be blocked")
  assert_true(blockers["-1.5,2.5"], "southwest wall segment should be blocked")
  assert_true(blockers["2.5,2.5"], "southeast wall segment should be blocked")

  local input = storage.biterport_coffee_inputs[port.unit_number]
  assert_true(input ~= nil and input.valid, "track_port should create the hidden coffee input")
  assert_eq(input.name, "biterport-coffee-input", "coffee input should be one all-sided hidden fluid box")
  assert_eq(input.position.x, port.position.x, "coffee input should be centered on the building")
  assert_eq(input.position.y, port.position.y, "coffee input should be centered on the building")

  reset_working_hours()
  package.loaded["scripts.biterport"] = nil
end)

test("biterport coffee input keeps visible pipe connectors", function()
  local path = mod_root .. "prototypes/entity/admin-buildings.lua"
  local file = assert(io.open(path, "r"))
  local source = file:read("*a")
  file:close()
  local helper = source:match("local function make_hidden_coffee_input.-local biter_station_coffee_input")
  assert_true(helper ~= nil, "coffee input helper should exist")

  assert_true(not helper:find("input%.pictures%s*=%s*nil"), "coffee input should not hide pipe connector pictures")
  assert_true(not helper:find("input%.pipe_covers%s*=%s*nil"), "coffee input should not hide pipe covers")
  assert_true(not helper:find("flow_direction"), "pipe prototypes should not use directional flow connections")
  assert_true(helper:find("direction%s*=%s*defines%.direction%.north"), "pipe prototypes should keep required connection directions")
  assert_true(helper:find("position%s*=%s*{%s*%-2,%s*%-2%s*}"), "coffee input should expose corner pipe sockets")
  assert_true(not helper:find("position%s*=%s*{%s*%-1,%s*%-2%s*}"), "coffee input sockets should not sit one tile off center")
  assert_true(not helper:find("position%s*=%s*{%s*%-2,%s*%-3%s*}"), "coffee input sockets should not be one tile outside the building")
end)

test("biter station sprite metrics match updated assets", function()
  local path = mod_root .. "prototypes/entity/admin-buildings.lua"
  local file = assert(io.open(path, "r"))
  local source = file:read("*a")
  file:close()
  local station_block = source:match("biter_station%.picture.-biter_station%.draw_stateless_visualisations_in_ghost")
  assert_true(station_block ~= nil, "biter station graphics block should exist")
  assert_true(station_block:find("work%-station%-floor%.png.-width%s*=%s*480.-height%s*=%s*419"), "floor sprite metrics should match 480x419 asset")
  assert_true(station_block:find("work%-station%-roof%.png.-width%s*=%s*480.-height%s*=%s*419"), "roof sprite metrics should match 480x419 asset")
end)

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

test("biterport reserves requester chest deliveries instead of dispatching every worker", function()
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
  local port = new_port(surface, force, 4, 4)
  local provider = new_chest(surface, 30, {x = 2, y = 0}, "passive-provider", {["iron-plate"] = 10})
  provider.force = force
  local requester = new_chest(surface, 31, {x = 4, y = 0}, "requester", {}, {
    {name = "iron-plate", count = 100},
  })
  requester.force = force

  biterport.ensure_storage()
  biterport.track_port(port)
  biterport.update(30)

  assert_eq(active_worker_count(), 1, "one requester/item should reserve one biter, not every available worker")
  assert_eq(requester.request_section.filters[1].min, 0, "reserved requester slot should be paused while the biter is en route")

  local active = first_active_worker()
  advance_worker_to(active, provider.position, 90, biterport)
  active = first_active_worker()
  advance_worker_to(active, requester.position, 91, biterport)

  assert_eq(requester.inventory.get_item_count("iron-plate"), 1, "requester chest should receive the requested item")
  assert_eq(requester.request_section.filters[1].min, 100, "requester slot should be restored after delivery")
end)

test("biterport does not overdispatch claimed source inventory", function()
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
  local port = new_port(surface, force, 4, 4)
  local provider = new_chest(surface, 30, {x = 2, y = 0}, "passive-provider", {["iron-plate"] = 1})
  provider.force = force
  local requester_a = new_chest(surface, 31, {x = 4, y = 0}, "requester", {}, {
    {name = "iron-plate", count = 1},
  })
  requester_a.force = force
  local requester_b = new_chest(surface, 32, {x = 6, y = 0}, "requester", {}, {
    {name = "iron-plate", count = 1},
  })
  requester_b.force = force

  biterport.ensure_storage()
  biterport.track_port(port)
  biterport.update(30)

  assert_eq(active_worker_count(), 1, "one provider item should only be claimed by one biter job")
end)

test("biterport rotates identical requester chest jobs", function()
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
  local port = new_port(surface, force, 1, 4)
  local provider = new_chest(surface, 30, {x = 2, y = 0}, "passive-provider", {["iron-plate"] = 4})
  provider.force = force
  local requester_west = new_chest(surface, 31, {x = 4, y = 0}, "requester", {}, {
    {name = "iron-plate", count = 2},
  })
  requester_west.force = force
  local requester_east = new_chest(surface, 32, {x = 6, y = 0}, "requester", {}, {
    {name = "iron-plate", count = 2},
  })
  requester_east.force = force

  biterport.ensure_storage()
  biterport.track_port(port)
  biterport.update(30)

  local active = first_active_worker()
  assert_true(active ~= nil, "first identical requester should dispatch")
  assert_eq(active.job.target_unit_number, requester_west.unit_number, "first dispatch should start from the west requester")
  advance_worker_to(active, provider.position, 30, biterport)
  active = first_active_worker()
  advance_worker_to(active, requester_west.position, 31, biterport)
  active = first_active_worker()
  advance_worker_to(active, port.position, 32, biterport)

  biterport.update(90)
  active = first_active_worker()
  assert_true(active ~= nil, "second identical requester should dispatch after return cooldown")
  assert_eq(active.job.target_unit_number, requester_east.unit_number, "second dispatch should rotate to the east requester")
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

test("returned logistics workers wait 30 ticks before redeploying", function()
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
  local port = new_port(surface, force, 1, 3)
  local provider = new_chest(surface, 30, {x = 2, y = 0}, "passive-provider", {["iron-plate"] = 5})
  provider.force = force
  local player = new_player(surface, force, {{name = "iron-plate", count = 2}}, {}, {})
  game.connected_players = {player}

  biterport.ensure_storage()
  biterport.track_port(port)
  biterport.update(30)

  local active = first_active_worker()
  assert_true(active ~= nil, "first request should dispatch immediately")
  advance_worker_to(active, provider.position, 30, biterport)
  active = first_active_worker()
  advance_worker_to(active, player.character.position, 31, biterport)
  active = first_active_worker()
  advance_worker_to(active, port.position, 32, biterport)

  assert_true(first_active_worker() == nil, "worker should be back inside the port")
  biterport.update(60)
  assert_true(first_active_worker() == nil, "worker should still be cooling down 28 ticks after return")

  biterport.update(90)
  assert_true(first_active_worker() ~= nil, "worker should be dispatchable again after the 30 tick cooldown")
end)

test("biterport restores an active logistics worker if its entity is invalid after load", function()
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
  local port = new_port(surface, force, 1, 1)
  local provider = new_chest(surface, 30, {x = 2, y = 0}, "passive-provider", {["iron-plate"] = 1})
  provider.force = force
  local player = new_player(surface, force, {{name = "iron-plate", count = 1}}, {}, {})
  game.connected_players = {player}

  biterport.ensure_storage()
  biterport.track_port(port)
  biterport.update(30)

  local active = first_active_worker()
  assert_true(active ~= nil, "request should dispatch a worker before the simulated load")
  local old_unit_number = active.biter_unit_number
  active.biter.valid = false

  biterport.update(31)
  active = first_active_worker()
  assert_true(active ~= nil, "active worker record should survive invalid entity recovery")
  assert_true(active.biter.valid, "worker entity should be recreated")
  assert_true(active.biter_unit_number ~= old_unit_number, "worker should be rekeyed to the recreated unit")
  assert_true(storage.biterport_workers[old_unit_number] == nil, "old unit key should be removed")

  advance_worker_to(active, provider.position, 31, biterport)
  active = first_active_worker()
  advance_worker_to(active, player.character.position, 32, biterport)

  assert_eq(player.main_inventory.get_item_count("iron-plate"), 1, "recreated worker should finish the delivery")
  assert_eq(provider.inventory.get_item_count("iron-plate"), 0, "provider item should only be consumed once")
end)

test("transport capacity research increases items carried per trip", function()
  storage = {}
  package.loaded["scripts.biterport"] = nil

  local surface = new_surface()
  local force = {
    name = "player",
    technologies = {
      ["biterport-transport-capacity-1"] = {researched = true},
      ["biterport-transport-capacity-2"] = {researched = true},
      ["biterport-transport-capacity-3"] = {researched = true},
    },
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
  local provider = new_chest(surface, 30, {x = 2, y = 0}, "passive-provider", {["iron-plate"] = 20})
  provider.force = force
  local player = new_player(surface, force, {{name = "iron-plate", count = 10}}, {}, {})
  game.connected_players = {player}

  biterport.ensure_storage()
  biterport.track_port(port)
  biterport.update(30)

  local active = first_active_worker()
  assert_true(active ~= nil, "transport request should dispatch a logistics worker")
  assert_eq(active.job.count, 10, "capacity III should let a logistics biter carry ten items")
  advance_worker_to(active, provider.position, 30, biterport)
  active = first_active_worker()
  advance_worker_to(active, player.character.position, 31, biterport)

  assert_eq(player.main_inventory.get_item_count("iron-plate"), 10, "player should receive the full transport-capacity batch")
  assert_eq(provider.inventory.get_item_count("iron-plate"), 10, "provider chest should lose the full carried batch")
end)

test("transport capacity I carries two items per trip", function()
  storage = {}
  package.loaded["scripts.biterport"] = nil

  local surface = new_surface()
  local force = {
    name = "player",
    technologies = {
      ["biterport-transport-capacity-1"] = {researched = true},
    },
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
  local provider = new_chest(surface, 30, {x = 2, y = 0}, "passive-provider", {["iron-plate"] = 5})
  provider.force = force
  local player = new_player(surface, force, {{name = "iron-plate", count = 2}}, {}, {})
  game.connected_players = {player}

  biterport.ensure_storage()
  biterport.track_port(port)
  biterport.update(30)

  local active = first_active_worker()
  assert_true(active ~= nil, "transport request should dispatch a logistics worker")
  assert_eq(active.job.count, 2, "capacity I should let a logistics biter carry two items")
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
