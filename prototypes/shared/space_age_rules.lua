local base_rules = require("prototypes.shared.non_space_age_rules")

local rules = {}

rules.OPERATING_FORM_BY_CATEGORY = base_rules.OPERATING_FORM_BY_CATEGORY
rules.OPERATING_FORM_BY_RECIPE = base_rules.OPERATING_FORM_BY_RECIPE
rules.OPERATING_FORM_EXEMPT_BY_CATEGORY = {
  ["metallurgy"] = true,
  ["organic"] = true,
  ["electromagnetics"] = true,
  ["cryogenics"] = true,
}
rules.OPERATING_FORM_EXEMPT_BY_RECIPE = {
  ["foundry"] = true,
  ["biochamber"] = true,
  ["electromagnetic-plant"] = true,
  ["cryogenic-plant"] = true,
}
rules.TAXPAYER_MONEY_COSTS = base_rules.TAXPAYER_MONEY_COSTS

-- Phase 1 compatibility keeps existing paperwork behavior until each
-- Space Age recipe family has planet-specific paperwork.
function rules.get_required_form(recipe_name)
  return base_rules.get_required_form(recipe_name)
end

return rules
