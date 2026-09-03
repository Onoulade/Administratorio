-------------------------------------------------------------------------------
-- ADMINISTRATIVE CLOCK RUNTIME TESTS
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

package.preload["scripts.working_hours"] = function()
  return {
    get_daytime_state = function(surface)
      return surface.daytime, surface.night or surface.forced_night or false
    end,
    get_day_shift_bounds = function()
      return 15, 85
    end,
  }
end

local function new_clock(surface)
  local section = {slots = {}, filters_count = 1000}
  function section.set_slot(index, filter)
    section.slots[index] = filter
  end
  function section.clear_slot(index)
    section.slots[index] = nil
  end

  local behavior = {}
  function behavior.get_section(index)
    return index == 1 and section or nil
  end
  function behavior.add_section()
    return section
  end

  local clock = {
    valid = true,
    name = "administrative-clock",
    unit_number = 1,
    surface = surface,
    position = {x = 0, y = 0},
  }
  function clock.get_or_create_control_behavior()
    return behavior
  end
  return clock, section
end

test("clock emits midnight-centered daytime and shift bounds during the day", function()
  storage = {}
  package.loaded["feature_flags"] = nil
  package.loaded["scripts.administrative_clock"] = nil
  local clock_module = require("scripts.administrative_clock")
  local clock, section = new_clock({valid = true, daytime = 0.25, night = false})

  clock_module.track_entity(clock)

  assert_eq(section.slots[1].value, "signal-daytime", "clock should emit daytime")
  assert_eq(section.slots[1].min, 75, "clock should emit daytime on a midnight-centered 0-100 scale")
  assert_eq(section.slots[2].value, "signal-working-hours", "clock should emit the open-hours signal")
  assert_eq(section.slots[2].min, 1, "open-hours signal should be one")
  assert_eq(section.slots[3].value, "signal-day-shift-start", "clock should emit the shift start signal")
  assert_eq(section.slots[3].min, 15, "clock should emit the shift start")
  assert_eq(section.slots[4].value, "signal-day-shift-end", "clock should emit the shift end signal")
  assert_eq(section.slots[4].min, 85, "clock should emit the shift end")
end)

test("clock removes working-hours signal at night", function()
  storage = {}
  package.loaded["feature_flags"] = nil
  package.loaded["scripts.administrative_clock"] = nil
  local clock_module = require("scripts.administrative_clock")
  local surface = {valid = true, daytime = 0.5, night = true}
  local clock, section = new_clock(surface)

  clock_module.track_entity(clock)
  assert_eq(section.slots[1].min, 0, "clock should emit midnight at the cycle wrap")
  assert_eq(section.slots[2], nil, "clock should omit the open-hours signal at night")
end)

print(("Administrative clock tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
