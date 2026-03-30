-- ADMINISTRATORIO: VANILLA OVERRIDES
-- Enforces the administrative paradigm on vanilla content:
--   - Hides military content (items, techs, upgrades)
--   - Pacifies biters and spawners
--   - Replaces military science with administrative science
--   - Integrates admin science into labs
--   - Hides vanilla modules (replaced by subpoena/audit/embezzlement)
--   - Converts furnaces to assembling machines
--   - QoL tweaks (assembler slots, locomotive inventory)
--   - Registers resources for Nauvis map generation
--   - Vanilla recipe hooks (greenhouse, steel batch, production science module swap)

-------------------------------------------------------------------------------
-- HIDE MILITARY CONTENT
-------------------------------------------------------------------------------
local items_to_hide = {
  "pistol", "submachine-gun", "shotgun", "rocket-launcher", "combat-shotgun",
  "flamethrower", "railgun",
  "firearm-magazine", "piercing-rounds-magazine", "uranium-rounds-magazine",
  "shotgun-shell", "piercing-shotgun-shell", "rocket", "explosive-rocket",
  "atomic-bomb", "flamethrower-ammo", "cannon-shell", "explosive-cannon-shell",
  "uranium-cannon-shell", "explosive-uranium-cannon-shell", "artillery-shell",
  "artillery-targeting-remote", "land-mine",
  "grenade", "cluster-grenade", "poison-capsule", "slowdown-capsule",
  "defender-capsule", "distractor-capsule", "destroyer-capsule",
  "gun-turret", "laser-turret", "flamethrower-turret", "artillery-turret",
  "artillery-wagon", "tank", "spidertron",
  "energy-shield-equipment", "energy-shield-mk2-equipment",
  "military-science-pack"
}

local function hide_prototype(category, name)
  if data.raw[category] and data.raw[category][name] then
    data.raw[category][name].enabled = false
    data.raw[category][name].hidden = true
  end
end

for _, name in ipairs(items_to_hide) do
  hide_prototype("item", name)
  hide_prototype("gun", name)
  hide_prototype("tool", name)
  hide_prototype("ammo", name)
  hide_prototype("armor", name)
  hide_prototype("recipe", name)
  hide_prototype("capsule", name)
end

-------------------------------------------------------------------------------
-- DISABLE MILITARY TECHNOLOGIES
-------------------------------------------------------------------------------
local techs_to_disable = {
  "military", "military-2", "military-3", "military-4",
  "military-science-pack",
  "atomic-bomb", "uranium-ammo", "flamethrower", "flammables",
  "personal-laser-defense-equipment", "discharge-defense-equipment",
  "artillery", "tank", "spidertron", "land-mine", "rocketry", "explosive-rocketry",
  "laser", "laser-turret", "gun-turret", "flamethrower-turret",
  "defender", "distractor", "destroyer",
  "energy-shield-equipment", "energy-shield-mk2-equipment"
}

for _, name in ipairs(techs_to_disable) do
  if data.raw["technology"][name] then
    data.raw["technology"][name].enabled = false
    data.raw["technology"][name].hidden = true
  end
end

-- Dynamic purge: catch upgrade techs
for tech_name, tech in pairs(data.raw["technology"]) do
  if tech_name:find("artillery") or tech_name:find("physical%-projectile")
     or tech_name:find("stronger%-explosives") or tech_name:find("refined%-flammables")
     or tech_name:find("energy%-weapons") or tech_name:find("laser%-weapons%-damage")
     or tech_name:find("weapon%-shooting%-speed")
     or tech_name:find("follower%-robot%-count") or tech_name:find("combat%-robot")
     or tech_name:find("laser%-shooting%-speed") or tech_name:find("laser%-turret%-shooting")
     or tech_name:find("turret") then
    tech.enabled = false
    tech.hidden = true
  end
end

-- Rewire the non-combat armor progression away from disabled military gates.
local armor_tech_prerequisite_replacements = {
  ["heavy-armor"] = {
    military = "administrative-bureaucracy",
  },
  ["power-armor-mk2"] = {
    ["military-4"] = "eminent-domain-zoning",
  },
}

