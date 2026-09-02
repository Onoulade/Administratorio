local M = {}

local RUNTIME_DEBUG_VIEW_NAME = "administratorio-runtime-debug"
local RUNTIME_DEBUG_CLOSE_NAME = "administratorio-runtime-debug-close"
local RUNTIME_DEBUG_EXPORT_NAME = "administratorio-runtime-debug-export"
local RUNTIME_DEBUG_UPDATED_NAME = "administratorio-runtime-debug-updated"
local RUNTIME_DEBUG_SUMMARY_NAME = "administratorio-runtime-debug-summary"
local RUNTIME_DEBUG_REGISTRATION_NAME = "administratorio-runtime-debug-registration"
local RUNTIME_DEBUG_FIELD_OFFICE_NAME = "administratorio-runtime-debug-field-office"
local RUNTIME_DEBUG_COUNTS_NAME = "administratorio-runtime-debug-counts"
local RUNTIME_DEBUG_BUTTONS_NAME = "administratorio-runtime-debug-buttons"
local RUNTIME_DEBUG_CONTENT_NAME = "administratorio-runtime-debug-content"
local COMPLAINT_LOCATOR_OPEN_NAME = "administratorio-complaint-locator-open"
local COMPLAINT_LOCATOR_FRAME_NAME = "administratorio-complaint-locator"
local COMPLAINT_LOCATOR_CLOSE_NAME = "administratorio-complaint-locator-close"
local COMPLAINT_LOCATOR_REFRESH_NAME = "administratorio-complaint-locator-refresh"
local COMPLAINT_LOCATOR_FILTERS_NAME = "administratorio-complaint-locator-filters"
local COMPLAINT_LOCATOR_ITEM_NAME = "administratorio-complaint-locator-item"
local COMPLAINT_LOCATOR_RESULTS_NAME = "administratorio-complaint-locator-results"
local COMPLAINT_LOCATOR_SUMMARY_NAME = "administratorio-complaint-locator-summary"
local COMPLAINT_LOCATOR_RESULT_PREFIX = "administratorio-complaint-locator-result-"
local RUNTIME_DEBUG_HISTORY_LIMIT = 60
local COMPLAINT_LOCATOR_RESULT_LIMIT = 100

local COMPLAINT_LOCATOR_ITEMS = {
  "ticket-landscape",
  "ticket-smog",
  "ticket-noise",
  "ticket-unemployment",
  "ticket-littering",
  "ticket-hazmat",
  "ticket-loitering",
  "ticket-vagrancy",
  "resolved-landscape",
  "resolved-smog",
  "resolved-noise",
  "resolved-unemployment",
  "resolved-littering",
  "resolved-hazmat",
  "resolved-loitering",
  "resolved-vagrancy",
}

local BELT_CONNECTABLE_TYPES = {
  ["transport-belt"] = true,
  ["underground-belt"] = true,
  splitter = true,
  loader = true,
  ["loader-1x1"] = true,
  ["linked-belt"] = true,
}

local RUNTIME_DEBUG_ACCOUNTED_KEYS = {
  "unit_groups",
  "unit_group_debug_tick",
  "group_redirects",
  "pneumatic",
  "trains",
  "biter_station",
  "biterport",
  "hired_biter",
  "rideable_biter",
  "protest_pacing",
  "startup_cleanup",
  "evolution_warnings",
  "working_hours_refresh",
  "protest_refresh",
  "working_hours",
  "desk_cache",
  "achievements",
  "registration",
  "resolutions",
  "frustration",
  "calmed_spawners",
  "circuit",
  "field_office",
  "field_office_placement_preview",
  "debug_finalize",
}

local RUNTIME_DEBUG_TRANSLATED_KEYS = {
  "total",
  "unit_groups",
  "unit_group_debug_tick",
  "group_redirects",
  "pneumatic",
  "trains",
  "biter_station",
  "biterport",
  "hired_biter",
  "rideable_biter",
  "protest_pacing",
  "startup_cleanup",
  "evolution_warnings",
  "working_hours_refresh",
  "protest_refresh",
  "working_hours",
  "desk_cache",
  "achievements",
  "registration",
  "registration_walkins",
  "registration_arrivals",
  "resolutions",
  "frustration",
  "calmed_spawners",
  "circuit",
  "field_office",
  "field_office_placement_preview",
  "field_office_releasing",
  "field_office_spawner_cache",
  "field_office_readiness",
  "field_office_spawner_lookup",
  "field_office_spawn_worker",
  "field_office_calling",
  "field_office_working",
  "debug_finalize",
}

