-- Field Office: early-game bureaucratic outpost.
-- Summons biters from nearby nests (100 tiles) as one-per-craft-cycle workers.
-- Only operates (1.0x, 0 pollution) while a biter is physically present and working.
-- Completely inactive otherwise. Does not call biters at night (unless overtime-exemption).
local C = require("scripts.constants")
local working_hours = require("scripts.working_hours")

local M = {}

local BITER_FORCE_NAME = "administratorio-biters"
local SPAWNER_TYPES = {"unit-spawner"}
local ENTITY_NAME = "field-office"
local CRAFTS_PER_BITER = 5

local function is_field_office(name)
  return name == ENTITY_NAME
end

local function get_biter_force()
  return game.forces[BITER_FORCE_NAME] or game.forces["neutral"]
end

function M.ensure_storage()
  storage.field_offices = storage.field_offices or {}
  storage.field_office_state = storage.field_office_state or {}
  storage.field_office_releasing = storage.field_office_releasing or {}
end

function M.track_entity(entity)
  if not entity or not entity.valid or not is_field_office(entity.name) then return end
  M.ensure_storage()
  storage.field_offices[entity.unit_number] = entity
  if not storage.field_office_state[entity.unit_number] then
    storage.field_office_state[entity.unit_number] = { phase = "idle" }
  end
end

function M.untrack_entity(entity)
  if not entity or not entity.unit_number then return end
  M.ensure_storage()
  local state = storage.field_office_state[entity.unit_number]
  if state then
    if state.biter and state.biter.valid then
      state.biter.destroy()
    end
    if state.overlay_id then
      local obj = rendering.get_object_by_id(state.overlay_id)
      if obj then obj.destroy() end
    end
  end
  storage.field_office_state[entity.unit_number] = nil
  storage.field_offices[entity.unit_number] = nil
end

local function find_nearest_spawner(surface, position, range)
  local spawners = surface.find_entities_filtered{
    type = SPAWNER_TYPES,
    position = position,
    radius = range,
    force = "enemy",
    limit = 1,
  }
  return spawners[1]
end

local function spawn_worker_biter(office, spawner)
  if not office or not office.valid or not spawner or not spawner.valid then return nil end

  local surface = office.surface
  local spawn_pos = surface.find_non_colliding_position("small-biter", spawner.position, 5, 0.5)
  if not spawn_pos then return nil end

  local biter = surface.create_entity{
    name = "small-biter",
    position = spawn_pos,
    force = get_biter_force(),
  }
  if not biter or not biter.valid then return nil end

  biter.commandable.set_command({
    type = defines.command.go_to_location,
    destination = office.position,
    radius = C.FIELD_OFFICE_ARRIVAL_RADIUS,
    distraction = defines.distraction.none,
  })

  return biter
end

local function distance_squared(pos1, pos2)
  local dx = pos1.x - pos2.x
  local dy = pos1.y - pos2.y
  return dx * dx + dy * dy
end

local function biter_has_arrived(biter, office)
  if not biter or not biter.valid or not office or not office.valid then return false end
  local threshold = C.FIELD_OFFICE_ARRIVAL_RADIUS + 0.5
  return distance_squared(biter.position, office.position) < threshold * threshold
end

local function create_working_overlay(biter)
  if not biter or not biter.valid then return nil end
  local render_obj = rendering.draw_text{
    text = {"gui.field-office-biter-working"},
    surface = biter.surface,
    target = {entity = biter, offset = {0, -1.8}},
    color = {r = 0.9, g = 0.85, b = 0.5},
    alignment = "center",
    vertical_alignment = "middle",
    scale = 1.0,
    scale_with_zoom = true,
  }
  return render_obj and render_obj.id or nil
end

local function destroy_overlay(state)
  if state.overlay_id then
    local obj = rendering.get_object_by_id(state.overlay_id)
    if obj then obj.destroy() end
    state.overlay_id = nil
  end
end

