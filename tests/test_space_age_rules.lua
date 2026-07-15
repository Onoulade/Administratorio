-------------------------------------------------------------------------------
-- ADMINISTRATORIO SPACE AGE COMPATIBILITY TESTS
--
-- Standalone Lua tests for Space Age-specific paperwork exemptions.
-- Run: lua tests/test_space_age_rules.lua
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

local function assert_nil(value, msg)
  if value ~= nil then
    error((msg or "expected nil") .. ", got " .. tostring(value), 2)
  end
end

local function assert_true(value, msg)
  if not value then
    error(msg or "expected true", 2)
  end
end

mods = {
  ["space-age"] = "2.0.0",
}

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

package.loaded["feature_flags"] = nil
package.loaded["prototypes.shared"] = nil
package.loaded["prototypes.shared.non_space_age_rules"] = nil
package.loaded["prototypes.shared.space_age_rules"] = nil

local shared = require("prototypes.shared")

test("native Space Age machine categories are exempt from recurring operating paperwork", function()
  assert_nil(shared.get_operating_form({name = "casting-copper-cable", category = "metallurgy"}), "metallurgy should be exempt")
  assert_nil(shared.get_operating_form({name = "yumako-processing", category = "organic"}), "organic should be exempt")
  assert_nil(shared.get_operating_form({name = "superconductor", category = "electromagnetics"}), "electromagnetics should be exempt")
  assert_nil(shared.get_operating_form({name = "fluoroketone", category = "cryogenics"}), "cryogenics should be exempt")
end)

test("native Space Age machine build recipes stay exempt on hybrid categories", function()
  assert_nil(shared.get_operating_form({name = "foundry", category = "metallurgy-or-assembling"}), "foundry should be exempt")
  assert_nil(shared.get_operating_form({name = "biochamber", category = "organic-or-assembling"}), "biochamber should be exempt")
  assert_nil(shared.get_operating_form({name = "electromagnetic-plant", category = "electronics-or-assembling"}), "electromagnetic-plant should be exempt")
  assert_nil(shared.get_operating_form({name = "cryogenic-plant", category = "cryogenics-or-assembling"}), "cryogenic-plant should be exempt")
end)

test("space age admin and convergence categories stay free of recurring operating paperwork", function()
  assert_nil(shared.get_operating_form({name = "industrial-charter", category = "bureaucracy-certification"}),
    "bureaucracy-certification should be exempt")
  assert_nil(shared.get_operating_form({name = "territorial-arbitration-processing", category = "territorial-arbitration"}),
    "territorial-arbitration should stay exempt")
  assert_nil(shared.get_operating_form({name = "asteroid-processing-docket", category = "orbital-bureaucracy"}),
    "orbital-bureaucracy should stay exempt")
  assert_nil(shared.get_operating_form({name = "cyan-yellow-form-production", category = "printing-multicolor"}),
    "printing-multicolor should stay exempt")
  assert_nil(shared.get_operating_form({name = "faxed-document-reconstruction", category = "fax-reconstruction"}),
    "fax-reconstruction should stay exempt")
end)

test("existing vanilla operating-paperwork mappings remain intact under Space Age", function()
  assert_eq(shared.get_operating_form({name = "oil-processing", category = "oil-processing"}), "chemical-handling-work-order")
  assert_eq(shared.get_operating_form({name = "advanced-oil-processing", category = "oil-processing"}), "chemical-handling-work-order")
  assert_eq(shared.get_operating_form({name = "uranium-processing", category = "centrifuging"}), "radiological-work-order")
end)

test("space age admin buildings stay out of vanilla recipe regulation", function()
  assert_true(shared.is_admin_recipe("chromatic-printer"), "chromatic-printer should be treated as an admin recipe")
  assert_true(shared.is_admin_recipe("laser-printer"), "laser-printer should be treated as an admin recipe")
  assert_true(shared.is_admin_recipe("formation-center"), "formation-center should be treated as an admin recipe")
  assert_true(shared.is_admin_recipe("administrative-space-station"), "administrative-space-station should be treated as an admin recipe")
  assert_true(shared.is_admin_recipe("trajectory-compliance-array"), "trajectory-compliance-array should be treated as an admin recipe")
  assert_true(shared.is_admin_recipe("orbital-employment-cannon"), "orbital-employment-cannon should be treated as an admin recipe")
  assert_true(shared.is_admin_recipe("orbital-deviation-order"), "orbital-deviation-order should be treated as an admin recipe")
  assert_true(shared.is_admin_recipe("orbital-infrastructure-permit"), "orbital-infrastructure-permit should be treated as an admin recipe")
  assert_true(shared.is_admin_recipe("territorial-arbitration-post"), "territorial-arbitration-post should be treated as an admin recipe")
  assert_true(shared.is_admin_recipe("capture-bureau"), "capture-bureau should be treated as an admin recipe")
  assert_true(shared.is_admin_recipe("digital-services-bureau"), "digital-services-bureau should be treated as an admin recipe")
  assert_true(shared.is_admin_recipe("fax-emitter"), "fax-emitter should be treated as an admin recipe")
  assert_true(shared.is_admin_recipe("interplanetary-fax-exchange"), "interplanetary-fax-exchange should be treated as an admin recipe")
end)

test("orbital infrastructure permits participate in shared paperwork systems", function()
  assert_true(shared.PAPERWORK_ITEMS["orbital-infrastructure-permit"] == true,
    "orbital infrastructure permit should be recognized as paperwork")
  assert_eq(shared.FORM_PRODUCTION_RECIPES["orbital-infrastructure-permit"], "orbital-infrastructure-permit",
    "orbital infrastructure permit should map to its issuance recipe")
end)

test("every current space-platform building is registered for its dedicated permit", function()
  for _, recipe_name in ipairs({
    "cargo-bay",
    "asteroid-collector",
    "crusher",
    "thruster",
    "administrative-space-station",
    "trajectory-compliance-array",
    "senior-trajectory-compliance-array",
    "executive-trajectory-compliance-array",
    "orbital-employment-cannon",
  }) do
    assert_true(shared.SPACE_PLATFORM_BUILDING_RECIPES[recipe_name] == true,
      recipe_name .. " should be registered as space-platform infrastructure")
  end
  assert_nil(shared.SPACE_PLATFORM_BUILDING_RECIPES["space-platform-foundation"],
    "foundation tiles should remain bootstrap infrastructure")
  assert_nil(shared.SPACE_PLATFORM_BUILDING_RECIPES["space-platform-starter-pack"],
    "starter packs should remain bootstrap infrastructure")
end)

test("rocket silos finance through derivatives instead of loose taxpayer money", function()
  assert_nil(shared.TAXPAYER_MONEY_COSTS["rocket-silo"])
end)

if failed > 0 then
  io.stderr:write(("Failed %d/%d tests\n"):format(failed, passed + failed))
  for _, err in ipairs(errors) do
    io.stderr:write(err, "\n")
  end
  os.exit(1)
end

print(("Passed %d tests"):format(passed))
