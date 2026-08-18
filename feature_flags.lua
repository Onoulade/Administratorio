local M = {}

local function startup_bool(name, default)
  local startup = settings and settings.startup
  local setting = startup and startup[name]
  if setting == nil or setting.value == nil then
    return default
  end
  return setting.value
end

-- These two flags are runtime-global settings so hard mode and belt/inserter
-- protests can be toggled mid-game rather than only at world creation.
local function runtime_global_bool(name, default)
  local global = settings and settings.global
  local setting = global and global[name]
  if setting == nil or setting.value == nil then
    return default
  end
  return setting.value
end

function M.working_hours_enabled()
  return startup_bool("administratorio-enable-working-hours", true)
end

function M.debug_protest_belts_and_inserters_enabled()
  return runtime_global_bool("administratorio-debug-protest-belts-and-inserters", false)
end

function M.debug_hard_mode_enabled()
  return runtime_global_bool("administratorio-debug-hard-mode", false)
end

local function mod_enabled(mod_name)
  if mods and mods[mod_name] then
    return true
  end

  -- Runtime fallback for control stage.
  if script and script.active_mods and script.active_mods[mod_name] then
    return true
  end

  return false
end

function M.space_age_enabled()
  return mod_enabled("space-age")
end

-- Quality is an optional native dependency.  Keep this as a distinct feature
-- flag rather than treating Space Age as a proxy: base-only Quality installs
-- are valid and Administratorio must remain unchanged without it.
function M.quality_enabled()
  return mod_enabled("quality")
end

-- Space Age (and other optional-dependency) entities may not exist in the
-- current prototype set. find_entities_filtered errors on an unknown
-- prototype name rather than returning empty, so every caller that filters
-- by one of these names must check existence first.
function M.entity_prototype_exists(name)
  if not (prototypes and prototypes.entity) then
    return true
  end
  return prototypes.entity[name] ~= nil
end

return M
