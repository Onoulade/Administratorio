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
  local chart_tags = {}
  local added_alerts = 0
  local removed_alerts = 0
  local played_sounds = 0

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

  defines = {
    alert_type = {
      custom = 1,
    },
  }

  local force = {
    name = "player",
  }
  function force.add_chart_tag(surface, params)
    local tag = {
      valid = true,
      surface = surface,
      icon = params.icon,
      position = params.position,
      text = params.text,
    }
    function tag.destroy()
      tag.valid = false
      chart_tags[tag] = nil
    end
    chart_tags[tag] = true
    return tag
  end

  local player = {
    valid = true,
    index = 1,
    force = force,
    remove_alert = function()
      removed_alerts = removed_alerts + 1
    end,
    add_custom_alert = function()
      added_alerts = added_alerts + 1
    end,
    play_sound = function()
      played_sounds = played_sounds + 1
    end,
  }

  game = {
    tick = 0,
    connected_players = {player},
    forces = {
      player = force,
    },
  }

  storage = {}

  local controller = rendering_factory.new({
    format_position = function(pos)
      if not pos then return "[nil]" end
      return "[" .. tostring(pos.x) .. "," .. tostring(pos.y) .. "]"
    end,
    log_prefix = "[Administratorio] ",
    protest_alert_sound_cooldown_ticks = 60,
    protest_alert_sound_path = "administratorio-protest-alert",
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
    force = force,
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
    get_chart_tag_count = function()
      local total = 0
      for _ in pairs(chart_tags) do
        total = total + 1
      end
      return total
    end,
    get_added_alerts = function() return added_alerts end,
    get_removed_alerts = function() return removed_alerts end,
    get_played_sounds = function() return played_sounds end,
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

test("pre-arrival protests do not alert players or create map tags", function()
  local ctx = new_render_context()
  local info = {
    state = "protesting",
    entity = ctx.entity,
    target_building = ctx.target,
    complaints = {"ticket-landscape"},
  }

  ctx.controller.notify_players_of_protest(info)

  assert_eq(ctx.get_added_alerts(), 0, "pre-arrival protest should not add a custom alert")
  assert_eq(ctx.get_played_sounds(), 0, "pre-arrival protest should not play the protest siren")
  assert_eq(ctx.get_chart_tag_count(), 0, "pre-arrival protest should not create a map tag")
end)

test("arrived protests alert players and create a map tag", function()
  local ctx = new_render_context()
  local info = {
    state = "protesting",
    entity = ctx.entity,
    target_building = ctx.target,
    arrived_at_building = true,
    complaints = {"ticket-landscape"},
  }

  game.tick = 120
  ctx.controller.notify_players_of_protest(info)

  assert_eq(ctx.get_added_alerts(), 1, "arrived protest should add a custom alert")
  assert_eq(ctx.get_played_sounds(), 1, "arrived protest should play the protest siren once")
  assert_eq(ctx.get_chart_tag_count(), 1, "arrived protest should create a map tag")
end)

print(("Protest rendering tests: %d passed, %d failed"):format(passed, failed))

if #errors > 0 then
  print("\nFAILURES:")
  for i, err in ipairs(errors) do
    print(("  %d) %s"):format(i, err))
  end
  os.exit(1)
end
