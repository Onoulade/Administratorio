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

local function assert_near(actual, expected, tolerance, msg)
  if math.abs(actual - expected) > tolerance then
    error((msg or "assertion failed") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function table_count(values)
  local count = 0
  for _ in pairs(values) do count = count + 1 end
  return count
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
    asteroid_collector_output = 2,
  },
}

storage = {}
rendering = nil

local module = dofile(mod_root .. "scripts/trajectory_compliance.lua")
local next_unit_number = 100

local function new_inventory()
  local inventory = {valid = true, counts = {}}
  inventory.get_item_count = function(name)
    return inventory.counts[name] or 0
  end
  inventory.remove = function(spec)
    local present = inventory.counts[spec.name] or 0
    local removed = math.min(present, spec.count)
    inventory.counts[spec.name] = present - removed
    return removed
  end
  return inventory
end

local function new_world(hub_capacity, damage_modifier, capacity_level)
  storage = {}

  local hub = {
    valid = true,
    capacity = hub_capacity == nil and 100 or hub_capacity,
    inserted_count = 0,
    inserted = {},
    position = {x = -5, y = 0},
  }
  hub.insert = function(spec)
    local inserted = math.min(spec.count, math.max(0, hub.capacity - hub.inserted_count))
    if inserted > 0 then
      hub.inserted_count = hub.inserted_count + inserted
      hub.inserted[#hub.inserted + 1] = {
        name = spec.name,
        count = inserted,
        quality = spec.quality,
      }
    end
    return inserted
  end

  local collector_inventory = new_inventory()
  local collector = {valid = true, type = "asteroid-collector"}
  collector.get_inventory = function(inventory_index)
    assert_eq(inventory_index, defines.inventory.asteroid_collector_output)
    return collector_inventory
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
    asteroids = {},
  }
  surface.find_entities_filtered = function(filter)
    if filter.type == "asteroid-collector" then return {collector} end
    if filter.type == "asteroid" then return surface.asteroids end
    return {}
  end
  platform.surface = surface

  local force = {
    valid = true,
    name = "player",
    platforms = {platform},
    damage_modifier = damage_modifier or 0,
    technologies = {},
  }
  if capacity_level == nil then capacity_level = module.CAPACITY_TECH_LEVELS end
  for level = 1, module.CAPACITY_TECH_LEVELS do
    force.technologies[module.CAPACITY_TECH_PREFIX .. level] = {
      researched = level <= capacity_level,
    }
  end
  force.get_ammo_damage_modifier = function(category)
    assert_eq(category, module.BITER_AMMO_CATEGORY)
    return force.damage_modifier
  end

  game = {
    forces = {player = force},
  }

  return platform, hub, surface, force, collector_inventory
end

local function new_source(surface, force, quality, name)
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
    name = name or module.CANNON_NAME,
    quality = {name = quality or "normal"},
    unit_number = next_unit_number,
    surface = surface,
    force = force,
    position = {x = 0, y = 0},
    priority_targets = {},
  }
  next_unit_number = next_unit_number + 1
  entity.get_inventory = function(inventory_index)
    assert_eq(inventory_index, defines.inventory.turret_ammo)
    return inventory
  end
  entity.set_priority_target = function(index, asteroid_name)
    entity.priority_targets[index] = asteroid_name
  end
  return entity
end

local asteroid_health = {
  small = 100,
  medium = 400,
  big = 2000,
  huge = 5000,
}

