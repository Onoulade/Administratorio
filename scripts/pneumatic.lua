-- Pneumatic tube transport: signal-chain logic
--
-- Items enter at tube-intake (furnace-style intake), are voided by this script,
-- and counted in a per-network signal table.  Items reappear at tube-outtake
-- (container) when this script inserts them from the signal pool.
--
-- Visible pneumatic pipes define the network topology.  A hidden
-- pneumatic-hidden-network-pipe at each intake/outtake position links them
-- into the pipe graph for BFS-based network detection.

local C = require("scripts.constants")
local M = {}

-------------------------------------------------------------------------------
-- HELPERS
-------------------------------------------------------------------------------

local function is_tube_entity(entity)
  return entity and C.PNEUMATIC_BUILDINGS[entity.name] ~= nil
end

-- Build a fast lookup set from the PNEUMATIC_ITEMS list (once).
local PNEUMATIC_SET = {}
for _, name in ipairs(C.PNEUMATIC_ITEMS) do
  PNEUMATIC_SET[name] = true
end

local function get_intake_inventory(entity)
  local source_inventory = defines.inventory.furnace_source
  if source_inventory then
    local inv = entity.get_inventory(source_inventory)
    if inv then return inv end
  end
  return entity.get_inventory(defines.inventory.chest)
end

local function deactivate_intake_machine(entity)
  if entity and entity.valid and entity.name == "tube-intake" then
    entity.active = false
  end
end

local function enable_tube_rotation(entity)
  if not entity or not entity.valid then return end
  pcall(function()
    entity.rotatable = true
  end)
end

local MAX_NETWORK_RADIUS = C.TUBE_MAX_NETWORK_RADIUS or 120 -- tiles from the starting pipe

--- BFS through fluidbox connections starting from a hidden network pipe.
--- Returns network_id, over_extended.
--- network_id: smallest unit_number in the connected component.
--- over_extended: true if any connected pipe exceeds MAX_NETWORK_RADIUS.
local function bfs_network_id(network_pipe)
  if not network_pipe or not network_pipe.valid then return nil, false end
  local origin = network_pipe.position
  local id = network_pipe.unit_number
  local visited = {[network_pipe.unit_number] = true}
  local queue = {network_pipe}
  local head = 1
  local over_extended = false
  while head <= #queue do
    local current = queue[head]
    head = head + 1
    local fb = current.fluidbox
    if fb then
      for i = 1, #fb do
        local connections = fb.get_connections(i)
        if connections then
          for _, connected_fb in ipairs(connections) do
            local owner = connected_fb.owner
            if owner and owner.valid and not visited[owner.unit_number] then
              visited[owner.unit_number] = true
              if owner.unit_number < id then id = owner.unit_number end
              local pos = owner.position
              local dx = pos.x - origin.x
              local dy = pos.y - origin.y
              if dx * dx + dy * dy > MAX_NETWORK_RADIUS * MAX_NETWORK_RADIUS then
                over_extended = true
              end
              table.insert(queue, owner)
            end
          end
        end
      end
    end
  end
  return id, over_extended
end

-------------------------------------------------------------------------------
-- CAPACITY HELPERS
-------------------------------------------------------------------------------

--- Return the max tube network capacity for a given force, using cached value.
function M.get_network_capacity(force)
  if not force or not force.valid then return C.TUBE_BASE_CAPACITY end
  local cache = storage.tube_capacity_cache or {}
  local fid = force.index
  if cache[fid] then return cache[fid] end

  local cap = C.TUBE_BASE_CAPACITY
  for tech_name, bonus in pairs(C.TUBE_CAPACITY_TECHS) do
    local tech = force.technologies[tech_name]
    if tech and tech.researched then
      cap = cap + bonus
    end
  end
  cache[fid] = cap
  storage.tube_capacity_cache = cache
  return cap
end

--- Invalidate the cached capacity (call on research_finished).
function M.invalidate_capacity_cache()
  storage.tube_capacity_cache = nil
end

