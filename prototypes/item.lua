-- ADMINISTRATORIO: ITEM PROTOTYPES LOADER

local feature_flags = require("feature_flags")
local working_hours_enabled = feature_flags.working_hours_enabled()
local space_age_enabled = feature_flags.space_age_enabled()

if not data.raw["damage-type"]["bureaucratic-logic"] then
  data:extend({
    { type = "damage-type", name = "bureaucratic-logic" },
    { type = "ammo-category", name = "bureaucracy" },
    { type = "ammo-category", name = "trajectory-compliance" }
  })
end

require("prototypes.item.groups")
require("prototypes.item.paperwork")
require("prototypes.item.resolution")
require("prototypes.item.economy")
require("prototypes.item.buildings")
if space_age_enabled then
  require("prototypes.item.space_age")
  require("prototypes.item.fulgora_archives")
end
if working_hours_enabled then
  require("prototypes.item.modules")
end
require("prototypes.item.capsules-and-fluids")