for tech_name, replacements in pairs(armor_tech_prerequisite_replacements) do
  local tech = data.raw["technology"][tech_name]
  if tech and tech.prerequisites then
    for i, prereq in ipairs(tech.prerequisites) do
      local replacement = replacements[prereq]
      if replacement then
        tech.prerequisites[i] = replacement
      end
    end
  end
end

-- Remove worm turrets from spawning
for _, worm in pairs(data.raw["turret"]) do
  if worm.name:find("worm") then
    worm.autoplace = nil
  end
end

-- Default enemy starting area to 150% — more room before biters
if data.raw["autoplace-control"] and data.raw["autoplace-control"]["enemy-base"] then
  data.raw["autoplace-control"]["enemy-base"].hidden = false
end

-------------------------------------------------------------------------------
-- PACIFY BITERS & SPAWNERS
-------------------------------------------------------------------------------
for _, entity_type in ipairs({"unit", "unit-spawner"}) do
  for _, entity in pairs(data.raw[entity_type]) do
    if entity.subgroup == "enemies" or entity.name:find("biter")
       or entity.name:find("spitter") or entity.type == "unit-spawner" then
      entity.resistances = {
        {type = "physical", percent = 100},
        {type = "fire", percent = 100},
        {type = "explosion", percent = 100},
        {type = "poison", percent = 100},
        {type = "laser", percent = 100},
        {type = "electric", percent = 100},
        {type = "acid", percent = 100},
        {type = "impact", percent = 100},
        {type = "bureaucratic-logic", percent = -50}
      }
      if entity.attack_parameters and entity.attack_parameters.ammo_type then
        local ammo = entity.attack_parameters.ammo_type
        if ammo.action then
          for _, action in pairs(ammo.action) do
            if action.action_delivery then
              for _, delivery in pairs(action.action_delivery) do
                if delivery.target_effects then
                  for _, effect in pairs(delivery.target_effects) do
                    if effect.type == "damage" then effect.damage.amount = 0 end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end

-------------------------------------------------------------------------------
-- REPLACE MILITARY SCIENCE WITH ADMINISTRATIVE SCIENCE
-------------------------------------------------------------------------------
for _, tech in pairs(data.raw["technology"]) do
  if tech.prerequisites then
    for i, prereq in ipairs(tech.prerequisites) do
      if prereq == "military-science-pack" then
        tech.prerequisites[i] = "administrative-bureaucracy"
      end
    end
  end
  if tech.unit and tech.unit.ingredients then
    for _, ingredient in ipairs(tech.unit.ingredients) do
      if ingredient[1] == "military-science-pack" then
        ingredient[1] = "administrative-science-pack"
      elseif ingredient.name == "military-science-pack" then
        ingredient.name = "administrative-science-pack"
      end
    end
  end
end

-------------------------------------------------------------------------------
-- INTEGRATE ADMIN SCIENCE INTO ALL LABS
-------------------------------------------------------------------------------
for _, lab in pairs(data.raw["lab"]) do
  if lab.inputs then
    local found = false
    for _, input in ipairs(lab.inputs) do
      if input == "administrative-science-pack" then found = true; break end
    end
    if not found then table.insert(lab.inputs, "administrative-science-pack") end
  end
end

