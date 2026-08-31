-------------------------------------------------------------------------------
-- COMPLAINT ITEM RECOVERY TESTS
-------------------------------------------------------------------------------

local passed, failed, errors = 0, 0, {}
local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then passed = passed + 1 else failed = failed + 1; errors[#errors + 1] = name .. ": " .. tostring(err) end
end
local function assert_eq(actual, expected, message)
  if actual ~= expected then error((message or "") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end
local function assert_true(value, message) if not value then error(message or "assertion failed", 2) end end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)"):gsub("tests/$", "")
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

defines = {
  direction = {north = 0, east = 2, south = 4, west = 6},
  inventory = {crafter_input = 1, crafter_output = 2},
}

local recovery = require("scripts.complaint_item_recovery")

local function stack(name, count, quality)
  local value = {
    name = name,
    count = count,
    quality = {name = quality or "normal"},
    valid_for_read = true,
  }
  function value.clear()
    value.valid_for_read = false
    value.count = 0
  end
  return value
end

local function make_context(input, output, progress, recipe)
  local spills, alerts = {}, {}
  local dropped_index = 0
  local surface = {name = "nauvis"}
  function surface.spill_item_stack(spec)
    spills[#spills + 1] = spec
    dropped_index = dropped_index + 1
    return {{valid = true, unit_number = dropped_index}}
  end
  local player = {valid = true}
  function player.add_custom_alert(entity, icon, message, show_on_map)
    alerts[#alerts + 1] = {entity = entity, icon = icon, message = message, show_on_map = show_on_map}
  end
  local entity = {
    valid = true,
    name = "resolution-office",
    position = {x = 10.8, y = -3.2},
    surface = surface,
    force = {players = {player}},
    crafting_progress = progress or 0,
  }
  function entity.get_inventory(index)
    return index == defines.inventory.crafter_input and input or output
  end
  function entity.get_recipe() return recipe end
  return entity, spills, alerts
end

test("destroyed office drops only complaint-chain inventory with alerts", function()
  local complaint = stack("ticket-smog", 3, "rare")
  local expendable = stack("blank-form", 9)
  local resolved = stack("resolved-landscape", 2)
  local entity, spills, alerts = make_context({complaint, expendable}, {resolved})

  local recovered = recovery.on_entity_died{entity = entity}

  assert_eq(recovered, 5)
  assert_eq(#spills, 2)
  assert_true(not complaint.valid_for_read, "complaint should be removed before vanilla death cleanup")
  assert_true(not resolved.valid_for_read, "resolution should be removed before vanilla death cleanup")
  assert_true(expendable.valid_for_read, "ordinary ingredients should retain vanilla behaviour")
  assert_eq(#alerts, 2)
  assert_true(alerts[1].show_on_map, "recovery alert should be visible on the map")

  local rare_ticket
  for _, spill in ipairs(spills) do
    if spill.stack.name == "ticket-smog" then rare_ticket = spill end
  end
  assert_true(rare_ticket ~= nil)
  assert_eq(rare_ticket.stack.quality, "rare")
  assert_true(rare_ticket.allow_belts == false, "recovered paperwork should remain beside the wreck")
end)

test("active craft restores its consumed complaint intermediate", function()
  local entity, spills = make_context({}, {}, 0.5, {
    ingredients = {
      {type = "item", name = "case-n", amount = 1},
      {type = "item", name = "narrative", amount = 2},
      {type = "fluid", name = "liquid-coffee", amount = 120},
    },
  })

  local recovered = recovery.on_entity_died{entity = entity}

  assert_eq(recovered, 1)
  assert_eq(#spills, 1)
  assert_eq(spills[1].stack.name, "case-n")
  assert_eq(spills[1].stack.count, 1)
end)

test("unrelated and intact entities are ignored", function()
  local entity, spills = make_context({stack("ticket-landscape", 1)}, {}, 0)
  entity.name = "assembling-machine-1"
  assert_eq(recovery.on_entity_died{entity = entity}, 0)
  assert_eq(#spills, 0)
  entity.name = "resolution-office"
  entity.valid = false
  assert_eq(recovery.on_entity_died{entity = entity}, 0)
end)

print(("Complaint item recovery tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then for _, err in ipairs(errors) do print(" - " .. err) end; os.exit(1) end
