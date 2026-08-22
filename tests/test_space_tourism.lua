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

local noop = function() end
local zone_reserved = {}

local function reserve_slot(desk_id, unit_number)
  zone_reserved[desk_id] = zone_reserved[desk_id] or {}
  zone_reserved[desk_id][1] = unit_number or true
  return 1
end

local function release_slot(desk_id)
  if zone_reserved[desk_id] then
    zone_reserved[desk_id][1] = nil
  end
end

local function load_biters_module()
  package.loaded["scripts.constants"] = {
    BITER_MAX_TIER = {
      ["small-biter"] = 1,
      ["small-spitter"] = 1,
    },
    IS_SPITTER = {
      ["small-spitter"] = true,
    },
    BITER_PAYOUT = {
      ["small-biter"] = 5,
      ["small-spitter"] = 5,
    },
    PROTEST_THRESHOLD = 600,
    CAPTURE_BUREAU_LURE_RADIUS = 29,
    CAPTURE_BUREAU_SPORE_UPKEEP_TICKS = 60,
    CAPTURE_BUREAU_SPORE_UPKEEP_AMOUNT = 5,
    CAPTURE_BUREAU_SPORE_VISUAL_TICKS = 60,
    HATCHED_PENTAPOD_FORCE_NAME = "administratorio-hatched-pentapods",
    PENTAPOD_MONEY_BAIT_INTERVAL_TICKS = 60,
    PENTAPOD_MONEY_BAIT_SCAN_LIMIT = 24,
    PENTAPOD_MONEY_BAIT_LURE_RADIUS = 24,
    PENTAPOD_MONEY_BAIT_PICKUP_RADIUS = 1.75,
    PENTAPOD_MONEY_BAIT_MIN_MONEY_PER_EGG = 10,
    PENTAPOD_MONEY_BAIT_MAX_MONEY_PER_EGG = 10,
    ENROLLMENT_OFFER_LOW_FRUSTRATION_RATIO = 0.25,
    ENROLLMENT_OFFER_MEDIUM_FRUSTRATION_RATIO = 0.50,
    ENROLLMENT_OFFER_LOW_CHANCE = 0.05,
    ENROLLMENT_OFFER_MEDIUM_CHANCE = 0.01,
    RETURN_WALK_DISTANCE = 200,
    RETURN_DESPAWN_TICKS = 30 * 60,
    DESK_SLOT_COMMAND_RADIUS = 0.5,
    DESK_SLOT_ARRIVAL_DISTANCE = 1.0,
    ZONE_DIRECTIONS = {},
    ZONE_DIR_NAMES = {},
    ZONE_SAFE_TYPES = {},
  }
  package.loaded["scripts.zones"] = {
    ensure_desk_runtime_state = noop,
    get_available_slots = function() return 1 end,
    get_zone_capacity = function() return 4 end,
    reserve_slot = reserve_slot,
    release_slot = release_slot,
    release_slot_by_index = release_slot,
    increment_desk_occupants = noop,
    decrement_desk_occupants = noop,
    get_queue_pos = function(desk)
      return {x = desk.position.x, y = desk.position.y + 2}
    end,
    get_zone_position = function(surface, desk_id, entity_name, unit_number)
      return {x = 0, y = 2}
    end,
  }
  package.loaded["scripts.working_hours"] = {}
  package.loaded["scripts.biters_rendering"] = {
    new = function()
      return {}
    end,
  }
  package.loaded["scripts.biters_protests"] = {
    new = function()
      return {
        reset_protest_targeting = noop,
        refresh_protest_notifications = noop,
        on_protest_target_removed = noop,
        reroute_desk_biters = noop,
        trigger_immediate_protest = noop,
        process_frustration_and_protests = noop,
        process_protest_pacing = noop,
        on_ai_command_completed = noop,
        on_script_path_request_finished = noop,
        on_script_trigger_effect = noop,
        on_biter_died = noop,
      }
    end,
  }

  return dofile(mod_root .. "scripts/biters.lua")
