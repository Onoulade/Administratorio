-------------------------------------------------------------------------------
-- ADMINISTRATORIO FIELD OFFICE RUNTIME TESTS
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

local function assert_near(actual, expected, message)
  if math.abs(actual - expected) > 0.0001 then
    error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

storage = {}
defines = {
  direction = {north = 0, east = 2, south = 4, west = 6},
  entity_status_diode = {red = 1, yellow = 2, green = 3},
  entity_status = {working = 1, normal = 2, low_power = 3},
  behavior_result = {success = 1, fail = 2},
  command = {go_to_location = 1, stop = 2, wander = 3},
  distraction = {none = 0, by_enemy = 1},
  inventory = {
    assembling_machine_input = 1,
    assembling_machine_output = 2,
  },
}

local drawn = {}
local next_render_id = 0
rendering = {}

function rendering.draw_circle(params)
  next_render_id = next_render_id + 1
  local obj = {
    id = next_render_id,
    params = params,
    destroyed = false,
  }
  function obj.destroy()
    obj.destroyed = true
  end
  drawn[obj.id] = obj
  return obj
end

function rendering.draw_text(params)
  next_render_id = next_render_id + 1
  local obj = {
    id = next_render_id,
    params = params,
    destroyed = false,
  }
  function obj.destroy()
    obj.destroyed = true
  end
  drawn[obj.id] = obj
  return obj
end

function rendering.get_object_by_id(id)
  return drawn[id]
end

game = {
  tick = 0,
  connected_players = {},
  forces = {
    ["administratorio-biters"] = {name = "administratorio-biters"},
    enemy = {name = "enemy"},
    neutral = {name = "neutral"},
    player = {name = "player"},
  },
}

local field_office = require("scripts.field_office")
local C = require("scripts.constants")

local function reset()
  storage = {}
  drawn = {}
  next_render_id = 0
  game.tick = 0
  game.connected_players = {}
end

