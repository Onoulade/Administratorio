-------------------------------------------------------------------------------
-- ADMIN BUILDINGS
-- Admin Station (9x9 footprint, centered 5x5 waiting grid): biter interface (storage for complaints/resolutions)
-- Resolution Office (3x3): complaint resolution crafting
-- Office Desk (2x2): filing, permits, general admin tasks
-- Greenhouse (7x7): wood and coffee cultivation
-- Corporate Breakroom (5x5): gossip, morale, coffee consumption
-- Union HQ (7x7): union approval negotiation
-- Propaganda Distillery (3x3): admin fluid processing (lies, misinformation)
-------------------------------------------------------------------------------
local feature_flags = require("feature_flags")
local working_hours_enabled = feature_flags.working_hours_enabled()
local entity_graphics = "__administratorio__/graphics/entities/"
local scrubber_graphics = entity_graphics .. "scrubber/"
local sound_path = "__administratorio__/sound/buildings/"
local OFFICE_DESK_SPEED = working_hours_enabled and 1.0 or 0.75
local BREAKROOM_SPEED = working_hours_enabled and 1.0 or 0.75
local UNION_HQ_SPEED = working_hours_enabled and 1.0 or 0.75
local SPRITTER_ANIMATION_SPEED = 1 / 3

local function disabled_entity_description(key)
  if working_hours_enabled then
    return nil
  end
  return {"entity-description." .. key}
end

local function placeable_by_item(name)
  return {
    {item = name, count = 1},
  }
end

local function tint_sprites(t, tint)
  if type(t) ~= "table" then return end
  if t.filename and not t.draw_as_shadow then
    t.tint = tint
  end
  for _, v in pairs(t) do tint_sprites(v, tint) end
end

local function machine_animation_layer(filename, width, height, frame_count, line_length, shift, extra)
  local layer = {
    filename = filename,
    priority = "high",
    width = width,
    height = height,
    frame_count = frame_count,
    line_length = line_length,
    animation_speed = SPRITTER_ANIMATION_SPEED,
    shift = shift,
    scale = 0.5,
  }

  if extra then
    for key, value in pairs(extra) do
      layer[key] = value
    end
  end

  return layer
end

local function machine_shadow_layer(filename, width, height, frame_count, shift)
  return {
    filename = filename,
    priority = "high",
    width = width,
    height = height,
    repeat_count = frame_count,
    shift = shift,
    draw_as_shadow = true,
    scale = 0.5,
  }
end

local ADMIN_STATION_PLACEABLE_BY = {
  {item = "admin-station", count = 1},
}

-- Admin Station: storage-only biter interface (no crafting).
-- The station is intentionally walk-through for players and biters. A dedicated footprint collision
-- layer handles placement feedback against other structures without blocking units in the 5x5 center.
local admin_station_base = {
  type = "container",
  name = "admin-station",
  icon = "__administratorio__/graphics/icons/admin-desk.png",
  icon_size = 64,
  flags = {"placeable-neutral", "player-creation"},
  minable = {mining_time = 0.5, result = "admin-station"},
  max_health = 500,
  corpse = "big-remnants",
  collision_mask = {layers = {administratorio_station_footprint = true, water_tile = true}},
  collision_box = {{-4.4, -4.4}, {4.4, 4.4}},
  selection_box = {{-4.5, -4.5}, {4.5, 4.5}},
  selection_priority = 1,
  inventory_size = 20,
  circuit_wire_max_distance = 9,
  fast_replaceable_group = "admin-station",
  circuit_connector = circuit_connector_definitions.create_single(
    universal_connector_template,
    {variation = 26, main_offset = util.by_pixel(96, 32), shadow_offset = util.by_pixel(100, 36), show_shadow = true}
  ),
  picture = {
    filename = "__core__/graphics/empty.png",
    width = 1,
    height = 1,
  },
  stateless_visualisation = {
    render_layer = "ground-patch-higher2",
    animation = {
      filename = entity_graphics .. "admin-station/platform-baked.png",
      width = 1516,
      height = 1484,
      frame_count = 1,
      scale = 0.2,
      shift = {0.35, -0.2},
    },
  },
  draw_stateless_visualisations_in_ghost = true,
}

local function make_admin_station(name)
  local station = table.deepcopy(admin_station_base)
  station.name = name
  station.localised_name = {"entity-name.admin-station"}
  station.localised_description = {"entity-description.admin-station"}
  station.additional_pastable_entities = {"admin-station"}
  station.placeable_by = ADMIN_STATION_PLACEABLE_BY
  if name ~= "admin-station" then
    station.hidden_in_factoriopedia = true
    station.factoriopedia_alternative = "admin-station"
  end
  return station
end

local admin_station = make_admin_station("admin-station")

