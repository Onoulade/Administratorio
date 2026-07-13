-------------------------------------------------------------------------------
-- ADMINISTRATORIO SPACE AGE CONTENT TESTS
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

local function assert_true(value, msg)
  if not value then error(msg or "assertion failed", 2) end
end

local recipes = {
  foundry = {type = "recipe", name = "foundry", ingredients = {{type = "item", name = "steel-plate", amount = 50}}},
  ["tungsten-plate"] = {type = "recipe", name = "tungsten-plate", ingredients = {{type = "item", name = "tungsten-ore", amount = 4}}},
  ["tungsten-carbide"] = {type = "recipe", name = "tungsten-carbide", ingredients = {{type = "item", name = "tungsten-plate", amount = 2}}},
  ["casting-low-density-structure"] = {type = "recipe", name = "casting-low-density-structure", ingredients = {{type = "item", name = "plastic-bar", amount = 20}}},
  ["advanced-circuit"] = {type = "recipe", name = "advanced-circuit", ingredients = {{type = "item", name = "electronic-circuit", amount = 2}}},
  ["low-density-structure"] = {type = "recipe", name = "low-density-structure", ingredients = {{type = "item", name = "steel-plate", amount = 10}}},
  ["rocket-control-unit"] = {type = "recipe", name = "rocket-control-unit", ingredients = {{type = "item", name = "processing-unit", amount = 1}}},
  ["rocket-silo"] = {type = "recipe", name = "rocket-silo", ingredients = {{type = "item", name = "steel-plate", amount = 100}}},
  ["molten-iron"] = {type = "recipe", name = "molten-iron", ingredients = {{type = "item", name = "calcite", amount = 1}}},
  ["molten-iron-from-lava"] = {type = "recipe", name = "molten-iron-from-lava", ingredients = {{type = "item", name = "calcite", amount = 1}}},
  ["molten-copper"] = {type = "recipe", name = "molten-copper", ingredients = {{type = "item", name = "calcite", amount = 1}}},
  ["molten-copper-from-lava"] = {type = "recipe", name = "molten-copper-from-lava", ingredients = {{type = "item", name = "calcite", amount = 1}}},
  ["simple-coal-liquefaction"] = {type = "recipe", name = "simple-coal-liquefaction", ingredients = {{type = "item", name = "calcite", amount = 1}}},
  ["acid-neutralisation"] = {type = "recipe", name = "acid-neutralisation", ingredients = {{type = "item", name = "calcite", amount = 1}}},
  ["rocket-fuel-from-jelly"] = {type = "recipe", name = "rocket-fuel-from-jelly", ingredients = {{type = "item", name = "jelly", amount = 1}}},
  ["bioplastic"] = {type = "recipe", name = "bioplastic", ingredients = {{type = "item", name = "bioflux", amount = 1}}},
  ["biosulfur"] = {type = "recipe", name = "biosulfur", ingredients = {{type = "item", name = "bioflux", amount = 1}}},
  ["biolubricant"] = {type = "recipe", name = "biolubricant", ingredients = {{type = "item", name = "bioflux", amount = 1}}},
  biochamber = {type = "recipe", name = "biochamber", ingredients = {{type = "item", name = "iron-plate", amount = 20}}},
  ["electromagnetic-plant"] = {type = "recipe", name = "electromagnetic-plant", ingredients = {{type = "item", name = "holmium-plate", amount = 150}}},
  ["cryogenic-plant"] = {type = "recipe", name = "cryogenic-plant", ingredients = {{type = "item", name = "lithium-plate", amount = 20}}},
  ["scrap-recycling"] = {type = "recipe", name = "scrap-recycling", results = {{type = "item", name = "iron-gear-wheel", amount = 1, probability = 0.2}}},
}

local items = {}
local ammos = {}
local fluids = {}
local signals = {}
local technologies = {
  ["administrative-science-research"] = {type = "technology", name = "administrative-science-research", effects = {}},
  ["metallurgic-science-pack"] = {type = "technology", name = "metallurgic-science-pack", effects = {}},
  ["calcite-processing"] = {type = "technology", name = "calcite-processing", effects = {}},
  ["printing-technology"] = {type = "technology", name = "printing-technology", effects = {}},
  ["industrial-propaganda"] = {type = "technology", name = "industrial-propaganda", effects = {}},
  ["corporate-hospitality"] = {type = "technology", name = "corporate-hospitality", effects = {}},
  ["agricultural-science-pack"] = {type = "technology", name = "agricultural-science-pack", effects = {}},
  ["electromagnetic-plant"] = {type = "technology", name = "electromagnetic-plant", effects = {}},
  ["electromagnetic-science-pack"] = {type = "technology", name = "electromagnetic-science-pack", effects = {}},
  ["cryogenic-science-pack"] = {type = "technology", name = "cryogenic-science-pack", effects = {}},
  ["after-hours-operations"] = {type = "technology", name = "after-hours-operations", effects = {}},
  ["discovery-redundant-rubble"] = {type = "technology", name = "discovery-redundant-rubble", effects = {}},
  ["nest-expropriation"] = {type = "technology", name = "nest-expropriation", effects = {}},
  ["hired-biter-fieldwork"] = {type = "technology", name = "hired-biter-fieldwork", effects = {}},
}

mods = {
  ["space-age"] = "2.0.0",
}

data = {
  raw = {
    recipe = recipes,
    item = items,
    ammo = ammos,
    fluid = fluids,
    ["virtual-signal"] = signals,
    furnace = {
      recycler = {type = "furnace", name = "recycler", result_inventory_size = 12},
    },
    technology = technologies,
  },
}

function data:extend(prototypes)
  for _, proto in ipairs(prototypes) do
    data.raw[proto.type] = data.raw[proto.type] or {}
    data.raw[proto.type][proto.name] = proto
    if proto.type == "recipe" then
      recipes[proto.name] = proto
    elseif proto.type == "item" then
      items[proto.name] = proto
    elseif proto.type == "ammo" then
      ammos[proto.name] = proto
    elseif proto.type == "fluid" then
      fluids[proto.name] = proto
    elseif proto.type == "virtual-signal" then
      signals[proto.name] = proto
    elseif proto.type == "technology" then
      technologies[proto.name] = proto
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

package.loaded["scripts.fax_shared"] = nil
local fax_shared = require("scripts.fax_shared")

dofile(mod_root .. "prototypes/item/space_age.lua")
dofile(mod_root .. "prototypes/item/capsules-and-fluids.lua")
dofile(mod_root .. "prototypes/recipe/space_age.lua")
dofile(mod_root .. "prototypes/recipe/planetary_abundance.lua")
dofile(mod_root .. "prototypes/technology/space_age.lua")
dofile(mod_root .. "prototypes/signals.lua")

local function has_ingredient(recipe, item_name)
  if not recipe or not recipe.ingredients then return false end
  for _, ingredient in ipairs(recipe.ingredients) do
    if (ingredient.name or ingredient[1]) == item_name then
      return true
    end
  end
  return false
end

local function has_result(recipe, item_name)
  if not recipe or not recipe.results then return false end
  for _, result in ipairs(recipe.results) do
    if (result.name or result[1]) == item_name then
      return true
    end
  end
  return false
end

local function get_result_amount(recipe, item_name)
  if not recipe or not recipe.results then return nil end
  for _, result in ipairs(recipe.results) do
    if (result.name or result[1]) == item_name then
      return result.amount or result[2]
    end
  end
  return nil
end

local function item_result_count(recipe)
  local count = 0
  if not recipe or not recipe.results then return count end
  for _, result in ipairs(recipe.results) do
    if (result.type or "item") == "item" then
      count = count + 1
    end
  end
  return count
end

local function get_result_probability(recipe, item_name)
  if not recipe or not recipe.results then return nil end
  for _, result in ipairs(recipe.results) do
    if (result.name or result[1]) == item_name then
      return result.probability or 1
    end
  end
  return nil
end

local function tech_unlocks_recipe(technology, recipe_name)
  if not technology or not technology.effects then return false end
  for _, effect in ipairs(technology.effects) do
    if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
      return true
    end
  end
  return false
end

