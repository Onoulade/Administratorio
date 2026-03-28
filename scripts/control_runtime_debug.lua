local M = {}

local RUNTIME_DEBUG_VIEW_NAME = "administratorio-runtime-debug"
local RUNTIME_DEBUG_CLOSE_NAME = "administratorio-runtime-debug-close"
local RUNTIME_DEBUG_EXPORT_NAME = "administratorio-runtime-debug-export"
local RUNTIME_DEBUG_UPDATED_NAME = "administratorio-runtime-debug-updated"
local RUNTIME_DEBUG_SUMMARY_NAME = "administratorio-runtime-debug-summary"
local RUNTIME_DEBUG_REGISTRATION_NAME = "administratorio-runtime-debug-registration"
local RUNTIME_DEBUG_COUNTS_NAME = "administratorio-runtime-debug-counts"
local RUNTIME_DEBUG_HISTORY_LIMIT = 60

local RUNTIME_DEBUG_ACCOUNTED_KEYS = {
  "unit_groups",
  "trains",
  "startup_cleanup",
  "working_hours",
  "desk_cache",
  "achievements",
  "registration",
  "resolutions",
  "frustration",
  "circuit",
  "debug_finalize",
}

local RUNTIME_DEBUG_TRANSLATED_KEYS = {
  "total",
  "unit_groups",
  "trains",
  "startup_cleanup",
  "working_hours",
  "desk_cache",
  "achievements",
  "registration",
  "registration_walkins",
  "registration_arrivals",
  "resolutions",
  "frustration",
  "circuit",
  "debug_finalize",
}

local RUNTIME_DEBUG_SUMMARY_ROWS = {
  {key = "total", label = {"gui.debug-total"}, export_label = "total", bold = true},
  {key = "unit_groups", label = {"gui.debug-unit-groups"}, export_label = "unit_groups"},
  {key = "trains", label = {"gui.debug-trains"}, export_label = "trains"},
  {key = "startup_cleanup", label = {"gui.debug-startup-cleanup"}, export_label = "startup_cleanup"},
  {key = "working_hours", label = {"gui.debug-working-hours"}, export_label = "working_hours"},
  {key = "desk_cache", label = {"gui.debug-desk-cache"}, export_label = "desk_cache"},
  {key = "achievements", label = {"gui.debug-achievements"}, export_label = "achievements"},
  {key = "registration", label = {"gui.debug-registration"}, export_label = "registration"},
  {key = "resolutions", label = {"gui.debug-resolutions"}, export_label = "resolutions"},
  {key = "frustration", label = {"gui.debug-frustration"}, export_label = "frustration"},
  {key = "circuit", label = {"gui.debug-circuit"}, export_label = "circuit"},
  {key = "debug_finalize", label = {"gui.debug-finalize"}, export_label = "debug_finalize"},
  {key = "other_overhead", label = {"gui.debug-other-overhead"}, export_label = "other_overhead", dim = true},
}

local RUNTIME_DEBUG_REGISTRATION_ROWS = {
  {key = "registration_walkins", label = {"gui.debug-registration-walkins"}, export_label = "registration_walkins"},
  {key = "registration_arrivals", label = {"gui.debug-registration-arrivals"}, export_label = "registration_arrivals"},
  {key = "registration_other", label = {"gui.debug-registration-other"}, export_label = "registration_other", dim = true},
}

local RUNTIME_DEBUG_COUNT_ROWS = {
  {key = "desks", label = {"gui.debug-count-desks"}},
  {key = "working_hours_buildings", label = {"gui.debug-count-working-hours-buildings"}},
  {key = "stations", label = {"gui.debug-count-stations"}},
  {key = "biters", label = {"gui.debug-count-biters"}},
  {key = "waiting", label = {"gui.debug-count-waiting"}},
  {key = "pathfinding", label = {"gui.debug-count-pathfinding"}},
  {key = "protesting", label = {"gui.debug-count-protesting"}},
  {key = "pacified", label = {"gui.debug-count-pacified"}},
  {key = "returning_home", label = {"gui.debug-count-returning"}},
}

local last_runtime_debug_snapshot = nil
local runtime_debug_history = {}
local runtime_debug_pending_samples = {}
local runtime_debug_pending_requests = {}
local runtime_debug_next_sample_id = 0

