local item_icons = "__administratorio__/graphics/icons/"

-- Capsules
data:extend({
  {
    type = "capsule", name = "promise",
    icon = item_icons .. "blank-form.png", icon_size = 64,
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
    icon = item_icons .. "regulation.png", icon_size = 64,
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
