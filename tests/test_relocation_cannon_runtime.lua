-------------------------------------------------------------------------------
-- RELOCATION CANNON RUNTIME TESTS
--
-- The cannon must bill only cargo that arrived and its cooldown belongs to the
-- sender, not every receiving request that happens to exist.
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

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or "assertion failed") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function assert_true(value, msg)
  if not value then error(msg or "assertion failed", 2) end
end

defines = {
  inventory = {furnace_source = 1, furnace_result = 2},
  entity_status_diode = {red = 1, yellow = 2, green = 3},
  direction = {north = 0, east = 2, south = 4, west = 6},
  wire_connector_id = {circuit_red = 1, circuit_green = 2},
}
game = {surfaces = {}, tick = 0}
storage = {}

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

package.loaded["scripts.relocation_cannon"] = nil
local cannon = require("scripts.relocation_cannon")
local C = require("scripts.constants")

-------------------------------------------------------------------------------
-- FAKES
-------------------------------------------------------------------------------

local function new_inventory(capacity)
  local inventory = {valid = true, contents = {}, capacity = capacity or 12}

  local function key(name, quality)
    return name .. "/" .. (quality or "normal")
  end

  function inventory.total()
    local total = 0
    for _, count in pairs(inventory.contents) do total = total + count end
    return total
  end

  function inventory.is_full()
    return inventory.total() >= inventory.capacity
  end

  function inventory.insert(stack)
    local room = inventory.capacity - inventory.total()
    local inserted = math.min(room, stack.count or 1)
    if inserted <= 0 then return 0 end
    local item_key = key(stack.name, stack.quality)
    inventory.contents[item_key] = (inventory.contents[item_key] or 0) + inserted
    return inserted
  end

  function inventory.remove(stack)
    local item_key = key(stack.name, stack.quality)
    local held = inventory.contents[item_key] or 0
    local removed = math.min(held, stack.count or 1)
    if removed <= 0 then return 0 end
    inventory.contents[item_key] = held - removed
    if inventory.contents[item_key] == 0 then inventory.contents[item_key] = nil end
    return removed
  end

  function inventory.get_item_count(spec)
    if type(spec) == "table" then
      return inventory.contents[key(spec.name, spec.quality)] or 0
    end
    local total = 0
    for item_key, count in pairs(inventory.contents) do
      if item_key:match("^(.*)/") == spec then total = total + count end
    end
    return total
  end

  return inventory
end

local next_unit_number = 0

