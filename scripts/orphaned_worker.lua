local C = require("scripts.constants")

local M = {}

local RETRY_TICKS = C.ORPHANED_WORKER_RETRY_TICKS or (10 * 60)

local ALERT_ICONS = {
  station = {type = "item", name = "worker-biter"},
  logistics = {type = "item", name = "biter-logistics-formation"},
}

local function current_tick(tick)
  if tick ~= nil then return tick end
  return game and game.tick or 0
end

local function players_for_force(force)
  if force and force.players then return force.players end
  return game and game.connected_players or {}
end

local function alert_players(state, entity, kind, force)
  if not entity or not entity.valid then return end
  local icon = ALERT_ICONS[kind] or ALERT_ICONS.station
  local surface_name = entity.surface and entity.surface.name or ""
  local gps = "[gps=" .. math.floor(entity.position.x) .. "," .. math.floor(entity.position.y)
    .. "," .. surface_name .. "]"

  state.orphan_alerted_players = state.orphan_alerted_players or {}
  for _, player in pairs(players_for_force(force)) do
    if player and player.valid then
      local player_key = player.index or player
      local has_method, method = pcall(function() return player.add_custom_alert end)
      if has_method and method and not state.orphan_alerted_players[player_key] then
        player.add_custom_alert(
          entity,
          icon,
          {"message.orphaned-worker-alert", {"message.orphaned-worker-kind-" .. kind}, gps},
          true
        )
        state.orphan_alerted_players[player_key] = true
      end
    end
  end
  state.orphan_alert_active = true
end

function M.begin(state, entity, kind, tick, force)
  if not state or not entity or not entity.valid then return end
  local now = current_tick(tick)
  state.orphan_worker_kind = state.orphan_worker_kind or kind or "station"
  state.orphan_frustration = state.orphan_frustration or 0
  state.orphan_frust_accum = state.orphan_frust_accum or 0
  state.orphan_last_frustration_tick = state.orphan_last_frustration_tick or now
  state.orphan_next_retry_tick = state.orphan_next_retry_tick or (now + RETRY_TICKS)
  alert_players(state, entity, state.orphan_worker_kind, force)
end

function M.update(state, entity, kind, tick, force)
  if not state or not entity or not entity.valid then return false end
  local now = current_tick(tick)
  M.begin(state, entity, kind, now, force)

  local last_tick = state.orphan_last_frustration_tick or now
  local elapsed_ticks = math.max(0, now - last_tick)
  state.orphan_last_frustration_tick = now
  if elapsed_ticks > 0 then
    local tier = C.get_individual_frust_tier({frustration = state.orphan_frustration or 0})
    local growth = C.FRUST_GROWTH_RATES[tier] or 0
    state.orphan_frust_accum = (state.orphan_frust_accum or 0) + growth * (elapsed_ticks / 60)
    local whole = math.floor(state.orphan_frust_accum)
    if whole > 0 then
      state.orphan_frustration = (state.orphan_frustration or 0) + whole
      state.orphan_frust_accum = state.orphan_frust_accum - whole
    end
  end

  return (state.orphan_frustration or 0) >= C.PROTEST_THRESHOLD
end

function M.should_retry(state, tick)
  if not state then return false end
  local now = current_tick(tick)
  if now < (state.orphan_next_retry_tick or 0) then return false end
  state.orphan_next_retry_tick = now + RETRY_TICKS
  return true
end

function M.clear(state, entity, force)
  if not state then return end
  if state.orphan_alert_active and entity and entity.valid then
    for _, player in pairs(players_for_force(force)) do
      if player and player.valid then
        local has_method, method = pcall(function() return player.remove_alert end)
        if has_method and method then
          player.remove_alert{
            entity = entity,
            type = defines.alert_type.custom,
          }
        end
      end
    end
  end
  state.orphan_alert_active = nil
  state.orphan_alerted_players = nil
  state.orphan_worker_kind = nil
  state.orphan_frustration = nil
  state.orphan_frust_accum = nil
  state.orphan_last_frustration_tick = nil
  state.orphan_next_retry_tick = nil
end

return M
