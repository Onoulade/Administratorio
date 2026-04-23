local C = require("scripts.constants")
local working_hours = require("scripts.working_hours")

local M = {}

local PORT_NAME = C.BITERPORT_NAME
local HIDDEN_ROBOPORT_NAME = C.BITERPORT_HIDDEN_ROBOPORT_NAME
local COFFEE_INPUT_NAME = "biterport-coffee-input"
local WORKER_FORCE_NAME = "administratorio-biters"
local WORKER_ITEM_NAME = "biter-logistics-formation"
local MONEY_ITEM_NAME = "taxpayer-money"
local COFFEE_FLUID_NAME = "liquid-coffee"
local WORKER_ENTITY_NAME = C.BITERPORT_WORKER_ENTITY_NAME or "small-biter"
local FALLBACK_WORKER_ENTITY_NAME = "small-biter"

local SLOT_TIER_TECHS = {
  {"biterport-capacity-1", 8},
  {"biterport-capacity-2", 10},
  {"biterport-capacity-3", 12},
  {"biterport-capacity-4", 15},
}

local SPEED_TIER_TECHS = {
  {"biterport-worker-speed-2", C.BITERPORT_WORKER_EXPRESS_ENTITY_NAME},
  {"biterport-worker-speed-1", C.BITERPORT_WORKER_FAST_ENTITY_NAME},
}

local SOURCE_CHEST_NAMES = {
  ["active-provider-chest"] = true,
  ["passive-provider-chest"] = true,
  ["storage-chest"] = true,
  ["buffer-chest"] = true,
  ["logistic-chest-active-provider"] = true,
  ["logistic-chest-passive-provider"] = true,
  ["logistic-chest-storage"] = true,
  ["logistic-chest-buffer"] = true,
}

local REQUESTER_CHEST_NAMES = {
  ["requester-chest"] = true,
  ["buffer-chest"] = true,
  ["logistic-chest-requester"] = true,
  ["logistic-chest-buffer"] = true,
}

local STORAGE_CHEST_NAMES = {
  ["storage-chest"] = true,
  ["logistic-chest-storage"] = true,
}

local LOGISTIC_CHEST_NAMES = {
  ["active-provider-chest"] = true,
  ["passive-provider-chest"] = true,
  ["storage-chest"] = true,
  ["buffer-chest"] = true,
  ["requester-chest"] = true,
  ["logistic-chest-active-provider"] = true,
  ["logistic-chest-passive-provider"] = true,
  ["logistic-chest-storage"] = true,
  ["logistic-chest-buffer"] = true,
  ["logistic-chest-requester"] = true,
}

local MIN_PHASE_TRAVEL_DISTANCE = 0.75
local PHASE_STUCK_TIMEOUT_TICKS = 120

local function copy_position(pos)
  return pos and {x = pos.x, y = pos.y} or nil
end

local function copy_box(box)
  if not box then return nil end
  return {
    left_top = copy_position(box.left_top),
    right_bottom = copy_position(box.right_bottom),
  }
end

local function safe_entity_field(entity, field)
  if not entity or not entity.valid then return nil end
  local ok, value = pcall(function() return entity[field] end)
  if ok then return value end
  return nil
end

local function distance_squared(a, b)
  local dx = a.x - b.x
  local dy = a.y - b.y
  return dx * dx + dy * dy
end

local function radius_box(pos, radius)
  return {
    left_top = {x = pos.x - radius, y = pos.y - radius},
    right_bottom = {x = pos.x + radius, y = pos.y + radius},
  }
end

local function get_station_inventory(entity)
  if not entity or not entity.valid or not entity.get_inventory then return nil end
  local ok, inv = pcall(entity.get_inventory, defines.inventory.chest)
  if ok then return inv end
  return nil
end

local function get_entity_inventory(entity)
  if not entity or not entity.valid or not entity.get_inventory then return nil end
  local inventory_ids = defines.inventory and {
    defines.inventory.chest,
    defines.inventory.car_trunk,
    defines.inventory.spider_trunk,
    defines.inventory.cargo_wagon,
  } or {}
  for _, inventory_id in ipairs(inventory_ids) do
    if inventory_id then
      local ok, inv = pcall(entity.get_inventory, inventory_id)
      if ok and inv then return inv end
    end
  end
  return nil
end

local function ensure_worker_force()
  local force = game.forces[WORKER_FORCE_NAME]
  if not force and game.create_force then
    force = game.create_force(WORKER_FORCE_NAME)
  end
  if not force then return nil end

  local player = game.forces["player"]
  if player then
    force.set_cease_fire(player, true)
    player.set_cease_fire(force, true)
  end

  local enemy = game.forces["enemy"]
  if enemy then
    force.set_cease_fire(enemy, true)
    enemy.set_cease_fire(force, true)
  end

  local neutral = game.forces["neutral"]
  if neutral then
    force.set_cease_fire(neutral, true)
    neutral.set_cease_fire(force, true)
  end

  return force
end

local function get_worker_force()
  local force = ensure_worker_force()
  if force and force.valid and force.name ~= "enemy" then return force end
  return game.forces["player"] or game.forces["neutral"]
end

local function force_has_researched(force, tech_name)
  if not force or not force.valid or not force.technologies then return false end
  local tech = force.technologies[tech_name]
  return tech and tech.researched or false
end

local function get_port_worker_slots_for_force(force)
  local slots = C.BITERPORT_WORKER_SLOTS
  for _, tier in ipairs(SLOT_TIER_TECHS) do
    if force_has_researched(force, tier[1]) then
      slots = tier[2]
    else
      break
    end
  end
  return slots
end

local function entity_prototype_exists(name)
  if not name then return false end
  if prototypes and prototypes.entity then
    return prototypes.entity[name] ~= nil
  end
  return true
end

local function get_worker_entity_name(force)
  for _, tier in ipairs(SPEED_TIER_TECHS) do
    local tech_name, entity_name = tier[1], tier[2]
    if force_has_researched(force, tech_name) and entity_prototype_exists(entity_name) then
      return entity_name
    end
  end
  if entity_prototype_exists(WORKER_ENTITY_NAME) then return WORKER_ENTITY_NAME end
  return FALLBACK_WORKER_ENTITY_NAME
end

local function set_entity_force(entity, force_name)
  if not entity or not entity.valid or not force_name then return false end
  local force = game and game.forces and game.forces[force_name] or force_name
  local ok = pcall(function() entity.force = force end)
  return ok
end

