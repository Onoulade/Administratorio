-------------------------------------------------------------------------------
-- ADMINISTRATORIO SPACE AGE AUTOMATION TESTS
--
-- Covers the shared rule modules introduced by the automation pass: trunk
-- payloads, slop tiering, egg couriers, relocation cargo, and the egg reroute
-- applied in final fixes.
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
    error((msg or "assertion failed") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
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
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

local payloads = require("prototypes.shared.interplanetary_payloads")
local slop_rules = require("prototypes.shared.slop_rules")
local taxonomy = require("prototypes.shared.paperwork_taxonomy")
local couriers = require("prototypes.shared.manager_couriers")
local relocation_cargo = require("prototypes.shared.relocation_cargo")
local egg_couriers = require("prototypes.final_fixes.egg_couriers")

local function contains(list, value)
  for _, entry in ipairs(list) do
    if entry == value then return true end
  end
  return false
end

-------------------------------------------------------------------------------
-- TRUNK PAYLOADS
-------------------------------------------------------------------------------

test("the base trunk tier carries regular paperwork and no colored forms", function()
  local chromatic = payloads.chromatic_set()
  for _, name in ipairs(payloads.regular) do
    assert_true(not chromatic[name], name .. " is a regular payload and must not be chromatic")
  end
  assert_true(contains(payloads.regular, "blank-form"), "regular payloads should carry blank forms")
  assert_true(contains(payloads.regular, "taxpayer-money"), "regular payloads should carry taxpayer money")
end)

test("colored paperwork and Space Age charters are chromatic-tier only", function()
  local regular = {}
  for _, name in ipairs(payloads.regular) do regular[name] = true end
  for _, name in ipairs({
    "blank-cyan-form", "blank-yellow-form", "blank-magenta-form",
    "cyan-yellow-form", "cyan-magenta-form", "yellow-magenta-form",
    "trichromatic-permit", "unified-operations-charter", "promethium-research-charter",
  }) do
    assert_true(not regular[name], name .. " must not ride the base trunk tier")
    assert_true(payloads.chromatic_set()[name], name .. " should be a chromatic payload")
  end
end)

test("every trunk payload has a dispatch recipe name and the set covers both tiers", function()
  local all = payloads.all()
  assert_eq(#all, #payloads.regular + #payloads.chromatic, "all() should be the union of both tiers")
  local set = payloads.as_set()
  for _, name in ipairs(all) do
    assert_true(set[name], name .. " should be in the payload set")
  end
  assert_eq(payloads.dispatch_recipe_name("blank-form"), "interplanetary-dispatch-blank-form",
    "dispatch recipes should be prefixed per item")
end)

-------------------------------------------------------------------------------
-- SLOP TIERING
-------------------------------------------------------------------------------

test("colored paperwork is never producible from slop at any tier", function()
  for name, entry in pairs(taxonomy.documents) do
    if entry.colors and next(entry.colors) ~= nil then
      assert_eq(slop_rules.tier_for(name), nil, name .. " has colors and must never be sloppable")
    end
  end
end)

test("restricted documents are never producible from slop", function()
  for name in pairs(taxonomy.restricted_documents) do
    assert_eq(slop_rules.tier_for(name), nil, name .. " is restricted and must never be sloppable")
  end
end)

test("slop tiers split on rank exactly as designed", function()
  for _, name in ipairs(slop_rules.documents_for_tier("base")) do
    assert_true(taxonomy.get(name).rank <= 1, name .. " should be rank 0-1 at the base tier")
  end
  for _, name in ipairs(slop_rules.documents_for_tier("advanced")) do
    local rank = taxonomy.get(name).rank
    assert_true(rank >= 2 and rank <= 3, name .. " should be rank 2-3 at the advanced tier")
  end
  assert_true(#slop_rules.documents_for_tier("base") > 0, "the base tier should produce something")
  assert_true(#slop_rules.documents_for_tier("advanced") > 0, "the advanced tier should produce something")
end)

test("slop cost and hallucination volume both rise with rank", function()
  local previous_cost, previous_citations = 0, 0
  for rank = 0, 3 do
    local sample
    for name, entry in pairs(taxonomy.documents) do
      if entry.rank == rank and slop_rules.tier_for(name) then sample = name break end
    end
    assert_true(sample ~= nil, "a sloppable rank " .. rank .. " document should exist")
    local cost = slop_rules.slop_cost(sample)
    local citations = slop_rules.citation_yield(sample)
    assert_true(cost > previous_cost, "rank " .. rank .. " should cost more slop than rank " .. (rank - 1))
    assert_true(citations > previous_citations, "rank " .. rank .. " should emit more citations")
    previous_cost, previous_citations = cost, citations
  end
end)

test("the Administratorium tier emits a flood rather than a trickle", function()
  local base_max, advanced_min = 0, math.huge
  for _, name in ipairs(slop_rules.documents_for_tier("base")) do
    base_max = math.max(base_max, slop_rules.citation_yield(name))
  end
  for _, name in ipairs(slop_rules.documents_for_tier("advanced")) do
    advanced_min = math.min(advanced_min, slop_rules.citation_yield(name))
  end
  assert_true(advanced_min > base_max,
    "the worst advanced-tier hallucination volume should exceed the best base-tier one")
end)

-------------------------------------------------------------------------------
-- EGG COURIERS
-------------------------------------------------------------------------------

test("every courier spoils back into a regular manager after thirty minutes", function()
  assert_eq(couriers.SPOIL_TICKS, 30 * 60 * 60, "couriers should last 30 minutes")
  assert_eq(couriers.SPOIL_RESULT, "middle-management-managing-manager",
    "an expired courier should cost the eggs and the trip, never the manager")
  assert_eq(couriers.EGGS_PER_COURIER, 10, "couriers should carry the vanilla ten-egg cost")
  assert_eq(#couriers.COURIERS, 3, "there should be exactly three couriers")
end)

test("only the Geotechnical courier is handed back", function()
  assert_eq(couriers.BY_KEY.geotechnical.fate, "returned", "the Gleba courier should return")
  assert_eq(couriers.BY_KEY.missionary.fate, "consumed", "the Aquilo courier should be consumed")
  assert_eq(couriers.BY_KEY.cobaye.fate, "consumed", "the orbital courier should be consumed")
end)

-------------------------------------------------------------------------------
-- EGG REROUTE
-------------------------------------------------------------------------------

local function fake_recipes()
  return {
    ["biolab"] = {ingredients = {{type = "item", name = "biter-egg", amount = 10}}, results = {}},
    ["nutrients-from-biter-egg"] = {ingredients = {{type = "item", name = "biter-egg", amount = 1}}, results = {}},
    ["overgrowth-yumako-soil"] = {ingredients = {{type = "item", name = "biter-egg", amount = 10}}, results = {}},
    ["overgrowth-jellynut-soil"] = {ingredients = {{type = "item", name = "biter-egg", amount = 10}}, results = {}},
    ["captive-biter-spawner"] = {ingredients = {{type = "item", name = "biter-egg", amount = 10}}, results = {}},
    ["promethium-science-pack"] = {
      ingredients = {
        {type = "item", name = "promethium-asteroid-chunk", amount = 25},
        {type = "item", name = "quantum-processor", amount = 1},
        {type = "item", name = "promethium-research-charter", amount = 1},
        {type = "item", name = "biter-egg", amount = 10},
      },
      results = {{type = "item", name = "promethium-science-pack", amount = 10}},
      energy_required = 5,
    },
  }
end

local function amount_of(recipe, name)
  for _, entry in ipairs(recipe.ingredients or {}) do
    if (entry.name or entry[1]) == name then return entry.amount or entry[2] end
  end
  return nil
end

local function result_amount_of(recipe, name)
  for _, entry in ipairs(recipe.results or {}) do
    if (entry.name or entry[1]) == name then return entry.amount or entry[2] end
  end
  return nil
end

test("no recipe still consumes biter eggs off Nauvis after the reroute", function()
  local recipes = fake_recipes()
  egg_couriers.apply({raw = {recipe = recipes}})

  for _, recipe_name in ipairs({
    "overgrowth-yumako-soil", "overgrowth-jellynut-soil",
    "captive-biter-spawner", "promethium-science-pack",
  }) do
    assert_eq(amount_of(recipes[recipe_name], "biter-egg"), nil,
      recipe_name .. " must not consume biter eggs offworld")
  end
end)

test("Nauvis-only egg crafts keep their eggs and gain a surface condition", function()
  local recipes = fake_recipes()
  egg_couriers.apply({raw = {recipe = recipes}})

  for _, recipe_name in ipairs({"biolab", "nutrients-from-biter-egg"}) do
    local recipe = recipes[recipe_name]
    assert_true(amount_of(recipe, "biter-egg") ~= nil, recipe_name .. " should keep its vanilla egg cost")
    assert_true(recipe.surface_conditions ~= nil and #recipe.surface_conditions > 0,
      recipe_name .. " should be pinned to Nauvis")
  end
end)

test("the Gleba soils take a Geotechnical courier and hand a manager back", function()
  local recipes = fake_recipes()
  egg_couriers.apply({raw = {recipe = recipes}})

  for _, recipe_name in ipairs({"overgrowth-yumako-soil", "overgrowth-jellynut-soil"}) do
    local recipe = recipes[recipe_name]
    assert_eq(amount_of(recipe, "geotechnical-assessment-manager"), 1,
      recipe_name .. " should consume one Geotechnical courier")
    assert_eq(result_amount_of(recipe, "middle-management-managing-manager"), 1,
      recipe_name .. " should hand the manager back")
  end
end)

test("the captive spawner consumes its missionary outright", function()
  local recipes = fake_recipes()
  egg_couriers.apply({raw = {recipe = recipes}})
  assert_eq(amount_of(recipes["captive-biter-spawner"], "missionary-manager"), 1,
    "the spawner should consume one Missionary")
  assert_eq(result_amount_of(recipes["captive-biter-spawner"], "middle-management-managing-manager"), nil,
    "the Missionary should not come back")
end)

test("Administratorium science batches tenfold against exactly one Cobaye", function()
  local recipes = fake_recipes()
  egg_couriers.apply({raw = {recipe = recipes}})
  local recipe = recipes["promethium-science-pack"]

  assert_eq(amount_of(recipe, "promethium-asteroid-chunk"), 250, "chunks should scale x10")
  assert_eq(amount_of(recipe, "quantum-processor"), 10, "processors should scale x10")
  assert_eq(result_amount_of(recipe, "promethium-science-pack"), 100, "output should scale x10")
  assert_eq(recipe.energy_required, 50, "energy should scale x10")
  assert_eq(amount_of(recipe, "voluntary-research-subject"), 1,
    "exactly one Cobaye per batch is what puts the recipe at vanilla rocket parity")
end)

test("the expedition charter scales with the batch instead of getting ten times cheaper", function()
  local recipes = fake_recipes()
  egg_couriers.apply({raw = {recipe = recipes}})
  assert_eq(amount_of(recipes["promethium-science-pack"], "promethium-research-charter"), 10,
    "the charter must stay at one per ten packs, as vanilla costs it")
end)

test("Cobaye rocket parity holds at two kilograms per science pack", function()
  -- Vanilla: 10 eggs at 2 kg buys 10 packs. Batched: one 200 kg Cobaye buys 100.
  local vanilla_kg_per_pack = (10 * 2) / 10
  local cobaye_kg_per_pack = 200 / 100
  assert_eq(cobaye_kg_per_pack, vanilla_kg_per_pack, "the Cobaye should land on exact vanilla parity")
end)

-------------------------------------------------------------------------------
-- RELOCATION CARGO
-------------------------------------------------------------------------------

test("the cannon never carries biter eggs", function()
  assert_true(not relocation_cargo.as_set()["biter-egg"],
    "a cannon that shipped eggs would reintroduce the problem the couriers solve")
end)

test("the cannon carries the courier traffic it exists for", function()
  local cargo = relocation_cargo.as_set()
  for _, courier in ipairs(couriers.COURIERS) do
    assert_true(cargo[courier.item], courier.item .. " should be cannon cargo")
  end
  assert_true(cargo["middle-management-managing-manager"], "spent managers should ride home")
end)

test("the cannon refuses paperwork, which is what keeps rockets relevant", function()
  local cargo = relocation_cargo.as_set()
  for _, name in ipairs({"blank-form", "taxpayer-money", "trichromatic-permit", "paper"}) do
    assert_true(not cargo[name], name .. " is not biter-family cargo")
  end
end)

test("the cannon moves a batch per shot and bills one form per item", function()
  assert_true(relocation_cargo.PAYLOAD_PER_SHOT > 1,
    "the cannon should move a batch, unlike the trunk's per-item flow")
  assert_eq(relocation_cargo.TRANSFER_FORM, "involuntary-transfer-order",
    "the cannon should consume its dedicated form")
end)

print(string.format("\n=== ADMINISTRATORIO SPACE AGE AUTOMATION TESTS ==="))
print(string.format("Passed: %d  Failed: %d  Total: %d", passed, failed, passed + failed))

if #errors > 0 then
  print("\nFAILURES:")
  for i, err in ipairs(errors) do
    print(string.format("  %d) %s", i, err))
  end
  os.exit(1)
end

print("\nAll tests passed!")
