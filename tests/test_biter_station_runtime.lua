-------------------------------------------------------------------------------
-- ADMINISTRATORIO BITER STATION RUNTIME TESTS
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
  inventory = {chest = 1},
  command = {go_to_location = 1},
  distraction = {none = 0},
}

package.loaded["scripts.working_hours"] = nil
package.preload["scripts.working_hours"] = function()
  return {
    is_enabled = function() return false end,
    is_night = function() return false end,
    is_managed_entity = function() return false end,
    refresh_entity = function() end,
  }
end

local drawn = {}
local next_render_id = 0
rendering = {}

function rendering.draw_text(params)
  next_render_id = next_render_id + 1
  local obj = {id = next_render_id, params = params, destroyed = false}
  function obj.destroy()
    obj.destroyed = true
  end
  drawn[obj.id] = obj
  return obj
end

function rendering.get_object_by_id(id)
  return drawn[id]
end

local function new_inventory(initial_items)
  local inventory = {items = {}}
  for name, count in pairs(initial_items or {}) do
    inventory.items[name] = count
  end
  function inventory.get_item_count(name)
    return inventory.items[name] or 0
  end
  function inventory.remove(stack)
    local available = inventory.items[stack.name] or 0
    local removed = math.min(available, stack.count or 0)
    inventory.items[stack.name] = available - removed
    if inventory.items[stack.name] <= 0 then inventory.items[stack.name] = nil end
    return removed
  end
  function inventory.insert(stack)
    inventory.items[stack.name] = (inventory.items[stack.name] or 0) + (stack.count or 0)
    return stack.count or 0
  end
  function inventory.can_insert()
    return true
  end
  function inventory.resize() end
  function inventory.supports_filters()
    return true
  end
  function inventory.set_filter() end
  setmetatable(inventory, {__len = function() return 20 end})
  return inventory
end

