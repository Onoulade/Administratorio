-------------------------------------------------------------------------------
-- STARTUP CLEANUP TESTS
--
-- Verifies the crash-site startup cleanup restocks the spaceship with the
-- mod's required starter items.
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
    error((msg or "assertion failed") .. " — expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function new_inventory()
  local inventory = {
    cleared = false,
    items = {},
  }
  inventory.clear = function()
    inventory.cleared = true
    inventory.items = {}
  end
  inventory.insert = function(stack)
    inventory.items[stack.name] = (inventory.items[stack.name] or 0) + stack.count
    return stack.count
  end
  return inventory
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
    chest = 1,
  },
}

local ship_inventory = new_inventory()
local chest_1_inventory = new_inventory()
local chest_2_inventory = new_inventory()

local surface = {
  find_entities_filtered = function(opts)
    if opts.name == "crash-site-spaceship" then
      return {
        {
          get_inventory = function(inventory_id)
            assert_eq(inventory_id, defines.inventory.chest, "spaceship should request chest inventory")
            return ship_inventory
          end,
        }
      }
    end
    if opts.name == "crash-site-chest-1" then
      return {
        {
          get_inventory = function(inventory_id)
            assert_eq(inventory_id, defines.inventory.chest, "crash chest 1 should request chest inventory")
            return chest_1_inventory
          end,
        }
      }
    end
    if opts.name == "crash-site-chest-2" then
      return {
        {
          get_inventory = function(inventory_id)
            assert_eq(inventory_id, defines.inventory.chest, "crash chest 2 should request chest inventory")
            return chest_2_inventory
          end,
        }
      }
    end
    return {}
  end,
}

game = {
  surfaces = {[1] = surface},
  players = {
    {character = true},
  },
  connected_players = {},
  forces = {
    player = {},
  },
}

storage = {
  needs_startup_cleanup = true,
  achievements = {},
}

local noop = function() end

local runtime_debug = {
  begin_snapshot = function()
    return nil, nil
  end,
  run_profiled_section = function(_, _, fn)
    if fn then fn() end
  end,
  complete_snapshot = noop,
}

local deps = {
  runtime_debug = runtime_debug,
  update_tracked_unit_group_debug = noop,
  trains = {on_tick = noop},
  strip_weapons = noop,
  warn_force_about_evolution_complaints = noop,
  cleanup_waiting_zone_overlays = noop,
  working_hours = {
    is_enabled = function() return false end,
    rebuild_registry = noop,
    update_managed_buildings = noop,
  },
  biters = {
    refresh_protest_notifications = noop,
    process_walk_in_registration = noop,
    process_resolutions = noop,
    process_frustration_and_protests = noop,
    process_calmed_spawners = noop,
    update_circuit_signals = noop,
  },
  get_cached_desks = function() return {} end,
  collect_runtime_debug_counts = function() return {} end,
}

local module = dofile(mod_root .. "scripts/control_resolution_processing.lua")

test("startup cleanup restocks crash pieces with starter tools and paperwork", function()
  local controller = module.new(deps)
  controller.on_tick({tick = 1})

  assert_true(storage.needs_startup_cleanup == nil, "startup cleanup flag should clear after cleanup")

  assert_true(ship_inventory.cleared, "spaceship inventory should be cleared")
  assert_eq(ship_inventory.items["mechanical-printer"], 1, "spaceship should receive one mechanical printer")
  assert_eq(ship_inventory.items["burner-mining-drill"], 2, "spaceship should receive two burner mining drills")
  assert_eq(ship_inventory.items["admin-station"], 1, "spaceship should receive one admin station")
  assert_true(ship_inventory.items["construction-permit"] == nil, "spaceship should not receive construction permits")
  assert_true(ship_inventory.items["safety-waiver"] == nil, "spaceship should not receive safety waivers")
  assert_eq(ship_inventory.items["carbon-offset-certificate-basic"], 3,
    "spaceship should receive three basic carbon offset certificates")

  assert_true(chest_1_inventory.cleared, "crash chest 1 should be cleared")
  assert_true(chest_2_inventory.cleared, "crash chest 2 should be cleared")
  assert_true(next(chest_1_inventory.items) == nil, "crash chest 1 should stay empty if present")
  assert_true(next(chest_2_inventory.items) == nil, "crash chest 2 should stay empty if present")
end)

print(string.format("\n=== STARTUP CLEANUP TESTS ==="))
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
