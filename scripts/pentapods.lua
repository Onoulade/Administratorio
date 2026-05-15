local C = require("scripts.constants")

local M = {}

M.PENTAPOD_EGG_YIELDS = {
  ["small-wriggler-pentapod"] = 1,
  ["medium-wriggler-pentapod"] = 2,
  ["big-wriggler-pentapod"] = 3,
  ["small-strafer-pentapod"] = 1,
  ["medium-strafer-pentapod"] = 2,
  ["big-strafer-pentapod"] = 3,
  ["small-stomper-pentapod"] = 2,
  ["medium-stomper-pentapod"] = 3,
  ["big-stomper-pentapod"] = 4,
  ["small-pentapod-premature"] = 1,
  ["medium-pentapod-premature"] = 1,
  ["big-pentapod-premature"] = 2,
}

local HATCHED_PENTAPOD_SCRIPT_EFFECT = "administratorio-pentapod-egg-hatch"
local HATCHED_PENTAPOD_FORCE_NAME = C.HATCHED_PENTAPOD_FORCE_NAME or "administratorio-hatched-pentapods"
local PENTAPOD_MONEY_BAIT_INTERVAL_TICKS = C.PENTAPOD_MONEY_BAIT_INTERVAL_TICKS or 120
local PENTAPOD_MONEY_BAIT_SCAN_LIMIT = C.PENTAPOD_MONEY_BAIT_SCAN_LIMIT or 24
local PENTAPOD_MONEY_BAIT_LURE_RADIUS = C.PENTAPOD_MONEY_BAIT_LURE_RADIUS or 24
local PENTAPOD_MONEY_BAIT_PICKUP_RADIUS = C.PENTAPOD_MONEY_BAIT_PICKUP_RADIUS or 1.75
local PENTAPOD_MONEY_BAIT_MIN_MONEY_PER_EGG = C.PENTAPOD_MONEY_BAIT_MIN_MONEY_PER_EGG or 10
local PENTAPOD_MONEY_BAIT_MAX_MONEY_PER_EGG = C.PENTAPOD_MONEY_BAIT_MAX_MONEY_PER_EGG or 20
local HATCHED_PENTAPOD_UNITS = {
  ["small-pentapod-premature"] = true,
  ["medium-pentapod-premature"] = true,
  ["big-pentapod-premature"] = true,
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

local function spill_pentapod_eggs(surface, position, count, force)
  if surface.spill_item_stack then
    surface.spill_item_stack{
      position = position,
      stack = {name = "pentapod-egg", count = count},
      enable_looted = true,
      force = force,
    }
  else
    surface.create_entity{
      name = "item-on-ground",
      position = position,
      stack = {name = "pentapod-egg", count = count},
    }
  end

  if rendering and rendering.draw_text then
    pcall(rendering.draw_text, {
      text = {"", "+", tostring(count), " ", {"item-name.pentapod-egg"}},
      surface = surface,
      target = position,
      color = {r = 0.9, g = 0.95, b = 0.25, a = 1},
      time_to_live = 90,
    })
  end
end

local function get_ground_item_count(item)
  local stack = item and item.valid and item.stack
  if not stack or not stack.valid_for_read or stack.name ~= "taxpayer-money" then return 0 end
  return stack.count or 0
end

local function consume_ground_money(item)
  local stack = item and item.valid and item.stack
  if not stack or not stack.valid_for_read or stack.name ~= "taxpayer-money" then return false end
  local count = stack.count or 0
  item.destroy()
  return count
end

local function roll_pentapod_bait_eggs(money_count)
  local eggs = 0
  local remaining = money_count or 0
  while remaining >= PENTAPOD_MONEY_BAIT_MIN_MONEY_PER_EGG do
    local cost = math.random(PENTAPOD_MONEY_BAIT_MIN_MONEY_PER_EGG, PENTAPOD_MONEY_BAIT_MAX_MONEY_PER_EGG)
    if remaining < cost then
      if eggs == 0 then
        eggs = 1
      end
      break
    end
    eggs = eggs + 1
    remaining = remaining - cost
  end
  return eggs
end

local function command_pentapod_to_money(unit, money)
  if not unit.commandable or not money.valid then return end
  local destination = {x = money.position.x, y = money.position.y}
  unit.commandable.set_command{
    type = defines.command.go_to_location,
    destination = destination,
    radius = 0.75,
    distraction = defines.distraction.none,
  }
end

function M.process_money_baits(tick)
  if (tick % PENTAPOD_MONEY_BAIT_INTERVAL_TICKS) ~= 0 then return end
  for _, surface in pairs(game.surfaces or {}) do
    if surface.valid ~= false then
      local money_items = surface.find_entities_filtered{
        name = "item-on-ground",
        limit = PENTAPOD_MONEY_BAIT_SCAN_LIMIT,
      }
      for _, money in ipairs(money_items) do
        if get_ground_item_count(money) > 0 then
          local money_position = {x = money.position.x, y = money.position.y}
          local pentapod_units = surface.find_entities_filtered{
            force = "enemy",
            type = "unit",
            position = money_position,
            radius = PENTAPOD_MONEY_BAIT_LURE_RADIUS,
          }
          local closest = nil
          local closest_dist = math.huge
          for _, unit in ipairs(pentapod_units) do
            if unit.valid and M.is_pentapod(unit.name) and not storage.waiting_biters[unit.unit_number] then
              local dx = unit.position.x - money_position.x
              local dy = unit.position.y - money_position.y
              local dist = dx * dx + dy * dy
              if dist < closest_dist then
                closest = unit
                closest_dist = dist
              end
            end
          end

          if closest then
            if closest_dist <= PENTAPOD_MONEY_BAIT_PICKUP_RADIUS * PENTAPOD_MONEY_BAIT_PICKUP_RADIUS then
              local pentapod_force = closest.valid and closest.force or nil
              local money_count = consume_ground_money(money)
              local egg_count = roll_pentapod_bait_eggs(money_count)
              if pentapod_force and egg_count > 0 then
                spill_pentapod_eggs(surface, money_position, egg_count, pentapod_force)
              end
            else
              command_pentapod_to_money(closest, money)
            end
          end
        end
      end
    end
  end
end

-- Returns true if the event was handled (pentapod egg hatch).
function M.on_script_trigger_effect(event)
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
