-------------------------------------------------------------------------------
-- ADMINISTRATORIO FLUID MACHINE ROTATION TESTS
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

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

local native_fluid_rotation = require("prototypes.shared.native_fluid_rotation")
local admin_desk_rotation = require("scripts.admin_desk_rotation")

test("native fluid boxes make a machine rotatable", function()
  local machine = {
    rotatable = false,
    fluid_boxes = {{production_type = "input"}},
  }
  native_fluid_rotation.enable(machine)
  assert_eq(machine.rotatable, true)
end)

test("empty fluid box arrays do not opt a machine into rotation", function()
  local machine = {rotatable = false, fluid_boxes = {}}
  native_fluid_rotation.enable(machine)
  assert_eq(machine.rotatable, false)
end)

test("hidden proxy plumbing does not opt a visible entity into rotation", function()
  local station = {
    rotatable = false,
    fluid_box = {filter = "liquid-coffee"},
  }
  native_fluid_rotation.enable(station)
  assert_eq(station.rotatable, false)
end)

test("capture bureaus stay rotatable at runtime", function()
  local bureau = {name = "capture-bureau", valid = true, rotatable = false}
  admin_desk_rotation.apply(bureau)
  assert_eq(bureau.rotatable, true)
end)

test("regular admin stations retain their fixed orientation", function()
  local station = {name = "admin-station", valid = true, rotatable = true}
  admin_desk_rotation.apply(station)
  assert_eq(station.rotatable, false)
end)

if failed > 0 then
  io.stderr:write(table.concat(errors, "\n") .. "\n")
  os.exit(1)
end

print(string.format("Passed %d fluid machine rotation tests", passed))
