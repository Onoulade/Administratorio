local root = debug.getinfo(1, "S").source:match("@(.*/)"):gsub("tests/$", "")
package.path = root .. "?.lua;" .. package.path
local achievements = require("scripts.achievements")
local unlocked = {}
local player = {unlock_achievement = function(name) unlocked[name] = true end}

storage = {}
achievements.sync_player(player)
assert(next(unlocked) == nil, "an empty save must not award achievements")
achievements.sync_player(nil)

storage.achievements = {first_complaint = true, first_resolved = true, first_protest = false,
  resolved_types = {["resolved-smog"] = true}}
achievements.sync_player(player)
assert(unlocked["first-complaint"] and unlocked["case-closed"], "late joiners must receive completed goals")
assert(not unlocked["first-protest"] and not unlocked["full-resolution"], "partial goals must stay locked")

storage.achievements = {first_complaint = true, first_protest = true, first_resolved = true,
  protest_suppressed = true, department_of_everything = true, full_resolution = true,
  behemoth_registered = true}
unlocked = {}
achievements.sync_player(player)
local count = 0
for _ in pairs(unlocked) do count = count + 1 end
assert(count == 7, "all seven completed scripted milestones must be restored")
print("Achievement join synchronisation passed")
