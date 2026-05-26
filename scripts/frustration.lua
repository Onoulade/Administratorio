-- Frustration system: biter inspection GUI (individual frustration only)
local C = require("scripts.constants")
local M = {}

local STATE_EXPLANATION_KEYS = {
  waiting = "biter-info-explanation-waiting",
  pathfinding = "biter-info-explanation-pathfinding",
  protesting = "biter-info-explanation-protesting",
  pacified = "biter-info-explanation-pacified",
  returning_home = "biter-info-explanation-returning_home",
  attacking = "biter-info-explanation-attacking",
}

local STATE_LABEL_KEYS = {
  waiting = "biter-info-state-waiting",
  pathfinding = "biter-info-state-pathfinding",
  protesting = "biter-info-state-protesting",
  pacified = "biter-info-state-pacified",
  returning_home = "biter-info-state-returning_home",
  attacking = "biter-info-state-attacking",
}

local TIER_MOOD_KEYS = {
  "biter-info-mood-calm",
  "biter-info-mood-irritated",
  "biter-info-mood-angry",
  "biter-info-mood-furious",
}

local function get_state_explanation(info)
  if not info then return nil end
  if info.hard_mode_attacking then
    return {"gui.biter-info-explanation-attacking"}
  end
  local key = STATE_EXPLANATION_KEYS[info.state]
  if key then return {"gui." .. key} end
  return nil
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

  local title = frame.add{type = "label", caption = {"gui.biter-info-title"}}
  title.style.font = "default-bold"
  title.style.bottom_margin = 4

  local capacity = C.get_frustration_capacity and C.get_frustration_capacity() or C.PROTEST_THRESHOLD
  local pct = math.floor((info.frustration or 0) / capacity * 100)
  local color = pct < 50 and {r=0.3, g=1, b=0.3} or pct < 80 and {r=1, g=1, b=0.3} or {r=1, g=0.2, b=0.2}
  local frust_label = frame.add{type = "label", caption = {"gui.biter-info-frustration", pct}}
  frust_label.style.font_color = color

  local bar = frame.add{type = "progressbar", value = math.min(1, pct / 100)}
  bar.style.width = 180
  bar.style.color = color

  local ft = C.get_individual_frust_tier(info)
  local mood_key = TIER_MOOD_KEYS[ft]
  local tier_label = frame.add{
    type = "label",
    caption = mood_key and {"gui.biter-info-mood", {"gui." .. mood_key}} or {"gui.biter-info-mood", "?"},
  }
  tier_label.style.font_color = {r=0.7, g=0.7, b=0.7}

  local state_key = STATE_LABEL_KEYS[info.state] or "biter-info-state-unknown"
  local state_label = frame.add{type = "label", caption = {"gui.biter-info-state", {"gui." .. state_key}}}
  state_label.style.font_color = info.state == "protesting" and {r=1, g=0.2, b=0.2} or {r=0.8, g=0.8, b=0.8}

  local explanation = get_state_explanation(info)
  if explanation then
    local explanation_label = frame.add{type = "label", caption = explanation}
    explanation_label.style.single_line = false
    explanation_label.style.maximal_width = 260
    explanation_label.style.font_color = {r=0.9, g=0.85, b=0.65}
  end

  if info.complaints and #info.complaints > 0 then
    local complaints_label = frame.add{type = "label", caption = {"gui.biter-info-pending-complaints"}}
    complaints_label.style.top_margin = 4
    for _, ticket in ipairs(info.complaints) do
      frame.add{
        type = "label",
        caption = {"gui.biter-info-complaint-line", ticket, {"item-name." .. ticket}},
      }
    end
  else
    frame.add{type = "label", caption = {"gui.biter-info-no-complaints"}}
  end
end

return M