local function has_fluid_ingredient(recipe, fluid_name)
  if not recipe or not recipe.ingredients then return false end
  for _, ingredient in ipairs(recipe.ingredients) do
    if ingredient.type == "fluid" and ingredient.name == fluid_name then
      return true
    end
  end
  return false
end

local function get_fluid_ingredient_amount(recipe, fluid_name)
  if not recipe or not recipe.ingredients then return nil end
  for _, ingredient in ipairs(recipe.ingredients) do
    if ingredient.type == "fluid" and ingredient.name == fluid_name then
      return ingredient.amount
    end
  end
  return nil
end

local function get_item_ingredient_amount(recipe, item_name)
  if not recipe or not recipe.ingredients then return nil end
  for _, ingredient in ipairs(recipe.ingredients) do
    if (ingredient.type or "item") == "item" and (ingredient.name or ingredient[1]) == item_name then
      return ingredient.amount or ingredient[2]
    end
  end
  return nil
end

local PLANET_SURFACE_CONDITIONS = {
  nauvis = {pressure = 1000, gravity = 10},
  vulcanus = {pressure = 4000, gravity = 40},
  gleba = {pressure = 2000, gravity = 20},
  fulgora = {pressure = 800, gravity = 8},
  aquilo = {pressure = 300, gravity = 15},
}

local function exact_surface_planet(recipe)
  local conditions = recipe and recipe.surface_conditions or nil
  if not conditions then return nil end

  local pressure_min, pressure_max, gravity_min, gravity_max
  for _, condition in ipairs(conditions) do
    if condition.property == "pressure" then
      pressure_min = condition.min
      pressure_max = condition.max
    elseif condition.property == "gravity" then
      gravity_min = condition.min
      gravity_max = condition.max
    end
  end

  for planet_name, properties in pairs(PLANET_SURFACE_CONDITIONS) do
    if pressure_min == properties.pressure
      and pressure_max == properties.pressure
      and gravity_min == properties.gravity
      and gravity_max == properties.gravity
    then
      return planet_name
    end
  end

  return nil
end

test("worker-biter exists as the enrolled-to-workforce intermediate", function()
  assert_true(items["job-offer"] ~= nil, "job-offer missing")
  assert_true(items["enrolled-biter"] ~= nil, "enrolled-biter missing")
  assert_true(items["worker-biter"] ~= nil, "worker-biter missing")
  assert_true(recipes["job-offer-production"] ~= nil, "job-offer recipe missing")
  assert_eq(recipes["job-offer-production"].category, "bureaucracy-policy", "job-offer should be drafted through policy bureaucracy")
  assert_true(has_ingredient(recipes["job-offer-production"], "treasury-bond"), "job-offer should require treasury-bonds")
  assert_true(has_ingredient(recipes["job-offer-production"], "taxpayer-money"), "job-offer should require taxpayer-money")
  assert_true(has_ingredient(recipes["job-offer-production"], "narrative"), "job-offer should require narrative")
  assert_true(recipes["worker-biter-formation"] ~= nil, "worker-biter formation recipe missing")
  assert_true(has_ingredient(recipes["worker-biter-formation"], "enrolled-biter"), "worker-biter should come from enrolled-biter")
end)

test("trainee formation consumes worker-biter instead of enrolled-biter directly", function()
  assert_true(has_ingredient(recipes["clerical-trainee-formation"], "worker-biter"), "clerical trainee should require worker-biter")
  assert_true(not has_ingredient(recipes["clerical-trainee-formation"], "enrolled-biter"), "clerical trainee should not require enrolled-biter directly")
  assert_true(has_ingredient(recipes["management-trainee-formation"], "worker-biter"), "management trainee should require worker-biter")
  assert_true(not has_ingredient(recipes["management-trainee-formation"], "enrolled-biter"), "management trainee should not require enrolled-biter directly")
end)

test("workforce surface policy keeps seed roles Nauvis-bound and specialists portable", function()
  for _, recipe_name in ipairs({
    "job-offer-production",
    "worker-biter-formation",
    "management-trainee-formation",
    "licensed-notary-formation",
  }) do
    assert_eq(exact_surface_planet(recipes[recipe_name]), "nauvis", recipe_name .. " should stay Nauvis-bound")
  end

  for _, recipe_name in ipairs({
    "clerical-trainee-formation",
    "astronaut-formation",
    "conciliation-officer-formation",
    "relay-clerk-formation",
    "cryoprint-technician-formation",
    "middle-management-managing-manager-formation",
  }) do
    assert_true(recipes[recipe_name] ~= nil, recipe_name .. " missing")
    assert_true(recipes[recipe_name].surface_conditions == nil,
      recipe_name .. " should stay portable once the workforce seed and relevant science are available")
  end
end)

test("astronaut training unlocks the orbital admin station chain", function()
  local workforce = technologies["workforce-formation"]
  assert_true(items["astronaut"] ~= nil, "astronaut missing")
  assert_true(items["administrative-space-station"] ~= nil, "administrative-space-station missing")
  assert_true(recipes["astronaut-formation"] ~= nil, "astronaut formation recipe missing")
  assert_true(has_ingredient(recipes["astronaut-formation"], "management-trainee"), "astronaut should require management-trainee")
  assert_true(recipes["administrative-space-station"] ~= nil, "administrative-space-station recipe missing")
  assert_true(has_ingredient(recipes["administrative-space-station"], "astronaut"),
    "administrative-space-station should require astronaut staffing")
  assert_true(tech_unlocks_recipe(workforce, "astronaut-formation"), "workforce-formation should unlock astronaut-formation")
  assert_true(tech_unlocks_recipe(workforce, "administrative-space-station"),
    "workforce-formation should unlock administrative-space-station")
  assert_eq(recipes["administrative-space-station"].surface_conditions[1].max, 0,
    "administrative-space-station should be craftable only in vacuum")
end)

test("native Space Age buildings consume planet-specific specialists", function()
  assert_true(has_ingredient(recipes["foundry"], "licensed-notary"), "foundry should require licensed-notary")
  assert_true(has_ingredient(recipes["foundry"], "tungsten-carbide"), "foundry should require tungsten-carbide")
  assert_true(not has_ingredient(recipes["foundry"], "offworld-metallurgy-charter"), "home-planet foundry should not require offworld-metallurgy-charter")
  assert_true(has_ingredient(recipes["foundry-offworld"], "licensed-notary"), "offworld foundry should still require licensed-notary")
  assert_true(has_ingredient(recipes["foundry-offworld"], "tungsten-carbide"), "offworld foundry should require tungsten-carbide")
  assert_true(has_ingredient(recipes["foundry-offworld"], "offworld-metallurgy-charter"), "offworld foundry should require offworld-metallurgy-charter")
  assert_true(has_ingredient(recipes["notary-office"], "licensed-notary"), "notary-office should require licensed-notary")
  assert_true(has_ingredient(recipes["territorial-arbitration-post"], "licensed-notary"),
    "territorial-arbitration-post should require licensed-notary")
  assert_true(has_ingredient(recipes["notary-office"], "tungsten-carbide"), "notary-office should require tungsten-carbide")
  assert_eq(exact_surface_planet(recipes["notary-office"]), "vulcanus", "notary-office should be crafted on Vulcanus")
  assert_true(has_ingredient(recipes["biochamber"], "conciliation-officer"), "biochamber should require conciliation-officer")
  assert_true(has_ingredient(recipes["electromagnetic-plant"], "relay-clerk"), "electromagnetic-plant should require relay-clerk")
  assert_true(has_ingredient(recipes["cryogenic-plant"], "cryoprint-technician"), "cryogenic-plant should require cryoprint-technician")
end)

test("chromatic printing unlocks the base chromatic chains across planets", function()
  local chromatic = technologies["chromatic-printing"]
  assert_true(chromatic ~= nil, "chromatic-printing missing")
  for _, recipe_name in ipairs({
    "chromatic-printer",
    "liquid-black-ink",
    "dubious-data-analysis-vulcanus",
    "cyan-slurry-production",
    "cyan-ink-production",
    "heatproof-form-stock",
    "blank-cyan-form-production",
    "charged-toner",
    "archive-rubble-recovery",
    "archive-documentation-recovery",
    "magenta-ink-production",
    "signal-form-stock",
    "blank-magenta-form-production",
    "permit-draft",
    "inspection-docket",
  }) do
    assert_true(tech_unlocks_recipe(chromatic, recipe_name), "chromatic-printing should unlock " .. recipe_name)
  end
end)

