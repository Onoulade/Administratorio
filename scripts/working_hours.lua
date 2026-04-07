local M = {}
local feature_flags = require("feature_flags")
local WORKING_HOURS_ENABLED = feature_flags.working_hours_enabled()

local MANAGED_BUILDINGS = {
  "office-desk",
  "corporate-breakroom",
  "union-headquarters",
}

local MANAGED_BUILDING_SET = {}
for _, name in ipairs(MANAGED_BUILDINGS) do
  MANAGED_BUILDING_SET[name] = true
end

local NIGHT_OVERLAY_COLOR = {r = 1, g = 0.92, b = 0.65}

local function get_render_object(render_ref)
  if not render_ref then return nil end
  if type(render_ref) == "number" then
    return rendering.get_object_by_id(render_ref)
  end
  if type(render_ref) == "userdata" then
    return render_ref.valid and render_ref or nil
  end
  return nil
end

local function destroy_render_object(render_ref)
  local object = get_render_object(render_ref)
  if object then
    object.destroy()
  end
end

local function overlay_offset(entity)
  local box = entity and entity.selection_box
  local top = box and box[1] and box[1][2] or -1
  return {0, top - 0.35}
end

local function clear_visual_state(entity, state)
  if state and state.overlay_id then
    destroy_render_object(state.overlay_id)
    state.overlay_id = nil
  end
  if entity and entity.valid then
    entity.custom_status = nil
  end
end

local function is_surface_night(surface)
  if not surface or not surface.valid then return false end

  local daytime = surface.daytime
  local evening = surface.evening
  local morning = surface.morning

  if evening == morning then
    return false
  end
  if evening < morning then
    return daytime >= evening and daytime < morning
  end
  return daytime >= evening or daytime < morning
end

local function has_overtime_exemption(entity)
  if not entity or not entity.valid or not entity.get_module_inventory then
    return false
  end
  local inventory = entity.get_module_inventory()
  return inventory and inventory.valid and inventory.get_item_count("overtime-exemption") > 0 or false
end

local function protest_claims_for(unit_number)
  return storage.working_hours_protest_claims and storage.working_hours_protest_claims[unit_number]
end

local function entity_is_protested(entity)
  if not entity or not entity.valid or not entity.unit_number then
    return false
  end
  local claims = protest_claims_for(entity.unit_number)
  return claims and next(claims) ~= nil or false
end

local function ensure_entity_state(unit_number)
  local state = storage.working_hours_state[unit_number]
  if not state then
    state = {}
    storage.working_hours_state[unit_number] = state
  end
  return state
end

local function maybe_notify_force(entity)
  local force = entity and entity.valid and entity.force
  if not force or not force.valid then return end
  if storage.working_hours_notified_forces[force.index] then return end

  storage.working_hours_notified_forces[force.index] = true
  force.print({
    "message.working-hours-tip-unlocked",
    {"tips-and-tricks-item-name.administratorio-working-hours"},
    {"technology-name.after-hours-operations"},
  })
end

local function apply_entity_state(entity, reason)
  if not entity or not entity.valid or not entity.unit_number then return end

  local state = ensure_entity_state(entity.unit_number)
  if state.reason == reason then
    return
  end

  if reason == "night" then
    entity.active = false
    entity.custom_status = {
      diode = defines.entity_status_diode.red,
      label = {"gui.working-hours-night-status"},
    }
    if not state.overlay_id then
      state.overlay_id = rendering.draw_text{
        surface = entity.surface,
        target = entity,
        target_offset = overlay_offset(entity),
        text = {"gui.working-hours-night-overlay"},
        color = NIGHT_OVERLAY_COLOR,
        alignment = "center",
        scale = 1,
        scale_with_zoom = false,
        use_rich_text = true,
        only_in_alt_mode = true,
      }
    end
    maybe_notify_force(entity)
  elseif reason == "protest" then
    entity.active = false
    clear_visual_state(entity, state)
  else
    entity.active = true
    clear_visual_state(entity, state)
  end

  state.reason = reason
end

local function rebuild_protest_claims()
  storage.working_hours_protest_claims = {}

  for protester_id, info in pairs(storage.waiting_biters or {}) do
    if info
       and info.state == "protesting"
       and info.arrived_at_building
       and info.target_building
       and info.target_building.valid
       and MANAGED_BUILDING_SET[info.target_building.name] then
      local target_id = info.target_building.unit_number
      if target_id then
        storage.working_hours_protest_claims[target_id] = storage.working_hours_protest_claims[target_id] or {}
        storage.working_hours_protest_claims[target_id][protester_id] = true
      end
    end
  end
end

local function clear_disabled_state()
  if not storage then return end

  rebuild_protest_claims()

  for unit_number, entity in pairs(storage.working_hours_entities or {}) do
    local state = storage.working_hours_state and storage.working_hours_state[unit_number] or nil
    clear_visual_state(entity, state)
    if entity and entity.valid then
      local was_protest_shutdown = state and state.reason == "protest"
      local still_protested = was_protest_shutdown and entity_is_protested(entity) or false
      if not still_protested then
        entity.active = true
      end
    end
  end

  for _, state in pairs(storage.working_hours_state or {}) do
    if state.overlay_id then
      destroy_render_object(state.overlay_id)
    end
  end

  storage.working_hours_entities = nil
  storage.working_hours_state = nil
  storage.working_hours_protest_claims = nil
  storage.working_hours_notified_forces = nil
end

function M.ensure_storage()
  if not WORKING_HOURS_ENABLED then return end
  storage.working_hours_entities = storage.working_hours_entities or {}
  storage.working_hours_state = storage.working_hours_state or {}
  storage.working_hours_protest_claims = storage.working_hours_protest_claims or {}
  storage.working_hours_notified_forces = storage.working_hours_notified_forces or {}
