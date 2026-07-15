-- Adds planet-specific paperwork after general recipe regulation.
-- Multi-planet inputs collapse into one composite form rather than stacking
-- individual color forms.

local M = {}

local PLANET_INTERMEDIATE_GATING = {
  ["tungsten-plate"] = "blank-cyan-form",
  ["tungsten-carbide"] = "blank-cyan-form",
  ["carbon-fiber"] = "blank-yellow-form",
  ["holmium-plate"] = "blank-magenta-form",
}
local TOP_TIER_MULTICOLOR_GATING = { ["quantum-processor"] = "unified-operations-charter" }
local EXPLICIT_MULTICOLOR_RECIPE_GATING = {
  ["fusion-reactor"] = "trichromatic-permit",
  ["fusion-generator"] = "trichromatic-permit",
  ["mech-armor"] = "trichromatic-permit",
  ["promethium-science-pack"] = "promethium-research-charter",
}
local CRYOGENIC_RECIPE_GATING = {
  ["lithium"] = "cyan-yellow-form",
  ["lithium-plate"] = "cyan-yellow-form",
  ["fluoroketone"] = "cryogenic-operations-license",
  ["fluoroketone-cooling"] = "cryogenic-operations-license",
  ["cryogenic-plant"] = "cryogenic-operations-license",
}

local function get_bicolor_gate(required_form_order)
  local has = {}
  for _, form_name in ipairs(required_form_order) do has[form_name] = true end
  if has["blank-cyan-form"] and has["blank-yellow-form"] then return "cyan-yellow-form" end
  if has["blank-cyan-form"] and has["blank-magenta-form"] then return "cyan-magenta-form" end
  if has["blank-yellow-form"] and has["blank-magenta-form"] then return "yellow-magenta-form" end
  return nil
end

function M.apply(data, shared, remove_ingredient_from_recipe, add_special_paperwork)
  for recipe_name, recipe in pairs(data.raw.recipe or {}) do
    if shared.is_admin_recipe(recipe_name) then goto next_gating end
    local target = recipe.normal or recipe
    if not target or not target.ingredients then goto next_gating end

    local required_forms, required_form_order = {}, {}
    for _, ingredient in ipairs(target.ingredients) do
      local form = PLANET_INTERMEDIATE_GATING[ingredient.name or ingredient[1]]
      if form and not required_forms[form] then
        required_forms[form] = true
        required_form_order[#required_form_order + 1] = form
      end
    end

    if #required_form_order >= 2 then
      local multicolor_gate = TOP_TIER_MULTICOLOR_GATING[recipe_name]
        or (#required_form_order == 2 and get_bicolor_gate(required_form_order) or "trichromatic-permit")
      for _, form_name in ipairs(required_form_order) do
        remove_ingredient_from_recipe(recipe_name, form_name)
      end
      if multicolor_gate then add_special_paperwork(recipe_name, multicolor_gate, 1) end
    else
      for _, form_name in ipairs(required_form_order) do
        add_special_paperwork(recipe_name, form_name, 1)
      end
    end

    ::next_gating::
  end

  for recipe_name, form_name in pairs(CRYOGENIC_RECIPE_GATING) do
    if data.raw.recipe[recipe_name] and not shared.is_admin_recipe(recipe_name) then
      add_special_paperwork(recipe_name, form_name, 1)
    end
  end
  for recipe_name, form_name in pairs(EXPLICIT_MULTICOLOR_RECIPE_GATING) do
    if data.raw.recipe[recipe_name] and not shared.is_admin_recipe(recipe_name) then
      add_special_paperwork(recipe_name, form_name, 1)
    end
  end
end

return M
