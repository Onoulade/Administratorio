-------------------------------------------------------------------------------
-- ADMINISTRATORIO TRAINS TESTS
--
-- Verifies transit permit chests are positioned on the leading corner of the
-- rail-facing edge of train stops and that legacy placements migrate in place.
-- Run: lua tests/test_trains.lua
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

local function positions_match(a, b)
  if not a or not b then return false end
  return math.abs(a.x - b.x) < 0.001 and math.abs(a.y - b.y) < 0.001
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

defines = {
  direction = {
    north = 0,
    east = 2,
    south = 4,
    west = 6,
  },
  inventory = {
    chest = 1,
  },
  train_state = {
    wait_station = 1,
  },
}

local trains = dofile(mod_root .. "scripts/trains.lua")

local next_unit_number = 100

local function alloc_unit_number()
  next_unit_number = next_unit_number + 1
  return next_unit_number
end

local function new_inventory(initial_count)
  local count = initial_count or 0
  local filters = {}
  local stack = {valid_for_read = count > 0, count = count, name = "transit-authorization"}

  local function refresh_stack()
    stack.valid_for_read = count > 0
    stack.count = count
  end

  return setmetatable({
    get_item_count = function(name)
      if name == "transit-authorization" then
        return count
      end
      return 0
    end,
    supports_filters = function()
      return true
    end,
    set_filter = function(index, name)
      filters[index] = name
    end,
    remove = function(params)
      local removed = math.min(count, params.count or 0)
      count = count - removed
      refresh_stack()
      return removed
    end,
    _filters = filters,
  }, {
    __len = function()
      return 1
    end,
    __index = function(_, key)
      if key == 1 then
        return stack
      end
      return nil
    end,
  })
end

local function new_chest(surface, position, inventory_count)
  local inventory = new_inventory(inventory_count)
  local chest = {
    valid = true,
    name = "transit-permit-chest",
    position = {x = position.x, y = position.y},
    force = "player",
    destructible = true,
    minable = true,
    direction = defines.direction.north,
    surface = surface,
    unit_number = alloc_unit_number(),
  }

  chest.get_inventory = function(_)
    return inventory
  end

  chest.teleport = function(target_position)
    chest.position = {x = target_position.x, y = target_position.y}
    return true
  end

  chest.destroy = function()
    chest.valid = false
  end

  chest._inventory = inventory

  return chest
end

