local feature_flags = require("feature_flags")
local working_hours = require("scripts.working_hours")

local M = {}

local ENTITY_NAME = "administrative-clock"
local DAYTIME_SIGNAL = "signal-daytime"
local WORKING_HOURS_SIGNAL = "signal-working-hours"
local DAY_SHIFT_START_SIGNAL = "signal-day-shift-start"
local DAY_SHIFT_END_SIGNAL = "signal-day-shift-end"
local DAYTIME_SCALE = 100

function M.ensure_storage()
  storage.administrative_clocks = storage.administrative_clocks or {}
  storage.administrative_clock_states = storage.administrative_clock_states or {}
end

local function is_clock(entity)
  return entity and entity.valid and entity.name == ENTITY_NAME and entity.unit_number ~= nil
end

local function update_signals(clock)
  if not is_clock(clock) then return end

  local daytime, is_night = working_hours.get_daytime_state(clock.surface, clock.position)
  if daytime == nil then return end

  local daytime_value = math.floor((((math.max(0, math.min(1, daytime)) + 0.5) % 1) * DAYTIME_SCALE) + 0.5)
  local shift_start, shift_end = working_hours.get_day_shift_bounds()
  local previous_state = storage.administrative_clock_states[clock.unit_number]
  if previous_state
     and previous_state.daytime_value == daytime_value
     and previous_state.is_night == is_night then
    return
  end

  local behavior = clock.get_or_create_control_behavior()
  if not behavior then return end
  local section = behavior.get_section(1)
  if not section then section = behavior.add_section() end
  if not section then return end

  section.set_slot(1, {value = DAYTIME_SIGNAL, min = daytime_value, max = daytime_value})
  if is_night then
    section.clear_slot(2)
  else
    section.set_slot(2, {value = WORKING_HOURS_SIGNAL, min = 1, max = 1})
  end
  section.set_slot(3, {value = DAY_SHIFT_START_SIGNAL, min = shift_start, max = shift_start})
  section.set_slot(4, {value = DAY_SHIFT_END_SIGNAL, min = shift_end, max = shift_end})
  storage.administrative_clock_states[clock.unit_number] = {
    daytime_value = daytime_value,
    is_night = is_night,
  }
end

function M.track_entity(entity)
  if not is_clock(entity) then return end
  M.ensure_storage()
  storage.administrative_clocks[entity.unit_number] = entity
  update_signals(entity)
end

function M.untrack_entity(entity)
  if not entity or not entity.unit_number then return end
  M.ensure_storage()
  storage.administrative_clocks[entity.unit_number] = nil
  storage.administrative_clock_states[entity.unit_number] = nil
end

function M.rebuild_registry()
  M.ensure_storage()
  storage.administrative_clocks = {}
  storage.administrative_clock_states = {}
  if not feature_flags.entity_prototype_exists(ENTITY_NAME) then return end

  for _, surface in pairs(game.surfaces) do
    for _, entity in ipairs(surface.find_entities_filtered{name = ENTITY_NAME}) do
      if is_clock(entity) then
        storage.administrative_clocks[entity.unit_number] = entity
        update_signals(entity)
      end
    end
  end
end

function M.update()
  M.ensure_storage()
  for unit_number, clock in pairs(storage.administrative_clocks) do
    if is_clock(clock) then
      update_signals(clock)
    else
      storage.administrative_clocks[unit_number] = nil
      storage.administrative_clock_states[unit_number] = nil
    end
  end
end

return M