function M.sync_intake_recipe_unlocks(force)
  if not force or force.valid == false then return end
  local technology = force.technologies and force.technologies["pneumatic-form-transport"]
  if not technology or not technology.researched then return end

  for _, item_name in ipairs(C.PNEUMATIC_ITEMS) do
    local recipe = force.recipes and force.recipes["pneumatic-intake-" .. item_name]
    if recipe then
      recipe.enabled = true
    end
  end
end

function M.sync_all_intake_recipe_unlocks()
  if not game or not game.forces then return end
  for _, force in pairs(game.forces) do
    M.sync_intake_recipe_unlocks(force)
  end
end

--- Sum all items in a network signal pool.
function M.get_network_total(net_id)
  local pool = storage.tube_signals[net_id]
  if not pool then return 0 end
  local total = 0
  for _, count in pairs(pool) do
    total = total + count
  end
  return total
end

function M.get_network_item_count(net_id, item_name)
  local pool = storage.tube_signals[net_id]
  if not pool then return 0 end
  return pool[item_name] or 0
end

local function intake_circuit_allows(entity)
  if not entity or not entity.valid or not entity.get_control_behavior then return true end

  -- Factorio evaluates the visible circuit condition; this script just honors it.
  local ok, disabled = pcall(function()
    return entity.disabled_by_control_behavior
  end)
  if ok and disabled == true then return false end

  ok, disabled = pcall(function()
    local behavior = entity.get_control_behavior()
    return behavior and behavior.disabled
  end)
  if ok and disabled == true then return false end

  return true
end

-------------------------------------------------------------------------------
-- COMBINATOR HELPERS
-------------------------------------------------------------------------------

local function connect_tube_combinator(entity, combinator)
  if not entity or not entity.valid or not combinator or not combinator.valid then return end
  local ent_red = entity.get_wire_connector(defines.wire_connector_id.circuit_red, true)
  local ent_green = entity.get_wire_connector(defines.wire_connector_id.circuit_green, true)
  local comb_red = combinator.get_wire_connector(defines.wire_connector_id.circuit_red, true)
  local comb_green = combinator.get_wire_connector(defines.wire_connector_id.circuit_green, true)
  if ent_red and comb_red then ent_red.connect_to(comb_red) end
  if ent_green and comb_green then ent_green.connect_to(comb_green) end
end

local function create_tube_combinator(entity)
  if not entity or not entity.valid then return nil end
  local combinator = entity.surface.create_entity{
    name = "tube-network-combinator",
    position = entity.position,
    force = entity.force,
  }
  if combinator then
    combinator.destructible = false
    connect_tube_combinator(entity, combinator)
  end
  return combinator
end

local function update_combinator_signals(combinator, pool)
  if not combinator or not combinator.valid then return end
  local behavior = combinator.get_or_create_control_behavior()
  if not behavior then return end
  local section = behavior.get_section(1)
  if not section then section = behavior.add_section() end
  if not section then return end

  -- Clear existing slots and set new ones from pool.
  local slot_idx = 1
  if pool then
    for item_name, count in pairs(pool) do
      if count > 0 then
        section.set_slot(slot_idx, {value = item_name, min = count})
        slot_idx = slot_idx + 1
      end
    end
  end
  -- Clear remaining slots.
  for i = slot_idx, section.filters_count do
    section.clear_slot(i)
  end
end

-------------------------------------------------------------------------------
-- ENTITY LIFECYCLE
-------------------------------------------------------------------------------

function M.is_pneumatic_building(entity)
  return is_tube_entity(entity)
end