local function new_surface(spawners)
  spawners = spawners or {}
  for index, spawner in ipairs(spawners) do
    spawner.unit_number = spawner.unit_number or (500 + index)
    spawner.type = spawner.type or "unit-spawner"
    spawner.prototype = spawner.prototype or {max_count_of_owned_units = 7}
  end
  local surface = {
    last_filter = nil,
    path_requests = {},
    next_path_request_id = 0,
    spawners = spawners,
    created_entities = {},
  }

  function surface.find_entities_filtered(params)
    surface.last_filter = params
    return surface.spawners
  end

  function surface.find_non_colliding_position(name, position)
    surface.last_non_colliding_name = name
    return {x = position.x + 1, y = position.y}
  end

  function surface.create_entity(params)
    local entity = {
      valid = true,
      name = params.name,
      position = params.position,
      surface = surface,
      force = params.force,
      prototype = {
        collision_box = {{-0.2, -0.2}, {0.2, 0.2}},
        collision_mask = {},
      },
      unit_number = 1000 + #surface.created_entities,
      commands = {},
      commandable = {},
      ai_settings = {
        destroy_when_commands_fail = true,
        allow_try_return_to_spawner = true,
        join_attacks = true,
      },
    }
    function entity.commandable.set_command(command)
      entity.commands[#entity.commands + 1] = command
    end
    function entity.destroy()
      entity.valid = false
      entity.destroyed = true
    end
    surface.created_entities[#surface.created_entities + 1] = entity
    return entity
  end

  function surface.request_path(params)
    surface.next_path_request_id = surface.next_path_request_id + 1
    surface.path_requests[surface.next_path_request_id] = params
    return surface.next_path_request_id
  end

  return surface
end

local function new_player(surface, stack_name)
  return {
    valid = true,
    index = 1,
    surface = surface,
    force = game.forces.player,
    position = {x = 10, y = 20},
    cursor_stack = stack_name and {valid_for_read = true, name = stack_name} or {valid_for_read = false},
  }
end

local function new_office(surface, unit_number, energy)
  local office = {
    valid = true,
    name = "field-office",
    unit_number = unit_number or 6,
    surface = surface,
    position = {x = 10, y = 20},
    energy = energy == nil and 100 or energy,
    active = nil,
    status = defines.entity_status.working,
    crafting_progress = 0,
    products_finished = 0,
  }
  function office.get_recipe()
    return {ingredients = {}}
  end
  function office.get_inventory(inventory)
    if inventory == defines.inventory.assembling_machine_output then
      return {is_full = function() return false end}
    end
    return {get_item_count = function() return 0 end}
  end
  return office
end

test("field office cursor draws office range and reachable nest markers", function()
  reset()
  local spawner = {valid = true, position = {x = 40, y = 50}}
  local surface = new_surface({spawner})
  local player = new_player(surface, "field-office")

  field_office.update_placement_preview(player, 100, true)

  assert_eq(#storage.field_office_placement_renders[1], 2, "office range and nest marker should be rendered")
  assert_eq(surface.last_filter.radius, C.FIELD_OFFICE_SPAWNER_RANGE, "scan radius should match the field office operating range")
  assert_eq(surface.last_filter.force, "enemy", "preview should scan enemy spawners")
  assert_eq(drawn[1].params.radius, C.FIELD_OFFICE_SPAWNER_RANGE, "range circle should use field office operating range")
  assert_eq(drawn[1].params.target, player.position, "range circle should be centered on the field office cursor")
  assert_eq(drawn[1].params.players[1], player, "preview should be local to the player")
  assert_eq(drawn[2].params.target, spawner.position, "nest marker should be drawn on reachable nests")
end)

test("field office cursor preview clears when item is no longer held", function()
  reset()
  local surface = new_surface({{valid = true, position = {x = 40, y = 50}}})
  local player = new_player(surface, "field-office")

  field_office.update_placement_preview(player, 100, true)
  player.cursor_stack = {valid_for_read = false}
  field_office.update_placement_preview(player, 101, true)

  assert_true(storage.field_office_placement_renders[1] == nil, "preview render ids should be cleared")
  assert_true(drawn[1].destroyed, "range circle should be destroyed")
  assert_true(drawn[2].destroyed, "nest marker should be destroyed")
end)

test("field office stays active when unpowered so native electricity alert can show", function()
  reset()
  local surface = new_surface({})
  local office = new_office(surface, 6, 0)
  field_office.track_entity(office)

  field_office.update(0)

  assert_eq(office.active, true, "unpowered office should not be script-disabled")
  assert_eq(office.custom_status.label[1], "gui.field-office-no-power", "custom status should still explain missing power")
end)

test("field office reports unreachable workers after pathing failure", function()
  reset()
  local spawner = {valid = true, position = {x = 40, y = 50}}
  local surface = new_surface({spawner})
  local office = new_office(surface, 6, 100)
  field_office.track_entity(office)

  field_office.update(0)

  local biter = surface.created_entities[1]
  assert_true(biter ~= nil, "ready office should summon a worker")
  assert_eq(office.custom_status.label[1], "gui.field-office-calling", "office should enter calling status")
  -- The search center is biased toward the worker's spawn position (approaching
  -- from the spawner), then the surface mock adds +1 to x for the found spot.
  local dx = biter.position.x - office.position.x
  local dy = biter.position.y - office.position.y
  local dist = math.sqrt(dx * dx + dy * dy)
  local approach = math.min(dist, C.FIELD_OFFICE_APPROACH_OFFSET)
  local expected_x = office.position.x + (dx / dist) * approach + 1
  local expected_y = office.position.y + (dy / dist) * approach
  assert_near(surface.path_requests[1].goal.x, expected_x, "path check should target a reachable standing position beside the office")
  assert_near(surface.path_requests[1].goal.y, expected_y, "path check should target a reachable standing position beside the office")

  field_office.on_ai_command_completed{unit_number = biter.unit_number, result = defines.behavior_result.fail, tick = 10}

  assert_true(biter.destroyed, "unreachable worker should be cleaned up")
  assert_eq(office.custom_status.label[1], "gui.field-office-no-workers-reachable", "office should report unreachable workers")
  assert_eq(office.active, false, "unreachable office should stay disabled")

  office.energy = 0
  field_office.update(30)

  assert_eq(office.custom_status.label[1], "gui.field-office-no-power", "office should switch to the current blocker")
end)

test("field office reports unreachable workers after path check failure", function()
  reset()
  local spawner = {valid = true, position = {x = 40, y = 50}}
  local surface = new_surface({spawner})
  local office = new_office(surface, 18, 100)
  field_office.track_entity(office)

  field_office.update(0)

  local biter = surface.created_entities[1]
  assert_true(biter ~= nil, "ready office should summon a worker")

  field_office.on_script_path_request_finished{id = 1, path = nil, tick = 1}

  assert_true(biter.destroyed, "path-failed worker should be cleaned up")
  assert_eq(office.custom_status.label[1], "gui.field-office-no-workers-reachable", "path failure should mark office unreachable")
end)

test("field office path check does not target the occupied office center", function()
  reset()
  local spawner = {valid = true, position = {x = 40, y = 50}}
  local surface = new_surface({spawner})
  local office = new_office(surface, 24, 100)
  field_office.track_entity(office)

  field_office.update(0)

  local request = surface.path_requests[1]
  assert_true(request ~= nil, "ready office should request a worker path check")
  local biter = surface.created_entities[1]
  local dx = biter.position.x - office.position.x
  local dy = biter.position.y - office.position.y
  local dist = math.sqrt(dx * dx + dy * dy)
  local approach = math.min(dist, C.FIELD_OFFICE_APPROACH_OFFSET)
  local expected_x = office.position.x + (dx / dist) * approach + 1
  local expected_y = office.position.y + (dy / dist) * approach
  assert_near(request.goal.x, expected_x, "path check should use the worker destination")
  assert_near(request.goal.y, expected_y, "path check should use the worker destination")
  assert_near(surface.created_entities[1].commands[1].destination.x, request.goal.x, "worker command and path check should use the same goal")
  assert_near(surface.created_entities[1].commands[1].destination.y, request.goal.y, "worker command and path check should use the same goal")
end)

test("field offices share their home nest population limit across update shards", function()
  reset()
  local spawner = {valid = true, position = {x = 40, y = 50}}
  local surface = new_surface({spawner})
  local offices = {}
  for i = 1, 10 do
    local office = new_office(surface, 30 + i, 100)
    office.position = {x = i * 4, y = 20}
    offices[#offices + 1] = office
    field_office.track_entity(office)
  end

  for tick = 0, 55, 5 do
    field_office.update(tick)
  end

  assert_eq(#surface.created_entities, 7, "one nest should not lease more workers than its population limit")
  local calling = 0
  local unavailable = 0
  for _, office in ipairs(offices) do
    if office.custom_status.label[1] == "gui.field-office-calling" then
      calling = calling + 1
    elseif office.custom_status.label[1] == "gui.field-office-no-workers-available" then
      unavailable = unavailable + 1
    end
  end
  assert_eq(calling, 7, "available nest slots should each dispatch one worker")
  assert_eq(unavailable, 3, "excess offices should wait for a leased slot to return")
end)

test("field office skips a full nest for a farther nest with available biters on the first attempt", function()
  reset()
  local full_spawner = {valid = true, position = {x = 12, y = 20}, prototype = {max_count_of_owned_units = 0}}
  local available_spawner = {valid = true, position = {x = 100, y = 20}}
  local surface = new_surface({full_spawner, available_spawner})
  local office = new_office(surface, 6, 100)
  office.position = {x = 10, y = 20}
  field_office.track_entity(office)

  field_office.update(0)

  assert_eq(#surface.created_entities, 1, "the nearer full nest should not block spawning from the farther available nest")
  assert_eq(office.custom_status.label[1], "gui.field-office-calling", "office should summon on the first attempt instead of reporting no workers available")
end)

test("released field office worker is not destroyed before reaching its spawner", function()
  reset()
  local spawner = {valid = true, position = {x = 40, y = 50}}
  local surface = new_surface({spawner})
  local office = new_office(surface, 6, 100)
  field_office.track_entity(office)

  field_office.update(0)
  local biter = surface.created_entities[1]
  assert_true(biter ~= nil, "ready office should summon a worker")

  biter.position = {x = office.position.x, y = office.position.y}
  field_office.update(30)
  assert_eq(storage.field_office_state[office.unit_number].phase, "working", "arrived worker should start working")

  office.products_finished = 3
  field_office.update(60)
  assert_true(storage.field_office_releasing[biter.unit_number] ~= nil, "released worker should be tracked while returning")
  assert_eq(biter.destructible, false, "returning worker should be protected from incidental removal")

  biter.position = {x = office.position.x, y = office.position.y}
  local command_count = #biter.commands
  field_office.update(60 + C.FIELD_OFFICE_BITER_DESPAWN_TICKS)
  assert_true(biter.valid, "returning worker should not be destroyed just because the stale timer elapsed")
  assert_true(storage.field_office_releasing[biter.unit_number] ~= nil, "returning worker should remain tracked until arrival")
  assert_true(#biter.commands > command_count, "stale return should reissue the home command")

  biter.position = {x = spawner.position.x, y = spawner.position.y}
  field_office.update(60 + C.FIELD_OFFICE_BITER_DESPAWN_TICKS + 5)
  -- The worker was a fresh spawn (never borrowed from the nest), so it must
  -- be destroyed on return rather than released as a new permanent wild
  -- biter -- otherwise every dispatch cycle would grow the nest's population.
  assert_true(not biter.valid, "worker should be destroyed on return to keep the nest population neutral")
  assert_true(storage.field_office_releasing[biter.unit_number] == nil, "arrived worker should leave the releasing tracker")
end)

test("field office worker with no home spawner left is destroyed immediately on the next check", function()
  reset()
  local spawner = {valid = true, position = {x = 40, y = 50}}
  local surface = new_surface({spawner})
  local office = new_office(surface, 6, 100)
  field_office.track_entity(office)

  field_office.update(0)
  local biter = surface.created_entities[1]
  biter.position = {x = office.position.x, y = office.position.y}
  field_office.update(30)

  office.products_finished = 3
  spawner.valid = false
  field_office.update(60)
  assert_true(storage.field_office_releasing[biter.unit_number] ~= nil, "worker should be tracked while returning even with no destination")

  field_office.update(60 + C.FIELD_OFFICE_BITER_DESPAWN_TICKS)
  assert_true(not biter.valid, "worker with no home spawner left to return to should be destroyed")
  assert_true(storage.field_office_releasing[biter.unit_number] == nil, "worker should leave the releasing tracker")
end)

test("field office worker stays on site during low power", function()
  reset()
  local spawner = {valid = true, position = {x = 40, y = 50}}
  local surface = new_surface({spawner})
  local office = new_office(surface, 6, 100)
  field_office.track_entity(office)

  field_office.update(0)
  local biter = surface.created_entities[1]
  assert_true(biter ~= nil, "ready office should summon a worker")

  biter.position = {x = office.position.x, y = office.position.y}
  field_office.update(30)
  assert_eq(storage.field_office_state[office.unit_number].phase, "working", "arrived worker should start working")

  office.status = defines.entity_status.low_power
  field_office.update(60)

  assert_eq(storage.field_office_state[office.unit_number].phase, "working", "low power should not dismiss the worker")
  assert_true(storage.field_office_releasing[biter.unit_number] == nil, "low power should not send the worker home")
  assert_eq(office.active, true, "field office should remain active so it can keep progressing under brownout")
end)

test("field office summons a replacement worker for an in-progress craft", function()
  reset()
  local spawner = {valid = true, position = {x = 40, y = 50}}
  local surface = new_surface({spawner})
  local office = new_office(surface, 6, 100)
  local input_count = 1
  function office.get_recipe()
    return {ingredients = {{type = "item", name = "ticket-landscape", amount = 1}}}
  end
  function office.get_inventory(inventory)
    if inventory == defines.inventory.assembling_machine_output then
      return {is_full = function() return false end}
    end
    return {get_item_count = function() return input_count end}
  end
  field_office.track_entity(office)

  field_office.update(0)
  local first_biter = surface.created_entities[1]
  first_biter.position = {x = office.position.x, y = office.position.y}
  field_office.update(30)

  -- The next craft starts before the completed shift is observed, consuming
  -- its complaint item from the input inventory.
  input_count = 0
  office.products_finished = 3
  office.crafting_progress = 0.5
  field_office.update(60)
  assert_eq(storage.field_office_state[office.unit_number].phase, "idle", "completed shift should release its worker")

  field_office.update(90)

  assert_true(surface.created_entities[2] ~= nil, "committed craft ingredients should allow a replacement worker to be summoned")
  assert_eq(storage.field_office_state[office.unit_number].phase, "calling", "office should call a worker to finish the in-progress craft")
  assert_eq(office.custom_status.label[1], "gui.field-office-calling", "office should not report the committed complaint as missing")
end)

test("field office reports unreachable workers when caller gets stuck", function()
  reset()
  local spawner = {valid = true, position = {x = 40, y = 50}}
  local surface = new_surface({spawner})
  local office = new_office(surface, 12, 100)
  field_office.track_entity(office)

  field_office.update(0)

  local biter = surface.created_entities[1]
  assert_true(biter ~= nil, "ready office should summon a worker")

  field_office.update(5 * 60)

  assert_true(biter.destroyed, "stuck worker should be cleaned up")
  assert_eq(office.custom_status.label[1], "gui.field-office-no-workers-reachable", "stuck worker should mark office unreachable")
end)

test("field office restores a calling worker if its entity is invalid after load", function()
  reset()
  local spawner = {valid = true, position = {x = 40, y = 50}}
  local surface = new_surface({spawner})
  local office = new_office(surface, 6, 100)
  field_office.track_entity(office)

  field_office.update(0)

  local old_biter = surface.created_entities[1]
  assert_true(old_biter ~= nil, "ready office should summon a worker")
  old_biter.valid = false

  field_office.update(30)

  local state = storage.field_office_state[office.unit_number]
  assert_true(state ~= nil, "field office state should remain tracked")
  assert_eq(state.phase, "calling", "office should keep waiting for the restored worker")
  assert_true(state.biter ~= nil and state.biter.valid, "calling worker should be recreated")
  assert_true(state.biter.unit_number ~= old_biter.unit_number, "restored worker should receive a fresh unit number")
  assert_eq(storage.field_office_worker_to_office[old_biter.unit_number], nil, "old worker mapping should be removed")
  assert_eq(storage.field_office_worker_to_office[state.biter.unit_number], office.unit_number, "new worker should be mapped to the office")
end)

test("field office restores a working worker if its entity is invalid after load", function()
  reset()
  local spawner = {valid = true, position = {x = 40, y = 50}}
  local surface = new_surface({spawner})
  local office = new_office(surface, 6, 100)
  field_office.track_entity(office)

  field_office.update(0)
  local old_biter = surface.created_entities[1]
  old_biter.position = {x = office.position.x, y = office.position.y}
  field_office.update(30)

  local state = storage.field_office_state[office.unit_number]
  assert_eq(state.phase, "working", "arrived worker should put the office to work")
  old_biter.valid = false

  field_office.update(60)

  state = storage.field_office_state[office.unit_number]
  assert_eq(state.phase, "working", "office should keep working after worker restoration")
  assert_true(state.biter ~= nil and state.biter.valid, "working worker should be recreated")
  assert_true(state.biter.unit_number ~= old_biter.unit_number, "restored working worker should receive a fresh unit number")
  assert_eq(office.active, true, "office should remain active with the restored worker")
end)

test("field office certification scales biter range and placement preview radius", function()
  assert_near(field_office.get_spawner_range({quality = {name = "normal"}}), C.FIELD_OFFICE_SPAWNER_RANGE,
    "normal certification should retain the base range")
  assert_near(field_office.get_spawner_range({quality = {name = "legendary"}}), C.FIELD_OFFICE_SPAWNER_RANGE * 1.5,
    "legendary certification should use the infrastructure curve")

  reset()
  local surface = new_surface({})
  local player = new_player(surface, "field-office")
  player.cursor_stack.quality = {name = "legendary"}
  field_office.update_placement_preview(player, 0, true)
  local circle = drawn[1]
  assert_near(circle.params.radius, C.FIELD_OFFICE_SPAWNER_RANGE * 1.5,
    "legendary field-office cursor preview should match the placed office range")
end)

if failed > 0 then
  io.stderr:write("Field office runtime tests failed:\n")
  for _, err in ipairs(errors) do
    io.stderr:write("  - " .. err .. "\n")
  end
  os.exit(1)
end

print(("Field office runtime tests: %d passed, %d failed"):format(passed, failed))