local RUNTIME_DEBUG_SUMMARY_ROWS = {
  {key = "total", label = {"gui.debug-total"}, export_label = "total", bold = true},
  {key = "unit_groups", label = {"gui.debug-unit-groups"}, export_label = "unit_groups"},
  {key = "unit_group_debug_tick", label = {"gui.debug-unit-group-debug-tick"}, export_label = "unit_group_debug_tick"},
  {key = "group_redirects", label = {"gui.debug-group-redirects"}, export_label = "group_redirects"},
  {key = "pneumatic", label = {"gui.debug-pneumatic"}, export_label = "pneumatic"},
  {key = "trains", label = {"gui.debug-trains"}, export_label = "trains"},
  {key = "biter_station", label = {"gui.debug-biter-station"}, export_label = "biter_station"},
  {key = "biterport", label = {"gui.debug-biterport"}, export_label = "biterport"},
  {key = "hired_biter", label = {"gui.debug-hired-biter"}, export_label = "hired_biter"},
  {key = "rideable_biter", label = {"gui.debug-rideable-biter"}, export_label = "rideable_biter"},
  {key = "protest_pacing", label = {"gui.debug-protest-pacing"}, export_label = "protest_pacing"},
  {key = "startup_cleanup", label = {"gui.debug-startup-cleanup"}, export_label = "startup_cleanup"},
  {key = "evolution_warnings", label = {"gui.debug-evolution-warnings"}, export_label = "evolution_warnings"},
  {key = "working_hours_refresh", label = {"gui.debug-working-hours-refresh"}, export_label = "working_hours_refresh"},
  {key = "protest_refresh", label = {"gui.debug-protest-refresh"}, export_label = "protest_refresh"},
  {key = "working_hours", label = {"gui.debug-working-hours"}, export_label = "working_hours"},
  {key = "desk_cache", label = {"gui.debug-desk-cache"}, export_label = "desk_cache"},
  {key = "achievements", label = {"gui.debug-achievements"}, export_label = "achievements"},
  {key = "registration", label = {"gui.debug-registration"}, export_label = "registration"},
  {key = "resolutions", label = {"gui.debug-resolutions"}, export_label = "resolutions"},
  {key = "frustration", label = {"gui.debug-frustration"}, export_label = "frustration"},
  {key = "calmed_spawners", label = {"gui.debug-calmed-spawners"}, export_label = "calmed_spawners"},
  {key = "circuit", label = {"gui.debug-circuit"}, export_label = "circuit"},
  {key = "field_office", label = {"gui.debug-field-office"}, export_label = "field_office"},
  {key = "field_office_placement_preview", label = {"gui.debug-field-office-placement-preview"}, export_label = "field_office_placement_preview"},
  {key = "debug_finalize", label = {"gui.debug-finalize"}, export_label = "debug_finalize"},
  {key = "other_overhead", label = {"gui.debug-other-overhead"}, export_label = "other_overhead", dim = true},
}

local RUNTIME_DEBUG_REGISTRATION_ROWS = {
  {key = "registration_walkins", label = {"gui.debug-registration-walkins"}, export_label = "registration_walkins"},
  {key = "registration_arrivals", label = {"gui.debug-registration-arrivals"}, export_label = "registration_arrivals"},
  {key = "registration_other", label = {"gui.debug-registration-other"}, export_label = "registration_other", dim = true},
}

local RUNTIME_DEBUG_FIELD_OFFICE_ROWS = {
  {key = "field_office_releasing", label = {"gui.debug-field-office-releasing"}, export_label = "field_office_releasing"},
  {key = "field_office_spawner_cache", label = {"gui.debug-field-office-spawner-cache"}, export_label = "field_office_spawner_cache"},
  {key = "field_office_readiness", label = {"gui.debug-field-office-readiness"}, export_label = "field_office_readiness"},
  {key = "field_office_spawner_lookup", label = {"gui.debug-field-office-spawner-lookup"}, export_label = "field_office_spawner_lookup"},
  {key = "field_office_spawn_worker", label = {"gui.debug-field-office-spawn-worker"}, export_label = "field_office_spawn_worker"},
  {key = "field_office_calling", label = {"gui.debug-field-office-calling"}, export_label = "field_office_calling"},
  {key = "field_office_working", label = {"gui.debug-field-office-working"}, export_label = "field_office_working"},
}

