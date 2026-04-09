local base_rules = require("prototypes.shared.non_space_age_rules")

local rules = {}

local function copy_rule_table(source)
  local copy = {}
  for name, rule in pairs(source or {}) do
    copy[name] = {form = rule.form, exempt = rule.exempt}
  end
  return copy
end

rules.OPERATING_FORM_CONFIG = {
  categories = copy_rule_table(base_rules.OPERATING_FORM_CONFIG.categories),
  recipes = copy_rule_table(base_rules.OPERATING_FORM_CONFIG.recipes),
}

rules.OPERATING_FORM_CONFIG.categories["oil-processing"] = {form = "chemical-handling-work-order"}
for _, category in ipairs({
  "metallurgy",
  "organic",
  "electromagnetics",
  "cryogenics",
  "bureaucracy-certification",
  "bureaucracy-conciliation",
  "orbital-bureaucracy",
}) do
  rules.OPERATING_FORM_CONFIG.categories[category] = {exempt = true}
end

for _, recipe_name in ipairs({
  "foundry",
  "biochamber",
  "electromagnetic-plant",
  "cryogenic-plant",
  "plastic-bar-vulcanus",
  "heatproof-paper-production",
  "liquid-stimulant-production",
  "liquid-coffee-vulcanus",
  "notary-office",
  "territorial-arbitration-post",
  "capture-bureau",
  "conciliation-desk",
}) do
  rules.OPERATING_FORM_CONFIG.recipes[recipe_name] = {exempt = true}
end
rules.TAXPAYER_MONEY_COSTS = base_rules.TAXPAYER_MONEY_COSTS

function rules.get_required_form(recipe_name)
  local gleba_overrides = {
    ["rocket-control-unit-gleba"] = "symbiosis-record",
    ["rocket-silo-gleba"] = "work-order",
  }
  if gleba_overrides[recipe_name] then
    return gleba_overrides[recipe_name]
  end
  return base_rules.get_required_form(recipe_name)
end

return rules
