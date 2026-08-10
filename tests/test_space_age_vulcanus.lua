-------------------------------------------------------------------------------
-- ADMINISTRATORIO VULCANUS SPACE AGE TESTS
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

mods = {
  ["space-age"] = "2.0.0",
}

local asteroid_prototypes = {}
for _, size in ipairs({"small", "medium", "big", "huge"}) do
  for _, family in ipairs({"metallic", "carbonic", "oxide", "promethium"}) do
    local name = size .. "-" .. family .. "-asteroid"
    asteroid_prototypes[name] = {
      type = "asteroid",
      name = name,
      trigger_target_mask = {"common"},
    }
  end
end

data = {
  raw = {
    item = {},
    fluid = {},
    ["virtual-signal"] = {},
    asteroid = asteroid_prototypes,
    ["asteroid-chunk"] = {
      ["metallic-asteroid-chunk"] = {
        type = "asteroid-chunk",
        name = "metallic-asteroid-chunk",
        icon = "__space-age__/graphics/icons/metallic-asteroid-chunk.png",
        minable = {mining_time = 0.2, result = "metallic-asteroid-chunk"},
        graphics_set = {},
      },
    },
    projectile = {
      rocket = {
        type = "projectile",
        name = "rocket",
        acceleration = 0.01,
        animation = {},
        shadow = {},
        smoke = {},
        action = {},
      },
    },
    unit = {
      ["behemoth-biter"] = {
        run_animation = {
          layers = {{
            filename = "mock-biter-run.png",
            width = 64,
            height = 64,
            frame_count = 16,
            direction_count = 16,
            line_length = 16,
            scale = 2,
            shift = {x = 1, y = -2},
          }},
        },
        attack_parameters = {
          animation = {
            layers = {{
              filename = "mock-biter-attack.png",
              width = 64,
              height = 64,
              frame_count = 11,
              direction_count = 16,
              line_length = 11,
              scale = 2,
              shift = {x = 1, y = -2},
            }},
          },
        },
      },
    },
    recipe = {
      foundry = {
        type = "recipe",
        name = "foundry",
        surface_conditions = {{property = "pressure", min = 4000, max = 4000}},
        ingredients = {},
      },
      biochamber = {type = "recipe", name = "biochamber", ingredients = {}},
      ["electromagnetic-plant"] = {type = "recipe", name = "electromagnetic-plant", ingredients = {}},
      ["cryogenic-plant"] = {type = "recipe", name = "cryogenic-plant", ingredients = {}},
      ["advanced-circuit"] = {type = "recipe", name = "advanced-circuit", ingredients = {}},
      ["low-density-structure"] = {type = "recipe", name = "low-density-structure", ingredients = {}},
      ["rocket-control-unit"] = {type = "recipe", name = "rocket-control-unit", ingredients = {}},
      ["rocket-silo"] = {type = "recipe", name = "rocket-silo", ingredients = {}},
      ["rocket-fuel-from-jelly"] = {type = "recipe", name = "rocket-fuel-from-jelly", ingredients = {}},
      ["bioplastic"] = {type = "recipe", name = "bioplastic", ingredients = {}},
      ["biosulfur"] = {type = "recipe", name = "biosulfur", ingredients = {}},
      ["biolubricant"] = {type = "recipe", name = "biolubricant", ingredients = {}},
    },
    technology = {
      ["administrative-science-research"] = {type = "technology", name = "administrative-science-research", effects = {}},
      ["printing-technology"] = {type = "technology", name = "printing-technology", effects = {}},
      ["corporate-hospitality"] = {type = "technology", name = "corporate-hospitality", effects = {}},
      ["metallurgic-science-pack"] = {type = "technology", name = "metallurgic-science-pack", effects = {}},
      ["agricultural-science-pack"] = {type = "technology", name = "agricultural-science-pack", effects = {}},
      ["electromagnetic-science-pack"] = {type = "technology", name = "electromagnetic-science-pack", effects = {}},
      ["cryogenic-science-pack"] = {type = "technology", name = "cryogenic-science-pack", effects = {}},
      ["after-hours-operations"] = {type = "technology", name = "after-hours-operations", effects = {}},
      ["discovery-redundant-rubble"] = {type = "technology", name = "discovery-redundant-rubble", effects = {}},
      ["nest-expropriation"] = {type = "technology", name = "nest-expropriation", effects = {}},
    },
    ["assembling-machine"] = {
      ["assembling-machine-1"] = {
        type = "assembling-machine",
        name = "assembling-machine-1",
        minable = {result = "assembling-machine-1"},
        placeable_by = {{item = "assembling-machine-1", count = 1}},
        fluid_boxes = {},
        graphics_set = {},
      },
      ["assembling-machine-2"] = {
        type = "assembling-machine",
        name = "assembling-machine-2",
        minable = {result = "assembling-machine-2"},
        placeable_by = {{item = "assembling-machine-2", count = 1}},
        fluid_boxes = {},
        graphics_set = {},
      },
      ["assembling-machine-3"] = {
        type = "assembling-machine",
        name = "assembling-machine-3",
        minable = {result = "assembling-machine-3"},
        placeable_by = {{item = "assembling-machine-3", count = 1}},
        fluid_boxes = {},
        graphics_set = {},
      },
      ["formation-center"] = {
        type = "assembling-machine",
        name = "formation-center",
        icon = "__administratorio__/graphics/icons/formation-center.png",
        icon_size = 64,
        minable = {result = "formation-center"},
        placeable_by = {{item = "formation-center", count = 1}},
        crafting_categories = {"biter-training"},
        fluid_boxes = {
          {production_type = "input", pipe_connections = {}, volume = 100},
          {production_type = "input", pipe_connections = {}, volume = 100},
        },
        graphics_set = {
          animation = {
            layers = {{
              filename = "__administratorio__/graphics/entities/formation-center/formation-center.png",
              width = 480,
              height = 435,
              scale = 1 / 3,
            }},
          },
        },
      },
    },
    ["container"] = {},
    ["ammo-turret"] = {
      ["gun-turret"] = {
        type = "ammo-turret",
        name = "gun-turret",
        minable = {result = "gun-turret"},
        placeable_by = {{item = "gun-turret", count = 1}},
        attack_parameters = {},
      },
      ["railgun-turret"] = {
        type = "ammo-turret",
        name = "railgun-turret",
        minable = {result = "railgun-turret"},
        placeable_by = {{item = "railgun-turret", count = 1}},
        attack_parameters = {},
        energy_source = {},
      },
    },
    ["train-stop"] = {
      ["train-stop"] = {
        type = "train-stop",
        name = "train-stop",
        minable = {result = "train-stop"},
        placeable_by = {{item = "train-stop", count = 1}},
      },
    },
  },
}

