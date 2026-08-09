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

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

local function load_protest_targets(setting_value)
  if setting_value == nil then
    settings = nil
  else
    settings = {
      startup = {
        ["administratorio-debug-protest-belts-and-inserters"] = {value = setting_value},
      },
    }
  end

  package.loaded["feature_flags"] = nil
  package.loaded["scripts.protest_targets"] = nil
  return require("scripts.protest_targets")
end

local function target_type_set(setting_value)
  local protest_targets = load_protest_targets(setting_value)
  local set = {}
  for _, target_type in ipairs(protest_targets.get_target_types()) do
    set[target_type] = true
  end
  return set
end

test("default protest targets exclude belts and inserters", function()
  local set = target_type_set(nil)

  assert_true(set["assembling-machine"], "base assembling-machine target type should remain enabled")
  assert_true(not set["transport-belt"], "transport belts should be excluded by default")
  assert_true(not set["underground-belt"], "underground belts should be excluded by default")
  assert_true(not set["splitter"], "splitters should be excluded by default")
  assert_true(not set["inserter"], "inserters should be excluded by default")
end)

test("disabled debug setting keeps belts and inserters out", function()
  local set = target_type_set(false)

  assert_true(not set["transport-belt"], "transport belts should stay excluded when debug setting is false")
  assert_true(not set["underground-belt"], "underground belts should stay excluded when debug setting is false")
  assert_true(not set["splitter"], "splitters should stay excluded when debug setting is false")
  assert_true(not set["inserter"], "inserters should stay excluded when debug setting is false")
end)

test("enabled debug setting adds belts and inserters", function()
  local set = target_type_set(true)

  assert_true(set["transport-belt"], "transport belts should be protest targets when debug setting is true")
  assert_true(set["underground-belt"], "underground belts should be protest targets when debug setting is true")
  assert_true(set["splitter"], "splitters should be protest targets when debug setting is true")
  assert_true(set["inserter"], "inserters should be protest targets when debug setting is true")
end)

test("obstruction attacks include buildings but permanently exclude transport infrastructure", function()
  local protest_targets = load_protest_targets(true)
  local set = {}
  for _, target_type in ipairs(protest_targets.get_obstacle_building_types()) do
    set[target_type] = true
  end

  assert_true(set["assembling-machine"], "assembling machines should be eligible blocking buildings")
  assert_true(set["furnace"], "furnaces should be eligible blocking buildings")
  assert_true(set["wall"], "walls should be eligible blocking buildings")
  assert_true(not set["pipe"], "pipes should never be obstruction attack targets")
  assert_true(not set["pipe-to-ground"], "underground pipes should never be obstruction attack targets")
  assert_true(not set["transport-belt"], "belts should never be obstruction attack targets")
  assert_true(not set["inserter"], "inserters should never be obstruction attack targets")
end)

print(("Protest target tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
