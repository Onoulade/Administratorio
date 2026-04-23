local C = require("scripts.constants")
local working_hours = require("scripts.working_hours")

local M = {}

local ZONE_COLOR      = {r = 0.9, g = 0.7, b = 0.2, a = 0.7}
local BUILDING_BORDER = {r = 0.9, g = 0.7, b = 0.2, a = 0.55}
local TEXT_COLOR      = {r = 0.9, g = 0.7, b = 0.2}
local COFFEE_INPUT_COLOR = {r = 0.75, g = 0.42, b = 0.18, a = 0.9}

local function zone_box(pos)
  local r = C.BITER_STATION_RANGE
  return {
    left_top     = {x = pos.x - r, y = pos.y - r},
    right_bottom = {x = pos.x + r, y = pos.y + r},
  }
end

local function add_render(player_index, obj)
  if not obj then return end
  local t = storage.biter_station_hover_renders[player_index] or {}
  t[#t + 1] = obj.id
  storage.biter_station_hover_renders[player_index] = t
end

local function rear_input_position(entity)
  local direction = entity and entity.direction or defines.direction.north
  local position = entity and entity.position or {x = 0, y = 0}
  if direction == defines.direction.east then
    return {x = position.x + 2.5, y = position.y}
  elseif direction == defines.direction.south then
    return {x = position.x + 0.5, y = position.y + 2}
  elseif direction == defines.direction.west then
    return {x = position.x - 1.5, y = position.y}
  end
  return {x = position.x + 0.5, y = position.y - 2}
end

local function draw_coffee_input_marker(player, station)
  if not working_hours.is_enabled() or not station or not station.valid then return end
  local surface = station.surface
  local input_position = rear_input_position(station)

  add_render(player.index, rendering.draw_line{
    color = COFFEE_INPUT_COLOR,
    width = 3,
    from = station.position,
    to = input_position,
    surface = surface,
    players = {player},
    draw_on_ground = true,
  })

  add_render(player.index, rendering.draw_circle{
    color = COFFEE_INPUT_COLOR,
    radius = 0.45,
    width = 4,
    target = input_position,
    surface = surface,
    players = {player},
    draw_on_ground = true,
  })

  add_render(player.index, rendering.draw_sprite{
    sprite = "fluid/liquid-coffee",
    target = input_position,
    surface = surface,
    x_scale = 0.45,
    y_scale = 0.45,
    players = {player},
  })
end

local function clear_renders(player_index)
  local ids = storage.biter_station_hover_renders[player_index]
  if ids then
    for _, id in ipairs(ids) do
      local obj = rendering.get_object_by_id(id)
      if obj then obj.destroy() end
    end
  end
  storage.biter_station_hover_renders[player_index] = nil
end

function M.ensure_storage()
  storage.biter_station_hover_renders = storage.biter_station_hover_renders or {}
end

function M.clear(player_index)
  clear_renders(player_index)
end

function M.show_station_zone(player, station)
  clear_renders(player.index)
  local surface = station.surface
  local box = zone_box(station.position)

  add_render(player.index, rendering.draw_rectangle{
    color        = ZONE_COLOR,
    width        = 2,
    left_top     = box.left_top,
    right_bottom = box.right_bottom,
    surface      = surface,
    players      = {player},
    draw_on_ground = true,
  })

  local nearby = surface.find_entities_filtered{
    name   = C.BITER_STATION_MANAGED_BUILDINGS,
    area   = box,
    force  = station.force,
  }

  for _, building in ipairs(nearby) do
    if building.valid then
      local bb = building.bounding_box
      add_render(player.index, rendering.draw_rectangle{
        color        = BUILDING_BORDER,
        width        = 2,
        left_top     = bb.left_top,
        right_bottom = bb.right_bottom,
        surface      = surface,
        players      = {player},
      })
    end
  end

  add_render(player.index, rendering.draw_text{
    text                 = {"gui.biter-station-hover-zone-count", #nearby},
    surface              = surface,
    target               = {entity = station, offset = {0, -2.2}},
    color                = TEXT_COLOR,
    alignment            = "center",
    vertical_alignment   = "middle",
    scale                = 1.1,
    scale_with_zoom      = true,
    players              = {player},
  })

  draw_coffee_input_marker(player, station)
end

function M.show_building_hover(player, building)
  clear_renders(player.index)
  local surface = building.surface
  local box = zone_box(building.position)

  local stations = surface.find_entities_filtered{
    name  = "biter-station",
    area  = box,
    force = building.force,
  }

  for _, station in ipairs(stations) do
    if station.valid then
      local sbox = zone_box(station.position)
      add_render(player.index, rendering.draw_rectangle{
        color        = ZONE_COLOR,
        width        = 2,
        left_top     = sbox.left_top,
        right_bottom = sbox.right_bottom,
        surface      = surface,
        players      = {player},
        draw_on_ground = true,
      })
      local sb = station.selection_box
      add_render(player.index, rendering.draw_rectangle{
        color        = ZONE_COLOR,
        width        = 3,
        left_top     = sb.left_top,
        right_bottom = sb.right_bottom,
        surface      = surface,
        players      = {player},
      })
    end
  end

  local count = #stations
  local text_key
  if count == 0 then
    text_key = "gui.biter-station-hover-managed-none"
  elseif count == 1 then
    text_key = "gui.biter-station-hover-managed-single"
  else
    text_key = "gui.biter-station-hover-managed-multi"
  end

  add_render(player.index, rendering.draw_text{
    text                 = {text_key, count},
    surface              = surface,
    target               = {entity = building, offset = {0, -2.2}},
    color                = TEXT_COLOR,
    alignment            = "center",
    vertical_alignment   = "middle",
    scale                = 1.1,
    scale_with_zoom      = true,
    players              = {player},
  })
end

return M
