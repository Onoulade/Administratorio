local M = {}
local biters = require("scripts.biters")

local NAME = "rideable-biter"
local MOUNTED_NAME = "rideable-biter-mounted"
local MIN_IDLE_TICKS = 40
local MAX_IDLE_TICKS = 100
local MAX_TURN = 0.2
local MIN_WANDER_SPEED = 0.02
local MAX_WANDER_SPEED = 0.06
local UNFUNDED_TIMEOUT_TICKS = 10 * 60 * 60

function M.ensure_storage()
  storage.rideable_biters = storage.rideable_biters or {}
  storage.rideable_biter_visual_swap_guard = storage.rideable_biter_visual_swap_guard or {}
  storage.rideable_biter_player_vehicle = storage.rideable_biter_player_vehicle or {}
end

function M.is_rideable(entity)
  return entity and entity.valid and (entity.name == NAME or entity.name == MOUNTED_NAME)
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
  local unit_number = entity.unit_number
  storage.rideable_biters[unit_number] = nil
  for player_index, tracked_unit_number in pairs(storage.rideable_biter_player_vehicle or {}) do
    if tracked_unit_number == unit_number then
      storage.rideable_biter_player_vehicle[player_index] = nil
    end
  end
end

function M.rebuild_registry()
  M.ensure_storage()
  storage.rideable_biters = {}
  storage.rideable_biter_player_vehicle = {}
  for _, surface in pairs(game.surfaces) do
    for _, entity in ipairs(surface.find_entities_filtered{name = {NAME, MOUNTED_NAME}}) do
      M.track(entity, game.tick)
    end
  end
end

local function call_entity_method(entity, method_name, ...)
  if not entity or not entity.valid or type(entity[method_name]) ~= "function" then return false, nil end
  local method = entity[method_name]
  if type(entity) == "table" then
    return pcall(method, entity, ...)
  end
  local ok, result = pcall(method, ...)
  if ok then return true, result end
  -- Plain-table test doubles use conventional colon-style methods.
  return pcall(method, entity, ...)
end

local function get_occupant(entity, method_name)
  local ok, occupant = call_entity_method(entity, method_name)
  if not ok then return nil end
  return occupant
end

local function is_occupied(entity)
  return get_occupant(entity, "get_driver") ~= nil or get_occupant(entity, "get_passenger") ~= nil
end

local get_fuel_inventory