local biter_station = table.deepcopy(data.raw["container"]["steel-chest"])
biter_station.name = "biter-station"
biter_station.icon = "__administratorio__/graphics/icons/admin-desk.png"
biter_station.icon_size = 64
biter_station.icons = {
  {
    icon = "__administratorio__/graphics/icons/admin-desk.png",
    icon_size = 64,
    tint = {r = 0.72, g = 0.78, b = 0.92, a = 1},
  },
}
biter_station.flags = {"placeable-neutral", "player-creation"}
biter_station.minable = {mining_time = 0.5, result = "biter-station"}
biter_station.max_health = 450
biter_station.collision_box = {{-1.8, -1.8}, {1.8, 1.8}}
biter_station.selection_box = {{-2.0, -2.0}, {2.0, 2.0}}
biter_station.inventory_size = 10
biter_station.collision_mask = {layers = {object = true, player = true, water_tile = true}}
biter_station.circuit_wire_max_distance = 9
biter_station.circuit_connector = circuit_connector_definitions.create_single(
  universal_connector_template,
  {variation = 26, main_offset = util.by_pixel(0, 0), shadow_offset = util.by_pixel(4, 4), show_shadow = true}
)
biter_station.picture = {
  layers = {
    {
      filename = entity_graphics .. "work-station/work-station.png",
      width = 512,
      height = 466,
      scale = 0.27,
      shift = util.by_pixel(0, 0),
    },
  },
}
biter_station.stateless_visualisation = nil
biter_station.draw_stateless_visualisations_in_ghost = nil
biter_station.placeable_by = placeable_by_item("biter-station")

local biterport = table.deepcopy(data.raw["container"]["steel-chest"])
biterport.name = "biterport"
biterport.localised_name = {"entity-name.biterport"}
biterport.localised_description = {"entity-description.biterport"}
biterport.icon = "__administratorio__/graphics/icons/admin-desk.png"
biterport.icon_size = 64
biterport.icons = {
  {
    icon = "__administratorio__/graphics/icons/admin-desk.png",
    icon_size = 64,
    tint = {r = 0.55, g = 0.85, b = 0.5, a = 1},
  },
}
biterport.flags = {"placeable-neutral", "player-creation"}
biterport.minable = {mining_time = 0.5, result = "biterport"}
biterport.max_health = 450
biterport.collision_box = {{-1.8, -1.8}, {1.8, 1.8}}
biterport.selection_box = {{-2.0, -2.0}, {2.0, 2.0}}
biterport.inventory_size = 6
biterport.inventory_type = "with_filters_and_bar"
biterport.collision_mask = {layers = {object = true, player = true, water_tile = true}}
biterport.circuit_wire_max_distance = 9
biterport.circuit_connector = circuit_connector_definitions.create_single(
  universal_connector_template,
  {variation = 26, main_offset = util.by_pixel(0, 0), shadow_offset = util.by_pixel(4, 4), show_shadow = true}
)
biterport.picture = {
  layers = {
    {
      filename = entity_graphics .. "work-station/work-station.png",
      width = 512,
      height = 466,
      scale = 0.27,
      shift = util.by_pixel(0, 0),
    },
  },
}
biterport.stateless_visualisation = nil
biterport.draw_stateless_visualisations_in_ghost = nil
biterport.placeable_by = placeable_by_item("biterport")

local hidden_biterport_roboport
local roboport_source = data.raw["roboport"] and data.raw["roboport"]["roboport"]
if roboport_source then
  hidden_biterport_roboport = table.deepcopy(roboport_source)
  hidden_biterport_roboport.name = "biterport-hidden-roboport"
  hidden_biterport_roboport.localised_name = {"entity-name.biterport"}
  hidden_biterport_roboport.localised_description = {"entity-description.biterport"}
  hidden_biterport_roboport.flags = {"not-on-map", "not-deconstructable", "not-blueprintable", "not-upgradable", "placeable-off-grid"}
  hidden_biterport_roboport.minable = nil
  hidden_biterport_roboport.placeable_by = nil
  hidden_biterport_roboport.hidden = true
  hidden_biterport_roboport.hidden_in_factoriopedia = true
  hidden_biterport_roboport.selectable_in_game = false
  hidden_biterport_roboport.collision_box = {{0, 0}, {0, 0}}
  hidden_biterport_roboport.selection_box = {{0, 0}, {0, 0}}
  hidden_biterport_roboport.collision_mask = {layers = {}}
  hidden_biterport_roboport.logistics_radius = 10
  hidden_biterport_roboport.logistics_connection_distance = 20
  hidden_biterport_roboport.construction_radius = 20
  hidden_biterport_roboport.robot_slots_count = 0
  hidden_biterport_roboport.material_slots_count = 0
  hidden_biterport_roboport.energy_source = {type = "void"}
  hidden_biterport_roboport.energy_usage = "1W"
  hidden_biterport_roboport.recharge_minimum = "1kJ"
  hidden_biterport_roboport.charging_energy = "1W"
end

