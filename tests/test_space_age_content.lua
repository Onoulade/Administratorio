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

local function assert_near(actual, expected, epsilon, msg)
  if math.abs(actual - expected) > (epsilon or 1e-9) then
    error((msg or "") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local recipes = {
  foundry = {
    type = "recipe",
    name = "foundry",
    surface_conditions = {{property = "pressure", min = 4000, max = 4000}},
    ingredients = {{type = "item", name = "steel-plate", amount = 50}},
  },
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
  ["acid-neutralisation"] = {
    type = "recipe",
    name = "acid-neutralisation",
    surface_conditions = {{property = "pressure", min = 4000, max = 4000}},
    ingredients = {{type = "item", name = "calcite", amount = 1}},
  },
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
  ["space-platform"] = {type = "technology", name = "space-platform", effects = {}},
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

local function has_icon_layer(prototype, icon_path)
  if not prototype or not prototype.icons then return false end
  for _, layer in ipairs(prototype.icons) do
    if layer.icon == icon_path then return true end
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
    "voluntary-exploration-space-miner-formation",
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

test("vacuum infrastructure uses one dedicated orbital permit", function()
  local workforce = technologies["workforce-formation"]
  local platform = technologies["space-platform"]
  local permit_name = "orbital-infrastructure-permit"
  local permit_icon = "__administratorio__/graphics/icons/orbital-infrastructure-permit.png"
  local permit_recipe = assert(recipes[permit_name], "orbital infrastructure permit recipe missing")

  assert_true(items[permit_name] ~= nil, "orbital infrastructure permit item missing")
  assert_eq(items[permit_name].subgroup, "forms-permits")
  assert_eq(permit_recipe.category, "bureaucracy-registration")
  assert_eq(permit_recipe.surface_conditions[1].min, 1,
    "orbital permits should be issued outside vacuum and shipped to the platform")
  assert_true(has_ingredient(permit_recipe, "low-density-structure"),
    "orbital permits should require launch-capable infrastructure")
  assert_true(not has_ingredient(permit_recipe, "space-science-pack"),
    "orbital permit issuance must not depend on the first platform's science output")
  assert_true(tech_unlocks_recipe(platform, permit_name),
    "creating a space platform should unlock orbital permit issuance")
  assert_true(not tech_unlocks_recipe(workforce, permit_name),
    "workforce formation should not delay orbital permit issuance")

  local ordinary_paperwork = {
    "work-order",
    "construction-permit",
    "construction-work-order",
    "management-approval-verbal",
    "management-verbal-work-order",
    "management-approval-written",
    "management-written-work-order",
  }
  for _, recipe_name in ipairs({
    "administrative-space-station",
    "trajectory-compliance-array",
    "senior-trajectory-compliance-array",
    "executive-trajectory-compliance-array",
    "orbital-employment-cannon",
  }) do
    local recipe = assert(recipes[recipe_name], recipe_name .. " missing")
    assert_true(has_ingredient(recipe, permit_name), recipe_name .. " should require the orbital permit")
    for _, paperwork_name in ipairs(ordinary_paperwork) do
      assert_true(not has_ingredient(recipe, paperwork_name),
        recipe_name .. " should not require ordinary paperwork " .. paperwork_name)
    end
    assert_true(not has_icon_layer(items[recipe_name], permit_icon),
      recipe_name .. " icon should not display its orbital permit gate")
  end
end)

test("native Space Age buildings use one canonical construction recipe", function()
  assert_true(has_ingredient(recipes["foundry"], "licensed-notary"), "foundry should require licensed-notary")
  assert_true(has_ingredient(recipes["foundry"], "tungsten-carbide"), "foundry should require tungsten-carbide")
  assert_eq(#recipes["foundry"].surface_conditions, 1, "foundry should retain the single vanilla surface condition")
  assert_eq(recipes["foundry"].surface_conditions[1].property, "pressure", "foundry should retain vanilla pressure gating")
  assert_eq(recipes["foundry"].surface_conditions[1].min, 4000, "foundry should retain vanilla minimum pressure")
  assert_eq(recipes["foundry"].surface_conditions[1].max, 4000, "foundry should retain vanilla maximum pressure")
  assert_true(recipes["foundry-offworld"] == nil, "foundry must not have an offworld construction variant")
  assert_true(has_ingredient(recipes["notary-office"], "licensed-notary"), "notary-office should require licensed-notary")
  assert_true(has_ingredient(recipes["territorial-arbitration-post"], "licensed-notary"),
    "territorial-arbitration-post should require licensed-notary")
  assert_true(has_ingredient(recipes["notary-office"], "tungsten-carbide"), "notary-office should require tungsten-carbide")
  assert_eq(exact_surface_planet(recipes["notary-office"]), "vulcanus", "notary-office should be crafted on Vulcanus")
  assert_true(has_ingredient(recipes["biochamber"], "conciliation-officer"), "biochamber should require conciliation-officer")
  assert_true(has_ingredient(recipes["electromagnetic-plant"], "relay-clerk"), "electromagnetic-plant should require relay-clerk")
  assert_true(has_ingredient(recipes["cryogenic-plant"], "cryoprint-technician"), "cryogenic-plant should require cryoprint-technician")
  for _, recipe_name in ipairs({"foundry", "biochamber", "electromagnetic-plant", "cryogenic-plant", "notary-office"}) do
    assert_true(has_ingredient(recipes[recipe_name], "staffing-briefed-middle-management-managing-manager"),
      recipe_name .. " should require a freshly staffing-briefed MMMM")
    assert_eq(get_result_amount(recipes[recipe_name], "middle-management-managing-manager"), 1,
      recipe_name .. " should return its manager unbriefed")
  end
  assert_true(has_ingredient(recipes["territorial-arbitration-post"],
    "compliance-briefed-middle-management-managing-manager"),
    "territorial arbitration construction should also require compliance oversight")
  assert_eq(get_result_amount(recipes["territorial-arbitration-post"],
    "middle-management-managing-manager"), 2)
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

test("vulcanus early bootstrap supplies inputs, not duplicated finished paperwork", function()
  local calcite = technologies["calcite-processing"]
  local propaganda = technologies["industrial-propaganda"]
  assert_true(calcite ~= nil, "calcite-processing missing")
  assert_true(propaganda ~= nil, "industrial-propaganda missing")
  assert_true(tech_unlocks_recipe(calcite, "dubious-data-analysis-vulcanus"), "calcite-processing should unlock dubious-data-analysis-vulcanus")
  assert_true(tech_unlocks_recipe(calcite, "paper-production-vulcanus"), "calcite-processing should unlock paper-production-vulcanus")
  assert_true(tech_unlocks_recipe(calcite, "carbon-offset-certificate-basic-vulcanus"), "calcite-processing should unlock carbon-offset-certificate-basic-vulcanus")
  assert_true(tech_unlocks_recipe(propaganda, "redundant-rubble-recovery-vulcanus"), "industrial-propaganda should unlock the local rubble bridge")
  assert_eq(get_result_amount(recipes["redundant-rubble-recovery-vulcanus"], "redundant-rubble"), 5,
    "the rubble bridge should make the generic paperwork chain possible")
  assert_eq(recipes["provisional-approval-vulcanus"], nil, "Vulcanus should use the canonical provisional approval recipe")
  assert_eq(recipes["research-grant-approval-vulcanus"], nil, "Vulcanus should use the canonical research grant recipe")
  assert_eq(recipes["administrative-science-pack-production-vulcanus"], nil, "Vulcanus should use the canonical administrative science recipe")
  assert_true(recipes["printer-t1-vulcanus"] == nil, "printer-t1 must keep one canonical recipe")
end)

test("vulcanus certification unlocks local notary gates, not a second paperwork catalogue", function()
  local certification = technologies["vulcanus-certification"]
  assert_true(certification ~= nil, "vulcanus-certification missing")
  for _, recipe_name in ipairs({
    "notary-office",
    "territorial-arbitration-post",
    "embossed-seal",
    "industrial-charter",
    "territorial-resettlement-order",
    "good-excuse-vulcanus",
    "management-approval-written-vulcanus",
    "government-grant-vulcanus",
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
  for _, recipe_name in ipairs({
    "safety-waiver-vulcanus",
    "construction-permit-vulcanus",
    "management-approval-verbal-vulcanus",
    "heatproof-filler-documentation",
    "form-27b-6-vulcanus",
  }) do
    assert_eq(recipes[recipe_name], nil, recipe_name .. " should defer to the canonical paperwork recipe")
  end
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
  assert_true(has_fluid_ingredient(recipes["management-approval-written-vulcanus"], "lie"), "written approval exception should consume locally distilled lie")
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
  }) do
    assert_true(not has_ingredient(recipes[recipe_name], "chemical-handling-work-order"), recipe_name .. " should stay bootstrap-safe on Vulcanus")
  end
end)

test("vanilla Vulcanus process recipes and restrictions stay untouched", function()
  for _, recipe_name in ipairs({
    "tungsten-plate",
    "tungsten-carbide",
    "molten-iron",
    "molten-iron-from-lava",
    "molten-copper",
    "molten-copper-from-lava",
    "simple-coal-liquefaction",
    "casting-low-density-structure",
  }) do
    assert_true(recipes[recipe_name].surface_conditions == nil,
      recipe_name .. " should retain its unrestricted vanilla recipe prototype")
    assert_true(recipes[recipe_name .. "-offworld"] == nil,
      recipe_name .. " must not gain an offworld clone")
  end
  local neutralisation = recipes["acid-neutralisation"]
  assert_eq(#neutralisation.surface_conditions, 1, "acid-neutralisation should retain one vanilla condition")
  assert_eq(neutralisation.surface_conditions[1].property, "pressure", "acid-neutralisation should retain pressure gating")
  assert_eq(neutralisation.surface_conditions[1].min, 4000, "acid-neutralisation should retain Vulcanus pressure")
  assert_eq(neutralisation.surface_conditions[1].max, 4000, "acid-neutralisation should retain Vulcanus pressure")
  assert_true(recipes["acid-neutralisation-offworld"] == nil,
    "acid-neutralisation must retain its vanilla Vulcanus isolation")
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

test("MMMM meetings batch five temporary briefings and formations return regular managers", function()
  local manager = assert(items["middle-management-managing-manager"], "regular MMMM missing")
  assert_eq(manager.type, "item")
  assert_eq(manager.stack_size, 20)

  local briefing_specs = {
    training = {material = "iron-gear-wheel", amount = 5},
    staffing = {material = "repair-pack", amount = 5},
    compliance = {material = "blank-form", amount = 5},
    liaison = {material = "electronic-circuit", amount = 5},
    orbital = {material = "rocket-fuel", amount = 1},
  }
  local workforce = technologies["workforce-formation"]

  for key, spec in pairs(briefing_specs) do
    local item_name = key .. "-briefed-middle-management-managing-manager"
    local recipe_name = "middle-management-" .. key .. "-briefing"
    local briefed = assert(items[item_name], item_name .. " missing")
    local meeting = assert(recipes[recipe_name], recipe_name .. " missing")
    assert_eq(briefed.stack_size, 5)
    assert_eq(briefed.spoil_ticks, 3 * 60 * 60)
    assert_eq(briefed.spoil_result, "middle-management-managing-manager")
    assert_eq(meeting.energy_required, 45)
    assert_eq(meeting.allow_productivity, false)
    assert_eq(get_item_ingredient_amount(meeting, "middle-management-managing-manager"), 5)
    assert_eq(get_item_ingredient_amount(meeting, "taxpayer-money"), 25)
    assert_eq(get_item_ingredient_amount(meeting, spec.material), spec.amount)
    assert_eq(get_fluid_ingredient_amount(meeting, "liquid-coffee"), 50)
    assert_eq(get_result_amount(meeting, item_name), 5)
    assert_true(tech_unlocks_recipe(workforce, recipe_name), recipe_name .. " should unlock with workforce formation")
  end

  local expected_formations = {
    ["clerical-trainee-formation"] = {"training"},
    ["astronaut-formation"] = {"training", "orbital"},
    ["licensed-notary-formation"] = {"training", "compliance"},
    ["conciliation-officer-formation"] = {"training", "liaison"},
    ["relay-clerk-formation"] = {"training", "liaison"},
    ["cryoprint-technician-formation"] = {"training", "compliance"},
  }
  for recipe_name, keys in pairs(expected_formations) do
    local recipe = assert(recipes[recipe_name])
    for _, key in ipairs(keys) do
      assert_true(has_ingredient(recipe, key .. "-briefed-middle-management-managing-manager"),
        recipe_name .. " should require its " .. key .. " briefing")
    end
    assert_eq(get_result_amount(recipe, "middle-management-managing-manager"), #keys,
      recipe_name .. " should return every manager unbriefed")
  end
end)

test("deviation paperwork and VESM cannon are distinct orbital systems", function()
  local miner = assert(ammos["voluntary-exploration-space-miner"], "VESM ammo missing")
  assert_eq(miner.type, "ammo")
  assert_eq(miner.ammo_category, "orbital-biter-ballistics", "VESM should feed the deployment cannon")
  assert_eq(miner.magazine_size, 1, "one VESM should power exactly one orbital sortie")
  local deliveries = miner.ammo_type.action.action_delivery
  local projectile_delivery
  local has_launch_reservation = false
  for _, delivery in ipairs(deliveries) do
    if delivery.type == "projectile" then
      projectile_delivery = delivery
    elseif delivery.type == "instant" then
      for _, effect in ipairs(delivery.target_effects or {}) do
        if effect.type == "script"
          and effect.effect_id == "administratorio-asteroid-biter-launched"
          and effect.affects_target == true
        then
          has_launch_reservation = true
        end
      end
    end
  end
  assert_true(projectile_delivery ~= nil, "VESM projectile delivery missing")
  assert_eq(projectile_delivery.projectile, "orbital-biter-projectile")
  assert_true(has_launch_reservation,
    "miner deployment cannon should reserve the exact asteroid when the projectile launches")

  local formation = assert(recipes["voluntary-exploration-space-miner-formation"], "VESM formation missing")
  assert_true(has_ingredient(formation, "astronaut"))
  assert_true(has_ingredient(formation, "electric-mining-drill"))
  assert_true(has_ingredient(formation, "training-briefed-middle-management-managing-manager"))
  assert_true(has_ingredient(formation, "compliance-briefed-middle-management-managing-manager"))
  assert_true(has_ingredient(formation, "orbital-briefed-middle-management-managing-manager"))
  assert_eq(get_result_amount(formation, "voluntary-exploration-space-miner"), 1)
  assert_eq(get_result_amount(formation, "middle-management-managing-manager"), 3)
  assert_true(tech_unlocks_recipe(technologies["workforce-formation"], formation.name))

  local deviation = assert(ammos["orbital-deviation-order"], "deviation order ammo missing")
  assert_eq(deviation.ammo_category, "trajectory-compliance")
  assert_eq(deviation.magazine_size, 1)
  local deviation_delivery = deviation.ammo_type.action.action_delivery
  assert_eq(deviation_delivery.type, "instant")
  assert_eq(deviation_delivery.target_effects[1].type, "script")
  assert_eq(deviation_delivery.target_effects[1].effect_id, "administratorio-trajectory-deviation")
  assert_eq(deviation_delivery.target_effects[1].affects_target, true)

  assert_true(recipes["trajectory-compliance-array"] ~= nil, "trajectory compliance array recipe missing")
  assert_true(tech_unlocks_recipe(technologies["workforce-formation"], "trajectory-compliance-array"), "workforce formation should unlock the compliance array")
  assert_true(items["orbital-employment-cannon"] ~= nil, "orbital employment cannon item missing")
  assert_true(recipes["orbital-employment-cannon"] ~= nil, "orbital employment cannon recipe missing")
  assert_true(tech_unlocks_recipe(technologies["workforce-formation"], "orbital-employment-cannon"),
    "workforce formation should unlock the employment cannon")

  local senior_recipe = assert(recipes["senior-trajectory-compliance-array"], "senior array recipe missing")
  local executive_recipe = assert(recipes["executive-trajectory-compliance-array"], "executive array recipe missing")
  assert_true(items["senior-trajectory-compliance-array"] ~= nil, "senior array item missing")
  assert_true(items["executive-trajectory-compliance-array"] ~= nil, "executive array item missing")
  assert_true(has_ingredient(senior_recipe, "trajectory-compliance-array"), "senior array should upgrade the junior array")
  assert_true(has_ingredient(senior_recipe, "tungsten-carbide"), "senior array should require Vulcanus hardware")
  assert_true(has_ingredient(senior_recipe, "carbon-fiber"), "senior array should require Gleba hardware")
  assert_true(has_ingredient(senior_recipe, "supercapacitor"), "senior array should require Fulgora hardware")
  assert_true(has_ingredient(executive_recipe, "senior-trajectory-compliance-array"),
    "executive array should upgrade the senior array")
  assert_true(has_ingredient(executive_recipe, "quantum-processor"),
    "executive array should require pre-Promethium quantum processing")

  local senior_tech = assert(technologies["trajectory-compliance-jurisdiction-2"], "senior jurisdiction missing")
  local executive_tech = assert(technologies["trajectory-compliance-jurisdiction-3"], "executive jurisdiction missing")
  assert_true(tech_unlocks_recipe(senior_tech, "senior-trajectory-compliance-array"))
  assert_true(tech_unlocks_recipe(executive_tech, "executive-trajectory-compliance-array"))
  local has_quantum_prerequisite = false
  for _, prerequisite in ipairs(executive_tech.prerequisites or {}) do
    if prerequisite == "quantum-processor" then has_quantum_prerequisite = true end
  end
  assert_true(has_quantum_prerequisite, "huge-asteroid jurisdiction must unlock through quantum processing")
  for _, ingredient in ipairs(executive_tech.unit.ingredients or {}) do
    assert_true((ingredient.name or ingredient[1]) ~= "promethium-science-pack",
      "Promethium-capable hardware cannot require Promethium science")
  end
end)

test("returning employees need no intermediate inventory item or burnout path", function()
  assert_true(items["burned-out-manager"] == nil, "random burnout item should be removed")
  assert_true(recipes["burned-out-manager-rehabilitation"] == nil, "burnout rehabilitation should be removed")
  assert_true(not tech_unlocks_recipe(technologies["workforce-formation"], "burned-out-manager-rehabilitation"))
  assert_true(items["returning-orbital-employee"] == nil,
    "collector should mine the chunk straight into VESM ammo, not an intermediate item")
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
    assert_true(has_ingredient(recipe, "orbital-briefed-middle-management-managing-manager"),
      recipe_name .. " should require a fresh orbital briefing")
    assert_eq(get_result_amount(recipe, "middle-management-managing-manager"), 1,
      recipe_name .. " should return its manager unbriefed")
    assert_true(tech_unlocks_recipe(workforce, recipe_name), "workforce-formation should unlock " .. recipe_name)
  end
  assert_true(items["asteroid-processing-docket"] ~= nil, "asteroid-processing-docket missing")
  assert_eq(get_result_amount(recipes["orbital-deviation-order"], "orbital-deviation-order"), 4,
    "one staffed review should issue four deviation orders")
end)

test("trajectory compliance speed research reaches every exact cooldown", function()
  local expected_seconds = {4.5, 4.0, 3.5, 3.0, 2.5, 2.0, 1.5, 1.0, 0.5}
  local expected_counts = {200, 350, 550, 800, 1000, 1500, 2250, 3000, 4000}
  local cumulative_modifier = 0

  local function has_pack(technology, pack_name)
    for _, ingredient in ipairs(technology.unit.ingredients or {}) do
      if (ingredient.name or ingredient[1]) == pack_name then return true end
    end
    return false
  end

  for level, seconds in ipairs(expected_seconds) do
    local technology = assert(technologies["trajectory-compliance-speed-" .. level], "speed tier missing")
    assert_eq(technology.unit.count, expected_counts[level], "unexpected research count at tier " .. level)
    local speed_effect
    for _, effect in ipairs(technology.effects or {}) do
      if effect.type == "gun-speed" and effect.ammo_category == "trajectory-compliance" then
        speed_effect = effect
      end
    end
    assert_true(speed_effect ~= nil, "gun-speed effect missing at tier " .. level)
    cumulative_modifier = cumulative_modifier + speed_effect.modifier
    assert_near(300 / (1 + cumulative_modifier), seconds * 60, 1e-9,
      "cooldown mismatch at tier " .. level)

    if level >= 5 then
      assert_true(has_pack(technology, "metallurgic-science-pack"), "tier " .. level .. " should use metallurgic science")
      assert_true(has_pack(technology, "agricultural-science-pack"), "tier " .. level .. " should use agricultural science")
      assert_true(has_pack(technology, "electromagnetic-science-pack"), "tier " .. level .. " should use electromagnetic science")
    end
    assert_eq(has_pack(technology, "cryogenic-science-pack"), level >= 8,
      "cryogenic gating mismatch at tier " .. level)
    assert_eq(has_pack(technology, "promethium-science-pack"), level >= 9,
      "promethium gating mismatch at tier " .. level)
  end
end)

test("orbital employment damage research scales by 50 percent through late science", function()
  local expected_counts = {350, 600, 1200, 2200, 4000}
  for level, count in ipairs(expected_counts) do
    local technology = assert(technologies["orbital-employment-damage-" .. level], "damage tier missing")
    assert_eq(technology.unit.count, count)
    local damage_effect
    for _, effect in ipairs(technology.effects or {}) do
      if effect.type == "ammo-damage" and effect.ammo_category == "orbital-biter-ballistics" then
        damage_effect = effect
      end
    end
    assert_true(damage_effect ~= nil, "biter ammo damage effect missing at tier " .. level)
    assert_eq(damage_effect.modifier, 0.5)
    local description_effect
    for _, effect in ipairs(technology.effects or {}) do
      if effect.type == "nothing" then description_effect = effect end
    end
    assert_eq(description_effect.effect_description[2], tostring(125 * (1 + level * 0.5)))
  end
end)

test("orbital staffing capacity grows from two through five VESMs", function()
  local function technology_has_pack(technology, pack_name)
    for _, ingredient in ipairs(technology.unit.ingredients or {}) do
      if (ingredient.name or ingredient[1]) == pack_name then return true end
    end
    return false
  end

  local expected_counts = {500, 1500, 3000, 6000}
  for level, count in ipairs(expected_counts) do
    local technology = assert(technologies["orbital-employment-capacity-" .. level],
      "staffing capacity tier missing")
    assert_eq(technology.unit.count, count)

    local description_effect
    for _, effect in ipairs(technology.effects or {}) do
      if effect.type == "nothing" then description_effect = effect end
    end
    assert_true(description_effect ~= nil, "capacity description effect missing at tier " .. level)
    assert_eq(description_effect.effect_description[2], tostring(level + 1))

    assert_eq(technology_has_pack(technology, "metallurgic-science-pack"), level >= 2,
      "metallurgic capacity gating mismatch")
    assert_eq(technology_has_pack(technology, "agricultural-science-pack"), level >= 2,
      "agricultural capacity gating mismatch")
    assert_eq(technology_has_pack(technology, "electromagnetic-science-pack"), level >= 2,
      "electromagnetic capacity gating mismatch")
    assert_eq(technology_has_pack(technology, "cryogenic-science-pack"), level >= 3,
      "cryogenic capacity gating mismatch")
    assert_eq(technology_has_pack(technology, "promethium-science-pack"), level >= 4,
      "Promethium capacity gating mismatch")
  end
end)

test("orbital employee return has no random recovery research", function()
  for level = 1, 9 do
    assert_true(technologies["orbital-employment-recovery-" .. level] == nil,
      "obsolete recovery tier should not exist: " .. level)
  end
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
    "management-approval-written-gleba",
    "government-grant-gleba",
    "composted-rubble-recovery-gleba",
    "conciliation-officer-formation-gleba",
  }) do
    assert_true(tech_unlocks_recipe(gleba, recipe_name), "gleba-conciliation should unlock " .. recipe_name)
  end
  for _, prerequisite in ipairs(gleba.prerequisites or {}) do
    assert_true(prerequisite ~= "agricultural-science-pack",
      "gleba-conciliation must bootstrap before agricultural science needs eggs")
  end
end)

test("gleba conciliation also unlocks orbital spitter tourism", function()
  local gleba = technologies["gleba-conciliation"]
  local expected = {
    {
      package_item = "small-spitter-tourism-package",
      tourist_item = "small-space-tourist",
      tourism_recipe = "small-spitter-space-tourism",
      jettison_recipe = "small-space-tourist-jettison",
      bond_payout = 2,
    },
    {
      package_item = "medium-spitter-tourism-package",
      tourist_item = "medium-space-tourist",
      tourism_recipe = "medium-spitter-space-tourism",
      jettison_recipe = "medium-space-tourist-jettison",
      bond_payout = 4,
    },
    {
      package_item = "big-spitter-tourism-package",
      tourist_item = "big-space-tourist",
      tourism_recipe = "big-spitter-space-tourism",
      jettison_recipe = "big-space-tourist-jettison",
      bond_payout = 9,
    },
    {
      package_item = "behemoth-spitter-tourism-package",
      tourist_item = "behemoth-space-tourist",
      tourism_recipe = "behemoth-spitter-space-tourism",
      jettison_recipe = "behemoth-space-tourist-jettison",
      bond_payout = 24,
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
    assert_eq(get_result_amount(tourism_recipe, "treasury-bond"), variant.bond_payout,
      variant.tourism_recipe .. " should pay the expected bond amount")
    assert_true(not has_result(tourism_recipe, "government-grant"),
      variant.tourism_recipe .. " should not award megaproject grants")
    assert_true(not has_result(tourism_recipe, "taxpayer-money"),
      variant.tourism_recipe .. " should not mint loose taxpayer money in orbit")
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

  assert_true(has_fluid_ingredient(recipes["yellow-ink-production"], "amber-sap"), "yellow-ink should consume amber-sap")
  assert_true(has_ingredient(recipes["yellow-ink-production"], "nutrients"), "yellow-ink should consume nutrients")
  assert_true(has_fluid_ingredient(recipes["mycelial-form-stock"], "yellow-ink"), "mycelial-form-stock should consume yellow-ink")
  assert_true(has_fluid_ingredient(recipes["blank-yellow-form-production"], "yellow-ink"), "blank-yellow-form should consume yellow-ink")
end)

test("gleba adds targeted ingredients instead of duplicate building recipes", function()
  for _, recipe_name in ipairs({
    "amber-sap-nonsense-seeding",
    "ink-production-gleba",
    "carbon-offset-certificate-basic-gleba",
    "construction-permit-gleba",
    "administrative-science-pack-production-gleba",
    "dubious-data-cultivation-gleba",
    "provisional-approval-cultivation-gleba",
    "management-approval-written-gleba",
    "government-grant-gleba",
    "composted-rubble-recovery-gleba",
    "conciliation-officer-formation-gleba",
    "capture-bureau",
  }) do
    assert_true(recipes[recipe_name] ~= nil, recipe_name .. " missing")
  end

  assert_true(has_ingredient(recipes["capture-bureau"], "worker-biter"), "capture-bureau should require worker-biter")
  assert_true(has_ingredient(recipes["capture-bureau"], "construction-permit"), "capture-bureau should use Gleba's local construction permit route")
  assert_true(not has_ingredient(recipes["capture-bureau"], "admin-station"), "capture-bureau must not import a Nauvis admin desk")
  assert_true(has_ingredient(recipes["capture-bureau"], "construction-work-order"), "capture-bureau should require imported construction paperwork")
  for _, recipe_name in ipairs({
    "admin-station-gleba",
    "printer-t1-gleba",
    "corporate-breakroom-gleba",
  }) do
    assert_true(recipes[recipe_name] == nil, recipe_name .. " must not duplicate a building recipe")
  end
  assert_true(recipes["management-approval-verbal-gleba"] == nil, "management-approval-verbal-gleba should not exist")
  assert_true(recipes["research-grant-approval-gleba"] == nil, "research-grant-approval-gleba should not exist")
  assert_true(recipes["form-27b-6-gleba"] == nil, "form-27b-6-gleba should not exist")
  assert_true(recipes["advanced-circuit-gleba"] == nil, "advanced-circuit-gleba should not exist")
  assert_true(recipes["low-density-structure-gleba"] == nil, "low-density-structure-gleba should not exist")
  assert_true(recipes["rocket-control-unit-gleba"] == nil, "rocket-control-unit-gleba should not exist")
  assert_true(recipes["rocket-silo-gleba"] == nil, "rocket-silo-gleba should not exist")
  for _, recipe_name in ipairs({
    "credentials-cultivation-gleba",
    "justification-cultivation-gleba",
    "basic-excuse-cultivation-gleba",
    "good-excuse-cultivation-gleba",
    "refined-nonsense-cultivation-gleba",
    "useless-documentation-cultivation-gleba",
  }) do
    assert_eq(recipes[recipe_name], nil, recipe_name .. " should remain a canonical or imported paperwork route")
  end
  assert_eq(get_result_amount(recipes["dubious-data-cultivation-gleba"], "dubious-data"), 8,
    "Gleba data cultivation should be a constrained bridge, not a generic upgrade")
  assert_eq(recipes["dubious-data-cultivation-gleba"].energy_required, 8,
    "Gleba data cultivation should be deliberately slow")
  assert_eq(get_result_amount(recipes["provisional-approval-cultivation-gleba"], "provisional-approval"), 1,
    "Gleba should receive only one provisional approval per cultivation")
  assert_eq(recipes["provisional-approval-cultivation-gleba"].energy_required, 4,
    "Gleba provisional approval should be deliberately slow")
  assert_eq(recipes["management-approval-written-gleba"].energy_required, 24,
    "Gleba should pay a meaningful biological cost for the terminal approval")
  assert_eq(recipes["government-grant-gleba"].energy_required, 36,
    "Gleba should pay a meaningful biological cost for the terminal grant")
  assert_eq(recipes["composted-rubble-recovery-gleba"].energy_required, 12,
    "Gleba rubble recovery should stay slow")
end)

test("vanilla Gleba bio recipes stay untouched and uncloned", function()
  for _, recipe_name in ipairs({"rocket-fuel-from-jelly", "bioplastic", "biosulfur", "biolubricant"}) do
    assert_true(recipes[recipe_name].surface_conditions == nil,
      recipe_name .. " should retain its unrestricted vanilla recipe prototype")
    assert_true(recipes[recipe_name .. "-offworld"] == nil,
      recipe_name .. " must not gain an offworld clone")
  end
  assert_true(items["biochamber-operating-waiver"] == nil,
    "obsolete offworld Biochamber paperwork should not exist")
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
    "management-approval-written-fulgora",
    "government-grant-fulgora",
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
  assert_true(recipes["electromagnetic-rocket-fuel-fulgora"] ~= nil,
    "Fulgora needs its electromagnetic rocket-fuel bridge")
  assert_eq(recipes["liquid-black-ink-fulgora"], nil,
    "Fulgora should not receive a broad liquid-black-ink substitute")
  assert_true(recipes["electromagnetic-lubricant-fulgora"] ~= nil,
    "Fulgora needs one expensive lubricant bridge for the unchanged electric-engine chain")
  assert_true(tech_unlocks_recipe(electromagnetic_plant, "electromagnetic-lubricant-fulgora"),
    "electromagnetic-plant should unlock the Fulgora lubricant bridge")
  for _, recipe_name in ipairs({"management-approval-written-fulgora", "government-grant-fulgora"}) do
    assert_true(recipes[recipe_name] ~= nil, recipe_name .. " should be a narrow Fulgora launch exception")
    assert_eq(recipes[recipe_name].category, "bureaucracy-registration", recipe_name .. " should use the digital bureau")
  end

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
    "composite-form-cyan-yellow-production",
    "composite-form-cyan-magenta-production",
    "composite-form-yellow-magenta-production",
    "trichromatic-permit-production",
    "unified-operations-charter-production",
    "cryogenic-operations-license-production",
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
    assert_true(has_ingredient(recipe, fax_shared.RECONSTRUCTION_PAPER_ITEM),
      recipe_name .. " should require thermal transfer media")
    assert_eq(get_item_ingredient_amount(recipe, fax_shared.RECONSTRUCTION_PAPER_ITEM), requirements.sheets,
      recipe_name .. " should require the correct number of transfer sheets")
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
  assert_true(items["trichromatic-permit"] ~= nil, "trichromatic-permit missing")
  assert_true(items["unified-operations-charter"] ~= nil, "unified-operations-charter missing")
  assert_true(items["cryogenic-operations-license"] ~= nil, "cryogenic-operations-license missing")
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
  assert_true(not has_ingredient(recipes["promethium-research-charter-production"], "orbital-deviation-order"),
    "promethium-research-charter should no longer require orbital-deviation-order")
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