local function new_surface()
  local surface = {
    index = 1,
    created_entities = {},
    buildings = {},
  }
  function surface.find_non_colliding_position(_, position)
    return {x = position.x + 0.5, y = position.y}
  end
  function surface.find_entities_filtered(params)
    if type(params.name) == "table" then
      return surface.buildings
    end
    return {}
  end
  function surface.create_entity(params)
    local entity = {
      valid = true,
      name = params.name,
      position = {x = params.position.x, y = params.position.y},
      surface = surface,
      force = params.force,
      unit_number = 1000 + #surface.created_entities,
      commandable = {has_command = false},
    }
    function entity.commandable.set_command(command)
      entity.last_command = command
      entity.commandable.has_command = true
    end
    function entity.destroy()
      entity.valid = false
    end
    surface.created_entities[#surface.created_entities + 1] = entity
    return entity
  end
  function surface.spill_item_stack() end
  return surface
end

local function new_station(surface, force, opts)
  opts = opts or {}
  local inventory = new_inventory(opts.inventory or {["biter-worker"] = 1, ["taxpayer-money"] = 1})
  local station = {
    valid = true,
    name = "biter-station",
    unit_number = opts.unit_number or 10,
    position = opts.position or {x = 0, y = 0},
    surface = surface,
    force = force,
    minable = true,
  }
  function station.get_inventory(index)
    assert_eq(index, defines.inventory.chest, "station should use chest inventory")
    return inventory
  end
  station.inventory = inventory
  return station
end

local function new_managed_building(surface, force, opts)
  opts = opts or {}
  local building = {
    valid = true,
    name = "printer-t2",
    unit_number = opts.unit_number or 20,
    position = opts.position or {x = 2, y = 0},
    surface = surface,
    force = force,
    active = false,
    products_finished = 0,
    crafting_progress = 0,
    bounding_box = {
      left_top = {x = 1.5, y = -0.5},
      right_bottom = {x = 2.5, y = 0.5},
    },
  }
  function building.get_recipe()
    return {name = "dummy"}
  end
  surface.buildings[#surface.buildings + 1] = building
  return building
end

local function active_worker()
  for _, state in pairs(storage.biter_station_biter or {}) do
    return state
  end
  return nil
end

test("platform industrial printers use onboard authorization instead of biter dispatch", function()
  storage = {}
  package.loaded["scripts.biter_station"] = nil
  local surface = new_surface()
  surface.platform = {valid = true}
  local force = {name = "player", valid = true, technologies = {}, set_cease_fire = function() end}
  game = {
    tick = 0,
    surfaces = {surface},
    forces = {player = force},
    create_force = function(name)
      local created = {name = name, valid = true, technologies = {}, set_cease_fire = function() end}
      game.forces[name] = created
      return created
    end,
  }
  local building = new_managed_building(surface, force)
  local biter_station = require("scripts.biter_station")

  biter_station.track_managed_building(building)

  assert_true(building.active, "platform industrial printer should remain active")
  assert_true(storage.managed_building_registry[building.unit_number] == nil,
    "platform industrial printer should not wait in the terrestrial dispatch registry")
end)

test("biter station restores active worker if its entity is invalid after load", function()
  storage = {}
  package.loaded["scripts.biter_station"] = nil
  local surface = new_surface()
  local force = {name = "player", valid = true, set_cease_fire = function() end, technologies = {}}
  game = {
    tick = 0,
    surfaces = {surface},
    forces = {
      player = force,
      enemy = {name = "enemy", valid = true, set_cease_fire = function() end},
      neutral = {name = "neutral", valid = true, set_cease_fire = function() end},
    },
    create_force = function(name)
      local created = {name = name, valid = true, set_cease_fire = function() end, technologies = {}}
      game.forces[name] = created
      return created
    end,
  }

  local biter_station = require("scripts.biter_station")
  local station = new_station(surface, force)
  local building = new_managed_building(surface, force)
  biter_station.track_station(station)
  biter_station.track_managed_building(building)

  biter_station.update(10)

  local active = active_worker()
  assert_true(active ~= nil, "managed building should dispatch a station worker")
  local old_unit_number = active.biter_unit_number
  active.biter.valid = false

  biter_station.update(20)

  active = active_worker()
  assert_true(active ~= nil, "active station worker should survive invalid entity recovery")
  assert_true(active.biter ~= nil and active.biter.valid, "station worker entity should be recreated")
  assert_true(active.biter_unit_number ~= old_unit_number, "restored worker should receive a fresh unit number")
  assert_true(storage.biter_station_biter[old_unit_number] == nil, "old active worker key should be removed")
  assert_eq(storage.biter_station_worker_units[old_unit_number], nil, "old worker unit marker should be removed")
  assert_eq(storage.managed_building_run[building.unit_number].claimed_by, active.biter_unit_number, "building claim should be moved to the restored worker")
end)

test("biter station keeps a triggered machine active until recipe progress wraps", function()
  storage = {}
  package.loaded["scripts.biter_station"] = nil
  local surface = new_surface()
  local force = {name = "player", valid = true, set_cease_fire = function() end, technologies = {}}
  game = {
    tick = 0,
    surfaces = {surface},
    forces = {
      player = force,
      enemy = {name = "enemy", valid = true, set_cease_fire = function() end},
      neutral = {name = "neutral", valid = true, set_cease_fire = function() end},
    },
    create_force = function(name)
      local created = {name = name, valid = true, set_cease_fire = function() end, technologies = {}}
      game.forces[name] = created
      return created
    end,
  }

  local biter_station = require("scripts.biter_station")
  local station = new_station(surface, force)
  local building = new_managed_building(surface, force)
  biter_station.track_station(station)
  biter_station.track_managed_building(building)

  biter_station.update(10)
  local active = active_worker()
  assert_true(active ~= nil, "managed building should dispatch a station worker")
  active.biter.position = {x = building.position.x, y = building.position.y}

  biter_station.update(20)
  assert_true(building.active, "arrival should activate the managed building")

  building.crafting_progress = 0.65
  biter_station.update(30)
  assert_true(building.active, "machine should stay active while the same recipe is still in progress")

  building.crafting_progress = 0.05
  biter_station.update(40)
  assert_eq(building.active, false, "machine should stop after the recipe progress wraps")
  assert_eq(storage.managed_building_run[building.unit_number], nil, "completed recipe authorization should clear runtime state")
end)

test("labor efficiency charges only for the buildings assigned to a trip", function()
  storage = {}
  package.loaded["scripts.biter_station"] = nil
  local surface = new_surface()
  local force = {name = "player", valid = true, set_cease_fire = function() end, technologies = {}}
  game = {
    tick = 0,
    surfaces = {surface},
    forces = {
      player = force,
      enemy = {name = "enemy", valid = true, set_cease_fire = function() end},
      neutral = {name = "neutral", valid = true, set_cease_fire = function() end},
    },
    create_force = function(name)
      local created = {name = name, valid = true, set_cease_fire = function() end, technologies = {}}
      game.forces[name] = created
      return created
    end,
  }

  local biter_station = require("scripts.biter_station")
  local station = new_station(surface, force, {
    inventory = {['biter-worker'] = 1, ['taxpayer-money'] = 1},
  })
  local building = new_managed_building(surface, force)
  biter_station.track_station(station)
  biter_station.track_managed_building(building)
  storage.biter_station_crafts_per_visit = 3

  biter_station.update(10)

  local active = active_worker()
  assert_true(active ~= nil, "one funded assignment should dispatch at labor efficiency tier one")
  assert_eq(#active.building_queue, 1, "worker trip should contain only the building that needs activation")
  assert_eq(active.dispatch_salary, 1, "one-building trip should reserve one taxpayer money")

  active.biter.position = {x = building.position.x, y = building.position.y}
  active.phase_departed = true
  biter_station.update(20)
  assert_eq(active.phase, "to_station", "worker should return after its only assignment")

  active.biter.position = {x = station.position.x, y = station.position.y}
  active.phase_departed = true
  biter_station.update(30)
  assert_eq(station.inventory.get_item_count("taxpayer-money"), 0, "completed one-building trip should charge exactly one taxpayer money")
end)

test("worker skips an unreachable second building instead of freezing in place", function()
  storage = {}
  package.loaded["scripts.biter_station"] = nil
  local surface = new_surface()
  local force = {name = "player", valid = true, set_cease_fire = function() end, technologies = {}}
  game = {
    tick = 0,
    surfaces = {surface},
    forces = {
      player = force,
      enemy = {name = "enemy", valid = true, set_cease_fire = function() end},
      neutral = {name = "neutral", valid = true, set_cease_fire = function() end},
    },
    create_force = function(name)
      local created = {name = name, valid = true, set_cease_fire = function() end, technologies = {}}
      game.forces[name] = created
      return created
    end,
  }

  local biter_station = require("scripts.biter_station")
  local station = new_station(surface, force)
  local building_one = new_managed_building(surface, force, {unit_number = 21, position = {x = 2, y = 0}})
  local building_two = new_managed_building(surface, force, {unit_number = 22, position = {x = 15, y = 0}})
  building_two.bounding_box = {
    left_top = {x = 14.5, y = -0.5},
    right_bottom = {x = 15.5, y = 0.5},
  }
  biter_station.track_station(station)
  biter_station.track_managed_building(building_one)
  biter_station.track_managed_building(building_two)
  storage.biter_station_crafts_per_visit = 2

  biter_station.update(10)

  local active = active_worker()
  assert_true(active ~= nil, "station should dispatch a worker")
  assert_eq(#active.building_queue, 2, "trip should cover both buildings")

  active.biter.position = {x = building_one.position.x, y = building_one.position.y}
  active.phase_departed = true
  biter_station.update(20)
  assert_eq(active.current_idx, 2, "arriving at the first building should advance the queue")
  assert_eq(active.phase, "to_building", "worker should now be heading to the second building")

  biter_station.on_ai_command_completed{unit_number = active.biter_unit_number, tick = 25, result = "fail"}

  assert_eq(active.current_idx, 3, "an unreachable second building should be skipped, not retried forever")
  assert_true(active.biter.valid, "worker should not be destroyed when a building is unreachable")
  assert_true(active.biter.commandable.has_command, "worker should receive a new command instead of freezing in place")
  assert_eq(station.custom_status.label[1], "gui.biter-station-building-unreachable", "station should surface the pathing failure")
end)

test("managed building is claimed by the nearest station in overlapping coverage", function()
  storage = {}
  package.loaded["scripts.biter_station"] = nil
  local surface = new_surface()
  local force = {name = "player", valid = true, set_cease_fire = function() end, technologies = {}}
  game = {
    tick = 0,
    surfaces = {surface},
    forces = {
      player = force,
      enemy = {name = "enemy", valid = true, set_cease_fire = function() end},
      neutral = {name = "neutral", valid = true, set_cease_fire = function() end},
    },
    create_force = function(name)
      local created = {name = name, valid = true, set_cease_fire = function() end, technologies = {}}
      game.forces[name] = created
      return created
    end,
  }

  local biter_station = require("scripts.biter_station")
  local farther_station = new_station(surface, force, {unit_number = 10, position = {x = 0, y = 0}})
  local closer_station = new_station(surface, force, {unit_number = 11, position = {x = 18, y = 0}})
  local building = new_managed_building(surface, force, {position = {x = 20, y = 0}})
  biter_station.track_station(farther_station)
  biter_station.track_station(closer_station)
  biter_station.track_managed_building(building)

  biter_station.update(10)

  local closer_workers = storage.biter_station_active_by_station[closer_station.unit_number]
  local farther_workers = storage.biter_station_active_by_station[farther_station.unit_number]
  assert_true(closer_workers ~= nil and next(closer_workers) ~= nil, "closer station should dispatch the worker")
  assert_true(farther_workers == nil or next(farther_workers) == nil, "farther station should not claim the overlapping building")

  local active = active_worker()
  assert_eq(active.station_id, closer_station.unit_number, "active worker should belong to the closest station")
  assert_eq(storage.managed_building_run[building.unit_number].claimed_by, active.biter_unit_number, "building should be claimed by the closest station worker")
end)

test("biter station stays minable while workers are active", function()
  storage = {}
  package.loaded["scripts.biter_station"] = nil
  local surface = new_surface()
  local force = {name = "player", valid = true, set_cease_fire = function() end, technologies = {}}
  game = {
    tick = 0,
    surfaces = {surface},
    forces = {
      player = force,
      enemy = {name = "enemy", valid = true, set_cease_fire = function() end},
      neutral = {name = "neutral", valid = true, set_cease_fire = function() end},
    },
    create_force = function(name)
      local created = {name = name, valid = true, set_cease_fire = function() end, technologies = {}}
      game.forces[name] = created
      return created
    end,
  }

  local biter_station = require("scripts.biter_station")
  local station = new_station(surface, force)
  local building = new_managed_building(surface, force)
  biter_station.track_station(station)
  biter_station.track_managed_building(building)

  biter_station.update(10)

  assert_true(active_worker() ~= nil, "managed building should dispatch a station worker")
  assert_eq(station.minable, true, "biter station should remain minable while a worker is out")
end)

test("almost-returned station worker protests instead of despawning after host removal", function()
  storage = {}
  package.loaded["scripts.biter_station"] = nil
  package.loaded["scripts.biters"] = nil

  local protested_entity = nil
  local biters_stub = {
    trigger_immediate_protest = function(entity, _, _, opts)
      protested_entity = entity
      assert_true(opts and opts.preserve_entity == true, "worker protest conversion should preserve the existing entity")
      return true
    end,
  }

  local surface = new_surface()
  local force = {name = "player", valid = true, set_cease_fire = function() end, technologies = {}}
  game = {
    tick = 0,
    surfaces = {surface},
    forces = {
      player = force,
      enemy = {name = "enemy", valid = true, set_cease_fire = function() end},
      neutral = {name = "neutral", valid = true, set_cease_fire = function() end},
    },
    create_force = function(name)
      local created = {name = name, valid = true, set_cease_fire = function() end, technologies = {}}
      game.forces[name] = created
      return created
    end,
  }

  local biter_station = require("scripts.biter_station")
  biter_station.set_biters_module(biters_stub)
  local station = new_station(surface, force)
  local building = new_managed_building(surface, force)
  biter_station.track_station(station)
  biter_station.track_managed_building(building)

  biter_station.update(10)

  local active = active_worker()
  assert_true(active ~= nil, "managed building should dispatch a station worker")
  local worker_entity = active.biter
  active.phase = "to_station"
  active.phase_destination = {x = station.position.x, y = station.position.y}
  active.phase_departed = true

  biter_station.untrack_station(station, 10)
  assert_eq(active.phase, "orphaned_returning", "returning worker should lose the removed-station return route")

  worker_entity.position = {x = station.position.x, y = station.position.y}
  biter_station.on_ai_command_completed{unit_number = active.biter_unit_number, tick = 20}
  biter_station.update(30)

  assert_true(protested_entity == worker_entity, "orphaned worker should protest immediately when no host has space")
  assert_true(worker_entity.valid, "orphaned worker should not despawn at the removed station position")
  assert_true(active_worker() == nil, "converted protester should leave station active worker tracking")
end)

test("non-returning orphaned station worker protests immediately without a host", function()
  storage = {}
  package.loaded["scripts.biter_station"] = nil
  package.loaded["scripts.biters"] = nil

  local protested_entity = nil
  local biters_stub = {
    trigger_immediate_protest = function(entity, _, _, opts)
      protested_entity = entity
      assert_true(opts and opts.preserve_entity == true, "worker protest conversion should preserve the existing entity")
      return true
    end,
  }

  local surface = new_surface()
  local force = {name = "player", valid = true, set_cease_fire = function() end, technologies = {}}
  game = {
    tick = 0,
    surfaces = {surface},
    forces = {
      player = force,
      enemy = {name = "enemy", valid = true, set_cease_fire = function() end},
      neutral = {name = "neutral", valid = true, set_cease_fire = function() end},
    },
    create_force = function(name)
      local created = {name = name, valid = true, set_cease_fire = function() end, technologies = {}}
      game.forces[name] = created
      return created
    end,
  }

  local biter_station = require("scripts.biter_station")
  biter_station.set_biters_module(biters_stub)
  local station = new_station(surface, force)
  local building = new_managed_building(surface, force)
  biter_station.track_station(station)
  biter_station.track_managed_building(building)

  biter_station.update(10)

  local active = active_worker()
  assert_true(active ~= nil, "managed building should dispatch a station worker")
  local worker_entity = active.biter
  active.current_idx = #(active.building_queue or {}) + 1

  biter_station.untrack_station(station, 10)
  assert_eq(active.phase, "orphaned_returning", "finished non-returning worker should become orphaned")
  assert_true(protested_entity == worker_entity, "orphaned worker should become a protester immediately")
  assert_true(active_worker() == nil, "converted protester should leave station active worker tracking")
end)

print(("Biter station runtime tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
