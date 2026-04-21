-------------------------------------------------------------------------------
-- ADMINISTRATORIO RIDEABLE BITER RUNTIME TESTS
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

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

storage = {}
defines = {
  inventory = {
    car_trunk = 1,
  },
}
game = {
  tick = 0,
  surfaces = {},
  forces = {enemy = {name = "enemy"}},
  connected_players = {},
}

local routed = nil
package.loaded["scripts.biters"] = nil
package.preload["scripts.biters"] = function()
  return {
    send_biter_to_station_with_targets = function(entity, desks)
      routed = {entity = entity, desks = desks}
    end,
    trigger_immediate_protest = function()
      error("should route to desk when desks are available")
    end,
  }
end

local rideable_biter = require("scripts.rideable_biter")

local function make_entity(unit_number)
  return {
    name = "rideable-biter",
    valid = true,
    unit_number = unit_number,
    orientation = 0.25,
    speed = 0,
    driver = nil,
    passenger = nil,
    get_driver = function(self) return self.driver end,
    get_passenger = function(self) return self.passenger end,
  }
end

local function make_unfunded_entity(unit_number)
  local created = {}
  local surface = {
    find_non_colliding_position = function(_, pos) return {x = pos.x + 1, y = pos.y} end,
    create_entity = function(params)
      created[#created + 1] = params
      return {
        name = params.name,
        valid = true,
        unit_number = unit_number + 1000,
        position = params.position,
        surface = surface,
      }
    end,
    spill_item_stack = function() end,
  }

  local fuel_inventory = {
    get_item_count = function() return 0 end,
  }
  local trunk_inventory = {}
  local entity = make_entity(unit_number)
  entity.position = {x = 10, y = 20}
  entity.surface = surface
  entity.force = {name = "player"}
  entity.get_fuel_inventory = function() return fuel_inventory end
  entity.get_inventory = function() return trunk_inventory end
  entity.destroy = function() entity.valid = false end

  return entity, created
end

test("idle rideable biters are tracked and nudged on update", function()
  math.randomseed(1)
  storage = {}
  rideable_biter.ensure_storage()
  local entity = make_entity(100)
  rideable_biter.track(entity, 0)

  local entry = storage.rideable_biters[100]
  assert_true(entry ~= nil, "rideable biter should be tracked")
  entry.next_wander_tick = 10

  rideable_biter.update(10)
  assert_true(entity.speed > 0, "idle rideable biter should receive a small wander speed")
  assert_true(entity.orientation ~= 0.25, "idle rideable biter should turn slightly")
  assert_true(entry.next_wander_tick > 10, "next wander tick should be rescheduled")
end)

test("occupied rideable biters do not wander", function()
  math.randomseed(1)
  storage = {}
  rideable_biter.ensure_storage()
  local entity = make_entity(101)
  entity.driver = {valid = true}
  rideable_biter.track(entity, 0)
  storage.rideable_biters[101].next_wander_tick = 10

  rideable_biter.update(10)
  assert_true(entity.speed == 0, "occupied rideable biter should not be nudged")
  assert_true(entity.orientation == 0.25, "occupied rideable biter should keep orientation")
end)

test("invalid rideable biters are removed from storage", function()
  storage = {}
  rideable_biter.ensure_storage()
  local entity = make_entity(102)
  rideable_biter.track(entity, 0)
  entity.valid = false

  rideable_biter.update(1000)
  assert_true(storage.rideable_biters[102] == nil, "invalid rideable biter should be untracked")
end)

test("unfunded rideable biter converts to a complaining biter after timeout", function()
  storage = {
    admin_desks = {
      [1] = {valid = true, unit_number = 1},
    },
  }
  routed = nil

  rideable_biter.ensure_storage()
  local entity, created = make_unfunded_entity(200)
  rideable_biter.track(entity, 0)
  storage.rideable_biters[200].unfunded_since_tick = 0

  rideable_biter.update(10 * 60 * 60)
  assert_true(storage.rideable_biters[200] == nil, "converted rideable biter should be untracked")
  assert_true(entity.valid == false, "rideable biter vehicle should be destroyed")
  assert_true(created[1] and created[1].name == "medium-biter", "conversion should create a regular medium biter")
  assert_true(routed and routed.entity.name == "medium-biter", "converted biter should be routed into complaint handling")
  assert_true(#routed.desks == 1, "available admin desks should be passed to the routing system")
end)

print(("Rideable biter runtime tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
