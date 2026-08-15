-- Biter eggs never leave Nauvis.
--
-- Spoiled eggs hatch hostile biters (one per 25 eggs, via
-- spoil_to_trigger_result). Off Nauvis there is no Administration Desk, no
-- complaint pipeline, and no way to handle what comes out. So every vanilla
-- recipe that consumed eggs somewhere other than Nauvis is rerouted through a
-- courier trained on Nauvis instead.
--
-- Vanilla egg costs are preserved exactly. Only what crosses space changes.
--
-- This runs in final fixes, after colored_ink_gating, so the promethium
-- expedition charter is already on the recipe and can be scaled with the batch
-- rather than silently becoming ten times cheaper per pack.

local manager_couriers = require("prototypes.shared.manager_couriers")
local space_age_planets = require("prototypes.shared.space_age_planets")

local M = {}

local EGG = manager_couriers.EGG_ITEM

local function ingredient_amount(recipe, name)
  for _, ingredient in ipairs(recipe.ingredients or {}) do
    if (ingredient.name or ingredient[1]) == name then
      return ingredient.amount or ingredient[2] or 0
    end
  end
  return nil
end

local function remove_ingredient(recipe, name)
  local kept = {}
  for _, ingredient in ipairs(recipe.ingredients or {}) do
    if (ingredient.name or ingredient[1]) ~= name then
      kept[#kept + 1] = ingredient
    end
  end
  recipe.ingredients = kept
end

local function add_ingredient(recipe, name, amount)
  recipe.ingredients = recipe.ingredients or {}
  recipe.ingredients[#recipe.ingredients + 1] = {type = "item", name = name, amount = amount}
end

local function add_result(recipe, name, amount, ignored)
  recipe.results = recipe.results or {}
  recipe.results[#recipe.results + 1] = {
    type = "item",
    name = name,
    amount = amount,
    ignored_by_productivity = ignored and amount or nil,
    ignored_by_stats = ignored and amount or nil,
  }
end

local function scale_all(list, factor, skip)
  for _, entry in ipairs(list or {}) do
    local name = entry.name or entry[1]
    if not (skip and skip[name]) then
      if entry.amount then
        entry.amount = entry.amount * factor
      elseif entry[2] then
        entry[2] = entry[2] * factor
      end
      if entry.ignored_by_productivity then
        entry.ignored_by_productivity = entry.ignored_by_productivity * factor
      end
      if entry.ignored_by_stats then
        entry.ignored_by_stats = entry.ignored_by_stats * factor
      end
    end
  end
end

function M.apply(data)
  local recipes = data.raw.recipe or {}

  -- Nauvis-only crafts. The eggs stay, the recipe simply cannot be run
  -- anywhere they would have had to travel to reach it.
  for _, recipe_name in ipairs({"biolab", "nutrients-from-biter-egg"}) do
    local recipe = recipes[recipe_name]
    if recipe and ingredient_amount(recipe, EGG) then
      space_age_planets.apply_planet_surface_conditions(recipe, "nauvis")
    end
  end

  -- Gleba soils: the Geotechnical courier is handed back after the craft, so
  -- Gleba slowly accumulates managers unless they are shipped home. That is a
  -- feature -- it gives the relocation cannon bidirectional traffic rather than
  -- a one-way pipe.
  local geotechnical = manager_couriers.BY_KEY.geotechnical
  for _, recipe_name in ipairs({"overgrowth-yumako-soil", "overgrowth-jellynut-soil"}) do
    local recipe = recipes[recipe_name]
    if recipe and ingredient_amount(recipe, EGG) then
      remove_ingredient(recipe, EGG)
      add_ingredient(recipe, geotechnical.item, 1)
      add_result(recipe, manager_couriers.SPOIL_RESULT, 1, true)
    end
  end

  -- The captive spawner consumes its missionary outright.
  local missionary = manager_couriers.BY_KEY.missionary
  local spawner = recipes["captive-biter-spawner"]
  if spawner and ingredient_amount(spawner, EGG) then
    remove_ingredient(spawner, EGG)
    add_ingredient(spawner, missionary.item, 1)
  end

  -- Administratorium science. Vanilla's 30-minute egg timer already forces
  -- promethium science to be crafted near Nauvis: a platform flies out, collects
  -- chunks, returns, takes on fresh eggs, and crafts. The Cobaye preserves that
  -- constraint exactly, so the recipe is batched x10 to match one courier.
  local cobaye = manager_couriers.BY_KEY.cobaye
  local promethium = recipes["promethium-science-pack"]
  if promethium and ingredient_amount(promethium, EGG) then
    remove_ingredient(promethium, EGG)
    -- The courier is the one thing that does not scale: one Cobaye per batch is
    -- what puts the recipe at exact vanilla rocket parity, 2 kg per pack.
    scale_all(promethium.ingredients, 10)
    scale_all(promethium.results, 10)
    add_ingredient(promethium, cobaye.item, 1)
    promethium.energy_required = (promethium.energy_required or 5) * 10
  end
end

return M
