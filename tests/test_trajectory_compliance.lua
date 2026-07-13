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
    yellow = 2,
  },
}

storage = {}

local module = dofile(mod_root .. "scripts/trajectory_compliance.lua")
local next_unit_number = 100

local function new_world(hub_capacity)
  storage = {}

  local hub = {
    valid = true,
    capacity = hub_capacity or 100,
    inserted = {},
  }
  hub.insert = function(spec)
    if #hub.inserted >= hub.capacity then return 0 end
    hub.inserted[#hub.inserted + 1] = {
      name = spec.name,
      count = spec.count,
      quality = spec.quality,
    }
    return spec.count
  end

  local platform = {
    valid = true,
    index = 7,
    hub = hub,
    created_chunks = {},
  }
  platform.create_asteroid_chunks = function(chunks)
    for _, chunk in ipairs(chunks) do
      platform.created_chunks[#platform.created_chunks + 1] = chunk
    end
  end
  local surface = {
    valid = true,
    platform = platform,
  }
  platform.surface = surface

  local force = {
    valid = true,
    platforms = {platform},
  }
  game = {
    forces = {player = force},
  }

  return platform, hub, surface
end

local function new_array(surface, quality, name)
  local inventory = {
    valid = true,
    {
      valid_for_read = true,
      name = "middle-management-managing-manager",
      quality = {name = quality or "normal"},
    },
  }
  local entity = {
    valid = true,
    name = name or "trajectory-compliance-array",
    unit_number = next_unit_number,
    surface = surface,
    force = "player",
    position = {x = 0, y = 0},
    disabled_by_script = false,
    priority_targets = {},
  }
  next_unit_number = next_unit_number + 1
  entity.get_inventory = function(inventory_index)
    assert_eq(inventory_index, defines.inventory.turret_ammo, "quality lookup should use turret ammo inventory")
    return inventory
  end
  entity.set_priority_target = function(index, asteroid_name)
    entity.priority_targets[index] = asteroid_name
  end
  return entity
end

local function new_target(entity_type, name)
  entity_type = entity_type or "asteroid"
  local target = {
    valid = true,
    type = entity_type,
    name = name or (entity_type == "asteroid" and "small-metallic-asteroid" or "metallic-asteroid-chunk"),
    position = {x = 10, y = 0},
    destroyed = false,
  }
  target.destroy = function()
    target.destroyed = true
    target.valid = false
    return true
  end
  return target
end

local function fire(source, target, roll, effect_id)
  return module.on_script_trigger_effect({
    effect_id = effect_id or module.EFFECT_ID,
    source_entity = source,
    target_entity = target,
  }, roll)
end

test("probability boundaries are deterministic", function()
  assert_eq(module.classify_outcome(0), module.OUTCOME_INTACT)
  assert_eq(module.classify_outcome(0.899999), module.OUTCOME_INTACT)
  assert_eq(module.classify_outcome(0.90), module.OUTCOME_BURNED_OUT)
  assert_eq(module.classify_outcome(0.949999), module.OUTCOME_BURNED_OUT)
  assert_eq(module.classify_outcome(0.95), module.OUTCOME_LOST)
  assert_eq(module.classify_outcome(1), module.OUTCOME_LOST)
end)

test("array configuration installs strict size-appropriate native priorities", function()
  local _, _, surface = new_world()
  local junior = new_array(surface, "normal", "trajectory-compliance-array")
  local senior = new_array(surface, "normal", "senior-trajectory-compliance-array")
  local executive = new_array(surface, "normal", "executive-trajectory-compliance-array")

  assert_true(module.configure_array(junior))
  assert_true(module.configure_array(senior))
  assert_true(module.configure_array(executive))
  assert_true(junior.ignore_unprioritised_targets)
  assert_true(senior.ignore_unprioritised_targets)
  assert_true(executive.ignore_unprioritised_targets)
  assert_eq(#junior.priority_targets, 8, "junior should list four families at two sizes")
  assert_eq(#senior.priority_targets, 12, "senior should list four families at three sizes")
  assert_eq(#executive.priority_targets, 16, "executive should list every family and size")
  for _, name in ipairs(junior.priority_targets) do
    assert_true(not name:match("^big%-") and not name:match("^huge%-"), "junior priority leaked a large asteroid")
  end
end)

test("script effect converts an asteroid into collectible salvage and returns manager quality", function()
  local platform, hub, surface = new_world()
  local array = new_array(surface, "epic")
  local asteroid = new_target("asteroid")

  local handled, outcome = fire(array, asteroid, 0.42)

  assert_true(handled, "trajectory effect should be handled")
  assert_eq(outcome, module.OUTCOME_INTACT)
  assert_true(asteroid.destroyed, "actual asteroid entity should be removed")
  assert_eq(#platform.created_chunks, 2, "small asteroids should yield two collectible chunks")
  assert_eq(platform.created_chunks[1].name, "metallic-asteroid-chunk")
  assert_true(platform.created_chunks[1].movement.x < 0, "salvage should drift toward the source array")
  assert_eq(#hub.inserted, 1, "returned manager should enter platform cargo")
  assert_eq(hub.inserted[1].name, module.MANAGEMENT_ITEM)
  assert_eq(hub.inserted[1].quality, "epic", "returned manager should preserve ammo quality")
end)

test("effect handler can resolve the turret's live shooting target", function()
  local platform, _, surface = new_world()
  local array = new_array(surface, "normal")
  local asteroid = new_target("asteroid", "medium-carbonic-asteroid")
  array.shooting_target = asteroid

  local handled = module.on_script_trigger_effect({
    effect_id = module.EFFECT_ID,
    source_entity = array,
  }, 0.95)

  assert_true(handled)
  assert_true(asteroid.destroyed)
  assert_eq(#platform.created_chunks, 6)
end)

test("every asteroid size yields its full vanilla-equivalent salvage count", function()
  local cases = {
    {name = "small-metallic-asteroid", count = 2, chunk = "metallic-asteroid-chunk"},
    {name = "medium-carbonic-asteroid", count = 6, chunk = "carbonic-asteroid-chunk"},
    {name = "big-oxide-asteroid", count = 18, chunk = "oxide-asteroid-chunk"},
    {name = "huge-promethium-asteroid", count = 54, chunk = "promethium-asteroid-chunk"},
  }

  for _, case in ipairs(cases) do
    local platform, _, surface = new_world()
    local executive = new_array(surface, "normal", "executive-trajectory-compliance-array")
    assert_true(fire(executive, new_target("asteroid", case.name), 0.95), case.name .. " should be handled")
    assert_eq(#platform.created_chunks, case.count, case.name .. " salvage count mismatch")
    for _, chunk in ipairs(platform.created_chunks) do
      assert_eq(chunk.name, case.chunk, case.name .. " should preserve asteroid family")
    end
  end
end)

test("burned-out boundary returns a burned manager with quality", function()
  local _, hub, surface = new_world()
  local array = new_array(surface, "rare")
  local asteroid = new_target()

  local _, outcome = fire(array, asteroid, 0.90)

  assert_eq(outcome, module.OUTCOME_BURNED_OUT)
  assert_true(asteroid.destroyed)
  assert_eq(hub.inserted[1].name, module.BURNED_OUT_ITEM)
  assert_eq(hub.inserted[1].quality, "rare")
end)

test("lost boundary destroys the asteroid without returning cargo", function()
  local _, hub, surface = new_world()
  local array = new_array(surface)
  local asteroid = new_target()

  local _, outcome = fire(array, asteroid, 0.95)

  assert_eq(outcome, module.OUTCOME_LOST)
  assert_true(asteroid.destroyed)
  assert_eq(#hub.inserted, 0, "lost manager should not produce an output")
  assert_true(not array.disabled_by_script, "lost output should not block the array")
end)

test("collectible chunks and unrelated script effects are ignored", function()
  local _, hub, surface = new_world()
  local array = new_array(surface)
  local chunk = new_target("asteroid-chunk")
  local asteroid = new_target("asteroid")

  assert_true(not fire(array, chunk, 0), "collectible asteroid chunks should be ignored")
  assert_true(not chunk.destroyed, "chunk should remain untouched")
  assert_true(not fire(array, asteroid, 0, "some-other-effect"), "unrelated effects should be ignored")
  assert_true(not asteroid.destroyed)
  assert_eq(#hub.inserted, 0)
end)

test("array tiers enforce progressively larger asteroid jurisdiction", function()
  local _, hub, surface = new_world()
  local junior = new_array(surface, "normal", "trajectory-compliance-array")
  local senior = new_array(surface, "normal", "senior-trajectory-compliance-array")
  local executive = new_array(surface, "normal", "executive-trajectory-compliance-array")

  assert_true(fire(junior, new_target("asteroid", "small-metallic-asteroid"), 0.95))
  assert_true(fire(junior, new_target("asteroid", "medium-carbonic-asteroid"), 0.95))

  local junior_big = new_target("asteroid", "big-oxide-asteroid")
  assert_true(not fire(junior, junior_big, 0.95), "junior array must reject big asteroids")
  assert_true(junior_big.valid, "rejected big asteroid should survive")

  assert_true(fire(senior, new_target("asteroid", "big-metallic-asteroid"), 0.95))
  local senior_huge = new_target("asteroid", "huge-carbonic-asteroid")
  assert_true(not fire(senior, senior_huge, 0.95), "senior array must reject huge asteroids")
  assert_true(senior_huge.valid, "rejected huge asteroid should survive")

  assert_true(fire(executive, new_target("asteroid", "huge-promethium-asteroid"), 0.95),
    "executive array should handle huge Promethium asteroids")
  assert_eq(#hub.inserted, 0, "forced lost outcomes should not insert manager cargo")
end)

test("full hub queues output, blocks its source, and retries once per second", function()
  local _, hub, surface = new_world(0)
  local array = new_array(surface, "legendary")
  local asteroid = new_target()

  fire(array, asteroid, 0.2)

  assert_true(array.disabled_by_script, "source array should be disabled while its output is blocked")
  assert_true(array.custom_status ~= nil, "source array should show an output-blocked status")
  assert_eq(array.custom_status.diode, defines.entity_status_diode.yellow)
  assert_true(storage.trajectory_compliance.pending_outputs[array.unit_number] ~= nil, "output should be queued")

  hub.capacity = 1
  module.on_tick({tick = 59})
  assert_eq(#hub.inserted, 0, "queue should not retry before the one-second boundary")
  module.on_tick({tick = 60})

  assert_eq(#hub.inserted, 1, "queued output should be delivered once cargo has room")
  assert_eq(hub.inserted[1].quality, "legendary")
  assert_true(not array.disabled_by_script, "array should resume after output delivery")
  assert_eq(array.custom_status, nil, "blocked status should clear after delivery")
  assert_eq(storage.trajectory_compliance.pending_outputs[array.unit_number], nil)
end)

test("removing an array does not lose its queued manager while the platform survives", function()
  local _, hub, surface = new_world(0)
  local array = new_array(surface, "uncommon")

  fire(array, new_target(), 0.1)
  array.valid = false
  hub.capacity = 1
  module.on_tick({tick = 60})

  assert_eq(#hub.inserted, 1, "deferred output should still reach the surviving platform")
  assert_eq(hub.inserted[1].quality, "uncommon")
  assert_eq(storage.trajectory_compliance.pending_outputs[array.unit_number], nil)
end)

test("orphaned queues are cleaned when both source and platform are removed", function()
  local platform, _, surface = new_world(0)
  local array = new_array(surface)

  fire(array, new_target(), 0.1)
  array.valid = false
  platform.valid = false
  module.on_tick({tick = 60})

  assert_eq(storage.trajectory_compliance.pending_outputs[array.unit_number], nil)
end)

test("multiple arrays maintain independent blocked outputs", function()
  local _, hub, surface = new_world(1)
  local first = new_array(surface, "normal")
  local second = new_array(surface, "rare")

  fire(first, new_target(), 0.2)
  fire(second, new_target(), 0.2)

  assert_eq(#hub.inserted, 1)
  assert_true(not first.disabled_by_script)
  assert_true(second.disabled_by_script)

  hub.capacity = 2
  module.on_tick({tick = 60})
  assert_eq(#hub.inserted, 2)
  assert_eq(hub.inserted[2].quality, "rare")
  assert_true(not second.disabled_by_script)
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
