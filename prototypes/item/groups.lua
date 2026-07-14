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
      order = "zc",
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

-- Subgroups (Paperwork Group)
data:extend({
  -- Forms & permits
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
})

-- Admin intermediate subgroup in vanilla intermediate-products group
data:extend({
  { type = "item-subgroup", name = "admin-intermediate", group = "intermediate-products", order = "za" },
})

-- Biter complaint resolution subgroups (Military tab)
data:extend({
  { type = "item-subgroup", name = "admin-biter-buildings",       group = "combat", order = "za" },
  -- Biter complaint tiers
  { type = "item-subgroup", name = "resolution-landscape",        group = "combat", order = "zb" },
  { type = "item-subgroup", name = "resolution-smog",             group = "combat", order = "zc" },
  { type = "item-subgroup", name = "resolution-noise",            group = "combat", order = "zd" },
  { type = "item-subgroup", name = "resolution-unemployment",     group = "combat", order = "ze" },
  -- Spitter complaint tiers
  { type = "item-subgroup", name = "resolution-littering",        group = "combat", order = "zf" },
  { type = "item-subgroup", name = "resolution-hazmat",           group = "combat", order = "zg" },
  { type = "item-subgroup", name = "resolution-loitering",        group = "combat", order = "zh" },
  { type = "item-subgroup", name = "resolution-vagrancy",         group = "combat", order = "zi" },
})
