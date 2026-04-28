-------------------------------------------------------------------------------
-- ADMINISTRATORIO RIDEABLE BITER VEHICLE TESTS
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

local function deepcopy(tbl)
  if type(tbl) ~= "table" then return tbl end
  local copy = {}
  for k, v in pairs(tbl) do
    copy[deepcopy(k)] = deepcopy(v)
  end
  return copy
end

data = {
  raw = {
    car = {
      car = {
        type = "car",
        name = "car",
        icon = "__base__/graphics/icons/car.png",
        icon_size = 64,
        minable = {result = "car"},
        inventory_size = 80,
        consumption = "150kW",
        energy_source = {
          type = "burner",
          fuel_categories = {"chemical"},
          fuel_inventory_size = 1,
          smoke = {{name = "car-smoke"}},
        },
        braking_power = "200kW",
        friction = 0.002,
        terrain_friction_modifier = 0.2,
        rotation_speed = 0.015,
        rotation_snap_angle = 0.015,
        weight = 700,
        energy_per_hit_point = 1,
        collision_box = {{-0.7, -1}, {0.7, 1}},
        selection_box = {{-0.7, -1}, {0.7, 1}},
        animation = {filename = "car.png"},
        light_animation = {frame_count = 2},
        turret_animation = {filename = "car-turret.png"},
        turret_rotation_speed = 0.005,
        guns = {"vehicle-machine-gun"},
        track_particle_triggers = {{type = "create-particle"}},
        working_sound = {main_sounds = {{sound = {filename = "__base__/sound/car-engine-driving.ogg"}}}},
        open_sound = {filename = "__base__/sound/car-door-open.ogg"},
        close_sound = {filename = "__base__/sound/car-door-close.ogg"},
        sound_no_fuel = {filename = "__base__/sound/fight/car-no-fuel-1.ogg"},
        stop_trigger = {{type = "play-sound", sound = {filename = "__base__/sound/car-breaks.ogg"}}},
      },
    },
    unit = {
      ["medium-biter"] = {
        name = "medium-biter",
        run_animation = {filename = "medium-biter.png"},
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
  table = {deepcopy = deepcopy},
  sprite_load = function(path, options)
    local sprite = deepcopy(options or {})
    sprite.filename = path
    return sprite
  end,
}
table.deepcopy = table.deepcopy or deepcopy

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end

dofile(mod_root .. "prototypes/entity/vehicles.lua")

test("rideable biter is a taxpayer-money fueled car with tiny storage", function()
  local vehicle = data.raw.car["rideable-biter"]
  assert_true(vehicle ~= nil, "rideable-biter car prototype missing")
  assert_true(vehicle.minable == nil, "rideable biter should not be minable after placement")
  assert_eq(vehicle.placeable_by[1].item, "rideable-biter")
  local not_deconstructable = false
  for _, flag in ipairs(vehicle.flags or {}) do
    if flag == "not-deconstructable" then
      not_deconstructable = true
      break
    end
  end
  assert_true(not_deconstructable, "rideable biter should not be removable by deconstruction")
  assert_eq(vehicle.inventory_size, 4, "rideable biter should have tiny cargo storage")
  assert_eq(vehicle.consumption, "110kW", "rideable biter should give a stack of taxpayer money about 15 minutes of autonomy")
  assert_eq(vehicle.effectivity, 1, "rideable biter should use straightforward taxpayer-money fuel scaling")
  assert_eq(vehicle.weight, 250, "rideable biter should feel lighter than the vanilla car")
  assert_eq(vehicle.braking_power, "900kW", "rideable biter should shed speed quickly")
  assert_eq(vehicle.friction, 0.024, "rideable biter should have less coasting inertia")
  assert_eq(vehicle.terrain_friction_modifier, 0.9, "rideable biter should not drift like a car")
  assert_eq(vehicle.rotation_speed, 0.018, "rideable biter should turn faster than a vanilla car without oversteering")
  assert_eq(vehicle.rotation_snap_angle, 0.01, "rideable biter should have fine steering steps")
  assert_true(vehicle.tank_driving, "rideable biter should be able to rotate in place")
  assert_eq(vehicle.energy_per_hit_point, 1000000000, "rideable biter should effectively disable collision damage")
  assert_true(vehicle.immune_to_tree_impacts, "rideable biter should ignore tree impact damage")
  assert_true(vehicle.immune_to_rock_impacts, "rideable biter should ignore rock impact damage")
  assert_eq(vehicle.collision_box[1][1], -0.35, "rideable biter should have a smaller collision box")
  assert_eq(vehicle.collision_box[2][2], 0.45, "rideable biter should have a smaller collision box")
  assert_eq(vehicle.energy_source.fuel_categories[1], "administratorio-taxpayer-money")
  assert_true(vehicle.energy_source.fuel_categories[2] == nil, "rideable biter should accept only the taxpayer-money fuel category")
  assert_true(vehicle.energy_source.fuel_category == nil, "rideable biter should not accept generic chemical fuel")
  assert_true(vehicle.energy_source.smoke == nil, "rideable biter should not emit car exhaust smoke")
  assert_eq(vehicle.icons[1].icon, "__base__/graphics/icons/medium-biter.png", "rideable vehicle icon should match the medium biter it uses/reverts to")
  assert_true(vehicle.icons[1].tint ~= nil, "rideable vehicle medium biter icon should use the role tint")
  assert_eq(vehicle.icons[2].icon, "__administratorio__/graphics/icons/transit-authorization.png", "rideable vehicle icon overlay should match the assignment paperwork")
  assert_true(vehicle.animation.layers ~= nil, "rideable biter should use layered biter animation assets")
  assert_eq(vehicle.animation.layers[1].filename, "__base__/graphics/entity/biter/biter-run")
  for _, layer in ipairs(vehicle.animation.layers) do
    assert_eq(layer.animation_speed, 3.0, "rideable biter visual run animation should be faster without changing vehicle movement")
  end
  assert_true(vehicle.guns == nil, "rideable biter should not inherit vanilla car weapons")
  assert_true(vehicle.light_animation == nil, "rideable biter should not inherit car headlight animation")
  assert_true(vehicle.turret_animation == nil, "rideable biter should not render the vanilla car turret overlay")
  assert_true(vehicle.turret_rotation_speed == nil, "rideable biter should not keep turret rotation behavior")
  assert_true(vehicle.track_particle_triggers == nil, "rideable biter should not kick up vanilla car movement particles")
  assert_true(vehicle.working_sound.main_sounds == nil, "rideable biter should not loop short biter walk samples while moving")
  assert_eq(vehicle.working_sound.activate_sound.variations[1].filename, "__base__/sound/creatures/biter-roar-mid-1.ogg")
  assert_eq(vehicle.working_sound.deactivate_sound.variations[1].filename, "__base__/sound/creatures/biter-call-1.ogg")
  assert_eq(vehicle.open_sound.variations[1].filename, "__base__/sound/creatures/biter-call-1.ogg")
  assert_eq(vehicle.close_sound.variations[1].filename, "__base__/sound/creatures/biter-call-1.ogg")
  assert_eq(vehicle.sound_no_fuel.variations[1].filename, "__base__/sound/creatures/biter-roar-mid-1.ogg")
  assert_eq(vehicle.dying_sound.variations[1].filename, "__base__/sound/creatures/biter-death-1.ogg")
  assert_eq(vehicle.stop_trigger[1].sound.variations[1].filename, "__base__/sound/creatures/biter-call-1.ogg")
end)

print(("Rideable biter vehicle tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
