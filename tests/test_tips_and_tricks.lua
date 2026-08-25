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
local categories = {}

data = {
  raw = {},
}

function data:extend(prototypes)
  for _, proto in ipairs(prototypes) do
    if proto.type == "tips-and-tricks-item" then
      tips[proto.name] = proto
    elseif proto.type == "tips-and-tricks-item-category" then
      categories[proto.name] = proto
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
mods = { ["space-age"] = "2.0.0" }

dofile(mod_root .. "prototypes/tips-and-tricks.lua")

local function read_file(path)
  local handle = assert(io.open(path, "r"))
  local content = handle:read("*a")
  handle:close()
  return content
end

local english_tips_locale = read_file(mod_root .. "locale/en/tips.cfg")
local english_items_locale = read_file(mod_root .. "locale/en/items.cfg")
local english_recipes_locale = read_file(mod_root .. "locale/en/recipes.cfg")

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
  for _, entity_name in ipairs({"office-desk", "union-headquarters", "biter-station", "biterport"}) do
    assert_true(
      trigger_contains(working_hours.trigger, "build-entity", "entity", entity_name),
      "working-hours tip should unlock from building " .. entity_name
    )
  end
  assert_true(
    not trigger_contains(working_hours.trigger, "build-entity", "entity", "field-office"),
    "working-hours tip should not treat the always-open field office as night-gated"
  )
end)

test("rideable biter tip unlocks with its dedicated technology", function()
  local item = tip("administratorio-rideable-biter")
  assert_true(
    trigger_contains(item.trigger, "research", "technology", "rideable-biter"),
    "rideable biter tip should unlock from rideable-biter"
  )
end)

test("Space Age job offers document their enrollment odds in tips and Factoriopedia text", function()
  assert_true(
    english_tips_locale:find("At or below 50% frustration — 75% chance", 1, true) ~= nil,
    "enrollment tip should document the 75% low-frustration chance"
  )
  assert_true(
    english_tips_locale:find("Above 50% through 75% — 50% chance", 1, true) ~= nil,
    "enrollment tip should document the 50% medium-frustration chance"
  )
  assert_true(
    english_tips_locale:find("Above 75% through 90% — 25% chance", 1, true) ~= nil and
      english_tips_locale:find("Above 90% — 0% chance", 1, true) ~= nil,
    "enrollment tip should document the upper enrollment bands and cutoff"
  )
  assert_true(
    english_items_locale:find("job-offer=Place this in an Admin Station", 1, true) ~= nil and
      english_items_locale:find("75% chance at or below 50% frustration", 1, true) ~= nil,
    "Job Offer item description should explain the odds"
  )
  assert_true(
    english_recipes_locale:find("job-offer-production=Draft an employment contract", 1, true) ~= nil and
      english_recipes_locale:find("75% chance at or below 50% frustration", 1, true) ~= nil,
    "Job Offer recipe description should explain the odds"
  )
end)

test("biterport tip unlocks with biterport-logistics technology", function()
  local item = tip("administratorio-biterport")
  assert_true(
    trigger_contains(item.trigger, "research", "technology", "biterport-logistics"),
    "biterport tip should unlock from the biterport-logistics technology"
  )
end)

test("previously orphaned core mechanic tips unlock with their mechanics", function()
  local expected = {
    ["administratorio-bullshit-economy"] = "discovery-bullshit",
    ["administratorio-admin-science"] = "administrative-science-research",
    ["administratorio-propaganda-distillery"] = "industrial-propaganda",
    ["administratorio-transit-authorization"] = "railway",
    ["administratorio-pneumatic-transport"] = "pneumatic-form-transport",
  }
  for name, technology in pairs(expected) do
    assert_true(
      trigger_contains(tip(name).trigger, "research", "technology", technology),
      name .. " should unlock from " .. technology
    )
  end
end)

test("every Administratorio tip is text-only", function()
  local count = 0
  for name, item in pairs(tips) do
    count = count + 1
    assert_true(item.simulation == nil, name .. " should not attach an animation")
  end
  assert_true(count >= 69, "expected complete core and Space Age tip coverage")
end)