test("vulcanus early bootstrap unlocks local dubious data and research grants before chromatic printing", function()
  local calcite = technologies["calcite-processing"]
  local admin_research = technologies["administrative-science-research"]
  local printing = technologies["printing-technology"]
  assert_true(calcite ~= nil, "calcite-processing missing")
  assert_true(admin_research ~= nil, "administrative-science-research missing")
  assert_true(printing ~= nil, "printing-technology missing")
  assert_true(tech_unlocks_recipe(calcite, "dubious-data-analysis-vulcanus"), "calcite-processing should unlock dubious-data-analysis-vulcanus")
  assert_true(tech_unlocks_recipe(calcite, "paper-production-vulcanus"), "calcite-processing should unlock paper-production-vulcanus")
  assert_true(tech_unlocks_recipe(calcite, "carbon-offset-certificate-basic-vulcanus"), "calcite-processing should unlock carbon-offset-certificate-basic-vulcanus")
  assert_true(tech_unlocks_recipe(admin_research, "research-grant-approval-vulcanus"), "administrative-science-research should unlock research-grant-approval-vulcanus")
  assert_true(tech_unlocks_recipe(admin_research, "administrative-science-pack-production-vulcanus"), "administrative-science-research should unlock administrative-science-pack-production-vulcanus")
  assert_true(tech_unlocks_recipe(printing, "printer-t1-vulcanus"), "printing-technology should unlock printer-t1-vulcanus")
end)

test("vulcanus certification unlocks the notary office and fallback paperwork", function()
  local certification = technologies["vulcanus-certification"]
  assert_true(certification ~= nil, "vulcanus-certification missing")
  for _, recipe_name in ipairs({
    "notary-office",
    "territorial-arbitration-post",
    "embossed-seal",
    "industrial-charter",
    "territorial-resettlement-order",
    "good-excuse-vulcanus",
    "safety-waiver-vulcanus",
    "construction-permit-vulcanus",
    "management-approval-verbal-vulcanus",
    "heatproof-filler-documentation",
    "form-27b-6-vulcanus",
    "vulcanus-lie-distillation",
  }) do
    assert_true(tech_unlocks_recipe(certification, recipe_name), "vulcanus-certification should unlock " .. recipe_name)
  end
  assert_true(not tech_unlocks_recipe(certification, "thermal-process-license"),
    "vulcanus-certification should no longer unlock thermal-process-license")
  assert_true(not tech_unlocks_recipe(certification, "calcite-reagent-waiver"),
    "vulcanus-certification should no longer unlock calcite-reagent-waiver")
  assert_true(not tech_unlocks_recipe(certification, "offworld-metallurgy-charter"),
    "vulcanus-certification should no longer unlock offworld-metallurgy-charter")
end)

test("vulcanus export charters split the later metallurgy paperwork", function()
  local export_charters = technologies["vulcanus-export-charters"]
  assert_true(export_charters ~= nil, "vulcanus-export-charters missing")
  assert_true(export_charters.prerequisites ~= nil, "vulcanus-export-charters should have prerequisites")

  local prerequisite_set = {}
  for _, prerequisite in ipairs(export_charters.prerequisites) do
    prerequisite_set[prerequisite] = true
  end

  assert_true(prerequisite_set["vulcanus-certification"], "vulcanus-export-charters should depend on vulcanus-certification")
  assert_true(prerequisite_set["metallurgic-science-pack"], "vulcanus-export-charters should depend on metallurgic-science-pack")

  for _, recipe_name in ipairs({
    "thermal-process-license",
    "calcite-reagent-waiver",
    "offworld-metallurgy-charter",
  }) do
    assert_true(tech_unlocks_recipe(export_charters, recipe_name), "vulcanus-export-charters should unlock " .. recipe_name)
  end
end)

test("vulcanus chromatic chain defines the expected fluids and fluid-fed recipes", function()
  assert_true(fluids["liquid-black-ink"] ~= nil, "liquid-black-ink missing")
  assert_true(fluids["cyan-slurry"] ~= nil, "cyan-slurry missing")
  assert_true(fluids["cyan-ink"] ~= nil, "cyan-ink missing")
  assert_true(fluids["liquid-stimulant"] ~= nil, "liquid-stimulant missing")
  assert_true(fluids["molten-promises"] ~= nil, "molten-promises missing")
  assert_true(fluids["yellow-ink"] ~= nil, "yellow-ink missing")
  assert_true(fluids["magenta-ink"] ~= nil, "magenta-ink missing")

  assert_true(has_fluid_ingredient(recipes["heatproof-form-stock"], "cyan-ink"), "heatproof-form-stock should consume cyan-ink")
  assert_true(not has_fluid_ingredient(recipes["heatproof-form-stock"], "sulfuric-acid"), "heatproof-form-stock should stay printer-only")
  assert_true(has_fluid_ingredient(recipes["blank-cyan-form-production"], "cyan-ink"), "blank-cyan-form should consume cyan-ink")
  assert_true(has_fluid_ingredient(recipes["permit-draft"], "cyan-ink"), "permit-draft should consume cyan-ink")
  assert_true(has_fluid_ingredient(recipes["inspection-docket"], "cyan-ink"), "inspection-docket should consume cyan-ink")
  assert_true(has_fluid_ingredient(recipes["management-approval-verbal-vulcanus"], "liquid-coffee"), "verbal approval notary shortcut should consume liquid-coffee")
  assert_true(has_fluid_ingredient(recipes["vulcanus-lie-distillation"], "molten-promises"), "lie distillation should consume molten-promises")
end)

test("vulcanus chemistry unlocks local stimulant and paper shortcuts", function()
  local calcite = technologies["calcite-processing"]
  local propaganda = technologies["industrial-propaganda"]
  assert_true(calcite ~= nil, "calcite-processing missing")
  assert_true(propaganda ~= nil, "industrial-propaganda missing")
  for _, recipe_name in ipairs({
    "liquid-stimulant-production",
    "liquid-coffee-vulcanus",
    "plastic-bar-vulcanus",
    "heatproof-paper-production",
    "molten-promises-production",
  }) do
    assert_true(tech_unlocks_recipe(calcite, recipe_name), "calcite-processing should unlock " .. recipe_name)
  end
  for _, recipe_name in ipairs({
    "refined-nonsense-production-vulcanus",
  }) do
    assert_true(tech_unlocks_recipe(propaganda, recipe_name), "industrial-propaganda should unlock " .. recipe_name)
  end
  for _, recipe_name in ipairs({
    "liquid-stimulant-production",
    "liquid-coffee-vulcanus",
    "plastic-bar-vulcanus",
    "heatproof-paper-production",
  }) do
    assert_true(not has_ingredient(recipes[recipe_name], "chemical-handling-work-order"), recipe_name .. " should stay bootstrap-safe on Vulcanus")
  end
end)

test("off-world vulcanus anchor recipes require shipped chromatic paperwork", function()
  assert_true(not has_ingredient(recipes["tungsten-plate"], "thermal-process-license"), "home-planet tungsten-plate should not require thermal-process-license")
  assert_true(not has_ingredient(recipes["tungsten-carbide"], "thermal-process-license"), "home-planet tungsten-carbide should not require thermal-process-license")
  assert_true(has_ingredient(recipes["tungsten-plate-offworld"], "thermal-process-license"), "tungsten-plate-offworld should require thermal-process-license")
  assert_true(has_ingredient(recipes["tungsten-carbide-offworld"], "thermal-process-license"), "tungsten-carbide-offworld should require thermal-process-license")
  assert_true(not has_ingredient(recipes["casting-low-density-structure"], "offworld-metallurgy-charter"), "home-planet LDS casting should not require offworld-metallurgy-charter")
  assert_true(has_ingredient(recipes["casting-low-density-structure-offworld"], "offworld-metallurgy-charter"), "casting-low-density-structure-offworld should require offworld-metallurgy-charter")
  for _, recipe_name in ipairs({
    "molten-iron-offworld",
    "molten-iron-from-lava-offworld",
    "molten-copper-offworld",
    "molten-copper-from-lava-offworld",
    "simple-coal-liquefaction-offworld",
    "acid-neutralisation-offworld",
  }) do
    assert_true(has_ingredient(recipes[recipe_name], "calcite-reagent-waiver"), recipe_name .. " should require calcite-reagent-waiver")
  end
  for _, recipe_name in ipairs({
    "molten-iron",
    "molten-iron-from-lava",
    "molten-copper",
    "molten-copper-from-lava",
    "simple-coal-liquefaction",
    "acid-neutralisation",
  }) do
    assert_true(not has_ingredient(recipes[recipe_name], "calcite-reagent-waiver"), recipe_name .. " should stay clean on Vulcanus")
  end
end)

