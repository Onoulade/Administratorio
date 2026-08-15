-------------------------------------------------------------------------------
-- OPTIC FIBRE
--
-- Inference Tokens are a fluid, and this is the only thing that carries them.
--
-- connection_category "optical-data" isolates the fibre from regular fluid
-- pipes and from the pneumatic tube network, exactly the way
-- "pneumatic-forms" isolates the tubes. The fluid itself sets auto_barrel
-- false, so tokens cannot be decanted into a barrel and moved by belt, chest,
-- train or rocket either. Compute has to be wired, not shipped.
--
-- Surface fibre artwork is from Moshine by snouz. See THIRD-PARTY-NOTICES.md.
-- The underground variant has no counterpart there, so it stays vanilla
-- pipe-to-ground art tinted to the fibre's casing grey.
-------------------------------------------------------------------------------

local FIBRE_CONNECTION_CATEGORY = "optical-data"
local FIBRE_MAX_EXTENT = 400
local FIBRE_UNDERGROUND_DISTANCE = 12
local underground_tint = {r = 0.62, g = 0.66, b = 0.72, a = 1} -- fibre casing grey

local fibre_graphics = "__administratorio__/graphics/entities/third-party/optical-fibre/"

local function placeable_by_item(name)
  return {
    {item = name, count = 1},
  }
end

local function tint_pipe_pictures(pictures, tint)
  if not pictures then return end
  for _, picture in pairs(pictures) do
    if type(picture) == "table" then
      if picture.filename and not picture.draw_as_shadow then
        picture.tint = tint
      end
      if picture.sheets then
        for _, sheet in ipairs(picture.sheets) do
          if not sheet.draw_as_shadow then sheet.tint = tint end
        end
      end
      if picture.layers then
        for _, layer in ipairs(picture.layers) do
          if not layer.draw_as_shadow then layer.tint = tint end
        end
      end
    end
  end
end

local function fibre_sprite(file, width, height)
  return {
    filename = fibre_graphics .. file .. ".png",
    priority = "extra-high",
    width = width or 128,
    height = height or 128,
    scale = 0.5,
  }
end

--- Every key the pipe prototype expects. A missing one is a load error, so the
--- set is written out in full rather than merged over the vanilla table.
local function fibre_pictures()
  return {
    straight_vertical_single = fibre_sprite("opticalfiber-straight-vertical-single", 160, 160),
    straight_vertical = fibre_sprite("opticalfiber-straight-vertical"),
    straight_vertical_window = fibre_sprite("opticalfiber-straight-vertical-window"),
    straight_horizontal = fibre_sprite("opticalfiber-straight-horizontal"),
    straight_horizontal_window = fibre_sprite("opticalfiber-straight-horizontal-window"),
    corner_up_right = fibre_sprite("opticalfiber-corner-up-right"),
    corner_up_left = fibre_sprite("opticalfiber-corner-up-left"),
    corner_down_right = fibre_sprite("opticalfiber-corner-down-right"),
    corner_down_left = fibre_sprite("opticalfiber-corner-down-left"),
    t_up = fibre_sprite("opticalfiber-t-up"),
    t_down = fibre_sprite("opticalfiber-t-down"),
    t_right = fibre_sprite("opticalfiber-t-right"),
    t_left = fibre_sprite("opticalfiber-t-left"),
    cross = fibre_sprite("opticalfiber-cross"),
    ending_up = fibre_sprite("opticalfiber-ending-up"),
    ending_down = fibre_sprite("opticalfiber-ending-down"),
    ending_right = fibre_sprite("opticalfiber-ending-right"),
    ending_left = fibre_sprite("opticalfiber-ending-left"),
    horizontal_window_background = fibre_sprite("opticalfiber-horizontal-window-background"),
    vertical_window_background = fibre_sprite("opticalfiber-vertical-window-background"),
    fluid_background = fibre_sprite("fluid-background", 64, 40),
    low_temperature_flow = fibre_sprite("fluid-flow-low-temperature", 160, 20),
    middle_temperature_flow = fibre_sprite("fluid-flow-medium-temperature", 160, 20),
    high_temperature_flow = fibre_sprite("fluid-flow-high-temperature", 160, 20),
    gas_flow = {
      filename = fibre_graphics .. "steam.png",
      priority = "extra-high",
      line_length = 10,
      width = 48,
      height = 30,
      frame_count = 60,
      axially_symmetrical = false,
      direction_count = 1,
      animation_speed = 0.25,
      scale = 0.5,
    },
  }
end

local function fibre_covers()
  local function cover(direction)
    return {
      layers = {
        fibre_sprite("opticalfiber-cover-" .. direction),
      },
    }
  end
  return {
    north = cover("north"),
    east = cover("east"),
    south = cover("south"),
    west = cover("west"),
  }
end

local function apply_fibre_category(fluid_box, underground_distance)
  for _, connection in pairs(fluid_box.pipe_connections or {}) do
    if not connection.connection_type or connection.connection_type == "normal" then
      connection.connection_category = FIBRE_CONNECTION_CATEGORY
    elseif connection.connection_type == "underground" then
      connection.connection_category = FIBRE_CONNECTION_CATEGORY
      if underground_distance then
        connection.max_underground_distance = underground_distance
      end
    end
  end
  fluid_box.max_pipeline_extent = FIBRE_MAX_EXTENT
end

local optical_fibre = table.deepcopy(data.raw["pipe"]["pipe"])
optical_fibre.name = "optical-fibre"
optical_fibre.minable.result = "optical-fibre"
optical_fibre.placeable_by = placeable_by_item("optical-fibre")
optical_fibre.fast_replaceable_group = "optical-fibre"
optical_fibre.icon = fibre_graphics .. "opticalfiber-cross.png"
optical_fibre.icon_size = 128
optical_fibre.icons = nil
optical_fibre.pictures = fibre_pictures()
optical_fibre.fluid_box.pipe_covers = fibre_covers()
optical_fibre.fluid_box.hide_connection_info = true
apply_fibre_category(optical_fibre.fluid_box)

local optical_fibre_underground = table.deepcopy(data.raw["pipe-to-ground"]["pipe-to-ground"])
optical_fibre_underground.name = "optical-fibre-to-ground"
optical_fibre_underground.minable.result = "optical-fibre-to-ground"
optical_fibre_underground.placeable_by = placeable_by_item("optical-fibre-to-ground")
optical_fibre_underground.fast_replaceable_group = "optical-fibre-to-ground"
optical_fibre_underground.icons = {
  {icon = "__base__/graphics/icons/pipe-to-ground.png", icon_size = 64, tint = underground_tint},
}
optical_fibre_underground.icon = nil
optical_fibre_underground.icon_size = nil
tint_pipe_pictures(optical_fibre_underground.pictures, underground_tint)
apply_fibre_category(optical_fibre_underground.fluid_box, FIBRE_UNDERGROUND_DISTANCE)

data:extend({optical_fibre, optical_fibre_underground})

return {
  CONNECTION_CATEGORY = FIBRE_CONNECTION_CATEGORY,
}
