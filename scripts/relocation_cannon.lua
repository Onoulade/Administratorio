-- Involuntary Relocation Cannon: batched planet-to-planet transfers of
-- biter-family cargo.
--
-- Framed as bureaucracy rather than artillery. No projectile, no turret, no
-- catapult: biters and managers are reassigned across the solar system because
-- HR filed a transfer order, and one order is consumed per item transferred.
--
-- Two buildings, one shared registry. The EMITTER holds cargo and fires; it
-- never files a request. The RECEIVER holds transfer orders and arrivals, and
-- files the request that makes an emitter fire. A planet that both sends and
-- receives builds one of each; unlike the Terminus, neither is limited to one
-- per planet.
--
-- The cannon differs from the interplanetary trunk in scope and shape. The
-- trunk carries paperwork, one item at a time, each with its own timer. The
-- cannon carries personnel, a batch per shot, and refuses everything else --
-- which is what keeps rockets relevant for all other cargo.
--
-- Planets only. Space platforms are out of scope; the Cobaye reaches orbit by
-- rocket at parity cost.
--
-- Both buildings broadcast their own inventory contents over a hidden
-- combinator wired to their own RED wire only. The receiver's requests are
-- read from GREEN only, so the two directions share one connector -- the
-- same one the player already wires to the real building -- without the
-- broadcast ever being misread as a request.

local C = require("scripts.constants")
local feature_flags = require("feature_flags")

local M = {}

-------------------------------------------------------------------------------
-- HELPERS
-------------------------------------------------------------------------------

function M.is_emitter(entity)
  return entity ~= nil and entity.valid and entity.name == C.RELOCATION_CANNON_NAME
end

function M.is_receiver(entity)
  return entity ~= nil and entity.valid and entity.name == C.RELOCATION_RECEIVER_NAME
end

function M.is_cannon(entity)
  return M.is_emitter(entity) or M.is_receiver(entity)
end

local function role_of(entity)
  if M.is_emitter(entity) then return "emitter" end
  if M.is_receiver(entity) then return "receiver" end
  return nil
end

