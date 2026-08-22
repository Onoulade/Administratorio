local M = {}

--- script.on_nth_tick replaces any handler already registered for an interval,
--- so two systems that happen to share a cadence silently evict each other.
--- Collecting handlers per interval and registering one dispatcher each lets
--- every system pick the cadence its own behaviour needs, independently of what
--- any other system picked.
local function register_nth_tick_handlers(registrations)
  local handlers_by_interval = {}
  local intervals = {}

  for _, registration in ipairs(registrations) do
    local interval, handler = registration[1], registration[2]
    if interval and handler then
      local handlers = handlers_by_interval[interval]
      if not handlers then
        handlers = {}
        handlers_by_interval[interval] = handlers
        intervals[#intervals + 1] = interval
      end
      handlers[#handlers + 1] = handler
    end
  end

  -- Sorted so registration order is stable regardless of table iteration order.
  table.sort(intervals)

  for _, interval in ipairs(intervals) do
    local handlers = handlers_by_interval[interval]
    if #handlers == 1 then
      script.on_nth_tick(interval, handlers[1])
    else
      script.on_nth_tick(interval, function(event)
        for _, handler in ipairs(handlers) do
          handler(event)
        end
      end)
    end
  end
end

function M.register(deps)
  script.on_init(deps.on_init)
  script.on_configuration_changed(deps.on_configuration_changed)
  script.on_load(deps.on_load)
  script.on_event(defines.events.on_runtime_mod_setting_changed, deps.on_runtime_mod_setting_changed)

  script.on_event(defines.events.on_player_created, deps.on_player_created)
  script.on_event(defines.events.on_player_respawned, deps.on_player_respawned)
  script.on_event(defines.events.on_player_joined_game, deps.on_player_joined_game)
  script.on_event(defines.events.on_player_left_game, deps.on_player_left_game)
  script.on_event(defines.events.on_player_crafted_item, deps.on_player_crafted_item)
  script.on_event(defines.events.on_player_cursor_stack_changed, deps.on_player_cursor_stack_changed)
  script.on_event(defines.events.on_selected_entity_changed, deps.on_selected_entity_changed)
  script.on_event(defines.events.on_player_selected_area, deps.on_player_selected_area)
  script.on_event(defines.events.on_player_alt_selected_area, deps.on_player_selected_area)
  script.on_event(defines.events.on_player_reverse_selected_area, deps.on_player_reverse_selected_area)
  script.on_event(defines.events.on_player_alt_reverse_selected_area, deps.on_player_reverse_selected_area)
  script.on_event(defines.events.on_pre_build, deps.on_pre_build)

  script.on_event(defines.events.on_built_entity, deps.on_entity_built)
  script.on_event(defines.events.on_robot_built_entity, deps.on_entity_built)
  script.on_event(defines.events.script_raised_built, deps.on_entity_built)
  script.on_event(defines.events.script_raised_revive, deps.on_entity_built)
  script.on_event(defines.events.on_player_mined_entity, deps.on_entity_removed)
  script.on_event(defines.events.on_robot_mined_entity, deps.on_entity_removed)
  script.on_event(defines.events.script_raised_destroy, deps.on_entity_removed)
  if deps.on_pre_entity_removed then
    if defines.events.on_pre_player_mined_item then
      script.on_event(defines.events.on_pre_player_mined_item, deps.on_pre_entity_removed)
    end
    if defines.events.on_robot_pre_mined then
      script.on_event(defines.events.on_robot_pre_mined, deps.on_pre_entity_removed)
    end
  end
  if deps.on_player_rotated_entity then
    script.on_event(defines.events.on_player_rotated_entity, deps.on_player_rotated_entity)
  end

  script.on_event("administratorio-toggle-runtime-debug", deps.on_toggle_runtime_debug)
  script.on_event("administratorio-field-agent-toggle-select", deps.on_field_agent_waypoint_input)
  script.on_event("administratorio-field-agent-set-waypoint", deps.on_field_agent_waypoint_input)
  script.on_event("administratorio-field-agent-append-waypoint", deps.on_field_agent_waypoint_input)

  script.on_event(defines.events.on_unit_group_created, deps.on_unit_group_created)
  script.on_event(defines.events.on_unit_added_to_group, deps.on_unit_added_to_group)
  script.on_event(defines.events.on_unit_group_finished_gathering, deps.on_unit_group_finished_gathering)
  if deps.on_entity_spawned then
    script.on_event(defines.events.on_entity_spawned, deps.on_entity_spawned)
  end
  script.on_event(defines.events.on_entity_died, deps.on_entity_died, deps.on_entity_died_filters)
  script.on_event(defines.events.on_script_trigger_effect, deps.on_script_trigger_effect)
  script.on_event(defines.events.on_ai_command_completed, deps.on_ai_command_completed)
  script.on_event(defines.events.on_script_path_request_finished, deps.on_script_path_request_finished)
  script.on_event(defines.events.on_string_translated, deps.on_string_translated)
  script.on_event(defines.events.on_tick, deps.on_trajectory_compliance_tick)

  script.on_event(defines.events.on_train_changed_state, deps.on_train_changed_state)
  script.on_event(defines.events.on_rocket_launched, deps.on_rocket_launched)
  script.on_event(defines.events.on_gui_click, deps.on_gui_click)
  script.on_event(defines.events.on_research_finished, deps.on_research_finished)

  -- Each system declares the cadence its own behaviour needs. Sharing an
  -- interval with another system is allowed and has no effect on either.
  register_nth_tick_handlers({
    {15, deps.on_pneumatic_tick},
    {deps.terminus_check_ticks, deps.on_interplanetary_tube_tick},
    {deps.ai_server_check_ticks, deps.on_ai_server_tick},
    {deps.relocation_cannon_check_ticks, deps.on_relocation_cannon_tick},
    {deps.biter_station_check_ticks or 10, deps.on_biter_station_tick},
    {deps.biterport_check_ticks or 30, deps.on_biterport_tick},
    {deps.field_office_update_ticks or 5, deps.on_field_office_tick},
    {20, deps.on_protest_pacing_tick},
    {deps.unit_group_debug_scan_interval, deps.on_unit_group_debug_tick},
    {60, deps.on_main_tick},
  })
end

return M
