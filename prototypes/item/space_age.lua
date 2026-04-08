local item_icons = "__administratorio__/graphics/icons/"

data:extend({
  {
    type = "item",
    name = "job-offer",
    icon = "__administratorio__/graphics/icons/management-written-proposal.png",
    icon_size = 64,
    subgroup = "admin-bs-economy",
    order = "j-0",
    stack_size = 20
  },
  {
    type = "item",
    name = "enrolled-biter",
    icon = "__base__/graphics/icons/small-biter.png",
    icon_size = 64,
    subgroup = "admin-bs-economy",
    order = "j-a",
    stack_size = 20
  },
  {
    type = "item",
    name = "worker-biter",
    icon = "__base__/graphics/icons/small-biter.png",
    icon_size = 64,
    subgroup = "admin-bs-economy",
    order = "j-a2",
    stack_size = 20
  },
  {
    type = "item",
    name = "clerical-trainee",
    icon = "__base__/graphics/icons/medium-biter.png",
    icon_size = 64,
    subgroup = "admin-bs-economy",
    order = "j-b",
    stack_size = 20
  },
  {
    type = "item",
    name = "management-trainee",
    icon = "__base__/graphics/icons/big-biter.png",
    icon_size = 64,
    subgroup = "admin-bs-economy",
    order = "j-c",
    stack_size = 20
  },
  {
    type = "item",
    name = "night-shift-supervisor",
    icons = {
      {icon = "__base__/graphics/icons/small-biter.png", icon_size = 64},
      {icon = item_icons .. "overtime-module.png", icon_size = 64, scale = 0.5, shift = {8, 8}},
    },
    subgroup = "admin-bs-economy",
    order = "j-d",
    stack_size = 20
  },
  {
    type = "item",
    name = "licensed-notary",
    icons = {
      {icon = "__base__/graphics/icons/small-biter.png", icon_size = 64},
      {icon = item_icons .. "construction-permit.png", icon_size = 64, scale = 0.5, shift = {8, 8}},
    },
    subgroup = "admin-bs-economy",
    order = "j-e",
    stack_size = 20
  },
  {
    type = "item",
    name = "conciliation-officer",
    icons = {
      {icon = "__base__/graphics/icons/small-biter.png", icon_size = 64},
      {icon = item_icons .. "promise.png", icon_size = 64, scale = 0.5, shift = {8, 8}},
    },
    subgroup = "admin-bs-economy",
    order = "j-f",
    stack_size = 20
  },
  {
    type = "item",
    name = "relay-clerk",
    icons = {
      {icon = "__base__/graphics/icons/small-biter.png", icon_size = 64},
      {icon = item_icons .. "data.png", icon_size = 64, scale = 0.5, shift = {8, 8}},
    },
    subgroup = "admin-bs-economy",
    order = "j-g",
    stack_size = 20
  },
  {
    type = "item",
    name = "cryoprint-technician",
    icons = {
      {icon = "__base__/graphics/icons/small-biter.png", icon_size = 64},
      {icon = item_icons .. "steel-forge-icon.png", icon_size = 64, scale = 0.5, shift = {8, 8}},
    },
    subgroup = "admin-bs-economy",
    order = "j-h",
    stack_size = 20
  },
  {
    type = "item",
    name = "field-negotiator",
    icons = {
      {icon = "__base__/graphics/icons/big-biter.png", icon_size = 64},
      {icon = item_icons .. "eviction-notice.png", icon_size = 64, scale = 0.5, shift = {8, 8}},
    },
    subgroup = "admin-bs-economy",
    order = "j-i",
    stack_size = 20
  },
  {
    type = "item",
    name = "middle-management-managing-manager",
    icons = {
      {icon = "__base__/graphics/icons/behemoth-biter.png", icon_size = 64},
      {icon = item_icons .. "policy.png", icon_size = 64, scale = 0.5, shift = {8, 8}},
    },
    subgroup = "admin-bs-economy",
    order = "j-j",
    stack_size = 20
  },
  {
    type = "item",
    name = "formation-center",
    icon = "__base__/graphics/icons/biter-spawner.png",
    icon_size = 64,
    subgroup = "admin-buildings",
    order = "h",
    place_result = "formation-center",
    stack_size = 20
  },
  {
    type = "item",
    name = "chromatic-printer",
    icon = "__administratorio__/graphics/icons/steel-forge-icon.png",
    icon_size = 64,
    subgroup = "admin-printers",
    order = "d",
    place_result = "chromatic-printer",
    stack_size = 50
  },
})
