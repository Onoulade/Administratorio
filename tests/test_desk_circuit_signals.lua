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

package.loaded["scripts.biters"] = nil
package.preload["scripts.constants"] = function()
  return {FRUST_PROTEST_PROCESS_SHARDS = 4}
end
package.preload["scripts.zones"] = function()
  return {get_available_slots = function() return 4 end}
end
package.preload["scripts.working_hours"] = function() return {} end
package.preload["scripts.biters_rendering"] = function()
  return {new = function() return {} end}
end
package.preload["scripts.biters_protests"] = function()
  return {new = function() return {} end}
end
package.preload["scripts.unit_ai_settings"] = function() return {} end
package.preload["scripts.protest_targets"] = function()
  return {
    get_target_types = function() return {} end,
    get_target_names = function() return {} end,
    get_protected_names = function() return {} end,
  }
end
package.preload["scripts.spawner_population"] = function() return {} end

test("desk circuit periodically clears phantom complaint signals", function()
  local desk_id = 42
  local slots = {
    [1] = {value = "signal-complaint-l", min = 3},
    [2] = {value = "signal-complaint-s", min = 5},
    [5] = {value = "signal-complaint-lt", min = 2},
  }
  local section = {}
  function section.set_slot(index, filter)
    slots[index] = filter
  end
  function section.clear_slot(index)
    slots[index] = nil
  end
  local behavior = {
    get_section = function() return section end,
    add_section = function() return section end,
  }
  local combinator = {
    valid = true,
    get_or_create_control_behavior = function() return behavior end,
  }
  local desk = {valid = true, unit_number = desk_id}

  storage = {
    waiting_biters = {},
    desk_biters = {[desk_id] = {}},
    desk_combinators = {[desk_id] = combinator},
    desk_circuit_dirty = {},
  }
  game = {tick = desk_id}

  local biters = require("scripts.biters")
  biters.update_circuit_signals({desk})

  assert_eq(slots[1], nil, "landscape complaint signal should be removed")
  assert_eq(slots[2], nil, "smog complaint signal should be removed")
  assert_eq(slots[5], nil, "littering complaint signal should be removed")
  assert_eq(slots[10], nil, "zero waiting citizens should not leave a signal")
  assert_eq(slots[9].value, "signal-available-slots", "nonzero desk capacity should still be broadcast")
  assert_eq(slots[9].min, 4, "available slot count should be refreshed")
  assert_eq(storage.desk_circuit_dirty[desk_id], nil, "reconciled desk should return to a clean state")
end)

print(("Desk circuit signal tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
