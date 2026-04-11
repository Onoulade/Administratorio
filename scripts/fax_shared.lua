local M = {}

M.RECEIVER_NAME = "interplanetary-fax-exchange"
M.EMITTER_NAME = "fax-emitter"
M.COMBINATOR_NAME = "fax-network-combinator"

M.GUI_FRAME_NAME = "administratorio-fax-emitter"
M.GUI_DROPDOWN_NAME = "administratorio-fax-destination"

M.TRANSMIT_TICKS = 60
M.PRINT_TICKS = 120

M.BASE_QUEUE_CAPACITY = 5
M.QUEUE_TECH_BONUSES = {
  ["fax-queue-capacity-1"] = 5,
  ["fax-queue-capacity-2"] = 5,
  ["fax-queue-capacity-3"] = 5,
}

M.SIGNAL_QUEUE_SIZE = "signal-fax-queue-size"
M.SIGNAL_FREE_SLOTS = "signal-fax-free-slots"
M.SIGNAL_RESERVED_SLOTS = "signal-fax-reserved-slots"

M.PLANET_ORDER = {
  "nauvis",
  "vulcanus",
  "gleba",
  "fulgora",
  "aquilo",
}

M.FAXABLE_PAPERWORK = {
  ["blank-form"] = true,
  ["blank-approval"] = true,
  ["blank-directive"] = true,
  ["carbon-offset-certificate-basic"] = true,
  ["provisional-approval"] = true,
  ["safety-waiver-draft"] = true,
  ["safety-waiver"] = true,
  ["construction-permit-draft"] = true,
  ["construction-permit"] = true,
  ["management-verbal-draft"] = true,
  ["management-approval-verbal"] = true,
  ["management-written-proposal"] = true,
  ["management-approval-written"] = true,
  ["transit-authorization"] = true,
  ["research-grant-approval"] = true,
  ["petrochemical-operating-permit"] = true,
  ["work-order"] = true,
  ["form-27b-6"] = true,
  ["safety-work-order"] = true,
  ["construction-work-order"] = true,
  ["management-verbal-work-order"] = true,
  ["management-written-work-order"] = true,
  ["research-grant-work-order"] = true,
  ["chemical-handling-work-order"] = true,
  ["radiological-work-order"] = true,
  ["carbon-offset-certificate-verified"] = true,
  ["environmental-impact-report"] = true,
  ["white-paper"] = true,
  ["ticket-landscape"] = true,
  ["filing-l"] = true,
  ["resolved-landscape"] = true,
  ["ticket-smog"] = true,
  ["filing-s"] = true,
  ["case-s"] = true,
  ["resolved-smog"] = true,
  ["ticket-noise"] = true,
  ["filing-n"] = true,
  ["case-n"] = true,
  ["brief-n"] = true,
  ["resolved-noise"] = true,
  ["ticket-unemployment"] = true,
  ["filing-u"] = true,
  ["case-u"] = true,
  ["brief-u"] = true,
  ["resolved-unemployment"] = true,
  ["osha-violation"] = true,
  ["ticket-littering"] = true,
  ["filing-lt"] = true,
  ["resolved-littering"] = true,
  ["ticket-hazmat"] = true,
  ["filing-h"] = true,
  ["case-h"] = true,
  ["resolved-hazmat"] = true,
  ["ticket-loitering"] = true,
  ["filing-lo"] = true,
  ["case-lo"] = true,
  ["brief-lo"] = true,
  ["resolved-loitering"] = true,
  ["ticket-vagrancy"] = true,
  ["filing-v"] = true,
  ["case-v"] = true,
  ["brief-v"] = true,
  ["resolved-vagrancy"] = true,
}

local PLANET_ORDER_INDEX = {}
for index, name in ipairs(M.PLANET_ORDER) do
  PLANET_ORDER_INDEX[name] = index
end

function M.make_signal_key(signal_id)
  if not signal_id then return nil end
  local signal_type = signal_id.type or "item"
  local quality = signal_id.quality or ""
  return table.concat({signal_type, signal_id.name or "", quality}, "/")
end

function M.is_faxable_signal(signal_id)
  return signal_id
    and signal_id.type == "item"
    and signal_id.name ~= nil
    and M.FAXABLE_PAPERWORK[signal_id.name] == true
end

function M.is_faxable_item_name(item_name)
  return item_name ~= nil and M.FAXABLE_PAPERWORK[item_name] == true
end

function M.get_queue_capacity(force)
  local capacity = M.BASE_QUEUE_CAPACITY
  if not force or not force.valid or not force.technologies then
    return capacity
  end

  for technology_name, bonus in pairs(M.QUEUE_TECH_BONUSES) do
    local technology = force.technologies[technology_name]
    if technology and technology.researched then
      capacity = capacity + bonus
    end
  end

  return capacity
end

function M.get_planet_name(surface)
  if not surface or not surface.valid then return nil end
  if surface.platform ~= nil then return nil end

  local planet = surface.planet
  if not planet or not planet.valid then return nil end
  if planet.surface and planet.surface ~= surface then return nil end

  return planet.name
end

function M.format_planet_name(planet_name)
  if not planet_name or planet_name == "" then return "Unknown" end
  return planet_name:gsub("^%l", string.upper)
end

function M.collect_planet_names(game)
  local seen = {}
  local names = {}

  for _, surface in pairs(game and game.surfaces or {}) do
    local planet_name = M.get_planet_name(surface)
    if planet_name and not seen[planet_name] then
      seen[planet_name] = true
      names[#names + 1] = planet_name
    end
  end

  table.sort(names, function(left, right)
    local left_order = PLANET_ORDER_INDEX[left] or math.huge
    local right_order = PLANET_ORDER_INDEX[right] or math.huge
    if left_order ~= right_order then
      return left_order < right_order
    end
    return left < right
  end)

  return names
end

function M.select_request_signal(signals, excluded_counts)
  local best_signal = nil
  local best_count = 0

  for _, entry in ipairs(signals or {}) do
    local signal_id = entry.signal
    if M.is_faxable_signal(signal_id) then
      local key = M.make_signal_key(signal_id)
      local count = (entry.count or 0) - ((excluded_counts and excluded_counts[key]) or 0)
      if count > 0 then
        if not best_signal
          or count > best_count
          or (count == best_count and key < M.make_signal_key(best_signal))
        then
          best_signal = {
            type = signal_id.type,
            name = signal_id.name,
            quality = signal_id.quality,
          }
          best_count = count
        end
      end
    end
  end

  return best_signal, best_count
end

return M
