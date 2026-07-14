local planets = require("prototypes.shared.space_age_planets")

local bureau = table.deepcopy(data.raw.furnace["recycler"])
bureau.name = "archive-recombination-bureau"
bureau.icons = {
  {icon = "__quality__/graphics/icons/recycler.png", icon_size = 64, tint = {r = 0.82, g = 0.68, b = 0.96, a = 1}},
  {icon = "__administratorio__/graphics/icons/blank-form.png", icon_size = 64, scale = 0.34, shift = {8, 8}},
}
bureau.icon = nil
bureau.minable = {mining_time = 0.5, result = "archive-recombination-bureau"}
bureau.placeable_by = {{item = "archive-recombination-bureau", count = 1}}
bureau.crafting_categories = {"archive-reassignment"}
bureau.source_inventory_size = 1
bureau.result_inventory_size = 12
bureau.energy_usage = "1MW"
bureau.crafting_speed = 0.5
bureau.fast_replaceable_group = nil
bureau.next_upgrade = nil
bureau.localised_name = {"entity-name.archive-recombination-bureau"}
bureau.localised_description = {"entity-description.archive-recombination-bureau"}
planets.require_non_vacuum_surface(bureau)

data:extend({bureau})
