local M = {}
local biters = require("scripts.biters")

local NAME = "rideable-biter"
local MIN_IDLE_TICKS = 40
local MAX_IDLE_TICKS = 100
local MAX_TURN = 0.2
local MIN_WANDER_SPEED = 0.02
local MAX_WANDER_SPEED = 0.06
local UNFUNDED_TIMEOUT_TICKS = 10 * 60 * 60

function M.ensure_storage()
  storage.rideable_biters = storage.rideable_biters or {}
end

function M.is_rideable(entity)
  return entity and entity.valid and entity.name == NAME
end

local function next_wander_tick(tick)
  return tick + math.random(MIN_IDLE_TICKS, MAX_IDLE_TICKS)
end

function M.track(entity, tick)
  if not M.is_rideable(entity) or not entity.unit_number then return end
  M.ensure_storage()
  local now = tick or game.tick
  storage.rideable_biters[entity.unit_number] = {
    entity = entity,
    next_wander_tick = next_wander_tick(now),
    unfunded_since_tick = nil,
  }
end

function M.untrack(entity)
  if not entity or not entity.unit_number or not storage.rideable_biters then return end
  storage.rideable_biters[entity.unit_number] = nil
end

function M.rebuild_registry()
  M.ensure_storage()
  storage.rideable_biters = {}
  for _, surface in pairs(game.surfaces) do
    for _, entity in ipairs(surface.find_entities_filtered{name = NAME}) do
      M.track(entity, game.tick)
    end
  end
end

local function get_occupant(entity, method_name)
  if not entity or not entity.valid or type(entity[method_name]) ~= "function" then return nil end
  local ok, occupant = pcall(function() return entity[method_name](entity) end)
  if not ok then return nil end
  return occupant
end

local function is_occupied(entity)
  return get_occupant(entity, "get_driver") ~= nil or get_occupant(entity, "get_passenger") ~= nil
end

local function get_fuel_inventory(entity)
  if not entity or not entity.valid or type(entity.get_fuel_inventory) ~= "function" then return nil end
  local ok, inv = pcall(function() return entity.get_fuel_inventory() end)
  if ok then return inv end
  return nil
end

local function has_taxpayer_money_fuel(entity)
  local fuel_inventory = get_fuel_inventory(entity)
  if not fuel_inventory then return true end
  return fuel_inventory.get_item_count("taxpayer-money") > 0
end

local function can_wander(entity)
  if not M.is_rideable(entity) then return false end
  if is_occupied(entity) then return false end
  return true
end

local function nudge(entity)
  pcall(function()
    entity.orientation = (entity.orientation + (math.random() * 2 - 1) * MAX_TURN) % 1
  end)
  pcall(function()
    entity.speed = MIN_WANDER_SPEED + math.random() * (MAX_WANDER_SPEED - MIN_WANDER_SPEED)
  end)
end

local function spill_inventory(surface, position, inventory)
  if not surface or not inventory then return end
  for i = 1, #inventory do
    local stack = inventory[i]
    if stack and stack.valid_for_read then
      surface.spill_item_stack{
        position = position,
        stack = stack,
        enable_looted = true,
        allow_belts = false,
      }
      stack.clear()
    end
  end
end

local function spill_contents(entity)
  local surface = entity.surface
  local position = entity.position
  if type(entity.get_inventory) == "function" and defines and defines.inventory then
    spill_inventory(surface, position, entity.get_inventory(defines.inventory.car_trunk))
  end
  spill_inventory(surface, position, get_fuel_inventory(entity))
end

local function get_admin_desks()
  local desks = {}
  for _, desk in pairs(storage.admin_desks or {}) do
    if desk and desk.valid then
      desks[#desks + 1] = desk
    end
  end
  return desks
end

local function notify_players(entity)
  if not game or not game.connected_players then return end
  local message = {"message.rideable-biter-unfunded", {"entity-name.rideable-biter"}}
  for _, player in pairs(game.connected_players) do
    if player.surface == entity.surface then
      player.print(message)
    end
  end
end

local function convert_to_complaining_biter(unit_number, entry)
  local entity = entry.entity
  if not M.is_rideable(entity) then
    storage.rideable_biters[unit_number] = nil
    return
  end

  local surface = entity.surface
  local force = game.forces["enemy"] and "enemy" or entity.force
  local position = surface.find_non_colliding_position("medium-biter", entity.position, 8, 0.5) or entity.position
  spill_contents(entity)
  notify_players(entity)
  entity.destroy{raise_destroy = true}
  storage.rideable_biters[unit_number] = nil

  local biter = surface.create_entity{
    name = "medium-biter",
    position = position,
    force = force,
  }
  if not biter or not biter.valid then return end

  local desks = get_admin_desks()
  if #desks > 0 then
    biters.send_biter_to_station_with_targets(biter, desks)
  else
    biters.trigger_immediate_protest(biter, biter.surface)
  end
end

function M.update(tick)
  M.ensure_storage()
  for unit_number, entry in pairs(storage.rideable_biters) do
    local entity = entry.entity
    if not entity or not entity.valid then
      storage.rideable_biters[unit_number] = nil
    else
      if has_taxpayer_money_fuel(entity) then
        entry.unfunded_since_tick = nil
      else
        entry.unfunded_since_tick = entry.unfunded_since_tick or tick
        if tick - entry.unfunded_since_tick >= UNFUNDED_TIMEOUT_TICKS then
          convert_to_complaining_biter(unit_number, entry)
          goto continue
        end
      end

      if tick >= (entry.next_wander_tick or 0) then
        if can_wander(entity) then
          nudge(entity)
        end
        entry.next_wander_tick = next_wander_tick(tick)
      end
    end
    ::continue::
  end
end

return M
