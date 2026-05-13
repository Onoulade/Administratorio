local base_rules = require("prototypes.shared.non_space_age_rules")

local rules = {}

rules.OPERATING_FORM_BY_CATEGORY = {
  ["oil-processing"] = "petrochemical-operating-permit",
  ["chemistry"] = "chemical-handling-work-order",
  ["centrifuging"] = "radiological-work-order",
}

rules.OPERATING_FORM_BY_RECIPE = {
  ["plastic-bar"] = "petrochemical-operating-permit",
  ["sulfur"] = "petrochemical-operating-permit",
  ["sulfuric-acid"] = "petrochemical-operating-permit",
  ["solid-fuel-from-heavy-oil"] = "petrochemical-operating-permit",
  ["solid-fuel-from-light-oil"] = "petrochemical-operating-permit",
  ["solid-fuel-from-petroleum-gas"] = "petrochemical-operating-permit",
  ["advanced-oil-processing"] = "chemical-handling-work-order",
  ["coal-liquefaction"] = "chemical-handling-work-order",
}
rules.OPERATING_FORM_EXEMPT_BY_CATEGORY = {
  ["metallurgy"] = true,
  ["organic"] = true,
  ["electromagnetics"] = true,
  ["cryogenics"] = true,
  ["bureaucracy-certification"] = true,
  ["bureaucracy-conciliation"] = true,
  ["orbital-bureaucracy"] = true,
}
rules.OPERATING_FORM_EXEMPT_BY_RECIPE = {
  ["foundry"] = true,
  ["biochamber"] = true,
  ["electromagnetic-plant"] = true,
  ["cryogenic-plant"] = true,
  ["plastic-bar-vulcanus"] = true,
  ["heatproof-paper-production"] = true,
  ["liquid-stimulant-production"] = true,
  ["liquid-coffee-vulcanus"] = true,
  ["notary-office"] = true,
  ["territorial-arbitration-post"] = true,
  ["capture-bureau"] = true,
  ["conciliation-desk"] = true,
}
rules.TAXPAYER_MONEY_COSTS = base_rules.TAXPAYER_MONEY_COSTS

function rules.get_required_form(recipe_name)
  return base_rules.get_required_form(recipe_name)
end

return rules
