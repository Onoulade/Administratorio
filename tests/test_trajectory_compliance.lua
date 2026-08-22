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

local function assert_returning_chunk(name, msg)
  assert_true(type(name) == "string"
    and name:match("^returning%-orbital%-employee") ~= nil,
    msg or ("expected returning employee chunk, got " .. tostring(name)))
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

defines = {
  direction = {
    north = 0,
    east = 4,
    south = 8,
    west = 12,
  },
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
    entities = {},
  }
  surface.find_entities_filtered = function(filter)
    if filter.type == "asteroid-collector" then return {collector} end
    if filter.type == "asteroid" then
      if not filter.position or not filter.radius then return surface.asteroids end
      local matches = {}
      local radius_squared = filter.radius * filter.radius
      for _, asteroid in ipairs(surface.asteroids) do
        local dx = asteroid.position.x - filter.position.x
        local dy = asteroid.position.y - filter.position.y
        if dx * dx + dy * dy <= radius_squared then
          matches[#matches + 1] = asteroid
        end
      end
      return matches
    end
    if filter.name then
      local accepted = {}
      if type(filter.name) == "table" then
        for _, name in ipairs(filter.name) do accepted[name] = true end
      else
        accepted[filter.name] = true
      end
      local matches = {}
      for _, entity in ipairs(surface.entities) do
        if accepted[entity.name] then matches[#matches + 1] = entity end
      end
      return matches
    end
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
    surfaces = {surface},
  }

  return platform, hub, surface, force, collector_inventory
end

local function new_source(surface, force, quality, name)
  local inventory = {
    valid = true,
    {
      valid_for_read = true,
      name = "voluntary-exploration-space-miner",
      quality = {name = quality or "normal"},
    },
  }
  local entity = {
    valid = true,
    name = name or module.CATAPULT_NAME,
    quality = {name = quality or "normal"},
    unit_number = next_unit_number,
    surface = surface,
    force = force,
    position = {x = 0, y = 0},
    direction = defines.direction.east,
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
  if surface then surface.entities[#surface.entities + 1] = entity end
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
  target.teleport = function(position)
    target.position = {x = position.x, y = position.y}
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

local function fire_biter_launch(source, target, tick)
  source.shooting_target = target
  return module.on_script_trigger_effect({
    effect_id = module.BITER_LAUNCH_EFFECT_ID,
    source_entity = source,
    target_entity = target,
    tick = tick or 0,
  })
end

local function fire_deviation(source, target, effect_id)
  source.shooting_target = target
  return module.on_script_trigger_effect({
    effect_id = effect_id or module.DEVIATION_EFFECT_ID,
    source_entity = source,
    target_entity = target,
  })
end

test("native ammo damage research scales per-second biter damage", function()
  local _, _, _, force = new_world(nil, 1.5)
  assert_near(module.biter_damage(force), 312.5, 1e-9)
end)

test("priority deviation orders apply twice the sustained push", function()
  local _, _, surface, force = new_world()
  local routine_array = new_source(surface, force, "normal", "trajectory-compliance-array")
  local priority_array = new_source(surface, force, "normal", "trajectory-compliance-array")
  local routine_target = new_target("asteroid", "medium-carbonic-asteroid", nil, surface)
  local priority_target = new_target("asteroid", "medium-carbonic-asteroid", nil, surface)
  routine_target.position = {x = 10, y = -2}
  priority_target.position = {x = 10, y = 2}

  fire_deviation(routine_array, routine_target)
  fire_deviation(priority_array, priority_target, module.PRIORITY_DEVIATION_EFFECT_ID)
  module.on_tick({tick = 1})

  local routine_distance = math.sqrt((routine_target.position.x + 5) ^ 2 + routine_target.position.y ^ 2)
  local priority_distance = math.sqrt((priority_target.position.x + 5) ^ 2 + priority_target.position.y ^ 2)
  local initial_distance = math.sqrt(15 ^ 2 + 2 ^ 2)
  assert_near(priority_distance - initial_distance, 2 * (routine_distance - initial_distance), 1e-9,
    "priority paperwork should have exactly twice routine force before the speed cap")
end)

test("VESM quality never changes orbital performance", function()
  local _, _, surface, force = new_world()
  local normal_catapult = new_source(surface, force, "normal")
  local legendary_catapult = new_source(surface, force, "legendary")
  local normal_target = new_target("asteroid", "medium-metallic-asteroid")
  local legendary_target = new_target("asteroid", "medium-metallic-asteroid")

  local normal_handled, _, normal_damage = fire_biter(normal_catapult, normal_target)
  local legendary_handled, _, legendary_damage = fire_biter(legendary_catapult, legendary_target)

  assert_true(normal_handled and legendary_handled)
  assert_eq(normal_damage, module.BASE_BITER_DAMAGE)
  assert_eq(legendary_damage, module.BASE_BITER_DAMAGE,
    "higher-quality VESMs must not gain a damage bonus")

  module.on_tick({tick = 60})
  assert_eq(normal_target.health, 275)
  assert_eq(legendary_target.health, 275,
    "higher-quality VESMs must not gain a work-cycle bonus")
end)

test("staffing research raises the hard per-asteroid employee cap", function()
  local platform, _, surface, force = new_world(nil, nil, 0)
  local catapult = new_source(surface, force)
  local asteroid = new_target("asteroid", "medium-metallic-asteroid", 400, surface)

  assert_eq(module.employee_capacity(force), 1)
  local handled, outcome = fire_biter(catapult, asteroid)
  assert_true(handled)
  assert_eq(outcome, module.OUTCOME_ATTACHED)
  assert_true(catapult.disabled_by_script, "catapult should pause when its only target reaches capacity")

  local assault
  for _, candidate in pairs(storage.trajectory_compliance.assaults) do assault = candidate end
  assert_eq(#assault.workers, 1)

  -- Simulate another catapult's projectile already being in flight when the
  -- first worker filled the allocation.
  local overflow_handled, overflow_outcome = fire_biter(catapult, asteroid)
  assert_true(overflow_handled)
  assert_eq(overflow_outcome, module.OUTCOME_AT_CAPACITY)
  assert_eq(#assault.workers, 1, "overflow must not exceed the researched cap")
  assert_eq(#platform.created_chunks, 1)
  assert_returning_chunk(platform.created_chunks[1].name,
    "an airborne rejected manager should remain collectible")

  force.technologies[module.CAPACITY_TECH_PREFIX .. 1].researched = true
  assert_eq(module.employee_capacity(force), 2)
  module.on_tick({tick = 60})
  assert_true(not catapult.disabled_by_script,
    "capacity research should wake a catapult whose current asteroid gained a vacancy")
  assert_eq(catapult.shooting_target, asteroid)

  fire_biter(catapult, asteroid)
  assert_eq(#assault.workers, 2)
  assert_true(catapult.disabled_by_script, "the researched cap must remain hard")

  for level = 2, module.CAPACITY_TECH_LEVELS do
    force.technologies[module.CAPACITY_TECH_PREFIX .. level].researched = true
    assert_eq(module.employee_capacity(force), level + 1)
  end
end)

test("launch reservations prevent unresearched duplicate managers", function()
  local platform, _, surface, force = new_world(nil, nil, 0)
  local catapult = new_source(surface, force)
  local asteroid = new_target("asteroid", "huge-metallic-asteroid", nil, surface)

  assert_true(fire_biter_launch(catapult, asteroid, 10))
  assert_eq(table_count(storage.trajectory_compliance.pending_assignments), 1)
  assert_true(catapult.disabled_by_script,
    "base-capacity catapult must pause as soon as its only slot is in flight")

  fire_biter(catapult, asteroid, {tick = 100})
  assert_eq(table_count(storage.trajectory_compliance.pending_assignments), 0)
  assert_eq(table_count(storage.trajectory_compliance.assaults), 1)
  assert_eq(#platform.created_chunks, 0,
    "the reserved manager should attach instead of spawning a drifting rejection")
end)

test("two catapults cannot reserve the same single-capacity asteroid", function()
  local platform, _, surface, force = new_world(nil, nil, 0)
  local first_catapult = new_source(surface, force)
  local second_catapult = new_source(surface, force)
  local asteroid = new_target("asteroid", "huge-metallic-asteroid", nil, surface)

  assert_true(fire_biter_launch(first_catapult, asteroid, 10))
  assert_true(not fire_biter_launch(second_catapult, asteroid, 10),
    "the second catapult must observe the first catapult's launch reservation")
  assert_eq(table_count(storage.trajectory_compliance.pending_assignments), 1)

  local rejected_handled, rejected_outcome = fire_biter(second_catapult, asteroid, {tick = 50})
  assert_true(rejected_handled)
  assert_eq(rejected_outcome, module.OUTCOME_AT_CAPACITY)
  assert_eq(table_count(storage.trajectory_compliance.pending_assignments), 1,
    "a rejected projectile must not steal another catapult's reservation")
  assert_eq(#platform.created_chunks, 1,
    "a native projectile already spawned during the race should return as a chunk")

  fire_biter(first_catapult, asteroid, {tick = 100})
  local assault
  for _, candidate in pairs(storage.trajectory_compliance.assaults) do assault = candidate end
  assert_eq(#assault.workers, 1)
end)

test("staffing research reserves exactly its additional in-flight slots", function()
  local _, _, surface, force = new_world(nil, nil, 1)
  local catapult = new_source(surface, force)
  local asteroid = new_target("asteroid", "huge-metallic-asteroid", nil, surface)

  assert_true(fire_biter_launch(catapult, asteroid, 10))
  assert_true(not catapult.disabled_by_script)
  assert_true(fire_biter_launch(catapult, asteroid, 20))
  assert_true(catapult.disabled_by_script)
  assert_eq(table_count(storage.trajectory_compliance.pending_assignments), 2)

  fire_biter(catapult, asteroid, {tick = 100})
  fire_biter(catapult, asteroid, {tick = 110})
  assert_eq(table_count(storage.trajectory_compliance.pending_assignments), 0)
  local assault
  for _, candidate in pairs(storage.trajectory_compliance.assaults) do assault = candidate end
  assert_eq(#assault.workers, 2)
end)

test("a full asteroid makes its catapult retarget another eligible asteroid", function()
  local _, _, surface, force = new_world(nil, nil, 0)
  local catapult = new_source(surface, force)
  local first = new_target("asteroid", "medium-metallic-asteroid", 400, surface)
  local second = new_target("asteroid", "big-carbonic-asteroid", 2000, surface)

  fire_biter(catapult, first)

  assert_true(not catapult.disabled_by_script)
  assert_eq(catapult.shooting_target, second,
    "a catapult should use another asteroid instead of wasting shots on a full one")

  fire_biter(catapult, second)
  assert_true(catapult.disabled_by_script,
    "catapult should pause when every available asteroid is fully staffed")
end)

test("catapult target selection keeps 56-tile reach inside a narrow firing arc", function()
  local _, _, surface, force = new_world(nil, nil, 0)
  local catapult = new_source(surface, force)
  local staffed = new_target("asteroid", "medium-metallic-asteroid", 400, surface)
  local outside_arc = new_target("asteroid", "medium-carbonic-asteroid", 400, surface)
  local downrange = new_target("asteroid", "medium-oxide-asteroid", 400, surface)
  outside_arc.position = {x = 50, y = 10}
  downrange.position = {x = 55, y = 0}

  assert_eq(module.CATAPULT_RANGE, 56)
  assert_near(module.CATAPULT_TURN_RANGE, 0.05, 1e-9)
  fire_biter(catapult, staffed)
  assert_eq(catapult.shooting_target, downrange,
    "retargeting should skip a closer asteroid outside the narrow firing corridor")
end)

test("array and catapult configuration install strict native priorities", function()
  local _, _, surface, force = new_world()
  local junior = new_source(surface, force, "normal", "trajectory-compliance-array")
  local senior = new_source(surface, force, "normal", "senior-trajectory-compliance-array")
  local executive = new_source(surface, force, "normal", "executive-trajectory-compliance-array")
  local catapult = new_source(surface, force)

  for _, entity in ipairs({junior, senior, executive, catapult}) do
    assert_true(module.configure_array(entity))
    assert_true(entity.ignore_unprioritised_targets)
  end
  assert_eq(#junior.priority_targets, 8)
  assert_eq(#senior.priority_targets, 12)
  assert_eq(#executive.priority_targets, 16)
  assert_eq(#catapult.priority_targets, 16)
end)

test("deviation pushes threats outward without deleting or salvaging them", function()
  local platform, hub, surface, force = new_world()
  local array = new_source(surface, force, "epic", "trajectory-compliance-array")
  local asteroid = new_target("asteroid", "medium-carbonic-asteroid")

  local handled, outcome = fire_deviation(array, asteroid)

  assert_true(handled)
  assert_eq(outcome, module.OUTCOME_DEVIATED)
  assert_true(not asteroid.destroyed)
  assert_eq(table_count(storage.trajectory_compliance.deviations), 1)

  module.on_tick({tick = 1})
  assert_near(asteroid.position.x, 10.02, 1e-9,
    "one pulse should push a medium asteroid slowly away from the hub")
  assert_eq(#platform.created_chunks, 0)
  assert_eq(#hub.inserted, 0)
end)

test("arrays periodically retarget the nearest eligible asteroid", function()
  local _, _, surface, force = new_world()
  local array = new_source(surface, force, "normal", "trajectory-compliance-array")
  local already_deviated = new_target("asteroid", "small-metallic-asteroid", nil, surface)
  local incoming = new_target("asteroid", "medium-carbonic-asteroid", nil, surface)
  already_deviated.position.x = 8
  incoming.position.x = 9

  fire_deviation(array, already_deviated)
  already_deviated.position.x = 11
  module.on_tick({tick = module.ARRAY_RETARGET_INTERVAL})

  assert_eq(array.shooting_target, incoming,
    "an array should leave a sufficiently displaced asteroid for the nearest eligible threat")
  assert_true(not array.disabled_by_script)
end)

test("asteroid mass and overlapping deviation pulses scale sustained movement", function()
  local _, _, surface, force = new_world()
  local array_a = new_source(surface, force, "normal", "executive-trajectory-compliance-array")
  local array_b = new_source(surface, force, "normal", "executive-trajectory-compliance-array")
  local huge = new_target("asteroid", "huge-metallic-asteroid")

  fire_deviation(array_a, huge)
  module.on_tick({tick = 1})
  assert_near(huge.position.x, 10.005, 1e-9,
    "one push should be strongly diluted by huge asteroid mass")

  fire_deviation(array_b, huge)
  module.on_tick({tick = 2})
  assert_near(huge.position.x, 10.015, 1e-9,
    "overlapping arrays should add their outward push")
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
  local catapult = new_source(surface, force, "rare")
  local asteroid = new_target("asteroid", "big-metallic-asteroid")

  local handled, outcome, damage, destroyed = fire_biter(catapult, asteroid)

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

test("attached manager visuals arrive randomly rotated and render above their asteroid", function()
  local _, _, surface, force = new_world()
  local catapult = new_source(surface, force)
  local asteroid = new_target("asteroid", "big-metallic-asteroid", nil, surface)
  local captured
  rendering = {
    draw_animation = function(spec)
      captured = spec
      return {valid = true, destroy = function() end}
    end,
  }

  fire_biter(catapult, asteroid)
  rendering = nil

  assert_true(captured ~= nil, "manager attack animation should be rendered")
  assert_eq(captured.target.entity, asteroid, "manager visual should attach directly to the asteroid")
  assert_eq(captured.render_layer, "186")
  assert_near(captured.animation_speed, 0.24, 1e-9)
  assert_true(math.sqrt(captured.target.offset[1] ^ 2 + captured.target.offset[2] ^ 2) > 0.9,
    "manager attachment should spread across a big asteroid's visible surface")
  local assault
  for _, candidate in pairs(storage.trajectory_compliance.assaults) do assault = candidate end
  local worker = assault.workers[1]
  assert_true(worker.arrival_orientation >= 0 and worker.arrival_orientation < 1)
  assert_near(captured.orientation, worker.arrival_orientation, 1e-9,
    "manager should arrive at its stored random absolute orientation")
end)

test("attached manager visual accumulates the asteroid sprite rotation", function()
  local _, _, surface, force = new_world()
  local catapult = new_source(surface, force)
  local asteroid = new_target("asteroid", "big-metallic-asteroid", nil, surface)
  local visual
  rendering = {
    draw_animation = function(spec)
      visual = {
        valid = true,
        orientation = spec.orientation,
        destroy = function() end,
      }
      return visual
    end,
  }

  fire_biter(catapult, asteroid, {tick = 100})
  local initial_orientation = visual.orientation
  module.on_tick({tick = 104})
  rendering = nil

  local expected = (initial_orientation
    + 4 * module.ASTEROID_ROTATION_SPEEDS.big) % 1
  assert_near(visual.orientation, expected, 1e-9,
    "manager facing should follow the asteroid graphics spin without positional drift")
end)

test("multiple managers receive distinct animated positions and phases", function()
  local _, _, surface, force = new_world()
  local catapult = new_source(surface, force)
  local asteroid = new_target("asteroid", "huge-promethium-asteroid", nil, surface)
  local captured = {}
  rendering = {
    draw_animation = function(spec)
      captured[#captured + 1] = spec
      return {valid = true, destroy = function() end}
    end,
  }

  fire_biter(catapult, asteroid)
  fire_biter(catapult, asteroid)
  fire_biter(catapult, asteroid)
  rendering = nil

  assert_eq(#captured, 3, "every attached manager needs its own animation render")
  for index, spec in ipairs(captured) do
    assert_near(spec.animation_speed, 0.24, 1e-9)
    local offset = spec.target.offset
    assert_true(math.sqrt(offset[1] ^ 2 + offset[2] ^ 2) > 2,
      "huge-asteroid managers should not overlap at its center")
    if index > 1 then
      local previous = captured[index - 1].target.offset
      assert_true(offset[1] ~= previous[1] or offset[2] ~= previous[2],
        "manager positions must occupy different points")
      assert_true(spec.animation_offset ~= captured[index - 1].animation_offset,
        "manager attack loops must start at different phases")
    end
  end
end)

test("a late-cycle impact waits a full second before its first damage", function()
  local _, _, surface, force = new_world()
  local catapult = new_source(surface, force)
  local asteroid = new_target("asteroid", "medium-metallic-asteroid")
  fire_biter(catapult, asteroid, {tick = 59})

  module.on_tick({tick = 60})
  assert_eq(asteroid.health, 400)
  module.on_tick({tick = 120})
  assert_eq(asteroid.health, 275)
end)

test("multiple attached workers stack damage and each becomes a chunk", function()
  local platform, _, surface, force = new_world()
  local catapult = new_source(surface, force, "epic")
  local asteroid = new_target("asteroid", "medium-carbonic-asteroid", 200)

  fire_biter(catapult, asteroid)
  fire_biter(catapult, asteroid)
  module.on_tick({tick = 60})

  assert_true(asteroid.destroyed)
  assert_eq(#platform.created_chunks, 8, "six salvage plus two employees expected")
  assert_returning_chunk(platform.created_chunks[7].name)
  assert_returning_chunk(platform.created_chunks[8].name)
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
    local catapult = new_source(surface, force)
    local asteroid = new_target("asteroid", case.name, 1)
    fire_biter(catapult, asteroid)
    module.on_tick({tick = 60})

    assert_true(asteroid.destroyed)
    assert_eq(#platform.created_chunks, case.count + 1, case.name .. " chunk count mismatch")
    for index = 1, case.count do
      assert_eq(platform.created_chunks[index].name, case.chunk)
      assert_true(platform.created_chunks[index].movement.x < 0, "salvage should drift toward the hub")
    end
    assert_returning_chunk(platform.created_chunks[case.count + 1].name)
  end
end)

test("released manager preserves arrival angle plus accumulated asteroid rotation", function()
  local platform, _, surface, force = new_world()
  local catapult = new_source(surface, force)
  local asteroid = new_target("asteroid", "medium-metallic-asteroid", 1, surface)
  fire_biter(catapult, asteroid)
  local assault
  for _, candidate in pairs(storage.trajectory_compliance.assaults) do assault = candidate end
  local worker = assault.workers[1]
  worker.arrival_orientation = 0.90

  -- A medium asteroid turns 0.0009 of a revolution per tick. Sixty ticks
  -- therefore advance the attached manager from 0.90 to 0.954.
  module.on_tick({tick = 60})

  local returning_chunk = platform.created_chunks[7]
  local expected = (0.90 + 60 * module.ASTEROID_ROTATION_SPEEDS.medium) % 1
  assert_eq(returning_chunk.name, module.returning_chunk_name(expected))
  assert_eq(returning_chunk.name, "returning-orbital-employee-orientation-15",
    "release should preserve the nearest available final biter direction")
end)

test("projectile cause lookup still attaches the fired employee", function()
  local platform, _, surface, force = new_world()
  local catapult = new_source(surface, force, "normal")
  local projectile = {valid = true, name = "orbital-biter-projectile"}
  local asteroid = new_target("asteroid", "small-metallic-asteroid", 1)

  assert_true(fire_biter(catapult, asteroid, {
    source_entity = projectile,
    cause_entity = catapult,
    quality = "legendary",
  }))
  module.on_tick({tick = 60})

  assert_returning_chunk(platform.created_chunks[3].name)
end)

test("external asteroid death releases attached employees alongside native debris", function()
  local platform, _, surface, force = new_world()
  local catapult = new_source(surface, force, "rare")
  local asteroid = new_target("asteroid", "big-oxide-asteroid")
  fire_biter(catapult, asteroid)

  assert_true(module.on_entity_died({entity = asteroid}))
  assert_eq(#platform.created_chunks, 1)
  assert_returning_chunk(platform.created_chunks[1].name)
  assert_eq(table_count(storage.trajectory_compliance.assaults), 0)
end)

test("an invalidated asteroid loses its attached workers in space", function()
  local platform, _, surface, force = new_world()
  local catapult = new_source(surface, force)
  local asteroid = new_target()
  fire_biter(catapult, asteroid)
  asteroid.valid = false

  module.on_tick({tick = 60})
  assert_eq(#platform.created_chunks, 0)
  assert_eq(table_count(storage.trajectory_compliance.assaults), 0)
end)

test("deviators ignore manager-occupied asteroids", function()
  local platform, _, surface, force = new_world()
  local catapult = new_source(surface, force)
  local array = new_source(surface, force, "normal", "executive-trajectory-compliance-array")
  local asteroid = new_target("asteroid", "small-metallic-asteroid")
  fire_biter(catapult, asteroid)

  assert_true(not fire_deviation(array, asteroid))
  assert_eq(#platform.created_chunks, 0)
  assert_eq(table_count(storage.trajectory_compliance.assaults), 1)
  assert_eq(table_count(storage.trajectory_compliance.deviations), 0)
  assert_true(array.disabled_by_script,
    "an array with no manager-free target should pause instead of wasting orders")
  assert_true(asteroid.valid)
end)

test("deviators ignore asteroids reserved by airborne employees", function()
  local _, _, surface, force = new_world(nil, nil, 0)
  local catapult = new_source(surface, force)
  local array = new_source(surface, force, "normal", "executive-trajectory-compliance-array")
  local asteroid = new_target("asteroid", "small-metallic-asteroid", nil, surface)

  assert_true(fire_deviation(array, asteroid))
  assert_eq(table_count(storage.trajectory_compliance.deviations), 1)
  assert_true(fire_biter_launch(catapult, asteroid, 10))

  assert_eq(table_count(storage.trajectory_compliance.deviations), 0,
    "launching an employee should cancel an older deviation push")
  assert_true(not fire_deviation(array, asteroid),
    "an in-flight employee reservation should exclude the asteroid")
  assert_true(array.disabled_by_script)
end)

test("attached employees cannot destroy an asteroid beneath an airborne coworker", function()
  local platform, _, surface, force = new_world(nil, nil, 1)
  local first_catapult = new_source(surface, force)
  local second_catapult = new_source(surface, force)
  local asteroid = new_target("asteroid", "small-metallic-asteroid", 1, surface)

  assert_true(fire_biter_launch(first_catapult, asteroid, 0))
  fire_biter(first_catapult, asteroid, {tick = 10})
  assert_true(fire_biter_launch(second_catapult, asteroid, 20))

  module.on_tick({tick = 60})
  assert_true(asteroid.valid,
    "lethal work must wait while another reserved employee is still traveling")
  assert_eq(table_count(storage.trajectory_compliance.pending_assignments), 1)

  fire_biter(second_catapult, asteroid, {tick = 80})
  module.on_tick({tick = 120})
  assert_true(asteroid.destroyed)
  assert_eq(#platform.created_chunks, 4,
    "small asteroid salvage and both employee chunks should survive the flight race")
end)

test("external asteroid death returns airborne employees as collectible chunks", function()
  local platform, _, surface, force = new_world(nil, nil, 0)
  local catapult = new_source(surface, force)
  local asteroid = new_target("asteroid", "medium-metallic-asteroid", nil, surface)

  assert_true(fire_biter_launch(catapult, asteroid, 10))
  assert_true(module.on_entity_died({entity = asteroid, tick = 20}))
  assert_eq(table_count(storage.trajectory_compliance.pending_assignments), 0)
  assert_eq(#platform.created_chunks, 1)
  assert_returning_chunk(platform.created_chunks[1].name,
    "an asteroid death must not erase an employee already in flight")
end)

test("an expired flight reservation returns its employee instead of deleting it", function()
  local platform, _, surface, force = new_world(nil, nil, 0)
  local catapult = new_source(surface, force)
  local asteroid = new_target("asteroid", "medium-metallic-asteroid", nil, surface)

  assert_true(fire_biter_launch(catapult, asteroid, 10))
  module.on_tick({tick = 10 + module.ASSIGNMENT_RESERVATION_LIFETIME + 1})

  assert_eq(table_count(storage.trajectory_compliance.pending_assignments), 0)
  assert_eq(#platform.created_chunks, 1)
  assert_returning_chunk(platform.created_chunks[1].name)
end)

test("new arrays pause before firing when every asteroid is occupied", function()
  local _, _, surface, force = new_world()
  local catapult = new_source(surface, force)
  local asteroid = new_target("asteroid", "medium-metallic-asteroid", nil, surface)
  fire_biter(catapult, asteroid)

  local array = new_source(surface, force, "normal", "trajectory-compliance-array")
  assert_true(module.configure_array(array))
  assert_true(array.disabled_by_script,
    "array configuration should exclude occupied asteroids before the first shot")
  assert_eq(table_count(storage.trajectory_compliance.deviations), 0)
end)

test("a manager landing cancels active deviation and reroutes its array", function()
  local _, _, surface, force = new_world()
  local array = new_source(surface, force, "normal", "executive-trajectory-compliance-array")
  local catapult = new_source(surface, force)
  local occupied = new_target("asteroid", "medium-metallic-asteroid", nil, surface)
  local available = new_target("asteroid", "big-carbonic-asteroid", nil, surface)

  assert_true(fire_deviation(array, occupied))
  module.on_tick({tick = 1})
  local position_after_push = occupied.position.x
  assert_true(position_after_push > 10)

  fire_biter(catapult, occupied)

  assert_eq(table_count(storage.trajectory_compliance.deviations), 0,
    "landing manager should terminate an existing push immediately")
  assert_eq(array.shooting_target, available,
    "array should choose the nearest manager-free asteroid")
  assert_true(not array.disabled_by_script)
  module.on_tick({tick = 2})
  assert_near(occupied.position.x, position_after_push, 1e-9,
    "occupied asteroid must stop moving once a manager lands")
end)

test("collectible chunks and unrelated effects are ignored", function()
  local _, hub, surface, force = new_world()
  local catapult = new_source(surface, force)
  local chunk = new_target("asteroid-chunk")
  local asteroid = new_target("asteroid")

  assert_true(not fire_biter(catapult, chunk))
  assert_true(not chunk.destroyed)
  assert_true(not fire_biter(catapult, asteroid, {effect_id = "some-other-effect"}))
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