local RUNTIME_DEBUG_COUNT_ROWS = {
  {key = "desks", label = {"gui.debug-count-desks"}},
  {key = "working_hours_buildings", label = {"gui.debug-count-working-hours-buildings"}},
  {key = "stations", label = {"gui.debug-count-stations"}},
  {key = "field_offices", label = {"gui.debug-count-field-offices"}},
  {key = "field_office_idle", label = {"gui.debug-count-field-office-idle"}},
  {key = "field_office_calling", label = {"gui.debug-count-field-office-calling"}},
  {key = "field_office_working", label = {"gui.debug-count-field-office-working"}},
  {key = "field_office_releasing", label = {"gui.debug-count-field-office-releasing"}},
  {key = "biters", label = {"gui.debug-count-biters"}},
  {key = "waiting", label = {"gui.debug-count-waiting"}},
  {key = "pathfinding", label = {"gui.debug-count-pathfinding"}},
  {key = "protesting", label = {"gui.debug-count-protesting"}},
  {key = "pacified", label = {"gui.debug-count-pacified"}},
  {key = "returning_home", label = {"gui.debug-count-returning"}},
  {key = "attacking", label = {"gui.debug-count-attacking"}},
  {key = "pending_group_redirects", label = {"gui.debug-count-pending-group-redirects"}},
  {key = "pending_path_requests", label = {"gui.debug-count-pending-path-requests"}},
  {key = "calmed_spawners", label = {"gui.debug-count-calmed-spawners"}},
}

local last_runtime_debug_snapshot = nil
local runtime_debug_history = {}
local runtime_debug_pending_samples = {}
local runtime_debug_pending_requests = {}
local runtime_debug_next_sample_id = 0
local runtime_debug_external_sections = {}
local runtime_debug_external_total = nil
local complaint_locator_results_by_player = {}

local update_runtime_debug_guis

