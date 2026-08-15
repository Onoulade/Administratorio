-------------------------------------------------------------------------------
-- RELOCATION CANNON CARGO TESTS
--
-- Biter-family cargo only, which is what keeps rockets relevant for everything else.
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
    error((msg or "assertion failed") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function assert_true(value, msg)
  if not value then error(msg or "assertion failed", 2) end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

local relocation_cargo = require("prototypes.shared.relocation_cargo")
local couriers = require("prototypes.shared.manager_couriers")

test("the cannon never carries biter eggs", function()
  assert_true(not relocation_cargo.as_set()["biter-egg"],
    "a cannon that shipped eggs would reintroduce the problem the couriers solve")
end)

test("the cannon carries the courier traffic it exists for", function()
  local cargo = relocation_cargo.as_set()
  for _, courier in ipairs(couriers.COURIERS) do
    assert_true(cargo[courier.item], courier.item .. " should be cannon cargo")
  end
  assert_true(cargo["middle-management-managing-manager"], "spent managers should ride home")
end)

test("the cannon refuses paperwork, which is what keeps rockets relevant", function()
  local cargo = relocation_cargo.as_set()
  for _, name in ipairs({"blank-form", "taxpayer-money", "trichromatic-permit", "paper"}) do
    assert_true(not cargo[name], name .. " is not biter-family cargo")
  end
end)

test("the cannon moves a batch per shot and bills one form per item", function()
  assert_true(relocation_cargo.PAYLOAD_PER_SHOT > 1,
    "the cannon should move a batch, unlike the trunk's per-item flow")
  assert_eq(relocation_cargo.TRANSFER_FORM, "involuntary-transfer-order",
    "the cannon should consume its dedicated form")
end)

print(string.format("\n=== RELOCATION CANNON CARGO TESTS ==="))
print(string.format("Passed: %d  Failed: %d  Total: %d", passed, failed, passed + failed))

if #errors > 0 then
  print("\nFAILURES:")
  for i, err in ipairs(errors) do
    print(string.format("  %d) %s", i, err))
  end
  os.exit(1)
end

print("\nAll tests passed!")
