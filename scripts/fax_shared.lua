local quality = require("scripts.quality")
local M = {}

M.RECEIVER_NAME = "interplanetary-fax-exchange"
M.EMITTER_NAME = "fax-emitter"
M.COMBINATOR_NAME = "fax-network-combinator"

M.GUI_FRAME_NAME = "administratorio-fax-panel"
M.GUI_DROPDOWN_NAME = "administratorio-fax-destination"
M.GUI_STATUS_NAME = "administratorio-fax-status"
M.GUI_QUEUE_NAME = "administratorio-fax-queue"
M.GUI_REQUESTS_NAME = "administratorio-fax-requests"
M.GUI_SUPPLIES_NAME = "administratorio-fax-supplies"
M.RECEIVER_GUI_FRAME_NAME = "administratorio-fax-receiver-window"
M.RECEIVER_GUI_CLOSE_NAME = "administratorio-fax-receiver-close"
M.RECEIVER_GUI_HEADER_NAME = "administratorio-fax-receiver-header"
M.RECEIVER_GUI_STATUS_BODY_NAME = "administratorio-fax-receiver-status-body"
M.RECEIVER_GUI_QUEUE_CONTENT_NAME = "administratorio-fax-receiver-queue-content"
M.RECEIVER_GUI_REQUESTS_CONTENT_NAME = "administratorio-fax-receiver-requests-content"
M.RECEIVER_GUI_SUPPLIES_CONTENT_NAME = "administratorio-fax-receiver-supplies-content"
M.RECEIVER_GUI_ACCEPT_BUTTON_NAME = "administratorio-fax-receiver-accept-requests"
M.RECEIVER_GUI_QUEUE_BUTTON_NAME = "administratorio-fax-receiver-read-queue"
M.RECEIVER_GUI_TOP_REQUEST_BUTTON_NAME = "administratorio-fax-receiver-read-top-request"
M.RECEIVER_GUI_QUEUE_SIGNAL_NAME = "administratorio-fax-receiver-queue-signal"
M.RECEIVER_GUI_FREE_SIGNAL_NAME = "administratorio-fax-receiver-free-signal"
M.RECEIVER_GUI_RESERVED_SIGNAL_NAME = "administratorio-fax-receiver-reserved-signal"

M.TRANSMIT_TICKS = 60
M.PRINT_TICKS = 120

M.BASE_FAX_TECH = "aquilo-fax-network"
M.COLOR_FAX_TECH = "color-faxing"
M.RECONSTRUCTION_RECIPE_PREFIX = "faxed-document-reconstruction-"
M.RECONSTRUCTION_PAPER_ITEM = "thermal-transfer-sheet"
M.RECONSTRUCTION_RIBBON_ITEM = "composite-chroma-ribbon"
M.INK_DEFINITIONS = {
  black = {
    id = "black",
    name = "liquid-black-ink",
    amount = 5,
    label = "Black",
  },
  cyan = {
    id = "cyan",
    name = "cyan-ink",
    amount = 5,
    label = "Cyan",
  },
  yellow = {
    id = "yellow",
    name = "yellow-ink",
    amount = 5,
    label = "Yellow",
  },
  magenta = {
    id = "magenta",
    name = "magenta-ink",
    amount = 5,
    label = "Magenta",
  },
}
M.RECONSTRUCTION_INK_FLUIDS = {
  M.INK_DEFINITIONS.black,
  M.INK_DEFINITIONS.cyan,
  M.INK_DEFINITIONS.yellow,
  M.INK_DEFINITIONS.magenta,
}

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

local function copy_array(values)
  local out = {}
  for index, value in ipairs(values or {}) do
    out[index] = value
  end
  return out
end

