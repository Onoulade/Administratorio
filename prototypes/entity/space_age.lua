local entity_graphics = "__administratorio__/graphics/entities/"
local sound_path = "__administratorio__/sound/buildings/"

local function placeable_by_item(name)
  return {
    {item = name, count = 1},
  }
end

local formation_center = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
formation_center.name = "formation-center"
formation_center.icon = "__base__/graphics/icons/biter-spawner.png"
formation_center.icon_size = 64
formation_center.minable = {mining_time = 0.2, result = "formation-center"}
formation_center.placeable_by = placeable_by_item("formation-center")
formation_center.next_upgrade = nil
formation_center.crafting_categories = {"workforce-formation"}
formation_center.crafting_speed = 1.5
formation_center.energy_usage = "500kW"
formation_center.energy_source = {type = "electric", usage_priority = "secondary-input"}
formation_center.ingredient_count = 6
formation_center.module_slots = 4
formation_center.allowed_effects = {"speed", "productivity", "consumption", "pollution"}

local chromatic_printer = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
chromatic_printer.name = "chromatic-printer"
chromatic_printer.icon = "__administratorio__/graphics/icons/steel-forge-icon.png"
chromatic_printer.icon_size = 64
chromatic_printer.minable = {mining_time = 0.2, result = "chromatic-printer"}
chromatic_printer.placeable_by = {{item = "chromatic-printer", count = 1}}
chromatic_printer.next_upgrade = nil
chromatic_printer.crafting_categories = {"printing", "printing-advanced", "printing-workorder", "printing-chromatic"}
chromatic_printer.crafting_speed = 3
chromatic_printer.energy_usage = "350kW"
chromatic_printer.energy_source = {type = "electric", usage_priority = "secondary-input"}
chromatic_printer.collision_box = {{-1.2, -1.2}, {1.2, 1.2}}
chromatic_printer.selection_box = {{-1.5, -1.5}, {1.5, 1.5}}
chromatic_printer.graphics_set = {
  animation = {
    layers = {
      {filename = entity_graphics .. "printer-t2/steel-forge.png", width = 256, height = 301, frame_count = 1, scale = 0.38, shift = {0, -0.15}},
    }
  }
}
chromatic_printer.working_sound = {
  sound = {filename = sound_path .. "industrial-printer-loop.ogg", volume = 0.55},
  idle_sound = {filename = "__base__/sound/idle1.ogg"}
}

data:extend({formation_center, chromatic_printer})