test("workforce tech owns the workforce progression unlocks", function()
  local workforce = technologies["workforce-formation"]
  local chromatic = technologies["chromatic-printing"]
  local metallurgy = technologies["metallurgic-science-pack"]
  assert_true(workforce ~= nil, "workforce-formation missing")
  assert_true(tech_unlocks_recipe(workforce, "job-offer-production"), "workforce-formation should unlock job-offer-production")
  assert_true(tech_unlocks_recipe(workforce, "worker-biter-formation"), "workforce-formation should unlock worker-biter-formation")
  assert_true(tech_unlocks_recipe(workforce, "licensed-notary-formation"), "workforce-formation should unlock licensed-notary-formation")
  assert_true(not tech_unlocks_recipe(chromatic, "worker-biter"), "chromatic-printing should not directly unlock worker-biter")
  assert_true(not tech_unlocks_recipe(metallurgy, "licensed-notary-formation"),
    "metallurgic-science-pack should no longer unlock licensed-notary-formation")
  assert_eq(workforce.prerequisites[1], "space-science-pack", "workforce-formation should unlock after space science")
end)

test("field agent recipes reuse the base hired biter instead of duplicate Space Age roles", function()
  assert_true(recipes["overtime-exemption-staffed"] == nil, "staffed overtime recipe should be removed")
  assert_true(recipes["night-shift-supervisor-formation"] == nil, "night-shift supervisor should be removed")
  assert_true(recipes["field-negotiator-formation"] == nil, "field negotiator should be removed")

  assert_true(recipes["promise-production-negotiated"] ~= nil, "negotiated promise recipe missing")
  assert_true(has_ingredient(recipes["promise-production-negotiated"], "hired-biter-capsule"), "negotiated promise should require hired-biter-capsule")
  assert_true(tech_unlocks_recipe(technologies["hired-biter-fieldwork"], "promise-production-negotiated"), "hired-biter-fieldwork should unlock negotiated promise")

  assert_true(recipes["eviction-notice-production-negotiated"] ~= nil, "negotiated eviction recipe missing")
  assert_true(has_ingredient(recipes["eviction-notice-production-negotiated"], "hired-biter-capsule"), "negotiated eviction should require hired-biter-capsule")
  assert_true(tech_unlocks_recipe(technologies["hired-biter-fieldwork"], "eviction-notice-production-negotiated"), "hired-biter-fieldwork should unlock negotiated eviction")
end)

test("MMMM is converted into trajectory-compliance ammo and sink hardware", function()
  assert_true(ammos["middle-management-managing-manager"] ~= nil, "MMMM ammo missing")
  assert_eq(ammos["middle-management-managing-manager"].type, "ammo", "MMMM should be ammo-backed for trajectory compliance")
  assert_eq(ammos["middle-management-managing-manager"].ammo_category, "trajectory-compliance", "MMMM should feed trajectory-compliance arrays")
  assert_true(ammos["orbital-deviation-order"] ~= nil, "orbital deviation order ammo missing")
  assert_eq(ammos["orbital-deviation-order"].ammo_category, "trajectory-compliance",
    "orbital-deviation-order should also feed trajectory-compliance arrays")
  assert_true(recipes["trajectory-compliance-array"] ~= nil, "trajectory compliance array recipe missing")
  assert_true(tech_unlocks_recipe(technologies["workforce-formation"], "trajectory-compliance-array"), "workforce formation should unlock the compliance array")
end)

test("orbital admin station recipes cover offworld metallurgy and asteroid paperwork", function()
  local workforce = technologies["workforce-formation"]
  for _, recipe_name in ipairs({
    "thermal-process-license-orbital",
    "calcite-reagent-waiver-orbital",
    "offworld-metallurgy-charter-orbital",
    "orbital-deviation-order",
    "asteroid-processing-docket",
  }) do
    local recipe = assert(recipes[recipe_name], recipe_name .. " missing")
    assert_eq(recipe.category, "orbital-bureaucracy", recipe_name .. " should use orbital-bureaucracy")
    assert_eq(recipe.surface_conditions[1].max, 0, recipe_name .. " should stay vacuum-only")
    assert_true(has_ingredient(recipe, "astronaut"), recipe_name .. " should require astronaut staffing")
    assert_true(tech_unlocks_recipe(workforce, recipe_name), "workforce-formation should unlock " .. recipe_name)
  end
  assert_true(items["asteroid-processing-docket"] ~= nil, "asteroid-processing-docket missing")
end)

test("gleba conciliation unlocks the yellow chain and gleba specialist buildings", function()
  local gleba = technologies["gleba-conciliation"]
  assert_true(gleba ~= nil, "gleba-conciliation missing")
  for _, recipe_name in ipairs({
    "capture-bureau",
    "capture-bureau-pentapod-eggs",
    "conciliation-desk",
    "yellow-ink-production",
    "mycelial-form-stock",
    "blank-yellow-form-production",
    "symbiosis-record",
    "conciliation-order",
    "biochamber-operating-waiver",
  }) do
    assert_true(tech_unlocks_recipe(gleba, recipe_name), "gleba-conciliation should unlock " .. recipe_name)
  end
  for _, prerequisite in ipairs(gleba.prerequisites or {}) do
    assert_true(prerequisite ~= "agricultural-science-pack",
      "gleba-conciliation must bootstrap before agricultural science needs eggs")
  end
end)

test("gleba yellow paperwork gates orbital spitter tourism with two-color forms", function()
  local gleba = technologies["gleba-conciliation"]
  local expected = {
    {
      package_item = "small-spitter-tourism-package",
      tourist_item = "small-space-tourist",
      tourism_recipe = "small-spitter-space-tourism",
      jettison_recipe = "small-space-tourist-jettison",
      payout = 75,
    },
    {
      package_item = "medium-spitter-tourism-package",
      tourist_item = "medium-space-tourist",
      tourism_recipe = "medium-spitter-space-tourism",
      jettison_recipe = "medium-space-tourist-jettison",
      payout = 175,
    },
    {
      package_item = "big-spitter-tourism-package",
      tourist_item = "big-space-tourist",
      tourism_recipe = "big-spitter-space-tourism",
      jettison_recipe = "big-space-tourist-jettison",
      payout = 450,
    },
    {
      package_item = "behemoth-spitter-tourism-package",
      tourist_item = "behemoth-space-tourist",
      tourism_recipe = "behemoth-spitter-space-tourism",
      jettison_recipe = "behemoth-space-tourist-jettison",
      payout = 1200,
    },
  }

  for _, variant in ipairs(expected) do
    assert_true(items[variant.package_item] ~= nil, variant.package_item .. " missing")
    assert_true(items[variant.tourist_item] ~= nil, variant.tourist_item .. " missing")

    local tourism_recipe = assert(recipes[variant.tourism_recipe], variant.tourism_recipe .. " missing")
    assert_eq(tourism_recipe.category, "orbital-bureaucracy", variant.tourism_recipe .. " should use orbital-bureaucracy")
    assert_eq(tourism_recipe.surface_conditions[1].max, 0, variant.tourism_recipe .. " should stay vacuum-only")
    assert_true(has_ingredient(tourism_recipe, variant.package_item), variant.tourism_recipe .. " should consume the packaged spitter")
    assert_true(has_ingredient(tourism_recipe, "astronaut"), variant.tourism_recipe .. " should require astronaut staffing")
    assert_true(has_ingredient(tourism_recipe, "transit-authorization"), variant.tourism_recipe .. " should require transit authorization")
    assert_true(not has_ingredient(tourism_recipe, "cyan-yellow-form"), variant.tourism_recipe .. " should not require cyan-yellow-form directly in orbit")
    assert_true(has_result(tourism_recipe, variant.tourist_item), variant.tourism_recipe .. " should emit a paid tourist")
    assert_eq(get_result_amount(tourism_recipe, "taxpayer-money"), variant.payout, variant.tourism_recipe .. " should pay the expected amount")
    assert_true(tech_unlocks_recipe(technologies["cyan-yellow-bureaucracy"], variant.tourism_recipe), "cyan-yellow-bureaucracy should unlock " .. variant.tourism_recipe)

    local jettison_recipe = assert(recipes[variant.jettison_recipe], variant.jettison_recipe .. " missing")
    assert_eq(jettison_recipe.category, "orbital-bureaucracy", variant.jettison_recipe .. " should use orbital-bureaucracy")
    assert_eq(jettison_recipe.surface_conditions[1].max, 0, variant.jettison_recipe .. " should stay vacuum-only")
    assert_true(has_ingredient(jettison_recipe, variant.tourist_item), variant.jettison_recipe .. " should consume the tourist")
    assert_true(has_result(jettison_recipe, "useless-documentation"), variant.jettison_recipe .. " should leave liability paperwork behind")
    assert_true(tech_unlocks_recipe(technologies["cyan-yellow-bureaucracy"], variant.jettison_recipe), "cyan-yellow-bureaucracy should unlock " .. variant.jettison_recipe)
  end
end)

