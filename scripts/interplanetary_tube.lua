-- Interplanetary tube trunk: a shared, force-wide pool between planet
-- Terminus buildings.
--
-- The trunk is a SEPARATE pool from the local pneumatic network in
-- scripts/pneumatic.lua.  The local pool is instant, per-surface, and scales to
-- 200 items.  This one is narrow (3 -> 20), slow (30 s -> 1 s per item), and
-- crosses planets.  The two must never be merged: a merged pool would be free
-- high-capacity teleportation and would delete rocket logistics entirely.
--
-- A Terminus is a furnace-style building.  Its source inventory is the outbound
-- buffer.  Loading it does not require a matching request: whatever is loaded
-- leaves the input slot on the current tier's timer and enters a shared,
-- force-wide pool.  From there, ANY Terminus on the same force -- including
-- the one that just contributed it -- may claim a matching item by naming it
-- on its own circuit condition.  A planet reclaiming its own paperwork is
-- just a withdrawal, not a shortcut: normally there is only one Terminus per
-- planet, and once C.TERMINUS_ADDITIONAL_TECH allows more, it is the same
-- planet moving paperwork between its own endpoints.  Arrivals are NOT
-- auto-fed anywhere: moving them into the local pneumatic pool, onto a belt,
-- or into a chest is the player's own explicit step.
--
-- A Terminus's single circuit connector carries both directions, split by
-- wire colour: GREEN is the request signal (read by M.collect_requests),
-- RED is the pool-content broadcast (written by a hidden combinator wired
-- only to the Terminus's red side). A furnace-type entity can't natively
-- emit computed signals the way a constant combinator can, and it also only
-- ever has one connector point -- there's no separate input/output pair the
-- way real combinators have -- so the hidden combinator does the writing
-- while the two colours keep the two directions from reading each other.

local C = require("scripts.constants")
local feature_flags = require("feature_flags")

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

-- Pool keys must keep quality as part of an item's identity. A control
-- character avoids collisions with valid prototype/quality names.
local POOL_KEY_SEPARATOR = "\31"

local function pool_key(item_name, quality_name)
  return item_name .. POOL_KEY_SEPARATOR .. (quality_name or "normal")
end

local function parse_pool_key(key)
  local separator_start = key:find(POOL_KEY_SEPARATOR, 1, true)
  if not separator_start then return key, "normal" end
  return key:sub(1, separator_start - 1), key:sub(separator_start + #POOL_KEY_SEPARATOR)
end

-------------------------------------------------------------------------------
-- TIER LOOKUP
-------------------------------------------------------------------------------

--- Capacity (max items pending + pooled) and per-item transit time for a force.
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

--- How many Terminuses a force may build on one planet. One by default;
--- C.TERMINUS_ADDITIONAL_TECH is an infinite technology that raises it by
--- one per researched level.
function M.max_terminus_per_planet(force)
  if not force or not force.valid or not force.technologies then
    return C.TERMINUS_BASE_PER_PLANET
  end
  local technology = force.technologies[C.TERMINUS_ADDITIONAL_TECH]
  if not technology or not technology.researched then
    return C.TERMINUS_BASE_PER_PLANET
  end
  return C.TERMINUS_BASE_PER_PLANET + technology.level
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
  -- Pre-pool phase only: an item sits here on its transit timer between being
  -- loaded and landing in the shared pool. No destination is bound here.
  storage.terminus_flights = storage.terminus_flights or {}
  -- storage.trunk_pool[force_index][pool_key] = count
  storage.trunk_pool = storage.trunk_pool or {}
  storage.trunk_pool_dirty = storage.trunk_pool_dirty or {}
end

--- The first registered Terminus on a planet, if any. One per planet by
--- default; M.max_terminus_per_planet raises the cap for a force that has
--- researched C.TERMINUS_ADDITIONAL_TECH.
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

--- How many Terminuses a force already has registered on a planet. Doubles
--- as a self-heal pass over stale entries, same as M.find_planet_terminus.
function M.count_planet_terminus(force_index, planet_name, except_unit_number)
  M.ensure_storage()
  local count = 0
  for unit_number, entry in pairs(storage.terminus_registry) do
    if unit_number ~= except_unit_number
        and entry.force_index == force_index
        and entry.planet == planet_name then
      local entity = entry.entity
      if entity and entity.valid then
        count = count + 1
      else
        storage.terminus_registry[unit_number] = nil
      end
    end
  end
  return count
end

--- The pool combinator rides the Terminus's own RED wire only. Requests are
--- read from GREEN only (see M.collect_requests), so the two never mix on the
--- same network -- a Terminus can never read its own pool broadcast back as
--- a self-request.
local function connect_pool_combinator(entity, combinator)
  if not entity or not entity.valid or not combinator or not combinator.valid then return end
  local ent_red = entity.get_wire_connector(defines.wire_connector_id.circuit_red, true)
  local comb_red = combinator.get_wire_connector(defines.wire_connector_id.circuit_red, true)
  if ent_red and comb_red then ent_red.connect_to(comb_red) end
end

local function create_pool_combinator(entity)
  if not entity or not entity.valid then return nil end
  local combinator = entity.surface.create_entity{
    name = C.TERMINUS_COMBINATOR_NAME,
    position = entity.position,
    force = entity.force,
  }
  if combinator then
    combinator.destructible = false
    connect_pool_combinator(entity, combinator)
  end
  return combinator
end

local function find_pool_combinator(entity)
  if not entity or not entity.valid then return nil end
  return entity.surface.find_entities_filtered{
    name = C.TERMINUS_COMBINATOR_NAME,
    position = entity.position,
    radius = 0.5,
  }[1]
end

local function destroy_pool_combinator(entity)
  local combinator = find_pool_combinator(entity)
  if combinator then combinator.destroy() end
end

function M.on_entity_built(entity, player)
  if not M.is_terminus(entity) then return true end
  M.ensure_storage()

  local planet_name = M.get_planet_name(entity.surface)
  if not planet_name then
    M.reject_placement(entity, player, {"gui.terminus-rejected-not-a-planet"})
    return false
  end

  local existing_count = M.count_planet_terminus(entity.force.index, planet_name, entity.unit_number)
  if existing_count >= M.max_terminus_per_planet(entity.force) then
    M.reject_placement(entity, player, {"gui.terminus-rejected-duplicate", planet_name})
    return false
  end

  deactivate(entity)
  storage.terminus_registry[entity.unit_number] = {
    entity = entity,
    planet = planet_name,
    force_index = entity.force.index,
    combinator = create_pool_combinator(entity),
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
  destroy_pool_combinator(entity)

  -- Only pre-pool cargo is entity-bound; refund it before the origin
  -- disappears. Pool contents are force-owned and untouched by any single
  -- Terminus's removal.
  local remaining = {}
  for _, flight in ipairs(storage.terminus_flights) do
    if flight.from_entity == entity then
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
  if anchor and anchor.valid then
    local inventory = arrival_inventory(anchor)
    if inventory and inventory.insert(stack) > 0 then return end
    anchor.surface.spill_item_stack{position = anchor.position, stack = stack, enable_looted = true}
  end
end

-------------------------------------------------------------------------------
-- REQUESTS
-------------------------------------------------------------------------------

--- Requested items are read from the Terminus's GREEN wire only. RED carries
--- the pool-content broadcast (see connect_pool_combinator); keeping requests
--- scoped to GREEN is what lets both share the Terminus's one connector
--- without the broadcast being misread as a request.
function M.collect_requests(entity)
  local requests = {}
  if not entity or not entity.valid or not entity.get_control_behavior then
    return requests
  end

  local ok, behavior = pcall(entity.get_control_behavior)
  if not ok or not behavior then return requests end

  local network_ok, network = pcall(entity.get_circuit_network, defines.wire_connector_id.circuit_green)
  if network_ok and network and network.signals then
    for _, entry in ipairs(network.signals) do
      local signal = entry.signal
      -- The engine reports item-type signals with type == nil on read;
      -- "item" is only ever seen for non-item signal kinds we don't want.
      if signal and (signal.type == nil or signal.type == "item") and (entry.count or 0) > 0
          and C.TRUNK_ITEM_SET[signal.name] then
        local key = signal.name .. "/" .. (signal.quality or "normal")
        if not requests[key] then
          requests[key] = {name = signal.name, quality = signal.quality or "normal", count = entry.count}
        end
      end
    end
  end

  return requests
end

-------------------------------------------------------------------------------
-- POOL
-------------------------------------------------------------------------------

local function pooled_count(force_index)
  local pool = storage.trunk_pool[force_index]
  if not pool then return 0 end
  local total = 0
  for _, count in pairs(pool) do
    total = total + count
  end
  return total
end

--- Capacity is charged across BOTH the pre-pool (timed) phase and the pooled
--- phase, per force -- the same "narrow trunk" throughput as before, just
--- measured across two stages instead of one flat flight list.
local function count_pending(force_index)
  local total = 0
  for _, flight in ipairs(storage.terminus_flights) do
    if flight.force_index == force_index then total = total + flight.count end
  end
  return total + pooled_count(force_index)
end

--- A planet may claim back what it just contributed itself. With one
--- Terminus per planet (before the additional-terminus tech is researched),
--- that's simply a withdrawal, not a shortcut around anything -- and once a
--- planet has more than one Terminus, it's the same planet moving its own
--- paperwork between its own endpoints, which is exactly what the trunk is
--- for. So the pool tracks nothing about where a count came from.
local function land_in_pool(flight)
  local force_pool = storage.trunk_pool[flight.force_index]
  if not force_pool then
    force_pool = {}
    storage.trunk_pool[flight.force_index] = force_pool
  end

  local key = pool_key(flight.item, flight.quality)
  force_pool[key] = (force_pool[key] or 0) + flight.count
  storage.trunk_pool_dirty[flight.force_index] = true
end

local function update_pool_combinator_signals(combinator, pool)
  if not combinator or not combinator.valid then return end
  local behavior = combinator.get_or_create_control_behavior()
  if not behavior then return end
  local section = behavior.get_section(1)
  if not section then section = behavior.add_section() end
  if not section then return end

  local slot_idx = 1
  if pool then
    for key, count in pairs(pool) do
      if count > 0 then
        local item_name, quality_name = parse_pool_key(key)
        section.set_slot(slot_idx, {
          value = {type = "item", name = item_name, quality = quality_name},
          min = count,
        })
        slot_idx = slot_idx + 1
      end
    end
  end
  for i = slot_idx, section.filters_count do
    section.clear_slot(i)
  end
end

--- Every Terminus for a force shows the same force-wide pool content --
--- there's one shared pool, and a wire tap at any endpoint should see it all.
function M.refresh_pool_combinators(force_index)
  local pool = storage.trunk_pool[force_index]
  for _, entry in pairs(storage.terminus_registry) do
    if entry.force_index == force_index and entry.combinator and entry.combinator.valid then
      update_pool_combinator_signals(entry.combinator, pool)
    end
  end
end

-------------------------------------------------------------------------------
-- LOAD / CLAIM
-------------------------------------------------------------------------------

--- Drains whatever is in the outbound slot into a new pre-pool flight,
--- unconditionally -- no matching request is required. This is what frees the
--- input slot for automation instead of jamming on an unwanted request.
local function try_load_outbound(source, entry, force, transit_ticks, tick)
  local outbound = outbound_inventory(source)
  if not outbound then return false end

  for _, stack in ipairs(outbound.get_contents()) do
    if M.can_force_carry(force, stack.name) then
      local removed = outbound.remove{name = stack.name, quality = stack.quality, count = 1}
      if removed == 1 then
        storage.terminus_flights[#storage.terminus_flights + 1] = {
          item = stack.name,
          quality = stack.quality or "normal",
          count = 1,
          force_index = entry.force_index,
          from_entity = source,
          arrive_tick = tick + transit_ticks,
        }
        return true
      end
    end
  end

  return false
end

--- Claim one matching item from the shared pool for this force. A planet may
--- claim back what it contributed itself -- see the note on land_in_pool.
--- Returns a status key describing why nothing happened, or
--- "claimed-from-pool" on success.
local function try_claim_from_pool(destination, entry, tick)
  local requests = M.collect_requests(destination)
  if not next(requests) then return "idle" end

  local arrivals = arrival_inventory(destination)
  if not arrivals or arrivals.is_full() then return "arrivals-full" end

  local pool = storage.trunk_pool[entry.force_index]
  if not pool then return "no-match-in-pool" end

  for _, request in pairs(requests) do
    local key = pool_key(request.name, request.quality)
    local count = pool[key]
    if count and count > 0 then
      local landed = arrivals.insert{name = request.name, quality = request.quality, count = 1}
      if landed > 0 then
        count = count - landed
        if count <= 0 then pool[key] = nil else pool[key] = count end
        storage.trunk_pool_dirty[entry.force_index] = true
        return "claimed-from-pool"
      end
    end
  end

  return "no-match-in-pool"
end

local function resolve_status(claim_status, trunk_full, loaded)
  if claim_status == "arrivals-full" then return "arrivals-full", defines.entity_status_diode.red end
  if claim_status == "claimed-from-pool" then return "claimed-from-pool", defines.entity_status_diode.green end
  if trunk_full then return "trunk-full", defines.entity_status_diode.yellow end
  if loaded then return "in-transit", defines.entity_status_diode.green end
  if claim_status == "no-match-in-pool" then return "no-match-in-pool", defines.entity_status_diode.yellow end
  return "idle", defines.entity_status_diode.yellow
end

-------------------------------------------------------------------------------
-- TICK
-------------------------------------------------------------------------------

function M.on_tick(event)
  M.ensure_storage()
  local tick = event and event.tick or game.tick

  -- Phase 1: resolve every pre-pool flight whose timer has elapsed into the
  -- shared pool.
  local still_flying = {}
  for _, flight in ipairs(storage.terminus_flights) do
    if tick >= flight.arrive_tick then
      land_in_pool(flight)
    else
      still_flying[#still_flying + 1] = flight
    end
  end
  storage.terminus_flights = still_flying

  -- Phase 2 + 3: each registered Terminus may both load new cargo into the
  -- pre-pool phase and claim a matching item from the pool, in the same tick.
  for unit_number, entry in pairs(storage.terminus_registry) do
    local building = entry.entity
    if not building or not building.valid then
      storage.terminus_registry[unit_number] = nil
    else
      local force = building.force
      local capacity, transit_ticks = M.get_tier(force)
      local trunk_full = count_pending(entry.force_index) >= capacity
      local loaded = (not trunk_full) and try_load_outbound(building, entry, force, transit_ticks, tick)
      local claim_status = try_claim_from_pool(building, entry, tick)
      local status_key, diode = resolve_status(claim_status, trunk_full, loaded)
      set_status(building, status_key, diode)
    end
  end

  -- Phase 4: refresh pool-content combinators for every force whose pool
  -- changed this tick.
  for force_index in pairs(storage.trunk_pool_dirty) do
    M.refresh_pool_combinators(force_index)
    storage.trunk_pool_dirty[force_index] = nil
  end
end

-------------------------------------------------------------------------------
-- REBUILD
-------------------------------------------------------------------------------

function M.rebuild_registry()
  M.ensure_storage()
  storage.terminus_registry = {}

  -- The tube terminus is a Space Age entity. find_entities_filtered errors
  -- on an unknown prototype name, so skip entirely without it.
  if not feature_flags.entity_prototype_exists(C.TERMINUS_NAME) then
    return
  end

  for _, surface in pairs(game.surfaces) do
    local planet_name = M.get_planet_name(surface)
    if planet_name then
      for _, entity in ipairs(surface.find_entities_filtered{name = C.TERMINUS_NAME}) do
        local existing_count = entity.valid
          and M.count_planet_terminus(entity.force.index, planet_name, entity.unit_number) or 0
        if entity.valid and existing_count < M.max_terminus_per_planet(entity.force) then
          deactivate(entity)
          local combinator = find_pool_combinator(entity)
          if combinator then
            connect_pool_combinator(entity, combinator)
          else
            combinator = create_pool_combinator(entity)
          end
          storage.terminus_registry[entity.unit_number] = {
            entity = entity,
            planet = planet_name,
            force_index = entity.force.index,
            combinator = combinator,
          }
        end
      end
    end
  end

  -- Drop or refund pre-pool flights whose origin did not survive the rebuild.
  -- The pool itself is per-force, not per-entity, so it survives untouched.
  local remaining = {}
  for _, flight in ipairs(storage.terminus_flights) do
    local origin = flight.from_entity
    if origin and origin.valid and storage.terminus_registry[origin.unit_number] then
      remaining[#remaining + 1] = flight
    else
      M.refund_flight(flight, nil, origin)
    end
  end
  storage.terminus_flights = remaining
end

return M
