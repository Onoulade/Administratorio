local M = {}

function M.has(recipe, category)
  for _, candidate in ipairs(recipe.categories or {"crafting"}) do
    if candidate == category then return true end
  end
  return false
end

-- Regulation follows the assembler route, even when a specialist is listed first.
function M.primary(recipe)
  for _, category in ipairs({"crafting", "advanced-crafting", "crafting-with-fluid", "chemistry"}) do
    if M.has(recipe, category) then return category end
  end
  return recipe.categories and recipe.categories[1] or "crafting"
end

function M.matches(recipe, categories)
  for _, category in ipairs(recipe.categories or {"crafting"}) do
    if categories[category] then return true end
  end
  return false
end

return M
