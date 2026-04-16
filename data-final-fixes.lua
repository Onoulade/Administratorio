-- ADMINISTRATORIO: DATA FINAL FIXES
--
-- Runs after ALL mods' data.lua and data-updates.lua.
-- This file handles:
--   1. Additional recipe categories for regulated crafting
--   2. Character setup (crafting restrictions, starting items)
--   3. Machine category setup (AM1/AM2/AM3 all use regulated categories)
--   4. Machine-family operating paperwork for hazardous process recipes
--   5. Deterministic recipe regulation
--   6. Handcrafting visibility
--   7. Pneumatic form transport recipe generation
--   8. Admin station collision footprint layering
--
-- The regulation system:
--   Red science or below (handcraftable):
--     Handcrafting -> original recipe (T0: no form, T1+: tier form added)
--     AM1/AM2/AM3 and Factoriopedia -> separate "-regulated" copy
--       (batched, form, consumed)
--   Above green science (not handcraftable):
--     Original recipe modified in-place -> regulated category, batched, form
--     Keeps recipe identity and tech unlocks intact

local shared = require("prototypes.shared")
local factoriopedia_merge = require("prototypes.factoriopedia_merge")
local feature_flags = require("feature_flags")

local ADMIN_STATION_COLLISION_LAYER = "administratorio_station_footprint"
local REGULATED_AM_FACTORIOPEDIA_NOTE = {"administratorio-factoriopedia.regulated-assembling-note"}
local WORKING_HOURS_ENABLED = feature_flags.working_hours_enabled()
local DEBUG_SHOW_PAPERWORK_ICON_OVERLAYS = false
local NIGHT_WORK_BUILDINGS = {
  ["office-desk"] = true,
  ["corporate-breakroom"] = true,
  ["union-headquarters"] = true,
}

local ADMIN_STATION_NON_BLOCKING_NAMES = {
  ["admin-station-combinator"] = true,
  ["waiting-zone-marker"] = true,
  ["transit-permit-chest"] = true,
  ["pneumatic-hidden-intake"] = true,
  ["pneumatic-hidden-outtake"] = true,
  ["pneumatic-hidden-network-pipe"] = true,
}

local ADMIN_STATION_EXCLUDED_TYPES = {
  -- Ephemeral / non-physical entities
  ["character"] = true,
  ["combat-robot"] = true,
  ["construction-robot"] = true,
  ["corpse"] = true,
  ["entity-ghost"] = true,
  ["explosion"] = true,
  ["fire"] = true,
  ["highlight-box"] = true,
  ["item-entity"] = true,
  ["logistic-robot"] = true,
  ["optimized-decorative"] = true,
  ["particle"] = true,
  ["particle-source"] = true,
  ["projectile"] = true,
  ["rocket-silo-rocket"] = true,
  ["segment"] = true,
  ["segmented-unit"] = true,
  ["smoke"] = true,
  ["smoke-with-trigger"] = true,
  ["speech-bubble"] = true,
  ["spider-leg"] = true,
  ["spider-unit"] = true,
  ["stream"] = true,
  ["tile-ghost"] = true,
  ["unit"] = true,
  -- Natural map features — must not block placement of miners, buildings, etc.
  ["resource"] = true,
  ["tree"] = true,
  ["simple-entity"] = true,
  ["simple-entity-with-force"] = true,
  ["simple-entity-with-owner"] = true,
  ["cliff"] = true,
  ["fish"] = true,
  -- Enemy structures — already blocked by object layer, no need for extra layer
  ["unit-spawner"] = true,
  ["turret"] = true,            -- enemy worms (player turrets are ammo-/electric-/fluid-turret)
  -- Walkable entities — player walks over these in vanilla
  ["transport-belt"] = true,
  ["underground-belt"] = true,
  ["splitter"] = true,
  ["loader"] = true,
  ["loader-1x1"] = true,
  ["linked-belt"] = true,
  ["lane-splitter"] = true,
  ["inserter"] = true,
  ["land-mine"] = true,
  ["straight-rail"] = true,
  ["curved-rail-a"] = true,
  ["curved-rail-b"] = true,
  ["half-diagonal-rail"] = true,
  ["elevated-straight-rail"] = true,
  ["elevated-curved-rail-a"] = true,
  ["elevated-curved-rail-b"] = true,
  ["elevated-half-diagonal-rail"] = true,
  ["rail-ramp"] = true,
  ["rail-support"] = true,
  ["legacy-straight-rail"] = true,
  ["legacy-curved-rail"] = true,
  ["rail-signal"] = true,
  ["rail-chain-signal"] = true,
  ["display-panel"] = true,
  -- Vehicles — mobile, should not be blocked by footprint
  ["car"] = true,               -- cars and tanks
  ["spider-vehicle"] = true,    -- spidertron
  ["locomotive"] = true,
  ["cargo-wagon"] = true,
  ["fluid-wagon"] = true,
}

local ADMIN_STATION_EXCLUDED_FLAGS = {
  ["not-on-map"] = true,
  ["placeable-off-grid"] = true,
}

-------------------------------------------------------------------------------
-- 1. ADDITIONAL RECIPE CATEGORIES
-------------------------------------------------------------------------------
data:extend({
  {type = "recipe-category", name = "crafting-regulated"},
  {type = "recipe-category", name = "advanced-crafting-regulated"},
})

