-- ADMINISTRATORIO: RECIPE PROTOTYPES LOADER

local feature_flags = require("feature_flags")
local working_hours_enabled = feature_flags.working_hours_enabled()
local space_age_enabled = feature_flags.space_age_enabled()

require("prototypes.recipe.paperwork")
require("prototypes.recipe.resolution")
require("prototypes.recipe.economy")
require("prototypes.recipe.buildings")
if space_age_enabled then
  require("prototypes.recipe.space_age")
  require("prototypes.recipe.fulgora_archives")
  require("prototypes.recipe.planetary_abundance")
end
if working_hours_enabled then
  require("prototypes.recipe.modules")
end
require("prototypes.recipe.production")

-- Printer paper masks read the selected recipe's primary crafting tint.
-- Apply it after every Administratorio printing recipe has been registered.
require("prototypes.shared.printing_tints").apply(data.raw.recipe)
