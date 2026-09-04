-------------------------------------------------------------------------------
-- PNEUMATIC TUBE TRANSPORT SYSTEM
-- Items enter at tube-intake (furnace-style intake), are voided by script,
-- and counted in a per-network signal table.  Items reappear at tube-outtake (container)
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
local tube_max_network_radius = 120

local function placeable_by_item(name)
  return {
    {item = name, count = 1},
  }
end

-- Helper: tint all sprite layers in a pipe pictures table
local function tint_pipe_pictures(pictures, tint, render_layer)
  if not pictures then return end
  for key, pic in pairs(pictures) do
    if type(pic) == "table" then
      if pic.filename and not pic.draw_as_shadow then
        pic.tint = tint
        if render_layer then pic.render_layer = render_layer end
      end
      if pic.sheets then
        for _, sheet in ipairs(pic.sheets) do
          if not sheet.draw_as_shadow then
            sheet.tint = tint
            if render_layer then sheet.render_layer = render_layer end
          end
        end
      end
      if pic.layers then
        for _, layer in ipairs(pic.layers) do
          if not layer.draw_as_shadow then
            layer.tint = tint
            if render_layer then layer.render_layer = render_layer end
          end
        end
      end
      if pic.sheet and not pic.sheet.draw_as_shadow then
        pic.sheet.tint = tint
        if render_layer then pic.sheet.render_layer = render_layer end
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
pneumatic_pipe.fluid_box.max_pipeline_extent = tube_max_network_radius

-- Pneumatic Underground Pipe (visible underground tube segment)
local pneumatic_underground = table.deepcopy(data.raw["pipe-to-ground"]["pipe-to-ground"])
pneumatic_underground.name = "pneumatic-pipe-to-ground"
pneumatic_underground.minable.result = "pneumatic-pipe-to-ground"
pneumatic_underground.placeable_by = placeable_by_item("pneumatic-pipe-to-ground")
pneumatic_underground.fast_replaceable_group = "pneumatic-pipe"
pneumatic_underground.icons = {{icon = "__base__/graphics/icons/pipe-to-ground.png", icon_size = 64, tint = pneumatic_tint}}
pneumatic_underground.icon = nil
pneumatic_underground.icon_size = nil
tint_pipe_pictures(pneumatic_underground.pictures, pneumatic_tint)
for _, pcon in pairs(pneumatic_underground.fluid_box.pipe_connections) do
  if not pcon.connection_type or pcon.connection_type == "normal" then
    pcon.connection_category = "pneumatic-forms"
  elseif pcon.connection_type == "underground" then
    pcon.connection_category = "pneumatic-forms"
    pcon.max_underground_distance = 16
  end
end
pneumatic_underground.fluid_box.max_pipeline_extent = tube_max_network_radius

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
pneumatic_hidden_network_pipe.pictures = table.deepcopy(pneumatic_pipe.pictures)
tint_pipe_pictures(pneumatic_hidden_network_pipe.pictures, pneumatic_tint, "higher-object-above")
if pneumatic_pipe.pipe_covers then
  pneumatic_hidden_network_pipe.pipe_covers = table.deepcopy(pneumatic_pipe.pipe_covers)
  tint_pipe_pictures(pneumatic_hidden_network_pipe.pipe_covers, pneumatic_tint, "higher-object-above")
else
  pneumatic_hidden_network_pipe.pipe_covers = nil
end
for _, pcon in pairs(pneumatic_hidden_network_pipe.fluid_box.pipe_connections) do
  if not pcon.connection_type or pcon.connection_type == "normal" then
    pcon.connection_category = "pneumatic-forms"
  end
end
pneumatic_hidden_network_pipe.fluid_box.max_pipeline_extent = tube_max_network_radius

local tube_sprite_scale = 0.43

local function tube_sprite(filename)
  return {
    layers = {
      {
        filename = filename,
        priority = "high",
        width = 110,
        height = 128,
        scale = tube_sprite_scale,
        shift = util.by_pixel(2.0, 1.0),
      },
    },
  }
end

local empty_connector_sprite = {
  filename = "__core__/graphics/empty.png",
  width = 1,
  height = 1,
}

local function hide_connector_body(connector)
  if connector.sprites then
    connector.sprites.connector_main = nil
    connector.sprites.connector_shadow = nil
    connector.sprites.led_blue = empty_connector_sprite
    connector.sprites.led_blue_off = empty_connector_sprite
    connector.sprites.led_green = empty_connector_sprite
    connector.sprites.led_red = empty_connector_sprite
  end
  return connector
end

local function universal_wire_connector(definition)
  return hide_connector_body(circuit_connector_definitions.create_single(universal_connector_template, definition))
end