-- Resolution Office: 3x3 complaint resolution
local resolution_office = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-1"])
resolution_office.name = "resolution-office"
resolution_office.minable.result = "resolution-office"
resolution_office.placeable_by = placeable_by_item("resolution-office")
resolution_office.next_upgrade = nil
resolution_office.icon = scrubber_graphics .. "base/scrubber-icon.png"
resolution_office.icon_size = 64
resolution_office.icons = nil
resolution_office.crafting_categories = {"bureaucracy-resolution", "resolution-handcraft"}
resolution_office.crafting_speed = 1.0
resolution_office.energy_usage = "300kW"
resolution_office.module_slots = 4
resolution_office.allowed_effects = {"speed", "productivity", "consumption", "pollution"}
resolution_office.collision_box = {{-1.2, -1.2}, {1.2, 1.2}}
resolution_office.selection_box = {{-1.5, -1.5}, {1.5, 1.5}}
local resolution_tint = {r=0.5, g=0.3, b=0.3, a=1.0}
resolution_office.graphics_set = {
  animation = {
    layers = {
      machine_animation_layer(scrubber_graphics .. "base/scrubber-animation.png", 210, 280, 60, 10, util.by_pixel(0, -10)),
      machine_animation_layer(scrubber_graphics .. "base/scrubber-color1.png", 210, 280, 60, 10, util.by_pixel(0, -10), {
        tint = resolution_tint,
        tint_as_overlay = true,
      }),
      machine_shadow_layer(scrubber_graphics .. "base/scrubber-shadow.png", 400, 350, 60, util.by_pixel(16, 4)),
    }
  }
}
resolution_office.fluid_boxes = {
  { production_type = "input",  pipe_connections = {{ flow_direction = "input", direction = defines.direction.north, position = {0, -1} }}, volume = 100 },
  { production_type = "input",  pipe_connections = {{ flow_direction = "input", direction = defines.direction.south, position = {0, 1} }},  volume = 100 },
}
resolution_office.fluid_boxes_off_when_no_fluid_recipe = true
resolution_office.working_sound = {
  sound = { filename = sound_path .. "resolution-signoff.ogg", volume = 0.55 },
  idle_sound = { filename = "__base__/sound/idle1.ogg" }
}

-- Office Desk: 5x5 filing, permits, general admin
local office_desk = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-1"])
office_desk.name = "office-desk"
office_desk.minable.result = "office-desk"
office_desk.placeable_by = placeable_by_item("office-desk")
office_desk.next_upgrade = nil
office_desk.crafting_categories = {"bureaucracy-registration", "bureaucratic-bootstrap"}
office_desk.crafting_speed = OFFICE_DESK_SPEED
office_desk.ingredient_count = 10
office_desk.module_slots = 4
office_desk.allowed_effects = {"speed", "productivity", "consumption", "pollution"}
office_desk.localised_description = disabled_entity_description("office-desk-no-working-hours")
office_desk.collision_box = {{-2.25, -2.25}, {2.25, 2.25}}
office_desk.selection_box = {{-2.5, -2.5}, {2.5, 2.5}}
office_desk.circuit_connector = circuit_connector_definitions.create_vector(
  universal_connector_template,
  {
    {variation = 18, main_offset = util.by_pixel(96, 32), shadow_offset = util.by_pixel(107, 38), show_shadow = true},
    {variation = 18, main_offset = util.by_pixel(96, 32), shadow_offset = util.by_pixel(107, 38), show_shadow = true},
    {variation = 18, main_offset = util.by_pixel(96, 32), shadow_offset = util.by_pixel(107, 38), show_shadow = true},
    {variation = 18, main_offset = util.by_pixel(96, 32), shadow_offset = util.by_pixel(107, 38), show_shadow = true},
  }
)
office_desk.graphics_set = {
  animation = {
    layers = {
      { filename = entity_graphics .. "advanced-assembling-machine/advanced-assembling-machine.png", priority = "high", width = 320, height = 320, frame_count = 1, repeat_count = 32, animation_speed = 0.25, shift = {0, 0}, scale = 0.5 },
      { filename = entity_graphics .. "advanced-assembling-machine/advanced-assembling-machine-w1.png", priority = "high", width = 128, height = 144, shift = {-1.02, 0.29}, frame_count = 32, line_length = 8, animation_speed = 0.1, scale = 0.5 },
      { filename = entity_graphics .. "advanced-assembling-machine/advanced-assembling-machine-steam.png", priority = "high", width = 80, height = 81, shift = {-1.2, -2.1}, frame_count = 32, line_length = 8, animation_speed = 1.5, scale = 0.5 },
      { filename = entity_graphics .. "advanced-assembling-machine/advanced-assembling-machine-sh.png", priority = "high", width = 346, height = 302, shift = {0.32, 0.12}, frame_count = 1, repeat_count = 32, animation_speed = 0.1, draw_as_shadow = true, scale = 0.5 },
      { filename = entity_graphics .. "advanced-assembling-machine/advanced-assembling-machine-w2.png", priority = "high", width = 37, height = 25, frame_count = 8, line_length = 4, repeat_count = 4, animation_speed = 0.1, shift = {0.17, -1.445}, scale = 0.5 },
      { filename = entity_graphics .. "advanced-assembling-machine/advanced-assembling-machine-w3.png", priority = "high", width = 23, height = 15, frame_count = 8, line_length = 4, repeat_count = 4, animation_speed = 0.1, shift = {0.93, -2.05}, scale = 0.5 },
      { filename = entity_graphics .. "advanced-assembling-machine/advanced-assembling-machine-w3.png", priority = "high", width = 23, height = 15, frame_count = 8, line_length = 4, repeat_count = 4, animation_speed = 0.1, shift = {0.868, -0.082}, scale = 0.5 },
      { filename = entity_graphics .. "advanced-assembling-machine/advanced-assembling-machine-w3.png", priority = "high", width = 23, height = 15, frame_count = 8, line_length = 4, repeat_count = 4, animation_speed = 0.1, shift = {0.868, 0.552}, scale = 0.5 },
    }
  }
}
office_desk.fluid_boxes = {
  { production_type = "input",  pipe_connections = {{ flow_direction = "input", direction = defines.direction.north, position = {0, -2} }}, volume = 100 },
  { production_type = "output", pipe_connections = {{ flow_direction = "output", direction = defines.direction.south, position = {0, 2} }},  volume = 100 },
}
office_desk.fluid_boxes_off_when_no_fluid_recipe = true
office_desk.working_sound = {
  sound = { filename = sound_path .. "office-paperwork.ogg", volume = 0.48 },
  idle_sound = { filename = "__base__/sound/idle1.ogg" }
}

