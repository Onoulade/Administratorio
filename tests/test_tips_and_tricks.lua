-------------------------------------------------------------------------------
-- ADMINISTRATORIO TIPS & TRICKS TESTS
--
-- Verifies that key player-facing tips unlock when the related mechanics first
-- become relevant, rather than drifting behind the tech tree.
-- Run: lua tests/test_tips_and_tricks.lua
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

local tips = {}

data = {
  raw = {},
}

function data:extend(prototypes)
  for _, proto in ipairs(prototypes) do
    if proto.type == "tips-and-tricks-item" then
      tips[proto.name] = proto
    end
  end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

dofile(mod_root .. "prototypes/tips-and-tricks.lua")

local function trigger_contains(trigger, expected_type, expected_key, expected_value)
  if not trigger then return false end
  if trigger.type == expected_type and trigger[expected_key] == expected_value then
    return true
  end
  if trigger.type == "or" and trigger.triggers then
    for _, child in ipairs(trigger.triggers) do
      if trigger_contains(child, expected_type, expected_key, expected_value) then
        return true
      end
    end
  end
  return false
end

local function tip(name)
  local value = tips[name]
  assert_true(value ~= nil, "missing tips item " .. name)
  return value
end

test("admin-station mechanics tips unlock when the first desk is built", function()
  for _, name in ipairs({
    "administratorio-biter-complaints",
    "administratorio-frustration",
    "administratorio-complaint-chain",
  }) do
    local item = tip(name)
    assert_true(
      trigger_contains(item.trigger, "build-entity", "entity", "admin-station"),
      name .. " should unlock from building an admin station"
    )
  end
end)

test("eviction and night-shift tips stay wired to the relevant unlocks", function()
  local eviction = tip("administratorio-nest-expropriation")
  assert_true(
    trigger_contains(eviction.trigger, "research", "technology", "nest-expropriation"),
    "nest-expropriation tip should unlock from the nest-expropriation technology"
  )

  local working_hours = tip("administratorio-working-hours")
  for _, entity_name in ipairs({"office-desk", "union-headquarters", "field-office", "biter-station", "biterport"}) do
    assert_true(
      trigger_contains(working_hours.trigger, "build-entity", "entity", entity_name),
      "working-hours tip should unlock from building " .. entity_name
    )
  end
end)

test("rideable biter tip unlocks with its dedicated technology", function()
  local item = tip("administratorio-rideable-biter")
  assert_true(
    trigger_contains(item.trigger, "research", "technology", "rideable-biter"),
    "rideable biter tip should unlock from rideable-biter"
  )
end)

test("biterport tip unlocks with biterport-logistics technology", function()
  local item = tip("administratorio-biterport")
  assert_true(
    trigger_contains(item.trigger, "research", "technology", "biterport-logistics"),
    "biterport tip should unlock from the biterport-logistics technology"
  )
end)

print(("Tips & Tricks tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
