-- Involuntary Relocation Cannon: batched planet-to-planet transfers of
-- biter-family cargo.
--
-- Framed as bureaucracy rather than artillery. No projectile, no turret, no
-- catapult: biters and managers are reassigned across the solar system because
-- HR filed a transfer order, and one order is consumed per item transferred.
--
-- The cannon differs from the interplanetary trunk in scope and shape. The
-- trunk carries paperwork, one item at a time, each with its own timer. The
-- cannon carries personnel, a batch per shot, and refuses everything else --
-- which is what keeps rockets relevant for all other cargo.
--
-- Planets only. Space platforms are out of scope; the Cobaye reaches orbit by
-- rocket at parity cost.

local C = require("scripts.constants")

local M = {}

-------------------------------------------------------------------------------
-- HELPERS
-------------------------------------------------------------------------------

function M.is_cannon(entity)
  return entity ~= nil and entity.valid and entity.name == C.RELOCATION_CANNON_NAME
end

local function set_status(entity, key, diode)
  if not M.is_cannon(entity) then return end
  entity.custom_status = {
    diode = diode,
    label = {"gui.relocation-cannon-" .. key},
  }
end

local function payload_inventory(entity)
  return entity.get_inventory(defines.inventory.furnace_source)
end

local function arrival_inventory(entity)
  return entity.get_inventory(defines.inventory.furnace_result)
end

local function get_planet_name(surface)
  if not surface or not surface.valid then return nil end
  if surface.platform ~= nil then return nil end
  local planet = surface.planet
  if not planet or not planet.valid then return nil end
  if planet.surface and planet.surface ~= surface then return nil end
  return planet.name
end

-------------------------------------------------------------------------------
-- LIFECYCLE
-------------------------------------------------------------------------------

function M.ensure_storage()
  storage.relocation_cannons = storage.relocation_cannons or {}
end

function M.on_entity_built(entity, player)
  if not M.is_cannon(entity) then return true end
  M.ensure_storage()

  local planet_name = get_planet_name(entity.surface)
  if not planet_name then
    if player and player.valid then
      player.create_local_flying_text{
        text = {"gui.relocation-cannon-rejected-not-a-planet"},
        position = entity.position,
      }
      if player.mine_entity(entity, true) then return false end
    end
    entity.surface.spill_item_stack{
      position = entity.position,
      stack = {name = C.RELOCATION_CANNON_NAME, count = 1},
      enable_looted = true,
    }
    entity.destroy()
    return false
  end

  entity.active = false
  storage.relocation_cannons[entity.unit_number] = {
    entity = entity,
    planet = planet_name,
    force_index = entity.force.index,
    next_shot_tick = 0,
  }
  set_status(entity, "idle", defines.entity_status_diode.yellow)
  return true
end

function M.on_entity_removed(entity)
  if not M.is_cannon(entity) then return end
  M.ensure_storage()
  storage.relocation_cannons[entity.unit_number] = nil
end

-------------------------------------------------------------------------------
-- REQUESTS
-------------------------------------------------------------------------------

--- A cannon asks for cargo the same way a Terminus does: a circuit signal names
--- what this planet wants pulled in.
local function collect_requests(entity)
  local requests = {}
  if not entity or not entity.valid or not entity.get_circuit_network then
    return requests
  end

  for _, connector in ipairs({defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green}) do
    local ok, network = pcall(entity.get_circuit_network, connector)
    if ok and network and network.signals then
      for _, entry in ipairs(network.signals) do
        local signal = entry.signal
        if signal and signal.type == "item" and (entry.count or 0) > 0
            and C.RELOCATION_CARGO_SET[signal.name] then
          local key = signal.name .. "/" .. (signal.quality or "normal")
          if not requests[key] then
            requests[key] = {
              name = signal.name,
              quality = signal.quality or "normal",
              count = math.min(entry.count, C.RELOCATION_PAYLOAD_PER_SHOT),
            }
          end
        end
      end
    end
  end

  return requests
end

-------------------------------------------------------------------------------
-- FIRING
-------------------------------------------------------------------------------

