local function add_unlock(technology_name, recipe_name)
  local technology = data.raw.technology and data.raw.technology[technology_name]
  local recipe = data.raw.recipe and data.raw.recipe[recipe_name]
  if not technology or not recipe then return end
  technology.effects = technology.effects or {}
  for _, effect in ipairs(technology.effects) do
    if effect.type == "unlock-recipe" and effect.recipe == recipe_name then return end
  end
  technology.effects[#technology.effects + 1] = {type = "unlock-recipe", recipe = recipe_name}
end

data:extend({
  {
    type = "technology",
    name = "archive-recombination",
    icon = "__administratorio__/graphics/technology/archive-recombination-v2.png",
    icon_size = 256,
    prerequisites = {"fulgora-digital-services"},
    effects = {
      {type = "unlock-recipe", recipe = "archive-recombination-bureau"},
    },
    research_trigger = {
      type = "craft-item",
      item = "digital-processing-certificate",
      count = 5,
    },
    order = "h-d2",
  },
})

add_unlock("recycling", "old-archive-recycling")