-- Greenhouse: 7x7 wood and coffee
local greenhouse = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-1"])
greenhouse.name = "greenhouse"
greenhouse.minable.result = "greenhouse"
greenhouse.placeable_by = placeable_by_item("greenhouse")
greenhouse.next_upgrade = nil
greenhouse.crafting_categories = {"admin-greenhouse"}
greenhouse.module_slots = 2
greenhouse.allowed_effects = {"speed", "productivity", "consumption", "pollution"}
greenhouse.collision_box = {{-3.25, -3.25}, {3.25, 3.25}}
greenhouse.selection_box = {{-3.5, -3.5}, {3.5, 3.5}}
greenhouse.fluid_boxes = {
  {
    production_type = "input",
    volume = 200,
    pipe_connections = {
      { flow_direction = "input", direction = defines.direction.north, position = {0, -3} },
      { flow_direction = "input", direction = defines.direction.south, position = {0, 3} },
      { flow_direction = "input", direction = defines.direction.east,  position = {3, 0} },
      { flow_direction = "input", direction = defines.direction.west,  position = {-3, 0} },
    },
  },
}
greenhouse.graphics_set = {
  animation = {
    layers = {
      { filename = entity_graphics .. "greenhouse/greenhouse.png", priority = "high", width = 512, height = 512, frame_count = 1, scale = 0.5 },
      { filename = entity_graphics .. "greenhouse/greenhouse-sh.png", priority = "high", width = 512, height = 512, shift = {0.16, 0}, frame_count = 1, draw_as_shadow = true, scale = 0.5 },
    }
  },
  working_visualisations = {
    { animation = { filename = entity_graphics .. "greenhouse/greenhouse-working.png", width = 512, height = 512, frame_count = 10, line_length = 5, scale = 0.5, animation_speed = 0.35 } },
    { animation = { filename = entity_graphics .. "greenhouse/greenhouse-light.png", width = 512, height = 512, frame_count = 1, repeat_count = 10, scale = 0.5, animation_speed = 0.35, draw_as_light = true } },
  }
}
greenhouse.energy_source = {
  type = "electric",
  usage_priority = "secondary-input",
  emissions_per_minute = { pollution = -2 },
}
greenhouse.working_sound = {
  sound = { filename = "__administratorio__/sound/buildings/greenhouse.ogg", volume = 0.75 },
  idle_sound = { filename = "__base__/sound/idle1.ogg" }
}

-- Corporate Breakroom: 5x5 gossip
local breakroom = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-1"])
breakroom.name = "corporate-breakroom"
breakroom.minable.result = "corporate-breakroom"
breakroom.placeable_by = placeable_by_item("corporate-breakroom")
breakroom.next_upgrade = nil
breakroom.crafting_categories = {"watercooler-gossip"}
breakroom.crafting_speed = BREAKROOM_SPEED
breakroom.module_slots = 3
breakroom.allowed_effects = {"speed", "productivity", "consumption", "pollution"}
breakroom.localised_description = disabled_entity_description("corporate-breakroom-no-working-hours")
breakroom.collision_box = {{-2.25, -2.25}, {2.25, 2.25}}
breakroom.selection_box = {{-2.5, -2.5}, {2.5, 2.5}}
breakroom.icon = "__administratorio__/graphics/icons/warehouse-icon.png"
breakroom.icon_size = 64
breakroom.graphics_set = {
  animation = {
    layers = {
      { filename = entity_graphics .. "corporate-breakroom/warehouse-1.png", priority = "high", width = 319, height = 328, frame_count = 1, scale = 0.5, shift = {0, -0.1} },
    }
  }
}
breakroom.fluid_boxes = {
  { production_type = "input",  pipe_connections = {{ flow_direction = "input", direction = defines.direction.north, position = {0, -2} }}, volume = 100 },
  { production_type = "output", pipe_connections = {{ flow_direction = "output", direction = defines.direction.south, position = {0, 2} }},  volume = 100 },
}
breakroom.fluid_boxes_off_when_no_fluid_recipe = true
breakroom.working_sound = {
  sound = {
    allow_random_repeat = true,
    variations = {
      { filename = sound_path .. "breakroom-gossip.ogg", volume = 0.42 },
      { filename = sound_path .. "coffee-machine.ogg", volume = 0.34 },
    },
  },
  idle_sound = { filename = "__base__/sound/idle1.ogg" }
}

