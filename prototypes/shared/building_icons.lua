local M = {}

local item_icons = "__administratorio__/graphics/icons/"

function M.field_office()
  return {
    {
      icon = item_icons .. "field-office.png",
      icon_size = 64,
    },
  }
end

function M.transit_permit_chest()
  return {
    {icon = "__base__/graphics/icons/steel-chest.png", icon_size = 64},
    {icon = item_icons .. "transit-authorization.png", icon_size = 64, scale = 0.36, shift = {8, 8}},
  }
end

function M.public_train_stop()
  return {
    {icon = "__base__/graphics/icons/train-stop.png", icon_size = 64},
    {icon = item_icons .. "public-transportation-contract.png", icon_size = 64, scale = 0.36, shift = {8, 8}},
  }
end

local trajectory_tiers = {
  junior = {},
  senior = {
    tint = {r = 0.72, g = 0.88, b = 1, a = 1},
  },
  executive = {
    tint = {r = 1, g = 0.72, b = 0.34, a = 1},
  },
}

function M.trajectory_array(tier)
  local spec = assert(trajectory_tiers[tier], "unknown trajectory array tier: " .. tostring(tier))
  return {{
    icon = item_icons .. "trajectory-compliance-array-v3.png",
    icon_size = 256,
    tint = spec.tint,
  }}
end

return M
