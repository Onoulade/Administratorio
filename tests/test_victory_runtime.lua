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

if failed > 0 then
  os.exit(1)
end

print(string.format("Victory runtime tests: %d passed, %d failed", passed, failed))