--- One transfer order per item transferred, filed at the receiving end.
---
--- A furnace source inventory is a single slot, so a cannon cannot hold cargo
--- and paperwork at once. The receiving office files the order, which frees the
--- sending cannon's slot for cargo and reads correctly anyway: HR at the
--- destination is the one requesting the transfer. A planet that both sends and
--- receives simply builds two cannons; unlike the Terminus they are not limited
--- to one per planet.
local function has_transfer_orders(inventory, count)
  return inventory.get_item_count(C.RELOCATION_TRANSFER_FORM) >= count
end

local function return_unlanded_payload(source, inventory, request, count)
  if count <= 0 then return end
  local returned = inventory.insert{name = request.name, quality = request.quality, count = count}
  if returned >= count then return end

  -- The source slot was just freed by this transfer, so this is only a last
  -- ditch safety net for an unexpected inventory mutation. Preserve personnel
  -- on the ground rather than deleting them.
  if source.surface and source.surface.spill_item_stack then
    source.surface.spill_item_stack{
      position = source.position,
      stack = {name = request.name, quality = request.quality, count = count - returned},
      enable_looted = true,
    }
  end
end

local function try_fire_to(destination, entry, tick)
  local requests = collect_requests(destination)
  if not next(requests) then
    set_status(destination, "idle", defines.entity_status_diode.yellow)
    return false
  end

  local arrivals = arrival_inventory(destination)
  if not arrivals or arrivals.is_full() then
    set_status(destination, "arrivals-full", defines.entity_status_diode.red)
    return false
  end

  local orders = payload_inventory(destination)
  if not orders then return false end

  for _, source_entry in pairs(storage.relocation_cannons) do
    local source = source_entry.entity
    if source and source.valid
        and source_entry.force_index == entry.force_index
        and source_entry.planet ~= entry.planet
        and tick >= (source_entry.next_shot_tick or 0) then
      local payload = payload_inventory(source)
      if payload then
        for _, request in pairs(requests) do
          local available = payload.get_item_count({name = request.name, quality = request.quality})
          local batch = math.min(available, request.count, C.RELOCATION_PAYLOAD_PER_SHOT)
          if batch > 0 then
            if not has_transfer_orders(orders, batch) then
              set_status(destination, "no-transfer-orders", defines.entity_status_diode.red)
              return false
            end

            local removed = payload.remove{name = request.name, quality = request.quality, count = batch}
            if removed > 0 then
              local landed = arrivals.insert{name = request.name, quality = request.quality, count = removed}
              if landed < removed then
                return_unlanded_payload(source, payload, request, removed - landed)
              end
              if landed > 0 then
                -- Bill only items that actually arrived. The order inventory
                -- was preflighted above, so a single tick cannot underpay.
                orders.remove{name = C.RELOCATION_TRANSFER_FORM, count = landed}
                set_status(destination, "transferred", defines.entity_status_diode.green)
                -- The sender fires the shot. A destination must not be able to
                -- multiply one cannon's throughput by issuing more requests.
                source_entry.next_shot_tick = tick + C.RELOCATION_SHOT_TICKS
                return true
              end
            end
          end
        end
      end
    end
  end

  return false
end

function M.on_tick(event)
  M.ensure_storage()
  local tick = event and event.tick or game.tick

  for unit_number, entry in pairs(storage.relocation_cannons) do
    local entity = entry.entity
    if not entity or not entity.valid then
      storage.relocation_cannons[unit_number] = nil
    else
      try_fire_to(entity, entry, tick)
    end
  end
end

-------------------------------------------------------------------------------
-- REBUILD
-------------------------------------------------------------------------------

function M.rebuild_registry()
  M.ensure_storage()
  local previous_entries = storage.relocation_cannons
  storage.relocation_cannons = {}

  for _, surface in pairs(game.surfaces) do
    local planet_name = get_planet_name(surface)
    if planet_name then
      for _, entity in ipairs(surface.find_entities_filtered{name = C.RELOCATION_CANNON_NAME}) do
        if entity.valid then
          entity.active = false
          storage.relocation_cannons[entity.unit_number] = {
            entity = entity,
            planet = planet_name,
            force_index = entity.force.index,
            -- A configuration rebuild must not turn into a free extra shot.
            next_shot_tick = previous_entries[entity.unit_number]
              and previous_entries[entity.unit_number].next_shot_tick or 0,
          }
        end
      end
    end
  end
end

return M
