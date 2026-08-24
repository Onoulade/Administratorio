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
    error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

local runtime_debug = require("scripts.control_runtime_debug")
local parse_result_index = runtime_debug._test.complaint_locator_result_index
local scan = runtime_debug._test.scan_world_for_complaint_item

local function inventory(counts)
  return {
    valid = true,
    get_item_count = function(name) return counts[name] or 0 end,
  }
end

local function inventory_owner(inv, extra)
  local owner = extra or {}
  owner.get_max_inventory_index = function() return 1 end
  owner.get_inventory = function() return inv end
  return owner
end

test("complaint result button names yield their result index", function()
  assert_eq(parse_result_index("administratorio-complaint-locator-result-4821"), 4821)
end)

test("other complaint locator controls are not mistaken for results", function()
  assert_eq(parse_result_index("administratorio-complaint-locator-refresh"), nil)
  assert_eq(parse_result_index("administratorio-complaint-locator-result-"), nil)
  assert_eq(parse_result_index("administratorio-complaint-locator-result-12-extra"), nil)
end)

test("player inventory is returned before any world entities are scanned", function()
  local surface_scanned = false
  local surface = {index = 1, name = "nauvis", find_entities = function()
    surface_scanned = true
    return {}
  end}
  local player = inventory_owner(inventory{["resolved-noise"] = 2}, {
    name = "Tester",
    surface = surface,
    position = {x = 4, y = 8},
    cursor_stack = {valid_for_read = false},
  })
  game = {players = {player}, surfaces = {surface}}
  storage = {}

  local rows, scanned, total, player_only = scan("resolved-noise", player)
  assert_eq(#rows, 1)
  assert_eq(total, 2)
  assert_eq(scanned, 0)
  assert_eq(player_only, true)
  assert_eq(surface_scanned, false, "world scan should be skipped")
end)

test("world scan finds complaint items inside entity inventories", function()
  local surface = {index = 1, name = "nauvis"}
  local chest = inventory_owner(inventory{["ticket-smog"] = 3}, {
    valid = true,
    type = "container",
    name = "steel-chest",
    surface = surface,
    position = {x = 10, y = 20},
  })
  surface.find_entities = function() return {chest} end
  local player = inventory_owner(inventory{}, {
    name = "Tester",
    surface = surface,
    position = {x = 0, y = 0},
    cursor_stack = {valid_for_read = false},
  })
  game = {players = {player}, surfaces = {surface}}
  storage = {}

  local rows, scanned, total, player_only = scan("ticket-smog", player)
  assert_eq(#rows, 1)
  assert_eq(rows[1].count, 3)
  assert_eq(rows[1].anchor, chest)
  assert_eq(scanned, 1)
  assert_eq(total, 3)
  assert_eq(player_only, false)
end)

print(("Complaint locator tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do print(" - " .. err) end
  os.exit(1)
end
