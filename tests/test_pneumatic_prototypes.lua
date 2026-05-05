-------------------------------------------------------------------------------
-- ADMINISTRATORIO PNEUMATIC PROTOTYPE TESTS
--
-- Standalone Lua tests that verify the pneumatic tube entity structure.
-- Run: lua tests/test_pneumatic_prototypes.lua
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- 0. MINI TEST FRAMEWORK
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

local function has_flag(prototype, flag)
  for _, value in ipairs(prototype.flags or {}) do
    if value == flag then return true end
  end
  return false
end

-------------------------------------------------------------------------------
-- 1. MOCK FACTORIO DATA STAGE
-------------------------------------------------------------------------------
data = {
  raw = {
    ["pipe"] = {
      pipe = {
        type = "pipe",
        name = "pipe",
        minable = {result = "pipe"},
        pictures = {
          straight_vertical_single = {
            filename = "__base__/graphics/entity/pipe/pipe-straight-vertical-single.png",
            width = 80,
            height = 80,
          },
        },
        fluid_box = {
          pipe_connections = {
            {direction = 0, connection_type = "normal"},
            {direction = 4, connection_type = "normal"},
          },
        },
      },
    },
    ["pipe-to-ground"] = {
      ["pipe-to-ground"] = {
        type = "pipe-to-ground",
        name = "pipe-to-ground",
        minable = {result = "pipe-to-ground"},
        pictures = {},
        fluid_box = {
          pipe_connections = {
            {direction = 0, connection_type = "normal"},
            {direction = 4, connection_type = "underground"},
          },
        },
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
}

function util.by_pixel(x, y)
  return {x / 32, y / 32}
end

if not table.deepcopy then
  table.deepcopy = util.table.deepcopy
end

circuit_connector_definitions = {
  create_single = function(_, definition) return definition end,
  create_vector = function(_, definitions) return definitions end,
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

-------------------------------------------------------------------------------
-- 2. LOAD MOD FILES
-------------------------------------------------------------------------------
local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

dofile(mod_root .. "prototypes/entity/pneumatic.lua")

-------------------------------------------------------------------------------
-- 3. TESTS
-------------------------------------------------------------------------------

test("tube-intake is a furnace-style intake with 1 source slot", function()
  local intake = data.raw.furnace["tube-intake"]
  assert_true(intake ~= nil, "tube-intake missing")
  assert_eq(intake.type, "furnace", "tube-intake should use furnace-style ingredient validation")
  assert_eq(intake.source_inventory_size, 1, "tube-intake should have 1 source slot")
  assert_eq(intake.crafting_categories[1], "pneumatic-intake", "tube-intake should use pneumatic intake recipes")
  assert_eq(intake.trash_inventory_size, 0, "tube-intake should not show a logistics trash pane")
  assert_eq(intake.enable_logistic_control_behavior, false, "tube-intake should not show logistic control behavior")
  assert_eq(intake.circuit_wire_max_distance, nil, "tube-intake should not own the native circuit/logistic GUI")
  assert_eq(intake.circuit_connector, nil, "tube-intake should not own the native circuit/logistic GUI")
end)

test("tube-intake has a wireable tube-content circuit port", function()
  local port = data.raw["constant-combinator"]["tube-intake-network-port"]
  assert_true(port ~= nil, "tube-intake-network-port missing")
  assert_true(port.selectable_in_game, "tube-intake network port should be wireable")
  assert_eq(port.circuit_wire_max_distance, 9, "tube-intake network port should support circuit wires")
  assert_true(port.circuit_wire_connection_points ~= nil, "tube-intake network port should define wire points")
end)

test("tube-intake has static graphics", function()
  local intake = data.raw.furnace["tube-intake"]
  assert_true(intake.graphics_set.animation.layers ~= nil, "tube-intake should use one static sprite")
end)

test("tube endpoints and hidden combinators are not rotatable", function()
  assert_true(has_flag(data.raw.furnace["tube-intake"], "not-rotatable"),
    "tube-intake should not rotate")
  assert_true(has_flag(data.raw.container["tube-outtake"], "not-rotatable"),
    "tube-outtake should not rotate")
  assert_true(has_flag(data.raw["constant-combinator"]["tube-network-combinator"], "not-rotatable"),
    "tube-network-combinator should not rotate")
  assert_true(has_flag(data.raw["constant-combinator"]["tube-intake-network-port"], "not-rotatable"),
    "tube-intake-network-port should not rotate")
end)

test("tube-outtake is a container with 1 slot", function()
  local outtake = data.raw.container["tube-outtake"]
  assert_true(outtake ~= nil, "tube-outtake missing")
  assert_eq(outtake.type, "container", "tube-outtake should be a container")
  assert_eq(outtake.inventory_size, 1, "tube-outtake should have 1 inventory slot")
  assert_eq(outtake.inventory_type, "with_bar", "tube-outtake should not use filtered logistics-style inventory")
end)

test("tube-outtake uses a container-compatible picture sprite", function()
  local outtake = data.raw.container["tube-outtake"]
  assert_true(outtake.picture ~= nil, "tube-outtake should define a picture")
  assert_true(outtake.picture.layers ~= nil, "tube-outtake picture should use sprite layers")
  assert_true(outtake.picture.layers[2].filename ~= nil, "tube-outtake picture layer should have a filename")
  assert_eq(outtake.picture.layers[2].filename, "__administratorio__/graphics/entities/pneumatic/outtake.png",
    "tube-outtake should use the new outtake asset")
end)

test("pneumatic-hidden-network-pipe connects to pneumatic-forms category", function()
  local pipe = data.raw.pipe["pneumatic-hidden-network-pipe"]
  assert_true(pipe ~= nil, "pneumatic-hidden-network-pipe missing")
  assert_true(pipe.hidden, "network pipe should be hidden")
  local found_pneumatic = false
  for _, pcon in pairs(pipe.fluid_box.pipe_connections) do
    if pcon.connection_category == "pneumatic-forms" then
      found_pneumatic = true
      break
    end
  end
  assert_true(found_pneumatic, "network pipe should use pneumatic-forms connection category")
end)

test("pneumatic-hidden-network-pipe has no collision layers", function()
  local pipe = data.raw.pipe["pneumatic-hidden-network-pipe"]
  assert_true(pipe ~= nil, "pneumatic-hidden-network-pipe missing")
  assert_true(pipe.collision_mask ~= nil, "network pipe should have collision_mask")
  assert_true(pipe.collision_mask.layers ~= nil, "collision_mask should have layers")
  assert_eq(next(pipe.collision_mask.layers), nil, "network pipe collision layers should be empty")
  -- Box must be non-zero so pipe connection positions fit inside it.
  assert_true(pipe.collision_box[1][1] < 0, "collision_box should have nonzero extent")
end)

test("pneumatic-hidden-network-pipe renders tinted pipe connections above tube endpoints", function()
  local pipe = data.raw.pipe["pneumatic-hidden-network-pipe"]
  assert_true(pipe.pictures ~= nil, "network pipe should keep pictures for visible endpoint connections")
  local picture = pipe.pictures.straight_vertical_single
  assert_true(picture ~= nil, "network pipe should inherit vanilla pipe pictures")
  assert_true(picture.tint ~= nil, "network pipe endpoint connection should be tinted")
  assert_eq(picture.render_layer, "higher-object-above",
    "network pipe endpoint connection should render above intake/outtake sprites")
end)

test("tube-intake and tube-outtake share fast-replaceable group", function()
  local intake = data.raw.furnace["tube-intake"]
  local outtake = data.raw.container["tube-outtake"]
  assert_eq(intake.fast_replaceable_group, "pneumatic-io", "intake should use pneumatic-io group")
  assert_eq(outtake.fast_replaceable_group, "pneumatic-io", "outtake should use pneumatic-io group")
end)

test("pneumatic pipes support the extended network radius", function()
  assert_eq(data.raw.pipe["pneumatic-pipe"].fluid_box.max_pipeline_extent, 120,
    "visible pneumatic pipe should support 120-tile networks")
  assert_eq(data.raw["pipe-to-ground"]["pneumatic-pipe-to-ground"].fluid_box.max_pipeline_extent, 120,
    "underground pneumatic pipe should support 120-tile networks")
  assert_eq(data.raw.pipe["pneumatic-hidden-network-pipe"].fluid_box.max_pipeline_extent, 120,
    "hidden network pipe should support 120-tile networks")
end)

-------------------------------------------------------------------------------
-- 4. REPORT
-------------------------------------------------------------------------------
if failed > 0 then
  io.stderr:write("FAILED " .. failed .. " tests\n")
  for _, err in ipairs(errors) do
    io.stderr:write(" - " .. err .. "\n")
  end
  os.exit(1)
else
  print("OK (" .. passed .. " tests)")
end