-------------------------------------------------------------------------------
-- RENAME & MODIFY VANILLA MODULES
-- Keep vanilla module items and techs, but override recipes with admin
-- ingredients. Locale renames them (speed→subpoena, prod→audit, eff→embezzlement).
-- Add administrative-science-pack to all module tech research costs.
-------------------------------------------------------------------------------
local module_recipe_overrides = {
  ["speed-module"]          = {{type="item", name="basic-excuse", amount=10},          {type="item", name="electronic-circuit", amount=5}},
  ["speed-module-2"]        = {{type="item", name="speed-module", amount=4},           {type="item", name="good-excuse", amount=5},       {type="item", name="advanced-circuit", amount=5}, {type="item", name="taxpayer-money", amount=5}},
  ["speed-module-3"]        = {{type="item", name="speed-module-2", amount=4},         {type="item", name="narrative", amount=5},          {type="item", name="processing-unit", amount=5},  {type="item", name="compacted-rubble", amount=10}, {type="item", name="credentials", amount=1}, {type="item", name="taxpayer-money", amount=10}},
  ["productivity-module"]   = {{type="item", name="dubious-data", amount=10},          {type="item", name="electronic-circuit", amount=5}},
  ["productivity-module-2"] = {{type="item", name="productivity-module", amount=4},    {type="item", name="data", amount=5},               {type="item", name="advanced-circuit", amount=5}, {type="item", name="taxpayer-money", amount=5}},
  ["productivity-module-3"] = {{type="item", name="productivity-module-2", amount=4},  {type="item", name="justification", amount=5},      {type="item", name="processing-unit", amount=5},  {type="item", name="compacted-rubble", amount=10}, {type="item", name="credentials", amount=1}, {type="item", name="taxpayer-money", amount=10}},
  ["efficiency-module"]     = {{type="item", name="crappy-report", amount=10},         {type="item", name="electronic-circuit", amount=5}},
  ["efficiency-module-2"]   = {{type="item", name="efficiency-module", amount=4},      {type="item", name="white-paper", amount=5},        {type="item", name="advanced-circuit", amount=5}, {type="item", name="taxpayer-money", amount=5}},
  ["efficiency-module-3"]   = {{type="item", name="efficiency-module-2", amount=4},    {type="item", name="policy", amount=5},             {type="item", name="processing-unit", amount=5},  {type="item", name="compacted-rubble", amount=10}, {type="item", name="credentials", amount=1}, {type="item", name="taxpayer-money", amount=10}},
}

for name, ingredients in pairs(module_recipe_overrides) do
  local recipe = data.raw["recipe"][name]
  if recipe then
    recipe.category = "bureaucracy-registration"
    recipe.ingredients = ingredients
  end
end

-- Add administrative-science-pack to all module technology research costs
local module_techs = {
  "modules",
  "speed-module", "speed-module-2", "speed-module-3",
  "productivity-module", "productivity-module-2", "productivity-module-3",
  "efficiency-module", "efficiency-module-2", "efficiency-module-3",
}
for _, tech_name in ipairs(module_techs) do
  local tech = data.raw["technology"][tech_name]
  if tech and tech.unit and tech.unit.ingredients then
    local has_admin = false
    for _, ing in ipairs(tech.unit.ingredients) do
      if ing[1] == "administrative-science-pack" or ing.name == "administrative-science-pack" then
        has_admin = true; break
      end
    end
    if not has_admin then
      table.insert(tech.unit.ingredients, {"administrative-science-pack", 1})
    end
  end
end

-- Add admin tech prerequisites to module techs (recipes use admin ingredients)
local module_admin_prereqs = {
  ["efficiency-module"]     = "littering-resolution",
  ["speed-module-2"]        = "industrial-propaganda",
  ["productivity-module-2"] = "industrial-propaganda",
  ["efficiency-module-2"]   = "eminent-domain-zoning",
  ["speed-module-3"]        = "health-and-safety",
  ["productivity-module-3"] = "health-and-safety",
  ["efficiency-module-3"]   = "eminent-domain-zoning",
}
for tech_name, admin_prereq in pairs(module_admin_prereqs) do
  local tech = data.raw["technology"][tech_name]
  if tech then
    if not tech.prerequisites then tech.prerequisites = {} end
    local has_prereq = false
    for _, prereq in ipairs(tech.prerequisites) do
      if prereq == admin_prereq then has_prereq = true; break end
    end
    if not has_prereq then
      table.insert(tech.prerequisites, admin_prereq)
    end
  end
end

local function tech_uses_research_pack(tech, pack_name)
  if not tech or not tech.unit or not tech.unit.ingredients then return false end
  for _, ingredient in ipairs(tech.unit.ingredients) do
    if (ingredient[1] or ingredient.name) == pack_name then
      return true
    end
  end
  return false
end

local function inherit_parent_technology_ingredients()
  local changed = true
  while changed do
    changed = false
    for _, tech in pairs(data.raw["technology"] or {}) do
      if tech.unit and tech.unit.ingredients then
        for _, prereq_name in ipairs(tech.prerequisites or {}) do
          local prereq = data.raw["technology"][prereq_name]
          if prereq and prereq.unit and prereq.unit.ingredients then
            for _, ingredient in ipairs(prereq.unit.ingredients) do
              local pack_name = ingredient[1] or ingredient.name
              if pack_name and not tech_uses_research_pack(tech, pack_name) then
                table.insert(tech.unit.ingredients, {pack_name, ingredient[2] or ingredient.amount or 1})
                changed = true
              end
            end
          end
        end
      end
    end
  end
