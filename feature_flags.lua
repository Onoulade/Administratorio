local M = {}

local function startup_bool(name, default)
  local startup = settings and settings.startup
  local setting = startup and startup[name]
  if setting == nil or setting.value == nil then
    return default
  end
  return setting.value
end

local function runtime_global_bool(name, default)
  local global_settings = settings and settings.global
  local setting = global_settings and global_settings[name]
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
  return runtime_global_bool("administratorio-debug-hard-mode", false)
end

return M
