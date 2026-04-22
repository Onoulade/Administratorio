local C = require("scripts.constants")
local biterport = require("scripts.biterport")

local M = {}

local LOGISTICS_COLOR = {r = 0.95, g = 0.72, b = 0.28, a = 0.75}
local CONSTRUCTION_COLOR = {r = 0.45, g = 1.0, b = 0.55, a = 0.55}
local LINK_COLOR = {r = 0.55, g = 1.0, b = 0.45, a = 0.5}
local TEXT_COLOR = {r = 0.55, g = 1.0, b = 0.45}

local function radius_box(pos, radius)
  return {
    left_top = {x = pos.x - radius, y = pos.y - radius},
    right_bottom = {x = pos.x + radius, y = pos.y + radius},
  }
end

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
  local logistics = radius_box(port.position, C.BITERPORT_LOGISTICS_RADIUS)
  local construction = radius_box(port.position, C.BITERPORT_CONSTRUCTION_RADIUS)

  add_render(player.index, rendering.draw_rectangle{
    color = CONSTRUCTION_COLOR,
    width = 2,
    left_top = construction.left_top,
    right_bottom = construction.right_bottom,
    surface = surface,
    players = {player},
    draw_on_ground = true,
  })

  add_render(player.index, rendering.draw_rectangle{
    color = LOGISTICS_COLOR,
    width = 3,
    left_top = logistics.left_top,
    right_bottom = logistics.right_bottom,
    surface = surface,
    players = {player},
    draw_on_ground = true,
  })

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
        local box = radius_box(member.position, C.BITERPORT_LOGISTICS_RADIUS)
        add_render(player.index, rendering.draw_rectangle{
          color = LINK_COLOR,
          width = 1,
          left_top = box.left_top,
          right_bottom = box.right_bottom,
          surface = surface,
          players = {player},
          draw_on_ground = true,
        })
      end
    end
  end

  local ports = summary and summary.ports or 1
  local workers = summary and summary.workers or 0
  add_render(player.index, rendering.draw_text{
    text = {"gui.biterport-network", ports, workers},
    surface = surface,
    target = {entity = port, offset = {0, -2.5}},
    color = TEXT_COLOR,
    alignment = "center",
    vertical_alignment = "middle",
    scale = 1.1,
    scale_with_zoom = true,
    players = {player},
  })
end

return M