local update_runtime_debug_guis

local function is_runtime_debug_enabled(player_index)
  return storage.runtime_debug_players and storage.runtime_debug_players[player_index] == true
end

local function get_runtime_metric_value(sample, key)
  if not sample then return nil end

  if key == "registration_other" then
    local registration = sample.sections.registration
    local walkins = sample.sections.registration_walkins or 0
    local arrivals = sample.sections.registration_arrivals or 0
    if not registration then return nil end
    return math.max(0, registration - walkins - arrivals)
  elseif key == "other_overhead" then
    local total = sample.sections.total
    if not total then return nil end
    local accounted = 0
    for _, accounted_key in ipairs(RUNTIME_DEBUG_ACCOUNTED_KEYS) do
      accounted = accounted + (sample.sections[accounted_key] or 0)
    end
    return math.max(0, total - accounted)
  end

  return sample.sections[key]
end

local function compute_runtime_metric_stats(key)
  local last = get_runtime_metric_value(last_runtime_debug_snapshot, key)
  local high = nil
  local total = 0
  local count = 0

  for _, sample in ipairs(runtime_debug_history) do
    local value = get_runtime_metric_value(sample, key)
    if value ~= nil then
      total = total + value
      count = count + 1
      if not high or value > high then
        high = value
      end
    end
  end

  local average = count > 0 and (total / count) or nil
  return last, average, high
end

local function format_runtime_ms(value)
  if value == nil then
    return {"gui.debug-no-data"}
  end
  return string.format("%.3f ms", value)
end

local function format_runtime_export_ms(value)
  if value == nil then return "" end
  return string.format("%.3f", value)
end

local function parse_runtime_profiler_ms(result)
  if not result or result == "" then return nil end

  local normalized = result
    :gsub("[%z\1-\31]", "")
    :gsub("%s+", "")
    :gsub("\194\160", "")
    :gsub("\226\128\137", "")
    :gsub("\226\128\175", "")
    :gsub(",", ".")
    :gsub("μ", "µ")

  local number_text, unit = normalized:match("([%d%.]+)([munµ]?s)")
  if not number_text or not unit then return nil end

  local value = tonumber(number_text)
  if not value then return nil end

  if unit == "ms" then
    return value
  elseif unit == "s" then
    return value * 1000
  elseif unit == "us" or unit == "µs" then
    return value / 1000
  elseif unit == "ns" then
    return value / 1000000
  end

  return nil
end

local function get_runtime_debug_translation_player()
  for _, player in pairs(game.connected_players) do
    if is_runtime_debug_enabled(player.index) then
      return player
    end
  end
  return game.connected_players[1]
end

local function request_runtime_profiler_translation(player, profiler)
  if not player or not profiler then return nil end
  return player.request_translation(profiler) or player.request_translation({"", profiler})
end