local function transfer_inventory(source, target)
  if not source or not target then return end
  for index = 1, math.min(#source, #target) do
    local source_stack = source[index]
    if source_stack and source_stack.valid_for_read then
      local target_stack = target[index]
      if target_stack and type(target_stack.swap_stack) == "function" then
        target_stack.swap_stack(source_stack)
      elseif type(target.insert) == "function" then
        target.insert(source_stack)
        source_stack.clear()
      end
    end
  end
end

local function copy_burner_state(source, target)
  local source_burner = source and source.burner
  local target_burner = target and target.burner
  if not source_burner or not target_burner then return end
  local currently_burning = source_burner.currently_burning
  local remaining_burning_fuel = source_burner.remaining_burning_fuel
  local heat = source_burner.heat
  pcall(function()
    target_burner.currently_burning = currently_burning
    target_burner.remaining_burning_fuel = remaining_burning_fuel
    target_burner.heat = heat
  end)
end

local function copy_optional_property(source, target, property)
  pcall(function() target[property] = source[property] end)
end

local function swap_visual_entity(entity, target_name, tick)
  if not M.is_rideable(entity) or entity.name == target_name then return entity end
  local surface = entity.surface
  if not surface or type(surface.create_entity) ~= "function" then return entity end

  local driver = get_occupant(entity, "get_driver")
  local passenger = get_occupant(entity, "get_passenger")
  local old_unit_number = entity.unit_number
  local entry = old_unit_number and storage.rideable_biters[old_unit_number]
  local replacement = surface.create_entity{
    name = target_name,
    position = entity.position,
    direction = entity.direction,
    force = entity.force,
    quality = entity.quality,
    create_build_effect_smoke = false,
    raise_built = false,
  }
  if not replacement or not replacement.valid then return entity end

  copy_optional_property(entity, replacement, "orientation")
  copy_optional_property(entity, replacement, "speed")
  copy_optional_property(entity, replacement, "health")
  copy_optional_property(entity, replacement, "color")
  copy_optional_property(entity, replacement, "destructible")
  copy_optional_property(entity, replacement, "operable")
  copy_optional_property(entity, replacement, "last_user")

  if defines and defines.inventory and defines.inventory.car_trunk
      and type(entity.get_inventory) == "function"
      and type(replacement.get_inventory) == "function" then
    transfer_inventory(
      entity.get_inventory(defines.inventory.car_trunk),
      replacement.get_inventory(defines.inventory.car_trunk)
    )
  end
  transfer_inventory(get_fuel_inventory(entity), get_fuel_inventory(replacement))
  copy_burner_state(entity, replacement)

  call_entity_method(entity, "set_driver", nil)
  call_entity_method(entity, "set_passenger", nil)
  entity.destroy{raise_destroy = false}
  if driver then call_entity_method(replacement, "set_driver", driver) end
  if passenger then call_entity_method(replacement, "set_passenger", passenger) end

  if old_unit_number then storage.rideable_biters[old_unit_number] = nil end
  if replacement.unit_number then
    entry = entry or {
      next_wander_tick = next_wander_tick(tick or game.tick),
      unfunded_since_tick = nil,
    }
    entry.entity = replacement
    storage.rideable_biters[replacement.unit_number] = entry
    for player_index, unit_number in pairs(storage.rideable_biter_player_vehicle) do
      if unit_number == old_unit_number then
        storage.rideable_biter_player_vehicle[player_index] = replacement.unit_number
      end
    end
  end
  return replacement
end

function M.sync_visual_state(entity, tick)
  if not M.is_rideable(entity) then return entity end
  local target_name = is_occupied(entity) and MOUNTED_NAME or NAME
  return swap_visual_entity(entity, target_name, tick)
end

function M.on_player_driving_changed_state(event)
  if not event or not event.player_index then return end
  M.ensure_storage()
  if storage.rideable_biter_visual_swap_guard[event.player_index] then return end
  local player = game.get_player and game.get_player(event.player_index)
  local entity = event.entity
  if not M.is_rideable(entity) and player then entity = player.vehicle end
  if not M.is_rideable(entity) then
    local tracked_unit_number = storage.rideable_biter_player_vehicle[event.player_index]
    local tracked = tracked_unit_number and storage.rideable_biters[tracked_unit_number]
    entity = tracked and tracked.entity
  end
  if not M.is_rideable(entity) then return end

  storage.rideable_biter_visual_swap_guard[event.player_index] = true
  local ok, replacement = pcall(M.sync_visual_state, entity, event.tick or game.tick)
  storage.rideable_biter_visual_swap_guard[event.player_index] = nil
  if not ok then
    if log then log("Administratorio rideable-biter visual swap failed: " .. tostring(replacement)) end
    return
  end
  if player and player.vehicle and M.is_rideable(player.vehicle) then
    storage.rideable_biter_player_vehicle[event.player_index] = replacement.unit_number
  else
    storage.rideable_biter_player_vehicle[event.player_index] = nil
  end
end

get_fuel_inventory = function(entity)
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
  local entries = {}
  for unit_number, entry in pairs(storage.rideable_biters) do
    entries[#entries + 1] = {unit_number = unit_number, entry = entry}
  end
  for _, tracked in ipairs(entries) do
    local unit_number = tracked.unit_number
    local entry = tracked.entry
    local entity = entry.entity
    if not entity or not entity.valid then
      storage.rideable_biters[unit_number] = nil
    else
      entity = M.sync_visual_state(entity, tick)
      unit_number = entity.unit_number or unit_number
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
