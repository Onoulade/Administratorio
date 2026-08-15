-------------------------------------------------------------------------------
-- OPTICAL FIBRE
--
-- Inference Tokens are a fluid, and this is the only thing that carries them.
--
-- connection_category "optical-data" isolates the fibre from regular fluid
-- pipes and from the pneumatic tube network, exactly the way
-- "pneumatic-forms" isolates the tubes. The fluid itself sets auto_barrel
-- false, so tokens cannot be decanted into a barrel and moved by belt, chest,
-- train or rocket either. Compute has to be wired, not shipped.
--
-- The artwork is vanilla pipe art tinted, the same approach the pneumatic
-- pipes take, so the fibre reads as Administratorio infrastructure rather than
-- as a borrowed asset.
-------------------------------------------------------------------------------

local optical_tint = {r = 0.35, g = 0.8, b = 1.0, a = 1} -- signal cyan
local FIBRE_CONNECTION_CATEGORY = "optical-data"
local FIBRE_MAX_EXTENT = 400
local FIBRE_UNDERGROUND_DISTANCE = 12

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
          if not sheet.draw_as_shadow then
            sheet.tint = tint
          end
        end
      end
      if picture.layers then
        for _, layer in ipairs(picture.layers) do
          if not layer.draw_as_shadow then
            layer.tint = tint
          end
        end
      end
    end
  end
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
optical_fibre.icons = {{icon = "__base__/graphics/icons/pipe.png", icon_size = 64, tint = optical_tint}}
optical_fibre.icon = nil
optical_fibre.icon_size = nil
tint_pipe_pictures(optical_fibre.pictures, optical_tint)
if optical_fibre.pipe_covers then
  tint_pipe_pictures(optical_fibre.pipe_covers, optical_tint)
end
apply_fibre_category(optical_fibre.fluid_box)

local optical_fibre_underground = table.deepcopy(data.raw["pipe-to-ground"]["pipe-to-ground"])
optical_fibre_underground.name = "optical-fibre-to-ground"
optical_fibre_underground.minable.result = "optical-fibre-to-ground"
optical_fibre_underground.placeable_by = placeable_by_item("optical-fibre-to-ground")
optical_fibre_underground.fast_replaceable_group = "optical-fibre-to-ground"
optical_fibre_underground.icons = {{icon = "__base__/graphics/icons/pipe-to-ground.png", icon_size = 64, tint = optical_tint}}
optical_fibre_underground.icon = nil
optical_fibre_underground.icon_size = nil
tint_pipe_pictures(optical_fibre_underground.pictures, optical_tint)
apply_fibre_category(optical_fibre_underground.fluid_box, FIBRE_UNDERGROUND_DISTANCE)

data:extend({optical_fibre, optical_fibre_underground})

return {
  CONNECTION_CATEGORY = FIBRE_CONNECTION_CATEGORY,
  TINT = optical_tint,
}
