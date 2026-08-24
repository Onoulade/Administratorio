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

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or "assertion failed") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
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
  admin_desks = {},
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

test("admin reservations only apply on the station's surface", function()
  local desk_id = 303
  local surface_a = make_surface({})
  local surface_b = make_surface({})
  surface_a.index = 1
  surface_b.index = 2
  storage.desk_zones[desk_id] = {bounds = BOUNDS, footprint = BOUNDS, surface_index = 1}
  storage.admin_desks[desk_id] = {valid = true, surface = surface_a}

  assert_true(zones.is_in_admin_zone(surface_a, BOUNDS), "the station should reserve its own surface")
  assert_false(zones.is_in_admin_zone(surface_b, BOUNDS), "the station must not reserve another surface")
  assert_true(zones.zone_overlaps_existing(surface_a, BOUNDS, nil), "station overlap should be detected on its own surface")
  assert_false(zones.zone_overlaps_existing(surface_b, BOUNDS, nil), "station overlap must not leak across surfaces")
end)

test("orphaned station zones do not reserve build space", function()
  local desk_id = 404
  local surface = make_surface({})
  surface.index = 1
  storage.desk_zones = {}
  storage.admin_desks = {}
  storage.desk_zones[desk_id] = {bounds = BOUNDS, footprint = BOUNDS, surface_index = 1}

  assert_false(zones.is_in_admin_zone(surface, BOUNDS), "a missing station must not leave a reserved hole")
  assert_false(zones.zone_overlaps_existing(surface, BOUNDS, nil), "an orphaned zone must not block a replacement station")
end)

test("desk waiting capacity starts at 4 and tops out at 12 with research tiers", function()
  local desk_id = 101
  storage.desk_zones[desk_id] = {bounds = BOUNDS}

  local technologies = {}
  for level = 1, 8 do
    technologies["admin-station-capacity-" .. level] = {researched = false}
  end

  storage.admin_desks[desk_id] = {
    valid = true,
    force = {
      valid = true,
      technologies = technologies,
    },
  }

  assert_eq(zones.get_zone_capacity(desk_id), 4, "capacity should start at 4 before upgrades")

  technologies["admin-station-capacity-1"].researched = true
  technologies["admin-station-capacity-2"].researched = true
  technologies["admin-station-capacity-3"].researched = true
  assert_eq(zones.get_zone_capacity(desk_id), 7, "capacity should grow one slot per researched tier")

  for level = 1, 8 do
    technologies["admin-station-capacity-" .. level].researched = true
  end
  assert_eq(zones.get_zone_capacity(desk_id), 12, "capacity should cap at 12")
end)

test("desk reservations respect tracked occupants even if grid slots drift", function()
  local desk_id = 202
  storage.desk_zones[desk_id] = {bounds = BOUNDS}
  storage.desk_grid_slots = {[desk_id] = {}}
  storage.desk_biters = {[desk_id] = {[11] = true, [12] = true, [13] = true, [14] = true}}
  storage.waiting_biters = {
    [11] = {desk_id = desk_id, state = "waiting", entity = {valid = true}},
    [12] = {desk_id = desk_id, state = "waiting", entity = {valid = true}},
    [13] = {desk_id = desk_id, state = "pathfinding", entity = {valid = true}},
    [14] = {desk_id = desk_id, state = "waiting", entity = {valid = true}},
  }

  local technologies = {}
  for level = 1, 8 do
    technologies["admin-station-capacity-" .. level] = {researched = false}
  end
  storage.admin_desks[desk_id] = {
    valid = true,
    force = {
      valid = true,
      technologies = technologies,
    },
  }

  assert_eq(zones.get_zone_capacity(desk_id), 4, "baseline capacity should be 4")
  assert_eq(zones.get_available_slots(desk_id), 0, "tracked occupants should consume all capacity even if slot grid is empty")
  assert_eq(zones.reserve_slot(desk_id, 99), nil, "reserve_slot should reject over-capacity desk when tracked occupants already fill it")
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
