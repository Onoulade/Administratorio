local planets = require("prototypes.shared.space_age_planets")
local entity_graphics = "__administratorio__/graphics/entities/"
local item_icons = "__administratorio__/graphics/icons/"
local sound_path = "__administratorio__/sound/buildings/"
local space_age_graphics = entity_graphics .. "space-age/"
local space_age_icons = item_icons .. "space-age/"

local function placeable_by_item(name)
  return {
    {item = name, count = 1},
  }
end

local function require_non_vacuum(entity)
  return planets.require_non_vacuum_surface(entity)
end

local function space_age_sprite(name, width, height)
  return {
    filename = space_age_graphics .. name .. ".png",
    priority = "high",
    width = width,
    height = height,
    frame_count = 1,
    scale = 0.5,
  }
end

local function space_age_shadow(name, width, height, shift_x, shift_y)
  return {
    filename = space_age_graphics .. name .. "-shadow.png",
    priority = "high",
    width = width,
    height = height,
    frame_count = 1,
    scale = 0.5,
    shift = util.by_pixel(shift_x, shift_y),
    draw_as_shadow = true,
  }
end

local function align_footprint(entity, collision_width, collision_height, selection_width, selection_height, offset)
  local x = offset and offset[1] or 0
  local y = offset and offset[2] or 0
  entity.collision_box = {
    {-collision_width / 2 + x, -collision_height / 2 + y},
    {collision_width / 2 + x, collision_height / 2 + y},
  }
  entity.selection_box = {
    {-selection_width / 2 + x, -selection_height / 2 + y},
    {selection_width / 2 + x, selection_height / 2 + y},
  }
end

local formation_center = data.raw["assembling-machine"]["formation-center"]
local extend_formation_center = formation_center == nil
if not formation_center then
  formation_center = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
  formation_center.name = "formation-center"
  formation_center.minable = {mining_time = 0.2, result = "formation-center"}
  formation_center.placeable_by = placeable_by_item("formation-center")
  formation_center.next_upgrade = nil
  formation_center.fluid_boxes = {
    {
      production_type = "input",
      pipe_connections = {{
        flow_direction = "input",
        direction = defines.direction.north,
        position = {0, -1},
      }},
      volume = 100,
    },
    {
      production_type = "input",
      pipe_connections = {{
        flow_direction = "input",
        direction = defines.direction.south,
        position = {0, 1},
      }},
      volume = 100,
    },
  }
end

formation_center.icon = item_icons .. "formation-center.png"
formation_center.icon_size = 64
formation_center.icons = nil
formation_center.crafting_categories = formation_center.crafting_categories or {}
local has_workforce_formation = false
for _, category in ipairs(formation_center.crafting_categories) do
  if category == "workforce-formation" then
    has_workforce_formation = true
    break
  end
end
if not has_workforce_formation then
  formation_center.crafting_categories[#formation_center.crafting_categories + 1] = "workforce-formation"
end
formation_center.crafting_speed = 1.5
formation_center.energy_usage = "500kW"
formation_center.energy_source = {type = "electric", usage_priority = "secondary-input"}
formation_center.ingredient_count = 6
formation_center.result_inventory_size = 4
formation_center.module_slots = 4
formation_center.allowed_effects = {"speed", "productivity", "consumption", "pollution"}
formation_center.fluid_boxes_off_when_no_fluid_recipe = true

local chromatic_printer = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
chromatic_printer.name = "chromatic-printer"
chromatic_printer.icon = space_age_icons .. "chromatic-printer.png"
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
align_footprint(chromatic_printer, 2.4, 2.4, 3, 3)
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
      space_age_sprite("chromatic-printer", 192, 192),
      space_age_shadow("chromatic-printer", 278, 144, 19.5, 18),
    }
  }
}
chromatic_printer.working_sound = {
  sound = {filename = sound_path .. "industrial-printer-loop.ogg", volume = 0.55},
  idle_sound = {filename = "__base__/sound/idle1.ogg"}
}

