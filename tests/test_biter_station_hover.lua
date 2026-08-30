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
    error((message or "assertion failed")
      .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

package.loaded["scripts.biter_station_hover"] = nil
package.loaded["scripts.constants"] = nil
package.loaded["scripts.working_hours"] = nil
package.preload["scripts.constants"] = function()
  return {
    BITER_STATION_RANGE = 30,
    BITER_STATION_MANAGED_BUILDINGS = {"corporate-breakroom", "propaganda-distillery"},
  }
end
package.preload["scripts.working_hours"] = function()
  return {is_enabled = function() return false end}
end

local next_render_id = 0
local circle_specs = {}
local function render(spec)
  next_render_id = next_render_id + 1
  return {id = next_render_id, spec = spec}
end

rendering = {
  draw_circle = function(spec)
    circle_specs[#circle_specs + 1] = spec
    return render(spec)
  end,
  draw_rectangle = render,
  draw_text = render,
  draw_sprite = render,
  get_object_by_id = function() return nil end,
}

storage = {biter_station_hover_renders = {}}
local hover = require("scripts.biter_station_hover")

local function make_surface(results)
  local surface = {last_filter = nil}
  function surface.find_entities_filtered(filter)
    surface.last_filter = filter
    return results
  end
  return surface
end

test("station hover uses the same circular radius as dispatch", function()
  circle_specs = {}
  local force = {name = "player"}
  local building = {
    valid = true,
    bounding_box = {left_top = {x = 9, y = 9}, right_bottom = {x = 11, y = 11}},
  }
  local surface = make_surface({building})
  local station = {valid = true, position = {x = 4, y = 5}, surface = surface, force = force}

  hover.show_station_zone({index = 1}, station)

  assert_eq(surface.last_filter.position, station.position, "coverage query should be centered on the station")
  assert_eq(surface.last_filter.radius, 30, "coverage query should use the dispatch radius")
  assert_eq(surface.last_filter.area, nil, "coverage query should not include square corner false positives")
  assert_eq(circle_specs[1].target, station.position, "coverage render should be centered on the station")
  assert_eq(circle_specs[1].radius, 30, "coverage render should show the dispatch radius")
end)

test("building hover finds stations by circular distance", function()
  circle_specs = {}
  local force = {name = "player"}
  local surface = make_surface({})
  local station = {
    valid = true,
    position = {x = 12, y = 13},
    surface = surface,
    force = force,
    selection_box = {left_top = {x = 11, y = 12}, right_bottom = {x = 13, y = 14}},
  }
  surface.find_entities_filtered = function(filter)
    surface.last_filter = filter
    return {station}
  end
  local building = {valid = true, position = {x = 20, y = 21}, surface = surface, force = force}

  hover.show_building_hover({index = 2}, building)

  assert_eq(surface.last_filter.position, building.position, "station query should be centered on the building")
  assert_eq(surface.last_filter.radius, 30, "station query should use the dispatch radius")
  assert_eq(surface.last_filter.area, nil, "station query should not include square corner false positives")
  assert_eq(circle_specs[1].target, station.position, "station coverage should render as a circle")
  assert_eq(circle_specs[1].radius, 30, "rendered station coverage should match dispatch")
end)

print(("Biter station hover tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