function data:extend(prototypes)
  for _, proto in ipairs(prototypes) do
    data.raw[proto.type] = data.raw[proto.type] or {}
    data.raw[proto.type][proto.name] = proto
  end
end

util = {
  table = {
    deepcopy = function(tbl)
      if type(tbl) ~= "table" then return tbl end
      local copy = {}
      for k, v in pairs(tbl) do
        copy[util.table.deepcopy(k)] = util.table.deepcopy(v)
      end
      return setmetatable(copy, getmetatable(tbl))
    end,
  },
  by_pixel = function(x, y)
    return {x / 32, y / 32}
  end,
}

if not table.deepcopy then
  table.deepcopy = util.table.deepcopy
end

circuit_connector_definitions = {
  create_vector = function()
    return {}
  end,
  create_single = function()
    return {}
  end,
}

universal_connector_template = {}

defines = {
  direction = {
    north = 0,
    east = 2,
    south = 4,
    west = 6,
  },
}

function pipecoverspictures()
  return {}
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

dofile(mod_root .. "prototypes/item/capsules-and-fluids.lua")
dofile(mod_root .. "prototypes/item/space_age.lua")
dofile(mod_root .. "prototypes/recipe/space_age.lua")
dofile(mod_root .. "prototypes/recipe/planetary_abundance.lua")
dofile(mod_root .. "prototypes/entity/printers.lua")
dofile(mod_root .. "prototypes/entity/space_age.lua")
dofile(mod_root .. "prototypes/technology/space_age.lua")

local planets = require("prototypes.shared.space_age_planets")

local function has_ingredient(recipe, ingredient_name)
  if not recipe or not recipe.ingredients then return false end
  for _, ingredient in ipairs(recipe.ingredients) do
    if ingredient.name == ingredient_name then
      return true
    end
  end
  return false
end

test("trajectory compliance tiers use native powered timing, range, and asteroid-size masks", function()
  local arrays = {
    {
      name = "trajectory-compliance-array",
      energy = "1.3MJ",
      flow = "2.6MW",
      next_upgrade = "senior-trajectory-compliance-array",
      range = 20,
      masks = {small = true, medium = true},
    },
    {
      name = "senior-trajectory-compliance-array",
      energy = "2.6MJ",
      flow = "5.2MW",
      next_upgrade = "executive-trajectory-compliance-array",
      range = 30,
      masks = {small = true, medium = true, big = true},
    },
    {
      name = "executive-trajectory-compliance-array",
      energy = "5.2MJ",
      flow = "10.4MW",
      masks = {small = true, medium = true, big = true, huge = true},
      range = 40,
    },
  }

  for _, expected in ipairs(arrays) do
    local array = assert(data.raw["ammo-turret"][expected.name], expected.name .. " missing")
    assert_eq(array.attack_parameters.ammo_category, "trajectory-compliance")
    assert_eq(array.attack_parameters.cooldown, 300, "base firing cooldown should be five seconds")
    assert_eq(array.attack_parameters.range, expected.range, "array range mismatch")
    assert_eq(array.energy_source.type, "electric")
    assert_eq(array.energy_source.buffer_capacity, expected.energy)
    assert_eq(array.energy_source.input_flow_limit, expected.flow)
    assert_eq(array.energy_per_shot, expected.energy)
    assert_eq(array.prepare_with_no_ammo, false)
    assert_eq(array.fast_replaceable_group, "trajectory-compliance-array")
    assert_eq(array.next_upgrade, expected.next_upgrade)

    local mask_set = {}
    for _, mask in ipairs(array.attack_target_mask or {}) do mask_set[mask] = true end
    for size, allowed in pairs(expected.masks) do
      assert_eq(mask_set["administratorio-asteroid-" .. size], allowed, expected.name .. " target mask mismatch")
    end
  end

  for _, size in ipairs({"small", "medium", "big", "huge"}) do
    for _, family in ipairs({"metallic", "carbonic", "oxide", "promethium"}) do
      local asteroid = assert(data.raw.asteroid[size .. "-" .. family .. "-asteroid"])
      local masks = {}
      for _, mask in ipairs(asteroid.trigger_target_mask or {}) do masks[mask] = true end
      assert_true(masks["administratorio-asteroid-" .. size], "asteroid should receive its size target mask")
      assert_true(not masks.common, "common targeting would let junior arrays waste managers on larger asteroids")
    end
  end
end)

