local passed, failed, errors = 0, 0, {}

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then passed = passed + 1 else failed = failed + 1; errors[#errors + 1] = name .. ": " .. tostring(err) end
end

local function assert_eq(actual, expected, message)
  if actual ~= expected then error((message or "assertion failed") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end

local root = debug.getinfo(1, "S").source:match("@(.*/)"):gsub("tests/$", "")
package.path = root .. "?.lua;" .. root .. "?/init.lua;" .. package.path

storage = {}
defines = {inventory = {assembling_machine_output = 1}}
prototypes = {entity = {}}

local archive = require("scripts.archive_recombination")

local function new_inventory(stacks, reject_outputs)
  local inventory = stacks or {}
  function inventory.insert(spec)
    if reject_outputs and spec.name ~= archive.ATTEMPT_ITEM and spec.name ~= archive.ENVELOPE_ITEM then return 0 end
    for _, stack in ipairs(inventory) do
      if stack.name == spec.name and stack.quality == (spec.quality or "normal") and stack.count > 0 then
        stack.count = stack.count + spec.count
        return spec.count
      end
    end
    inventory[#inventory + 1] = {
      name = spec.name,
      count = spec.count,
      quality = spec.quality or "normal",
      valid_for_read = true,
    }
    return spec.count
  end
  function inventory.get_item_count(name)
    local count = 0
    for _, stack in ipairs(inventory) do if stack.name == name then count = count + stack.count end end
    return count
  end
  return inventory
end

local function researched_force(researched)
  local technologies = setmetatable({}, {
    __index = function(table_value, key)
      local value = {researched = researched ~= false}
      rawset(table_value, key, value)
      return value
    end,
  })
  return {valid = true, technologies = technologies}
end

local function new_state(inventory, force, left, right)
  return {
    left = left or "carbon-offset-certificate-basic",
    right = right or "work-order",
    attempts = 0,
    successes = 0,
    failures = 0,
    entity = {
      valid = true,
      unit_number = 42,
      force = force or researched_force(true),
      get_inventory = function() return inventory end,
    },
  }
end

local function stack(name, quality)
  return {name = name, count = 1, quality = quality or "normal", valid_for_read = true}
end

test("successful envelopes become exactly one legal third form", function()
  local inventory = new_inventory({stack(archive.ATTEMPT_ITEM), stack(archive.ENVELOPE_ITEM)})
  local state = new_state(inventory)
  archive.process_state(state)
  assert_eq(state.attempts, 1)
  assert_eq(state.successes, 1)
  assert_eq(state.failures, 0)
  assert_eq(inventory.get_item_count(archive.ATTEMPT_ITEM), 0)
  assert_eq(inventory.get_item_count(archive.ENVELOPE_ITEM), 0)
  assert_eq(inventory.get_item_count(state.last_result), 1)
  if state.last_result == state.left or state.last_result == state.right then error("output must differ from both inputs") end
end)

test("successful recombination preserves the native recipe quality", function()
  local inventory = new_inventory({stack(archive.ATTEMPT_ITEM, "rare"), stack(archive.ENVELOPE_ITEM, "rare")})
  local state = new_state(inventory)
  archive.process_state(state)
  assert_eq(state.attempts, 1)
  local result = nil
  for _, candidate in ipairs(inventory) do
    if candidate.name == state.last_result and candidate.count > 0 then result = candidate end
  end
  assert_eq(result and result.quality, "rare", "recombination must not raise or erase quality")
end)

test("failed attempts produce residue and no form", function()
  local inventory = new_inventory({stack(archive.ATTEMPT_ITEM)})
  local state = new_state(inventory)
  archive.process_state(state)
  assert_eq(state.attempts, 1)
  assert_eq(state.successes, 0)
  assert_eq(state.failures, 1)
  assert_eq(inventory.get_item_count(archive.RESIDUE_ITEM), 1)
end)

test("locked output candidates pause without consuming the attempt", function()
  local inventory = new_inventory({stack(archive.ATTEMPT_ITEM), stack(archive.ENVELOPE_ITEM)})
  local state = new_state(inventory, researched_force(false), "blank-cyan-form", "blank-yellow-form")
  archive.process_state(state)
  assert_eq(state.attempts, 0)
  assert_eq(inventory.get_item_count(archive.ATTEMPT_ITEM), 1)
  assert_eq(inventory.get_item_count(archive.ENVELOPE_ITEM), 1)
end)

test("blocked output restores hidden results and retries safely", function()
  local inventory = new_inventory({stack(archive.ATTEMPT_ITEM), stack(archive.ENVELOPE_ITEM)}, true)
  local state = new_state(inventory)
  archive.process_state(state)
  assert_eq(state.attempts, 0)
  assert_eq(inventory.get_item_count(archive.ATTEMPT_ITEM), 1)
  assert_eq(inventory.get_item_count(archive.ENVELOPE_ITEM), 1)
end)

print(("Archive recombination runtime tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do print(err) end
  os.exit(1)
end
