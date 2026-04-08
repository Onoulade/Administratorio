-- ADMINISTRATORIO: ENTITY PROTOTYPES LOADER

local feature_flags = require("feature_flags")
local space_age_enabled = feature_flags.space_age_enabled()

require("prototypes.categories")
require("prototypes.resources")
require("prototypes.entity.admin-buildings")
require("prototypes.entity.vehicles")
require("prototypes.entity.printers")
if space_age_enabled then
  require("prototypes.entity.space_age")
end
require("prototypes.entity.pneumatic")
