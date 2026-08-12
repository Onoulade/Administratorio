local item_icons = "__administratorio__/graphics/icons/"
local entity_graphics = "__administratorio__/graphics/entities/"
local feature_flags = require("feature_flags")
local building_icons = require("prototypes.shared.building_icons")
local working_hours_enabled = feature_flags.working_hours_enabled()
local space_age_enabled = feature_flags.space_age_enabled()

local function disabled_item_description(key)
  if working_hours_enabled then
    return nil
  end
  return {"item-description." .. key}
end

data:extend({
  -- Infrastructure
  { type = "item", name = "pneumatic-pipe",            icons = {{icon = "__base__/graphics/icons/pipe.png", icon_size = 64, tint = {r=0.85, g=0.75, b=0.55, a=1}}},            subgroup = "admin-infrastructure", order = "d1", place_result = "pneumatic-pipe",            stack_size = 100 },
  { type = "item", name = "pneumatic-pipe-to-ground",  icons = {{icon = "__base__/graphics/icons/pipe-to-ground.png", icon_size = 64, tint = {r=0.85, g=0.75, b=0.55, a=1}}}, subgroup = "admin-infrastructure", order = "d2", place_result = "pneumatic-pipe-to-ground",  stack_size = 50 },
  { type = "item", name = "tube-intake",                icon = "__administratorio__/graphics/entities/pneumatic/intake-icon.png",  icon_size = 64, subgroup = "admin-infrastructure", order = "e1", place_result = "tube-intake",                stack_size = 50 },
  { type = "item", name = "tube-outtake",               icon = "__administratorio__/graphics/entities/pneumatic/outtake-icon.png", icon_size = 64, subgroup = "admin-infrastructure", order = "e2", place_result = "tube-outtake",               stack_size = 50 },
  { type = "item", name = "paperwork-provider-chest",   icons = {{icon = "__base__/graphics/icons/wooden-chest.png", icon_size = 64, tint = {r=1.0, g=0.48, b=0.42, a=1}}, {icon = item_icons .. "paper.png", icon_size = 64, scale = 0.34, shift = {8, 8}}}, subgroup = "admin-infrastructure", order = "f2a", place_result = "paperwork-provider-chest", stack_size = 50 },
  { type = "item", name = "paperwork-storage-chest",    icons = {{icon = "__base__/graphics/icons/wooden-chest.png", icon_size = 64, tint = {r=1.0, g=0.86, b=0.38, a=1}}, {icon = item_icons .. "paper.png", icon_size = 64, scale = 0.34, shift = {8, 8}}}, subgroup = "admin-infrastructure", order = "f2b", place_result = "paperwork-storage-chest", stack_size = 50 },
  { type = "item", name = "paperwork-requester-chest",  icons = {{icon = "__base__/graphics/icons/wooden-chest.png", icon_size = 64, tint = {r=0.38, g=0.66, b=1.0, a=1}}, {icon = item_icons .. "paper.png", icon_size = 64, scale = 0.34, shift = {8, 8}}}, subgroup = "admin-infrastructure", order = "f2c", place_result = "paperwork-requester-chest", stack_size = 50 },

  -- Buildings (regular admin buildings)
  { type = "item", name = "office-desk",               icon = item_icons .. "office-building.png",                              icon_size = 64,  subgroup = "admin-buildings", order = "a",  place_result = "office-desk",               stack_size = 50, localised_description = disabled_item_description("office-desk-no-working-hours") },
  { type = "item", name = "greenhouse",                icon = item_icons .. "greenhouse.png",                                   icon_size = 64,  subgroup = "admin-production", order = "a",  place_result = "greenhouse",                stack_size = 50 },
  { type = "item", name = "corporate-breakroom",       icon = item_icons .. "corporate-breakroom-v2.png",                       icon_size = 64,  subgroup = "admin-buildings", order = "d",  place_result = "corporate-breakroom",       stack_size = 20, localised_description = disabled_item_description("corporate-breakroom-no-working-hours") },
  { type = "item", name = "union-headquarters",        icon = "__administratorio__/graphics/entities/union-hq/icon.png",            icon_size = 64,  subgroup = "admin-buildings", order = "f",  place_result = "union-headquarters",        stack_size = 10, localised_description = disabled_item_description("union-headquarters-no-working-hours") },
  { type = "item", name = "propaganda-distillery",     icon = entity_graphics .. "propaganda-distillery/base/fuel-refinery-icon.png", icon_size = 64, subgroup = "admin-buildings", order = "g",  place_result = "propaganda-distillery",     stack_size = 20 },
  { type = "item", name = "mechanical-printer",        icon = "__administratorio__/graphics/icons/mechanical-printer-v2.png", icon_size = 64, subgroup = "admin-printers", order = "a", place_result = "mechanical-printer", stack_size = 20 },
  { type = "item", name = "printer-t1",                icon = "__administratorio__/graphics/icons/printer-t1-v2.png", icon_size = 64, subgroup = "admin-printers", order = "b", place_result = "printer-t1", stack_size = 50 },
  { type = "item", name = "printer-t2",                icon = "__administratorio__/graphics/icons/printer-t2-v2.png", icon_size = 64, subgroup = "admin-printers", order = "c", place_result = "printer-t2", stack_size = 50 },
  { type = "item", name = "transit-permit-chest",      icons = building_icons.transit_permit_chest(), subgroup = "admin-infrastructure", order = "f1", stack_size = 50 },
})

