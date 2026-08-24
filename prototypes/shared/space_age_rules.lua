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
-- Space Age migrates several vanilla chemical recipes away from `chemistry`
-- so they can also run in Biochambers or Cryogenic Plants. They remain
-- hazardous chemical processes and must not lose their operating paperwork
-- merely because their category became a hybrid.
rules.OPERATING_FORM_CONFIG.categories["chemistry-or-cryogenics"] = {form = "chemical-handling-work-order"}
rules.OPERATING_FORM_CONFIG.categories["organic-or-chemistry"] = {form = "chemical-handling-work-order"}
for _, category in ipairs({
  "metallurgy",
  "organic",
  "electromagnetics",
  "cryogenics",
  "bureaucracy-certification",
  "bureaucracy-conciliation",
  "orbital-bureaucracy",
  "orbital-printing",
}) do
  rules.OPERATING_FORM_CONFIG.categories[category] = {exempt = true}
end

-- Platform life support uses locally printed operating forms. Ice melting is
-- the paperwork-free bootstrap that makes water, and therefore those forms,
-- available after a platform has exhausted every imported consumable.
rules.OPERATING_FORM_CONFIG.recipes["ice-melting"] = {exempt = true}
for _, recipe_name in ipairs({
  "thruster-fuel",
  "thruster-oxidizer",
  "advanced-thruster-fuel",
  "advanced-thruster-oxidizer",
}) do
  rules.OPERATING_FORM_CONFIG.recipes[recipe_name] = {form = "orbital-operations-form"}
end

for _, recipe_name in ipairs({
  "foundry",
  "biochamber",
  "electromagnetic-plant",
  "cryogenic-plant",
  "plastic-bar-vulcanus",
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
  return base_rules.get_required_form(recipe_name)
end

return rules