test("capture bureau mode recipes split by surface and role", function()
  local workforce = assert(recipes["capture-bureau-workforce"], "capture-bureau-workforce missing")
  local tourism = assert(recipes["capture-bureau-tourism"], "capture-bureau-tourism missing")
  local pentapods = assert(recipes["capture-bureau-pentapod-eggs"], "capture-bureau-pentapod-eggs missing")
  local spore_base = assert(recipes["hostile-spore-culture-production"], "hostile-spore-culture-production missing")
  local workforce_spores = assert(recipes["workforce-lure-spores-production"], "workforce-lure-spores-production missing")
  local tourism_spores = assert(recipes["tourism-lure-spores-production"], "tourism-lure-spores-production missing")
  local egg_spores = assert(recipes["oviposition-lure-spores-production"], "oviposition-lure-spores-production missing")
  local cyan_yellow = technologies["cyan-yellow-bureaucracy"]

  assert_eq(workforce.category, "hostile-acquisition", "workforce mode should use hostile-acquisition")
  assert_eq(tourism.category, "hostile-acquisition", "tourism mode should use hostile-acquisition")
  assert_eq(pentapods.category, "hostile-acquisition", "pentapod mode should use hostile-acquisition")
  assert_true(fluids["hostile-spore-culture"] ~= nil, "hostile-spore-culture missing")
  assert_true(fluids["workforce-lure-spores"] ~= nil, "workforce-lure-spores missing")
  assert_true(fluids["tourism-lure-spores"] ~= nil, "tourism-lure-spores missing")
  assert_true(fluids["oviposition-lure-spores"] ~= nil, "oviposition-lure-spores missing")
  assert_eq(fluids["workforce-lure-spores"].auto_barrel, false,
    "workforce lure spores should not be barrelable")
  assert_eq(fluids["tourism-lure-spores"].auto_barrel, false,
    "tourism lure spores should not be barrelable")
  assert_eq(fluids["oviposition-lure-spores"].auto_barrel, false,
    "egg lure spores should not be barrelable")

  assert_eq(exact_surface_planet(workforce), "nauvis", "workforce mode should stay on Nauvis")
  assert_eq(exact_surface_planet(tourism), "nauvis", "tourism mode should stay on Nauvis")
  assert_eq(exact_surface_planet(pentapods), "gleba", "pentapod mode should stay on Gleba")
  assert_eq(exact_surface_planet(spore_base), "gleba", "spore culture base should stay on Gleba")
  assert_eq(spore_base.category, "organic", "spore culture should be Biochamber-only")
  assert_eq(workforce_spores.category, "organic", "workforce lure spores should be Biochamber-only")
  assert_eq(tourism_spores.category, "organic", "tourism lure spores should be Biochamber-only")
  assert_eq(egg_spores.category, "organic", "egg lure spores should be Biochamber-only")
  assert_true(has_fluid_ingredient(workforce_spores, "hostile-spore-culture"),
    "workforce lure spores should consume Gleba spore culture")
  assert_true(has_fluid_ingredient(tourism_spores, "hostile-spore-culture"),
    "tourism lure spores should consume Gleba spore culture")
  assert_true(has_fluid_ingredient(egg_spores, "hostile-spore-culture"),
    "egg lure spores should consume Gleba spore culture")
  assert_true(not has_ingredient(egg_spores, "agricultural-science-pack"),
    "egg lure spores should not require the agricultural science that needs eggs")
  assert_true(recipes["manual-pentapod-egg-foraging"] == nil,
    "eggs should not be craftable from ingredients; bootstrap comes from bribing wild pentapods with dropped money")
  assert_true(recipes["pentapod-egg-bounty"] == nil,
    "egg bootstrap should use loose taxpayer-money, not a dedicated crafted capsule")

  assert_true(tech_unlocks_recipe(technologies["workforce-formation"], "capture-bureau-workforce"),
    "workforce-formation should unlock capture-bureau-workforce")
  assert_true(tech_unlocks_recipe(technologies["workforce-formation"], "workforce-lure-spores-production"),
    "workforce-formation should unlock workforce lure spores")
  assert_true(has_ingredient(tourism, "cyan-yellow-form"),
    "tourism mode should consume cyan-yellow-form")
  assert_true(tech_unlocks_recipe(cyan_yellow, "capture-bureau-tourism"),
    "cyan-yellow-bureaucracy should unlock capture-bureau-tourism")
  assert_true(tech_unlocks_recipe(cyan_yellow, "tourism-lure-spores-production"),
    "cyan-yellow-bureaucracy should unlock tourism lure spores")
  assert_true(tech_unlocks_recipe(technologies["gleba-conciliation"], "capture-bureau-pentapod-eggs"),
    "gleba-conciliation should unlock capture-bureau-pentapod-eggs")
  assert_true(tech_unlocks_recipe(technologies["gleba-conciliation"], "hostile-spore-culture-production"),
    "gleba-conciliation should unlock spore culture")
  assert_true(tech_unlocks_recipe(technologies["gleba-conciliation"], "oviposition-lure-spores-production"),
    "gleba-conciliation should unlock egg lure spores")
end)

test("gleba chromatic chain defines amber sap and printer-fed yellow forms", function()
  assert_true(fluids["amber-sap"] ~= nil, "amber-sap missing")
  assert_true(fluids["yellow-ink"] ~= nil, "yellow-ink missing")
  assert_true(items["mycelial-form-stock"] ~= nil, "mycelial-form-stock missing")
  assert_true(items["blank-yellow-form"] ~= nil, "blank-yellow-form missing")
  assert_true(items["symbiosis-record"] ~= nil, "symbiosis-record missing")
  assert_true(items["conciliation-order"] ~= nil, "conciliation-order missing")
  assert_true(items["biochamber-operating-waiver"] ~= nil, "biochamber-operating-waiver missing")

  assert_true(has_fluid_ingredient(recipes["yellow-ink-production"], "amber-sap"), "yellow-ink should consume amber-sap")
  assert_true(has_ingredient(recipes["yellow-ink-production"], "nutrients"), "yellow-ink should consume nutrients")
  assert_true(has_fluid_ingredient(recipes["mycelial-form-stock"], "yellow-ink"), "mycelial-form-stock should consume yellow-ink")
  assert_true(has_fluid_ingredient(recipes["blank-yellow-form-production"], "yellow-ink"), "blank-yellow-form should consume yellow-ink")
end)

