local M = {}

local function set_ai_setting(settings, key, value)
  if not settings then return false end
  local ok = pcall(function()
    settings[key] = value
  end)
  return ok
end

function M.apply_managed_unit_settings(unit)
  if not unit or not unit.valid or (unit.type and unit.type ~= "unit") then return false end

  local ok, settings = pcall(function() return unit.ai_settings end)
  if not ok or not settings then return false end

  -- Runtime LuaAISettings prefixes this key with "allow_"; the prototype
  -- UnitAISettings field below deliberately uses the unprefixed spelling.
  local protected_from_command_failure = set_ai_setting(settings, "allow_destroy_when_commands_fail", false)
  local detached_from_spawner = set_ai_setting(settings, "allow_try_return_to_spawner", false)
  local excluded_from_attacks = set_ai_setting(settings, "join_attacks", false)
  return protected_from_command_failure and detached_from_spawner and excluded_from_attacks
end

function M.reset_regular_unit_settings(unit)
  if not unit or not unit.valid or (unit.type and unit.type ~= "unit") then return false end

  local ok, settings = pcall(function() return unit.ai_settings end)
  if not ok or not settings then return false end

  local restored_command_failure = set_ai_setting(settings, "allow_destroy_when_commands_fail", true)
  local restored_spawner_return = set_ai_setting(settings, "allow_try_return_to_spawner", true)
  local restored_attack_joining = set_ai_setting(settings, "join_attacks", true)
  return restored_command_failure and restored_spawner_return and restored_attack_joining
end

function M.release_as_regular_enemy(unit)
  if not unit or not unit.valid or (unit.type and unit.type ~= "unit") then return false end

  M.reset_regular_unit_settings(unit)

  if game and game.forces and game.forces["enemy"] then
    pcall(function() unit.force = game.forces["enemy"] end)
  else
    pcall(function() unit.force = "enemy" end)
  end
  pcall(function() unit.destructible = true end)
  pcall(function() unit.active = true end)
  if unit.commandable and unit.commandable.set_command and defines and defines.command then
    pcall(function()
      unit.commandable.set_command({
        type = defines.command.stop,
        distraction = defines.distraction.by_enemy,
      })
    end)
  end
  return true
end

function M.apply_managed_prototype_settings(prototype)
  if not prototype then return nil end

  prototype.ai_settings = table.deepcopy(prototype.ai_settings or {})
  prototype.ai_settings.destroy_when_commands_fail = false
  prototype.ai_settings.allow_try_return_to_spawner = false
  prototype.ai_settings.join_attacks = false
  return prototype
end

return M
