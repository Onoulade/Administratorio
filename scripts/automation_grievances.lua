-- The automation grievance thread.
--
-- This is data, not a new system. It adds one complaint family to the pipeline
-- that already exists -- Administration Desk queue, Resolution Office chain,
-- frustration, protest retargeting, Taxpayer Money payout -- and feeds it from
-- the four things the automation pass introduced.
--
-- The result is the thesis of the whole expansion: the more of the biter
-- economy is automated away, the more biter grievances are generated, and
-- grievances can only be processed by the biter economy. The endgame does not
-- escape the mod; it is consumed by it.
--
-- Four feeders:
--   * AI Servers running
--   * Unstaffed Operations Waivers installed
--   * Synthetic personnel manufactured
--   * Fabricated Citations left unhandled

local C = require("scripts.constants")

local M = {}

M.TICKET = "ticket-automation"

-------------------------------------------------------------------------------
-- STORAGE
-------------------------------------------------------------------------------

function M.ensure_storage()
  storage.automation_pressure = storage.automation_pressure or {}
  storage.automation_pending = storage.automation_pending or {}
  storage.automation_personnel_seen = storage.automation_personnel_seen or {}
end

local function add_pressure(force_index, amount)
  if not force_index or amount <= 0 then return end
  local pressure = storage.automation_pressure
  pressure[force_index] = (pressure[force_index] or 0) + amount

  while pressure[force_index] >= C.AUTOMATION_GRIEVANCE_THRESHOLD do
    pressure[force_index] = pressure[force_index] - C.AUTOMATION_GRIEVANCE_THRESHOLD
    storage.automation_pending[force_index] = (storage.automation_pending[force_index] or 0) + 1
  end

  -- A backlog nobody can serve is just a memory leak. Cap it.
  local pending = storage.automation_pending[force_index] or 0
  if pending > C.AUTOMATION_GRIEVANCE_MAX_PENDING then
    storage.automation_pending[force_index] = C.AUTOMATION_GRIEVANCE_MAX_PENDING
  end
end

-------------------------------------------------------------------------------
-- CONSUMPTION
-------------------------------------------------------------------------------

--- Called when a biter files at a desk. A pending automation grievance rides
--- along with whatever the biter came to complain about, which is what puts it
--- through the untouched existing pipeline.
function M.consume_pending(force)
  if not force or not force.valid then return false end
  M.ensure_storage()

  local force_index = force.index
  local pending = storage.automation_pending[force_index] or 0
  if pending <= 0 then return false end

  storage.automation_pending[force_index] = pending - 1
  return true
end

function M.pending_count(force_index)
  M.ensure_storage()
  return storage.automation_pending[force_index] or 0
end

-------------------------------------------------------------------------------
-- FEEDERS
-------------------------------------------------------------------------------

local function feed_ai_servers()
  for _, entry in pairs(storage.ai_servers or {}) do
    local entity = entry.entity
    if entity and entity.valid and entity.status == defines.entity_status.working then
      add_pressure(entity.force.index, C.AUTOMATION_PRESSURE_PER_AI_SERVER)
    end
  end
end

local function feed_waivers()
  for _, entity in pairs(storage.managed_building_registry or {}) do
    if entity and entity.valid and entity.get_module_inventory then
      local inventory = entity.get_module_inventory()
      if inventory and inventory.valid then
        local installed = inventory.get_item_count("unstaffed-operations-waiver")
        if installed > 0 then
          add_pressure(entity.force.index, C.AUTOMATION_PRESSURE_PER_WAIVER * installed)
        end
      end
    end
  end
end

--- Synthesised personnel are counted from the Bureau's finished-product tally,
--- so one grievance is filed per person manufactured rather than per tick spent
--- manufacturing.
local function feed_synthetic_personnel()
  local seen = storage.automation_personnel_seen
  for _, surface in pairs(game.surfaces) do
    for _, entity in ipairs(surface.find_entities_filtered{name = C.SYNTHETIC_PERSONNEL_BUREAU_NAME}) do
      if entity.valid and entity.unit_number then
        local finished = entity.products_finished or 0
        local previous = seen[entity.unit_number] or 0
        if finished > previous then
          add_pressure(entity.force.index,
            C.AUTOMATION_PRESSURE_PER_SYNTHETIC_PERSON * (finished - previous))
        end
        seen[entity.unit_number] = finished
      end
    end
  end
end

--- Citations left sitting in a server's output are the "ignore" branch of
--- hallucination handling. Ignoring them stalls the server and annoys the union.
local function feed_unhandled_citations()
  for _, entry in pairs(storage.ai_servers or {}) do
    local entity = entry.entity
    if entity and entity.valid then
      local output = entity.get_output_inventory()
      if output and output.valid then
        local citations = output.get_item_count("fabricated-citations")
        if citations >= C.AUTOMATION_CITATION_BACKLOG then
          add_pressure(entity.force.index, C.AUTOMATION_PRESSURE_PER_CITATION_BACKLOG)
        end
      end
    end
  end
end

-------------------------------------------------------------------------------
-- TICK
-------------------------------------------------------------------------------

function M.on_tick(_event)
  M.ensure_storage()

  feed_ai_servers()
  feed_waivers()
  feed_synthetic_personnel()
  feed_unhandled_citations()
end

function M.rebuild_registry()
  M.ensure_storage()
  -- Re-baseline synthesised-personnel counters so a reload does not file a
  -- grievance for every person ever manufactured.
  storage.automation_personnel_seen = {}
  for _, surface in pairs(game.surfaces) do
    for _, entity in ipairs(surface.find_entities_filtered{name = C.SYNTHETIC_PERSONNEL_BUREAU_NAME}) do
      if entity.valid and entity.unit_number then
        storage.automation_personnel_seen[entity.unit_number] = entity.products_finished or 0
      end
    end
  end
end

return M
