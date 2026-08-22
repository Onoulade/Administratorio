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
-- Fibre artwork is from Moshine by snouz. See THIRD-PARTY-NOTICES.md.
--
-- There is no underground variant: fibre runs on the surface only.
-- Connection covers are omitted deliberately, so the strands meet cleanly
-- instead of being capped by a pipe-style collar at every junction.
-------------------------------------------------------------------------------

local FIBRE_CONNECTION_CATEGORY = "optical-data"
local FIBRE_MAX_EXTENT = 400

local fibre_graphics = "__administratorio__/graphics/entities/third-party/optical-fibre/"

local function placeable_by_item(name)
  return {
    {item = name, count = 1},
  }
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

local function apply_fibre_category(fluid_box)
  for _, connection in pairs(fluid_box.pipe_connections or {}) do
    connection.connection_category = FIBRE_CONNECTION_CATEGORY
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
optical_fibre.fluid_box.hide_connection_info = true
apply_fibre_category(optical_fibre.fluid_box)

data:extend({optical_fibre})

return {
  CONNECTION_CATEGORY = FIBRE_CONNECTION_CATEGORY,
}