-- Union Headquarters: 7x7
local union_hq = table.deepcopy(data.raw["assembling-machine"]["centrifuge"])
union_hq.name = "union-headquarters"
union_hq.minable.result = "union-headquarters"
union_hq.placeable_by = placeable_by_item("union-headquarters")
union_hq.next_upgrade = nil
union_hq.fast_replaceable_group = "late-admin-campus"
union_hq.crafting_categories = {"union-negotiation", "bureaucracy-policy"}
union_hq.crafting_speed = UNION_HQ_SPEED
union_hq.ingredient_count = 10
union_hq.module_slots = 6
union_hq.allowed_effects = {"speed", "productivity", "consumption", "pollution"}
union_hq.localised_description = disabled_entity_description("union-headquarters-no-working-hours")
union_hq.collision_box = {{-3.25, -3.25}, {3.25, 3.25}}
union_hq.selection_box = {{-3.5, -3.5}, {3.5, 3.5}}
union_hq.energy_usage = "1MW"
union_hq.icon = "__administratorio__/graphics/icons/lufter-icon.png"
union_hq.icon_size = 64
union_hq.graphics_set = {
  animation = {
    layers = {
      { filename = entity_graphics .. "union-hq/lufter.png", width = 473, height = 459, frame_count = 1, scale = 0.5, shift = {0.4, 0} },
    }
  }
}
union_hq.fluid_boxes = {
  { production_type = "input",  pipe_connections = {{ flow_direction = "input", direction = defines.direction.north, position = {0, -3} }}, volume = 100 },
  { production_type = "input",  pipe_connections = {{ flow_direction = "input", direction = defines.direction.south, position = {0, 3} }}, volume = 100 },
  { production_type = "output", pipe_connections = {{ flow_direction = "output", direction = defines.direction.east,  position = {3, 0} }}, volume = 100 },
}
union_hq.fluid_boxes_off_when_no_fluid_recipe = true
union_hq.working_sound = {
  sound = {
    allow_random_repeat = true,
    variations = {
      { filename = sound_path .. "union-office-ambience.ogg", volume = 0.36 },
      { filename = sound_path .. "office-ambience-a.ogg", volume = 0.34 },
      { filename = sound_path .. "office-ambience-b.ogg", volume = 0.34 },
    },
  },
  idle_sound = { filename = "__base__/sound/idle1.ogg" }
}

-- Waiting Zone Marker (floor overlay, no collision)
local waiting_zone_marker = {
  type = "simple-entity-with-owner",
  name = "waiting-zone-marker",
  icon = "__administratorio__/graphics/icons/ticket-landscape.png",
  icon_size = 64,
  flags = {"not-on-map", "not-blueprintable", "not-deconstructable", "placeable-off-grid"},
  max_health = 1,
  render_layer = "floor",
  collision_mask = {layers = {}},
  collision_box = {{0, 0}, {0, 0}},
  selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
  selectable_in_game = false,
  hidden = true,
  picture = {
    filename = "__administratorio__/graphics/entities/waiting-zone/zone-marker.png",
    width = 64, height = 64, scale = 0.5
  }
}

local admin_station_corner_blocker = {
  type = "simple-entity-with-owner",
  name = "admin-station-corner-blocker",
  icon = "__administratorio__/graphics/icons/admin-desk.png",
  icon_size = 64,
  flags = {"not-on-map", "not-blueprintable", "not-deconstructable", "placeable-off-grid"},
  max_health = 1,
  collision_box = {{-0.49, -0.49}, {0.49, 0.49}},
  selection_box = {{0, 0}, {0, 0}},
  selectable_in_game = false,
  hidden = true,
  picture = {
    filename = "__core__/graphics/empty.png",
    width = 1,
    height = 1,
  }
}

