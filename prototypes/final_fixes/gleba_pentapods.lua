local M = {}

-- Keep the vanilla small-family mix. Evolution still shortens each nest's
-- spawning cooldown, but it can no longer replace small units with larger ones.
local SMALL_SPAWNS = {
  ["gleba-spawner"] = {
    {"small-wriggler-pentapod", {{0, 0.4}, {1, 0.4}}},
    {"small-strafer-pentapod", {{0, 0.4}, {1, 0.4}}},
    {"small-stomper-pentapod", {{0, 0.2}, {1, 0.2}}},
  },
  ["gleba-spawner-small"] = {
    {"small-wriggler-pentapod", {{0, 0.9}, {1, 0.9}}},
  },
}

local function keep_egg_hatch_small(effects)
  if not effects then return end
  if effects.type == "create-entity"
      and (effects.entity_name == "medium-wriggler-pentapod-premature"
        or effects.entity_name == "big-wriggler-pentapod-premature") then
    effects.entity_name = "small-wriggler-pentapod-premature"
  end
  for _, child in pairs(effects) do
    if type(child) == "table" then keep_egg_hatch_small(child) end
  end
end

function M.apply(data_stage)
  for name, result_units in pairs(SMALL_SPAWNS) do
    local spawner = data_stage.raw["unit-spawner"] and data_stage.raw["unit-spawner"][name]
    if spawner then spawner.result_units = result_units end
  end

  local egg = data_stage.raw.item and data_stage.raw.item["pentapod-egg"]
  if egg and egg.spoil_to_trigger_result then
    keep_egg_hatch_small(egg.spoil_to_trigger_result)
  end
end

return M
