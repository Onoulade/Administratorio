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

return M
