-------------------------------------------------------------------------------
-- ADMINISTRATORIO TERRITORIAL ARBITRATION TESTS
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

local function assert_nil(value, msg)
  if value ~= nil then
    error((msg or "expected nil") .. " - got " .. tostring(value), 2)
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
    assembling_machine_input = 1,
    furnace_source = 2,
    chest = 3,
  },
  entity_status_diode = {
    red = 1,
    green = 2,
  },
}

storage = {}

local module = dofile(mod_root .. "scripts/territorial_arbitration.lua")

local next_unit_number = 1000

local function chunk_key(chunk)
  return tostring(chunk.x) .. ":" .. tostring(chunk.y)
end

local function sorted_chunk_keys(chunk_lookup)
  local keys = {}
  for key in pairs(chunk_lookup or {}) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

local function keys_from_positions(chunks)
  local keys = {}
  for _, chunk in ipairs(chunks or {}) do
    keys[chunk_key(chunk)] = true
  end
  return keys
end

local function new_inventory(initial_orders)
  local order_count = initial_orders or 0
  return {
    valid = true,
    get_item_count = function(item_name)
      if item_name == module.ORDER_ITEM then
        return order_count
      end
      return 0
    end,
    remove = function(spec)
      if spec.name ~= module.ORDER_ITEM then
        return 0
      end
      local removed = math.min(order_count, spec.count or 0)
      order_count = order_count - removed
      return removed
    end,
    count = function()
      return order_count
    end,
  }
end

local function new_fluidbox(initial_amount)
  local fluidbox = {
    [1] = initial_amount > 0 and {
      name = module.COFFEE_FLUID,
      amount = initial_amount,
      temperature = 25,
    } or nil,
  }

  function fluidbox:amount()
    local entry = self[1]
    if entry and entry.name == module.COFFEE_FLUID then
      return entry.amount
    end
    return 0
  end

  return fluidbox
end

local function new_segmented_unit(name)
  local unit = {
    valid = true,
    prototype = {name = name},
    destroy_calls = 0,
    die_calls = 0,
  }

  function unit.destroy()
    unit.destroy_calls = unit.destroy_calls + 1
    unit.valid = false
  end

  function unit.die()
    unit.die_calls = unit.die_calls + 1
    unit.valid = false
  end

  return unit
end

