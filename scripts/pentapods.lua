local C = require("scripts.constants")

local M = {}

M.PENTAPOD_EGG_YIELDS = {
  ["small-wriggler-pentapod"] = 1,
  ["medium-wriggler-pentapod"] = 2,
  ["big-wriggler-pentapod"] = 4,
  ["small-strafer-pentapod"] = 1,
  ["medium-strafer-pentapod"] = 2,
  ["big-strafer-pentapod"] = 4,
  ["small-stomper-pentapod"] = 1,
  ["medium-stomper-pentapod"] = 2,
  ["big-stomper-pentapod"] = 4,
  ["small-wriggler-pentapod-premature"] = 1,
  ["medium-wriggler-pentapod-premature"] = 2,
  ["big-wriggler-pentapod-premature"] = 4,
}

local HATCHED_PENTAPOD_SCRIPT_EFFECT = "administratorio-pentapod-egg-hatch"
local PENTAPOD_SAMPLING_SCRIPT_EFFECT = "administratorio-pentapod-sampling"
local HATCHED_PENTAPOD_FORCE_NAME = C.HATCHED_PENTAPOD_FORCE_NAME or "administratorio-hatched-pentapods"
local PENTAPOD_SAMPLING_COOLDOWN_TICKS = C.PENTAPOD_SAMPLING_COOLDOWN_TICKS or 30 * 60
local PENTAPOD_SAMPLING_CAPSULE_NAME = "pentapod-sampling-capsule"
local HATCHED_PENTAPOD_UNITS = {
  ["small-wriggler-pentapod-premature"] = true,
  ["medium-wriggler-pentapod-premature"] = true,
  ["big-wriggler-pentapod-premature"] = true,
}
function M.is_pentapod(entity_name)
  return entity_name ~= nil and M.PENTAPOD_EGG_YIELDS[entity_name] ~= nil
end

local function get_hatched_pentapod_force()
  local force = game.forces[HATCHED_PENTAPOD_FORCE_NAME]
  if not force and game.create_force then
    force = game.create_force(HATCHED_PENTAPOD_FORCE_NAME)
  end
  local player = game.forces.player
  if force and player then
    force.set_cease_fire(player, false)
    player.set_cease_fire(force, false)
  end
  return force
end

local function give_item_to_player(player, name, count)
  if not player or count <= 0 then return end
  local inserted = player.insert{name = name, count = count}
  if inserted < count then
    player.surface.spill_item_stack{
      position = player.position,
      stack = {name = name, count = count - inserted},
      enable_looted = true,
      force = player.force,
    }
  end
end

local function sample_pentapod(event)
  local source = event.source_entity
  local player = source and source.valid and source.type == "character" and source.player or nil
  if not player then return end

  local target = event.target_entity
  local egg_count = target and target.valid and M.PENTAPOD_EGG_YIELDS[target.name] or nil
  if not egg_count or not target.force or target.force.name ~= "enemy"
     or not target.surface.planet or target.surface.planet.name ~= "gleba" then
    give_item_to_player(player, PENTAPOD_SAMPLING_CAPSULE_NAME, 1)
    player.create_local_flying_text{text = {"message.pentapod-sampling-invalid"}, position = player.position}
    return
  end

  local tick = event.tick or game.tick
  storage.pentapod_sampling_cooldowns = storage.pentapod_sampling_cooldowns or {}
  local cooldowns = storage.pentapod_sampling_cooldowns
  for unit_number, expires in pairs(cooldowns) do
    if expires <= tick then cooldowns[unit_number] = nil end
  end
  local expires = cooldowns[target.unit_number]
  if expires and expires > tick then
    give_item_to_player(player, PENTAPOD_SAMPLING_CAPSULE_NAME, 1)
    player.create_local_flying_text{
      text = {"message.pentapod-sampling-cooldown", math.ceil((expires - tick) / 60)},
      position = player.position,
    }
    return
  end

  cooldowns[target.unit_number] = tick + PENTAPOD_SAMPLING_COOLDOWN_TICKS
  give_item_to_player(player, "pentapod-egg", egg_count)
  player.create_local_flying_text{
    text = {"message.pentapod-sampling-success", egg_count},
    position = player.position,
  }
end

-- Returns true if the event was handled (pentapod egg hatch).
function M.on_script_trigger_effect(event)
  if event and event.effect_id == PENTAPOD_SAMPLING_SCRIPT_EFFECT then
    sample_pentapod(event)
    return true
  end
  if not event or event.effect_id ~= HATCHED_PENTAPOD_SCRIPT_EFFECT then return false end

  local source_entity = event.source_entity
  local surface = (source_entity and source_entity.valid and source_entity.surface)
    or (event.surface_index and game.get_surface(event.surface_index))
    or game.surfaces[1]
  if not surface then return true end

  local anchor = (source_entity and source_entity.valid and source_entity.position)
    or event.source_position
    or event.target_position
    or {x = 0, y = 0}
  local force = get_hatched_pentapod_force()
  if not force then return true end

  for _, unit in ipairs(surface.find_entities_filtered{force = "enemy", type = "unit", position = anchor, radius = 12}) do
    if unit.valid and HATCHED_PENTAPOD_UNITS[unit.name] then
      unit.force = force
      if unit.commandable and defines.command.attack_area then
        unit.commandable.set_command{
          type = defines.command.attack_area,
          destination = anchor,
          radius = 48,
          distraction = defines.distraction.by_enemy or defines.distraction.none,
        }
      end
    end
  end
  return true
end

return M