-- Hidden Constant Combinator for admin-station circuit signals
local admin_station_combinator = {
  type = "constant-combinator",
  name = "admin-station-combinator",
  icon = "__administratorio__/graphics/icons/admin-desk.png",
  icon_size = 64,
  flags = {"not-on-map", "not-blueprintable", "not-deconstructable", "placeable-off-grid"},
  collision_mask = {layers = {}},
  collision_box = {{0, 0}, {0, 0}},
  selection_box = {{0, 0}, {0, 0}},
  selectable_in_game = false,
  hidden = true,
  item_slot_count = 10,
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
    { wire = {red = util.by_pixel(104, 33), green = util.by_pixel(106, 40)}, shadow = {red = util.by_pixel(120, 46), green = util.by_pixel(114, 46)} },
    { wire = {red = util.by_pixel(104, 33), green = util.by_pixel(106, 40)}, shadow = {red = util.by_pixel(120, 46), green = util.by_pixel(114, 46)} },
    { wire = {red = util.by_pixel(104, 33), green = util.by_pixel(106, 40)}, shadow = {red = util.by_pixel(120, 46), green = util.by_pixel(114, 46)} },
    { wire = {red = util.by_pixel(104, 33), green = util.by_pixel(106, 40)}, shadow = {red = util.by_pixel(120, 46), green = util.by_pixel(114, 46)} },
  },
  circuit_wire_max_distance = 9
}

local distillery_graphics = entity_graphics .. "propaganda-distillery/"
local distillery_scale = 0.525
local distillery_shift = util.by_pixel(5, -5)

local function distillery_animation_layer(filename, extra)
  local merged = { scale = distillery_scale }
  if extra then
    for key, value in pairs(extra) do
      merged[key] = value
    end
  end
  return machine_animation_layer(distillery_graphics .. filename, 340, 340, 64, 8, distillery_shift, merged)
end

local function distillery_color_layer(filename, extra)
  local merged = { scale = distillery_scale }
  if extra then
    for key, value in pairs(extra) do
      merged[key] = value
    end
  end
  return machine_animation_layer(distillery_graphics .. filename, 270, 310, 64, 8, distillery_shift, merged)
end

local propaganda_distillery = table.deepcopy(data.raw["assembling-machine"]["oil-refinery"])
propaganda_distillery.name = "propaganda-distillery"
propaganda_distillery.minable.result = "propaganda-distillery"
propaganda_distillery.placeable_by = placeable_by_item("propaganda-distillery")
propaganda_distillery.next_upgrade = nil
propaganda_distillery.icon = distillery_graphics .. "base/fuel-refinery-icon.png"
propaganda_distillery.icon_size = 64
propaganda_distillery.icons = nil
propaganda_distillery.crafting_categories = {"propaganda-distillery"}
propaganda_distillery.crafting_speed = 1.0
propaganda_distillery.energy_usage = "250kW"
propaganda_distillery.module_slots = 4
propaganda_distillery.allowed_effects = {"speed", "productivity", "consumption", "pollution"}
propaganda_distillery.collision_box = {{-2.4, -2.4}, {2.4, 2.4}}
propaganda_distillery.selection_box = {{-2.5, -2.5}, {2.5, 2.5}}
propaganda_distillery.fluid_boxes_off_when_no_fluid_recipe = true

local inherited_distillery_pipe_picture = nil
if propaganda_distillery.fluid_boxes and propaganda_distillery.fluid_boxes[1] then
  inherited_distillery_pipe_picture = table.deepcopy(propaganda_distillery.fluid_boxes[1].pipe_picture)
end

propaganda_distillery.fluid_boxes = {
  {
    production_type = "input",
    pipe_covers = pipecoverspictures(),
    pipe_picture = table.deepcopy(inherited_distillery_pipe_picture),
    pipe_connections = {{ flow_direction = "input", direction = defines.direction.west, position = {-2, -1} }},
    volume = 1000,
  },
  {
    production_type = "input",
    pipe_covers = pipecoverspictures(),
    pipe_picture = table.deepcopy(inherited_distillery_pipe_picture),
    pipe_connections = {{ flow_direction = "input", direction = defines.direction.west, position = {-2, 1} }},
    volume = 1000,
  },
  {
    production_type = "output",
    pipe_covers = pipecoverspictures(),
    pipe_picture = table.deepcopy(inherited_distillery_pipe_picture),
    pipe_connections = {{ flow_direction = "output", direction = defines.direction.east, position = {2, -1} }},
    volume = 1000,
  },
  {
    production_type = "output",
    pipe_covers = pipecoverspictures(),
    pipe_picture = table.deepcopy(inherited_distillery_pipe_picture),
    pipe_connections = {{ flow_direction = "output", direction = defines.direction.east, position = {2, 1} }},
    volume = 1000,
  },
}

