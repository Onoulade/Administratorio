local M = {}

function M.register(deps)
  script.on_init(deps.on_init)
  script.on_configuration_changed(deps.on_configuration_changed)
  script.on_load(deps.on_load)

  script.on_event(defines.events.on_player_created, deps.on_player_created)
  script.on_event(defines.events.on_player_respawned, deps.on_player_respawned)
  script.on_event(defines.events.on_player_joined_game, deps.on_player_joined_game)
  script.on_event(defines.events.on_selected_entity_changed, deps.on_selected_entity_changed)

  script.on_event(defines.events.on_built_entity, deps.on_entity_built)
  script.on_event(defines.events.on_robot_built_entity, deps.on_entity_built)
  script.on_event(defines.events.script_raised_built, deps.on_entity_built)
  script.on_event(defines.events.script_raised_revive, deps.on_entity_built)
  script.on_event(defines.events.on_player_mined_entity, deps.on_entity_removed)
  script.on_event(defines.events.on_robot_mined_entity, deps.on_entity_removed)
  script.on_event(defines.events.script_raised_destroy, deps.on_entity_removed)
  script.on_event(defines.events.on_player_rotated_entity, deps.on_player_rotated_entity)

  script.on_event("administratorio-toggle-runtime-debug", deps.on_toggle_runtime_debug)

  script.on_event(defines.events.on_unit_group_created, deps.on_unit_group_created)
  script.on_event(defines.events.on_unit_added_to_group, deps.on_unit_added_to_group)
  script.on_event(defines.events.on_unit_removed_from_group, deps.on_unit_removed_from_group)
  script.on_event(defines.events.on_unit_group_finished_gathering, deps.on_unit_group_finished_gathering)
  script.on_event(defines.events.on_entity_died, deps.on_entity_died, deps.on_entity_died_filters)
  script.on_event(defines.events.on_script_trigger_effect, deps.on_script_trigger_effect)
  script.on_event(defines.events.on_ai_command_completed, deps.on_ai_command_completed)
  script.on_event(defines.events.on_script_path_request_finished, deps.on_script_path_request_finished)
  script.on_event(defines.events.on_string_translated, deps.on_string_translated)

  script.on_event(defines.events.on_train_changed_state, deps.on_train_changed_state)
  script.on_event(defines.events.on_rocket_launched, deps.on_rocket_launched)
  script.on_event(defines.events.on_gui_click, deps.on_gui_click)
  script.on_event(defines.events.on_research_finished, deps.on_research_finished)

  script.on_nth_tick(15, deps.on_pneumatic_tick)
  if deps.on_biter_station_tick then
    script.on_nth_tick(deps.biter_station_check_ticks or 10, deps.on_biter_station_tick)
  end
  script.on_nth_tick(20, deps.on_protest_pacing_tick)
  script.on_nth_tick(deps.unit_group_debug_scan_interval, deps.on_unit_group_debug_tick)
  script.on_nth_tick(60, deps.on_main_tick)
end

return M