local notary_office = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
notary_office.name = "notary-office"
notary_office.icon = space_age_icons .. "notary-office.png"
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
align_footprint(notary_office, 2.4, 2.4, 3, 3, {-0.5 / 32, 1 / 32})
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
notary_office.graphics_set = {
  animation = {
    layers = {
      space_age_sprite("notary-office", 192, 192),
      space_age_shadow("notary-office", 272, 148, 19.5, 18),
    }
  }
}
notary_office.working_sound = {
  sound = {filename = sound_path .. "office-machine-loop-v2.ogg", volume = 0.45},
  idle_sound = {filename = "__base__/sound/idle1.ogg"}
}

local territorial_arbitration_post = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
territorial_arbitration_post.name = "territorial-arbitration-post"
territorial_arbitration_post.icon = space_age_icons .. "territorial-arbitration-post.png"
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
align_footprint(territorial_arbitration_post, 6.5, 6.5, 7, 7, {-0.5 / 32, 23 / 32})
territorial_arbitration_post.fluid_boxes_off_when_no_fluid_recipe = true
territorial_arbitration_post.fluid_boxes = {
  {
    production_type = "input",
    pipe_covers = pipecoverspictures(),
    pipe_connections = {{flow_direction = "input", direction = defines.direction.north, position = {0, -2.5}}},
    volume = 1000,
  },
}
territorial_arbitration_post.graphics_set = {
  animation = {
    layers = {
      space_age_sprite("territorial-arbitration-post", 448, 448),
      space_age_shadow("territorial-arbitration-post", 768, 348, 77.5, 38.5),
    }
  }
}
territorial_arbitration_post.working_sound = {
  sound = {filename = sound_path .. "office-machine-loop-v2.ogg", volume = 0.4},
  idle_sound = {filename = "__base__/sound/idle1.ogg"}
}

local conciliation_desk = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
conciliation_desk.name = "conciliation-desk"
conciliation_desk.icon = space_age_icons .. "conciliation-desk.png"
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
align_footprint(conciliation_desk, 2.4, 2.4, 3, 3, {0, 2 / 32})
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
conciliation_desk.graphics_set = {
  animation = {
    layers = {
      space_age_sprite("conciliation-desk", 192, 192),
      space_age_shadow("conciliation-desk", 284, 144, 21, 19.5),
    }
  }
}
conciliation_desk.working_sound = {
  sound = {filename = sound_path .. "office-machine-loop-v2.ogg", volume = 0.45},
  idle_sound = {filename = "__base__/sound/idle1.ogg"}
}

local digital_services_bureau = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
digital_services_bureau.name = "digital-services-bureau"
digital_services_bureau.icon = space_age_icons .. "digital-services-bureau.png"
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
align_footprint(digital_services_bureau, 2.4, 2.4, 3, 3, {-0.5 / 32, 1 / 32})
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
digital_services_bureau.graphics_set = {
  animation = {
    layers = {
      space_age_sprite("digital-services-bureau", 192, 192),
      space_age_shadow("digital-services-bureau", 304, 162, 26, 5),
    }
  }
}
digital_services_bureau.working_sound = {
  sound = {filename = sound_path .. "office-ambience-loop.ogg", volume = 0.5},
  idle_sound = {filename = "__base__/sound/idle1.ogg"}
}

local laser_printer = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
laser_printer.name = "laser-printer"
laser_printer.icon = space_age_icons .. "laser-printer.png"
laser_printer.icon_size = 64
laser_printer.minable = {mining_time = 0.2, result = "laser-printer"}
laser_printer.placeable_by = placeable_by_item("laser-printer")
laser_printer.next_upgrade = nil
laser_printer.crafting_categories = {"printing", "printing-advanced", "printing-workorder", "printing-multicolor", "orbital-printing"}
laser_printer.crafting_speed = 5
laser_printer.energy_usage = "600kW"
laser_printer.energy_source = {type = "electric", usage_priority = "secondary-input"}
laser_printer.ingredient_count = 10
laser_printer.module_slots = 6
laser_printer.allowed_effects = {"speed", "productivity", "consumption", "pollution"}
align_footprint(laser_printer, 2.4, 2.4, 3, 3, {-3 / 32, 0})
laser_printer.fluid_boxes_off_when_no_fluid_recipe = true
laser_printer.fluid_boxes = {}
laser_printer.graphics_set = {
  animation = {
    layers = {
      space_age_sprite("laser-printer", 192, 192),
      space_age_shadow("laser-printer", 304, 110, 32.5, 31),
    }
  }
}
laser_printer.working_sound = {
  sound = {filename = sound_path .. "industrial-printer-loop.ogg", volume = 0.6},
  idle_sound = {filename = "__base__/sound/idle1.ogg"}
}

