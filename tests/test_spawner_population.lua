-------------------------------------------------------------------------------
-- SPAWNER POPULATION LEASE TESTS
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

local function assert_true(value, message)
  if not value then error(message or "assertion failed", 2) end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

local limiter = require("scripts.spawner_population")

local function new_spawner(unit_number, limit)
  return {
    valid = true,
    type = "unit-spawner",
    unit_number = unit_number,
    prototype = {max_count_of_owned_units = limit},
  }
end

local function new_unit(unit_number, spawner)
  local unit = {
    valid = true,
    type = "unit",
    unit_number = unit_number,
    commandable = {spawner = spawner},
  }
  function unit.destroy()
    unit.valid = false
    unit.destroyed = true
  end
  return unit
end

local function reset(units)
  storage = {}
  local surface = {}
  function surface.find_entities_filtered()
    return units or {}
  end
  game = {surfaces = {surface}}
end

test("rebuild recovers native ownership and detached complaint leases", function()
  local spawner = new_spawner(10, 4)
  local owned_a = new_unit(1, spawner)
  local owned_b = new_unit(2, spawner)
  local detached = new_unit(3, nil)
  reset({owned_a, owned_b})
  storage.waiting_biters = {
    [detached.unit_number] = {entity = detached, home_spawner = spawner},
  }

  limiter.rebuild()

  local owned_count, detached_count = limiter.get_counts(spawner)
  assert_eq(owned_count, 2, "native owned units should be recovered")
  assert_eq(detached_count, 1, "managed complaint visitor should keep a nest lease")
end)

test("detaching an owned unit transfers rather than increases population", function()
  local spawner = new_spawner(20, 3)
  local unit = new_unit(4, spawner)
  reset({unit})
  limiter.rebuild()

  limiter.detach_unit(unit, spawner)

  local owned_count, detached_count = limiter.get_counts(spawner)
  assert_eq(owned_count, 0, "detached unit should leave native ownership accounting")
  assert_eq(detached_count, 1, "detached unit should consume one logical lease")
  assert_true(unit.valid, "detaching must not destroy the managed unit")
end)

test("replacement spawn is rejected when leases fill the nest limit", function()
  local spawner = new_spawner(30, 2)
  local first = new_unit(5, spawner)
  local second = new_unit(6, spawner)
  reset({first, second})
  limiter.rebuild()
  limiter.detach_unit(first, spawner)
  limiter.detach_unit(second, spawner)

  local replacement = new_unit(7, spawner)
  limiter.on_entity_spawned{entity = replacement, spawner = spawner}

  assert_true(replacement.destroyed, "overflow replacement should be discarded")
  local owned_count, detached_count = limiter.get_counts(spawner)
  assert_eq(owned_count, 0, "rejected replacement must not stay owned")
  assert_eq(detached_count, 2, "both distant managed units must keep their leases")
end)

test("replacement spawn is allowed while total population remains below limit", function()
  local spawner = new_spawner(40, 3)
  local detached = new_unit(8, spawner)
  reset({detached})
  limiter.rebuild()
  limiter.detach_unit(detached, spawner)

  local replacement = new_unit(9, spawner)
  limiter.on_entity_spawned{entity = replacement, spawner = spawner}

  assert_true(replacement.valid, "replacement within the combined cap should survive")
  local owned_count, detached_count = limiter.get_counts(spawner)
  assert_eq(owned_count, 1)
  assert_eq(detached_count, 1)
end)

test("field office lease transfers one native nest slot", function()
  local spawner = new_spawner(50, 2)
  local owned_a = new_unit(10, spawner)
  local owned_b = new_unit(11, spawner)
  reset({owned_a, owned_b})
  limiter.rebuild()
  local worker = new_unit(12, nil)

  assert_true(limiter.lease_new_unit(worker, spawner), "available nest slot should be leasable")

  local owned_count, detached_count = limiter.get_counts(spawner)
  assert_eq(owned_count, 1, "one native unit should be converted into worker capacity")
  assert_eq(detached_count, 1)
  assert_true(owned_a.destroyed or owned_b.destroyed, "a native slot should be retired during transfer")
  assert_true(worker.valid, "leased worker must remain detached and alive")
end)

test("invalid detached unit retains its lease until recovery rekeys it", function()
  local spawner = new_spawner(60, 1)
  local worker = new_unit(13, nil)
  reset({})
  assert_true(limiter.lease_new_unit(worker, spawner))
  worker.valid = false
  limiter.on_entity_died(worker)

  local replacement = new_unit(14, nil)
  limiter.rekey_detached(worker.unit_number, replacement.unit_number, replacement, spawner)

  local owned_count, detached_count = limiter.get_counts(spawner)
  assert_eq(owned_count, 0)
  assert_eq(detached_count, 1, "recovered worker should inherit rather than duplicate its lease")
  assert_true(limiter.get_home_spawner(replacement.unit_number) == spawner)
end)

test("new worker is refused when all nest slots are already leased", function()
  local spawner = new_spawner(70, 1)
  local first = new_unit(15, nil)
  local second = new_unit(16, nil)
  reset({})
  assert_true(limiter.lease_new_unit(first, spawner))
  assert_true(not limiter.lease_new_unit(second, spawner), "second artificial worker must wait for capacity")

  local owned_count, detached_count = limiter.get_counts(spawner)
  assert_eq(owned_count, 0)
  assert_eq(detached_count, 1)
  assert_true(second.valid, "caller retains control of a refused worker entity")
end)

if failed > 0 then
  io.stderr:write(table.concat(errors, "\n") .. "\n")
  os.exit(1)
end

print(("Spawner population tests: %d passed, %d failed"):format(passed, failed))
