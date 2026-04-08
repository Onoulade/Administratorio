local entity_graphics = "__administratorio__/graphics/entities/"
local sound_path = "__administratorio__/sound/buildings/"

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

data:extend({chromatic_printer})
