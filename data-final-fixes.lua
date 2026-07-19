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
--   7. Colored ink gating for planet intermediates
--   8. Pneumatic form transport recipe generation
--   9. Admin station collision footprint layering
--   10. Taxpayer money fuel compatibility
--
-- The regulation system:
--   No fluid ingredient (handcraftable, matches vanilla):
--     Handcrafting -> original recipe (T0: no form, T1+: tier form added)
--     AM1/AM2/AM3 and Factoriopedia -> separate "-regulated" copy
--       (batched, form, consumed)
--   Fluid ingredient (not handcraftable, matches vanilla):
--     Original recipe modified in-place -> regulated category, batched, form
--     Keeps recipe identity and tech unlocks intact

local shared = require("prototypes.shared")
local factoriopedia_merge = require("prototypes.factoriopedia_merge")
local feature_flags = require("feature_flags")
local space_age_planets = feature_flags.space_age_enabled() and require("prototypes.shared.space_age_planets") or nil

-- Quality builds automatic recycling recipes during data-updates, after this
-- mod's data.lua. Reassert the intended lossy paperwork rule at the final stage:
-- every form in a paperwork subgroup recycles to one paper at 25% probability.
if feature_flags.space_age_enabled() then
  require("prototypes.shared.paperwork_recycling").apply()
end

-- The Quality mod owns its native recipes and automatic recycling recipes.
-- Apply the administrative retheme only after every data-updates pass has run.
if feature_flags.quality_enabled() then
  require("prototypes.final_fixes.quality_integration").apply(data)
end

local REGULATED_AM_FACTORIOPEDIA_NOTE = {"administratorio-factoriopedia.regulated-assembling-note"}
local PNEUMATIC_TRANSPORT_NOTE = {
  "",
  {"administratorio-factoriopedia.pneumatic-transport-note-prefix"},
  " ",
  {"item-name.tube-intake"},
  " ([item=tube-intake]).",
}
local TAXPAYER_MONEY_FUEL_CATEGORY = "administratorio-taxpayer-money"
local REGULAR_FUEL_CATEGORY = "chemical"
local HATCHED_PENTAPOD_UNITS = {
  ["small-pentapod-premature"] = true,
  ["medium-pentapod-premature"] = true,
  ["big-pentapod-premature"] = true,
}

local function sync_scrap_recycler_output_slots()
  local recipe = data.raw.recipe and data.raw.recipe["scrap-recycling"]
  local recycler = data.raw.furnace and data.raw.furnace["recycler"]
  if not recipe or not recycler then return end

  local required_slots = 0
  local function count_item_results(target)
    if not target or not target.results then return end
    local slots = 0
    for _, result in ipairs(target.results) do
      if (result.type or "item") == "item" then
        slots = slots + 1
      end
    end
    required_slots = math.max(required_slots, slots)
  end

  count_item_results(recipe)
  count_item_results(recipe.normal)
  count_item_results(recipe.expensive)

  if required_slots > 0 then
    recycler.result_inventory_size = math.max(recycler.result_inventory_size or 0, required_slots)
  end
end

sync_scrap_recycler_output_slots()

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

require("prototypes.final_fixes.military_hiding").apply(data)

-------------------------------------------------------------------------------
-- 2a. BITER SETUP
-------------------------------------------------------------------------------
for _, biter in pairs(data.raw["unit"] or {}) do
  if not HATCHED_PENTAPOD_UNITS[biter.name] then
    if biter.vision_distance then
        biter.vision_distance = 0
        biter.distraction_radius = 0
    end
    -- Biters queuing inside admin station waiting zones must be clickable over
    -- the station (51) and over resources (50).
    biter.selection_priority = 52
  end
end

for _, spawner in pairs(data.raw["unit-spawner"] or {}) do
    spawner.call_for_help_radius = 0
end

