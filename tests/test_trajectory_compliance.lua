-------------------------------------------------------------------------------
-- ADMINISTRATORIO TRAJECTORY COMPLIANCE TESTS
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

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

defines = {
  inventory = {
    turret_ammo = 1,
  },
  entity_status_diode = {
    red = 1,
  },
}

storage = {}

local function new_inventory(initial_count)
  local count = initial_count or 0
  return {
    valid = true,
    get_item_count = function(name)
      if name == "middle-management-managing-manager" then
        return count
      end
      return 0
    end,
    remove = function(spec)
      if spec.name ~= "middle-management-managing-manager" then
        return 0
      end
      local removed = math.min(count, spec.count or 0)
      count = count - removed
      return removed
    end,
    set_count = function(value)
      count = value
    end,
    _count = function()
      return count
    end,
  }
end

local next_unit_number = 100
local surface

local function new_array(force, inventory_count, position)
  local inventory = new_inventory(inventory_count)
  local entity = {
    valid = true,
    name = "trajectory-compliance-array",
    force = force,
    position = position or {x = 0, y = 0},
    unit_number = next_unit_number,
    custom_status = nil,
    get_inventory = function(inventory_index)
      assert_eq(inventory_index, defines.inventory.turret_ammo, "array should use turret ammo inventory")
      return inventory
    end,
  }
  next_unit_number = next_unit_number + 1
  entity._inventory = inventory
  return entity
end

local destroyed = {}
local chunks = {}
surface = {
  valid = true,
  find_entities_filtered = function(opts)
    if opts.name == "trajectory-compliance-array" then
      return surface._entities or {}
    end
    return {}
  end,
}

local platform = {
  valid = true,
  surface = surface,
  find_asteroid_chunks_filtered = function(spec)
    local limit = spec and spec.limit or #chunks
    local results = {}
    for i = 1, math.min(limit, #chunks) do
      results[#results + 1] = chunks[i]
    end
    return results
  end,
  destroy_asteroid_chunks = function(spec)
    destroyed[#destroyed + 1] = spec
    for i, chunk in ipairs(chunks) do
      if chunk.name == spec.name and chunk.position.x == spec.position.x and chunk.position.y == spec.position.y then
        table.remove(chunks, i)
        break
      end
    end
  end,
}

local printed_messages = {}
local force = {
  index = 1,
  valid = true,
  platforms = {[1] = platform},
  print = function(message)
    printed_messages[#printed_messages + 1] = message
  end,
}

game = {
  forces = {
    player = force,
  },
}

local module = dofile(mod_root .. "scripts/trajectory_compliance.lua")

test("arrays do not spend MMMM when no asteroid chunk is present", function()
  storage = {}
  destroyed = {}
  printed_messages = {}
  chunks = {}
  surface._entities = {new_array(force, 2)}

  module.on_tick({tick = 60})

  assert_eq(surface._entities[1]._inventory._count(), 2, "array should not spend MMMM without a target")
  assert_eq(#destroyed, 0, "array should not destroy chunks without a target")
end)

test("arrays spend MMMM to deviate nearby asteroid chunks", function()
  storage = {}
  destroyed = {}
  printed_messages = {}
  chunks = {
    {name = "metallic-asteroid-chunk", position = {x = 4, y = 2}},
  }
  surface._entities = {new_array(force, 2)}

  module.on_tick({tick = 60})

  assert_eq(surface._entities[1]._inventory._count(), 1, "array should spend one MMMM when deviating a chunk")
  assert_eq(#destroyed, 1, "array should destroy one chunk when loaded")
  assert_eq(destroyed[1].name, "metallic-asteroid-chunk", "array should target the discovered chunk")
end)

test("arrays report starvation when asteroids arrive but MMMM is empty", function()
  storage = {}
  destroyed = {}
  printed_messages = {}
  chunks = {
    {name = "carbonic-asteroid-chunk", position = {x = 1, y = 1}},
  }
  surface._entities = {new_array(force, 0)}

  module.on_tick({tick = 60})

  assert_eq(#destroyed, 0, "array should not destroy chunks without MMMM")
  assert_true(surface._entities[1].custom_status ~= nil, "array should expose missing-management status")
  assert_eq(#printed_messages, 1, "force should receive one starvation warning")
end)

test("multiple arrays scale total throughput by count", function()
  storage = {}
  destroyed = {}
  printed_messages = {}
  chunks = {
    {name = "metallic-asteroid-chunk", position = {x = 1, y = 1}},
    {name = "carbonic-asteroid-chunk", position = {x = 2, y = 2}},
  }

  local array_a = new_array(force, 1, {x = 0, y = 0})
  local array_b = new_array(force, 1, {x = 8, y = 8})
  surface._entities = {array_a, array_b}

  module.on_tick({tick = 60})

  assert_eq(#destroyed, 2, "two arrays should clear two chunks in the same cycle")
  assert_eq(array_a._inventory._count(), 0, "first array should spend its MMMM")
  assert_eq(array_b._inventory._count(), 0, "second array should spend its MMMM")
end)

print(string.format("\n=== ADMINISTRATORIO TRAJECTORY COMPLIANCE TESTS ==="))
print(string.format("Passed: %d  Failed: %d  Total: %d", passed, failed, passed + failed))

if #errors > 0 then
  print("\nFAILURES:")
  for i, err in ipairs(errors) do
    print(string.format("  %d) %s", i, err))
  end
  os.exit(1)
else
  print("\nAll tests passed!")
  os.exit(0)
end
