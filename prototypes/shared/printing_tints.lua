local icon_tints = require("prototypes.shared.icon_tints")

local M = {}

local PRINTING_CATEGORIES = {
  ["printing"] = true,
  ["printing-advanced"] = true,
  ["printing-workorder"] = true,
}

local function result_name(recipe)
  if recipe.main_product and recipe.main_product ~= "" then
    return recipe.main_product
  end

  if recipe.result then
    return recipe.result
  end

  local first_result = recipe.results and recipe.results[1]
  return first_result and (first_result.name or first_result[1]) or nil
end

function M.apply(recipes)
  for _, recipe in pairs(recipes or {}) do
    if PRINTING_CATEGORIES[recipe.category] and not recipe.crafting_machine_tint then
      recipe.crafting_machine_tint = icon_tints.document_tint(result_name(recipe))
    end
  end
end

return M
