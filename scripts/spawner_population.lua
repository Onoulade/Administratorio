-- Keeps script-managed biters counted against their home spawner's population
-- limit after they are detached from Factorio's native spawner ownership.
--
-- Managed units must remain detached: Factorio may remove spawner-owned units
-- that travel too far from their nest. We therefore keep a separate lease
-- ledger and discard only replacement spawns that would exceed the prototype's
-- max_count_of_owned_units.
local M = {}

local function safe_commandable_spawner(unit)
  if not unit or not unit.valid or not unit.commandable then return nil end
  local ok, spawner = pcall(function() return unit.commandable.spawner end)
  if ok and spawner and spawner.valid and spawner.type == "unit-spawner" then
    return spawner
  end
  return nil
end

local function spawner_limit(spawner)
  if not spawner or not spawner.valid or not spawner.prototype then return nil end
  local limit = spawner.prototype.max_count_of_owned_units
  if type(limit) ~= "number" then return nil end
  return math.max(0, math.floor(limit))
end

function M.ensure_storage()
  storage.spawner_population = storage.spawner_population or {}
  storage.spawner_population_unit_links = storage.spawner_population_unit_links or {}
end

local function ensure_ready()
  M.ensure_storage()
  if storage.spawner_population_ready ~= true and game and game.surfaces then
    M.rebuild()
  end
end

local function ensure_record(spawner)
  if not spawner or not spawner.valid or not spawner.unit_number then return nil end
  M.ensure_storage()
  local spawner_id = spawner.unit_number
  local record = storage.spawner_population[spawner_id]
  if not record then
    record = {
      spawner = spawner,
      owned = {},
      detached = {},
    }
    storage.spawner_population[spawner_id] = record
  else
    record.spawner = spawner
    record.owned = record.owned or {}
    record.detached = record.detached or {}
  end
  return record
end

local function remove_link(unit_number, expected_kind, expected_spawner_id)
  local links = storage.spawner_population_unit_links
  local link = links and links[unit_number]
  if not link then return end
  if expected_kind and link.kind ~= expected_kind then return end
  if expected_spawner_id and link.spawner_id ~= expected_spawner_id then return end
  links[unit_number] = nil
end

local function remove_from_record(unit_number, link)
  if not link then return end
  local record = storage.spawner_population and storage.spawner_population[link.spawner_id]
  if record then
    if link.kind == "owned" and record.owned then
      record.owned[unit_number] = nil
    elseif link.kind == "detached" and record.detached then
      record.detached[unit_number] = nil
    end
  end
  remove_link(unit_number, link.kind, link.spawner_id)
end

local function unlink_unit(unit_number)
  if not unit_number then return end
  M.ensure_storage()
  remove_from_record(unit_number, storage.spawner_population_unit_links[unit_number])
end

local function count_entries(entries)
  local count = 0
  for _ in pairs(entries or {}) do count = count + 1 end
  return count
end

local function prune_invalid_owned(record)
  if not record then return end
  local spawner_id = record.spawner and record.spawner.unit_number
  for unit_number, entity in pairs(record.owned or {}) do
    if not entity or not entity.valid then
      record.owned[unit_number] = nil
      remove_link(unit_number, "owned", spawner_id)
    end
  end
end

local function destroy_one_owned(record)
  prune_invalid_owned(record)
  local spawner_id = record.spawner and record.spawner.unit_number
  for unit_number, entity in pairs(record.owned or {}) do
    record.owned[unit_number] = nil
    remove_link(unit_number, "owned", spawner_id)
    if entity and entity.valid then entity.destroy() end
    return true
  end
  return false
end

local function trim_owned_to_limit(record)
  if not record or not record.spawner or not record.spawner.valid then return end
  prune_invalid_owned(record)
  local limit = spawner_limit(record.spawner)
  if not limit then return end
  local detached_count = count_entries(record.detached)
  local owned_count = count_entries(record.owned)
  while detached_count + owned_count > limit and owned_count > 0 do
    if not destroy_one_owned(record) then break end
    owned_count = owned_count - 1
  end
end

local function link_unit(record, unit_number, entity, kind)
  if not record or not unit_number then return false end
  local spawner_id = record.spawner.unit_number
  unlink_unit(unit_number)
  record[kind][unit_number] = entity or false
  storage.spawner_population_unit_links[unit_number] = {
    spawner_id = spawner_id,
    kind = kind,
  }
  return true
end

local function register_owned(entity, spawner)
  if not entity or not entity.valid or not entity.unit_number then return nil end
  local record = ensure_record(spawner)
  if not record then return nil end
  link_unit(record, entity.unit_number, entity, "owned")
  return record
end

-- Converts a real spawner-owned unit into a logical lease. This never rejects:
-- the unit already existed and is only changing which system accounts for it.
function M.detach_unit(entity, spawner)
  if not entity or not entity.valid or not entity.unit_number then return false end
  ensure_ready()
  local unit_number = entity.unit_number
  local existing = storage.spawner_population_unit_links[unit_number]
  spawner = spawner
    or (existing and storage.spawner_population[existing.spawner_id]
      and storage.spawner_population[existing.spawner_id].spawner)
    or safe_commandable_spawner(entity)
  local record = ensure_record(spawner)
  if not record then return false end

  if existing and existing.spawner_id == spawner.unit_number and existing.kind == "detached" then
    record.detached[unit_number] = entity
    return true
  end

  link_unit(record, unit_number, entity, "detached")
  trim_owned_to_limit(record)
  return true
end

