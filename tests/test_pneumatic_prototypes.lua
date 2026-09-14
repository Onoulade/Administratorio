-------------------------------------------------------------------------------
-- PNEUMATIC PROTOTYPE TESTS
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

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "assertion failed") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)"):gsub("tests/$", "")
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

local function deepcopy(value)
  if type(value) ~= "table" then return value end
  local copy = {}
  for key, entry in pairs(value) do
    copy[deepcopy(key)] = deepcopy(entry)
  end
  return copy
end

util = {
  table = {deepcopy = deepcopy},
  by_pixel = function(x, y) return {x, y} end,
}
table.deepcopy = deepcopy
defines = {direction = {north = 0}}

universal_connector_template = {}
circuit_connector_definitions = {
  create_single = function(_, _)
    return {sprites = {}}
  end,
  create_vector = function(_, definitions)
    local connectors = {}
    for index in ipairs(definitions) do
      connectors[index] = {sprites = {}}
    end
    return connectors
  end,
}

local function base_pipe()
  return {
    type = "pipe",
    name = "pipe",
    minable = {result = "pipe"},
    fluid_box = {
      pipe_connections = {
        {}, {}, {}, {},
      },
    },
    pictures = {},
    pipe_covers = {},
  }
end

local function base_underground_pipe()
  return {
    type = "pipe-to-ground",
    name = "pipe-to-ground",
    minable = {result = "pipe-to-ground"},
    fluid_box = {
      pipe_connections = {
        {}, {connection_type = "underground"},
      },
    },
    pictures = {},
  }
end

data = {
  raw = {
    pipe = {pipe = base_pipe()},
    ["pipe-to-ground"] = { ["pipe-to-ground"] = base_underground_pipe() },
  },
}

function data:extend(prototypes)
  for _, prototype in ipairs(prototypes) do
    self.raw[prototype.type] = self.raw[prototype.type] or {}
    self.raw[prototype.type][prototype.name] = prototype
  end
end

require("prototypes.entity.pneumatic")

test("pneumatic pipes share a fast-replace group", function()
  local pipe = data.raw.pipe["pneumatic-pipe"]
  local underground = data.raw["pipe-to-ground"]["pneumatic-pipe-to-ground"]
  assert_eq(pipe.fast_replaceable_group, "pneumatic-pipe")
  assert_eq(underground.fast_replaceable_group, pipe.fast_replaceable_group,
    "regular and underground pneumatic pipes must be fast-replaceable")
end)

test("tube pump exposes multiple filters and vanilla pump artwork", function()
  local pump = data.raw.inserter["tube-pump"]
  assert_eq(pump.filter_count, 5)
  assert_eq(pump.rotatable, true)
  assert_eq(pump.collision_box[1][2], -0.9)
  local artwork = {
    north = {"south", 114, 160, 12.5, -8},
    east = {"west", 131, 111, -0.25, 1.25},
    south = {"north", 103, 164, 8, -0.85},
    west = {"east", 130, 109, -0.5, 1.75},
  }
  for direction, expected in pairs(artwork) do
    local picture = pump.platform_picture[direction]
    assert_eq(picture.filename, "__base__/graphics/entity/pump/pump-" .. expected[1] .. ".png")
    assert_eq(picture.width, expected[2])
    assert_eq(picture.height, expected[3])
    assert_eq(picture.shift[1], expected[4])
    assert_eq(picture.shift[2], expected[5])
    assert_eq(picture.tint.r, 0.85)
    assert_eq(picture.tint.g, 0.75)
  end
end)

print(("Pneumatic prototype tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do print(" - " .. err) end
  os.exit(1)
end
