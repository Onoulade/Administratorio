-------------------------------------------------------------------------------
-- ADMINISTRATORIO SPACE AGE RESOURCE TESTS
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

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or "") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function assert_true(value, msg)
  if not value then error(msg or "assertion failed", 2) end
end

mods = {
  ["space-age"] = "2.0.0",
}

data = {
  raw = {
    resource = {},
  },
}

function data:extend(prototypes)
  for _, proto in ipairs(prototypes) do
    data.raw[proto.type] = data.raw[proto.type] or {}
    data.raw[proto.type][proto.name] = proto
  end
end

package.preload["resource-autoplace"] = function()
  return {
    resource_autoplace_settings = function(settings)
      return settings
    end,
  }
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

dofile(mod_root .. "prototypes/resources.lua")

local function exact_surface_planet(resource)
  local conditions = resource and resource.surface_conditions or nil
  if not conditions then return nil end

  local pressure_min, pressure_max, gravity_min, gravity_max
  for _, condition in ipairs(conditions) do
    if condition.property == "pressure" then
      pressure_min = condition.min
      pressure_max = condition.max
    elseif condition.property == "gravity" then
      gravity_min = condition.min
      gravity_max = condition.max
    end
  end

  if pressure_min == 4000 and pressure_max == 4000 and gravity_min == 40 and gravity_max == 40 then
    return "vulcanus"
  end
  if pressure_min == 2000 and pressure_max == 2000 and gravity_min == 20 and gravity_max == 20 then
    return "gleba"
  end
  if pressure_min == 800 and pressure_max == 800 and gravity_min == 8 and gravity_max == 8 then
    return "fulgora"
  end
  return nil
end

test("core Space Age planets each define a local administratorio raw shortcut", function()
  assert_eq(exact_surface_planet(data.raw.resource["verdigris-crust"]), "vulcanus",
    "verdigris-crust should be Vulcanus-local")
  assert_eq(data.raw.resource["verdigris-crust"].minable.result, "verdigris-crust",
    "verdigris-crust should mine its own local mineral")

  assert_eq(exact_surface_planet(data.raw.resource["amber-sap-seep"]), "gleba",
    "amber-sap-seep should be Gleba-local")
  assert_eq(data.raw.resource["amber-sap-seep"].minable.results[1].name, "amber-sap",
    "amber-sap-seep should pump amber sap")

  assert_eq(exact_surface_planet(data.raw.resource["static-charge-deposit"]), "fulgora",
    "static-charge-deposit should be Fulgora-local")
  assert_eq(data.raw.resource["static-charge-deposit"].minable.result, "charged-toner",
    "static-charge-deposit should mine charged toner directly")
end)

test("Fulgora toner deposit has its own autoplace control", function()
  local resource = assert(data.raw.resource["static-charge-deposit"], "static-charge-deposit missing")
  assert_true(resource.autoplace ~= nil, "static-charge-deposit should define autoplace")
  assert_eq(resource.autoplace.autoplace_control_name, "fulgora_static-charge-deposit",
    "static-charge-deposit should use its Fulgora autoplace control")
  assert_true(resource.autoplace.has_starting_area_placement == true,
    "static-charge-deposit should support first-landing bootstrap")
end)

if failed > 0 then
  io.stderr:write(("Failed %d/%d tests\n"):format(failed, passed + failed))
  for _, err in ipairs(errors) do
    io.stderr:write(err, "\n")
  end
  os.exit(1)
end

print(("Passed %d tests"):format(passed))