function M.add_pneumatic_inserter(entity)
  if not is_tube_entity(entity) then return end
  enable_tube_rotation(entity)
  deactivate_intake_machine(entity)

  -- Create the hidden inserter (only for entities that need one).
  local inserter_name = C.PNEUMATIC_BUILDINGS[entity.name]
  local inserter = nil
  if inserter_name then
    inserter = entity.surface.create_entity{
      name = inserter_name,
      type = "inserter",
      position = entity.position,
      direction = entity.direction,
      force = entity.force,
    }
    if inserter then
      inserter.destructible = false
      inserter.inserter_stack_size_override = 1
    end
  end

  -- Create the hidden network pipe for topology detection.
  local network_pipe = entity.surface.create_entity{
    name = "pneumatic-hidden-network-pipe",
    position = entity.position,
    force = entity.force,
  }
  if network_pipe then
    network_pipe.destructible = false
  end

  -- Create the hidden combinator for circuit signals.
  local combinator = create_tube_combinator(entity)

  -- Track in storage.
  M.ensure_storage()
  if entity.name == "tube-intake" then
    storage.tube_intakes[entity.unit_number] = {
      entity = entity,
      inserter = inserter,
      network_pipe = network_pipe,
      combinator = combinator,
    }
  elseif entity.name == "tube-outtake" then
    storage.tube_outtakes[entity.unit_number] = {
      entity = entity,
      network_pipe = network_pipe,
      combinator = combinator,
    }
  end
  storage.tube_network_dirty = true
end

function M.update_pneumatic_inserter_direction(entity)
  local inserters = entity.surface.find_entities_filtered{
    type = "inserter",
    name = "pneumatic-hidden-intake",
    position = entity.position,
    radius = 0.5
  }
  for _, ins in ipairs(inserters) do
    ins.direction = entity.direction
  end
end

function M.delete_pneumatic_inserters(entity, buffer)
  -- Remove hidden inserters.
  local inserters = entity.surface.find_entities_filtered{
    type = "inserter",
    name = "pneumatic-hidden-intake",
    position = entity.position,
    radius = 0.5
  }
  for _, ins in ipairs(inserters) do
    if buffer and ins.held_stack and ins.held_stack.valid_for_read then
      buffer.insert(ins.held_stack)
    end
    ins.destroy()
  end

  -- Remove hidden network pipes.
  local pipes = entity.surface.find_entities_filtered{
    name = "pneumatic-hidden-network-pipe",
    position = entity.position,
    radius = 0.5
  }
  for _, p in ipairs(pipes) do
    p.destroy()
  end

  -- Remove hidden combinators.
  local combinators = entity.surface.find_entities_filtered{
    name = "tube-network-combinator",
    position = entity.position,
    radius = 0.5
  }
  for _, c in ipairs(combinators) do
    c.destroy()
  end

  -- Untrack from storage.
  M.ensure_storage()
  if entity.name == "tube-intake" then
    storage.tube_intakes[entity.unit_number] = nil
  elseif entity.name == "tube-outtake" then
    storage.tube_outtakes[entity.unit_number] = nil
  end
  storage.tube_network_dirty = true
end

-------------------------------------------------------------------------------
-- NETWORK DETECTION
-------------------------------------------------------------------------------

--- Rebuild the network_id cache for all tracked intakes and outtakes.
function M.rebuild_network_cache()
  M.ensure_storage()
  storage.tube_network_cache = {}
  storage.tube_network_disabled = {} -- [network_id] = true if over-extended

  -- Also clean up stale entries and rebuild network_pipe references.
  for uid, entry in pairs(storage.tube_intakes) do
    if not entry.entity or not entry.entity.valid then
      storage.tube_intakes[uid] = nil
    else
      if not entry.network_pipe or not entry.network_pipe.valid then
        local pipes = entry.entity.surface.find_entities_filtered{
          name = "pneumatic-hidden-network-pipe",
          position = entry.entity.position,
          radius = 0.5,
        }
        entry.network_pipe = pipes[1]
      end
      if entry.network_pipe and entry.network_pipe.valid then
        local net_id, over = bfs_network_id(entry.network_pipe)
        storage.tube_network_cache[uid] = net_id
        if over and net_id then storage.tube_network_disabled[net_id] = true end
      end
      -- Deactivate/activate the hidden intake inserter based on network state.
      if entry.inserter and entry.inserter.valid then
        local net_id = storage.tube_network_cache[uid]
        entry.inserter.active = net_id ~= nil and not storage.tube_network_disabled[net_id]
      end
    end
  end

  for uid, entry in pairs(storage.tube_outtakes) do
    if not entry.entity or not entry.entity.valid then
      storage.tube_outtakes[uid] = nil
    else
      if not entry.network_pipe or not entry.network_pipe.valid then
        local pipes = entry.entity.surface.find_entities_filtered{
          name = "pneumatic-hidden-network-pipe",
          position = entry.entity.position,
          radius = 0.5,
        }
        entry.network_pipe = pipes[1]
      end
      if entry.network_pipe and entry.network_pipe.valid then
        local net_id, over = bfs_network_id(entry.network_pipe)
        storage.tube_network_cache[uid] = net_id
        if over and net_id then storage.tube_network_disabled[net_id] = true end
      end
    end
  end

  -- Prune orphaned signal pools (networks with no intakes or outtakes).
  local active_nets = {}
  for _, net_id in pairs(storage.tube_network_cache) do
    active_nets[net_id] = true
  end
  for net_id in pairs(storage.tube_signals) do
    if not active_nets[net_id] then
      storage.tube_signals[net_id] = nil
    end
  end

  storage.tube_network_dirty = false
