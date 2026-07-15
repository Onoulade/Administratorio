-- Enforces the global invariant that science packs are research inputs only.
-- This final pass intentionally discovers packs from the loaded prototype set
-- so compatibility mods receive the same treatment as base and Space Age.

local M = {}

local function ingredient_name(ingredient)
  return ingredient and (ingredient.name or ingredient[1])
end

local function ingredient_type(ingredient)
  return (ingredient and ingredient.type) or "item"
end

local function ingredient_amount(ingredient)
  if not ingredient then return 0 end
  return ingredient.amount or ingredient[2] or 1
end

local function set_ingredient_amount(ingredient, amount)
  if ingredient.name or ingredient.type or ingredient.amount ~= nil then
    ingredient.amount = amount
  else
    ingredient[2] = amount
  end
end

local function append_or_merge_ingredient(ingredients, ingredient)
  local name = ingredient_name(ingredient)
  if not name then return end

  local ingredient_type_name = ingredient_type(ingredient)
  for _, existing in ipairs(ingredients) do
    if ingredient_name(existing) == name and ingredient_type(existing) == ingredient_type_name then
      set_ingredient_amount(existing, ingredient_amount(existing) + ingredient_amount(ingredient))
      return
    end
  end

  ingredients[#ingredients + 1] = ingredient
end

function M.apply(data, item_like_prototype_types)
  local science_pack_items = {}
  for _, item_type in ipairs(item_like_prototype_types) do
    for item_name, item in pairs(data.raw[item_type] or {}) do
      if item.subgroup == "science-pack" or item_name:find("science%-pack$") then
        science_pack_items[item_name] = true
      end
    end
  end

  local function strip_science_pack_ingredients(target)
    if not target or not target.ingredients then return end

    local ingredients = {}
    for _, ingredient in ipairs(target.ingredients) do
      local name = ingredient_name(ingredient)
      if ingredient_type(ingredient) ~= "item" or not science_pack_items[name] then
        append_or_merge_ingredient(ingredients, util.table.deepcopy(ingredient))
      end
    end
    target.ingredients = ingredients
  end

  for _, recipe in pairs(data.raw.recipe or {}) do
    strip_science_pack_ingredients(recipe)
    strip_science_pack_ingredients(recipe.normal)
    strip_science_pack_ingredients(recipe.expensive)
  end
end

return M