test("tips are divided into mechanic-focused categories", function()
  local expected_categories = {
    "administratorio-welcome",
    "administratorio-biter-complaints",
    "administratorio-biter-employment",
    "administratorio-workforce-formation-title",
    "administratorio-chromatic-printing",
    "administratorio-vulcanus-certification",
    "administratorio-gleba-conciliation",
    "administratorio-cross-planet-bureaucracy",
    "administratorio-fulgora-digital-services",
    "administratorio-aquilo-tube-network",
  }

  for _, category_name in ipairs(expected_categories) do
    assert_true(categories[category_name] ~= nil, "missing tips category " .. category_name)
    local title = tip(category_name)
    assert_true(title.category == category_name, category_name .. " title should belong to its own category")
    assert_true(title.is_title == true, category_name .. " should be the category title")
    assert_true(title.indent == 0, category_name .. " title should not be indented")
  end

  assert_true(categories.administratorio == nil, "the legacy catch-all category should be removed")
  for name, item in pairs(tips) do
    assert_true(categories[item.category] ~= nil, name .. " references missing category " .. tostring(item.category))
    if not item.is_title then
      assert_true(item.indent == 1, name .. " should be a category child")
    end
  end
end)

test("Space Age planet manifests unlock with their planetary systems", function()
  local expected = {
    ["administratorio-vulcanus-manifest"] = "vulcanus-certification",
    ["administratorio-gleba-manifest"] = "gleba-conciliation",
    ["administratorio-fulgora-archives"] = "archive-recombination",
    ["administratorio-aquilo-manifest"] = "interplanetary-tube-chromatic",
  }
  for name, technology in pairs(expected) do
    assert_true(
      trigger_contains(tip(name).trigger, "research", "technology", technology),
      name .. " should unlock from " .. technology
    )
  end
end)

test("orbital tips unlock with the feature they explain", function()
  assert_true(
    trigger_contains(tip("administratorio-workforce-formation-title").trigger, "research", "technology", "space-platform"),
    "the orbital category should appear with space-platform"
  )
  assert_true(
    trigger_contains(tip("administratorio-workforce-formation").trigger, "research", "technology", "worker-formation"),
    "workforce overview should unlock from worker-formation"
  )
  assert_true(
    trigger_contains(tip("administratorio-orbital-specialists").trigger, "research", "technology", "specialized-formation"),
    "orbital specialists should unlock from specialized-formation"
  )

  local compliance_tips = {
    "administratorio-trajectory-compliance-arrays",
    "administratorio-orbital-employment-catapult",
  }
  for _, name in ipairs(compliance_tips) do
    assert_true(
      trigger_contains(tip(name).trigger, "research", "technology", "orbital-compliance-systems"),
      name .. " should unlock from orbital-compliance-systems"
    )
  end
  assert_true(
    trigger_contains(tip("administratorio-administrative-space-station").trigger,
      "research", "technology", "orbital-employment-infrastructure"),
    "the administrative station should unlock from orbital-employment-infrastructure"
  )

  local permit = tip("administratorio-orbital-infrastructure-permit")
  assert_true(
    trigger_contains(permit.trigger, "research", "technology", "space-platform"),
    "orbital-infrastructure-permit should unlock from space-platform"
  )
end)

test("previously undocumented Space Age mechanics have dedicated tips", function()
  local expected = {
    ["administratorio-space-age-enrollment"] = "worker-formation",
    ["administratorio-offworld-economy"] = "space-platform",
    ["administratorio-management-briefings"] = "management-formation",
    ["administratorio-yellow-paperwork-spoilage"] = "gleba-conciliation",
    ["administratorio-pentapod-bargaining"] = "gleba-conciliation",
    ["administratorio-space-tourism"] = "cyan-yellow-bureaucracy",
    ["administratorio-promethium-administration"] = "promethium-science-pack",
  }
  for name, technology in pairs(expected) do
    assert_true(
      trigger_contains(tip(name).trigger, "research", "technology", technology),
      name .. " should unlock from " .. technology
    )
  end
end)

test("every registered tip has an English name and description", function()
  local locale_helpers = require("tests.locale_helpers")
  local names = locale_helpers.section(mod_root, "en", "tips-and-tricks-item-name")
  local descriptions = locale_helpers.section(mod_root, "en", "tips-and-tricks-item-description")

  for name in pairs(tips) do
    assert_true(names[name], "missing English tip name " .. name)
    assert_true(descriptions[name], "missing English tip description " .. name)
  end
end)

test("advanced orbital tips wait for their first relevant research", function()
  local expected = {
    ["administratorio-senior-trajectory-compliance-array"] = "trajectory-compliance-jurisdiction-2",
    ["administratorio-executive-trajectory-compliance-array"] = "trajectory-compliance-jurisdiction-3",
    ["administratorio-orbital-employment-damage"] = "orbital-employment-damage-1",
    ["administratorio-orbital-employment-capacity"] = "orbital-employment-capacity-1",
    ["administratorio-trajectory-compliance-speed"] = "trajectory-compliance-speed-1",
  }
  for name, technology in pairs(expected) do
    assert_true(
      trigger_contains(tip(name).trigger, "research", "technology", technology),
      name .. " should unlock from " .. technology
    )
  end
end)

print(("Tips & Tricks tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