end

defines = {
  inventory = {
    chest = 1,
    assembling_machine_output = 2,
  },
  command = {
    stop = 1,
    go_to_location = 2,
    attack_area = 3,
  },
  distraction = {
    none = 1,
    by_enemy = 2,
  },
}

local biters = load_biters_module()
local pentapods = require("scripts.pentapods")

local function new_inventory(opts)
  opts = opts or {}
  local output_stack = {
    valid_for_read = opts.output_name ~= nil,
    name = opts.output_name or "resolved-landscape",
    count = opts.output_count or 0,
  }
  local added = {}
  local removed = {}

  local inventory = {
    [1] = output_stack,
  }

  function inventory.is_empty()
    return not output_stack.valid_for_read
  end

  function inventory.insert(spec)
    local count = spec.count or 1
    added[spec.name] = (added[spec.name] or 0) + count
    output_stack.valid_for_read = true
    output_stack.name = spec.name
    output_stack.count = (output_stack.count or 0) + count
    return count
  end

  function inventory.can_insert(_spec)
    return opts.output_room ~= false
  end

  function inventory.remove(spec)
    local count = spec.count or 1
    local removed_count = 0
    if output_stack.valid_for_read and output_stack.name == spec.name then
      removed_count = math.min(output_stack.count, count)
      output_stack.count = output_stack.count - removed_count
      if output_stack.count <= 0 then
        output_stack.valid_for_read = false
      end
    end
    removed[spec.name] = (removed[spec.name] or 0) + removed_count
    return removed_count
  end

  inventory._added = added
  inventory._removed = removed
  return inventory
end

