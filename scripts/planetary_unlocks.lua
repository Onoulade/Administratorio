local M = {}

M.AMBER_SAP_TECHNOLOGY = "amber-sap-processing"
M.AMBER_SAP_RECIPES = {
  "amber-sap-nonsense-seeding",
  "ink-production-gleba",
  "carbon-offset-certificate-basic-gleba",
  "provisional-approval-cultivation-gleba",
  "construction-permit-gleba",
}

function M.sync_force(force)
  if not force or force.valid == false then return end

  local technology = force.technologies and force.technologies[M.AMBER_SAP_TECHNOLOGY]
  local unlocked = technology and technology.researched or false
  for _, recipe_name in ipairs(M.AMBER_SAP_RECIPES) do
    local recipe = force.recipes and force.recipes[recipe_name]
    if recipe then
      recipe.enabled = unlocked
    end
  end
end

function M.sync_all()
  if not game or not game.forces then return end
  for _, force in pairs(game.forces) do
    M.sync_force(force)
  end
end

function M.on_research_finished(research)
  if research and research.name == M.AMBER_SAP_TECHNOLOGY then
    M.sync_force(research.force)
  end
end

return M
