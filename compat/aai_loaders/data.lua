-- ADMINISTRATORIO: AAI LOADERS DATA COMPATIBILITY
--
-- AAI Loaders move items across belt junctions unattended. Keep their
-- paperwork and batch policy in this module so the core rules remain unaware
-- of the foreign mod.

local hooks = require("compat.hooks")
local installed_mods = mods or {}

if not installed_mods["aai-loaders"] then
  return
end

local LOADER_FORMS = {
  ["aai-loader"] = "safety-waiver",
  ["aai-fast-loader"] = "safety-waiver",
  ["aai-express-loader"] = "safety-waiver",
}

local LOADER_BATCH_MULTIPLIERS = {
  ["aai-loader"] = 2,
  ["aai-fast-loader"] = 1,
  ["aai-express-loader"] = 1,
}

hooks.register("recipe_required_form", function(recipe_name)
  return LOADER_FORMS[recipe_name]
end)

hooks.register("recipe_batch_multiplier", function(recipe_name)
  return LOADER_BATCH_MULTIPLIERS[recipe_name]
end)