local function release_biter(state, tick)
  if not state.biter or not state.biter.valid then
    state.biter = nil
    return
  end

  -- Command biter to walk back to spawner (or wander if spawner gone)
  if state.spawner and state.spawner.valid then
    state.biter.commandable.set_command({
      type = defines.command.go_to_location,
      destination = state.spawner.position,
      radius = 3,
      distraction = defines.distraction.none,
    })
  end

  -- Track for despawn
  M.ensure_storage()
  storage.field_office_releasing[state.biter.unit_number] = {
    entity = state.biter,
    despawn_tick = tick + C.FIELD_OFFICE_BITER_DESPAWN_TICKS,
  }

  destroy_overlay(state)
  state.biter = nil
  state.spawner = nil
end

--- Check if the field office is shut down for the night (working hours).
local function is_night_shutdown(office)
  if not working_hours.is_enabled() then return false end
  if working_hours.entity_has_overtime_exemption(office) then return false end
  return working_hours.is_night(office.surface)
end

--- Check if the field office can craft (has recipe, ingredients, and output space).
--- Briefly activates the machine to read its status, then deactivates again.
local function can_craft(office)
  if not office or not office.valid then return false end
  if not office.get_recipe() then return false end

  -- Briefly activate to let Factorio evaluate crafting readiness
  office.active = true
  local status = office.status
  office.active = false

  -- These statuses mean the machine is ready or already working
  return status == defines.entity_status.working
      or status == defines.entity_status.normal
end

