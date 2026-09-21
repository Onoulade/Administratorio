-- Compact, per-player overview of service capacity across the force's surfaces.
local zones = require("scripts.zones")
local M = {}

local SHORTCUT = "administratorio-station-overview"
local FRAME = "administratorio-station-overview-frame"
local LIST = "administratorio-station-overview-list"
local CLOSE = "administratorio-station-overview-close"
local ROW = "administratorio-station-overview-row"

local function count_protests(force)
  local count = 0
  for _, info in pairs(storage.waiting_biters or {}) do
    local entity = info.entity
    if (info.state == "protesting" or info.state == "attacking")
      and entity and entity.valid and entity.surface
      and (not info.player_force_index or info.player_force_index == force.index) then
      count = count + 1
    end
  end
  return count
end

local function collect_stations(force)
  local rows = {}
  local occupied, capacity, inbound = 0, 0, 0
  for id, station in pairs(storage.admin_desks or {}) do
    if station and station.valid and station.name == "admin-station" and station.force == force then
      local total = zones.get_zone_capacity(station.unit_number)
      local free = zones.get_available_slots(station.unit_number)
      rows[#rows + 1] = {entity = station, occupied = total - free, capacity = total, free = free}
      occupied = occupied + total - free
      capacity = capacity + total
    elseif not station or not station.valid then
      storage.admin_desks[id] = nil
    end
  end
  for _, info in pairs(storage.waiting_biters or {}) do
    if info.state == "pathfinding" and info.desk_id then
      local desk = storage.admin_desks and storage.admin_desks[info.desk_id]
      if desk and desk.valid and desk.force == force and desk.name == "admin-station" then
        inbound = inbound + 1
      end
    end
  end
  table.sort(rows, function(a, b)
    local ae, be = a.entity, b.entity
    if ae.surface.index ~= be.surface.index then return ae.surface.index < be.surface.index end
    if ae.position.y ~= be.position.y then return ae.position.y < be.position.y end
    if ae.position.x ~= be.position.x then return ae.position.x < be.position.x end
    return ae.unit_number < be.unit_number
  end)
  return rows, occupied, capacity, inbound
end

local function update(player)
  local frame = player.gui.left[FRAME]
  if not frame then return end
  local rows, occupied, capacity, inbound = collect_stations(player.force)
  frame["administratorio-station-overview-summary"].caption = {
    "gui.station-overview-summary", occupied, capacity, capacity - occupied, inbound,
    count_protests(player.force),
  }
  local list = frame[LIST]
  local same_rows = #list.children == math.max(1, #rows)
  if same_rows and #rows > 0 then
    for index, row in ipairs(rows) do
      if list.children[index].name ~= ROW .. row.entity.unit_number then
        same_rows = false
        break
      end
    end
  elseif same_rows then
    same_rows = list.children[1].name == "administratorio-station-overview-empty"
  end
  if not same_rows then list.clear() end
  if #rows == 0 then
    if not same_rows then
      list.add{type = "label", name = "administratorio-station-overview-empty",
        caption = {"gui.station-overview-empty"}}
    end
  else
    for index, row in ipairs(rows) do
      local station = row.entity
      local caption = {"gui.station-overview-row", station.surface.name,
        math.floor(station.position.x), math.floor(station.position.y),
        row.occupied, row.capacity, row.free}
      if same_rows then
        list.children[index].caption = caption
      else
        local button = list.add{
          type = "button",
          name = ROW .. station.unit_number,
          caption = caption,
          tooltip = {"gui.station-overview-jump"},
          tags = {station_id = station.unit_number},
        }
        button.style.horizontally_stretchable = true
        button.style.horizontal_align = "left"
      end
    end
  end
end

local function close(player)
  local frame = player.gui.left[FRAME]
  if frame then frame.destroy() end
  player.set_shortcut_toggled(SHORTCUT, false)
end

function M.toggle(player)
  if player.gui.left[FRAME] then
    close(player)
    return
  end
  local frame = player.gui.left.add{type = "frame", name = FRAME, direction = "vertical"}
  frame.style.minimal_width = 330
  frame.style.maximal_width = 430
  local heading = frame.add{type = "flow", direction = "horizontal"}
  heading.style.horizontally_stretchable = true
  local title = heading.add{type = "label", caption = {"gui.station-overview-title"}, style = "frame_title"}
  title.style.horizontally_stretchable = true
  heading.add{type = "sprite-button", name = CLOSE, sprite = "utility/close",
    style = "frame_action_button", tooltip = {"gui.debug-close"}}
  frame.add{type = "label", name = "administratorio-station-overview-summary", caption = ""}
  local list = frame.add{type = "scroll-pane", name = LIST, direction = "vertical"}
  list.style.maximal_height = 350
  list.style.horizontally_stretchable = true
  player.set_shortcut_toggled(SHORTCUT, true)
  update(player)
end

function M.on_shortcut(event)
  if event.prototype_name ~= SHORTCUT then return end
  local player = game.get_player(event.player_index)
  if player then M.toggle(player) end
end

function M.on_click(player, element)
  if element.name == CLOSE then
    close(player)
    return true
  end
  if element.name:sub(1, #ROW) ~= ROW then return false end
  local id = element.tags and element.tags.station_id
  local station = id and storage.admin_desks and storage.admin_desks[id]
  if station and station.valid and station.force == player.force then
    player.set_controller{type = defines.controllers.remote,
      position = station.position, surface = station.surface}
    player.zoom = 1.5
  else
    update(player)
  end
  return true
end

function M.refresh_open()
  for _, player in pairs(game.connected_players) do
    if player.gui.left[FRAME] then update(player) end
  end
end

function M.sync_player(player)
  player.set_shortcut_toggled(SHORTCUT, player.gui.left[FRAME] ~= nil)
  update(player)
end

return M
