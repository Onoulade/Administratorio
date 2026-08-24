local M = {}

-- Factorio 2.0 exposes runtime technology effects through LuaTechnology.prototype
-- instead of the removed game.technology_prototypes table.
local function resolve_technology_prototype(force, technology_ref)
  if type(technology_ref) == "string" then
    local technology = force and force.technologies and force.technologies[technology_ref] or nil
    if technology then
      technology_ref = technology
    elseif prototypes and prototypes.technology then
      technology_ref = prototypes.technology[technology_ref]
    else
      technology_ref = nil
    end
  end

  if not technology_ref or technology_ref.valid == false then return nil end

  local prototype = technology_ref.prototype or technology_ref
  if prototype.valid == false then return nil end
  return prototype
end

function M.enable_regulated_variants_for_technology(force, technology_ref)
  if not force or force.valid == false then return end

  local technology = resolve_technology_prototype(force, technology_ref)
  if not technology or not technology.effects then return end

  for _, effect in ipairs(technology.effects) do
    if effect.type == "unlock-recipe" and effect.recipe then
      local original = force.recipes[effect.recipe]
      if original then
        original.enabled = true
      end

      local regulated = force.recipes[effect.recipe .. "-regulated"]
      if regulated then
        regulated.enabled = true
      end
    end
  end
end

-- New regulated prototypes added by an update are not automatically enabled
-- for existing forces, even when their original recipe is enabled from the
-- start (basic belts are the important case). Mirror every currently enabled
-- original during init/configuration sync, independently of technology effects.
function M.sync_enabled_variants(force)
  if not force or force.valid == false or not force.recipes then return end

  for recipe_name, original in pairs(force.recipes) do
    if original.enabled and not recipe_name:find("%-regulated$") then
      local regulated = force.recipes[recipe_name .. "-regulated"]
      if regulated then
        regulated.enabled = true
      end
    end
  end
end

return M
