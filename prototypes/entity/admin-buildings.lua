-------------------------------------------------------------------------------
-- ADMIN BUILDINGS
-- Admin Station (9x9 footprint, centered 5x5 waiting grid): biter interface (storage for complaints/resolutions)
-- Resolution Office (3x3): complaint resolution crafting
-- Office Desk (2x2): filing, permits, general admin tasks
-- Greenhouse (7x7): wood and coffee cultivation
-- Corporate Breakroom (5x5): gossip, morale, coffee consumption
-- Endless Meeting (7x7): high-level policy drafting (very slow)
-- Union HQ (7x7): union approval negotiation
-- Propaganda Distillery (3x3): admin fluid processing (lies, misinformation)
-------------------------------------------------------------------------------
local feature_flags = require("feature_flags")
local working_hours_enabled = feature_flags.working_hours_enabled()
local entity_graphics = "__administratorio__/graphics/entities/"
local sound_path = "__administratorio__/sound/buildings/"
local OFFICE_DESK_SPEED = working_hours_enabled and 0.75 or 0.5
local BREAKROOM_SPEED = working_hours_enabled and 0.75 or 0.5
local MEETING_SPEED = working_hours_enabled and 0.5 or 0.25
local UNION_HQ_SPEED = working_hours_enabled and 1.5 or 1.0

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

local ADMIN_STATION_PLACEABLE_BY = {
  {item = "admin-station", count = 1},
}

