local M = {}
local approvals = require("prototypes.shared.specialist_approvals")

local STAMP_ICON = "__base__/graphics/icons/signal/signal_X.png"

local function rename_building_result(recipe, old_name, new_name)
  local function rename(target)
    if not target then return end
    if target.result == old_name then target.result = new_name end
    if target.main_product == old_name then target.main_product = new_name end
    for _, result in ipairs(target.results or {}) do
      if result.name == old_name then result.name = new_name end
      if result[1] == old_name then result[1] = new_name end
    end
  end
  rename(recipe)
  rename(recipe.normal)
  rename(recipe.expensive)
end

local function chassis_item(approved, spec)
  local chassis = util.table.deepcopy(approved)
  chassis.name = spec.chassis
  chassis.place_result = nil
  chassis.localised_name = {"item-name." .. spec.chassis}
  chassis.localised_description = {"item-description." .. spec.chassis}
  chassis.order = (approved.order or spec.name) .. "-y[unapproved]"
  chassis.icons = chassis.icons or {{icon = chassis.icon, icon_size = chassis.icon_size or 64}}
  chassis.icon = nil
  chassis.icons[#chassis.icons + 1] = {
    icon = STAMP_ICON, icon_size = 64, scale = 0.4, shift = {8, 8},
    tint = {r = 1, g = 0.28, b = 0.28, a = 1},
  }
  return chassis
end

local function approval_recipe(original, approved, spec)
  return {
    type = "recipe",
    name = spec.approval_recipe,
    category = "specialist-approval",
    enabled = original.enabled == true,
    subgroup = approved.subgroup,
    order = (approved.order or spec.name) .. "-z[approval]",
    localised_name = {"item-name." .. spec.name},
    localised_description = {"recipe-description." .. spec.approval_recipe},
    ingredients = {
      {type = "item", name = spec.chassis, amount = 1},
      {type = "item", name = spec.form, amount = 1},
    },
    results = {{type = "item", name = spec.name, amount = 1}},
    energy_required = 5,
    allow_productivity = false,
    allow_quality = false,
    auto_recycle = false,
  }
end

local function add_unlock(technologies, source_name, approval_name)
  for _, technology in pairs(technologies or {}) do
    for _, effect in ipairs(technology.effects or {}) do
      if effect.type == "unlock-recipe" and effect.recipe == source_name then
        technology.effects[#technology.effects + 1] = {
          type = "unlock-recipe", recipe = approval_name,
        }
        break
      end
    end
  end
end

function M.apply(data, remove_ingredient_from_recipe)
  local items = {}
  local recipes = {}
  for _, spec in ipairs(approvals.buildings) do
    local approved = data.raw.item and data.raw.item[spec.name]
    local original = data.raw.recipe and data.raw.recipe[spec.name]
    local entity = data.raw["assembling-machine"] and data.raw["assembling-machine"][spec.name]
    if approved and original and entity then
      items[#items + 1] = chassis_item(approved, spec)
      recipes[#recipes + 1] = approval_recipe(original, approved, spec)

      -- Both construction routes retain their physical materials, specialist,
      -- and any handcraft/assembler work order. Approval owns the color form.
      for _, recipe_name in ipairs({spec.name, spec.name .. "-regulated"}) do
        local build_recipe = data.raw.recipe[recipe_name]
        if build_recipe then
          remove_ingredient_from_recipe(recipe_name, spec.form)
          rename_building_result(build_recipe, spec.name, spec.chassis)
          build_recipe.localised_name = {"item-name." .. spec.chassis}
          build_recipe.localised_description = {"item-description." .. spec.chassis}
        end
      end

      entity.minable = entity.minable or {mining_time = 0.5}
      entity.minable.results = nil
      entity.minable.result = spec.chassis
      entity.minable.count = 1
      add_unlock(data.raw.technology, spec.name, spec.approval_recipe)
    end
  end
  data:extend(items)
  data:extend(recipes)
end

return M
