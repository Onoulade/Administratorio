-- Milestones discovers reverse remote interfaces before choosing its preset.
-- No tracker, polling, aliases or access to another mod's storage is needed:
-- regulated crafts and desk outputs use native force production statistics.
local M = require("compat.milestones.presets")

if script and script.active_mods and script.active_mods["Milestones"] then
  remote.add_interface("administratorio-milestones", {
    milestones_presets = M.presets,
  })
end

return M