end

local function dedupe_technology_ingredients()
  for _, tech in pairs(data.raw["technology"] or {}) do
    if tech.unit and tech.unit.ingredients then
      local deduped = {}
      local seen = {}
      for _, ingredient in ipairs(tech.unit.ingredients) do
        local pack_name = ingredient[1] or ingredient.name
        if pack_name and not seen[pack_name] then
          seen[pack_name] = true
          deduped[#deduped + 1] = ingredient
        end
      end
      tech.unit.ingredients = deduped
    end
  end
end

inherit_parent_technology_ingredients()
dedupe_technology_ingredients()

-------------------------------------------------------------------------------
-- CONVERT FURNACES TO ASSEMBLING MACHINES
-------------------------------------------------------------------------------
local furnace_categories = {
  ["stone-furnace"]    = {"smelting-basic"},
  ["steel-furnace"]    = {"smelting-basic"},
  ["electric-furnace"] = {"smelting"},
}

for name, categories in pairs(furnace_categories) do
  local furnace = data.raw["furnace"][name]
  if furnace then
    furnace.type = "assembling-machine"
    furnace.fixed_recipe = nil
    furnace.ingredient_count = 6
    furnace.crafting_categories = categories
    data.raw["assembling-machine"][name] = furnace
    data.raw["furnace"][name] = nil
  end
end

-------------------------------------------------------------------------------
-- ASSEMBLING MACHINE INGREDIENT SLOTS
-------------------------------------------------------------------------------
for _, entity in pairs(data.raw["assembling-machine"] or {}) do
  if not entity.ingredient_count or entity.ingredient_count < 6 then
    entity.ingredient_count = 6
  end
end

-------------------------------------------------------------------------------
-- VANILLA RECIPE HOOKS
-------------------------------------------------------------------------------

-- Greenhouse progression is owned by the Office Agriculture branch.

-- Steel batch smelting with steel-processing
if data.raw["technology"]["steel-processing"] then
  local tech = data.raw["technology"]["steel-processing"]
  if not tech.effects then tech.effects = {} end
  table.insert(tech.effects, {type = "unlock-recipe", recipe = "steel-plate-batch"})
end

-------------------------------------------------------------------------------
-- LOCOMOTIVE PAPERWORK COMPLIANCE
-------------------------------------------------------------------------------
for _, loco in pairs(data.raw["locomotive"]) do
  loco.inventory_size = 1
end

-- KEEP SCIENCE PACKS VISIBLE IN HANDCRAFTING UI
-------------------------------------------------------------------------------
if data.raw["recipe"]["logistic-science-pack"] then
  data.raw["recipe"]["logistic-science-pack"].hide_from_player_crafting = false
end

-------------------------------------------------------------------------------
-- REGISTER RESOURCES FOR NAUVIS MAP GENERATION
-------------------------------------------------------------------------------
if data.raw.planet and data.raw.planet.nauvis then
  local map_gen = data.raw.planet.nauvis.map_gen_settings

  if not map_gen.autoplace_controls then map_gen.autoplace_controls = {} end
  map_gen.autoplace_controls["bullshit-ore"] = map_gen.autoplace_controls["bullshit-ore"] or {}
  map_gen.autoplace_controls["politician-fluid"] = map_gen.autoplace_controls["politician-fluid"] or {}
  map_gen.autoplace_controls["redundant-rubble"] = map_gen.autoplace_controls["redundant-rubble"] or {}

  -- Larger starting area (150% of default) — more room before biters
  map_gen.starting_area = 1.5

  if not map_gen.autoplace_settings then map_gen.autoplace_settings = {} end
  if not map_gen.autoplace_settings.entity then
    map_gen.autoplace_settings.entity = {settings = {}}
  end
  local entity_settings = map_gen.autoplace_settings.entity.settings
  entity_settings["bullshit-ore"] = entity_settings["bullshit-ore"] or {}
  entity_settings["politician-fluid"] = entity_settings["politician-fluid"] or {}
  entity_settings["redundant-rubble"] = entity_settings["redundant-rubble"] or {}
end
