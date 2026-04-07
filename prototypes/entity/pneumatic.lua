-------------------------------------------------------------------------------
-- PNEUMATIC FORM TRANSPORT SYSTEM
-- Converts paperwork items to fluids for transport through sealed pipes.
-- Uses "pneumatic-forms" connection_category so pneumatic pipes
-- CANNOT connect to regular fluid pipes.
-------------------------------------------------------------------------------

local pneumatic_tint = {r=0.85, g=0.75, b=0.55, a=1} -- manila/tan
local pneumatic_sound_path = "__administratorio__/sound/pneumatic/"

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

-- Pneumatic Pipe
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

-- Pneumatic Underground Pipe
local pneumatic_underground = table.deepcopy(data.raw["pipe-to-ground"]["pipe-to-ground"])
pneumatic_underground.name = "pneumatic-pipe-to-ground"
pneumatic_underground.minable.result = "pneumatic-pipe-to-ground"
pneumatic_underground.placeable_by = placeable_by_item("pneumatic-pipe-to-ground")
pneumatic_underground.fast_replaceable_group = "pneumatic-pipe-to-ground"
pneumatic_underground.icons = {{icon = "__base__/graphics/icons/pipe-to-ground.png", icon_size = 64, tint = pneumatic_tint}}
pneumatic_underground.icon = nil
pneumatic_underground.icon_size = nil
tint_pipe_pictures(pneumatic_underground.pictures, pneumatic_tint)
for _, pcon in pairs(pneumatic_underground.fluid_box.pipe_connections) do
  if not pcon.connection_type or pcon.connection_type == "normal" then
    pcon.connection_category = "pneumatic-forms"
  elseif pcon.connection_type == "underground" then
    pcon.connection_category = "pneumatic-forms"
  end
end

-- Empty sheet for hidden inserter graphics
local empty_sheet = {
  filename = "__core__/graphics/empty.png",
  priority = "very-low",
  width = 1, height = 1,
  frame_count = 1,
}

-- Form Liquifier (intake): furnace that converts items -> pneumatic fluids
local form_liquifier = {
  type = "furnace",
  name = "form-liquifier",
  icon = "__administratorio__/graphics/icons/pneumatic/intake.png",
  icon_size = 32,
  flags = {"placeable-neutral", "placeable-player", "player-creation"},
  minable = {mining_time = 0.2, result = "form-liquifier"},
  placeable_by = placeable_by_item("form-liquifier"),
  fast_replaceable_group = "pneumatic-io",
  max_health = 200,
  corpse = "small-remnants",
  collision_box = {{-0.3, -0.3}, {0.3, 0.3}},
  selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
  crafting_categories = {"pneumatic-liquify"},
  crafting_speed = 3,
  result_inventory_size = 0,
  source_inventory_size = 1,
  energy_source = {
    type = "electric",
    usage_priority = "secondary-input",
    emissions_per_minute = {["pollution"] = 0.03},
  },
  energy_usage = "20kW",
  graphics_set = {
    animation = {
      north = {
        filename = "__administratorio__/graphics/entities/pneumatic-intake/intake-up.png",
        priority = "high",
        width = 66,
        height = 72,
      },
      east = {
        filename = "__administratorio__/graphics/entities/pneumatic-intake/intake-right.png",
        priority = "high",
        width = 46,
        height = 46,
      },
      south = {
        filename = "__administratorio__/graphics/entities/pneumatic-intake/intake-down.png",
        priority = "high",
        width = 66,
        height = 72,
      },
      west = {
        filename = "__administratorio__/graphics/entities/pneumatic-intake/intake-left.png",
        priority = "high",
        width = 46,
        height = 46,
      },
    },
  },
  fluid_boxes = {
    {
      volume = 150,
      production_type = "output",
      pipe_covers = pipecoverspictures(),
      pipe_connections = {{direction = defines.direction.north, flow_direction = "output", position = {0, 0}, connection_category = "pneumatic-forms"}},
    },
  },
  working_sound = {
    sound = { filename = pneumatic_sound_path .. "pneumatic-send.ogg", volume = 0.32 },
    idle_sound = { filename = "__base__/sound/idle1.ogg" },
  },
}

-- Form Solidifier (outtake): furnace that converts pneumatic fluids -> items
local form_solidifier = {
  type = "furnace",
  name = "form-solidifier",
  icon = "__administratorio__/graphics/icons/pneumatic/outtake.png",
  icon_size = 32,
  flags = {"placeable-neutral", "placeable-player", "player-creation"},
  minable = {mining_time = 0.2, result = "form-solidifier"},
  placeable_by = placeable_by_item("form-solidifier"),
  fast_replaceable_group = "pneumatic-io",
  max_health = 200,
  corpse = "small-remnants",
  collision_box = {{-0.3, -0.3}, {0.3, 0.3}},
  selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
  crafting_categories = {"pneumatic-solidify"},
  crafting_speed = 3,
  result_inventory_size = 1,
  source_inventory_size = 0,
  energy_source = {
    type = "electric",
    usage_priority = "secondary-input",
    emissions_per_minute = {["pollution"] = 0.03},
  },
  energy_usage = "20kW",
  graphics_set = {
    animation = {
      north = {
        filename = "__administratorio__/graphics/entities/pneumatic-outtake/outtake-up.png",
        priority = "high",
        width = 66,
        height = 72,
      },
      east = {
        filename = "__administratorio__/graphics/entities/pneumatic-outtake/outtake-right.png",
        priority = "high",
        width = 46,
        height = 46,
      },
      south = {
        filename = "__administratorio__/graphics/entities/pneumatic-outtake/outtake-down.png",
        priority = "high",
        width = 66,
        height = 72,
      },
      west = {
        filename = "__administratorio__/graphics/entities/pneumatic-outtake/outtake-left.png",
        priority = "high",
        width = 46,
        height = 46,
      },
    },
  },
  fluid_boxes = {
    {
      volume = 150,
      production_type = "input",
      pipe_covers = pipecoverspictures(),
      pipe_connections = {{direction = defines.direction.north, flow_direction = "input", position = {0, 0}, connection_category = "pneumatic-forms"}},
    },
  },
  working_sound = {
    sound = { filename = pneumatic_sound_path .. "pneumatic-receive.ogg", volume = 0.3 },
    idle_sound = { filename = "__base__/sound/idle1.ogg" },
  },
}

-- Hidden inserters for liquifier/solidifier (move items in/out)
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
  -- Keep the drop point off the belt centerline so rotations don't flip lanes.
  pickup_position = {0, -0.2}, insert_position = {0.2, 1},
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

data:extend({pneumatic_pipe, pneumatic_underground, form_liquifier, form_solidifier, hidden_intake_inserter, hidden_outtake_inserter})
