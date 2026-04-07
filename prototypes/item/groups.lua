local item_icons = "__administratorio__/graphics/icons/"

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

-- Subgroups (Paperwork Group)
data:extend({
  -- Forms & permits
  { type = "item-subgroup", name = "forms-base",         group = "admin-paperwork-group", order = "a" },
  { type = "item-subgroup", name = "forms-permits",      group = "admin-paperwork-group", order = "b" },
  { type = "item-subgroup", name = "forms-work-orders",  group = "admin-paperwork-group", order = "c" },
  { type = "item-subgroup", name = "forms-printed",      group = "admin-paperwork-group", order = "d" },
  -- Resolution by complaint tier
  { type = "item-subgroup", name = "resolution-landscape",    group = "admin-paperwork-group", order = "e" },
  { type = "item-subgroup", name = "resolution-smog",         group = "admin-paperwork-group", order = "f" },
  { type = "item-subgroup", name = "resolution-noise",        group = "admin-paperwork-group", order = "g" },
  { type = "item-subgroup", name = "resolution-unemployment", group = "admin-paperwork-group", order = "h" },
  -- Spitter complaint resolution subgroups
  { type = "item-subgroup", name = "resolution-littering",    group = "admin-paperwork-group", order = "i" },
  { type = "item-subgroup", name = "resolution-hazmat",       group = "admin-paperwork-group", order = "j" },
  { type = "item-subgroup", name = "resolution-loitering",    group = "admin-paperwork-group", order = "k" },
  { type = "item-subgroup", name = "resolution-vagrancy",     group = "admin-paperwork-group", order = "l" },
})

-- Subgroups (Logistics/Admin Group)
data:extend({
  { type = "item-subgroup", name = "admin-raw",            group = "admin-logistics-group", order = "a" },
  { type = "item-subgroup", name = "admin-bs-economy",     group = "admin-logistics-group", order = "b" },
  { type = "item-subgroup", name = "admin-fluids",         group = "admin-logistics-group", order = "c" },
  { type = "item-subgroup", name = "admin-money",          group = "admin-logistics-group", order = "d" },
  { type = "item-subgroup", name = "admin-infrastructure", group = "admin-logistics-group", order = "f" },
  { type = "item-subgroup", name = "admin-buildings",      group = "admin-logistics-group", order = "g" },
})

-- Admin intermediate subgroup in vanilla intermediate-products group
data:extend({
  { type = "item-subgroup", name = "admin-intermediate", group = "intermediate-products", order = "za" },
})
