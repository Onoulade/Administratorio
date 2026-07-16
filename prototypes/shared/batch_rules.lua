-- ADMINISTRATORIO: REGULATED RECIPE BATCH CLASSIFICATION
--
-- Batch size is an economic property of the thing being produced, not a
-- release-era list of recipe names.  Keep the immutable 1x rules here, then
-- allow explicit balance overrides, and finally fall back to semantic output
-- classes.  The returned reason is deliberately stable so tests and audit
-- tooling can explain why a recipe received its multiplier.

local M = {}

local ITEM_LIKE_PROTOTYPE_TYPES = {
  "item",
  "tool",
  "repair-tool",
  "module",
  "capsule",
  "ammo",
  "gun",
  "armor",
  "blueprint",
  "blueprint-book",
  "copy-paste-tool",
  "deconstruction-item",
  "item-with-entity-data",
  "item-with-inventory",
  "item-with-label",
  "item-with-tags",
  "rail-planner",
  "selection-tool",
  "space-platform-starter-pack",
  "spidertron-remote",
  "upgrade-item",
}

-- Repeatable network/infrastructure pieces are built in useful lots.  Any
-- other placeable result is a production, military, or utility building and
-- receives the building default instead.
local TOOL_ENTITY_TYPES = {
  ["arithmetic-combinator"] = true,
  ["constant-combinator"] = true,
  ["container"] = true,
  ["decider-combinator"] = true,
  ["display-panel"] = true,
  ["electric-pole"] = true,
  ["gate"] = true,
  ["heat-pipe"] = true,
  ["inserter"] = true,
  ["lamp"] = true,
  ["linked-belt"] = true,
  ["loader"] = true,
  ["loader-1x1"] = true,
  ["logistic-container"] = true,
  ["offshore-pump"] = true,
  ["pipe"] = true,
  ["pipe-to-ground"] = true,
  ["power-switch"] = true,
  ["programmable-speaker"] = true,
  ["pump"] = true,
  ["rail-chain-signal"] = true,
  ["rail-signal"] = true,
  ["selector-combinator"] = true,
  ["splitter"] = true,
  ["storage-tank"] = true,
  ["train-stop"] = true,
  ["transport-belt"] = true,
  ["underground-belt"] = true,
  ["wall"] = true,
}

local function prototype_name(entry)
  return entry and (entry.name or entry[1])
end

local function recipe_target(recipe)
  return recipe.normal or recipe
end

local function recipe_results(recipe)
  local target = recipe_target(recipe)
  if target.results then return target.results end
  if target.result then
    return {{type = "item", name = target.result, amount = target.result_count or 1}}
  end
  return {}
end

local function find_item_like_prototype(data_raw, name)
  for _, prototype_type in ipairs(ITEM_LIKE_PROTOTYPE_TYPES) do
    local prototypes = data_raw[prototype_type]
    if prototypes and prototypes[name] then return prototypes[name] end
  end
end

local function is_fluid_result(data_raw, result)
  if result.type == "fluid" then return true end
  if result.type and result.type ~= "item" then return false end
  local name = prototype_name(result)
  return result.type == nil
    and name ~= nil
    and data_raw.fluid ~= nil
    and data_raw.fluid[name] ~= nil
    and find_item_like_prototype(data_raw, name) == nil
end

local function name_mentions_biter(name)
  return type(name) == "string" and name:find("biter", 1, true) ~= nil
end

local function recipe_mentions_biter(recipe_name, recipe, results, data_raw)
  if name_mentions_biter(recipe_name) or name_mentions_biter(recipe.subgroup) then
    return true
  end

  local target = recipe_target(recipe)
  for _, entry in ipairs(target.ingredients or {}) do
    if name_mentions_biter(prototype_name(entry)) then return true end
  end

  for _, result in ipairs(results) do
    local name = prototype_name(result)
    if name_mentions_biter(name) then return true end
    local prototype = name and find_item_like_prototype(data_raw, name)
    if prototype and name_mentions_biter(prototype.subgroup) then return true end
  end

  return false
end

local function starts_with_any(value, prefixes)
  if type(value) ~= "string" then return false end
  for _, prefix in ipairs(prefixes or {}) do
    if value:sub(1, #prefix) == prefix then return true end
  end
  return false
end

local function placed_entity_type(data_raw, place_result)
  for entity_type in pairs(TOOL_ENTITY_TYPES) do
    local prototypes = data_raw[entity_type]
    if prototypes and prototypes[place_result] then return entity_type end
  end
end

function M.resolve(data_raw, recipe_name, recipe, config)
  config = config or {}
  local results = recipe_results(recipe)
  if #results == 0 then return 1, "no-results" end

  local target = recipe_target(recipe)
  local main_product = target.main_product or recipe.main_product
  if main_product and data_raw.fluid and data_raw.fluid[main_product] then
    return 1, "fluid-only"
  end

  local all_fluid = true
  for _, result in ipairs(results) do
    if not is_fluid_result(data_raw, result) then
      all_fluid = false
      break
    end
  end
  if all_fluid then return 1, "fluid-only" end

  if recipe_mentions_biter(recipe_name, recipe, results, data_raw) then
    return 1, "biter-related"
  end

  local result_prototypes = {}
  for _, result in ipairs(results) do
    if not is_fluid_result(data_raw, result) then
      local name = prototype_name(result)
      local prototype = name and find_item_like_prototype(data_raw, name)
      result_prototypes[#result_prototypes + 1] = {name = name, prototype = prototype}

      if prototype and prototype.type == "module" then
        return 1, "module"
      end
      if prototype and prototype.place_as_equipment_result then
        return 1, "equipment"
      end
      if prototype and (prototype.stack_size or 1) == 1 then
        return 1, "non-stackable"
      end
      if name and config.unbatched_result_names and config.unbatched_result_names[name] then
        return 1, "unbatched-result"
      end
      if prototype and config.unbatched_result_subgroups
          and config.unbatched_result_subgroups[prototype.subgroup] then
        return 1, "unbatched-subgroup"
      end
    end
  end

  local explicit = config.multipliers and config.multipliers[recipe_name]
  if explicit then return explicit, "explicit" end

  if starts_with_any(recipe.subgroup, config.space_subgroup_prefixes) then
    return 1, "space-default"
  end
  for _, result in ipairs(result_prototypes) do
    if result.prototype
        and starts_with_any(result.prototype.subgroup, config.space_subgroup_prefixes) then
      return 1, "space-default"
    end
  end

  local has_tool_result = false
  local has_building_result = false
  for _, result in ipairs(result_prototypes) do
    local prototype = result.prototype
    if prototype then
      if prototype.type == "rail-planner" or prototype.place_as_tile then
        has_tool_result = true
      elseif prototype.place_result then
        if placed_entity_type(data_raw, prototype.place_result) then
          has_tool_result = true
        else
          has_building_result = true
        end
      end
    end
  end

  if has_building_result then
    return config.building_multiplier or 2, "production-building"
  end
  if has_tool_result then
    return config.tool_multiplier or 5, "tool-building"
  end

  return config.default_multiplier or 5, "standard-item"
end

return M
