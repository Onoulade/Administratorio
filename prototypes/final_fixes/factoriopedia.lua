-- Presentation only: preserve recipe identities, costs, categories and unlocks.
local M = {}
local PREFIX = "administratorio-factoriopedia."

local function field(prototype, title, value, order)
  if not prototype then return end
  prototype.custom_tooltip_fields = prototype.custom_tooltip_fields or {}
  table.insert(prototype.custom_tooltip_fields, {
    name = {PREFIX .. title}, value = value, order = order or 10,
    show_in_tooltip = false, show_in_factoriopedia = true,
  })
end

local function append_description(prototype, key)
  prototype.localised_description = {"", prototype.localised_description
    or {"?", {"technology-description." .. prototype.name}, ""}, "\n\n", {PREFIX .. key}}
end

local function accepts(recipe, categories)
  local accepted = {}
  for _, category in ipairs(categories or {}) do accepted[category] = true end
  if accepted[recipe.category or "crafting"] then return true end
  for _, category in ipairs(recipe.additional_categories or {}) do
    if accepted[category] then return true end
  end
  return false
end

function M.apply(raw, space_age, item_types)
  local recipes = raw.recipe or {}
  local function item(name)
    for _, kind in ipairs(item_types or {"item", "capsule", "tool", "module"}) do
      if raw[kind] and raw[kind][name] then return raw[kind][name] end
    end
  end
  local function entity(name)
    return (raw["assembling-machine"] or {})[name]
      or (raw.furnace or {})[name]
      or (raw.container or {})[name]
  end
  local function info(prototype, key, ...)
    field(prototype, "obtained-through", {PREFIX .. key, ...}, 5)
  end
  local function source(prototype, key, ...)
    field(prototype, "acquisition-process", {PREFIX .. key, ...}, 5)
  end

  local names = {}
  for name in pairs(recipes) do
    if name:match("%-regulated$") and recipes[name:gsub("%-regulated$", "")] then
      names[#names + 1] = name
    end
  end
  table.sort(names)
  local paired = {}
  for _, name in ipairs(names) do
    local base_name = name:gsub("%-regulated$", "")
    local original, regulated = recipes[base_name], recipes[name]
    -- Do not expose intentionally hidden compatibility recipes.
    if not original.hidden and not regulated.hidden then
      local handcraft = accepts(original, ((raw.character or {}).character or {}).crafting_categories)
      local machine = false
      for _, kind in ipairs({"assembling-machine", "furnace"}) do
        for _, prototype in pairs(raw[kind] or {}) do
          if not prototype.hidden and accepts(original, prototype.crafting_categories) then machine = true end
        end
      end
      local route = handcraft and (machine and "route-handcraft-specialist" or "route-handcraft") or "route-specialist"
      local title = regulated.localised_name or original.localised_name or {"recipe-name." .. base_name}
      original.localised_name = {PREFIX .. route, title}
      regulated.localised_name = {PREFIX .. "route-regulated", title}
      original.always_show_made_in = true
      regulated.always_show_made_in = true
      -- A redirect loses the manual ingredient list. Keep both real routes
      -- navigable; the product page supplies the index into them.
      if original.factoriopedia_alternative == name then
        original.factoriopedia_alternative = nil
        original.hidden_in_factoriopedia = false
      end
      local seen = {}
      local ingredients = {}
      for _, ingredient in ipairs(regulated.ingredients or {}) do
        ingredients[ingredient.name or ingredient[1]] = ingredient.amount or ingredient[2]
      end
      local results = regulated.results
      if not results and regulated.result then
        results = {{name = regulated.result, amount = regulated.result_count or 1}}
      end
      for _, result in ipairs(results or {}) do
        local product = result.type == "fluid" and (raw.fluid or {})[result.name] or item(result.name)
        -- Returned staff/catalysts are not a new way to obtain that item.
        -- Their ordinary "Used in" links still expose the complete recipes.
        local is_primary = regulated.main_product and regulated.main_product ~= ""
          and regulated.main_product == result.name
        local is_product = (not regulated.main_product or regulated.main_product == "")
          and (not ingredients[result.name] or (result.amount or result.amount_max or 0) > ingredients[result.name])
        if product and not seen[product] and (is_primary or is_product) then
          field(product, "production-routes", {"", "[recipe=" .. base_name .. "]  ",
            {PREFIX .. route, title}, "\n[recipe=" .. name .. "]  ",
            {PREFIX .. "route-regulated", title}}, 20)
          seen[product] = true
        end
      end
      paired[name] = base_name
    end
  end

  for _, technology in pairs(raw.technology or {}) do
    local visible = {}
    for _, effect in ipairs(technology.effects or {}) do
      if effect.type == "unlock-recipe" and not effect.hidden then visible[effect.recipe] = true end
    end
    local folded = false
    for _, effect in ipairs(technology.effects or {}) do
      if effect.type == "unlock-recipe" and paired[effect.recipe] and visible[paired[effect.recipe]] then
        effect.hidden = true
        folded = true
      end
    end
    if folded then append_description(technology, "paired-unlocks") end
  end

  local employment = space_age and "acquire-enrolled" or "acquire-worker-base"
  info(item(space_age and "enrolled-biter" or "worker-biter"), employment)
  source(item("job-offer"), employment)
  source(entity("admin-station"), employment)
  if not space_age then return end

  -- Resolve the final recipe identity after Factoriopedia recipe merging.
  local formation = recipes["worker-biter"] and "worker-biter" or "worker-biter-formation"
  info(item("worker-biter"), "acquire-worker-space", "[recipe=" .. formation .. "]")
  source(entity("formation-center"), "acquire-worker-space", "[recipe=" .. formation .. "]")
  source((raw.fluid or {})["workforce-lure-spores"], "acquire-workforce")
  source(entity("capture-bureau"), "acquire-workforce")
  source(entity("capture-bureau"), "acquire-tourism")
  source(entity("capture-bureau"), "acquire-eggs-capture")
  source((raw.fluid or {})["tourism-lure-spores"], "acquire-tourism")
  source((raw.fluid or {})["oviposition-lure-spores"], "acquire-eggs-capture")
  info(item("pentapod-egg"), "acquire-eggs-sampling")
  info(item("pentapod-egg"), "acquire-eggs-capture")
  info(item("pentapod-egg"), "acquire-eggs-breeding")
  source(item("pentapod-sampling-capsule"), "acquire-eggs-sampling")
  for _, size in ipairs({"small", "medium", "big", "behemoth"}) do
    local package = item(size .. "-spitter-tourism-package")
    local lifetime = package and (package.spoil_ticks or 0) / 3600 or 5
    info(package, "acquire-tourism-package", "[entity=" .. size .. "-spitter]", tostring(lifetime))
  end
end

return M
