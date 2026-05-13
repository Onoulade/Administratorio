local rules = {}

function rules.get_required_form(recipe_name)
  local explicit_form_overrides = {
    ["advanced-circuit"] = "management-approval-verbal",
    ["electric-engine-unit"] = "management-approval-verbal",
    ["processing-unit"] = "management-approval-verbal",
    ["flying-robot-frame"] = "management-approval-verbal",
    ["logistic-robot"] = "management-approval-verbal",
    ["construction-robot"] = "management-approval-verbal",
    ["personal-roboport-equipment"] = "management-approval-verbal",
    ["personal-roboport-mk2-equipment"] = "management-approval-verbal",
    ["rail"] = "construction-permit",
    ["train-stop"] = "construction-permit",
    ["rail-signal"] = "construction-permit",
    ["rail-chain-signal"] = "construction-permit",
    ["locomotive"] = "safety-waiver",
    ["rocket-fuel"] = "management-approval-verbal",
    ["low-density-structure"] = "management-approval-written",
    ["rocket-control-unit"] = "management-approval-written",
    ["satellite"] = "management-approval-written",
    ["heat-exchanger"] = "management-approval-written",
    ["steam-turbine"] = "management-approval-written",
    ["fusion-reactor-equipment"] = "management-approval-written",
  }
  if explicit_form_overrides[recipe_name] then
    return explicit_form_overrides[recipe_name]
  end

  if recipe_name == "burner-inserter" then return "work-order" end

  local tier4_patterns = {
    "assembling%-machine%-3", "centrifuge", "rocket%-silo",
    "nuclear%-reactor", "beacon",
    "fusion%-reactor", "quantum", "antimatter", "singularity",
  }
  for _, pat in ipairs(tier4_patterns) do
    if recipe_name:find(pat) then return "management-approval-written" end
  end

  local tier3_patterns = {
    "locomotive", "cargo%-wagon", "fluid%-wagon",
    "roboport", "solar%-panel", "accumulator", "electric%-furnace",
  }
  for _, pat in ipairs(tier3_patterns) do
    if recipe_name:find(pat) then return "management-approval-verbal" end
  end

  local tier2_patterns = {
    "assembling%-machine%-2", "chemical%-plant", "oil%-refinery",
    "pumpjack", "storage%-tank", "offshore%-pump",
    "steel%-furnace",
    "underground%-belt", "pipe%-to%-ground",
    "rail%-ramp", "rail%-support",
    "fast%-transport%-belt", "express%-transport%-belt",
  }
  for _, pat in ipairs(tier2_patterns) do
    if recipe_name:find(pat) then return "construction-permit" end
  end

  local tier1_patterns = {
    "inserter", "radar", "stone%-wall", "gate", "splitter",
    "medium%-electric%-pole", "big%-electric%-pole", "substation",
    "boiler", "steam%-engine", "assembling%-machine%-1",
  }
  for _, pat in ipairs(tier1_patterns) do
    if recipe_name:find(pat) then return "safety-waiver" end
  end

  if recipe_name == "lab" then return "construction-permit" end
  if recipe_name:find("mining%-drill") then return "construction-permit" end
  if recipe_name:find("science%-pack") then return "research-grant-approval" end

  return "work-order"
end

rules.OPERATING_FORM_BY_CATEGORY = {
  ["chemistry"] = "chemical-handling-work-order",
  ["centrifuging"] = "radiological-work-order",
}

rules.OPERATING_FORM_BY_RECIPE = {
  ["advanced-oil-processing"] = "chemical-handling-work-order",
  ["coal-liquefaction"] = "chemical-handling-work-order",
}

rules.OPERATING_FORM_EXEMPT_BY_CATEGORY = {}
rules.OPERATING_FORM_EXEMPT_BY_RECIPE = {}

rules.TAXPAYER_MONEY_COSTS = {
  ["roboport"] = 25,
  ["beacon"] = 30,
  ["nuclear-reactor"] = 100,
  ["centrifuge"] = 50,
  ["rocket-silo"] = 200,
}

return rules