local function new_surface()
  local surface = {
    valid = true,
    _territory_by_chunk = {},
    _territory_ops = {},
    _entities = {},
    _spilled = {},
  }

  function surface.get_territory_for_chunk(chunk)
    return surface._territory_by_chunk[chunk_key(chunk)]
  end

  function surface.set_territory_for_chunks(chunks, territory)
    surface._territory_ops[#surface._territory_ops + 1] = {
      territory = territory,
      chunks = chunks,
    }

    for _, chunk in ipairs(chunks or {}) do
      local key = chunk_key(chunk)
      local previous = surface._territory_by_chunk[key]
      if previous and previous._chunk_lookup then
        previous._chunk_lookup[key] = nil
      end

      if territory then
        territory._chunk_lookup[key] = {x = chunk.x, y = chunk.y}
        surface._territory_by_chunk[key] = territory
      else
        surface._territory_by_chunk[key] = nil
      end
    end
  end

  function surface.find_entities_filtered(opts)
    if opts and opts.name == module.POST_NAME then
      return surface._entities
    end
    return {}
  end

  function surface.spill_item_stack(spec)
    surface._spilled[#surface._spilled + 1] = spec
  end

  return surface
end

local function new_territory(surface, chunks, demolisher_name)
  local segmented_unit = new_segmented_unit(demolisher_name)
  local territory = {
    valid = true,
    surface = surface,
    _chunk_lookup = {},
    _segmented_units = {segmented_unit},
    patrol_regenerations = 0,
  }

  for _, chunk in ipairs(chunks) do
    territory._chunk_lookup[chunk_key(chunk)] = {x = chunk.x, y = chunk.y}
    surface._territory_by_chunk[chunk_key(chunk)] = territory
  end

  function territory.get_chunks()
    local result = {}
    for _, key in ipairs(sorted_chunk_keys(territory._chunk_lookup)) do
      local chunk = territory._chunk_lookup[key]
      result[#result + 1] = {position = {x = chunk.x, y = chunk.y}}
    end
    return result
  end

  function territory.get_segmented_units()
    return territory._segmented_units
  end

  function territory.regenerate_patrol_path()
    territory.patrol_regenerations = territory.patrol_regenerations + 1
  end

  return territory, segmented_unit
end

local function new_force()
  return {
    valid = true,
    index = 1,
  }
end

local function new_player()
  local player = {
    valid = true,
    inserted = {},
    messages = {},
  }

  function player.insert(stack)
    player.inserted[#player.inserted + 1] = stack
    return stack.count or 0
  end

  function player.print(message)
    player.messages[#player.messages + 1] = message
  end

  return player
end

local function bounding_box_for_chunks(chunks)
  local min_x, min_y = math.huge, math.huge
  local max_x, max_y = -math.huge, -math.huge
  for _, chunk in ipairs(chunks) do
    min_x = math.min(min_x, chunk.x * 32)
    min_y = math.min(min_y, chunk.y * 32)
    max_x = math.max(max_x, (chunk.x + 1) * 32)
    max_y = math.max(max_y, (chunk.y + 1) * 32)
  end
  return {
    left_top = {x = min_x, y = min_y},
    right_bottom = {x = max_x, y = max_y},
  }
end

local function new_post(surface, force, covered_chunks, orders, coffee)
  local inventory = new_inventory(orders)
  local fluidbox = new_fluidbox(coffee)
  local entity = {
    valid = true,
    name = module.POST_NAME,
    force = force,
    surface = surface,
    position = {x = covered_chunks[1].x * 32 + 16, y = covered_chunks[1].y * 32 + 16},
    bounding_box = bounding_box_for_chunks(covered_chunks),
    unit_number = next_unit_number,
    active = true,
    destructible = true,
    energy = 5000,
    custom_status = nil,
    prototype = {
      items_to_place_this = {
        {name = module.POST_NAME},
      },
    },
    fluidbox = fluidbox,
    get_inventory = function(_, _)
      return inventory
    end,
  }
  next_unit_number = next_unit_number + 1

  function entity.destroy()
    entity.valid = false
    entity.destroyed = true
  end

  entity._inventory = inventory
  entity._fluidbox = fluidbox
  surface._entities[#surface._entities + 1] = entity
  return entity
end

local function reset_world()
  storage = {}
  next_unit_number = 1000

  local surface = new_surface()
  local force = new_force()
  local player = new_player()

  game = {
    tick = 0,
    surfaces = {[1] = surface},
    forces = {player = force},
  }

  module.ensure_storage()

  return {
    surface = surface,
    force = force,
    player = player,
  }
end

local function run_tick(tick)
  game.tick = tick
  module.on_tick({tick = tick})
end

local function only_territory_state()
  local territories = storage.territorial_arbitration.territories
  local count = 0
  local last
  for _, territory_state in pairs(territories) do
    count = count + 1
    last = territory_state
  end
  assert_eq(count, 1, "expected exactly one tracked territory")
  return last
end

test("invalid placement is rejected and refunded", function()
  local world = reset_world()
  local post = new_post(world.surface, world.force, {{x = 0, y = 0}}, 0, 0)

  local built = module.on_entity_built(post, world.player)

  assert_true(not built, "invalid placement should fail")
  assert_true(post.destroyed, "invalid placement should destroy the post")
  assert_eq(#world.player.inserted, 1, "invalid placement should refund one post item")
  assert_eq(#world.player.messages, 1, "invalid placement should notify the player")
end)

test("territory shrink regrows only inside the original footprint when upkeep collapses", function()
  local world = reset_world()
  local original_chunks = {
    {x = 0, y = 0},
    {x = 1, y = 0},
    {x = 2, y = 0},
  }
  local territory = new_territory(world.surface, original_chunks, "small-demolisher")
  local post = new_post(world.surface, world.force, {{x = 0, y = 0}}, 2, 100)

  assert_true(module.on_entity_built(post, world.player), "post should bind to the territory")
  run_tick(60)
  run_tick(120)

  assert_nil(world.surface.get_territory_for_chunk({x = 1, y = 0}),
    "second chunk should be removed after two successful upkeep cycles")
  assert_eq(territory.patrol_regenerations, 2, "territory path should refresh as chunks change")

  run_tick(180)

  assert_eq(world.surface.get_territory_for_chunk({x = 1, y = 0}), territory,
    "removed chunks should regrow back to their original territory positions")
  assert_true(world.surface.get_territory_for_chunk({x = 2, y = 0}) == territory,
    "territory should never regrow outside the original footprint")

  local original_key_set = keys_from_positions(original_chunks)
  for _, operation in ipairs(world.surface._territory_ops) do
    for _, chunk in ipairs(operation.chunks or {}) do
      assert_true(original_key_set[chunk_key(chunk)] ~= nil, "territorial updates must stay inside the original footprint")
    end
  end
end)

test("multiple posts stack successful upkeep without extra starvation penalty", function()
  local world = reset_world()
  new_territory(world.surface, {
    {x = 0, y = 0},
    {x = 1, y = 0},
    {x = 2, y = 0},
  }, "small-demolisher")

  local fed_post = new_post(world.surface, world.force, {{x = 0, y = 0}}, 1, 50)
  local starved_post = new_post(world.surface, world.force, {{x = 1, y = 0}}, 0, 0)

  assert_true(module.on_entity_built(fed_post, world.player), "fed post should bind")
  assert_true(module.on_entity_built(starved_post, world.player), "second post should bind")

  run_tick(60)

  local territory_state = only_territory_state()
  assert_eq(territory_state.progress, 1, "one successful post should still advance shared territory progress")
  assert_true(fed_post.custom_status ~= nil and fed_post.custom_status.diode == defines.entity_status_diode.green,
    "fed post should show green progress status")
  assert_true(starved_post.custom_status ~= nil and starved_post.custom_status.diode == defines.entity_status_diode.red,
    "empty post should report starvation")

  run_tick(120)
  assert_eq(territory_state.progress, 0, "shared territory should decay once when no post maintains it")
end)

test("one post touching multiple territories pays upkeep for each independently", function()
  local world = reset_world()
  new_territory(world.surface, {
    {x = 0, y = 0},
    {x = 0, y = 1},
  }, "small-demolisher")
  new_territory(world.surface, {
    {x = 1, y = 0},
    {x = 1, y = 1},
  }, "big-demolisher")

  local post = new_post(world.surface, world.force, {
    {x = 0, y = 0},
    {x = 1, y = 0},
  }, 4, 250)

  assert_true(module.on_entity_built(post, world.player), "multi-territory post should bind")
  run_tick(60)

  local territory_states = {}
  for _, territory_state in pairs(storage.territorial_arbitration.territories) do
    territory_states[#territory_states + 1] = territory_state
  end

  assert_eq(#territory_states, 2, "two territories should remain tracked")
  assert_eq(post._inventory.count(), 0, "multi-territory upkeep should consume the summed order cost")
  assert_eq(post._fluidbox:amount(), 0, "multi-territory upkeep should consume the summed propaganda-fluid cost")
  for _, territory_state in ipairs(territory_states) do
    assert_eq(territory_state.progress, 1, "each touched territory should advance independently")
  end
end)

test("completion destroys the demolisher and permanently clears the territory", function()
  local world = reset_world()
  local territory, segmented_unit = new_territory(world.surface, {
    {x = 0, y = 0},
  }, "small-demolisher")
  local post = new_post(world.surface, world.force, {{x = 0, y = 0}}, 1, 50)

  assert_true(module.on_entity_built(post, world.player), "post should bind")
  run_tick(60)

  assert_eq(segmented_unit.destroy_calls, 1, "completion should destroy the demolisher once")
  assert_eq(segmented_unit.die_calls, 0, "completion should not use combat death paths")
  assert_nil(world.surface.get_territory_for_chunk({x = 0, y = 0}), "completed territory should stay cleared")
  assert_true(next(storage.territorial_arbitration.territories) == nil, "completed territories should be removed from runtime state")
  assert_true(territory.patrol_regenerations >= 1, "completion should refresh the territory patrol path")
end)

test("post is always indestructible regardless of progress", function()
  local world = reset_world()
  new_territory(world.surface, {
    {x = 0, y = 0},
    {x = 1, y = 0},
  }, "small-demolisher")
  local post = new_post(world.surface, world.force, {{x = 0, y = 0}}, 0, 0)

  assert_true(module.on_entity_built(post, world.player), "post should bind")
  assert_true(not post.destructible, "post should be indestructible after placement")

  run_tick(60)
  assert_true(not post.destructible, "post should remain indestructible even with zero progress")

  run_tick(660)
  assert_true(not post.destructible, "post should remain indestructible regardless of time")
end)

print(string.format("\n=== ADMINISTRATORIO TERRITORIAL ARBITRATION TESTS ==="))
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