test("gleba adds targeted alternates instead of a duplicated paperwork ladder", function()
  for _, recipe_name in ipairs({
    "amber-sap-nonsense-seeding",
    "ink-production-gleba",
    "carbon-offset-certificate-basic-gleba",
    "admin-station-gleba",
    "printer-t1-gleba",
    "corporate-breakroom-gleba",
    "administrative-science-pack-production-gleba",
    "capture-bureau",
  }) do
    assert_true(recipes[recipe_name] ~= nil, recipe_name .. " missing")
  end

  assert_true(has_ingredient(recipes["capture-bureau"], "worker-biter"), "capture-bureau should require worker-biter")
  assert_true(has_ingredient(recipes["capture-bureau"], "construction-work-order"), "capture-bureau should require imported construction paperwork")
  assert_true(recipes["management-approval-written-gleba"] == nil, "management-approval-written-gleba should not exist")
  assert_true(recipes["management-approval-verbal-gleba"] == nil, "management-approval-verbal-gleba should not exist")
  assert_true(recipes["research-grant-approval-gleba"] == nil, "research-grant-approval-gleba should not exist")
  assert_true(recipes["form-27b-6-gleba"] == nil, "form-27b-6-gleba should not exist")
  assert_true(recipes["advanced-circuit-gleba"] == nil, "advanced-circuit-gleba should not exist")
  assert_true(recipes["low-density-structure-gleba"] == nil, "low-density-structure-gleba should not exist")
  assert_true(recipes["rocket-control-unit-gleba"] == nil, "rocket-control-unit-gleba should not exist")
  assert_true(recipes["rocket-silo-gleba"] == nil, "rocket-silo-gleba should not exist")
end)

test("gleba offworld bio variants require the operating waiver", function()
  for _, recipe_name in ipairs({
    "rocket-fuel-from-jelly-offworld",
    "bioplastic-offworld",
    "biosulfur-offworld",
    "biolubricant-offworld",
  }) do
    assert_true(recipes[recipe_name] ~= nil, recipe_name .. " missing")
    assert_true(has_ingredient(recipes[recipe_name], "biochamber-operating-waiver"),
      recipe_name .. " should require biochamber-operating-waiver")
  end
end)

test("fulgora digital services unlocks the bureau and finalized digital paperwork", function()
  local fulgora = technologies["fulgora-digital-services"]
  assert_true(fulgora ~= nil, "fulgora-digital-services missing")
  for _, recipe_name in ipairs({
    "digital-services-bureau",
    "archive-recovery-permit",
    "digital-processing-certificate",
    "electromagnetic-operating-license",
    "data-recovery-order",
  }) do
    assert_true(tech_unlocks_recipe(fulgora, recipe_name), "fulgora-digital-services should unlock " .. recipe_name)
  end
end)

test("fulgora magenta chain defines the expected forms and staffed bureau", function()
  assert_true(items["charged-toner"] ~= nil, "charged-toner missing")
  assert_true(items["signal-form-stock"] ~= nil, "signal-form-stock missing")
  assert_true(items["blank-magenta-form"] ~= nil, "blank-magenta-form missing")
  assert_true(items["archive-recovery-permit"] ~= nil, "archive-recovery-permit missing")
  assert_true(items["digital-processing-certificate"] ~= nil, "digital-processing-certificate missing")
  assert_true(items["electromagnetic-operating-license"] ~= nil, "electromagnetic-operating-license missing")
  assert_true(items["data-recovery-order"] ~= nil, "data-recovery-order missing")
  assert_true(items["digital-services-bureau"] ~= nil, "digital-services-bureau missing")

  assert_true(has_ingredient(recipes["digital-services-bureau"], "relay-clerk"),
    "digital-services-bureau should require relay-clerk")
  assert_true(has_ingredient(recipes["digital-services-bureau"], "holmium-plate"),
    "digital-services-bureau should require holmium-plate")
  assert_true(has_ingredient(recipes["charged-toner"], "scrap"), "charged-toner should recover from scrap")
  assert_true(not has_ingredient(recipes["charged-toner"], "useless-documentation"),
    "charged-toner should bootstrap directly from scrap")
  assert_true(has_ingredient(recipes["archive-rubble-recovery"], "scrap"),
    "archive-rubble-recovery should consume scrap")
  assert_true(has_ingredient(recipes["archive-documentation-recovery"], "charged-toner"),
    "archive-documentation-recovery should consume charged-toner")
  assert_true(has_ingredient(recipes["archive-documentation-recovery"], "scrap"),
    "archive-documentation-recovery should consume scrap")
  assert_true(has_fluid_ingredient(recipes["signal-form-stock"], "magenta-ink"),
    "signal-form-stock should consume magenta-ink")
  assert_true(has_fluid_ingredient(recipes["blank-magenta-form-production"], "magenta-ink"),
    "blank-magenta-form should consume magenta-ink")
  assert_true(has_ingredient(recipes["archive-recovery-permit"], "blank-magenta-form"),
    "archive-recovery-permit should consume blank-magenta-form")
  assert_true(has_ingredient(recipes["digital-processing-certificate"], "processing-unit"),
    "digital-processing-certificate should require processing-unit")
  assert_true(has_ingredient(recipes["electromagnetic-operating-license"], "digital-processing-certificate"),
    "electromagnetic-operating-license should require digital-processing-certificate")
  assert_true(has_ingredient(recipes["data-recovery-order"], "archive-recovery-permit"),
    "data-recovery-order should require archive-recovery-permit")
  assert_true(not has_ingredient(recipes["magenta-ink-production"], "taxpayer-money"),
    "magenta-ink-production should not require taxpayer-money")

  for _, result_name in ipairs({
    "charged-toner",
    "redundant-rubble",
    "useless-documentation",
    "old-archive",
  }) do
    assert_true(has_result(recipes["scrap-recycling"], result_name),
      "scrap-recycling should randomly recover " .. result_name)
    assert_true(get_result_probability(recipes["scrap-recycling"], result_name) < 1,
      result_name .. " should be a probabilistic Fulgora salvage output")
  end
  for _, finished_form in ipairs({
    "signal-form-stock",
    "blank-magenta-form",
    "archive-recovery-permit",
    "digital-processing-certificate",
    "electromagnetic-operating-license",
    "data-recovery-order",
  }) do
    assert_true(not has_result(recipes["scrap-recycling"], finished_form),
      "scrap should not bypass Fulgora processing by dropping " .. finished_form)
  end
  assert_true(data.raw.furnace["recycler"].result_inventory_size >= item_result_count(recipes["scrap-recycling"]),
    "recycler output inventory must fit the expanded scrap-recycling result table")
end)

test("fulgora archive and electrolyte bootstrap stays local", function()
  local electrolyte = assert(recipes["salvage-electrolyte-fulgora"], "salvage-electrolyte-fulgora missing")
  local archive_technology = assert(technologies["archive-recombination"], "archive-recombination missing")
  local electromagnetic_plant = assert(technologies["electromagnetic-plant"], "electromagnetic-plant missing")

  assert_eq(exact_surface_planet(electrolyte), "fulgora", "salvage electrolyte should stay on Fulgora")
  assert_true(has_fluid_ingredient(electrolyte, "holmium-solution"), "salvage electrolyte should use holmium solution")
  assert_true(has_fluid_ingredient(electrolyte, "water"), "salvage electrolyte should use water")
  assert_true(has_ingredient(electrolyte, "charged-toner"), "salvage electrolyte should use charged toner")
  assert_true(has_ingredient(electrolyte, "redundant-rubble"), "salvage electrolyte should use redundant rubble")
  assert_true(not has_fluid_ingredient(electrolyte, "crude-oil"), "salvage electrolyte should not import crude oil")
  assert_true(not has_fluid_ingredient(electrolyte, "heavy-oil"), "salvage electrolyte should not import heavy oil")
  assert_true(tech_unlocks_recipe(electromagnetic_plant, "salvage-electrolyte-fulgora"),
    "electromagnetic-plant should unlock the local electrolyte route")

  assert_true(archive_technology.unit == nil, "archive recombination should not require off-world science packs")
  assert_true(archive_technology.research_trigger ~= nil, "archive recombination should use a local craft trigger")
  assert_eq(archive_technology.research_trigger.item, "digital-processing-certificate",
    "archive recombination should be proven through Fulgora digital paperwork")
  assert_eq(archive_technology.research_trigger.count, 5,
    "archive recombination should require a meaningful local paperwork batch")
end)

