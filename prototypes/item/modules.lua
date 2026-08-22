local feature_flags = require("feature_flags")

local modules = {
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
}

if feature_flags.space_age_enabled() then
  table.insert(modules, 1, {
    -- The waiver occupies a productivity slot. That implicit trade is a real
    -- cost the player feels, at no design expense.
    type = "module",
    name = "unstaffed-operations-waiver",
    icon = "__administratorio__/graphics/icons/unstaffed-operations-waiver.png",
    icon_size = 64,
    subgroup = "module",
    order = "z[unstaffed-operations-waiver]",
    stack_size = 50,
    category = "unstaffed-operations",
    tier = 1,
    -- Deliberately does not spoil. Spoilage works in a module slot, but
    -- nothing can feed or remove a module automatically, so an expiring waiver
    -- would be a manual chore rather than a logistics problem. The cost carries
    -- the weight instead.
    effect = {},
  })
end

data:extend(modules)
