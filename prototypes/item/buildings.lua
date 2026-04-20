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
  { type = "item", name = "tube-intake",                icon = item_icons .. "pneumatic/intake.png",  icon_size = 32, subgroup = "admin-infrastructure", order = "e1", place_result = "tube-intake",                stack_size = 50 },
  { type = "item", name = "tube-outtake",               icon = item_icons .. "pneumatic/outtake.png", icon_size = 32, subgroup = "admin-infrastructure", order = "e2", place_result = "tube-outtake",               stack_size = 50 },

  -- Buildings
  { type = "item", name = "field-office",              icons = {{icon = item_icons .. "office-building.png", icon_size = 64, tint = {r=0.75, g=0.65, b=0.45, a=1}}}, subgroup = "admin-buildings", order = "a0", place_result = "field-office",              stack_size = 50 },
  { type = "item", name = "office-desk",               icon = item_icons .. "office-building.png",                              icon_size = 64,  subgroup = "admin-buildings", order = "a",  place_result = "office-desk",               stack_size = 50, localised_description = disabled_item_description("office-desk-no-working-hours") },
  { type = "item", name = "admin-station",             icon = item_icons .. "admin-desk.png",                                  icon_size = 64,  subgroup = "admin-biter-buildings", order = "a",  place_result = "admin-station",             stack_size = 50 },
  { type = "item", name = "resolution-office",         icon = entity_graphics .. "scrubber/base/scrubber-icon.png",                  icon_size = 64,  subgroup = "admin-biter-buildings", order = "b", place_result = "resolution-office",         stack_size = 50 },
  { type = "item", name = "greenhouse",                icon = item_icons .. "greenhouse.png",                                   icon_size = 64,  subgroup = "admin-buildings", order = "c",  place_result = "greenhouse",                stack_size = 50 },
  { type = "item", name = "corporate-breakroom",       icon = "__administratorio__/graphics/icons/warehouse-icon.png",         icon_size = 64,  subgroup = "admin-buildings", order = "d",  place_result = "corporate-breakroom",       stack_size = 20, localised_description = disabled_item_description("corporate-breakroom-no-working-hours") },
  { type = "item", name = "union-headquarters",        icon = "__administratorio__/graphics/icons/lufter-icon.png",            icon_size = 64,  subgroup = "admin-buildings", order = "f",  place_result = "union-headquarters",        stack_size = 10, localised_description = disabled_item_description("union-headquarters-no-working-hours") },
  { type = "item", name = "propaganda-distillery",     icon = entity_graphics .. "propaganda-distillery/base/fuel-refinery-icon.png", icon_size = 64, subgroup = "admin-buildings", order = "g",  place_result = "propaganda-distillery",     stack_size = 20 },
  { type = "item", name = "mechanical-printer",        icon = "__administratorio__/graphics/entities/mechanical-printer/icon.png", icon_size = 64,  subgroup = "admin-printers", order = "a",  place_result = "mechanical-printer",        stack_size = 20 },
  { type = "item", name = "printer-t1",                icon = "__administratorio__/graphics/icons/mini-assembler-icon.png",    icon_size = 64,  subgroup = "admin-printers", order = "b",  place_result = "printer-t1",                stack_size = 50 },
  { type = "item", name = "printer-t2",                icon = "__administratorio__/graphics/icons/steel-forge-icon.png",       icon_size = 64,  subgroup = "admin-printers", order = "c",  place_result = "printer-t2",                stack_size = 50 },
  { type = "item", name = "transit-permit-chest",      icon = "__base__/graphics/icons/steel-chest.png",                         icon_size = 64,  subgroup = "admin-infrastructure", order = "f1", stack_size = 50 },
})
