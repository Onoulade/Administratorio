local planets = require("prototypes.shared.space_age_planets")
local entity_graphics = "__administratorio__/graphics/entities/"
local sound_path = "__administratorio__/sound/buildings/"

local function placeable_by_item(name)
  return {
    {item = name, count = 1},
  }
end

local function require_non_vacuum(entity)
  return planets.require_non_vacuum_surface(entity)
end

local function fax_picture(filename, width, height, scale, shift)
  return {
    filename = filename,
    width = width,
    height = height,
    scale = scale,
    shift = shift,
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
chromatic_printer.crafting_categories = {"printing", "printing-advanced", "printing-workorder", "printing-chromatic", "printing-multicolor"}
chromatic_printer.crafting_speed = 3
chromatic_printer.energy_usage = "350kW"
chromatic_printer.energy_source = {type = "electric", usage_priority = "secondary-input"}
chromatic_printer.surface_conditions = {
  {
    property = "pressure",
    min = planets.BASIC_PLANET_PROPERTIES.aquilo.pressure + 1,
  },
}
chromatic_printer.collision_box = {{-1.2, -1.2}, {1.2, 1.2}}
chromatic_printer.selection_box = {{-1.5, -1.5}, {1.5, 1.5}}
chromatic_printer.fluid_boxes_off_when_no_fluid_recipe = true
chromatic_printer.fluid_boxes = {
  {
    production_type = "input",
    pipe_covers = pipecoverspictures(),
    pipe_connections = {{flow_direction = "input", direction = defines.direction.north, position = {0, -1}}},
    volume = 1000,
  },
  {
    production_type = "input",
    pipe_covers = pipecoverspictures(),
    pipe_connections = {{flow_direction = "input", direction = defines.direction.east, position = {1, 0}}},
    volume = 1000,
  },
  {
    production_type = "input",
    pipe_covers = pipecoverspictures(),
    pipe_connections = {{flow_direction = "input", direction = defines.direction.south, position = {0, 1}}},
    volume = 1000,
  },
  {
    production_type = "input",
    pipe_covers = pipecoverspictures(),
    pipe_connections = {{flow_direction = "input", direction = defines.direction.west, position = {-1, 0}}},
    volume = 1000,
  },
}
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

local notary_office = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
notary_office.name = "notary-office"
notary_office.icon = "__administratorio__/graphics/icons/management-approval-written.png"
notary_office.icon_size = 64
notary_office.minable = {mining_time = 0.2, result = "notary-office"}
notary_office.placeable_by = placeable_by_item("notary-office")
notary_office.next_upgrade = nil
notary_office.crafting_categories = {"bureaucracy-certification"}
notary_office.crafting_speed = 2
notary_office.energy_usage = "450kW"
notary_office.energy_source = {type = "electric", usage_priority = "secondary-input"}
notary_office.ingredient_count = 8
notary_office.module_slots = 4
notary_office.allowed_effects = {"speed", "productivity", "consumption", "pollution"}
notary_office.collision_box = {{-1.2, -1.2}, {1.2, 1.2}}
notary_office.selection_box = {{-1.5, -1.5}, {1.5, 1.5}}
notary_office.fluid_boxes_off_when_no_fluid_recipe = true
notary_office.fluid_boxes = {
  {
    production_type = "input",
    pipe_covers = pipecoverspictures(),
    pipe_connections = {{flow_direction = "input", direction = defines.direction.north, position = {0, -1}}},
    volume = 1000,
  },
  {
    production_type = "input",
    pipe_covers = pipecoverspictures(),
    pipe_connections = {{flow_direction = "input", direction = defines.direction.south, position = {0, 1}}},
    volume = 1000,
  },
  {
    production_type = "output",
    pipe_covers = pipecoverspictures(),
    pipe_connections = {{flow_direction = "output", direction = defines.direction.east, position = {1, 0}}},
    volume = 1000,
  },
}
notary_office.working_sound = {
  sound = {filename = sound_path .. "office-machine-loop-v2.ogg", volume = 0.45},
  idle_sound = {filename = "__base__/sound/idle1.ogg"}
}

local territorial_arbitration_post = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
territorial_arbitration_post.name = "territorial-arbitration-post"
territorial_arbitration_post.icon = "__administratorio__/graphics/icons/construction-permit.png"
territorial_arbitration_post.icon_size = 64
territorial_arbitration_post.minable = {mining_time = 0.2, result = "territorial-arbitration-post"}
territorial_arbitration_post.placeable_by = placeable_by_item("territorial-arbitration-post")
territorial_arbitration_post.next_upgrade = nil
territorial_arbitration_post.fixed_recipe = "territorial-arbitration-processing"
territorial_arbitration_post.crafting_categories = {"territorial-arbitration"}
territorial_arbitration_post.crafting_speed = 1
territorial_arbitration_post.energy_usage = "300kW"
territorial_arbitration_post.energy_source = {type = "electric", usage_priority = "secondary-input"}
territorial_arbitration_post.ingredient_count = 6
territorial_arbitration_post.module_slots = 0
territorial_arbitration_post.allowed_effects = {}
territorial_arbitration_post.collision_box = {{-3.25, -3.25}, {3.25, 3.25}}
territorial_arbitration_post.selection_box = {{-3.5, -3.5}, {3.5, 3.5}}
territorial_arbitration_post.fluid_boxes_off_when_no_fluid_recipe = true
territorial_arbitration_post.fluid_boxes = {
  {
    production_type = "input",
    pipe_covers = pipecoverspictures(),
    pipe_connections = {{flow_direction = "input", direction = defines.direction.north, position = {0, -3}}},
    volume = 1000,
  },
}
territorial_arbitration_post.working_sound = {
  sound = {filename = sound_path .. "office-machine-loop-v2.ogg", volume = 0.4},
  idle_sound = {filename = "__base__/sound/idle1.ogg"}
}

local conciliation_desk = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
conciliation_desk.name = "conciliation-desk"
conciliation_desk.icon = "__administratorio__/graphics/icons/promise.png"
conciliation_desk.icon_size = 64
conciliation_desk.minable = {mining_time = 0.2, result = "conciliation-desk"}
conciliation_desk.placeable_by = placeable_by_item("conciliation-desk")
conciliation_desk.next_upgrade = nil
conciliation_desk.crafting_categories = {"bureaucracy-conciliation"}
conciliation_desk.crafting_speed = 1.75
conciliation_desk.energy_usage = "450kW"
conciliation_desk.energy_source = {type = "electric", usage_priority = "secondary-input"}
conciliation_desk.ingredient_count = 8
conciliation_desk.module_slots = 4
conciliation_desk.allowed_effects = {"speed", "productivity", "consumption", "pollution"}
conciliation_desk.collision_box = {{-1.2, -1.2}, {1.2, 1.2}}
conciliation_desk.selection_box = {{-1.5, -1.5}, {1.5, 1.5}}
conciliation_desk.fluid_boxes_off_when_no_fluid_recipe = true
conciliation_desk.fluid_boxes = {
  {
    production_type = "input",
    pipe_covers = pipecoverspictures(),
    pipe_connections = {{flow_direction = "input", direction = defines.direction.north, position = {0, -1}}},
    volume = 1000,
  },
  {
    production_type = "input",
    pipe_covers = pipecoverspictures(),
    pipe_connections = {{flow_direction = "input", direction = defines.direction.south, position = {0, 1}}},
    volume = 1000,
  },
  {
    production_type = "output",
    pipe_covers = pipecoverspictures(),
    pipe_connections = {{flow_direction = "output", direction = defines.direction.east, position = {1, 0}}},
    volume = 1000,
  },
}
conciliation_desk.working_sound = {
  sound = {filename = sound_path .. "office-machine-loop-v2.ogg", volume = 0.45},
  idle_sound = {filename = "__base__/sound/idle1.ogg"}
}

local digital_services_bureau = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
digital_services_bureau.name = "digital-services-bureau"
digital_services_bureau.icon = "__administratorio__/graphics/icons/office-building.png"
digital_services_bureau.icon_size = 64
digital_services_bureau.minable = {mining_time = 0.2, result = "digital-services-bureau"}
digital_services_bureau.placeable_by = placeable_by_item("digital-services-bureau")
digital_services_bureau.next_upgrade = nil
digital_services_bureau.crafting_categories = {"bureaucracy-registration", "bureaucratic-bootstrap"}
digital_services_bureau.crafting_speed = 3
digital_services_bureau.energy_usage = "1MW"
digital_services_bureau.energy_source = {type = "electric", usage_priority = "secondary-input"}
digital_services_bureau.ingredient_count = 10
digital_services_bureau.module_slots = 6
digital_services_bureau.allowed_effects = {"speed", "productivity", "consumption", "pollution"}
digital_services_bureau.collision_box = {{-1.2, -1.2}, {1.2, 1.2}}
digital_services_bureau.selection_box = {{-1.5, -1.5}, {1.5, 1.5}}
digital_services_bureau.fluid_boxes_off_when_no_fluid_recipe = true
digital_services_bureau.fluid_boxes = {
  {
    production_type = "input",
    pipe_covers = pipecoverspictures(),
    pipe_connections = {{flow_direction = "input", direction = defines.direction.north, position = {0, -1}}},
    volume = 1000,
  },
  {
    production_type = "output",
    pipe_covers = pipecoverspictures(),
    pipe_connections = {{flow_direction = "output", direction = defines.direction.south, position = {0, 1}}},
    volume = 1000,
  },
}
digital_services_bureau.working_sound = {
  sound = {filename = sound_path .. "office-ambience-loop.ogg", volume = 0.5},
  idle_sound = {filename = "__base__/sound/idle1.ogg"}
}

local laser_printer = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
laser_printer.name = "laser-printer"
laser_printer.icon = "__administratorio__/graphics/icons/steel-forge-icon.png"
laser_printer.icon_size = 64
laser_printer.minable = {mining_time = 0.2, result = "laser-printer"}
laser_printer.placeable_by = placeable_by_item("laser-printer")
laser_printer.next_upgrade = nil
laser_printer.crafting_categories = {"printing", "printing-advanced", "printing-workorder", "printing-multicolor"}
laser_printer.crafting_speed = 5
laser_printer.energy_usage = "600kW"
laser_printer.energy_source = {type = "electric", usage_priority = "secondary-input"}
laser_printer.ingredient_count = 10
laser_printer.module_slots = 6
laser_printer.allowed_effects = {"speed", "productivity", "consumption", "pollution"}
laser_printer.collision_box = {{-1.2, -1.2}, {1.2, 1.2}}
laser_printer.selection_box = {{-1.5, -1.5}, {1.5, 1.5}}
laser_printer.fluid_boxes_off_when_no_fluid_recipe = true
laser_printer.fluid_boxes = {}
laser_printer.graphics_set = {
  animation = {
    layers = {
      {filename = entity_graphics .. "printer-t2/steel-forge.png", width = 256, height = 301, frame_count = 1, scale = 0.38, shift = {0, -0.15}},
    }
  }
}
laser_printer.working_sound = {
  sound = {filename = sound_path .. "industrial-printer-loop.ogg", volume = 0.6},
  idle_sound = {filename = "__base__/sound/idle1.ogg"}
}

local administrative_space_station = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
administrative_space_station.name = "administrative-space-station"
administrative_space_station.icon = "__administratorio__/graphics/icons/office-building.png"
administrative_space_station.icon_size = 64
administrative_space_station.minable = {mining_time = 0.2, result = "administrative-space-station"}
administrative_space_station.placeable_by = placeable_by_item("administrative-space-station")
administrative_space_station.next_upgrade = nil
administrative_space_station.crafting_categories = {"orbital-bureaucracy"}
administrative_space_station.crafting_speed = 3.5
administrative_space_station.energy_usage = "750kW"
administrative_space_station.energy_source = {type = "electric", usage_priority = "secondary-input"}
administrative_space_station.ingredient_count = 10
administrative_space_station.module_slots = 4
administrative_space_station.allowed_effects = {"speed", "productivity", "consumption", "pollution"}
administrative_space_station.collision_box = {{-1.2, -1.2}, {1.2, 1.2}}
administrative_space_station.selection_box = {{-1.5, -1.5}, {1.5, 1.5}}
administrative_space_station.surface_conditions = {
  {
    property = "pressure",
    min = 0,
    max = 0,
  },
}
administrative_space_station.fluid_boxes_off_when_no_fluid_recipe = true
administrative_space_station.fluid_boxes = {
  {
    production_type = "input",
    pipe_covers = pipecoverspictures(),
    pipe_connections = {{flow_direction = "input", direction = defines.direction.north, position = {0, -1}}},
    volume = 1000,
  },
  {
    production_type = "output",
    pipe_covers = pipecoverspictures(),
    pipe_connections = {{flow_direction = "output", direction = defines.direction.south, position = {0, 1}}},
    volume = 1000,
  },
}
administrative_space_station.graphics_set = {
  animation = {
    layers = {
      {filename = entity_graphics .. "printer-t2/steel-forge.png", width = 256, height = 301, frame_count = 1, scale = 0.38, shift = {0, -0.15}},
    }
  }
}
administrative_space_station.working_sound = {
  sound = {filename = sound_path .. "office-ambience-loop.ogg", volume = 0.55},
  idle_sound = {filename = "__base__/sound/idle1.ogg"}
}

local fax_emitter = {
  type = "container",
  name = "fax-emitter",
  icon = "__administratorio__/graphics/icons/office-building.png",
  icon_size = 64,
  flags = {"placeable-neutral", "player-creation"},
  minable = {mining_time = 0.2, result = "fax-emitter"},
  max_health = 250,
  corpse = "medium-remnants",
  placeable_by = placeable_by_item("fax-emitter"),
  collision_box = {{-0.7, -0.7}, {0.7, 0.7}},
  selection_box = {{-1, -1}, {1, 1}},
  inventory_size = 1,
  circuit_wire_max_distance = 9,
  circuit_connector = circuit_connector_definitions.create_vector(
    universal_connector_template,
    {
      {variation = 18, main_offset = util.by_pixel(96, 32), shadow_offset = util.by_pixel(107, 38), show_shadow = true},
      {variation = 18, main_offset = util.by_pixel(96, 32), shadow_offset = util.by_pixel(107, 38), show_shadow = true},
      {variation = 18, main_offset = util.by_pixel(96, 32), shadow_offset = util.by_pixel(107, 38), show_shadow = true},
      {variation = 18, main_offset = util.by_pixel(96, 32), shadow_offset = util.by_pixel(107, 38), show_shadow = true},
    }
  ),
  picture = fax_picture(entity_graphics .. "printer-t1/mini-assembler.png", 227, 255, 0.28, {0, -0.1}),
}

local interplanetary_fax_exchange = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
interplanetary_fax_exchange.name = "interplanetary-fax-exchange"
interplanetary_fax_exchange.icon = "__administratorio__/graphics/icons/office-building.png"
interplanetary_fax_exchange.icon_size = 64
interplanetary_fax_exchange.flags = {"placeable-neutral", "player-creation"}
interplanetary_fax_exchange.minable = {mining_time = 0.2, result = "interplanetary-fax-exchange"}
interplanetary_fax_exchange.max_health = 450
interplanetary_fax_exchange.corpse = "big-remnants"
interplanetary_fax_exchange.placeable_by = placeable_by_item("interplanetary-fax-exchange")
interplanetary_fax_exchange.next_upgrade = nil
interplanetary_fax_exchange.crafting_categories = {"fax-reconstruction"}
interplanetary_fax_exchange.crafting_speed = 1
interplanetary_fax_exchange.energy_usage = "450kW"
interplanetary_fax_exchange.energy_source = {type = "electric", usage_priority = "secondary-input"}
interplanetary_fax_exchange.ingredient_count = 5
interplanetary_fax_exchange.module_slots = 0
interplanetary_fax_exchange.allowed_effects = {}
interplanetary_fax_exchange.collision_box = {{-1.2, -1.2}, {1.2, 1.2}}
interplanetary_fax_exchange.selection_box = {{-1.5, -1.5}, {1.5, 1.5}}
interplanetary_fax_exchange.circuit_wire_max_distance = 9
interplanetary_fax_exchange.circuit_connector = circuit_connector_definitions.create_vector(
  universal_connector_template,
  {
    {variation = 18, main_offset = util.by_pixel(96, 32), shadow_offset = util.by_pixel(107, 38), show_shadow = true},
    {variation = 18, main_offset = util.by_pixel(96, 32), shadow_offset = util.by_pixel(107, 38), show_shadow = true},
    {variation = 18, main_offset = util.by_pixel(96, 32), shadow_offset = util.by_pixel(107, 38), show_shadow = true},
    {variation = 18, main_offset = util.by_pixel(96, 32), shadow_offset = util.by_pixel(107, 38), show_shadow = true},
  }
)
interplanetary_fax_exchange.fluid_boxes_off_when_no_fluid_recipe = true
interplanetary_fax_exchange.fluid_boxes = {}
interplanetary_fax_exchange.graphics_set = {
  animation = {
    layers = {
      {filename = entity_graphics .. "printer-t2/steel-forge.png", width = 256, height = 301, frame_count = 1, scale = 0.38, shift = {0, -0.15}},
    }
  }
}
interplanetary_fax_exchange.working_sound = {
  sound = {filename = sound_path .. "industrial-printer-loop.ogg", volume = 0.55},
  idle_sound = {filename = "__base__/sound/idle1.ogg"}
}

local fax_network_combinator = {
  type = "constant-combinator",
  name = "fax-network-combinator",
  icon = "__administratorio__/graphics/icons/office-building.png",
  icon_size = 64,
  flags = {"not-on-map", "not-blueprintable", "not-deconstructable", "placeable-off-grid"},
  collision_mask = {layers = {}},
  collision_box = {{0, 0}, {0, 0}},
  selection_box = {{0, 0}, {0, 0}},
  selectable_in_game = false,
  hidden = true,
  item_slot_count = 12,
  sprites = {
    north = { filename = "__core__/graphics/empty.png", width = 1, height = 1 },
    east  = { filename = "__core__/graphics/empty.png", width = 1, height = 1 },
    south = { filename = "__core__/graphics/empty.png", width = 1, height = 1 },
    west  = { filename = "__core__/graphics/empty.png", width = 1, height = 1 },
  },
  activity_led_sprites = {
    north = { filename = "__core__/graphics/empty.png", width = 1, height = 1 },
    east  = { filename = "__core__/graphics/empty.png", width = 1, height = 1 },
    south = { filename = "__core__/graphics/empty.png", width = 1, height = 1 },
    west  = { filename = "__core__/graphics/empty.png", width = 1, height = 1 },
  },
  activity_led_light_offsets = {{0, 0}, {0, 0}, {0, 0}, {0, 0}},
  circuit_wire_connection_points = {
    { wire = {red = util.by_pixel(0, 0), green = util.by_pixel(0, 0)}, shadow = {red = util.by_pixel(0, 0), green = util.by_pixel(0, 0)} },
    { wire = {red = util.by_pixel(0, 0), green = util.by_pixel(0, 0)}, shadow = {red = util.by_pixel(0, 0), green = util.by_pixel(0, 0)} },
    { wire = {red = util.by_pixel(0, 0), green = util.by_pixel(0, 0)}, shadow = {red = util.by_pixel(0, 0), green = util.by_pixel(0, 0)} },
    { wire = {red = util.by_pixel(0, 0), green = util.by_pixel(0, 0)}, shadow = {red = util.by_pixel(0, 0), green = util.by_pixel(0, 0)} },
  },
  circuit_wire_max_distance = 9
}

local trajectory_compliance_array = table.deepcopy(data.raw["ammo-turret"]["gun-turret"])
trajectory_compliance_array.name = "trajectory-compliance-array"
trajectory_compliance_array.icon = "__base__/graphics/icons/radar.png"
trajectory_compliance_array.icon_size = 64
trajectory_compliance_array.minable = {mining_time = 0.2, result = "trajectory-compliance-array"}
trajectory_compliance_array.placeable_by = placeable_by_item("trajectory-compliance-array")
trajectory_compliance_array.next_upgrade = nil
trajectory_compliance_array.fast_replaceable_group = nil
trajectory_compliance_array.attack_parameters.ammo_category = "trajectory-compliance"
trajectory_compliance_array.attack_parameters.cooldown = 60
trajectory_compliance_array.attack_parameters.range = 30
trajectory_compliance_array.surface_conditions = {
  {
    property = "pressure",
    min = 0,
    max = 0,
  },
}

local public_train_stop = table.deepcopy(data.raw["train-stop"]["train-stop"])
public_train_stop.name = "public-train-stop"
public_train_stop.minable = {mining_time = 0.2, result = "public-train-stop"}
public_train_stop.placeable_by = placeable_by_item("public-train-stop")

for _, entity in ipairs({
  formation_center,
  chromatic_printer,
  laser_printer,
  notary_office,
  territorial_arbitration_post,
  conciliation_desk,
  digital_services_bureau,
  fax_emitter,
  interplanetary_fax_exchange,
}) do
  require_non_vacuum(entity)
end

data:extend({
  formation_center,
  chromatic_printer,
  laser_printer,
  administrative_space_station,
  notary_office,
  territorial_arbitration_post,
  conciliation_desk,
  digital_services_bureau,
  fax_emitter,
  interplanetary_fax_exchange,
  fax_network_combinator,
  trajectory_compliance_array,
  public_train_stop,
})