end

-------------------------------------------------------------------------------
-- TICK HANDLER
-------------------------------------------------------------------------------

function M.on_pneumatic_tick()
  M.ensure_storage()

  if storage.tube_network_dirty then
    M.rebuild_network_cache()
  end

  local networks_changed = {} -- [net_id] = true when pool was modified

  -- Process intakes: remove 1 item from source slot, add to signal pool.
  for uid, entry in pairs(storage.tube_intakes) do
    local entity = entry.entity
    if not entity or not entity.valid then
      storage.tube_intakes[uid] = nil
      storage.tube_network_dirty = true
      goto next_intake
    end

    local net_id = storage.tube_network_cache[uid]
    if not net_id then goto next_intake end
    if storage.tube_network_disabled[net_id] then goto next_intake end
    if not intake_circuit_allows(entity) then goto next_intake end

    local inv = get_intake_inventory(entity)
    if inv and not inv.is_empty() then
      local stack = inv[1]
      if stack and stack.valid_for_read then
        local item_name = stack.name

        if not PNEUMATIC_SET[item_name] then
          goto next_intake
        end

        -- Check per-item capacity before consuming. Different forms no longer
        -- compete for the same slots and cannot starve each other out.
        local capacity = M.get_network_capacity(entity.force)
        local item_count = M.get_network_item_count(net_id, item_name)
        if item_count >= capacity then
          goto next_intake
        end

        -- Remove exactly 1 item.
        inv.remove{name = item_name, count = 1}

        local pool = storage.tube_signals[net_id]
        if not pool then
          pool = {}
          storage.tube_signals[net_id] = pool
        end
        pool[item_name] = (pool[item_name] or 0) + 1
        networks_changed[net_id] = true
      end
    end

    ::next_intake::
  end

  -- Process outtakes: if container empty and signals available, insert item.
  for uid, entry in pairs(storage.tube_outtakes) do
    local entity = entry.entity
    if not entity or not entity.valid then
      storage.tube_outtakes[uid] = nil
      storage.tube_network_dirty = true
      goto next_outtake
    end

    local net_id = storage.tube_network_cache[uid]
    if not net_id then goto next_outtake end
    if storage.tube_network_disabled[net_id] then goto next_outtake end

    local inv = entity.get_inventory(defines.inventory.chest)
    if not inv or not inv.is_empty() then goto next_outtake end

    local pool = storage.tube_signals[net_id]
    if not pool then goto next_outtake end

    -- Check if the player set a filter on slot 1.
    local slot_filter = inv.get_filter(1)
    local allowed_name = slot_filter and slot_filter.name or nil

    -- Pick item: if filtered, only that item; otherwise largest-count-first.
    local best_name, best_count = nil, 0
    if allowed_name then
      local count = pool[allowed_name]
      if count and count > 0 then
        best_name = allowed_name
        best_count = count
      end
    else
      for item_name, count in pairs(pool) do
        if count > best_count then
          best_name = item_name
          best_count = count
        end
      end
    end

    if best_name and best_count > 0 then
      local inserted = inv.insert{name = best_name, count = 1}
      if inserted > 0 then
        pool[best_name] = best_count - inserted
        if pool[best_name] <= 0 then
          pool[best_name] = nil
        end
        networks_changed[net_id] = true
      end
    end

    ::next_outtake::
  end

  -- Update circuit combinator signals for changed networks.
  if next(networks_changed) then
    for uid, entry in pairs(storage.tube_intakes) do
      local net_id = storage.tube_network_cache[uid]
      if net_id and networks_changed[net_id] then
        update_combinator_signals(entry.combinator, storage.tube_signals[net_id])
      end
    end
    for uid, entry in pairs(storage.tube_outtakes) do
      local net_id = storage.tube_network_cache[uid]
      if net_id and networks_changed[net_id] then
        update_combinator_signals(entry.combinator, storage.tube_signals[net_id])
      end
    end
  end

  -- Refresh the hover GUI for any player currently selecting a tube entity.
  for _, player in pairs(game.connected_players) do
    if player.gui.left["administratorio-tube-info"] then
      local entity = player.selected
      if entity and entity.valid and (entity.name == "tube-intake" or entity.name == "tube-outtake") then
        M.update_tube_info_gui(player, entity)
      else
        M.destroy_tube_info_gui(player)
      end
    end
  end
