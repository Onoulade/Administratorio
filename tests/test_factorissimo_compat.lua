-------------------------------------------------------------------------------
-- FACTORISSIMO COMPATIBILITY TESTS
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

local hooks = require("compat.hooks")
require("compat.factorissimo.runtime")

test("the module registers the factory wall pumps as traversable", function()
  local collected = hooks.collect("tube_traversable_entities", {["pneumatic-pipe"] = true})

  assert_eq(collected["pneumatic-pipe"], true, "the core entries survive")
  assert_eq(collected["factory-inside-pump-input"], true, "inside pump is traversable")
  assert_eq(collected["factory-inside-pump-output"], true, "inside pump is traversable")
  assert_eq(collected["factory-outside-pump-input"], true, "outside pump is traversable")
  assert_eq(collected["factory-outside-pump-output"], true, "outside pump is traversable")
end)

print(("Factorissimo compatibility tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
