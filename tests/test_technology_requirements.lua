local requirements = require("prototypes.final_fixes.technology_requirements")
local function contains(values, value)
  for _, entry in ipairs(values or {}) do if entry == value then return true end end
  return false
end
local function packs(technology)
  local values = {}
  for _, ingredient in ipairs((technology.unit or {}).ingredients or {}) do values[#values + 1] = ingredient.name or ingredient[1] end
  return values
end
local function tech(prerequisites, recipes)
  local effects = {}
  for _, name in ipairs(recipes or {}) do effects[#effects + 1] = {type = "unlock-recipe", recipe = name} end
  return {prerequisites = prerequisites, effects = effects,
    unit = {ingredients = {{"automation-science-pack", 1}, {"administrative-science-pack", 1}}}}
end
local function recipe(ingredients, product, category, enabled, hidden)
  local inputs = {}
  for _, name in ipairs(ingredients) do inputs[#inputs + 1] = {type = "item", name = name, amount = 1} end
  return {ingredients = inputs, results = {{type = "item", name = product, amount = 1}},
    category = category, enabled = enabled or false, hidden = hidden}
end
local data = {raw = {
  technology = {
    ["administrative-science-research"] = {effects = {}, unit = {ingredients = {{"automation-science-pack", 1}}}},
    administration = tech({}, {"permit"}),
    unrelated = tech({}, {"irrelevant"}),
    ordinary = tech({"unrelated"}, {"building", "payload"}),
    ["logistic-science-pack"] = tech({}, {}),
    ["metallurgic-science-pack"] = {effects = {}, research_trigger = {type = "craft-item", item = "tungsten-plate"}},
    ["automation-science-pack"] = {effects = {}, research_trigger = {type = "craft-item", item = "lab"}},
    ["quality-module"] = tech({}, {}),
    alternative = tech({"ordinary"}, {"late-permit"}),
    recycler = tech({}, {"ore-recycling"}),
  },
  recipe = {
    permit = recipe({"ore"}, "permit"),
    irrelevant = recipe({}, "irrelevant"),
    building = recipe({"ore", "permit"}, "building"),
    payload = recipe({"irrelevant"}, "nothing", "pneumatic-intake", false, true),
    ["late-permit"] = recipe({}, "permit"),
    ["ore-recycling"] = recipe({"building"}, "ore", "recycling"),
  },
  resource = {ore = {minable = {result = "ore"}}},
},
  administratorio_technology_ownership = {administration = true, unrelated = true},
  administratorio_original_prerequisites = {ordinary = {}},
}
requirements.apply(data)
local technologies = data.raw.technology
assert(not contains(packs(technologies.ordinary), "administrative-science-pack"))
assert(contains(packs(technologies.administration), "administrative-science-pack"))
assert(contains(packs(technologies["logistic-science-pack"]), "administrative-science-pack"))
assert(contains(packs(technologies["quality-module"]), "administrative-science-pack"))
assert(not technologies["metallurgic-science-pack"].research_trigger)
assert(technologies["metallurgic-science-pack"].unit.count == 75)
assert(technologies["metallurgic-science-pack"].unit.time == 30)
assert(technologies["automation-science-pack"].research_trigger, "red science remains the bootstrap")
assert(not contains(technologies.ordinary.prerequisites, "unrelated"), "hidden transport payloads cannot gate production")
assert(contains(technologies.ordinary.prerequisites, "administration"), "construction input producer must gate the recipe")
assert(not contains(technologies.ordinary.prerequisites, "alternative"), "alternative producer cannot introduce a cycle")
assert(not contains(technologies.ordinary.prerequisites, "recycler"), "mined roots cannot depend on recycling")
assert(contains(technologies["logistic-science-pack"].prerequisites, "administrative-science-research"))
local parent_count = #technologies.ordinary.prerequisites
requirements.apply(data)
assert(#technologies.ordinary.prerequisites == parent_count, "reconciliation must be idempotent")
print("Technology requirement invariants passed")
