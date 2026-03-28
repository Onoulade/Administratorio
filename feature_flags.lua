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

return M