local function append_source_effect(action_delivery, effect)
  if not action_delivery then return false end
  if action_delivery[1] then
    local appended = false
    for _, delivery in ipairs(action_delivery) do
      appended = append_source_effect(delivery, effect) or appended
    end
    return appended
  end
  action_delivery.source_effects = action_delivery.source_effects or {}
  action_delivery.source_effects[#action_delivery.source_effects + 1] = effect
  return true
end

local pentapod_egg = data.raw.item and data.raw.item["pentapod-egg"]
local egg_spoil_trigger = pentapod_egg
  and pentapod_egg.spoil_to_trigger_result
  and pentapod_egg.spoil_to_trigger_result.trigger
if egg_spoil_trigger and egg_spoil_trigger.action_delivery then
  append_source_effect(egg_spoil_trigger.action_delivery, {
    type = "script",
    effect_id = "administratorio-pentapod-egg-hatch",
  })
end

-------------------------------------------------------------------------------
-- 2b. TAXPAYER MONEY FUEL SETUP
-- Taxpayer money keeps its dedicated fuel category so the rideable biter can
-- reject ordinary fuel, while regular chemical burners also accept it.
-------------------------------------------------------------------------------
local function fuel_category_list_has(categories, category_name)
  if not categories then return false end
  for _, fuel_category in ipairs(categories) do
    if fuel_category == category_name then
      return true
    end
  end
  return false
end

local function burner_accepts_regular_fuel(energy_source)
  if not energy_source or energy_source.type ~= "burner" then return false end

  if energy_source.fuel_categories then
    return fuel_category_list_has(energy_source.fuel_categories, REGULAR_FUEL_CATEGORY)
  end

  return (energy_source.fuel_category or REGULAR_FUEL_CATEGORY) == REGULAR_FUEL_CATEGORY
end

local function add_taxpayer_money_fuel_category(energy_source)
  if not burner_accepts_regular_fuel(energy_source) then return end

  local categories = {}
  if energy_source.fuel_categories then
    for _, fuel_category in ipairs(energy_source.fuel_categories) do
      categories[#categories + 1] = fuel_category
    end
  else
    categories[#categories + 1] = energy_source.fuel_category or REGULAR_FUEL_CATEGORY
  end

  if not fuel_category_list_has(categories, TAXPAYER_MONEY_FUEL_CATEGORY) then
    categories[#categories + 1] = TAXPAYER_MONEY_FUEL_CATEGORY
  end

  energy_source.fuel_categories = categories
  energy_source.fuel_category = nil
end

for _, prototypes in pairs(data.raw or {}) do
  if type(prototypes) == "table" then
    for _, prototype in pairs(prototypes) do
      if type(prototype) == "table" then
        add_taxpayer_money_fuel_category(prototype.energy_source)
      end
    end
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
  local am3 = data.raw["assembling-machine"]["assembling-machine-3"]
  am3.crafting_categories = {"crafting-regulated", "advanced-crafting-regulated"}
  am3.ingredient_count = 12
end

-------------------------------------------------------------------------------
-- 4. MACHINE-FAMILY OPERATING PAPERWORK
-------------------------------------------------------------------------------
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

  local ing_type = ingredient_type(ingredient)
  for _, existing in ipairs(ingredients) do
    if ingredient_name(existing) == name and ingredient_type(existing) == ing_type then
      set_ingredient_amount(existing, ingredient_amount(existing) + ingredient_amount(ingredient))
      return
    end
  end

  ingredients[#ingredients + 1] = ingredient
end

local function normalized_ingredient_list(ingredients)
  local normalized = {}
  for _, ingredient in ipairs(ingredients or {}) do
    append_or_merge_ingredient(normalized, util.table.deepcopy(ingredient))
  end
  return normalized
end

local function add_ingredient_to_target(target, item_name, count)
  if not target or not target.ingredients then return end

  local ingredients = normalized_ingredient_list(target.ingredients)
  append_or_merge_ingredient(ingredients, {type = "item", name = item_name, amount = count})
  target.ingredients = ingredients
end

local function ensure_ingredient_in_target(target, item_name, count)
  if not target or not target.ingredients then return end

  local ingredients = normalized_ingredient_list(target.ingredients)
  for _, ingredient in ipairs(ingredients) do
    if ingredient_name(ingredient) == item_name and ingredient_type(ingredient) == "item" then
      target.ingredients = ingredients
      return
    end
  end

  append_or_merge_ingredient(ingredients, {type = "item", name = item_name, amount = count})
  target.ingredients = ingredients
end

local function add_ingredient_to_recipe(recipe_name, item_name, count)
  local recipe = data.raw["recipe"][recipe_name]
  if not recipe then return end

  if recipe.ingredients then
    add_ingredient_to_target(recipe, item_name, count)
  elseif recipe.normal and recipe.normal.ingredients then
    add_ingredient_to_target(recipe.normal, item_name, count)
    if recipe.expensive and recipe.expensive.ingredients then
      add_ingredient_to_target(recipe.expensive, item_name, count)
    end
  end
end

local function add_special_paperwork(recipe_name, item_name, count)
  local recipe = data.raw["recipe"][recipe_name]
  if not recipe then return end

  if recipe.ingredients then
    ensure_ingredient_in_target(recipe, item_name, count)
  elseif recipe.normal and recipe.normal.ingredients then
    ensure_ingredient_in_target(recipe.normal, item_name, count)
    if recipe.expensive and recipe.expensive.ingredients then
      ensure_ingredient_in_target(recipe.expensive, item_name, count)
    end
  end
end

local function remove_ingredient_from_recipe(recipe_name, item_name)
  local recipe = data.raw["recipe"][recipe_name]
  if not recipe then return end

  local function strip_ingredient(target)
    if not target or not target.ingredients then return end

    local filtered = {}
    for _, ingredient in ipairs(target.ingredients) do
      if ingredient_name(ingredient) ~= item_name then
        append_or_merge_ingredient(filtered, util.table.deepcopy(ingredient))
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

-- This alternate recipe is declared before the canonical batch receives the
-- product's name. Link it only after the rename succeeds so Factorio never sees
-- a dangling RecipeID during prototype validation.
local compacted_rubble_electric = data.raw.recipe["compacted-rubble-electric"]
if compacted_rubble_electric then
  compacted_rubble_electric.factoriopedia_alternative =
    data.raw.recipe["compacted-rubble"] and "compacted-rubble" or nil
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
  "space-platform-starter-pack",
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

  -- Space-platform processing is deliberately one craft at a time.  Some
  -- space recipes produce ordinary intermediate items, so checking only the
  -- result item's subgroup would let them inherit the normal 5x batch badge.
  -- The Space Age recipe subgroups use the `space-` prefix; keeping that whole
  -- family unbatched also covers compatible space-platform recipes.
  if recipe.subgroup and recipe.subgroup:sub(1, 6) == "space-" then
    return 1
  end

  for _, res in ipairs(results) do
    local res_name = res.name or res[1]
    if res_name then
      local prototype = find_item_like_prototype(res_name)
      if shared.UNBATCHED_RESULT_NAMES[res_name] then
        return 1
      end
      if prototype and shared.UNBATCHED_RESULT_SUBGROUPS[prototype.subgroup] then
        return 1
      end
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

local function apply_bulk_recipe_icon_overlay(recipe, multiplier)
  if not recipe then return end

  local _, product_type = get_primary_result_name_and_type(recipe)
  if product_type == "fluid" then return end

  local icons = get_recipe_base_icons(recipe)
  if not icons then return end

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
local function regulate_recipe(recipe, paperwork_requirements, multiplier, options)
  if not recipe then return end
  options = options or {}
  paperwork_requirements = normalize_paperwork_requirements(paperwork_requirements)

  local function process_level(target)
    if not target then return end

    -- Multiply base craft time
    if target.energy_required then
      target.energy_required = target.energy_required * multiplier
    else
      target.energy_required = 0.5 * multiplier
    end

    -- Process ingredients: strip old paperwork, multiply base, add paperwork.
    -- Build a fresh ingredient list so compatibility recipes that alias vanilla
    -- ingredient tables do not mutate each other.
    if target.ingredients then
      local clean_ingredients = {}
      local retained_paperwork = {}
      local has_retained_paperwork = false
      for _, ing in ipairs(target.ingredients) do
        local name = ingredient_name(ing)
        if shared.PAPERWORK_ITEMS[name] and options.preserve_existing_paperwork then
          local resolved_name = shared.COMBINED_FORMS[name] or name
          append_or_merge_ingredient(retained_paperwork, {
            type = "item",
            name = resolved_name,
            amount = ingredient_amount(ing),
          })
          has_retained_paperwork = true
        elseif not shared.PAPERWORK_ITEMS[name] then
          local new_ing = util.table.deepcopy(ing)
          set_ingredient_amount(new_ing, ingredient_amount(new_ing) * multiplier)
          append_or_merge_ingredient(clean_ingredients, new_ing)
        end
      end
      target.ingredients = clean_ingredients

      if options.preserve_existing_paperwork and not has_retained_paperwork
          and options.fallback_paperwork then
        for _, paperwork in ipairs(options.fallback_paperwork()) do
          append_or_merge_ingredient(target.ingredients, {
            type = "item",
            name = paperwork.name,
            amount = paperwork.amount,
          })
        end
      end

      for _, paperwork in ipairs(retained_paperwork) do
        append_or_merge_ingredient(target.ingredients, paperwork)
      end

      -- Paperwork per batch is fixed and never multiplied.
      for _, paperwork in ipairs(paperwork_requirements) do
        append_or_merge_ingredient(target.ingredients, {type = "item", name = paperwork.name, amount = paperwork.amount})
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

    -- Multiply ingredients, strip any pre-existing paperwork, then add the
    -- controlled paperwork cost. Some compatibility mods reuse vanilla
    -- ingredient tables by reference, so assign a fresh list instead of
    -- editing the shared table in place.
    if target.ingredients then
      local clean_ingredients = {}
      for _, ing in ipairs(target.ingredients) do
        local name = ingredient_name(ing)
        if not shared.PAPERWORK_ITEMS[name] then
          local new_ing = util.table.deepcopy(ing)
          set_ingredient_amount(new_ing, ingredient_amount(new_ing) * multiplier)
          append_or_merge_ingredient(clean_ingredients, new_ing)
        end
      end
      target.ingredients = clean_ingredients

      for _, paperwork in ipairs(paperwork_requirements) do
        append_or_merge_ingredient(target.ingredients, {type = "item", name = paperwork.name, amount = paperwork.amount})
      end
    end

    -- Multiply results
    if target.results then
      local results = {}
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
      target.results = results
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
  apply_bulk_recipe_icon_overlay(recipe, multiplier)

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

  -- Determine regulated category
  local regulated_cat
  if cat == "crafting" then
    regulated_cat = "crafting-regulated"
  else
    regulated_cat = "advanced-crafting-regulated"
  end

  -- Fluid recipes can never be hand-crafted (matches vanilla: the character
  -- has no "crafting-with-fluid" category), so leaving the original on that
  -- category would orphan it after we repurpose AM2/AM3 onto regulated
  -- categories. Every other vanilla-handcraftable recipe stays handcraftable
  -- here, regardless of tech tier.
  local fluid_only = (cat == "crafting-with-fluid")

  if fluid_only then
    -------------------------------------------------------------------------
    -- FLUID INGREDIENT: Regulate original recipe in-place.
    -- No handcrafting possible (not even in vanilla), so we convert the
    -- original directly. This preserves the recipe's identity (name, tech
    -- unlock, usage info) while showing the correct regulated
    -- ingredients/machines. Keep the recipe visible in the player's
    -- crafting UI as unavailable.
    -------------------------------------------------------------------------
    recipe.category = regulated_cat
    regulate_recipe(recipe, regulated_paperwork, multiplier)
    apply_bulk_recipe_icon_overlay(recipe, multiplier)
    recipe.hide_from_player_crafting = false

    -- Inject taxpayer-money for expensive late-game items
    local money_cost = shared.TAXPAYER_MONEY_COSTS[name]
    if money_cost then
      local target = recipe.normal or recipe
      add_ingredient_to_target(target, "taxpayer-money", money_cost)
      if recipe.normal and recipe.expensive and recipe.expensive.ingredients then
        add_ingredient_to_target(recipe.expensive, "taxpayer-money", money_cost)
      end
    end

    -- Tech effects: keep original unlock as-is (recipe name unchanged)
  else
    -------------------------------------------------------------------------
    -- NO FLUID INGREDIENT: Create separate regulated copy for AMs,
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
    apply_bulk_recipe_icon_overlay(regulated, multiplier)

    -- Inject taxpayer-money for expensive late-game items
    local money_cost = shared.TAXPAYER_MONEY_COSTS[name]
    if money_cost then
      local target = regulated.normal or regulated
      add_ingredient_to_target(target, "taxpayer-money", money_cost)
      if regulated.normal and regulated.expensive and regulated.expensive.ingredients then
        add_ingredient_to_target(regulated.expensive, "taxpayer-money", money_cost)
      end
    end

    regulated_recipes[regulated.name] = regulated
    prefer_factoriopedia_recipe(recipe, regulated.name)

    -- Modify original for T1+ handcrafting (batch + tier form)
    if not is_t0 then
      batch_original_with_form(recipe, handcraft_paperwork, multiplier)
      apply_bulk_recipe_icon_overlay(recipe, multiplier)
    end

  end

  ::continue::
end

-------------------------------------------------------------------------------
-- OIL-PROCESSING BULKING
-- Oil refineries are biter-station-managed — each dispatched worker only
-- authorizes one craft cycle. Vanilla refinery recipe sizes would make
-- refineries craft absurdly fast under that model, so we bulk every
-- oil-processing recipe 5x (same multiplier as the regulated economy).
-- No operating paperwork is added — biter-station dispatch is the gate.
-------------------------------------------------------------------------------
local OIL_REFINERY_BULK_MULTIPLIER = 5
for name, recipe in pairs(data.raw["recipe"]) do
  if shared.is_admin_recipe(name) or shared.ADMIN_BUILDINGS[name]
     or FORM_PRODUCTION_RECIPE_SET[name] then
    goto oil_continue
  end

  local cat = recipe.category or "crafting"
  if cat ~= "oil-processing" then goto oil_continue end

  regulate_recipe(recipe, {}, OIL_REFINERY_BULK_MULTIPLIER)
  apply_bulk_recipe_icon_overlay(recipe, OIL_REFINERY_BULK_MULTIPLIER)

  ::oil_continue::
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
--
-- Paperwork handling for admin building regulated copies:
--   - Tier forms (construction-permit, safety-waiver, etc.) are replaced
--     by their combined equivalents (construction-work-order, etc.).
--   - All other paperwork items (combined forms, treasury-bond, …) are
--     kept as fixed costs and NOT multiplied.
--   - Regular material ingredients are multiplied by the batch multiplier.
-------------------------------------------------------------------------------

local function regulate_admin_building(recipe, multiplier, recipe_name)
  regulate_recipe(recipe, {}, multiplier, {
    preserve_existing_paperwork = true,
    fallback_paperwork = function()
      return shared.get_paperwork_requirements(shared.get_required_form(recipe_name), true)
    end,
  })
end

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
  regulate_admin_building(regulated, multiplier, recipe_name)
  apply_bulk_recipe_icon_overlay(regulated, multiplier)

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
-- stacked management paperwork. Beacon and rocket-silo are excluded because
-- they already push ingredient counts close to the AM3 limit.
local env_report_exceptions = { ["beacon"] = true, ["rocket-silo"] = true }
for recipe_name, recipe in pairs(data.raw["recipe"] or {}) do
  if not shared.is_admin_recipe(recipe_name) and recipe then
    local base_recipe_name = recipe_name:gsub("%-regulated$", "")
    local required_form = shared.get_required_form(base_recipe_name)
    if required_form == "management-approval-written" and not env_report_exceptions[base_recipe_name] then
      add_special_paperwork(recipe_name, "environmental-impact-report", 1)
    end
  end
end
add_special_paperwork("beacon", "treasury-bond", 1)
-- One grant represents 500 taxpayer-money through the bond/grant chain. The
-- silo consumes financed public works rather than loose currency, making the
-- derivative the efficient interplanetary export.
add_special_paperwork("rocket-silo", "government-grant", 1)

-- Space-platform asteroid cracking should also consume explicit orbital
-- processing paperwork instead of running as a free crusher side loop.
for recipe_name, recipe in pairs(data.raw["recipe"] or {}) do
  if recipe
    and not shared.is_admin_recipe(recipe_name)
    and recipe_name:find("asteroid")
    and (recipe_name:find("crushing") or recipe_name:find("processing") or recipe_name:find("reprocessing"))
  then
    add_special_paperwork(recipe_name, "asteroid-processing-docket", 1)
  end
end

-- Cliff charges should stay civilian; remove the hidden military grenade
-- dependency after any recipe cloning/regulation has happened.
remove_ingredient_from_recipe("cliff-explosives", "grenade")
remove_ingredient_from_recipe("cliff-explosives-regulated", "grenade")

-- Specialist workers for vanilla industrial buildings. Oil refineries are
-- intentionally absent: refinery construction and operation are gated by
-- regulated assembler paperwork plus biter-station dispatch, not specialists.
local specialist_buildings = {
  ["chemical-plant"] = {name = "chemical-operator", amount = 1},
  ["nuclear-reactor"] = {name = "nuclear-technician", amount = 2},
  ["centrifuge"] = {name = "nuclear-technician", amount = 1},
}
for building_name, specialist in pairs(specialist_buildings) do
  add_special_paperwork(building_name, specialist.name, specialist.amount)
  add_special_paperwork(building_name .. "-regulated", specialist.name, specialist.amount)
end

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
  add_special_paperwork(recipe_name, "carbon-offset-certificate-basic", 1)
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

-- 7. COLORED INK GATING FOR PLANET INTERMEDIATES
-- Any recipe that consumes a Space Age planet-specific intermediate must also
-- consume the corresponding colored ink form. This makes planet ink production
-- essential for late-game manufacturing everywhere. Once Aquilo is online,
-- multi-planet recipes are consolidated into composite paperwork instead of
-- stacking multiple raw CMY forms independently.
-- One form per batch (not multiplied), added after regulation.
-------------------------------------------------------------------------------
require("prototypes.final_fixes.colored_ink_gating").apply(
  data,
  shared,
  remove_ingredient_from_recipe,
  add_special_paperwork
)

-------------------------------------------------------------------------------
-- 7b. SPACE-PLATFORM BUILDING PERMITS
-- Platform buildings consume exactly one orbital infrastructure permit as
-- their sole paperwork ingredient. Run this after every general/special gate
-- so construction, management, chromatic, or compatibility paperwork cannot
-- leak back into either the canonical or regulated recipe.
-------------------------------------------------------------------------------
require("prototypes.final_fixes.space_platform_permits").apply(data, shared, ITEM_LIKE_PROTOTYPE_TYPES, {
  ingredient_name = ingredient_name,
  append_or_merge_ingredient = append_or_merge_ingredient,
})

-------------------------------------------------------------------------------
-- 8. PNEUMATIC TUBE TRANSPORT
-- Fluid/recipe generation removed — the tube system now uses a script-managed
-- signal chain.  The pneumatic items list lives in shared.PNEUMATIC_ITEMS.
-------------------------------------------------------------------------------

local function append_item_description_note(item, note)
  if not item or not note then return end
  local base = item.localised_description or {"item-description." .. item.name}
  item.localised_description = {"", base, "\n\n", note}
end

for item_name in pairs(shared.PNEUMATIC_ITEMS) do
  local item = data.raw.item[item_name]
  if item then
    append_item_description_note(item, PNEUMATIC_TRANSPORT_NOTE)
  end
end


-------------------------------------------------------------------------------
-- 9. ADMIN STATION COLLISION FOOTPRINT
-------------------------------------------------------------------------------
require("prototypes.final_fixes.collision_masks").apply(data, feature_flags.working_hours_enabled())

-------------------------------------------------------------------------------
-- 8b. BITERPORT ITEM PLACE_RESULT FALLBACK
-- biterport-placement-preview is only created when the base roboport prototype
-- exists. If it wasn't registered, fall back to the real container so the item
-- doesn't cause an assignID error on load.
-------------------------------------------------------------------------------
local biterport_item = data.raw["item"]["biterport"]
if biterport_item and not (data.raw["roboport"] and data.raw["roboport"]["biterport-placement-preview"]) then
  biterport_item.place_result = "biterport"
end

-------------------------------------------------------------------------------
-- 10. RIDEABLE BITER SOUND OVERRIDE
-- Force biter sounds onto the rideable-biter car last, after all mods run.
-- The car type defaults to engine sounds; this must be set in final-fixes
-- to guarantee it survives any data-stage ordering issues.
-------------------------------------------------------------------------------
local rideable = data.raw["car"] and data.raw["car"]["rideable-biter"]
if rideable then
  if rideable.energy_source then
    rideable.energy_source.fuel_categories = {TAXPAYER_MONEY_FUEL_CATEGORY}
    rideable.energy_source.fuel_category = nil
    rideable.energy_source.fuel_inventory_size = 1
  end
  rideable.working_sound = nil
  rideable.stop_trigger = nil
  rideable.stop_trigger_speed = nil
  rideable.sound_no_fuel = nil
  rideable.open_sound = nil
  rideable.close_sound = nil
  rideable.track_particle_triggers = nil
  rideable.vehicle_impact_sound = nil
  rideable.crash_trigger = nil
  rideable.mined_sound = nil
  rideable.dying_sound = nil
  -- Factorio 2.x candidates
  rideable.rolling_sound = nil
  rideable.idle_sound = nil
  rideable.starting_sound = nil
  rideable.engine_sound = nil
end

-------------------------------------------------------------------------------
-- 11. SHARED ROCKET-SILO AUTHORIZATION
-- Space Age planets use the same physical silo and the same administrative
-- recipe. Public finance travels as grants rather than loose taxpayer money;
-- Aquilo remains import-dependent because it cannot produce every input.
-------------------------------------------------------------------------------
if space_age_planets and data.raw.recipe and data.raw.recipe["rocket-silo"] then
  local canonical = data.raw.recipe["rocket-silo"]
  local replaceable_admin_ingredients = {
    ["government-grant"] = true,
    ["management-approval-written"] = true,
    ["management-written-work-order"] = true,
    ["construction-work-order"] = true,
    ["environmental-impact-report"] = true,
    ["taxpayer-money"] = true,
  }

  local function replace_admin_cost(recipe, additions)
    local filtered = {}
    for _, ingredient in ipairs(recipe.ingredients or {}) do
      local name = ingredient.name or ingredient[1]
      if not replaceable_admin_ingredients[name] then filtered[#filtered + 1] = ingredient end
    end
    for _, ingredient in ipairs(additions) do filtered[#filtered + 1] = ingredient end
    recipe.ingredients = filtered
  end

  replace_admin_cost(canonical, {
    {type = "item", name = "government-grant", amount = 1},
    {type = "item", name = "management-approval-written", amount = 1},
  })
  canonical.surface_conditions = nil

  -- Taxpayer money is generated, securitized, and allocated on Nauvis. Off-world
  -- finance arrives as a finished grant, never from minting money, bonds, or
  -- grants on another planet.
  for _, source_recipe_name in ipairs({"treasury-bond-production", "government-grant-production", "tax-audit"}) do
    local recipe_name = factoriopedia_recipe_renames[source_recipe_name] or source_recipe_name
    space_age_planets.apply_planet_surface_conditions(data.raw.recipe[recipe_name], "nauvis")
  end
end

-------------------------------------------------------------------------------
-- 12. SCIENCE PACKS ARE RESEARCH-ONLY
-- Science packs belong in technology unit ingredients, never crafting recipe
-- ingredients. Discover them from loaded item prototypes so vanilla, Space
-- Age, Administratorio, and compatibility-mod packs all obey the same rule.
-- This runs last to prevent any earlier recipe mutation from reintroducing one.
-------------------------------------------------------------------------------
require("prototypes.final_fixes.science_pack_stripping").apply(data, ITEM_LIKE_PROTOTYPE_TYPES)

-------------------------------------------------------------------------------
-- 13. ROCKET CARGO WEIGHTS
-- Apply after every item-producing integration has finished so all mod-owned
-- cargo, including Space Age tourism items and generated forms, is covered.
-------------------------------------------------------------------------------
require("prototypes.final_fixes.rocket_weights").apply()
