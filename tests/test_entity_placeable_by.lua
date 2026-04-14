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
  for _, name in ipairs({"admin-station", "admin-station-north", "admin-station-east", "admin-station-west"}) do
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
    data.raw["furnace"]["form-liquifier"],
    data.raw["furnace"]["form-solidifier"],
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
  assert_true(data.raw.item["admin-station-north"].place_result == nil, "admin-station-north should not remain placeable")
  assert_true(data.raw.item["admin-station-east"].place_result == nil, "admin-station-east should not remain placeable")
  assert_true(data.raw.item["admin-station-west"].place_result == nil, "admin-station-west should not remain placeable")
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

if failed > 0 then
  io.stderr:write("FAILED " .. failed .. " tests\n")
  for _, err in ipairs(errors) do
    io.stderr:write(" - " .. err .. "\n")
  end
  os.exit(1)
else
  print("OK (" .. passed .. " tests)")
end
