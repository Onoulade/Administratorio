-- Keep administrative science local to administration, and make recipe inputs
-- available through explicit technology prerequisites rather than broad hooks.
local M = {}

local ADMINISTRATIVE_EXCEPTIONS = {
  modules = true,
  ["speed-module"] = true, ["speed-module-2"] = true, ["speed-module-3"] = true,
  ["productivity-module"] = true, ["productivity-module-2"] = true, ["productivity-module-3"] = true,
  ["efficiency-module"] = true, ["efficiency-module-2"] = true, ["efficiency-module-3"] = true,
  ["quality-module"] = true, ["quality-module-2"] = true, ["quality-module-3"] = true,
  ["epic-quality"] = true, ["legendary-quality"] = true,
}

local function sorted_keys(values)
  local keys = {}
  for key in pairs(values) do keys[#keys + 1] = key end
  table.sort(keys)
  return keys
end

function M.apply(data)
  local technologies, recipes = data.raw.technology or {}, data.raw.recipe or {}
  local owned = data.administratorio_technology_ownership or {}
  local original = data.administratorio_original_prerequisites or {}
  local producers, initial, unlocked, inputs = {}, {}, {}, {}
  local function product_key(value) return (value.type or "item") .. "/" .. (value.name or value[1]) end
  initial["item/taxpayer-money"] = true -- awarded by scripted complaint resolution
  initial["item/enrolled-biter"] = true -- recruited by the Capture Bureau
  initial["fluid/water"] = true
  for _, prototype_type in ipairs({"resource", "tree", "plant", "simple-entity", "simple-entity-with-owner", "fish"}) do
    for _, prototype in pairs(data.raw[prototype_type] or {}) do
      local minable = prototype.minable or {}
      if minable.result then initial["item/" .. minable.result] = true end
      for _, result in ipairs(minable.results or {}) do initial[product_key(result)] = true end
    end
  end
  for _, tile in pairs(data.raw.tile or {}) do
    if tile.fluid then initial["fluid/" .. tile.fluid] = true end
  end
  for name in pairs(data.raw["asteroid-chunk"] or {}) do initial["item/" .. name] = true end
  local function production_recipe(recipe)
    return recipe and not recipe.hidden and recipe.category ~= "recycling"
      and recipe.category ~= "recycling-or-hand-crafting"
  end
  for _, recipe in pairs(recipes) do
    for _, result in ipairs(recipe.results or {}) do
      if production_recipe(recipe) and recipe.enabled ~= false then initial[product_key(result)] = true end
    end
  end
  for name, technology in pairs(technologies) do
    unlocked[name], inputs[name] = {}, {}
    for _, effect in ipairs(technology.effects or {}) do
      local recipe = effect.type == "unlock-recipe" and recipes[effect.recipe]
      if production_recipe(recipe) then
        for _, result in ipairs(recipe.results or {}) do
          local key = product_key(result)
          unlocked[name][key] = true
          producers[key] = producers[key] or {}
          producers[key][name] = true
        end
        for _, ingredient in ipairs(recipe.ingredients or {}) do inputs[name][product_key(ingredient)] = true end
      end
    end
  end

  local function closure(name, seen)
    seen = seen or {}
    if seen[name] then return seen end
    seen[name] = true
    for _, parent in ipairs((technologies[name] or {}).prerequisites or {}) do closure(parent, seen) end
    return seen
  end
  local function append(name, parent)
    local technology = technologies[name]
    technology.prerequisites = technology.prerequisites or {}
    technology.prerequisites[#technology.prerequisites + 1] = parent
  end

  for _, name in ipairs(sorted_keys(technologies)) do
    local technology = technologies[name]
    local science_unlock = name:match("%-science%-pack$") and name ~= "automation-science-pack"
      and name ~= "military-science-pack"
    -- Science unlocks after red science are paid administrative research,
    -- including Space Age's former craft/build triggers.
    if science_unlock and technology.research_trigger then
      technology.research_trigger = nil
      technology.unit = {count = 75, ingredients = {{"administrative-science-pack", 1}}, time = 30}
    end
    local administrative = owned[name] or ADMINISTRATIVE_EXCEPTIONS[name] or science_unlock
    if technology.unit then
      local ingredients, has_admin = {}, false
      for _, ingredient in ipairs(technology.unit.ingredients or {}) do
        local pack = ingredient.name or ingredient[1]
        if pack ~= "administrative-science-pack" or administrative then
          ingredients[#ingredients + 1] = ingredient
          if pack == "administrative-science-pack" then has_admin = true end
        end
      end
      if science_unlock and not has_admin then ingredients[#ingredients + 1] = {"administrative-science-pack", 1} end
      technology.unit.ingredients = ingredients
    end

    -- Only remove hooks this mod added to pre-existing, ordinary technologies.
    -- Science milestones and explicitly administrative vanilla skins stay intact.
    if original[name] and not administrative then
      local native, kept = {}, {}
      for _, parent in ipairs(original[name]) do native[parent] = true end
      for _, parent in ipairs(technology.prerequisites or {}) do
        local required = false
        for key in pairs(inputs[name]) do
          if (unlocked[parent] or {})[key] then required = true; break end
        end
        if native[parent] or not owned[parent] or required then kept[#kept + 1] = parent end
      end
      technology.prerequisites = kept
    end
  end

  -- Recipe inputs can have alternative producers. Prefer an existing ancestor;
  -- otherwise pick the earliest acyclic producer, deterministically. An input
  -- produced by another recipe unlocked here does not need an external gate.
  for _, name in ipairs(sorted_keys(technologies)) do
    local technology = technologies[name]
    if technology.hidden or technology.enabled == false then goto next_technology end
    for _, key in ipairs(sorted_keys(inputs[name])) do
      if initial[key] or unlocked[name][key] then goto next_input end
      local ancestors, candidates, available = closure(name), {}, false
      for producer in pairs(producers[key] or {}) do
        if ancestors[producer] then available = true; break end
        local parent = technologies[producer]
        if not parent.hidden and parent.enabled ~= false and not closure(producer)[name] then
          candidates[#candidates + 1] = producer
        end
      end
      if not available and #candidates > 0 then
        table.sort(candidates, function(a, b)
          local a_count, b_count = 0, 0
          for _ in pairs(closure(a)) do a_count = a_count + 1 end
          for _ in pairs(closure(b)) do b_count = b_count + 1 end
          return a_count == b_count and a < b or a_count < b_count
        end)
        append(name, candidates[1])
      end
      ::next_input::
    end
    -- Every paid administrative science cost must follow its own bootstrap.
    for _, ingredient in ipairs((technology.unit or {}).ingredients or {}) do
      if (ingredient.name or ingredient[1]) == "administrative-science-pack"
          and technologies["administrative-science-research"]
          and not closure(name)["administrative-science-research"] then
        append(name, "administrative-science-research")
      end
    end
    ::next_technology::
  end
end

return M
