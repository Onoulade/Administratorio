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

package.loaded["scripts.constants"] = nil
package.preload["scripts.constants"] = function()
  return {
    BITERPORT_HIDDEN_ROBOPORT_NAME = "biterport-hidden-roboport",
    ZONE_SAFE_TYPES = {},
  }
end

local zones = dofile(mod_root .. "scripts/zones.lua")

test("available slots counts waiting biters even when desk index is stale", function()
  local desk_id = 42
  local force = {
    valid = true,
    technologies = {},
  }

  storage = {
    admin_desks = {
      [desk_id] = {
        valid = true,
        unit_number = desk_id,
        position = {x = 0, y = 0},
        force = force,
      },
    },
    desk_zones = {
      [desk_id] = {
        bounds = {
          left_top = {x = -2.5, y = -2.5},
          right_bottom = {x = 2.5, y = 2.5},
        },
        footprint = {
          left_top = {x = -4.5, y = -4.5},
          right_bottom = {x = 4.5, y = 4.5},
        },
      },
    },
    desk_grid_slots = {
      [desk_id] = {},
    },
    waiting_biters = {},
    desk_biters = {
      [desk_id] = {},
    },
  }

  for unit_number = 1, 4 do
    storage.waiting_biters[unit_number] = {
      desk_id = desk_id,
      state = "waiting",
      entity = {
        valid = true,
      },
    }
  end

  assert_eq(zones.get_available_slots(desk_id), 0, "full desk should not report free slots when desk index is stale")
end)

print(("Zone available slot tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
