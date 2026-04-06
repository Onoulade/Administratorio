-------------------------------------------------------------------------------
-- ADMINISTRATORIO ZONE TESTS
--
-- Verifies admin-station footprint validation ignores transient flying robots
-- so robot-built stations are not immediately rejected.
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

local function assert_false(value, msg)
  if value then error(msg or "assertion failed", 2) end
end

defines = {
  direction = {
    north = 0,
    east = 2,
    south = 4,
    west = 6,
  },
}

storage = {
  desk_zones = {},
}

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

local zones = require("scripts.zones")

local BOUNDS = {
  left_top = {x = -4.5, y = -4.5},
  right_bottom = {x = 4.5, y = 4.5},
}

local function make_surface(entities)
  return {
    find_tiles_filtered = function(_)
      return {}
    end,
    find_entities_filtered = function(_)
      return entities
    end,
  }
end

test("zone_area_is_clear allows construction robots during station build", function()
  local surface = make_surface({
    {valid = true, type = "construction-robot", name = "construction-robot"},
  })
  assert_true(zones.zone_area_is_clear(surface, BOUNDS, nil), "construction robots should not block station placement")
end)

test("zone_area_is_clear still rejects real blocking structures", function()
  local surface = make_surface({
    {valid = true, type = "assembling-machine", name = "assembling-machine-1"},
  })
  assert_false(zones.zone_area_is_clear(surface, BOUNDS, nil), "assembling machines should block station placement")
end)

if failed > 0 then
  io.stderr:write("FAILED " .. failed .. " tests\n")
  for _, err in ipairs(errors) do
    io.stderr:write(" - " .. err .. "\n")
  end
  os.exit(1)
else
  print("OK (" .. passed .. " tests)")
end
