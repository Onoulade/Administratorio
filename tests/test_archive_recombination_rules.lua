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
  assert_true(count >= 24, "too few recyclable forms")
  assert_true(count <= 32, "too many recyclable forms: " .. count)
end)

test("every unordered recyclable pair has two or three candidates", function()
  local generated_pairs, invalid = rules.generate_all_pairs()
  assert_eq(#invalid, 0, "invalid pair count")
  local names = taxonomy.recyclable_names()
  assert_eq((#names * (#names - 1)) / 2, (function()
    local count = 0
    for _ in pairs(generated_pairs) do count = count + 1 end
    return count
  end)(), "pair count")
  for key, pair in pairs(generated_pairs) do
    assert_true(#pair.candidates == 2 or #pair.candidates == 3, key .. " candidate count")
  end
end)

test("candidate tier and identity rules hold for every pair", function()
  local generated = rules.generate_all_pairs()
  for key, pair in pairs(generated) do
    local left = taxonomy.get(pair.left)
    local right = taxonomy.get(pair.right)
    local minimum_rank = math.min(left.rank, right.rank)
    local maximum_rank = math.min(math.max(left.rank, right.rank), minimum_rank + 1)
    local colors = rules.union_colors(left.colors, right.colors)
    for _, candidate in ipairs(pair.candidates) do
      assert_true(candidate.name ~= pair.left and candidate.name ~= pair.right, key .. " returned an input")
      assert_true(candidate.rank >= minimum_rank, key .. " downgraded below the lower input")
      assert_true(candidate.rank <= maximum_rank, key .. " jumped tiers")
      assert_true(rules.colors_subset(candidate.colors, colors), key .. " invented a color")
      assert_true(not taxonomy.restricted_documents[candidate.name], key .. " produced a restricted document")
    end
  end
end)

test("input order does not affect the mapping", function()
  local forward = rules.generate_candidates("work-order", "carbon-offset-certificate-basic")
  local reverse = rules.generate_candidates("carbon-offset-certificate-basic", "work-order")
  assert_eq(#forward, #reverse)
  for index = 1, #forward do
    assert_eq(forward[index].name, reverse[index].name)
    assert_eq(forward[index].weight, reverse[index].weight)
  end
end)

test("basic inputs cannot produce executive paperwork", function()
  local candidates = rules.generate_candidates("work-order", "carbon-offset-certificate-basic")
  assert_true(candidates and #candidates >= 2)
  for _, candidate in ipairs(candidates) do
    assert_true(candidate.rank == 0, "basic pair produced rank " .. candidate.rank)
  end
end)

test("colored candidates never invent magenta", function()
  local candidates = rules.generate_candidates("blank-cyan-form", "blank-yellow-form")
  assert_true(candidates and #candidates >= 2)
  for _, candidate in ipairs(candidates) do
    assert_true(not candidate.colors.magenta, candidate.name .. " invented magenta")
  end
end)

test("deterministic rolls are stable and change with attempt count", function()
  local first = rules.deterministic_roll(42, 1, "blank-form", "work-order", "success")
  assert_eq(first, rules.deterministic_roll(42, 1, "blank-form", "work-order", "success"))
  assert_true(first ~= rules.deterministic_roll(42, 2, "blank-form", "work-order", "success"))
end)

test("technology filtering excludes locked outputs", function()
  local force = {
    valid = true,
    technologies = {
      ["automation"] = {researched = true},
      ["discovery-bullshit"] = {researched = false},
    },
  }
  local available = rules.available_candidates({
    {name = "work-order", unlock_technology = "automation", weight = 60},
    {name = "safety-waiver", unlock_technology = "discovery-bullshit", weight = 40},
  }, force)
  assert_eq(#available, 1)
  assert_eq(available[1].name, "work-order")
end)

if failed > 0 then
  for _, err in ipairs(errors) do io.stderr:write(err .. "\n") end
  os.exit(1)
end

print(string.format("Archive recombination rule tests: %d passed, %d failed", passed, failed))