local administrative_space_station = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
administrative_space_station.name = "administrative-space-station"
administrative_space_station.icon = space_age_icons .. "administrative-space-station.png"
administrative_space_station.icon_size = 64
administrative_space_station.icons = nil
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
align_footprint(administrative_space_station, 2.4, 2.4, 3, 3, {-0.5 / 32, 2 / 32})
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
      space_age_sprite("administrative-space-station", 192, 192),
      space_age_shadow("administrative-space-station", 248, 154, 12.5, 15.5),
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
  icon = space_age_icons .. "fax-emitter.png",
  icon_size = 64,
  flags = {"placeable-neutral", "player-creation"},
  minable = {mining_time = 0.2, result = "fax-emitter"},
  max_health = 250,
  corpse = "medium-remnants",
  placeable_by = placeable_by_item("fax-emitter"),
  inventory_size = 1,
  circuit_wire_max_distance = 9,
  circuit_connector = circuit_connector_definitions.create_vector(
    universal_connector_template,
    {
      {variation = 18, main_offset = util.by_pixel(14, 14), shadow_offset = util.by_pixel(18, 18), show_shadow = true},
      {variation = 18, main_offset = util.by_pixel(14, 14), shadow_offset = util.by_pixel(18, 18), show_shadow = true},
      {variation = 18, main_offset = util.by_pixel(14, 14), shadow_offset = util.by_pixel(18, 18), show_shadow = true},
      {variation = 18, main_offset = util.by_pixel(14, 14), shadow_offset = util.by_pixel(18, 18), show_shadow = true},
    }
  ),
  picture = {
    layers = {
      space_age_sprite("fax-emitter", 128, 128),
      space_age_shadow("fax-emitter", 192, 110, 15.5, 13.5),
    },
  },
}
align_footprint(fax_emitter, 1.4, 1.4, 2, 2, {0, 1 / 32})

