local passed, failed = 0, 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    io.stderr:write(name .. ": " .. tostring(err) .. "\n")
  end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)") or "./"
mod_root = mod_root:gsub("tests/$", "")
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

local victory = require("scripts.victory")
local metrics = require("scripts.metrics")

test("base-only rocket launches retain Administratorio victory", function()
  assert(victory.should_finish_on_rocket_launch(false) == true)
end)

test("Space Age cargo launches do not trigger Administratorio victory", function()
  assert(victory.should_finish_on_rocket_launch(true) == false)
end)

test("cargo launch statistics remain available in Space Age", function()
  local stats = {}
  assert(victory.record_rocket_launch(stats) == 1)
  assert(victory.record_rocket_launch(stats) == 2)
  assert(stats.rockets_launched == 2)
end)

test("every victory metric migrates old saves with a zero default", function()
  local stats = {cases_resolved = 7}
  metrics.ensure(stats)
  assert(stats.cases_resolved == 7)
  for _, keys in pairs(metrics.KEY_GROUPS) do
    for _, key in ipairs(keys) do
      assert(type(stats[key]) == "number", key .. " should be initialized")
    end
  end
end)

test("metric recording rejects typos and accumulates successful work", function()
  local stats = metrics.ensure({})
  assert(metrics.increment(stats, "personnel_routed") == 1)
  assert(metrics.increment(stats, "personnel_routed", 4) == 5)
  assert(not pcall(metrics.increment, stats, "personnel_routeed", 1))
end)

test("base victory rows hide expansion-only accounting", function()
  local stats = metrics.ensure({tourists_served = 3, territories_arbitrated = 2})
  local captions = {}
  for _, section in ipairs(victory.SECTIONS) do
    for _, row in ipairs(victory.rows_for_section(section, stats, 12, false)) do
      captions[row.caption] = row.value
    end
  end
  assert(captions["gui.stat-forms-crafted"] == 12)
  assert(captions["gui.stat-tourists-served"] == nil)
  assert(captions["gui.stat-territories-arbitrated"] == nil)
end)

test("Space Age victory rows include every offworld counter", function()
  local stats = metrics.ensure({territories_arbitrated = 2})
  local captions = {}
  for _, section in ipairs(victory.SECTIONS) do
    for _, row in ipairs(victory.rows_for_section(section, stats, 0, true)) do
      captions[row.caption] = row.value
    end
  end
  assert(captions["gui.stat-territories-arbitrated"] == 2)
  assert(captions["gui.stat-tourists-served"] == 0)
end)

test("the victory screen exposes every registered lifetime metric", function()
  local shown = {}
  for _, section in ipairs(victory.SECTIONS) do
    for _, row in ipairs(section.rows) do
      if row.metric then
        assert(metrics.is_known(row.metric), row.metric .. " is not registered")
        assert(not shown[row.metric], row.metric .. " is shown twice")
        shown[row.metric] = true
      end
    end
  end
  for _, keys in pairs(metrics.KEY_GROUPS) do
    for _, key in ipairs(keys) do
      assert(shown[key], key .. " is tracked but absent from the victory screen")
    end
  end
end)

if failed > 0 then
  os.exit(1)
end

print(string.format("Victory runtime tests: %d passed, %d failed", passed, failed))