propaganda_distillery.graphics_set = {
  animation = {
    layers = {
      distillery_animation_layer("base/fuel-refinery-animation.png"),
      {
        filename = distillery_graphics .. "base/fuel-refinery-shadow.png",
        priority = "high",
        width = 600,
        height = 500,
        frame_count = 1,
        repeat_count = 64,
        shift = distillery_shift,
        draw_as_shadow = true,
        scale = distillery_scale,
      },
    },
  },
  frozen_patch = {
    layers = {
      distillery_animation_layer("base/fuel-refinery-frozen.png"),
    },
  },
  working_visualisations = {
    {
      always_draw = true,
      apply_recipe_tint = "primary",
      animation = distillery_color_layer("color/fuel-refinery-color2.png"),
    },
    {
      always_draw = true,
      fadeout = true,
      constant_speed = true,
      apply_recipe_tint = "secondary",
      animation = distillery_animation_layer("base/fuel-refinery-emission1.png", {
        blend_mode = "additive",
        draw_as_glow = true,
      }),
    },
    {
      always_draw = true,
      fadeout = true,
      constant_speed = true,
      apply_recipe_tint = "tertiary",
      animation = distillery_animation_layer("base/fuel-refinery-emission2.png", {
        blend_mode = "additive",
        draw_as_glow = true,
      }),
    },
  },
}

-- Field Office: 3x3 early-game desk that must be placed near biter nests
local field_office = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-1"])
field_office.name = "field-office"
field_office.minable.result = "field-office"
field_office.placeable_by = placeable_by_item("field-office")
field_office.next_upgrade = nil
field_office.crafting_categories = {"bureaucracy-registration", "bureaucratic-bootstrap"}
field_office.crafting_speed = 1.0
field_office.module_slots = 1
field_office.allowed_effects = {"consumption"}
field_office.allowed_module_categories = {"night-work"}
field_office.localised_description = disabled_entity_description("field-office-no-working-hours")
field_office.collision_box = {{-1.2, -1.2}, {1.2, 1.2}}
field_office.selection_box = {{-1.5, -1.5}, {1.5, 1.5}}
field_office.energy_source = {
  type = "electric",
  usage_priority = "secondary-input",
  emissions_per_minute = { pollution = 0 },
}
local field_office_tint = {r=0.75, g=0.65, b=0.45, a=1.0}
field_office.graphics_set = {
  animation = {
    layers = {
      machine_animation_layer(scrubber_graphics .. "base/scrubber-animation.png", 210, 280, 60, 10, util.by_pixel(0, -10), {
        tint = field_office_tint,
      }),
      machine_shadow_layer(scrubber_graphics .. "base/scrubber-shadow.png", 400, 350, 60, util.by_pixel(16, 4)),
    }
  }
}
field_office.fluid_boxes = {
  { production_type = "input",  pipe_connections = {{ flow_direction = "input", direction = defines.direction.north, position = {0, -1} }}, volume = 100 },
  { production_type = "output", pipe_connections = {{ flow_direction = "output", direction = defines.direction.south, position = {0, 1} }},  volume = 100 },
}
field_office.fluid_boxes_off_when_no_fluid_recipe = true
field_office.working_sound = {
  sound = { filename = sound_path .. "office-paperwork.ogg", volume = 0.38 },
  idle_sound = { filename = "__base__/sound/idle1.ogg" }
}

-- Transit Permit Chest: visible 1x1 chest auto-placed next to train stops
local transit_permit_chest = table.deepcopy(data.raw["container"]["steel-chest"])
transit_permit_chest.name = "transit-permit-chest"
transit_permit_chest.icon = "__base__/graphics/icons/steel-chest.png"
transit_permit_chest.icon_size = 64
transit_permit_chest.flags = {"placeable-neutral", "not-deconstructable", "not-blueprintable", "not-upgradable", "placeable-off-grid"}
transit_permit_chest.minable = nil
transit_permit_chest.inventory_size = 1
transit_permit_chest.inventory_type = "with_filters_and_bar"
transit_permit_chest.max_health = 200
transit_permit_chest.collision_box = {{0, 0}, {0, 0}}
transit_permit_chest.collision_mask = {layers = {}}

-- Legacy supply cache from pre-spider field agents. Kept hidden so old saves can
-- load cleanly; runtime destroys any remaining instances.
local _lc_src = data.raw["logistic-container"] and (
  data.raw["logistic-container"]["logistic-chest-requester"] or
  data.raw["logistic-container"]["passive-provider-chest"]
)
local hired_biter_supply_chest
if _lc_src then
  hired_biter_supply_chest = table.deepcopy(_lc_src)
  hired_biter_supply_chest.logistic_mode = "requester"
else
  -- Build minimal logistic-container from steel-chest visuals
  local _base = table.deepcopy(data.raw["container"]["steel-chest"])
  _base.type = "logistic-container"
  _base.logistic_mode = "requester"
  hired_biter_supply_chest = _base
