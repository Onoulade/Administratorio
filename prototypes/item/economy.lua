local item_icons = "__administratorio__/graphics/icons/"

local function biter_role_icons(biter_icon, tint, overlay_icon)
  local icons = {
    {icon = biter_icon, icon_size = 64, tint = tint},
  }
  if overlay_icon then
    icons[#icons + 1] = {icon = overlay_icon, icon_size = 64, scale = 0.35, shift = {8, 8}}
  end
  return icons
end

data:extend({
  { type = "fuel-category", name = "administratorio-taxpayer-money" },

  -- Raw Resources (admin group)
  { type = "item", name = "bullshit-ore",     icon = item_icons .. "bullshit-ore.png",  icon_size = 64, subgroup = "admin-raw", order = "a", stack_size = 100 },
  { type = "item", name = "redundant-rubble", icon = item_icons .. "redundant-rubble.png", icon_size = 64, subgroup = "admin-raw", order = "b", stack_size = 100 },
  { type = "item", name = "compacted-rubble", icons = {{icon = item_icons .. "compacted-rubble.png", icon_size = 64, tint = {r=0.5, g=0.5, b=0.5, a=1}}}, subgroup = "admin-raw", order = "b2", stack_size = 100 },
  { type = "item", name = "useless-documentation", icon = item_icons .. "useless-documentation.png", icon_size = 64, subgroup = "admin-raw", order = "b3", stack_size = 100 },
  { type = "item", name = "refined-nonsense", icons = {{icon = item_icons .. "regulation.png", icon_size = 64, tint = {r=0.7, g=0.3, b=0.6, a=1}}}, subgroup = "admin-raw", order = "b4", stack_size = 100 },

  -- Core administrative supplies
  { type = "item", name = "paper",            icon = item_icons .. "paper.png",         icon_size = 64, subgroup = "admin-paper-supplies", order = "a", stack_size = 200 },
  { type = "item", name = "ink",              icons = {{icon = item_icons .. "ink-cartridge.png", icon_size = 64, tint = {r=0.35, g=0.35, b=0.45, a=1}}}, subgroup = "admin-paper-supplies", order = "b", stack_size = 100 },
  { type = "item", name = "coffee-bean",      icon = item_icons .. "coffee-bean.png",   icon_size = 32, subgroup = "admin-paper-supplies", order = "c", stack_size = 50 },
  -- BS Economy Intermediaries
  { type = "item", name = "dubious-data",       icon = item_icons .. "dubious-data.png",       icon_size = 64, subgroup = "admin-bs-economy", order = "a", stack_size = 100 },
  { type = "item", name = "basic-excuse",       icon = item_icons .. "basic-excuse.png",       icon_size = 64, subgroup = "admin-bs-economy", order = "b", stack_size = 100 },
  { type = "item", name = "crappy-report",      icon = item_icons .. "crappy-report.png",      icon_size = 64, subgroup = "admin-bs-economy", order = "c", stack_size = 100 },
  { type = "item", name = "credentials",        icon = item_icons .. "credentials.png",        icon_size = 64, subgroup = "admin-bs-economy", order = "d", stack_size = 100 },
  { type = "item", name = "data",               icon = item_icons .. "data.png",               icon_size = 64, subgroup = "admin-bs-economy", order = "e", stack_size = 100 },
  { type = "item", name = "good-excuse",        icon = item_icons .. "good-excuse.png",        icon_size = 64, subgroup = "admin-bs-economy", order = "f", stack_size = 100 },
  { type = "item", name = "justification",      icon = item_icons .. "justification.png",      icon_size = 64, subgroup = "admin-bs-economy", order = "g", stack_size = 100 },
  { type = "item", name = "narrative",          icon = item_icons .. "narrative.png",           icon_size = 64, subgroup = "admin-bs-economy", order = "h", stack_size = 100 },
  { type = "item", name = "policy",             icon = item_icons .. "policy.png",              icon_size = 64, subgroup = "admin-bs-economy", order = "i", stack_size = 100 },
  { type = "item", name = "regulation",         icon = item_icons .. "regulation.png",          icon_size = 64, subgroup = "admin-bs-economy", order = "k", stack_size = 100 },
  { type = "item", name = "watercooler-gossip", icon = item_icons .. "watercooler-gossip.png",  icon_size = 64, subgroup = "admin-bs-economy", order = "z", stack_size = 100 },
  {
    type = "item", name = "office-drama",
    icons = {{icon = item_icons .. "watercooler-gossip.png", icon_size = 64, tint = {r=0.9, g=0.3, b=0.3}}},
    subgroup = "admin-bs-economy", order = "z1", stack_size = 100
  },

  -- Money
  { type = "item", name = "taxpayer-money",   icon = item_icons .. "taxpayer-money.png",   icon_size = 64, subgroup = "admin-money", order = "a", stack_size = 200, fuel_category = "administratorio-taxpayer-money", fuel_value = "500kJ", fuel_emissions_multiplier = 1.5 },
  { type = "item", name = "treasury-bond",    icon = item_icons .. "treasury-bond.png",    icon_size = 64, subgroup = "admin-money", order = "b", stack_size = 200 },
  { type = "item", name = "government-grant", icon = item_icons .. "government-grant.png", icon_size = 64, subgroup = "admin-money", order = "c", stack_size = 100 },

  -- Biter Employment - moved to admin-biter-group
  {
    type = "item", name = "job-offer",
    icons = {{icon = item_icons .. "blank-form.png", icon_size = 64, tint = {r=0.4, g=0.9, b=0.4, a=1}}},
    subgroup = "admin-biter-employees", order = "a", stack_size = 20
  },
  {
    type = "item", name = "biter-worker",
    icons = biter_role_icons("__base__/graphics/icons/small-biter.png", {r=0.75, g=0.95, b=0.65, a=1}),
    subgroup = "admin-biter-employees", order = "b", stack_size = 1
  },
  {
    type = "item", name = "biter-logistics-formation",
    icons = biter_role_icons("__base__/graphics/icons/small-biter.png", {r=0.45, g=0.85, b=0.55, a=1}),
    subgroup = "admin-biter-employees", order = "c", stack_size = 1
  },
  {
    type = "item", name = "rideable-biter",
    icons = biter_role_icons("__base__/graphics/icons/medium-biter.png", {r=0.55, g=0.75, b=1.0, a=1}),
    subgroup = "transport", order = "b[personal-transport]-a[rideable-biter]",
    place_result = "rideable-biter", stack_size = 1
  },
  {
    type = "item", name = "biter-station",
    icon = item_icons .. "biter-station.png", icon_size = 64,
    subgroup = "admin-biter-buildings", order = "a1", place_result = "biter-station", stack_size = 40
  },
  {
    type = "item", name = "union-delegate",
    icons = biter_role_icons("__base__/graphics/icons/medium-biter.png", {r=0.45, g=0.55, b=1.0, a=1}),
    subgroup = "admin-biter-management", order = "a", stack_size = 10
  },
  {
    type = "item", name = "chemical-operator",
    icons = biter_role_icons("__base__/graphics/icons/medium-biter.png", {r=1.0, g=0.75, b=0.25, a=1}),
    subgroup = "admin-biter-operations", order = "a", stack_size = 10
  },
  {
    type = "item", name = "nuclear-technician",
    icons = biter_role_icons("__base__/graphics/icons/medium-biter.png", {r=0.35, g=1.0, b=0.85, a=1}),
    subgroup = "admin-biter-operations", order = "b", stack_size = 10
  },
})
