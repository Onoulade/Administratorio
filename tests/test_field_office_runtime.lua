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
  entity_status = {working = 1, normal = 2},
  behavior_result = {success = 1, fail = 2},
  command = {go_to_location = 1, stop = 2},
  distraction = {none = 0},
  inventory = {
    assembling_machine_input = 1,
    assembling_machine_output = 2,
  },
}

package.loaded["scripts.working_hours"] = nil
package.preload["scripts.working_hours"] = function()
  return {
    is_enabled = function() return false end,
    is_night = function() return false end,
    entity_has_overtime_exemption = function() return false end,
  }
end

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
  local surface = {
    last_filter = nil,
    path_requests = {},
    next_path_request_id = 0,
    spawners = spawners or {},
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
  assert_near(surface.path_requests[1].goal.x, office.position.x + 1, "path check should target a reachable standing position beside the office")
  assert_near(surface.path_requests[1].goal.y, office.position.y, "path check should target a reachable standing position beside the office")

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
  assert_near(request.goal.x, office.position.x + 1, "path check should use the worker destination")
  assert_near(request.goal.y, office.position.y, "path check should use the worker destination")
  assert_near(surface.created_entities[1].commands[1].destination.x, request.goal.x, "worker command and path check should use the same goal")
  assert_near(surface.created_entities[1].commands[1].destination.y, request.goal.y, "worker command and path check should use the same goal")
end)

test("multiple ready field offices each summon a worker across update shards", function()
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

  assert_eq(#surface.created_entities, 10, "each ready office should get its own worker")
  for _, office in ipairs(offices) do
    assert_eq(office.custom_status.label[1], "gui.field-office-calling", "each ready office should be calling")
  end
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

if failed > 0 then
  io.stderr:write("Field office runtime tests failed:\n")
  for _, err in ipairs(errors) do
    io.stderr:write("  - " .. err .. "\n")
  end
  os.exit(1)
end

print(("Field office runtime tests: %d passed, %d failed"):format(passed, failed))
