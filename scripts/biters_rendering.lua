local M = {}

function M.new(deps)
  local controller = {}

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
    local render_object = get_render_object(render_ref)
    if render_object then
      render_object.destroy()
    end
  end

  local function pick_primary_complaint(info)
    local counts = {}
    local best_ticket = nil
    local best_count = -1

    for _, ticket in ipairs(info.complaints or {}) do
      counts[ticket] = (counts[ticket] or 0) + 1
    end

    for ticket, count in pairs(counts) do
      if count > best_count then
        best_ticket = ticket
        best_count = count
      end
    end

    return best_ticket or "ticket-landscape"
  end

  local function ensure_protest_theme(info)
    if not info then
      return "ticket-landscape", "Public outrage!", deps.protest_tints["ticket-landscape"]
    end

    local ticket = info.protest_primary_ticket or pick_primary_complaint(info)
    info.protest_primary_ticket = ticket

    if not info.protest_message then
      local slogans = deps.protest_slogans[ticket] or {"Public outrage!"}
      info.protest_message = slogans[math.random(1, #slogans)]
    end

    return ticket, info.protest_message, deps.protest_tints[ticket] or {r = 1, g = 0.4, b = 0.3}
  end

  local function get_protest_alert_icon(info)
    return {type = "virtual", name = "signal-protest-alert"}
  end

  local function get_protest_alert_caption(info)
    local ticket, message = ensure_protest_theme(info)
    return {"", {"item-name." .. ticket}, ": \"", message, "\""}
  end

  function controller.destroy_protest_chart_tag(info)
    if not info then return end

    if info.protest_chart_tags_by_force then
      for force_name, chart_tag in pairs(info.protest_chart_tags_by_force) do
        if chart_tag and chart_tag.valid then
          chart_tag.destroy()
        end
        info.protest_chart_tags_by_force[force_name] = nil
      end
    end

    if info.protest_chart_tag and info.protest_chart_tag.valid then
      info.protest_chart_tag.destroy()
    end
    info.protest_chart_tag = nil
    info.protest_chart_tags_by_force = nil
  end

  function controller.ensure_protest_chart_tag(info, player_override)
    if not info or info.state ~= "protesting" then return end

    local target = info.target_building
    local entity = info.entity
    local anchor = (target and target.valid and target) or (entity and entity.valid and entity) or nil
    if not anchor then
      -- log(deps.log_prefix .. "Protest DEBUG UI: chart tag skipped, no valid anchor entity or target")
      controller.destroy_protest_chart_tag(info)
      return
    end

    local icon = get_protest_alert_icon(info)
    info.protest_chart_tags_by_force = info.protest_chart_tags_by_force or {}
    local players = player_override and {player_override} or game.connected_players
    local applied_forces = {}

    for _, player in pairs(players) do
      if player and player.valid and player.force then
        local force = player.force
        if not applied_forces[force.name] then
          local chart_tag = info.protest_chart_tags_by_force[force.name]
          if chart_tag and chart_tag.valid then
            chart_tag.icon = icon
            chart_tag.position = anchor.position
            chart_tag.text = deps.protest_map_tag_text
            -- log(deps.log_prefix .. "Protest DEBUG UI: chart tag updated at " .. deps.format_position(anchor.position)
            --   .. " anchor=" .. anchor.name .. " force=" .. force.name
            --   .. " state=" .. tostring(info.state)
            --   .. " arrived=" .. tostring(info.arrived_at_building))
          else
            info.protest_chart_tags_by_force[force.name] = force.add_chart_tag(anchor.surface, {
              position = anchor.position,
              icon = icon,
              text = deps.protest_map_tag_text,
            })
            -- log(deps.log_prefix .. "Protest DEBUG UI: chart tag created at " .. deps.format_position(anchor.position)
            --   .. " anchor=" .. anchor.name .. " force=" .. force.name
            --   .. " arrived=" .. tostring(info.arrived_at_building))
          end
          applied_forces[force.name] = true
        end
      end
    end

    if not next(applied_forces) then
      local force = (target and target.valid and target.force) or game.forces.player
      if not force then
        -- log(deps.log_prefix .. "Protest DEBUG UI: chart tag skipped, no force for anchor " .. anchor.name)
        return
      end

      local chart_tag = info.protest_chart_tag
      if chart_tag and chart_tag.valid then
        chart_tag.icon = icon
        chart_tag.position = anchor.position
        chart_tag.text = deps.protest_map_tag_text
        -- log(deps.log_prefix .. "Protest DEBUG UI: legacy chart tag updated at " .. deps.format_position(anchor.position)
        --   .. " anchor=" .. anchor.name .. " force=" .. force.name)
      else
        info.protest_chart_tag = force.add_chart_tag(anchor.surface, {
          position = anchor.position,
          icon = icon,
          text = deps.protest_map_tag_text,
        })
        -- log(deps.log_prefix .. "Protest DEBUG UI: legacy chart tag created at " .. deps.format_position(anchor.position)
        --   .. " anchor=" .. anchor.name .. " force=" .. force.name)
      end
    end
  end

  function controller.destroy_protest_rendering(info)
    if not info then return end
    destroy_render_object(info.protest_text_render_id)
    destroy_render_object(info.protest_stop_text_render_id)
    destroy_render_object(info.protest_icon_render_id)
    destroy_render_object(info.protest_light_render_id)
    destroy_render_object(info.protest_circle_render_id)
    info.protest_text_render_id = nil
    info.protest_text_target_unit_number = nil
    info.protest_stop_text_render_id = nil
    info.protest_icon_render_id = nil
    info.protest_light_render_id = nil
    info.protest_circle_render_id = nil
  end

  function controller.ensure_protest_rendering(info)
    if not info or info.state ~= "protesting" then return end
    local entity = info.entity
    local target = info.target_building
    if not entity or not entity.valid or not target or not target.valid or not info.arrived_at_building then
      controller.destroy_protest_rendering(info)
      return
    end

    local ticket, message, complaint_tint = ensure_protest_theme(info)

    if not get_render_object(info.protest_circle_render_id) then
      info.protest_circle_render_id = rendering.draw_circle{
        color = deps.protest_stop_tint,
        radius = 1.8,
        width = 5,
        target = target,
        surface = target.surface,
        blink_interval = 30,
        draw_on_ground = true,
      }.id
    end

    if not get_render_object(info.protest_light_render_id) then
      info.protest_light_render_id = rendering.draw_light{
        sprite = "utility/light_medium",
        color = deps.protest_stop_tint,
        intensity = 0.9,
        minimum_darkness = 0,
        scale = 2.1,
        target = {entity = target, offset = {0, -0.2}},
        surface = target.surface,
        blink_interval = 30,
      }.id
    end

    if not get_render_object(info.protest_icon_render_id) then
      info.protest_icon_render_id = rendering.draw_text{
        text = "X",
        target = {entity = target, offset = {0, -1.2}},
        surface = target.surface,
        color = deps.protest_stop_tint,
        alignment = "center",
        vertical_alignment = "middle",
        scale = 3.1,
        scale_with_zoom = true,
      }.id
    end

    if not get_render_object(info.protest_stop_text_render_id) then
      info.protest_stop_text_render_id = rendering.draw_text{
        text = "STOP",
        target = {entity = target, offset = {0, 0.35}},
        surface = target.surface,
        color = deps.protest_stop_text_tint,
        alignment = "center",
        vertical_alignment = "middle",
        scale = 1.35,
        scale_with_zoom = true,
      }.id
    end

    if info.protest_text_target_unit_number ~= entity.unit_number then
      destroy_render_object(info.protest_text_render_id)
      info.protest_text_render_id = nil
    end

    if not get_render_object(info.protest_text_render_id) then
      info.protest_text_render_id = rendering.draw_text{
        text = "[item=" .. ticket .. "] " .. message,
        surface = entity.surface,
        target = {entity = entity, offset = {0, -2.6}},
        color = complaint_tint,
        alignment = "center",
        vertical_alignment = "middle",
        scale = 1.35,
        scale_with_zoom = true,
        use_rich_text = true,
      }.id
      info.protest_text_target_unit_number = entity.unit_number
    end
  end

  function controller.notify_players_of_protest(info, player_override)
    if not info or info.state ~= "protesting" then return end

    local target = info.target_building
    local entity = info.entity
    local alert_entity = (target and target.valid and target) or (entity and entity.valid and entity) or nil
    if not alert_entity then
      -- log(deps.log_prefix .. "Protest DEBUG UI: alert skipped, no valid alert entity")
      controller.destroy_protest_chart_tag(info)
      return
    end

    controller.ensure_protest_chart_tag(info, player_override)

    info.protest_alerted_players = info.protest_alerted_players or {}
    storage.protest_alert_sound_tick_by_player = storage.protest_alert_sound_tick_by_player or {}

    local icon = get_protest_alert_icon(info)
    local caption = get_protest_alert_caption(info)
    local gps = "[gps=" .. math.floor(alert_entity.position.x) .. "," .. math.floor(alert_entity.position.y) .. "]"
    local players = player_override and {player_override} or game.connected_players
    local alerted_count = 0

    for _, player in pairs(players) do
      if player.valid then
        player.remove_alert{
          entity = alert_entity,
          type = defines.alert_type.custom,
        }
        player.add_custom_alert(alert_entity, icon, {"message.protest-alert", caption, gps}, true)

        local last_sound_tick = storage.protest_alert_sound_tick_by_player[player.index] or -math.huge
        if game.tick - last_sound_tick >= deps.protest_alert_sound_cooldown_ticks then
          player.play_sound{
            path = deps.protest_alert_sound_path,
            volume_modifier = 0.9,
          }
          storage.protest_alert_sound_tick_by_player[player.index] = game.tick
        end

        info.protest_alerted_players[player.index] = true
        alerted_count = alerted_count + 1
      end
    end

    -- log(deps.log_prefix .. "Protest DEBUG UI: notify attempt anchor=" .. alert_entity.name
    --   .. " pos=" .. deps.format_position(alert_entity.position)
    --   .. " target=" .. tostring(target and target.valid and target.name or nil)
    --   .. " arrived=" .. tostring(info.arrived_at_building)
    --   .. " alerted_players=" .. tostring(alerted_count)
    --   .. " connected_players=" .. tostring(#players))
  end

  return controller
end

return M