end
hired_biter_supply_chest.name = "hired-biter-supply-chest"
hired_biter_supply_chest.localised_name = {"entity-name.hired-biter-supply-chest"}
hired_biter_supply_chest.icon = "__administratorio__/graphics/icons/eviction-notice.png"
hired_biter_supply_chest.icon_size = 64
hired_biter_supply_chest.flags = {"not-on-map", "not-deconstructable", "not-blueprintable", "not-upgradable", "placeable-off-grid"}
hired_biter_supply_chest.minable = nil
hired_biter_supply_chest.hidden = true
hired_biter_supply_chest.hidden_in_factoriopedia = true
hired_biter_supply_chest.selectable_in_game = false
hired_biter_supply_chest.inventory_size = 1
hired_biter_supply_chest.max_logistic_slots = 1
hired_biter_supply_chest.max_health = 9999
hired_biter_supply_chest.collision_box = {{0, 0}, {0, 0}}
hired_biter_supply_chest.collision_mask = {layers = {}}
hired_biter_supply_chest.selection_box = {{0, 0}, {0, 0}}
hired_biter_supply_chest.picture = {
  filename = "__core__/graphics/empty.png",
  width = 1,
  height = 1,
}
hired_biter_supply_chest.render_not_in_network_icon = false

local function make_worker_biter(name, source_name, localised_name, speed_multiplier)
  local unit_table = data.raw["unit"]
  if not unit_table or not unit_table[source_name] then return nil end
  local biter = table.deepcopy(unit_table[source_name])
  biter.name = name
  biter.localised_name = localised_name or {"entity-name.biter-station"}
  biter.minable = nil
  biter.placeable_by = nil
  biter.hidden_in_factoriopedia = true
  if speed_multiplier then
    if biter.movement_speed then
      biter.movement_speed = biter.movement_speed * speed_multiplier
    end
    if biter.distance_per_frame then
      biter.distance_per_frame = biter.distance_per_frame * speed_multiplier
    end
  end
  return biter
end

local biter_worker_t2 = make_worker_biter("biter-worker-t2", "small-biter")
local biter_worker_t3 = make_worker_biter("biter-worker-t3", "small-biter")
local biterport_worker = make_worker_biter("biterport-worker", "small-biter", {"entity-name.biterport-worker"}, 1.0)
local biterport_worker_fast = make_worker_biter("biterport-worker-fast", "small-biter", {"entity-name.biterport-worker-fast"}, 1.35)
local biterport_worker_express = make_worker_biter("biterport-worker-express", "small-biter", {"entity-name.biterport-worker-express"}, 1.7)

local function make_hired_biter_unit()
  local biter_table = data.raw["unit"]
  if not biter_table or not biter_table["behemoth-biter"] then return nil end
  local unit = table.deepcopy(biter_table["behemoth-biter"])
  unit.name = "hired-biter-unit"
  unit.localised_name = {"entity-name.hired-biter-unit"}
  unit.icon = "__base__/graphics/icons/behemoth-biter.png"
  unit.icon_size = 64
  unit.minable = {mining_time = 1, result = "hired-biter-capsule"}
  unit.placeable_by = placeable_by_item("hired-biter-capsule")
  unit.flags = {"placeable-player", "player-creation", "not-flammable"}
  unit.hidden_in_factoriopedia = true
  unit.max_health = 2000
  unit.collision_box = unit.collision_box or {{-0.6, -0.6}, {0.6, 0.6}}
  unit.selection_box = unit.selection_box or {{-0.8, -1.0}, {0.8, 0.6}}
  unit.collision_mask = {layers = {object = true, player = true, water_tile = true}}
  unit.vision_distance = 0
  unit.max_pursue_distance = 0
  unit.min_pursue_time = 0
  unit.distraction_cooldown = 60 * 60 * 60
  unit.ai_settings = table.deepcopy(unit.ai_settings or {})
  unit.ai_settings.join_attacks = false
  if unit.attack_parameters then
    unit.attack_parameters.range = 0.01
    unit.attack_parameters.min_range = 0
    unit.attack_parameters.min_attack_distance = 0
    unit.attack_parameters.cooldown = 60 * 60 * 60
    unit.attack_parameters.damage_modifier = 0
    unit.attack_parameters.sound = nil
    unit.attack_parameters.cyclic_sound = nil
  end
  unit.map_color = {r = 0.4, g = 0.8, b = 0.35, a = 1}
  return unit
end

local hired_biter_unit = make_hired_biter_unit()

local entities = {
  admin_station,
  biter_station,
  biterport,
  resolution_office, office_desk, field_office, greenhouse,
  breakroom, union_hq, propaganda_distillery,
  waiting_zone_marker, admin_station_corner_blocker, admin_station_combinator,
  transit_permit_chest
}
if hidden_biterport_roboport then table.insert(entities, hidden_biterport_roboport) end
if biter_worker_t2 then table.insert(entities, biter_worker_t2) end
if biter_worker_t3 then table.insert(entities, biter_worker_t3) end
if biterport_worker then table.insert(entities, biterport_worker) end
if biterport_worker_fast then table.insert(entities, biterport_worker_fast) end
if biterport_worker_express then table.insert(entities, biterport_worker_express) end
if hired_biter_unit then table.insert(entities, hired_biter_unit) end
table.insert(entities, hired_biter_supply_chest)

data:extend(entities)