local function finalize_runtime_debug_sample(sample_id)
  local sample = runtime_debug_pending_samples[sample_id]
  if not sample or sample.pending > 0 then return end

  runtime_debug_pending_samples[sample_id] = nil
  local completed_sample = {
    tick = sample.tick,
    counts = sample.counts,
    sections = sample.sections,
  }

  if not last_runtime_debug_snapshot or completed_sample.tick >= last_runtime_debug_snapshot.tick then
    last_runtime_debug_snapshot = completed_sample
  end

  runtime_debug_history[#runtime_debug_history + 1] = completed_sample
  table.sort(runtime_debug_history, function(a, b)
    return a.tick < b.tick
  end)
  while #runtime_debug_history > RUNTIME_DEBUG_HISTORY_LIMIT do
    table.remove(runtime_debug_history, 1)
  end

  update_runtime_debug_guis()
end

local function queue_runtime_debug_snapshot(snapshot)
  local player = get_runtime_debug_translation_player()
  if not player or not player.valid or not player.connected then return end

  runtime_debug_next_sample_id = runtime_debug_next_sample_id + 1
  local sample_id = runtime_debug_next_sample_id
  local pending = {
    tick = snapshot.tick,
    counts = snapshot.counts,
    sections = {},
    pending = 0,
  }
  runtime_debug_pending_samples[sample_id] = pending
  local requested_any = false

  for _, key in ipairs(RUNTIME_DEBUG_TRANSLATED_KEYS) do
    local profiler = key == "total" and snapshot.total or snapshot.sections[key]
    if profiler then
      local request_id = request_runtime_profiler_translation(player, profiler)
      if request_id then
        runtime_debug_pending_requests[request_id] = {
          sample_id = sample_id,
          key = key,
        }
        pending.pending = pending.pending + 1
        requested_any = true
      end
    end
  end

  if not requested_any then
    runtime_debug_pending_samples[sample_id] = nil
    return
  end

  finalize_runtime_debug_sample(sample_id)
end

local function add_runtime_metric_table(parent, name, rows)
  local metric_table = parent.add{
    type = "table",
    name = name,
    column_count = 4,
  }
  metric_table.style.column_alignments[2] = "right"
  metric_table.style.column_alignments[3] = "right"
  metric_table.style.column_alignments[4] = "right"
  metric_table.style.horizontal_spacing = 16
  metric_table.style.vertical_spacing = 3

  local spacer = metric_table.add{type = "label", caption = ""}
  spacer.style.horizontally_stretchable = true

  local last_header = metric_table.add{type = "label", caption = {"gui.debug-header-last"}}
  last_header.style.font = "default-semibold"
  local avg_header = metric_table.add{type = "label", caption = {"gui.debug-header-avg"}}
  avg_header.style.font = "default-semibold"
  local high_header = metric_table.add{type = "label", caption = {"gui.debug-header-high"}}
  high_header.style.font = "default-semibold"

  for _, row in ipairs(rows) do
    local label = metric_table.add{
      type = "label",
      name = "label-" .. row.key,
      caption = row.label,
    }
    if row.bold then
      label.style.font = "default-semibold"
    elseif row.dim then
      label.style.font_color = {r = 0.7, g = 0.7, b = 0.7}
    end

    for _, prefix in ipairs({"last-", "avg-", "high-"}) do
      local value = metric_table.add{
        type = "label",
        name = prefix .. row.key,
        caption = {"gui.debug-no-data"},
      }
      if row.bold then
        value.style.font = "default-bold"
        value.style.font_color = {r = 1, g = 0.85, b = 0.2}
      end
    end
  end

  return metric_table
end

local function ensure_runtime_debug_gui(player)
  local frame = player.gui.left[RUNTIME_DEBUG_VIEW_NAME]
  if frame and frame.valid then
    if frame[RUNTIME_DEBUG_UPDATED_NAME]
      and frame[RUNTIME_DEBUG_SUMMARY_NAME]
      and frame[RUNTIME_DEBUG_REGISTRATION_NAME]
      and frame[RUNTIME_DEBUG_COUNTS_NAME] then
      return frame
    end
    frame.destroy()
  end

  frame = player.gui.left.add{
    type = "frame",
    name = RUNTIME_DEBUG_VIEW_NAME,
    direction = "vertical",
  }
  frame.style.minimal_width = 520

  local title_flow = frame.add{type = "flow", direction = "horizontal"}
  title_flow.style.horizontally_stretchable = true

  local title = title_flow.add{type = "label", caption = {"gui.debug-title"}}
  title.style.font = "default-bold"
  title.style.horizontally_stretchable = true

  local close_button = title_flow.add{
    type = "sprite-button",
    name = RUNTIME_DEBUG_CLOSE_NAME,
    sprite = "utility/close",
    style = "frame_action_button",
    tooltip = {"gui.debug-close"},
  }
  close_button.style.top_margin = -4

  local subtitle = frame.add{type = "label", caption = {"gui.debug-subtitle"}}
  subtitle.style.single_line = false
  subtitle.style.font_color = {r = 0.7, g = 0.7, b = 0.7}
  subtitle.style.bottom_margin = 4

  local updated = frame.add{
    type = "label",
    name = RUNTIME_DEBUG_UPDATED_NAME,
    caption = {"gui.debug-waiting"},
  }
  updated.style.font_color = {r = 0.85, g = 0.85, b = 0.85}
  updated.style.bottom_margin = 6

  local summary_title = frame.add{type = "label", caption = {"gui.debug-summary-title"}}
  summary_title.style.font = "default-semibold"
  add_runtime_metric_table(frame, RUNTIME_DEBUG_SUMMARY_NAME, RUNTIME_DEBUG_SUMMARY_ROWS)

  frame.add{type = "line"}

  local registration_title = frame.add{type = "label", caption = {"gui.debug-registration-title"}}
  registration_title.style.font = "default-semibold"
  registration_title.style.top_margin = 2
  add_runtime_metric_table(frame, RUNTIME_DEBUG_REGISTRATION_NAME, RUNTIME_DEBUG_REGISTRATION_ROWS)

  frame.add{type = "line"}

  local counts_title = frame.add{type = "label", caption = {"gui.debug-counts-title"}}
  counts_title.style.font = "default-semibold"
  counts_title.style.top_margin = 2

  local counts_table = frame.add{
    type = "table",
    name = RUNTIME_DEBUG_COUNTS_NAME,
    column_count = 2,
  }
  counts_table.style.column_alignments[2] = "right"
  counts_table.style.horizontal_spacing = 20
  counts_table.style.vertical_spacing = 3

  for _, row in ipairs(RUNTIME_DEBUG_COUNT_ROWS) do
    counts_table.add{
      type = "label",
      name = "label-" .. row.key,
      caption = row.label,
    }
    counts_table.add{
      type = "label",
      name = "value-" .. row.key,
      caption = "0",
    }
  end

  local button_flow = frame.add{type = "flow", direction = "horizontal"}
  button_flow.style.top_margin = 8
  button_flow.add{
    type = "button",
    name = RUNTIME_DEBUG_EXPORT_NAME,
    caption = {"gui.debug-export"},
  }

  return frame
end

local function update_runtime_metric_table(metric_table, rows)
  if not metric_table or not metric_table.valid then return end

  for _, row in ipairs(rows) do
    local last, average, high = compute_runtime_metric_stats(row.key)
    local last_value = metric_table["last-" .. row.key]
    local avg_value = metric_table["avg-" .. row.key]
    local high_value = metric_table["high-" .. row.key]

    if last_value then last_value.caption = format_runtime_ms(last) end
    if avg_value then avg_value.caption = format_runtime_ms(average) end
    if high_value then high_value.caption = format_runtime_ms(high) end
  end
end

local function update_runtime_debug_gui(player)
  if not player or not player.valid then return end

  if not is_runtime_debug_enabled(player.index) then
    local frame = player.gui.left[RUNTIME_DEBUG_VIEW_NAME]
    if frame then frame.destroy() end
    return
  end

  local frame = ensure_runtime_debug_gui(player)
  local updated = frame[RUNTIME_DEBUG_UPDATED_NAME]
  local summary_table = frame[RUNTIME_DEBUG_SUMMARY_NAME]
  local registration_table = frame[RUNTIME_DEBUG_REGISTRATION_NAME]
  local counts_table = frame[RUNTIME_DEBUG_COUNTS_NAME]

  if last_runtime_debug_snapshot then
    updated.caption = {"gui.debug-updated", last_runtime_debug_snapshot.tick, #runtime_debug_history}
  else
    updated.caption = {"gui.debug-waiting"}
  end

  update_runtime_metric_table(summary_table, RUNTIME_DEBUG_SUMMARY_ROWS)
  update_runtime_metric_table(registration_table, RUNTIME_DEBUG_REGISTRATION_ROWS)

  for _, row in ipairs(RUNTIME_DEBUG_COUNT_ROWS) do
    local value = counts_table["value-" .. row.key]
    if value then
      local count = last_runtime_debug_snapshot and last_runtime_debug_snapshot.counts[row.key] or 0
      value.caption = tostring(count)
    end
  end
end

local function build_runtime_debug_export_text()
  local sample_count = #runtime_debug_history
  local lines = {
    "Administratorio Runtime Debug Export",
    "",
    "tick\t" .. tostring(last_runtime_debug_snapshot and last_runtime_debug_snapshot.tick or 0),
    "minute_samples\t" .. tostring(sample_count),
    "",
    "top_level_breakdown",
    "section\tlast_ms\tavg_ms\thigh_ms",
  }

  for _, row in ipairs(RUNTIME_DEBUG_SUMMARY_ROWS) do
    local last, average, high = compute_runtime_metric_stats(row.key)
    lines[#lines + 1] = table.concat({
      row.export_label,
      format_runtime_export_ms(last),
      format_runtime_export_ms(average),
      format_runtime_export_ms(high),
    }, "\t")
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "registration_detail_subset"
  lines[#lines + 1] = "section\tlast_ms\tavg_ms\thigh_ms"

  for _, row in ipairs(RUNTIME_DEBUG_REGISTRATION_ROWS) do
    local last, average, high = compute_runtime_metric_stats(row.key)
    lines[#lines + 1] = table.concat({
      row.export_label,
      format_runtime_export_ms(last),
      format_runtime_export_ms(average),
      format_runtime_export_ms(high),
    }, "\t")
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "live_counts"
  lines[#lines + 1] = "key\tvalue"

  for _, row in ipairs(RUNTIME_DEBUG_COUNT_ROWS) do
    local count = last_runtime_debug_snapshot and last_runtime_debug_snapshot.counts[row.key] or 0
    lines[#lines + 1] = row.key .. "\t" .. tostring(count)
  end

  return table.concat(lines, "\n") .. "\n"
end

local function export_runtime_debug(player)
  if not player or not player.valid then return end
  if not last_runtime_debug_snapshot or #runtime_debug_history == 0 then
    player.print({"message.runtime-debug-export-unavailable"})
    return
  end

  local path = string.format(
    "administratorio/runtime-debug/runtime-debug-%d-player-%d.txt",
    last_runtime_debug_snapshot.tick,
    player.index
  )
  helpers.write_file(path, build_runtime_debug_export_text(), false, player.index)
  player.print({"message.runtime-debug-exported", path})
end

update_runtime_debug_guis = function()
  for _, player in pairs(game.connected_players) do
    update_runtime_debug_gui(player)
  end
end

function M.is_enabled(player_index)
  return is_runtime_debug_enabled(player_index)
end

function M.has_active_viewers()
  if not storage.runtime_debug_players then return false end
  for player_index, enabled in pairs(storage.runtime_debug_players) do
    if enabled then
      local player = game.get_player(player_index)
      if player and player.valid and player.connected then
        return true
      end
    end
  end
  return false
end

function M.run_profiled_section(snapshot, key, fn)
  if not snapshot then
    fn()
    return
  end

  local profiler = game.create_profiler()
  fn()
  profiler.stop()
  snapshot.sections[key] = profiler
end

function M.begin_snapshot(tick)
  if not M.has_active_viewers() then
    return nil, nil
  end

  return {
    tick = tick,
    sections = {},
    counts = {},
  }, game.create_profiler()
end

function M.complete_snapshot(snapshot, total_profiler)
  if not snapshot or not total_profiler then return end

  total_profiler.stop()
  snapshot.total = total_profiler
  queue_runtime_debug_snapshot(snapshot)
end

function M.toggle(player)
  if not player then return end

  local enabled = not is_runtime_debug_enabled(player.index)
  storage.runtime_debug_players[player.index] = enabled or nil

  update_runtime_debug_gui(player)
  if enabled then
    player.print({"message.runtime-debug-enabled"})
  else
    player.print({"message.runtime-debug-disabled"})
  end
end

function M.handle_gui_click(player, element_name)
  if element_name == RUNTIME_DEBUG_CLOSE_NAME then
    storage.runtime_debug_players[player.index] = nil
    update_runtime_debug_gui(player)
    return true
  end

  if element_name == RUNTIME_DEBUG_EXPORT_NAME then
    export_runtime_debug(player)
    return true
  end

  return false
end

function M.handle_string_translated(event)
  local request = runtime_debug_pending_requests[event.id]
  if not request then return end

  runtime_debug_pending_requests[event.id] = nil
  local sample = runtime_debug_pending_samples[request.sample_id]
  if not sample then return end

  local parsed_ms = event.translated and parse_runtime_profiler_ms(event.result) or nil
  sample.sections[request.key] = parsed_ms
  sample.pending = math.max(0, sample.pending - 1)

  finalize_runtime_debug_sample(request.sample_id)
end

return M
