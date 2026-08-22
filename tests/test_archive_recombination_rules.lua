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

local function assert_true(value, message)
  if not value then error(message or "assertion failed", 2) end
end

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)") or "./"
mod_root = mod_root:gsub("tests/$", "")
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

local taxonomy = require("prototypes.shared.paperwork_taxonomy")
local rules = require("scripts.archive_recombination_rules")

test("taxonomy remains within the planned prototype budget", function()
  local count = #taxonomy.recyclable_names()
  assert_true(count >= 24, "too few reassignable forms")
  assert_true(count <= 32, "too many reassignable forms: " .. count)
end)

test("every supported form has exactly three independent candidates", function()
  local assignments, invalid = rules.generate_all_reassignments()
  assert_eq(#invalid, 0, "invalid reassignment count")
  local count = 0
  for input_name, assignment in pairs(assignments) do
    count = count + 1
    assert_eq(assignment.input, input_name)
    assert_eq(#assignment.candidates, rules.CANDIDATE_COUNT, input_name .. " candidate count")
  end
  assert_eq(count, #taxonomy.recyclable_names(), "reassignment recipe count")
end)

test("candidate tier color and identity rules hold for every form", function()
  local assignments = rules.generate_all_reassignments()
  for input_name, assignment in pairs(assignments) do
    local input = taxonomy.get(input_name)
    local seen = {}
    for _, candidate in ipairs(assignment.candidates) do
      assert_true(candidate.name ~= input_name, input_name .. " returned itself")
      assert_true(not seen[candidate.name], input_name .. " repeated " .. candidate.name)
      seen[candidate.name] = true
      assert_eq(candidate.rank, input.rank, input_name .. " crossed a progression band")
      assert_true(rules.colors_subset(candidate.colors, input.colors), input_name .. " invented a color")
      assert_true(not taxonomy.restricted_documents[candidate.name], input_name .. " produced a restricted form")
    end
  end
end)

test("basic forms cannot produce executive paperwork", function()
  for _, candidate in ipairs(assert(rules.generate_candidates("work-order"))) do
    assert_eq(candidate.rank, 0)
  end
end)

test("colorless forms cannot create chromatic forms", function()
  for _, candidate in ipairs(assert(rules.generate_candidates("management-approval-written"))) do
    assert_eq(rules.color_count(candidate.colors), 0, candidate.name .. " invented a color")
  end
end)

test("colored forms cannot invent an unavailable color", function()
  for _, candidate in ipairs(assert(rules.generate_candidates("blank-cyan-form"))) do
    assert_true(not candidate.colors.yellow, candidate.name .. " invented yellow")
    assert_true(not candidate.colors.magenta, candidate.name .. " invented magenta")
  end
end)

test("candidate mappings are stable", function()
  local first = assert(rules.generate_candidates("carbon-offset-certificate-basic"))
  local second = assert(rules.generate_candidates("carbon-offset-certificate-basic"))
  for index = 1, rules.CANDIDATE_COUNT do
    assert_eq(first[index].name, second[index].name)
  end
end)

test("reassignment recipes use a distinct namespace and twenty-five percent rolls", function()
  assert_eq(rules.recipe_name("work-order"), "work-order-archive-reassignment")
  assert_eq(rules.OUTPUT_PROBABILITY, 0.25)
end)

if failed > 0 then
  for _, err in ipairs(errors) do io.stderr:write(err .. "\n") end
  os.exit(1)
end

print(string.format("Archive reassignment rule tests: %d passed, %d failed", passed, failed))
