local function deepcopy(value)
  if table.deepcopy then return table.deepcopy(value) end
  if util and util.table and util.table.deepcopy then return util.table.deepcopy(value) end
  if type(value) ~= "table" then return value end

  local copy = {}
  for k, v in pairs(value) do
    copy[deepcopy(k)] = deepcopy(v)
  end
  return copy
end

local function sound_variations(path_prefix, count, min_volume, max_volume)
  local variations = {}
  local high = max_volume or min_volume
  for i = 1, count do
    local volume = min_volume
    if count > 1 and high ~= min_volume then
      volume = min_volume + (high - min_volume) * ((i - 1) / (count - 1))
    end
    variations[i] = {
      filename = path_prefix .. "-" .. i .. ".ogg",
      volume = volume,
    }
  end
  return variations
end

local function biter_sound(path_prefix, count, min_volume, max_volume, max_count)
  return {
    category = "enemy",
    variations = sound_variations(path_prefix, count, min_volume, max_volume),
    aggregation = {max_count = max_count or 3, remove = true, count_already_playing = true},
  }
end

local function rideable_biter_run_animation()
  if not (util and util.sprite_load) then return nil end

  local scale = 0.7
  local animation_speed = 3.0
  local tint1 = {0.49, 0.46, 0.51, 1}
  local tint2 = {0.6, 0.36, 0.36, 0.7}

  return {
    layers = {
      util.sprite_load("__administratorio__/graphics/entities/rideable-biter/biter-run", {
        slice = 8,
        frame_count = 16,
        direction_count = 16,
        scale = scale * 0.5,
        multiply_shift = scale,
        animation_speed = animation_speed,
        allow_forced_downscale = true,
        surface = "nauvis",
        usage = "enemy",
      }),
      util.sprite_load("__administratorio__/graphics/entities/rideable-biter/biter-run-mask1", {
        slice = 8,
        frame_count = 16,
        direction_count = 16,
        flags = {"mask"},
        tint = tint1,
        scale = scale * 0.5,
        multiply_shift = scale,
        animation_speed = animation_speed,
        allow_forced_downscale = true,
        surface = "nauvis",
        usage = "enemy",
      }),
      util.sprite_load("__administratorio__/graphics/entities/rideable-biter/biter-run-mask2", {
        slice = 8,
        frame_count = 16,
        direction_count = 16,
        flags = {"mask"},
        tint = tint2,
        tint_as_overlay = true,
        scale = scale * 0.5,
        multiply_shift = scale,
        animation_speed = animation_speed,
        allow_forced_downscale = true,
        surface = "nauvis",
        usage = "enemy",
      }),
      util.sprite_load("__administratorio__/graphics/entities/rideable-biter/biter-run-shadow", {
        slice = 8,
        frame_count = 16,
        direction_count = 16,
        draw_as_shadow = true,
        scale = scale * 0.5,
        multiply_shift = scale,
        animation_speed = animation_speed,
        allow_forced_downscale = true,
        surface = "nauvis",
        usage = "enemy",
      }),
    },
  }
end

local function make_rideable_biter()
  local base_car = data.raw["car"] and data.raw["car"]["car"]
  local biter = data.raw["unit"] and (data.raw["unit"]["medium-biter"] or data.raw["unit"]["small-biter"])
  if not base_car or not biter then return nil end

  local vehicle = deepcopy(base_car)
  vehicle.name = "rideable-biter"
  vehicle.localised_name = {"entity-name.rideable-biter"}
  vehicle.localised_description = {"entity-description.rideable-biter"}
  vehicle.icon = "__base__/graphics/icons/medium-biter.png"
  vehicle.icon_size = 64
  vehicle.icons = {
    {icon = "__base__/graphics/icons/medium-biter.png", icon_size = 64},
    {icon = "__administratorio__/graphics/icons/taxpayer-money.png", icon_size = 64, scale = 0.35, shift = {8, 8}},
  }
  vehicle.minable = nil
  vehicle.placeable_by = {{item = "rideable-biter", count = 1}}
  vehicle.flags = deepcopy(vehicle.flags or {"placeable-neutral", "player-creation"})
  vehicle.flags[#vehicle.flags + 1] = "not-deconstructable"
  vehicle.collision_box = {{-0.35, -0.45}, {0.35, 0.45}}
  vehicle.selection_box = {{-0.65, -0.85}, {0.65, 0.85}}
  vehicle.inventory_size = 4
  vehicle.max_health = 240
  vehicle.weight = 250
  vehicle.consumption = "110kW"
  vehicle.braking_power = "900kW"
  vehicle.friction = 0.024
  vehicle.terrain_friction_modifier = 0.9
  vehicle.rotation_speed = 0.018
  vehicle.rotation_snap_angle = 0.01
  vehicle.energy_per_hit_point = 1000000000
  vehicle.immune_to_tree_impacts = true
  vehicle.immune_to_rock_impacts = true
  vehicle.effectivity = 1
  vehicle.tank_driving = true
  vehicle.guns = nil
  vehicle.light_animation = nil
  vehicle.turret_animation = nil
  vehicle.turret_rotation_speed = nil
  vehicle.turret_return_timeout = nil
  vehicle.track_particle_triggers = nil
  vehicle.dying_sound = biter_sound("__base__/sound/creatures/biter-death", 5, 0.45, 0.6)
  vehicle.sound_no_fuel = biter_sound("__base__/sound/creatures/biter-roar-mid", 7, 0.35, 0.5, 1)
  vehicle.open_sound = biter_sound("__base__/sound/creatures/biter-call", 5, 0.18, 0.3, 2)
  vehicle.close_sound = biter_sound("__base__/sound/creatures/biter-call", 5, 0.14, 0.24, 2)
  vehicle.vehicle_impact_sound = nil
  vehicle.stop_trigger = {{
    type = "play-sound",
    sound = biter_sound("__base__/sound/creatures/biter-call", 5, 0.12, 0.22, 1),
  }}
  vehicle.stop_trigger_speed = nil
  vehicle.working_sound = {
    activate_sound = biter_sound("__base__/sound/creatures/biter-roar-mid", 7, 0.2, 0.35, 1),
    deactivate_sound = biter_sound("__base__/sound/creatures/biter-call", 5, 0.12, 0.22, 1),
  }

  if vehicle.energy_source then
    vehicle.energy_source.fuel_categories = {"administratorio-taxpayer-money"}
    vehicle.energy_source.fuel_category = nil
    vehicle.energy_source.fuel_inventory_size = 1
    vehicle.energy_source.smoke = nil
  end

  vehicle.animation = rideable_biter_run_animation()
  if not vehicle.animation and biter.run_animation then
    vehicle.animation = deepcopy(biter.run_animation)
  end

  return vehicle
end

local rideable_biter = make_rideable_biter()
if rideable_biter then
  data:extend({rideable_biter})
end