function M.update(tick)
  M.ensure_storage()

  -- Process releasing biters (despawn after timeout)
  for biter_id, info in pairs(storage.field_office_releasing) do
    if not info.entity or not info.entity.valid then
      storage.field_office_releasing[biter_id] = nil
    elseif tick >= info.despawn_tick then
      info.entity.destroy()
      storage.field_office_releasing[biter_id] = nil
    end
  end

  if not next(storage.field_offices) then return end
  if tick % C.FIELD_OFFICE_CHECK_TICKS ~= 0 then return end

  for office_id, office in pairs(storage.field_offices) do
    if not office or not office.valid then
      local state = storage.field_office_state[office_id]
      if state then
        if state.biter and state.biter.valid then state.biter.destroy() end
        destroy_overlay(state)
      end
      storage.field_office_state[office_id] = nil
      storage.field_offices[office_id] = nil
      goto continue
    end

    local state = storage.field_office_state[office_id]
    if not state then
      state = { phase = "idle" }
      storage.field_office_state[office_id] = state
    end

    local night = is_night_shutdown(office)

    if state.phase == "idle" then
      -- Building is inactive while waiting
      office.active = false

      -- Don't summon biters at night
      if night then
        office.custom_status = {
          diode = defines.entity_status_diode.red,
          label = {"gui.working-hours-night-status"},
        }
        goto continue
      end

      -- Only call for a biter if the building can actually craft
      if not can_craft(office) then
        office.custom_status = nil  -- let Factorio show native status
        goto continue
      end

      -- Search for a spawner and summon a biter
      local spawner = find_nearest_spawner(office.surface, office.position, C.FIELD_OFFICE_SPAWNER_RANGE)
      if spawner then
        local biter = spawn_worker_biter(office, spawner)
        if biter then
          state.phase = "calling"
          state.biter = biter
          state.spawner = spawner
          office.custom_status = {
            diode = defines.entity_status_diode.yellow,
            label = {"gui.field-office-calling"},
          }
        else
          office.custom_status = {
            diode = defines.entity_status_diode.red,
            label = {"gui.field-office-no-nest"},
          }
        end
      else
        office.custom_status = {
          diode = defines.entity_status_diode.red,
          label = {"gui.field-office-no-nest"},
        }
      end

    elseif state.phase == "calling" then
      -- Building is inactive while biter is travelling
      office.active = false

      -- If night falls while biter is en route, release it
      if night then
        if state.biter and state.biter.valid then
          release_biter(state, tick)
        else
          state.biter = nil
        end
        state.phase = "idle"
        office.custom_status = {
          diode = defines.entity_status_diode.red,
          label = {"gui.working-hours-night-status"},
        }
        goto continue
      end

      -- Check if biter is still alive
      if not state.biter or not state.biter.valid then
        state.biter = nil
        state.phase = "idle"
        goto continue
      end

      -- Check if biter has arrived
      if biter_has_arrived(state.biter, office) then
        -- Stop biter movement
        state.biter.commandable.set_command({
          type = defines.command.stop,
          distraction = defines.distraction.none,
        })

        -- Show working overlay
        state.overlay_id = create_working_overlay(state.biter)

        -- Activate the building
        office.active = true
        state.products_at_arrival = office.products_finished
        state.phase = "working"

        office.custom_status = {
          diode = defines.entity_status_diode.green,
          label = {"gui.field-office-working"},
        }
      else
        office.custom_status = {
          diode = defines.entity_status_diode.yellow,
          label = {"gui.field-office-calling"},
        }
      end

    elseif state.phase == "working" then
      -- Check if biter died while working
      if not state.biter or not state.biter.valid then
        destroy_overlay(state)
        state.biter = nil
        state.phase = "idle"
        office.active = false
        office.custom_status = {
          diode = defines.entity_status_diode.red,
          label = {"gui.field-office-no-nest"},
        }
        goto continue
      end

      -- If night falls, release biter and shut down
      if night then
        release_biter(state, tick)
        state.phase = "idle"
        office.active = false
        office.custom_status = {
          diode = defines.entity_status_diode.red,
          label = {"gui.working-hours-night-status"},
        }
        goto continue
      end

      -- Release if the machine has nothing left to do (office is already active, check status directly)
      local status = office.status
      if not office.get_recipe()
         or (status ~= defines.entity_status.working and status ~= defines.entity_status.normal) then
        release_biter(state, tick)
        state.phase = "idle"
        office.active = false
        office.custom_status = nil
        goto continue
      end

      -- Check if the biter has completed its shift (5 crafts)
      if office.products_finished >= (state.products_at_arrival or 0) + CRAFTS_PER_BITER then
        -- Release the biter
        release_biter(state, tick)
        office.active = false

        -- Immediately try to summon next biter
        local spawner = find_nearest_spawner(office.surface, office.position, C.FIELD_OFFICE_SPAWNER_RANGE)
        if spawner then
          local biter = spawn_worker_biter(office, spawner)
          if biter then
            state.phase = "calling"
            state.biter = biter
            state.spawner = spawner
            office.custom_status = {
              diode = defines.entity_status_diode.yellow,
              label = {"gui.field-office-calling"},
            }
          else
            state.phase = "idle"
            office.custom_status = {
              diode = defines.entity_status_diode.red,
              label = {"gui.field-office-no-nest"},
            }
          end
        else
          state.phase = "idle"
          office.custom_status = {
            diode = defines.entity_status_diode.red,
            label = {"gui.field-office-no-nest"},
          }
        end
      end
    end

    ::continue::
  end
end

function M.rebuild_registry()
  M.ensure_storage()

  -- Destroy existing worker biters and overlays before rebuild
  for _, state in pairs(storage.field_office_state) do
    if state.biter and state.biter.valid then state.biter.destroy() end
    destroy_overlay(state)
  end
  for _, info in pairs(storage.field_office_releasing) do
    if info.entity and info.entity.valid then info.entity.destroy() end
  end

  storage.field_offices = {}
  storage.field_office_state = {}
  storage.field_office_releasing = {}

  for _, surface in pairs(game.surfaces) do
    for _, entity in ipairs(surface.find_entities_filtered{name = ENTITY_NAME}) do
      if entity.valid and entity.unit_number then
        storage.field_offices[entity.unit_number] = entity
        storage.field_office_state[entity.unit_number] = { phase = "idle" }
      end
    end
  end
end

M.is_field_office = is_field_office

return M