-------------------------------------------------------------------------------
-- 2. CHARACTER SETUP
-- Remove starting weapons. Character recipe categories are defined centrally
-- in prototypes/categories.lua; keep final-fixes focused on inventory cleanup.
-------------------------------------------------------------------------------
if data.raw["character"]["character"] then
  local char = data.raw["character"]["character"]
  char.created_items = {}
  char.respawn_items = {}
  char.guns_inventory_size = 1
end

-- Hide all guns and ammo (final pass catches anything other mods may add)
for _, proto_type in ipairs({"gun", "ammo"}) do
  for _, proto in pairs(data.raw[proto_type] or {}) do
    proto.hidden = true
  end
end

-------------------------------------------------------------------------------
-- 3. MACHINE CATEGORY SETUP
-- All AMs use only regulated categories. No original crafting categories.
-------------------------------------------------------------------------------
if data.raw["assembling-machine"]["assembling-machine-1"] then
  data.raw["assembling-machine"]["assembling-machine-1"].crafting_categories = {"crafting-regulated"}
end
if data.raw["assembling-machine"]["assembling-machine-2"] then
  data.raw["assembling-machine"]["assembling-machine-2"].crafting_categories = {"crafting-regulated", "advanced-crafting-regulated"}
end
if data.raw["assembling-machine"]["assembling-machine-3"] then
  data.raw["assembling-machine"]["assembling-machine-3"].crafting_categories = {"crafting-regulated", "advanced-crafting-regulated"}
end

-------------------------------------------------------------------------------
-- 4. MACHINE-FAMILY OPERATING PAPERWORK
-------------------------------------------------------------------------------
local function add_ingredient_to_recipe(recipe_name, item_name, count)
  local recipe = data.raw["recipe"][recipe_name]
  if not recipe then return end

  if recipe.ingredients then
    table.insert(recipe.ingredients, {type = "item", name = item_name, amount = count})
  elseif recipe.normal and recipe.normal.ingredients then
    table.insert(recipe.normal.ingredients, {type = "item", name = item_name, amount = count})
    if recipe.expensive and recipe.expensive.ingredients then
      table.insert(recipe.expensive.ingredients, {type = "item", name = item_name, amount = count})
    end
  end
end

local function add_special_paperwork(recipe_name, item_name, count)
  local recipe = data.raw["recipe"][recipe_name]
  if not recipe then return end

  local function has_ingredient(target)
    if not target or not target.ingredients then return false end
    for _, ingredient in ipairs(target.ingredients) do
      if (ingredient.name or ingredient[1]) == item_name then
        return true
      end
    end
    return false
  end

  local target = recipe.normal or recipe
  if not has_ingredient(target) then
    add_ingredient_to_recipe(recipe_name, item_name, count)
  end
end

local function remove_ingredient_from_recipe(recipe_name, item_name)
  local recipe = data.raw["recipe"][recipe_name]
  if not recipe then return end

  local function strip_ingredient(target)
    if not target or not target.ingredients then return end

    local filtered = {}
    for _, ingredient in ipairs(target.ingredients) do
      if (ingredient.name or ingredient[1]) ~= item_name then
        filtered[#filtered + 1] = ingredient
      end
    end
    target.ingredients = filtered
  end

  strip_ingredient(recipe)
  strip_ingredient(recipe.normal)
  strip_ingredient(recipe.expensive)
end

local function add_osha_violation(target)
  if not target then return end
  local original_product = target.main_product or target.result

  if not original_product and target.results and target.results[1] then
    original_product = target.results[1].name or target.results[1][1]
  end

  local product_type = "item"
  if original_product and data.raw["fluid"][original_product] then product_type = "fluid" end

  local res = target.results or (target.result and {
    {type = product_type, name = target.result, amount = (target.result_count or 1)}
  })

  if res then
    table.insert(res, {type = "item", name = "osha-violation", amount = 1, probability = 0.5})
    target.results = res
    target.result = nil
    if original_product then target.main_product = original_product end
  end
end

for _, recipe in pairs(data.raw["recipe"]) do
  if not shared.is_admin_recipe(recipe.name) then
    local cat = recipe.category or "crafting"
    local operating_form = shared.get_operating_form(recipe)
    if operating_form then
      add_ingredient_to_recipe(recipe.name, operating_form, 1)

      -- Hazardous process families still create OSHA fallout.
      local is_hazardous = cat == "centrifuging"
         or recipe.name:find("uranium") or recipe.name:find("nuclear")
         or recipe.name:find("explosive") or recipe.name:find("acid")
      if is_hazardous then
        add_osha_violation(recipe)
        if recipe.normal then add_osha_violation(recipe.normal) end
        if recipe.expensive then add_osha_violation(recipe.expensive) end
      end
    end
  end
end

-------------------------------------------------------------------------------
-- 4a. FACTORIOPEDIA CANONICAL RECIPE NAMES
-- Factoriopedia merges a product page with a recipe page only when both share
-- the same internal name. Apply that to safe mod recipes whose product has a
-- single canonical recipe, while leaving alternate recipes visible.
-------------------------------------------------------------------------------
local factoriopedia_recipe_renames = factoriopedia_merge.build_recipe_rename_map(data.raw, shared)
factoriopedia_merge.apply_recipe_renames(data.raw, shared, factoriopedia_recipe_renames)

-------------------------------------------------------------------------------
-- 5a. BUILD RED-SCIENCE-ONLY RECIPE SET
-- Scan all technologies to determine which recipes are unlocked by red science
-- (automation-science-pack + administrative-science-pack only).
-- Recipes requiring green science or higher are hidden from handcrafting.
-------------------------------------------------------------------------------
local RED_SCIENCE_PACKS = {
  ["automation-science-pack"] = true,
  ["administrative-science-pack"] = true,
}

local red_science_recipes = {}

for _, tech in pairs(data.raw.technology) do
  local is_red_only = true
  if tech.unit and tech.unit.ingredients then
    for _, ing in ipairs(tech.unit.ingredients) do
      local pack_name = ing[1] or ing.name
      if not RED_SCIENCE_PACKS[pack_name] then
        is_red_only = false
        break
      end
    end
  end
  -- research_trigger techs (mine-entity) count as red-science-tier
  if tech.research_trigger then
    is_red_only = true
  end

  if is_red_only and tech.effects then
    for _, effect in ipairs(tech.effects) do
      if effect.type == "unlock-recipe" then
        red_science_recipes[effect.recipe] = true
      end
    end
  end
end

local function is_red_science_or_below(recipe_name)
  local recipe = data.raw["recipe"][recipe_name]
  if not recipe then return false end
  -- Enabled by default = available from start (no tech needed)
  if recipe.enabled ~= false then return true end
  -- Unlocked by a red-science-only tech
  return red_science_recipes[recipe_name] == true
end

-------------------------------------------------------------------------------
-- 5. DETERMINISTIC RECIPE REGULATION
--
-- For every vanilla "crafting" / "advanced-crafting" / "crafting-with-fluid"
-- recipe, create a regulated copy:
--
-- A) "-regulated" (AM1/AM2/AM3):
--    - Batch multiplied ingredients and results
--    - Requires combined form (tier form + work-order) for T1+ items,
--      or just work-order for T0 items
--    - Form is consumed (no return)
--
-- B) Original recipe modification (T1+ items):
--    - Tier form added as ingredient (for handcrafting)
-------------------------------------------------------------------------------

