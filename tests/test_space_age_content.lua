-------------------------------------------------------------------------------
-- ADMINISTRATORIO SPACE AGE CONTENT TESTS
-------------------------------------------------------------------------------

local passed, failed, errors = 0, 0, {}

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    errors[#errors + 1] = name .. ": " .. tostring(err)
  end
end

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or "") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function assert_true(value, msg)
  if not value then error(msg or "assertion failed", 2) end
end

local function assert_near(actual, expected, epsilon, msg)
  if math.abs(actual - expected) > (epsilon or 1e-9) then
    error((msg or "") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local recipes = {
  foundry = {
    type = "recipe",
    name = "foundry",
    surface_conditions = {{property = "pressure", min = 4000, max = 4000}},
    ingredients = {{type = "item", name = "steel-plate", amount = 50}},
  },
  ["tungsten-plate"] = {type = "recipe", name = "tungsten-plate", ingredients = {{type = "item", name = "tungsten-ore", amount = 4}}},
  ["tungsten-carbide"] = {type = "recipe", name = "tungsten-carbide", ingredients = {{type = "item", name = "tungsten-plate", amount = 2}}},
  ["casting-low-density-structure"] = {type = "recipe", name = "casting-low-density-structure", ingredients = {{type = "item", name = "plastic-bar", amount = 20}}},
  ["advanced-circuit"] = {type = "recipe", name = "advanced-circuit", ingredients = {{type = "item", name = "electronic-circuit", amount = 2}}},
  ["low-density-structure"] = {type = "recipe", name = "low-density-structure", ingredients = {{type = "item", name = "steel-plate", amount = 10}}},
  ["rocket-control-unit"] = {type = "recipe", name = "rocket-control-unit", ingredients = {{type = "item", name = "processing-unit", amount = 1}}},
  ["rocket-silo"] = {type = "recipe", name = "rocket-silo", ingredients = {{type = "item", name = "steel-plate", amount = 100}}},
  ["space-science-pack"] = {
    type = "recipe",
    name = "space-science-pack",
    enabled = false,
    ingredients = {
      {type = "item", name = "iron-plate", amount = 2},
      {type = "item", name = "carbon", amount = 1},
      {type = "item", name = "ice", amount = 1},
      {type = "item", name = "research-grant-approval", amount = 1},
    },
    results = {{type = "item", name = "space-science-pack", amount = 5}},
  },
  ["molten-iron"] = {type = "recipe", name = "molten-iron", ingredients = {{type = "item", name = "calcite", amount = 1}}},
  ["molten-iron-from-lava"] = {type = "recipe", name = "molten-iron-from-lava", ingredients = {{type = "item", name = "calcite", amount = 1}}},
  ["molten-copper"] = {type = "recipe", name = "molten-copper", ingredients = {{type = "item", name = "calcite", amount = 1}}},
  ["molten-copper-from-lava"] = {type = "recipe", name = "molten-copper-from-lava", ingredients = {{type = "item", name = "calcite", amount = 1}}},
  ["simple-coal-liquefaction"] = {type = "recipe", name = "simple-coal-liquefaction", ingredients = {{type = "item", name = "calcite", amount = 1}}},
  ["acid-neutralisation"] = {
    type = "recipe",
    name = "acid-neutralisation",
    surface_conditions = {{property = "pressure", min = 4000, max = 4000}},
    ingredients = {{type = "item", name = "calcite", amount = 1}},
  },
  ["rocket-fuel-from-jelly"] = {type = "recipe", name = "rocket-fuel-from-jelly", ingredients = {{type = "item", name = "jelly", amount = 1}}},
  ["bioplastic"] = {type = "recipe", name = "bioplastic", ingredients = {{type = "item", name = "bioflux", amount = 1}}},
  ["biosulfur"] = {type = "recipe", name = "biosulfur", ingredients = {{type = "item", name = "bioflux", amount = 1}}},
  ["biolubricant"] = {type = "recipe", name = "biolubricant", ingredients = {{type = "item", name = "bioflux", amount = 1}}},
  biochamber = {type = "recipe", name = "biochamber", surface_conditions = {{property = "pressure", min = 2000, max = 2000}}, ingredients = {{type = "item", name = "iron-plate", amount = 20}}},
  ["electromagnetic-plant"] = {type = "recipe", name = "electromagnetic-plant", surface_conditions = {{property = "pressure", min = 800, max = 800}}, ingredients = {{type = "item", name = "holmium-plate", amount = 150}}},
  ["cryogenic-plant"] = {type = "recipe", name = "cryogenic-plant", surface_conditions = {{property = "pressure", min = 300, max = 300}}, ingredients = {{type = "item", name = "lithium-plate", amount = 20}}},
  ["biter-logistics-formation"] = {
    type = "recipe",
    name = "biter-logistics-formation",
    category = "biter-training",
    enabled = false,
    ingredients = {{type = "item", name = "biter-worker", amount = 1}},
    results = {{type = "item", name = "biter-logistics-formation", amount = 1}},
  },
  ["scrap-recycling"] = {type = "recipe", name = "scrap-recycling", results = {{type = "item", name = "iron-gear-wheel", amount = 1, probability = 0.2}}},
}

local items = {
  ["formation-center"] = {
    type = "item",
    name = "formation-center",
    icon = "__administratorio__/graphics/icons/formation-center.png",
    icon_size = 64,
    subgroup = "admin-biter-buildings",
    order = "d",
    place_result = "formation-center",
    stack_size = 20,
  },
}
local ammos = {}
local fluids = {}
local signals = {}
local technologies = {
  ["space-platform"] = {type = "technology", name = "space-platform", effects = {}},
  ["space-science-pack"] = {
    type = "technology",
    name = "space-science-pack",
    effects = {{type = "unlock-recipe", recipe = "space-science-pack"}},
    prerequisites = {"space-platform"},
  },
  ["space-platform-thruster"] = {type = "technology", name = "space-platform-thruster", effects = {}, prerequisites = {}},
  ["electric-engine"] = {type = "technology", name = "electric-engine", effects = {}},
  ["electric-mining-drill"] = {type = "technology", name = "electric-mining-drill", effects = {}},
  ["repair-pack"] = {type = "technology", name = "repair-pack", effects = {}},
  ["radar"] = {type = "technology", name = "radar", effects = {}},
  ["administrative-science-research"] = {type = "technology", name = "administrative-science-research", effects = {}},
  ["metallurgic-science-pack"] = {type = "technology", name = "metallurgic-science-pack", effects = {}},
  ["foundry"] = {type = "technology", name = "foundry", effects = {{type = "unlock-recipe", recipe = "foundry"}}, prerequisites = {}},
  ["calcite-processing"] = {type = "technology", name = "calcite-processing", effects = {}},
  ["printing-technology"] = {type = "technology", name = "printing-technology", effects = {}},
  ["industrial-propaganda"] = {type = "technology", name = "industrial-propaganda", effects = {}},
  ["corporate-hospitality"] = {type = "technology", name = "corporate-hospitality", effects = {}},
  ["agricultural-science-pack"] = {type = "technology", name = "agricultural-science-pack", effects = {}},
  ["electromagnetic-plant"] = {type = "technology", name = "electromagnetic-plant", effects = {{type = "unlock-recipe", recipe = "electromagnetic-plant"}}, prerequisites = {}},
  ["biochamber"] = {type = "technology", name = "biochamber", effects = {{type = "unlock-recipe", recipe = "biochamber"}}, prerequisites = {}},
  ["big-mining-drill"] = {type = "technology", name = "big-mining-drill", effects = {}, prerequisites = {}},
  ["electromagnetic-science-pack"] = {type = "technology", name = "electromagnetic-science-pack", effects = {}},
  ["cryogenic-plant"] = {type = "technology", name = "cryogenic-plant", effects = {{type = "unlock-recipe", recipe = "cryogenic-plant"}}, prerequisites = {}},
  ["cryogenic-science-pack"] = {type = "technology", name = "cryogenic-science-pack", effects = {}},
  ["advanced-asteroid-processing"] = {type = "technology", name = "advanced-asteroid-processing", effects = {}},
  ["after-hours-operations"] = {type = "technology", name = "after-hours-operations", effects = {}},
  ["discovery-bullshit"] = {type = "technology", name = "discovery-bullshit", effects = {}},
  ["discovery-redundant-rubble"] = {type = "technology", name = "discovery-redundant-rubble", effects = {}},
  ["planet-discovery-gleba"] = {type = "technology", name = "planet-discovery-gleba", effects = {}},
  ["nest-expropriation"] = {type = "technology", name = "nest-expropriation", effects = {}},
  ["hired-biter-fieldwork"] = {type = "technology", name = "hired-biter-fieldwork", effects = {}},
  ["promethium-science-pack"] = {
    type = "technology",
    name = "promethium-science-pack",
    effects = {},
    prerequisites = {"biter-egg-handling", "fusion-reactor"},
    unit = {
      count = 2000,
      ingredients = {
        {"automation-science-pack", 1},
        {"cryogenic-science-pack", 1},
      },
      time = 60,
    },
  },
}

mods = {
  ["space-age"] = "2.0.0",
}

data = {
  raw = {
    recipe = recipes,
    item = items,
    ammo = ammos,
    fluid = fluids,
    ["virtual-signal"] = signals,
    furnace = {
      recycler = {type = "furnace", name = "recycler", result_inventory_size = 12},
    },
    technology = technologies,
  },
}

function data:extend(prototypes)
  for _, proto in ipairs(prototypes) do
    data.raw[proto.type] = data.raw[proto.type] or {}
    data.raw[proto.type][proto.name] = proto
    if proto.type == "recipe" then
      recipes[proto.name] = proto
    elseif proto.type == "item" then
      items[proto.name] = proto
    elseif proto.type == "ammo" then
      ammos[proto.name] = proto
    elseif proto.type == "fluid" then
      fluids[proto.name] = proto
    elseif proto.type == "virtual-signal" then
      signals[proto.name] = proto
    elseif proto.type == "technology" then
      technologies[proto.name] = proto
    end
  end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

local bureaucracy_categories = require("prototypes.shared.bureaucracy_categories")
local manager_couriers = require("prototypes.shared.manager_couriers")

local preexisting_technology_names = {}
for technology_name in pairs(technologies) do
  preexisting_technology_names[technology_name] = true
end

-- job-offer / job-offer-production live in economy.lua (loaded before space_age.lua,
-- matching prototypes/item.lua and prototypes/recipe.lua's real require order).
dofile(mod_root .. "prototypes/item/economy.lua")
dofile(mod_root .. "prototypes/recipe/economy.lua")
dofile(mod_root .. "prototypes/item/space_age.lua")
dofile(mod_root .. "prototypes/item/capsules-and-fluids.lua")
dofile(mod_root .. "prototypes/recipe/space_age.lua")
dofile(mod_root .. "prototypes/recipe/planetary_abundance.lua")
dofile(mod_root .. "prototypes/technology/space_age.lua")
dofile(mod_root .. "prototypes/signals.lua")

local function has_ingredient(recipe, item_name)
  if not recipe or not recipe.ingredients then return false end
  for _, ingredient in ipairs(recipe.ingredients) do
    if (ingredient.name or ingredient[1]) == item_name then
      return true
    end
  end
  return false
end

local function has_icon_layer(prototype, icon_path)
  if not prototype or not prototype.icons then return false end
  for _, layer in ipairs(prototype.icons) do
    if layer.icon == icon_path then return true end
  end
  return false
end

local function has_result(recipe, item_name)
  if not recipe or not recipe.results then return false end
  for _, result in ipairs(recipe.results) do
    if (result.name or result[1]) == item_name then
      return true
    end
  end
  return false
end

local function get_result_amount(recipe, item_name)
  if not recipe or not recipe.results then return nil end
  for _, result in ipairs(recipe.results) do
    if (result.name or result[1]) == item_name then
      return result.amount or result[2]
    end
  end
  return nil
end

local function item_result_count(recipe)
  local count = 0
  if not recipe or not recipe.results then return count end
  for _, result in ipairs(recipe.results) do
    if (result.type or "item") == "item" then
      count = count + 1
    end
  end
  return count
end

local function get_result_probability(recipe, item_name)
  if not recipe or not recipe.results then return nil end
  for _, result in ipairs(recipe.results) do
    if (result.name or result[1]) == item_name then
      return result.probability or 1
    end
  end
  return nil
end

local function tech_unlocks_recipe(technology, recipe_name)
  if not technology or not technology.effects then return false end
  for _, effect in ipairs(technology.effects) do
    if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
      return true
    end
  end
  return false
end

local function tech_has_prerequisite(technology, prerequisite_name)
  for _, prerequisite in ipairs((technology and technology.prerequisites) or {}) do
    if prerequisite == prerequisite_name then return true end
  end
  return false
end

local function tech_uses_pack(technology, pack_name)
  for _, ingredient in ipairs((technology and technology.unit and technology.unit.ingredients) or {}) do
    if (ingredient.name or ingredient[1]) == pack_name then return true end
  end
  return false
end

local function has_fluid_ingredient(recipe, fluid_name)
  if not recipe or not recipe.ingredients then return false end
  for _, ingredient in ipairs(recipe.ingredients) do
    if ingredient.type == "fluid" and ingredient.name == fluid_name then
      return true
    end
  end
  return false
end

local function get_fluid_ingredient_amount(recipe, fluid_name)
  if not recipe or not recipe.ingredients then return nil end
  for _, ingredient in ipairs(recipe.ingredients) do
    if ingredient.type == "fluid" and ingredient.name == fluid_name then
      return ingredient.amount
    end
  end
  return nil
end

local function get_item_ingredient_amount(recipe, item_name)
  if not recipe or not recipe.ingredients then return nil end
  for _, ingredient in ipairs(recipe.ingredients) do
    if (ingredient.type or "item") == "item" and (ingredient.name or ingredient[1]) == item_name then
      return ingredient.amount or ingredient[2]
    end
  end
  return nil
end

local PLANET_SURFACE_CONDITIONS = {
  nauvis = {pressure = 1000, gravity = 10},
  vulcanus = {pressure = 4000, gravity = 40},
  gleba = {pressure = 2000, gravity = 20},
  fulgora = {pressure = 800, gravity = 8},
  aquilo = {pressure = 300, gravity = 15},
}

local function exact_surface_planet(recipe)
  local conditions = recipe and recipe.surface_conditions or nil
  if not conditions then return nil end

  local pressure_min, pressure_max, gravity_min, gravity_max
  for _, condition in ipairs(conditions) do
    if condition.property == "pressure" then
      pressure_min = condition.min
      pressure_max = condition.max
    elseif condition.property == "gravity" then
      gravity_min = condition.min
      gravity_max = condition.max
    end
  end

  for planet_name, properties in pairs(PLANET_SURFACE_CONDITIONS) do
    if pressure_min == properties.pressure
      and pressure_max == properties.pressure
      and gravity_min == properties.gravity
      and gravity_max == properties.gravity
    then
      return planet_name
    end
  end

  return nil
end

local function recipe_allows_planet(recipe, planet_name)
  local properties = assert(PLANET_SURFACE_CONDITIONS[planet_name], "unknown planet " .. tostring(planet_name))
  for _, condition in ipairs((recipe and recipe.surface_conditions) or {}) do
    local value = properties[condition.property]
    if value ~= nil then
      if condition.min ~= nil and value < condition.min then return false end
      if condition.max ~= nil and value > condition.max then return false end
    end
  end
  return true
end

local function tech_depends_on_or_equals(technology_name, prerequisite_name, seen)
  if technology_name == prerequisite_name then return true end
  if not technology_name or not prerequisite_name then return false end
  seen = seen or {}
  if seen[technology_name] then return false end
  seen[technology_name] = true
  for _, parent_name in ipairs((technologies[technology_name] and technologies[technology_name].prerequisites) or {}) do
    if tech_depends_on_or_equals(parent_name, prerequisite_name, seen) then return true end
  end
  return false
end

test("couriers, cannon, waiver, and bureau unlock only after their real inputs", function()
  local couriers = assert(technologies["egg-courier-formation"], "egg courier technology missing")
  assert_true(tech_has_prerequisite(couriers, "agricultural-science-pack"),
    "courier research must follow the agricultural science it consumes")
  assert_true(tech_has_prerequisite(couriers, "biter-egg-handling"),
    "courier recipes must not unlock before a real biter-egg source exists")

  local cannon = assert(technologies["involuntary-relocation"], "relocation cannon technology missing")
  assert_true(tech_has_prerequisite(cannon, "metallurgic-science-pack"),
    "cannon research must follow the metallurgic science it consumes")
  assert_true(tech_has_prerequisite(cannon, "agricultural-science-pack"),
    "cannon research must follow the agricultural science it consumes")
  assert_true(tech_has_prerequisite(cannon, "tungsten-steel"),
    "the cannon must not unlock before its tungsten-plate recipe input")

  local waiver = assert(technologies["unstaffed-operations"], "unstaffed operations technology missing")
  assert_true(tech_has_prerequisite(waiver, "quantum-processor"),
    "the waiver must not unlock before its quantum-processor recipe input")

  local bureau = assert(technologies["synthetic-personnel"], "synthetic personnel technology missing")
  assert_true(tech_has_prerequisite(bureau, "quantum-processor"),
    "the bureau must not unlock before its quantum-processor recipe input")
end)

test("worker-biter exists as the enrolled-to-workforce intermediate", function()
  assert_true(items["job-offer"] ~= nil, "job-offer missing")
  assert_true(items["enrolled-biter"] ~= nil, "enrolled-biter missing")
  assert_true(items["worker-biter"] ~= nil, "worker-biter missing")
  assert_true(recipes["job-offer-production"] ~= nil, "job-offer recipe missing")
  assert_eq(recipes["job-offer-production"].category, "bureaucracy-registration", "job-offer should be drafted through registration bureaucracy")
  assert_true(has_ingredient(recipes["job-offer-production"], "taxpayer-money"), "job-offer should require taxpayer-money")
  assert_true(has_ingredient(recipes["job-offer-production"], "blank-form"), "job-offer should require a blank form")
  assert_true(has_ingredient(recipes["job-offer-production"], "provisional-approval"), "job-offer should require provisional approval")
  assert_true(recipes["worker-biter-formation"] ~= nil, "worker-biter formation recipe missing")
  assert_true(has_ingredient(recipes["worker-biter-formation"], "enrolled-biter"), "worker-biter should come from enrolled-biter")
end)

test("space age keeps the formation center item icon", function()
  assert_eq(items["formation-center"].icon,
    "__administratorio__/graphics/icons/formation-center.png",
    "Space Age should not replace the custom formation center icon")
end)

test("trainee formation consumes worker-biter instead of enrolled-biter directly", function()
  assert_true(has_ingredient(recipes["clerical-trainee-formation"], "worker-biter"), "clerical trainee should require worker-biter")
  assert_true(not has_ingredient(recipes["clerical-trainee-formation"], "enrolled-biter"), "clerical trainee should not require enrolled-biter directly")
  assert_true(has_ingredient(recipes["management-trainee-formation"], "worker-biter"), "management trainee should require worker-biter")
  assert_true(not has_ingredient(recipes["management-trainee-formation"], "enrolled-biter"), "management trainee should not require enrolled-biter directly")
end)

test("workforce formation stays on Nauvis while MMMM briefings work on every planet", function()
  local briefing_count = 0
  local formation_count = 0

  for recipe_name, recipe in pairs(recipes) do
    if recipe.category == "workforce-formation" or recipe.category == "biter-training" then
      assert_true(not has_ingredient(recipe, "taxpayer-money"),
        recipe_name .. " must not use taxpayer money for workforce training")

      local primary_result = recipe.main_product
      if not primary_result and recipe.results and recipe.results[1] then
        primary_result = recipe.results[1].name or recipe.results[1][1]
      end
      local result_item = items[primary_result]
      -- Egg couriers also spoil back into a regular manager, but they are a
      -- distinct second class: sourced from eggs rather than meetings, and
      -- trained only on Nauvis because biter eggs never leave it.
      local is_egg_courier = primary_result ~= nil and manager_couriers.ITEM_SET[primary_result] == true
      local is_manager_briefing = not is_egg_courier
        and result_item
        and result_item.spoil_result == "middle-management-managing-manager"

      if is_manager_briefing then
        briefing_count = briefing_count + 1
        for planet_name in pairs(PLANET_SURFACE_CONDITIONS) do
          assert_true(recipe_allows_planet(recipe, planet_name),
            recipe_name .. " should be usable on " .. planet_name)
        end
      else
        formation_count = formation_count + 1
        assert_eq(exact_surface_planet(recipe), "nauvis",
          recipe_name .. " should form its biter profession on Nauvis")
      end
    end
  end

  assert_eq(briefing_count, 5, "all five MMMM briefings should be recognized")
  assert_true(formation_count >= 9, "the workforce formation audit should cover every profession")
end)

test("every staffed recipe unlock follows the workforce recipe that supplies its staff", function()
  local recipe_unlockers = {}
  for technology_name, technology in pairs(technologies) do
    for _, effect in ipairs(technology.effects or {}) do
      if effect.type == "unlock-recipe" then
        recipe_unlockers[effect.recipe] = recipe_unlockers[effect.recipe] or {}
        table.insert(recipe_unlockers[effect.recipe], technology_name)
      end
    end
  end

  local workforce_producers = {}
  for recipe_name, recipe in pairs(recipes) do
    if recipe.category == "workforce-formation" or recipe.category == "biter-training" then
      local primary_result = recipe.main_product
      if not primary_result and recipe.results and recipe.results[1] then
        primary_result = recipe.results[1].name or recipe.results[1][1]
      end
      if primary_result then
        workforce_producers[primary_result] = workforce_producers[primary_result] or {}
        table.insert(workforce_producers[primary_result], recipe_name)
      end
    end
  end

  local checked = 0
  for consumer_recipe_name, consumer_recipe in pairs(recipes) do
    local consumer_unlockers = recipe_unlockers[consumer_recipe_name]
    -- Hidden payload-validation families exist only so inserters can check what
    -- may enter a building. They are never crafted, so they carry no
    -- progression order to audit.
    if consumer_recipe.hidden then consumer_unlockers = nil end
    if consumer_unlockers then
      for _, ingredient in ipairs(consumer_recipe.ingredients or {}) do
        local ingredient_name = ingredient.name or ingredient[1]
        local producers = workforce_producers[ingredient_name]
        if producers then
          checked = checked + 1
          local available_in_time = false
          for _, consumer_technology in ipairs(consumer_unlockers) do
            for _, producer_recipe_name in ipairs(producers) do
              for _, producer_technology in ipairs(recipe_unlockers[producer_recipe_name] or {}) do
                if tech_depends_on_or_equals(consumer_technology, producer_technology) then
                  available_in_time = true
                end
              end
            end
          end
          assert_true(available_in_time,
            consumer_recipe_name .. " unlocks before its " .. ingredient_name .. " workforce supply")
        end
      end
    end
  end

  assert_true(checked >= 20, "the workforce unlock-order audit should cover staffed formations and buildings")
end)

test("astronaut training unlocks the orbital admin station chain", function()
  local specialized = technologies["specialized-formation"]
  local orbital = technologies["orbital-employment-infrastructure"]
  assert_true(items["astronaut"] ~= nil, "astronaut missing")
  assert_true(items["administrative-space-station"] ~= nil, "administrative-space-station missing")
  assert_true(recipes["astronaut-formation"] ~= nil, "astronaut formation recipe missing")
  assert_true(has_ingredient(recipes["astronaut-formation"], "management-trainee"), "astronaut should require management-trainee")
  assert_true(recipes["administrative-space-station"] ~= nil, "administrative-space-station recipe missing")
  assert_true(has_ingredient(recipes["administrative-space-station"], "astronaut"),
    "administrative-space-station should require astronaut staffing")
  assert_true(tech_unlocks_recipe(specialized, "astronaut-formation"), "specialized-formation should unlock astronaut-formation")
  assert_true(tech_unlocks_recipe(orbital, "administrative-space-station"),
    "orbital-employment-infrastructure should unlock administrative-space-station")
  assert_eq(recipes["administrative-space-station"].surface_conditions[1].max, 0,
    "administrative-space-station should be craftable only in vacuum")
end)

test("vacuum infrastructure uses one dedicated orbital permit", function()
  local worker = technologies["worker-formation"]
  local platform = technologies["space-platform"]
  local permit_name = "orbital-infrastructure-permit"
  local permit_icon = "__administratorio__/graphics/icons/orbital-infrastructure-permit.png"
  local permit_recipe = assert(recipes[permit_name], "orbital infrastructure permit recipe missing")

  assert_true(items[permit_name] ~= nil, "orbital infrastructure permit item missing")
  assert_eq(items[permit_name].subgroup, "forms-permits")
  assert_eq(permit_recipe.category, "bureaucracy-registration")
  assert_eq(permit_recipe.surface_conditions[1].min, 1,
    "orbital permits should be issued outside vacuum and shipped to the platform")
  assert_true(has_ingredient(permit_recipe, "low-density-structure"),
    "orbital permits should require launch-capable infrastructure")
  assert_true(not has_ingredient(permit_recipe, "space-science-pack"),
    "orbital permit issuance must not depend on the first platform's science output")
  assert_true(tech_unlocks_recipe(platform, permit_name),
    "creating a space platform should unlock orbital permit issuance")
  assert_true(not tech_unlocks_recipe(worker, permit_name),
    "worker formation should not delay orbital permit issuance")

  local ordinary_paperwork = {
    "work-order",
    "construction-permit",
    "construction-work-order",
    "management-approval-verbal",
    "management-verbal-work-order",
    "management-approval-written",
    "management-written-work-order",
  }
  for _, recipe_name in ipairs({
    "administrative-space-station",
    "trajectory-compliance-array",
    "senior-trajectory-compliance-array",
    "executive-trajectory-compliance-array",
    "orbital-employment-catapult",
  }) do
    local recipe = assert(recipes[recipe_name], recipe_name .. " missing")
    assert_true(has_ingredient(recipe, permit_name), recipe_name .. " should require the orbital permit")
    for _, paperwork_name in ipairs(ordinary_paperwork) do
      assert_true(not has_ingredient(recipe, paperwork_name),
        recipe_name .. " should not require ordinary paperwork " .. paperwork_name)
    end
    assert_true(not has_icon_layer(items[recipe_name], permit_icon),
      recipe_name .. " icon should not display its orbital permit gate")
  end
end)

test("native Space Age buildings use one canonical construction recipe", function()
  assert_true(has_ingredient(recipes["foundry"], "licensed-notary"), "foundry should require licensed-notary")
  assert_true(has_ingredient(recipes["foundry"], "tungsten-carbide"), "foundry should require tungsten-carbide")
  assert_eq(#recipes["foundry"].surface_conditions, 1, "foundry should retain the single vanilla surface condition")
  assert_eq(recipes["foundry"].surface_conditions[1].property, "pressure", "foundry should retain vanilla pressure gating")
  assert_eq(recipes["foundry"].surface_conditions[1].min, 4000, "foundry should retain vanilla minimum pressure")
  assert_eq(recipes["foundry"].surface_conditions[1].max, 4000, "foundry should retain vanilla maximum pressure")
  assert_true(recipes["foundry-offworld"] == nil, "foundry must not have an offworld construction variant")
  assert_true(has_ingredient(recipes["notary-office"], "licensed-notary"), "notary-office should require licensed-notary")
  assert_true(has_ingredient(recipes["territorial-arbitration-post"], "licensed-notary"),
    "territorial-arbitration-post should require licensed-notary")
  assert_true(has_ingredient(recipes["notary-office"], "tungsten-carbide"), "notary-office should require tungsten-carbide")
  assert_eq(exact_surface_planet(recipes["notary-office"]), "vulcanus", "notary-office should be crafted on Vulcanus")
  assert_true(has_ingredient(recipes["biochamber"], "conciliation-officer"), "biochamber should require conciliation-officer")
  assert_true(has_ingredient(recipes["electromagnetic-plant"], "relay-clerk"), "electromagnetic-plant should require relay-clerk")
  assert_true(has_ingredient(recipes["cryogenic-plant"], "cryoprint-technician"), "cryogenic-plant should require cryoprint-technician")
  for _, recipe_name in ipairs({"foundry", "biochamber", "electromagnetic-plant", "cryogenic-plant", "notary-office"}) do
    assert_true(has_ingredient(recipes[recipe_name], "staffing-briefed-middle-management-managing-manager"),
      recipe_name .. " should require a freshly staffing-briefed MMMM")
    assert_eq(get_result_amount(recipes[recipe_name], "middle-management-managing-manager"), 1,
      recipe_name .. " should return its manager unbriefed")
  end
  assert_true(has_ingredient(recipes["territorial-arbitration-post"],
    "compliance-briefed-middle-management-managing-manager"),
    "territorial arbitration construction should also require compliance oversight")
  assert_eq(get_result_amount(recipes["territorial-arbitration-post"],
    "middle-management-managing-manager"), 2)
end)

test("planetary inks are owned by their own pre-science bootstrap technologies", function()
  local chromatic = technologies["chromatic-printing"]
  local cyan_ink = technologies["cyan-ink-production"]
  local fulgora = technologies["fulgora-salvage-administration"]
  assert_true(chromatic ~= nil, "chromatic-printing missing")
  for _, recipe_name in ipairs({
    "chromatic-printer",
    "liquid-black-ink",
  }) do
    assert_true(tech_unlocks_recipe(chromatic, recipe_name), "chromatic-printing should unlock " .. recipe_name)
  end
  for _, recipe_name in ipairs({
    "cyan-slurry-production",
    "cyan-ink-production",
    "heatproof-form-stock",
    "blank-cyan-form-production",
    "permit-draft",
    "inspection-docket",
  }) do
    assert_true(tech_unlocks_recipe(cyan_ink, recipe_name), "cyan-ink-production should unlock " .. recipe_name)
    assert_true(not tech_unlocks_recipe(fulgora, recipe_name),
      "Fulgora bootstrap should not own Vulcanus recipe " .. recipe_name)
  end
  for _, recipe_name in ipairs({
    "charged-toner",
    "archive-rubble-recovery",
    "archive-documentation-recovery",
    "magenta-ink-production",
    "signal-form-stock",
    "blank-magenta-form-production",
    "archive-recovery-permit",
    "ink-recovery-fulgora",
    "salvaged-data-analysis-fulgora",
    "carbon-offset-certificate-basic-fulgora",
  }) do
    assert_true(tech_unlocks_recipe(fulgora, recipe_name),
      "fulgora-salvage-administration should unlock " .. recipe_name)
    assert_true(not tech_unlocks_recipe(cyan_ink, recipe_name),
      "Vulcanus cyan technology should not own Fulgora recipe " .. recipe_name)
  end
  assert_eq(cyan_ink.research_trigger.type, "mine-entity")
  assert_eq(cyan_ink.research_trigger.entity, "verdigris-crust")
  assert_true(not tech_has_prerequisite(cyan_ink, "metallurgic-science-pack"),
    "cyan ink must precede metallurgic science")
  assert_true(not tech_uses_pack(cyan_ink, "metallurgic-science-pack"),
    "cyan ink must not consume the science pack it bootstraps")
end)

test("vulcanus early bootstrap supplies inputs, not duplicated finished paperwork", function()
  local calcite = technologies["calcite-processing"]
  local propaganda = technologies["industrial-propaganda"]
  assert_true(calcite ~= nil, "calcite-processing missing")
  assert_true(propaganda ~= nil, "industrial-propaganda missing")
  assert_true(tech_unlocks_recipe(calcite, "dubious-data-analysis-vulcanus"), "calcite-processing should unlock dubious-data-analysis-vulcanus")
  assert_true(tech_unlocks_recipe(calcite, "paper-production-vulcanus"), "calcite-processing should unlock paper-production-vulcanus")
  assert_true(tech_unlocks_recipe(calcite, "carbon-offset-certificate-basic-vulcanus"), "calcite-processing should unlock carbon-offset-certificate-basic-vulcanus")
  assert_true(has_ingredient(recipes["carbon-offset-certificate-basic-vulcanus"], "blank-form"),
    "Vulcanus certificates should retain a real paperwork cost")
  assert_eq(recipes["carbon-offset-certificate-basic-vulcanus"].energy_required, 3,
    "Vulcanus certificates should be slower than the canonical bootstrap route")
  assert_true(tech_unlocks_recipe(propaganda, "redundant-rubble-recovery-vulcanus"), "industrial-propaganda should unlock the local rubble bridge")
  assert_eq(get_result_amount(recipes["redundant-rubble-recovery-vulcanus"], "redundant-rubble"), 5,
    "the rubble bridge should make the generic paperwork chain possible")
  assert_eq(recipes["provisional-approval-vulcanus"], nil, "Vulcanus should use the canonical provisional approval recipe")
  assert_eq(recipes["research-grant-approval-vulcanus"], nil, "Vulcanus should use the canonical research grant recipe")
  assert_eq(recipes["administrative-science-pack-production-vulcanus"], nil, "Vulcanus should use the canonical administrative science recipe")
  assert_true(recipes["printer-t1-vulcanus"] == nil, "printer-t1 must keep one canonical recipe")
end)

test("vulcanus certification unlocks local notary gates, not a second paperwork catalogue", function()
  local certification = technologies["vulcanus-certification"]
  assert_true(certification ~= nil, "vulcanus-certification missing")
  for _, recipe_name in ipairs({
    "notary-office",
    "territorial-arbitration-post",
    "embossed-seal",
    "industrial-charter",
    "territorial-resettlement-order",
    "vulcanus-lie-distillation",
  }) do
    assert_true(tech_unlocks_recipe(certification, recipe_name), "vulcanus-certification should unlock " .. recipe_name)
  end
  assert_true(not tech_unlocks_recipe(certification, "thermal-process-license"),
    "vulcanus-certification should no longer unlock thermal-process-license")
  assert_true(not tech_unlocks_recipe(certification, "calcite-reagent-waiver"),
    "vulcanus-certification should no longer unlock calcite-reagent-waiver")
  assert_true(not tech_unlocks_recipe(certification, "offworld-metallurgy-charter"),
    "vulcanus-certification should no longer unlock offworld-metallurgy-charter")
  assert_true(tech_has_prerequisite(certification, "cyan-ink-production"),
    "notary certification should follow the local cyan bootstrap")
  assert_true(tech_has_prerequisite(certification, "tungsten-carbide"),
    "the notary office should follow the local material used to build it")
  assert_true(not tech_has_prerequisite(certification, "metallurgic-science-pack"),
    "the notary needed for the first foundry cannot require metallurgic science")
  assert_true(not tech_uses_pack(certification, "metallurgic-science-pack"),
    "pre-foundry certification cannot consume metallurgic science")
  assert_true(tech_has_prerequisite(technologies["foundry"], "vulcanus-certification"),
    "the first foundry should wait for its required notary formation")
  for _, recipe_name in ipairs({
    "safety-waiver-vulcanus",
    "construction-permit-vulcanus",
    "management-approval-verbal-vulcanus",
    "heatproof-filler-documentation",
    "form-27b-6-vulcanus",
  }) do
    assert_eq(recipes[recipe_name], nil, recipe_name .. " should defer to the canonical paperwork recipe")
  end
end)

test("vulcanus export charters split the later metallurgy paperwork", function()
  local export_charters = technologies["vulcanus-export-charters"]
  assert_true(export_charters ~= nil, "vulcanus-export-charters missing")
  assert_true(export_charters.prerequisites ~= nil, "vulcanus-export-charters should have prerequisites")

  local prerequisite_set = {}
  for _, prerequisite in ipairs(export_charters.prerequisites) do
    prerequisite_set[prerequisite] = true
  end

  assert_true(prerequisite_set["vulcanus-certification"], "vulcanus-export-charters should depend on vulcanus-certification")
  assert_true(prerequisite_set["metallurgic-science-pack"],
    "export paperwork should be the post-metallurgic branch")

  for _, recipe_name in ipairs({
    "thermal-process-license",
    "calcite-reagent-waiver",
    "offworld-metallurgy-charter",
  }) do
    assert_true(tech_unlocks_recipe(export_charters, recipe_name), "vulcanus-export-charters should unlock " .. recipe_name)
  end
end)

test("vulcanus chromatic chain defines the expected fluids and fluid-fed recipes", function()
  assert_true(fluids["liquid-black-ink"] ~= nil, "liquid-black-ink missing")
  assert_true(fluids["cyan-slurry"] ~= nil, "cyan-slurry missing")
  assert_true(fluids["cyan-ink"] ~= nil, "cyan-ink missing")
  assert_true(fluids["liquid-stimulant"] ~= nil, "liquid-stimulant missing")
  assert_true(fluids["molten-promises"] ~= nil, "molten-promises missing")
  assert_true(fluids["yellow-ink"] ~= nil, "yellow-ink missing")
  assert_true(fluids["magenta-ink"] ~= nil, "magenta-ink missing")

  assert_true(has_fluid_ingredient(recipes["heatproof-form-stock"], "cyan-ink"), "heatproof-form-stock should consume cyan-ink")
  assert_true(not has_fluid_ingredient(recipes["heatproof-form-stock"], "sulfuric-acid"), "heatproof-form-stock should stay printer-only")
  assert_true(has_fluid_ingredient(recipes["blank-cyan-form-production"], "cyan-ink"), "blank-cyan-form should consume cyan-ink")
  assert_true(has_fluid_ingredient(recipes["permit-draft"], "cyan-ink"), "permit-draft should consume cyan-ink")
  assert_true(has_fluid_ingredient(recipes["inspection-docket"], "cyan-ink"), "inspection-docket should consume cyan-ink")
  assert_eq(recipes["good-excuse-vulcanus"], nil, "Vulcanus should import finished good excuses")
  assert_eq(recipes["management-approval-written-vulcanus"], nil,
    "Vulcanus should import finished executive approvals")
  assert_eq(recipes["government-grant-vulcanus"], nil, "Vulcanus must not mint Nauvis government grants")
  assert_true(has_fluid_ingredient(recipes["vulcanus-lie-distillation"], "molten-promises"), "lie distillation should consume molten-promises")
end)

test("vulcanus chemistry unlocks local stimulant and paper shortcuts", function()
  local calcite = technologies["calcite-processing"]
  local propaganda = technologies["industrial-propaganda"]
  assert_true(calcite ~= nil, "calcite-processing missing")
  assert_true(propaganda ~= nil, "industrial-propaganda missing")
  for _, recipe_name in ipairs({
    "liquid-stimulant-production",
    "liquid-coffee-vulcanus",
    "plastic-bar-vulcanus",
    "molten-promises-production",
  }) do
    assert_true(tech_unlocks_recipe(calcite, recipe_name), "calcite-processing should unlock " .. recipe_name)
  end
  for _, recipe_name in ipairs({
    "refined-nonsense-production-vulcanus",
  }) do
    assert_true(tech_unlocks_recipe(propaganda, recipe_name), "industrial-propaganda should unlock " .. recipe_name)
  end
  for _, recipe_name in ipairs({
    "liquid-stimulant-production",
    "liquid-coffee-vulcanus",
    "plastic-bar-vulcanus",
  }) do
    assert_true(not has_ingredient(recipes[recipe_name], "chemical-handling-work-order"), recipe_name .. " should stay bootstrap-safe on Vulcanus")
  end
end)

test("vanilla Vulcanus process recipes and restrictions stay untouched", function()
  for _, recipe_name in ipairs({
    "tungsten-plate",
    "tungsten-carbide",
    "molten-iron",
    "molten-iron-from-lava",
    "molten-copper",
    "molten-copper-from-lava",
    "simple-coal-liquefaction",
    "casting-low-density-structure",
  }) do
    assert_true(recipes[recipe_name].surface_conditions == nil,
      recipe_name .. " should retain its unrestricted vanilla recipe prototype")
    assert_true(recipes[recipe_name .. "-offworld"] == nil,
      recipe_name .. " must not gain an offworld clone")
  end
  local neutralisation = recipes["acid-neutralisation"]
  assert_eq(#neutralisation.surface_conditions, 1, "acid-neutralisation should retain one vanilla condition")
  assert_eq(neutralisation.surface_conditions[1].property, "pressure", "acid-neutralisation should retain pressure gating")
  assert_eq(neutralisation.surface_conditions[1].min, 4000, "acid-neutralisation should retain Vulcanus pressure")
  assert_eq(neutralisation.surface_conditions[1].max, 4000, "acid-neutralisation should retain Vulcanus pressure")
  assert_true(recipes["acid-neutralisation-offworld"] == nil,
    "acid-neutralisation must retain its vanilla Vulcanus isolation")
end)

test("workforce progression is split by role and orbital scope", function()
  local worker = technologies["worker-formation"]
  local management = technologies["management-formation"]
  local specialized = technologies["specialized-formation"]
  local orbital = technologies["orbital-employment-infrastructure"]
  local compliance = technologies["orbital-compliance-systems"]
  local chromatic = technologies["chromatic-printing"]
  local metallurgy = technologies["metallurgic-science-pack"]
  local certification = technologies["vulcanus-certification"]
  assert_true(worker ~= nil, "worker-formation missing")
  assert_true(management ~= nil, "management-formation missing")
  assert_true(specialized ~= nil, "specialized-formation missing")
  assert_true(orbital ~= nil, "orbital-employment-infrastructure missing")
  assert_true(compliance ~= nil, "orbital-compliance-systems missing")
  assert_true(tech_unlocks_recipe(worker, "job-offer-production"), "worker-formation should unlock job-offer-production")
  assert_true(tech_unlocks_recipe(worker, "worker-biter-formation"), "worker-formation should unlock worker-biter-formation")
  assert_true(not tech_unlocks_recipe(worker, "clerical-trainee-formation"),
    "worker-formation should not expose clerical training before MMMM briefings exist")
  assert_true(tech_unlocks_recipe(management, "clerical-trainee-formation"),
    "management-formation should unlock clerical trainees with their briefing supply")
  assert_true(tech_unlocks_recipe(management, "management-trainee-formation"), "management-formation should unlock management trainees")
  assert_true(tech_unlocks_recipe(management, "middle-management-training-briefing"),
    "management-formation should unlock the briefings its staff consume")
  assert_true(not tech_unlocks_recipe(specialized, "licensed-notary-formation"),
    "orbital specialist formation should not unlock a Vulcanus profession")
  assert_true(tech_unlocks_recipe(certification, "licensed-notary-formation"),
    "Vulcanus certification should unlock its licensed notary")
  assert_true(tech_unlocks_recipe(specialized, "astronaut-formation"), "specialized-formation should unlock astronaut-formation")
  assert_true(not tech_unlocks_recipe(orbital, "trajectory-compliance-array"),
    "orbital administration should not bundle the base compliance array")
  assert_true(tech_unlocks_recipe(compliance, "trajectory-compliance-array"),
    "orbital compliance systems should unlock the base array")
  assert_true(tech_unlocks_recipe(compliance, "voluntary-exploration-space-miner-formation"),
    "orbital compliance systems should unlock VESM formation")
  assert_true(tech_has_prerequisite(technologies["space-platform"], "electric-engine"),
    "space-platform machinery should follow the electric engines it consumes")
  assert_true(tech_has_prerequisite(technologies["space-science-pack"], "orbital-employment-infrastructure"),
    "space science should follow the station that consumes its imported grant")
  assert_true(tech_has_prerequisite(compliance, "radar"),
    "orbital compliance arrays should follow their non-planetary radar component")
  assert_true(tech_has_prerequisite(compliance, "electric-mining-drill"),
    "orbital miner formation should follow the electric drills it consumes")
  assert_true(tech_has_prerequisite(technologies["space-platform-thruster"], "orbital-compliance-systems"),
    "platform propulsion should follow the separate compliance and catapult systems")
  assert_true(not tech_unlocks_recipe(chromatic, "worker-biter"), "chromatic-printing should not directly unlock worker-biter")
  assert_true(not tech_unlocks_recipe(metallurgy, "licensed-notary-formation"),
    "metallurgic-science-pack should no longer unlock licensed-notary-formation")
  assert_eq(worker.prerequisites[1], "formation-center", "worker formation should require the formation center")
  assert_eq(worker.prerequisites[2], "space-platform", "worker formation should follow the platform bootstrap")
  assert_true(tech_has_prerequisite(worker, "health-and-safety"),
    "worker formation should follow the narrative and excuse supply used by its recipes")
  assert_true(tech_has_prerequisite(management, "eminent-domain-zoning"),
    "management formation should follow the policy supply used by regular MMMMs")
  assert_true(tech_has_prerequisite(management, "repair-pack"),
    "management formation should follow the repair packs used by staffing briefings")
  assert_true(tech_uses_pack(management, "production-science-pack"),
    "management formation should retain the production pack required by its policy prerequisite")
  for _, technology in ipairs({worker, management, specialized, orbital, compliance}) do
    assert_true(not tech_uses_pack(technology, "utility-science-pack"),
      technology.name .. " should not require yellow science before the first administrative station")
    assert_true(not tech_uses_pack(technology, "space-science-pack"),
      technology.name .. " should not require the platform science unlocked downstream")
  end
  for _, planet_gate in ipairs({
    "vulcanus-certification",
    "cyan-yellow-bureaucracy",
    "cyan-magenta-bureaucracy",
    "yellow-magenta-bureaucracy",
  }) do
    assert_true(not tech_has_prerequisite(orbital, planet_gate),
      "basic orbital infrastructure should not require " .. planet_gate)
  end
  for _, planet_pack in ipairs({
    "metallurgic-science-pack",
    "agricultural-science-pack",
    "electromagnetic-science-pack",
    "cryogenic-science-pack",
  }) do
    assert_true(not tech_uses_pack(orbital, planet_pack),
      "basic orbital infrastructure should not consume " .. planet_pack)
  end
end)

test("obsolete field-agent paperwork recipes are removed with duplicate Space Age roles", function()
  assert_true(recipes["overtime-exemption-staffed"] == nil, "staffed overtime recipe should be removed")
  assert_true(recipes["night-shift-supervisor-formation"] == nil, "night-shift supervisor should be removed")
  assert_true(recipes["field-negotiator-formation"] == nil, "field negotiator should be removed")

  assert_true(recipes["promise-production-negotiated"] == nil, "negotiated promise recipe should be removed")
  assert_true(recipes["eviction-notice-production-negotiated"] == nil, "negotiated eviction recipe should be removed")
  assert_true(not tech_unlocks_recipe(technologies["hired-biter-fieldwork"], "promise-production-negotiated"),
    "hired-biter-fieldwork should not unlock the removed negotiated promise")
  assert_true(not tech_unlocks_recipe(technologies["hired-biter-fieldwork"], "eviction-notice-production-negotiated"),
    "hired-biter-fieldwork should not unlock the removed negotiated eviction")
end)

test("MMMM meetings cheaply brief one reusable manager on any planet", function()
  local manager = assert(items["middle-management-managing-manager"], "regular MMMM missing")
  assert_eq(manager.type, "item")
  assert_eq(manager.stack_size, 20)

  local briefing_specs = {
    training = {material = "iron-gear-wheel", amount = 1},
    staffing = {material = "repair-pack", amount = 1},
    compliance = {material = "blank-form", amount = 1},
    liaison = {material = "electronic-circuit", amount = 1},
    orbital = {material = "rocket-fuel", amount = 1},
  }
  local management = technologies["management-formation"]

  for key, spec in pairs(briefing_specs) do
    local item_name = key .. "-briefed-middle-management-managing-manager"
    local recipe_name = "middle-management-" .. key .. "-briefing"
    local briefed = assert(items[item_name], item_name .. " missing")
    local meeting = assert(recipes[recipe_name], recipe_name .. " missing")
    assert_eq(briefed.stack_size, 5)
    assert_eq(briefed.spoil_ticks, 3 * 60 * 60)
    assert_eq(briefed.spoil_result, "middle-management-managing-manager")
    assert_eq(meeting.energy_required, 5)
    assert_eq(meeting.allow_productivity, false)
    assert_eq(get_item_ingredient_amount(meeting, "middle-management-managing-manager"), 1)
    assert_true(not has_ingredient(meeting, "taxpayer-money"), recipe_name .. " should be cashless")
    assert_eq(get_item_ingredient_amount(meeting, spec.material), spec.amount)
    assert_eq(get_fluid_ingredient_amount(meeting, "liquid-coffee"), 5)
    assert_eq(get_result_amount(meeting, item_name), 1)
    for planet_name in pairs(PLANET_SURFACE_CONDITIONS) do
      assert_true(recipe_allows_planet(meeting, planet_name), recipe_name .. " should work on " .. planet_name)
    end
    assert_true(tech_unlocks_recipe(management, recipe_name), recipe_name .. " should unlock with management formation")
  end

  local expected_formations = {
    ["clerical-trainee-formation"] = {"training"},
    ["astronaut-formation"] = {"training", "orbital"},
    ["licensed-notary-formation"] = {"training", "compliance"},
    ["conciliation-officer-formation"] = {"training", "liaison"},
    ["relay-clerk-formation"] = {"training", "liaison"},
    ["cryoprint-technician-formation"] = {"training", "compliance"},
  }
  for recipe_name, keys in pairs(expected_formations) do
    local recipe = assert(recipes[recipe_name])
    for _, key in ipairs(keys) do
      assert_true(has_ingredient(recipe, key .. "-briefed-middle-management-managing-manager"),
        recipe_name .. " should require its " .. key .. " briefing")
    end
    assert_eq(get_result_amount(recipe, "middle-management-managing-manager"), #keys,
      recipe_name .. " should return every manager unbriefed")
  end
end)

test("deviation paperwork and VESM catapult are distinct orbital systems", function()
  local miner = assert(ammos["voluntary-exploration-space-miner"], "VESM ammo missing")
  assert_eq(miner.type, "ammo")
  assert_eq(miner.ammo_category, "orbital-biter-ballistics", "VESM should feed the deployment catapult")
  assert_eq(miner.magazine_size, 1, "one VESM should power exactly one orbital sortie")
  local deliveries = miner.ammo_type.action.action_delivery
  local projectile_delivery
  local has_launch_reservation = false
  for _, delivery in ipairs(deliveries) do
    if delivery.type == "projectile" then
      projectile_delivery = delivery
    elseif delivery.type == "instant" then
      for _, effect in ipairs(delivery.target_effects or {}) do
        if effect.type == "script"
          and effect.effect_id == "administratorio-asteroid-biter-launched"
          and effect.affects_target == true
        then
          has_launch_reservation = true
        end
      end
    end
  end
  assert_true(projectile_delivery ~= nil, "VESM projectile delivery missing")
  assert_eq(projectile_delivery.projectile, "orbital-biter-projectile")
  assert_eq(projectile_delivery.starting_speed, 0.36,
    "VESM projectiles should cross the catapult corridor promptly")
  assert_true(has_launch_reservation,
    "miner deployment catapult should reserve the exact asteroid when the projectile launches")

  local formation = assert(recipes["voluntary-exploration-space-miner-formation"], "VESM formation missing")
  assert_true(has_ingredient(formation, "astronaut"))
  assert_true(has_ingredient(formation, "electric-mining-drill"))
  assert_true(has_ingredient(formation, "training-briefed-middle-management-managing-manager"))
  assert_true(has_ingredient(formation, "compliance-briefed-middle-management-managing-manager"))
  assert_true(has_ingredient(formation, "orbital-briefed-middle-management-managing-manager"))
  assert_eq(get_result_amount(formation, "voluntary-exploration-space-miner"), 1)
  assert_eq(get_result_amount(formation, "middle-management-managing-manager"), 3)
  assert_true(tech_unlocks_recipe(technologies["orbital-compliance-systems"], formation.name))

  local deviation = assert(ammos["orbital-deviation-order"], "deviation order ammo missing")
  assert_eq(deviation.ammo_category, "trajectory-compliance")
  assert_eq(deviation.magazine_size, 1)
  local deviation_delivery = deviation.ammo_type.action.action_delivery
  assert_eq(deviation_delivery.type, "instant")
  assert_eq(deviation_delivery.target_effects[1].type, "script")
  assert_eq(deviation_delivery.target_effects[1].effect_id, "administratorio-trajectory-deviation")
  assert_eq(deviation_delivery.target_effects[1].affects_target, true)

  assert_true(recipes["trajectory-compliance-array"] ~= nil, "trajectory compliance array recipe missing")
  assert_true(tech_unlocks_recipe(technologies["orbital-compliance-systems"], "trajectory-compliance-array"),
    "orbital compliance systems should unlock the compliance array")
  assert_true(items["orbital-employment-catapult"] ~= nil, "orbital employment catapult item missing")
  assert_true(recipes["orbital-employment-catapult"] ~= nil, "orbital employment catapult recipe missing")
  assert_true(tech_unlocks_recipe(technologies["orbital-compliance-systems"], "orbital-employment-catapult"),
    "orbital compliance systems should unlock the employment catapult")

  local senior_recipe = assert(recipes["senior-trajectory-compliance-array"], "senior array recipe missing")
  local executive_recipe = assert(recipes["executive-trajectory-compliance-array"], "executive array recipe missing")
  assert_true(items["senior-trajectory-compliance-array"] ~= nil, "senior array item missing")
  assert_true(items["executive-trajectory-compliance-array"] ~= nil, "executive array item missing")
  assert_true(has_ingredient(senior_recipe, "trajectory-compliance-array"), "senior array should upgrade the junior array")
  assert_true(has_ingredient(senior_recipe, "tungsten-carbide"), "senior array should require Vulcanus hardware")
  assert_true(has_ingredient(senior_recipe, "carbon-fiber"), "senior array should require Gleba hardware")
  assert_true(has_ingredient(senior_recipe, "supercapacitor"), "senior array should require Fulgora hardware")
  assert_true(has_ingredient(executive_recipe, "senior-trajectory-compliance-array"),
    "executive array should upgrade the senior array")
  assert_true(has_ingredient(executive_recipe, "quantum-processor"),
    "executive array should require pre-Promethium quantum processing")

  local senior_tech = assert(technologies["trajectory-compliance-jurisdiction-2"], "senior jurisdiction missing")
  local executive_tech = assert(technologies["trajectory-compliance-jurisdiction-3"], "executive jurisdiction missing")
  assert_true(tech_unlocks_recipe(senior_tech, "senior-trajectory-compliance-array"))
  assert_true(tech_unlocks_recipe(executive_tech, "executive-trajectory-compliance-array"))
  local has_quantum_prerequisite = false
  for _, prerequisite in ipairs(executive_tech.prerequisites or {}) do
    if prerequisite == "quantum-processor" then has_quantum_prerequisite = true end
  end
  assert_true(has_quantum_prerequisite, "huge-asteroid jurisdiction must unlock through quantum processing")
  for _, ingredient in ipairs(executive_tech.unit.ingredients or {}) do
    assert_true((ingredient.name or ingredient[1]) ~= "promethium-science-pack",
      "Promethium-capable hardware cannot require Promethium science")
  end
end)

test("returning employees need no intermediate inventory item or burnout path", function()
  assert_true(items["burned-out-manager"] == nil, "random burnout item should be removed")
  assert_true(recipes["burned-out-manager-rehabilitation"] == nil, "burnout rehabilitation should be removed")
  assert_true(not tech_unlocks_recipe(technologies["worker-formation"], "burned-out-manager-rehabilitation"))
  assert_true(items["returning-orbital-employee"] == nil,
    "collector should mine the chunk straight into VESM ammo, not an intermediate item")
end)

test("orbital admin station closes the basic asteroid paperwork loop without consuming staff", function()
  local orbital = technologies["orbital-employment-infrastructure"]
  for _, recipe_name in ipairs({
    "orbital-paper-production",
    "orbital-ink-production",
    "orbital-operations-form",
    "asteroid-processing-docket",
  }) do
    local recipe = assert(recipes[recipe_name], recipe_name .. " missing")
    assert_eq(recipe.category, "orbital-bureaucracy", recipe_name .. " should use orbital-bureaucracy")
    assert_eq(recipe.surface_conditions[1].max, 0, recipe_name .. " should stay vacuum-only")
    assert_true(not has_ingredient(recipe, "astronaut"), recipe_name .. " should use the station's permanent astronaut")
    assert_true(not has_ingredient(recipe, "orbital-briefed-middle-management-managing-manager"),
      recipe_name .. " should not consume recurring staff")
    assert_true(tech_unlocks_recipe(orbital, recipe_name), "orbital infrastructure should unlock " .. recipe_name)
  end
  assert_true(items["orbital-operations-form"] ~= nil, "orbital-operations-form missing")
  assert_true(items["asteroid-processing-docket"] ~= nil, "asteroid-processing-docket missing")
  assert_eq(recipes["space-science-pack"].category, "orbital-bureaucracy",
    "the Administrative Space Station should craft the one native space-science recipe")
  assert_true(has_ingredient(recipes["space-science-pack"], "research-grant-approval"),
    "space science should consume the ordinary research approval shipped from a planet")
  assert_eq(get_result_amount(recipes["space-science-pack"], "space-science-pack"), 5,
    "one imported research approval should authorize the native five-pack batch")
  assert_true(recipes["space-science-pack-orbital"] == nil,
    "Administratorio must not duplicate Space Age's native space-science recipe")
  assert_true(not tech_unlocks_recipe(orbital, "orbital-deviation-order"),
    "routine deviation ammo belongs to the separate compliance technology")
  assert_true(tech_unlocks_recipe(technologies["orbital-compliance-systems"], "orbital-deviation-order"),
    "orbital compliance systems should unlock routine deviation ammo")
  assert_eq(get_result_amount(recipes["orbital-deviation-order"], "orbital-deviation-order"), 8,
    "one local operations form should issue eight routine deviation orders")

  local forbidden = {
    ["bullshit-ore"] = true,
    ["redundant-rubble"] = true,
    ["compacted-rubble"] = true,
    ["useless-documentation"] = true,
    ["dubious-data"] = true,
    ["blank-form"] = true,
    ["blank-approval"] = true,
    ["transit-authorization"] = true,
    ["chemical-handling-work-order"] = true,
  }
  for _, recipe_name in ipairs({
    "orbital-paper-production",
    "orbital-ink-production",
    "orbital-operations-form",
    "orbital-deviation-order",
    "asteroid-processing-docket",
    "thermal-process-license-orbital",
    "calcite-reagent-waiver-orbital",
    "offworld-metallurgy-charter-orbital",
  }) do
    for _, ingredient in ipairs(recipes[recipe_name].ingredients or {}) do
      assert_true(not forbidden[ingredient.name or ingredient[1]],
        recipe_name .. " should not inherit terrestrial rubble/nonsense paperwork")
    end
  end
end)

test("advanced asteroid outputs feed tier-two orbital administration", function()
  local advanced = technologies["advanced-asteroid-processing"]
  local expected = {
    ["orbital-archival-paper-production"] = {"carbon", "calcite"},
    ["orbital-secure-ink-production"] = {"carbon", "copper-ore", "sulfur"},
    ["orbital-operations-form-copying"] = {"copper-ore"},
    ["asteroid-processing-docket-copying"] = {"calcite"},
    ["priority-orbital-deviation-order"] = {"copper-ore", "sulfur", "calcite"},
  }
  for recipe_name, ingredient_names in pairs(expected) do
    local recipe = assert(recipes[recipe_name], recipe_name .. " missing")
    assert_eq(recipe.surface_conditions[1].max, 0, recipe_name .. " should stay vacuum-only")
    assert_true(tech_unlocks_recipe(advanced, recipe_name),
      "advanced asteroid processing should unlock " .. recipe_name)
    for _, ingredient_name in ipairs(ingredient_names) do
      assert_true(has_ingredient(recipe, ingredient_name),
        recipe_name .. " should consume advanced asteroid output " .. ingredient_name)
    end
  end
  assert_eq(recipes["orbital-operations-form-copying"].category, "orbital-printing")
  assert_eq(recipes["priority-orbital-deviation-order"].category, "orbital-printing")
  assert_eq(get_result_amount(recipes["orbital-operations-form-copying"], "orbital-operations-form"), 16,
    "tier-two form copying should substantially outperform direct printing")
  assert_eq(get_result_amount(recipes["asteroid-processing-docket-copying"], "asteroid-processing-docket"), 10,
    "tier-two docket copying should substantially outperform direct printing")
  assert_true(ammos["priority-orbital-deviation-order"] ~= nil, "priority deviation ammo missing")
end)

test("trajectory compliance speed research reaches every exact cooldown", function()
  local expected_seconds = {4.5, 4.0, 3.5, 3.0, 2.5, 2.0, 1.5, 1.0, 0.5}
  local expected_counts = {200, 350, 550, 800, 1000, 1500, 2250, 3000, 4000}
  local cumulative_modifier = 0

  local function has_pack(technology, pack_name)
    for _, ingredient in ipairs(technology.unit.ingredients or {}) do
      if (ingredient.name or ingredient[1]) == pack_name then return true end
    end
    return false
  end

  for level, seconds in ipairs(expected_seconds) do
    local technology = assert(technologies["trajectory-compliance-speed-" .. level], "speed tier missing")
    assert_eq(technology.unit.count, expected_counts[level], "unexpected research count at tier " .. level)
    local speed_effect
    for _, effect in ipairs(technology.effects or {}) do
      if effect.type == "gun-speed" and effect.ammo_category == "trajectory-compliance" then
        speed_effect = effect
      end
    end
    assert_true(speed_effect ~= nil, "gun-speed effect missing at tier " .. level)
    cumulative_modifier = cumulative_modifier + speed_effect.modifier
    assert_near(300 / (1 + cumulative_modifier), seconds * 60, 1e-9,
      "cooldown mismatch at tier " .. level)

    if level >= 5 then
      assert_true(has_pack(technology, "metallurgic-science-pack"), "tier " .. level .. " should use metallurgic science")
      assert_true(has_pack(technology, "agricultural-science-pack"), "tier " .. level .. " should use agricultural science")
      assert_true(has_pack(technology, "electromagnetic-science-pack"), "tier " .. level .. " should use electromagnetic science")
    end
    assert_eq(has_pack(technology, "cryogenic-science-pack"), level >= 8,
      "cryogenic gating mismatch at tier " .. level)
    assert_eq(has_pack(technology, "promethium-science-pack"), level >= 9,
      "promethium gating mismatch at tier " .. level)
  end
end)

test("orbital employment damage research scales by 50 percent through late science", function()
  local expected_counts = {350, 600, 1200, 2200, 4000}
  for level, count in ipairs(expected_counts) do
    local technology = assert(technologies["orbital-employment-damage-" .. level], "damage tier missing")
    assert_eq(technology.unit.count, count)
    local damage_effect
    for _, effect in ipairs(technology.effects or {}) do
      if effect.type == "ammo-damage" and effect.ammo_category == "orbital-biter-ballistics" then
        damage_effect = effect
      end
    end
    assert_true(damage_effect ~= nil, "biter ammo damage effect missing at tier " .. level)
    assert_eq(damage_effect.modifier, 0.5)
    local description_effect
    for _, effect in ipairs(technology.effects or {}) do
      if effect.type == "nothing" then description_effect = effect end
    end
    assert_eq(description_effect.effect_description[2], tostring(125 * (1 + level * 0.5)))
  end
end)

test("orbital staffing capacity grows from two through five VESMs", function()
  local function technology_has_pack(technology, pack_name)
    for _, ingredient in ipairs(technology.unit.ingredients or {}) do
      if (ingredient.name or ingredient[1]) == pack_name then return true end
    end
    return false
  end

  local expected_counts = {500, 1500, 3000, 6000}
  for level, count in ipairs(expected_counts) do
    local technology = assert(technologies["orbital-employment-capacity-" .. level],
      "staffing capacity tier missing")
    assert_eq(technology.unit.count, count)

    local description_effect
    for _, effect in ipairs(technology.effects or {}) do
      if effect.type == "nothing" then description_effect = effect end
    end
    assert_true(description_effect ~= nil, "capacity description effect missing at tier " .. level)
    assert_eq(description_effect.effect_description[2], tostring(level + 1))

    assert_eq(technology_has_pack(technology, "metallurgic-science-pack"), level >= 2,
      "metallurgic capacity gating mismatch")
    assert_eq(technology_has_pack(technology, "agricultural-science-pack"), level >= 2,
      "agricultural capacity gating mismatch")
    assert_eq(technology_has_pack(technology, "electromagnetic-science-pack"), level >= 2,
      "electromagnetic capacity gating mismatch")
    assert_eq(technology_has_pack(technology, "cryogenic-science-pack"), level >= 3,
      "cryogenic capacity gating mismatch")
    assert_eq(technology_has_pack(technology, "promethium-science-pack"), level >= 4,
      "Promethium capacity gating mismatch")
  end
end)

test("orbital employee return has no random recovery research", function()
  for level = 1, 9 do
    assert_true(technologies["orbital-employment-recovery-" .. level] == nil,
      "obsolete recovery tier should not exist: " .. level)
  end
end)

test("gleba conciliation unlocks the yellow chain and gleba specialist buildings", function()
  local gleba = technologies["gleba-conciliation"]
  assert_true(gleba ~= nil, "gleba-conciliation missing")
  for _, recipe_name in ipairs({
    "capture-bureau",
    "conciliation-desk",
    "yellow-ink-production",
    "mycelial-form-stock",
    "blank-yellow-form-production",
    "symbiosis-record",
    "conciliation-order",
    "management-approval-written-gleba",
    "composted-rubble-recovery-gleba",
  }) do
    assert_true(tech_unlocks_recipe(gleba, recipe_name), "gleba-conciliation should unlock " .. recipe_name)
  end
  assert_true(tech_unlocks_recipe(gleba, "capture-bureau-pentapod-eggs"),
    "gleba-conciliation should unlock egg harvesting before agricultural science")
  assert_true(tech_unlocks_recipe(gleba, "conciliation-officer-formation"),
    "gleba-conciliation should unlock the specialist required by the Capture Bureau")
  assert_true(technologies["gleba-pentapod-formations"] == nil,
    "Gleba should not add a post-agricultural duplicate officer-formation technology")
  assert_true(recipes["conciliation-officer-formation-gleba"] == nil,
    "specific biter professions should not gain an off-world formation recipe")
  local has_amber_sap_processing = false
  for _, prerequisite in ipairs(gleba.prerequisites or {}) do
    has_amber_sap_processing = has_amber_sap_processing or prerequisite == "amber-sap-processing"
  end
  assert_true(not tech_has_prerequisite(gleba, "agricultural-science-pack"),
    "the Capture Bureau bootstrap must precede agricultural science")
  assert_true(not tech_uses_pack(gleba, "agricultural-science-pack"),
    "Gleba conciliation must not consume the pack whose eggs it bootstraps")
  assert_true(tech_has_prerequisite(technologies["biochamber"], "gleba-conciliation"),
    "the Biochamber should follow the officer and egg-harvest system in its own recipe")
  assert_true(has_amber_sap_processing,
    "gleba-conciliation should follow the local amber sap discovery")
end)

test("mining amber sap unlocks Gleba bootstrap recipes", function()
  local technology = assert(technologies["amber-sap-processing"], "amber-sap-processing missing")
  assert_eq(technology.research_trigger.type, "mine-entity",
    "amber-sap-processing should use a resource discovery trigger")
  assert_eq(technology.research_trigger.entity, "amber-sap-seep",
    "amber-sap-processing should trigger from mining the amber sap seep")
  assert_eq(technology.prerequisites[1], "planet-discovery-gleba",
    "amber-sap-processing should remain behind arrival on Gleba")

  for _, recipe_name in ipairs({
    "amber-sap-nonsense-seeding",
    "ink-production-gleba",
    "carbon-offset-certificate-basic-gleba",
    "provisional-approval-cultivation-gleba",
    "construction-permit-gleba",
  }) do
    local recipe = assert(recipes[recipe_name], recipe_name .. " missing")
    assert_eq(recipe.enabled, false, recipe_name .. " must not start unlocked")
    assert_true(tech_unlocks_recipe(technology, recipe_name),
      "amber-sap-processing should unlock " .. recipe_name)
  end

  assert_true(not tech_unlocks_recipe(technologies["discovery-bullshit"],
    "provisional-approval-cultivation-gleba"),
    "Nauvis bullshit discovery must not reveal Gleba cultivation")
  assert_true(not tech_unlocks_recipe(technologies["corporate-hospitality"],
    "construction-permit-gleba"),
    "Nauvis hospitality research must not reveal Gleba construction permits")
end)

test("field office categories never claim planet-local recipes", function()
  local field_office_categories = {}
  for _, category in ipairs(bureaucracy_categories.field_office()) do
    field_office_categories[category] = true
  end

  local office_desk_categories = {}
  for _, category in ipairs(bureaucracy_categories.office_desk(true)) do
    office_desk_categories[category] = true
  end

  local planet_category_owner = {}
  for _, planet_name in ipairs(bureaucracy_categories.OFFWORLD_PLANETS) do
    local bootstrap = bureaucracy_categories.bootstrap_for_planet(planet_name)
    local registration = bureaucracy_categories.registration_for_planet(planet_name)
    planet_category_owner[bootstrap] = planet_name
    planet_category_owner[registration] = planet_name
    assert_true(office_desk_categories[bootstrap], "office desk missing " .. bootstrap)
    assert_true(office_desk_categories[registration], "office desk missing " .. registration)
    assert_true(not field_office_categories[bootstrap], "field office must not support " .. bootstrap)
    assert_true(not field_office_categories[registration], "field office must not support " .. registration)
  end

  for recipe_name, recipe in pairs(recipes) do
    local planet_name = exact_surface_planet(recipe)
    if planet_name and planet_name ~= "nauvis" then
      assert_true(not field_office_categories[recipe.category or "crafting"],
        recipe_name .. " on " .. planet_name .. " leaks into a Field Office category")

      local category_owner = planet_category_owner[recipe.category]
      if category_owner then
        assert_eq(category_owner, planet_name,
          recipe_name .. " uses a bureaucracy category belonging to another planet")
        assert_eq(recipe.enabled, false,
          recipe_name .. " is planet-local bureaucracy and must have an explicit discovery unlock")
      end
    end
  end
end)

test("gleba yellow paperwork gates orbital spitter tourism with two-color forms", function()
  local gleba = technologies["gleba-conciliation"]
  local expected = {
    {
      package_item = "small-spitter-tourism-package",
      tourist_item = "small-space-tourist",
      tourism_recipe = "small-spitter-space-tourism",
      jettison_recipe = "small-space-tourist-jettison",
      bond_payout = 2,
    },
    {
      package_item = "medium-spitter-tourism-package",
      tourist_item = "medium-space-tourist",
      tourism_recipe = "medium-spitter-space-tourism",
      jettison_recipe = "medium-space-tourist-jettison",
      bond_payout = 4,
    },
    {
      package_item = "big-spitter-tourism-package",
      tourist_item = "big-space-tourist",
      tourism_recipe = "big-spitter-space-tourism",
      jettison_recipe = "big-space-tourist-jettison",
      bond_payout = 9,
    },
    {
      package_item = "behemoth-spitter-tourism-package",
      tourist_item = "behemoth-space-tourist",
      tourism_recipe = "behemoth-spitter-space-tourism",
      jettison_recipe = "behemoth-space-tourist-jettison",
      bond_payout = 24,
    },
  }

  for _, variant in ipairs(expected) do
    assert_true(items[variant.package_item] ~= nil, variant.package_item .. " missing")
    assert_true(items[variant.tourist_item] ~= nil, variant.tourist_item .. " missing")

    local tourism_recipe = assert(recipes[variant.tourism_recipe], variant.tourism_recipe .. " missing")
    assert_eq(tourism_recipe.category, "orbital-bureaucracy", variant.tourism_recipe .. " should use orbital-bureaucracy")
    assert_eq(tourism_recipe.surface_conditions[1].max, 0, variant.tourism_recipe .. " should stay vacuum-only")
    assert_true(has_ingredient(tourism_recipe, variant.package_item), variant.tourism_recipe .. " should consume the packaged spitter")
    assert_true(not has_ingredient(tourism_recipe, "astronaut"), variant.tourism_recipe .. " should use permanent station staff")
    assert_true(has_ingredient(tourism_recipe, "orbital-operations-form"), variant.tourism_recipe .. " should use local orbital paperwork")
    assert_true(not has_ingredient(tourism_recipe, "transit-authorization"), variant.tourism_recipe .. " should not import terrestrial paperwork")
    assert_true(not has_ingredient(tourism_recipe, "cyan-yellow-form"), variant.tourism_recipe .. " should not require cyan-yellow-form directly in orbit")
    assert_true(has_result(tourism_recipe, variant.tourist_item), variant.tourism_recipe .. " should emit a paid tourist")
    assert_eq(get_result_amount(tourism_recipe, "treasury-bond"), variant.bond_payout,
      variant.tourism_recipe .. " should pay the expected bond amount")
    assert_true(not has_result(tourism_recipe, "government-grant"),
      variant.tourism_recipe .. " should not award megaproject grants")
    assert_true(not has_result(tourism_recipe, "taxpayer-money"),
      variant.tourism_recipe .. " should not mint loose taxpayer money in orbit")
    assert_true(tech_unlocks_recipe(technologies["cyan-yellow-bureaucracy"], variant.tourism_recipe), "cyan-yellow-bureaucracy should unlock " .. variant.tourism_recipe)

    assert_true(recipes[variant.jettison_recipe] == nil, variant.jettison_recipe .. " should be removed")
    assert_true(not tech_unlocks_recipe(technologies["cyan-yellow-bureaucracy"], variant.jettison_recipe),
      "cyan-yellow-bureaucracy should not unlock tourist conversion")
  end
end)

test("capture bureau mode recipes split by surface and role", function()
  local workforce = assert(recipes["capture-bureau-workforce"], "capture-bureau-workforce missing")
  local tourism = assert(recipes["capture-bureau-tourism"], "capture-bureau-tourism missing")
  local pentapods = assert(recipes["capture-bureau-pentapod-eggs"], "capture-bureau-pentapod-eggs missing")
  local spore_base = assert(recipes["hostile-spore-culture-production"], "hostile-spore-culture-production missing")
  local workforce_spores = assert(recipes["workforce-lure-spores-production"], "workforce-lure-spores-production missing")
  local tourism_spores = assert(recipes["tourism-lure-spores-production"], "tourism-lure-spores-production missing")
  local egg_spores = assert(recipes["oviposition-lure-spores-production"], "oviposition-lure-spores-production missing")
  local cyan_yellow = technologies["cyan-yellow-bureaucracy"]

  assert_eq(workforce.category, "hostile-acquisition", "workforce mode should use hostile-acquisition")
  assert_eq(tourism.category, "hostile-acquisition", "tourism mode should use hostile-acquisition")
  assert_eq(pentapods.category, "hostile-acquisition", "pentapod mode should use hostile-acquisition")
  assert_true(fluids["hostile-spore-culture"] ~= nil, "hostile-spore-culture missing")
  assert_true(fluids["workforce-lure-spores"] ~= nil, "workforce-lure-spores missing")
  assert_true(fluids["tourism-lure-spores"] ~= nil, "tourism-lure-spores missing")
  assert_true(fluids["oviposition-lure-spores"] ~= nil, "oviposition-lure-spores missing")
  assert_eq(fluids["workforce-lure-spores"].auto_barrel, false,
    "workforce lure spores should not be barrelable")
  assert_eq(fluids["tourism-lure-spores"].auto_barrel, false,
    "tourism lure spores should not be barrelable")
  assert_eq(fluids["oviposition-lure-spores"].auto_barrel, false,
    "egg lure spores should not be barrelable")

  assert_eq(exact_surface_planet(workforce), "nauvis", "workforce mode should stay on Nauvis")
  assert_eq(exact_surface_planet(tourism), "nauvis", "tourism mode should stay on Nauvis")
  assert_eq(exact_surface_planet(pentapods), "gleba", "pentapod mode should stay on Gleba")
  assert_eq(exact_surface_planet(spore_base), "gleba", "spore culture base should stay on Gleba")
  assert_eq(spore_base.category, "organic-or-chemistry",
    "the first egg lure must be craftable in a Chemical Plant before the Biochamber")
  assert_eq(workforce_spores.category, "organic", "workforce lure spores should be Biochamber-only")
  assert_eq(tourism_spores.category, "organic", "tourism lure spores should be Biochamber-only")
  assert_eq(egg_spores.category, "organic-or-chemistry",
    "the first egg lure must not require a Biochamber built from an egg")
  assert_true(has_fluid_ingredient(workforce_spores, "hostile-spore-culture"),
    "workforce lure spores should consume Gleba spore culture")
  assert_true(has_fluid_ingredient(tourism_spores, "hostile-spore-culture"),
    "tourism lure spores should consume Gleba spore culture")
  assert_true(has_fluid_ingredient(egg_spores, "hostile-spore-culture"),
    "egg lure spores should consume Gleba spore culture")
  assert_true(not has_ingredient(egg_spores, "agricultural-science-pack"),
    "egg lure spores should not require the agricultural science that needs eggs")
  assert_true(recipes["manual-pentapod-egg-foraging"] == nil,
    "eggs should not be craftable from ingredients; bootstrap comes from bribing wild pentapods with dropped money")
  assert_true(recipes["pentapod-egg-bounty"] == nil,
    "egg bootstrap should use loose taxpayer-money, not a dedicated crafted capsule")

  assert_true(not tech_unlocks_recipe(technologies["worker-formation"], "capture-bureau-workforce"),
    "worker formation must not expose the Capture Bureau mode before Gleba")
  assert_true(not tech_unlocks_recipe(technologies["worker-formation"], "workforce-lure-spores-production"),
    "worker formation must not expose Biochamber lure spores before Gleba")
  assert_true(tech_unlocks_recipe(technologies["gleba-conciliation"], "capture-bureau-workforce"),
    "Gleba conciliation should unlock the Capture Bureau workforce mode")
  assert_true(not tech_unlocks_recipe(technologies["gleba-conciliation"], "workforce-lure-spores-production"),
    "Gleba conciliation must not unlock Biochamber-only spores before the chamber")
  assert_true(tech_unlocks_recipe(technologies["biochamber"], "workforce-lure-spores-production"),
    "the Biochamber technology should unlock workforce lure spores when they become usable")
  assert_true(has_ingredient(tourism, "cyan-yellow-form"),
    "tourism mode should consume cyan-yellow-form")
  assert_true(tech_unlocks_recipe(cyan_yellow, "capture-bureau-tourism"),
    "cyan-yellow-bureaucracy should unlock capture-bureau-tourism")
  assert_true(tech_unlocks_recipe(cyan_yellow, "tourism-lure-spores-production"),
    "cyan-yellow-bureaucracy should unlock tourism lure spores")
  assert_true(tech_unlocks_recipe(technologies["gleba-conciliation"], "capture-bureau-pentapod-eggs"),
    "gleba-conciliation should unlock capture-bureau-pentapod-eggs before agricultural science")
  assert_true(tech_unlocks_recipe(technologies["gleba-conciliation"], "hostile-spore-culture-production"),
    "gleba-conciliation should unlock spore culture")
  assert_true(tech_unlocks_recipe(technologies["gleba-conciliation"], "oviposition-lure-spores-production"),
    "gleba-conciliation should unlock egg lure spores")
end)

test("gleba chromatic chain defines amber sap and printer-fed yellow forms", function()
  assert_true(fluids["amber-sap"] ~= nil, "amber-sap missing")
  assert_true(fluids["yellow-ink"] ~= nil, "yellow-ink missing")
  assert_true(items["mycelial-form-stock"] ~= nil, "mycelial-form-stock missing")
  assert_true(items["blank-yellow-form"] ~= nil, "blank-yellow-form missing")
  assert_true(items["symbiosis-record"] ~= nil, "symbiosis-record missing")
  assert_true(items["conciliation-order"] ~= nil, "conciliation-order missing")

  assert_true(has_fluid_ingredient(recipes["yellow-ink-production"], "amber-sap"), "yellow-ink should consume amber-sap")
  assert_true(has_ingredient(recipes["yellow-ink-production"], "nutrients"), "yellow-ink should consume nutrients")
  assert_true(has_fluid_ingredient(recipes["mycelial-form-stock"], "yellow-ink"), "mycelial-form-stock should consume yellow-ink")
  assert_true(has_fluid_ingredient(recipes["blank-yellow-form-production"], "yellow-ink"), "blank-yellow-form should consume yellow-ink")
end)

test("gleba adds targeted ingredients instead of duplicate building recipes", function()
  for _, recipe_name in ipairs({
    "amber-sap-nonsense-seeding",
    "ink-production-gleba",
    "carbon-offset-certificate-basic-gleba",
    "construction-permit-gleba",
    "provisional-approval-cultivation-gleba",
    "management-approval-written-gleba",
    "composted-rubble-recovery-gleba",
    "capture-bureau",
  }) do
    assert_true(recipes[recipe_name] ~= nil, recipe_name .. " missing")
  end

  assert_true(has_ingredient(recipes["capture-bureau"], "worker-biter"), "capture-bureau should require worker-biter")
  assert_true(has_ingredient(recipes["capture-bureau"], "construction-permit"), "capture-bureau should use Gleba's local construction permit route")
  assert_true(not has_ingredient(recipes["capture-bureau"], "admin-station"), "capture-bureau must not import a Nauvis admin desk")
  assert_true(has_ingredient(recipes["capture-bureau"], "construction-work-order"), "capture-bureau should require imported construction paperwork")
  for _, recipe_name in ipairs({
    "admin-station-gleba",
    "printer-t1-gleba",
    "corporate-breakroom-gleba",
  }) do
    assert_true(recipes[recipe_name] == nil, recipe_name .. " must not duplicate a building recipe")
  end
  assert_true(recipes["management-approval-verbal-gleba"] == nil, "management-approval-verbal-gleba should not exist")
  assert_true(recipes["research-grant-approval-gleba"] == nil, "research-grant-approval-gleba should not exist")
  assert_true(recipes["form-27b-6-gleba"] == nil, "form-27b-6-gleba should not exist")
  assert_true(recipes["advanced-circuit-gleba"] == nil, "advanced-circuit-gleba should not exist")
  assert_true(recipes["low-density-structure-gleba"] == nil, "low-density-structure-gleba should not exist")
  assert_true(recipes["rocket-control-unit-gleba"] == nil, "rocket-control-unit-gleba should not exist")
  assert_true(recipes["rocket-silo-gleba"] == nil, "rocket-silo-gleba should not exist")
  for _, recipe_name in ipairs({
    "credentials-cultivation-gleba",
    "justification-cultivation-gleba",
    "basic-excuse-cultivation-gleba",
    "good-excuse-cultivation-gleba",
    "refined-nonsense-cultivation-gleba",
    "useless-documentation-cultivation-gleba",
  }) do
    assert_eq(recipes[recipe_name], nil, recipe_name .. " should remain a canonical or imported paperwork route")
  end
  assert_eq(recipes["dubious-data-cultivation-gleba"], nil,
    "Gleba should refine its seeded bullshit ore through the canonical dubious-data recipe")
  assert_eq(get_result_amount(recipes["provisional-approval-cultivation-gleba"], "provisional-approval"), 1,
    "Gleba should receive only one provisional approval per cultivation")
  assert_eq(recipes["provisional-approval-cultivation-gleba"].energy_required, 4,
    "Gleba provisional approval should be deliberately slow")
  assert_eq(recipes["carbon-offset-certificate-basic-gleba"].energy_required, 5,
    "Gleba certificates should be a costly local material bridge")
  assert_eq(recipes["administrative-science-pack-production-gleba"], nil,
    "Gleba should use the canonical administrative science recipe")
  assert_eq(recipes["management-approval-written-gleba"].energy_required, 24,
    "Gleba's one bulk-escape approval bridge should stay deliberately slow")
  assert_eq(recipes["government-grant-gleba"], nil,
    "Gleba must not mint Nauvis government grants")
  assert_eq(recipes["composted-rubble-recovery-gleba"].energy_required, 12,
    "Gleba rubble recovery should stay slow")
end)

test("vanilla Gleba bio recipes stay untouched and uncloned", function()
  for _, recipe_name in ipairs({"rocket-fuel-from-jelly", "bioplastic", "biosulfur", "biolubricant"}) do
    assert_true(recipes[recipe_name].surface_conditions == nil,
      recipe_name .. " should retain its unrestricted vanilla recipe prototype")
    assert_true(recipes[recipe_name .. "-offworld"] == nil,
      recipe_name .. " must not gain an offworld clone")
  end
  assert_true(items["biochamber-operating-waiver"] == nil,
    "obsolete offworld Biochamber paperwork should not exist")
end)

test("fulgora digital services unlocks only the bureau and finalized digital paperwork", function()
  local fulgora = technologies["fulgora-digital-services"]
  local salvage = technologies["fulgora-salvage-administration"]
  assert_true(fulgora ~= nil, "fulgora-digital-services missing")
  for _, recipe_name in ipairs({
    "digital-services-bureau",
    "digital-processing-certificate",
    "electromagnetic-operating-license",
    "data-recovery-order",
  }) do
    assert_true(tech_unlocks_recipe(fulgora, recipe_name), "fulgora-digital-services should unlock " .. recipe_name)
  end
  assert_true(tech_unlocks_recipe(salvage, "archive-recovery-permit"),
    "archive recovery belongs to the pre-electromagnetic salvage bootstrap")
  assert_true(tech_unlocks_recipe(salvage, "relay-clerk-formation"),
    "the relay clerk required by the electromagnetic plant must be trainable before its science pack")
  assert_true(tech_has_prerequisite(salvage, "management-formation"),
    "Fulgora's relay clerk bootstrap should include the workforce system it uses")
  assert_true(tech_has_prerequisite(technologies["electromagnetic-plant"], "fulgora-salvage-administration"),
    "the electromagnetic plant should follow its magenta form and relay-clerk bootstrap")
  assert_true(not tech_unlocks_recipe(technologies["electromagnetic-science-pack"], "relay-clerk-formation"),
    "electromagnetic science must not own the specialist needed to build its plant")
  assert_true(not tech_unlocks_recipe(fulgora, "archive-recovery-permit"),
    "digital services should not duplicate the salvage permit unlock")
end)

test("fulgora magenta chain defines the expected forms and staffed bureau", function()
  assert_true(items["charged-toner"] ~= nil, "charged-toner missing")
  assert_true(items["signal-form-stock"] ~= nil, "signal-form-stock missing")
  assert_true(items["blank-magenta-form"] ~= nil, "blank-magenta-form missing")
  assert_true(items["archive-recovery-permit"] ~= nil, "archive-recovery-permit missing")
  assert_true(items["digital-processing-certificate"] ~= nil, "digital-processing-certificate missing")
  assert_true(items["electromagnetic-operating-license"] ~= nil, "electromagnetic-operating-license missing")
  assert_true(items["data-recovery-order"] ~= nil, "data-recovery-order missing")
  assert_true(items["digital-services-bureau"] ~= nil, "digital-services-bureau missing")

  assert_true(has_ingredient(recipes["digital-services-bureau"], "relay-clerk"),
    "digital-services-bureau should require relay-clerk")
  assert_true(has_ingredient(recipes["digital-services-bureau"], "holmium-plate"),
    "digital-services-bureau should require holmium-plate")
  assert_true(has_ingredient(recipes["charged-toner"], "scrap"), "charged-toner should recover from scrap")
  assert_true(not has_ingredient(recipes["charged-toner"], "useless-documentation"),
    "charged-toner should bootstrap directly from scrap")
  assert_true(has_ingredient(recipes["archive-rubble-recovery"], "scrap"),
    "archive-rubble-recovery should consume scrap")
  assert_true(has_ingredient(recipes["archive-documentation-recovery"], "charged-toner"),
    "archive-documentation-recovery should consume charged-toner")
  assert_true(has_ingredient(recipes["archive-documentation-recovery"], "scrap"),
    "archive-documentation-recovery should consume scrap")
  assert_true(has_fluid_ingredient(recipes["signal-form-stock"], "magenta-ink"),
    "signal-form-stock should consume magenta-ink")
  assert_true(has_fluid_ingredient(recipes["blank-magenta-form-production"], "magenta-ink"),
    "blank-magenta-form should consume magenta-ink")
  assert_true(has_ingredient(recipes["archive-recovery-permit"], "blank-magenta-form"),
    "archive-recovery-permit should consume blank-magenta-form")
  assert_true(has_ingredient(recipes["digital-processing-certificate"], "processing-unit"),
    "digital-processing-certificate should require processing-unit")
  assert_true(has_ingredient(recipes["electromagnetic-operating-license"], "digital-processing-certificate"),
    "electromagnetic-operating-license should require digital-processing-certificate")
  assert_true(has_ingredient(recipes["data-recovery-order"], "archive-recovery-permit"),
    "data-recovery-order should require archive-recovery-permit")
  assert_true(not has_ingredient(recipes["magenta-ink-production"], "taxpayer-money"),
    "magenta-ink-production should not require taxpayer-money")

  for _, result_name in ipairs({
    "charged-toner",
    "redundant-rubble",
    "useless-documentation",
    "old-archive",
  }) do
    assert_true(has_result(recipes["scrap-recycling"], result_name),
      "scrap-recycling should randomly recover " .. result_name)
    assert_true(get_result_probability(recipes["scrap-recycling"], result_name) < 1,
      result_name .. " should be a probabilistic Fulgora salvage output")
  end
  for _, finished_form in ipairs({
    "signal-form-stock",
    "blank-magenta-form",
    "archive-recovery-permit",
    "digital-processing-certificate",
    "electromagnetic-operating-license",
    "data-recovery-order",
  }) do
    assert_true(not has_result(recipes["scrap-recycling"], finished_form),
      "scrap should not bypass Fulgora processing by dropping " .. finished_form)
  end
  assert_true(data.raw.furnace["recycler"].result_inventory_size >= item_result_count(recipes["scrap-recycling"]),
    "recycler output inventory must fit the expanded scrap-recycling result table")
end)

test("fulgora archive and electrolyte bootstrap stays local", function()
  local electrolyte = assert(recipes["salvage-electrolyte-fulgora"], "salvage-electrolyte-fulgora missing")
  local archive_technology = assert(technologies["archive-recombination"], "archive-recombination missing")
  local electromagnetic_plant = assert(technologies["electromagnetic-plant"], "electromagnetic-plant missing")

  assert_eq(exact_surface_planet(electrolyte), "fulgora", "salvage electrolyte should stay on Fulgora")
  assert_true(has_fluid_ingredient(electrolyte, "holmium-solution"), "salvage electrolyte should use holmium solution")
  assert_true(has_fluid_ingredient(electrolyte, "water"), "salvage electrolyte should use water")
  assert_true(has_ingredient(electrolyte, "charged-toner"), "salvage electrolyte should use charged toner")
  assert_true(has_ingredient(electrolyte, "redundant-rubble"), "salvage electrolyte should use redundant rubble")
  assert_true(not has_fluid_ingredient(electrolyte, "crude-oil"), "salvage electrolyte should not import crude oil")
  assert_true(not has_fluid_ingredient(electrolyte, "heavy-oil"), "salvage electrolyte should not import heavy oil")
  assert_true(tech_unlocks_recipe(electromagnetic_plant, "salvage-electrolyte-fulgora"),
    "electromagnetic-plant should unlock the local electrolyte route")
  assert_true(recipes["electromagnetic-rocket-fuel-fulgora"] ~= nil,
    "Fulgora needs its electromagnetic rocket-fuel bridge")
  assert_eq(recipes["liquid-black-ink-fulgora"], nil,
    "Fulgora should not receive a broad liquid-black-ink substitute")
  assert_true(recipes["electromagnetic-lubricant-fulgora"] ~= nil,
    "Fulgora needs one expensive lubricant bridge for the unchanged electric-engine chain")
  assert_true(tech_unlocks_recipe(electromagnetic_plant, "electromagnetic-lubricant-fulgora"),
    "electromagnetic-plant should unlock the Fulgora lubricant bridge")
  assert_eq(get_result_amount(recipes["carbon-offset-certificate-basic-fulgora"], "carbon-offset-certificate-basic"), 1,
    "Fulgora certificates should not create a bulk paperwork surplus")
  assert_eq(recipes["carbon-offset-certificate-basic-fulgora"].energy_required, 8,
    "Fulgora certificates should be an expensive salvage conversion")
  assert_eq(recipes["management-approval-written-fulgora"], nil,
    "Fulgora should import finished executive approvals")
  assert_eq(recipes["government-grant-fulgora"], nil,
    "Fulgora must not recover Nauvis government grants from archives")

  assert_true(archive_technology.unit == nil, "archive recombination should not require off-world science packs")
  assert_true(archive_technology.research_trigger ~= nil, "archive recombination should use a local craft trigger")
  assert_eq(archive_technology.research_trigger.item, "digital-processing-certificate",
    "archive recombination should be proven through Fulgora digital paperwork")
  assert_eq(archive_technology.research_trigger.count, 5,
    "archive recombination should require a meaningful local paperwork batch")
end)

test("Aquilo bootstrap precedes cryogenic science and the chromatic trunk follows it", function()
  local bootstrap = technologies["aquilo-cryogenic-administration"]
  local aquilo = technologies["interplanetary-tube-chromatic"]
  assert_true(bootstrap ~= nil, "aquilo-cryogenic-administration missing")
  assert_true(aquilo ~= nil, "interplanetary-tube-chromatic missing")
  for _, recipe_name in ipairs({
    "laser-printer",
    "transfer-emulsion-production",
    "thermal-transfer-sheet-production",
    "cryogenic-operations-license-production",
    "cryoprint-technician-formation",
  }) do
    assert_true(tech_unlocks_recipe(bootstrap, recipe_name),
      "aquilo-cryogenic-administration should unlock " .. recipe_name)
    assert_true(not tech_unlocks_recipe(aquilo, recipe_name),
      "interplanetary-tube-chromatic should not duplicate bootstrap unlock " .. recipe_name)
  end
  for _, recipe_name in ipairs({
    "composite-chroma-ribbon-production",
    "trichromatic-permit-production",
    "unified-operations-charter-production",
    "promethium-research-charter-production",
  }) do
    assert_true(tech_unlocks_recipe(aquilo, recipe_name), "interplanetary-tube-chromatic should unlock " .. recipe_name)
  end
  assert_true(not tech_uses_pack(bootstrap, "cryogenic-science-pack"),
    "Cryogenic Plant bootstrap must not consume cryogenic science")
  assert_true(tech_has_prerequisite(technologies["cryogenic-plant"], "aquilo-cryogenic-administration"),
    "Cryogenic Plant should explicitly follow its operating-license bootstrap")
  assert_eq(recipes["transfer-emulsion-production"].category, "chemistry-or-cryogenics",
    "transfer emulsion must have a pre-Cryogenic-Plant provider")
end)

test("Administratorium expedition closes the administrative progression loop", function()
  local technology = assert(technologies["promethium-science-pack"], "promethium-science-pack missing")
  local prerequisites = {}
  for _, prerequisite in ipairs(technology.prerequisites or {}) do
    prerequisites[prerequisite] = true
  end

  assert_true(prerequisites["interplanetary-tube-chromatic"],
    "Administratorium expedition should require the Aquilo chromatic tube tier")
  local uses_administrative_science = false
  for _, ingredient in ipairs(technology.unit.ingredients or {}) do
    if (ingredient.name or ingredient[1]) == "administrative-science-pack" then
      uses_administrative_science = true
    end
  end
  assert_true(uses_administrative_science,
    "Administratorium expedition should consume administrative science")
end)

test("bicolored paperwork technologies require the matching planet sciences", function()
  local cyan_yellow = assert(technologies["cyan-yellow-bureaucracy"], "cyan-yellow-bureaucracy missing")
  local cyan_magenta = assert(technologies["cyan-magenta-bureaucracy"], "cyan-magenta-bureaucracy missing")
  local yellow_magenta = assert(technologies["yellow-magenta-bureaucracy"], "yellow-magenta-bureaucracy missing")

  local function prerequisite_set(technology)
    local set = {}
    for _, prerequisite in ipairs(technology.prerequisites or {}) do
      set[prerequisite] = true
    end
    return set
  end

  local cyan_yellow_prereqs = prerequisite_set(cyan_yellow)
  assert_true(cyan_yellow_prereqs["vulcanus-certification"], "cyan-yellow-bureaucracy should depend on vulcanus-certification")
  assert_true(cyan_yellow_prereqs["gleba-conciliation"], "cyan-yellow-bureaucracy should depend on gleba-conciliation")
  assert_true(cyan_yellow_prereqs["metallurgic-science-pack"], "cyan-yellow-bureaucracy should depend on metallurgic-science-pack")
  assert_true(cyan_yellow_prereqs["agricultural-science-pack"], "cyan-yellow-bureaucracy should depend on agricultural-science-pack")
  assert_true(tech_unlocks_recipe(cyan_yellow, "capture-bureau-tourism"), "cyan-yellow-bureaucracy should unlock capture-bureau-tourism")
  assert_true(tech_unlocks_recipe(cyan_yellow, "public-transportation-contract-production"), "cyan-yellow-bureaucracy should unlock public-transportation-contract-production")
  assert_true(tech_unlocks_recipe(cyan_yellow, "cyan-yellow-form-production"), "cyan-yellow-bureaucracy should unlock cyan-yellow-form-production")

  local cyan_magenta_prereqs = prerequisite_set(cyan_magenta)
  assert_true(cyan_magenta_prereqs["vulcanus-certification"], "cyan-magenta-bureaucracy should depend on vulcanus-certification")
  assert_true(cyan_magenta_prereqs["fulgora-digital-services"], "cyan-magenta-bureaucracy should depend on fulgora-digital-services")
  assert_true(cyan_magenta_prereqs["metallurgic-science-pack"], "cyan-magenta-bureaucracy should depend on metallurgic-science-pack")
  assert_true(cyan_magenta_prereqs["electromagnetic-science-pack"], "cyan-magenta-bureaucracy should depend on electromagnetic-science-pack")
  assert_true(tech_unlocks_recipe(cyan_magenta, "cyan-magenta-form-production"), "cyan-magenta-bureaucracy should unlock cyan-magenta-form-production")
  assert_true(tech_unlocks_recipe(cyan_magenta, "hardened-data-vault-production"), "cyan-magenta-bureaucracy should unlock hardened-data-vault-production")

  local yellow_magenta_prereqs = prerequisite_set(yellow_magenta)
  assert_true(yellow_magenta_prereqs["gleba-conciliation"], "yellow-magenta-bureaucracy should depend on gleba-conciliation")
  assert_true(yellow_magenta_prereqs["fulgora-digital-services"], "yellow-magenta-bureaucracy should depend on fulgora-digital-services")
  assert_true(yellow_magenta_prereqs["agricultural-science-pack"], "yellow-magenta-bureaucracy should depend on agricultural-science-pack")
  assert_true(yellow_magenta_prereqs["electromagnetic-science-pack"], "yellow-magenta-bureaucracy should depend on electromagnetic-science-pack")
  assert_true(tech_unlocks_recipe(yellow_magenta, "yellow-magenta-form-production"), "yellow-magenta-bureaucracy should unlock yellow-magenta-form-production")
  assert_true(tech_unlocks_recipe(yellow_magenta, "anecdotal-data-reprocessing"), "yellow-magenta-bureaucracy should unlock anecdotal-data-reprocessing")
end)

test("aquilo transfer media and multicolor forms define the expected convergence chain", function()
  assert_true(items["transfer-emulsion"] ~= nil, "transfer-emulsion missing")
  assert_true(items["thermal-transfer-sheet"] ~= nil, "thermal-transfer-sheet missing")
  assert_true(items["composite-chroma-ribbon"] ~= nil, "composite-chroma-ribbon missing")
  assert_true(items["cyan-yellow-form"] ~= nil, "cyan-yellow-form missing")
  assert_true(items["cyan-magenta-form"] ~= nil, "cyan-magenta-form missing")
  assert_true(items["yellow-magenta-form"] ~= nil, "yellow-magenta-form missing")
  assert_true(items["hardened-data-vault"] ~= nil, "hardened-data-vault missing")
  assert_true(items["trichromatic-permit"] ~= nil, "trichromatic-permit missing")
  assert_true(items["unified-operations-charter"] ~= nil, "unified-operations-charter missing")
  assert_true(items["cryogenic-operations-license"] ~= nil, "cryogenic-operations-license missing")
  assert_true(items["promethium-research-charter"] ~= nil, "promethium-research-charter missing")
  assert_true(items["laser-printer"] ~= nil, "laser-printer missing")

  assert_true(has_ingredient(recipes["laser-printer"], "cryoprint-technician"),
    "laser-printer should require cryoprint-technician")
  assert_true(has_ingredient(recipes["laser-printer"], "lithium-plate"),
    "laser-printer should require lithium-plate")
  assert_true(has_ingredient(recipes["transfer-emulsion-production"], "plastic-bar"),
    "transfer-emulsion should require plastic-bar")
  assert_true(has_ingredient(recipes["thermal-transfer-sheet-production"], "transfer-emulsion"),
    "thermal-transfer-sheet should require transfer-emulsion")
  assert_true(has_ingredient(recipes["composite-chroma-ribbon-production"], "blank-magenta-form"),
    "composite-chroma-ribbon should require blank-magenta-form")
  assert_true(has_fluid_ingredient(recipes["cyan-yellow-form-production"], "cyan-ink"),
    "cyan-yellow-form should require cyan-ink")
  assert_true(has_fluid_ingredient(recipes["cyan-yellow-form-production"], "yellow-ink"),
    "cyan-yellow-form should require yellow-ink")
  assert_true(has_fluid_ingredient(recipes["cyan-magenta-form-production"], "cyan-ink"),
    "cyan-magenta-form should require cyan-ink")
  assert_true(has_fluid_ingredient(recipes["cyan-magenta-form-production"], "magenta-ink"),
    "cyan-magenta-form should require magenta-ink")
  assert_true(has_fluid_ingredient(recipes["yellow-magenta-form-production"], "yellow-ink"),
    "yellow-magenta-form should require yellow-ink")
  assert_true(has_fluid_ingredient(recipes["yellow-magenta-form-production"], "magenta-ink"),
    "yellow-magenta-form should require magenta-ink")
  assert_true(has_ingredient(recipes["hardened-data-vault-production"], "cyan-magenta-form"),
    "hardened-data-vault should require cyan-magenta-form")
  assert_true(has_ingredient(recipes["hardened-data-vault-production"], "industrial-charter"),
    "hardened-data-vault should require Vulcanus industrial-charter")
  assert_true(has_ingredient(recipes["hardened-data-vault-production"], "data-recovery-order"),
    "hardened-data-vault should require Fulgora data-recovery-order")
  assert_true(has_ingredient(recipes["trichromatic-permit-production"], "composite-chroma-ribbon"),
    "trichromatic-permit should require composite-chroma-ribbon")
  assert_true(has_ingredient(recipes["unified-operations-charter-production"], "electromagnetic-operating-license"),
    "unified-operations-charter should require electromagnetic-operating-license")
  assert_true(has_ingredient(recipes["cryogenic-operations-license-production"], "lithium-plate"),
    "cryogenic-operations-license should require lithium-plate")
  assert_true(has_ingredient(recipes["promethium-research-charter-production"], "unified-operations-charter"),
    "promethium-research-charter should require unified-operations-charter")
  assert_true(has_ingredient(recipes["promethium-research-charter-production"], "hardened-data-vault"),
    "promethium-research-charter should require Vulcanus-Fulgora hardened-data-vault")
  assert_true(has_ingredient(recipes["promethium-research-charter-production"], "asteroid-processing-docket"),
    "promethium-research-charter should require asteroid-processing-docket")
  assert_true(not has_ingredient(recipes["promethium-research-charter-production"], "orbital-deviation-order"),
    "promethium-research-charter should no longer require orbital-deviation-order")
  assert_true(not has_ingredient(recipes["transfer-emulsion-production"], "taxpayer-money"),
    "transfer-emulsion should not require taxpayer-money")
end)

test("two-color forms gate tourism intake and public transit contracts", function()
  local cyan_yellow_form = assert(recipes["cyan-yellow-form-production"], "cyan-yellow-form-production missing")
  local public_transport = assert(recipes["public-transportation-contract-production"], "public-transportation-contract-production missing")
  local anecdotal = assert(recipes["anecdotal-data-reprocessing"], "anecdotal-data-reprocessing missing")

  assert_eq(cyan_yellow_form.category, "printing-multicolor", "cyan-yellow-form should use printing-multicolor")
  assert_true(has_fluid_ingredient(cyan_yellow_form, "cyan-ink"),
    "cyan-yellow-form should require cyan-ink")
  assert_true(has_fluid_ingredient(cyan_yellow_form, "yellow-ink"),
    "cyan-yellow-form should require yellow-ink")

  assert_eq(public_transport.category, "printing-chromatic", "public-transportation-contract should use printing-chromatic")
  assert_true(has_ingredient(public_transport, "cyan-yellow-form"),
    "public-transportation-contract should require cyan-yellow-form")
  assert_true(has_ingredient(public_transport, "transit-authorization"),
    "public-transportation-contract should require transit-authorization")
  assert_true(has_ingredient(anecdotal, "yellow-magenta-form"),
    "anecdotal-data-reprocessing should require yellow-magenta-form")
  assert_eq(get_result_amount(anecdotal, "dubious-data"), 6,
    "anecdotal-data-reprocessing should produce a worthwhile amount of dubious-data")
end)

test("planet-local space age recipes stay free of raw taxpayer money off Nauvis", function()
  for recipe_name, recipe in pairs(recipes) do
    local planet_name = exact_surface_planet(recipe)
    if planet_name and planet_name ~= "nauvis" then
      assert_true(not has_ingredient(recipe, "taxpayer-money"),
        recipe_name .. " should not require taxpayer-money on " .. planet_name)
    end
  end
end)

local locale_helpers = require("tests.locale_helpers")

test("every Space Age technology has a name and description in every shipped locale", function()
  local missing = {}
  for _, locale_name in ipairs({"en", "fr", "ru"}) do
    local names = locale_helpers.section(mod_root, locale_name, "technology-name")
    local descriptions = locale_helpers.section(mod_root, locale_name, "technology-description")
    for technology_name, technology in pairs(technologies) do
      if not preexisting_technology_names[technology_name] and technology.hidden ~= true then
        if not names[technology_name] or names[technology_name] == "" then
          missing[#missing + 1] = locale_name .. ":technology-name." .. technology_name
        end
        if not descriptions[technology_name] or descriptions[technology_name] == "" then
          missing[#missing + 1] = locale_name .. ":technology-description." .. technology_name
        end
      end
    end
  end
  table.sort(missing)
  assert_true(#missing == 0, "missing locale keys: " .. table.concat(missing, ", "))
end)

if failed > 0 then
  io.stderr:write(("Failed %d/%d tests\n"):format(failed, passed + failed))
  for _, err in ipairs(errors) do
    io.stderr:write(err, "\n")
  end
  os.exit(1)
end

print(("Passed %d tests"):format(passed))
