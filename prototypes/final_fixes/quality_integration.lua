-- Administrative Certification is intentionally a thin skin over Factorio's
-- native Quality system.  Native identifiers, tiers, probabilities and unlock
-- effects remain untouched so other quality-aware mods retain compatibility.
local M = {}

local QUALITY_NAMES = {"normal", "uncommon", "rare", "epic", "legendary"}

local CERTIFICATION_TECHS = {
  ["quality-module"] = {prerequisite = "littering-resolution"},
  ["quality-module-2"] = {prerequisite = "industrial-propaganda"},
  ["quality-module-3"] = {prerequisite = "health-and-safety"},
  ["epic-quality"] = {prerequisite = "executive-review"},
  ["legendary-quality"] = {prerequisite = "constitutional-law"},
}

local QUALITY_MODULE_RECIPES = {
  ["quality-module"] = {
    {type = "item", name = "dubious-data", amount = 10},
    {type = "item", name = "electronic-circuit", amount = 5},
    {type = "item", name = "safety-waiver", amount = 1},
    {type = "item", name = "taxpayer-money", amount = 25},
  },
  ["quality-module-2"] = {
    {type = "item", name = "quality-module", amount = 5},
    {type = "item", name = "data", amount = 5},
    {type = "item", name = "advanced-circuit", amount = 5},
    {type = "item", name = "management-approval-verbal", amount = 1},
    {type = "item", name = "taxpayer-money", amount = 100},
  },
  ["quality-module-3"] = {
    {type = "item", name = "quality-module-2", amount = 5},
    {type = "item", name = "policy", amount = 10},
    {type = "item", name = "credentials", amount = 5},
    {type = "item", name = "processing-unit", amount = 5},
    {type = "item", name = "management-approval-written", amount = 1},
    {type = "item", name = "taxpayer-money", amount = 500},
  },
}

-- These craft paperwork or ordinary infrastructure, so their native Quality
-- speed and department-slot effects are useful.  Field offices and fax units
-- have script-owned metrics; the other special systems stay cosmetic-only.
local PRODUCTION_FACILITIES = {
  "resolution-office",
  "office-desk",
  "formation-center",
  "greenhouse",
  "corporate-breakroom",
  "union-headquarters",
  "propaganda-distillery",
  "mechanical-printer",
  "printer-t1",
  "printer-t2",
  "chromatic-printer",
  "notary-office",
  "conciliation-desk",
  "digital-services-bureau",
  "laser-printer",
}

local COSMETIC_CRAFTING_MACHINES = {
  "archive-recombination-bureau",
  "territorial-arbitration-post",
  "administrative-space-station",
}

local function append_once(values, value)
  values = values or {}
  for _, existing in ipairs(values) do
    if existing == value then return values end
  end
  values[#values + 1] = value
  return values
end

local function add_administrative_science_once(technology)
  if not technology or not technology.unit then return end
  technology.unit.ingredients = technology.unit.ingredients or {}
  for _, ingredient in ipairs(technology.unit.ingredients) do
    if (ingredient.name or ingredient[1]) == "administrative-science-pack" then
      return
    end
  end
  technology.unit.ingredients[#technology.unit.ingredients + 1] = {
    "administrative-science-pack", 1,
  }
end

local function every_quality_value(value)
  local values = {}
  for _, quality_name in ipairs(QUALITY_NAMES) do
    values[quality_name] = value
  end
  return values
end

local function conventional_machine(raw, name)
  local entity = (raw["assembling-machine"] and raw["assembling-machine"][name])
    or (raw.furnace and raw.furnace[name])
  if not entity then return end
  entity.allowed_effects = append_once(entity.allowed_effects, "quality")
  entity.quality_affects_module_slots = true
  -- Explicitly keep native Quality's no-energy-change rule even if another
  -- prototype pass sets an energy quality table on the source entity.
  entity.quality_affects_energy_usage = false
  entity.energy_usage_quality_multiplier = every_quality_value(1)
end

local function cosmetic_machine(raw, name)
  local entity = (raw["assembling-machine"] and raw["assembling-machine"][name])
    or (raw.furnace and raw.furnace[name])
  if not entity then return end
  entity.crafting_speed_quality_multiplier = every_quality_value(1)
  entity.energy_usage_quality_multiplier = every_quality_value(1)
  entity.quality_affects_module_slots = false
end

function M.apply(data_api)
  local raw = data_api.raw

  for name, ingredients in pairs(QUALITY_MODULE_RECIPES) do
    local recipe = raw.recipe and raw.recipe[name]
    if recipe then
      recipe.category = "bureaucracy-modules"
      recipe.ingredients = ingredients
    end
  end

  for name, config in pairs(CERTIFICATION_TECHS) do
    local technology = raw.technology and raw.technology[name]
    if technology then
      technology.prerequisites = append_once(technology.prerequisites, config.prerequisite)
      add_administrative_science_once(technology)
    end
  end

  for _, name in ipairs(PRODUCTION_FACILITIES) do
    conventional_machine(raw, name)
  end
  for _, name in ipairs(COSMETIC_CRAFTING_MACHINES) do
    cosmetic_machine(raw, name)
  end

  -- Pneumatic hardware remains entirely quality-neutral.  Its runtime still
  -- preserves quality on paperwork stacks passing through the network.
  for _, name in ipairs({"pneumatic-pipe", "pneumatic-pipe-to-ground", "tube-intake", "tube-outtake"}) do
    local recipe = raw.recipe and raw.recipe[name]
    if recipe then recipe.allow_quality = false end
  end
end

return M
