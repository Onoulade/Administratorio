-- Removes conventional combat prototypes while preserving Administratorio's
-- managerial Space Age defense interfaces.

local M = {}

local visibility_exceptions = {
  ammo = {
    ["orbital-deviation-order"] = true,
    ["priority-orbital-deviation-order"] = true,
    ["voluntary-exploration-space-miner"] = true,
  },
  ["ammo-turret"] = {
    ["trajectory-compliance-array"] = true,
    ["senior-trajectory-compliance-array"] = true,
    ["executive-trajectory-compliance-array"] = true,
    ["orbital-employment-catapult"] = true,
  },
}

function M.apply(data)
  for _, prototype_type in ipairs({"gun", "ammo", "ammo-turret", "electric-turret", "fluid-turret"}) do
    for name, prototype in pairs(data.raw[prototype_type] or {}) do
      if not (visibility_exceptions[prototype_type] or {})[name] then
        prototype.hidden = true
      end
    end
  end

  for _, name in ipairs({
    "railgun", "railgun-ammo", "railgun-turret",
    "teslagun", "tesla-gun", "tesla-ammo", "tesla-turret",
  }) do
    for _, prototype_type in ipairs({"item", "gun", "ammo", "recipe", "ammo-turret", "electric-turret", "fluid-turret"}) do
      local prototype = data.raw[prototype_type] and data.raw[prototype_type][name]
      if prototype then
        prototype.hidden = true
        prototype.enabled = false
      end
    end
    local technology = data.raw.technology and data.raw.technology[name]
    if technology then
      technology.hidden = true
      technology.enabled = false
    end
  end
end

return M
