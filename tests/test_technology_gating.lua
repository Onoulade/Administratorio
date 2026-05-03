-------------------------------------------------------------------------------
-- ADMINISTRATORIO TECHNOLOGY GATING TESTS
--
-- Standalone Lua tests that verify the split administrative tech tree, the
-- vanilla prerequisite hooks, and the monotonic science-pack rule.
-- Run: lua tests/test_technology_gating.lua
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

local function ingredient_list(...)
  local ingredients = {}
  for _, pack_name in ipairs({...}) do
    ingredients[#ingredients + 1] = {pack_name, 1}
  end
  return ingredients
end

local technologies = {}

data = {
  raw = {
    recipe = {
      car = {name = "car", enabled = true},
    },
    technology = technologies,
  },
}

function data:extend(prototypes)
  for _, proto in ipairs(prototypes) do
    if proto.type == "technology" then
      technologies[proto.name] = proto
    end
  end
end

local function vanilla_tech(name, prerequisites, effects, packs)
  local tech = {
    type = "technology",
    name = name,
    prerequisites = prerequisites or {},
    effects = effects or {},
  }
  if packs and #packs > 0 then
    tech.unit = {
      count = 1,
      ingredients = ingredient_list(table.unpack(packs)),
      time = 1,
    }
  end
  technologies[name] = tech
end

vanilla_tech("automation", nil, nil, {"automation-science-pack"})
vanilla_tech("automation-science-pack", nil, nil, {"automation-science-pack"})
vanilla_tech("logistic-science-pack", nil, nil, {"automation-science-pack", "logistic-science-pack"})
vanilla_tech("chemical-science-pack", nil, nil, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack"})
vanilla_tech("production-science-pack", {"productivity-module"}, nil, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "production-science-pack"})
vanilla_tech("utility-science-pack", nil, nil, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "utility-science-pack"})

vanilla_tech("steel-processing", nil, nil, {"automation-science-pack", "logistic-science-pack"})
vanilla_tech("electronics", nil, nil, {"automation-science-pack"})
vanilla_tech("fluid-handling", nil, nil, {"automation-science-pack", "logistic-science-pack"})
vanilla_tech("advanced-circuit", nil, nil, {"automation-science-pack", "logistic-science-pack"})
vanilla_tech("plastics", nil, nil, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack"})
vanilla_tech("sulfur-processing", nil, nil, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack"})
vanilla_tech("processing-unit", nil, nil, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "production-science-pack"})
vanilla_tech("productivity-module", nil, nil, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "production-science-pack"})
vanilla_tech("speed-module", nil, nil, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "production-science-pack"})
vanilla_tech("electric-engine", nil, nil, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "production-science-pack"})
vanilla_tech("battery", nil, nil, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack"})
vanilla_tech("robotics", nil, {
  {type = "unlock-recipe", recipe = "flying-robot-frame"},
}, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack"})
vanilla_tech("personal-roboport-equipment", {"robotics"}, nil, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack"})
vanilla_tech("personal-roboport-mk2-equipment", {"personal-roboport-equipment"}, nil, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "utility-science-pack"})
vanilla_tech("oil-gathering", nil, nil, {"chemical-science-pack"})
vanilla_tech("uranium-mining", nil, nil, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack"})
vanilla_tech("nuclear-power", {"uranium-processing"}, {
  {type = "unlock-recipe", recipe = "nuclear-reactor"},
  {type = "unlock-recipe", recipe = "heat-exchanger"},
  {type = "unlock-recipe", recipe = "heat-pipe"},
  {type = "unlock-recipe", recipe = "steam-turbine"},
}, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "production-science-pack"})
vanilla_tech("rocket-fuel", nil, nil, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "production-science-pack", "utility-science-pack"})
vanilla_tech("concrete", nil, nil, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "production-science-pack"})
vanilla_tech("low-density-structure", nil, nil, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "production-science-pack"})
vanilla_tech("advanced-material-processing", nil, {
  {type = "unlock-recipe", recipe = "steel-furnace"},
}, {"automation-science-pack", "logistic-science-pack"})
vanilla_tech("circuit-network", nil, {
  {type = "unlock-recipe", recipe = "arithmetic-combinator"},
  {type = "unlock-recipe", recipe = "decider-combinator"},
  {type = "unlock-recipe", recipe = "constant-combinator"},
  {type = "unlock-recipe", recipe = "power-switch"},
  {type = "unlock-recipe", recipe = "programmable-speaker"},
  {type = "unlock-recipe", recipe = "display-panel"},
}, {"automation-science-pack", "logistic-science-pack"})
vanilla_tech("advanced-combinators", {"circuit-network"}, nil, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack"})
vanilla_tech("electric-energy-distribution-1", nil, {
  {type = "unlock-recipe", recipe = "medium-electric-pole"},
  {type = "unlock-recipe", recipe = "big-electric-pole"},
}, {"automation-science-pack", "logistic-science-pack"})
vanilla_tech("electric-energy-distribution-2", {"electric-energy-distribution-1"}, nil, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack"})
vanilla_tech("logistics-2", nil, {
  {type = "unlock-recipe", recipe = "fast-transport-belt"},
  {type = "unlock-recipe", recipe = "fast-underground-belt"},
  {type = "unlock-recipe", recipe = "fast-splitter"},
}, {"automation-science-pack", "logistic-science-pack"})
vanilla_tech("bulk-inserter", {"logistics-2"}, nil, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack"})
vanilla_tech("logistics-3", {"logistics-2"}, {
  {type = "unlock-recipe", recipe = "express-transport-belt"},
  {type = "unlock-recipe", recipe = "express-underground-belt"},
  {type = "unlock-recipe", recipe = "express-splitter"},
}, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "production-science-pack"})
vanilla_tech("productivity-module-3", nil, {
  {type = "unlock-recipe", recipe = "productivity-module-3"},
}, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "production-science-pack"})
vanilla_tech("speed-module-3", nil, {
  {type = "unlock-recipe", recipe = "speed-module-3"},
}, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "production-science-pack"})

