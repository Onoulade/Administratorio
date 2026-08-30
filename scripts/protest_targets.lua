local feature_flags = require("feature_flags")

local M = {}

local BASE_PROTEST_TARGET_TYPES = {
  "assembling-machine",
  "furnace",
  "lab",
  "mining-drill",
}

local DEBUG_BELT_INSERTER_PROTEST_TARGET_TYPES = {
  "transport-belt",
  "underground-belt",
  "splitter",
  "inserter",
}

local PROTEST_TARGET_NAMES = {
  "office-desk",
  "greenhouse",
  "corporate-breakroom",
  "union-headquarters",
  "propaganda-distillery",
  "printer-t1",
  "printer-t2",
  "tube-intake",
  "tube-outtake",
}

local PROTEST_PROTECTED_NAMES = {
  ["admin-station"] = true,
  ["resolution-office"] = true,
}

-- Substantial structures that hard-mode protesters may deliberately demolish
-- after a protest-target path request proves that they are blocked. Normal
-- mode never uses this list for destructive routing. Small transport
-- infrastructure is intentionally absent: belts, inserters, loaders, pipes,
-- underground pipes, rails, poles, and combinators are never breach targets.
local PROTEST_OBSTACLE_BUILDING_TYPES = {
  "accumulator",
  "agricultural-tower",
  "ammo-turret",
  "artillery-turret",
  "assembling-machine",
  "asteroid-collector",
  "beacon",
  "boiler",
  "burner-generator",
  "cargo-bay",
  "cargo-landing-pad",
  "container",
  "electric-energy-interface",
  "electric-turret",
  "fluid-turret",
  "furnace",
  "fusion-generator",
  "fusion-reactor",
  "gate",
  "generator",
  "lab",
  "lightning-attractor",
  "logistic-container",
  "market",
  "mining-drill",
  "offshore-pump",
  "radar",
  "reactor",
  "roboport",
  "rocket-silo",
  "solar-panel",
  "storage-tank",
  "thruster",
  "wall",
}

local function copy_array(source)
  local copy = {}
  for index, value in ipairs(source) do
    copy[index] = value
  end
  return copy
end

local function copy_set(source)
  local copy = {}
  for key, value in pairs(source) do
    copy[key] = value
  end
  return copy
end

function M.get_target_types()
  local target_types = copy_array(BASE_PROTEST_TARGET_TYPES)
  if feature_flags.debug_protest_belts_and_inserters_enabled() then
    for _, target_type in ipairs(DEBUG_BELT_INSERTER_PROTEST_TARGET_TYPES) do
      target_types[#target_types + 1] = target_type
    end
  end
  return target_types
end

function M.get_target_names()
  return copy_array(PROTEST_TARGET_NAMES)
end

function M.get_protected_names()
  return copy_set(PROTEST_PROTECTED_NAMES)
end

function M.get_obstacle_building_types()
  return copy_array(PROTEST_OBSTACLE_BUILDING_TYPES)
end

return M
