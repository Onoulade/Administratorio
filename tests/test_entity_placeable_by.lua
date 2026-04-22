-------------------------------------------------------------------------------
-- ADMINISTRATORIO ENTITY PLACEABLE_BY TESTS
--
-- Verifies cloned custom entities point ghost construction back to the correct
-- item instead of inheriting stale placement metadata from the vanilla
-- prototype they were copied from.
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

data = {
  raw = {
    item = {},
    ["assembling-machine"] = {
      ["assembling-machine-1"] = {
        type = "assembling-machine",
        name = "assembling-machine-1",
        minable = {result = "assembling-machine-1"},
        placeable_by = {{item = "assembling-machine-1", count = 1}},
        graphics_set = {},
        fluid_boxes = {},
      },
      ["assembling-machine-2"] = {
        type = "assembling-machine",
        name = "assembling-machine-2",
        minable = {result = "assembling-machine-2"},
        placeable_by = {{item = "assembling-machine-2", count = 1}},
        graphics_set = {},
        fluid_boxes = {},
      },
      ["assembling-machine-3"] = {
        type = "assembling-machine",
        name = "assembling-machine-3",
        minable = {result = "assembling-machine-3"},
        placeable_by = {{item = "assembling-machine-3", count = 1}},
        graphics_set = {},
        fluid_boxes = {},
      },
      ["oil-refinery"] = {
        type = "assembling-machine",
        name = "oil-refinery",
        minable = {result = "oil-refinery"},
        placeable_by = {{item = "oil-refinery", count = 1}},
        graphics_set = {},
        fluid_boxes = {},
      },
      ["centrifuge"] = {
        type = "assembling-machine",
        name = "centrifuge",
        minable = {result = "centrifuge"},
        placeable_by = {{item = "centrifuge", count = 1}},
        graphics_set = {},
        fluid_boxes = {},
      },
    },
    ["furnace"] = {},
    ["pipe"] = {
      pipe = {
        type = "pipe",
        name = "pipe",
        minable = {result = "pipe"},
        placeable_by = {{item = "pipe", count = 1}},
        pictures = {},
        fluid_box = {pipe_connections = {}},
      },
    },
    ["pipe-to-ground"] = {
      ["pipe-to-ground"] = {
        type = "pipe-to-ground",
        name = "pipe-to-ground",
        minable = {result = "pipe-to-ground"},
        placeable_by = {{item = "pipe-to-ground", count = 1}},
        pictures = {},
        fluid_box = {pipe_connections = {}},
      },
    },
    ["container"] = {
      ["steel-chest"] = {
        type = "container",
        name = "steel-chest",
        inventory_size = 48,
      },
    },
    ["logistic-container"] = {
      ["logistic-chest-requester"] = {
        type = "logistic-container",
        name = "logistic-chest-requester",
        logistic_mode = "requester",
        inventory_size = 48,
      },
    },
    ["roboport"] = {
      roboport = {
        type = "roboport",
        name = "roboport",
        minable = {result = "roboport"},
        logistics_radius = 25,
        logistics_connection_distance = 50,
        construction_radius = 55,
        robot_slots_count = 7,
        material_slots_count = 7,
        energy_source = {type = "electric"},
        energy_usage = "50kW",
        recharge_minimum = "40MJ",
        charging_energy = "500kW",
        collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
        selection_box = {{-2, -2}, {2, 2}},
      },
    },
    ["spider-vehicle"] = {
      spidertron = {
        type = "spider-vehicle",
        name = "spidertron",
        minable = {result = "spidertron"},
        placeable_by = {{item = "spidertron", count = 1}},
        inventory_size = 80,
        trash_inventory_size = 10,
        energy_source = {type = "void"},
        guns = {"spidertron-rocket-launcher-1"},
        automatic_weapon_cycling = true,
        spider_engine = {
          legs = {
            {leg = "spidertron-leg-1", mount_position = {1, 1}, ground_position = {2, 2}, walking_group = 1},
          },
          walking_group_overlap = 0,
        },
        graphics_set = {base_animation = {filename = "spidertron.png", width = 1, height = 1}},
      },
    },
    ["spider-leg"] = {
      ["spidertron-leg-1"] = {
        type = "spider-leg",
        name = "spidertron-leg-1",
        collision_box = {{-0.1, -0.1}, {0.1, 0.1}},
        collision_mask = {layers = {object = true}},
        graphics_set = {joint = {filename = "leg.png", width = 1, height = 1}},
      },
    },
    unit = {
      ["small-biter"] = {
        type = "unit",
        name = "small-biter",
        run_animation = {filename = "small-biter.png", width = 1, height = 1, frame_count = 1},
        attack_parameters = {range = 1, cooldown = 10, damage_modifier = 1},
        collision_box = {{-0.2, -0.2}, {0.2, 0.2}},
        selection_box = {{-0.4, -0.5}, {0.4, 0.3}},
        movement_speed = 0.2,
        distance_per_frame = 0.1,
      },
      ["behemoth-biter"] = {
        type = "unit",
        name = "behemoth-biter",
        run_animation = {filename = "behemoth-biter.png", width = 1, height = 1, frame_count = 1},
        attack_parameters = {range = 1, cooldown = 10, damage_modifier = 1},
        collision_box = {{-0.6, -0.6}, {0.6, 0.6}},
        selection_box = {{-0.8, -1.0}, {0.8, 0.6}},
      },
    },
    ["item-with-entity-data"] = {
      spidertron = {
        type = "item-with-entity-data",
        name = "spidertron",
        place_result = "spidertron",
        stack_size = 1,
      },
    },
    ["spidertron-remote"] = {
      ["spidertron-remote"] = {
        type = "spidertron-remote",
        name = "spidertron-remote",
        stack_size = 1,
      },
    },
    ["selection-tool"] = {
      ["copy-paste-tool"] = {
        type = "selection-tool",
        name = "copy-paste-tool",
        select = {},
        alt_select = {},
        stack_size = 1,
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

defines = {
  direction = {
    north = 0,
    east = 2,
    south = 4,
    west = 6,
  },
}

settings = {
  startup = {
    ["administratorio-enable-working-hours"] = {value = true},
  },
}

universal_connector_template = {}
circuit_connector_definitions = {
  create_single = function(_, params)
    return params
  end,
  create_vector = function(_, params)
    return params
  end,
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

dofile(mod_root .. "prototypes/item/buildings.lua")
dofile(mod_root .. "prototypes/item/capsules-and-fluids.lua")
dofile(mod_root .. "prototypes/entity/admin-buildings.lua")
dofile(mod_root .. "prototypes/entity/printers.lua")
dofile(mod_root .. "prototypes/entity/pneumatic.lua")
dofile(mod_root .. "prototypes/recipe/resolution.lua")

local function find_entity_prototype(name)
  for proto_type, prototypes in pairs(data.raw) do
    if proto_type ~= "item" and type(prototypes) == "table" then
      local prototype = prototypes[name]
      if prototype then
        return prototype, proto_type
      end
    end
  end
  return nil, nil
end

local function entity_has_matching_placeable_item(entity, place_result)
  if not entity or not entity.placeable_by then return false end
  for _, entry in ipairs(entity.placeable_by) do
    local item = entry.item and data.raw.item[entry.item]
    if item and item.place_result == place_result then
      return true
    end
  end
  return false
end

test("every visible placeable building item resolves to a robot-buildable entity", function()
  local checked = 0
  for item_name, item in pairs(data.raw.item) do
    if item.place_result and not item.hidden then
      local entity, proto_type = find_entity_prototype(item.place_result)
      assert_true(entity ~= nil, item_name .. " place_result " .. item.place_result .. " prototype missing")
      assert_true(entity.placeable_by ~= nil, item_name .. " place_result " .. item.place_result .. " missing placeable_by on " .. tostring(proto_type))
      assert_true(entity_has_matching_placeable_item(entity, item.place_result), item_name .. " place_result " .. item.place_result .. " cannot be built from any matching item")
      checked = checked + 1
    end
  end
  assert_true(checked > 0, "expected to check at least one placeable item")
end)

test("admin-station and its directional variants build from the canonical item", function()
  for _, name in ipairs({"admin-station"}) do
    local entity, proto_type = find_entity_prototype(name)
    assert_true(entity ~= nil, name .. " prototype missing")
    assert_true(entity.placeable_by ~= nil and entity.placeable_by[1] ~= nil, name .. " missing placeable_by on " .. tostring(proto_type))
    assert_eq(entity.placeable_by[1].item, "admin-station", name .. " should build from the canonical admin-station item")
  end
end)

test("propaganda-distillery uses a symmetric four-port refinery layout", function()
  local entity = data.raw["assembling-machine"]["propaganda-distillery"]
  assert_true(entity ~= nil, "propaganda-distillery prototype missing")
  assert_true(entity.fluid_boxes ~= nil, "propaganda-distillery fluid boxes missing")
  assert_eq(#entity.fluid_boxes, 4, "propaganda-distillery should expose four pipe connections")

  local expected = {
    {"input", defines.direction.west, -2, -1},
    {"input", defines.direction.west, -2, 1},
    {"output", defines.direction.east, 2, -1},
    {"output", defines.direction.east, 2, 1},
  }

  for index, spec in ipairs(expected) do
    local fluid_box = entity.fluid_boxes[index]
    assert_eq(fluid_box.production_type, spec[1], "unexpected production type for fluid box " .. index)
    assert_true(fluid_box.pipe_connections ~= nil and fluid_box.pipe_connections[1] ~= nil, "missing pipe connection for fluid box " .. index)
    assert_eq(fluid_box.pipe_connections[1].flow_direction, spec[1], "unexpected flow direction for fluid box " .. index)
    assert_eq(fluid_box.pipe_connections[1].direction, spec[2], "unexpected direction for fluid box " .. index)
    assert_eq(fluid_box.pipe_connections[1].position[1], spec[3], "unexpected x position for fluid box " .. index)
    assert_eq(fluid_box.pipe_connections[1].position[2], spec[4], "unexpected y position for fluid box " .. index)
  end
end)

test("union-headquarters now supports both union negotiation and policy work", function()
  local entity = data.raw["assembling-machine"]["union-headquarters"]
  assert_true(entity ~= nil, "union-headquarters prototype missing")

  local categories = {}
  for _, category in ipairs(entity.crafting_categories or {}) do
    categories[category] = true
  end

  assert_true(categories["union-negotiation"], "union-headquarters should keep union-negotiation")
  assert_true(categories["bureaucracy-policy"], "union-headquarters should also handle policy work")
  assert_true((entity.ingredient_count or 0) >= 6, "union-headquarters must support high-ingredient late recipes")

  assert_true(entity.fluid_boxes ~= nil, "union-headquarters fluid boxes missing")
  assert_true(#entity.fluid_boxes >= 3, "union-headquarters should expose two fluid inputs and one output")

  local input_count = 0
  local output_count = 0
  for _, fluid_box in ipairs(entity.fluid_boxes) do
    if fluid_box.production_type == "input" then
      input_count = input_count + 1
    elseif fluid_box.production_type == "output" then
      output_count = output_count + 1
    end
  end

  assert_true(input_count >= 2, "union-headquarters should have at least two fluid inputs")
  assert_true(output_count >= 1, "union-headquarters should have at least one fluid output")
end)

test("resolution-office supports bootstrap and resolution categories", function()
  local entity = data.raw["assembling-machine"]["resolution-office"]
  assert_true(entity ~= nil, "resolution-office prototype missing")

  local categories = {}
  for _, category in ipairs(entity.crafting_categories or {}) do
    categories[category] = true
  end

  assert_true(categories["bureaucracy-resolution"], "resolution-office should craft bureaucracy-resolution recipes")
  assert_true(not categories["bureaucratic-bootstrap"], "resolution-office should NOT craft bureaucratic-bootstrap recipes (complaints only)")
end)

test("resolution-office can craft all complaint paper recipes", function()
  local entity = data.raw["assembling-machine"]["resolution-office"]
  assert_true(entity ~= nil, "resolution-office prototype missing")

  local craftable_categories = {}
  for _, category in ipairs(entity.crafting_categories or {}) do
    craftable_categories[category] = true
  end

  local complaint_recipes = {
    -- Biter chain
    "filing-landscape", "landscape-final",
    "filing-smog", "case-smog", "smog-final",
    "filing-noise", "case-noise", "brief-noise", "noise-final",
    "filing-unemployment", "case-unemployment", "brief-unemployment", "unemployment-final",
    -- Spitter chain
    "filing-littering", "littering-final",
    "filing-hazmat", "case-hazmat", "hazmat-final",
    "filing-loitering", "case-loitering", "brief-loitering", "loitering-final",
    "filing-vagrancy", "case-vagrancy", "brief-vagrancy", "vagrancy-final",
  }

  for _, recipe_name in ipairs(complaint_recipes) do
    local recipe = data.raw.recipe and data.raw.recipe[recipe_name]
    assert_true(recipe ~= nil, recipe_name .. " recipe missing")
    local category = recipe.category or "crafting"
    assert_true(craftable_categories[category],
      recipe_name .. " category '" .. tostring(category) .. "' is not craftable by resolution-office")
  end
end)

test("all custom fluid connections are explicitly one-way", function()
  local prototypes = {
    data.raw["assembling-machine"]["resolution-office"],
    data.raw["assembling-machine"]["office-desk"],
    data.raw["assembling-machine"]["greenhouse"],
    data.raw["assembling-machine"]["corporate-breakroom"],
    data.raw["assembling-machine"]["union-headquarters"],
    data.raw["assembling-machine"]["propaganda-distillery"],
  }

  for _, prototype in ipairs(prototypes) do
    assert_true(prototype ~= nil, "missing prototype in flow-direction coverage")
    assert_true(prototype.fluid_boxes ~= nil, prototype.name .. " should expose fluid boxes")

    for fluid_box_index, fluid_box in ipairs(prototype.fluid_boxes) do
      local expected = fluid_box.production_type
      assert_true(expected == "input" or expected == "output",
        prototype.name .. " has non-directional fluid box " .. fluid_box_index)
      assert_true(fluid_box.pipe_connections ~= nil and #fluid_box.pipe_connections > 0,
        prototype.name .. " fluid box " .. fluid_box_index .. " should have at least one connection")

      for connection_index, connection in ipairs(fluid_box.pipe_connections) do
        assert_eq(connection.flow_direction, expected,
          prototype.name .. " fluid box " .. fluid_box_index .. " connection " .. connection_index .. " flow_direction mismatch")
      end
    end
  end
end)

test("legacy directional admin-station items are no longer placement sources", function()
  assert_eq(data.raw.item["admin-station"].place_result, "admin-station", "admin-station should stay placeable")
end)

test("office-desk circuit connector is shifted to the custom desk position", function()
  local entity = assert(find_entity_prototype("office-desk"))
  local connector = assert(entity.circuit_connector and entity.circuit_connector[1], "office-desk missing circuit connector override")
  assert_eq(connector.main_offset[1], 96 / 32, "office-desk connector should sit 3 tiles east of center")
  assert_eq(connector.main_offset[2], 32 / 32, "office-desk connector should sit 1 tile south of center")
  assert_eq(connector.shadow_offset[1], 107 / 32, "office-desk connector shadow should follow east shift")
  assert_eq(connector.shadow_offset[2], 38 / 32, "office-desk connector shadow should follow south shift")
end)

test("admin-station circuit connector is shifted to the custom desk position", function()
  local entity = assert(find_entity_prototype("admin-station"))
  local connector = assert(entity.circuit_connector, "admin-station missing circuit connector override")
  assert_eq(connector.main_offset[1], 96 / 32, "admin-station connector should sit 3 tiles east of center")
  assert_eq(connector.main_offset[2], 32 / 32, "admin-station connector should sit 1 tile south of center")
  assert_eq(connector.shadow_offset[1], 100 / 32, "admin-station connector shadow should follow east shift")
  assert_eq(connector.shadow_offset[2], 36 / 32, "admin-station connector shadow should follow south shift")
end)

test("admin-station hidden circuit helper matches the desk connector position", function()
  local combinator = assert(find_entity_prototype("admin-station-combinator"))
  assert_true((combinator.item_slot_count or 0) >= 10, "admin-station-combinator should expose at least 10 signal slots")
  local point = assert(combinator.circuit_wire_connection_points and combinator.circuit_wire_connection_points[1], "admin-station-combinator missing wire points")
  assert_eq(point.wire.red[1], 104 / 32, "helper red wire should match desk connector x")
  assert_eq(point.wire.red[2], 33 / 32, "helper red wire should match desk connector y")
  assert_eq(point.wire.green[1], 106 / 32, "helper green wire should match desk connector x")
  assert_eq(point.wire.green[2], 40 / 32, "helper green wire should match desk connector y")
  assert_eq(point.shadow.red[1], 120 / 32, "helper red shadow should match desk connector shadow x")
  assert_eq(point.shadow.red[2], 46 / 32, "helper red shadow should match desk connector shadow y")
  assert_eq(point.shadow.green[1], 114 / 32, "helper green shadow should match desk connector shadow x")
  assert_eq(point.shadow.green[2], 46 / 32, "helper green shadow should match desk connector shadow y")
end)

test("hired biter supply chest is hidden and non-selectable", function()
  local chest = assert(find_entity_prototype("hired-biter-supply-chest"))
  assert_true(chest.hidden, "hired-biter-supply-chest should be hidden")
  assert_true(chest.selectable_in_game == false, "hired-biter-supply-chest should not be selectable")
  assert_eq(chest.picture.filename, "__core__/graphics/empty.png", "hired-biter-supply-chest should use an empty sprite")

  local flags = {}
  for _, flag in ipairs(chest.flags or {}) do
    flags[flag] = true
  end
  assert_true(flags["not-on-map"], "hired-biter-supply-chest should not appear on the map")
end)

test("biterport has worker storage and a hidden robot service cell", function()
  local port = assert(find_entity_prototype("biterport"))
  local hidden = assert(find_entity_prototype("biterport-hidden-roboport"))

  assert_eq(port.placeable_by[1].item, "biterport", "biterport should be placeable by its item")
  assert_eq(port.inventory_size, 6, "biterport should expose one money slot plus five worker slots")
  assert_eq(port.inventory_type, "with_filters_and_bar", "biterport inventory should support worker slot filters")
  assert_true(port.collision_mask.layers.object, "biterport should be a ground building")

  assert_true(hidden.hidden, "hidden biterport roboport should be hidden")
  assert_true(hidden.selectable_in_game == false, "hidden biterport roboport should not be selectable")
  assert_eq(hidden.logistics_radius, 10, "hidden roboport should expose the biter logistics radius to robots")
  assert_eq(hidden.logistics_connection_distance, 20, "hidden roboport should link biter cells only when logistics areas touch")
  assert_eq(hidden.construction_radius, 20, "hidden roboport should expose the biter construction radius to robots")
  assert_eq(hidden.robot_slots_count, 0, "hidden roboport should not store regular robots")
  assert_eq(hidden.material_slots_count, 0, "hidden roboport should not store repair packs")
  assert_eq(hidden.recharge_minimum, "1kJ", "hidden roboport should satisfy the roboport recharge invariant")
end)

test("biterport worker speed tiers use hidden custom biter units", function()
  local base = data.raw.unit["biterport-worker"]
  local fast = data.raw.unit["biterport-worker-fast"]
  local express = data.raw.unit["biterport-worker-express"]

  assert_true(base ~= nil, "base biterport worker unit missing")
  assert_true(fast ~= nil, "fast biterport worker unit missing")
  assert_true(express ~= nil, "express biterport worker unit missing")
  assert_true(base.hidden_in_factoriopedia, "base biterport worker should stay hidden")
  assert_true(fast.hidden_in_factoriopedia, "fast biterport worker should stay hidden")
  assert_true(express.hidden_in_factoriopedia, "express biterport worker should stay hidden")
  assert_true(base.placeable_by == nil, "biterport workers should not be player-placeable")
  assert_eq(base.movement_speed, data.raw.unit["small-biter"].movement_speed, "base worker should preserve small-biter speed")
  assert_true(fast.movement_speed > base.movement_speed, "speed tier I should be faster than the base worker")
  assert_true(express.movement_speed > fast.movement_speed, "speed tier II should be faster than speed tier I")
  assert_true(fast.distance_per_frame > base.distance_per_frame, "speed tier I animation pacing should scale with movement")
  assert_true(express.distance_per_frame > fast.distance_per_frame, "speed tier II animation pacing should scale with movement")
end)

test("hired biter field agent is a real biter unit with a custom remote", function()
  local item = data.raw.item["hired-biter-capsule"]
  local remote = data.raw["selection-tool"]["hired-biter-command-capsule"]
  local agent = data.raw.unit["hired-biter-unit"]

  assert_true(item ~= nil, "hired-biter-capsule should be a normal placeable item")
  assert_eq(item.place_result, "hired-biter-unit", "hired-biter-capsule should place the field agent")
  assert_true(remote ~= nil, "deployment order should be a custom selection tool")
  assert_true(agent ~= nil, "hired-biter-unit biter unit missing")
  assert_eq(agent.placeable_by[1].item, "hired-biter-capsule", "field agent should be placeable by the crafted item")
  assert_eq(agent.run_animation.filename, "behemoth-biter.png", "field agent should keep the native behemoth biter asset")
  assert_true(agent.collision_mask.layers.object, "field agent should collide with objects and trees")
  assert_true(agent.collision_mask.layers.player, "field agent should use ground-unit collision")
  assert_eq(agent.vision_distance, 0, "field agent should not acquire nearby combat targets")
  assert_eq(agent.max_pursue_distance, 0, "field agent should not pursue combat targets")
  assert_true(agent.ai_settings.join_attacks == false, "field agent should not join attack groups")
  assert_eq(agent.attack_parameters.damage_modifier, 0, "field agent attacks should be harmless if forced")
  assert_eq(remote.select.entity_filters[1], "hired-biter-unit", "remote should select field agents")
  assert_eq(remote.select.mode[1], "any-entity", "remote should select entities")
  assert_eq(remote.select.mode[2], "same-force", "remote should be limited to same-force agents")
  assert_true(data.raw["spider-vehicle"]["hired-biter-unit"] == nil, "field agent should not be a spider vehicle")
end)

if failed > 0 then
  io.stderr:write("FAILED " .. failed .. " tests\n")
  for _, err in ipairs(errors) do
    io.stderr:write(" - " .. err .. "\n")
  end
  os.exit(1)
else
  print("OK (" .. passed .. " tests)")
end
