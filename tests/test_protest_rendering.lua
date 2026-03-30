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

local rendering_factory = dofile(mod_root .. "scripts/biters_rendering.lua")

local function new_render_context()
  local next_id = 0
  local objects = {}

  local function new_object(kind, params)
    next_id = next_id + 1
    local object = {
      id = next_id,
      kind = kind,
      params = params,
      valid = true,
    }
    function object.destroy()
      object.valid = false
      objects[object.id] = nil
    end
    objects[object.id] = object
    return object
  end

  rendering = {
    get_object_by_id = function(id)
      return objects[id]
    end,
    draw_text = function(params)
      return new_object("text", params)
    end,
    draw_circle = function(params)
      return new_object("circle", params)
    end,
    draw_light = function(params)
      return new_object("light", params)
    end,
  }

  local controller = rendering_factory.new({
    format_position = function(pos)
      if not pos then return "[nil]" end
      return "[" .. tostring(pos.x) .. "," .. tostring(pos.y) .. "]"
    end,
    log_prefix = "[Administratorio] ",
    protest_map_tag_text = "PROTEST",
    protest_slogans = {
      ["ticket-landscape"] = {"Stop paving our habitat!"},
    },
    protest_stop_text_tint = {r = 1, g = 1, b = 1},
    protest_stop_tint = {r = 1, g = 0, b = 0},
    protest_tints = {
      ["ticket-landscape"] = {r = 0.5, g = 1, b = 0.5},
    },
  })

  local surface = {name = "nauvis"}
  local target = {
    valid = true,
    name = "office-desk",
    position = {x = 10, y = 10},
    surface = surface,
    force = {name = "player"},
    bounding_box = {
      left_top = {x = 9.5, y = 9.5},
      right_bottom = {x = 10.5, y = 10.5},
    },
  }
  local entity = {
    valid = true,
    name = "small-biter",
    unit_number = 7,
    position = {x = 1, y = 1},
    surface = surface,
  }

  return {
    controller = controller,
    entity = entity,
    target = target,
    get_object = function(id) return objects[id] end,
  }
end

test("pre-arrival protesters still render their complaint text", function()
  local ctx = new_render_context()
  local info = {
    state = "protesting",
    entity = ctx.entity,
    target_building = ctx.target,
    complaints = {"ticket-landscape"},
  }

  ctx.controller.ensure_protest_rendering(info)

  assert_true(info.protest_text_render_id ~= nil, "protesting biter should have floating complaint text before arrival")
  assert_true(ctx.get_object(info.protest_text_render_id) ~= nil, "complaint text render object should exist")
  assert_true(info.protest_circle_render_id == nil, "pre-arrival protest should not draw the stop circle on the target")
  assert_true(info.protest_light_render_id == nil, "pre-arrival protest should not draw the stop light on the target")
end)

test("arrived protesters render both text and stop visuals", function()
  local ctx = new_render_context()
  local info = {
    state = "protesting",
    entity = ctx.entity,
    target_building = ctx.target,
    arrived_at_building = true,
    complaints = {"ticket-landscape"},
  }

  ctx.controller.ensure_protest_rendering(info)

  assert_true(info.protest_text_render_id ~= nil, "arrived protest should keep floating complaint text")
  assert_true(info.protest_circle_render_id ~= nil, "arrived protest should draw the stop circle")
  assert_true(info.protest_light_render_id ~= nil, "arrived protest should draw the stop light")
  assert_true(info.protest_icon_render_id ~= nil, "arrived protest should draw the stop icon")
  assert_true(info.protest_stop_text_render_id ~= nil, "arrived protest should draw the stop label")
end)

print(("Protest rendering tests: %d passed, %d failed"):format(passed, failed))

if #errors > 0 then
  print("\nFAILURES:")
  for i, err in ipairs(errors) do
    print(("  %d) %s"):format(i, err))
  end
  os.exit(1)
end
