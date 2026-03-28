-------------------------------------------------------------------------------
-- ADMINISTRATORIO COMPLAINT TIER TESTS
--
-- Verifies that the final biter complaint stays on the purple-science branch
-- while the final spitter complaint stays on the yellow-science branch.
-- Run: lua tests/test_complaint_tiers.lua
-------------------------------------------------------------------------------

defines = {
  direction = {
    north = 0,
    east = 2,
    south = 4,
    west = 6,
  },
}

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

local constants = dofile(mod_root .. "scripts/constants.lua")

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function warning_tech(id)
  for _, warning in ipairs(constants.EVOLUTION_COMPLAINT_WARNINGS) do
    if warning.id == id then
      return warning.technology
    end
  end
  return nil
end

assert_eq(constants.COMPLAINT_TIERS[#constants.COMPLAINT_TIERS], "ticket-unemployment", "biters should peak at unemployment complaints")
assert_eq(constants.SPITTER_COMPLAINT_TIERS[#constants.SPITTER_COMPLAINT_TIERS], "ticket-vagrancy", "spitters should peak at vagrancy complaints")
assert_eq(constants.BITER_MAX_TIER["behemoth-biter"], 4, "behemoth biters should reach the fourth complaint tier")
assert_eq(constants.BITER_MAX_TIER["behemoth-spitter"], 4, "behemoth spitters should reach the fourth complaint tier")
assert_eq(warning_tech("unemployment"), "constitutional-law", "behemoth biter complaints should gate on constitutional-law")
assert_eq(warning_tech("vagrancy"), "vagrancy-ordinances", "behemoth spitter complaints should gate on vagrancy-ordinances")

print("Complaint tier tests: 6 passed, 0 failed")