local function complaint_locator_result_index(element_name)
  if type(element_name) ~= "string" then return nil end
  if element_name:sub(1, #COMPLAINT_LOCATOR_RESULT_PREFIX) ~= COMPLAINT_LOCATOR_RESULT_PREFIX then
    return nil
  end
  local suffix = element_name:sub(#COMPLAINT_LOCATOR_RESULT_PREFIX + 1)
  if suffix == "" or suffix:find("%D") then return nil end
  return tonumber(suffix)
end

local function pool_key_item_name(key)
  if type(key) ~= "string" then return nil end
  local separator = key:find("\31", 1, true)
  return separator and key:sub(1, separator - 1) or key
end

local function inventory_item_count(owner, item_name)
  local total = 0
  local seen = {}
  local ok, max_index = pcall(owner.get_max_inventory_index)
  if not ok or not max_index then return 0 end
  for inventory_index = 1, max_index do
    local got_inventory, inventory = pcall(owner.get_inventory, inventory_index)
    if got_inventory and inventory and inventory.valid and not seen[inventory] then
      seen[inventory] = true
      local got_count, count = pcall(inventory.get_item_count, item_name)
      if got_count then total = total + (count or 0) end
    end
  end
  return total
end

local function line_item_count(line, item_name)
  if not line or not line.valid then return 0 end
  local total = 0
  for index = 1, #line do
    local stack = line[index]
    if stack and stack.valid_for_read and stack.name == item_name then
      total = total + (stack.count or 0)
    end
  end
  return total
end

local function entity_transport_item_count(entity, item_name)
  if not BELT_CONNECTABLE_TYPES[entity.type] then return 0 end
  local ok, max_index = pcall(entity.get_max_transport_line_index)
  if not ok or not max_index then return 0 end
  local total = 0
  for line_index = 1, max_index do
    local got_line, line = pcall(entity.get_transport_line, line_index)
    if got_line then total = total + line_item_count(line, item_name) end
  end
  return total
end

local function add_locator_result(rows, count, source, anchor, surface, position)
  if not count or count <= 0 then return end
  if anchor and anchor.valid then
    surface = anchor.surface
    position = anchor.position
  end
  rows[#rows + 1] = {
    count = count,
    source = source,
    anchor = anchor,
    surface = surface,
    position = position,
  }
end

local function first_pneumatic_anchor(net_id)
  for uid, entry in pairs(storage.tube_intakes or {}) do
    if storage.tube_network_cache and storage.tube_network_cache[uid] == net_id
      and entry.entity and entry.entity.valid then
      return entry.entity
    end
  end
  for uid, entry in pairs(storage.tube_outtakes or {}) do
    if storage.tube_network_cache and storage.tube_network_cache[uid] == net_id
      and entry.entity and entry.entity.valid then
      return entry.entity
    end
  end
  return nil
end

local function first_terminus_anchor(force_index)
  for _, entry in pairs(storage.terminus_registry or {}) do
    if entry.force_index == force_index and entry.entity and entry.entity.valid then
      return entry.entity
    end
  end
  return nil
end

local function scan_script_managed_items(rows, item_name)
  for net_id, pool in pairs(storage.tube_signals or {}) do
    local count = 0
    for key, amount in pairs(pool) do
      if pool_key_item_name(key) == item_name then count = count + amount end
    end
    add_locator_result(rows, count, {"gui.complaint-locator-source-pneumatic"}, first_pneumatic_anchor(net_id))
  end

  for _, pool in pairs(storage.tube_orphan_signals or {}) do
    local count = 0
    for key, amount in pairs(pool) do
      if pool_key_item_name(key) == item_name then count = count + amount end
    end
    add_locator_result(rows, count, {"gui.complaint-locator-source-pneumatic-orphan"})
  end

  for _, flight in ipairs(storage.terminus_flights or {}) do
    if flight.item == item_name then
      add_locator_result(rows, flight.count, {"gui.complaint-locator-source-terminus-transit"}, flight.from_entity)
    end
  end

  for force_index, pool in pairs(storage.trunk_pool or {}) do
    local count = 0
    for key, amount in pairs(pool) do
      if pool_key_item_name(key) == item_name then count = count + amount end
    end
    add_locator_result(rows, count, {"gui.complaint-locator-source-terminus-pool"}, first_terminus_anchor(force_index))
  end

  for _, active in pairs(storage.biterport_workers or {}) do
    local stack = active and active.carried_stack
    if stack and stack.name == item_name then
      add_locator_result(rows, stack.count, {"gui.complaint-locator-source-biterport"}, active.biter)
    end
  end
end

local function scan_world_for_complaint_item(item_name, requesting_player)
  local rows = {}
  local scanned_entities = 0

  local function scan_player(owner)
    local count = inventory_item_count(owner, item_name)
    local cursor = owner.cursor_stack
    if cursor and cursor.valid_for_read and cursor.name == item_name then
      count = count + (cursor.count or 0)
    end
    add_locator_result(rows, count, {"gui.complaint-locator-source-player", owner.name},
      owner.character, owner.surface, owner.position)
  end

  if requesting_player then scan_player(requesting_player) end
  if #rows > 0 then
    return rows, 0, rows[1].count, true
  end

  for _, owner in pairs(game.players) do
    if owner ~= requesting_player then scan_player(owner) end
  end

  if #rows > 0 then
    local total_items = 0
    for _, row in ipairs(rows) do total_items = total_items + row.count end
    return rows, 0, total_items, true
  end

  for _, surface in pairs(game.surfaces) do
    for _, entity in ipairs(surface.find_entities()) do
      scanned_entities = scanned_entities + 1
      if entity.valid then
        if entity.type == "item-entity" then
          local stack = entity.stack
          if stack and stack.valid_for_read and stack.name == item_name then
            add_locator_result(rows, stack.count, {"gui.complaint-locator-source-ground"}, entity)
          end
        elseif entity.type ~= "character" then
          local inventory_count = inventory_item_count(entity, item_name)
          add_locator_result(rows, inventory_count, {
            "gui.complaint-locator-source-inventory", "[entity=" .. entity.name .. "]"
          }, entity)

          local transport_count = entity_transport_item_count(entity, item_name)
          add_locator_result(rows, transport_count, {
            "gui.complaint-locator-source-belt", "[entity=" .. entity.name .. "]"
          }, entity)

          if entity.type == "inserter" then
            local held = entity.held_stack
            if held and held.valid_for_read and held.name == item_name then
              add_locator_result(rows, held.count, {"gui.complaint-locator-source-inserter"}, entity)
            end
          end
        end
      end
    end
  end

  scan_script_managed_items(rows, item_name)
  table.sort(rows, function(a, b)
    if a.surface and not b.surface then return true end
    if b.surface and not a.surface then return false end
    local a_surface = a.surface and a.surface.index or math.huge
    local b_surface = b.surface and b.surface.index or math.huge
    if a_surface ~= b_surface then return a_surface < b_surface end
    local ax = a.position and a.position.x or math.huge
    local bx = b.position and b.position.x or math.huge
    if ax ~= bx then return ax < bx end
    local ay = a.position and a.position.y or math.huge
    local by = b.position and b.position.y or math.huge
    return ay < by
  end)

  local total_items = 0
  for _, row in ipairs(rows) do total_items = total_items + row.count end
  return rows, scanned_entities, total_items, false
end

local function add_runtime_profiler_to_table(target, key, profiler)
  if not target or not key or not profiler then return end
  local section = target[key]
  if not section then
    section = game.create_profiler(true)
    target[key] = section
  end
  section.add(profiler)
end

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
  local legacy_frame = player.gui.left[RUNTIME_DEBUG_VIEW_NAME]
  if legacy_frame and legacy_frame.valid then legacy_frame.destroy() end
  local display_height = player.display_resolution and player.display_resolution.height or 900
  local display_scale = player.display_scale or 1
  local available_height = math.max(320, math.floor(display_height / display_scale) - 120)
  local frame = player.gui.screen[RUNTIME_DEBUG_VIEW_NAME]
  if frame and frame.valid then
    local content = frame[RUNTIME_DEBUG_CONTENT_NAME]
    if content
      and content[RUNTIME_DEBUG_UPDATED_NAME]
      and content[RUNTIME_DEBUG_SUMMARY_NAME]
      and content[RUNTIME_DEBUG_REGISTRATION_NAME]
      and content[RUNTIME_DEBUG_FIELD_OFFICE_NAME]
      and content[RUNTIME_DEBUG_COUNTS_NAME]
      and frame[RUNTIME_DEBUG_BUTTONS_NAME]
      and frame[RUNTIME_DEBUG_BUTTONS_NAME][COMPLAINT_LOCATOR_OPEN_NAME] then
      frame.style.height = available_height
      frame.style.maximal_height = available_height
      content.style.height = available_height - 50
      content.style.maximal_height = available_height - 50
      return frame
    end
    frame.destroy()
  end

  frame = player.gui.screen.add{
    type = "frame",
    name = RUNTIME_DEBUG_VIEW_NAME,
    direction = "vertical",
  }
  frame.style.minimal_width = 520
  frame.style.height = available_height
  frame.style.maximal_height = available_height
  frame.auto_center = true

  local title_flow = frame.add{type = "flow", name = RUNTIME_DEBUG_BUTTONS_NAME, direction = "horizontal"}
  title_flow.drag_target = frame
  title_flow.style.horizontally_stretchable = true

  local title = title_flow.add{type = "label", caption = {"gui.debug-title"}, style = "frame_title"}
  title.drag_target = frame
  title.style.horizontally_stretchable = true

  title_flow.add{
    type = "button",
    name = COMPLAINT_LOCATOR_OPEN_NAME,
    caption = {"gui.complaint-locator-open"},
  }
  title_flow.add{
    type = "button",
    name = RUNTIME_DEBUG_EXPORT_NAME,
    caption = {"gui.debug-export"},
  }

  local close_button = title_flow.add{
    type = "sprite-button",
    name = RUNTIME_DEBUG_CLOSE_NAME,
    sprite = "utility/close",
    style = "frame_action_button",
    tooltip = {"gui.debug-close"},
  }
  close_button.style.top_margin = -4

  local content = frame.add{
    type = "scroll-pane",
    name = RUNTIME_DEBUG_CONTENT_NAME,
    direction = "vertical",
    vertical_scroll_policy = "auto",
    horizontal_scroll_policy = "never",
  }
  content.style.horizontally_stretchable = true
  content.style.vertically_stretchable = true
  content.style.height = available_height - 50
  content.style.maximal_height = available_height - 50

  local subtitle = content.add{type = "label", caption = {"gui.debug-subtitle"}}
  subtitle.style.single_line = false
  subtitle.style.maximal_width = 480
  subtitle.style.font_color = {r = 0.7, g = 0.7, b = 0.7}
  subtitle.style.bottom_margin = 4

  local updated = content.add{
    type = "label",
    name = RUNTIME_DEBUG_UPDATED_NAME,
    caption = {"gui.debug-waiting"},
  }
  updated.style.font_color = {r = 0.85, g = 0.85, b = 0.85}
  updated.style.bottom_margin = 6

  local summary_title = content.add{type = "label", caption = {"gui.debug-summary-title"}}
  summary_title.style.font = "default-semibold"
  add_runtime_metric_table(content, RUNTIME_DEBUG_SUMMARY_NAME, RUNTIME_DEBUG_SUMMARY_ROWS)

  content.add{type = "line"}

  local registration_title = content.add{type = "label", caption = {"gui.debug-registration-title"}}
  registration_title.style.font = "default-semibold"
  registration_title.style.top_margin = 2
  add_runtime_metric_table(content, RUNTIME_DEBUG_REGISTRATION_NAME, RUNTIME_DEBUG_REGISTRATION_ROWS)

  content.add{type = "line"}

  local field_office_title = content.add{type = "label", caption = {"gui.debug-field-office-title"}}
  field_office_title.style.font = "default-semibold"
  field_office_title.style.top_margin = 2
  add_runtime_metric_table(content, RUNTIME_DEBUG_FIELD_OFFICE_NAME, RUNTIME_DEBUG_FIELD_OFFICE_ROWS)

  content.add{type = "line"}

  local counts_title = content.add{type = "label", caption = {"gui.debug-counts-title"}}
  counts_title.style.font = "default-semibold"
  counts_title.style.top_margin = 2

  local counts_table = content.add{
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

  return frame
end

local function ensure_complaint_locator_gui(player)
  local existing = player.gui.screen[COMPLAINT_LOCATOR_FRAME_NAME]
  if existing and existing.valid then return existing end

  local frame = player.gui.screen.add{
    type = "frame",
    name = COMPLAINT_LOCATOR_FRAME_NAME,
    direction = "vertical",
  }
  frame.style.minimal_width = 440
  frame.style.maximal_width = 480
  frame.style.maximal_height = 700
  frame.auto_center = true

  local titlebar = frame.add{type = "flow", direction = "horizontal"}
  titlebar.drag_target = frame
  titlebar.style.horizontally_stretchable = true
  local title = titlebar.add{type = "label", caption = {"gui.complaint-locator-title"}, style = "frame_title"}
  title.drag_target = frame
  title.style.horizontally_stretchable = true
  titlebar.add{
    type = "sprite-button",
    name = COMPLAINT_LOCATOR_CLOSE_NAME,
    sprite = "utility/close",
    style = "frame_action_button",
    tooltip = {"gui.debug-close"},
  }

  local subtitle = frame.add{type = "label", caption = {"gui.complaint-locator-subtitle"}}
  subtitle.style.single_line = false
  subtitle.style.maximal_width = 440
  subtitle.style.font_color = {r = 0.7, g = 0.7, b = 0.7}

  local filters = frame.add{type = "flow", name = COMPLAINT_LOCATOR_FILTERS_NAME, direction = "horizontal"}
  filters.style.top_margin = 6
  filters.add{type = "label", caption = {"gui.complaint-locator-item-filter"}}
  local item_items = {}
  for _, item_name in ipairs(COMPLAINT_LOCATOR_ITEMS) do
    item_items[#item_items + 1] = {"item-name." .. item_name}
  end
  filters.add{
    type = "drop-down",
    name = COMPLAINT_LOCATOR_ITEM_NAME,
    items = item_items,
    selected_index = 1,
  }
  filters.add{
    type = "button",
    name = COMPLAINT_LOCATOR_REFRESH_NAME,
    caption = {"gui.complaint-locator-search"},
  }

  local summary = frame.add{
    type = "label",
    name = COMPLAINT_LOCATOR_SUMMARY_NAME,
    caption = {"gui.complaint-locator-ready"},
  }
  summary.style.top_margin = 6
  summary.style.font = "default-semibold"

  local results = frame.add{
    type = "scroll-pane",
    name = COMPLAINT_LOCATOR_RESULTS_NAME,
    direction = "vertical",
    vertical_scroll_policy = "auto",
    horizontal_scroll_policy = "never",
  }
  results.style.horizontally_stretchable = true
  results.style.maximal_height = 520

  return frame
end

local function release_complaint_locator_pause(player_index)
  complaint_locator_results_by_player[player_index] = nil
  local owners = storage.complaint_locator_pause_owners
  if not owners or not owners[player_index] then return end
  owners[player_index] = nil
  if not next(owners) then
    game.tick_paused = storage.complaint_locator_preexisting_pause == true
    storage.complaint_locator_preexisting_pause = nil
  end
end

local function refresh_complaint_locator(player)
  local frame = player.gui.screen[COMPLAINT_LOCATOR_FRAME_NAME]
  if not frame or not frame.valid then return end
  local filters = frame[COMPLAINT_LOCATOR_FILTERS_NAME]
  local dropdown = filters[COMPLAINT_LOCATOR_ITEM_NAME]
  local item_name = COMPLAINT_LOCATOR_ITEMS[dropdown.selected_index]
  local results = frame[COMPLAINT_LOCATOR_RESULTS_NAME]
  results.clear()

  storage.complaint_locator_pause_owners = storage.complaint_locator_pause_owners or {}
  if not next(storage.complaint_locator_pause_owners) then
    storage.complaint_locator_preexisting_pause = game.tick_paused == true
  end
  storage.complaint_locator_pause_owners[player.index] = true
  game.tick_paused = true

  frame[COMPLAINT_LOCATOR_SUMMARY_NAME].caption = {"gui.complaint-locator-searching", {"item-name." .. item_name}}
  local scan_ok, rows, scanned_entities, total_items, player_only =
    pcall(scan_world_for_complaint_item, item_name, player)
  if not scan_ok then
    release_complaint_locator_pause(player.index)
    error(rows)
  end
  complaint_locator_results_by_player[player.index] = rows

  local shown = math.min(#rows, COMPLAINT_LOCATOR_RESULT_LIMIT)
  frame[COMPLAINT_LOCATOR_SUMMARY_NAME].caption = {
    player_only and "gui.complaint-locator-summary-player" or "gui.complaint-locator-summary",
    total_items,
    #rows,
    shown,
    scanned_entities,
  }
  if shown == 0 then
    results.add{type = "label", caption = {"gui.complaint-locator-empty"}}
    return
  end

  for index = 1, shown do
    local row = rows[index]
    local surface_name = row.surface and row.surface.name or "?"
    local x = row.position and math.floor(row.position.x) or "?"
    local y = row.position and math.floor(row.position.y) or "?"
    local location = row.surface and row.position
      and {"gui.complaint-locator-location", surface_name, x, y}
      or {"gui.complaint-locator-unlocated"}
    local button = results.add{
      type = "button",
      name = COMPLAINT_LOCATOR_RESULT_PREFIX .. tostring(index),
      caption = {
        "",
        "[item=", item_name, "] ×", row.count,
        "  ", row.source, "  ", location,
      },
      tooltip = {"gui.complaint-locator-result-tooltip"},
    }
    button.style.horizontally_stretchable = true
    button.style.horizontal_align = "left"
  end
end

local function open_complaint_locator(player)
  ensure_complaint_locator_gui(player)
end

local function focus_complaint(player, result_index)
  local row = complaint_locator_results_by_player[player.index]
    and complaint_locator_results_by_player[player.index][result_index]
  if not row then
    player.print({"message.complaint-locator-missing"})
    return
  end
  local surface = row.anchor and row.anchor.valid and row.anchor.surface or row.surface
  local position = row.anchor and row.anchor.valid and row.anchor.position or row.position
  if not surface or not position then
    player.print({"message.complaint-locator-no-position"})
    return
  end

  player.set_controller{
    type = defines.controllers.remote,
    position = position,
    surface = surface,
  }
  player.zoom = 1.5
  rendering.draw_circle{
    color = {r = 1, g = 0.2, b = 0.2, a = 1},
    radius = 4,
    width = 5,
    filled = false,
    target = position,
    surface = surface,
    players = {player},
    time_to_live = 600,
  }
  player.print({"message.complaint-locator-focused", surface.name, math.floor(position.x), math.floor(position.y)})
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
    local frame = player.gui.screen[RUNTIME_DEBUG_VIEW_NAME]
    if frame then frame.destroy() end
    local legacy_frame = player.gui.left[RUNTIME_DEBUG_VIEW_NAME]
    if legacy_frame then legacy_frame.destroy() end
    return
  end

  local frame = ensure_runtime_debug_gui(player)
  local content = frame[RUNTIME_DEBUG_CONTENT_NAME]
  local updated = content[RUNTIME_DEBUG_UPDATED_NAME]
  local summary_table = content[RUNTIME_DEBUG_SUMMARY_NAME]
  local registration_table = content[RUNTIME_DEBUG_REGISTRATION_NAME]
  local field_office_table = content[RUNTIME_DEBUG_FIELD_OFFICE_NAME]
  local counts_table = content[RUNTIME_DEBUG_COUNTS_NAME]

  if last_runtime_debug_snapshot then
    updated.caption = {"gui.debug-updated", last_runtime_debug_snapshot.tick, #runtime_debug_history}
  else
    updated.caption = {"gui.debug-waiting"}
  end

  update_runtime_metric_table(summary_table, RUNTIME_DEBUG_SUMMARY_ROWS)
  update_runtime_metric_table(registration_table, RUNTIME_DEBUG_REGISTRATION_ROWS)
  update_runtime_metric_table(field_office_table, RUNTIME_DEBUG_FIELD_OFFICE_ROWS)

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
  lines[#lines + 1] = "field_office_detail_subset"
  lines[#lines + 1] = "section\tlast_ms\tavg_ms\thigh_ms"

  for _, row in ipairs(RUNTIME_DEBUG_FIELD_OFFICE_ROWS) do
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

function M.run_profiled_external_sections(root_key, fn)
  if not M.has_active_viewers() then
    fn(nil)
    return
  end

  local sections = {}
  local profiler = game.create_profiler()
  fn(sections)
  profiler.stop()

  add_runtime_profiler_to_table(runtime_debug_external_sections, root_key, profiler)
  if not runtime_debug_external_total then
    runtime_debug_external_total = game.create_profiler(true)
  end
  runtime_debug_external_total.add(profiler)

  for key, section in pairs(sections) do
    add_runtime_profiler_to_table(runtime_debug_external_sections, key, section)
  end
end

function M.begin_snapshot(tick)
  if not M.has_active_viewers() then
    return nil, nil
  end

  local sections = runtime_debug_external_sections
  local external_total = runtime_debug_external_total
  runtime_debug_external_sections = {}
  runtime_debug_external_total = nil

  return {
    tick = tick,
    sections = sections,
    counts = {},
    external_total = external_total,
  }, game.create_profiler()
end

function M.complete_snapshot(snapshot, total_profiler)
  if not snapshot or not total_profiler then return end

  total_profiler.stop()
  if snapshot.external_total then
    total_profiler.add(snapshot.external_total)
    snapshot.external_total = nil
  end
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

function M.toggle_complaint_locator(player)
  if not player then return end
  local frame = player.gui.screen[COMPLAINT_LOCATOR_FRAME_NAME]
  if frame and frame.valid then
    release_complaint_locator_pause(player.index)
    frame.destroy()
  else
    open_complaint_locator(player)
  end
end

function M.close_complaint_locator(player_index)
  release_complaint_locator_pause(player_index)
  local player = game.get_player(player_index)
  local frame = player and player.gui.screen[COMPLAINT_LOCATOR_FRAME_NAME]
  if frame and frame.valid then frame.destroy() end
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

  if element_name == COMPLAINT_LOCATOR_OPEN_NAME then
    open_complaint_locator(player)
    return true
  end

  if element_name == COMPLAINT_LOCATOR_CLOSE_NAME then
    local frame = player.gui.screen[COMPLAINT_LOCATOR_FRAME_NAME]
    release_complaint_locator_pause(player.index)
    if frame then frame.destroy() end
    return true
  end

  if element_name == COMPLAINT_LOCATOR_REFRESH_NAME then
    refresh_complaint_locator(player)
    return true
  end

  local result_index = complaint_locator_result_index(element_name)
  if result_index then
    focus_complaint(player, result_index)
    return true
  end

  return false
end

function M.handle_gui_closed(element, player_index)
  if element and element.valid and element.name == COMPLAINT_LOCATOR_FRAME_NAME then
    release_complaint_locator_pause(player_index)
    element.destroy()
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


M._test = {
  complaint_locator_result_index = complaint_locator_result_index,
  scan_world_for_complaint_item = scan_world_for_complaint_item,
}

return M