local function new_entity(surface, spec, created_entities, last_command_ref)
  local entity = {
    valid = true,
    name = spec.name,
    type = spec.type or "unit",
    unit_number = spec.unit_number,
    position = spec.position or {x = 0, y = 0},
    surface = surface,
    force = {name = spec.force or "enemy"},
    active = false,
  }
  entity.commandable = {
    set_command = function(command)
      last_command_ref.value = command
    end,
  }
  entity.destroy = function()
    entity.valid = false
  end
  created_entities[#created_entities + 1] = entity
  return entity
end

local function new_context(opts)
  opts = opts or {}
  zone_reserved = {}

  local created_entities = {}
  local last_command = {value = nil}
  local next_unit_number = 200
  local nearby_enemies = {}
  local ground_items = {}
  local spilled_items = {}
  local surfaces_by_index = {}

  local surface = {
    index = 1,
    name = opts.surface_name or "nauvis",
  }
  surfaces_by_index[surface.index] = surface

  function surface.find_non_colliding_position(_, position)
    return {x = position.x, y = position.y}
  end

  function surface.find_entities_filtered(filters)
    if filters and filters.name == "item-on-ground" then
      if not filters.position or not filters.radius then
        return ground_items
      end
      local result = {}
      local radius_sq = filters.radius * filters.radius
      for _, item in ipairs(ground_items) do
        if item.valid then
          local dx = item.position.x - filters.position.x
          local dy = item.position.y - filters.position.y
          if dx * dx + dy * dy <= radius_sq then
            result[#result + 1] = item
          end
        end
      end
      return result
    end
    if filters and filters.force == "enemy" and filters.type then
      if not filters.position or not filters.radius then
        return nearby_enemies
      end
      local result = {}
      local radius_sq = filters.radius * filters.radius
      for _, enemy in ipairs(nearby_enemies) do
        local type_matches = filters.type == enemy.type
        if type(filters.type) == "table" then
          type_matches = false
          for _, entity_type in ipairs(filters.type) do
            if entity_type == enemy.type then
              type_matches = true
              break
            end
          end
        end
        if enemy.valid and type_matches then
          local dx = enemy.position.x - filters.position.x
          local dy = enemy.position.y - filters.position.y
          if dx * dx + dy * dy <= radius_sq then
            result[#result + 1] = enemy
          end
        end
      end
      return result
    end
    return {}
  end

  function surface.create_entity(spec)
    if spec.name == "item-on-ground" then
      local entity = {
        valid = true,
        name = "item-on-ground",
        position = spec.position,
        surface = surface,
        stack = {
          valid_for_read = true,
          name = spec.stack.name,
          count = spec.stack.count,
        },
      }
      entity.destroy = function()
        entity.valid = false
      end
      ground_items[#ground_items + 1] = entity
      return entity
    end
    next_unit_number = next_unit_number + 1
    return new_entity(surface, {
      name = spec.name,
      type = spec.type or "unit",
      unit_number = next_unit_number,
      position = spec.position,
      force = spec.force,
    }, created_entities, last_command)
  end

  function surface.spill_item_stack(spec)
    spilled_items[#spilled_items + 1] = spec
  end

  local output_inventory = new_inventory(opts)
  local fluidbox = opts.lure_fluid and {
    {name = opts.lure_fluid, amount = opts.lure_amount or 100},
  } or {}
  local desk = {
    valid = true,
    name = opts.desk_name or "capture-bureau",
    unit_number = 71,
    position = {x = 0, y = 0},
    surface = surface,
    get_recipe = function()
      return opts.recipe_name and {name = opts.recipe_name} or nil
    end,
    get_inventory = function(inventory_id)
      if inventory_id == defines.inventory.assembling_machine_output or inventory_id == defines.inventory.chest then
        return output_inventory
      end
      return nil
    end,
    fluidbox = fluidbox,
  }
  function desk.remove_fluid(spec)
    local removed = 0
    for index, fluid in pairs(fluidbox) do
      if fluid and fluid.name == spec.name and removed < spec.amount then
        local take = math.min(fluid.amount, spec.amount - removed)
        removed = removed + take
        fluid.amount = fluid.amount - take
        if fluid.amount <= 0 then
          fluidbox[index] = nil
        end
      end
    end
    return removed
  end

  if opts.enemy_name then
    nearby_enemies[1] = new_entity(surface, {
      name = opts.enemy_name,
      type = opts.enemy_type,
      unit_number = 11,
      position = opts.enemy_position or {x = 1, y = 1},
      force = "enemy",
    }, created_entities, last_command)
  end

  if opts.money_position then
    surface.create_entity{
      name = "item-on-ground",
      position = opts.money_position,
      stack = {name = "taxpayer-money", count = opts.money_count or 1},
    }
  end

  local function new_force(name)
    local force = {
      name = name,
      cease_fire = {},
    }
    force.set_cease_fire = function(other, value)
      force.cease_fire[other.name] = value
    end
    return force
  end
  local player_force = new_force("player")
  local hatched_force = new_force("administratorio-hatched-pentapods")

  game = {
    tick = 0,
    connected_players = {},
    surfaces = {[1] = surface},
    get_surface = function(_, index)
      return surfaces_by_index[index]
    end,
    forces = {
      neutral = new_force("neutral"),
      player = player_force,
      ["administratorio-hatched-pentapods"] = hatched_force,
    },
    create_force = function(name)
      local force = new_force(name)
      game.forces[name] = force
      return force
    end,
  }

  storage = {
    waiting_biters = {},
    waiting_biter_state_index = {
      waiting = {},
      pathfinding = {},
      protesting = {},
      pacified = {},
      returning_home = {},
    },
    waiting_biter_state_index_built = true,
    desk_biters = {
      [desk.unit_number] = {},
    },
    admin_desks = {
      [desk.unit_number] = desk,
    },
    desk_circuit_dirty = {},
    capture_bureau_lure_upkeep = {},
    achievements = {},
    stats = {
      cases_resolved = 0,
      money_earned = 0,
    },
  }

  return {
    desk = desk,
    inventory = output_inventory,
    nearby_enemies = nearby_enemies,
    created_entities = created_entities,
    ground_items = ground_items,
    spilled_items = spilled_items,
    last_command = function()
      return last_command.value
    end,
  }
end

test("capture bureau tourism mode itemizes nearby spitters", function()
  local ctx = new_context({
    desk_name = "capture-bureau",
    recipe_name = "capture-bureau-tourism",
    lure_fluid = "tourism-lure-spores",
    enemy_name = "small-spitter",
    enemy_position = {x = 0, y = 2},
  })

  biters.process_walk_in_registration(ctx.desk.surface, {ctx.desk})

  assert_eq(ctx.inventory._added["small-spitter-tourism-package"], 1,
    "tourism mode should output an itemized spitter package")
  assert_true(ctx.nearby_enemies[1].valid == false, "captured spitter should be removed from the world")
  assert_eq(storage.stats.cases_resolved, 1, "captured spitter should count as resolved throughput")
end)

test("capture bureau workforce mode converts nearby biters into workers", function()
  local ctx = new_context({
    desk_name = "capture-bureau",
    recipe_name = "capture-bureau-workforce",
    lure_fluid = "workforce-lure-spores",
    enemy_name = "small-biter",
    enemy_position = {x = 0, y = 2},
  })

  biters.process_walk_in_registration(ctx.desk.surface, {ctx.desk})

  assert_eq(ctx.inventory._added["worker-biter"], 1, "workforce mode should output worker-biter")
  assert_true(ctx.nearby_enemies[1].valid == false, "captured biter should be removed from the world")
end)

test("capture bureau without lure spores does not attract enemies", function()
  local ctx = new_context({
    desk_name = "capture-bureau",
    recipe_name = "capture-bureau-workforce",
    enemy_name = "small-biter",
    enemy_position = {x = 0, y = 2},
  })

  biters.process_walk_in_registration(ctx.desk.surface, {ctx.desk})

  assert_true(ctx.inventory._added["worker-biter"] == nil, "bureau should not capture without lure fluid")
  assert_true(ctx.nearby_enemies[1].valid == true, "unlured biter should remain in the world")
end)

test("capture bureau pentapod mode converts gleba wildlife into eggs", function()
  local ctx = new_context({
    desk_name = "capture-bureau",
    recipe_name = "capture-bureau-pentapod-eggs",
    lure_fluid = "oviposition-lure-spores",
    enemy_name = "small-wriggler-pentapod",
    enemy_position = {x = 0, y = 2},
    surface_name = "gleba",
  })

  biters.process_walk_in_registration(ctx.desk.surface, {ctx.desk})

  assert_eq(ctx.inventory._added["pentapod-egg"], 1, "pentapod mode should output pentapod eggs")
  assert_true(ctx.nearby_enemies[1].valid == false, "captured pentapod should be removed from the world")
end)

test("oviposition spores attract every pentapod size and family across the enlarged radius", function()
  local expected_yields = {
    ["small-wriggler-pentapod"] = {eggs = 1, type = "unit"},
    ["medium-wriggler-pentapod"] = {eggs = 2, type = "unit"},
    ["big-wriggler-pentapod"] = {eggs = 4, type = "unit"},
    ["small-strafer-pentapod"] = {eggs = 1, type = "spider-unit"},
    ["medium-strafer-pentapod"] = {eggs = 2, type = "spider-unit"},
    ["big-strafer-pentapod"] = {eggs = 4, type = "spider-unit"},
    ["small-stomper-pentapod"] = {eggs = 1, type = "spider-unit"},
    ["medium-stomper-pentapod"] = {eggs = 2, type = "spider-unit"},
    ["big-stomper-pentapod"] = {eggs = 4, type = "spider-unit"},
    ["small-wriggler-pentapod-premature"] = {eggs = 1, type = "unit"},
    ["medium-wriggler-pentapod-premature"] = {eggs = 2, type = "unit"},
    ["big-wriggler-pentapod-premature"] = {eggs = 4, type = "unit"},
  }

  for entity_name, expected in pairs(expected_yields) do
    local attracted = new_context({
      desk_name = "capture-bureau",
      recipe_name = "capture-bureau-pentapod-eggs",
      lure_fluid = "oviposition-lure-spores",
      enemy_name = entity_name,
      enemy_type = expected.type,
      enemy_position = {x = 28.5, y = 0},
      surface_name = "gleba",
    })

    biters.process_walk_in_registration(attracted.desk.surface, {attracted.desk})

    assert_true(attracted.last_command() ~= nil,
      entity_name .. " should be attracted from within the enlarged spore radius")

    local captured = new_context({
      desk_name = "capture-bureau",
      recipe_name = "capture-bureau-pentapod-eggs",
      lure_fluid = "oviposition-lure-spores",
      enemy_name = entity_name,
      enemy_type = expected.type,
      enemy_position = {x = 0, y = 2},
      surface_name = "gleba",
    })

    biters.process_walk_in_registration(captured.desk.surface, {captured.desk})

    assert_eq(captured.inventory._added["pentapod-egg"], expected.eggs,
      entity_name .. " should yield eggs according to its size")
    assert_true(captured.nearby_enemies[1].valid == false,
      entity_name .. " should be consumed by the Capture Bureau")
  end
end)

test("spoiled tourism packages hatch back into max-frustration spitters", function()
  local ctx = new_context({
    desk_name = "admin-station",
    surface_name = "nauvis",
  })

  local source_entity = {
    valid = true,
    position = {x = 0, y = 0},
    surface = ctx.desk.surface,
  }

  biters.on_script_trigger_effect({
    effect_id = "administratorio-small-spitter-tourism-hatch",
    source_entity = source_entity,
    surface_index = ctx.desk.surface.index,
    source_position = {x = 0, y = 0},
  })

  local tracked = nil
  for _, info in pairs(storage.waiting_biters) do
    tracked = info
    break
  end

  assert_true(tracked ~= nil, "hatched spitter should be routed into the bureaucracy system when desks exist")
  assert_eq(tracked.entity_name, "small-spitter", "hatched entity should be a spitter")
  assert_eq(tracked.frustration, 600, "hatched spitter should start at 100% frustration")
end)

test("spoiled pentapod eggs hatch into hostile attackers instead of bureaucracy clients", function()
  local ctx = new_context({
    desk_name = "admin-station",
    surface_name = "gleba",
    enemy_name = "small-wriggler-pentapod-premature",
    enemy_position = {x = 0, y = 0},
  })

  biters.on_script_trigger_effect({
    effect_id = "administratorio-pentapod-egg-hatch",
    surface_index = ctx.desk.surface.index,
    source_position = {x = 0, y = 0},
  })

  assert_eq(ctx.nearby_enemies[1].force.name, "administratorio-hatched-pentapods",
    "hatched pentapod should move to the hostile hatchling force")
  assert_true(game.forces.player.cease_fire["administratorio-hatched-pentapods"] == false,
    "players should not be at ceasefire with hatched pentapods")
  assert_eq(ctx.last_command().type, defines.command.attack_area,
    "hatched pentapod should receive an attack command")
  assert_true(next(storage.waiting_biters) == nil,
    "hatched pentapod should not be redirected into the admin desk queue")
end)

test("dropped taxpayer money lures pentapods and can buy eggs", function()
  local ctx = new_context({
    desk_name = "admin-station",
    surface_name = "gleba",
    enemy_name = "small-wriggler-pentapod",
    enemy_position = {x = 5, y = 0},
    money_position = {x = 0, y = 0},
    money_count = 25,
  })

  pentapods.process_money_baits(60)

  assert_eq(ctx.last_command().type, defines.command.go_to_location,
    "pentapod should be lured toward dropped taxpayer money")
  assert_eq(ctx.last_command().destination.x, 0, "pentapod should path to money x")

  ctx.nearby_enemies[1].position = {x = 0.5, y = 0}
  pentapods.process_money_baits(120)

  assert_true(ctx.ground_items[1].valid == false, "pentapod should consume the whole taxpayer money stack")
  assert_eq(ctx.ground_items[2].stack.name, "pentapod-egg", "pentapod should sometimes drop an egg")
  assert_eq(ctx.ground_items[2].stack.count, 2, "egg payout should scale around one egg per 10-20 money")
  assert_eq(ctx.ground_items[2].position.x, 0, "eggs should drop where the money was")
  assert_eq(ctx.ground_items[2].position.y, 0, "eggs should drop where the money was")
  assert_true(next(storage.waiting_biters) == nil,
    "money-baited pentapod should not enter the admin desk queue")
end)

test("dropped taxpayer money always pays at least one egg at the minimum threshold", function()
  local ctx = new_context({
    desk_name = "admin-station",
    surface_name = "gleba",
    enemy_name = "small-wriggler-pentapod",
    enemy_position = {x = 0.5, y = 0},
    money_position = {x = 0, y = 0},
    money_count = 10,
  })

  pentapods.process_money_baits(60)

  assert_true(ctx.ground_items[1].valid == false, "pentapod should consume the whole taxpayer money stack")
  assert_eq(ctx.ground_items[2].stack.name, "pentapod-egg", "minimum money threshold should still drop an egg")
  assert_eq(ctx.ground_items[2].stack.count, 1, "10 money should buy one bootstrap egg")
end)

test("nearby split taxpayer money piles combine into one pentapod egg payment", function()
  local ctx = new_context({
    desk_name = "admin-station",
    surface_name = "gleba",
    enemy_name = "small-wriggler-pentapod",
    enemy_position = {x = 0.5, y = 0},
    money_position = {x = 0, y = 0},
    money_count = 5,
  })
  ctx.desk.surface.create_entity{
    name = "item-on-ground",
    position = {x = 0.3, y = 0},
    stack = {name = "taxpayer-money", count = 5},
  }

  pentapods.process_money_baits(60)

  assert_true(ctx.ground_items[1].valid == false, "first money pile should be consumed")
  assert_true(ctx.ground_items[2].valid == false, "nearby money pile should be consumed with it")
  assert_eq(ctx.ground_items[3].stack.name, "pentapod-egg", "combined nearby money should produce an egg")
  assert_eq(ctx.ground_items[3].stack.count, 1, "combined 10 money should buy one egg")
  assert_eq(ctx.ground_items[3].position.x, 0, "eggs should drop at the bait position")
end)

test("larger pentapods multiply loose-money egg payouts", function()
  local medium = new_context({
    desk_name = "admin-station",
    surface_name = "gleba",
    enemy_name = "medium-wriggler-pentapod",
    enemy_position = {x = 0.5, y = 0},
    money_position = {x = 0, y = 0},
    money_count = 10,
  })

  pentapods.process_money_baits(60)

  assert_eq(medium.ground_items[2].stack.name, "pentapod-egg", "medium pentapod should drop eggs")
  assert_eq(medium.ground_items[2].stack.count, 2, "medium pentapod should double the small payout")

  local big = new_context({
    desk_name = "admin-station",
    surface_name = "gleba",
    enemy_name = "big-wriggler-pentapod",
    enemy_position = {x = 0.5, y = 0},
    money_position = {x = 0, y = 0},
    money_count = 10,
  })

  pentapods.process_money_baits(60)

  assert_eq(big.ground_items[2].stack.name, "pentapod-egg", "big pentapod should drop eggs")
  assert_eq(big.ground_items[2].stack.count, 4, "big pentapod should quadruple the small payout")
end)

if failed > 0 then
  io.stderr:write(("Failed %d/%d tests\n"):format(failed, passed + failed))
  for _, err in ipairs(errors) do
    io.stderr:write(err, "\n")
  end
  os.exit(1)
end

print(("Passed %d tests"):format(passed))
