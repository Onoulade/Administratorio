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

local planetary_unlocks = require("scripts.planetary_unlocks")

local function make_force(researched)
  local recipes = {unrelated = {enabled = true}}
  for _, recipe_name in ipairs(planetary_unlocks.AMBER_SAP_RECIPES) do
    recipes[recipe_name] = {enabled = true}
  end
  return {
    valid = true,
    technologies = {
      [planetary_unlocks.AMBER_SAP_TECHNOLOGY] = {researched = researched},
    },
    recipes = recipes,
  }
end

test("configuration sync disables legacy default Gleba recipes before amber sap discovery", function()
  local force = make_force(false)
  planetary_unlocks.sync_force(force)

  for _, recipe_name in ipairs(planetary_unlocks.AMBER_SAP_RECIPES) do
    assert_eq(force.recipes[recipe_name].enabled, false, recipe_name .. " should be disabled")
  end
  assert_eq(force.recipes.unrelated.enabled, true, "unrelated recipe should not change")
end)

test("configuration sync preserves Gleba recipes after amber sap discovery", function()
  local force = make_force(true)
  for _, recipe_name in ipairs(planetary_unlocks.AMBER_SAP_RECIPES) do
    force.recipes[recipe_name].enabled = false
  end

  planetary_unlocks.sync_force(force)
  for _, recipe_name in ipairs(planetary_unlocks.AMBER_SAP_RECIPES) do
    assert_eq(force.recipes[recipe_name].enabled, true, recipe_name .. " should be enabled")
  end
end)

if failed > 0 then
  io.stderr:write(("Planetary unlock tests failed: %d/%d\n"):format(failed, passed + failed))
  for _, err in ipairs(errors) do
    io.stderr:write(err, "\n")
  end
  os.exit(1)
end

print(("Planetary unlock tests: %d passed, 0 failed"):format(passed))
