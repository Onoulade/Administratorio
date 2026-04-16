-------------------------------------------------------------------------------
-- PNEUMATIC TUBE TRANSPORT SYSTEM
-- Items enter at tube-intake (container), are voided by script, and counted
-- in a per-network signal table.  Items reappear at tube-outtake (container)
-- when the script inserts them from the signal pool.
--
-- Visible pneumatic pipes define the network topology.  A hidden
-- pneumatic-hidden-network-pipe at each intake/outtake position links them
-- into the pipe graph for BFS-based network detection.
--
-- connection_category "pneumatic-forms" keeps the tube network isolated
-- from regular fluid pipes.
-------------------------------------------------------------------------------

local pneumatic_tint = {r=0.85, g=0.75, b=0.55, a=1} -- manila/tan

local function placeable_by_item(name)
  return {
    {item = name, count = 1},
  }
end

-- Helper: tint all sprite layers in a pipe pictures table
local function tint_pipe_pictures(pictures, tint)
  if not pictures then return end
  for key, pic in pairs(pictures) do
    if type(pic) == "table" then
      if pic.filename and not pic.draw_as_shadow then
        pic.tint = tint
      end
      if pic.sheets then
        for _, sheet in ipairs(pic.sheets) do
          if not sheet.draw_as_shadow then sheet.tint = tint end
        end
      end
      if pic.layers then
        for _, layer in ipairs(pic.layers) do
          if not layer.draw_as_shadow then layer.tint = tint end
        end
      end
      if pic.sheet and not pic.sheet.draw_as_shadow then
        pic.sheet.tint = tint
      end
    end
  end
end

-- Pneumatic Pipe (visible tube segment)
local pneumatic_pipe = table.deepcopy(data.raw["pipe"]["pipe"])
pneumatic_pipe.name = "pneumatic-pipe"
pneumatic_pipe.minable.result = "pneumatic-pipe"
pneumatic_pipe.placeable_by = placeable_by_item("pneumatic-pipe")
pneumatic_pipe.fast_replaceable_group = "pneumatic-pipe"
pneumatic_pipe.icons = {{icon = "__base__/graphics/icons/pipe.png", icon_size = 64, tint = pneumatic_tint}}
pneumatic_pipe.icon = nil
pneumatic_pipe.icon_size = nil
tint_pipe_pictures(pneumatic_pipe.pictures, pneumatic_tint)
if pneumatic_pipe.pipe_covers then
  tint_pipe_pictures(pneumatic_pipe.pipe_covers, pneumatic_tint)
end
for _, pcon in pairs(pneumatic_pipe.fluid_box.pipe_connections) do
  if not pcon.connection_type or pcon.connection_type == "normal" then
    pcon.connection_category = "pneumatic-forms"
  end
end
pneumatic_pipe.fluid_box.max_pipeline_extent = 60

-- Pneumatic Underground Pipe (visible underground tube segment)
local pneumatic_underground = table.deepcopy(data.raw["pipe-to-ground"]["pipe-to-ground"])
pneumatic_underground.name = "pneumatic-pipe-to-ground"
pneumatic_underground.minable.result = "pneumatic-pipe-to-ground"
pneumatic_underground.placeable_by = placeable_by_item("pneumatic-pipe-to-ground")
pneumatic_underground.fast_replaceable_group = "pneumatic-pipe-to-ground"
pneumatic_underground.icons = {{icon = "__base__/graphics/icons/pipe-to-ground.png", icon_size = 64, tint = pneumatic_tint}}
pneumatic_underground.icon = nil
pneumatic_underground.icon_size = nil
tint_pipe_pictures(pneumatic_underground.pictures, pneumatic_tint)
pneumatic_underground.fluid_box.pipe_connections[2].max_underground_distance = 16
for _, pcon in pairs(pneumatic_underground.fluid_box.pipe_connections) do
  if not pcon.connection_type or pcon.connection_type == "normal" then
    pcon.connection_category = "pneumatic-forms"
  elseif pcon.connection_type == "underground" then
    pcon.connection_category = "pneumatic-forms"
  end
end
pneumatic_underground.fluid_box.max_pipeline_extent = 60

-- Hidden network pipe: invisible pipe placed at intake/outtake positions
-- for topology detection via fluidbox.get_connections() BFS.
local pneumatic_hidden_network_pipe = table.deepcopy(data.raw["pipe"]["pipe"])
pneumatic_hidden_network_pipe.name = "pneumatic-hidden-network-pipe"
pneumatic_hidden_network_pipe.hidden = true
pneumatic_hidden_network_pipe.selectable_in_game = false
pneumatic_hidden_network_pipe.collision_mask = {layers = {}}
pneumatic_hidden_network_pipe.collision_box = {{-0.1, -0.1}, {0.1, 0.1}}
pneumatic_hidden_network_pipe.selection_box = {{0, 0}, {0, 0}}
pneumatic_hidden_network_pipe.flags = {"not-on-map", "not-blueprintable", "not-deconstructable", "not-flammable"}
pneumatic_hidden_network_pipe.minable = nil
pneumatic_hidden_network_pipe.pictures = nil
pneumatic_hidden_network_pipe.pipe_covers = nil
for _, pcon in pairs(pneumatic_hidden_network_pipe.fluid_box.pipe_connections) do
  if not pcon.connection_type or pcon.connection_type == "normal" then
    pcon.connection_category = "pneumatic-forms"
  end
end
pneumatic_hidden_network_pipe.fluid_box.max_pipeline_extent = 60

-- Empty sheet for hidden inserter graphics
local empty_sheet = {
  filename = "__core__/graphics/empty.png",
  priority = "very-low",
  width = 1, height = 1,
  frame_count = 1,
}

