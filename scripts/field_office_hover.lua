local field_office = require("scripts.field_office")
local spawner_population = require("scripts.spawner_population")

local M = {}

local GUI_NAME = "administratorio-field-office-workforce-info"

local function destroy_gui(player)
  local frame = player and player.gui and player.gui.left and player.gui.left[GUI_NAME]
  if frame then frame.destroy() end
end

local function add_title(frame, caption)
  local title = frame.add{type = "label", caption = caption}
  title.style.font = "default-bold"
  title.style.bottom_margin = 4
end

local function add_summary(frame, available, used, total)
  local label = frame.add{
    type = "label",
    caption = {"gui.field-office-hover-capacity", available, used, total},
  }
  label.style.font_color = available > 0
    and {r = 0.35, g = 1.0, b = 0.35}
    or {r = 1.0, g = 0.35, b = 0.25}
end

function M.clear(player_or_index)
  local player = type(player_or_index) == "number" and game.get_player(player_or_index) or player_or_index
  destroy_gui(player)
end

function M.show_field_office(player, office)
  destroy_gui(player)
  if not office or not office.valid then return end

  local summary = field_office.get_nearby_population_summary(office)
  local frame = player.gui.left.add{
    type = "frame",
    name = GUI_NAME,
    direction = "vertical",
  }
  frame.style.minimal_width = 280
  add_title(frame, {"gui.field-office-hover-title"})
  add_summary(frame, summary.available, summary.used, summary.total)

  local count = #summary.nests
  local count_label = frame.add{type = "label", caption = {"gui.field-office-hover-nests", count}}
  count_label.style.top_margin = 4

  local rows = frame.add{type = "scroll-pane", direction = "vertical"}
  rows.style.maximal_height = 360
  rows.style.minimal_width = 260

  for index, nest in ipairs(summary.nests) do
    local entity = nest.entity
    local row = rows.add{
      type = "label",
      caption = {
        "gui.field-office-hover-nest-row",
        index,
        nest.available,
        nest.used,
        nest.total,
        math.floor(nest.distance_squared ^ 0.5 + 0.5),
      },
    }
    row.style.font_color = nest.available > 0
      and {r = 0.8, g = 0.9, b = 0.8}
      or {r = 1.0, g = 0.55, b = 0.4}
    row.tooltip = {
      "gui.field-office-hover-nest-tooltip",
      entity.localised_name,
      entity.position.x,
      entity.position.y,
      entity.surface.name,
    }
  end
end

function M.show_nest(player, spawner)
  destroy_gui(player)
  if not spawner or not spawner.valid then return end

  local available, used, total = spawner_population.get_capacity(spawner)
  available = available or 0
  total = total or used
  local frame = player.gui.left.add{
    type = "frame",
    name = GUI_NAME,
    direction = "vertical",
  }
  frame.style.minimal_width = 260
  add_title(frame, {"gui.field-office-hover-nest-title"})
  add_summary(frame, available, used, total)
  frame.add{
    type = "label",
    caption = {"gui.field-office-hover-nearby-offices", field_office.get_nearby_office_count(spawner)},
  }
end

function M.refresh(player)
  local entity = player and player.selected
  if not entity or not entity.valid then
    destroy_gui(player)
  elseif field_office.is_field_office(entity.name) then
    M.show_field_office(player, entity)
  elseif entity.type == "unit-spawner" and entity.force and entity.force.name == "enemy" then
    M.show_nest(player, entity)
  else
    destroy_gui(player)
  end
end

function M.is_open(player)
  return player and player.gui and player.gui.left and player.gui.left[GUI_NAME] ~= nil
end

return M
