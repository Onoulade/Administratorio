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

function rendering.get_object_by_id(id)
  return drawn[id]
end

game = {tick = 0, connected_players = {}}

local field_office = require("scripts.field_office")
local C = require("scripts.constants")

local function reset()
  storage = {}
  drawn = {}
  next_render_id = 0
  game.tick = 0
end

local function new_surface(spawners)
  local surface = {
    last_filter = nil,
    spawners = spawners or {},
  }

  function surface.find_entities_filtered(params)
    surface.last_filter = params
    return surface.spawners
  end

  return surface
end

local function new_player(surface, stack_name)
  return {
    valid = true,
    index = 1,
    surface = surface,
    position = {x = 10, y = 20},
    cursor_stack = stack_name and {valid_for_read = true, name = stack_name} or {valid_for_read = false},
  }
end

test("field office cursor draws nest range overlays", function()
  reset()
  local spawner = {valid = true, position = {x = 40, y = 50}}
  local surface = new_surface({spawner})
  local player = new_player(surface, "field-office")

  field_office.update_placement_preview(player, 100, true)

  assert_eq(#storage.field_office_placement_renders[1], 2, "range and nest marker should be rendered")
  assert_eq(surface.last_filter.radius, C.FIELD_OFFICE_PLACEMENT_PREVIEW_SCAN_RADIUS, "scan radius should use configured preview range")
  assert_eq(surface.last_filter.force, "enemy", "preview should scan enemy spawners")
  assert_eq(drawn[1].params.radius, C.FIELD_OFFICE_SPAWNER_RANGE, "range circle should use field office operating range")
  assert_eq(drawn[1].params.players[1], player, "preview should be local to the player")
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

if failed > 0 then
  io.stderr:write("Field office runtime tests failed:\n")
  for _, err in ipairs(errors) do
    io.stderr:write("  - " .. err .. "\n")
  end
  os.exit(1)
end

print(("Field office runtime tests: %d passed, %d failed"):format(passed, failed))
