-- Recipe icon assignment for recipes that produce nothing.
--
-- Factorio infers a recipe's icon from its main product. A recipe with an empty
-- results table has no main product, so the engine fails to load it with
-- 'Key "icon" not found in property tree'. Every no-output recipe family in
-- this mod -- pneumatic intake, interplanetary dispatch, relocation payload,
-- citation venting -- therefore has to set one explicitly.

local M = {}

--- Factorio's table.deepcopy is a runtime extension, so this module carries its
--- own copy and stays loadable by the data stage and the test harness alike.
local function copy(value)
  if type(value) ~= "table" then return value end
  local copied = {}
  for key, entry in pairs(value) do
    copied[key] = copy(entry)
  end
  return copied
end

--- Copy an item's icon onto a recipe, falling back to an empty sprite so a
--- missing prototype degrades to an invisible icon rather than a load error.
function M.from_item(recipe, item_name)
  local item_proto = (data.raw.item and data.raw.item[item_name])
    or (data.raw.tool and data.raw.tool[item_name])
    or (data.raw.module and data.raw.module[item_name])
    or (data.raw.capsule and data.raw.capsule[item_name])
    or (data.raw.fluid and data.raw.fluid[item_name])

  if item_proto and item_proto.icons then
    recipe.icons = copy(item_proto.icons)
  elseif item_proto and item_proto.icon then
    recipe.icon = item_proto.icon
    recipe.icon_size = item_proto.icon_size
    recipe.icon_mipmaps = item_proto.icon_mipmaps
  else
    recipe.icon = "__core__/graphics/empty.png"
    recipe.icon_size = 1
  end

  return recipe
end

return M