local interplanetary_fax_exchange = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
interplanetary_fax_exchange.name = "interplanetary-fax-exchange"
interplanetary_fax_exchange.icon = space_age_icons .. "interplanetary-fax-exchange.png"
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
align_footprint(interplanetary_fax_exchange, 2.4, 2.4, 3, 3, {-1 / 32, 3 / 32})
interplanetary_fax_exchange.circuit_wire_max_distance = 9
interplanetary_fax_exchange.circuit_connector = circuit_connector_definitions.create_vector(
  universal_connector_template,
  {
    {variation = 18, main_offset = util.by_pixel(26, 26), shadow_offset = util.by_pixel(30, 30), show_shadow = true},
    {variation = 18, main_offset = util.by_pixel(26, 26), shadow_offset = util.by_pixel(30, 30), show_shadow = true},
    {variation = 18, main_offset = util.by_pixel(26, 26), shadow_offset = util.by_pixel(30, 30), show_shadow = true},
    {variation = 18, main_offset = util.by_pixel(26, 26), shadow_offset = util.by_pixel(30, 30), show_shadow = true},
  }
)
interplanetary_fax_exchange.fluid_boxes_off_when_no_fluid_recipe = true
interplanetary_fax_exchange.fluid_boxes = {}
interplanetary_fax_exchange.graphics_set = {
  animation = {
    layers = {
      space_age_sprite("interplanetary-fax-exchange", 192, 192),
      space_age_shadow("interplanetary-fax-exchange", 248, 150, 13, 14.5),
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

local asteroid_size_masks = {
  small = "administratorio-asteroid-small",
  medium = "administratorio-asteroid-medium",
  big = "administratorio-asteroid-big",
  huge = "administratorio-asteroid-huge",
}

data:extend({
  {type = "trigger-target-type", name = asteroid_size_masks.small},
  {type = "trigger-target-type", name = asteroid_size_masks.medium},
  {type = "trigger-target-type", name = asteroid_size_masks.big},
  {type = "trigger-target-type", name = asteroid_size_masks.huge},
})

-- Deviation arrays have actual jurisdictional limits. Giving every asteroid
-- size its own native target mask stops junior hardware from wasting orders and
-- power on an asteroid that its committee is not authorised to redirect.
for _, size in ipairs({"small", "medium", "big", "huge"}) do
  for _, family in ipairs({"metallic", "carbonic", "oxide", "promethium"}) do
    local asteroid = data.raw.asteroid[size .. "-" .. family .. "-asteroid"]
    if asteroid then
      asteroid.trigger_target_mask = {asteroid_size_masks[size]}
    end
  end
end

local function trajectory_array_icons(tint, overlay)
  local icons = {
    {icon = "__base__/graphics/icons/radar.png", icon_size = 64, tint = tint},
  }
  if overlay then
    icons[#icons + 1] = {icon = overlay, icon_size = 64, scale = 0.38, shift = {8, 8}}
  end
  return icons
end

local function make_trajectory_compliance_array(spec)
  local array = table.deepcopy(data.raw["ammo-turret"]["gun-turret"])
  array.name = spec.name
  array.icon = nil
  array.icons = spec.icons
  array.minable = {mining_time = 0.2, result = spec.name}
  array.placeable_by = placeable_by_item(spec.name)
  array.next_upgrade = spec.next_upgrade
  array.fast_replaceable_group = "trajectory-compliance-array"
  array.attack_target_mask = spec.target_masks
  array.attack_parameters.ammo_category = "trajectory-compliance"
  array.attack_parameters.cooldown = 300
  array.attack_parameters.range = spec.range
  array.energy_source = {
    type = "electric",
    buffer_capacity = spec.energy_per_shot,
    input_flow_limit = spec.input_flow_limit,
    usage_priority = "primary-input",
  }
  array.energy_per_shot = spec.energy_per_shot
  array.prepare_with_no_ammo = false
  array.surface_conditions = {
    {
      property = "pressure",
      min = 0,
      max = 0,
    },
  }
  return array
end

local trajectory_compliance_array = make_trajectory_compliance_array({
  name = "trajectory-compliance-array",
  icons = trajectory_array_icons(),
  next_upgrade = "senior-trajectory-compliance-array",
  target_masks = {asteroid_size_masks.small, asteroid_size_masks.medium},
  range = 20,
  energy_per_shot = "1.3MJ",
  input_flow_limit = "2.6MW",
})

local senior_trajectory_compliance_array = make_trajectory_compliance_array({
  name = "senior-trajectory-compliance-array",
  icons = trajectory_array_icons(
    {r = 0.72, g = 0.88, b = 1, a = 1},
    "__base__/graphics/icons/behemoth-biter.png"
  ),
  next_upgrade = "executive-trajectory-compliance-array",
  target_masks = {asteroid_size_masks.small, asteroid_size_masks.medium, asteroid_size_masks.big},
  range = 30,
  energy_per_shot = "2.6MJ",
  input_flow_limit = "5.2MW",
})

local executive_trajectory_compliance_array = make_trajectory_compliance_array({
  name = "executive-trajectory-compliance-array",
  icons = trajectory_array_icons(
    {r = 1, g = 0.72, b = 0.34, a = 1},
    "__space-age__/graphics/icons/quantum-processor.png"
  ),
  next_upgrade = nil,
  target_masks = {
    asteroid_size_masks.small,
    asteroid_size_masks.medium,
    asteroid_size_masks.big,
    asteroid_size_masks.huge,
  },
  range = 40,
  energy_per_shot = "5.2MJ",
  input_flow_limit = "10.4MW",
})

local fallback_manager_animation = {
  filename = "__base__/graphics/icons/behemoth-biter.png",
  width = 64,
  height = 64,
  frame_count = 1,
  direction_count = 1,
}
local manager_unit = data.raw.unit and data.raw.unit["behemoth-biter"] or {
  run_animation = fallback_manager_animation,
  attack_parameters = {animation = fallback_manager_animation},
}

local function scale_layer_shift(layer, scale_factor)
  local shift = layer.shift
  if not shift then return end
  if shift.x ~= nil or shift.y ~= nil then
    shift.x = (shift.x or 0) * scale_factor
    shift.y = (shift.y or 0) * scale_factor
  else
    shift[1] = (shift[1] or 0) * scale_factor
    shift[2] = (shift[2] or 0) * scale_factor
  end
end

local function scale_animation_layers(animation, scale_factor, animation_speed)
  local result = table.deepcopy(animation)
  for _, layer in ipairs(result.layers or {result}) do
    layer.scale = (layer.scale or 1) * scale_factor
    scale_layer_shift(layer, scale_factor)
    if animation_speed then layer.animation_speed = animation_speed end
  end
  return result
end

local function make_manager_attack_animation(source_animation, scale_factor, animation_speed)
  local animation = {type = "animation", name = "orbital-manager-attack", layers = {}}
  for _, source_layer in ipairs(source_animation.layers or {source_animation}) do
    local layer = table.deepcopy(source_layer)
    if layer.filenames then
      layer.filename = layer.filenames[1]
      layer.filenames = nil
      layer.lines_per_file = nil
      layer.slice = nil
    end
    layer.direction_count = nil
    layer.scale = (layer.scale or 1) * scale_factor
    scale_layer_shift(layer, scale_factor)
    layer.animation_speed = animation_speed
    animation.layers[#animation.layers + 1] = layer
  end
  return animation
end

local function make_manager_still_sprite(source_animation, direction_index, scale_factor)
  local sprite = {layers = {}}
  for _, source_layer in ipairs(source_animation.layers or {source_animation}) do
    local layer = table.deepcopy(source_layer)
    local frame_count = layer.frame_count or 1
    local line_length = layer.line_length or frame_count
    local first_frame = direction_index * frame_count
    local first_row = math.floor(first_frame / line_length)
    local first_column = first_frame % line_length

    if layer.filenames then
      local lines_per_file = layer.lines_per_file or 1
      local file_index = math.floor(first_row / lines_per_file) + 1
      layer.filename = layer.filenames[file_index]
      layer.y = (layer.y or 0) + (first_row % lines_per_file) * layer.height
      layer.filenames = nil
      layer.lines_per_file = nil
      layer.slice = nil
    else
      layer.y = (layer.y or 0) + first_row * layer.height
    end

    layer.x = (layer.x or 0) + first_column * layer.width
    layer.direction_count = nil
    layer.frame_count = nil
    layer.line_length = nil
    layer.animation_speed = nil
    layer.scale = (layer.scale or 1) * scale_factor
    scale_layer_shift(layer, scale_factor)
    sprite.layers[#sprite.layers + 1] = layer
  end
  return sprite
end

local manager_attack_animation = make_manager_attack_animation(
  manager_unit.attack_parameters.animation,
  0.46,
  1
)
data:extend({manager_attack_animation})

-- A deployed VESM rides the asteroid until demolition, then becomes one more
-- native collectible chunk. Mining that chunk returns the miner directly to
-- collector output, so belts and inserters can route the employee normally.
-- Asteroid chunks cannot animate themselves. Use a still frame from the real
-- biter run sheet. Sixteen hidden directional variants preserve the manager's
-- final facing without polling or synchronising an invisible render object.
local returning_employee_chunks = {}
for direction_index = 0, 15 do
  local returning_employee_chunk = table.deepcopy(data.raw["asteroid-chunk"]["metallic-asteroid-chunk"])
  returning_employee_chunk.name = direction_index == 0
      and "returning-orbital-employee"
    or string.format("returning-orbital-employee-orientation-%02d", direction_index)
  returning_employee_chunk.localised_name = {"item-name.returning-orbital-employee"}
  returning_employee_chunk.localised_description = {"item-description.returning-orbital-employee"}
  returning_employee_chunk.icon = nil
  returning_employee_chunk.icons = {
    {icon = "__space-age__/graphics/icons/metallic-asteroid-chunk.png", icon_size = 64},
    {icon = "__base__/graphics/icons/behemoth-biter.png", icon_size = 64, scale = 0.48, shift = {4, -2}},
    {icon = "__base__/graphics/icons/electric-mining-drill.png", icon_size = 64, scale = 0.28, shift = {9, 7}},
  }
  returning_employee_chunk.minable = {
    mining_time = 0.2,
    result = "voluntary-exploration-space-miner",
    mining_particle = "metallic-asteroid-chunk-particle-medium",
  }
  returning_employee_chunk.graphics_set = {
    rotation_speed = 0,
    sprite = make_manager_still_sprite(manager_unit.run_animation, direction_index, 0.46),
  }
  returning_employee_chunk.dying_trigger_effect = {
    type = "create-explosion",
    entity_name = "explosion-hit",
    only_when_visible = true,
  }
  if direction_index ~= 0 then
    returning_employee_chunk.hidden_in_factoriopedia = true
    returning_employee_chunk.hide_from_signal_gui = true
  end
  returning_employee_chunks[#returning_employee_chunks + 1] = returning_employee_chunk
end
data:extend(returning_employee_chunks)

-- The projectile is, with complete institutional sincerity, a behemoth biter.
-- Its script effect attaches the worker; one-second work cycles perform damage,
-- and collection of the eventual employee chunk is the only return path.
local orbital_biter_projectile = table.deepcopy(data.raw.projectile["rocket"])
orbital_biter_projectile.name = "orbital-biter-projectile"
orbital_biter_projectile.acceleration = 0
orbital_biter_projectile.max_speed = 0.36
orbital_biter_projectile.turn_speed = 0.08
orbital_biter_projectile.turning_speed_increases_exponentially_with_projectile_speed = nil
orbital_biter_projectile.animation = scale_animation_layers(manager_unit.run_animation, 0.46, 0.18)
orbital_biter_projectile.shadow = nil
orbital_biter_projectile.smoke = nil
orbital_biter_projectile.action = {
  type = "direct",
  action_delivery = {
    type = "instant",
    target_effects = {
      {
        type = "script",
        effect_id = "administratorio-asteroid-biter-assault",
        affects_target = true,
      },
      {type = "create-explosion", entity_name = "explosion-hit"},
    },
  },
}

local orbital_employment_cannon = table.deepcopy(data.raw["ammo-turret"]["railgun-turret"])
orbital_employment_cannon.name = "orbital-employment-cannon"
orbital_employment_cannon.icon = nil
orbital_employment_cannon.icons = {
  {icon = "__space-age__/graphics/icons/railgun-turret.png", icon_size = 64},
  {icon = "__base__/graphics/icons/electric-mining-drill.png", icon_size = 64, scale = 0.38, shift = {8, 8}},
}
orbital_employment_cannon.minable = {mining_time = 0.5, result = "orbital-employment-cannon"}
orbital_employment_cannon.placeable_by = placeable_by_item("orbital-employment-cannon")
orbital_employment_cannon.next_upgrade = nil
orbital_employment_cannon.fast_replaceable_group = nil
orbital_employment_cannon.attack_target_mask = {
  asteroid_size_masks.small,
  asteroid_size_masks.medium,
  asteroid_size_masks.big,
  asteroid_size_masks.huge,
}
orbital_employment_cannon.attack_parameters.ammo_category = "orbital-biter-ballistics"
orbital_employment_cannon.attack_parameters.cooldown = 240
orbital_employment_cannon.attack_parameters.range = 56
orbital_employment_cannon.attack_parameters.min_range = 4
orbital_employment_cannon.attack_parameters.turn_range = 0.05
orbital_employment_cannon.energy_source = {
  type = "electric",
  buffer_capacity = "10MJ",
  input_flow_limit = "5MW",
  usage_priority = "primary-input",
}
orbital_employment_cannon.energy_per_shot = "5MJ"
orbital_employment_cannon.surface_conditions = {
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
  notary_office,
  territorial_arbitration_post,
  conciliation_desk,
  digital_services_bureau,
  fax_emitter,
  interplanetary_fax_exchange,
}) do
  require_non_vacuum(entity)
end

local space_age_entities = {
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
  orbital_biter_projectile,
  trajectory_compliance_array,
  senior_trajectory_compliance_array,
  executive_trajectory_compliance_array,
  orbital_employment_cannon,
  public_train_stop,
}

if extend_formation_center then
  table.insert(space_age_entities, 1, formation_center)
end

data:extend(space_age_entities)
