-- One reusable chassis and one jurisdictional approval for each native
-- Space Age specialist machine. Keep recipe and runtime names in one place.
local M = {}

M.buildings = {
  {name = "foundry", form = "blank-cyan-form"},
  {name = "biochamber", form = "blank-yellow-form"},
  {name = "electromagnetic-plant", form = "blank-magenta-form"},
  {name = "cryogenic-plant", form = "cryogenic-operations-license"},
}

M.recipe_names = {}
for _, building in ipairs(M.buildings) do
  building.chassis = building.name .. "-unapproved"
  building.approval_recipe = building.name .. "-approval"
  M.recipe_names[building.approval_recipe] = true
end

return M
