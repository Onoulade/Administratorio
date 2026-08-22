-------------------------------------------------------------------------------
-- SLOP SYNTHESIS RULE TESTS
--
-- Which documents an AI Server may fabricate, derived from the paperwork taxonomy.
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

local slop_rules = require("prototypes.shared.slop_rules")
local taxonomy = require("prototypes.shared.paperwork_taxonomy")

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

print(string.format("\n=== SLOP SYNTHESIS RULE TESTS ==="))
print(string.format("Passed: %d  Failed: %d  Total: %d", passed, failed, passed + failed))

if #errors > 0 then
  print("\nFAILURES:")
  for i, err in ipairs(errors) do
    print(string.format("  %d) %s", i, err))
  end
  os.exit(1)
end

print("\nAll tests passed!")
