local item_icons = "__administratorio__/graphics/icons/"
local feature_flags = require("feature_flags")

-- Item Groups
data:extend({
  {
    type = "item-group",
    name = "admin-paperwork-group",
    order = "za",
    icon = item_icons .. "blank-form.png",
    icon_size = 64
  },
  {
    type = "item-group",
    name = "admin-logistics-group",
    order = "zb",
    icon = item_icons .. "office-building.png",
    icon_size = 64
  },
  {
    type = "item-group",
    name = "admin-biter-group",
    order = "zd",
    icon = "__base__/graphics/icons/behemoth-biter.png",
    icon_size = 64
  }
})

-- Space Age's hidden Recycler recipes remain browseable in Factoriopedia. Keep
-- them out of the normal paperwork tab so the two form-conversion paths and
-- Old Archive recovery can be found without scanning ordinary production.
if feature_flags.space_age_enabled() then
  data:extend({
    {
      type = "item-group",
      name = "admin-recycling-group",
      order = "ze",
      icon = "__quality__/graphics/icons/recycler.png",
      icon_size = 64,
    },
    {
      type = "item-subgroup",
      name = "archive-recovery-recipes",
      group = "admin-recycling-group",
      order = "a",
    },
    {
      type = "item-subgroup",
      name = "form-reassignment-recipes",
      group = "admin-recycling-group",
      order = "b",
    },
    {
      type = "item-subgroup",
      name = "form-paper-recycling-recipes",
      group = "admin-recycling-group",
      order = "c",
    },
  })
end

-- Subgroups (Paperwork Group) - Forms only, ordered by tier/category
data:extend({
  -- Forms & permits (tiered: base -> permits -> work orders -> printed)
  { type = "item-subgroup", name = "forms-base",         group = "admin-paperwork-group", order = "a" },
  { type = "item-subgroup", name = "forms-permits",      group = "admin-paperwork-group", order = "b" },
  { type = "item-subgroup", name = "forms-work-orders",  group = "admin-paperwork-group", order = "c" },
  { type = "item-subgroup", name = "forms-printed",      group = "admin-paperwork-group", order = "d" },
})

-- Subgroups (Logistics/Admin Group)
data:extend({
  { type = "item-subgroup", name = "admin-raw",            group = "admin-logistics-group", order = "a" },
  { type = "item-subgroup", name = "admin-paper-supplies", group = "admin-logistics-group", order = "b" },
  { type = "item-subgroup", name = "admin-bs-economy",     group = "admin-logistics-group", order = "c" },
  { type = "item-subgroup", name = "admin-fluids",         group = "admin-logistics-group", order = "d" },
  { type = "item-subgroup", name = "admin-money",          group = "admin-logistics-group", order = "e" },
  { type = "item-subgroup", name = "admin-infrastructure", group = "admin-logistics-group", order = "f" },
  { type = "item-subgroup", name = "admin-buildings",      group = "admin-logistics-group", order = "g" },
  { type = "item-subgroup", name = "admin-printers",       group = "admin-logistics-group", order = "h" },
  { type = "item-subgroup", name = "admin-production",     group = "admin-logistics-group", order = "i" },
  { type = "item-subgroup", name = "admin-recycling",      group = "admin-logistics-group", order = "j" },
})

-- Space Age owns the vanilla space item group. Do not register these
-- subgroups without it: item-subgroups must always reference an existing
-- item-group during Factorio's prototype ID assignment.
if feature_flags.space_age_enabled() then
  data:extend({
    { type = "item-subgroup", name = "admin-space-compliance", group = "space", order = "za" },
    { type = "item-subgroup", name = "admin-space-orbital",    group = "space", order = "zb" },
    { type = "item-subgroup", name = "admin-space-buildings",  group = "space", order = "zc" },
  })
end

-- Biter Group Subgroups
data:extend({
  { type = "item-subgroup", name = "admin-biter-buildings",      group = "admin-biter-group", order = "a" },
  { type = "item-subgroup", name = "admin-biter-employees",      group = "admin-biter-group", order = "b" },
  { type = "item-subgroup", name = "admin-biter-management",     group = "admin-biter-group", order = "c" },
  { type = "item-subgroup", name = "admin-biter-operations",     group = "admin-biter-group", order = "d" },
})

-- Admin intermediate subgroup in vanilla intermediate-products group
data:extend({
  { type = "item-subgroup", name = "admin-intermediate", group = "intermediate-products", order = "za" },
})

-- Biter complaint resolution subgroups (Military tab)
data:extend({
  { type = "item-subgroup", name = "resolution-landscape",        group = "combat", order = "za" },
  { type = "item-subgroup", name = "resolution-smog",             group = "combat", order = "zb" },
  { type = "item-subgroup", name = "resolution-noise",            group = "combat", order = "zc" },
  { type = "item-subgroup", name = "resolution-unemployment",     group = "combat", order = "zd" },
  { type = "item-subgroup", name = "resolution-littering",        group = "combat", order = "ze" },
  { type = "item-subgroup", name = "resolution-hazmat",           group = "combat", order = "zf" },
  { type = "item-subgroup", name = "resolution-loitering",        group = "combat", order = "zg" },
  { type = "item-subgroup", name = "resolution-vagrancy",         group = "combat", order = "zh" },
})
