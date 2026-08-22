-------------------------------------------------------------------------------
-- SPACE AGE DISABLED GUARD TESTS
--
-- find_entities_filtered errors on an unknown prototype name rather than
-- returning empty, so every rebuild_registry() that scans for a Space-Age-
-- only entity must skip out before calling it when Space Age is absent.
-- A2ace50 fixed a live crash on exactly this path; this file is the
-- regression test that fix shipped without.
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
  inventory = {furnace_source = 1, furnace_result = 2, chest = 3, assembling_machine_input = 4},
  entity_status_diode = {red = 1, yellow = 2, green = 3},
  direction = {north = 0, east = 2, south = 4, west = 6},
  wire_connector_id = {circuit_red = 1, circuit_green = 2},
}
storage = {}

-- A surface whose find_entities_filtered always errors. Any rebuild_registry
-- that reaches it despite the missing prototype fails the test immediately,
-- which is a stronger signal than "did not throw".
local function poisoned_surface()
  return {
    valid = true,
    find_entities_filtered = function()
      error("find_entities_filtered must not be called for a Space-Age-only name when the prototype does not exist")
    end,
  }
end

local function fresh(module_name)
  package.loaded[module_name] = nil
  return require(module_name)
end

-------------------------------------------------------------------------------
-- feature_flags.entity_prototype_exists
-------------------------------------------------------------------------------

test("entity_prototype_exists is true when the prototypes table is unavailable", function()
  prototypes = nil
  local feature_flags = fresh("feature_flags")
  assert_true(feature_flags.entity_prototype_exists("ai-server"),
    "data stage / no prototype table should not block a caller that cannot check")
end)

test("entity_prototype_exists is false for a name absent from prototypes.entity", function()
  prototypes = {entity = {}}
  local feature_flags = fresh("feature_flags")
  assert_true(not feature_flags.entity_prototype_exists("ai-server"),
    "Space Age disabled means ai-server should not be reported as existing")
end)

test("entity_prototype_exists is true for a name present in prototypes.entity", function()
  prototypes = {entity = {["ai-server"] = {}}}
  local feature_flags = fresh("feature_flags")
  assert_true(feature_flags.entity_prototype_exists("ai-server"))
end)

-------------------------------------------------------------------------------
-- rebuild_registry() with Space Age absent
-------------------------------------------------------------------------------

test("ai_server.rebuild_registry is a no-op without the ai-server prototype", function()
  prototypes = {entity = {}}
  storage = {}
  game = {surfaces = {poisoned_surface()}}
  local ai_server = fresh("scripts.ai_server")

  ai_server.rebuild_registry()

  assert_eq(next(storage.ai_servers), nil, "no server should have been tracked")
end)

test("interplanetary_tube.rebuild_registry is a no-op without the terminus prototype", function()
  prototypes = {entity = {}}
  storage = {}
  game = {surfaces = {poisoned_surface()}}
  local interplanetary_tube = fresh("scripts.interplanetary_tube")

  interplanetary_tube.rebuild_registry()

  assert_eq(next(storage.terminus_registry), nil, "no terminus should have been tracked")
end)

test("relocation_cannon.rebuild_registry is a no-op without either role's prototype", function()
  prototypes = {entity = {}}
  storage = {}
  game = {surfaces = {poisoned_surface()}}
  local relocation_cannon = fresh("scripts.relocation_cannon")

  relocation_cannon.rebuild_registry()

  assert_eq(next(storage.relocation_cannons), nil, "neither emitter nor receiver should have been tracked")
end)

test("territorial_arbitration.rebuild_registry is a no-op without the post prototype", function()
  prototypes = {entity = {}}
  storage = {}
  game = {surfaces = {poisoned_surface()}}
  local territorial_arbitration = fresh("scripts.territorial_arbitration")

  territorial_arbitration.rebuild_registry()

  assert_eq(next(storage.territorial_arbitration.posts), nil, "no post should have been tracked")
end)

test("heat_exhaust.rebuild_registry is a no-op without the heat-exhaust prototype", function()
  prototypes = {entity = {}}
  storage = {}
  game = {surfaces = {poisoned_surface()}}
  local heat_exhaust = fresh("scripts.heat_exhaust")

  -- Must simply return without error; Heat Exhaust keeps no registry of its own.
  heat_exhaust.rebuild_registry()
end)

-------------------------------------------------------------------------------
-- The same modules still scan normally once the prototype exists
-------------------------------------------------------------------------------

test("ai_server.rebuild_registry scans surfaces once the prototype exists", function()
  local C = fresh("scripts.constants")
  prototypes = {entity = {[C.AI_SERVER_NAME] = {}}}
  storage = {}
  local scanned_names = {}
  game = {
    surfaces = {
      {
        valid = true,
        find_entities_filtered = function(opts)
          scanned_names[opts.name] = true
          return {}
        end,
      },
    },
  }
  local ai_server = fresh("scripts.ai_server")

  ai_server.rebuild_registry()

  assert_true(scanned_names[C.AI_SERVER_NAME], "rebuild should scan for servers once the prototype is present")
  assert_true(scanned_names[C.AI_SERVER_HEAT_CORE_NAME], "rebuild should also sweep orphaned heat cores")
end)

print(string.format("\n=== SPACE AGE DISABLED GUARD TESTS ==="))
print(string.format("Passed: %d  Failed: %d  Total: %d", passed, failed, passed + failed))

if #errors > 0 then
  print("\nFAILURES:")
  for i, err in ipairs(errors) do
    print(string.format("  %d) %s", i, err))
  end
  os.exit(1)
end

print("\nAll tests passed!")
