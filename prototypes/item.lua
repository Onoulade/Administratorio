-- ADMINISTRATORIO: ITEM PROTOTYPES LOADER

local feature_flags = require("feature_flags")
local working_hours_enabled = feature_flags.working_hours_enabled()

if not data.raw["damage-type"]["bureaucratic-logic"] then
  data:extend({
    { type = "damage-type", name = "bureaucratic-logic" },
    { type = "ammo-category", name = "bureaucracy" }
  })
end

require("prototypes.item.groups")
require("prototypes.item.paperwork")
require("prototypes.item.resolution")
require("prototypes.item.economy")
require("prototypes.item.buildings")
if working_hours_enabled then
  require("prototypes.item.modules")
end
require("prototypes.item.capsules-and-fluids")