test("orbital employment cannon deploys powered voluntary space miners", function()
  local cannon = assert(data.raw["ammo-turret"]["orbital-employment-cannon"])
  assert_eq(cannon.attack_parameters.ammo_category, "orbital-biter-ballistics")
  assert_eq(cannon.attack_parameters.cooldown, 240)
  assert_eq(cannon.attack_parameters.range, 56)
  assert_eq(cannon.attack_parameters.min_range, 4)
  assert_eq(cannon.attack_parameters.turn_range, 0.05)
  assert_eq(cannon.energy_per_shot, "5MJ")
  assert_eq(cannon.energy_source.buffer_capacity, "10MJ")
  assert_eq(cannon.surface_conditions[1].max, 0)

  local projectile = assert(data.raw.projectile["orbital-biter-projectile"])
  assert_eq(projectile.max_speed, 0.36)
  local effects = projectile.action.action_delivery.target_effects
  assert_eq(effects[1].type, "script")
  assert_eq(effects[1].effect_id, "administratorio-asteroid-biter-assault")
  for _, effect in ipairs(effects) do
    assert_true(effect.type ~= "damage",
      "VESM projectiles must not carry quality-scalable impact damage")
  end
  assert_eq(projectile.animation.layers[1].scale, 0.92,
    "projectile body should scale the real biter layer")
  assert_eq(projectile.animation.layers[1].shift.x, 0.46,
    "projectile layer anchors must scale with the sprite")
  assert_eq(projectile.animation.layers[1].shift.y, -0.92,
    "projectile layer anchors must remain aligned after scaling")

  local attack = assert(data.raw.animation["orbital-manager-attack"])
  assert_eq(attack.layers[1].shift.x, 0.46,
    "attached manager attack layers must use the same scaled anchor")
  assert_eq(attack.layers[1].animation_speed, 1,
    "runtime render objects should own each manager's animation clock")

  local chunk = assert(data.raw["asteroid-chunk"]["returning-orbital-employee"],
    "returning employee asteroid chunk missing")
  assert_eq(chunk.minable.result, "voluntary-exploration-space-miner",
    "collector should output the reusable VESM directly")
  assert_true(chunk.graphics_set.sprite ~= nil, "employee chunk should visibly combine biter and debris")
  for direction_index = 1, 15 do
    local oriented_name = string.format("returning-orbital-employee-orientation-%02d", direction_index)
    local oriented = assert(data.raw["asteroid-chunk"][oriented_name],
      "returning employee orientation variant missing")
    assert_eq(oriented.minable.result, "voluntary-exploration-space-miner")
    assert_eq(oriented.graphics_set.rotation_speed, 0)
    assert_true(oriented.hidden_in_factoriopedia,
      "orientation variants must not clutter Factoriopedia")
  end
end)

