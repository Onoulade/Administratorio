local function add_tech_unlock(technology_name, recipe_name)
  local technology = data.raw["technology"] and data.raw["technology"][technology_name]
  if not technology or not recipe_name then return end
  technology.effects = technology.effects or {}
  for _, effect in ipairs(technology.effects) do
    if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
      return
    end
  end
  table.insert(technology.effects, {type = "unlock-recipe", recipe = recipe_name})
end

data:extend({
  {
    type = "technology",
    name = "chromatic-printing",
    icon = "__administratorio__/graphics/icons/steel-forge-icon.png",
    icon_size = 64,
    effects = {
      {type = "unlock-recipe", recipe = "chromatic-printer"},
    },
    prerequisites = {"industrial-printing", "executive-review"},
    unit = {
      count = 220,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-a",
  },
  {
    type = "technology",
    name = "workforce-formation",
    icon = "__base__/graphics/technology/worker-robots-speed.png",
    icon_size = 256,
    effects = {
      {type = "unlock-recipe", recipe = "formation-center"},
      {type = "unlock-recipe", recipe = "trajectory-compliance-array"},
      {type = "unlock-recipe", recipe = "job-offer-production"},
      {type = "unlock-recipe", recipe = "worker-biter-formation"},
      {type = "unlock-recipe", recipe = "clerical-trainee-formation"},
      {type = "unlock-recipe", recipe = "management-trainee-formation"},
      {type = "unlock-recipe", recipe = "night-shift-supervisor-formation"},
      {type = "unlock-recipe", recipe = "field-negotiator-formation"},
      {type = "unlock-recipe", recipe = "middle-management-managing-manager-formation"},
    },
    prerequisites = {"space-science-pack", "executive-review"},
    unit = {
      count = 280,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"utility-science-pack", 1},
        {"space-science-pack", 1},
        {"administrative-science-pack", 1},
      },
      time = 45,
    },
    order = "h-b",
  },
})

add_tech_unlock("metallurgic-science-pack", "licensed-notary-formation")
add_tech_unlock("agricultural-science-pack", "conciliation-officer-formation")
add_tech_unlock("electromagnetic-science-pack", "relay-clerk-formation")
add_tech_unlock("cryogenic-science-pack", "cryoprint-technician-formation")
add_tech_unlock("after-hours-operations", "overtime-exemption-staffed")
add_tech_unlock("discovery-redundant-rubble", "promise-production-negotiated")
add_tech_unlock("nest-expropriation", "eviction-notice-production-negotiated")
