local item_icons = "__administratorio__/graphics/icons/"
local entity_graphics = "__administratorio__/graphics/entities/"
local feature_flags = require("feature_flags")
local working_hours_enabled = feature_flags.working_hours_enabled()

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

  -- Buildings
  { type = "item", name = "field-office",              icons = {{icon = item_icons .. "office-building.png", icon_size = 64, tint = {r=0.75, g=0.65, b=0.45, a=1}}}, subgroup = "admin-biter-buildings", order = "a0", place_result = "field-office",              stack_size = 50 },
  { type = "item", name = "office-desk",               icon = item_icons .. "office-building.png",                              icon_size = 64,  subgroup = "admin-buildings", order = "a",  place_result = "office-desk",               stack_size = 50, localised_description = disabled_item_description("office-desk-no-working-hours") },
  { type = "item", name = "biterport",                 icon = item_icons .. "biterport.png", icon_size = 64, subgroup = "admin-biter-buildings", order = "a1", place_result = "biterport-placement-preview", stack_size = 20 },
  { type = "item", name = "admin-station",             icon = item_icons .. "admin-desk.png",                                  icon_size = 64,  subgroup = "admin-biter-buildings", order = "a",  place_result = "admin-station",             stack_size = 50 },
  { type = "item", name = "formation-center",          icon = item_icons .. "formation-center.png", icon_size = 64, subgroup = "admin-biter-buildings", order = "a2", place_result = "formation-center", stack_size = 20 },
  { type = "item", name = "petition-counter",          icon = item_icons .. "office-building.png",                             icon_size = 64,  subgroup = "admin-biter-buildings", order = "a3", place_result = "petition-counter",          stack_size = 50 },
  { type = "item", name = "resolution-office",         icon = entity_graphics .. "scrubber/base/scrubber-icon.png",                  icon_size = 64,  subgroup = "admin-biter-buildings", order = "b", place_result = "resolution-office",         stack_size = 50 },
  { type = "item", name = "greenhouse",                icon = item_icons .. "greenhouse.png",                                   icon_size = 64,  subgroup = "admin-buildings", order = "c",  place_result = "greenhouse",                stack_size = 50 },
  { type = "item", name = "corporate-breakroom",       icon = "__administratorio__/graphics/icons/warehouse-icon.png",         icon_size = 64,  subgroup = "admin-buildings", order = "d",  place_result = "corporate-breakroom",       stack_size = 20, localised_description = disabled_item_description("corporate-breakroom-no-working-hours") },
  { type = "item", name = "union-headquarters",        icon = "__administratorio__/graphics/entities/union-hq/icon.png",            icon_size = 64,  subgroup = "admin-buildings", order = "f",  place_result = "union-headquarters",        stack_size = 10, localised_description = disabled_item_description("union-headquarters-no-working-hours") },
  { type = "item", name = "propaganda-distillery",     icon = entity_graphics .. "propaganda-distillery/base/fuel-refinery-icon.png", icon_size = 64, subgroup = "admin-buildings", order = "g",  place_result = "propaganda-distillery",     stack_size = 20 },
  { type = "item", name = "mechanical-printer",        icon = "__administratorio__/graphics/entities/mechanical-printer/icon.png", icon_size = 64,  subgroup = "admin-printers", order = "a",  place_result = "mechanical-printer",        stack_size = 20 },
  { type = "item", name = "printer-t1",                icon = "__administratorio__/graphics/icons/printer-t1-icon.png", icon_size = 64, subgroup = "admin-printers", order = "b", place_result = "printer-t1", stack_size = 50 },
  { type = "item", name = "printer-t2",                icon = "__administratorio__/graphics/icons/printer-t2-icon.png", icon_size = 64, subgroup = "admin-printers", order = "c", place_result = "printer-t2", stack_size = 50 },
  { type = "item", name = "transit-permit-chest",      icon = "__base__/graphics/icons/steel-chest.png",                         icon_size = 64,  subgroup = "admin-infrastructure", order = "f1", stack_size = 50 },
})