local function apply_port_inventory(port)
  local inv = get_station_inventory(port)
  if not inv then return end
  local target = get_port_worker_slots_for_force(port.force) + 1
  if #inv < target and inv.resize then
    inv.resize(target)
  end
  if inv.set_filter and inv.supports_filters and inv.supports_filters() then
    inv.set_filter(1, {name = MONEY_ITEM_NAME})
    for i = 2, math.min(#inv, target) do
      inv.set_filter(i, {name = WORKER_ITEM_NAME})
    end
  end
end

local function port_worker_count(port)
  local inv = get_station_inventory(port)
  return inv and inv.get_item_count and inv.get_item_count(WORKER_ITEM_NAME) or 0
end

local function port_money_count(port)
  local inv = get_station_inventory(port)
  return inv and inv.get_item_count and inv.get_item_count(MONEY_ITEM_NAME) or 0
end

local function rear_input_position(entity)
  local direction = entity and entity.direction or defines.direction.north
  local position = entity and entity.position or {x = 0, y = 0}
  if direction == defines.direction.east then
    return {x = position.x + 2, y = position.y}
  elseif direction == defines.direction.south then
    return {x = position.x, y = position.y + 2}
  elseif direction == defines.direction.west then
    return {x = position.x - 2, y = position.y}
  end
  return {x = position.x, y = position.y - 2}
end

local function create_hidden_coffee_input(port)
  if not port or not port.valid or not port.unit_number then return nil end
  storage.biterport_coffee_inputs = storage.biterport_coffee_inputs or {}
  local input = storage.biterport_coffee_inputs[port.unit_number]
  if input and input.valid then
    return input
  end

  local created = port.surface.create_entity{
    name = COFFEE_INPUT_NAME,
    position = rear_input_position(port),
    direction = port.direction or defines.direction.north,
    force = port.force,
    create_build_effect_smoke = false,
  }
  if created and created.valid then
    created.destructible = false
    created.minable = false
    created.operable = false
    storage.biterport_coffee_inputs[port.unit_number] = created
  end
  return created
end

local function destroy_hidden_coffee_input(port_id)
  local input = storage.biterport_coffee_inputs and storage.biterport_coffee_inputs[port_id]
  if input and input.valid then
    input.destroy()
  end
  if storage.biterport_coffee_inputs then
    storage.biterport_coffee_inputs[port_id] = nil
  end
end

local function dispatch_requires_coffee(port)
  return port and port.valid
    and working_hours.is_enabled()
    and working_hours.is_night(port.surface)
end

local function available_dispatch_coffee(port)
  if not dispatch_requires_coffee(port) then
    return math.huge
  end

  local input = create_hidden_coffee_input(port)
  local fluidbox = input and input.valid and input.fluidbox
  local fluid = fluidbox and fluidbox[1] or nil
  if fluid and fluid.name == COFFEE_FLUID_NAME then
    return fluid.amount or 0
  end
  return 0
end

local function has_dispatch_coffee(port)
  return available_dispatch_coffee(port) >= C.BITERPORT_NIGHT_COFFEE_PER_DISPATCH
end

local function remove_dispatch_coffee(port)
  if not dispatch_requires_coffee(port) then
    return true
  end

  local input = create_hidden_coffee_input(port)
  if not input or not input.valid or not input.remove_fluid then
    return false
  end

  local ok, removed = pcall(input.remove_fluid, {
    name = COFFEE_FLUID_NAME,
    amount = C.BITERPORT_NIGHT_COFFEE_PER_DISPATCH,
  })
  return ok and (removed or 0) >= C.BITERPORT_NIGHT_COFFEE_PER_DISPATCH
end

local function port_can_dispatch(port)
  return port and port.valid
    and port_worker_count(port) > 0
    and port_money_count(port) >= C.BITERPORT_WORKER_SALARY
    and has_dispatch_coffee(port)
end

local function station_has_active_workers(port_id)
  local set = storage.biterport_active_by_port and storage.biterport_active_by_port[port_id]
  return set and next(set) ~= nil or false
end

local function set_port_status(port, key)
  if not port or not port.valid then return end
  if key == "biterport-calling" then
    port.custom_status = {
      diode = defines.entity_status_diode.yellow,
      label = {"gui.biterport-calling"},
    }
  elseif key == "biterport-no-workers" or key == "biterport-no-money" or key == "biterport-no-coffee" then
    port.custom_status = {
      diode = defines.entity_status_diode.red,
      label = {"gui." .. key},
    }
  else
    port.custom_status = {
      diode = defines.entity_status_diode.green,
      label = {"gui.biterport-idle"},
    }
  end
end

local function refresh_port_status(port)
  if not port or not port.valid then return end
  port.minable = not station_has_active_workers(port.unit_number)
  if station_has_active_workers(port.unit_number) then
    set_port_status(port, "biterport-calling")
  elseif port_worker_count(port) <= 0 then
    set_port_status(port, "biterport-no-workers")
  elseif port_money_count(port) < C.BITERPORT_WORKER_SALARY then
    set_port_status(port, "biterport-no-money")
  elseif not has_dispatch_coffee(port) then
    set_port_status(port, "biterport-no-coffee")
  else
    set_port_status(port, "biterport-idle")
  end
end

local function create_hidden_roboport(port)
  if not port or not port.valid or not port.unit_number then return nil end
  storage.biterport_hidden_roboports = storage.biterport_hidden_roboports or {}
  local hidden = storage.biterport_hidden_roboports[port.unit_number]
  if hidden and hidden.valid then
    return hidden
  end
  local created = port.surface.create_entity{
    name = HIDDEN_ROBOPORT_NAME,
    position = port.position,
    force = port.force,
    create_build_effect_smoke = false,
  }
  if created and created.valid then
    created.destructible = false
    created.minable = false
    created.operable = false
    storage.biterport_hidden_roboports[port.unit_number] = created
  end
  return created
end

local function destroy_hidden_roboport(port_id)
  local hidden = storage.biterport_hidden_roboports and storage.biterport_hidden_roboports[port_id]
  if hidden and hidden.valid then
    hidden.destroy()
  end
  if storage.biterport_hidden_roboports then
    storage.biterport_hidden_roboports[port_id] = nil
  end
end

local function register_active_worker(active)
  if not active or not active.biter_unit_number then return end
  storage.biterport_workers[active.biter_unit_number] = active
  local port_id = active.home_port_id
  if port_id then
    storage.biterport_active_by_port[port_id] = storage.biterport_active_by_port[port_id] or {}
    storage.biterport_active_by_port[port_id][active.biter_unit_number] = true
  end
end

local function unregister_active_worker(active)
  if not active then return end
  local unit_number = active.biter_unit_number
  if unit_number then
    storage.biterport_workers[unit_number] = nil
  end
  local port_id = active.home_port_id
  if port_id and storage.biterport_active_by_port then
    local set = storage.biterport_active_by_port[port_id]
    if set and unit_number then
      set[unit_number] = nil
      if not next(set) then storage.biterport_active_by_port[port_id] = nil end
    end
  end
end

local function mark_worker_unit(unit_number, port_id)
  if not unit_number then return end
  storage.biterport_worker_units = storage.biterport_worker_units or {}
  storage.biterport_worker_units[unit_number] = port_id or true
end

local function unmark_worker_unit(unit_number)
  if not unit_number or not storage.biterport_worker_units then return end
  storage.biterport_worker_units[unit_number] = nil
end

local function destroy_render(render_id)
  if not render_id or not rendering or not rendering.get_object_by_id then return end
  local object = rendering.get_object_by_id(render_id)
  if object then object.destroy() end
end

local JOB_TINT_COLORS = {
  construction = {r = 0.4, g = 1.0, b = 0.4},
  logistics    = {r = 0.4, g = 0.6, b = 1.0},
}

local function apply_job_tint(biter, job_kind)
  if not biter or not biter.valid then return end
  local color = JOB_TINT_COLORS[job_kind]
  if color then biter.color = color end
end

local function create_reserved_overlay(job)
  if not rendering or not rendering.draw_text or not job or not job.surface or not job.position then
    return nil
  end
  local obj = rendering.draw_text{
    text = {"gui.biterport-reserved"},
    surface = job.surface,
    target = job.position,
    color = {r = 0.55, g = 1.0, b = 0.45},
    alignment = "center",
    vertical_alignment = "middle",
    scale = 0.9,
    scale_with_zoom = true,
  }
  return obj and obj.id or nil
end

local function snapshot_ghost(ghost, item_name, source)
  local ghost_name = ghost.ghost_name or (ghost.ghost_prototype and ghost.ghost_prototype.name)
  if not ghost_name then return nil end
  local force_name = ghost.force and ghost.force.name or nil
  local quality_proto = safe_entity_field(ghost, "quality")
  local direction = safe_entity_field(ghost, "direction") or defines.direction.north
  local quality = quality_proto and quality_proto.name or nil
  return {
    kind = "construction",
    item_name = item_name,
    source = source,
    ghost = ghost,
    surface = ghost.surface,
    surface_index = ghost.surface and ghost.surface.index or nil,
    force_name = force_name,
    ghost_name = ghost_name,
    position = copy_position(ghost.position),
    bounding_box = copy_box(safe_entity_field(ghost, "bounding_box")),
    direction = direction,
    mirror = safe_entity_field(ghost, "mirror"),
    quality = quality,
    tags = safe_entity_field(ghost, "tags"),
  }
end

local function restore_construction_ghost(job)
  if not job or job.restored or job.built then return end
  if job.overlay_id then
    destroy_render(job.overlay_id)
    job.overlay_id = nil
  end
  if job.ghost and job.ghost.valid then
    set_entity_force(job.ghost, job.force_name)
    job.restored = true
    return
  end
  if not job.surface or not job.position or not job.ghost_name then return end
  local params = {
    name = "entity-ghost",
    inner_name = job.ghost_name,
    position = job.position,
    direction = job.direction,
    force = job.force_name,
    create_build_effect_smoke = false,
    tags = job.tags,
  }
  if job.quality then params.quality = job.quality end
  pcall(job.surface.create_entity, params)
  job.restored = true
end

local function get_ghost_item_name(ghost)
  if not ghost or not ghost.valid then return nil end
  local proto = ghost.ghost_prototype
  local items = proto and proto.items_to_place_this
  if items and items[1] and items[1].name then
    return items[1].name
  end
  return ghost.ghost_name
end

local function is_logistic_chest(entity)
  if not entity or not entity.valid then return false end
  if LOGISTIC_CHEST_NAMES[entity.name] then return true end
  if entity.type == "logistic-container" then return true end
  return false
end

local function is_source_chest(entity)
  if not entity or not entity.valid then return false end
  if SOURCE_CHEST_NAMES[entity.name] then return true end
  local mode = entity.prototype and entity.prototype.logistic_mode
  return entity.type == "logistic-container" and mode ~= "requester"
end

local function is_requester_chest(entity)
  if not entity or not entity.valid then return false end
  if REQUESTER_CHEST_NAMES[entity.name] then return true end
  local mode = entity.prototype and entity.prototype.logistic_mode
  return entity.type == "logistic-container" and mode == "requester"
end

local function collect_ports_for_surface_force(surface, force)
  local ports = {}
  for _, port in pairs(storage.biterports or {}) do
    if port and port.valid
       and port.surface == surface
       and port.force == force then
      ports[#ports + 1] = port
    end
  end
  table.sort(ports, function(a, b)
    return (a.unit_number or 0) < (b.unit_number or 0)
  end)
  return ports
end

local function build_networks(surface, force)
  local ports = collect_ports_for_surface_force(surface, force)
  local parent = {}
  for i = 1, #ports do parent[i] = i end

  local function find(i)
    while parent[i] ~= i do
      parent[i] = parent[parent[i]]
      i = parent[i]
    end
    return i
  end

  local function unite(a, b)
    local ra, rb = find(a), find(b)
    if ra ~= rb then parent[rb] = ra end
  end

  local link_sq = (C.BITERPORT_LOGISTICS_RADIUS * 2) * (C.BITERPORT_LOGISTICS_RADIUS * 2)
  for i = 1, #ports do
    for j = i + 1, #ports do
      if distance_squared(ports[i].position, ports[j].position) <= link_sq then
        unite(i, j)
      end
    end
  end

  local by_root = {}
  for i, port in ipairs(ports) do
    local root = find(i)
    local network = by_root[root]
    if not network then
      network = {surface = surface, force = force, ports = {}, port_set = {}}
      by_root[root] = network
    end
    network.ports[#network.ports + 1] = port
    network.port_set[port.unit_number] = true
  end

  local networks = {}
  for _, network in pairs(by_root) do
    networks[#networks + 1] = network
  end
  table.sort(networks, function(a, b)
    return (a.ports[1].unit_number or 0) < (b.ports[1].unit_number or 0)
  end)
  return networks
end

local function build_all_networks()
  local groups = {}
  for _, port in pairs(storage.biterports or {}) do
    if port and port.valid and port.surface and port.force then
      local key = tostring(port.surface.index) .. ":" .. port.force.name
      groups[key] = groups[key] or {surface = port.surface, force = port.force}
    end
  end

  local networks = {}
  for _, group in pairs(groups) do
    for _, network in ipairs(build_networks(group.surface, group.force)) do
      networks[#networks + 1] = network
    end
  end
  return networks
end

local function position_in_network_radius(network, position, radius)
  local radius_sq = radius * radius
  for _, port in ipairs(network.ports) do
    if distance_squared(port.position, position) <= radius_sq then
      return true
    end
  end
  return false
end

local function for_each_logistic_chest(network, callback)
  local seen = {}
  for _, port in ipairs(network.ports) do
    local chests = network.surface.find_entities_filtered{
      type = "logistic-container",
      area = radius_box(port.position, C.BITERPORT_LOGISTICS_RADIUS),
      force = network.force,
      limit = C.BITERPORT_MAX_CHESTS_PER_PORT_SCAN,
    }
    for _, chest in ipairs(chests) do
      local key = chest.unit_number or (chest.name .. "@" .. math.floor(chest.position.x) .. "," .. math.floor(chest.position.y))
      if chest.valid and is_logistic_chest(chest) and not seen[key] then
        seen[key] = true
        if callback(chest) then return true end
      end
    end
  end
  return false
end

local function find_source_for_item(network, item_name, position, excluded_unit_number)
  local best, best_inv, best_score = nil, nil, math.huge
  for_each_logistic_chest(network, function(chest)
    if is_source_chest(chest) and chest.unit_number ~= excluded_unit_number then
      local inv = get_entity_inventory(chest)
      if inv and inv.get_item_count and inv.get_item_count(item_name) > 0 then
        local score = position and distance_squared(chest.position, position) or 0
        if score < best_score then
          best = chest
          best_inv = inv
          best_score = score
        end
      end
    end
    return false
  end)
  return best, best_inv
end

local function choose_worker_port(network, pickup_position, target_position)
  local best, best_score = nil, math.huge
  for _, port in ipairs(network.ports) do
    if port_can_dispatch(port) then
      local score = distance_squared(port.position, pickup_position)
        + distance_squared(pickup_position, target_position)
        + distance_squared(target_position, port.position)
      if score < best_score then
        best = port
        best_score = score
      end
    end
  end
  return best
end

local function claim_ghost(ghost, source)
  local item_name = get_ghost_item_name(ghost)
  if not item_name then return nil end
  local job = snapshot_ghost(ghost, item_name, source)
  if not job then return nil end
  job.overlay_id = create_reserved_overlay(job)
  local worker_force = get_worker_force()
  if worker_force and worker_force.valid and worker_force.name ~= job.force_name then
    local ok = pcall(function() ghost.force = worker_force end)
    if ok then
      job.reserved_by_force_swap = true
    else
      ghost.destroy()
      job.ghost = nil
    end
  else
    ghost.destroy()
    job.ghost = nil
  end
  return job
end

local function find_construction_job(network)
  for _, port in ipairs(network.ports) do
    local ghosts = network.surface.find_entities_filtered{
      type = "entity-ghost",
      area = radius_box(port.position, C.BITERPORT_CONSTRUCTION_RADIUS),
      force = network.force,
      limit = C.BITERPORT_MAX_GHOSTS_PER_PORT_SCAN,
    }
    table.sort(ghosts, function(a, b)
      return distance_squared(a.position, port.position) < distance_squared(b.position, port.position)
    end)

    for _, ghost in ipairs(ghosts) do
      if ghost.valid and position_in_network_radius(network, ghost.position, C.BITERPORT_CONSTRUCTION_RADIUS) then
        local item_name = get_ghost_item_name(ghost)
        if item_name then
          local source = find_source_for_item(network, item_name, ghost.position)
          if source and source.valid then
            local worker_port = choose_worker_port(network, source.position, ghost.position)
            if worker_port then
              local job = claim_ghost(ghost, source)
              if job then
                return job, worker_port
              end
            end
          end
        end
      end
    end
  end
  return nil, nil
end

local function find_network_for_position(surface, force, position, radius)
  if not surface or not force or not position then return nil end
  for _, network in ipairs(build_networks(surface, force)) do
    if position_in_network_radius(network, position, radius) then
      return network
    end
  end
  return nil
end

local function find_construction_job_for_ghost(network, ghost)
  if not network or not ghost or not ghost.valid or ghost.type ~= "entity-ghost" then
    return nil, nil
  end
  if not position_in_network_radius(network, ghost.position, C.BITERPORT_CONSTRUCTION_RADIUS) then
    return nil, nil
  end

  local item_name = get_ghost_item_name(ghost)
  if not item_name then return nil, nil end

  local source = find_source_for_item(network, item_name, ghost.position)
  if not source or not source.valid then return nil, nil end

  local worker_port = choose_worker_port(network, source.position, ghost.position)
  if not worker_port then return nil, nil end

  local job = claim_ghost(ghost, source)
  if not job then return nil, nil end
  return job, worker_port
end

local function requester_filters(entity)
  if not entity or not entity.valid or not entity.get_requester_point then return nil end
  local ok, point = pcall(entity.get_requester_point)
  if not ok or not point or not point.valid or point.enabled == false then return nil end
  return point.filters
end

local function get_player_character(player)
  local character = safe_entity_field(player, "character")
  if character and character.valid then return character end
  return nil
end

local function get_player_main_inventory(player)
  if not player or not player.valid then return nil end
  if player.get_main_inventory then
    local ok, inv = pcall(player.get_main_inventory)
    if ok and inv then return inv end
  end
  if player.get_inventory and defines and defines.inventory and defines.inventory.character_main then
    local ok, inv = pcall(player.get_inventory, defines.inventory.character_main)
    if ok and inv then return inv end
  end
  return nil
end

local function get_player_trash_inventory(player)
  if not player or not player.valid or not player.get_inventory then return nil end
  local trash_inventory = defines and defines.inventory and defines.inventory.character_trash
  if not trash_inventory then return nil end
  local ok, inv = pcall(player.get_inventory, trash_inventory)
  if ok and inv then return inv end
  return nil
end

local function player_delivery_destination(player)
  return get_player_character(player) or player
end

local function make_player_tracking_key(player)
  if not player or not player.index then return nil end
  return "player:" .. player.index
end

local function active_logistics_count(key_name, key_value, item_name)
  if not key_name or key_value == nil then return 0 end
  local count = 0
  for _, active in pairs(storage.biterport_workers or {}) do
    local job = active.job
    if job and job.kind == "logistics"
       and job[key_name] == key_value
       and job.item_name == item_name then
      count = count + (job.count or 1)
    end
  end
  return count
end

local function counted_items(subject, inv, item_name)
  if subject and subject.valid and subject.get_item_count then
    local ok, count = pcall(subject.get_item_count, item_name)
    if ok then return count or 0 end
  end
  return inv and inv.get_item_count and inv.get_item_count(item_name) or 0
end

local function requested_missing_stack(entity, inv, tracking_key, counted_subject)
  local filters = requester_filters(entity)
  if not filters then return nil end
  for _, filter in ipairs(filters) do
    local item_name = filter.name
    local target = filter.count or 0
    if item_name and target > 0 then
      local current = counted_items(counted_subject or entity, inv, item_name)
      local in_flight = active_logistics_count(
        tracking_key and "target_tracking_key" or "target_unit_number",
        tracking_key or entity.unit_number,
        item_name
      )
      if current + in_flight < target then
        return item_name, math.min(1, target - current - in_flight)
      end
    end
  end
  return nil
end

local function find_trash_target(network, item_name, position)
  local best, best_score = nil, math.huge
  for_each_logistic_chest(network, function(chest)
    if not is_source_chest(chest) then return false end
    local inv = get_entity_inventory(chest)
    if not inv or not inv.insert then return false end
    if inv.can_insert and not inv.can_insert({name = item_name, count = 1}) then
      return false
    end

    local score = position and distance_squared(chest.position, position) or 0
    if STORAGE_CHEST_NAMES[chest.name]
       or (chest.prototype and chest.prototype.logistic_mode == "storage") then
      score = score - 1000
    end
    if inv.get_item_count and inv.get_item_count(item_name) > 0 then
      score = score - 25
    end
    if score < best_score then
      best = chest
      best_score = score
    end
    return false
  end)
  return best
end

local function next_player_trash_stack(player)
  local inv = get_player_trash_inventory(player)
  local tracking_key = make_player_tracking_key(player)
  if not inv then return nil end
  for i = 1, #inv do
    local stack = inv[i]
    if stack and stack.valid_for_read and stack.name and stack.count and stack.count > 0 then
      local total = inv.get_item_count and inv.get_item_count(stack.name) or stack.count
      local in_flight = active_logistics_count("source_tracking_key", tracking_key, stack.name)
      if total > in_flight then
        return stack.name, 1, inv
      end
    end
  end
  return nil
end

local function find_logistics_job(network)
  local found_job, found_port
  for_each_logistic_chest(network, function(requester)
    if found_job then return true end
    if not is_requester_chest(requester) then return false end
    local target_inv = get_entity_inventory(requester)
    if not target_inv or not target_inv.insert then return false end
    local item_name, count = requested_missing_stack(requester, target_inv)
    if not item_name then return false end
    local source = find_source_for_item(network, item_name, requester.position, requester.unit_number)
    if not source or not source.valid then return false end
    local worker_port = choose_worker_port(network, source.position, requester.position)
    if not worker_port then return false end

    found_job = {
      kind = "logistics",
      item_name = item_name,
      count = count or 1,
      source = source,
      target = requester,
      target_unit_number = requester.unit_number,
    }
    found_port = worker_port
    return true
  end)
  return found_job, found_port
end

local function find_player_delivery_job(network)
  for _, player in ipairs(game.connected_players or {}) do
    local character = get_player_character(player)
    if player and player.valid
       and character
       and player.surface == network.surface
       and player.force == network.force
       and position_in_network_radius(network, player.position, C.BITERPORT_LOGISTICS_RADIUS) then
      local target_inv = get_player_main_inventory(player)
      if target_inv and player.insert then
        local tracking_key = make_player_tracking_key(player)
        local item_name, count = requested_missing_stack(player, target_inv, tracking_key, player)
        if item_name then
          local source = find_source_for_item(network, item_name, player.position)
          if source and source.valid then
            local worker_port = choose_worker_port(network, source.position, player.position)
            if worker_port then
              return {
                kind = "logistics",
                item_name = item_name,
                count = count or 1,
                source = source,
                target = player,
                target_destination = character,
                target_tracking_key = tracking_key,
              }, worker_port
            end
          end
        end
      end
    end
  end
  return nil, nil
end

local function find_player_trash_job(network)
  for _, player in ipairs(game.connected_players or {}) do
    local character = get_player_character(player)
    if player and player.valid
       and character
       and player.surface == network.surface
       and player.force == network.force
       and position_in_network_radius(network, player.position, C.BITERPORT_LOGISTICS_RADIUS) then
      local item_name = next_player_trash_stack(player)
      if item_name then
        local target = find_trash_target(network, item_name, player.position)
        if target and target.valid then
          local worker_port = choose_worker_port(network, player.position, target.position)
          if worker_port then
            return {
              kind = "logistics",
              item_name = item_name,
              count = 1,
              source = player,
              source_destination = character,
              source_tracking_key = make_player_tracking_key(player),
              target = target,
              target_unit_number = target.unit_number,
            }, worker_port
          end
        end
      end
    end
  end
  return nil, nil
end

local function clamp(value, min_value, max_value)
  if value < min_value then return min_value end
  if value > max_value then return max_value end
  return value
end

local function resolve_destination_position(destination)
  if not destination then return nil end
  if destination.valid and destination.position then return destination.position end
  if destination.position then return destination.position end
  if destination.x and destination.y then return destination end
  return nil
end

local function resolve_destination_unit_number(destination)
  if not destination or (destination.valid ~= nil and not destination.valid) then return nil end
  return safe_entity_field(destination, "unit_number")
end

local function position_reaches_entity(position, entity, radius)
  if not position or not entity or (entity.valid ~= nil and not entity.valid) then return false end
  local box = safe_entity_field(entity, "bounding_box")
  if not box then return false end
  local pad = math.max(0.5, radius or C.BITERPORT_ARRIVAL_RADIUS)
  return position.x >= box.left_top.x - pad
    and position.x <= box.right_bottom.x + pad
    and position.y >= box.left_top.y - pad
    and position.y <= box.right_bottom.y + pad
end

local function resolve_command_destination(biter, destination, radius)
  local target_position = resolve_destination_position(destination)
  if not target_position then return nil end
  if not biter or not biter.valid then return target_position end

  local box = destination and (destination.valid == nil or destination.valid) and safe_entity_field(destination, "bounding_box") or nil
  if box then
    local from = biter.position
    local pad = math.max(0.75, (radius or C.BITERPORT_ARRIVAL_RADIUS) * 0.5)
    local left = box.left_top.x - pad
    local right = box.right_bottom.x + pad
    local top = box.left_top.y - pad
    local bottom = box.right_bottom.y + pad

    local px = clamp(from.x, left, right)
    local py = clamp(from.y, top, bottom)
    if from.x >= left and from.x <= right and from.y >= top and from.y <= bottom then
      local d_left = math.abs(from.x - left)
      local d_right = math.abs(right - from.x)
      local d_top = math.abs(from.y - top)
      local d_bottom = math.abs(bottom - from.y)
      local best_side = math.min(d_left, d_right, d_top, d_bottom)
      if best_side == d_left then
        px = left
      elseif best_side == d_right then
        px = right
      elseif best_side == d_top then
        py = top
      else
        py = bottom
      end
    end

    local mid_x = (left + right) * 0.5
    local mid_y = (top + bottom) * 0.5
    local candidates = {
      {x = px, y = py},
      {x = left, y = mid_y},
      {x = right, y = mid_y},
      {x = mid_x, y = top},
      {x = mid_x, y = bottom},
      {x = left, y = top},
      {x = right, y = top},
      {x = left, y = bottom},
      {x = right, y = bottom},
    }
    local best_pos, best_dist = nil, math.huge
    for _, candidate in ipairs(candidates) do
      local approach = biter.surface.find_non_colliding_position(biter.name, candidate, 1.0, 0.25)
      if approach then
        local dist = distance_squared(from, approach)
        if dist < best_dist then
          best_pos = approach
          best_dist = dist
        end
      end
    end
    if best_pos then return best_pos end

    local fallback = biter.surface.find_non_colliding_position(
      biter.name,
      target_position,
      math.max(2.0, (radius or C.BITERPORT_ARRIVAL_RADIUS) + 2.0),
      0.25
    )
    if fallback then return fallback end
  end

  return target_position
end

local function construction_destination(job)
  if not job then return nil end
  if job.ghost and job.ghost.valid then return job.ghost end
  if job.position and job.bounding_box then
    return {
      position = job.position,
      bounding_box = job.bounding_box,
    }
  end
  return job.position
end

local function position_inside_box(position, box, pad)
  if not position or not box then return false end
  pad = pad or 0
  return position.x >= box.left_top.x - pad
    and position.x <= box.right_bottom.x + pad
    and position.y >= box.left_top.y - pad
    and position.y <= box.right_bottom.y + pad
end

local function move_worker_clear_of_construction(active, job)
  local biter = active and active.biter
  if not biter or not biter.valid or not job or not job.bounding_box then return true end
  if not position_inside_box(biter.position, job.bounding_box, 0.1) then return true end

  local target = construction_destination(job)
  local position = resolve_command_destination(biter, target, C.BITERPORT_ARRIVAL_RADIUS)
  if position then
    local ok, teleported = pcall(biter.teleport, position)
    return ok and teleported ~= false
  end
  return false
end

local function phase_target_shifted(active, destination)
  local current = resolve_destination_position(destination)
  local previous = active and active.phase_target_position
  if not current or not previous then return false end
  local threshold = math.max(1.0, active.phase_command_radius or C.BITERPORT_ARRIVAL_RADIUS)
  return distance_squared(current, previous) > threshold * threshold
end

local function issue_move_command(biter, destination, radius)
  if not biter or not biter.valid or not destination or not biter.commandable then return false end
  biter.force = get_worker_force()
  biter.active = true
  biter.commandable.set_command{
    type = defines.command.go_to_location,
    destination = destination,
    radius = radius or C.BITERPORT_ARRIVAL_RADIUS,
    distraction = defines.distraction.none,
  }
  return true
end

local function begin_phase_move(active, phase, destination, radius, tick)
  local biter = active and active.biter
  if not active or not biter or not biter.valid then return false end
  local target_position = resolve_destination_position(destination)
  if not target_position then return false end
  local command_destination = resolve_command_destination(biter, destination, radius)
  if not command_destination then return false end

  active.phase = phase
  active.phase_started_tick = tick or game.tick
  active.phase_origin = copy_position(biter.position)
  active.phase_departed = false
  active.phase_target_position = copy_position(target_position)
  active.phase_target_unit_number = resolve_destination_unit_number(destination)
  active.phase_destination = copy_position(command_destination)
  active.phase_radius = radius
  active.phase_command_radius = math.max(0.5, (radius or 0) * 0.5)
  active.phase_arrived_tick = nil
  return issue_move_command(biter, command_destination, active.phase_command_radius)
end

local function phase_origin_distance_squared(active, biter)
  if not active or not active.phase_origin or not biter or not biter.valid then return 0 end
  return distance_squared(active.phase_origin, biter.position)
end

local function phase_has_departed(active, biter, tick)
  if not active or not biter or not biter.valid then return false end
  if active.phase_departed then return true end
  if phase_origin_distance_squared(active, biter) >= (MIN_PHASE_TRAVEL_DISTANCE * MIN_PHASE_TRAVEL_DISTANCE) then
    active.phase_departed = true
    return true
  end
  local started_tick = active.phase_started_tick or tick
  if (tick - started_tick) >= PHASE_STUCK_TIMEOUT_TICKS then
    active.phase_departed = true
    return true
  end
  return false
end

local function phase_is_arrived(active, biter, destination, fallback_radius)
  if not active or not biter or not biter.valid then return false end
  if active.phase_arrived_tick then return true end
  local radius = active.phase_radius or fallback_radius or C.BITERPORT_ARRIVAL_RADIUS
  if destination and destination.valid and position_reaches_entity(biter.position, destination, radius) then
    return true
  end

  local target_position = resolve_destination_position(destination) or active.phase_target_position
  if target_position and distance_squared(biter.position, target_position) <= radius * radius then
    return true
  end

  local command_destination = active.phase_destination
  if command_destination then
    local command_radius = math.max(radius, active.phase_command_radius or 0)
    return distance_squared(biter.position, command_destination) <= command_radius * command_radius
  end
  return false
end

local function spawn_worker(port, job_kind)
  local worker_entity_name = get_worker_entity_name(port.force)
  local offset_x = job_kind == "logistics" and -1.5 or 1.5
  local spawn_origin = {x = port.position.x + offset_x, y = port.position.y + 2.5}
  local spawn_pos = port.surface.find_non_colliding_position(worker_entity_name, spawn_origin, 8, 0.5)
  if not spawn_pos then return nil end
  return port.surface.create_entity{
    name = worker_entity_name,
    position = spawn_pos,
    force = get_worker_force(),
  }
end

local function maybe_reinsert_worker(port)
  local inv = get_station_inventory(port)
  if not inv then return false end
  if inv.can_insert and inv.can_insert({name = WORKER_ITEM_NAME, count = 1}) then
    inv.insert({name = WORKER_ITEM_NAME, count = 1})
    return true
  end
  if port.surface and port.surface.spill_item_stack then
    port.surface.spill_item_stack{
      position = port.position,
      stack = {name = WORKER_ITEM_NAME, count = 1},
      enable_looted = false,
      force = port.force,
      allow_belts = false,
    }
  end
  return false
end

local function remove_dispatch_inputs(port)
  local inv = get_station_inventory(port)
  if not inv then return false end
  if inv.remove({name = WORKER_ITEM_NAME, count = 1}) < 1 then return false end
  if inv.remove({name = MONEY_ITEM_NAME, count = C.BITERPORT_WORKER_SALARY}) < C.BITERPORT_WORKER_SALARY then
    inv.insert({name = WORKER_ITEM_NAME, count = 1})
    return false
  end
  if not remove_dispatch_coffee(port) then
    inv.insert({name = MONEY_ITEM_NAME, count = C.BITERPORT_WORKER_SALARY})
    inv.insert({name = WORKER_ITEM_NAME, count = 1})
    return false
  end
  return true
end

local function insert_stack_into_target(target, stack)
  if not target or not stack or not stack.name or (stack.count or 0) <= 0 then return 0 end
  if target.valid and target.insert then
    local ok, inserted = pcall(target.insert, stack)
    if ok then return inserted or 0 end
  end
  local inv = get_entity_inventory(target)
  if inv and inv.insert then
    return inv.insert(stack) or 0
  end
  return 0
end

local function return_carried_item(active, preferred_entity)
  local stack = active and active.carried_stack
  if not stack or not stack.name or (stack.count or 0) <= 0 then return end

  local inserted = insert_stack_into_target(preferred_entity, stack)

  local remaining = (stack.count or 0) - inserted
  if remaining > 0 then
    local surface = active.biter and active.biter.valid and active.biter.surface
      or (preferred_entity and preferred_entity.valid and preferred_entity.surface)
    local position = active.biter and active.biter.valid and active.biter.position
      or (preferred_entity and preferred_entity.valid and preferred_entity.position)
    if surface and position and surface.spill_item_stack then
      surface.spill_item_stack{
        position = position,
        stack = {name = stack.name, count = remaining},
        enable_looted = false,
        force = preferred_entity and preferred_entity.valid and preferred_entity.force or nil,
        allow_belts = false,
      }
    end
  end
  active.carried_stack = nil
end

local function nearest_valid_port(active)
  local biter = active and active.biter
  local home = active and active.home_port_id and storage.biterports[active.home_port_id]
  if home and home.valid then return home end
  if not biter or not biter.valid then return nil end

  local best, best_score = nil, math.huge
  for _, port in pairs(storage.biterports or {}) do
    if port and port.valid and port.surface == biter.surface and port.force == active.force then
      local score = distance_squared(biter.position, port.position)
      if score < best_score then
        best, best_score = port, score
      end
    end
  end
  return best
end

local function start_return(active, tick)
  local port = nearest_valid_port(active)
  if not port or not port.valid then return false end
  active.return_port_id = port.unit_number
  return begin_phase_move(active, "returning", port, C.BITERPORT_ARRIVAL_RADIUS, tick)
end

local function finish_worker(active, tick, return_worker)
  if return_worker then
    local port = active.return_port_id and storage.biterports[active.return_port_id]
      or active.home_port_id and storage.biterports[active.home_port_id]
    if port and port.valid then
      maybe_reinsert_worker(port)
      refresh_port_status(port)
    end
  end

  if active.biter and active.biter.valid then
    active.biter.destroy()
  end
  unmark_worker_unit(active.biter_unit_number)
  unregister_active_worker(active)
end

local function fail_job_and_return(active, tick)
  local job = active.job
  if job and job.kind == "construction" and not job.built then
    restore_construction_ghost(job)
  elseif job and job.overlay_id then
    destroy_render(job.overlay_id)
    job.overlay_id = nil
  end
  return_carried_item(active, job and job.source)
  if not start_return(active, tick) then
    finish_worker(active, tick, true)
  end
end

local function perform_pickup(active, tick)
  local job = active.job
  local source = job and job.source
  local source_inv
  if source == nil or (source.valid ~= nil and not source.valid) then
    fail_job_and_return(active, tick)
    return
  end
  if job and job.source_tracking_key then
    source_inv = get_player_trash_inventory(source)
  else
    source_inv = get_entity_inventory(source)
  end
  if not source_inv or not source_inv.remove then
    fail_job_and_return(active, tick)
    return
  end
  local count = job.count or 1
  local removed = source_inv.remove({name = job.item_name, count = count}) or 0
  if removed <= 0 then
    fail_job_and_return(active, tick)
    return
  end
  active.carried_stack = {name = job.item_name, count = removed}
  local target = job.kind == "construction" and construction_destination(job)
    or job.target_destination
    or job.target
  begin_phase_move(active, "to_target", target, C.BITERPORT_ARRIVAL_RADIUS, tick)
end

local function build_construction_job(active, tick)
  local job = active.job
  if not job or not job.surface then
    fail_job_and_return(active, tick)
    return
  end

  move_worker_clear_of_construction(active, job)

  local built
  if job.ghost and job.ghost.valid then
    set_entity_force(job.ghost, job.force_name)
    if job.ghost.valid and job.ghost.silent_revive then
      local ok, _, revived = pcall(job.ghost.silent_revive, {raise_revive = true})
      if ok then built = revived end
    end
    if not built and job.ghost.valid and job.ghost.revive then
      local ok, _, revived = pcall(job.ghost.revive, {raise_revive = true})
      if ok then built = revived end
    end
  else
    local params = {
      name = job.ghost_name,
      position = job.position,
      direction = job.direction,
      force = job.force_name,
      raise_built = true,
      create_build_effect_smoke = true,
      spill = false,
    }
    if job.quality then params.quality = job.quality end
    if job.mirror ~= nil then params.mirror = job.mirror end
    built = job.surface.create_entity(params)
  end

  if built and built.valid then
    job.built = true
    job.ghost = nil
    if job.overlay_id then
      destroy_render(job.overlay_id)
      job.overlay_id = nil
    end
    active.carried_stack = nil
    if not start_return(active, tick) then
      finish_worker(active, tick, true)
    end
  else
    fail_job_and_return(active, tick)
  end
end

local function deliver_logistics_job(active, tick)
  local job = active.job
  local target = job and job.target
  if not target or (target.valid ~= nil and not target.valid) then
    return_carried_item(active, job and job.source)
    if not start_return(active, tick) then finish_worker(active, tick, true) end
    return
  end
  local stack = active.carried_stack
  local inserted = insert_stack_into_target(target, stack)
  if inserted <= 0 then
    return_carried_item(active, job and job.source)
    if not start_return(active, tick) then finish_worker(active, tick, true) end
    return
  end
  local remaining = stack and ((stack.count or 0) - inserted) or 0
  if remaining > 0 then
    active.carried_stack = {name = stack.name, count = remaining}
    return_carried_item(active, target)
  else
    active.carried_stack = nil
  end
  if not start_return(active, tick) then
    finish_worker(active, tick, true)
  end
end

local function advance_active_workers(tick)
  local active_list = {}
  for _, active in pairs(storage.biterport_workers or {}) do
    active_list[#active_list + 1] = active
  end

  for _, active in ipairs(active_list) do
    if not active or not storage.biterport_workers[active.biter_unit_number] then
      goto continue
    end
    local biter = active.biter
    if not biter or not biter.valid then
      if active.job and active.job.kind == "construction" and not active.job.built then
        restore_construction_ghost(active.job)
      elseif active.job and active.job.overlay_id then
        destroy_render(active.job.overlay_id)
        active.job.overlay_id = nil
      end
      return_carried_item(active, active.job and active.job.source)
      unmark_worker_unit(active.biter_unit_number)
      unregister_active_worker(active)
      local port = active.home_port_id and storage.biterports[active.home_port_id]
      if port and port.valid then refresh_port_status(port) end
      goto continue
    end

    if active.phase == "to_pickup" then
      local job = active.job
      local source = job and (job.source_destination or job.source)
      if not source or (source.valid ~= nil and not source.valid) then
        fail_job_and_return(active, tick)
        goto continue
      end
      local arrived = phase_is_arrived(active, biter, source, C.BITERPORT_ARRIVAL_RADIUS)
        and (active.phase_arrived_tick or phase_has_departed(active, biter, tick))
      if arrived then
        perform_pickup(active, tick)
      elseif active.phase_target_unit_number ~= resolve_destination_unit_number(source)
          or phase_target_shifted(active, source)
          or (biter.commandable and not biter.commandable.has_command) then
        begin_phase_move(active, "to_pickup", source, C.BITERPORT_ARRIVAL_RADIUS, tick)
    end

    elseif active.phase == "to_target" then
      local job = active.job
      local target = job and (
        job.kind == "construction" and construction_destination(job)
        or job.target_destination
        or job.target
      )
      local target_position = resolve_destination_position(target)
      if not target_position then
        fail_job_and_return(active, tick)
        goto continue
      end
      local arrived = phase_is_arrived(active, biter, target, C.BITERPORT_ARRIVAL_RADIUS)
        and (active.phase_arrived_tick or phase_has_departed(active, biter, tick))
      if arrived then
        if job.kind == "construction" then
          build_construction_job(active, tick)
        else
          deliver_logistics_job(active, tick)
        end
      elseif active.phase_target_unit_number ~= resolve_destination_unit_number(target)
          or phase_target_shifted(active, target)
          or (biter.commandable and not biter.commandable.has_command) then
        begin_phase_move(active, "to_target", target, C.BITERPORT_ARRIVAL_RADIUS, tick)
      end

    elseif active.phase == "returning" then
      local port = active.return_port_id and storage.biterports[active.return_port_id]
      if not port or not port.valid then
        port = nearest_valid_port(active)
        if port then active.return_port_id = port.unit_number end
      end
      if not port or not port.valid then
        finish_worker(active, tick, false)
        goto continue
      end
      local arrived = phase_is_arrived(active, biter, port, C.BITERPORT_ARRIVAL_RADIUS)
        and (active.phase_arrived_tick or phase_has_departed(active, biter, tick))
      if arrived then
        finish_worker(active, tick, true)
      elseif active.phase_target_unit_number ~= port.unit_number
          or (biter.commandable and not biter.commandable.has_command) then
        begin_phase_move(active, "returning", port, C.BITERPORT_ARRIVAL_RADIUS, tick)
      end

    else
      fail_job_and_return(active, tick)
    end

    ::continue::
  end
end

local function dispatch_job(worker_port, job)
  if not worker_port or not worker_port.valid or not job then return false end
  if not remove_dispatch_inputs(worker_port) then
    if job.kind == "construction" then restore_construction_ghost(job) end
    refresh_port_status(worker_port)
    return false
  end

  local biter = spawn_worker(worker_port, job.kind)
  if not biter or not biter.valid then
    maybe_reinsert_worker(worker_port)
    if job.kind == "construction" then restore_construction_ghost(job) end
    refresh_port_status(worker_port)
    return false
  end

  apply_job_tint(biter, job.kind)
  local active = {
    biter = biter,
    biter_unit_number = biter.unit_number,
    home_port_id = worker_port.unit_number,
    force = worker_port.force,
    job = job,
  }
  register_active_worker(active)
  mark_worker_unit(biter.unit_number, worker_port.unit_number)
  begin_phase_move(active, "to_pickup", job.source_destination or job.source, C.BITERPORT_ARRIVAL_RADIUS, game.tick)
  refresh_port_status(worker_port)
  return true
end

local function dispatch_network_jobs(network)
  local dispatched = 0

  while true do
    local job, worker_port = find_construction_job(network)
    if not job or not worker_port then break end
    if dispatch_job(worker_port, job) then
      dispatched = dispatched + 1
    else
      break
    end
  end

  while true do
    local job, worker_port = find_logistics_job(network)
    if not job or not worker_port then break end
    if dispatch_job(worker_port, job) then
      dispatched = dispatched + 1
    else
      break
    end
  end

  while true do
    local job, worker_port = find_player_delivery_job(network)
    if not job or not worker_port then break end
    if dispatch_job(worker_port, job) then
      dispatched = dispatched + 1
    else
      break
    end
  end

  while true do
    local job, worker_port = find_player_trash_job(network)
    if not job or not worker_port then break end
    if dispatch_job(worker_port, job) then
      dispatched = dispatched + 1
    else
      break
    end
  end

  return dispatched
end

function M.ensure_storage()
  ensure_worker_force()
  storage.biterports = storage.biterports or {}
  storage.biterport_hidden_roboports = storage.biterport_hidden_roboports or {}
  storage.biterport_coffee_inputs = storage.biterport_coffee_inputs or {}
  storage.biterport_workers = storage.biterport_workers or {}
  storage.biterport_active_by_port = storage.biterport_active_by_port or {}
  storage.biterport_worker_units = storage.biterport_worker_units or {}
end

function M.is_port(entity_or_name)
  local name = entity_or_name
  if type(entity_or_name) ~= "string" then
    name = entity_or_name and entity_or_name.name
  end
  return name == PORT_NAME
end

function M.is_hidden_roboport(entity_or_name)
  local name = entity_or_name
  if type(entity_or_name) ~= "string" then
    name = entity_or_name and entity_or_name.name
  end
  return name == HIDDEN_ROBOPORT_NAME
end

function M.is_worker_unit(unit_number)
  return unit_number
    and storage
    and storage.biterport_worker_units
    and storage.biterport_worker_units[unit_number] ~= nil
    or false
end

function M.track_port(entity)
  M.ensure_storage()
  if not entity or not entity.valid or not entity.unit_number or not M.is_port(entity) then return end
  storage.biterports[entity.unit_number] = entity
  apply_port_inventory(entity)
  create_hidden_roboport(entity)
  if working_hours.is_enabled() then
    create_hidden_coffee_input(entity)
  end
  refresh_port_status(entity)
end

function M.on_entity_built(event)
  M.ensure_storage()
  local entity = event and (event.entity or event.created_entity)
  if not entity or not entity.valid or entity.type ~= "entity-ghost" then
    return false
  end

  local network = find_network_for_position(
    entity.surface,
    entity.force,
    entity.position,
    C.BITERPORT_CONSTRUCTION_RADIUS
  )
  if not network then return false end

  local job, worker_port = find_construction_job_for_ghost(network, entity)
  if not job or not worker_port then return false end
  return dispatch_job(worker_port, job)
end

function M.untrack_port(entity, tick)
  M.ensure_storage()
  if not entity or not entity.unit_number then return end
  local port_id = entity.unit_number
  destroy_hidden_roboport(port_id)
  destroy_hidden_coffee_input(port_id)
  storage.biterports[port_id] = nil

  local active_set = storage.biterport_active_by_port[port_id]
  if active_set then
    local units = {}
    for unit_number in pairs(active_set) do units[#units + 1] = unit_number end
    for _, unit_number in ipairs(units) do
      local active = storage.biterport_workers[unit_number]
      if active then
        fail_job_and_return(active, tick or game.tick)
      end
    end
  end
end

function M.on_entity_removed(event)
  local entity = event and event.entity
  if not entity then return end
  if M.is_port(entity) then
    M.untrack_port(entity, event.tick or game.tick)
  elseif M.is_hidden_roboport(entity) and storage.biterport_hidden_roboports then
    for port_id, hidden in pairs(storage.biterport_hidden_roboports) do
      if hidden == entity then
        storage.biterport_hidden_roboports[port_id] = nil
        break
      end
    end
  elseif entity.name == COFFEE_INPUT_NAME and storage.biterport_coffee_inputs then
    for port_id, input in pairs(storage.biterport_coffee_inputs) do
      if input == entity then
        storage.biterport_coffee_inputs[port_id] = nil
        break
      end
    end
  end
end

function M.on_entity_died(event)
  local entity = event and event.entity
  if entity and entity.type == "unit" and entity.unit_number then
    local active = storage.biterport_workers and storage.biterport_workers[entity.unit_number]
    if active then
      if active.job and active.job.kind == "construction" and not active.job.built then
        restore_construction_ghost(active.job)
      elseif active.job and active.job.overlay_id then
        destroy_render(active.job.overlay_id)
        active.job.overlay_id = nil
      end
      return_carried_item(active, active.job and active.job.source)
      unmark_worker_unit(active.biter_unit_number)
      unregister_active_worker(active)
      local port = active.home_port_id and storage.biterports[active.home_port_id]
      if port and port.valid then refresh_port_status(port) end
      return
    end
  end
  M.on_entity_removed(event)
end

function M.on_ai_command_completed(event)
  if not event or not event.unit_number then return false end
  local active = storage.biterport_workers and storage.biterport_workers[event.unit_number]
  if not active then return false end
  local biter = active.biter
  if not biter or not biter.valid then return true end
  local destination = active.phase_destination
  if destination and phase_is_arrived(active, biter, destination, active.phase_command_radius) then
    active.phase_arrived_tick = event.tick or game.tick
  elseif destination then
    issue_move_command(biter, destination, active.phase_command_radius)
  end
  return true
end

function M.on_research_finished(research)
  if not research or not research.valid or not research.name then return end
  if not research.name:find("^biterport%-capacity%-") then return end

  M.ensure_storage()
  for _, port in pairs(storage.biterports or {}) do
    if port and port.valid and port.force == research.force then
      apply_port_inventory(port)
      refresh_port_status(port)
    end
  end
end

function M.rebuild_registry()
  M.ensure_storage()

  for _, active in pairs(storage.biterport_workers or {}) do
    if active.job and active.job.kind == "construction" and not active.job.built then
      restore_construction_ghost(active.job)
    end
    if active.biter and active.biter.valid then
      active.biter.destroy()
    end
  end

  for _, surface in pairs(game.surfaces) do
    for _, hidden in ipairs(surface.find_entities_filtered{name = HIDDEN_ROBOPORT_NAME}) do
      if hidden.valid then hidden.destroy() end
    end
    for _, input in ipairs(surface.find_entities_filtered{name = COFFEE_INPUT_NAME}) do
      if input.valid then input.destroy() end
    end
  end

  storage.biterports = {}
  storage.biterport_hidden_roboports = {}
  storage.biterport_coffee_inputs = {}
  storage.biterport_workers = {}
  storage.biterport_active_by_port = {}
  storage.biterport_worker_units = {}

  for _, surface in pairs(game.surfaces) do
    for _, port in ipairs(surface.find_entities_filtered{name = PORT_NAME}) do
      if port.valid and port.unit_number then
        M.track_port(port)
      end
    end
  end
end

function M.get_network_summary(port)
  M.ensure_storage()
  if not port or not port.valid then return nil end
  for _, network in ipairs(build_networks(port.surface, port.force)) do
    if network.port_set[port.unit_number] then
      local workers = 0
      for _, member in ipairs(network.ports) do
        workers = workers + port_worker_count(member)
      end
      return {
        ports = #network.ports,
        workers = workers,
        network = network,
      }
    end
  end
  return nil
end

function M.update(tick)
  M.ensure_storage()
  advance_active_workers(tick)
  if tick % C.BITERPORT_CHECK_TICKS ~= 0 then return end

  for _, network in ipairs(build_all_networks()) do
    dispatch_network_jobs(network)
  end

  for port_id, port in pairs(storage.biterports or {}) do
    if not port or not port.valid then
      destroy_hidden_roboport(port_id)
      storage.biterports[port_id] = nil
    else
      if not storage.biterport_hidden_roboports[port_id]
         or not storage.biterport_hidden_roboports[port_id].valid then
        create_hidden_roboport(port)
      end
      if working_hours.is_enabled()
         and (not storage.biterport_coffee_inputs[port_id]
           or not storage.biterport_coffee_inputs[port_id].valid) then
        create_hidden_coffee_input(port)
      end
      refresh_port_status(port)
    end
  end
end

return M
