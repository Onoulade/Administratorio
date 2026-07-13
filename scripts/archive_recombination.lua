local rules = require("scripts.archive_recombination_rules")

local M = {}

M.ENTITY_NAME = "archive-recombination-bureau"
M.ATTEMPT_ITEM = "archive-attempt-record"
M.ENVELOPE_ITEM = "recombination-envelope"
M.RESIDUE_ITEM = "archive-residue"

local FRAME_NAME = "administratorio-archive-recombination"
local LEFT_SELECTOR = "administratorio-archive-left"
local RIGHT_SELECTOR = "administratorio-archive-right"
local APPLY_BUTTON = "administratorio-archive-apply"
local CLOSE_BUTTON = "administratorio-archive-close"
local PREVIEW_LABEL = "administratorio-archive-preview"
local STATS_LABEL = "administratorio-archive-stats"
local STATUS_LABEL = "administratorio-archive-status"
local COMBINATOR_NAME = "fax-network-combinator"

local CIRCUIT_SIGNALS = {
  "signal-archive-input-ready",
  "signal-archive-valid-pair",
  "signal-archive-working",
  "signal-archive-successes",
  "signal-archive-failures",
  "signal-archive-output-blocked",
}

local generated_pairs = rules.generate_all_pairs()
local pair_keys = {}
for key in pairs(generated_pairs) do pair_keys[#pair_keys + 1] = key end
table.sort(pair_keys)

local recipe_by_pair = {}
local pair_by_recipe = {}
for index, key in ipairs(pair_keys) do
  local recipe_name = string.format("archive-recombination-%03d", index)
  recipe_by_pair[key] = recipe_name
  pair_by_recipe[recipe_name] = generated_pairs[key]
end

local function ensure_storage()
  storage.archive_recombination_bureaus = storage.archive_recombination_bureaus or {}
  storage.archive_recombination_gui = storage.archive_recombination_gui or {}
end

local function get_quality_name(stack)
  local quality = stack and stack.quality or nil
  if quality and type(quality) ~= "string" then return quality.name end
  return quality or "normal"
end

local function connect_combinator(entity, combinator)
  if not entity or not entity.valid or not combinator or not combinator.valid then return end
  if not entity.get_wire_connector or not combinator.get_wire_connector then return end
  local connector_ids = defines and defines.wire_connector_id or nil
  if not connector_ids then return end
  for _, id in ipairs({connector_ids.circuit_red, connector_ids.circuit_green}) do
    local entity_connector = entity.get_wire_connector(id, true)
    local combinator_connector = combinator.get_wire_connector(id, true)
    if entity_connector and combinator_connector then entity_connector.connect_to(combinator_connector) end
  end
end

local function ensure_combinator(state)
  local entity = state and state.entity or nil
  if not entity or not entity.valid then return nil end
  if not entity.surface or not entity.surface.create_entity then return nil end
  if not state.combinator or not state.combinator.valid then
    state.combinator = entity.surface.create_entity{
      name = COMBINATOR_NAME,
      position = entity.position,
      force = entity.force,
    }
    if state.combinator then state.combinator.destructible = false end
  end
  connect_combinator(entity, state.combinator)
  return state.combinator
end

local function destroy_combinator(state)
  if state and state.combinator and state.combinator.valid then state.combinator.destroy() end
  if state then state.combinator = nil end
end

local function set_circuit_outputs(state, counts)
  local combinator = ensure_combinator(state)
  local behavior = combinator and combinator.get_or_create_control_behavior and combinator.get_or_create_control_behavior() or nil
  if not behavior then return end
  local section = behavior.get_section and behavior.get_section(1) or nil
  if not section and behavior.add_section then section = behavior.add_section() end
  if not section then return end
  for index, signal_name in ipairs(CIRCUIT_SIGNALS) do
    local count = counts[index] or 0
    if count > 0 then
      section.set_slot(index, {value = signal_name, min = count})
    else
      section.clear_slot(index)
    end
  end
end

local function find_child(element, name)
  if not element or not element.valid then return nil end
  if element.name == name then return element end
  for _, child in pairs(element.children or {}) do
    local found = find_child(child, name)
    if found then return found end
  end
  return nil
end

local function get_frame(player)
  return player and player.valid and player.gui and player.gui.screen and player.gui.screen[FRAME_NAME] or nil
end

local function current_pair(entity)
  if not entity or not entity.valid or not entity.get_recipe then return nil end
  local recipe, quality = entity.get_recipe()
  local pair = recipe and pair_by_recipe[recipe.name] or nil
  return pair, quality and quality.name or "normal"
end

local function state_for(entity)
  if not entity or not entity.valid or entity.name ~= M.ENTITY_NAME then return nil end
  ensure_storage()
  local unit_number = entity.unit_number
  local state = storage.archive_recombination_bureaus[unit_number]
  if not state then
    state = {entity = entity, attempts = 0, successes = 0, failures = 0}
    storage.archive_recombination_bureaus[unit_number] = state
  else
    state.entity = entity
  end
  local pair, quality = current_pair(entity)
  if pair then
    state.left = pair.left
    state.right = pair.right
    state.left_quality = state.left_quality or quality
    state.right_quality = state.right_quality or quality
  end
  return state
end

local function format_candidate(candidate, force, available_weight)
  if not rules.technology_unlocked(force, candidate.unlock_technology) then
    return {"gui.archive-recombination-candidate-locked",
      {"item-name." .. candidate.name}, {"technology-name." .. candidate.unlock_technology}}
  end
  local percent = available_weight > 0 and math.floor(candidate.weight / available_weight * 1000 + 0.5) / 10 or 0
  return {"gui.archive-recombination-candidate-available", {"item-name." .. candidate.name}, percent}
end

local function update_gui(player)
  local gui_state = storage.archive_recombination_gui[player.index]
  local frame = get_frame(player)
  if not gui_state or not frame or not frame.valid then return end
  local bureau_state = storage.archive_recombination_bureaus[gui_state.unit_number]
  local entity = bureau_state and bureau_state.entity or nil
  local pair = rules.pair_key(gui_state.left, gui_state.right)
  local candidates = pair and generated_pairs[pair] and generated_pairs[pair].candidates or nil
  local available = entity and entity.valid and rules.available_candidates(candidates, entity.force) or {}
  local preview = find_child(frame, PREVIEW_LABEL)
  if preview then
    if not candidates then
      preview.caption = {"gui.archive-recombination-invalid-pair"}
    elseif (gui_state.left_quality or "normal") ~= (gui_state.right_quality or "normal") then
      preview.caption = {"gui.archive-recombination-quality-mismatch"}
    elseif #available == 0 then
      preview.caption = {"gui.archive-recombination-no-unlocked-output"}
    else
      local caption = {"", {"gui.archive-recombination-possible-outputs"}, " "}
      local available_weight = 0
      for _, candidate in ipairs(available) do available_weight = available_weight + (candidate.weight or 0) end
      for index, candidate in ipairs(candidates) do
        if index > 1 then caption[#caption + 1] = ", " end
        caption[#caption + 1] = format_candidate(candidate, entity.force, available_weight)
      end
      preview.caption = caption
    end
  end
  local stats = find_child(frame, STATS_LABEL)
  if stats and bureau_state then
    stats.caption = {"gui.archive-recombination-statistics", bureau_state.attempts or 0,
      bureau_state.successes or 0, bureau_state.failures or 0}
  end
  local status = find_child(frame, STATUS_LABEL)
  if status and bureau_state and entity and entity.valid then
    local progress = math.floor(math.max(0, math.min(1, entity.crafting_progress or 0)) * 100)
    local last_result
    if bureau_state.last_result then
      last_result = {"item-name." .. bureau_state.last_result}
    elseif (bureau_state.attempts or 0) > 0 then
      last_result = {"gui.archive-recombination-last-failed"}
    else
      last_result = {"gui.archive-recombination-last-none"}
    end
    status.caption = {"gui.archive-recombination-status", progress, last_result}
  end
end

local function close_gui(player)
  local frame = get_frame(player)
  if frame and frame.valid then frame.destroy() end
  if storage.archive_recombination_gui then storage.archive_recombination_gui[player.index] = nil end
end

local function open_gui(player, entity)
  close_gui(player)
  local state = state_for(entity)
  if not state then return false end
  storage.archive_recombination_gui[player.index] = {
    unit_number = entity.unit_number,
    left = state.left,
    right = state.right,
    left_quality = state.left_quality or "normal",
    right_quality = state.right_quality or "normal",
    suppress_close_once = true,
  }

  local frame = player.gui.screen.add{type = "frame", name = FRAME_NAME, direction = "vertical"}
  local titlebar = frame.add{type = "flow", direction = "horizontal"}
  titlebar.drag_target = frame
  local title = titlebar.add{type = "label", caption = {"gui.archive-recombination-title"}, style = "frame_title"}
  title.drag_target = frame
  local drag = titlebar.add{type = "empty-widget", style = "draggable_space_header"}
  drag.style.horizontally_stretchable = true
  drag.style.height = 24
  drag.drag_target = frame
  titlebar.add{type = "sprite-button", name = CLOSE_BUTTON, sprite = "utility/close", style = "frame_action_button"}

  frame.add{type = "label", caption = {"gui.archive-recombination-instructions"}}
  local selectors = frame.add{type = "flow", direction = "horizontal"}
  local left = selectors.add{type = "choose-elem-button", name = LEFT_SELECTOR, elem_type = "item-with-quality"}
  if state.left then
    left.elem_value = {name = state.left, quality = state.left_quality or "normal"}
  end
  selectors.add{type = "label", caption = {"gui.archive-recombination-plus"}}
  local right = selectors.add{type = "choose-elem-button", name = RIGHT_SELECTOR, elem_type = "item-with-quality"}
  if state.right then
    right.elem_value = {name = state.right, quality = state.right_quality or "normal"}
  end
  selectors.add{type = "sprite", sprite = "utility/enter"}
  selectors.add{type = "label", caption = {"gui.archive-recombination-success-rate"}}
  frame.add{type = "label", name = PREVIEW_LABEL, caption = {"gui.archive-recombination-invalid-pair"}}
  frame.add{type = "label", name = STATS_LABEL, caption = ""}
  frame.add{type = "label", name = STATUS_LABEL, caption = ""}
  frame.add{type = "button", name = APPLY_BUTTON, caption = {"gui.archive-recombination-apply"}, style = "confirm_button"}
  if frame.force_auto_center then frame.force_auto_center() end
  if player.opened == entity then player.opened = nil end
  player.opened = frame
  update_gui(player)
  return true
end

local function find_stack(inventory, item_name, quality_name)
  if not inventory then return nil end
  for index = 1, #inventory do
    local stack = inventory[index]
    if stack and stack.valid_for_read and (stack.count or 0) > 0 and stack.name == item_name
      and (not quality_name or get_quality_name(stack) == quality_name)
    then
      return stack
    end
  end
  return nil
end

local function process_state(state)
  local entity = state and state.entity or nil
  if not entity or not entity.valid then return false end
  local output = entity.get_inventory(defines.inventory.assembling_machine_output)
  if not output then return true end
  state.output_blocked = false

  for _ = 1, 100 do
    local record = find_stack(output, M.ATTEMPT_ITEM)
    if not record then break end
    local quality = get_quality_name(record)
    local envelope = find_stack(output, M.ENVELOPE_ITEM, quality) or find_stack(output, M.ENVELOPE_ITEM)
    local candidates = generated_pairs[rules.pair_key(state.left, state.right)]
    candidates = candidates and rules.available_candidates(candidates.candidates, entity.force) or {}
    local result_name
    if envelope and #candidates > 0 then
      local roll = rules.deterministic_roll(entity.unit_number, (state.attempts or 0) + 1,
        state.left, state.right, tostring(entity.force and entity.force.index or 0) .. ":output")
      local candidate = rules.choose_candidate(candidates, roll)
      result_name = candidate and candidate.name or nil
    elseif not envelope then
      result_name = M.RESIDUE_ITEM
    else
      state.output_blocked = true
      break
    end

    local result_stack = {name = result_name, count = 1, quality = quality}
    record.count = record.count - 1
    if envelope then envelope.count = envelope.count - 1 end
    local inserted = output.insert(result_stack)
    if inserted ~= 1 then
      output.insert{name = M.ATTEMPT_ITEM, count = 1, quality = quality}
      if envelope then output.insert{name = M.ENVELOPE_ITEM, count = 1, quality = quality} end
      state.output_blocked = true
      break
    end

    state.attempts = (state.attempts or 0) + 1
    if envelope then
      state.successes = (state.successes or 0) + 1
      state.last_result = result_name
    else
      state.failures = (state.failures or 0) + 1
      state.last_result = nil
    end
  end

  local input = entity.get_inventory(defines.inventory.assembling_machine_input)
  local pair = generated_pairs[rules.pair_key(state.left, state.right)]
  local available = pair and rules.available_candidates(pair.candidates, entity.force) or {}
  local quality = state.left_quality or "normal"
  local input_ready = input and state.left and state.right
    and find_stack(input, state.left, quality) ~= nil
    and find_stack(input, state.right, quality) ~= nil
    and find_stack(input, "archival-substrate", quality) ~= nil
  set_circuit_outputs(state, {
    input_ready and 1 or 0,
    #available > 0 and 1 or 0,
    (entity.crafting_progress or 0) > 0 and 1 or 0,
    state.successes or 0,
    state.failures or 0,
    state.output_blocked and 1 or 0,
  })
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
      for _, entity in ipairs(surface.find_entities_filtered{name = M.ENTITY_NAME}) do
        local previous = storage.archive_recombination_bureaus[entity.unit_number] or {}
        previous.entity = entity
        local pair, quality = current_pair(entity)
        if pair then
          previous.left, previous.right = pair.left, pair.right
          previous.left_quality = previous.left_quality or quality
          previous.right_quality = previous.right_quality or quality
        end
        ensure_combinator(previous)
        rebuilt[entity.unit_number] = previous
      end
    end
  end
  storage.archive_recombination_bureaus = rebuilt
end

function M.on_entity_built(entity)
  if not M.is_bureau(entity) then return false end
  ensure_combinator(state_for(entity))
  return true
end

function M.on_entity_removed(entity)
  if not entity or entity.name ~= M.ENTITY_NAME then return false end
  ensure_storage()
  destroy_combinator(storage.archive_recombination_bureaus[entity.unit_number])
  storage.archive_recombination_bureaus[entity.unit_number] = nil
  for player_index, gui_state in pairs(storage.archive_recombination_gui) do
    if gui_state.unit_number == entity.unit_number then
      local player = game.get_player(player_index)
      if player then close_gui(player) end
    end
  end
  return true
end

function M.on_tick()
  ensure_storage()
  for unit_number, state in pairs(storage.archive_recombination_bureaus) do
    if not process_state(state) then storage.archive_recombination_bureaus[unit_number] = nil end
  end
end

function M.on_gui_opened(player, entity)
  if not M.is_bureau(entity) then return false end
  return open_gui(player, entity)
end

function M.on_gui_closed(player)
  if not player or not storage.archive_recombination_gui or not storage.archive_recombination_gui[player.index] then
    return false
  end
  local gui_state = storage.archive_recombination_gui[player.index]
  if gui_state.suppress_close_once then
    gui_state.suppress_close_once = false
    return true
  end
  close_gui(player)
  return true
end

function M.on_gui_click(event)
  local element = event.element
  if not element or not element.valid then return false end
  if element.name ~= APPLY_BUTTON and element.name ~= CLOSE_BUTTON then return false end
  local player = game.get_player(event.player_index)
  if not player then return true end
  if element.name == CLOSE_BUTTON then
    close_gui(player)
    return true
  end

  local gui_state = storage.archive_recombination_gui[player.index]
  local state = gui_state and storage.archive_recombination_bureaus[gui_state.unit_number] or nil
  local entity = state and state.entity or nil
  local key = gui_state and rules.pair_key(gui_state.left, gui_state.right) or nil
  local pair = key and generated_pairs[key] or nil
  local candidates = pair and entity and rules.available_candidates(pair.candidates, entity.force) or {}
  if not entity or not entity.valid or not pair or #candidates == 0 then
    player.create_local_flying_text{text = {"message.archive-recombination-invalid"}, position = player.position}
    return true
  end
  local left_quality = gui_state.left_quality or "normal"
  local right_quality = gui_state.right_quality or "normal"
  if left_quality ~= right_quality then
    player.create_local_flying_text{text = {"message.archive-recombination-quality-mismatch"}, position = player.position}
    return true
  end
  entity.set_recipe(recipe_by_pair[key], left_quality)
  state.left, state.right = pair.left, pair.right
  state.left_quality, state.right_quality = left_quality, right_quality
  gui_state.left, gui_state.right = pair.left, pair.right
  player.create_local_flying_text{text = {"message.archive-recombination-configured"}, position = entity.position}
  update_gui(player)
  return true
end

function M.on_gui_elem_changed(event)
  local element = event.element
  if not element or not element.valid or (element.name ~= LEFT_SELECTOR and element.name ~= RIGHT_SELECTOR) then
    return false
  end
  local player = game.get_player(event.player_index)
  local gui_state = player and storage.archive_recombination_gui[player.index] or nil
  if not gui_state then return true end
  local value = element.elem_value
  local item_name = type(value) == "table" and value.name or value
  local quality_name = type(value) == "table" and value.quality or "normal"
  if element.name == LEFT_SELECTOR then
    gui_state.left, gui_state.left_quality = item_name, quality_name
  else
    gui_state.right, gui_state.right_quality = item_name, quality_name
  end
  update_gui(player)
  return true
end

M.process_state = process_state
M.recipe_by_pair = recipe_by_pair
M.pair_by_recipe = pair_by_recipe

return M
