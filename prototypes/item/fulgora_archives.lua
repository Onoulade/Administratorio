local item_icons = "__administratorio__/graphics/icons/"

data:extend({
  {
    type = "item",
    name = "old-archive",
    icons = {
      {icon = item_icons .. "useless-documentation.png", icon_size = 64, tint = {r = 0.72, g = 0.62, b = 0.82, a = 1}},
      {icon = item_icons .. "redundant-rubble.png", icon_size = 64, scale = 0.34, shift = {8, 8}},
    },
    subgroup = "admin-raw",
    order = "b7[old-archive]",
    stack_size = 100,
  },
  {
    type = "item",
    name = "archive-recombination-bureau",
    icons = {
      {icon = item_icons .. "office-building.png", icon_size = 64, tint = {r = 0.75, g = 0.58, b = 0.86, a = 1}},
      {icon = item_icons .. "redundant-rubble.png", icon_size = 64, scale = 0.32, shift = {8, 8}},
    },
    subgroup = "admin-buildings",
    order = "l2[archive-recombination-bureau]",
    place_result = "archive-recombination-bureau",
    stack_size = 20,
  },
})
