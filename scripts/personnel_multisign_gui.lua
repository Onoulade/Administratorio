local R = require("prototypes.shared.personnel_routing")
local signals = require("scripts.personnel_signals")
local M = {}
local NAME = "administratorio-personnel-multisign"
local arrows = {left="←",straight="↑",right="→"}

local function frame(player) return player.gui.screen[NAME] end
function M.close(player)
  local root = frame(player)
  if root then
    if player.opened == root then player.opened = nil end
    if root.valid then root.destroy() end
  end
end
local function editable(player, record)
  return record and record.entity.valid and record.entity.force == player.force
end
function M.refresh(player, record)
  local root = frame(player)
  if not root then return end
  if not editable(player, record) or root.tags.unit_number ~= record.entity.unit_number then
    M.close(player); return
  end
  for _,exit in ipairs(R.exits) do
    local row = root.body[exit]
    local manual = signals.mode(record, exit) == "manual"
    row.heading.mode.switch_state = manual and "left" or "right"
    local slots = (record.manual_filters or {})[exit] or {}
    for slot=1,5 do
      local button = row.slots["slot" .. slot]
      button.elem_value = slots[slot]
      button.enabled = manual
    end
    row.help.caption = {"personnel-routing." .. (manual and "manual-help" or "circuit-help")}
  end
end
function M.open(player, record)
  if not editable(player, record) then return end
  local existing = frame(player)
  if existing and existing.tags.unit_number == record.entity.unit_number then
    player.opened = existing
    M.refresh(player, record)
    return
  end
  M.close(player)
  local root = player.gui.screen.add{type="frame",name=NAME,direction="vertical",
    tags={unit_number=record.entity.unit_number}}
  root.auto_center = true
  local titlebar = root.add{type="flow",direction="horizontal"}
  titlebar.drag_target = root
  titlebar.add{type="label",caption={"entity-name." .. R.MULTISIGN},style="frame_title"}.ignored_by_interaction = true
  local drag = titlebar.add{type="empty-widget",style="draggable_space_header"}
  drag.style.horizontally_stretchable = true
  drag.style.height = 24
  drag.drag_target = root
  titlebar.add{type="sprite-button",name=NAME.."-close",style="frame_action_button",
    sprite="utility/close",hovered_sprite="utility/close_black",clicked_sprite="utility/close_black",
    tooltip={"gui.close-instruction"}}
  local body = root.add{type="frame",name="body",direction="vertical",style="inside_shallow_frame"}
  local intro = body.add{type="label",caption={"personnel-routing.gui-directions"}}
  intro.style.single_line = false
  intro.style.maximal_width = 420
  local names = {}
  for name in pairs(R.cargo) do if prototypes.item[name] then names[#names+1] = name end end
  table.sort(names)
  local filters = {}
  for _,name in ipairs(names) do filters[#filters+1] = {filter="name",name=name,mode="or"} end
  for _,exit in ipairs(R.exits) do
    local row = body.add{type="frame",name=exit,direction="vertical",style="deep_frame_in_shallow_frame"}
    row.style.padding = 12
    local heading = row.add{type="flow",name="heading",direction="horizontal"}
    heading.style.vertical_align = "center"
    local label = heading.add{type="label",caption={"",arrows[exit].."  ",{"personnel-routing."..exit}},style="heading_2_label"}
    label.style.minimal_width = 130
    heading.add{type="switch",name="mode",switch_state="right",allow_none_state=false,
      left_label_caption={"personnel-routing.manual"},right_label_caption={"personnel-routing.circuit"},
      tags={multisign_action="mode",exit=exit}}
    local slots = row.add{type="flow",name="slots",direction="horizontal"}
    slots.style.horizontal_spacing = 0
    for slot=1,5 do
      slots.add{type="choose-elem-button",name="slot"..slot,elem_type="item",elem_filters=filters,style="slot_button",
        tooltip={"personnel-routing.filter-slot",slot},tags={multisign_action="filter",exit=exit,slot=slot}}
    end
    local help = row.add{type="label",name="help"}
    help.style.single_line = false
    help.style.maximal_width = 420
  end
  local footer = body.add{type="label",caption={"personnel-routing.gui-priority"}}
  footer.style.single_line = false
  footer.style.maximal_width = 420
  player.opened = root
  M.refresh(player, record)
end
function M.refresh_all(records)
  for _,player in pairs(game.players) do
    local root = frame(player)
    if root then
      if player.opened ~= root then M.close(player)
      else M.refresh(player, records[root.tags.unit_number]) end
    end
  end
end
function M.on_closed(event)
  local element = event.element
  if element and element.valid and element.name == NAME then
    local player = game.get_player(event.player_index)
    if player then M.close(player) end
  end
end
function M.on_click(event)
  if event.element and event.element.valid and event.element.name == NAME.."-close" then
    local player = game.get_player(event.player_index)
    if player then M.close(player) end
    return true
  end
end
function M.on_changed(event, records, changed)
  local element = event.element
  if not element or not element.valid then return end
  local tags = element.tags
  if not tags.multisign_action then return end
  local player = game.get_player(event.player_index)
  local root = player and frame(player)
  if not root or player.opened ~= root then return end
  -- Only controls within our currently open frame can write this sign.
  local parent = element.parent
  while parent and parent ~= root do parent = parent.parent end
  if not parent then return end
  local record = records[root.tags.unit_number]
  if not editable(player, record) then M.close(player); return end
  local exit = tags.exit
  if exit ~= "left" and exit ~= "straight" and exit ~= "right" then return end
  if tags.multisign_action == "mode" and element.type == "switch" then
    record.filter_modes = record.filter_modes or {}
    record.filter_modes[exit] = element.switch_state == "left" and "manual" or "circuit"
  elseif tags.multisign_action == "filter" and element.type == "choose-elem-button"
    and signals.mode(record, exit) == "manual" and tags.slot >= 1 and tags.slot <= 5 then
    local name = element.elem_value
    record.manual_filters = record.manual_filters or {}
    record.manual_filters[exit] = record.manual_filters[exit] or {}
    record.manual_filters[exit][tags.slot] = name and R.cargo[name] and name or nil
  else return end
  changed(record)
  M.refresh_all(records)
  return true
end
return M
