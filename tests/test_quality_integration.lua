-------------------------------------------------------------------------------
-- ADMINISTRATIVE CERTIFICATION DATA + RUNTIME TESTS
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

local function assert_true(value, message)
  if not value then error(message or "assertion failed", 2) end
end

local function assert_near(actual, expected, message)
  if math.abs(actual - expected) > 0.0001 then
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

local integration = require("prototypes.final_fixes.quality_integration")
local quality = require("scripts.quality")

local function contains(values, expected)
  for _, value in ipairs(values or {}) do
    if value == expected then return true end
  end
  return false
end

local function has_ingredient(recipe, name, amount)
  for _, ingredient in ipairs(recipe.ingredients or {}) do
    if ingredient.name == name and ingredient.amount == amount then return true end
  end
  return false
end

local function new_data()
  local raw = {
    recipe = {
      ["quality-module"] = {},
      ["quality-module-2"] = {},
      ["quality-module-3"] = {},
      ["pneumatic-pipe"] = {},
      ["pneumatic-pipe-to-ground"] = {},
      ["tube-intake"] = {},
      ["tube-outtake"] = {},
    },
    technology = {},
    ["assembling-machine"] = {
      ["resolution-office"] = {allowed_effects = {"speed"}, energy_usage_quality_multiplier = {legendary = 99}},
      ["office-desk"] = {allowed_effects = {"speed"}},
      ["mechanical-printer"] = {allowed_effects = {"speed"}},
      ["printer-t1"] = {allowed_effects = {"speed"}},
      ["printer-t2"] = {allowed_effects = {"speed"}},
      ["archive-recombination-bureau"] = {},
      ["territorial-arbitration-post"] = {},
      ["administrative-space-station"] = {},
    },
    furnace = {},
  }
  for _, name in ipairs({"quality-module", "quality-module-2", "quality-module-3", "epic-quality", "legendary-quality"}) do
    raw.technology[name] = {
      prerequisites = {"native-prerequisite"},
      unit = {ingredients = {{"automation-science-pack", 1}}},
    }
  end
  return {raw = raw}
end

