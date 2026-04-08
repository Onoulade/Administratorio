local M = {}

local function startup_bool(name, default)
  local startup = settings and settings.startup
  local setting = startup and startup[name]
  if setting == nil or setting.value == nil then
    return default
  end
  return setting.value
end

function M.working_hours_enabled()
  return startup_bool("administratorio-enable-working-hours", true)
end

function M.debug_protest_belts_and_inserters_enabled()
  return startup_bool("administratorio-debug-protest-belts-and-inserters", false)
end

function M.debug_hard_mode_enabled()
  return startup_bool("administratorio-debug-hard-mode", false)
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

return M
