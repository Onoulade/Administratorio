local root = debug.getinfo(1, "S").source:match("@(.*/)"):gsub("tests/$", "")
package.path = root .. "?.lua;" .. root .. "?/init.lua;" .. package.path
local ai = require("scripts.unit_ai_settings")

local settings = {
  allow_destroy_when_commands_fail = true,
  allow_try_return_to_spawner = true,
  join_attacks = true,
}
local unit = {valid = true, type = "unit", ai_settings = settings}
assert(ai.apply_managed_unit_settings(unit))
assert(settings.allow_destroy_when_commands_fail == false)
assert(settings.allow_try_return_to_spawner == false)
assert(settings.join_attacks == false)
assert(settings.destroy_when_commands_fail == nil)

assert(ai.reset_regular_unit_settings(unit))
assert(settings.allow_destroy_when_commands_fail == true)
assert(settings.allow_try_return_to_spawner == true)
assert(settings.join_attacks == true)

print("Unit AI settings tests passed")