local function set_status(entity, key, diode)
  local role = role_of(entity)
  if not role then return end
  entity.custom_status = {
    diode = diode,
    label = {"gui.relocation-" .. role .. "-" .. key},
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

--- The status combinator rides the building's own RED wire only -- see the
--- header comment and C.RELOCATION_STATUS_COMBINATOR_NAME.
local function connect_status_combinator(entity, combinator)
  if not entity or not entity.valid or not combinator or not combinator.valid then return end
  local ent_red = entity.get_wire_connector(defines.wire_connector_id.circuit_red, true)
  local comb_red = combinator.get_wire_connector(defines.wire_connector_id.circuit_red, true)
  if ent_red and comb_red then ent_red.connect_to(comb_red) end
end

local function create_status_combinator(entity)
  if not entity or not entity.valid then return nil end
  local combinator = entity.surface.create_entity{
    name = C.RELOCATION_STATUS_COMBINATOR_NAME,
    position = entity.position,
    force = entity.force,
  }
  if combinator then
    combinator.destructible = false
    connect_status_combinator(entity, combinator)
  end
  return combinator
end

local function find_status_combinator(entity)
  if not entity or not entity.valid then return nil end
  return entity.surface.find_entities_filtered{
    name = C.RELOCATION_STATUS_COMBINATOR_NAME,
    position = entity.position,
    radius = 0.5,
  }[1]
end

local function destroy_status_combinator(entity)
  local combinator = find_status_combinator(entity)
  if combinator then combinator.destroy() end
end

function M.on_entity_built(entity, player)
  local role = role_of(entity)
  if not role then return true end
  M.ensure_storage()

  local planet_name = get_planet_name(entity.surface)
  if not planet_name then
    if player and player.valid then
      player.create_local_flying_text{
        text = {"gui.relocation-" .. role .. "-rejected-not-a-planet"},
        position = entity.position,
      }
      if player.mine_entity(entity, true) then return false end
    end
    entity.surface.spill_item_stack{
      position = entity.position,
      stack = {name = entity.name, count = 1},
      enable_looted = true,
    }
    entity.destroy()
    return false
  end

  entity.active = false
  storage.relocation_cannons[entity.unit_number] = {
    entity = entity,
    role = role,
    planet = planet_name,
    force_index = entity.force.index,
    next_shot_tick = 0,
    combinator = create_status_combinator(entity),
  }
  set_status(entity, role == "emitter" and "empty" or "idle", defines.entity_status_diode.yellow)
  return true
end

function M.on_entity_removed(entity)
  if not M.is_cannon(entity) then return end
  M.ensure_storage()
  storage.relocation_cannons[entity.unit_number] = nil
  destroy_status_combinator(entity)
end

-------------------------------------------------------------------------------
-- REQUESTS
-------------------------------------------------------------------------------

--- A receiver asks for cargo the same way a Terminus does: a circuit signal
--- names what this planet wants pulled in. Only ever called for a receiver --
--- an emitter never files a request.
local function collect_requests(entity)
  local requests = {}
  if not entity or not entity.valid or not entity.get_circuit_network then
    return requests
  end

  -- GREEN only -- RED carries the status-combinator broadcast on this same
  -- connector; see the header comment.
  local ok, network = pcall(entity.get_circuit_network, defines.wire_connector_id.circuit_green)
  if ok and network and network.signals then
    for _, entry in ipairs(network.signals) do
      local signal = entry.signal
      -- The engine reports item-type signals with type == nil on read;
      -- "item" is only ever seen for non-item signal kinds we don't want.
      if signal and (signal.type == nil or signal.type == "item") and (entry.count or 0) > 0
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

  return requests
end

-------------------------------------------------------------------------------
-- STATUS COMBINATOR
-------------------------------------------------------------------------------

--- Broadcasts a building's own inventory contents: cargo for an emitter,
--- transfer-order count for a receiver.
local function update_status_combinator(entry)
  local combinator = entry.combinator
  if not combinator or not combinator.valid then return end

  local inventory = payload_inventory(entry.entity)
  local contents = inventory and inventory.get_contents() or {}

  local behavior = combinator.get_or_create_control_behavior()
  if not behavior then return end
  local section = behavior.get_section(1)
  if not section then section = behavior.add_section() end
  if not section then return end

  local slot_idx = 1
  for _, stack in ipairs(contents) do
    if stack.count > 0 then
      section.set_slot(slot_idx, {
        value = {type = "item", name = stack.name, quality = stack.quality},
        min = stack.count,
      })
      slot_idx = slot_idx + 1
    end
  end
  for i = slot_idx, section.filters_count do
    section.clear_slot(i)
  end
end

-------------------------------------------------------------------------------
-- FIRING
-------------------------------------------------------------------------------

--- One transfer order per item transferred, filed at the receiving end.
---
--- A furnace source inventory is a single slot: an emitter's slot holds cargo,
--- a receiver's slot holds transfer orders -- never both, and never the
--- other's kind, since each role only unlocks its own loadable recipes. The
--- receiving office files the order, which frees the sending emitter's slot
--- for more cargo and reads correctly anyway: HR at the destination is the
--- one requesting the transfer.
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
        and source_entry.role == "emitter"
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

local function update_emitter_status(entity)
  local inventory = payload_inventory(entity)
  local contents = inventory and inventory.get_contents() or {}
  if #contents > 0 then
    set_status(entity, "loaded", defines.entity_status_diode.green)
  else
    set_status(entity, "empty", defines.entity_status_diode.yellow)
  end
end

function M.on_tick(event)
  M.ensure_storage()
  local tick = event and event.tick or game.tick

  for unit_number, entry in pairs(storage.relocation_cannons) do
    local entity = entry.entity
    if not entity or not entity.valid then
      storage.relocation_cannons[unit_number] = nil
    else
      if entry.role == "receiver" then
        try_fire_to(entity, entry, tick)
      else
        update_emitter_status(entity)
      end
      update_status_combinator(entry)
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

  for _, role_info in ipairs({
    {name = C.RELOCATION_CANNON_NAME, role = "emitter"},
    {name = C.RELOCATION_RECEIVER_NAME, role = "receiver"},
  }) do
    -- Both roles are Space Age entities. find_entities_filtered errors on an
    -- unknown prototype name, so skip a role entirely without its prototype.
    if not feature_flags.entity_prototype_exists(role_info.name) then
      goto continue_role
    end

    for _, surface in pairs(game.surfaces) do
      local planet_name = get_planet_name(surface)
      if planet_name then
        for _, entity in ipairs(surface.find_entities_filtered{name = role_info.name}) do
          if entity.valid then
            entity.active = false
            local previous = previous_entries[entity.unit_number]
            local combinator = previous and previous.combinator
            if not combinator or not combinator.valid then
              combinator = find_status_combinator(entity)
              if combinator then
                connect_status_combinator(entity, combinator)
              else
                combinator = create_status_combinator(entity)
              end
            end
            storage.relocation_cannons[entity.unit_number] = {
              entity = entity,
              role = role_info.role,
              planet = planet_name,
              force_index = entity.force.index,
              -- A configuration rebuild must not turn into a free extra shot.
              next_shot_tick = previous and previous.next_shot_tick or 0,
              combinator = combinator,
            }
          end
        end
      end
    end
    ::continue_role::
  end
end

return M