local function new_cannon(planet_name, requests, arrivals_capacity)
  next_unit_number = next_unit_number + 1
  local entity = {
    valid = true,
    name = C.RELOCATION_CANNON_NAME,
    unit_number = next_unit_number,
    position = {x = 0, y = 0},
    active = false,
    custom_status = nil,
    force = {valid = true, index = 1},
    input = new_inventory(20),
    arrivals = new_inventory(arrivals_capacity or 12),
    requests = requests or {},
    spills = {},
  }
  local surface = {
    valid = true,
    platform = nil,
    planet = {valid = true, name = planet_name},
  }
  surface.planet.surface = surface
  function surface.find_entities_filtered(opts)
    if opts.name == C.RELOCATION_CANNON_NAME then return {entity} end
    return {}
  end
  function surface.spill_item_stack(params)
    entity.spills[#entity.spills + 1] = params.stack
  end
  entity.surface = surface

  function entity.get_inventory(which)
    if which == defines.inventory.furnace_source then return entity.input end
    if which == defines.inventory.furnace_result then return entity.arrivals end
    return nil
  end

  function entity.get_circuit_network(connector)
    if connector ~= defines.wire_connector_id.circuit_red then return nil end
    local signals = {}
    for _, request in ipairs(entity.requests) do
      signals[#signals + 1] = {
        signal = {type = "item", name = request.name, quality = request.quality},
        count = request.count,
      }
    end
    return #signals > 0 and {signals = signals} or nil
  end

  return entity
end

local function register(entity)
  cannon.ensure_storage()
  storage.relocation_cannons[entity.unit_number] = {
    entity = entity,
    planet = entity.surface.planet.name,
    force_index = entity.force.index,
    next_shot_tick = 0,
  }
end

local function reset()
  storage = {}
  next_unit_number = 0
  cannon.ensure_storage()
end

local CARGO = "middle-management-managing-manager"

local function request_cargo(count)
  return {{name = CARGO, quality = "normal", count = count}}
end

-------------------------------------------------------------------------------
-- ACCOUNTING
-------------------------------------------------------------------------------

test("insufficient orders leave both cargo and forms untouched", function()
  reset()
  local source = new_cannon("nauvis")
  source.input.insert{name = CARGO, count = C.RELOCATION_PAYLOAD_PER_SHOT}
  local destination = new_cannon("aquilo", request_cargo(C.RELOCATION_PAYLOAD_PER_SHOT))
  destination.input.insert{name = C.RELOCATION_TRANSFER_FORM, count = C.RELOCATION_PAYLOAD_PER_SHOT - 1}
  register(source)
  register(destination)

  cannon.on_tick{tick = 0}

  assert_eq(source.input.get_item_count(CARGO), C.RELOCATION_PAYLOAD_PER_SHOT,
    "a failed order preflight must not consume personnel")
  assert_eq(destination.input.get_item_count(C.RELOCATION_TRANSFER_FORM), C.RELOCATION_PAYLOAD_PER_SHOT - 1,
    "a failed order preflight must not consume forms")
  assert_eq(destination.arrivals.get_item_count(CARGO), 0, "no cargo should arrive without a full order batch")
end)

test("a partial arrival bills only cargo that actually lands", function()
  reset()
  local source = new_cannon("nauvis")
  source.input.insert{name = CARGO, count = C.RELOCATION_PAYLOAD_PER_SHOT}
  local destination = new_cannon("aquilo", request_cargo(C.RELOCATION_PAYLOAD_PER_SHOT), 3)
  destination.input.insert{name = C.RELOCATION_TRANSFER_FORM, count = C.RELOCATION_PAYLOAD_PER_SHOT}
  register(source)
  register(destination)

  cannon.on_tick{tick = 0}

  assert_eq(destination.arrivals.get_item_count(CARGO), 3, "only free arrival slots should receive cargo")
  assert_eq(source.input.get_item_count(CARGO), C.RELOCATION_PAYLOAD_PER_SHOT - 3,
    "unlanded personnel must return to the source")
  assert_eq(destination.input.get_item_count(C.RELOCATION_TRANSFER_FORM), C.RELOCATION_PAYLOAD_PER_SHOT - 3,
    "only landed personnel should consume transfer orders")
  assert_eq(#source.spills, 0, "normal partial arrivals must not spill or void cargo")
end)

test("a full arrival buffer does not consume a source cooldown or orders", function()
  reset()
  local source = new_cannon("nauvis")
  source.input.insert{name = CARGO, count = C.RELOCATION_PAYLOAD_PER_SHOT}
  local destination = new_cannon("aquilo", request_cargo(C.RELOCATION_PAYLOAD_PER_SHOT), 0)
  destination.input.insert{name = C.RELOCATION_TRANSFER_FORM, count = C.RELOCATION_PAYLOAD_PER_SHOT}
  register(source)
  register(destination)

  cannon.on_tick{tick = 0}

  assert_eq(storage.relocation_cannons[source.unit_number].next_shot_tick, 0,
    "a shot that cannot land must not start the sender cooldown")
  assert_eq(destination.input.get_item_count(C.RELOCATION_TRANSFER_FORM), C.RELOCATION_PAYLOAD_PER_SHOT,
    "blocked arrivals must not spend forms")
end)

-------------------------------------------------------------------------------
-- THROUGHPUT
-------------------------------------------------------------------------------

test("one sender fires once even when several destinations request cargo", function()
  reset()
  local source = new_cannon("nauvis")
  source.input.insert{name = CARGO, count = C.RELOCATION_PAYLOAD_PER_SHOT * 2}
  local first = new_cannon("aquilo", request_cargo(C.RELOCATION_PAYLOAD_PER_SHOT))
  local second = new_cannon("vulcanus", request_cargo(C.RELOCATION_PAYLOAD_PER_SHOT))
  first.input.insert{name = C.RELOCATION_TRANSFER_FORM, count = C.RELOCATION_PAYLOAD_PER_SHOT}
  second.input.insert{name = C.RELOCATION_TRANSFER_FORM, count = C.RELOCATION_PAYLOAD_PER_SHOT}
  register(source)
  register(first)
  register(second)

  cannon.on_tick{tick = 0}

  local total_arrived = first.arrivals.get_item_count(CARGO) + second.arrivals.get_item_count(CARGO)
  assert_eq(total_arrived, C.RELOCATION_PAYLOAD_PER_SHOT,
    "multiple receiving requests must not multiply a single cannon's fire rate")
  assert_eq(source.input.get_item_count(CARGO), C.RELOCATION_PAYLOAD_PER_SHOT,
    "one source shot should remove exactly one payload batch")
  assert_eq(storage.relocation_cannons[source.unit_number].next_shot_tick, C.RELOCATION_SHOT_TICKS,
    "the source, not the destination, owns the cooldown")
end)

test("registry rebuild preserves a sender cooldown", function()
  reset()
  local source = new_cannon("nauvis")
  register(source)
  storage.relocation_cannons[source.unit_number].next_shot_tick = 12345
  game.surfaces = {source.surface}

  cannon.rebuild_registry()

  assert_eq(storage.relocation_cannons[source.unit_number].next_shot_tick, 12345,
    "a configuration rebuild must not reset a sender's cooldown")
end)

print(string.format("\n=== RELOCATION CANNON RUNTIME TESTS ==="))
print(string.format("Passed: %d  Failed: %d  Total: %d", passed, failed, passed + failed))

if #errors > 0 then
  print("\nFAILURES:")
  for i, err in ipairs(errors) do
    print(string.format("  %d) %s", i, err))
  end
  os.exit(1)
end

print("\nAll tests passed!")
