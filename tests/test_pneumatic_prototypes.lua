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
        pictures = {},
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

test("tube-intake is a container with 1 slot", function()
  local intake = data.raw.container["tube-intake"]
  assert_true(intake ~= nil, "tube-intake missing")
  assert_eq(intake.type, "container", "tube-intake should be a container")
  assert_eq(intake.inventory_size, 1, "tube-intake should have 1 inventory slot")
end)

test("tube-outtake is a container with 1 slot", function()
  local outtake = data.raw.container["tube-outtake"]
  assert_true(outtake ~= nil, "tube-outtake missing")
  assert_eq(outtake.type, "container", "tube-outtake should be a container")
  assert_eq(outtake.inventory_size, 1, "tube-outtake should have 1 inventory slot")
end)

test("hidden outtake inserter drops at belt center for even lane distribution", function()
  local outtake = data.raw.inserter["pneumatic-hidden-outtake"]
  assert_true(outtake ~= nil, "pneumatic-hidden-outtake missing")
  assert_eq(outtake.insert_position[1], 0, "outtake insert x should be centered for dual-lane distribution")
  assert_eq(outtake.insert_position[2], 1, "outtake should still target the adjacent tile")
end)

test("hidden intake inserter has no filters (validation is script-side)", function()
  local intake = data.raw.inserter["pneumatic-hidden-intake"]
  assert_true(intake ~= nil, "pneumatic-hidden-intake missing")
  assert_true(not intake.filter_count or intake.filter_count == 0,
    "intake inserter should not have prototype-level filters (Factorio caps at 5)")
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

test("tube-intake and tube-outtake share fast-replaceable group", function()
  local intake = data.raw.container["tube-intake"]
  local outtake = data.raw.container["tube-outtake"]
  assert_eq(intake.fast_replaceable_group, "pneumatic-io", "intake should use pneumatic-io group")
  assert_eq(outtake.fast_replaceable_group, "pneumatic-io", "outtake should use pneumatic-io group")
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