-- Reserves capacity for a newly-created managed worker. One currently owned
-- nest unit is retired when necessary, making this a population transfer rather
-- than an extra biter. Returns false when every slot is already leased.
function M.can_lease_new_unit(spawner)
  ensure_ready()
  local record = ensure_record(spawner)
  if not record then return false end
  local limit = spawner_limit(spawner)
  return not limit or count_entries(record.detached) < limit
end

function M.lease_new_unit(entity, spawner)
  if not entity or not entity.valid or not entity.unit_number then return false end
  ensure_ready()
  local record = ensure_record(spawner)
  if not record then return false end
  prune_invalid_owned(record)

  if not M.can_lease_new_unit(spawner) then
    return false
  end

  link_unit(record, entity.unit_number, entity, "detached")
  trim_owned_to_limit(record)
  return true
end

-- Restores a logical lease from persisted subsystem state. Unlike a new lease,
-- restoration must not delete the managed unit if an older save was already
-- over capacity; natural replacements are trimmed and the excess drains as the
-- existing cases complete.
function M.restore_detached(unit_number, entity, spawner)
  if not unit_number then return false end
  ensure_ready()
  local record = ensure_record(spawner)
  if not record then return false end
  link_unit(record, unit_number, entity, "detached")
  trim_owned_to_limit(record)
  return true
end

function M.rekey_detached(old_unit_number, new_unit_number, entity, spawner)
  if not new_unit_number then return false end
  ensure_ready()
  if old_unit_number == new_unit_number then
    local link = storage.spawner_population_unit_links[new_unit_number]
    local record = link and storage.spawner_population[link.spawner_id]
    if record and link.kind == "detached" then
      record.detached[new_unit_number] = entity or record.detached[new_unit_number]
      return true
    end
  end

  local old_link = old_unit_number and storage.spawner_population_unit_links[old_unit_number] or nil
  if old_link then
    local old_record = storage.spawner_population[old_link.spawner_id]
    spawner = spawner or (old_record and old_record.spawner)
    remove_from_record(old_unit_number, old_link)
  end
  return M.restore_detached(new_unit_number, entity, spawner)
end

function M.untrack_unit(unit_number)
  unlink_unit(unit_number)
end

function M.get_home_spawner(unit_number)
  if not unit_number then return nil end
  ensure_ready()
  local link = storage.spawner_population_unit_links[unit_number]
  local record = link and storage.spawner_population[link.spawner_id]
  local spawner = record and record.spawner
  if spawner and spawner.valid then return spawner end
  return nil
end

function M.on_unit_added_to_group(event)
  local unit = event and event.unit
  if not unit or not unit.valid or not unit.unit_number then return end
  ensure_ready()
  local link = storage.spawner_population_unit_links[unit.unit_number]
  local record = link and storage.spawner_population[link.spawner_id]
  local spawner = record and record.spawner or safe_commandable_spawner(unit)
  if spawner then M.detach_unit(unit, spawner) end
end

function M.on_entity_spawned(event)
  local entity = event and event.entity
  local spawner = event and event.spawner
  if not entity or not entity.valid or not spawner or not spawner.valid then return end
  ensure_ready()
  local record = register_owned(entity, spawner)
  if not record then return end

  prune_invalid_owned(record)
  local limit = spawner_limit(spawner)
  if not limit then return end
  if count_entries(record.detached) + count_entries(record.owned) <= limit then return end

  -- Prefer rejecting the spawn that triggered the overflow. Existing owned
  -- units keep their identity and detached workers remain safe at any distance.
  record.owned[entity.unit_number] = nil
  remove_link(entity.unit_number, "owned", spawner.unit_number)
  if entity.valid then entity.destroy() end
end

function M.on_entity_died(entity)
  if not entity or not entity.unit_number then return end
  ensure_ready()
  local link = storage.spawner_population_unit_links[entity.unit_number]
  -- Detached workers may be recreated by their owning subsystem. Their logical
  -- lease stays live until that subsystem explicitly untracks or rekeys it.
  if link and link.kind == "owned" then
    remove_from_record(entity.unit_number, link)
  end
end

function M.rebuild()
  storage.spawner_population = {}
  storage.spawner_population_unit_links = {}
  storage.spawner_population_ready = true

  -- Recover Factorio-owned units first so restored leases can transfer/trim
  -- those slots deterministically.
  for _, surface in pairs(game.surfaces or {}) do
    for _, unit in ipairs(surface.find_entities_filtered{type = "unit", force = "enemy"}) do
      local spawner = safe_commandable_spawner(unit)
      if spawner then register_owned(unit, spawner) end
    end
  end

  for unit_number, info in pairs(storage.waiting_biters or {}) do
    local spawner = info and info.home_spawner
    if spawner and spawner.valid then
      M.restore_detached(unit_number, info.entity, spawner)
    end
  end

  for _, state in pairs(storage.field_office_state or {}) do
    local unit_number = state and (state.biter_unit_number
      or (state.biter and state.biter.valid and state.biter.unit_number))
    local spawner = state and state.spawner
    if unit_number and spawner and spawner.valid then
      M.restore_detached(unit_number, state.biter, spawner)
    end
  end

  for unit_number, info in pairs(storage.field_office_releasing or {}) do
    local spawner = info and info.spawner
    if spawner and spawner.valid then
      M.restore_detached(unit_number, info.entity, spawner)
    end
  end
end

function M.get_counts(spawner)
  if not spawner or not spawner.unit_number then return 0, 0 end
  ensure_ready()
  local record = storage.spawner_population[spawner.unit_number]
  if not record then return 0, 0 end
  prune_invalid_owned(record)
  return count_entries(record.owned), count_entries(record.detached)
end

return M
