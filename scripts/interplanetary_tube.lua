-- Interplanetary tube trunk: per-item timed transfers between planet Terminus
-- buildings.
--
-- The trunk is a SEPARATE pool from the local pneumatic network in
-- scripts/pneumatic.lua.  The local pool is instant, per-surface, and scales to
-- 200 items.  This one is narrow (3 -> 20), slow (30 s -> 1 s per item), and
-- crosses planets.  The two must never be merged: a merged pool would be free
-- high-capacity teleportation and would delete rocket logistics entirely.
--
-- A Terminus is a furnace-style building.  Its source inventory is the outbound
-- buffer; inserters validate against the interplanetary-dispatch recipe family,
-- so the engine enforces the payload whitelist for free.  Its result inventory
-- is the arrivals buffer.  Arrivals are NOT auto-fed anywhere: moving them into
-- the local pneumatic pool, onto a belt, or into a chest is the player's own
-- explicit step.  That hand-off is what keeps the two pools legibly separate.

local C = require("scripts.constants")

local M = {}

-------------------------------------------------------------------------------
-- HELPERS
-------------------------------------------------------------------------------

function M.is_terminus(entity)
  return entity ~= nil and entity.valid and entity.name == C.TERMINUS_NAME
end

--- Planet name for a surface, or nil for space platforms and non-planet surfaces.
--- The trunk links planets only; orbit is reached by rocket at parity cost.
function M.get_planet_name(surface)
  if not surface or not surface.valid then return nil end
  if surface.platform ~= nil then return nil end

  local planet = surface.planet
  if not planet or not planet.valid then return nil end
  if planet.surface and planet.surface ~= surface then return nil end

  return planet.name
end

local function set_status(entity, key, diode)
  if not M.is_terminus(entity) then return end
  entity.custom_status = {
    diode = diode,
    label = {"gui.terminus-" .. key},
  }
end

local function deactivate(entity)
  if M.is_terminus(entity) then
    entity.active = false
  end
end

local function outbound_inventory(entity)
  return entity.get_inventory(defines.inventory.furnace_source)
end

local function arrival_inventory(entity)
  return entity.get_inventory(defines.inventory.furnace_result)
end

-------------------------------------------------------------------------------
-- TIER LOOKUP
-------------------------------------------------------------------------------

--- Capacity (max items in flight) and per-item transit time for a force.
--- Both ladders are read together: a tier raises capacity and cuts transit.
function M.get_tier(force)
  local capacity = C.TRUNK_BASE_CAPACITY
  local transit_ticks = C.TRUNK_BASE_TRANSIT_TICKS
  if not force or not force.valid or not force.technologies then
    return capacity, transit_ticks
  end

  for _, tier in ipairs(C.TRUNK_TIERS) do
    local technology = force.technologies[tier.technology]
    if technology and technology.researched then
      capacity = tier.capacity
      transit_ticks = tier.transit_ticks
    end
  end

  return capacity, transit_ticks
end

function M.chromatic_unlocked(force)
  if not force or not force.valid or not force.technologies then return false end
  local technology = force.technologies[C.TRUNK_CHROMATIC_TECH]
  return technology ~= nil and technology.researched
end

--- The base tier carries regular forms only; colored paperwork waits for Aquilo.
function M.can_force_carry(force, item_name)
  if not C.TRUNK_ITEM_SET[item_name] then return false end
  if not C.TRUNK_CHROMATIC_SET[item_name] then return true end
  return M.chromatic_unlocked(force)
end

-------------------------------------------------------------------------------
-- REGISTRY
-------------------------------------------------------------------------------

function M.ensure_storage()
  storage.terminus_registry = storage.terminus_registry or {}
  storage.terminus_flights = storage.terminus_flights or {}
end

--- One Terminus per planet. A single endpoint per world is what keeps the
--- trunk a trunk rather than a mesh, and it gives the arrivals buffer one
--- obvious home.
function M.find_planet_terminus(force_index, planet_name, except_unit_number)
  M.ensure_storage()
  for unit_number, entry in pairs(storage.terminus_registry) do
    if unit_number ~= except_unit_number
        and entry.force_index == force_index
        and entry.planet == planet_name then
      local entity = entry.entity
      if entity and entity.valid then
        return entity, unit_number
      end
      storage.terminus_registry[unit_number] = nil
    end
  end
  return nil
