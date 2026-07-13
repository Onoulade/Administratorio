local taxonomy = require("prototypes.shared.paperwork_taxonomy")
local rules = require("scripts.archive_recombination_rules")

local M = {}

M.ENTITY_NAME = "archive-recombination-bureau"
M.POWER_SINK_NAME = "archive-recombination-power-sink"
M.PROCESS_TICKS = 20 * 60
M.UPDATE_TICKS = 60
M.POWER_READY_ENERGY = 1

local generated_pairs = rules.generate_all_pairs()

local function ensure_storage()
  storage.archive_recombination_bureaus = storage.archive_recombination_bureaus or {}
  -- Removed in the standard-UI revision; discard any stale selector state.
  storage.archive_recombination_gui = nil
end

local function get_quality_name(stack)
  local quality = stack and stack.quality or nil
  if quality and type(quality) ~= "string" then return quality.name end
  return quality or "normal"
end

local function input_inventory(entity)
  local inventory_id = defines and defines.inventory and defines.inventory.lab_input
  return inventory_id and entity.get_inventory(inventory_id) or nil
end

local function available_pair(force, left_name, right_name)
  local pair = generated_pairs[rules.pair_key(left_name, right_name)]
  if not pair then return nil end
  local available = rules.available_candidates(pair.candidates, force)
  if #available == 0 then return nil end
  return pair, available
end

local function find_compatible_stacks(entity)
  local inventory = input_inventory(entity)
  if not inventory then return nil end

  for left_index = 1, #inventory - 1 do
    local left = inventory[left_index]
    if left and left.valid_for_read and (left.count or 0) > 0 and taxonomy.is_recyclable(left.name) then
      local left_quality = get_quality_name(left)
      for right_index = left_index + 1, #inventory do
        local right = inventory[right_index]
        if right and right.valid_for_read and (right.count or 0) > 0
          and right.name ~= left.name
          and taxonomy.is_recyclable(right.name)
          and get_quality_name(right) == left_quality
        then
          local pair, available = available_pair(entity.force, left.name, right.name)
          if pair then return left, right, pair, available, left_quality end
        end
      end
    end
  end
  return nil
end

local function state_for(entity)
  if not entity or not entity.valid or entity.name ~= M.ENTITY_NAME then return nil end
  ensure_storage()
  local state = storage.archive_recombination_bureaus[entity.unit_number]
  if not state then
    state = {entity = entity, attempts = 0, successes = 0, failures = 0}
    storage.archive_recombination_bureaus[entity.unit_number] = state
  else
    state.entity = entity
  end
  return state
end

local function destroy_power_sink(state)
  local sink = state and state.power_sink or nil
  if sink and sink.valid and sink.destroy then sink.destroy() end
  if state then state.power_sink = nil end
end

local function ensure_power_sink(state)
  local sink = state and state.power_sink or nil
  if sink and sink.valid then return sink end
  local entity = state and state.entity or nil
  if not entity or not entity.valid or not entity.surface or not entity.surface.create_entity then return nil end
  sink = entity.surface.create_entity{
    name = M.POWER_SINK_NAME,
    position = entity.position,
    force = entity.force,
    create_build_effect_smoke = false,
  }
  if sink then
    sink.destructible = false
    state.power_sink = sink
  end
  return sink
end

local function set_status(entity, diode, label)
  if not entity or not entity.valid then return end
  entity.custom_status = {
    diode = diode,
    label = label,
  }
end

local function idle_status(entity)
  local diode = defines and defines.entity_status_diode and defines.entity_status_diode.red or nil
  set_status(entity, diode, {"entity-status.archive-recombination-waiting"})
end

local function working_status(entity)
  local diode = defines and defines.entity_status_diode and defines.entity_status_diode.yellow or nil
  set_status(entity, diode, {"entity-status.archive-recombination-working"})
end

local function no_power_status(entity)
  local diode = defines and defines.entity_status_diode and defines.entity_status_diode.red or nil
  set_status(entity, diode, {"entity-status.archive-recombination-no-power"})
end

local function output_position(entity)
  -- The Lab-derived Bureau is visually symmetric and non-rotatable. Its east
  -- edge acts as a mining-drill-style output chute; belts are preferred.
  return {x = entity.position.x + 2, y = entity.position.y}
end

