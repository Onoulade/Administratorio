-------------------------------------------------------------------------------
-- ADMINISTRATORIO TRAJECTORY COMPLIANCE MIGRATION TESTS
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

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end

local function read_file(path)
  local file = assert(io.open(path, "rb"))
  local contents = file:read("*a")
  file:close()
  return contents
end

test("0.5.6 renames orbital deviation orders to MMMMs", function()
  local migration = read_file(mod_root .. "migrations/0.5.6.json")
  assert_true(migration:find('"item"', 1, true) ~= nil, "migration should target item prototypes")
  assert_true(migration:find('"orbital-deviation-order"', 1, true) ~= nil, "old item name missing")
  assert_true(migration:find('"middle-management-managing-manager"', 1, true) ~= nil, "new item name missing")
end)

test("0.5.7 reapplies researched recipe unlocks", function()
  local migration = read_file(mod_root .. "migrations/0.5.7.lua")
  assert_true(migration:find("reset_technology_effects", 1, true) ~= nil,
    "new orbital recipes should unlock for established forces")
end)

test("0.5.7 converts legacy burned-out managers back to active staff", function()
  local migration = read_file(mod_root .. "migrations/0.5.7.json")
  assert_true(migration:find('"burned-out-manager"', 1, true) ~= nil, "legacy item name missing")
  assert_true(migration:find('"middle-management-managing-manager"', 1, true) ~= nil,
    "active manager replacement missing")
end)

test("0.5.8 converts loaded cannon ammunition to VESMs", function()
  local migration = read_file(mod_root .. "migrations/0.5.8.lua")
  assert_true(migration:find('"orbital-employment-cannon"', 1, true) ~= nil,
    "migration should inspect existing deployment cannons")
  assert_true(migration:find('"voluntary-exploration-space-miner"', 1, true) ~= nil,
    "migration should install replacement VESM ammunition")
end)

test("0.6.0 reapplies technology effects after the workforce tree split", function()
  local migration = read_file(mod_root .. "migrations/0.6.0.lua")
  assert_true(migration:find("reset_technology_effects", 1, true) ~= nil,
    "workforce-tree migration should reapply researched recipe unlocks")

  local info = read_file(mod_root .. "info.json")
  assert_true(info:find('"version": "0.6.1"', 1, true) ~= nil, "info.json should advertise current release version")
end)

print(string.format("\n=== ADMINISTRATORIO TRAJECTORY COMPLIANCE MIGRATION TESTS ==="))
print(string.format("Passed: %d  Failed: %d  Total: %d", passed, failed, passed + failed))

if #errors > 0 then
  print("\nFAILURES:")
  for i, err in ipairs(errors) do
    print(string.format("  %d) %s", i, err))
  end
  os.exit(1)
else
  print("\nAll tests passed!")
end
