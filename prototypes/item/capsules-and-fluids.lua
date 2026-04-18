local item_icons = "__administratorio__/graphics/icons/"

local smoke_animation = {
  width = 152,
  height = 120,
  line_length = 5,
  frame_count = 60,
  shift = {-0.53125, -0.4375},
  priority = "high",
  animation_speed = 0.25,
  filename = "__base__/graphics/entity/smoke/smoke.png",
  flags = { "smoke" }
}

-- Hush Money cloud (green smog visual)
data:extend({
  {
    name = "hush-money-cloud",
    type = "smoke-with-trigger",
    flags = {"not-on-map"},
    hidden = true,
    show_when_smoke_off = true,
    particle_count = 12,
    particle_spread = { 1.5, 1.5 * 0.6 },
    particle_distance_scale_factor = 0.5,
    particle_scale_factor = { 1, 0.707 },
    wave_speed = { 1/80, 1/60 },
    wave_distance = { 0.3, 0.2 },
    spread_duration_variation = 20,
    particle_duration_variation = 60 * 3,
    render_layer = "object",
    affected_by_wind = false,
    cyclic = true,
    duration = 60 * 60 * 3,
    fade_away_duration = 60 * 20,
    spread_duration = 20,
    color = {0.15, 0.85, 0.25, 0.6},
    animation = smoke_animation,
    created_effect = {
      {
        type = "cluster",
        cluster_count = 8,
        distance = 2,
        distance_deviation = 1.5,
        action_delivery = {
          type = "instant",
          target_effects = {
            { type = "create-smoke", show_in_tooltip = false, entity_name = "hush-money-visual", initial_height = 0 },
          }
        }
      },
      {
        type = "cluster",
        cluster_count = 6,
        distance = 4,
        distance_deviation = 1,
        action_delivery = {
          type = "instant",
          target_effects = {
            { type = "create-smoke", show_in_tooltip = false, entity_name = "hush-money-visual", initial_height = 0 },
          }
        }
      }
    },
  },
  {
    type = "smoke-with-trigger",
    name = "hush-money-visual",
    flags = {"not-on-map"},
    hidden = true,
    show_when_smoke_off = true,
    particle_count = 14,
    particle_spread = { 1.5, 1.5 * 0.6 },
    particle_distance_scale_factor = 0.5,
    particle_scale_factor = { 1, 0.707 },
    particle_duration_variation = 60 * 3,
    wave_speed = { 0.5 / 80, 0.5 / 60 },
    wave_distance = { 0.8, 0.5 },
    spread_duration_variation = 100,
    render_layer = "object",
    affected_by_wind = false,
    cyclic = true,
    duration = 60 * 60 * 3 + 4 * 60,
    fade_away_duration = 60 * 20,
    spread_duration = (300 - 20) / 2,
    color = {0.05, 0.45, 0.12, 0.35},
    animation = smoke_animation,
  },
})

-- Invisible collision blocker placed while a spawner is calmed by hush money
data:extend({
  {
    type = "simple-entity-with-owner",
    name = "hush-money-placeholder",
    flags = {"not-deconstructable", "not-blueprintable", "placeable-off-grid", "not-on-map"},
    hidden = true,
    collision_box = {{-2.2, -2.2}, {2.2, 2.2}},
    collision_mask = {layers = {item = true, object = true, player = true, water_tile = true}},
    max_health = 1,
    destructible = false,
    selectable_in_game = false,
    picture = { filename = "__core__/graphics/empty.png", width = 1, height = 1 },
  },
})

-- Capsules
data:extend({
  {
    type = "capsule", name = "hush-money",
    icon = item_icons .. "hush-money-capsule.png", icon_size = 64,
    subgroup = "capsule", order = "z0[hush-money]", stack_size = 10,
    capsule_action = {
      type = "throw",
      attack_parameters = {
        type = "projectile", ammo_category = "capsule", cooldown = 30, range = 25,
        ammo_type = {
          category = "capsule", target_type = "position",
          action = {
            type = "direct",
            action_delivery = {
              type = "instant",
              target_effects = {
                { type = "create-entity", entity_name = "hush-money-cloud" },
                { type = "script", effect_id = "hush-money-target" },
              }
            }
          }
        }
      }
    }
  },
  {
    type = "capsule", name = "promise",
    icon = item_icons .. "bureaucratic-promise.png", icon_size = 64,
    subgroup = "capsule", order = "z1[promise]", stack_size = 20,
    capsule_action = {
      type = "throw",
      attack_parameters = {
        type = "projectile", ammo_category = "capsule", cooldown = 15, range = 20,
        ammo_type = {
          category = "capsule", target_type = "position",
          action = {
            type = "area", radius = 5,
            action_delivery = {
              type = "instant",
              target_effects = { { type = "script", effect_id = "promise-target" } }
            }
          }
        }
      }
    }
  },
  {
    type = "capsule", name = "eviction-notice",
    icon = item_icons .. "eviction-notice.png", icon_size = 64,
    subgroup = "capsule", order = "z2[eviction-notice]", stack_size = 5,
    capsule_action = {
      type = "throw",
      attack_parameters = {
        type = "projectile", ammo_category = "capsule", cooldown = 15, range = 20,
        ammo_type = {
          category = "capsule", target_type = "position",
          action = {
            type = "area", radius = 2,
            action_delivery = {
              type = "instant",
              target_effects = { { type = "script", effect_id = "eviction-target" } }
            }
          }
        }
      }
    }
  }
})

-- Fluids
data:extend({
  { type = "fluid", name = "slush-fund",        icon = item_icons .. "slush-fund.png",                  icon_size = 64, subgroup = "admin-fluids", order = "a", default_temperature = 25, base_color = {r=0.2, g=0.4, b=0.2}, flow_color = {r=0.3, g=0.5, b=0.3} },
  { type = "fluid", name = "politician-fluid",  icon = item_icons .. "politician-fluid.png",            icon_size = 64, subgroup = "admin-fluids", order = "b", default_temperature = 25, base_color = {r=0.5, g=0, b=0},     flow_color = {r=0.7, g=0.1, b=0.1} },
  { type = "fluid", name = "lie",               icon = item_icons .. "lie.png",                         icon_size = 64, subgroup = "admin-fluids", order = "c", default_temperature = 25, base_color = {r=0.7, g=0.7, b=0},   flow_color = {r=1, g=1, b=0} },
  { type = "fluid", name = "misinformation",    icon = item_icons .. "misinformation.png",              icon_size = 64, subgroup = "admin-fluids", order = "d", default_temperature = 25, base_color = {r=0.5, g=0.5, b=0.5}, flow_color = {r=0.8, g=0.8, b=0.8} },
  { type = "fluid", name = "union-approval",    icon = item_icons .. "union-approval.png", icon_size = 64, subgroup = "admin-fluids", order = "e", default_temperature = 25, base_color = {r=0.2, g=0.4, b=1.0}, flow_color = {r=0.4, g=0.6, b=1.0} },
  { type = "fluid", name = "liquid-coffee",     icon = item_icons .. "coffee.png",                  icon_size = 64, subgroup = "admin-fluids", order = "f", default_temperature = 80, base_color = {r=0.3, g=0.2, b=0.1}, flow_color = {r=0.4, g=0.2, b=0.1} },
})
