local biterport = require("scripts.biterport")

local M = {}

local LINK_COLOR = {r = 0.55, g = 1.0, b = 0.45, a = 0.5}

local function add_render(player_index, obj)
  if not obj then return end
  local renders = storage.biterport_hover_renders[player_index] or {}
  renders[#renders + 1] = obj.id
  storage.biterport_hover_renders[player_index] = renders
end

local function clear_renders(player_index)
  local ids = storage.biterport_hover_renders[player_index]
  if ids then
    for _, id in ipairs(ids) do
      local obj = rendering.get_object_by_id(id)
      if obj then obj.destroy() end
    end
  end
  storage.biterport_hover_renders[player_index] = nil
end

function M.ensure_storage()
  storage.biterport_hover_renders = storage.biterport_hover_renders or {}
end

function M.clear(player_index)
  clear_renders(player_index)
end

function M.show_port(player, port)
  M.ensure_storage()
  clear_renders(player.index)
  if not port or not port.valid then return end

  local surface = port.surface

  local summary = biterport.get_network_summary(port)
  if summary and summary.network then
    for _, member in ipairs(summary.network.ports) do
      if member.valid and member ~= port then
        add_render(player.index, rendering.draw_line{
          color = LINK_COLOR,
          width = 2,
          from = port.position,
          to = member.position,
          surface = surface,
          players = {player},
          draw_on_ground = true,
        })
      end
    end
  end
end

return M
