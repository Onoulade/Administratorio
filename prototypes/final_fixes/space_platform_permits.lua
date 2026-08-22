-- Replaces all other paperwork on platform-building recipes with their single
-- orbital infrastructure permit after every general regulation pass has run.

local M = {}

local ORBITAL_INFRASTRUCTURE_PERMIT = "orbital-infrastructure-permit"

function M.apply(data, shared, item_like_prototype_types, helpers)
  local space_platform_building_recipes = util.table.deepcopy(shared.SPACE_PLATFORM_BUILDING_RECIPES or {})
  for _, item_type in ipairs(item_like_prototype_types) do
    for item_name, item in pairs(data.raw[item_type] or {}) do
      if item.subgroup == "space-platform" and item.place_result and data.raw.recipe[item_name] then
        space_platform_building_recipes[item_name] = true
      end
    end
  end

  local function require_only_orbital_infrastructure_permit(recipe)
    if not recipe then return end
    local function replace_target_paperwork(target)
      if not target or not target.ingredients then return end
      local ingredients = {}
      for _, ingredient in ipairs(target.ingredients) do
        local name = helpers.ingredient_name(ingredient)
        if not shared.PAPERWORK_ITEMS[name] then
          helpers.append_or_merge_ingredient(ingredients, util.table.deepcopy(ingredient))
        end
      end
      helpers.append_or_merge_ingredient(ingredients, {
        type = "item", name = ORBITAL_INFRASTRUCTURE_PERMIT, amount = 1,
      })
      target.ingredients = ingredients
    end
    replace_target_paperwork(recipe)
    replace_target_paperwork(recipe.normal)
    replace_target_paperwork(recipe.expensive)
  end

  for recipe_name in pairs(space_platform_building_recipes) do
    local regulated_name = recipe_name .. "-regulated"
    require_only_orbital_infrastructure_permit(data.raw.recipe[recipe_name])
    require_only_orbital_infrastructure_permit(data.raw.recipe[regulated_name])
  end
end

return M
