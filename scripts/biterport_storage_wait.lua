local biter_emotes = require("scripts.biter_emotes")

local M = {}
local RETRY_TICKS = 5 * 60

local function players_for_force(force)
  return force and force.players or game and game.connected_players or {}
end

-- A missing storage destination needs one visible carrier per network, not
-- every worker in the network. This also recognizes workers saved before the
-- dispatch guard existed.
function M.has_pending_loose_pickup(network)
  for _, active in pairs(storage.biterport_workers or {}) do
    local job = active.job
    if job and job.kind == "deconstruction" and job.deconstruction_type == "loose_item"
       and active.phase ~= "returning" and active.phase ~= "orphaned_returning"
       and network.port_set[active.home_port_id] then
      return true
    end
  end
  return false
end

function M.is_surplus_waiter(active, network)
  if not network or not network.port_set[active.home_port_id] then return false end
  for unit_number, other in pairs(storage.biterport_workers or {}) do
    if other ~= active and other.phase == "waiting_for_storage"
       and network.port_set[other.home_port_id]
       and unit_number < active.biter_unit_number then
      return true
    end
  end
  return false
end

function M.clear(active)
  if not active then return end
  local biter = active.biter
  if active.storage_wait_alerted_players and biter and biter.valid then
    for _, player in pairs(players_for_force(active.force)) do
      local ok, method = pcall(function() return player and player.remove_alert end)
      if ok and player.valid and method then
        player.remove_alert{entity = biter, type = defines.alert_type.custom}
      end
    end
  end
  active.storage_wait_alerted_players = nil
  active.storage_next_retry_tick = nil
  biter_emotes.clear(active)
end

function M.alert(active, worker_item_name)
  local biter = active and active.biter
  local stack = active and active.carried_stack
  if not biter or not biter.valid or not stack or not stack.name then return end
  active.storage_wait_alerted_players = active.storage_wait_alerted_players or {}
  local gps = "[gps=" .. math.floor(biter.position.x) .. "," .. math.floor(biter.position.y)
    .. "," .. (biter.surface and biter.surface.name or "") .. "]"
  for _, player in pairs(players_for_force(active.force)) do
    local ok, method = pcall(function() return player and player.add_custom_alert end)
    if ok and player.valid and method then
      local key = player.index or player
      if not active.storage_wait_alerted_players[key] then
        player.add_custom_alert(biter, {type = "item", name = worker_item_name},
          {"message.biterport-no-storage-alert", "[item=" .. stack.name .. "]", gps}, true)
        active.storage_wait_alerted_players[key] = true
      end
    end
  end
end

function M.enter(active, tick, worker_item_name)
  active.phase = "waiting_for_storage"
  active.phase_destination = nil
  active.storage_next_retry_tick = tick + RETRY_TICKS
  if active.biter and active.biter.valid then
    if active.biter.commandable and defines.command.stop then
      active.biter.commandable.set_command{type = defines.command.stop, distraction = defines.distraction.none}
    end
    biter_emotes.set(active, active.biter, "waiting-slot")
  end
  M.alert(active, worker_item_name)
end

return M
