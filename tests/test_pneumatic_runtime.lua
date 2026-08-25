-------------------------------------------------------------------------------
-- PNEUMATIC RUNTIME TESTS
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
    error((message or "assertion failed") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

defines = {
  inventory = {furnace_source = 1, chest = 2},
  entity_status_diode = {red = 1, yellow = 2, green = 3},
  direction = {north = 0, east = 2, south = 4, west = 6},
}
game = {connected_players = {}}
storage = {}

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

package.loaded["scripts.pneumatic"] = nil
local pneumatic = require("scripts.pneumatic")

local function new_inventory(stack_spec)
  local stack = {
    name = stack_spec and stack_spec.name,
    count = stack_spec and stack_spec.count or 0,
    quality = stack_spec and stack_spec.quality and {name = stack_spec.quality} or nil,
  }
  stack.valid_for_read = stack.count > 0

  local inventory = {[1] = stack}

  function inventory.is_empty()
    return not stack.valid_for_read
  end

  function inventory.remove(spec)
    local stack_quality = stack.quality and stack.quality.name or "normal"
    local requested_quality = spec.quality or "normal"
    if not stack.valid_for_read or stack.name ~= spec.name or stack_quality ~= requested_quality then return 0 end
    local removed = math.min(stack.count, spec.count or 1)
    stack.count = stack.count - removed
    if stack.count == 0 then
      stack.valid_for_read = false
      stack.name = nil
      stack.quality = nil
    end
    return removed
  end

  function inventory.insert(spec)
    if stack.valid_for_read then return 0 end
    stack.name = spec.name
    stack.count = spec.count or 1
    stack.quality = spec.quality and {name = spec.quality} or nil
    stack.valid_for_read = true
    return stack.count
  end

  return inventory
end

local function new_endpoint(name, inventory, unit_number)
  return {
    valid = true,
    name = name,
    unit_number = unit_number,
    force = {valid = true, index = 1, technologies = {}},
    get_inventory = function(_, _) return inventory end,
  }
end

test("pneumatic transport conserves an item and its quality", function()
  local source = new_inventory({name = "work-order", quality = "legendary", count = 1})
  local destination = new_inventory()
  local intake = new_endpoint("tube-intake", source, 101)
  local outtake = new_endpoint("tube-outtake", destination, 102)

  storage = {
    tube_intakes = {[101] = {entity = intake}},
    tube_outtakes = {[102] = {entity = outtake}},
    tube_signals = {},
    tube_network_cache = {[101] = 1, [102] = 1},
    tube_network_disabled = {},
    tube_network_dirty = false,
  }

  pneumatic.on_pneumatic_tick()

  assert_eq(source[1].valid_for_read, false, "intake should remove exactly one source item")
  assert_eq(destination[1].name, "work-order", "outtake should recreate the transported item")
  assert_eq(destination[1].count, 1, "outtake should recreate exactly one item")
  assert_eq(destination[1].quality.name, "legendary", "outtake should preserve item quality")
  assert_eq(pneumatic.get_network_total(1), 0, "completed transfer should leave no duplicate in the pool")
end)

test("legacy unqualified signal-pool entries remain normal quality", function()
  local destination = new_inventory()
  local outtake = new_endpoint("tube-outtake", destination, 202)

  storage = {
    tube_intakes = {},
    tube_outtakes = {[202] = {entity = outtake}},
    tube_signals = {[2] = { ["work-order"] = 1 }},
    tube_network_cache = {[202] = 2},
    tube_network_disabled = {},
    tube_network_dirty = false,
  }

  pneumatic.on_pneumatic_tick()

  assert_eq(destination[1].name, "work-order", "legacy pool should still emit its item")
  assert_eq(destination[1].quality.name, "normal", "legacy pool entries should decode as normal quality")
  assert_eq(pneumatic.get_network_total(2), 0, "legacy transfer should remain conserved")
end)

-- Factorissimo compatibility: a tube network crosses a factory wall through the
-- linked pump pair, and must not leak into the fluid network behind that pump.
local function new_fluid_entity(spec)
  local entity = {
    valid = true,
    name = spec.name,
    type = spec.type or "pipe",
    unit_number = spec.unit_number,
    position = spec.position,
    surface_index = spec.surface_index,
    connections = {},
  }
  entity.fluidbox = {true}
  function entity.fluidbox.get_pipe_connections(_)
    local pipe_connections = {}
    for _, neighbour in ipairs(entity.connections) do
      pipe_connections[#pipe_connections + 1] = {target = {owner = neighbour}}
    end
    return pipe_connections
  end
  return entity
end

local function link(a, b)
  a.connections[#a.connections + 1] = b
  b.connections[#b.connections + 1] = a
end

test("tube network crosses a Factorissimo wall without absorbing fluid pipes", function()
  local outside_pipe = new_fluid_entity{name = "pneumatic-hidden-network-pipe", unit_number = 10, position = {x = 0, y = 0}, surface_index = 1}
  local outside_pump = new_fluid_entity{name = "factory-outside-pump-input", type = "pump", unit_number = 20, position = {x = 1, y = 0}, surface_index = 1}
  -- The factory interior sits at unrelated coordinates on its own surface.
  local inside_pump = new_fluid_entity{name = "factory-inside-pump-input", type = "pump", unit_number = 30, position = {x = 4000, y = 4000}, surface_index = 2}
  local inside_pipe = new_fluid_entity{name = "pneumatic-pipe", unit_number = 40, position = {x = 4001, y = 4000}, surface_index = 2}
  local foreign_pipe = new_fluid_entity{name = "pipe", unit_number = 5, position = {x = 2, y = 0}, surface_index = 1}

  link(outside_pipe, outside_pump)
  link(outside_pump, inside_pump) -- the linked cross-surface connection
  link(inside_pump, inside_pipe)
  link(outside_pump, foreign_pipe)

  local net_id, over_extended = pneumatic.bfs_network_id(outside_pipe)

  assert_eq(net_id, 10, "network id should ignore the foreign fluid pipe behind the pump")
  assert_eq(over_extended, false, "a factory interior's coordinates must not count against the radius limit")
end)

print("\n=== PNEUMATIC RUNTIME TESTS ===")
print("Passed: " .. passed .. "  Failed: " .. failed .. "  Total: " .. (passed + failed))
if failed > 0 then
  for _, err in ipairs(errors) do print("  FAIL: " .. err) end
  os.exit(1)
end
print("\nAll tests passed!")
