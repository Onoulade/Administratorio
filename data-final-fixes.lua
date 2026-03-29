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
local NIGHT_WORK_BUILDINGS = {
  ["office-desk"] = true,
  ["corporate-breakroom"] = true,
  ["meeting-room"] = true,
  ["union-headquarters"] = true,
}

local ADMIN_STATION_NON_BLOCKING_NAMES = {
  ["admin-station-combinator"] = true,
  ["waiting-zone-marker"] = true,
  ["transit-permit-chest"] = true,
  ["pneumatic-hidden-intake"] = true,
  ["pneumatic-hidden-outtake"] = true,
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
  ["artillery-wagon"] = true,
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
    local operating_form = shared.OPERATING_FORM_BY_CATEGORY[cat]
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

-- Demolition products need explicit construction paperwork on top of their
-- normal process permits so cliff clearance and blasting stay on-theme.
for _, recipe_name in ipairs({"explosives", "cliff-explosives"}) do
  add_special_paperwork(recipe_name, "construction-permit", 1)
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

local function get_max_stack_size(item_name)
  for _, item_type in ipairs({"item", "ammo", "gun", "armor", "capsule", "tool", "selection-tool", "item-with-entity-data"}) do
    if data.raw[item_type] and data.raw[item_type][item_name] then
      return data.raw[item_type][item_name].stack_size or 1
    end
  end
  return 100
end

local function find_item_like_prototype(name)
  for _, item_type in ipairs({"item", "ammo", "gun", "armor", "capsule", "tool", "selection-tool", "item-with-entity-data", "rail-planner", "spidertron-remote"}) do
    if data.raw[item_type] and data.raw[item_type][name] then
      return data.raw[item_type][name]
    end
  end
  return nil
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

local function resolve_regulated_recipe_localisation(recipe, recipe_name)
  if recipe.localised_name and recipe.localised_description then
    return recipe.localised_name, recipe.localised_description
  end

  local product_name, product_type = get_primary_result_name_and_type(recipe)
  local localised_name = recipe.localised_name
  local localised_description = recipe.localised_description

  if product_name and product_type == "item" then
    local prototype = find_item_like_prototype(product_name)
    localised_name = localised_name or (prototype and prototype.localised_name) or {"item-name." .. product_name}
    localised_description = localised_description or (prototype and prototype.localised_description) or {"item-description." .. product_name}
  elseif product_name and product_type == "fluid" then
    local prototype = data.raw["fluid"] and data.raw["fluid"][product_name]
    localised_name = localised_name or (prototype and prototype.localised_name) or {"fluid-name." .. product_name}
    localised_description = localised_description or (prototype and prototype.localised_description) or {"fluid-description." .. product_name}
  else
    localised_name = localised_name or {"recipe-name." .. recipe_name}
  end

  return localised_name, localised_description
end

-- Create a batched copy of a recipe with a form requirement.
-- The form is always consumed (no return).
local function regulate_recipe(recipe, form_name, multiplier)
  if not recipe then return end

  local function process_level(target)
    if not target then return end

    -- Multiply base craft time
    if target.energy_required then
      target.energy_required = target.energy_required * multiplier
    else
      target.energy_required = 0.5 * multiplier
    end

    -- Process ingredients: strip old paperwork, multiply base, add form
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

      -- 1 form per batch (never multiplied)
      table.insert(target.ingredients, {type = "item", name = form_name, amount = 1})
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

-- Batch the original recipe and add a form ingredient (for handcrafting T1+ items).
-- Same batch multiplier as AM recipes so form cost per item is consistent.
-- Form is consumed (no return/expiration for handcrafting).
local function batch_original_with_form(recipe, form_name, multiplier)
  local function process_level(target)
    if not target then return end

    -- Multiply craft time
    if target.energy_required then
      target.energy_required = target.energy_required * multiplier
    else
      target.energy_required = 0.5 * multiplier
    end

    -- Multiply ingredients, add form
    if target.ingredients then
      for _, ing in ipairs(target.ingredients) do
        if ing.amount then
          ing.amount = ing.amount * multiplier
        else
          ing[2] = ing[2] * multiplier
        end
      end
      table.insert(target.ingredients, {type = "item", name = form_name, amount = 1})
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
  local multiplier = shared.BATCH_MULTIPLIERS[name] or shared.BATCH_MULTIPLIER_DEFAULT
  local r_proto = recipe.normal or recipe
  local results = r_proto.results or (r_proto.result and {{name = r_proto.result}}) or {}
  local primary_result_name = get_primary_item_like_result_name(recipe)
  if primary_result_name then
    regulated_factoriopedia_products[primary_result_name] = true
  end
  for _, res in ipairs(results) do
    local res_name = res.name or res[1]
    if res_name and get_max_stack_size(res_name) == 1 then
      multiplier = 1
      break
    end
  end

  -- Determine which form is required based on item tier
  local required_form = shared.get_required_form(name)
  local is_t0 = (required_form == "work-order")

  -- Determine the form for regulated recipe
  local regulated_form
  if is_t0 then
    regulated_form = "work-order"
  else
    regulated_form = shared.COMBINED_FORMS[required_form] or required_form
  end

  -- Determine regulated category
  local regulated_cat
  if cat == "crafting" then
    regulated_cat = "crafting-regulated"
  else
    regulated_cat = "advanced-crafting-regulated"
  end

  local above_green = not is_red_science_or_below(name)

  if above_green then
    -------------------------------------------------------------------------
    -- ABOVE GREEN SCIENCE: Regulate original recipe in-place.
    -- No handcrafting possible, so we convert the original directly.
    -- This preserves the recipe's identity (name, tech unlock, usage info)
    -- while showing the correct regulated ingredients/machines.
    -- Keep the recipe visible in the player's crafting UI as unavailable.
    -------------------------------------------------------------------------
    recipe.category = regulated_cat
    regulate_recipe(recipe, regulated_form, multiplier)
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

    regulate_recipe(regulated, regulated_form, multiplier)

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
      batch_original_with_form(recipe, required_form, multiplier)
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
-- crafting categories gets a "-regulated" copy here.
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

  -- Add work-order as ingredient (1 per craft, consistent with T0 regulation)
  local target = regulated.normal or regulated
  if target.ingredients then
    table.insert(target.ingredients, {type = "item", name = "work-order", amount = 1})
  end
  if regulated.normal and regulated.expensive and regulated.expensive.ingredients then
    table.insert(regulated.expensive.ingredients, {type = "item", name = "work-order", amount = 1})
  end

  table.insert(admin_building_regulated, regulated)
  regulated_factoriopedia_products[recipe_name] = true
  prefer_factoriopedia_recipe(recipe, regulated.name)

  ::next_admin_building::
end
data:extend(admin_building_regulated)

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
-- 5d. CERTIFIED STEEL FURNACE SMELTING
-- Steel furnaces run the certificate-gated smelting-basic category. Clone each
-- vanilla smelting recipe into a certified variant so steel furnaces can keep
-- using standard plate/brick recipes without sharing the electric-furnace path.
-------------------------------------------------------------------------------
local certified_smelting_recipes = {}

local function recipe_has_ingredient(recipe, item_name)
  if not recipe or not recipe.ingredients then return false end
  for _, ingredient in ipairs(recipe.ingredients) do
    if (ingredient.name or ingredient[1]) == item_name then
      return true
    end
  end
  return false
end

for name, recipe in pairs(data.raw["recipe"]) do
  if recipe.category == "smelting" and not name:find("%-certified$") then
    local certified = table.deepcopy(recipe)
    certified.name = name .. "-certified"
    certified.category = "smelting-basic"
    certified.localised_name = recipe.localised_name or {"recipe-name." .. name}
    certified.localised_description = recipe.localised_description or {"recipe-description." .. name}
    certified.hide_from_player_crafting = true
    certified.allow_as_intermediate = false
    certified.allow_decomposition = false

    local target = certified.normal or certified
    if target.ingredients and not recipe_has_ingredient(target, "carbon-offset-certificate-basic") then
      table.insert(target.ingredients, {type = "item", name = "carbon-offset-certificate-basic", amount = 1})
    end

    if certified.normal and certified.expensive and certified.expensive.ingredients
      and not recipe_has_ingredient(certified.expensive, "carbon-offset-certificate-basic") then
      table.insert(certified.expensive.ingredients, {type = "item", name = "carbon-offset-certificate-basic", amount = 1})
    end

    certified_smelting_recipes[#certified_smelting_recipes + 1] = certified
  end
end

data:extend(certified_smelting_recipes)

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
-- 7. PNEUMATIC FORM TRANSPORT — FLUID & RECIPE GENERATION
-- Auto-generates a fluid + liquify/solidify recipe pair for every paperwork item.
-- These fluids flow through pneumatic pipes (connection_category = "pneumatic-forms")
-- and cannot mix with regular fluid pipes.
-------------------------------------------------------------------------------

local PNEUMATIC_BATCH = 1
local PNEUMATIC_FLUID_PER = 10

-- All paperwork items from shared, plus complaint pipeline items
local pneumatic_items = {}
for name, _ in pairs(shared.PAPERWORK_ITEMS) do
  pneumatic_items[name] = true
end

-- Add complaint pipeline items
local extra_pneumatic = {
  "paper", "ink", "blank-form", "blank-approval", "blank-directive",
  "safety-waiver-draft", "construction-permit-draft",
  "management-verbal-draft", "management-written-proposal", "management-written-review",
  "ticket-landscape", "ticket-smog", "ticket-noise", "ticket-unemployment",
  "ticket-littering", "ticket-hazmat", "ticket-loitering", "ticket-vagrancy",
  "filing-l", "filing-s", "filing-n", "filing-u",
  "filing-lt", "filing-h", "filing-lo", "filing-v",
  "case-s", "case-n", "case-u",
  "case-h", "case-lo", "case-v",
  "brief-n", "brief-u",
  "brief-lo", "brief-v",
  "resolved-landscape", "resolved-smog", "resolved-noise", "resolved-unemployment",
  "resolved-littering", "resolved-hazmat", "resolved-loitering", "resolved-vagrancy",
  "osha-violation",
  "dubious-data", "basic-excuse", "crappy-report", "credentials", "data",
  "good-excuse", "justification", "narrative", "policy", "regulation",
  "white-paper", "administrative-science-pack",
  "watercooler-gossip", "office-drama",
  "taxpayer-money",
  "useless-documentation", "compacted-rubble", "refined-nonsense",
}
for _, name in ipairs(extra_pneumatic) do
  pneumatic_items[name] = true
end

local pneumatic_fluids = {}
local pneumatic_recipes = {}

for item_name, _ in pairs(pneumatic_items) do
  -- Find the item in any item-type table
  local item_data = nil
  for _, item_type in ipairs({"item", "tool", "module", "capsule"}) do
    if data.raw[item_type] and data.raw[item_type][item_name] then
      item_data = data.raw[item_type][item_name]
      break
    end
  end
  if not item_data then goto next_pneumatic end

  local fluid_name = "pneumatic-" .. item_name
  local batch = PNEUMATIC_BATCH
  if item_data.stack_size and batch > item_data.stack_size then
    batch = item_data.stack_size
  end
  if batch < 1 then batch = 1 end

  -- Create the pneumatic fluid
  local fluid_icon = item_data.icon or "__administratorio__/graphics/icons/blank-form.png"
  local fluid_icon_size = item_data.icon_size or 64
  local fluid_icons = nil
  if item_data.icons then
    fluid_icons = table.deepcopy(item_data.icons)
  else
    fluid_icons = {{icon = fluid_icon, icon_size = fluid_icon_size}}
  end

  table.insert(pneumatic_fluids, {
    type = "fluid",
    name = fluid_name,
    icons = fluid_icons,
    localised_name = {"fluid-name.pneumatic-form-fluid", item_data.localised_name or {"item-name." .. item_name}},
    default_temperature = 15,
    base_color = {r = 0.85, g = 0.75, b = 0.55},
    flow_color = {r = 0.95, g = 0.9, b = 0.75},
    subgroup = item_data.subgroup,
    order = item_data.order,
    auto_barrel = false,
    hidden_in_factoriopedia = true,
  })

  -- Create liquify recipe (item -> fluid)
  table.insert(pneumatic_recipes, {
    type = "recipe",
    name = "pneumatic-liquify-" .. item_name,
    energy_required = 0.4,
    enabled = true,
    hide_from_player_crafting = true,
    hide_from_stats = true,
    hidden_in_factoriopedia = true,
    ingredients = {{type = "item", name = item_name, amount = batch}},
    results = {{type = "fluid", name = fluid_name, amount = batch * PNEUMATIC_FLUID_PER}},
    category = "pneumatic-liquify",
    overload_multiplier = 2,
  })

  -- Create solidify recipe (fluid -> item)
  table.insert(pneumatic_recipes, {
    type = "recipe",
    name = "pneumatic-solidify-" .. item_name,
    energy_required = 0.4,
    enabled = true,
    hide_from_player_crafting = true,
    hide_from_stats = true,
    hidden_in_factoriopedia = true,
    ingredients = {{type = "fluid", name = fluid_name, amount = batch * PNEUMATIC_FLUID_PER}},
    results = {{type = "item", name = item_name, amount = batch}},
    category = "pneumatic-solidify",
    overload_multiplier = 2,
  })

  ::next_pneumatic::
end

data:extend(pneumatic_fluids)
data:extend(pneumatic_recipes)

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
