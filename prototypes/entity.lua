-- ADMINISTRATORIO: ENTITY PROTOTYPES LOADER

local feature_flags = require("feature_flags")
local space_age_enabled = feature_flags.space_age_enabled()

require("prototypes.categories")
require("prototypes.resources")
require("prototypes.entity.admin-buildings")
if feature_flags.working_hours_enabled() then
  require("prototypes.entity.administrative-clock")
end
require("prototypes.entity.vehicles")
require("prototypes.entity.printers")
if space_age_enabled then
  require("prototypes.entity.space_age")
  require("prototypes.entity.archive_recombination")
end
require("prototypes.entity.pneumatic")

if space_age_enabled then
  require("prototypes.entity.optical_fiber")
end
