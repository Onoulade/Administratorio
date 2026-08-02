local C = require("scripts.constants")
local quality = require("scripts.quality")
local working_hours = require("scripts.working_hours")
local unit_ai_settings = require("scripts.unit_ai_settings")

local M = {}
local biters_module = nil

local PORT_NAME = C.BITERPORT_NAME
local HIDDEN_ROBOPORT_NAME = C.BITERPORT_HIDDEN_ROBOPORT_NAME
local COFFEE_INPUT_NAME = "biterport-coffee-input"
local WALL_BLOCKER_NAME = "biterport-wall-blocker"
local WORKER_FORCE_NAME = "administratorio-biters"
local WORKER_ITEM_NAME = "biter-logistics-formation"
local MONEY_ITEM_NAME = "taxpayer-money"
local COFFEE_FLUID_NAME = "liquid-coffee"
local WORKER_ENTITY_NAME = C.BITERPORT_WORKER_ENTITY_NAME or "small-biter"
local FALLBACK_WORKER_ENTITY_NAME = "small-biter"
local PORT_WALL_OFFSETS = {
  {x = -2, y = -2}, {x = -1, y = -2}, {x = 1, y = -2}, {x = 2, y = -2},
  {x = -2, y = -1}, {x = 2, y = -1},
  {x = -2, y = 1}, {x = 2, y = 1},
  {x = -2, y = 2}, {x = -1, y = 2}, {x = 1, y = 2}, {x = 2, y = 2},
}
local PORT_DESPAWN_INTERIOR_OFFSET = {x = 0, y = 0}
local PORT_SPAWN_INTERIOR_OFFSET = {x = 0, y = 0}

local TRANSPORT_TIER_TECHS = {
  {"biterport-transport-capacity-1", 2},
  {"biterport-transport-capacity-2", 5},
  {"biterport-transport-capacity-3", 10},
  {"biterport-transport-capacity-4", 25},
}

local SPEED_TIER_TECHS = {
  {"biterport-worker-speed-2", C.BITERPORT_WORKER_EXPRESS_ENTITY_NAME},
  {"biterport-worker-speed-1", C.BITERPORT_WORKER_FAST_ENTITY_NAME},
}

local SOURCE_CHEST_NAMES = {
  [C.BITERPORT_CRAPPY_PASSIVE_PROVIDER_CHEST] = true,
  [C.BITERPORT_CRAPPY_STORAGE_CHEST] = true,
}

local REQUESTER_CHEST_NAMES = {
  [C.BITERPORT_CRAPPY_REQUESTER_CHEST] = true,
}

local STORAGE_CHEST_NAMES = {
  [C.BITERPORT_CRAPPY_STORAGE_CHEST] = true,
}