test("aquilo fax network unlocks the printer, exchange, and multicolor paperwork", function()
  local aquilo = technologies["aquilo-fax-network"]
  assert_true(aquilo ~= nil, "aquilo-fax-network missing")
  for _, recipe_name in ipairs({
    "laser-printer",
    "fax-emitter",
    "interplanetary-fax-exchange",
    "transfer-emulsion-production",
    "thermal-transfer-sheet-production",
    "composite-chroma-ribbon-production",
    "trichromatic-permit-production",
    "unified-operations-charter-production",
    "cryogenic-operations-license-production",
    "promethium-research-charter-production",
  }) do
    assert_true(tech_unlocks_recipe(aquilo, recipe_name), "aquilo-fax-network should unlock " .. recipe_name)
  end
end)

test("fax reconstruction recipes use tiered dry media and split unlocks between basic and color faxing", function()
  local aquilo = assert(technologies["aquilo-fax-network"], "aquilo-fax-network missing")
  local color_faxing = assert(technologies["color-faxing"], "color-faxing missing")

  assert_eq(color_faxing.prerequisites[1], "aquilo-fax-network",
    "color-faxing should follow the base fax network unlock")

  for item_name in pairs(fax_shared.FAX_DOCUMENTS) do
    local recipe_name = fax_shared.reconstruction_recipe_name(item_name)
    local recipe = assert(recipes[recipe_name], recipe_name .. " missing")
    local requirements = fax_shared.get_reconstruction_requirements(item_name)
    local expected_tech = fax_shared.document_requires_color(item_name) and color_faxing or aquilo
    local unexpected_tech = fax_shared.document_requires_color(item_name) and aquilo or color_faxing

    assert_true(recipe.hidden == true, recipe_name .. " should stay hidden")
    assert_true(recipe.enabled == false, recipe_name .. " should be tech-gated")
    assert_eq(fax_shared.RECONSTRUCTION_PAPER_ITEM, "thermal-transfer-sheet",
      "fax reconstruction should use Aquilo transfer media")
    assert_true(has_ingredient(recipe, fax_shared.RECONSTRUCTION_PAPER_ITEM),
      recipe_name .. " should require thermal transfer media")
    assert_eq(get_item_ingredient_amount(recipe, fax_shared.RECONSTRUCTION_PAPER_ITEM), requirements.sheets,
      recipe_name .. " should require the correct number of transfer sheets")
    assert_eq(get_item_ingredient_amount(recipe, fax_shared.RECONSTRUCTION_SUBSTRATE_ITEM), requirements.substrate,
      recipe_name .. " should require the correct amount of archival substrate")
    assert_eq(get_item_ingredient_amount(recipe, fax_shared.RECONSTRUCTION_RIBBON_ITEM) or 0, requirements.ribbon,
      recipe_name .. " should require the correct number of ribbon charges")
    for _, fluid in ipairs(fax_shared.RECONSTRUCTION_INK_FLUIDS) do
      assert_true(not has_fluid_ingredient(recipe, fluid.name),
        recipe_name .. " should not require liquid ink " .. fluid.name)
    end

    assert_true(tech_unlocks_recipe(expected_tech, recipe_name),
      expected_tech.name .. " should unlock " .. recipe_name)
    assert_true(not tech_unlocks_recipe(unexpected_tech, recipe_name),
      unexpected_tech.name .. " should not unlock " .. recipe_name)
  end
end)

test("bicolored paperwork technologies require the matching planet sciences", function()
  local cyan_yellow = assert(technologies["cyan-yellow-bureaucracy"], "cyan-yellow-bureaucracy missing")
  local cyan_magenta = assert(technologies["cyan-magenta-bureaucracy"], "cyan-magenta-bureaucracy missing")
  local yellow_magenta = assert(technologies["yellow-magenta-bureaucracy"], "yellow-magenta-bureaucracy missing")

  local function prerequisite_set(technology)
    local set = {}
    for _, prerequisite in ipairs(technology.prerequisites or {}) do
      set[prerequisite] = true
    end
    return set
  end

  local cyan_yellow_prereqs = prerequisite_set(cyan_yellow)
  assert_true(cyan_yellow_prereqs["vulcanus-certification"], "cyan-yellow-bureaucracy should depend on vulcanus-certification")
  assert_true(cyan_yellow_prereqs["gleba-conciliation"], "cyan-yellow-bureaucracy should depend on gleba-conciliation")
  assert_true(cyan_yellow_prereqs["metallurgic-science-pack"], "cyan-yellow-bureaucracy should depend on metallurgic-science-pack")
  assert_true(cyan_yellow_prereqs["agricultural-science-pack"], "cyan-yellow-bureaucracy should depend on agricultural-science-pack")
  assert_true(tech_unlocks_recipe(cyan_yellow, "capture-bureau-tourism"), "cyan-yellow-bureaucracy should unlock capture-bureau-tourism")
  assert_true(tech_unlocks_recipe(cyan_yellow, "public-transportation-contract-production"), "cyan-yellow-bureaucracy should unlock public-transportation-contract-production")
  assert_true(tech_unlocks_recipe(cyan_yellow, "cyan-yellow-form-production"), "cyan-yellow-bureaucracy should unlock cyan-yellow-form-production")

  local cyan_magenta_prereqs = prerequisite_set(cyan_magenta)
  assert_true(cyan_magenta_prereqs["vulcanus-certification"], "cyan-magenta-bureaucracy should depend on vulcanus-certification")
  assert_true(cyan_magenta_prereqs["fulgora-digital-services"], "cyan-magenta-bureaucracy should depend on fulgora-digital-services")
  assert_true(cyan_magenta_prereqs["metallurgic-science-pack"], "cyan-magenta-bureaucracy should depend on metallurgic-science-pack")
  assert_true(cyan_magenta_prereqs["electromagnetic-science-pack"], "cyan-magenta-bureaucracy should depend on electromagnetic-science-pack")
  assert_true(tech_unlocks_recipe(cyan_magenta, "cyan-magenta-form-production"), "cyan-magenta-bureaucracy should unlock cyan-magenta-form-production")
  assert_true(tech_unlocks_recipe(cyan_magenta, "hardened-data-vault-production"), "cyan-magenta-bureaucracy should unlock hardened-data-vault-production")

  local yellow_magenta_prereqs = prerequisite_set(yellow_magenta)
  assert_true(yellow_magenta_prereqs["gleba-conciliation"], "yellow-magenta-bureaucracy should depend on gleba-conciliation")
  assert_true(yellow_magenta_prereqs["fulgora-digital-services"], "yellow-magenta-bureaucracy should depend on fulgora-digital-services")
  assert_true(yellow_magenta_prereqs["agricultural-science-pack"], "yellow-magenta-bureaucracy should depend on agricultural-science-pack")
  assert_true(yellow_magenta_prereqs["electromagnetic-science-pack"], "yellow-magenta-bureaucracy should depend on electromagnetic-science-pack")
  assert_true(tech_unlocks_recipe(yellow_magenta, "yellow-magenta-form-production"), "yellow-magenta-bureaucracy should unlock yellow-magenta-form-production")
  assert_true(tech_unlocks_recipe(yellow_magenta, "anecdotal-data-reprocessing"), "yellow-magenta-bureaucracy should unlock anecdotal-data-reprocessing")
end)