end

function M.on_entity_built(entity, player)
  if not M.is_terminus(entity) then return true end
  M.ensure_storage()

  local planet_name = M.get_planet_name(entity.surface)
  if not planet_name then
    M.reject_placement(entity, player, {"gui.terminus-rejected-not-a-planet"})
    return false
  end

  local existing = M.find_planet_terminus(entity.force.index, planet_name, entity.unit_number)
  if existing then
    M.reject_placement(entity, player, {"gui.terminus-rejected-duplicate", planet_name})
    return false
  end

  deactivate(entity)
  storage.terminus_registry[entity.unit_number] = {
    entity = entity,
    planet = planet_name,
    force_index = entity.force.index,
  }
  set_status(entity, "idle", defines.entity_status_diode.yellow)
  return true
end

--- Return the building to the player rather than destroying their materials.
function M.reject_placement(entity, player, message)
  if player and player.valid then
    player.create_local_flying_text{text = message, position = entity.position}
    if player.mine_entity(entity, true) then return end
  end
  entity.surface.spill_item_stack{
    position = entity.position,
    stack = {name = C.TERMINUS_NAME, count = 1},
    enable_looted = true,
  }
  entity.destroy()
end

function M.on_entity_removed(entity, buffer)
  if not M.is_terminus(entity) then return end
  M.ensure_storage()

  local unit_number = entity.unit_number
  storage.terminus_registry[unit_number] = nil

  -- Items still in flight toward a removed Terminus would otherwise vanish.
  -- Hand them back at the departure end so the player keeps the paperwork.
  local remaining = {}
  for _, flight in ipairs(storage.terminus_flights) do
    if flight.to_unit == unit_number then
      M.refund_flight(flight, buffer, entity)
    else
      remaining[#remaining + 1] = flight
    end
  end
  storage.terminus_flights = remaining
end

function M.refund_flight(flight, buffer, anchor)
  local stack = {name = flight.item, quality = flight.quality, count = flight.count}
  if buffer then
    buffer.insert(stack)
    return
  end
  local source = flight.from_entity
  if source and source.valid then
    local inventory = arrival_inventory(source)
    if inventory and inventory.insert(stack) > 0 then return end
  end
  if anchor and anchor.valid then
    anchor.surface.spill_item_stack{position = anchor.position, stack = stack, enable_looted = true}
  end
end

-------------------------------------------------------------------------------
-- REQUESTS
-------------------------------------------------------------------------------

--- Requested items are read from the Terminus's circuit condition. A request
--- names what this planet wants pulled from any other planet's outbound buffer.
function M.collect_requests(entity)
  local requests = {}
  if not entity or not entity.valid or not entity.get_control_behavior then
    return requests
  end

  local ok, behavior = pcall(entity.get_control_behavior)
  if not ok or not behavior then return requests end

  for _, connector in ipairs({defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green}) do
    local network_ok, network = pcall(entity.get_circuit_network, connector)
    if network_ok and network and network.signals then
      for _, entry in ipairs(network.signals) do
        local signal = entry.signal
        if signal and signal.type == "item" and (entry.count or 0) > 0
            and C.TRUNK_ITEM_SET[signal.name] then
          local key = signal.name .. "/" .. (signal.quality or "normal")
          if not requests[key] then
            requests[key] = {name = signal.name, quality = signal.quality or "normal", count = entry.count}
          end
        end
      end
    end
  end

  return requests
end

-------------------------------------------------------------------------------
-- DISPATCH
-------------------------------------------------------------------------------

local function count_in_flight(force_index)
  local total = 0
  for _, flight in ipairs(storage.terminus_flights) do
    if flight.force_index == force_index then
      total = total + flight.count
    end
  end
  return total
end

--- Pull one requested item from any other planet's outbound buffer.
local function try_dispatch_to(destination, entry, force, transit_ticks, tick)
  local requests = M.collect_requests(destination)
  if not next(requests) then return false end

  local arrivals = arrival_inventory(destination)
  if not arrivals or arrivals.is_full() then return false end

  for _, source_entry in pairs(storage.terminus_registry) do
    local source = source_entry.entity
    if source and source.valid
        and source_entry.force_index == entry.force_index
        and source_entry.planet ~= entry.planet then
      local outbound = outbound_inventory(source)
      if outbound then
        for _, request in pairs(requests) do
          if M.can_force_carry(force, request.name) then
            local removed = outbound.remove{
              name = request.name,
              quality = request.quality,
              count = 1,
            }
            if removed == 1 then
              storage.terminus_flights[#storage.terminus_flights + 1] = {
                item = request.name,
                quality = request.quality,
                count = 1,
                force_index = entry.force_index,
                from_entity = source,
                to_unit = destination.unit_number,
                arrive_tick = tick + transit_ticks,
              }
              return true
            end
          end
        end
      end
    end
  end

  return false
end

-------------------------------------------------------------------------------
-- TICK
-------------------------------------------------------------------------------

function M.on_tick(event)
  M.ensure_storage()
  local tick = event and event.tick or game.tick

  -- Land everything whose per-item timer has elapsed.
  local still_flying = {}
  for _, flight in ipairs(storage.terminus_flights) do
    if tick >= flight.arrive_tick then
      local entry = storage.terminus_registry[flight.to_unit]
      local destination = entry and entry.entity
      if destination and destination.valid then
        local arrivals = arrival_inventory(destination)
        local stack = {name = flight.item, quality = flight.quality, count = flight.count}
        if arrivals and arrivals.insert(stack) > 0 then
          set_status(destination, "delivered", defines.entity_status_diode.green)
        else
          -- A full arrivals buffer holds the item in flight rather than voiding
          -- it. The trunk stalls, which is the visible back-pressure the
          -- explicit hand-off is meant to produce.
          still_flying[#still_flying + 1] = flight
          set_status(destination, "arrivals-full", defines.entity_status_diode.red)
        end
      else
        M.refund_flight(flight, nil, nil)
      end
    else
      still_flying[#still_flying + 1] = flight
    end
  end
  storage.terminus_flights = still_flying

  -- Dispatch toward every Terminus that is asking for something.
  for unit_number, entry in pairs(storage.terminus_registry) do
    local destination = entry.entity
    if not destination or not destination.valid then
      storage.terminus_registry[unit_number] = nil
    else
      local force = destination.force
      local capacity, transit_ticks = M.get_tier(force)
      if count_in_flight(entry.force_index) >= capacity then
        set_status(destination, "trunk-full", defines.entity_status_diode.yellow)
      elseif try_dispatch_to(destination, entry, force, transit_ticks, tick) then
        set_status(destination, "in-transit", defines.entity_status_diode.green)
      end
    end
  end
end

-------------------------------------------------------------------------------
-- REBUILD
-------------------------------------------------------------------------------

function M.rebuild_registry()
  M.ensure_storage()
  storage.terminus_registry = {}

  for _, surface in pairs(game.surfaces) do
    local planet_name = M.get_planet_name(surface)
    if planet_name then
      for _, entity in ipairs(surface.find_entities_filtered{name = C.TERMINUS_NAME}) do
        if entity.valid and not M.find_planet_terminus(entity.force.index, planet_name, entity.unit_number) then
          deactivate(entity)
          storage.terminus_registry[entity.unit_number] = {
            entity = entity,
            planet = planet_name,
            force_index = entity.force.index,
          }
        end
      end
    end
  end

  -- Drop flights whose destination did not survive the rebuild.
  local remaining = {}
  for _, flight in ipairs(storage.terminus_flights) do
    if storage.terminus_registry[flight.to_unit] then
      remaining[#remaining + 1] = flight
    else
      M.refund_flight(flight, nil, nil)
    end
  end
  storage.terminus_flights = remaining
end

return M
