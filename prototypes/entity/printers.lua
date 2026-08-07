-------------------------------------------------------------------------------
-- PRINTERS
-- Mechanical Printer: T0 early game (burner, slow)
-- Printer T1: electric, printing category
-- Printer T2: electric, printing + printing-advanced categories
-------------------------------------------------------------------------------
local entity_graphics = "__administratorio__/graphics/entities/"
local sound_path = "__administratorio__/sound/buildings/"
local icon_graphics = "__administratorio__/graphics/icons/"
local feature_flags = require("feature_flags")
local planets = require("prototypes.shared.space_age_planets")
local generated_animation_speeds = require("prototypes.shared.generated_animation_speeds")
local GENERATED_FRAME_COUNT = generated_animation_speeds.FRAME_COUNT
local GENERATED_LINE_LENGTH = generated_animation_speeds.LINE_LENGTH

local function placeable_by_item(name)
  return {
    {item = name, count = 1},
  }
end

local function printer_sprite(filename, width, height, scale, shift)
  return {
    filename = filename,
    priority = "high",
    width = width,
    height = height,
    frame_count = 1,
    scale = scale,
    shift = shift,
  }
end

local function printer_graphics(name, directory, base_filename, width, height, scale, shift, shadow)
  local animation_filename = base_filename:gsub("%.png$", "-animation.png")
  local base_animation = printer_sprite(directory .. animation_filename, width, height, scale, shift)
  base_animation.frame_count = GENERATED_FRAME_COUNT
  base_animation.line_length = GENERATED_LINE_LENGTH
  base_animation.animation_speed = generated_animation_speeds.speed(name)
  local animation = base_animation
  if shadow then
    local shadow_animation = printer_sprite(
      directory .. shadow.filename,
      shadow.width,
      shadow.height,
      shadow.scale or scale,
      shadow.shift
    )
    shadow_animation.draw_as_shadow = true
    shadow_animation.repeat_count = GENERATED_FRAME_COUNT
    animation = {layers = {base_animation, shadow_animation}}
  end

  local light_animation = printer_sprite(directory .. "light.png", width, height, scale, shift)
  light_animation.blend_mode = "additive"
  light_animation.draw_as_glow = true

  return {
    animation = animation,
    working_visualisations = {
      {
        always_draw = true,
        apply_recipe_tint = "primary",
        animation = printer_sprite(directory .. "color.png", width, height, scale, shift),
      },
      {
        fadeout = true,
        animation = light_animation,
      },
    },
  }
end

-- Mechanical Printer (T0 - early game)
local mechanical_printer = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-1"])
mechanical_printer.name = "mechanical-printer"
mechanical_printer.placeable_by = placeable_by_item("mechanical-printer")
mechanical_printer.next_upgrade = "printer-t1"
mechanical_printer.icon = icon_graphics .. "mechanical-printer-v2.png"
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
mechanical_printer.graphics_set = printer_graphics(
  "mechanical-printer",
  entity_graphics .. "mechanical-printer/",
  "machanical-printer.png",
  116,
  128,
  0.46,
  -- Source art was cropped 18px off its left edge; Factorio centers a sprite
  -- on its own width, so the shift is nudged right by half that crop (9px)
  -- times scale (0.46) to keep the building in the same on-screen spot/size.
  util.by_pixel(-3 + 9 * 0.46, 0),
  {
    filename = "shadow.png",
    width = 202,
    height = 100,
    scale = 0.46,
    shift = util.by_pixel(18.62, 10.58),
  }
)
mechanical_printer.working_sound = {
  sound = { filename = sound_path .. "industrial-printer-loop.ogg", volume = 0.55 },
  idle_sound = { filename = "__base__/sound/idle1.ogg" }
}

-- Printer T1: electric, printing
local printer_t1 = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
printer_t1.name = "printer-t1"
printer_t1.placeable_by = placeable_by_item("printer-t1")
printer_t1.icon = icon_graphics .. "printer-t1-v2.png"
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
printer_t1.graphics_set = printer_graphics(
  "printer-t1",
  entity_graphics .. "printer-t1/",
  "printer-t1.png",
  128,
  152,
  0.46,
  {0, 0},
  {
    filename = "shadow.png",
    width = 194,
    height = 110,
    scale = 0.46,
    shift = util.by_pixel(14.72, 9.66),
  }
)
printer_t1.working_sound = {
  sound = { filename = sound_path .. "personal-printer-loop.ogg", volume = 0.5 },
  idle_sound = { filename = "__base__/sound/idle1.ogg" }
}

-- Printer T2: electric, printing + printing-advanced
local printer_t2 = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
printer_t2.name = "printer-t2"
printer_t2.placeable_by = placeable_by_item("printer-t2")
printer_t2.icon = icon_graphics .. "printer-t2-v2.png"
printer_t2.icon_size = 64
printer_t2.icons = nil
printer_t2.minable.result = "printer-t2"
printer_t2.next_upgrade = nil
printer_t2.crafting_categories = {"printing", "printing-advanced", "printing-workorder"}
if feature_flags.space_age_enabled() then
  printer_t2.crafting_categories[#printer_t2.crafting_categories + 1] = "orbital-printing"
end
printer_t2.crafting_speed = 2
printer_t2.energy_usage = "200kW"
printer_t2.energy_source = { type = "electric", usage_priority = "secondary-input" }
printer_t2.fluid_boxes = nil
printer_t2.collision_box = {{-1.2, -1.2}, {1.2, 1.2}}
printer_t2.selection_box = {{-1.5, -1.5}, {1.5, 1.5}}
printer_t2.graphics_set = printer_graphics(
  "printer-t2",
  entity_graphics .. "printer-t2/",
  "printer-t2.png",
  160,
  172,
  0.57,
  util.by_pixel(0, -2),
  {
    filename = "shadow.png",
    width = 248,
    height = 132,
    scale = 0.57,
    shift = util.by_pixel(22.8, 16.81),
  }
)
printer_t2.working_sound = {
  sound = { filename = sound_path .. "industrial-press-loop.ogg", volume = 0.58 },
  idle_sound = { filename = "__base__/sound/idle1.ogg" }
}

if feature_flags.space_age_enabled() then
  planets.require_non_vacuum_surface(mechanical_printer)
  planets.require_non_vacuum_surface(printer_t1)
end

data:extend({mechanical_printer, printer_t1, printer_t2})
