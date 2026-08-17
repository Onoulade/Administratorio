-------------------------------------------------------------------------------
-- RELOCATION CANNON RUNTIME TESTS
--
-- The emitter must bill only cargo that arrived and its cooldown belongs to
-- the emitter, not every receiving request that happens to exist. Only a
-- registry entry tagged as an emitter may ever act as a cargo source.
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

local function key(name, quality)
  return name .. "/" .. (quality or "normal")
end

local function parse_key(k)
  local name, quality = k:match("^(.-)/(.*)$")
  return name, quality
end

local function new_inventory(capacity)
  local inventory = {valid = true, contents = {}, capacity = capacity or 12}

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

  function inventory.get_contents()
    local list = {}
    for item_key, count in pairs(inventory.contents) do
      if count > 0 then
        local name, quality = parse_key(item_key)
        list[#list + 1] = {name = name, quality = quality, count = count}
      end
    end
    return list
  end

  return inventory
end

-- A fake constant-combinator control behavior supporting the Factorio 2.0
-- sections API subset the status combinator actually uses.
local function new_fake_behavior()
  local behavior = {sections = {}}
  function behavior.get_section(idx) return behavior.sections[idx] end
  function behavior.add_section()
    local section = {slots = {}, filters_count = 1000}
    function section.set_slot(idx, def) section.slots[idx] = def end
    function section.clear_slot(idx) section.slots[idx] = nil end
    behavior.sections[#behavior.sections + 1] = section
    return section
  end
  return behavior
end

-- A fake wire connector: production code only ever calls .connect_to() on it.
local function new_fake_wire_connector()
  local connector = {}
  function connector.connect_to(_) end
  return connector
end

local next_unit_number = 0

local function new_cannon(role, planet_name, requests, arrivals_capacity)
  next_unit_number = next_unit_number + 1
  local entity_name = (role == "emitter") and C.RELOCATION_CANNON_NAME or C.RELOCATION_RECEIVER_NAME
  local entity = {
    valid = true,
    name = entity_name,
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

  local surface
  surface = {valid = true, platform = nil, planet = {valid = true, name = planet_name}, spawned = {entity}}
  surface.planet.surface = surface

  function surface.spill_item_stack(params)
    entity.spills[#entity.spills + 1] = params.stack
  end

  function surface.create_entity(params)
    local ent = {valid = true, name = params.name, position = params.position, force = params.force}
    function ent.destroy() ent.valid = false end
    function ent.get_or_create_control_behavior()
      ent.behavior = ent.behavior or new_fake_behavior()
      return ent.behavior
    end
    function ent.get_wire_connector(_, _) return new_fake_wire_connector() end
    surface.spawned[#surface.spawned + 1] = ent
    return ent
  end

  function surface.find_entities_filtered(filters)
    local results = {}
    for _, ent in ipairs(surface.spawned) do
      if ent.valid and (not filters.name or ent.name == filters.name) then
        results[#results + 1] = ent
      end
    end
    return results
  end

  entity.surface = surface

  function entity.get_inventory(which)
    if which == defines.inventory.furnace_source then return entity.input end
    if which == defines.inventory.furnace_result then return entity.arrivals end
    return nil
  end

  function entity.get_wire_connector(_, _) return new_fake_wire_connector() end

  function entity.get_circuit_network(connector)
    -- Requests are read from GREEN only; see collect_requests.
    if connector ~= defines.wire_connector_id.circuit_green then return nil end
    local signals = {}
    for _, request in ipairs(entity.requests) do
      signals[#signals + 1] = {
        -- Real Factorio reports item-type signals with type == nil on read.
        signal = {type = nil, name = request.name, quality = request.quality},
        count = request.count,
      }
    end
    return #signals > 0 and {signals = signals} or nil
  end

  return entity
end

local function new_emitter(planet_name)
  return new_cannon("emitter", planet_name)
end

local function new_receiver(planet_name, requests, arrivals_capacity)
  return new_cannon("receiver", planet_name, requests, arrivals_capacity)
end

local function register(entity, role)
  cannon.ensure_storage()
  storage.relocation_cannons[entity.unit_number] = {
    entity = entity,
    role = role,
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
  local source = new_emitter("nauvis")
  source.input.insert{name = CARGO, count = C.RELOCATION_PAYLOAD_PER_SHOT}
  local destination = new_receiver("aquilo", request_cargo(C.RELOCATION_PAYLOAD_PER_SHOT))
  destination.input.insert{name = C.RELOCATION_TRANSFER_FORM, count = C.RELOCATION_PAYLOAD_PER_SHOT - 1}
  register(source, "emitter")
  register(destination, "receiver")

  cannon.on_tick{tick = 0}

  assert_eq(source.input.get_item_count(CARGO), C.RELOCATION_PAYLOAD_PER_SHOT,
    "a failed order preflight must not consume personnel")
  assert_eq(destination.input.get_item_count(C.RELOCATION_TRANSFER_FORM), C.RELOCATION_PAYLOAD_PER_SHOT - 1,
    "a failed order preflight must not consume forms")
  assert_eq(destination.arrivals.get_item_count(CARGO), 0, "no cargo should arrive without a full order batch")
end)

test("a partial arrival bills only cargo that actually lands", function()
  reset()
  local source = new_emitter("nauvis")
  source.input.insert{name = CARGO, count = C.RELOCATION_PAYLOAD_PER_SHOT}
  local destination = new_receiver("aquilo", request_cargo(C.RELOCATION_PAYLOAD_PER_SHOT), 3)
  destination.input.insert{name = C.RELOCATION_TRANSFER_FORM, count = C.RELOCATION_PAYLOAD_PER_SHOT}
  register(source, "emitter")
  register(destination, "receiver")

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
  local source = new_emitter("nauvis")
  source.input.insert{name = CARGO, count = C.RELOCATION_PAYLOAD_PER_SHOT}
  local destination = new_receiver("aquilo", request_cargo(C.RELOCATION_PAYLOAD_PER_SHOT), 0)
  destination.input.insert{name = C.RELOCATION_TRANSFER_FORM, count = C.RELOCATION_PAYLOAD_PER_SHOT}
  register(source, "emitter")
  register(destination, "receiver")

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
  local source = new_emitter("nauvis")
  source.input.insert{name = CARGO, count = C.RELOCATION_PAYLOAD_PER_SHOT * 2}
  local first = new_receiver("aquilo", request_cargo(C.RELOCATION_PAYLOAD_PER_SHOT))
  local second = new_receiver("vulcanus", request_cargo(C.RELOCATION_PAYLOAD_PER_SHOT))
  first.input.insert{name = C.RELOCATION_TRANSFER_FORM, count = C.RELOCATION_PAYLOAD_PER_SHOT}
  second.input.insert{name = C.RELOCATION_TRANSFER_FORM, count = C.RELOCATION_PAYLOAD_PER_SHOT}
  register(source, "emitter")
  register(first, "receiver")
  register(second, "receiver")

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
  local source = new_emitter("nauvis")
  register(source, "emitter")
  storage.relocation_cannons[source.unit_number].next_shot_tick = 12345
  game.surfaces = {source.surface}

  cannon.rebuild_registry()

  assert_eq(storage.relocation_cannons[source.unit_number].next_shot_tick, 12345,
    "a configuration rebuild must not reset a sender's cooldown")
end)

-------------------------------------------------------------------------------
-- ROLE ISOLATION
-------------------------------------------------------------------------------

test("only emitters are treated as cargo sources, never receivers", function()
  reset()
  -- A receiver would never normally hold cargo (its recipe category only
  -- accepts transfer orders), but the role check must exclude it as a source
  -- regardless of what its inventory happens to contain.
  local mislabeled = new_receiver("nauvis")
  mislabeled.input.insert{name = CARGO, count = C.RELOCATION_PAYLOAD_PER_SHOT}
  register(mislabeled, "receiver")

  local destination = new_receiver("aquilo", request_cargo(C.RELOCATION_PAYLOAD_PER_SHOT))
  destination.input.insert{name = C.RELOCATION_TRANSFER_FORM, count = C.RELOCATION_PAYLOAD_PER_SHOT}
  register(destination, "receiver")

  cannon.on_tick{tick = 0}

  assert_eq(destination.arrivals.get_item_count(CARGO), 0,
    "a receiver must never be treated as a cargo source, regardless of its inventory contents")
end)

test("rebuild_registry assigns role correctly from the entity's own name", function()
  reset()
  local emitter = new_emitter("nauvis")
  local receiver = new_receiver("vulcanus")
  game.surfaces = {emitter.surface, receiver.surface}

  cannon.rebuild_registry()

  assert_eq(storage.relocation_cannons[emitter.unit_number].role, "emitter",
    "an involuntary-relocation-cannon entity should be registered as an emitter")
  assert_eq(storage.relocation_cannons[receiver.unit_number].role, "receiver",
    "an involuntary-relocation-receiver entity should be registered as a receiver")
end)

-------------------------------------------------------------------------------
-- STATUS COMBINATOR
-------------------------------------------------------------------------------

test("the status combinator broadcasts a building's own inventory contents", function()
  reset()
  local source = new_emitter("nauvis")
  source.input.insert{name = CARGO, count = 2}
  assert_true(cannon.on_entity_built(source, nil), "the emitter should be accepted")

  cannon.on_tick{tick = 0}

  local entry = storage.relocation_cannons[source.unit_number]
  assert_true(entry.combinator ~= nil and entry.combinator.valid, "a status combinator should exist")
  local behavior = entry.combinator.get_or_create_control_behavior()
  local section = behavior.get_section(1)
  assert_true(section ~= nil, "the combinator should have written a section")
  assert_eq(section.slots[1].value.name, CARGO, "the status combinator should show what's loaded")
  assert_eq(section.slots[1].min, 2, "the status combinator should show the current loaded count")
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