if space_age_enabled then
  data:extend({
  -- Space Buildings (Space tab)
  { type = "item", name = "trajectory-compliance-array",
    icons = building_icons.trajectory_array("junior"),
    subgroup = "admin-space-compliance", order = "a",
    place_result = "trajectory-compliance-array", stack_size = 20
  },
  { type = "item", name = "senior-trajectory-compliance-array",
    icons = building_icons.trajectory_array("senior"),
    subgroup = "admin-space-compliance", order = "b",
    place_result = "senior-trajectory-compliance-array", stack_size = 20
  },
  { type = "item", name = "executive-trajectory-compliance-array",
    icons = building_icons.trajectory_array("executive"),
    subgroup = "admin-space-compliance", order = "c",
    place_result = "executive-trajectory-compliance-array", stack_size = 20
  },
  { type = "item", name = "orbital-employment-cannon",
    icons = {
      {icon = "__space-age__/graphics/icons/railgun-turret.png", icon_size = 64},
      {icon = "__base__/graphics/icons/electric-mining-drill.png", icon_size = 64, scale = 0.38, shift = {8, 8}},
      {icon = item_icons .. "orbital-infrastructure-permit.png", icon_size = 64, scale = 0.38, shift = {8, 8}},
    },
    subgroup = "admin-space-orbital", order = "a",
    place_result = "orbital-employment-cannon", stack_size = 10
  },
  { type = "item", name = "administrative-space-station",
    icon = item_icons .. "space-age/administrative-space-station.png", icon_size = 64,
    subgroup = "admin-space-buildings", order = "a",
    place_result = "administrative-space-station", stack_size = 20
  },
  { type = "item", name = "interplanetary-fax-exchange",
    icon = item_icons .. "space-age/interplanetary-fax-exchange.png", icon_size = 64,
    subgroup = "admin-space-buildings", order = "b",
    place_result = "interplanetary-fax-exchange", stack_size = 20
  },
  { type = "item", name = "fax-emitter",
    icon = item_icons .. "space-age/fax-emitter.png", icon_size = 64,
    subgroup = "admin-space-buildings", order = "c",
    place_result = "fax-emitter", stack_size = 20
  },
  })
end

data:extend({
  -- Biter buildings (Biter Employment tab) - field-office, biterport, admin-station, formation-center, resolution-office
  { type = "item", name = "field-office",              icons = building_icons.field_office(), subgroup = "admin-biter-buildings", order = "a",  place_result = "field-office",              stack_size = 50 },
  { type = "item", name = "biterport",                 icon = item_icons .. "biterport.png", icon_size = 64, subgroup = "admin-biter-buildings", order = "b", place_result = "biterport-placement-preview", stack_size = 20 },
  { type = "item", name = "admin-station",             icon = item_icons .. "admin-desk.png",                                  icon_size = 64,  subgroup = "admin-biter-buildings", order = "c",  place_result = "admin-station",             stack_size = 50 },
  { type = "item", name = "formation-center",          icon = item_icons .. "formation-center.png", icon_size = 64, subgroup = "admin-biter-buildings", order = "d", place_result = "formation-center", stack_size = 20 },
  { type = "item", name = "resolution-office",         icon = entity_graphics .. "scrubber/base/scrubber-icon.png",                  icon_size = 64,  subgroup = "admin-biter-buildings", order = "e", place_result = "resolution-office",         stack_size = 50 },
})
