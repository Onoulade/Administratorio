-------------------------------------------------------------------------------
-- PNEUMATIC RUNTIME TESTS
--
-- Standalone Lua tests for fair tube-outtake distribution.
-- Run: lua tests/test_pneumatic_runtime.lua
-------------------------------------------------------------------------------

package.path = "./?.lua;./?/init.lua;" .. package.path

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

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or "") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

defines = {
  inventory = {chest = 1, furnace_source = 2},
  entity_status_diode = {green = 1, yellow = 2, red = 3},
  direction = {north = 0, east = 4, south = 8, west = 12},
}

game = {connected_players = {}}

local pneumatic = require("scripts.pneumatic")

local function new_inventory(filter)
  local inventory = {item = nil, filter = filter}

  function inventory.is_empty()
    return inventory.item == nil
  end

  function inventory.get_filter(_slot)
    return inventory.filter
  end

  function inventory.insert(stack)
    if inventory.item then return 0 end
    inventory.item = stack.name
    return stack.count
  end

  return inventory
end

local function new_outtake(uid, inventory)
  local entity = {
    valid = true,
    name = "tube-outtake",
    unit_number = uid,
  }

  function entity.get_inventory(_inventory_type)
    return inventory
  end

  return {entity = entity}, inventory
end

local function reset_network(outtake_specs)
  storage = {
    tube_intakes = {},
    tube_outtakes = {},
    tube_signals = {[1] = {}},
    tube_network_cache = {},
    tube_network_disabled = {},
    tube_outtake_cursor = {},
    tube_network_dirty = false,
  }

  local inventories = {}
  for _, spec in ipairs(outtake_specs) do
    local entry, inventory = new_outtake(spec.uid, new_inventory(spec.filter))
    storage.tube_outtakes[spec.uid] = entry
    storage.tube_network_cache[spec.uid] = 1
    inventories[spec.uid] = inventory
  end
  return inventories
end

test("successive deliveries rotate across empty outtakes", function()
  local inventories = reset_network{{uid = 10}, {uid = 20}, {uid = 30}}

  storage.tube_signals[1]["resolved-landscape"] = 1
  pneumatic.on_pneumatic_tick()
  assert_eq(inventories[10].item, "resolved-landscape", "first delivery should use first outtake")

  inventories[10].item = nil
  storage.tube_signals[1]["resolved-landscape"] = 1
  pneumatic.on_pneumatic_tick()
  assert_eq(inventories[20].item, "resolved-landscape", "second delivery should rotate to next outtake")

  inventories[20].item = nil
  storage.tube_signals[1]["resolved-landscape"] = 1
  pneumatic.on_pneumatic_tick()
  assert_eq(inventories[30].item, "resolved-landscape", "third delivery should continue rotation")
end)

test("round robin skips occupied and unsatisfied filtered outtakes", function()
  local inventories = reset_network{
    {uid = 10},
    {uid = 20},
    {uid = 30, filter = "resolved-smog"},
  }
  storage.tube_outtake_cursor[1] = 10
  inventories[20].item = "resolved-landscape"
  storage.tube_signals[1]["resolved-landscape"] = 1

  pneumatic.on_pneumatic_tick()

  assert_eq(inventories[30].item, nil, "mismatched filtered outtake should remain empty")
  assert_eq(inventories[10].item, "resolved-landscape", "delivery should wrap to an eligible outtake")
end)

if failed > 0 then
  io.stderr:write(table.concat(errors, "\n") .. "\n")
  os.exit(1)
end

print(string.format("Passed: %d, Failed: %d", passed, failed))
