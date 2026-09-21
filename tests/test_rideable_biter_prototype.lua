-------------------------------------------------------------------------------
-- ADMINISTRATORIO RIDEABLE BITER PROTOTYPE TESTS
-------------------------------------------------------------------------------

local passed, failed, errors = 0, 0, {}

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then passed = passed + 1 else failed = failed + 1; errors[#errors + 1] = name .. ": " .. tostring(err) end
end

local function assert_true(value, message)
  if not value then error(message or "assertion failed", 2) end
end

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)"):gsub("tests/$", "")
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

local function deepcopy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, child in pairs(value) do result[deepcopy(key)] = deepcopy(child) end
  return result
end

util = {
  table = {deepcopy = deepcopy},
  sprite_load = function(path, options)
    local sprite = deepcopy(options)
    sprite.filename = path
    return sprite
  end,
}
table.deepcopy = deepcopy

data = {
  raw = {
    car = {
      car = {
        type = "car",
        name = "car",
        flags = {"placeable-neutral", "player-creation"},
        energy_source = {type = "burner", fuel_categories = {"chemical"}},
      },
    },
    unit = {
      ["medium-biter"] = {
        run_animation = {filename = "fallback-medium-biter.png"},
      },
    },
  },
  extend = function(self, prototypes)
    for _, prototype in ipairs(prototypes) do
      self.raw[prototype.type] = self.raw[prototype.type] or {}
      self.raw[prototype.type][prototype.name] = prototype
    end
  end,
}

package.loaded["prototypes.entity.vehicles"] = nil
require("prototypes.entity.vehicles")

test("empty rideable biter uses the ordinary biter body and shadow", function()
  local empty = assert(data.raw.car["rideable-biter"])
  assert_eq(#empty.animation.layers, 4)
  assert_true(empty.animation.layers[1].filename:find("__base__/graphics/entity/biter/biter%-run") ~= nil)
  assert_true(empty.animation.layers[4].draw_as_shadow)
  for _, layer in ipairs(empty.animation.layers) do
    assert_true(not layer.filename:find("rideable%-biter/run%.png"),
      "unoccupied vehicle must not display the generated rider")
  end
end)

test("rideable biter ignores terrain friction and uses its selective collision layer", function()
  local empty = assert(data.raw.car["rideable-biter"])
  local mounted = assert(data.raw.car["rideable-biter-mounted"])
  for _, vehicle in ipairs({empty, mounted}) do
    assert_eq(vehicle.terrain_friction_modifier, 0)
    assert_true(vehicle.collision_mask.layers.administratorio_rideable_biter_collision)
    assert_true(vehicle.collision_mask.layers.administratorio_rideable_biter_terrain)
    assert_true(vehicle.collision_mask.layers.train)
    assert_true(vehicle.collision_mask.consider_tile_transitions)
  end
end)

test("mounted rideable biter combines generated rider art with the ordinary shadow", function()
  local mounted = assert(data.raw.car["rideable-biter-mounted"])
  assert_eq(#mounted.animation.layers, 2)
  assert_eq(mounted.animation.layers[1].filename,
    "__administratorio__/graphics/entities/rideable-biter/run.png")
  assert_true(mounted.animation.layers[2].filename:find("__base__/graphics/entity/biter/biter%-run%-shadow") ~= nil)
  assert_true(mounted.animation.layers[2].draw_as_shadow)
  assert_true(mounted.hidden_in_factoriopedia)
end)

print(("Rideable biter prototype tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do print(" - " .. err) end
  os.exit(1)
end
