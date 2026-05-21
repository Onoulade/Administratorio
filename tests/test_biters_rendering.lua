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

local rendering_factory = dofile(mod_root .. "scripts/biters_rendering.lua")

local function make_chart_tag(surface, spec, counters)
  local fields = {
    valid = true,
    surface = surface,
    position = {x = spec.position.x, y = spec.position.y},
    icon = spec.icon,
    text = spec.text,
  }
  local tag = {}

  function fields.destroy()
    fields.valid = false
    counters.destroyed = counters.destroyed + 1
  end

  return setmetatable(tag, {
    __index = fields,
    __newindex = function(_, key, value)
      if key == "position" then
        error("LuaCustomChartTag::position is read only.", 2)
      end
      fields[key] = value
    end,
  })
end

local function new_context()
  local counters = {created = 0, destroyed = 0}
  local surface = {index = 1, valid = true}
  local force
  force = {
    name = "player",
    add_chart_tag = function(tag_surface, spec)
      counters.created = counters.created + 1
      return make_chart_tag(tag_surface, spec, counters)
    end,
  }

  settings = {
    get_player_settings = function()
      return {}
    end,
  }

  game = {
    connected_players = {
      {valid = true, force = force},
    },
    forces = {
      player = force,
    },
  }

  storage = {}

  local controller = rendering_factory.new({
    protest_map_tag_text = "PROTEST",
    protest_tints = {},
    protest_slogans = {},
  })

  local target = {
    valid = true,
    position = {x = 10, y = 20},
    surface = surface,
    force = force,
  }

  local info = {
    state = "protesting",
    arrived_at_building = true,
    target_building = target,
  }

  return controller, info, target, counters
end

test("ensure_protest_chart_tag updates existing tag without assigning read-only position", function()
  local controller, info, _, counters = new_context()

  controller.ensure_protest_chart_tag(info)
  controller.ensure_protest_chart_tag(info)

  assert_eq(counters.created, 1, "same-position tag should be reused")
  assert_eq(counters.destroyed, 0, "same-position tag should not be recreated")
  assert_eq(info.protest_chart_tags_by_force.player.text, "PROTEST", "tag text should be updated")
end)

test("ensure_protest_chart_tag recreates tag when protest anchor moves", function()
  local controller, info, target, counters = new_context()

  controller.ensure_protest_chart_tag(info)
  target.position = {x = 12, y = 22}
  controller.ensure_protest_chart_tag(info)

  assert_eq(counters.created, 2, "moved tag should be recreated")
  assert_eq(counters.destroyed, 1, "old moved tag should be destroyed")
  assert_eq(info.protest_chart_tags_by_force.player.position.x, 12, "new tag should use moved x")
  assert_eq(info.protest_chart_tags_by_force.player.position.y, 22, "new tag should use moved y")
end)

print(string.format("\n=== BITERS RENDERING TESTS ==="))
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