local LOGISTIC_CHEST_NAMES = {
  [C.BITERPORT_CRAPPY_PASSIVE_PROVIDER_CHEST] = true,
  [C.BITERPORT_CRAPPY_STORAGE_CHEST] = true,
  [C.BITERPORT_CRAPPY_REQUESTER_CHEST] = true,
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

-- Biterport jobs must identify a stack by both prototype and certification
-- grade.  Missing legacy fields deliberately mean normal, never "any grade".
local function normalized_quality_name(value)
  local name = quality.name(value)
  return name == "" and "normal" or name
end

local function item_identity_key(item_name, quality_name)
  return tostring(item_name or "") .. "\31" .. normalized_quality_name(quality_name)
end

local function stack_identity(stack)
  -- Empty inventory slots are LuaItemStacks too, but Factorio forbids reading
  -- fields such as name or quality until valid_for_read is true.
  if not stack or not stack.valid_for_read then return nil, "normal" end
  if not stack.name then return nil, "normal" end
  return stack.name, normalized_quality_name(stack)
end

local function exact_stack(item_name, count, quality_name)
  return {
    name = item_name,
    count = count,
    quality = normalized_quality_name(quality_name),
  }
end

local function job_quality_name(job)
  return normalized_quality_name(job and (job.item_quality or job.quality))
end

local function inventory_exact_count(inventory, item_name, quality_name)
  if not inventory or not item_name then return 0 end
  local normalized = normalized_quality_name(quality_name)
  local slots = #inventory
  if slots > 0 then
    local count = 0
    for index = 1, slots do
      local stack = inventory[index]
      local stack_name, stack_quality = stack_identity(stack)
      if stack_name == item_name and stack_quality == normalized then
        count = count + (stack.count or 0)
      end
    end
    return count
  end
  if inventory.get_item_count then
    local ok, count = pcall(inventory.get_item_count, exact_stack(item_name, 1, normalized))
    if ok then return count or 0 end
    if normalized == "normal" then
      ok, count = pcall(inventory.get_item_count, item_name)
      if ok then return count or 0 end
    end
  end
  return 0
end

local function port_logistics_radius(port)
  return C.BITERPORT_LOGISTICS_RADIUS * quality.infrastructure_multiplier(port)
end

local function port_construction_radius(port)
  return C.BITERPORT_CONSTRUCTION_RADIUS * quality.infrastructure_multiplier(port)
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

local function rotate_local_offset(offset, direction)
  direction = direction or defines.direction.north
  if direction == defines.direction.east then
    return {x = -offset.y, y = offset.x}
  elseif direction == defines.direction.south then
    return {x = -offset.x, y = -offset.y}
  elseif direction == defines.direction.west then
    return {x = offset.y, y = -offset.x}
  end
  return {x = offset.x, y = offset.y}
end

local function offset_position(entity, offset)
  local position = entity and entity.position or {x = 0, y = 0}
  return {x = position.x + offset.x, y = position.y + offset.y}
end

local function current_tick(fallback_tick)
  if fallback_tick ~= nil then return fallback_tick end
  return game and game.tick or 0
end

local function debug_position(pos)
  if not pos then return "[nil]" end
  return "[" .. tostring(pos.x) .. "," .. tostring(pos.y) .. "]"
end

local function debug_force_name(force)
  if not force then return "nil" end
  return force.name or tostring(force)
end

local function debug_entity_summary(entity)
  if not entity then return "entity=nil" end
  local ok_valid, valid = pcall(function() return entity.valid end)
  if not ok_valid or not valid then return "entity=invalid" end
  local ok_name, name = pcall(function() return entity.name end)
  local ok_unit, unit_number = pcall(function() return entity.unit_number end)
  local ok_force, force = pcall(function() return entity.force end)
  local ok_active, active = pcall(function() return entity.active end)
  local ok_position, position = pcall(function() return entity.position end)
  local ok_has_command, has_command = pcall(function()
    return entity.commandable and entity.commandable.has_command or false
  end)
  local ok_command, command = pcall(function()
    return entity.commandable and entity.commandable.command or nil
  end)
  return "entity_unit=" .. tostring(ok_unit and unit_number or "nil")
    .. " entity_name=" .. tostring(ok_name and name or "nil")
    .. " entity_force=" .. debug_force_name(ok_force and force or nil)
    .. " entity_active=" .. (ok_active and tostring(active) or "n/a")
    .. " entity_pos=" .. tostring(ok_position and debug_position(position) or "[nil]")
    .. " entity_has_command=" .. (ok_has_command and tostring(has_command) or "n/a")
    .. " entity_command=" .. tostring(ok_command and command and command.type or "nil")
end

local function worker_debug_log(label, active, extra)
  if not log then return end
  local parts = {
    "[administratorio-biterport-worker]",
    "tick=" .. tostring(current_tick()),
    "label=" .. tostring(label),
    "worker_unit=" .. tostring(active and active.biter_unit_number or "nil"),
    "phase=" .. tostring(active and active.phase or "nil"),
    "home_port=" .. tostring(active and active.home_port_id or "nil"),
    "return_port=" .. tostring(active and active.return_port_id or "nil"),
    "job=" .. tostring(active and active.job and active.job.kind or "nil"),
    "force=" .. debug_force_name(active and active.force or nil),
    debug_entity_summary(active and active.biter or nil),
  }
  if extra then parts[#parts + 1] = tostring(extra) end
  log(table.concat(parts, " "))
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
  if not force or force.valid == false or not force.technologies then return false end
  local tech = force.technologies[tech_name]
  return tech and tech.researched or false
end

local function get_transport_capacity_for_force(force)
  local capacity = 1
  for _, tier in ipairs(TRANSPORT_TIER_TECHS) do
    if force_has_researched(force, tier[1]) then
      capacity = tier[2]
    else
      break
    end
  end
  return capacity
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
  local target = C.BITERPORT_WORKER_SLOTS + 1
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

local function prune_worker_cooldowns(port_id, tick)
  if not port_id or not storage.biterport_worker_cooldowns then return 0 end
  local cooldowns = storage.biterport_worker_cooldowns[port_id]
  if not cooldowns then return 0 end

  local now = current_tick(tick)
  local kept = 0
  for i = 1, #cooldowns do
    local ready_tick = cooldowns[i]
    if ready_tick and ready_tick > now then
      kept = kept + 1
      cooldowns[kept] = ready_tick
    end
  end
  for i = kept + 1, #cooldowns do
    cooldowns[i] = nil
  end

  if kept <= 0 then
    storage.biterport_worker_cooldowns[port_id] = nil
    return 0
  end
  return kept
end

local function add_worker_cooldown(port_id, ready_tick)
  if not port_id or not ready_tick then return end
  storage.biterport_worker_cooldowns = storage.biterport_worker_cooldowns or {}
  local cooldowns = storage.biterport_worker_cooldowns[port_id]
  if not cooldowns then
    cooldowns = {}
    storage.biterport_worker_cooldowns[port_id] = cooldowns
  end
  cooldowns[#cooldowns + 1] = ready_tick
end

local function port_available_worker_count(port, tick)
  if not port or not port.valid or not port.unit_number then return 0 end
  local cooling = prune_worker_cooldowns(port.unit_number, tick)
  return math.max(0, port_worker_count(port) - cooling)
end

local function port_money_count(port)
  local inv = get_station_inventory(port)
  return inv and inv.get_item_count and inv.get_item_count(MONEY_ITEM_NAME) or 0
end

local function hidden_coffee_input_position(entity)
  return entity and entity.position or {x = 0, y = 0}
end

local function port_blocker_area(port)
  local pos = port and port.position or {x = 0, y = 0}
  return {
    {x = pos.x - 2.5, y = pos.y - 2.5},
    {x = pos.x + 2.5, y = pos.y + 2.5},
  }
end

local function destroy_wall_blockers(port)
  if not port or not port.valid then return end
  local blockers = port.surface.find_entities_filtered{
    name = WALL_BLOCKER_NAME,
    area = port_blocker_area(port),
  }
  for _, blocker in ipairs(blockers) do
    if blocker.valid then blocker.destroy() end
  end
end

local function create_wall_blockers(port)
  if not port or not port.valid then return end
  destroy_wall_blockers(port)
  for _, offset in ipairs(PORT_WALL_OFFSETS) do
    local blocker = port.surface.create_entity{
      name = WALL_BLOCKER_NAME,
      position = offset_position(port, offset),
      force = port.force,
      create_build_effect_smoke = false,
    }
    if blocker and blocker.valid then
      blocker.destructible = false
      blocker.minable = false
      blocker.operable = false
    end
  end
end

local function port_spawn_position(port)
  return offset_position(port, PORT_SPAWN_INTERIOR_OFFSET)
end

local function port_despawn_position(port)
  return offset_position(port, PORT_DESPAWN_INTERIOR_OFFSET)
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
    position = hidden_coffee_input_position(port),
    direction = defines.direction.north,
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

local function port_can_dispatch(port, tick)
  local now = current_tick(tick)
  local next_tick = port and port.unit_number
    and storage.biterport_next_dispatch_ticks
    and storage.biterport_next_dispatch_ticks[port.unit_number]
    or nil
  return port and port.valid
    and (not next_tick or next_tick <= now)
    and port_available_worker_count(port, tick) > 0
    and port_money_count(port) >= C.BITERPORT_WORKER_SALARY
    and has_dispatch_coffee(port)
end

local function mark_port_dispatched(port, tick)
  if not port or not port.valid or not port.unit_number then return end
  storage.biterport_next_dispatch_ticks = storage.biterport_next_dispatch_ticks or {}
  storage.biterport_next_dispatch_ticks[port.unit_number] =
    current_tick(tick) + C.BITERPORT_DISPATCH_COOLDOWN_TICKS
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
    if normalized_quality_name(hidden) == normalized_quality_name(port) then
      return hidden
    end
    hidden.destroy()
    storage.biterport_hidden_roboports[port.unit_number] = nil
  end
  local created = port.surface.create_entity{
    name = HIDDEN_ROBOPORT_NAME,
    position = port.position,
    force = port.force,
    quality = normalized_quality_name(port),
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
  deconstruction = {r = 1.0, g = 0.55, b = 0.25},
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
  local item_quality = normalized_quality_name(quality_proto)
  return {
    kind = "construction",
    construction_type = ghost.type == "tile-ghost" and "tile" or "entity",
    item_name = item_name,
    item_quality = item_quality,
    item_key = item_identity_key(item_name, item_quality),
    count = 1,
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
    quality = item_quality,
    tags = safe_entity_field(ghost, "tags"),
  }
end

local function snapshot_deconstruction(entity)
  if not entity or not entity.valid then return nil end
  return {
    kind = "deconstruction",
    deconstruction_type = "entity",
    target = entity,
    source = entity,
    surface = entity.surface,
    force_name = entity.force and entity.force.name or nil,
    position = copy_position(entity.position),
    bounding_box = copy_box(safe_entity_field(entity, "bounding_box")),
    item_quality = normalized_quality_name(entity),
  }
end

local function snapshot_tile_deconstruction(tile, force)
  if not tile or not tile.valid then return nil end
  local proto = tile.prototype
  local item_name = nil
  local items = proto and proto.items_to_place_this
  if items and items[1] and items[1].name then
    item_name = items[1].name
  end
  item_name = item_name or tile.name
  local hidden_tile = tile.surface and tile.surface.get_hidden_tile and tile.surface.get_hidden_tile(tile.position)
    or safe_entity_field(tile, "hidden_tile")
  if type(hidden_tile) == "table" then
    hidden_tile = hidden_tile.name
  end
  return {
    kind = "deconstruction",
    deconstruction_type = "tile",
    target = tile,
    source = tile,
    surface = tile.surface,
    force_name = force and force.name or nil,
    position = copy_position(tile.position),
    item_name = item_name,
    item_quality = "normal",
    replacement_tile = hidden_tile or "grass-1",
  }
end

local function snapshot_tile_proxy_deconstruction(proxy, force)
  if not proxy or not proxy.valid or not proxy.surface then return nil end
  local tile = proxy.surface.get_tile and proxy.surface.get_tile(proxy.position)
  local job = snapshot_tile_deconstruction(tile, force)
  if not job then return nil end
  job.target = proxy
  job.tile_position = copy_position(tile.position)
  local unit_number = safe_entity_field(proxy, "unit_number")
  if unit_number then job.deconstruction_key = "entity:" .. tostring(unit_number) end
  return job
end

local function snapshot_loose_item_deconstruction(item_entity)
  if not item_entity or not item_entity.valid then return nil end
  local stack = safe_entity_field(item_entity, "stack")
  if not stack or not stack.valid_for_read or not stack.name then return nil end
  if item_entity.order_deconstruction and not item_entity.to_be_deconstructed() then
    pcall(function() item_entity.order_deconstruction(item_entity.force or game.forces.player) end)
  end
  return {
    kind = "deconstruction",
    deconstruction_type = "loose_item",
    target = item_entity,
    source = item_entity,
    surface = item_entity.surface,
    force_name = item_entity.force and item_entity.force.name or nil,
    position = copy_position(item_entity.position),
    item_name = stack.name,
    item_quality = normalized_quality_name(stack),
    count = stack.count or 1,
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

local active_logistics_item_count
local active_construction_item_count

local function deconstruction_reservation_key(target)
  if not target then return nil end
  local unit_number = safe_entity_field(target, "unit_number")
  if unit_number then return "entity:" .. tostring(unit_number) end
  local position = safe_entity_field(target, "position")
  local surface = safe_entity_field(target, "surface")
  if position and surface then
    return "tile:" .. tostring(surface.index or 0) .. ":" .. tostring(math.floor(position.x)) .. ":" .. tostring(math.floor(position.y))
  end
  return nil
end

local function job_deconstruction_key(job)
  if not job then return nil end
  return job.deconstruction_key or deconstruction_reservation_key(job.target)
end

local function is_deconstruction_reserved(target)
  local key = deconstruction_reservation_key(target)
  return key and storage.biterport_deconstruction_reservations and storage.biterport_deconstruction_reservations[key] ~= nil
end

local function reserve_deconstruction_job(job)
  if not job or job.kind ~= "deconstruction" then return true end
  local key = job_deconstruction_key(job)
  if not key then return false end
  storage.biterport_deconstruction_reservations = storage.biterport_deconstruction_reservations or {}
  if storage.biterport_deconstruction_reservations[key] then return false end
  job.deconstruction_key = key
  storage.biterport_deconstruction_reservations[key] = {
    tick = game and game.tick or 0,
    type = job.deconstruction_type,
  }
  return true
end

local function release_deconstruction_reservation(job)
  local key = job_deconstruction_key(job)
  if key and storage.biterport_deconstruction_reservations then
    storage.biterport_deconstruction_reservations[key] = nil
  end
  if job then job.deconstruction_key = nil end
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

local function source_available_item_count(source, item_name, item_quality)
  local inv = get_entity_inventory(source)
  if not inv then return 0 end
  local available = inventory_exact_count(inv, item_name, item_quality)
  local unit_number = safe_entity_field(source, "unit_number")
  if unit_number then
    available = available - active_logistics_item_count("source_unit_number", unit_number, item_name, item_quality)
    if active_construction_item_count then
      available = available - active_construction_item_count(unit_number, item_name, item_quality)
    end
  end
  return math.max(0, available)
end

local function is_logistic_chest(entity)
  if not entity or not entity.valid then return false end
  if LOGISTIC_CHEST_NAMES[entity.name] then return true end
  return false
end

local function is_source_chest(entity)
  if not entity or not entity.valid then return false end
  if SOURCE_CHEST_NAMES[entity.name] then return true end
  return false
end

local function is_requester_chest(entity)
  if not entity or not entity.valid then return false end
  if REQUESTER_CHEST_NAMES[entity.name] then return true end
  return false
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

  local link_sq = C.BITERPORT_LOGISTICS_CONNECTION_DISTANCE * C.BITERPORT_LOGISTICS_CONNECTION_DISTANCE
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

local function network_storage_key(network)
  if not network or not network.surface or not network.force or not network.ports or not network.ports[1] then
    return nil
  end
  return tostring(network.surface.index)
    .. ":"
    .. network.force.name
    .. ":"
    .. tostring(network.ports[1].unit_number or 0)
end

local function position_in_network_radius(network, position, radius)
  for _, port in ipairs(network.ports) do
    local scaled_radius = radius * quality.infrastructure_multiplier(port)
    local radius_sq = scaled_radius * scaled_radius
    if distance_squared(port.position, position) <= radius_sq then
      return true
    end
  end
  return false
end

local function port_scan_area(port, radius, subdivisions, tick, salt)
  subdivisions = math.max(1, subdivisions or 1)
  if subdivisions == 1 then
    return radius_box(port.position, radius)
  end

  local total = subdivisions * subdivisions
  local cycle = math.floor(current_tick(tick) / math.max(1, C.BITERPORT_CHECK_TICKS))
  local phase = ((cycle + (port.unit_number or 0) + (salt or 0)) % total)
  local row = math.floor(phase / subdivisions)
  local col = phase % subdivisions
  local step = (radius * 2) / subdivisions
  local left = port.position.x - radius + (col * step)
  local top = port.position.y - radius + (row * step)
  local right = col == (subdivisions - 1) and (port.position.x + radius) or (left + step)
  local bottom = row == (subdivisions - 1) and (port.position.y + radius) or (top + step)
  return {
    left_top = {x = left, y = top},
    right_bottom = {x = right, y = bottom},
  }
end

local function logistic_chest_key(chest)
  if not chest then return nil end
  if chest.unit_number then return tostring(chest.unit_number) end
  return chest.name .. "@" .. math.floor(chest.position.x) .. "," .. math.floor(chest.position.y)
end

local function for_each_logistic_chest(network, callback, options)
  options = options or {}
  local full_scan = options.full_scan == true
  local tick = options.tick
  local seen = {}
  for _, port in ipairs(network.ports) do
    local area = full_scan
      and radius_box(port.position, port_logistics_radius(port))
      or port_scan_area(
        port,
        port_logistics_radius(port),
        C.BITERPORT_LOGISTICS_SCAN_SUBDIVISIONS,
        tick,
        0
      )
    local chests = network.surface.find_entities_filtered{
      type = "logistic-container",
      area = area,
      force = network.force,
      limit = C.BITERPORT_MAX_CHESTS_PER_PORT_SCAN,
    }
    for _, chest in ipairs(chests) do
      local key = logistic_chest_key(chest)
      if chest.valid and is_logistic_chest(chest) and not seen[key] then
        seen[key] = true
        if callback(chest) then return true end
      end
    end
  end
  return false
end

local function collect_logistic_chests(network, options)
  local chests = {}
  for_each_logistic_chest(network, function(chest)
    chests[#chests + 1] = chest
    return false
  end, options)
  return chests
end

active_logistics_item_count = function(key_name, key_value, item_name, item_quality)
  if not key_name or key_value == nil then return 0 end
  local count = 0
  for _, reservation in pairs(storage.biterport_logistics_reservations or {}) do
    if reservation
       and reservation[key_name] == key_value
       and reservation.item_name == item_name
       and normalized_quality_name(reservation.item_quality) == normalized_quality_name(item_quality) then
      count = count + (reservation.count or 1)
    end
  end
  for _, active in pairs(storage.biterport_workers or {}) do
    local job = active.job
    if job and job.kind == "logistics"
       and not job.reservation_id
       and job[key_name] == key_value
       and job.item_name == item_name
       and job_quality_name(job) == normalized_quality_name(item_quality) then
      count = count + (job.count or 1)
    end
  end
  return count
end

active_construction_item_count = function(source_unit_number, item_name, item_quality)
  if not source_unit_number or not item_name then return 0 end
  local count = 0
  for _, active in pairs(storage.biterport_workers or {}) do
    local job = active.job
    local source = job and job.source
    if job and job.kind == "construction"
       and job.item_name == item_name
       and job_quality_name(job) == normalized_quality_name(item_quality)
       and source and safe_entity_field(source, "unit_number") == source_unit_number then
      count = count + (job.count or 1)
    end
  end
  return count
end

local function find_source_for_item_in_chests(chests, item_name, item_quality, position, excluded_unit_number)
  local best, best_inv, best_score = nil, nil, math.huge
  for _, chest in ipairs(chests or {}) do
    if is_source_chest(chest) and chest.unit_number ~= excluded_unit_number then
      local inv = get_entity_inventory(chest)
      local available = inventory_exact_count(inv, item_name, item_quality)
      available = available - active_logistics_item_count("source_unit_number", chest.unit_number, item_name, item_quality)
      available = available - active_construction_item_count(chest.unit_number, item_name, item_quality)
      if inv and available > 0 then
        local score = position and distance_squared(chest.position, position) or 0
        if score < best_score then
          best = chest
          best_inv = inv
          best_score = score
        end
      end
    end
  end
  return best, best_inv
end

local function find_source_for_item(network, item_name, item_quality, position, excluded_unit_number, tick)
  local chests = collect_logistic_chests(network, {full_scan = true, tick = tick})
  return find_source_for_item_in_chests(chests, item_name, item_quality, position, excluded_unit_number)
end

local function choose_worker_port(network, pickup_position, target_position, tick)
  local best, best_score = nil, math.huge
  for _, port in ipairs(network.ports) do
    if port_can_dispatch(port, tick) then
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

local function find_construction_job(network, tick, ghost_type)
  local transport_capacity = get_transport_capacity_for_force(network.force)
  for _, port in ipairs(network.ports) do
    local area = port_scan_area(
      port,
      port_construction_radius(port),
      C.BITERPORT_CONSTRUCTION_SCAN_SUBDIVISIONS,
      tick,
      13
    )
    local ghosts = network.surface.find_entities_filtered{
      type = ghost_type or "entity-ghost",
      area = area,
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
          local item_quality = normalized_quality_name(ghost)
          local source = find_source_for_item(network, item_name, item_quality, ghost.position, nil, tick)
          if source and source.valid then
            local worker_port = choose_worker_port(network, source.position, ghost.position, tick)
            if worker_port then
              local job = claim_ghost(ghost, source)
              if job then
                job.count = math.max(1, math.min(transport_capacity, source_available_item_count(source, item_name, item_quality)))
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
  local item_quality = normalized_quality_name(ghost)

  local tick = current_tick()
  local source = find_source_for_item(network, item_name, item_quality, ghost.position, nil, tick)
  if not source or not source.valid then return nil, nil end

  local worker_port = choose_worker_port(network, source.position, ghost.position, tick)
  if not worker_port then return nil, nil end

  local job = claim_ghost(ghost, source)
  if not job then return nil, nil end
  job.count = math.max(1, math.min(get_transport_capacity_for_force(network.force), source_available_item_count(source, item_name, item_quality)))
  return job, worker_port
end

local function find_next_carried_construction_job(active, tick)
  local current = active and active.job
  local stack = active and active.carried_stack
  if not current or not stack or (stack.count or 0) <= 0 or not current.surface then return nil end
  local network = find_network_for_position(
    current.surface,
    game and game.forces and current.force_name and game.forces[current.force_name] or active.force,
    current.position or (active.biter and active.biter.valid and active.biter.position),
    C.BITERPORT_CONSTRUCTION_RADIUS
  )
  if not network then return nil end
  local target_type = current.construction_type == "tile" and "tile-ghost" or "entity-ghost"

  for _, port in ipairs(network.ports) do
    local area = port_scan_area(
      port,
      port_construction_radius(port),
      C.BITERPORT_CONSTRUCTION_SCAN_SUBDIVISIONS,
      tick,
      current.construction_type == "tile" and 29 or 17
    )
    local ghosts = network.surface.find_entities_filtered{
      type = target_type,
      area = area,
      force = network.force,
      limit = C.BITERPORT_MAX_GHOSTS_PER_PORT_SCAN,
    }
    table.sort(ghosts, function(a, b)
      return distance_squared(a.position, active.biter.position) < distance_squared(b.position, active.biter.position)
    end)
    for _, ghost in ipairs(ghosts) do
      if ghost.valid
         and position_in_network_radius(network, ghost.position, C.BITERPORT_CONSTRUCTION_RADIUS)
         and get_ghost_item_name(ghost) == stack.name
         and normalized_quality_name(ghost) == normalized_quality_name(stack) then
        local job = claim_ghost(ghost, current.source)
        if job then return job end
      end
    end
  end
  return nil
end

local function requester_filters(entity)
  if not entity or not entity.valid or not entity.get_requester_point then return nil end
  local ok, point = pcall(entity.get_requester_point)
  if not ok or not point or not point.valid or point.enabled == false then return nil end
  return point.filters
end

local function logistic_filter_item_name(filter)
  if not filter then return nil end
  if filter.name then return filter.name end
  local value = filter.value
  if type(value) == "string" then return value end
  if type(value) == "table" then return value.name end
  return nil
end

local function logistic_filter_quality_name(filter)
  if not filter then return "normal" end
  if filter.quality then return normalized_quality_name(filter.quality) end
  local value = filter.value
  if type(value) == "table" and value.quality then
    return normalized_quality_name(value.quality)
  end
  -- A requester filter without a grade is intentionally normal-only.
  return "normal"
end

local function logistic_filter_min_count(filter)
  if not filter then return 0 end
  return filter.count or filter.min or 0
end

local function copy_logistic_filter(filter)
  if type(filter) ~= "table" then return filter end
  local copied = {}
  for key, value in pairs(filter) do
    if type(value) == "table" then
      local nested = {}
      for nested_key, nested_value in pairs(value) do
        nested[nested_key] = nested_value
      end
      copied[key] = nested
    else
      copied[key] = value
    end
  end
  return copied
end

local function set_logistic_filter_min_count(filter, count)
  local adjusted = copy_logistic_filter(filter) or {}
  count = math.max(0, count or 0)
  if adjusted.count ~= nil then
    adjusted.count = count
  else
    adjusted.min = count
  end
  return adjusted
end

local function find_request_slot(entity, item_name, item_quality)
  if not entity or not entity.valid or not entity.get_requester_point then return nil end
  local ok, point = pcall(entity.get_requester_point)
  if not ok or not point or not point.valid then return nil end

  local sections = point.sections
  if sections then
    for _, section in ipairs(sections) do
      if section and section.valid ~= false and section.filters_count then
        for slot_index = 1, section.filters_count do
          local slot_ok, filter = pcall(section.get_slot, slot_index)
          if slot_ok and logistic_filter_item_name(filter) == item_name
             and logistic_filter_quality_name(filter) == normalized_quality_name(item_quality) then
            return section, slot_index, filter
          end
        end
      end
    end
  end

  if point.sections_count and point.get_section then
    for section_index = 1, point.sections_count do
      local section_ok, section = pcall(point.get_section, section_index)
      if section_ok and section and section.valid ~= false and section.filters_count then
        for slot_index = 1, section.filters_count do
          local slot_ok, filter = pcall(section.get_slot, slot_index)
          if slot_ok and logistic_filter_item_name(filter) == item_name
             and logistic_filter_quality_name(filter) == normalized_quality_name(item_quality) then
            return section, slot_index, filter
          end
        end
      end
    end
  end

  return nil
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

local function has_active_logistics_job(key_name, key_value, item_name, item_quality)
  if not key_name or key_value == nil then return false end
  for _, reservation in pairs(storage.biterport_logistics_reservations or {}) do
    if reservation
       and reservation[key_name] == key_value
       and reservation.item_name == item_name
       and normalized_quality_name(reservation.item_quality) == normalized_quality_name(item_quality) then
      return true
    end
  end
  for _, active in pairs(storage.biterport_workers or {}) do
    local job = active.job
    if job and job.kind == "logistics"
       and job[key_name] == key_value
       and job.item_name == item_name
       and job_quality_name(job) == normalized_quality_name(item_quality) then
      return true
    end
  end
  return false
end

local function counted_items(subject, inv, item_name, item_quality)
  local stack = exact_stack(item_name, 1, item_quality)
  if subject and subject.valid and subject.get_item_count then
    local ok, count = pcall(subject.get_item_count, stack)
    if ok then return count or 0 end
  end
  return inventory_exact_count(inv, item_name, item_quality)
end

local function requested_missing_stack(entity, inv, tracking_key, counted_subject, max_count)
  local filters = requester_filters(entity)
  if not filters then return nil end
  for _, filter in ipairs(filters) do
    local item_name = logistic_filter_item_name(filter)
    local item_quality = logistic_filter_quality_name(filter)
    local target = logistic_filter_min_count(filter)
    if item_name and target > 0 then
      local in_flight_key = tracking_key and "target_tracking_key" or "target_unit_number"
      local in_flight_value = tracking_key or entity.unit_number
      if has_active_logistics_job(in_flight_key, in_flight_value, item_name, item_quality) then
        goto next_filter
      end
      local current = counted_items(counted_subject or entity, inv, item_name, item_quality)
      if current < target then
        return item_name, item_quality, math.min(max_count or 1, target - current)
      end
    end
    ::next_filter::
  end
  return nil
end

local function restore_logistics_reservation(reservation)
  if not reservation or not reservation.section or not reservation.slot_index or not reservation.original_filter then
    return
  end
  local section = reservation.section
  if section.valid == false or not section.set_slot then return end
  pcall(section.set_slot, reservation.slot_index, copy_logistic_filter(reservation.original_filter))
end

local function release_logistics_reservation(job)
  local reservation_id = job and job.reservation_id
  if not reservation_id or not storage.biterport_logistics_reservations then return end
  local reservation = storage.biterport_logistics_reservations[reservation_id]
  restore_logistics_reservation(reservation)
  storage.biterport_logistics_reservations[reservation_id] = nil
  job.reservation_id = nil
end

local function create_logistics_reservation(job)
  if not job or job.kind ~= "logistics" or job.reservation_id then return true end
  storage.biterport_next_logistics_reservation_id = (storage.biterport_next_logistics_reservation_id or 0) + 1
  local reservation_id = storage.biterport_next_logistics_reservation_id
  local reservation = {
    id = reservation_id,
    item_name = job.item_name,
    item_quality = job_quality_name(job),
    count = job.count or 1,
    source_unit_number = safe_entity_field(job.source, "unit_number"),
    source_tracking_key = job.source_tracking_key,
    target_unit_number = job.target_unit_number,
    target_tracking_key = job.target_tracking_key,
  }

  local section, slot_index, filter = find_request_slot(job.target, job.item_name, job_quality_name(job))
  if section and slot_index and filter and section.set_slot then
    local target_inv = job.target_tracking_key and get_player_main_inventory(job.target)
      or get_entity_inventory(job.target)
    local current_count = counted_items(job.target, target_inv, job.item_name, job_quality_name(job))
    local adjusted = set_logistic_filter_min_count(filter, current_count)
    local ok = pcall(section.set_slot, slot_index, adjusted)
    if ok then
      reservation.section = section
      reservation.slot_index = slot_index
      reservation.original_filter = copy_logistic_filter(filter)
    end
  end

  storage.biterport_logistics_reservations[reservation_id] = reservation
  job.reservation_id = reservation_id
  return true
end

local function find_trash_target(network, item_name, item_quality, position, tick, count)
  local network_key = network_storage_key(network)
  local cache = network_key
    and storage.biterport_storage_target_cache
    and storage.biterport_storage_target_cache[network_key]
    or nil
  local cache_key = item_identity_key(item_name, item_quality)
  local cached_unit = cache and cache[cache_key] or nil
  if cached_unit then
    for _, chest in ipairs(collect_logistic_chests(network, {full_scan = false, tick = tick})) do
      if chest.unit_number == cached_unit and STORAGE_CHEST_NAMES[chest.name] then
        local inv = get_entity_inventory(chest)
        if inv and inv.insert
           and (not inv.can_insert or inv.can_insert(exact_stack(item_name, count or 1, item_quality))) then
          return chest
        end
        break
      end
    end
  end

  local best, best_score = nil, math.huge
  for_each_logistic_chest(network, function(chest)
    if not STORAGE_CHEST_NAMES[chest.name] then return false end
    local inv = get_entity_inventory(chest)
    if not inv or not inv.insert then return false end
    if inv.can_insert and not inv.can_insert(exact_stack(item_name, count or 1, item_quality)) then
      return false
    end

    local score = position and distance_squared(chest.position, position) or 0
    if inventory_exact_count(inv, item_name, item_quality) > 0 then
      score = score - 25
    end
    if score < best_score then
      best = chest
      best_score = score
    end
    return false
  end, {full_scan = true, tick = tick})
  if network_key and best and best.unit_number then
    storage.biterport_storage_target_cache = storage.biterport_storage_target_cache or {}
    storage.biterport_storage_target_cache[network_key] = storage.biterport_storage_target_cache[network_key] or {}
    storage.biterport_storage_target_cache[network_key][cache_key] = best.unit_number
  end
  return best
end

local function next_player_trash_stack(player, max_count)
  local inv = get_player_trash_inventory(player)
  local tracking_key = make_player_tracking_key(player)
  if not inv then return nil end
  for i = 1, #inv do
    local stack = inv[i]
    if stack and stack.valid_for_read and stack.name and stack.count and stack.count > 0 then
      local item_name, item_quality = stack_identity(stack)
      local total = inventory_exact_count(inv, item_name, item_quality)
      if not has_active_logistics_job("source_tracking_key", tracking_key, item_name, item_quality) then
        return item_name, item_quality, math.min(max_count or 1, total), inv
      end
    end
  end
  return nil
end

local function find_logistics_job(network, tick)
  local candidates = {}
  local transport_capacity = get_transport_capacity_for_force(network.force)
  local chests = collect_logistic_chests(network, {full_scan = true, tick = tick})
  for _, requester in ipairs(chests) do
    if is_requester_chest(requester) then
      local target_inv = get_entity_inventory(requester)
      if target_inv and target_inv.insert then
        local item_name, item_quality, count = requested_missing_stack(requester, target_inv, nil, nil, transport_capacity)
        if item_name then
          local source = find_source_for_item_in_chests(chests, item_name, item_quality, requester.position, requester.unit_number)
          if source and source.valid then
            local worker_port = choose_worker_port(network, source.position, requester.position, tick)
            if worker_port then
              candidates[#candidates + 1] = {
                requester = requester,
                key = logistic_chest_key(requester),
                worker_port = worker_port,
                job = {
                  kind = "logistics",
                  item_name = item_name,
                  item_quality = item_quality,
                  item_key = item_identity_key(item_name, item_quality),
                  count = count or 1,
                  source = source,
                  target = requester,
                  target_unit_number = requester.unit_number,
                },
              }
            end
          end
        end
      end
    end
  end

  if #candidates <= 0 then return nil, nil end
  table.sort(candidates, function(a, b)
    local ar, br = a.requester, b.requester
    local ax, bx = ar.position and ar.position.x or 0, br.position and br.position.x or 0
    if ax ~= bx then return ax < bx end
    local ay, by = ar.position and ar.position.y or 0, br.position and br.position.y or 0
    if ay ~= by then return ay < by end
    return (ar.unit_number or 0) < (br.unit_number or 0)
  end)

  local network_key = network_storage_key(network)
  local cursor = network_key
    and storage.biterport_logistics_request_cursors
    and storage.biterport_logistics_request_cursors[network_key]
    or nil
  local selected_index = 1
  if cursor then
    for i, candidate in ipairs(candidates) do
      if candidate.key == cursor then
        selected_index = (i % #candidates) + 1
        break
      end
    end
  end

  local selected = candidates[selected_index]
  selected.job.network_key = network_key
  selected.job.request_cursor_key = selected.key
  return selected.job, selected.worker_port
end

local function find_player_delivery_job(network, tick)
  local transport_capacity = get_transport_capacity_for_force(network.force)
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
        local item_name, item_quality, count = requested_missing_stack(player, target_inv, tracking_key, player, transport_capacity)
        if item_name then
          local source = find_source_for_item(network, item_name, item_quality, player.position, nil, tick)
          if source and source.valid then
            local worker_port = choose_worker_port(network, source.position, player.position, tick)
            if worker_port then
              return {
                kind = "logistics",
                item_name = item_name,
                item_quality = item_quality,
                item_key = item_identity_key(item_name, item_quality),
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

local function find_player_trash_job(network, tick)
  local transport_capacity = get_transport_capacity_for_force(network.force)
  for _, player in ipairs(game.connected_players or {}) do
    local character = get_player_character(player)
    if player and player.valid
       and character
       and player.surface == network.surface
       and player.force == network.force
       and position_in_network_radius(network, player.position, C.BITERPORT_LOGISTICS_RADIUS) then
      local item_name, item_quality, count = next_player_trash_stack(player, transport_capacity)
      if item_name then
        local target = find_trash_target(network, item_name, item_quality, player.position, tick, count)
        if target and target.valid then
          local worker_port = choose_worker_port(network, player.position, target.position, tick)
          if worker_port then
            return {
                kind = "logistics",
                item_name = item_name,
                item_quality = item_quality,
                item_key = item_identity_key(item_name, item_quality),
              count = count or 1,
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

local function find_deconstruction_job(network, tick)
  for _, port in ipairs(network.ports) do
    local area = port_scan_area(
      port,
      port_construction_radius(port),
      C.BITERPORT_CONSTRUCTION_SCAN_SUBDIVISIONS,
      tick,
      7
    )
    local entities = network.surface.find_entities_filtered{
      area = area,
      to_be_deconstructed = true,
      limit = C.BITERPORT_MAX_DECONSTRUCTION_PER_PORT_SCAN,
    }
    table.sort(entities, function(a, b)
      return distance_squared(a.position, port.position) < distance_squared(b.position, port.position)
    end)
    for _, entity in ipairs(entities) do
      if entity.valid
         and not is_deconstruction_reserved(entity)
         and entity.type ~= "entity-ghost"
         and entity.type ~= "tile-ghost"
         and entity.type ~= "deconstructible-tile-proxy"
         and position_in_network_radius(network, entity.position, C.BITERPORT_CONSTRUCTION_RADIUS) then
        local worker_port = choose_worker_port(network, entity.position, entity.position, tick)
        if worker_port then
          return snapshot_deconstruction(entity), worker_port
        end
      end
    end

    local tile_proxies = network.surface.find_entities_filtered{
      area = area,
      name = "deconstructible-tile-proxy",
      force = network.force,
      limit = C.BITERPORT_MAX_DECONSTRUCTION_PER_PORT_SCAN,
    }
    table.sort(tile_proxies, function(a, b)
      return distance_squared(a.position, port.position) < distance_squared(b.position, port.position)
    end)
    for _, proxy in ipairs(tile_proxies) do
      if proxy.valid
         and not is_deconstruction_reserved(proxy)
         and position_in_network_radius(network, proxy.position, C.BITERPORT_CONSTRUCTION_RADIUS) then
        local worker_port = choose_worker_port(network, proxy.position, proxy.position, tick)
        if worker_port then
          return snapshot_tile_proxy_deconstruction(proxy, network.force), worker_port
        end
      end
    end

    local loose_items = network.surface.find_entities_filtered{
      area = area,
      type = "item-entity",
      limit = C.BITERPORT_MAX_DECONSTRUCTION_PER_PORT_SCAN,
    }
    table.sort(loose_items, function(a, b)
      return distance_squared(a.position, port.position) < distance_squared(b.position, port.position)
    end)
    for _, item_entity in ipairs(loose_items) do
      if item_entity.valid
         and not is_deconstruction_reserved(item_entity)
         and position_in_network_radius(network, item_entity.position, C.BITERPORT_CONSTRUCTION_RADIUS) then
        local worker_port = choose_worker_port(network, item_entity.position, item_entity.position, tick)
        if worker_port then
          return snapshot_loose_item_deconstruction(item_entity), worker_port
        end
      end
    end

    if network.surface.find_tiles_filtered then
      local tiles = network.surface.find_tiles_filtered{
        area = area,
        force = network.force,
        to_be_deconstructed = true,
        limit = C.BITERPORT_MAX_DECONSTRUCTION_PER_PORT_SCAN,
      }
      for _, tile in ipairs(tiles) do
        local marked = false
        if tile.valid and tile.to_be_deconstructed then
          local ok, value = pcall(tile.to_be_deconstructed, network.force)
          marked = ok and value or false
        end
        if marked
           and not is_deconstruction_reserved(tile)
           and position_in_network_radius(network, tile.position, C.BITERPORT_CONSTRUCTION_RADIUS) then
          local worker_port = choose_worker_port(network, tile.position, tile.position, tick)
          if worker_port then
            return snapshot_tile_deconstruction(tile, network.force), worker_port
          end
        end
      end
    end
  end
  return nil, nil
end

local function count_network_logistic_chests(network, tick)
  local counts = {total = 0, providers = 0, requesters = 0, storages = 0}
  if not network then return counts end
  for_each_logistic_chest(network, function(chest)
    counts.total = counts.total + 1
    if is_source_chest(chest) then
      counts.providers = counts.providers + 1
    end
    if is_requester_chest(chest) then
      counts.requesters = counts.requesters + 1
    end
    if STORAGE_CHEST_NAMES[chest.name]
       or (chest.prototype and chest.prototype.logistic_mode == "storage") then
      counts.storages = counts.storages + 1
    end
    return false
  end, {full_scan = true, tick = tick})
  return counts
end

local function clamp(value, min_value, max_value)
  if value < min_value then return min_value end
  if value > max_value then return max_value end
  return value
end

local function resolve_destination_position(destination)
  if not destination then return nil end
  if destination.valid ~= nil and not destination.valid then return nil end
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
  local spawn_origin = port_spawn_position(port)
  local spawn_pos = port.surface.find_non_colliding_position(worker_entity_name, spawn_origin, 1, 0.25)
  if not spawn_pos then return nil end
  local biter = port.surface.create_entity{
    name = worker_entity_name,
    position = spawn_pos,
    force = get_worker_force(),
  }
  unit_ai_settings.apply_managed_unit_settings(biter)
  return biter
end

local function refresh_active_worker_snapshot(active, biter)
  if not active or not biter or not biter.valid then return end
  active.worker_entity_name = biter.name
  active.worker_surface_index = biter.surface and biter.surface.index or nil
  active.worker_last_position = copy_position(biter.position)
end

local function rekey_active_worker(active, old_unit_number, new_unit_number)
  if not active or not old_unit_number or not new_unit_number then return end
  if storage.biterport_workers then
    storage.biterport_workers[old_unit_number] = nil
    storage.biterport_workers[new_unit_number] = active
  end
  if storage.biterport_worker_units then
    local port_marker = storage.biterport_worker_units[old_unit_number]
    storage.biterport_worker_units[old_unit_number] = nil
    storage.biterport_worker_units[new_unit_number] = port_marker or active.home_port_id or true
  end
  local port_id = active.home_port_id
  local active_set = port_id and storage.biterport_active_by_port and storage.biterport_active_by_port[port_id]
  if active_set then
    active_set[old_unit_number] = nil
    active_set[new_unit_number] = true
  end
end

local function recreate_missing_worker(active, tick)
  if not active or not game or not game.surfaces then return nil end
  local surface = active.worker_surface_index and game.surfaces[active.worker_surface_index] or nil
  local port = active.home_port_id and storage.biterports and storage.biterports[active.home_port_id] or nil
  surface = surface or (port and port.valid and port.surface) or nil
  if not surface then return nil end

  local position = active.worker_last_position
    or (port and port.valid and port_spawn_position(port))
    or nil
  if not position then return nil end

  local entity_name = active.worker_entity_name
    or (port and port.valid and get_worker_entity_name(port.force))
    or WORKER_ENTITY_NAME
  local spawn_pos = surface.find_non_colliding_position(entity_name, position, 2, 0.25) or position
  local force = get_worker_force()
  local biter = surface.create_entity{
    name = entity_name,
    position = spawn_pos,
    force = force,
    create_build_effect_smoke = false,
  }
  if not biter or not biter.valid then return nil end
  unit_ai_settings.apply_managed_unit_settings(biter)

  apply_job_tint(biter, active.job and active.job.kind)
  local old_unit_number = active.biter_unit_number
  active.biter = biter
  active.biter_unit_number = biter.unit_number
  rekey_active_worker(active, old_unit_number, biter.unit_number)
  refresh_active_worker_snapshot(active, biter)
  if active.phase and active.phase_destination then
    issue_move_command(biter, active.phase_destination, active.phase_command_radius)
    active.phase_started_tick = tick or game.tick
    active.phase_origin = copy_position(biter.position)
    active.phase_arrived_tick = nil
  end
  return biter
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

local function remove_dispatch_inputs(port, tick)
  local inv = get_station_inventory(port)
  if not inv then return false end
  if port_available_worker_count(port, tick) <= 0 then return false end
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
  mark_port_dispatched(port, tick)
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
        stack = exact_stack(stack.name, remaining, stack),
        enable_looted = false,
        force = preferred_entity and preferred_entity.valid and preferred_entity.force or nil,
        allow_belts = false,
      }
    end
  end
  active.carried_stack = nil
end

local function port_has_worker_space(port)
  local inv = get_station_inventory(port)
  if not inv then return false end
  if inv.can_insert then
    return inv.can_insert({name = WORKER_ITEM_NAME, count = 1})
  end
  return true
end

local function nearest_valid_port(active)
  local biter = active and active.biter
  local home = active and active.home_port_id and storage.biterports[active.home_port_id]
  if home and home.valid and port_has_worker_space(home) then return home end
  if not biter or not biter.valid then return nil end

  local best, best_score = nil, math.huge
  for _, port in pairs(storage.biterports or {}) do
    if port and port.valid
       and port.surface == biter.surface
       and port.force == active.force
       and port_has_worker_space(port) then
      local score = distance_squared(biter.position, port.position)
      if score < best_score then
        best, best_score = port, score
      end
    end
  end
  return best
end

local turn_worker_into_protester

local function start_return(active, tick)
  local port = nearest_valid_port(active)
  if not port or not port.valid then
    worker_debug_log("start-return-no-port", active)
    active.phase = "orphaned_returning"
    active.return_port_id = nil
    active.orphan_return_started_tick = active.orphan_return_started_tick or current_tick(tick)
    active.phase_started_tick = current_tick(tick)
    active.phase_destination = nil
    active.phase_target_position = nil
    active.phase_target_unit_number = nil
    if active.biter and active.biter.valid and active.biter.commandable and defines.command.stop then
      active.biter.commandable.set_command({
        type = defines.command.stop,
        distraction = defines.distraction.none,
      })
    end
    local protested = turn_worker_into_protester(active, tick)
    worker_debug_log("start-return-protest-result", active, "protested=" .. tostring(protested))
    return true
  end
  worker_debug_log("start-return-retarget-port", active, "port=" .. tostring(port.unit_number) .. " port_pos=" .. debug_position(port.position))
  active.return_port_id = port.unit_number
  active.orphan_return_started_tick = nil
  return begin_phase_move(
    active,
    "returning",
    port_despawn_position(port),
    C.BITERPORT_ARRIVAL_RADIUS,
    tick
  )
end

turn_worker_into_protester = function(active, tick)
  if not active then
    worker_debug_log("turn-protester-skip-no-active", active)
    return false
  end
  local biter = active.biter
  worker_debug_log("turn-protester-start", active)

  if active.job and active.job.kind == "construction" and not active.job.built then
    restore_construction_ghost(active.job)
  elseif active.job and active.job.overlay_id then
    destroy_render(active.job.overlay_id)
    active.job.overlay_id = nil
  end
  release_logistics_reservation(active.job)
  release_deconstruction_reservation(active.job)
  return_carried_item(active, active.job and active.job.source)

  if not biter or not biter.valid then
    worker_debug_log("turn-protester-skip-invalid-biter", active)
    return false
  end
  biter.active = true
  biter.destructible = true

  local biters = biters_module
  if biters and biters.trigger_immediate_protest then
    if biters.trigger_immediate_protest(biter, biter.surface, nil, {preserve_entity = true}) then
      worker_debug_log("turn-protester-success", active)
      unmark_worker_unit(active.biter_unit_number)
      unregister_active_worker(active)
      return true
    end
  end
  worker_debug_log("turn-protester-failed", active, "has_module=" .. tostring(biters ~= nil) .. " has_trigger=" .. tostring(biters and biters.trigger_immediate_protest ~= nil))
  return false
end

local function advance_orphaned_return(active, tick)
  local port = nearest_valid_port(active)
  if port and port.valid then
    worker_debug_log("orphan-retarget-port", active, "port=" .. tostring(port.unit_number) .. " port_pos=" .. debug_position(port.position))
    active.return_port_id = port.unit_number
    active.orphan_return_started_tick = nil
    begin_phase_move(active, "returning", port_despawn_position(port), C.BITERPORT_ARRIVAL_RADIUS, tick)
    return "retargeted"
  end

  active.phase = "orphaned_returning"
  active.orphan_return_started_tick = active.orphan_return_started_tick or current_tick(tick)
  local protested = turn_worker_into_protester(active, tick)
  worker_debug_log("orphan-protest-result", active, "protested=" .. tostring(protested))
  return "protesting"
end

local function finish_worker(active, tick, return_worker)
  if return_worker then
    local port = active.return_port_id and storage.biterports[active.return_port_id]
      or active.home_port_id and storage.biterports[active.home_port_id]
    if port and port.valid then
      if maybe_reinsert_worker(port) then
        add_worker_cooldown(port.unit_number, current_tick(tick) + C.BITERPORT_RETURN_COOLDOWN_TICKS)
      end
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
  release_logistics_reservation(job)
  release_deconstruction_reservation(job)
  return_carried_item(active, job and job.source)
  if not start_return(active, tick) then
    finish_worker(active, tick, true)
  end
end

local function perform_pickup(active, tick)
  local job = active.job
  if job and job.kind == "deconstruction" then
    begin_phase_move(active, "to_target", job.target, C.BITERPORT_ARRIVAL_RADIUS, tick)
    return
  end
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
  local item_quality = job_quality_name(job)
  local removed = source_inv.remove(exact_stack(job.item_name, count, item_quality)) or 0
  if removed <= 0 then
    fail_job_and_return(active, tick)
    return
  end
  active.carried_stack = exact_stack(job.item_name, removed, item_quality)
  local target = job.kind == "construction" and construction_destination(job)
    or job.target_destination
    or job.target
  begin_phase_move(active, "to_target", target, C.BITERPORT_ARRIVAL_RADIUS, tick)
end

local function deconstruction_products(entity)
  local proto = entity and entity.prototype
  local mineable = proto and proto.mineable_properties
  local products = mineable and mineable.products
  local result = {}
  for _, product in ipairs(products or {}) do
    local name = product.name or product[1]
    local amount = product.amount or product.count or product.amount_min or product[2] or 1
    if name and amount and amount > 0 then
      result[#result + 1] = {
        name = name,
        count = math.max(1, math.floor(amount)),
        quality = normalized_quality_name(entity),
      }
    end
  end
  return result
end

local function carried_stack_count(active)
  local stack = active and active.carried_stack
  return stack and stack.name and (stack.count or 0) or 0
end

local function add_carried_stack(active, name, count, item_quality)
  if not active or not name or not count or count <= 0 then return end
  local normalized = normalized_quality_name(item_quality)
  active.carried_stack = active.carried_stack or exact_stack(name, 0, normalized)
  if active.carried_stack.name == name
     and normalized_quality_name(active.carried_stack) == normalized then
    active.carried_stack.count = active.carried_stack.count + count
    return true
  end
  return false
end

local function product_identity_set(products)
  local set = {}
  for _, product in ipairs(products or {}) do
    if product.name then set[item_identity_key(product.name, product.quality)] = true end
  end
  return set
end

local function collect_nearby_mined_items(active, surface, position, products)
  if not active or not surface or not position or not surface.find_entities_filtered then return end
  local wanted = product_identity_set(products)
  if not next(wanted) then return end
  local items = surface.find_entities_filtered{
    type = "item-entity",
    area = {
      {position.x - 1.0, position.y - 1.0},
      {position.x + 1.0, position.y + 1.0},
    },
  }
  for _, item_entity in ipairs(items) do
    local stack = item_entity.valid and safe_entity_field(item_entity, "stack") or nil
    if stack and stack.valid_for_read then
      local stack_name, stack_quality = stack_identity(stack)
      local key = item_identity_key(stack_name, stack_quality)
      if wanted[key] and (not active.carried_stack
          or (active.carried_stack.name == stack_name
            and normalized_quality_name(active.carried_stack) == stack_quality)) then
        add_carried_stack(active, stack_name, stack.count or 1, stack_quality)
        item_entity.destroy()
      elseif wanted[key] and item_entity.order_deconstruction then
        pcall(function() item_entity.order_deconstruction(item_entity.force or game.forces.player) end)
      end
    end
  end
end

local function dispose_carried_stack(active, tick)
  local stack = active and active.carried_stack
  if not stack or not stack.name or (stack.count or 0) <= 0 then
    active.carried_stack = nil
    if not start_return(active, tick) then finish_worker(active, tick, true) end
    return
  end
  local network = find_network_for_position(active.biter.surface, active.force, active.biter.position, C.BITERPORT_LOGISTICS_RADIUS)
  local target = network and find_trash_target(
    network, stack.name, normalized_quality_name(stack), active.biter.position, tick, stack.count) or nil
  if target then
    active.job.target = target
    active.job.target_unit_number = target.unit_number
    begin_phase_move(active, "dispose_items", target, C.BITERPORT_ARRIVAL_RADIUS, tick)
  else
    return_carried_item(active, nil)
    if not start_return(active, tick) then finish_worker(active, tick, true) end
  end
end

local function perform_deconstruction(active, tick)
  local job = active and active.job
  local target = job and job.target
  if job and job.deconstruction_type == "loose_item" then
    if target and target.valid then
      local stack = safe_entity_field(target, "stack")
      if stack and stack.valid_for_read then
        active.carried_stack = exact_stack(stack.name, stack.count or 1, stack)
      end
      target.destroy()
    end
    release_deconstruction_reservation(job)
    dispose_carried_stack(active, tick)
    return
  end

  if job and job.deconstruction_type == "tile" then
    local tile = job.surface and job.surface.get_tile and job.surface.get_tile(job.tile_position or job.position) or nil
    local replacement_tile = job.replacement_tile or (tile and safe_entity_field(tile, "hidden_tile")) or "grass-1"
    if target and target.valid and target.cancel_deconstruction then
      pcall(function() target.cancel_deconstruction(active.force) end)
    end
    if job.surface and job.position and job.surface.set_tiles then
      pcall(function()
        job.surface.set_tiles({
          {name = replacement_tile, position = job.tile_position or job.position}
        }, true, true, true, true)
      end)
    end
    if target and target.valid and target.destroy then
      pcall(function() target.destroy{raise_destroy = true} end)
    end
    if job.item_name then
      active.carried_stack = exact_stack(job.item_name, 1, job_quality_name(job))
    end
    release_deconstruction_reservation(job)
    dispose_carried_stack(active, tick)
    return
  end

  if not target or not target.valid then
    release_deconstruction_reservation(job)
    dispose_carried_stack(active, tick)
    return
  end

  local products = deconstruction_products(target)
  local inv = game and game.create_inventory and game.create_inventory(1) or nil
  local before_count = carried_stack_count(active)
  local target_surface = safe_entity_field(target, "surface")
  local target_position = copy_position(safe_entity_field(target, "position"))
  local mined = false
  if target.mine then
    local ok, result = pcall(function()
      return target.mine{inventory = inv, force = false, raise_destroyed = true}
    end)
    mined = ok and result ~= false
  end
  if not mined and target.destroy then
    mined = pcall(function() target.destroy{raise_destroy = true} end)
    if mined and inv and inv.insert then
      for _, product in ipairs(products) do
        inv.insert(exact_stack(product.name, product.count, product.quality))
      end
    end
  end

  if inv and #inv > 0 then
    for index = 1, #inv do
      local stack = inv[index]
      if stack and stack.valid_for_read and stack.name and (stack.count or 0) > 0 then
        add_carried_stack(active, stack.name, stack.count, stack)
      end
    end
  elseif inv and inv.get_contents then
    for name, count in pairs(inv.get_contents()) do
      local content_name = type(count) == "table" and (count.name or name) or name
      local content_count = type(count) == "table" and count.count or count
      local content_quality = type(count) == "table" and count.quality or "normal"
      if content_name and content_count and content_count > 0 then
        add_carried_stack(active, content_name, content_count, content_quality)
      end
    end
    if inv.destroy then inv.destroy() end
  end

  if mined and carried_stack_count(active) == before_count then
    for _, product in ipairs(products) do
      add_carried_stack(active, product.name, product.count, product.quality)
      if active.carried_stack then break end
    end
  end
  collect_nearby_mined_items(active, target_surface, target_position, products)

  release_deconstruction_reservation(job)
  dispose_carried_stack(active, tick)
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
      local ok, first, revived = pcall(job.ghost.silent_revive, {raise_revive = true})
      if ok then
        built = job.construction_type == "tile" and (first or revived or not job.ghost.valid) or revived
      end
    end
    if not built and job.ghost.valid and job.ghost.revive then
      local ok, first, revived = pcall(job.ghost.revive, {raise_revive = true})
      if ok then
        built = job.construction_type == "tile" and (first or revived or not job.ghost.valid) or revived
      end
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

  if built and (built == true or built.valid) then
    job.built = true
    job.ghost = nil
    if job.overlay_id then
      destroy_render(job.overlay_id)
      job.overlay_id = nil
    end
    if active.carried_stack and active.carried_stack.count and active.carried_stack.count > 0 then
      active.carried_stack.count = active.carried_stack.count - 1
      if active.carried_stack.count <= 0 then
        active.carried_stack = nil
      end
    end
    local next_job = find_next_carried_construction_job(active, tick)
    if next_job then
      active.job = next_job
      begin_phase_move(active, "to_target", construction_destination(next_job), C.BITERPORT_ARRIVAL_RADIUS, tick)
    elseif not start_return(active, tick) then
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
    release_logistics_reservation(job)
    return_carried_item(active, job and job.source)
    if not start_return(active, tick) then finish_worker(active, tick, true) end
    return
  end
  local stack = active.carried_stack
  local inserted = insert_stack_into_target(target, stack)
  if inserted <= 0 then
    release_logistics_reservation(job)
    return_carried_item(active, job and job.source)
    if not start_return(active, tick) then finish_worker(active, tick, true) end
    return
  end
  local remaining = stack and ((stack.count or 0) - inserted) or 0
  if remaining > 0 then
    active.carried_stack = exact_stack(stack.name, remaining, stack)
    return_carried_item(active, target)
  else
    active.carried_stack = nil
  end
  release_logistics_reservation(job)
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
      biter = recreate_missing_worker(active, tick)
      if not biter or not biter.valid then
        if active.job and active.job.kind == "construction" and not active.job.built then
          restore_construction_ghost(active.job)
        elseif active.job and active.job.overlay_id then
          destroy_render(active.job.overlay_id)
          active.job.overlay_id = nil
        end
        release_logistics_reservation(active.job)
        release_deconstruction_reservation(active.job)
        return_carried_item(active, active.job and active.job.source)
        local port = active.home_port_id and storage.biterports[active.home_port_id]
        if port and port.valid then
          maybe_reinsert_worker(port)
          refresh_port_status(port)
        end
        unmark_worker_unit(active.biter_unit_number)
        unregister_active_worker(active)
        goto continue
      end
    end
    refresh_active_worker_snapshot(active, biter)

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
        elseif job.kind == "deconstruction" then
          perform_deconstruction(active, tick)
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
        advance_orphaned_return(active, tick)
        goto continue
      end
      local return_destination = port_despawn_position(port)
      local arrived = phase_is_arrived(active, biter, return_destination, C.BITERPORT_ARRIVAL_RADIUS)
        and (active.phase_arrived_tick or phase_has_departed(active, biter, tick))
      if arrived then
        finish_worker(active, tick, true)
      elseif active.phase_target_unit_number ~= nil
          or (biter.commandable and not biter.commandable.has_command) then
        begin_phase_move(active, "returning", return_destination, C.BITERPORT_ARRIVAL_RADIUS, tick)
      end

    elseif active.phase == "orphaned_returning" then
      advance_orphaned_return(active, tick)

    elseif active.phase == "dispose_items" then
      local job = active.job
      local target = job and job.target
      if not target or not target.valid then
        fail_job_and_return(active, tick)
        goto continue
      end
      local arrived = phase_is_arrived(active, biter, target, C.BITERPORT_ARRIVAL_RADIUS)
        and (active.phase_arrived_tick or phase_has_departed(active, biter, tick))
      if arrived then
        deliver_logistics_job(active, tick)
      elseif active.phase_target_unit_number ~= resolve_destination_unit_number(target)
          or phase_target_shifted(active, target)
          or (biter.commandable and not biter.commandable.has_command) then
        begin_phase_move(active, "dispose_items", target, C.BITERPORT_ARRIVAL_RADIUS, tick)
      end

    else
      fail_job_and_return(active, tick)
    end

    ::continue::
  end
end

local function dispatch_job(worker_port, job, tick)
  if not worker_port or not worker_port.valid or not job then return false end
  if job.kind == "deconstruction" and not reserve_deconstruction_job(job) then
    refresh_port_status(worker_port)
    return false
  end
  if job.kind == "logistics" and not create_logistics_reservation(job) then
    refresh_port_status(worker_port)
    return false
  end
  if not remove_dispatch_inputs(worker_port, tick) then
    if job.kind == "construction" then restore_construction_ghost(job) end
    release_logistics_reservation(job)
    release_deconstruction_reservation(job)
    refresh_port_status(worker_port)
    return false
  end

  local biter = spawn_worker(worker_port, job.kind)
  if not biter or not biter.valid then
    maybe_reinsert_worker(worker_port)
    if job.kind == "construction" then restore_construction_ghost(job) end
    release_logistics_reservation(job)
    release_deconstruction_reservation(job)
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
  refresh_active_worker_snapshot(active, biter)
  register_active_worker(active)
  mark_worker_unit(biter.unit_number, worker_port.unit_number)
  if job.kind == "logistics" and job.network_key and job.request_cursor_key then
    storage.biterport_logistics_request_cursors = storage.biterport_logistics_request_cursors or {}
    storage.biterport_logistics_request_cursors[job.network_key] = job.request_cursor_key
  end
  begin_phase_move(active, "to_pickup", job.source_destination or job.source, C.BITERPORT_ARRIVAL_RADIUS, current_tick(tick))
  refresh_port_status(worker_port)
  return true
end

local function dispatch_network_jobs(network, tick)
  local dispatched = 0

  while true do
    local job, worker_port = find_deconstruction_job(network, tick)
    if not job or not worker_port then break end
    if dispatch_job(worker_port, job, tick) then
      dispatched = dispatched + 1
    else
      break
    end
  end

  while true do
    local job, worker_port = find_construction_job(network, tick, "tile-ghost")
    if not job or not worker_port then break end
    if dispatch_job(worker_port, job, tick) then
      dispatched = dispatched + 1
    else
      break
    end
  end

  while true do
    local job, worker_port = find_construction_job(network, tick, "entity-ghost")
    if not job or not worker_port then break end
    if dispatch_job(worker_port, job, tick) then
      dispatched = dispatched + 1
    else
      break
    end
  end

  while true do
    local job, worker_port = find_logistics_job(network, tick)
    if not job or not worker_port then break end
    if dispatch_job(worker_port, job, tick) then
      dispatched = dispatched + 1
    else
      break
    end
  end

  while true do
    local job, worker_port = find_player_delivery_job(network, tick)
    if not job or not worker_port then break end
    if dispatch_job(worker_port, job, tick) then
      dispatched = dispatched + 1
    else
      break
    end
  end

  while true do
    local job, worker_port = find_player_trash_job(network, tick)
    if not job or not worker_port then break end
    if dispatch_job(worker_port, job, tick) then
      dispatched = dispatched + 1
    else
      break
    end
  end

  return dispatched
end

local function normalize_legacy_quality_state()
  local normalized = 0
  for _, reservation in pairs(storage.biterport_logistics_reservations or {}) do
    if reservation and reservation.item_name then
      reservation.item_quality = normalized_quality_name(reservation.item_quality)
      reservation.item_key = item_identity_key(reservation.item_name, reservation.item_quality)
      normalized = normalized + 1
    end
  end
  for _, active in pairs(storage.biterport_workers or {}) do
    local job = active and active.job
    if job and job.item_name then
      job.item_quality = job_quality_name(job)
      job.item_key = item_identity_key(job.item_name, job.item_quality)
      normalized = normalized + 1
    end
    local stack = active and active.carried_stack
    if stack and stack.name then
      stack.quality = normalized_quality_name(stack)
      normalized = normalized + 1
    end
  end
  for _, cache in pairs(storage.biterport_storage_target_cache or {}) do
    for key, unit_number in pairs(cache) do
      if type(key) == "string" and not key:find("\31", 1, true) then
        cache[item_identity_key(key, "normal")] = unit_number
        cache[key] = nil
        normalized = normalized + 1
      end
    end
  end
  return normalized
end

function M.ensure_storage()
  ensure_worker_force()
  storage.biterports = storage.biterports or {}
  storage.biterport_hidden_roboports = storage.biterport_hidden_roboports or {}
  storage.biterport_coffee_inputs = storage.biterport_coffee_inputs or {}
  storage.biterport_workers = storage.biterport_workers or {}
  storage.biterport_active_by_port = storage.biterport_active_by_port or {}
  storage.biterport_worker_units = storage.biterport_worker_units or {}
  storage.biterport_worker_cooldowns = storage.biterport_worker_cooldowns or {}
  storage.biterport_next_dispatch_ticks = storage.biterport_next_dispatch_ticks or {}
  storage.biterport_logistics_reservations = storage.biterport_logistics_reservations or {}
  storage.biterport_next_logistics_reservation_id = storage.biterport_next_logistics_reservation_id or 0
  storage.biterport_logistics_request_cursors = storage.biterport_logistics_request_cursors or {}
  storage.biterport_storage_target_cache = storage.biterport_storage_target_cache or {}
  storage.biterport_deconstruction_reservations = storage.biterport_deconstruction_reservations or {}
end

function M.normalize_quality_state()
  M.ensure_storage()
  return normalize_legacy_quality_state()
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

function M.set_biters_module(module)
  biters_module = module
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
  create_wall_blockers(entity)
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
  return dispatch_job(worker_port, job, event and event.tick)
end

function M.untrack_port(entity, tick)
  M.ensure_storage()
  if not entity or not entity.unit_number then return end
  local port_id = entity.unit_number
  destroy_hidden_roboport(port_id)
  destroy_hidden_coffee_input(port_id)
  destroy_wall_blockers(entity)
  storage.biterports[port_id] = nil
  if storage.biterport_worker_cooldowns then
    storage.biterport_worker_cooldowns[port_id] = nil
  end
  if storage.biterport_next_dispatch_ticks then
    storage.biterport_next_dispatch_ticks[port_id] = nil
  end
  local active_set = storage.biterport_active_by_port[port_id]
  if active_set then
    for unit_number in pairs(active_set) do
      local active = storage.biterport_workers[unit_number]
      if active then
        worker_debug_log("untrack-port-active-worker", active, "removed_port=" .. tostring(port_id))
        if active.home_port_id == port_id then active.home_port_id = nil end
        if active.return_port_id == port_id then active.return_port_id = nil end
        fail_job_and_return(active, tick or game.tick)
      end
    end
    storage.biterport_active_by_port[port_id] = nil
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
      release_logistics_reservation(active.job)
      release_deconstruction_reservation(active.job)
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
  if not research.name:find("^biterport%-transport%-capacity%-") then
    return
  end

  M.ensure_storage()
  for _, port in pairs(storage.biterports or {}) do
    if port and port.valid and port.force == research.force then
      refresh_port_status(port)
    end
  end
end

function M.rebuild_registry()
  M.ensure_storage()
  normalize_legacy_quality_state()

  for _, active in pairs(storage.biterport_workers or {}) do
    if active.job and active.job.kind == "construction" and not active.job.built then
      restore_construction_ghost(active.job)
    end
    release_logistics_reservation(active.job)
    release_deconstruction_reservation(active.job)
    return_carried_item(active, active.job and active.job.source)
    if active.biter and active.biter.valid then
      active.biter.destroy()
    end
  end

  for _, surface in pairs(game.surfaces) do
    for _, blocker in ipairs(surface.find_entities_filtered{name = WALL_BLOCKER_NAME}) do
      if blocker.valid then blocker.destroy() end
    end
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
  storage.biterport_worker_cooldowns = {}
  storage.biterport_next_dispatch_ticks = {}
  storage.biterport_logistics_reservations = {}
  storage.biterport_next_logistics_reservation_id = 0
  storage.biterport_logistics_request_cursors = {}
  storage.biterport_storage_target_cache = {}
  storage.biterport_deconstruction_reservations = {}

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
      local chests = count_network_logistic_chests(network, game and game.tick or nil)
      return {
        ports = #network.ports,
        workers = workers,
        logistic_chests = chests.total,
        provider_chests = chests.providers,
        requester_chests = chests.requesters,
        storage_chests = chests.storages,
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
    dispatch_network_jobs(network, tick)
  end

  for port_id, port in pairs(storage.biterports or {}) do
    if not port or not port.valid then
      destroy_hidden_roboport(port_id)
      storage.biterports[port_id] = nil
      if storage.biterport_worker_cooldowns then
        storage.biterport_worker_cooldowns[port_id] = nil
      end
      if storage.biterport_next_dispatch_ticks then
        storage.biterport_next_dispatch_ticks[port_id] = nil
      end
    else
      prune_worker_cooldowns(port_id, tick)
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