local ADMIN_STATION_NAMES = {
  "admin-station",
  "admin-station-north",
  "admin-station-east",
  "admin-station-west",
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
  station.additional_pastable_entities = ADMIN_STATION_NAMES
  station.placeable_by = ADMIN_STATION_PLACEABLE_BY
  if name ~= "admin-station" then
    station.hidden_in_factoriopedia = true
    station.factoriopedia_alternative = "admin-station"
  end
  return station
end

local admin_station = make_admin_station("admin-station")
local admin_station_north = make_admin_station("admin-station-north")
local admin_station_east = make_admin_station("admin-station-east")
local admin_station_west = make_admin_station("admin-station-west")

-- Resolution Office: 3x3 complaint resolution
local resolution_office = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-1"])
resolution_office.name = "resolution-office"
resolution_office.minable.result = "resolution-office"
resolution_office.placeable_by = placeable_by_item("resolution-office")
resolution_office.next_upgrade = nil
resolution_office.icon = nil
resolution_office.icon_size = nil
resolution_office.icons = {{icon = "__base__/graphics/icons/assembling-machine-1.png", icon_size = 64, tint = {r=0.9, g=0.3, b=0.3, a=1.0}}}
resolution_office.crafting_categories = {"bureaucracy-resolution"}
resolution_office.crafting_speed = 1.0
resolution_office.energy_usage = "300kW"
resolution_office.module_slots = 4
resolution_office.allowed_effects = {"speed", "productivity", "consumption", "pollution"}
resolution_office.collision_box = {{-1.2, -1.2}, {1.2, 1.2}}
resolution_office.selection_box = {{-1.5, -1.5}, {1.5, 1.5}}
local resolution_tint = {r=0.5, g=0.3, b=0.3, a=1.0}
tint_sprites(resolution_office.graphics_set, resolution_tint)
resolution_office.fluid_boxes = {
  { production_type = "input",  pipe_connections = {{ direction = defines.direction.north, position = {0, -1} }}, volume = 100 },
  { production_type = "input",  pipe_connections = {{ direction = defines.direction.south, position = {0, 1} }},  volume = 100 },
}
resolution_office.fluid_boxes_off_when_no_fluid_recipe = true
resolution_office.working_sound = {
  sound = { filename = sound_path .. "stamp.ogg", volume = 0.6 },
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
  { production_type = "input",  pipe_connections = {{ direction = defines.direction.north, position = {0, -2} }}, volume = 100 },
  { production_type = "output", pipe_connections = {{ direction = defines.direction.south, position = {0, 2} }},  volume = 100 },
}
office_desk.fluid_boxes_off_when_no_fluid_recipe = true
office_desk.working_sound = {
  sound = { filename = sound_path .. "office-loop.ogg", volume = 0.5 },
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
      { flow_direction = "input-output", direction = defines.direction.north, position = {0, -3} },
      { flow_direction = "input-output", direction = defines.direction.south, position = {0, 3} },
      { flow_direction = "input-output", direction = defines.direction.east,  position = {3, 0} },
      { flow_direction = "input-output", direction = defines.direction.west,  position = {-3, 0} },
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
breakroom.collision_box = {{-3.25, -3.25}, {3.25, 3.25}}
breakroom.selection_box = {{-3.5, -3.5}, {3.5, 3.5}}
breakroom.icon = "__administratorio__/graphics/icons/warehouse-icon.png"
breakroom.icon_size = 64
breakroom.graphics_set = {
  animation = {
    layers = {
      { filename = entity_graphics .. "corporate-breakroom/warehouse-1.png", priority = "high", width = 319, height = 328, frame_count = 1, scale = 0.7, shift = {0, -0.1} },
    }
  }
}
breakroom.fluid_boxes = {
  { production_type = "input",  pipe_connections = {{ direction = defines.direction.north, position = {0, -3} }}, volume = 100 },
  { production_type = "output", pipe_connections = {{ direction = defines.direction.south, position = {0, 3} }},  volume = 100 },
}
breakroom.fluid_boxes_off_when_no_fluid_recipe = true
breakroom.working_sound = {
  sound = { filename = sound_path .. "coffee-machine.ogg", volume = 0.5 },
  idle_sound = { filename = "__base__/sound/idle1.ogg" }
}

-- Meeting Room: 7x7 slow policy drafting
local meeting = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
meeting.name = "meeting-room"
meeting.minable.result = "meeting-room"
meeting.placeable_by = placeable_by_item("meeting-room")
meeting.next_upgrade = nil
meeting.icon = "__administratorio__/graphics/icons/meeting-room-icon.png"
meeting.icon_size = 64
meeting.crafting_categories = {"bureaucracy-policy"}
meeting.crafting_speed = MEETING_SPEED
meeting.module_slots = 6
meeting.allowed_effects = {"speed", "productivity", "consumption", "pollution"}
meeting.localised_description = disabled_entity_description("meeting-room-no-working-hours")
meeting.collision_box = {{-3.25, -3.25}, {3.25, 3.25}}
meeting.selection_box = {{-3.5, -3.5}, {3.5, 3.5}}
meeting.energy_usage = "50kW"
meeting.graphics_set = {
  animation = {
    layers = {
      { filename = entity_graphics .. "endless-meeting/architectural-office.png", width = 520, height = 500, frame_count = 1, scale = 0.45, shift = {0, -0.2} },
      { filename = entity_graphics .. "endless-meeting/singularity-lab-shadow.png", width = 548, height = 482, frame_count = 1, scale = 0.45, shift = {0.3, 0.1}, draw_as_shadow = true }
    }
  }
}
meeting.fluid_boxes = {
  { production_type = "input", pipe_connections = {{ direction = defines.direction.north, position = {0, -3} }}, volume = 100 },
  { production_type = "input", pipe_connections = {{ direction = defines.direction.south, position = {0, 3} }}, volume = 100 },
}
meeting.fluid_boxes_off_when_no_fluid_recipe = true
meeting.working_sound = {
  sound = { filename = sound_path .. "people-talking.ogg", volume = 0.4 },
  idle_sound = { filename = "__base__/sound/idle1.ogg" }
}

-- Union Headquarters: 7x7
local union_hq = table.deepcopy(data.raw["assembling-machine"]["centrifuge"])
union_hq.name = "union-headquarters"
union_hq.minable.result = "union-headquarters"
union_hq.placeable_by = placeable_by_item("union-headquarters")
union_hq.next_upgrade = nil
union_hq.crafting_categories = {"union-negotiation"}
union_hq.crafting_speed = UNION_HQ_SPEED
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
  { production_type = "input",  pipe_connections = {{ direction = defines.direction.north, position = {0, -3} }}, volume = 100 },
  { production_type = "output", pipe_connections = {{ direction = defines.direction.south, position = {0, 3} }}, volume = 100 },
}
union_hq.fluid_boxes_off_when_no_fluid_recipe = true
union_hq.working_sound = {
  sound = { filename = sound_path .. "office-ambience-loop.ogg", volume = 0.4 },
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
  item_slot_count = 6,
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

-- 5x5 admin fluid refinery (lies, misinformation, slush fund, etc.)
local distillery_tint = {r=0.5, g=0.2, b=0.5, a=1.0}

local propaganda_distillery = table.deepcopy(data.raw["assembling-machine"]["oil-refinery"])
propaganda_distillery.name = "propaganda-distillery"
propaganda_distillery.minable.result = "propaganda-distillery"
propaganda_distillery.placeable_by = placeable_by_item("propaganda-distillery")
propaganda_distillery.next_upgrade = nil
propaganda_distillery.icon = nil
propaganda_distillery.icon_size = nil
propaganda_distillery.icons = {{icon = "__base__/graphics/icons/oil-refinery.png", icon_size = 64, tint = distillery_tint}}
propaganda_distillery.crafting_categories = {"propaganda-distillery"}
propaganda_distillery.crafting_speed = 1.0
propaganda_distillery.energy_usage = "250kW"
propaganda_distillery.module_slots = 4
propaganda_distillery.allowed_effects = {"speed", "productivity", "consumption", "pollution"}
propaganda_distillery.fluid_boxes_off_when_no_fluid_recipe = true
tint_sprites(propaganda_distillery.graphics_set, distillery_tint)

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

data:extend({
  admin_station, admin_station_north, admin_station_east, admin_station_west,
  resolution_office, office_desk, greenhouse,
  breakroom, meeting, union_hq, propaganda_distillery,
  waiting_zone_marker, admin_station_corner_blocker, admin_station_combinator,
  transit_permit_chest
})