-- Tube Intake: container that receives items for the signal chain
local tube_intake = {
  type = "container",
  name = "tube-intake",
  icon = "__administratorio__/graphics/icons/pneumatic/intake.png",
  icon_size = 32,
  flags = {"placeable-neutral", "placeable-player", "player-creation"},
  minable = {mining_time = 0.2, result = "tube-intake"},
  placeable_by = placeable_by_item("tube-intake"),
  fast_replaceable_group = "pneumatic-io",
  max_health = 200,
  corpse = "small-remnants",
  collision_box = {{-0.3, -0.3}, {0.3, 0.3}},
  selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
  inventory_size = 1,
  circuit_wire_max_distance = 9,
  circuit_connector = circuit_connector_definitions.create_single(
    universal_connector_template,
    {variation = 26, main_offset = util.by_pixel(0, -8), shadow_offset = util.by_pixel(4, -4), show_shadow = true}
  ),
  picture = {
    layers = {
      {
        filename = "__administratorio__/graphics/entities/pneumatic-intake/intake-up.png",
        priority = "high",
        width = 66,
        height = 72,
      },
    },
  },
}

-- Tube Outtake: container that dispenses items from the signal chain
local tube_outtake = {
  type = "container",
  name = "tube-outtake",
  icon = "__administratorio__/graphics/icons/pneumatic/outtake.png",
  icon_size = 32,
  flags = {"placeable-neutral", "placeable-player", "player-creation"},
  minable = {mining_time = 0.2, result = "tube-outtake"},
  placeable_by = placeable_by_item("tube-outtake"),
  fast_replaceable_group = "pneumatic-io",
  max_health = 200,
  corpse = "small-remnants",
  collision_box = {{-0.3, -0.3}, {0.3, 0.3}},
  selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
  inventory_size = 1,
  inventory_type = "with_filters_and_bar",
  circuit_wire_max_distance = 9,
  circuit_connector = circuit_connector_definitions.create_single(
    universal_connector_template,
    {variation = 26, main_offset = util.by_pixel(0, -8), shadow_offset = util.by_pixel(4, -4), show_shadow = true}
  ),
  picture = {
    layers = {
      {
        filename = "__administratorio__/graphics/entities/pneumatic-outtake/outtake-up.png",
        priority = "high",
        width = 66,
        height = 72,
      },
    },
  },
}

-- Hidden inserters for intake/outtake (move items in/out)
local hidden_intake_inserter = {
  type = "inserter",
  hidden = true,
  name = "pneumatic-hidden-intake",
  energy_source = {type = "void"},
  extension_speed = 1, rotation_speed = 1,
  pickup_position = {0, 1}, insert_position = {0, -0.2},
  stack = false, stack_size_bonus = 50,
  draw_held_item = false, draw_inserter_arrow = false, chases_belt_items = false,
  platform_picture = empty_sheet,
  hand_base_picture = empty_sheet,
  hand_open_picture = empty_sheet,
  hand_closed_picture = empty_sheet,
  collision_box = {{-0.1, -0.1}, {0.1, 0.1}},
  collision_mask = {layers = {}},
  selectable_in_game = false,
  flags = {"not-on-map", "not-blueprintable", "not-deconstructable", "not-flammable"},
}

local hidden_outtake_inserter = {
  type = "inserter",
  hidden = true,
  name = "pneumatic-hidden-outtake",
  energy_source = {type = "void"},
  extension_speed = 1, rotation_speed = 1,
  -- Center drop so Factorio distributes items across both belt lanes.
  pickup_position = {0, -0.2}, insert_position = {0, 1},
  stack = false, stack_size_bonus = 50,
  draw_held_item = false, draw_inserter_arrow = false, chases_belt_items = false,
  platform_picture = empty_sheet,
  hand_base_picture = empty_sheet,
  hand_open_picture = empty_sheet,
  hand_closed_picture = empty_sheet,
  collision_box = {{-0.1, -0.1}, {0.1, 0.1}},
  collision_mask = {layers = {}},
  selectable_in_game = false,
  flags = {"not-on-map", "not-blueprintable", "not-deconstructable", "not-flammable"},
}

-- Hidden Constant Combinator for tube network circuit signals
local tube_network_combinator = {
  type = "constant-combinator",
  name = "tube-network-combinator",
  icon = "__administratorio__/graphics/icons/pneumatic/intake.png",
  icon_size = 32,
  flags = {"not-on-map", "not-blueprintable", "not-deconstructable", "placeable-off-grid"},
  collision_mask = {layers = {}},
  collision_box = {{0, 0}, {0, 0}},
  selection_box = {{0, 0}, {0, 0}},
  selectable_in_game = false,
  hidden = true,
  item_slot_count = 128,
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
    { wire = {red = {0, 0}, green = {0, 0}}, shadow = {red = {0, 0}, green = {0, 0}} },
    { wire = {red = {0, 0}, green = {0, 0}}, shadow = {red = {0, 0}, green = {0, 0}} },
    { wire = {red = {0, 0}, green = {0, 0}}, shadow = {red = {0, 0}, green = {0, 0}} },
    { wire = {red = {0, 0}, green = {0, 0}}, shadow = {red = {0, 0}, green = {0, 0}} },
  },
  circuit_wire_max_distance = 9,
}

data:extend({
  pneumatic_pipe, pneumatic_underground, pneumatic_hidden_network_pipe,
  tube_intake, tube_outtake,
  hidden_intake_inserter, hidden_outtake_inserter,
  tube_network_combinator,
})