end

-------------------------------------------------------------------------------
-- INSPECTION GUI
-------------------------------------------------------------------------------

function M.destroy_tube_info_gui(player)
  if player.gui.left["administratorio-tube-info"] then
    player.gui.left["administratorio-tube-info"].destroy()
  end
end

function M.update_tube_info_gui(player, entity)
  M.destroy_tube_info_gui(player)
  if not entity or not entity.valid then return end

  M.ensure_storage()
  local uid = entity.unit_number

  -- Determine the network id from the cache.
  local net_id = storage.tube_network_cache[uid]
  local is_disabled = net_id and storage.tube_network_disabled[net_id]

  local frame = player.gui.left.add{
    type = "frame",
    name = "administratorio-tube-info",
    direction = "vertical",
  }
  frame.style.minimal_width = 220

  local title = frame.add{type = "label", caption = "Tube Network"}
  title.style.font = "default-bold"
  title.style.bottom_margin = 4

  -- Network status.
  if not net_id then
    local status = frame.add{type = "label", caption = "Status: Disconnected"}
    status.style.font_color = {r=1, g=0.3, b=0.3}
    return
  elseif is_disabled then
    local status = frame.add{type = "label", caption = "Status: Over-extended"}
    status.style.font_color = {r=1, g=0.6, b=0.2}
    return
  else
    local status = frame.add{type = "label", caption = "Status: Connected"}
    status.style.font_color = {r=0.3, g=1, b=0.3}
  end

  -- Capacity.
  local capacity = M.get_network_capacity(entity.force)
  local total = M.get_network_total(net_id)
  local max_item_count = 0
  local pool = storage.tube_signals[net_id]
  if pool then
    for _, count in pairs(pool) do
      if count > max_item_count then max_item_count = count end
    end
  end
  local pct = capacity > 0 and (max_item_count / capacity) or 0
  local cap_color = pct < 0.7 and {r=0.3, g=1, b=0.3} or pct < 0.9 and {r=1, g=1, b=0.3} or {r=1, g=0.2, b=0.2}

  local cap_label = frame.add{type = "label", caption = "Capacity: " .. capacity .. " per item (" .. total .. " total)"}
  cap_label.style.font_color = cap_color

  local bar = frame.add{type = "progressbar", value = math.min(1, pct)}
  bar.style.width = 200
  bar.style.color = cap_color

  -- Item breakdown.
  if pool and next(pool) then
    local items_label = frame.add{type = "label", caption = "Contents:"}
    items_label.style.top_margin = 4
    items_label.style.font = "default-semibold"

    -- Sort by count descending.
    local sorted = {}
    for item_name, count in pairs(pool) do
      if count > 0 then
        table.insert(sorted, {name = item_name, count = count})
      end
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)

    for _, item in ipairs(sorted) do
      local display_name = item.name:gsub("%-", " ")
      frame.add{type = "label", caption = "  [item=" .. item.name .. "] " .. display_name .. "  x" .. item.count}
    end
  else
    local empty_label = frame.add{type = "label", caption = "Empty"}
    empty_label.style.font_color = {r=0.6, g=0.6, b=0.6}
    empty_label.style.top_margin = 4
  end
