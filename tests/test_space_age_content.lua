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
  ["electromagnetic-science-pack"] = {type = "technology", name = "electromagnetic-science-pack", effects = {}},
  ["cryogenic-science-pack"] = {type = "technology", name = "cryogenic-science-pack", effects = {}},
  ["after-hours-operations"] = {type = "technology", name = "after-hours-operations", effects = {}},
  ["discovery-redundant-rubble"] = {type = "technology", name = "discovery-redundant-rubble", effects = {}},
  ["nest-expropriation"] = {type = "technology", name = "nest-expropriation", effects = {}},
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

dofile(mod_root .. "prototypes/item/space_age.lua")
dofile(mod_root .. "prototypes/item/capsules-and-fluids.lua")
dofile(mod_root .. "prototypes/recipe/space_age.lua")
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

test("native Space Age buildings consume planet-specific specialists", function()
  assert_true(has_ingredient(recipes["foundry"], "licensed-notary"), "foundry should require licensed-notary")
  assert_true(not has_ingredient(recipes["foundry"], "offworld-metallurgy-charter"), "home-planet foundry should not require offworld-metallurgy-charter")
  assert_true(has_ingredient(recipes["foundry-offworld"], "licensed-notary"), "offworld foundry should still require licensed-notary")
  assert_true(has_ingredient(recipes["foundry-offworld"], "offworld-metallurgy-charter"), "offworld foundry should require offworld-metallurgy-charter")
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
  assert_true(tech_unlocks_recipe(calcite, "admin-station-vulcanus"), "calcite-processing should unlock admin-station-vulcanus")
  assert_true(tech_unlocks_recipe(admin_research, "research-grant-approval-vulcanus"), "administrative-science-research should unlock research-grant-approval-vulcanus")
  assert_true(tech_unlocks_recipe(admin_research, "administrative-science-pack-production-vulcanus"), "administrative-science-research should unlock administrative-science-pack-production-vulcanus")
  assert_true(tech_unlocks_recipe(printing, "printer-t1-vulcanus"), "printing-technology should unlock printer-t1-vulcanus")
end)

test("vulcanus certification unlocks the notary office and fallback paperwork", function()
  local certification = technologies["vulcanus-certification"]
  assert_true(certification ~= nil, "vulcanus-certification missing")
  for _, recipe_name in ipairs({
    "notary-office",
    "embossed-seal",
    "industrial-charter",
    "thermal-process-license",
    "calcite-reagent-waiver",
    "offworld-metallurgy-charter",
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
  assert_true(workforce ~= nil, "workforce-formation missing")
  assert_true(tech_unlocks_recipe(workforce, "job-offer-production"), "workforce-formation should unlock job-offer-production")
  assert_true(tech_unlocks_recipe(workforce, "worker-biter-formation"), "workforce-formation should unlock worker-biter-formation")
  assert_true(not tech_unlocks_recipe(chromatic, "worker-biter"), "chromatic-printing should not directly unlock worker-biter")
  assert_eq(workforce.prerequisites[1], "space-science-pack", "workforce-formation should unlock after space science")
end)

test("night shift and negotiator roles feed their intended recipes", function()
  assert_true(recipes["overtime-exemption-staffed"] ~= nil, "staffed overtime recipe missing")
  assert_true(has_ingredient(recipes["overtime-exemption-staffed"], "night-shift-supervisor"), "staffed overtime should require night-shift-supervisor")
  assert_true(tech_unlocks_recipe(technologies["after-hours-operations"], "overtime-exemption-staffed"), "after-hours-operations should unlock staffed overtime")

  assert_true(recipes["promise-production-negotiated"] ~= nil, "negotiated promise recipe missing")
  assert_true(has_ingredient(recipes["promise-production-negotiated"], "field-negotiator"), "negotiated promise should require field-negotiator")
  assert_true(tech_unlocks_recipe(technologies["discovery-redundant-rubble"], "promise-production-negotiated"), "discovery-redundant-rubble should unlock negotiated promise")

  assert_true(recipes["eviction-notice-production-negotiated"] ~= nil, "negotiated eviction recipe missing")
  assert_true(has_ingredient(recipes["eviction-notice-production-negotiated"], "field-negotiator"), "negotiated eviction should require field-negotiator")
  assert_true(tech_unlocks_recipe(technologies["nest-expropriation"], "eviction-notice-production-negotiated"), "nest-expropriation should unlock negotiated eviction")
end)

test("MMMM is converted into trajectory-compliance ammo and sink hardware", function()
  assert_true(ammos["middle-management-managing-manager"] ~= nil, "MMMM ammo missing")
  assert_eq(ammos["middle-management-managing-manager"].type, "ammo", "MMMM should be ammo-backed for trajectory compliance")
  assert_eq(ammos["middle-management-managing-manager"].ammo_category, "trajectory-compliance", "MMMM should feed trajectory-compliance arrays")
  assert_true(recipes["trajectory-compliance-array"] ~= nil, "trajectory compliance array recipe missing")
  assert_true(tech_unlocks_recipe(technologies["workforce-formation"], "trajectory-compliance-array"), "workforce formation should unlock the compliance array")
end)

test("gleba conciliation unlocks the yellow chain and gleba specialist buildings", function()
  local gleba = technologies["gleba-conciliation"]
  assert_true(gleba ~= nil, "gleba-conciliation missing")
  for _, recipe_name in ipairs({
    "capture-bureau",
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

test("aquilo transfer media and multicolor forms define the expected convergence chain", function()
  assert_true(items["transfer-emulsion"] ~= nil, "transfer-emulsion missing")
  assert_true(items["thermal-transfer-sheet"] ~= nil, "thermal-transfer-sheet missing")
  assert_true(items["composite-chroma-ribbon"] ~= nil, "composite-chroma-ribbon missing")
  assert_true(items["composite-form"] ~= nil, "composite-form missing")
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
  assert_true(has_ingredient(recipes["composite-form-cyan-yellow-production"], "blank-cyan-form"),
    "cyan-yellow composite-form should require blank-cyan-form")
  assert_true(has_ingredient(recipes["composite-form-cyan-magenta-production"], "blank-magenta-form"),
    "cyan-magenta composite-form should require blank-magenta-form")
  assert_true(has_ingredient(recipes["composite-form-yellow-magenta-production"], "blank-yellow-form"),
    "yellow-magenta composite-form should require blank-yellow-form")
  assert_true(has_ingredient(recipes["trichromatic-permit-production"], "composite-chroma-ribbon"),
    "trichromatic-permit should require composite-chroma-ribbon")
  assert_true(has_ingredient(recipes["unified-operations-charter-production"], "electromagnetic-operating-license"),
    "unified-operations-charter should require electromagnetic-operating-license")
  assert_true(has_ingredient(recipes["cryogenic-operations-license-production"], "lithium-plate"),
    "cryogenic-operations-license should require lithium-plate")
  assert_true(not has_ingredient(recipes["transfer-emulsion-production"], "taxpayer-money"),
    "transfer-emulsion should not require taxpayer-money")
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