local function document_definition(ink_ids)
  return {
    ink_ids = copy_array(ink_ids),
    requires_color = not (#ink_ids == 1 and ink_ids[1] == "black"),
  }
end

local function add_documents(target, names, ink_ids)
  for _, item_name in ipairs(names) do
    target[item_name] = document_definition(ink_ids)
  end
end

local black_only_documents = {
  "blank-form",
  "blank-approval",
  "blank-directive",
  "carbon-offset-certificate-basic",
  "provisional-approval",
  "safety-waiver-draft",
  "safety-waiver",
  "construction-permit-draft",
  "construction-permit",
  "management-verbal-draft",
  "management-approval-verbal",
  "management-written-proposal",
  "management-approval-written",
  "transit-authorization",
  "orbital-infrastructure-permit",
  "research-grant-approval",
  "work-order",
  "form-27b-6",
  "safety-work-order",
  "construction-work-order",
  "management-verbal-work-order",
  "management-written-work-order",
  "research-grant-work-order",
  "chemical-handling-work-order",
  "radiological-work-order",
  "carbon-offset-certificate-verified",
  "environmental-impact-report",
  "white-paper",
  "ticket-landscape",
  "filing-l",
  "resolved-landscape",
  "ticket-smog",
  "filing-s",
  "case-s",
  "resolved-smog",
  "ticket-noise",
  "filing-n",
  "case-n",
  "brief-n",
  "resolved-noise",
  "ticket-unemployment",
  "filing-u",
  "case-u",
  "brief-u",
  "resolved-unemployment",
  "osha-violation",
  "ticket-littering",
  "filing-lt",
  "resolved-littering",
  "ticket-hazmat",
  "filing-h",
  "case-h",
  "resolved-hazmat",
  "ticket-loitering",
  "filing-lo",
  "case-lo",
  "brief-lo",
  "resolved-loitering",
  "ticket-vagrancy",
  "filing-v",
  "case-v",
  "brief-v",
  "resolved-vagrancy",
}

M.FAX_DOCUMENTS = {}
add_documents(M.FAX_DOCUMENTS, black_only_documents, {"black"})
add_documents(M.FAX_DOCUMENTS, {"blank-cyan-form"}, {"cyan"})
add_documents(M.FAX_DOCUMENTS, {"blank-yellow-form"}, {"yellow"})
add_documents(M.FAX_DOCUMENTS, {"blank-magenta-form"}, {"magenta"})
add_documents(M.FAX_DOCUMENTS, {"cyan-yellow-form", "cryogenic-operations-license"}, {"cyan", "yellow"})
add_documents(M.FAX_DOCUMENTS, {"cyan-magenta-form", "hardened-data-vault"}, {"cyan", "magenta"})
add_documents(M.FAX_DOCUMENTS, {"yellow-magenta-form"}, {"yellow", "magenta"})
add_documents(M.FAX_DOCUMENTS, {"trichromatic-permit", "unified-operations-charter", "promethium-research-charter"}, {"cyan", "yellow", "magenta"})

M.FAXABLE_PAPERWORK = {}
for item_name in pairs(M.FAX_DOCUMENTS) do
  M.FAXABLE_PAPERWORK[item_name] = true
end

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
    and M.FAX_DOCUMENTS[signal_id.name] ~= nil
end

function M.is_faxable_item_name(item_name)
  return item_name ~= nil and M.FAX_DOCUMENTS[item_name] ~= nil
end

function M.get_document_definition(item_name)
  return item_name and M.FAX_DOCUMENTS[item_name] or nil
end

function M.document_requires_color(item_name)
  local definition = M.get_document_definition(item_name)
  return definition and definition.requires_color or false
end

function M.get_document_ink_ids(item_name)
  local definition = M.get_document_definition(item_name)
  return copy_array(definition and definition.ink_ids or {})
end

function M.get_document_ink_requirements(item_name)
  local requirements = {}
  for _, ink_id in ipairs(M.get_document_ink_ids(item_name)) do
    local ink = M.INK_DEFINITIONS[ink_id]
    if ink then
      requirements[#requirements + 1] = {
        id = ink.id,
        name = ink.name,
        amount = ink.amount,
        label = ink.label,
      }
    end
  end
  return requirements
end

function M.get_reconstruction_requirements(item_name)
  local definition = M.get_document_definition(item_name)
  if not definition then return nil end
  local color_count = 0
  for _, ink_id in ipairs(definition.ink_ids or {}) do
    if ink_id ~= "black" then color_count = color_count + 1 end
  end
  if color_count == 0 then
    return {sheets = 2, ribbon = 0}
  elseif color_count == 1 then
    return {sheets = 2, ribbon = 1}
  elseif color_count == 2 then
    return {sheets = 3, ribbon = 1}
  end
  return {sheets = 4, ribbon = 2}
end

function M.format_reconstruction_media(item_name)
  local requirements = M.get_reconstruction_requirements(item_name)
  if not requirements then return {"gui.fax-none"} end
  return {"gui.fax-reconstruction-media", requirements.sheets, requirements.ribbon}
end

function M.format_required_inks(item_name)
  local labels = {}
  for _, fluid in ipairs(M.get_document_ink_requirements(item_name)) do
    labels[#labels + 1] = fluid.label
  end
  if #labels == 0 then
    return "None"
  end
  return table.concat(labels, " + ")
end

function M.reconstruction_unlock_technology(item_name)
  if M.document_requires_color(item_name) then
    return M.COLOR_FAX_TECH
  end
  return M.BASE_FAX_TECH
end

function M.is_color_faxing_unlocked(force)
  if not force or not force.valid or not force.technologies then
    return false
  end
  local technology = force.technologies[M.COLOR_FAX_TECH]
  return technology and technology.researched or false
end

function M.can_force_fax_document(force, item_name)
  if not M.is_faxable_item_name(item_name) then
    return false
  end
  if not M.document_requires_color(item_name) then
    return true
  end
  return M.is_color_faxing_unlocked(force)
end

function M.get_queue_capacity(force, receiver)
  local capacity = M.BASE_QUEUE_CAPACITY + quality.level(receiver)
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

function M.get_transmit_ticks(emitter)
  return quality.scaled_ticks(M.TRANSMIT_TICKS, emitter)
end

function M.get_print_ticks(receiver)
  return quality.scaled_ticks(M.PRINT_TICKS, receiver)
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

function M.reconstruction_recipe_name(item_name)
  if not item_name then return nil end
  return M.RECONSTRUCTION_RECIPE_PREFIX .. item_name
end

function M.collect_request_signals(signals, excluded_counts, limit)
  local requests = {}

  for _, entry in ipairs(signals or {}) do
    local signal_id = entry.signal
    if M.is_faxable_signal(signal_id) then
      local key = M.make_signal_key(signal_id)
      local count = (entry.count or 0) - ((excluded_counts and excluded_counts[key]) or 0)
      if count > 0 then
        requests[#requests + 1] = {
          signal = {
            type = signal_id.type,
            name = signal_id.name,
            quality = signal_id.quality,
          },
          count = count,
          key = key,
        }
      end
    end
  end

  table.sort(requests, function(left, right)
    if left.count ~= right.count then
      return left.count > right.count
    end
    return left.key < right.key
  end)

  if limit and #requests > limit then
    for index = #requests, limit + 1, -1 do
      requests[index] = nil
    end
  end

  return requests
end

function M.select_request_signal(signals, excluded_counts)
  local requests = M.collect_request_signals(signals, excluded_counts, 1)
  local best = requests[1]
  return best and best.signal or nil, best and best.count or 0
end

return M