test("certification recipes use the exact costly administrative chain", function()
  local data_api = new_data()
  integration.apply(data_api)
  local recipes = data_api.raw.recipe

  assert_eq(recipes["quality-module"].category, "bureaucracy-modules")
  assert_eq(#recipes["quality-module"].ingredients, 4)
  assert_true(has_ingredient(recipes["quality-module"], "dubious-data", 10))
  assert_true(has_ingredient(recipes["quality-module"], "taxpayer-money", 25))

  assert_eq(#recipes["quality-module-2"].ingredients, 5)
  assert_true(has_ingredient(recipes["quality-module-2"], "quality-module", 5))
  assert_true(has_ingredient(recipes["quality-module-2"], "taxpayer-money", 100))

  assert_eq(#recipes["quality-module-3"].ingredients, 6)
  assert_true(has_ingredient(recipes["quality-module-3"], "quality-module-2", 5))
  assert_true(has_ingredient(recipes["quality-module-3"], "policy", 10))
  assert_true(has_ingredient(recipes["quality-module-3"], "credentials", 5))
  assert_true(has_ingredient(recipes["quality-module-3"], "taxpayer-money", 500))
end)

test("certification technologies retain native costs and gain one administrative pack", function()
  local data_api = new_data()
  integration.apply(data_api)
  local expected_prerequisites = {
    ["quality-module"] = "littering-resolution",
    ["quality-module-2"] = "industrial-propaganda",
    ["quality-module-3"] = "health-and-safety",
    ["epic-quality"] = "executive-review",
    ["legendary-quality"] = "constitutional-law",
  }
  for name, prerequisite in pairs(expected_prerequisites) do
    local technology = data_api.raw.technology[name]
    assert_true(contains(technology.prerequisites, "native-prerequisite"), name .. " should retain native prerequisites")
    assert_true(contains(technology.prerequisites, prerequisite), name .. " should gain its administrative prerequisite")
    local packs = 0
    for _, ingredient in ipairs(technology.unit.ingredients) do
      if ingredient[1] == "administrative-science-pack" or ingredient.name == "administrative-science-pack" then
        packs = packs + 1
      end
    end
    assert_eq(packs, 1, name .. " should contain administrative science exactly once")
  end
end)

test("ordinary facilities gain native certification mechanics while sensitive systems remain cosmetic", function()
  local data_api = new_data()
  integration.apply(data_api)
  local facility = data_api.raw["assembling-machine"]["resolution-office"]
  assert_true(contains(facility.allowed_effects, "quality"))
  assert_true(facility.quality_affects_module_slots)
  assert_eq(facility.quality_affects_energy_usage, false)
  assert_eq(facility.energy_usage_quality_multiplier.legendary, 1)
  for _, name in ipairs({"mechanical-printer", "printer-t1", "printer-t2"}) do
    assert_true(contains(data_api.raw["assembling-machine"][name].allowed_effects, "quality"),
      name .. " should be a certificated production facility")
  end

  for _, name in ipairs({"archive-recombination-bureau", "territorial-arbitration-post", "administrative-space-station"}) do
    local machine = data_api.raw["assembling-machine"][name]
    assert_eq(machine.crafting_speed_quality_multiplier.legendary, 1, name .. " speed must remain cosmetic")
    assert_eq(machine.quality_affects_module_slots, false, name .. " must not gain departments")
  end
  for _, name in ipairs({"pneumatic-pipe", "pneumatic-pipe-to-ground", "tube-intake", "tube-outtake"}) do
    assert_eq(data_api.raw.recipe[name].allow_quality, false, name .. " must be quality-neutral")
  end
end)

test("native and infrastructure certification curves match every tier", function()
  local expected_tiers = {
    {name = "normal", level = 0, native_speed = 1.0, infrastructure = 1.0},
    {name = "uncommon", level = 1, native_speed = 1.3, infrastructure = 1.1},
    {name = "rare", level = 2, native_speed = 1.6, infrastructure = 1.2},
    {name = "epic", level = 3, native_speed = 1.9, infrastructure = 1.3},
    {name = "legendary", level = 5, native_speed = 2.5, infrastructure = 1.5},
  }
  for _, tier in ipairs(expected_tiers) do
    local subject = {quality = {name = tier.name}}
    assert_eq(quality.level(subject), tier.level, tier.name .. " quality level")
    assert_near(quality.native_speed_multiplier(subject), tier.native_speed, tier.name .. " native speed")
    assert_near(quality.infrastructure_multiplier(subject), tier.infrastructure, tier.name .. " infrastructure scale")
  end
  assert_eq(quality.scaled_ticks(60, {quality = {name = "legendary"}}), 24)
  assert_eq(quality.scaled_ticks(120, {quality = {name = "legendary"}}), 48)
end)

test("quality helpers accept strict LuaQualityPrototype objects", function()
  local values = {name = "legendary", level = 5}
  local quality_prototype = setmetatable({}, {
    __index = function(_, key)
      if values[key] ~= nil then return values[key] end
      error("LuaQualityPrototype doesn't contain key " .. tostring(key), 2)
    end,
  })

  assert_eq(quality.name(quality_prototype), "legendary")
  assert_eq(quality.level(quality_prototype), 5)
  assert_near(quality.infrastructure_multiplier(quality_prototype), 1.5)
end)

test("certification locale provides the administrative retheme", function()
  local locale = require("tests.locale_helpers").load(mod_root, "en")
  assert_true(locale["item-name"]["quality-module"] == "Accreditation Module 1")
  assert_true(locale["technology-name"]["legendary-quality"] == "Ministerial Accreditation")
end)

test("the next versioned migration normalizes legacy biterport grades", function()
  local file = assert(io.open(mod_root .. "migrations/0.5.8.lua", "r"))
  local migration = file:read("*a")
  file:close()
  assert_true(migration:find("reservation%.item_quality = reservation%.item_quality or \"normal\""))
  assert_true(migration:find("job%.item_quality = job%.item_quality or job%.quality or \"normal\""))
  assert_true(migration:find("carried%.quality = carried%.quality or \"normal\""))
end)

if failed > 0 then
  io.stderr:write("Administrative Certification tests: " .. passed .. " passed, " .. failed .. " failed\n")
  for _, err in ipairs(errors) do io.stderr:write(" - " .. err .. "\n") end
  os.exit(1)
end
print("Administrative Certification tests: " .. passed .. " passed, 0 failed")
