local merge = {}

local ITEM_LIKE_TYPES = {
  "item",
  "tool",
  "repair-tool",
  "module",
  "capsule",
  "ammo",
  "gun",
  "armor",
  "selection-tool",
  "item-with-entity-data",
  "rail-planner",
  "spidertron-remote",
}

local EXTRA_ALLOWED_RECIPES = {
  ["paper-production"] = true,
  ["ink-production"] = true,
}

local function get_recipe_level(recipe)
  if recipe and recipe.normal then return recipe.normal end
  return recipe
end

local function get_unique_products(recipe)
  local level = get_recipe_level(recipe)
  if not level then return {} end

  local products = {}
  local seen = {}
  local results = level.results or (level.result and {{name = level.result}}) or {}

  for _, result in ipairs(results) do
    local name = result.name or result[1]
    if name and not seen[name] then
      seen[name] = true
      products[#products + 1] = name
    end
  end

  return products
end

local function get_merge_target(recipe)
  if not recipe then return nil end

  if recipe.main_product ~= nil and recipe.main_product ~= "" then
    return recipe.main_product
  end

  local level = get_recipe_level(recipe)
  if level and level ~= recipe and level.main_product ~= nil and level.main_product ~= "" then
    return level.main_product
  end

  local products = get_unique_products(recipe)
  if #products == 1 then
    return products[1]
  end

  return nil
end

local function is_supported_target(data_raw, name)
  if not name then return false end
  if data_raw.fluid and data_raw.fluid[name] then return true end

  for _, proto_type in ipairs(ITEM_LIKE_TYPES) do
    if data_raw[proto_type] and data_raw[proto_type][name] then
      return true
    end
  end

  return false
end

function merge.build_recipe_rename_map(data_raw, shared)
  local recipes = data_raw.recipe or {}
  local candidate_targets = {}
  local candidate_names = {}

  for recipe_name, recipe in pairs(recipes) do
    -- Quality generates one "-recycling" recipe per recyclable product. Some
    -- of those names match Administratorio's broad recipe patterns, but they
    -- are alternate disposal paths rather than canonical production recipes.
    -- Counting them here makes recipe identities depend on whether Quality is
    -- enabled, which in turn removes recipes from existing saves.
    local is_recycling_recipe = recipe_name:match("%-recycling$") ~= nil
    -- Recipes that explicitly redirect or hide from Factoriopedia are alternate
    -- production paths. They must not prevent the primary recipe from taking
    -- the product's canonical name. A hidden recipe can receive its alternative
    -- only after that canonical recipe has been created.
    local is_factoriopedia_alternative = recipe.factoriopedia_alternative ~= nil
      or recipe.hidden_in_factoriopedia == true
    if not is_recycling_recipe
      and not is_factoriopedia_alternative
      and (shared.is_admin_recipe(recipe_name) or EXTRA_ALLOWED_RECIPES[recipe_name]) then
      local target_name = get_merge_target(recipe)
      if target_name
        and target_name ~= recipe_name
        and not recipes[target_name]
        and is_supported_target(data_raw, target_name) then
        candidate_targets[target_name] = (candidate_targets[target_name] or 0) + 1
        candidate_names[recipe_name] = target_name
      end
    end
  end

  local rename_map = {}
  for recipe_name, target_name in pairs(candidate_names) do
    if candidate_targets[target_name] == 1 then
      rename_map[recipe_name] = target_name
    end
  end

  return rename_map
end

function merge.apply_recipe_renames(data_raw, shared, rename_map)
  local recipes = data_raw.recipe or {}

  for old_name, new_name in pairs(rename_map or {}) do
    local recipe = recipes[old_name]
    if recipe and not recipes[new_name] then
      recipes[old_name] = nil
      recipe.name = new_name
      recipes[new_name] = recipe
    end
  end

  for _, tech in pairs(data_raw.technology or {}) do
    if tech.effects then
      for _, effect in ipairs(tech.effects) do
        if effect.type == "unlock-recipe" and rename_map[effect.recipe] then
          effect.recipe = rename_map[effect.recipe]
        end
      end
    end
  end

  for _, recipe_table in ipairs({
    shared.FORM_PRODUCTION_RECIPES,
    shared.COMBINED_FORM_PRODUCTION_RECIPES,
  }) do
    for key, recipe_name in pairs(recipe_table) do
      if rename_map[recipe_name] then
        recipe_table[key] = rename_map[recipe_name]
      end
    end
  end
end

return merge
