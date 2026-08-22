local M = {}

M.PAPERWORK_SUBGROUPS = {
  ["forms-base"] = true,
  ["forms-permits"] = true,
  ["forms-work-orders"] = true,
  ["forms-printed"] = true,
}

local function canonical_recipe(item_name)
  return {
    type = "recipe",
    name = item_name .. "-recycling",
    category = "recycling",
    subgroup = "form-paper-recycling-recipes",
    order = item_name,
    enabled = true,
    hidden = true,
    hidden_in_factoriopedia = false,
    hide_from_player_crafting = true,
    auto_recycle = false,
    allow_as_intermediate = false,
    allow_decomposition = false,
    allow_productivity = false,
    ingredients = {
      {type = "item", name = item_name, amount = 1},
    },
    results = {
      {type = "item", name = "paper", amount = 1, probability = 0.25},
    },
    energy_required = 0.5,
  }
end

local function overwrite_recipe(target, replacement)
  -- Quality generates automatic recycling recipes during data-updates. Clear
  -- every result/variant field it may have added before applying our canonical
  -- one-form-to-paper rule in data-final-fixes.
  target.normal = nil
  target.expensive = nil
  target.main_product = nil
  target.result = nil
  target.result_count = nil
  target.results = nil
  target.ingredients = nil
  target.surface_conditions = nil
  for key, value in pairs(replacement) do target[key] = value end
end

function M.apply()
  local item_names = {}
  for item_name, item in pairs(data.raw.item or {}) do
    if M.PAPERWORK_SUBGROUPS[item.subgroup] then
      item_names[#item_names + 1] = item_name
    end
  end
  table.sort(item_names)

  local additions = {}
  for _, item_name in ipairs(item_names) do
    local replacement = canonical_recipe(item_name)
    local existing = data.raw.recipe and data.raw.recipe[replacement.name]
    if existing then
      overwrite_recipe(existing, replacement)
    else
      additions[#additions + 1] = replacement
    end
  end
  if #additions > 0 then data:extend(additions) end
  return #item_names
end

return M