local ITEM_LIKE_PROTOTYPE_TYPES = {
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

local function find_item_like_prototype(name)
  for _, item_type in ipairs(ITEM_LIKE_PROTOTYPE_TYPES) do
    if data.raw[item_type] and data.raw[item_type][name] then
      return data.raw[item_type][name]
    end
  end
  return nil
end

local function get_max_stack_size(item_name)
  local prototype = find_item_like_prototype(item_name)
  if prototype then return prototype.stack_size or 1 end
  return 100
end

local function get_recipe_batch_multiplier(recipe_name, recipe)
  local explicit_multiplier = shared.BATCH_MULTIPLIERS[recipe_name]
  local multiplier = explicit_multiplier or shared.BATCH_MULTIPLIER_DEFAULT
  local r_proto = recipe.normal or recipe
  local results = r_proto.results or (r_proto.result and {{name = r_proto.result}}) or {}

  for _, res in ipairs(results) do
    local res_name = res.name or res[1]
    if res_name then
      local prototype = find_item_like_prototype(res_name)
      if get_max_stack_size(res_name) == 1 then
        return 1
      end
      -- Equipment-grid items are always unbatched, even if a future explicit
      -- multiplier override is accidentally added.
      if prototype and prototype.placed_as_equipment_result then
        return 1
      end
    end
  end

  return multiplier
end

local function get_item_like_localisation(prototype, product_name)
  if not prototype then
    return {"item-name." .. product_name}, {"item-description." .. product_name}
  end

  local localised_name = prototype.localised_name
  local localised_description = prototype.localised_description

  if not localised_name then
    if prototype.place_result then
      localised_name = {"entity-name." .. prototype.place_result}
    elseif prototype.placed_as_equipment_result then
      localised_name = {"equipment-name." .. prototype.placed_as_equipment_result}
    elseif prototype.place_as_tile and prototype.place_as_tile.result then
      localised_name = {"tile-name." .. prototype.place_as_tile.result}
    else
      localised_name = {"item-name." .. product_name}
    end
  end

  if not localised_description then
    if prototype.place_result then
      localised_description = {"entity-description." .. prototype.place_result}
    elseif prototype.placed_as_equipment_result then
      localised_description = {"equipment-description." .. prototype.placed_as_equipment_result}
    elseif prototype.place_as_tile and prototype.place_as_tile.result then
      localised_description = {"tile-description." .. prototype.place_as_tile.result}
    else
      localised_description = {"item-description." .. product_name}
    end
  end

  return localised_name, localised_description
end

local function add_factoriopedia_note(prototype, note)
  if not prototype or not note then return end
  if prototype.factoriopedia_description then
    prototype.factoriopedia_description = {"", prototype.factoriopedia_description, "\n\n", note}
  else
    prototype.factoriopedia_description = note
  end
end

local function prefer_factoriopedia_recipe(original_recipe, preferred_recipe_name)
  if not original_recipe or not preferred_recipe_name then return end
  original_recipe.hidden_in_factoriopedia = true
  original_recipe.factoriopedia_alternative = preferred_recipe_name
end

local function get_primary_item_like_result_name(recipe)
  local target = recipe.normal or recipe
  if not target then return nil end

  if target.main_product and target.main_product ~= "" and find_item_like_prototype(target.main_product) then
    return target.main_product
  end
  if recipe.main_product and recipe.main_product ~= "" and find_item_like_prototype(recipe.main_product) then
    return recipe.main_product
  end

  local results = target.results or (target.result and {{name = target.result}}) or {}
  local product_name = nil
  for _, res in ipairs(results) do
    local res_name = res.name or res[1]
    if res_name and find_item_like_prototype(res_name) then
      if product_name and product_name ~= res_name then
        return nil
      end
      product_name = res_name
    end
  end

  return product_name
end

local function get_primary_result_name_and_type(recipe)
  local target = recipe.normal or recipe
  if not target then return nil, nil end

  local main_product = target.main_product or recipe.main_product
  if main_product and main_product ~= "" then
    if find_item_like_prototype(main_product) then
      return main_product, "item"
    end
    if data.raw["fluid"] and data.raw["fluid"][main_product] then
      return main_product, "fluid"
    end
  end

  local results = target.results or (target.result and {{name = target.result}}) or {}
  local product_name = nil
  local product_type = nil
  for _, res in ipairs(results) do
    local res_name = res.name or res[1]
    local res_type = res.type

    if not res_type then
      if find_item_like_prototype(res_name) then
        res_type = "item"
      elseif data.raw["fluid"] and data.raw["fluid"][res_name] then
        res_type = "fluid"
      end
    end

    if res_name and (res_type == "item" or res_type == "fluid") then
      if product_name and product_name ~= res_name then
        return nil, nil
      end
      product_name = res_name
      product_type = res_type
    end
  end

  return product_name, product_type
end

local function clone_icon_layers(prototype)
  if not prototype then return nil end
  if prototype.icons then
    return util.table.deepcopy(prototype.icons)
  end
  if prototype.icon then
    return {{
      icon = prototype.icon,
      icon_size = prototype.icon_size or 64,
      icon_mipmaps = prototype.icon_mipmaps,
    }}
  end
  return nil
end

local function get_recipe_base_icons(recipe)
  local icons = clone_icon_layers(recipe)
  if icons then return icons end

  local product_name, product_type = get_primary_result_name_and_type(recipe)
  if not product_name then return nil end

  if product_type == "item" then
    return clone_icon_layers(find_item_like_prototype(product_name))
  end
  if product_type == "fluid" and data.raw["fluid"] and data.raw["fluid"][product_name] then
    return clone_icon_layers(data.raw["fluid"][product_name])
  end

  return nil
end

local function shift_icon_layer(layer, offset, scale)
  local shifted = util.table.deepcopy(layer)
  local base_shift = shifted.shift or {0, 0}

  shifted.shift = {
    (base_shift[1] or 0) + offset[1],
    (base_shift[2] or 0) + offset[2],
  }
  shifted.scale = (shifted.scale or 1) * scale

  return shifted
end

local function apply_bulk_recipe_icon_overlay(recipe, multiplier, paperwork_name)
  if not recipe or not paperwork_name then return end

  local icons = get_recipe_base_icons(recipe)
  if not icons then return end

  if DEBUG_SHOW_PAPERWORK_ICON_OVERLAYS and paperwork_name ~= "work-order" then
    local paperwork = find_item_like_prototype(paperwork_name)
    if not paperwork and data.raw["fluid"] then
      paperwork = data.raw["fluid"][paperwork_name]
    end
    local paperwork_icons = clone_icon_layers(paperwork)
    if paperwork_icons then
      for _, layer in ipairs(paperwork_icons) do
        table.insert(icons, shift_icon_layer(layer, {12, -12}, 0.24))
      end
    end
  end

  if multiplier and multiplier > 1 then
    local multiplier_text = tostring(multiplier)
    local start_x = -14
    for i = 1, #multiplier_text do
      local digit = multiplier_text:sub(i, i)
      table.insert(icons, {
        icon = "__base__/graphics/icons/signal/signal_" .. digit .. ".png",
        icon_size = 64,
        scale = 0.26,
        shift = {start_x + ((i - 1) * 10), -12},
      })
    end
  end

  recipe.icons = icons
  recipe.icon = nil
  recipe.icon_size = nil
  recipe.icon_mipmaps = nil
end

local function resolve_regulated_recipe_localisation(recipe, recipe_name)
  if recipe.localised_name and recipe.localised_description then
    return recipe.localised_name, recipe.localised_description
  end

  local product_name, product_type = get_primary_result_name_and_type(recipe)
  local localised_name = recipe.localised_name
  local localised_description = recipe.localised_description

  if product_name and product_type == "item" then
    local prototype = find_item_like_prototype(product_name)
    local prototype_name, prototype_description = get_item_like_localisation(prototype, product_name)
    localised_name = localised_name or prototype_name
    localised_description = localised_description or prototype_description
  elseif product_name and product_type == "fluid" then
    local prototype = data.raw["fluid"] and data.raw["fluid"][product_name]
    localised_name = localised_name or (prototype and prototype.localised_name) or {"fluid-name." .. product_name}
    localised_description = localised_description or (prototype and prototype.localised_description) or {"fluid-description." .. product_name}
  else
    localised_name = localised_name or {"recipe-name." .. recipe_name}
  end

  return localised_name, localised_description
end

local function normalize_paperwork_requirements(requirements)
  if not requirements then return {} end

  if type(requirements) == "string" then
    return {{name = requirements, amount = 1}}
  end

  local normalized = {}
  for _, requirement in ipairs(requirements) do
    if type(requirement) == "string" then
      normalized[#normalized + 1] = {name = requirement, amount = 1}
    elseif requirement and requirement.name then
      normalized[#normalized + 1] = {
        name = requirement.name,
        amount = requirement.amount or 1,
      }
    end
  end

  return normalized
end

-- Create a batched copy of a recipe with paperwork requirements.
-- Paperwork is always consumed (no return).
local function regulate_recipe(recipe, paperwork_requirements, multiplier)
  if not recipe then return end
  paperwork_requirements = normalize_paperwork_requirements(paperwork_requirements)

  local function process_level(target)
    if not target then return end

    -- Multiply base craft time
    if target.energy_required then
      target.energy_required = target.energy_required * multiplier
    else
      target.energy_required = 0.5 * multiplier
    end

    -- Process ingredients: strip old paperwork, multiply base, add paperwork
    if target.ingredients then
      local clean_ingredients = {}
      for _, ing in ipairs(target.ingredients) do
        local name = ing.name or ing[1]
        if not shared.PAPERWORK_ITEMS[name] then
          table.insert(clean_ingredients, ing)
        end
      end
      target.ingredients = clean_ingredients

      for _, ing in ipairs(target.ingredients) do
        if ing.amount then
          ing.amount = ing.amount * multiplier
        else
          ing[2] = ing[2] * multiplier
        end
      end

      -- Paperwork per batch is fixed and never multiplied.
      for _, paperwork in ipairs(paperwork_requirements) do
        table.insert(target.ingredients, {type = "item", name = paperwork.name, amount = paperwork.amount})
      end
    end

    -- Process results: multiply outputs
    local results = {}
    if target.results then
      for _, res in ipairs(target.results) do
        local new_res = util.table.deepcopy(res)
        if new_res.amount then
          new_res.amount = new_res.amount * multiplier
        elseif new_res.amount_min and new_res.amount_max then
          new_res.amount_min = new_res.amount_min * multiplier
          new_res.amount_max = new_res.amount_max * multiplier
        end
        table.insert(results, new_res)
      end
    elseif target.result then
      local count = (target.result_count or 1) * multiplier
      table.insert(results, {type = "item", name = target.result, amount = count})
      target.result = nil
      target.result_count = nil
    end

    target.results = results
    target.main_product = target.main_product or (results[1] and results[1].name)
  end

  process_level(recipe)
  if recipe.normal then process_level(recipe.normal) end
  if recipe.expensive then process_level(recipe.expensive) end
end

-- Batch the original recipe and add paperwork ingredients (for handcrafting T1+ items).
-- Same batch multiplier as AM recipes so paperwork cost per item stays consistent.
local function batch_original_with_form(recipe, paperwork_requirements, multiplier)
  paperwork_requirements = normalize_paperwork_requirements(paperwork_requirements)

  local function process_level(target)
    if not target then return end

    -- Multiply craft time
    if target.energy_required then
      target.energy_required = target.energy_required * multiplier
    else
      target.energy_required = 0.5 * multiplier
    end

    -- Multiply ingredients, add paperwork
    if target.ingredients then
      for _, ing in ipairs(target.ingredients) do
        if ing.amount then
          ing.amount = ing.amount * multiplier
        else
          ing[2] = ing[2] * multiplier
        end
      end
      for _, paperwork in ipairs(paperwork_requirements) do
        table.insert(target.ingredients, {type = "item", name = paperwork.name, amount = paperwork.amount})
      end
    end

    -- Multiply results
    if target.results then
      for _, res in ipairs(target.results) do
        if res.amount then
          res.amount = res.amount * multiplier
        elseif res.amount_min and res.amount_max then
          res.amount_min = res.amount_min * multiplier
          res.amount_max = res.amount_max * multiplier
        end
      end
    elseif target.result then
      local count = (target.result_count or 1) * multiplier
      target.results = {{type = "item", name = target.result, amount = count}}
      target.main_product = target.result
      target.result = nil
      target.result_count = nil
    end
  end

  if recipe.ingredients then
    process_level(recipe)
  end
  if recipe.normal then process_level(recipe.normal) end
  if recipe.expensive then process_level(recipe.expensive) end
end

for name, recipe in pairs(data.raw["recipe"]) do
  if shared.is_admin_recipe(name) then goto next_operating_recipe end

  local operating_form = shared.get_operating_form(recipe)
  if not operating_form then goto next_operating_recipe end

  local multiplier = get_recipe_batch_multiplier(name, recipe)
  regulate_recipe(recipe, operating_form, multiplier)
  apply_bulk_recipe_icon_overlay(recipe, multiplier, operating_form)

  ::next_operating_recipe::
end

-- Build reverse set of form production recipes for quick lookup
local FORM_PRODUCTION_RECIPE_SET = {}
for _, recipe_name in pairs(shared.FORM_PRODUCTION_RECIPES) do
  FORM_PRODUCTION_RECIPE_SET[recipe_name] = true
end
for _, recipe_name in pairs(shared.COMBINED_FORM_PRODUCTION_RECIPES) do
  FORM_PRODUCTION_RECIPE_SET[recipe_name] = true
end

local regulated_recipes = {}
local regulated_factoriopedia_products = {}

for name, recipe in pairs(data.raw["recipe"]) do
  -- Skip our mod's recipes
  if shared.is_admin_recipe(name) or shared.ADMIN_BUILDINGS[name]
     or FORM_PRODUCTION_RECIPE_SET[name] then
    goto continue
  end

  local cat = recipe.category or "crafting"

  -- Only regulate standard crafting categories
  if cat ~= "crafting" and cat ~= "advanced-crafting" and cat ~= "crafting-with-fluid" then
    goto continue
  end

  -- Determine batch multiplier (force 1 for non-stackable outputs)
  local multiplier = get_recipe_batch_multiplier(name, recipe)
  local primary_result_name = get_primary_item_like_result_name(recipe)
  if primary_result_name then
    regulated_factoriopedia_products[primary_result_name] = true
  end

  -- Determine which form is required based on item tier
  local required_form = shared.get_required_form(name)
  local is_t0 = (required_form == "work-order")

  local handcraft_paperwork = shared.get_paperwork_requirements(required_form, false)
  local regulated_paperwork = shared.get_paperwork_requirements(required_form, true)
  local regulated_form = (regulated_paperwork[1] and regulated_paperwork[1].name) or required_form

  -- Determine regulated category
  local regulated_cat
  if cat == "crafting" then
    regulated_cat = "crafting-regulated"
  else
    regulated_cat = "advanced-crafting-regulated"
  end

  -- Fluid recipes can never be hand-crafted, so leaving the original on
  -- crafting-with-fluid would orphan it after we repurpose AM2/AM3 onto
  -- regulated categories.
  local above_green = not is_red_science_or_below(name) or cat == "crafting-with-fluid"

  if above_green then
    -------------------------------------------------------------------------
    -- ABOVE GREEN SCIENCE: Regulate original recipe in-place.
    -- No handcrafting possible, so we convert the original directly.
    -- This preserves the recipe's identity (name, tech unlock, usage info)
    -- while showing the correct regulated ingredients/machines.
    -- Keep the recipe visible in the player's crafting UI as unavailable.
    -------------------------------------------------------------------------
    recipe.category = regulated_cat
    regulate_recipe(recipe, regulated_paperwork, multiplier)
    apply_bulk_recipe_icon_overlay(recipe, multiplier, regulated_form)
    recipe.hide_from_player_crafting = false

    -- Inject taxpayer-money for expensive late-game items
    local money_cost = shared.TAXPAYER_MONEY_COSTS[name]
    if money_cost then
      local target = recipe.normal or recipe
      if target.ingredients then
        table.insert(target.ingredients, {type = "item", name = "taxpayer-money", amount = money_cost})
      end
      if recipe.normal and recipe.expensive and recipe.expensive.ingredients then
        table.insert(recipe.expensive.ingredients, {type = "item", name = "taxpayer-money", amount = money_cost})
      end
    end

    -- Tech effects: keep original unlock as-is (recipe name unchanged)
  else
    -------------------------------------------------------------------------
    -- RED SCIENCE OR BELOW: Create separate regulated copy for AMs,
    -- keep original for handcrafting, but point Factoriopedia at the
    -- regulated version so machine info reflects the real automation path.
    -------------------------------------------------------------------------
    local regulated = util.table.deepcopy(recipe)
    regulated.name = name .. "-regulated"
    regulated.localised_name, regulated.localised_description = resolve_regulated_recipe_localisation(recipe, name)
    regulated.hide_from_player_crafting = true
    regulated.hide_from_stats = true
    regulated.category = regulated_cat

    regulate_recipe(regulated, regulated_paperwork, multiplier)
    apply_bulk_recipe_icon_overlay(regulated, multiplier, regulated_form)

    -- Inject taxpayer-money for expensive late-game items
    local money_cost = shared.TAXPAYER_MONEY_COSTS[name]
    if money_cost then
      local target = regulated.normal or regulated
      if target.ingredients then
        table.insert(target.ingredients, {type = "item", name = "taxpayer-money", amount = money_cost})
      end
      if regulated.normal and regulated.expensive and regulated.expensive.ingredients then
        table.insert(regulated.expensive.ingredients, {type = "item", name = "taxpayer-money", amount = money_cost})
      end
    end

    regulated_recipes[regulated.name] = regulated
    prefer_factoriopedia_recipe(recipe, regulated.name)

    -- Modify original for T1+ handcrafting (batch + tier form)
    if not is_t0 then
      batch_original_with_form(recipe, handcraft_paperwork, multiplier)
      apply_bulk_recipe_icon_overlay(recipe, multiplier, required_form)
    end

  end

  ::continue::
end

-- Register all regulated recipes
local regulated_list = {}
for _, regulated in pairs(regulated_recipes) do
  table.insert(regulated_list, regulated)
end
data:extend(regulated_list)

-------------------------------------------------------------------------------
-- 5a2. FALLBACK REGULATION FOR REMAINING CRAFTING RECIPES
-- Some mod recipes are intentionally skipped by the main regulation loop
-- (admin buildings and other admin-detected crafting recipes), but should
-- still be craftable in assembling machines. Any recipe left in vanilla
-- crafting categories gets a batched "-regulated" copy here.
-------------------------------------------------------------------------------
local admin_building_regulated = {}
for recipe_name, recipe in pairs(data.raw["recipe"]) do
  if recipe_name:find("%-regulated$") then goto next_admin_building end

  local cat = recipe.category or "crafting"
  if cat ~= "crafting" and cat ~= "advanced-crafting" then goto next_admin_building end
  if data.raw["recipe"][recipe_name .. "-regulated"] then goto next_admin_building end

  local regulated = util.table.deepcopy(recipe)
  regulated.name = recipe_name .. "-regulated"
  regulated.localised_name, regulated.localised_description = resolve_regulated_recipe_localisation(recipe, recipe_name)
  regulated.hide_from_player_crafting = true
  regulated.hide_from_stats = true
  regulated.category = (cat == "advanced-crafting") and "advanced-crafting-regulated" or "crafting-regulated"

  local multiplier = get_recipe_batch_multiplier(recipe_name, recipe)
  local required_form = shared.get_required_form(recipe_name)
  local regulated_paperwork = shared.get_paperwork_requirements(required_form, true)
  local regulated_form = (regulated_paperwork[1] and regulated_paperwork[1].name) or required_form
  batch_original_with_form(regulated, regulated_paperwork, multiplier)
  apply_bulk_recipe_icon_overlay(regulated, multiplier, regulated_form)

  table.insert(admin_building_regulated, regulated)
  regulated_factoriopedia_products[recipe_name] = true
  prefer_factoriopedia_recipe(recipe, regulated.name)

  ::next_admin_building::
end
data:extend(admin_building_regulated)

-- Demolition products need explicit construction paperwork on top of their
-- normal process permits so cliff clearance and blasting stay on-theme.
for _, recipe_name in ipairs({
  "explosives",
  "explosives-regulated",
  "cliff-explosives",
  "cliff-explosives-regulated",
}) do
  add_special_paperwork(recipe_name, "construction-permit", 1)
end

-- Engine manufacture carries direct emissions, so every batch requires
-- explicit carbon offset paperwork.
for _, recipe_name in ipairs({
  "engine-unit",
  "engine-unit-regulated",
}) do
  add_special_paperwork(recipe_name, "carbon-offset-certificate-basic", 1)
end

-- Higher-energy process recipes should consume the verified certificate tier.
for _, recipe_name in ipairs({
  "electric-engine-unit",
  "electric-engine-unit-regulated",
  "battery",
  "battery-regulated",
  "rocket-fuel",
  "rocket-fuel-regulated",
}) do
  add_special_paperwork(recipe_name, "carbon-offset-certificate-verified", 1)
end

-- Top-tier recipes get explicit environmental compliance on top of their
-- stacked management paperwork.
for recipe_name, recipe in pairs(data.raw["recipe"] or {}) do
  if not shared.is_admin_recipe(recipe_name) and recipe then
    local base_recipe_name = recipe_name:gsub("%-regulated$", "")
    local required_form = shared.get_required_form(base_recipe_name)
    if required_form == "management-approval-written" then
      add_special_paperwork(recipe_name, "environmental-impact-report", 1)
    end
  end
end

-- Cliff charges should stay civilian; remove the hidden military grenade
-- dependency after any recipe cloning/regulation has happened.
remove_ingredient_from_recipe("cliff-explosives", "grenade")
remove_ingredient_from_recipe("cliff-explosives-regulated", "grenade")

for product_name, _ in pairs(regulated_factoriopedia_products) do
  local prototype = find_item_like_prototype(product_name)
  if prototype then
    add_factoriopedia_note(prototype, REGULATED_AM_FACTORIOPEDIA_NOTE)
  end
end

-------------------------------------------------------------------------------
-- 5b. HIDE BURNER MINING DRILL UNTIL REDUNDANT RUBBLE MINED
-- The burner-mining-drill requires construction-permit, which is available
-- from the start, but the drill recipe itself is unlocked by discovery-redundant-rubble.
-------------------------------------------------------------------------------
if data.raw["recipe"]["burner-mining-drill"] then
  data.raw["recipe"]["burner-mining-drill"].enabled = false
end
if data.raw["recipe"]["burner-mining-drill-regulated"] then
  data.raw["recipe"]["burner-mining-drill-regulated"].enabled = false
end

-------------------------------------------------------------------------------
-- 5c. BOILER CARBON OFFSET REQUIREMENT
-- Inject carbon-offset-certificate-basic into the boiler recipe as a special
-- case. This is added after regulation so it applies to both original and
-- regulated versions.
-------------------------------------------------------------------------------
local function inject_carbon_cert_to_boiler(recipe_name)
  local recipe = data.raw["recipe"][recipe_name]
  if not recipe then return end
  local target = recipe.normal or recipe
  if target.ingredients then
    table.insert(target.ingredients, {type = "item", name = "carbon-offset-certificate-basic", amount = 1})
  end
  if recipe.normal and recipe.expensive and recipe.expensive.ingredients then
    table.insert(recipe.expensive.ingredients, {type = "item", name = "carbon-offset-certificate-basic", amount = 1})
  end
end

inject_carbon_cert_to_boiler("boiler")
inject_carbon_cert_to_boiler("boiler-regulated")

-------------------------------------------------------------------------------
-- 5d. SMELTING RECIPE CLEANUP
-- Furnaces should only expose the explicit batch-smelting recipes in
-- smelting-basic. Do not clone vanilla unbatched smelting recipes into that
-- category, or the furnace UI shows duplicate plate/brick options.
-------------------------------------------------------------------------------
-- 6. HANDCRAFTING VISIBILITY EXCEPTIONS
-- Keep late vanilla recipes visible as unavailable, but hide special machine-
-- only/admin helper recipes that just add noise to the character crafting UI.
-------------------------------------------------------------------------------
for name, recipe in pairs(data.raw["recipe"]) do
  local cat = recipe.category or "crafting"

  if name:find("^copy%-") then
    recipe.hide_from_player_crafting = true
  elseif cat == "smelting" then
    recipe.hide_from_player_crafting = true
  end
end

-------------------------------------------------------------------------------
-- 6a. ADMIN RECIPE UI ORDERING
-- Align recipe row/ordering with produced item/fluid so crafting panes remain
-- consistent with handcraft inventory rows.
-------------------------------------------------------------------------------
local ADMIN_RECIPE_UI_EXTRAS = {
  ["paper-production"] = true,
  ["ink-production"] = true,
}

local function recipe_primary_product_name(recipe)
  if not recipe then return nil end

  if recipe.main_product ~= nil and recipe.main_product ~= "" then
    return recipe.main_product
  end

  local level = recipe.normal or recipe
  if level.main_product ~= nil and level.main_product ~= "" then
    return level.main_product
  end

  if recipe.result then return recipe.result end
  if level.result then return level.result end

  local results = level.results or recipe.results
  if results and results[1] then
    return results[1].name or results[1][1]
  end

  return nil
end

local function product_sort_data(product_name)
  if not product_name then return nil end

  local item = find_item_like_prototype(product_name)
  if item then return item end

  return (data.raw.fluid and data.raw.fluid[product_name]) or nil
end

for _, recipe in pairs(data.raw["recipe"] or {}) do
  if shared.is_admin_recipe(recipe.name) or ADMIN_RECIPE_UI_EXTRAS[recipe.name] then
    local needs_subgroup = recipe.subgroup == nil
    local needs_order = recipe.order == nil
    if needs_subgroup or needs_order then
      local product_name = recipe_primary_product_name(recipe)
      local sort_data = product_sort_data(product_name)
      if sort_data then
        if needs_subgroup then
          recipe.subgroup = sort_data.subgroup
        end

        if needs_order then
          local base_order = sort_data.order or product_name or recipe.name
          if recipe.name:find("^copy%-") then
            recipe.order = base_order .. "-y[copy]"
          elseif recipe.name:find("%-regulated$") then
            recipe.order = base_order .. "-z[regulated]"
          else
            recipe.order = base_order
          end
        end
      end
    end
  end
end

-------------------------------------------------------------------------------
-- 7. PNEUMATIC TUBE TRANSPORT
-- Fluid/recipe generation removed — the tube system now uses a script-managed
-- signal chain.  The pneumatic items list lives in shared.PNEUMATIC_ITEMS.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- 8. ADMIN STATION COLLISION FOOTPRINT
-------------------------------------------------------------------------------

local function collision_box_is_zero(box)
  return box
    and box[1] and box[2]
    and box[1][1] == 0 and box[1][2] == 0
    and box[2][1] == 0 and box[2][2] == 0
end

local function normalize_collision_mask(mask)
  if not mask then
    -- Preserve Factorio's default collision layers for ground entities;
    -- without these the entity loses water/object/player collision entirely.
    return {layers = {item = true, object = true, player = true, water_tile = true}}
  end
  if mask.layers then
    mask.layers = mask.layers or {}
    return mask
  end

  local normalized = {layers = {}}
  for key, value in pairs(mask) do
    if key == "not_colliding_with_itself" or key == "consider_tile_transitions" or key == "colliding_with_tiles_only" then
      normalized[key] = value
    elseif type(key) == "number" and type(value) == "string" then
      normalized.layers[value] = true
    elseif type(key) == "string" and value == true then
      normalized.layers[key] = true
    end
  end
  return normalized
end

local function has_excluded_flag(prototype)
  if not prototype.flags then return false end
  for _, flag in ipairs(prototype.flags) do
    if ADMIN_STATION_EXCLUDED_FLAGS[flag] then
      return true
    end
  end
  return false
end

local function should_add_admin_station_layer(prototype)
  if not prototype or ADMIN_STATION_NON_BLOCKING_NAMES[prototype.name] then
    return false
  end
  if ADMIN_STATION_EXCLUDED_TYPES[prototype.type] or has_excluded_flag(prototype) then
    return false
  end
  if not prototype.collision_mask then
    return false
  end
  if not prototype.collision_box or collision_box_is_zero(prototype.collision_box) then
    return false
  end
  return true
end

local function build_standard_module_categories()
  local categories = {}
  for name, _ in pairs(data.raw["module-category"] or {}) do
    if name ~= "night-work" then
      categories[#categories + 1] = name
    end
  end
  table.sort(categories)
  return categories
end

local function copy_array(values)
  local copy = {}
  for index, value in ipairs(values) do
    copy[index] = value
  end
  return copy
end

local STANDARD_MODULE_CATEGORIES = build_standard_module_categories()

for _, prototype_set in pairs(data.raw) do
  for _, prototype in pairs(prototype_set) do
    if should_add_admin_station_layer(prototype) then
      prototype.collision_mask = normalize_collision_mask(prototype.collision_mask)
      prototype.collision_mask.layers[ADMIN_STATION_COLLISION_LAYER] = true
    end

    if prototype and type(prototype.module_slots) == "number" and prototype.module_slots > 0 then
      local categories = copy_array(STANDARD_MODULE_CATEGORIES)
      if WORKING_HOURS_ENABLED and NIGHT_WORK_BUILDINGS[prototype.name] then
        categories[#categories + 1] = "night-work"
      end
      prototype.allowed_module_categories = categories
    end
  end
end
