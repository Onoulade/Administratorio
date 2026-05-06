-------------------------------------------------------------------------------
-- PRINTERS
-- Mechanical Printer: T0 early game (burner, slow)
-- Printer T1: electric, printing category
-- Printer T2: electric, printing + printing-advanced categories
-------------------------------------------------------------------------------
local entity_graphics = "__administratorio__/graphics/entities/"
local sound_path = "__administratorio__/sound/buildings/"
local printer_color_mask = entity_graphics .. "printers/assembling-machine-base-mask.png"
local printer_highlights = entity_graphics .. "printers/assembling-machine-base-highlights.png"
local printer_t1_icon = "__administratorio__/graphics/icons/printer-t1-icon.png"
local printer_t2_icon = "__administratorio__/graphics/icons/printer-t2-icon.png"
local electric_printer_tint = {r = 0.86, g = 0.86, b = 0.80, a = 1}
local copier_printer_tint = {r = 0.18, g = 0.19, b = 0.20, a = 1}

local function placeable_by_item(name)
  return {
    {item = name, count = 1},
  }
end

local function set_animation_scale(animation, scale)
  if not animation then
    return
  end

  if animation.layers then
    for _, layer in ipairs(animation.layers) do
      set_animation_scale(layer, scale)
    end
    return
  end

  animation.scale = scale
end

local function add_printer_color_layers(machine, tint, scale)
  local animation = machine.graphics_set and machine.graphics_set.animation
  if not animation then
    return
  end

  if not animation.layers then
    animation.layers = {table.deepcopy(animation)}
    for key in pairs(animation) do
      if key ~= "layers" then
        animation[key] = nil
      end
    end
  end

  animation.layers[#animation.layers + 1] = {
    filename = printer_color_mask,
    priority = "high",
    width = 214,
    height = 237,
    frame_count = 1,
    repeat_count = 32,
    tint = tint,
    scale = scale or 0.5,
  }

  animation.layers[#animation.layers + 1] = {
    filename = printer_highlights,
    priority = "high",
    width = 214,
    height = 237,
    frame_count = 1,
    repeat_count = 32,
    scale = scale or 0.5,
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
local printer_t1 = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
printer_t1.name = "printer-t1"
printer_t1.placeable_by = placeable_by_item("printer-t1")
printer_t1.icon = printer_t1_icon
printer_t1.icon_size = 64
printer_t1.icons = nil
printer_t1.minable.result = "printer-t1"
printer_t1.next_upgrade = nil
printer_t1.crafting_categories = {"printing", "printing-workorder"}
printer_t1.crafting_speed = 1
printer_t1.energy_usage = "50kW"
printer_t1.energy_source = { type = "electric", usage_priority = "secondary-input" }
printer_t1.fluid_boxes = nil
printer_t1.collision_box = {{-0.7, -0.7}, {0.7, 0.7}}
printer_t1.selection_box = {{-1, -1}, {1, 1}}
set_animation_scale(printer_t1.graphics_set and printer_t1.graphics_set.animation, 0.36)
add_printer_color_layers(printer_t1, electric_printer_tint, 0.36)
printer_t1.working_sound = {
  sound = { filename = sound_path .. "personal-printer-loop.ogg", volume = 0.5 },
  idle_sound = { filename = "__base__/sound/idle1.ogg" }
}

-- Printer T2: electric, printing + printing-advanced
local printer_t2 = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
printer_t2.name = "printer-t2"
printer_t2.placeable_by = placeable_by_item("printer-t2")
printer_t2.icon = printer_t2_icon
printer_t2.icon_size = 64
printer_t2.icons = nil
printer_t2.minable.result = "printer-t2"
printer_t2.next_upgrade = nil
printer_t2.crafting_categories = {"printing", "printing-advanced", "printing-workorder"}
printer_t2.crafting_speed = 2
printer_t2.energy_usage = "200kW"
printer_t2.energy_source = { type = "electric", usage_priority = "secondary-input" }
printer_t2.fluid_boxes = nil
printer_t2.collision_box = {{-1.2, -1.2}, {1.2, 1.2}}
printer_t2.selection_box = {{-1.5, -1.5}, {1.5, 1.5}}
add_printer_color_layers(printer_t2, copier_printer_tint, 0.5)
printer_t2.working_sound = {
  sound = { filename = sound_path .. "industrial-press-loop.ogg", volume = 0.58 },
  idle_sound = { filename = "__base__/sound/idle1.ogg" }
}

data:extend({mechanical_printer, printer_t1, printer_t2})
