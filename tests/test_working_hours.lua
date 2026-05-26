-------------------------------------------------------------------------------
-- WORKING HOURS TESTS
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

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

settings = {
  startup = {
    ["administratorio-enable-working-hours"] = {value = true},
  },
}

defines = {
  entity_status_diode = {red = 1, yellow = 2, green = 3},
}

rendering = {}
function rendering.get_object_by_id()
  return nil
end
function rendering.draw_text()
  return {destroy = function() end}
end

local function new_entity(name)
  local inventory = {valid = true}
  function inventory.get_item_count()
    return 0
  end

  local entity = {
    valid = true,
    name = name,
    unit_number = name == "office-desk" and 1 or 2,
    active = true,
    surface = {valid = true, index = 1, daytime = 0.5, dusk = 0.25, dawn = 0.75},
    force = {valid = true, index = 1, print = function() end},
  }
  function entity.get_module_inventory()
    return inventory
  end
  return entity
end

test("worker station managed buildings do not need overtime exemption at night", function()
  storage = {}
  package.loaded["feature_flags"] = nil
  package.loaded["scripts.working_hours"] = nil
  local working_hours = require("scripts.working_hours")

  local breakroom = new_entity("corporate-breakroom")
  working_hours.refresh_entity(breakroom)

  assert_eq(breakroom.active, true, "breakroom should stay available for biter-station dispatch")
  assert_eq(storage.working_hours_state[breakroom.unit_number].reason, nil, "breakroom should not receive a night shutdown reason")
end)

test("regular working-hours buildings still need overtime exemption at night", function()
  storage = {}
  package.loaded["feature_flags"] = nil
  package.loaded["scripts.working_hours"] = nil
  local working_hours = require("scripts.working_hours")

  local office_desk = new_entity("office-desk")
  working_hours.refresh_entity(office_desk)

  assert_eq(office_desk.active, false, "office desk should still shut down at night without overtime")
  assert_eq(storage.working_hours_state[office_desk.unit_number].reason, "night", "office desk should keep the night shutdown reason")
end)

test("worker station managed buildings can still be shut down by protests", function()
  storage = {}
  package.loaded["feature_flags"] = nil
  package.loaded["scripts.working_hours"] = nil
  local working_hours = require("scripts.working_hours")

  local breakroom = new_entity("corporate-breakroom")
  assert_eq(working_hours.claim_protest_target(breakroom, 99), true, "breakroom should still accept protest claims")

  assert_eq(breakroom.active, false, "protest should disable the breakroom")
  assert_eq(storage.working_hours_state[breakroom.unit_number].reason, "protest", "breakroom should keep the protest shutdown reason")
end)

test("hard mode attackers do not keep working-hours protest shutdown claims", function()
  storage = {
    waiting_biters = {
      [42] = {
        state = "protesting",
        hard_mode_attacking = true,
        arrived_at_building = true,
      },
    },
  }
  package.loaded["feature_flags"] = nil
  package.loaded["scripts.working_hours"] = nil
  local working_hours = require("scripts.working_hours")

  local breakroom = new_entity("corporate-breakroom")
  storage.waiting_biters[42].target_building = breakroom
  game = {
    surfaces = {
      {
        find_entities_filtered = function(params)
          if params.name == "corporate-breakroom" then
            return {breakroom}
          end
          return {}
        end,
      },
    },
  }

  working_hours.rebuild_registry()

  assert_eq(breakroom.active, true, "hard-mode attackers should release protest shutdowns so they can attack live buildings")
  assert_eq(storage.working_hours_state[breakroom.unit_number].reason, nil, "hard-mode attackers should not leave a protest shutdown reason")
end)

print(("Working hours tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
