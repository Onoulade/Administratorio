-- Frustration system: biter inspection GUI (individual frustration only)
local C = require("scripts.constants")
local M = {}

local STATE_EXPLANATIONS = {
  waiting = "Waiting for its complaint case to be resolved; return the matching resolved case to this desk.",
  pathfinding = "Heading to a reserved desk slot to file paperwork; keep the desk reachable and uncrowded.",
  protesting = "Protesting because the queue failed; use a Bureaucratic Promise so it stops and returns to a desk.",
  pacified = "It accepted a Bureaucratic Promise and is waiting for an open desk slot before the promise expires.",
  returning_home = "Its complaint is resolved and it is leaving; no further action is needed.",
}

local function get_state_explanation(info)
  if not info then return nil end
  return STATE_EXPLANATIONS[info.state]
end

-- Biter inspection GUI (shown when hovering over a waiting biter)
function M.destroy_biter_info_gui(player)
  if player.gui.left["administratorio-biter-info"] then
    player.gui.left["administratorio-biter-info"].destroy()
  end
end

function M.update_biter_info_gui(player, entity)
  M.destroy_biter_info_gui(player)
  if not entity or not entity.valid then return end

  local info = storage.waiting_biters[entity.unit_number]
  if not info then return end

  local frame = player.gui.left.add{
    type = "frame",
    name = "administratorio-biter-info",
    direction = "vertical",
  }
  frame.style.minimal_width = 200

  local title = frame.add{type = "label", caption = "Complaint Status"}
  title.style.font = "default-bold"
  title.style.bottom_margin = 4

  local pct = math.floor(info.frustration / C.PROTEST_THRESHOLD * 100)
  local color = pct < 50 and {r=0.3, g=1, b=0.3} or pct < 80 and {r=1, g=1, b=0.3} or {r=1, g=0.2, b=0.2}
  local frust_label = frame.add{type = "label", caption = "Frustration: " .. pct .. "%"}
  frust_label.style.font_color = color

  local bar = frame.add{type = "progressbar", value = math.min(1, pct / 100)}
  bar.style.width = 180
  bar.style.color = color

  local ft = C.get_individual_frust_tier(info)
  local tier_names = {"Calm", "Irritated", "Angry", "Furious"}
  local tier_label = frame.add{type = "label", caption = "Mood: " .. (tier_names[ft] or "?")}
  tier_label.style.font_color = {r=0.7, g=0.7, b=0.7}

  local state_label = frame.add{type = "label", caption = "State: " .. (info.state or "unknown")}
  state_label.style.font_color = info.state == "protesting" and {r=1, g=0.2, b=0.2} or {r=0.8, g=0.8, b=0.8}

  local explanation = get_state_explanation(info)
  if explanation then
    local explanation_label = frame.add{type = "label", caption = explanation}
    explanation_label.style.single_line = false
    explanation_label.style.maximal_width = 260
    explanation_label.style.font_color = {r=0.9, g=0.85, b=0.65}
  end

  if info.complaints and #info.complaints > 0 then
    local complaints_label = frame.add{type = "label", caption = "Pending complaints:"}
    complaints_label.style.top_margin = 4
    for _, ticket in ipairs(info.complaints) do
      local name = ticket:gsub("ticket%-", "")
      frame.add{type = "label", caption = "  - " .. name}
    end
  else
    frame.add{type = "label", caption = "No pending complaints"}
  end
end

return M