local function new_surface()
  local surface = {
    entities = {},
    created_entities = {},
    spilled_items = {},
  }

  surface.find_entities_filtered = function(params)
    local results = {}
    for _, entity in ipairs(surface.entities) do
      if entity.valid ~= false then
        local matches = true
        if params.name and entity.name ~= params.name then
          matches = false
        end
        if params.type and entity.type ~= params.type then
          matches = false
        end
        if matches and params.position and params.radius then
          if not positions_match(entity.position, params.position) then
            local dx = entity.position.x - params.position.x
            local dy = entity.position.y - params.position.y
            if math.sqrt(dx * dx + dy * dy) > params.radius then
              matches = false
            end
          end
        elseif matches and params.position then
          matches = positions_match(entity.position, params.position)
        end
        if matches then
          results[#results + 1] = entity
        end
      end
    end
    return results
  end

  surface.create_entity = function(params)
    if params.name == "transit-permit-chest" then
      local chest = new_chest(surface, params.position, 0)
      chest.force = params.force
      chest.direction = params.direction or chest.direction
      surface.entities[#surface.entities + 1] = chest
      surface.created_entities[#surface.created_entities + 1] = chest
      return chest
    end
    error("unexpected entity creation: " .. tostring(params.name))
  end

  surface.spill_item_stack = function(params)
    surface.spilled_items[#surface.spilled_items + 1] = params
  end

  return surface
end

local function new_station(surface, direction, position)
  local behavior = {}
  local station = {
    valid = true,
    type = "train-stop",
    name = "train-stop",
    position = {x = position.x, y = position.y},
    direction = direction,
    force = "player",
    unit_number = alloc_unit_number(),
    trains_limit = nil,
    surface = surface,
  }

  station.get_control_behavior = function()
    return behavior
  end

  station._behavior = behavior
  surface.entities[#surface.entities + 1] = station
  return station
end

local function new_runtime(surface)
  storage = {}
  game = {
    connected_players = {},
    surfaces = {[1] = surface},
  }
end

test("new train stops place permit chests on the leading rail-side corner for all directions", function()
  local expected_offsets = {
    [defines.direction.north] = {x = -0.5, y = 1.5},
    [defines.direction.east] = {x = -1.5, y = -0.5},
    [defines.direction.south] = {x = 0.5, y = -1.5},
    [defines.direction.west] = {x = 1.5, y = 0.5},
  }

  for direction, offset in pairs(expected_offsets) do
    local surface = new_surface()
    new_runtime(surface)
    local station = new_station(surface, direction, {x = 10, y = 20})

    trains.on_built(station)

    local station_data = storage.stations[station.unit_number]
    assert_true(station_data ~= nil, "station should be registered in storage")
    local chest = station_data.chest
    assert_true(chest ~= nil and chest.valid, "station should get a valid permit chest")
    assert_eq(chest.position.x, 10 + offset.x, "chest x offset should match the leading rail-side corner")
    assert_eq(chest.position.y, 20 + offset.y, "chest y offset should match the leading rail-side corner")
    assert_eq(chest.direction, direction, "new chest should inherit the station rotation")
    assert_eq(chest.destructible, false, "permit chest should be indestructible")
    assert_eq(chest.minable, false, "permit chest should not be minable")
    assert_eq(chest._inventory._filters[1], "transit-authorization", "permit chest should filter for transit forms")
    assert_eq(station.trains_limit, 0, "empty permit chest should close the station")
    assert_eq(station._behavior.circuit_enable_disable, false, "circuit enable/disable should stay locked off")
    assert_eq(station._behavior.set_trains_limit, false, "circuit train limits should stay locked off")
  end
end)

test("legacy overlapping permit chests are moved beside the rail and keep their contents", function()
  local surface = new_surface()
  new_runtime(surface)

  local station = new_station(surface, defines.direction.east, {x = 7, y = 1})
  local legacy_chest = new_chest(surface, {x = 7, y = 1}, 3)
  surface.entities[#surface.entities + 1] = legacy_chest

  trains.on_init()

  local station_data = storage.stations[station.unit_number]
  assert_true(station_data ~= nil, "station should be registered during init")
  assert_true(station_data.chest == legacy_chest, "existing permit chest should be reused for migration")
  assert_eq(#surface.created_entities, 0, "migration should not spawn a duplicate permit chest")
  assert_eq(legacy_chest.position.x, 5.5, "legacy chest should move to the leading rail-side corner for east-facing stops")
  assert_eq(legacy_chest.position.y, 0.5, "legacy chest should move to the leading rail-side corner for east-facing stops")
  assert_eq(station.trains_limit, 3, "migrated chest contents should continue to set the train limit")
end)

test("permit chests from the previous rail-edge placement migrate to the correct corner", function()
  local surface = new_surface()
  new_runtime(surface)

  local station = new_station(surface, defines.direction.north, {x = 9, y = 12})
  local misplaced_chest = new_chest(surface, {x = 8, y = 12}, 2)
  surface.entities[#surface.entities + 1] = misplaced_chest

  trains.on_init()

  local station_data = storage.stations[station.unit_number]
  assert_true(station_data ~= nil, "station should be registered during init")
  assert_true(station_data.chest == misplaced_chest, "existing misplaced permit chest should be reused for migration")
  assert_eq(#surface.created_entities, 0, "migration should not spawn a duplicate permit chest")
  assert_eq(misplaced_chest.position.x, 8.5, "north-facing stop chest should move below the stop on the rail-adjacent side")
  assert_eq(misplaced_chest.position.y, 13.5, "north-facing stop chest should move below the stop on the rail-adjacent side")
  assert_eq(station.trains_limit, 2, "migrated chest contents should continue to set the train limit")
end)

print(("Trains tests: %d passed, %d failed"):format(passed, failed))

if #errors > 0 then
  print("\nFAILURES:")
  for i, err in ipairs(errors) do
    print(("  %d) %s"):format(i, err))
  end
  os.exit(1)
end