end

-------------------------------------------------------------------------------
-- STORAGE
-------------------------------------------------------------------------------

function M.ensure_storage()
  storage.tube_intakes = storage.tube_intakes or {}
  storage.tube_outtakes = storage.tube_outtakes or {}
  storage.tube_signals = storage.tube_signals or {}
  storage.tube_network_cache = storage.tube_network_cache or {}
  storage.tube_network_disabled = storage.tube_network_disabled or {}
  if storage.tube_network_dirty == nil then
    storage.tube_network_dirty = true
  end
end

--- Full rebuild from scratch — scan surfaces for tube entities and recreate
--- storage tracking.  Called from on_init and on_configuration_changed.
function M.rebuild_all()
  M.ensure_storage()
  storage.tube_intakes = {}
  storage.tube_outtakes = {}

  -- Destroy any stale hidden outtake inserters (no longer used).
  for _, surface in pairs(game.surfaces) do
    for _, ins in ipairs(surface.find_entities_filtered{name = "pneumatic-hidden-outtake"}) do
      ins.destroy()
    end
  end

  for _, surface in pairs(game.surfaces) do
    for building_name, inserter_name in pairs(C.PNEUMATIC_BUILDINGS) do
      for _, entity in ipairs(surface.find_entities_filtered{name = building_name}) do
        if entity.valid then
          enable_tube_rotation(entity)
          deactivate_intake_machine(entity)

          -- Find or create hidden inserter (only for entities that need one).
          local inserter = nil
          if inserter_name then
            local inserters = surface.find_entities_filtered{
              type = "inserter",
              name = inserter_name,
              position = entity.position,
              radius = 0.5,
            }
            inserter = inserters[1]
            if not inserter then
              inserter = surface.create_entity{
                name = inserter_name,
                type = "inserter",
                position = entity.position,
                direction = entity.direction,
                force = entity.force,
              }
              if inserter then
                inserter.destructible = false
                inserter.inserter_stack_size_override = 1
              end
            end
          end

          -- Find or create hidden network pipe.
          local pipes = surface.find_entities_filtered{
            name = "pneumatic-hidden-network-pipe",
            position = entity.position,
            radius = 0.5,
          }
          local network_pipe = pipes[1]
          if not network_pipe then
            network_pipe = surface.create_entity{
              name = "pneumatic-hidden-network-pipe",
              position = entity.position,
              force = entity.force,
            }
            if network_pipe then
              network_pipe.destructible = false
            end
          end

          -- Find or create hidden combinator.
          local combinators = surface.find_entities_filtered{
            name = "tube-network-combinator",
            position = entity.position,
            radius = 0.5,
          }
          local combinator = combinators[1]
          if not combinator then
            combinator = create_tube_combinator(entity)
          else
            connect_tube_combinator(entity, combinator)
          end

          if entity.name == "tube-intake" then
            storage.tube_intakes[entity.unit_number] = {
              entity = entity,
              inserter = inserter,
              network_pipe = network_pipe,
              combinator = combinator,
            }
          elseif entity.name == "tube-outtake" then
            storage.tube_outtakes[entity.unit_number] = {
              entity = entity,
              network_pipe = network_pipe,
              combinator = combinator,
            }
          end
        end
      end
    end
  end

  storage.tube_network_dirty = true
end

return M
