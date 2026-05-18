-- Layered icons: vanilla circuit signal + complaint ticket strip.

local item_icons = "__administratorio__/graphics/icons/"
local signal_yellow = "__base__/graphics/icons/signal/signal_yellow.png"
local signal_green = "__base__/graphics/icons/signal/signal_green.png"

local M = {}

local function ticket_overlay(ticket_icon)
  return { icon = ticket_icon, icon_size = 64 }
end

function M.complaint_signal_icons(ticket_icon)
  return {
    { icon = signal_yellow, icon_size = 64 },
    ticket_overlay(ticket_icon),
  }
end

function M.resolved_complaint_icons(ticket_icon)
  return {
    { icon = signal_green, icon_size = 64 },
    ticket_overlay(ticket_icon),
  }
end

function M.ticket_icon(ticket_name)
  return item_icons .. ticket_name .. ".png"
end

return M
