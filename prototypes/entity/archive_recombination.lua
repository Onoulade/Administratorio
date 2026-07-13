local planets = require("prototypes.shared.space_age_planets")

local bureau = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
bureau.name = "archive-recombination-bureau"
bureau.icons = {
  {icon = "__administratorio__/graphics/icons/office-building.png", icon_size = 64, tint = {r = 0.75, g = 0.58, b = 0.86, a = 1}},
  {icon = "__administratorio__/graphics/icons/redundant-rubble.png", icon_size = 64, scale = 0.32, shift = {8, 8}},
}
bureau.icon = nil
bureau.minable = {mining_time = 0.5, result = "archive-recombination-bureau"}
bureau.placeable_by = {{item = "archive-recombination-bureau", count = 1}}
bureau.next_upgrade = nil
bureau.crafting_categories = {"archive-recombination"}
bureau.crafting_speed = 1
bureau.energy_usage = "1MW"
bureau.ingredient_count = 3
bureau.module_slots = 0
bureau.allowed_effects = {}
bureau.fast_replaceable_group = nil
bureau.fluid_boxes = {}
bureau.fluid_boxes_off_when_no_fluid_recipe = true
bureau.localised_name = {"entity-name.archive-recombination-bureau"}
bureau.localised_description = {"entity-description.archive-recombination-bureau"}
planets.require_non_vacuum_surface(bureau)

data:extend({bureau})
