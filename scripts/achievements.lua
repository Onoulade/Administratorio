-- Scripted goals describe shared world milestones. A player joining after the
-- triggering event must still receive the completed goals stored in that save.
local M = {}

local completed_goals = {
  first_complaint = "first-complaint",
  first_protest = "first-protest",
  first_resolved = "case-closed",
  protest_suppressed = "protest-suppressed",
  department_of_everything = "department-of-everything",
  full_resolution = "full-resolution",
  behemoth_registered = "behemoth-paperwork",
}

function M.sync_player(player)
  if not player then return end
  for flag, name in pairs(completed_goals) do
    if storage.achievements and storage.achievements[flag] then
      player.unlock_achievement(name)
    end
  end
end

return M