vanilla_tech("railway", {"logistics-2", "engine"}, {
  {type = "unlock-recipe", recipe = "rail"},
  {type = "unlock-recipe", recipe = "locomotive"},
}, {"automation-science-pack", "logistic-science-pack"})
vanilla_tech("solar-energy", {"steel-processing", "logistic-science-pack"}, {
  {type = "unlock-recipe", recipe = "solar-panel"},
}, {"automation-science-pack", "logistic-science-pack"})
vanilla_tech("advanced-material-processing-2", {"advanced-material-processing", "steel-processing"}, {
  {type = "unlock-recipe", recipe = "electric-furnace"},
}, {"automation-science-pack", "logistic-science-pack"})
vanilla_tech("electric-energy-accumulators", {"electric-energy-distribution-1", "battery"}, {
  {type = "unlock-recipe", recipe = "accumulator"},
}, {"automation-science-pack", "logistic-science-pack"})
vanilla_tech("construction-robotics", {"robotics"}, {
  {type = "unlock-recipe", recipe = "roboport"},
  {type = "unlock-recipe", recipe = "construction-robot"},
}, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack"})
vanilla_tech("logistic-robotics", {"robotics"}, {
  {type = "unlock-recipe", recipe = "roboport"},
  {type = "unlock-recipe", recipe = "logistic-robot"},
  {type = "unlock-recipe", recipe = "passive-provider-chest"},
  {type = "unlock-recipe", recipe = "storage-chest"},
}, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack"})
vanilla_tech("logistic-system", {"logistic-robotics", "utility-science-pack"}, {
  {type = "unlock-recipe", recipe = "active-provider-chest"},
  {type = "unlock-recipe", recipe = "buffer-chest"},
  {type = "unlock-recipe", recipe = "requester-chest"},
}, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "utility-science-pack"})
vanilla_tech("oil-processing", {"oil-gathering"}, {
  {type = "unlock-recipe", recipe = "oil-refinery"},
}, {"chemical-science-pack"})
vanilla_tech("automation-3", {"speed-module", "production-science-pack", "electric-engine"}, {
  {type = "unlock-recipe", recipe = "assembling-machine-3"},
}, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "production-science-pack"})
vanilla_tech("effect-transmission", {"processing-unit", "production-science-pack"}, {
  {type = "unlock-recipe", recipe = "beacon"},
}, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "production-science-pack"})
vanilla_tech("uranium-processing", {"uranium-mining"}, {
  {type = "unlock-recipe", recipe = "centrifuge"},
}, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack"})
vanilla_tech("rocket-silo", {"concrete", "rocket-fuel", "utility-science-pack"}, {
  {type = "unlock-recipe", recipe = "rocket-silo"},
}, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "production-science-pack", "utility-science-pack"})
vanilla_tech("engine", nil, {
  {type = "unlock-recipe", recipe = "engine-unit"},
}, {"automation-science-pack", "logistic-science-pack"})
vanilla_tech("automobilism", {"engine"}, {
  {type = "unlock-recipe", recipe = "car"},
}, {"automation-science-pack", "logistic-science-pack"})
vanilla_tech("gate", nil, nil, {"automation-science-pack", "logistic-science-pack"})
vanilla_tech("electric-mining-drill", nil, nil, {"automation-science-pack"})
vanilla_tech("stone-wall", nil, nil, {"automation-science-pack"})
vanilla_tech("power-armor-mk2", nil, nil, {"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "production-science-pack", "utility-science-pack"})

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

dofile(mod_root .. "prototypes/technology.lua")

local function load_locale_section(section_name)
  local path = mod_root .. "locale/en/config.cfg"
  local section = {}
  local in_section = false
  for line in io.lines(path) do
    local header = line:match("^%[(.-)%]$")
    if header then
      in_section = header == section_name
    elseif in_section then
      local key, value = line:match("^([^=]+)=(.*)$")
      if key then
        section[key] = value
      end
    end
  end
  return section
end

local technology_name_locale = load_locale_section("technology-name")
local technology_description_locale = load_locale_section("technology-description")
local technology_effect_locale = load_locale_section("technology-effect")

local function tech_unlocks_recipe(tech_name, recipe_name)
  local tech = technologies[tech_name]
  if not tech or not tech.effects then return false end
  for _, effect in ipairs(tech.effects) do
    if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
      return true
    end
  end
  return false
end

local function tech_has_prereq(tech_name, prereq_name)
  local tech = technologies[tech_name]
  if not tech or not tech.prerequisites then return false end
  for _, prereq in ipairs(tech.prerequisites) do
    if prereq == prereq_name then
      return true
    end
  end
  return false
end

local function tech_depends_on(tech_name, ancestor_name, seen)
  if tech_name == ancestor_name then return true end
  local tech = technologies[tech_name]
  if not tech or not tech.prerequisites then return false end
  seen = seen or {}
  if seen[tech_name] then return false end
  seen[tech_name] = true
  for _, prereq in ipairs(tech.prerequisites) do
    if prereq == ancestor_name then
      return true
    end
    if technologies[prereq] and tech_depends_on(prereq, ancestor_name, seen) then
      return true
    end
  end
  return false
end

local function tech_uses_pack(tech_name, pack_name)
  local tech = technologies[tech_name]
  if not tech or not tech.unit or not tech.unit.ingredients then return false end
  for _, ingredient in ipairs(tech.unit.ingredients) do
    if (ingredient[1] or ingredient.name) == pack_name then
      return true
    end
  end
  return false
end

local function tech_has_effect(tech_name, effect_type)
  local tech = technologies[tech_name]
  if not tech or not tech.effects then return false end
  for _, effect in ipairs(tech.effects) do
    if effect.type == effect_type then
      return true
    end
  end
  return false
end

local function assert_pack_superset(child_name, parent_name)
  local parent = technologies[parent_name]
  assert_true(parent and parent.unit and parent.unit.ingredients, parent_name .. " should have science packs in the test harness")
  for _, ingredient in ipairs(parent.unit.ingredients) do
    local pack_name = ingredient[1] or ingredient.name
    assert_true(tech_uses_pack(child_name, pack_name), child_name .. " should inherit " .. pack_name .. " from " .. parent_name)
  end
end

test("industrial printing owns printer-t2 and bulk copy unlocks", function()
  assert_true(tech_unlocks_recipe("industrial-printing", "printer-t2"), "industrial-printing should unlock printer-t2")
  assert_true(tech_unlocks_recipe("industrial-printing", "copy-blank-form"), "industrial-printing should unlock blank-form copying")
  assert_true(tech_unlocks_recipe("industrial-printing", "copy-blank-approval"), "industrial-printing should unlock blank-approval copying")
  assert_true(tech_unlocks_recipe("industrial-printing", "copy-form-27b-6"), "industrial-printing should unlock Form 27B-6 copying")
  assert_true(tech_unlocks_recipe("industrial-printing", "copy-environmental-impact-report"), "industrial-printing should unlock environmental report copying")
  assert_true(not tech_unlocks_recipe("industrial-printing", "copy-work-order"), "industrial-printing should not unlock work-order copying")
  assert_true(not tech_unlocks_recipe("industrial-printing", "form-27b-6"), "industrial-printing should not unlock Form 27B-6")
  assert_true(tech_has_prereq("industrial-printing", "advanced-circuit"), "industrial-printing should require advanced circuits")
end)

test("work order duplication is the purple-science copy upgrade", function()
  assert_true(tech_unlocks_recipe("work-order-duplication", "copy-work-order"), "work-order-duplication should unlock work-order copying")
  assert_true(tech_unlocks_recipe("work-order-duplication", "copy-safety-work-order"), "work-order-duplication should unlock safety work-order copying")
  assert_true(tech_unlocks_recipe("work-order-duplication", "copy-construction-work-order"), "work-order-duplication should unlock construction work-order copying")
  assert_true(tech_unlocks_recipe("work-order-duplication", "copy-management-verbal-work-order"), "work-order-duplication should unlock verbal management work-order copying")
  assert_true(tech_unlocks_recipe("work-order-duplication", "copy-management-written-work-order"), "work-order-duplication should unlock written management work-order copying")
  assert_true(tech_unlocks_recipe("work-order-duplication", "copy-research-grant-work-order"), "work-order-duplication should unlock research grant work-order copying")
  assert_true(tech_unlocks_recipe("work-order-duplication", "copy-chemical-handling-work-order"), "work-order-duplication should unlock chemical handling work-order copying")
  assert_true(tech_unlocks_recipe("work-order-duplication", "copy-radiological-work-order"), "work-order-duplication should unlock radiological work-order copying")
  assert_true(tech_has_prereq("work-order-duplication", "industrial-printing"), "work-order-duplication should require industrial-printing")
  assert_true(tech_has_prereq("work-order-duplication", "radiological-compliance"), "work-order-duplication should require radiological-compliance")
  assert_true(tech_has_prereq("work-order-duplication", "processing-unit"), "work-order-duplication should require processing units")
  assert_true(tech_has_prereq("work-order-duplication", "production-science-pack"), "work-order-duplication should require production science")
  assert_true(tech_uses_pack("work-order-duplication", "production-science-pack"), "work-order-duplication should use production science")
end)

test("local precedents and environmental compliance are split", function()
  assert_true(tech_unlocks_recipe("local-precedents", "form-27b-6"), "local-precedents should unlock Form 27B-6")
  assert_true(not tech_unlocks_recipe("local-precedents", "copy-form-27b-6"), "local-precedents should not unlock Form 27B-6 copying anymore")
  assert_true(not tech_unlocks_recipe("local-precedents", "environmental-impact-report"), "local-precedents should not unlock environmental impact reports anymore")
  assert_true(not tech_unlocks_recipe("local-precedents", "chemical-handling-work-order-production"), "local-precedents should not unlock chemical handling work orders")
  assert_true(not tech_unlocks_recipe("local-precedents", "carbon-offset-certificate-verified"), "local-precedents should not unlock verified carbon certificates")
  assert_true(not tech_unlocks_recipe("environmental-compliance", "petrochemical-operating-permit-production"), "environmental-compliance should not unlock removed petrochemical permits")
  assert_true(tech_unlocks_recipe("environmental-compliance", "environmental-impact-report"), "environmental-compliance should unlock environmental impact reports")
  assert_true(tech_unlocks_recipe("environmental-compliance", "chemical-handling-work-order-production"), "environmental-compliance should unlock chemical handling work orders")
  assert_true(tech_unlocks_recipe("environmental-compliance", "carbon-offset-certificate-verified"), "environmental-compliance should unlock verified carbon certificates")
  assert_true(not tech_unlocks_recipe("environmental-compliance", "chemical-operator-training"), "environmental-compliance should not unlock chemical operator training directly")
  assert_true(tech_has_prereq("chemical-operator-training", "environmental-compliance"), "chemical operator training should branch from environmental-compliance")
  assert_true(not tech_unlocks_recipe("environmental-compliance", "copy-environmental-impact-report"), "environmental-compliance should not unlock impact-report copying")
end)

test("administrative bureaucracy owns only the early greenhouse wood bootstrap", function()
  assert_true(technologies["administrative-bureaucracy"].icon == "__administratorio__/graphics/technology/greenhouse.png",
    "administrative-bureaucracy should use the greenhouse technology icon")
  assert_true(technologies["administrative-bureaucracy"].icon_size == 128,
    "administrative-bureaucracy should use the 128px greenhouse technology icon size")
  assert_true(tech_unlocks_recipe("administrative-bureaucracy", "greenhouse"), "administrative-bureaucracy should unlock the greenhouse")
  assert_true(tech_unlocks_recipe("administrative-bureaucracy", "greenhouse-wood"), "administrative-bureaucracy should unlock wood growth")
  assert_true(not tech_unlocks_recipe("administrative-bureaucracy", "filing-landscape"), "administrative-bureaucracy should not unlock landscape filing")
  assert_true(not tech_unlocks_recipe("administrative-bureaucracy", "landscape-final"), "administrative-bureaucracy should not unlock landscape resolution")
  assert_true(not tech_unlocks_recipe("administrative-bureaucracy", "greenhouse-discovery"), "administrative-bureaucracy should not unlock coffee discovery")
  assert_true(tech_has_prereq("administrative-bureaucracy", "automation"), "administrative-bureaucracy should require automation for work-order-gated vanilla ingredients")
  assert_true(not tech_has_prereq("administrative-bureaucracy", "printing-technology"), "administrative-bureaucracy should not require printing-technology")
  assert_true(not tech_has_prereq("administrative-bureaucracy", "administrative-science-research"), "administrative-bureaucracy should not require administrative science research")
  assert_true(tech_uses_pack("administrative-bureaucracy", "automation-science-pack"), "administrative-bureaucracy should still use automation science")
  assert_true(not tech_uses_pack("administrative-bureaucracy", "administrative-science-pack"), "administrative-bureaucracy should not use administrative science")
end)

test("admin station capacity upgrades are tiered and chain correctly", function()
  local expected_icon = "__administratorio__/graphics/technology/admin-station-capacity.png"
  for level = 1, 8 do
    local tech_name = "admin-station-capacity-" .. level
    assert_true(technologies[tech_name] ~= nil, tech_name .. " should exist")
    assert_true(tech_has_effect(tech_name, "nothing"), tech_name .. " should expose a scripted-effect marker")
    assert_true(technologies[tech_name].icon == expected_icon, tech_name .. " should use the building-based technology icon")
    assert_true(technologies[tech_name].icon_size == 256, tech_name .. " should use the 256px technology icon size")

    if level == 1 then
      assert_true(tech_has_prereq(tech_name, "administrative-bureaucracy"), tech_name .. " should start from administrative-bureaucracy")
      assert_true(tech_uses_pack(tech_name, "automation-science-pack"), tech_name .. " should use automation science")
      assert_true(tech_uses_pack(tech_name, "administrative-science-pack"), tech_name .. " should use administrative science")
    else
      assert_true(tech_has_prereq(tech_name, "admin-station-capacity-" .. (level - 1)), tech_name .. " should chain from prior level")
    end
  end

  assert_true(tech_has_prereq("admin-station-capacity-3", "logistic-science-pack"), "capacity III should require logistic science")
  assert_true(tech_has_prereq("admin-station-capacity-5", "chemical-science-pack"), "capacity V should require chemical science")
  assert_true(tech_has_prereq("admin-station-capacity-7", "production-science-pack"), "capacity VII should require production science")
  assert_true(tech_has_prereq("admin-station-capacity-8", "utility-science-pack"), "capacity VIII should require utility science")
  assert_true(tech_uses_pack("admin-station-capacity-8", "utility-science-pack"), "capacity VIII should consume utility science")
end)

test("pneumatic capacity upgrade chain has base upgrade locale", function()
  assert_true(technology_name_locale["pneumatic-capacity"] ~= nil, "pneumatic capacity upgrade base name should be localized")
  assert_true(technology_description_locale["pneumatic-capacity"] ~= nil, "pneumatic capacity upgrade base description should be localized")

  for level = 1, 4 do
    local tech_name = "pneumatic-capacity-" .. level
    assert_true(technologies[tech_name] ~= nil, tech_name .. " should exist")
    assert_true(technology_name_locale[tech_name] ~= nil, tech_name .. " name should be localized")
    assert_true(technology_description_locale[tech_name] ~= nil, tech_name .. " description should be localized")
  end

  assert_true(tech_has_prereq("pneumatic-capacity-4", "utility-science-pack"), "pneumatic capacity IV should require utility science")
  assert_true(tech_uses_pack("pneumatic-capacity-4", "utility-science-pack"), "pneumatic capacity IV should consume utility science")
end)

test("biterport capacity, transport, and logistics speed upgrades are tiered and localized", function()
  assert_true(technology_effect_locale["biterport-capacity"] == nil, "removed biterport capacity effect should not be localized")
  assert_true(technology_effect_locale["biterport-transport-capacity"] ~= nil, "biterport transport effect should be localized")
  assert_true(technology_effect_locale["biterport-worker-speed"] ~= nil, "biterport worker speed effect should be localized")
  assert_true(technology_name_locale["biter-labor-efficiency"] ~= nil, "biter labor efficiency base name should be localized")
  assert_true(technology_description_locale["biter-labor-efficiency"] ~= nil, "biter labor efficiency base description should be localized")
  assert_true(technology_effect_locale["biter-labor-efficiency"] ~= nil, "biter labor efficiency effect should be localized")
  assert_true(technology_name_locale["biterport-transport-capacity"] ~= nil, "biterport transport base name should be localized")
  assert_true(technology_description_locale["biterport-transport-capacity"] ~= nil, "biterport transport base description should be localized")
  assert_true(technology_name_locale["biterport-worker-speed"] ~= nil, "biterport worker speed base name should be localized")
  assert_true(technology_description_locale["biterport-worker-speed"] ~= nil, "biterport worker speed base description should be localized")
  assert_true(technologies["biterport-logistics"] ~= nil, "biterport-logistics should exist")
  assert_true(technology_name_locale["biterport-logistics"] ~= nil, "biterport-logistics name should be localized")
  assert_true(technology_description_locale["biterport-logistics"] ~= nil, "biterport-logistics description should be localized")
  assert_true(tech_depends_on("biterport-logistics", "biter-employment"), "biterport logistics should require biter employment via formation-center")
  assert_true(tech_has_prereq("biterport-logistics", "formation-center"), "biterport logistics should be gated behind formation-center")
  assert_true(tech_has_prereq("biterport-logistics", "steel-processing"), "biterport logistics should require steel-processing for biterport infrastructure")
  assert_true(tech_has_prereq("biterport-logistics", "advanced-circuit"), "biterport logistics should require advanced circuits for biterport infrastructure")
  assert_true(tech_unlocks_recipe("biterport-logistics", "biterport"), "biterport logistics should unlock biterports")
  assert_true(tech_unlocks_recipe("biterport-logistics", "biter-logistics-formation"), "biterport logistics should unlock dedicated logistics formations")
  assert_true(not tech_unlocks_recipe("biter-employment", "biterport"), "biter-employment should not unlock biterports directly")

  local expected_labor_efficiency = {3, 5}
  for level = 1, 2 do
    local tech_name = "biter-labor-efficiency-" .. level
    assert_true(technology_name_locale[tech_name] ~= nil, tech_name .. " name should be localized")
    assert_true(technology_description_locale[tech_name] ~= nil, tech_name .. " description should be localized")
    assert_true(tech_has_effect(tech_name, "nothing"), tech_name .. " should expose a scripted-effect marker")
    assert_true(
      technologies[tech_name].effects[1].effect_description[2] == tostring(expected_labor_efficiency[level]),
      tech_name .. " should advertise " .. expected_labor_efficiency[level] .. " machine authorizations"
    )
  end

  for _, chest_recipe in ipairs({
    "paperwork-provider-chest",
    "paperwork-storage-chest",
    "paperwork-requester-chest",
  }) do
    assert_true(tech_unlocks_recipe("biterport-logistics", chest_recipe), "biterport logistics should unlock " .. chest_recipe)
    assert_true(not tech_unlocks_recipe("logistic-robotics", chest_recipe), "logistic robotics should not own " .. chest_recipe)
  end

  for _, chest_recipe in ipairs({
    "active-provider-chest",
    "passive-provider-chest",
    "storage-chest",
    "buffer-chest",
    "requester-chest",
  }) do
    assert_true(not tech_unlocks_recipe("biterport-logistics", chest_recipe), "biterport logistics should not unlock real " .. chest_recipe)
    assert_true(tech_unlocks_recipe("logistic-robotics", chest_recipe), "logistic robotics should unlock real " .. chest_recipe)
  end

  for level = 1, 4 do
    local tech_name = "biterport-capacity-" .. level
    assert_true(technologies[tech_name] == nil, tech_name .. " should not exist")
    assert_true(technology_name_locale[tech_name] == nil, tech_name .. " name should not be localized")
    assert_true(technology_description_locale[tech_name] == nil, tech_name .. " description should not be localized")
  end

  local expected_transport = {2, 5, 10, 25}
  for level = 1, 4 do
    local tech_name = "biterport-transport-capacity-" .. level
    assert_true(technologies[tech_name] ~= nil, tech_name .. " should exist")
    assert_true(technology_name_locale[tech_name] ~= nil, tech_name .. " name should be localized")
    assert_true(technology_description_locale[tech_name] ~= nil, tech_name .. " description should be localized")
    assert_true(tech_has_effect(tech_name, "nothing"), tech_name .. " should expose a scripted-effect marker")
    assert_true(
      technologies[tech_name].effects[1].effect_description[2] == tostring(expected_transport[level]),
      tech_name .. " should advertise " .. expected_transport[level] .. " items per trip"
    )
    if level == 1 then
      assert_true(tech_has_prereq(tech_name, "biterport-logistics"), tech_name .. " should start from biterport logistics")
    else
      assert_true(tech_has_prereq(tech_name, "biterport-transport-capacity-" .. (level - 1)), tech_name .. " should chain from prior level")
    end
  end

  for level = 1, 2 do
    local tech_name = "biterport-worker-speed-" .. level
    assert_true(technologies[tech_name] ~= nil, tech_name .. " should exist")
    assert_true(technology_name_locale[tech_name] ~= nil, tech_name .. " name should be localized")
    assert_true(technology_description_locale[tech_name] ~= nil, tech_name .. " description should be localized")
    assert_true(tech_has_effect(tech_name, "nothing"), tech_name .. " should expose a scripted-effect marker")
    if level == 1 then
      assert_true(tech_has_prereq(tech_name, "biterport-logistics"), tech_name .. " should start from biterport logistics")
    else
      assert_true(tech_has_prereq(tech_name, "biterport-worker-speed-" .. (level - 1)), tech_name .. " should chain from prior level")
    end
  end

  assert_true(not tech_uses_pack("biterport-transport-capacity-3", "chemical-science-pack"), "transport III should not use chemical science")
  assert_true(tech_uses_pack("biterport-transport-capacity-4", "chemical-science-pack"), "transport IV should use chemical science")
  assert_true(tech_has_prereq("biterport-transport-capacity-4", "chemical-science-pack"), "transport IV should depend on chemical science")
  assert_true(tech_uses_pack("biterport-worker-speed-2", "chemical-science-pack"), "speed II should use chemical science")
  assert_true(tech_has_prereq("biterport-worker-speed-2", "chemical-science-pack"), "speed II should depend on chemical science")
end)

test("filing cabinet logistics upgrades grant character logistics bonuses", function()
  for level = 1, 3 do
    local tech_name = "filing-cabinet-logistics-" .. level
    assert_true(technologies[tech_name] ~= nil, tech_name .. " should exist")
    assert_true(tech_has_effect(tech_name, "character-logistic-requests"), tech_name .. " should increase logistic requests")
    assert_true(tech_has_effect(tech_name, "character-logistic-trash-slots"), tech_name .. " should increase trash slots")
  end

  assert_true(tech_has_prereq("filing-cabinet-logistics-1", "information-management"), "filing logistics I should require information-management")
  assert_true(tech_has_prereq("filing-cabinet-logistics-1", "logistic-robotics"), "filing logistics I should require logistic robotics")
  assert_true(tech_has_prereq("filing-cabinet-logistics-2", "filing-cabinet-logistics-1"), "filing logistics II should chain from level I")
  assert_true(tech_has_prereq("filing-cabinet-logistics-3", "filing-cabinet-logistics-2"), "filing logistics III should chain from level II")
  assert_true(tech_has_prereq("filing-cabinet-logistics-3", "utility-science-pack"), "filing logistics III should require utility science")
end)

test("bootstrap paperwork is gated behind both discovery chains", function()
  assert_true(technologies["discovery-redundant-rubble"].icon == "__administratorio__/graphics/technology/redundant-rubble.png",
    "geological inefficiency should use the redundant rubble technology icon")
  assert_true(technologies["discovery-redundant-rubble"].icon_size == 128,
    "geological inefficiency should use the 128px redundant rubble technology icon size")
  assert_true(tech_unlocks_recipe("biter-employment", "office-desk"), "biter-employment should unlock the office desk")
  assert_true(tech_unlocks_recipe("discovery-redundant-rubble", "promise-production"), "discovery-redundant-rubble should unlock promises")
  assert_true(tech_unlocks_recipe("discovery-redundant-rubble", "filing-landscape"), "discovery-redundant-rubble should unlock landscape filing")
  assert_true(tech_unlocks_recipe("discovery-redundant-rubble", "admin-station"), "discovery-redundant-rubble should unlock the admin station")
  assert_true(not tech_unlocks_recipe("printing-technology", "admin-station"), "printing-technology should not duplicate the admin station")
  assert_true(tech_unlocks_recipe("biter-employment", "resolution-office"), "biter-employment should unlock the resolution office")
  assert_true(not tech_unlocks_recipe("printing-technology", "resolution-office"), "printing-technology should not unlock the resolution office before biter workers exist")
  assert_true(tech_unlocks_recipe("discovery-bullshit", "landscape-final"), "discovery-bullshit should unlock landscape resolution")
  assert_true(tech_unlocks_recipe("discovery-bullshit", "safety-waiver-draft"), "discovery-bullshit should unlock safety waiver drafts")
  assert_true(tech_unlocks_recipe("discovery-bullshit", "construction-permit-draft"), "discovery-bullshit should unlock construction permit drafts")
  assert_true(tech_unlocks_recipe("discovery-bullshit", "dubious-data-refining"), "discovery-bullshit should unlock bullshit refining when the ore is discovered")
  assert_true(not tech_unlocks_recipe("printing-technology", "promise-production"), "printing-technology should not unlock promises")
  assert_true(not tech_unlocks_recipe("printing-technology", "safety-waiver-draft"), "printing-technology should not unlock safety waiver drafts")
  assert_true(not tech_unlocks_recipe("printing-technology", "construction-permit-draft"), "printing-technology should not unlock construction permit drafts")
  assert_true(tech_unlocks_recipe("rubble-compaction", "compacted-rubble-production"), "rubble-compaction should unlock compacted rubble")
  assert_true(tech_depends_on("printing-technology", "discovery-bullshit"), "printing-technology should depend on discovery-bullshit")
  assert_true(tech_depends_on("printing-technology", "discovery-redundant-rubble"), "printing-technology should depend on discovery-redundant-rubble")
  assert_true(tech_depends_on("administrative-bureaucracy", "discovery-redundant-rubble"), "administrative-bureaucracy should stay behind discovery-redundant-rubble")
end)

test("rideable biter gets its own tech while automobilism stays the late car unlock", function()
  assert_true(technologies["rideable-biter"] ~= nil, "rideable-biter technology should exist")
  assert_true(tech_unlocks_recipe("rideable-biter", "rideable-biter"), "rideable-biter tech should unlock the rideable biter recipe")
  assert_true(tech_depends_on("rideable-biter", "biter-employment"), "rideable-biter should still require biter employment through formation-center")
  assert_true(tech_has_prereq("rideable-biter", "formation-center"), "rideable-biter should be gated behind formation-center")
  assert_true(tech_has_prereq("rideable-biter", "engine"), "rideable-biter should still require engine")

  assert_true(tech_unlocks_recipe("automobilism", "car"), "automobilism should unlock the vanilla car")
  assert_true(not tech_unlocks_recipe("automobilism", "rideable-biter"), "automobilism should no longer unlock the rideable biter")
  assert_true(tech_has_prereq("automobilism", "utility-science-pack"), "automobilism should require utility science")
  assert_true(tech_uses_pack("automobilism", "utility-science-pack"), "automobilism should consume utility science")
  assert_true(not tech_has_prereq("automobilism", "formation-center"), "automobilism should not require formation-center anymore")
  assert_true(not tech_depends_on("automobilism", "biter-employment"), "automobilism should no longer depend on biter employment")
  assert_true(data.raw.recipe.car.enabled == true, "vanilla car recipe should remain tech-disabled by base data in the harness")
  assert_true(technology_name_locale["rideable-biter"] ~= nil, "rideable-biter tech name should be localized")
  assert_true(technology_description_locale["rideable-biter"] ~= nil, "rideable-biter tech description should be localized")
end)

test("office agriculture now owns only the later coffee branch", function()
  assert_true(tech_unlocks_recipe("office-agriculture", "coffee-plantation"), "office-agriculture should unlock coffee plantations")
  assert_true(not tech_unlocks_recipe("office-agriculture", "charcoal-production"), "office-agriculture should not unlock charcoal")
  assert_true(not tech_unlocks_recipe("office-agriculture", "greenhouse"), "office-agriculture should not unlock the greenhouse anymore")
  assert_true(not tech_unlocks_recipe("office-agriculture", "greenhouse-discovery"), "office-agriculture should not unlock coffee discovery anymore")
  assert_true(tech_has_prereq("office-agriculture", "corporate-hospitality"), "office-agriculture should require corporate-hospitality for coffee seeding")
  assert_true(not tech_has_prereq("office-agriculture", "industrial-printing"), "office-agriculture should not require industrial-printing")
end)

test("charcoal production has its own late office technology", function()
  assert_true(technologies["charcoal-production"] ~= nil, "charcoal-production technology should exist")
  assert_true(tech_unlocks_recipe("charcoal-production", "charcoal-production"), "charcoal-production tech should unlock charcoal recipe")
  assert_true(tech_has_prereq("charcoal-production", "corporate-hospitality"), "charcoal-production should require the coffee branch")
  assert_true(tech_has_prereq("charcoal-production", "fluid-handling"), "charcoal-production should require fluid handling")
  assert_true(tech_has_prereq("charcoal-production", "chemical-science-pack"), "charcoal-production should require chemical science")
  assert_true(tech_uses_pack("charcoal-production", "automation-science-pack"), "charcoal-production should use automation science")
  assert_true(tech_uses_pack("charcoal-production", "logistic-science-pack"), "charcoal-production should use logistic science")
  assert_true(tech_uses_pack("charcoal-production", "administrative-science-pack"), "charcoal-production should use administrative science")
  assert_true(not tech_has_prereq("charcoal-production", "administrative-bureaucracy"), "charcoal-production should not sit directly on the early wood branch")
end)

test("midgame office branches are split into separate pipelines", function()
  assert_true(tech_unlocks_recipe("corporate-hospitality", "corporate-breakroom"), "corporate-hospitality should unlock the breakroom")
  assert_true(tech_unlocks_recipe("corporate-hospitality", "greenhouse-discovery"), "corporate-hospitality should unlock coffee discovery")
  assert_true(tech_unlocks_recipe("corporate-hospitality", "coffee-refining"), "corporate-hospitality should unlock coffee refining")
  assert_true(tech_unlocks_recipe("corporate-hospitality", "watercooler-gossip-production"), "corporate-hospitality should unlock gossip")
  assert_true(not tech_unlocks_recipe("corporate-hospitality", "data-production"), "corporate-hospitality should not unlock data anymore")
  assert_true(tech_unlocks_recipe("information-management", "data-production"), "information-management should unlock data-production")
  assert_true(tech_unlocks_recipe("information-management", "good-excuse-production"), "information-management should unlock good excuses")
  assert_true(tech_unlocks_recipe("verbal-approvals", "blank-directive-production"), "verbal-approvals should unlock blank directives")
  assert_true(tech_unlocks_recipe("verbal-approvals", "management-verbal-work-order-production"), "verbal-approvals should unlock management verbal work orders")
  assert_true(tech_unlocks_recipe("verbal-approvals", "management-verbal-printing"), "verbal-approvals should unlock verbal approval printing")
end)

test("industrial printing stays optional outside bulk-copy throughput", function()
  assert_true(tech_has_prereq("streamlined-work-orders", "printing-technology"), "streamlined-work-orders should require printing-technology")
  assert_true(not tech_has_prereq("streamlined-work-orders", "industrial-printing"), "streamlined-work-orders should not require industrial-printing")
  assert_true(not tech_has_prereq("industrial-propaganda", "industrial-printing"), "industrial-propaganda should not require industrial-printing")
end)

test("compacted rubble sits on its own shared tech", function()
  assert_true(not tech_unlocks_recipe("industrial-propaganda", "compacted-rubble-production"), "industrial-propaganda should not unlock compacted rubble")
  assert_true(not tech_unlocks_recipe("pneumatic-form-transport", "compacted-rubble-production"), "pneumatic-form-transport should not unlock compacted rubble")
  assert_true(tech_has_prereq("industrial-propaganda", "rubble-compaction"), "industrial-propaganda should require rubble-compaction")
  assert_true(tech_has_prereq("pneumatic-form-transport", "rubble-compaction"), "pneumatic-form-transport should require rubble-compaction")
end)

test("environmental compliance is a single consolidated branch", function()
  assert_true(technologies["environmental-reporting"] == nil, "environmental-reporting should not exist as a separate tech")
  assert_true(technologies["environmental-certification"] == nil, "environmental-certification should not exist as a separate tech")
  assert_true(tech_has_prereq("environmental-compliance", "local-precedents"), "environmental-compliance should require local-precedents")
  assert_true(tech_has_prereq("environmental-compliance", "fluid-handling"), "environmental-compliance should require fluid-handling")
  assert_true(tech_has_prereq("environmental-compliance", "steel-processing"), "environmental-compliance should require steel-processing")
end)

test("environmental compliance stays below chemical tier lock-in", function()
  assert_true(not tech_has_prereq("environmental-compliance", "chemical-science-pack"), "environmental-compliance should not require chemical science")
  assert_true(not tech_has_prereq("environmental-compliance", "public-finance"), "environmental-compliance should not require public-finance")
  assert_true(not tech_has_prereq("environmental-compliance", "production-science-pack"), "environmental-compliance should not require production science")
  assert_true(not tech_uses_pack("environmental-compliance", "chemical-science-pack"), "environmental-compliance should not use chemical science")
  assert_true(tech_uses_pack("environmental-compliance", "logistic-science-pack"), "environmental-compliance should use logistic science")
  assert_true(not tech_uses_pack("environmental-compliance", "production-science-pack"), "environmental-compliance should not use production science")
end)

test("late administrative branches are split into finance meetings and nuclear paperwork", function()
  assert_true(tech_unlocks_recipe("public-finance", "treasury-bond-production"), "public-finance should unlock treasury bonds")
  assert_true(tech_unlocks_recipe("public-finance", "union-headquarters"), "public-finance should unlock union headquarters")
  assert_true(tech_has_prereq("public-finance", "steel-processing"), "public-finance should require steel-processing")
  assert_true(tech_has_prereq("public-finance", "biter-employment-office"), "public-finance should require biter employment office for union delegates")
  assert_true(tech_has_prereq("public-finance", "union-delegate-training"), "public-finance should require union delegate training first")
  assert_true(tech_unlocks_recipe("board-meetings", "management-written-proposal"), "board-meetings should unlock written proposals")
  assert_true(tech_unlocks_recipe("board-meetings", "management-written-1st-printing"), "board-meetings should unlock written approval printing")
  assert_true(tech_unlocks_recipe("executive-review", "management-written-work-order-production"), "executive-review should unlock written management work orders")
  assert_true(not tech_unlocks_recipe("executive-review", "management-written-proposal"), "executive-review should not unlock written proposals directly anymore")
  assert_true(tech_unlocks_recipe("radiological-compliance", "radiological-work-order-production"), "radiological-compliance should unlock radiological paperwork")
  assert_true(tech_has_prereq("radiological-compliance", "environmental-compliance"), "radiological-compliance should require environmental-compliance")
  assert_true(tech_has_prereq("radiological-compliance", "battery"), "radiological-compliance should require battery")
end)

test("delegate training and vanilla relocation hooks keep each tech meaningful", function()
  assert_true(tech_has_prereq("union-delegate-training", "formation-center"), "union delegate training should require the formation center")
  assert_true(tech_has_prereq("union-delegate-training", "verbal-approvals"), "union delegate training should require verbal approvals")
  assert_true(tech_has_prereq("union-delegate-training", "local-precedents"), "union delegate training should require local precedents")
  assert_true(tech_has_prereq("union-delegate-training", "chemical-science-pack"), "union delegate training should require chemical science")

  assert_true(tech_unlocks_recipe("advanced-material-processing", "steel-furnace"), "advanced material processing should keep the steel furnace unlock")
  assert_true(not tech_unlocks_recipe("concrete", "steel-furnace"), "concrete should not duplicate the steel furnace unlock")
  assert_true(not tech_unlocks_recipe("circuit-network", "arithmetic-combinator"), "circuit network should not unlock arithmetic combinators early")
  assert_true(tech_unlocks_recipe("advanced-combinators", "arithmetic-combinator"), "advanced combinators should unlock arithmetic combinators")
  assert_true(tech_unlocks_recipe("electric-energy-distribution-1", "medium-electric-pole"), "electric-energy-distribution-1 should keep the medium pole unlock")
  assert_true(tech_unlocks_recipe("electric-energy-distribution-1", "big-electric-pole"), "electric-energy-distribution-1 should keep the big pole unlock")
  assert_true(not tech_unlocks_recipe("electric-energy-distribution-2", "medium-electric-pole"), "electric-energy-distribution-2 should not duplicate the medium pole unlock")
  assert_true(tech_unlocks_recipe("logistics-2", "fast-transport-belt"), "logistics-2 should keep fast belt unlocks")
  assert_true(not tech_unlocks_recipe("bulk-inserter", "fast-transport-belt"), "bulk-inserter should not duplicate fast belt unlocks")
  assert_true(tech_has_prereq("logistics-3", "bulk-inserter"), "logistics-3 should require bulk inserter so express belts have fast belts available")
  assert_true(tech_unlocks_recipe("engine", "engine-unit"), "engine should keep the engine-unit unlock")
  assert_true(not tech_unlocks_recipe("fluid-handling", "engine-unit"), "fluid-handling should not duplicate the engine-unit unlock")
  assert_true(tech_unlocks_recipe("productivity-module-3", "productivity-module-3"), "productivity module 3 tech should keep its own recipe unlock")
  assert_true(tech_unlocks_recipe("speed-module-3", "speed-module-3"), "speed module 3 tech should keep its own recipe unlock")
  assert_true(not tech_unlocks_recipe("railway", "locomotive"), "railway should not unlock locomotives before the production-tier recipe is usable")
  assert_true(tech_unlocks_recipe("production-science-pack", "locomotive"), "production science should unlock locomotives once their full ingredient chain exists")
  assert_true(not tech_unlocks_recipe("rocket-silo", "productivity-module-3"), "rocket-silo should not duplicate productivity module 3")
  assert_true(not tech_unlocks_recipe("rocket-silo", "speed-module-3"), "rocket-silo should not duplicate speed module 3")
end)

test("late complaint tiers are split by family and science tier", function()
  assert_true(tech_unlocks_recipe("noise-ordinances", "noise-final"), "noise-ordinances should unlock noise resolution")
  assert_true(tech_unlocks_recipe("loitering-ordinances", "loitering-final"), "loitering-ordinances should unlock loitering resolution")
  assert_true(tech_unlocks_recipe("constitutional-law", "unemployment-final"), "constitutional-law should unlock unemployment resolution")
  assert_true(tech_unlocks_recipe("vagrancy-ordinances", "vagrancy-final"), "vagrancy-ordinances should unlock vagrancy resolution")
  assert_true(tech_uses_pack("loitering-ordinances", "utility-science-pack"), "loitering-ordinances should use utility science")
  assert_true(not tech_uses_pack("loitering-ordinances", "production-science-pack"), "loitering-ordinances should not use production science")
  assert_true(tech_uses_pack("constitutional-law", "production-science-pack"), "constitutional-law should use production science")
  assert_true(not tech_uses_pack("constitutional-law", "utility-science-pack"), "constitutional-law should not use utility science")
  assert_true(tech_uses_pack("vagrancy-ordinances", "utility-science-pack"), "vagrancy-ordinances should use utility science")
end)

test("science tier heads and inherited pack requirements are enforced", function()
  assert_true(tech_has_prereq("industrial-printing", "chemical-science-pack"), "industrial-printing should require chemical science")
  assert_true(tech_uses_pack("industrial-printing", "chemical-science-pack"), "industrial-printing should use chemical science")
  assert_true(tech_has_prereq("corporate-hospitality", "logistic-science-pack"), "corporate-hospitality should require logistic science")
  assert_true(tech_uses_pack("corporate-hospitality", "logistic-science-pack"), "corporate-hospitality should use logistic science")
  assert_true(tech_has_prereq("office-agriculture", "logistic-science-pack"), "office-agriculture should require logistic science")
  assert_true(tech_has_prereq("charcoal-production", "chemical-science-pack"), "charcoal-production should require chemical science")
  assert_true(tech_has_prereq("information-management", "advanced-circuit"), "information-management should require advanced-circuit")
  assert_true(tech_has_prereq("pneumatic-form-transport", "logistic-science-pack"), "pneumatic-form-transport should require logistic science")
  assert_true(tech_uses_pack("pneumatic-form-transport", "logistic-science-pack"), "pneumatic-form-transport should use logistic science")
  assert_true(tech_has_prereq("public-finance", "chemical-science-pack"), "public-finance should require chemical science")
  assert_true(tech_has_prereq("environmental-compliance", "fluid-handling"), "environmental-compliance should require fluid handling")
  assert_true(tech_has_prereq("board-meetings", "health-and-safety"), "board-meetings should require health-and-safety")
  assert_true(tech_has_prereq("board-meetings", "chemical-science-pack"), "board-meetings should require chemical science")
  assert_true(tech_has_prereq("eminent-domain-zoning", "production-science-pack"), "eminent-domain-zoning should require production science")
  assert_true(tech_has_prereq("constitutional-law", "production-science-pack"), "constitutional-law should require production science")
  assert_true(tech_has_prereq("loitering-ordinances", "utility-science-pack"), "loitering-ordinances should require utility science")
  assert_true(not tech_has_prereq("loitering-ordinances", "production-science-pack"), "loitering-ordinances should not require production science")
  assert_true(tech_has_prereq("vagrancy-ordinances", "utility-science-pack"), "vagrancy-ordinances should require utility science")
  assert_true(not tech_has_prereq("electric-mining-drill", "printing-technology"), "electric-mining-drill should not require printing-technology")
  assert_true(not tech_has_prereq("stone-wall", "printing-technology"), "stone-wall should not require printing-technology")

  assert_pack_superset("board-meetings", "public-finance")
  assert_pack_superset("executive-review", "health-and-safety")
  assert_pack_superset("information-management", "advanced-circuit")
  assert_pack_superset("environmental-compliance", "fluid-handling")
  assert_pack_superset("environmental-compliance", "steel-processing")
  assert_pack_superset("radiological-compliance", "battery")
  assert_pack_superset("vagrancy-ordinances", "constitutional-law")

  if technologies["after-hours-operations"] then
    assert_true(tech_has_prereq("after-hours-operations", "federal-regulation"), "after-hours-operations should require federal-regulation")
    assert_true(tech_has_prereq("after-hours-operations", "utility-science-pack"), "after-hours-operations should require utility science")
    assert_pack_superset("after-hours-operations", "federal-regulation")
  end
end)

test("only pneumatic capacity upgrades depend on pneumatic form transport", function()
  for tech_name, tech in pairs(data.raw.technology) do
    for _, prereq in ipairs(tech.prerequisites or {}) do
      if prereq == "pneumatic-form-transport" then
        assert_true(tech_name == "pneumatic-capacity-1", tech_name .. " should not require pneumatic-form-transport")
      end
    end
  end
end)

test("vanilla branches gain the required bureaucracy prerequisites", function()
  assert_true(tech_unlocks_recipe("railway", "transit-authorization-production"), "railway should unlock transit authorizations")
  assert_true(tech_has_prereq("railway", "verbal-approvals"), "railway should require verbal-approvals")
  assert_true(tech_has_prereq("railway", "local-precedents"), "railway should require local-precedents")

  assert_true(tech_has_prereq("advanced-material-processing-2", "verbal-approvals"), "advanced-material-processing-2 should require verbal-approvals")
  assert_true(tech_has_prereq("solar-energy", "verbal-approvals"), "solar-energy should require verbal-approvals")
  assert_true(tech_has_prereq("electric-energy-accumulators", "verbal-approvals"), "accumulators should require verbal-approvals")
  assert_true(tech_has_prereq("construction-robotics", "verbal-approvals"), "construction-robotics should require verbal-approvals")
  assert_true(tech_has_prereq("logistic-robotics", "verbal-approvals"), "logistic-robotics should require verbal-approvals")
  assert_true(tech_has_prereq("personal-roboport-equipment", "verbal-approvals"), "personal-roboport-equipment should require verbal-approvals")
  assert_true(tech_has_prereq("personal-roboport-mk2-equipment", "verbal-approvals"), "personal-roboport-mk2-equipment should require verbal-approvals")
  assert_true(tech_has_prereq("construction-robotics", "utility-science-pack"), "construction-robotics should explicitly require utility science")
  assert_true(tech_has_prereq("logistic-robotics", "utility-science-pack"), "logistic-robotics should explicitly require utility science")
  assert_true(tech_has_prereq("personal-roboport-equipment", "utility-science-pack"), "personal-roboport-equipment should explicitly require utility science")
  assert_true(tech_has_prereq("robotics", "federal-regulation"), "robotics should be delayed to the production-era bureaucracy branch")
  assert_true(tech_unlocks_recipe("robotics", "flying-robot-frame"), "robotics should still own robot frames")
  assert_true(tech_depends_on("construction-robotics", "federal-regulation"), "construction robots should be late-game")
  assert_true(tech_depends_on("logistic-robotics", "federal-regulation"), "logistic robots should be late-game")
  assert_true(tech_depends_on("personal-roboport-equipment", "federal-regulation"), "personal roboports should be late-game")

  assert_true(tech_has_prereq("oil-processing", "environmental-compliance"), "oil-processing should require environmental-compliance")

  assert_true(tech_has_prereq("automation-3", "executive-review"), "automation-3 should require executive-review")
  assert_true(tech_has_prereq("effect-transmission", "executive-review"), "effect-transmission should require executive-review")
  assert_true(tech_has_prereq("nuclear-power", "executive-review"), "nuclear-power should require executive-review")
  assert_true(tech_has_prereq("uranium-processing", "radiological-compliance"), "uranium-processing should require radiological-compliance")
  assert_true(tech_has_prereq("uranium-processing", "nuclear-technician-training"), "uranium-processing should require nuclear technician training for centrifuge technicians")
  assert_true(tech_has_prereq("rocket-silo", "executive-review"), "rocket-silo should require executive-review")
  assert_true(tech_has_prereq("hired-biter-fieldwork", "executive-review"), "hired biter fieldwork should require written management work orders")
  assert_true(tech_has_prereq("power-armor-mk2", "utility-science-pack"), "power armor mk2 should require utility science explicitly")
end)

test("vanilla children inherit the science packs of their bureaucracy parents", function()
  assert_pack_superset("railway", "verbal-approvals")
  assert_pack_superset("advanced-material-processing-2", "verbal-approvals")
  assert_pack_superset("solar-energy", "verbal-approvals")
  assert_pack_superset("electric-energy-accumulators", "verbal-approvals")
  assert_pack_superset("construction-robotics", "verbal-approvals")
  assert_pack_superset("logistic-robotics", "verbal-approvals")
  assert_pack_superset("personal-roboport-equipment", "verbal-approvals")
  assert_pack_superset("personal-roboport-mk2-equipment", "verbal-approvals")
  assert_pack_superset("robotics", "federal-regulation")
  assert_pack_superset("oil-processing", "environmental-compliance")
  assert_pack_superset("automation-3", "executive-review")
  assert_pack_superset("effect-transmission", "executive-review")
  assert_pack_superset("nuclear-power", "executive-review")
  assert_pack_superset("uranium-processing", "radiological-compliance")
  assert_pack_superset("rocket-silo", "executive-review")
end)

print(("Technology gating tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
