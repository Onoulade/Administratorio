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

local function new_station(surface, force)
  local inventory = new_inventory({["biter-worker"] = 1, ["taxpayer-money"] = 1})
  local station = {
    valid = true,
    name = "biter-station",
    unit_number = 10,
    position = {x = 0, y = 0},
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

local function new_managed_building(surface, force)
  local building = {
    valid = true,
    name = "printer-t2",
    unit_number = 20,
    position = {x = 2, y = 0},
    surface = surface,
    force = force,
    active = false,
    products_finished = 0,
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

print(("Biter station runtime tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