test("chromatic printer is a flippable four-port liquid-fed machine", function()
  local entity = data.raw["assembling-machine"]["chromatic-printer"]
  assert_true(entity ~= nil, "chromatic-printer missing")
  assert_eq(#(entity.fluid_boxes or {}), 4, "chromatic-printer should expose four input ports")

  local expected = {
    {defines.direction.north, 0, -1},
    {defines.direction.east, 1, 0},
    {defines.direction.south, 0, 1},
    {defines.direction.west, -1, 0},
  }

  for index, spec in ipairs(expected) do
    local fluid_box = entity.fluid_boxes[index]
    assert_eq(fluid_box.production_type, "input", "chromatic-printer ports should all be inputs")
    local connection = assert(fluid_box.pipe_connections[1], "chromatic-printer port missing connection")
    assert_eq(connection.flow_direction, "input", "chromatic-printer port should be input-only")
    assert_eq(connection.direction, spec[1], "unexpected pipe direction for chromatic-printer port " .. index)
    assert_eq(connection.position[1], spec[2], "unexpected x position for chromatic-printer port " .. index)
    assert_eq(connection.position[2], spec[3], "unexpected y position for chromatic-printer port " .. index)
  end
end)

test("notary office is the dedicated certification machine", function()
  local entity = data.raw["assembling-machine"]["notary-office"]
  assert_true(entity ~= nil, "notary-office missing")
  assert_eq(entity.placeable_by[1].item, "notary-office", "notary-office should build from the notary-office item")
  local categories = entity.crafting_categories or {}
  assert_eq(#categories, 1, "notary-office should only expose one crafting category")
  assert_eq(categories[1], "bureaucracy-certification", "notary-office should only craft certification recipes")
  assert_eq(#(entity.fluid_boxes or {}), 3, "notary-office should expose two inputs and one output")
  assert_eq(entity.fluid_boxes[3].production_type, "output", "notary-office should vent fluid outputs")
end)

test("conciliation desk is the dedicated gleba certification machine", function()
  local entity = data.raw["assembling-machine"]["conciliation-desk"]
  assert_true(entity ~= nil, "conciliation-desk missing")
  assert_eq(entity.placeable_by[1].item, "conciliation-desk", "conciliation-desk should build from the conciliation-desk item")
  local categories = entity.crafting_categories or {}
  assert_eq(#categories, 1, "conciliation-desk should only expose one crafting category")
  assert_eq(categories[1], "bureaucracy-conciliation", "conciliation-desk should only craft conciliation recipes")
  assert_eq(#(entity.fluid_boxes or {}), 3, "conciliation-desk should expose two inputs and one output")
  assert_eq(entity.fluid_boxes[3].production_type, "output", "conciliation-desk should vent fluid outputs")
end)

test("digital services bureau is a staffed fulgora office upgrade", function()
  local entity = data.raw["assembling-machine"]["digital-services-bureau"]
  assert_true(entity ~= nil, "digital-services-bureau missing")
  assert_eq(entity.placeable_by[1].item, "digital-services-bureau",
    "digital-services-bureau should build from the digital-services-bureau item")
  local categories = entity.crafting_categories or {}
  assert_eq(#categories, 2, "digital-services-bureau should expose only Fulgora office categories")
  assert_eq(categories[1], "bureaucracy-registration-fulgora",
    "digital-services-bureau should handle Fulgora registration work")
  assert_eq(categories[2], "bureaucratic-bootstrap-fulgora",
    "digital-services-bureau should handle Fulgora bootstrap work")
  assert_eq(entity.crafting_speed, 3, "digital-services-bureau should be significantly faster than an office desk")
  assert_eq(#(entity.fluid_boxes or {}), 2, "digital-services-bureau should expose one input and one output")
  assert_eq(entity.fluid_boxes[1].production_type, "input", "digital-services-bureau should take fluid inputs")
  assert_eq(entity.fluid_boxes[2].production_type, "output", "digital-services-bureau should vent outputs")
end)

test("administrative space station is the dedicated vacuum bureaucracy building", function()
  local entity = data.raw["assembling-machine"]["administrative-space-station"]
  local recipe = data.raw.recipe["administrative-space-station"]
  assert_true(entity ~= nil, "administrative-space-station missing")
  assert_true(recipe ~= nil, "administrative-space-station recipe missing")
  assert_eq(entity.placeable_by[1].item, "administrative-space-station",
    "administrative-space-station should build from its own item")
  assert_eq(entity.crafting_categories[1], "orbital-bureaucracy",
    "administrative-space-station should only craft orbital paperwork")
  assert_eq(entity.surface_conditions[1].max, 0, "administrative-space-station entity should stay vacuum-only")
  assert_eq(recipe.surface_conditions[1].max, 0, "administrative-space-station recipe should stay vacuum-only")
end)

test("aquilo printer and exchange are specialized endgame bureaucracy machines", function()
  local laser = data.raw["assembling-machine"]["laser-printer"]
  assert_true(laser ~= nil, "laser-printer missing")
  assert_eq(laser.placeable_by[1].item, "laser-printer", "laser-printer should build from the laser-printer item")
  local laser_categories = {}
  for _, category in ipairs(laser.crafting_categories or {}) do
    laser_categories[category] = true
  end
  assert_true(laser_categories["printing"], "laser-printer should keep base printing")
  assert_true(laser_categories["printing-advanced"], "laser-printer should keep advanced printing")
  assert_true(laser_categories["printing-workorder"], "laser-printer should keep work-order printing")
  assert_true(laser_categories["printing-multicolor"], "laser-printer should expose multicolor printing")
  assert_true(laser_categories["orbital-printing"], "laser-printer should expose advanced orbital printing")
  assert_true(not laser_categories["fax-reconstruction"],
    "laser-printer should leave fax reconstruction to the dedicated exchange")
  assert_eq(laser.crafting_speed, 5, "laser-printer should be the fastest printer")
  assert_eq(#(laser.fluid_boxes or {}), 0, "laser-printer should use solid transfer media instead of fluid ports")

  local emitter = data.raw.container["fax-emitter"]
  assert_true(emitter ~= nil, "fax-emitter missing")
  assert_eq(emitter.placeable_by[1].item, "fax-emitter", "fax-emitter should build from the fax-emitter item")
  assert_eq(emitter.inventory_size, 1, "fax-emitter should hold a single source document")

  local exchange = data.raw["assembling-machine"]["interplanetary-fax-exchange"]
  assert_true(exchange ~= nil, "interplanetary-fax-exchange missing")
  assert_eq(exchange.placeable_by[1].item, "interplanetary-fax-exchange",
    "interplanetary-fax-exchange should build from the fax exchange item")
  assert_eq(exchange.crafting_categories[1], "fax-reconstruction",
    "interplanetary-fax-exchange should own fax reconstruction")
  assert_eq(#(exchange.fluid_boxes or {}), 0,
    "interplanetary-fax-exchange should use dry sheets and ribbon")
  assert_eq(exchange.ingredient_count, 5,
    "interplanetary-fax-exchange should have room for solid reconstruction media")
end)

test("industrial and laser printers are vacuum-approved while lower printers remain grounded", function()
  local mechanical = assert(data.raw["assembling-machine"]["mechanical-printer"])
  local t1 = assert(data.raw["assembling-machine"]["printer-t1"])
  local t2 = assert(data.raw["assembling-machine"]["printer-t2"])
  local laser = assert(data.raw["assembling-machine"]["laser-printer"])
  assert_true(mechanical.surface_conditions and mechanical.surface_conditions[1].min >= 1)
  assert_true(t1.surface_conditions and t1.surface_conditions[1].min >= 1)
  assert_true(t2.surface_conditions == nil, "industrial printer should be placeable in vacuum")
  assert_true(laser.surface_conditions == nil, "laser printer should be placeable in vacuum")
  local t2_categories = {}
  for _, category in ipairs(t2.crafting_categories or {}) do t2_categories[category] = true end
  assert_true(t2_categories["orbital-printing"], "industrial printer should run tier-two orbital recipes")
end)

test("formation center supports coffee-fed batch meetings", function()
  local center = assert(data.raw["assembling-machine"]["formation-center"])
  assert_eq(center.icon, "__administratorio__/graphics/icons/formation-center.png",
    "Space Age should keep the custom formation center icon")
  assert_eq(center.graphics_set.animation.layers[1].filename,
    "__administratorio__/graphics/entities/formation-center/formation-center.png",
    "Space Age should keep the custom formation center sprite")
  assert_eq(center.crafting_speed, 1.5)
  assert_eq(center.result_inventory_size, 4,
    "advanced formations need room for their employee and returned managers")
  assert_eq(#(center.fluid_boxes or {}), 2,
    "managerial meetings should accept coffee from either side")
  assert_eq(center.fluid_boxes[1].production_type, "input")
  assert_eq(center.fluid_boxes[2].production_type, "input")
  assert_true(center.fluid_boxes_off_when_no_fluid_recipe)
  local allowed = {}
  for _, effect in ipairs(center.allowed_effects or {}) do allowed[effect] = true end
  assert_true(allowed.speed, "Formation Center meetings should accept speed modules")
  local categories = {}
  for _, category in ipairs(center.crafting_categories or {}) do categories[category] = true end
  assert_true(categories["biter-training"], "Formation Center should keep its base training recipes")
  assert_true(categories["workforce-formation"], "Formation Center should accept Space Age formations")
end)

test("non-orbital space age admin machines stay out of vacuum", function()
  for _, entity_name in ipairs({
    "formation-center",
    "notary-office",
    "digital-services-bureau",
  }) do
    local entity = assert(data.raw["assembling-machine"][entity_name], entity_name .. " missing")
    assert_true(entity.surface_conditions ~= nil and entity.surface_conditions[1] ~= nil,
      entity_name .. " should define a vacuum-blocking pressure rule")
    assert_eq(entity.surface_conditions[1].property, "pressure", entity_name .. " should gate on pressure")
    assert_true((entity.surface_conditions[1].min or 0) >= 1, entity_name .. " should require non-vacuum pressure")
  end

  local fax_entities = {
    ["fax-emitter"] = data.raw.container,
    ["interplanetary-fax-exchange"] = data.raw["assembling-machine"],
  }

  for _, entity_name in ipairs({"fax-emitter", "interplanetary-fax-exchange"}) do
    local entity = assert(fax_entities[entity_name][entity_name], entity_name .. " missing")
    assert_true(entity.surface_conditions ~= nil and entity.surface_conditions[1] ~= nil,
      entity_name .. " should define a vacuum-blocking pressure rule")
    assert_true((entity.surface_conditions[1].min or 0) >= 1, entity_name .. " should require non-vacuum pressure")
  end
end)

test("planet helper exposes exact basic-planet conditions and abundance outputs", function()
  local vulcanus = planets.surface_conditions_for_planet("vulcanus")
  local gleba = planets.surface_conditions_for_planet("gleba")
  local fulgora = planets.surface_conditions_for_planet("fulgora")
  local aquilo = planets.surface_conditions_for_planet("aquilo")

  assert_eq(vulcanus[1].property, "pressure", "vulcanus first condition should be pressure")
  assert_eq(vulcanus[1].min, 4000, "vulcanus pressure should match Space Age")
  assert_eq(vulcanus[2].property, "gravity", "vulcanus second condition should be gravity")
  assert_eq(vulcanus[2].min, 40, "vulcanus gravity should match Space Age")
  assert_eq(gleba[1].min, 2000, "gleba pressure should match Space Age")
  assert_eq(fulgora[1].min, 800, "fulgora pressure should match Space Age")
  assert_eq(aquilo[1].min, 300, "aquilo pressure should match Space Age")
  assert_eq(aquilo[2].min, 15, "aquilo gravity should match Space Age")

  assert_eq(planets.BASIC_PLANET_ABUNDANCE.vulcanus, "lie", "vulcanus abundance should be lie")
  assert_eq(planets.BASIC_PLANET_ABUNDANCE.gleba, "dubious-data", "gleba abundance should be dubious-data")
  assert_eq(planets.BASIC_PLANET_ABUNDANCE.fulgora, "useless-documentation", "fulgora abundance should be useless-documentation")
end)

test("vulcanus local inputs and narrow notary gates are present and surface-limited", function()
  local required = {
    "paper-production-vulcanus",
    "carbon-offset-certificate-basic-vulcanus",
    "redundant-rubble-recovery-vulcanus",
    "dubious-data-analysis-vulcanus",
    "plastic-bar-vulcanus",
    "refined-nonsense-production-vulcanus",
    "blank-cyan-form-production",
    "vulcanus-lie-distillation",
    "territorial-resettlement-order",
    "territorial-arbitration-post",
  }

  for _, recipe_name in ipairs(required) do
    local recipe = assert(data.raw.recipe[recipe_name], recipe_name .. " missing")
    assert_true(recipe.surface_conditions ~= nil and #recipe.surface_conditions >= 2, recipe_name .. " should be surface-limited")
    assert_eq(recipe.surface_conditions[1].min, 4000, recipe_name .. " should target Vulcanus pressure")
    assert_eq(recipe.surface_conditions[2].min, 40, recipe_name .. " should target Vulcanus gravity")
  end

  assert_true(data.raw.recipe["management-written-approval-vulcanus"] == nil,
    "management-written-approval-vulcanus should stay import-seeded")
  for _, recipe_name in ipairs({
    "provisional-approval-vulcanus",
    "research-grant-approval-vulcanus",
    "administrative-science-pack-production-vulcanus",
    "compacted-rubble-production-vulcanus",
    "safety-waiver-vulcanus",
    "construction-permit-vulcanus",
    "management-approval-verbal-vulcanus",
    "heatproof-filler-documentation",
    "form-27b-6-vulcanus",
  }) do
    assert_true(data.raw.recipe[recipe_name] == nil, recipe_name .. " should defer to a canonical recipe")
  end
end)

test("territorial arbitration post is a Vulcanus-only field office with scripted upkeep inputs", function()
  local entity = assert(data.raw["assembling-machine"]["territorial-arbitration-post"], "territorial-arbitration-post entity missing")
  local recipe = assert(data.raw.recipe["territorial-arbitration-post"], "territorial-arbitration-post recipe missing")
  local processing = assert(data.raw.recipe["territorial-arbitration-processing"], "territorial-arbitration-processing missing")

  assert_eq(entity.fixed_recipe, "territorial-arbitration-processing",
    "territorial-arbitration-post should use the hidden processing recipe")
  assert_eq(entity.crafting_categories[1], "territorial-arbitration",
    "territorial-arbitration-post should use the territorial-arbitration category")
  assert_eq(#(entity.fluid_boxes or {}), 1, "territorial-arbitration-post should expose one fluid input")
  assert_eq(entity.fluid_boxes[1].production_type, "input", "territorial-arbitration-post should take fluid input")

  assert_true(has_ingredient(recipe, "licensed-notary"), "territorial-arbitration-post should require licensed-notary")
  assert_true(has_ingredient(recipe, "tungsten-carbide"), "territorial-arbitration-post should require tungsten-carbide")
  assert_true(recipe.surface_conditions ~= nil and #recipe.surface_conditions >= 2,
    "territorial-arbitration-post should be surface-limited")
  assert_eq(recipe.surface_conditions[1].min, 4000, "territorial-arbitration-post should target Vulcanus pressure")
  assert_eq(recipe.surface_conditions[2].min, 40, "territorial-arbitration-post should target Vulcanus gravity")

  assert_eq(processing.category, "territorial-arbitration", "territorial processing should use the arbitration category")
  assert_true(processing.hidden, "territorial processing should stay hidden")
  assert_true(has_ingredient(processing, "territorial-resettlement-order"),
    "territorial processing should consume territorial-resettlement-order")
end)

test("chromatic recipes stay printer-only while support-heavy paperwork lives in the notary office", function()
  assert_eq(data.raw.recipe["blank-cyan-form-production"].category, "printing-chromatic", "blank-cyan-form should be printer-made")
  assert_eq(data.raw.recipe["inspection-docket"].category, "printing-chromatic", "inspection-docket should be printer-made")
  assert_eq(data.raw.recipe["offworld-metallurgy-charter"].category, "bureaucracy-certification", "offworld charter should be notary-made")
  assert_eq(data.raw.recipe["good-excuse-vulcanus"], nil,
    "Vulcanus should not receive a local generic good-excuse recipe")
end)

test("chromatic printer and liquid black ink are excluded from Aquilo", function()
  local printer_recipe = assert(data.raw.recipe["chromatic-printer"], "chromatic-printer recipe missing")
  local liquid_black_ink = assert(data.raw.recipe["liquid-black-ink"], "liquid-black-ink recipe missing")
  local printer_entity = assert(data.raw["assembling-machine"]["chromatic-printer"], "chromatic-printer entity missing")

  assert_eq(printer_recipe.surface_conditions[1].min, 301, "chromatic-printer recipe should exclude Aquilo pressure")
  assert_eq(liquid_black_ink.surface_conditions[1].min, 301, "liquid-black-ink should exclude Aquilo pressure")
  assert_eq(printer_entity.surface_conditions[1].min, 301, "chromatic-printer entity should exclude Aquilo placement")
end)

test("offworld variants cover materials, not Foundry construction", function()
  assert_eq(#data.raw.recipe["foundry"].surface_conditions, 1,
    "foundry should retain the single vanilla surface condition")
  assert_eq(data.raw.recipe["foundry"].surface_conditions[1].property, "pressure",
    "foundry should retain vanilla pressure gating")
  assert_eq(data.raw.recipe["foundry"].surface_conditions[1].min, 4000,
    "foundry should be restricted to Vulcanus pressure")
  assert_eq(data.raw.recipe["foundry"].surface_conditions[1].max, 4000,
    "foundry should retain vanilla maximum pressure")
  assert_true(has_ingredient(data.raw.recipe["foundry"], "licensed-notary"), "foundry should require licensed-notary")
  assert_true(has_ingredient(data.raw.recipe["foundry"], "tungsten-carbide"), "foundry should require tungsten-carbide")
  assert_true(data.raw.recipe["foundry-offworld"] == nil,
    "foundry must not have a separate offworld construction recipe")
end)

test("licensed notary training is specialized but stays Nauvis-only", function()
  local formation = assert(data.raw.recipe["licensed-notary-formation"], "licensed-notary-formation missing")
  local certification = assert(data.raw.technology["vulcanus-certification"], "vulcanus-certification missing")
  local metallurgy = assert(data.raw.technology["metallurgic-science-pack"], "metallurgic-science-pack missing")
  local export_charters = assert(data.raw.technology["vulcanus-export-charters"], "vulcanus-export-charters missing")

  assert_true(formation.surface_conditions ~= nil and #formation.surface_conditions >= 2,
    "licensed-notary-formation should stay surface-limited")
  assert_eq(formation.surface_conditions[1].min, 1000, "licensed-notary-formation should target Nauvis pressure")
  assert_eq(formation.surface_conditions[2].min, 10, "licensed-notary-formation should target Nauvis gravity")

  local certification_unlocks = {}
  for _, effect in ipairs(certification.effects or {}) do
    if effect.type == "unlock-recipe" then
      certification_unlocks[effect.recipe] = true
    end
  end
  local metallurgy_unlocks = {}
  for _, effect in ipairs(metallurgy.effects or {}) do
    if effect.type == "unlock-recipe" then
      metallurgy_unlocks[effect.recipe] = true
    end
  end
  local export_unlocks = {}
  for _, effect in ipairs(export_charters.effects or {}) do
    if effect.type == "unlock-recipe" then
      export_unlocks[effect.recipe] = true
    end
  end

  assert_true(certification_unlocks["licensed-notary-formation"],
    "Vulcanus certification should unlock the notary needed for the first foundry")
  assert_true(not metallurgy_unlocks["licensed-notary-formation"],
    "metallurgic-science-pack should not unlock licensed-notary-formation")
  assert_true(export_unlocks["offworld-metallurgy-charter"], "vulcanus-export-charters should unlock offworld-metallurgy-charter")
end)

test("gleba ingredient routes are surface-limited and keep the yellow family compact", function()
  local required = {
    "construction-permit-gleba",
    "capture-bureau",
    "capture-bureau-pentapod-eggs",
    "yellow-ink-production",
    "mycelial-form-stock",
    "blank-yellow-form-production",
    "symbiosis-record",
    "conciliation-order",
    "management-approval-written-gleba",
    "composted-rubble-recovery-gleba",
  }

  for _, recipe_name in ipairs(required) do
    local recipe = assert(data.raw.recipe[recipe_name], recipe_name .. " missing")
    assert_true(recipe.surface_conditions ~= nil and #recipe.surface_conditions >= 2, recipe_name .. " should be surface-limited")
    assert_eq(recipe.surface_conditions[1].min, 2000, recipe_name .. " should target Gleba pressure")
    assert_eq(recipe.surface_conditions[2].min, 20, recipe_name .. " should target Gleba gravity")
  end

  assert_true(data.raw.recipe["advanced-circuit-gleba"] == nil,
    "advanced-circuit-gleba should stay absent")
  assert_true(data.raw.recipe["low-density-structure-gleba"] == nil,
    "low-density-structure-gleba should stay absent")
  assert_true(data.raw.recipe["rocket-control-unit-gleba"] == nil,
    "rocket-control-unit-gleba should stay absent")
  assert_true(data.raw.recipe["rocket-silo-gleba"] == nil,
    "rocket-silo-gleba should stay absent")
  for _, recipe_name in ipairs({
    "admin-station-gleba",
    "printer-t1-gleba",
    "corporate-breakroom-gleba",
    "propaganda-distillery-vulcanus",
    "foundry-offworld",
  }) do
    assert_true(data.raw.recipe[recipe_name] == nil, recipe_name .. " must not duplicate a building recipe")
  end
end)

test("vanilla gleba bio recipes remain unmodified and uncloned", function()
  for _, recipe_name in ipairs({"rocket-fuel-from-jelly", "bioplastic", "biosulfur", "biolubricant"}) do
    local source = assert(data.raw.recipe[recipe_name], recipe_name .. " missing")
    assert_true(source.surface_conditions == nil,
      recipe_name .. " should retain its vanilla surface conditions")
    assert_true(data.raw.recipe[recipe_name .. "-offworld"] == nil,
      recipe_name .. " must not gain an offworld clone")
  end
  assert_true(data.raw.item["biochamber-operating-waiver"] == nil,
    "obsolete offworld Biochamber paperwork should not exist")
end)

test("fulgora bureau and magenta paperwork stay on fulgora", function()
  local required = {
    "digital-services-bureau",
    "charged-toner",
    "archive-rubble-recovery",
    "archive-documentation-recovery",
    "magenta-ink-production",
    "signal-form-stock",
    "blank-magenta-form-production",
    "archive-recovery-permit",
    "digital-processing-certificate",
    "electromagnetic-operating-license",
    "data-recovery-order",
  }

  for _, recipe_name in ipairs(required) do
    local recipe = assert(data.raw.recipe[recipe_name], recipe_name .. " missing")
    assert_true(recipe.surface_conditions ~= nil and #recipe.surface_conditions >= 2, recipe_name .. " should be surface-limited")
    assert_eq(recipe.surface_conditions[1].min, 800, recipe_name .. " should target Fulgora pressure")
    assert_eq(recipe.surface_conditions[2].min, 8, recipe_name .. " should target Fulgora gravity")
  end

  assert_eq(data.raw.recipe["blank-magenta-form-production"].category, "printing-chromatic",
    "blank-magenta-form should be printer-made")
  assert_eq(data.raw.recipe["archive-rubble-recovery"].category, "bureaucratic-bootstrap-fulgora",
    "archive-rubble-recovery should stay a Fulgora bootstrap salvage recipe")
  assert_eq(data.raw.recipe["digital-processing-certificate"].category, "bureaucracy-registration-fulgora",
    "digital-processing-certificate should be Fulgora office work")
  assert_true(has_ingredient(data.raw.recipe["digital-services-bureau"], "relay-clerk"),
    "digital-services-bureau should require relay-clerk")
  assert_true(has_ingredient(data.raw.recipe["electromagnetic-operating-license"], "digital-processing-certificate"),
    "electromagnetic-operating-license should build from digital-processing-certificate")
end)

test("aquilo fax and multicolor paperwork stay on Aquilo", function()
  local required = {
    "laser-printer",
    "fax-emitter",
    "interplanetary-fax-exchange",
    "transfer-emulsion-production",
    "thermal-transfer-sheet-production",
    "composite-chroma-ribbon-production",
    "trichromatic-permit-production",
    "unified-operations-charter-production",
    "cryogenic-operations-license-production",
  }

  for _, recipe_name in ipairs(required) do
    local recipe = assert(data.raw.recipe[recipe_name], recipe_name .. " missing")
    assert_true(recipe.surface_conditions ~= nil and #recipe.surface_conditions >= 2, recipe_name .. " should be surface-limited")
    assert_eq(recipe.surface_conditions[1].min, 300, recipe_name .. " should target Aquilo pressure")
    assert_eq(recipe.surface_conditions[2].min, 15, recipe_name .. " should target Aquilo gravity")
  end

  assert_eq(data.raw.recipe["transfer-emulsion-production"].category, "chemistry-or-cryogenics",
    "transfer-emulsion should be chemical-plant compatible before the first cryogenic plant")
  assert_eq(data.raw.recipe["composite-chroma-ribbon-production"].category, "printing-multicolor",
    "composite-chroma-ribbon should be laser-printer multicolor work")
  assert_eq(data.raw.recipe["cryogenic-operations-license-production"].category, "printing-multicolor",
    "cryogenic-operations-license should be multicolor printed")
  assert_true(has_ingredient(data.raw.recipe["laser-printer"], "cryoprint-technician"),
    "laser-printer should require cryoprint-technician")
  assert_true(has_ingredient(data.raw.recipe["fax-emitter"], "cryoprint-technician"),
    "fax-emitter should require cryoprint-technician")
  assert_true(has_ingredient(data.raw.recipe["interplanetary-fax-exchange"], "cryoprint-technician"),
    "interplanetary-fax-exchange should require cryoprint-technician")
end)

if failed > 0 then
  io.stderr:write(("Failed %d/%d tests\n"):format(failed, passed + failed))
  for _, err in ipairs(errors) do
    io.stderr:write(err, "\n")
  end
  os.exit(1)
end

print(("Passed %d tests"):format(passed))
