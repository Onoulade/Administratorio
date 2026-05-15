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
    CAPTURE_BUREAU_LURE_RADIUS = 24,
    CAPTURE_BUREAU_SPORE_UPKEEP_TICKS = 10 * 60,
    CAPTURE_BUREAU_SPORE_UPKEEP_AMOUNT = 1,
    CAPTURE_BUREAU_SPORE_VISUAL_TICKS = 60,
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
  },
  distraction = {
    none = 1,
  },
}

local biters = load_biters_module()

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
    if filters and filters.force == "enemy" and filters.type == "unit" then
      return nearby_enemies
    end
    return {}
  end

  function surface.create_entity(spec)
    next_unit_number = next_unit_number + 1
    return new_entity(surface, {
      name = spec.name,
      type = spec.type or "unit",
      unit_number = next_unit_number,
      position = spec.position,
      force = spec.force,
    }, created_entities, last_command)
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
      unit_number = 11,
      position = opts.enemy_position or {x = 1, y = 1},
      force = "enemy",
    }, created_entities, last_command)
  end

  game = {
    tick = 0,
    connected_players = {},
    surfaces = {[1] = surface},
    get_surface = function(_, index)
      return surfaces_by_index[index]
    end,
    forces = {
      neutral = {name = "neutral"},
    },
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

if failed > 0 then
  io.stderr:write(("Failed %d/%d tests\n"):format(failed, passed + failed))
  for _, err in ipairs(errors) do
    io.stderr:write(err, "\n")
  end
  os.exit(1)
end

print(("Passed %d tests"):format(passed))