local function spill_output(entity, item_name, quality_name)
  if not entity.surface or not entity.surface.spill_item_stack then return false end
  local spilled = entity.surface.spill_item_stack{
    position = output_position(entity),
    stack = {name = item_name, count = 1, quality = quality_name},
    enable_looted = true,
    force = entity.force,
    allow_belts = true,
    max_radius = 1,
    use_start_position_on_failure = true,
    drop_full_stack = true,
  }
  return spilled ~= nil
end

local function begin_attempt(state)
  local entity = state.entity
  local left_stack, right_stack, pair, _, quality = find_compatible_stacks(entity)
  if not pair then
    destroy_power_sink(state)
    idle_status(entity)
    return false
  end

  left_stack.count = left_stack.count - 1
  right_stack.count = right_stack.count - 1
  state.left = pair.left
  state.right = pair.right
  state.quality = quality
  state.remaining_ticks = M.PROCESS_TICKS
  state.working = true
  ensure_power_sink(state)
  working_status(entity)
  return true
end

local function finish_attempt(state)
  local entity = state.entity
  local next_attempt = (state.attempts or 0) + 1
  local pair, available = available_pair(entity.force, state.left, state.right)
  local success_roll = rules.deterministic_roll(entity.unit_number, next_attempt,
    state.left, state.right, "success")
  local result_name

  if pair and success_roll < rules.SUCCESS_PERCENT then
    local output_roll = rules.deterministic_roll(entity.unit_number, next_attempt,
      state.left, state.right, tostring(entity.force and entity.force.index or 0) .. ":output")
    local candidate = rules.choose_candidate(available, output_roll)
    result_name = candidate and candidate.name or nil
  end

  if result_name and spill_output(entity, result_name, state.quality) then
    state.successes = (state.successes or 0) + 1
    state.last_result = result_name
  else
    state.failures = (state.failures or 0) + 1
    state.last_result = nil
  end
  state.attempts = next_attempt
  state.left = nil
  state.right = nil
  state.quality = nil
  state.remaining_ticks = nil
  state.working = false
  destroy_power_sink(state)
  idle_status(entity)
end

local function process_state(state)
  local entity = state and state.entity or nil
  if not entity or not entity.valid then
    destroy_power_sink(state)
    return false
  end

  if not state.working and not begin_attempt(state) then return true end

  local power_sink = ensure_power_sink(state)
  if not power_sink or (power_sink.energy or 0) < M.POWER_READY_ENERGY then
    no_power_status(entity)
    return true
  end
  state.remaining_ticks = math.max(0, (state.remaining_ticks or M.PROCESS_TICKS) - M.UPDATE_TICKS)
  working_status(entity)
  if state.remaining_ticks == 0 then finish_attempt(state) end
  return true
end

function M.ensure_storage()
  ensure_storage()
end

function M.is_bureau(entity)
  return entity and entity.valid and entity.name == M.ENTITY_NAME
end

function M.rebuild_registry()
  ensure_storage()
  local rebuilt = {}
  if prototypes and prototypes.entity and prototypes.entity[M.ENTITY_NAME] then
    for _, surface in pairs(game.surfaces) do
      for _, sink in ipairs(surface.find_entities_filtered{name = M.POWER_SINK_NAME}) do
        if sink.valid then sink.destroy() end
      end
      for _, entity in ipairs(surface.find_entities_filtered{name = M.ENTITY_NAME}) do
        local state = storage.archive_recombination_bureaus[entity.unit_number]
          or {attempts = 0, successes = 0, failures = 0}
        state.entity = entity
        state.power_sink = nil
        if state.working then ensure_power_sink(state) end
        rebuilt[entity.unit_number] = state
      end
    end
  end
  storage.archive_recombination_bureaus = rebuilt
end

function M.on_entity_built(entity)
  if not M.is_bureau(entity) then return false end
  idle_status(entity)
  state_for(entity)
  return true
end

function M.on_entity_removed(entity)
  if not entity or entity.name ~= M.ENTITY_NAME then return false end
  ensure_storage()
  destroy_power_sink(storage.archive_recombination_bureaus[entity.unit_number])
  storage.archive_recombination_bureaus[entity.unit_number] = nil
  return true
end

function M.on_tick()
  ensure_storage()
  for unit_number, state in pairs(storage.archive_recombination_bureaus) do
    if not process_state(state) then storage.archive_recombination_bureaus[unit_number] = nil end
  end
end

M.process_state = process_state
M.find_compatible_stacks = find_compatible_stacks
M.ensure_power_sink = ensure_power_sink

return M