local function new_target(entity_type, name, health, surface)
  entity_type = entity_type or "asteroid"
  name = name or (entity_type == "asteroid" and "small-metallic-asteroid" or "metallic-asteroid-chunk")
  local size, family = name:match("^(%a+)%-(.+)%-asteroid$")
  local default_health = asteroid_health[size]
  if default_health and family == "promethium" then default_health = default_health * 2 end
  local target = {
    valid = true,
    type = entity_type,
    name = name,
    health = health or default_health,
    position = {x = 10, y = 0},
    destroyed = false,
    surface = surface,
  }
  target.destroy = function()
    target.destroyed = true
    target.valid = false
    return true
  end
  if surface then surface.asteroids[#surface.asteroids + 1] = target end
  return target
end

local function fire_biter(source, target, extra_event)
  source.shooting_target = target
  local event = extra_event or {}
  event.effect_id = event.effect_id or module.BITER_ASSAULT_EFFECT_ID
  event.source_entity = event.source_entity or source
  event.target_entity = event.target_entity or target
  return module.on_script_trigger_effect(event)
end

local function fire_deviation(source, target)
  return module.on_script_trigger_effect({
    effect_id = module.DEVIATION_EFFECT_ID,
    source_entity = source,
    target_entity = target,
  })
end

test("native ammo damage research scales per-second biter damage", function()
  local _, _, _, force = new_world(nil, 1.5)
  assert_near(module.biter_damage(force), 312.5, 1e-9)
end)

test("MMMM quality never changes orbital performance", function()
  local _, _, surface, force = new_world()
  local normal_cannon = new_source(surface, force, "normal")
  local legendary_cannon = new_source(surface, force, "legendary")
  local normal_target = new_target("asteroid", "medium-metallic-asteroid")
  local legendary_target = new_target("asteroid", "medium-metallic-asteroid")

  local normal_handled, _, normal_damage = fire_biter(normal_cannon, normal_target)
  local legendary_handled, _, legendary_damage = fire_biter(legendary_cannon, legendary_target)

  assert_true(normal_handled and legendary_handled)
  assert_eq(normal_damage, module.BASE_BITER_DAMAGE)
  assert_eq(legendary_damage, module.BASE_BITER_DAMAGE,
    "higher-quality MMMMs must not gain a damage bonus")

  module.on_tick({tick = 60})
  assert_eq(normal_target.health, 275)
  assert_eq(legendary_target.health, 275,
    "higher-quality MMMMs must not gain a work-cycle bonus")
end)

test("staffing research raises the hard per-asteroid employee cap", function()
  local platform, _, surface, force = new_world(nil, nil, 0)
  local cannon = new_source(surface, force)
  local asteroid = new_target("asteroid", "medium-metallic-asteroid", 400, surface)

  assert_eq(module.employee_capacity(force), 1)
  local handled, outcome = fire_biter(cannon, asteroid)
  assert_true(handled)
  assert_eq(outcome, module.OUTCOME_ATTACHED)
  assert_true(cannon.disabled_by_script, "cannon should pause when its only target reaches capacity")

  local assault
  for _, candidate in pairs(storage.trajectory_compliance.assaults) do assault = candidate end
  assert_eq(#assault.workers, 1)

  -- Simulate another cannon's projectile already being in flight when the
  -- first worker filled the allocation.
  local overflow_handled, overflow_outcome = fire_biter(cannon, asteroid)
  assert_true(overflow_handled)
  assert_eq(overflow_outcome, module.OUTCOME_AT_CAPACITY)
  assert_eq(#assault.workers, 1, "overflow must not exceed the researched cap")
  assert_eq(#platform.created_chunks, 1)
  assert_eq(platform.created_chunks[1].name, module.RETURNING_CHUNK,
    "an airborne rejected manager should remain collectible")

  force.technologies[module.CAPACITY_TECH_PREFIX .. 1].researched = true
  assert_eq(module.employee_capacity(force), 2)
  module.on_tick({tick = 60})
  assert_true(not cannon.disabled_by_script,
    "capacity research should wake a cannon whose current asteroid gained a vacancy")
  assert_eq(cannon.shooting_target, asteroid)

  fire_biter(cannon, asteroid)
  assert_eq(#assault.workers, 2)
  assert_true(cannon.disabled_by_script, "the researched cap must remain hard")

  for level = 2, module.CAPACITY_TECH_LEVELS do
    force.technologies[module.CAPACITY_TECH_PREFIX .. level].researched = true
    assert_eq(module.employee_capacity(force), level + 1)
  end
end)

test("a full asteroid makes its cannon retarget another eligible asteroid", function()
  local _, _, surface, force = new_world(nil, nil, 0)
  local cannon = new_source(surface, force)
  local first = new_target("asteroid", "medium-metallic-asteroid", 400, surface)
  local second = new_target("asteroid", "big-carbonic-asteroid", 2000, surface)

  fire_biter(cannon, first)

  assert_true(not cannon.disabled_by_script)
  assert_eq(cannon.shooting_target, second,
    "a cannon should use another asteroid instead of wasting shots on a full one")

  fire_biter(cannon, second)
  assert_true(cannon.disabled_by_script,
    "cannon should pause when every available asteroid is fully staffed")
end)

test("array and cannon configuration install strict native priorities", function()
  local _, _, surface, force = new_world()
  local junior = new_source(surface, force, "normal", "trajectory-compliance-array")
  local senior = new_source(surface, force, "normal", "senior-trajectory-compliance-array")
  local executive = new_source(surface, force, "normal", "executive-trajectory-compliance-array")
  local cannon = new_source(surface, force)

  for _, entity in ipairs({junior, senior, executive, cannon}) do
    assert_true(module.configure_array(entity))
    assert_true(entity.ignore_unprioritised_targets)
  end
  assert_eq(#junior.priority_targets, 8)
  assert_eq(#senior.priority_targets, 12)
  assert_eq(#executive.priority_targets, 16)
  assert_eq(#cannon.priority_targets, 16)
end)

test("deviation removes threats without producing salvage", function()
  local platform, hub, surface, force = new_world()
  local array = new_source(surface, force, "epic", "trajectory-compliance-array")
  local asteroid = new_target("asteroid", "medium-carbonic-asteroid")

  local handled, outcome = fire_deviation(array, asteroid)

  assert_true(handled)
  assert_eq(outcome, module.OUTCOME_DEVIATED)
  assert_true(asteroid.destroyed)
  assert_eq(#platform.created_chunks, 0)
  assert_eq(#hub.inserted, 0)
end)

test("deviation tiers reject asteroids beyond their jurisdiction", function()
  local _, _, surface, force = new_world()
  local junior = new_source(surface, force, "normal", "trajectory-compliance-array")
  local senior = new_source(surface, force, "normal", "senior-trajectory-compliance-array")
  local executive = new_source(surface, force, "normal", "executive-trajectory-compliance-array")

  local big = new_target("asteroid", "big-oxide-asteroid")
  assert_true(not fire_deviation(junior, big))
  assert_true(big.valid)
  assert_true(fire_deviation(senior, big))

  local huge = new_target("asteroid", "huge-promethium-asteroid")
  assert_true(not fire_deviation(senior, huge))
  assert_true(huge.valid)
  assert_true(fire_deviation(executive, huge))
end)

test("impact attaches a worker and damage begins on the next work cycle", function()
  local platform, hub, surface, force = new_world()
  local cannon = new_source(surface, force, "rare")
  local asteroid = new_target("asteroid", "big-metallic-asteroid")

  local handled, outcome, damage, destroyed = fire_biter(cannon, asteroid)

  assert_true(handled)
  assert_eq(outcome, module.OUTCOME_ATTACHED)
  assert_eq(damage, 125)
  assert_true(not destroyed)
  assert_eq(asteroid.health, 2000, "impact must not deal immediate damage")
  assert_eq(table_count(storage.trajectory_compliance.assaults), 1)

  module.on_tick({tick = 59})
  assert_eq(asteroid.health, 2000)
  module.on_tick({tick = 60})
  assert_eq(asteroid.health, 1875)
  assert_eq(#platform.created_chunks, 0)
  assert_eq(#hub.inserted, 0, "attached workers cannot teleport home")
end)

test("a late-cycle impact waits a full second before its first damage", function()
  local _, _, surface, force = new_world()
  local cannon = new_source(surface, force)
  local asteroid = new_target("asteroid", "medium-metallic-asteroid")
  fire_biter(cannon, asteroid, {tick = 59})

  module.on_tick({tick = 60})
  assert_eq(asteroid.health, 400)
  module.on_tick({tick = 120})
  assert_eq(asteroid.health, 275)
end)

test("multiple attached workers stack damage and each becomes a chunk", function()
  local platform, _, surface, force = new_world()
  local cannon = new_source(surface, force, "epic")
  local asteroid = new_target("asteroid", "medium-carbonic-asteroid", 200)

  fire_biter(cannon, asteroid)
  fire_biter(cannon, asteroid)
  module.on_tick({tick = 60})

  assert_true(asteroid.destroyed)
  assert_eq(#platform.created_chunks, 8, "six salvage plus two employees expected")
  assert_eq(platform.created_chunks[7].name, module.RETURNING_CHUNK)
  assert_eq(platform.created_chunks[8].name, module.RETURNING_CHUNK)
end)

test("completed demolition creates full salvage plus the employee chunk", function()
  local cases = {
    {name = "small-metallic-asteroid", count = 2, chunk = "metallic-asteroid-chunk"},
    {name = "medium-carbonic-asteroid", count = 6, chunk = "carbonic-asteroid-chunk"},
    {name = "big-oxide-asteroid", count = 18, chunk = "oxide-asteroid-chunk"},
    {name = "huge-promethium-asteroid", count = 54, chunk = "promethium-asteroid-chunk"},
  }

  for _, case in ipairs(cases) do
    local platform, _, surface, force = new_world()
    local cannon = new_source(surface, force)
    local asteroid = new_target("asteroid", case.name, 1)
    fire_biter(cannon, asteroid)
    module.on_tick({tick = 60})

    assert_true(asteroid.destroyed)
    assert_eq(#platform.created_chunks, case.count + 1, case.name .. " chunk count mismatch")
    for index = 1, case.count do
      assert_eq(platform.created_chunks[index].name, case.chunk)
      assert_true(platform.created_chunks[index].movement.x < 0, "salvage should drift toward the hub")
    end
    assert_eq(platform.created_chunks[case.count + 1].name, module.RETURNING_CHUNK)
  end
end)

test("projectile cause lookup still attaches the fired employee", function()
  local platform, _, surface, force = new_world()
  local cannon = new_source(surface, force, "normal")
  local projectile = {valid = true, name = "orbital-biter-projectile"}
  local asteroid = new_target("asteroid", "small-metallic-asteroid", 1)

  assert_true(fire_biter(cannon, asteroid, {
    source_entity = projectile,
    cause_entity = cannon,
    quality = "legendary",
  }))
  module.on_tick({tick = 60})

  assert_eq(platform.created_chunks[3].name, module.RETURNING_CHUNK)
end)

test("external asteroid death releases attached employees alongside native debris", function()
  local platform, _, surface, force = new_world()
  local cannon = new_source(surface, force, "rare")
  local asteroid = new_target("asteroid", "big-oxide-asteroid")
  fire_biter(cannon, asteroid)

  assert_true(module.on_entity_died({entity = asteroid}))
  assert_eq(#platform.created_chunks, 1)
  assert_eq(platform.created_chunks[1].name, module.RETURNING_CHUNK)
  assert_eq(table_count(storage.trajectory_compliance.assaults), 0)
end)

test("an invalidated asteroid loses its attached workers in space", function()
  local platform, _, surface, force = new_world()
  local cannon = new_source(surface, force)
  local asteroid = new_target()
  fire_biter(cannon, asteroid)
  asteroid.valid = false

  module.on_tick({tick = 60})
  assert_eq(#platform.created_chunks, 0)
  assert_eq(table_count(storage.trajectory_compliance.assaults), 0)
end)

test("deviating an occupied asteroid loses its workers and yields nothing", function()
  local platform, _, surface, force = new_world()
  local cannon = new_source(surface, force)
  local array = new_source(surface, force, "normal", "executive-trajectory-compliance-array")
  local asteroid = new_target("asteroid", "small-metallic-asteroid")
  fire_biter(cannon, asteroid)

  assert_true(fire_deviation(array, asteroid))
  assert_eq(#platform.created_chunks, 0)
  assert_eq(table_count(storage.trajectory_compliance.assaults), 0)
end)

test("collectible chunks and unrelated effects are ignored", function()
  local _, hub, surface, force = new_world()
  local cannon = new_source(surface, force)
  local chunk = new_target("asteroid-chunk")
  local asteroid = new_target("asteroid")

  assert_true(not fire_biter(cannon, chunk))
  assert_true(not chunk.destroyed)
  assert_true(not fire_biter(cannon, asteroid, {effect_id = "some-other-effect"}))
  assert_true(not asteroid.destroyed)
  assert_eq(#hub.inserted, 0)
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