end

function M.is_enabled()
  return WORKING_HOURS_ENABLED
end

function M.is_managed_entity(entity_or_name)
  if not WORKING_HOURS_ENABLED then return false end
  local name = entity_or_name
  if type(entity_or_name) ~= "string" then
    name = entity_or_name and entity_or_name.name
  end
  return name and MANAGED_BUILDING_SET[name] == true or false
end

function M.refresh_entity(entity)
  if not WORKING_HOURS_ENABLED then return end
  M.ensure_storage()
  if not entity or not entity.valid or not M.is_managed_entity(entity) then return end

  local reason = nil
  if entity_is_protested(entity) then
    reason = "protest"
  elseif is_surface_night(entity.surface) and not has_overtime_exemption(entity) then
    reason = "night"
  end

  storage.working_hours_entities[entity.unit_number] = entity
  apply_entity_state(entity, reason)
end

function M.track_entity(entity)
  if not WORKING_HOURS_ENABLED then return end
  M.ensure_storage()
  if not entity or not entity.valid or not M.is_managed_entity(entity) or not entity.unit_number then
    return
  end
  storage.working_hours_entities[entity.unit_number] = entity
  M.refresh_entity(entity)
end

function M.untrack_entity(entity)
  if not WORKING_HOURS_ENABLED then return end
  M.ensure_storage()
  if not entity or not entity.unit_number or not M.is_managed_entity(entity) then return end

  local unit_number = entity.unit_number
  local state = storage.working_hours_state[unit_number]
  if state then
    clear_visual_state(entity, state)
    storage.working_hours_state[unit_number] = nil
  end

  storage.working_hours_entities[unit_number] = nil
  storage.working_hours_protest_claims[unit_number] = nil
end

function M.claim_protest_target(target, protester_id)
  if not WORKING_HOURS_ENABLED then return false end
  M.ensure_storage()
  if not target or not target.valid or not M.is_managed_entity(target) or not target.unit_number then
    return false
  end

  local target_id = target.unit_number
  local claim_id = protester_id or target_id
  local claims = storage.working_hours_protest_claims[target_id]
  if not claims then
    claims = {}
    storage.working_hours_protest_claims[target_id] = claims
  end
  claims[claim_id] = true

  storage.working_hours_entities[target_id] = target
  M.refresh_entity(target)
  return true
end

function M.release_protest_target(target, protester_id)
  if not WORKING_HOURS_ENABLED then return false end
  M.ensure_storage()
  if not target or not target.valid or not M.is_managed_entity(target) or not target.unit_number then
    return false
  end

  local target_id = target.unit_number
  if not protester_id then
    storage.working_hours_protest_claims[target_id] = nil
  else
    local claims = storage.working_hours_protest_claims[target_id]
    if claims then
      claims[protester_id] = nil
      if not next(claims) then
        storage.working_hours_protest_claims[target_id] = nil
      end
    end
  end

  storage.working_hours_entities[target_id] = target
  M.refresh_entity(target)
  return true
end

function M.transfer_protest_target(target, old_protester_id, new_protester_id)
  if not WORKING_HOURS_ENABLED then return false end
  M.ensure_storage()
  if not target or not target.valid or not M.is_managed_entity(target) or not target.unit_number then
    return false
  end

  local target_id = target.unit_number
  local claims = storage.working_hours_protest_claims[target_id]
  if not claims then
    claims = {}
    storage.working_hours_protest_claims[target_id] = claims
  end
  if old_protester_id then
    claims[old_protester_id] = nil
  end
  claims[new_protester_id or target_id] = true

  storage.working_hours_entities[target_id] = target
  M.refresh_entity(target)
  return true
end

function M.rebuild_registry()
  if not WORKING_HOURS_ENABLED then
    clear_disabled_state()
    return
  end
  M.ensure_storage()

  for _, state in pairs(storage.working_hours_state) do
    if state.overlay_id then
      destroy_render_object(state.overlay_id)
    end
  end

  storage.working_hours_state = {}
  storage.working_hours_entities = {}
  rebuild_protest_claims()

  for _, surface in pairs(game.surfaces) do
    for _, name in ipairs(MANAGED_BUILDINGS) do
      for _, entity in ipairs(surface.find_entities_filtered{name = name}) do
        if entity.valid and entity.unit_number then
          storage.working_hours_entities[entity.unit_number] = entity
        end
      end
    end
  end

  for _, entity in pairs(storage.working_hours_entities) do
    M.refresh_entity(entity)
  end
end

function M.update_managed_buildings()
  if not WORKING_HOURS_ENABLED then
    return
  end
  M.ensure_storage()
  if not next(storage.working_hours_entities) then
    return
  end

  local surface_night_cache = {}
  for unit_number, entity in pairs(storage.working_hours_entities) do
    if not entity or not entity.valid then
      local state = storage.working_hours_state[unit_number]
      if state and state.overlay_id then
        destroy_render_object(state.overlay_id)
      end
      storage.working_hours_entities[unit_number] = nil
      storage.working_hours_state[unit_number] = nil
      storage.working_hours_protest_claims[unit_number] = nil
    else
      local surface_id = entity.surface.index
      local surface_is_night = surface_night_cache[surface_id]
      if surface_is_night == nil then
        surface_is_night = is_surface_night(entity.surface)
        surface_night_cache[surface_id] = surface_is_night
      end

      local reason = nil
      if entity_is_protested(entity) then
        reason = "protest"
      elseif surface_is_night and not has_overtime_exemption(entity) then
        reason = "night"
      end

      apply_entity_state(entity, reason)
    end
  end
end

return M