local function universal_wire_connectors(definitions)
  local connectors = circuit_connector_definitions.create_vector(universal_connector_template, definitions)
  for _, connector in ipairs(connectors) do
    hide_connector_body(connector)
  end
  return connectors
end

-- Tube Intake: furnace-style receiver that lets inserters use recipe
-- ingredient validation before items reach the signal chain.
local tube_intake = {
  type = "furnace",
  name = "tube-intake",
  icon = "__administratorio__/graphics/entities/pneumatic/intake-icon.png",
  icon_size = 64,
  flags = {"placeable-neutral", "placeable-player", "player-creation"},
  minable = {mining_time = 0.2, result = "tube-intake"},
  placeable_by = placeable_by_item("tube-intake"),
  fast_replaceable_group = "pneumatic-io",
  max_health = 200,
  corpse = "small-remnants",
  collision_box = {{-0.3, -0.3}, {0.3, 0.3}},
  selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
  crafting_categories = {"pneumatic-intake"},
  crafting_speed = 0.001,
  energy_usage = "1W",
  energy_source = {type = "void"},
  source_inventory_size = 1,
  result_inventory_size = 1,
  trash_inventory_size = 0,
  module_slots = 0,
  allowed_effects = {},
  show_recipe_icon = false,
  show_recipe_icon_on_map = false,
  enable_logistic_control_behavior = false,
  circuit_wire_max_distance = 9,
  circuit_connector = universal_wire_connectors({
    {variation = 25, main_offset = util.by_pixel(10, -5), shadow_offset = util.by_pixel(0, 0), show_shadow = false},
    {variation = 25, main_offset = util.by_pixel(10, -5), shadow_offset = util.by_pixel(0, 0), show_shadow = false},
    {variation = 25, main_offset = util.by_pixel(10, -5), shadow_offset = util.by_pixel(0, 0), show_shadow = false},
    {variation = 25, main_offset = util.by_pixel(10, -5), shadow_offset = util.by_pixel(0, 0), show_shadow = false},
  }),
  graphics_set = {
    animation = tube_sprite("__administratorio__/graphics/entities/pneumatic/intake.png"),
  },
}

-- Tube Outtake: container that dispenses items from the signal chain
local tube_outtake = {
  type = "container",
  name = "tube-outtake",
  icon = "__administratorio__/graphics/entities/pneumatic/outtake-icon.png",
  icon_size = 64,
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
  circuit_connector = universal_wire_connector(
    {variation = 25, main_offset = util.by_pixel(10, -5), shadow_offset = util.by_pixel(0, 0), show_shadow = false}
  ),
  picture = tube_sprite("__administratorio__/graphics/entities/pneumatic/outtake.png"),
}

-- Hidden Constant Combinator for tube network circuit signals
local tube_network_combinator = {
  type = "constant-combinator",
  name = "tube-network-combinator",
  icon = "__administratorio__/graphics/entities/pneumatic/intake-icon.png",
  icon_size = 64,
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
    { wire = {red = {0.3, 0}, green = {0.3, 0}}, shadow = {red = {0.3, 0}, green = {0.3, 0}} },
    { wire = {red = {0.3, 0}, green = {0.3, 0}}, shadow = {red = {0.3, 0}, green = {0.3, 0}} },
    { wire = {red = {0.3, 0}, green = {0.3, 0}}, shadow = {red = {0.3, 0}, green = {0.3, 0}} },
    { wire = {red = {0.3, 0}, green = {0.3, 0}}, shadow = {red = {0.3, 0}, green = {0.3, 0}} },
  },
  circuit_wire_max_distance = 9,
}

-- Legacy wireable port kept so existing saves can clean it up after migration.
local tube_intake_network_port = table.deepcopy(tube_network_combinator)
tube_intake_network_port.name = "tube-intake-network-port"
tube_intake_network_port.hidden = true
tube_intake_network_port.selectable_in_game = true
tube_intake_network_port.selection_box = {{-0.2, -0.55}, {0.2, -0.2}}
tube_intake_network_port.circuit_wire_connection_points = {
  { wire = {red = {0, -0.35}, green = {0, -0.35}}, shadow = {red = {0, -0.35}, green = {0, -0.35}} },
  { wire = {red = {0, -0.35}, green = {0, -0.35}}, shadow = {red = {0, -0.35}, green = {0, -0.35}} },
  { wire = {red = {0, -0.35}, green = {0, -0.35}}, shadow = {red = {0, -0.35}, green = {0, -0.35}} },
  { wire = {red = {0, -0.35}, green = {0, -0.35}}, shadow = {red = {0, -0.35}, green = {0, -0.35}} },
}

data:extend({
  pneumatic_pipe, pneumatic_underground, pneumatic_hidden_network_pipe,
  tube_intake, tube_outtake,
  tube_network_combinator, tube_intake_network_port,
})
