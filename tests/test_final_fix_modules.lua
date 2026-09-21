-------------------------------------------------------------------------------
-- Direct tests for final-fix passes that do not need the full data-stage mock.
-------------------------------------------------------------------------------

local passed, failed, errors = 0, 0, {}
local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then passed = passed + 1 else failed = failed + 1; errors[#errors + 1] = name .. ": " .. tostring(err) end
end
local function assert_true(value, message) if not value then error(message or "assertion failed", 2) end end
local function assert_eq(actual, expected, message)
  if actual ~= expected then error((message or "") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end
local function mask_has_layer(mask, layer)
  if mask.layers then return mask.layers[layer] == true end
  for _, name in ipairs(mask) do
    if name == layer then return true end
  end
  return false
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)"):gsub("tests/$", "")
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

util = {table = {deepcopy = function(value)
  if type(value) ~= "table" then return value end
  local copy = {}
  for key, entry in pairs(value) do copy[key] = util.table.deepcopy(entry) end
  return copy
end}}
kg, grams, tons = 1, 0.001, 1000
package.preload["collision-mask-util"] = function()
  return {
    get_default_mask = function(prototype_type)
      if prototype_type == "car" then
        return {layers = {player = true, car = true, train = true, is_object = true}}
      end
      return {layers = {item = true, object = true, player = true, water_tile = true}}
    end,
    masks_collide = function(mask_a, mask_b)
      for layer in pairs(mask_a.layers or {}) do
        if mask_b.layers and mask_b.layers[layer] then return true end
      end
      return false
    end,
  }
end

local function ingredient_names(recipe)
  local names = {}
  for _, ingredient in ipairs(recipe.ingredients or {}) do names[ingredient.name or ingredient[1]] = true end
  return names
end

test("science-pack stripping removes item packs at every recipe level", function()
  local stripping = require("prototypes.final_fixes.science_pack_stripping")
  local data = {raw = {
    item = {}, tool = {science = {name = "science", subgroup = "science-pack"}},
    recipe = {sample = {ingredients = {{type = "item", name = "science"}, {type = "fluid", name = "water"}},
      normal = {ingredients = {{type = "item", name = "science"}}},
      expensive = {ingredients = {{type = "item", name = "science"}}}}},
  }}
  stripping.apply(data, {"item", "tool"})
  assert_eq(#data.raw.recipe.sample.ingredients, 1)
  assert_eq(#data.raw.recipe.sample.normal.ingredients, 0)
  assert_eq(#data.raw.recipe.sample.expensive.ingredients, 0)
  stripping.apply(data, {"item", "tool"})
  assert_eq(#data.raw.recipe.sample.ingredients, 1, "stripping should be idempotent")
end)

test("unstaffed operation gating discovers categories and preserves managed machines", function()
  local gating = require("prototypes.final_fixes.unstaffed_operations_gating")
  local data = {raw = {
    ["module-category"] = {speed = {}, productivity = {}, ["unstaffed-operations"] = {}},
    ["assembling-machine"] = {
      printer = {name = "printer", module_slots = 2},
      managed = {name = "managed", module_slots = 2},
      empty = {name = "empty", module_slots = 0},
    },
  }}
  gating.apply(data, {"managed"})
  assert_eq(#data.raw["assembling-machine"].printer.allowed_module_categories, 2)
  assert_eq(data.raw["assembling-machine"].printer.allowed_module_categories[1], "productivity")
  assert_true(data.raw["assembling-machine"].managed.allowed_module_categories == nil)
  gating.apply(data, {"managed"})
  assert_eq(#data.raw["assembling-machine"].printer.allowed_module_categories, 2, "gating should be idempotent")
end)

test("space platform permits replace all paperwork and are idempotent", function()
  local permits = require("prototypes.final_fixes.space_platform_permits")
  local shared = {SPACE_PLATFORM_BUILDING_RECIPES = {platform = true}, PAPERWORK_ITEMS = {permit = true, order = true}}
  local data = {raw = {
    recipe = {platform = {ingredients = {{type = "item", name = "permit"}, {type = "item", name = "steel"}}}},
    item = {platform = {subgroup = "space-platform", place_result = "platform"}},
  }}
  local helpers = {
    ingredient_name = function(ingredient) return ingredient.name or ingredient[1] end,
    append_or_merge_ingredient = function(list, ingredient)
      for _, existing in ipairs(list) do
        if (existing.name or existing[1]) == (ingredient.name or ingredient[1]) then return end
      end
      list[#list + 1] = ingredient
    end,
  }
  permits.apply(data, shared, {"item"}, helpers)
  local names = ingredient_names(data.raw.recipe.platform)
  assert_true(names["orbital-infrastructure-permit"])
  assert_true(not names.permit)
  permits.apply(data, shared, {"item"}, helpers)
  assert_eq(#data.raw.recipe.platform.ingredients, 2, "platform permit pass should be idempotent")
end)

test("rocket weights apply defaults and explicit overrides", function()
  local weights = require("prototypes.final_fixes.rocket_weights")
  data = {raw = {item = {
    ["blank-form"] = {name = "blank-form", subgroup = "forms-permits"},
    ["construction-work-order"] = {name = "construction-work-order"},
    ["paper"] = {name = "paper"},
    ["biter-worker"] = {name = "biter-worker"},
  }, tool = {}, ammo = {}}}
  weights.apply()
  assert_eq(data.raw.item["blank-form"].weight, 1 * kg)
  assert_eq(data.raw.item["construction-work-order"].weight, 3 * kg)
  assert_eq(data.raw.item.paper.weight, 100 * grams)
  assert_eq(data.raw.item["biter-worker"].weight, 100 * kg)
  weights.apply()
  assert_eq(data.raw.item["construction-work-order"].weight, 3 * kg, "weight pass should be idempotent")
end)

test("collision masks separate worker obstacles from passable infrastructure", function()
  local masks = require("prototypes.final_fixes.collision_masks")
  data = {raw = {
    item = {}, ["module-category"] = {speed = {}, productivity = {}},
    chest = {box = {name = "box", type = "container", collision_mask = {"item", "player"}, collision_box = {{-1, -1}, {1, 1}}, module_slots = 1}},
    ["assembling-machine"] = {
      machine = {name = "machine", type = "assembling-machine", collision_mask = {"item", "object", "player"}, collision_box = {{-1, -1}, {1, 1}}},
      default_mask_machine = {name = "default-mask-machine", type = "assembling-machine", collision_box = {{-1, -1}, {1, 1}}},
    },
    ["electric-pole"] = {
      pole = {name = "pole", type = "electric-pole", collision_mask = {"object", "player"}, collision_box = {{-0.2, -0.2}, {0.2, 0.2}}},
    },
    inserter = {
      inserter = {name = "inserter", type = "inserter", collision_mask = {"object", "player"}, collision_box = {{-0.2, -0.2}, {0.2, 0.2}}},
    },
    tree = {
      tree = {name = "tree", type = "tree", collision_mask = {"object", "player"}, collision_box = {{-0.4, -0.4}, {0.4, 0.4}}},
    },
    ["offshore-pump"] = {
      pump = {name = "offshore-pump", type = "offshore-pump",
        collision_mask = {layers = {object = true, train = true, is_object = true, is_lower_object = true}},
        collision_box = {{-0.6, -1.05}, {0.6, 0.3}}},
    },
    ["pipe-to-ground"] = {
      pipe = {name = "pipe-to-ground", type = "pipe-to-ground",
        collision_mask = {layers = {item = true, car = true, water_tile = true}},
        collision_box = {{-0.4, -0.4}, {0.4, 0.4}}},
    },
    ["spider-leg"] = {
      leg = {name = "spider-leg", type = "spider-leg",
        collision_mask = {layers = {player = true, rail = true}},
        collision_box = {{-0.2, -0.2}, {0.2, 0.2}}},
    },
    ["transport-belt"] = {
      belt = {name = "belt", type = "transport-belt", collision_mask = {"object"}, collision_box = {{-0.4, -0.4}, {0.4, 0.4}}},
    },
    car = {
      car = {name = "car", type = "car", collision_box = {{-0.7, -1}, {0.7, 1}}},
      rideable = {name = "rideable-biter", type = "car", collision_mask = {layers = {administratorio_rideable_biter_collision = true, administratorio_rideable_biter_terrain = true, train = true}}, collision_box = {{-0.3, -0.4}, {0.3, 0.4}}},
    },
    container = {
      station = {name = "biter-station", type = "container", collision_mask = {"administratorio_station_footprint"}, collision_box = {{-2, -2}, {2, 2}}},
      biterport = {name = "biterport", type = "container", collision_mask = {"administratorio_station_footprint"}, collision_box = {{-2, -2}, {2, 2}}},
      admin = {name = "admin-station", type = "container", collision_mask = {"administratorio_station_footprint"}, collision_box = {{-4, -4}, {4, 4}}},
    },
    furnace = {
      bureau = {name = "capture-bureau", type = "furnace", collision_mask = {"administratorio_station_footprint"}, collision_box = {{-4, -4}, {4, 4}}},
    },
    character = {character = {name = "character", type = "character", collision_mask = {layers = {player = true, train = true, is_object = true}}, collision_box = {{-1, -1}, {1, 1}}}},
    tile = {
      water = {name = "water", collision_mask = {layers = {water_tile = true, player = true}}},
      dirt = {name = "dirt", collision_mask = {layers = {ground_tile = true}}},
    },
  }}
  masks.apply(data, true)
  assert_true(data.raw.chest.box.collision_mask.layers.administratorio_station_footprint)
  assert_true(data.raw.chest.box.collision_mask.layers.administratorio_worker_obstacle)
  assert_true(data.raw["assembling-machine"].machine.collision_mask.layers.administratorio_worker_obstacle)
  assert_true(data.raw["assembling-machine"].default_mask_machine.collision_mask.layers.administratorio_worker_obstacle)
  assert_true(not mask_has_layer(data.raw["electric-pole"].pole.collision_mask, "administratorio_worker_obstacle"))
  assert_true(not mask_has_layer(data.raw.inserter.inserter.collision_mask, "administratorio_worker_obstacle"))
  assert_true(not mask_has_layer(data.raw["transport-belt"].belt.collision_mask, "administratorio_worker_obstacle"))
  assert_true(not mask_has_layer(data.raw.container.station.collision_mask, "administratorio_worker_obstacle"))
  assert_true(not mask_has_layer(data.raw.container.biterport.collision_mask, "administratorio_worker_obstacle"))
  assert_true(not mask_has_layer(data.raw.container.admin.collision_mask, "administratorio_worker_obstacle"))
  assert_true(not mask_has_layer(data.raw.furnace.bureau.collision_mask, "administratorio_worker_obstacle"))
  assert_true(data.raw.tile.water.collision_mask.layers.administratorio_worker_terrain)
  assert_true(not data.raw.tile.dirt.collision_mask.layers.administratorio_worker_terrain)
  assert_true(data.raw.chest.box.collision_mask.layers.administratorio_rideable_biter_collision)
  assert_true(data.raw["assembling-machine"].machine.collision_mask.layers.administratorio_rideable_biter_collision)
  assert_true(not mask_has_layer(data.raw.car.car.collision_mask, "administratorio_rideable_biter_collision"))
  assert_true(data.raw.car.rideable.collision_mask.layers.administratorio_rideable_biter_collision)
  assert_true(not data.raw.car.rideable.collision_mask.layers.administratorio_worker_obstacle)
  assert_true(data.raw.tile.water.collision_mask.layers.administratorio_rideable_biter_terrain)
  assert_true(not data.raw.tile.water.collision_mask.layers.administratorio_rideable_biter_collision)
  assert_true(not data.raw["offshore-pump"].pump.collision_mask.layers.administratorio_rideable_biter_collision)
  assert_true(not data.raw["offshore-pump"].pump.collision_mask.layers.administratorio_rideable_biter_terrain)
  local collides = package.preload["collision-mask-util"]().masks_collide
  assert_true(not collides(data.raw["offshore-pump"].pump.collision_mask, data.raw.tile.water.collision_mask),
    "offshore pump must remain placeable beside water")
  assert_true(collides(data.raw["offshore-pump"].pump.collision_mask, data.raw.car.rideable.collision_mask),
    "mounted biter must still collide with offshore pumps")
  assert_true(not collides(data.raw.character.character.collision_mask, data.raw["pipe-to-ground"].pipe.collision_mask),
    "character must still walk over underground pipes")
  assert_true(not collides(data.raw["spider-leg"].leg.collision_mask, data.raw["pipe-to-ground"].pipe.collision_mask),
    "spider legs must still cross underground pipes")
  assert_true(not mask_has_layer(data.raw.tile.dirt.collision_mask, "administratorio_rideable_biter_terrain"))
  assert_true(not mask_has_layer(data.raw.tree.tree.collision_mask, "administratorio_rideable_biter_collision"))
  assert_true(not mask_has_layer(data.raw.inserter.inserter.collision_mask, "administratorio_rideable_biter_collision"))
  assert_true(not mask_has_layer(data.raw["electric-pole"].pole.collision_mask, "administratorio_rideable_biter_collision"))
  assert_true(not mask_has_layer(data.raw["transport-belt"].belt.collision_mask, "administratorio_rideable_biter_collision"))
  assert_eq(#data.raw.chest.box.allowed_module_categories, 2)
  masks.apply(data, true)
  assert_eq(#data.raw.chest.box.allowed_module_categories, 2, "collision pass should be idempotent")
end)

test("rolling stock keeps vanilla mask so trains can use rail ramps", function()
  package.loaded["prototypes.final_fixes.collision_masks"] = nil
  local masks = require("prototypes.final_fixes.collision_masks")
  local function layers(names)
    local result = {layers = {}}
    for _, name in ipairs(names) do result.layers[name] = true end
    return result
  end
  local function collides(mask_a, mask_b)
    for layer in pairs(mask_a.layers or {}) do
      if mask_b.layers and mask_b.layers[layer] then return true end
    end
    return false
  end
  -- Vanilla masks: stock is train-only, ramps/supports block cars via is_object.
  local stock_box = {{-0.6, -1.8}, {0.6, 1.8}}
  local ramp_mask = layers({"elevated_rail", "object", "rail", "rail_support", "is_lower_object", "is_object"})
  local support_mask = layers({"object", "rail", "rail_support", "is_lower_object", "is_object"})
  local stock_mask = layers({"train"})
  data = {raw = {
    item = {}, ["module-category"] = {},
    locomotive = {
      loco = {name = "loco", type = "locomotive", collision_mask = layers({"train"}), collision_box = stock_box},
      default_loco = {name = "default-loco", type = "locomotive", collision_box = stock_box},
    },
    ["cargo-wagon"] = {
      wagon = {name = "wagon", type = "cargo-wagon", collision_mask = layers({"train"}), collision_box = stock_box},
    },
    ["fluid-wagon"] = {
      wagon = {name = "wagon", type = "fluid-wagon", collision_mask = layers({"train"}), collision_box = stock_box},
    },
    ["artillery-wagon"] = {
      wagon = {name = "wagon", type = "artillery-wagon", collision_mask = layers({"train"}), collision_box = stock_box},
    },
    ["rail-ramp"] = {
      ramp = {name = "ramp", type = "rail-ramp", collision_mask = ramp_mask, collision_box = {{-1, -3}, {1, 3}}},
    },
    ["rail-support"] = {
      support = {name = "support", type = "rail-support", collision_mask = support_mask, collision_box = {{-1, -1}, {1, 1}}},
    },
    car = {
      rideable = {name = "rideable-biter", type = "car", collision_mask = layers({"administratorio_rideable_biter_collision", "train"}), collision_box = {{-0.3, -0.4}, {0.3, 0.4}}},
    },
  }}
  masks.apply(data, false)
  local loco = data.raw.locomotive.loco.collision_mask
  assert_true(not mask_has_layer(loco, "administratorio_rideable_biter_collision"), "locomotive must not gain the rideable layer")
  assert_true(not mask_has_layer(data.raw.locomotive.default_loco.collision_mask, "administratorio_rideable_biter_collision"), "default-mask locomotive must not gain the rideable layer")
  assert_true(not mask_has_layer(data.raw["cargo-wagon"].wagon.collision_mask, "administratorio_rideable_biter_collision"), "cargo wagon must not gain the rideable layer")
  assert_true(not mask_has_layer(data.raw["fluid-wagon"].wagon.collision_mask, "administratorio_rideable_biter_collision"), "fluid wagon must not gain the rideable layer")
  assert_true(not mask_has_layer(data.raw["artillery-wagon"].wagon.collision_mask, "administratorio_rideable_biter_collision"), "artillery wagon must not gain the rideable layer")
  local ramp = data.raw["rail-ramp"].ramp.collision_mask
  local support = data.raw["rail-support"].support.collision_mask
  assert_true(not collides(loco, ramp), "locomotive must not collide with rail ramps")
  assert_true(not collides(loco, support), "locomotive must not collide with rail supports")
  assert_true(not collides(stock_mask, ramp), "default stock mask must not collide with rail ramps")
  -- The rideable biter still collides with ramps/supports like a car does.
  assert_true(collides(data.raw.car.rideable.collision_mask, ramp), "rideable biter must stay blocked by rail ramps")
  assert_true(collides(data.raw.car.rideable.collision_mask, support), "rideable biter must stay blocked by rail supports")
end)

print(("Final-fix module tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then for _, err in ipairs(errors) do print(" - " .. err) end; os.exit(1) end
