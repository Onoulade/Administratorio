data:extend({
  -- The waiver occupies a productivity slot. That implicit trade is a real cost
  -- the player feels, at no design expense.
  {
    type = "module",
    name = "unstaffed-operations-waiver",
    icon = "__administratorio__/graphics/icons/overtime-module.png",
    icon_size = 64,
    subgroup = "module",
    order = "z[unstaffed-operations-waiver]",
    stack_size = 50,
    category = "unstaffed-operations",
    tier = 1,
    effect = {},
    spoil_ticks = 60 * 60 * 60,
    spoil_result = "expired-waiver",
  },
  {
    type = "item",
    name = "expired-waiver",
    icons = {{icon = "__administratorio__/graphics/icons/overtime-module.png", icon_size = 64, tint = {r = 0.5, g = 0.5, b = 0.5, a = 1}}},
    subgroup = "module",
    order = "z[unstaffed-operations-waiver]-b",
    stack_size = 50,
  },
  {
    type = "module",
    name = "overtime-exemption",
    icon = "__administratorio__/graphics/icons/overtime-module.png",
    icon_size = 64,
    subgroup = "module",
    order = "z[overtime-exemption]",
    stack_size = 50,
    category = "night-work",
    tier = 1,
    effect = {},
  },
})