test("aquilo transfer media and multicolor forms define the expected convergence chain", function()
  assert_true(items["transfer-emulsion"] ~= nil, "transfer-emulsion missing")
  assert_true(items["thermal-transfer-sheet"] ~= nil, "thermal-transfer-sheet missing")
  assert_true(items["composite-chroma-ribbon"] ~= nil, "composite-chroma-ribbon missing")
  assert_true(items["cyan-yellow-form"] ~= nil, "cyan-yellow-form missing")
  assert_true(items["cyan-magenta-form"] ~= nil, "cyan-magenta-form missing")
  assert_true(items["yellow-magenta-form"] ~= nil, "yellow-magenta-form missing")
  assert_true(items["hardened-data-vault"] ~= nil, "hardened-data-vault missing")
  assert_true(items["trichromatic-permit"] ~= nil, "trichromatic-permit missing")
  assert_true(items["unified-operations-charter"] ~= nil, "unified-operations-charter missing")
  assert_true(items["cryogenic-operations-license"] ~= nil, "cryogenic-operations-license missing")
  assert_true(items["promethium-research-charter"] ~= nil, "promethium-research-charter missing")
  assert_true(items["laser-printer"] ~= nil, "laser-printer missing")
  assert_true(items["fax-emitter"] ~= nil, "fax-emitter missing")
  assert_true(items["interplanetary-fax-exchange"] ~= nil, "interplanetary-fax-exchange missing")

  assert_true(has_ingredient(recipes["laser-printer"], "cryoprint-technician"),
    "laser-printer should require cryoprint-technician")
  assert_true(has_ingredient(recipes["laser-printer"], "lithium-plate"),
    "laser-printer should require lithium-plate")
  assert_true(has_ingredient(recipes["fax-emitter"], "cryoprint-technician"),
    "fax-emitter should require cryoprint-technician")
  assert_true(has_ingredient(recipes["interplanetary-fax-exchange"], "cryoprint-technician"),
    "interplanetary-fax-exchange should require cryoprint-technician")
  assert_true(has_ingredient(recipes["interplanetary-fax-exchange"], "fax-emitter"),
    "interplanetary-fax-exchange should require a fax-emitter as part of the receiver build")
  assert_true(has_ingredient(recipes["transfer-emulsion-production"], "plastic-bar"),
    "transfer-emulsion should require plastic-bar")
  assert_true(has_ingredient(recipes["thermal-transfer-sheet-production"], "transfer-emulsion"),
    "thermal-transfer-sheet should require transfer-emulsion")
  assert_true(has_ingredient(recipes["composite-chroma-ribbon-production"], "blank-magenta-form"),
    "composite-chroma-ribbon should require blank-magenta-form")
  assert_true(has_fluid_ingredient(recipes["cyan-yellow-form-production"], "cyan-ink"),
    "cyan-yellow-form should require cyan-ink")
  assert_true(has_fluid_ingredient(recipes["cyan-yellow-form-production"], "yellow-ink"),
    "cyan-yellow-form should require yellow-ink")
  assert_true(has_fluid_ingredient(recipes["cyan-magenta-form-production"], "cyan-ink"),
    "cyan-magenta-form should require cyan-ink")
  assert_true(has_fluid_ingredient(recipes["cyan-magenta-form-production"], "magenta-ink"),
    "cyan-magenta-form should require magenta-ink")
  assert_true(has_fluid_ingredient(recipes["yellow-magenta-form-production"], "yellow-ink"),
    "yellow-magenta-form should require yellow-ink")
  assert_true(has_fluid_ingredient(recipes["yellow-magenta-form-production"], "magenta-ink"),
    "yellow-magenta-form should require magenta-ink")
  assert_true(has_ingredient(recipes["hardened-data-vault-production"], "cyan-magenta-form"),
    "hardened-data-vault should require cyan-magenta-form")
  assert_true(has_ingredient(recipes["hardened-data-vault-production"], "industrial-charter"),
    "hardened-data-vault should require Vulcanus industrial-charter")
  assert_true(has_ingredient(recipes["hardened-data-vault-production"], "data-recovery-order"),
    "hardened-data-vault should require Fulgora data-recovery-order")
  assert_true(has_ingredient(recipes["trichromatic-permit-production"], "composite-chroma-ribbon"),
    "trichromatic-permit should require composite-chroma-ribbon")
  assert_true(has_ingredient(recipes["unified-operations-charter-production"], "electromagnetic-operating-license"),
    "unified-operations-charter should require electromagnetic-operating-license")
  assert_true(has_ingredient(recipes["cryogenic-operations-license-production"], "lithium-plate"),
    "cryogenic-operations-license should require lithium-plate")
  assert_true(has_ingredient(recipes["promethium-research-charter-production"], "unified-operations-charter"),
    "promethium-research-charter should require unified-operations-charter")
  assert_true(has_ingredient(recipes["promethium-research-charter-production"], "hardened-data-vault"),
    "promethium-research-charter should require Vulcanus-Fulgora hardened-data-vault")
  assert_true(has_ingredient(recipes["promethium-research-charter-production"], "asteroid-processing-docket"),
    "promethium-research-charter should require asteroid-processing-docket")
  assert_true(has_ingredient(recipes["promethium-research-charter-production"], "orbital-deviation-order"),
    "promethium-research-charter should require orbital-deviation-order")
  assert_true(not has_ingredient(recipes["transfer-emulsion-production"], "taxpayer-money"),
    "transfer-emulsion should not require taxpayer-money")
end)

test("two-color forms gate tourism intake and public transit contracts", function()
  local cyan_yellow_form = assert(recipes["cyan-yellow-form-production"], "cyan-yellow-form-production missing")
  local public_transport = assert(recipes["public-transportation-contract-production"], "public-transportation-contract-production missing")
  local anecdotal = assert(recipes["anecdotal-data-reprocessing"], "anecdotal-data-reprocessing missing")

  assert_eq(cyan_yellow_form.category, "printing-multicolor", "cyan-yellow-form should use printing-multicolor")
  assert_true(has_fluid_ingredient(cyan_yellow_form, "cyan-ink"),
    "cyan-yellow-form should require cyan-ink")
  assert_true(has_fluid_ingredient(cyan_yellow_form, "yellow-ink"),
    "cyan-yellow-form should require yellow-ink")

  assert_eq(public_transport.category, "printing-chromatic", "public-transportation-contract should use printing-chromatic")
  assert_true(has_ingredient(public_transport, "cyan-yellow-form"),
    "public-transportation-contract should require cyan-yellow-form")
  assert_true(has_ingredient(public_transport, "transit-authorization"),
    "public-transportation-contract should require transit-authorization")
  assert_true(has_ingredient(anecdotal, "yellow-magenta-form"),
    "anecdotal-data-reprocessing should require yellow-magenta-form")
  assert_eq(get_result_amount(anecdotal, "dubious-data"), 6,
    "anecdotal-data-reprocessing should produce a worthwhile amount of dubious-data")
end)

test("planet-local space age recipes stay free of raw taxpayer money off Nauvis", function()
  for recipe_name, recipe in pairs(recipes) do
    local planet_name = exact_surface_planet(recipe)
    if planet_name and planet_name ~= "nauvis" then
      assert_true(not has_ingredient(recipe, "taxpayer-money"),
        recipe_name .. " should not require taxpayer-money on " .. planet_name)
    end
  end
end)

test("fax queue capacity technologies form a dedicated Aquilo follow-up chain", function()
  local capacity_1 = technologies["fax-queue-capacity-1"]
  local capacity_2 = technologies["fax-queue-capacity-2"]
  local capacity_3 = technologies["fax-queue-capacity-3"]

  assert_true(capacity_1 ~= nil, "fax-queue-capacity-1 missing")
  assert_true(capacity_2 ~= nil, "fax-queue-capacity-2 missing")
  assert_true(capacity_3 ~= nil, "fax-queue-capacity-3 missing")
  assert_eq(capacity_1.prerequisites[1], "aquilo-fax-network", "fax-queue-capacity-1 should follow Aquilo fax unlocks")
  assert_eq(capacity_2.prerequisites[1], "fax-queue-capacity-1", "fax-queue-capacity-2 should chain from the first upgrade")
  assert_eq(capacity_3.prerequisites[1], "fax-queue-capacity-2", "fax-queue-capacity-3 should chain from the second upgrade")
end)

test("fax virtual signals exist for queue visibility", function()
  assert_true(signals["signal-fax-queue-size"] ~= nil, "signal-fax-queue-size missing")
  assert_true(signals["signal-fax-free-slots"] ~= nil, "signal-fax-free-slots missing")
  assert_true(signals["signal-fax-reserved-slots"] ~= nil, "signal-fax-reserved-slots missing")
end)

if failed > 0 then
  io.stderr:write(("Failed %d/%d tests\n"):format(failed, passed + failed))
  for _, err in ipairs(errors) do
    io.stderr:write(err, "\n")
  end
  os.exit(1)
end

print(("Passed %d tests"):format(passed))
