-------------------------------------------------------------------------------
-- PRINTERS
-- Mechanical Printer: T0 early game (burner, slow)
-- Printer T1: electric, printing category
-- Printer T2: electric, printing + printing-advanced categories
-------------------------------------------------------------------------------
local entity_graphics = "__administratorio__/graphics/entities/"
local sound_path = "__administratorio__/sound/buildings/"

local function placeable_by_item(name)
  return {
    {item = name, count = 1},
  }
end

-- Mechanical Printer (T0 - early game)
local mechanical_printer = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-1"])
mechanical_printer.name = "mechanical-printer"
mechanical_printer.placeable_by = placeable_by_item("mechanical-printer")
mechanical_printer.next_upgrade = "printer-t1"
mechanical_printer.icon = "__administratorio__/graphics/entities/mechanical-printer/icon.png"
mechanical_printer.icon_size = 64
mechanical_printer.minable = { mining_time = 0.2, result = "mechanical-printer" }
mechanical_printer.max_health = 200
mechanical_printer.corpse = "big-remnants"
mechanical_printer.collision_box = {{-0.7, -0.7}, {0.7, 0.7}}
mechanical_printer.selection_box = {{-1, -1}, {1, 1}}
mechanical_printer.crafting_categories = {"printing"}
mechanical_printer.crafting_speed = 0.5
mechanical_printer.energy_usage = "100kW"
mechanical_printer.energy_source = {
  type = "burner",
  fuel_categories = {"chemical"},
  effectivity = 0.8,
  fuel_inventory_size = 1,
  emissions_per_minute = { pollution = 5 }
}
mechanical_printer.graphics_set = {
  animation = {
    layers = {
      { filename = entity_graphics .. "mechanical-printer/animation.png", priority="high", width = 214, height = 226, frame_count = 32, line_length = 8, shift = {0, 0.05}, scale = 0.32 },
      { filename = entity_graphics .. "mechanical-printer/shadow.png", priority="high", width = 190, height = 165, frame_count = 32, line_length = 8, draw_as_shadow = true, shift = {0.15, 0.1}, scale = 0.32 },
    }
  },
  working_visualisations = {
    {
      draw_as_glow = true, fadeout = true,
      animation = { filename = entity_graphics .. "mechanical-printer/light.png", priority = "high", width = 214, height = 226, frame_count = 1, repeat_count = 32, animation_speed = 1, shift = {0, 0.05}, scale = 0.32, draw_as_glow = true, blend_mode = "additive" },
    }
  }
}
mechanical_printer.working_sound = {
  sound = { filename = sound_path .. "industrial-printer-loop.ogg", volume = 0.55 },
  idle_sound = { filename = "__base__/sound/idle1.ogg" }
}

-- Printer T1: electric, printing
local printer_t1 = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-1"])
printer_t1.name = "printer-t1"
printer_t1.placeable_by = placeable_by_item("printer-t1")
printer_t1.icon = "__administratorio__/graphics/icons/mini-assembler-icon.png"
printer_t1.icon_size = 64
printer_t1.minable.result = "printer-t1"
printer_t1.next_upgrade = nil
printer_t1.crafting_categories = {"printing", "printing-workorder"}
printer_t1.crafting_speed = 1
printer_t1.energy_usage = "50kW"
printer_t1.energy_source = { type = "electric", usage_priority = "secondary-input" }
printer_t1.collision_box = {{-0.7, -0.7}, {0.7, 0.7}}
printer_t1.selection_box = {{-1, -1}, {1, 1}}
printer_t1.graphics_set = {
  animation = {
    layers = {
      { filename = entity_graphics .. "printer-t1/mini-assembler.png", width = 227, height = 255, frame_count = 1, scale = 0.28, shift = {0, -0.1} },
    }
  }
}
printer_t1.working_sound = {
  sound = { filename = sound_path .. "personal-printer-loop.ogg", volume = 0.5 },
  idle_sound = { filename = "__base__/sound/idle1.ogg" }
}

-- Printer T2: electric, printing + printing-advanced
local printer_t2 = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
printer_t2.name = "printer-t2"
printer_t2.placeable_by = placeable_by_item("printer-t2")
printer_t2.icon = "__administratorio__/graphics/icons/steel-forge-icon.png"
printer_t2.icon_size = 64
printer_t2.minable.result = "printer-t2"
printer_t2.next_upgrade = nil
printer_t2.crafting_categories = {"printing", "printing-advanced", "printing-workorder"}
printer_t2.crafting_speed = 2
printer_t2.energy_usage = "200kW"
printer_t2.energy_source = { type = "electric", usage_priority = "secondary-input" }
printer_t2.collision_box = {{-1.2, -1.2}, {1.2, 1.2}}
printer_t2.selection_box = {{-1.5, -1.5}, {1.5, 1.5}}
printer_t2.graphics_set = {
  animation = {
    layers = {
      { filename = entity_graphics .. "printer-t2/steel-forge.png", width = 256, height = 301, frame_count = 1, scale = 0.38, shift = {0, -0.15} },
    }
  }
}
printer_t2.working_sound = {
  sound = { filename = sound_path .. "industrial-press-loop.ogg", volume = 0.58 },
  idle_sound = { filename = "__base__/sound/idle1.ogg" }
}

data:extend({mechanical_printer, printer_t1, printer_t2})
