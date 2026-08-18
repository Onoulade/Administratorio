-- AI Server heat: drives a hidden reactor child from the visible machine's
-- crafting state.
--
-- The engine will not let one entity both craft a recipe and emit heat:
-- assembling-machine has no heat output, reactor has no crafting. So the
-- visible AI Server is an assembling-machine and a hidden ai-server-heat-core
-- reactor sits at the same position carrying the heat connections. This script
-- is the only thing joining them.
--
-- Hidden children have precedent here: the Biterport's hidden roboport and the
-- pneumatic network pipe both work this way.

local C = require("scripts.constants")

local M = {}

-------------------------------------------------------------------------------
-- HELPERS
-------------------------------------------------------------------------------

function M.is_ai_server(entity)
  return entity ~= nil and entity.valid and entity.name == C.AI_SERVER_NAME
end

local function set_status(entity, key, diode)
  if not M.is_ai_server(entity) then return end
  entity.custom_status = {
    diode = diode,
    label = {"gui.ai-server-" .. key},
  }
end

local function find_heat_core(entity)
  local cores = entity.surface.find_entities_filtered{
    name = C.AI_SERVER_HEAT_CORE_NAME,
    position = entity.position,
    radius = 0.5,
  }
  return cores[1]
end

local function ensure_heat_core(entity)
  local core = find_heat_core(entity)
  if core and core.valid then
    core.destructible = false
    return core
  end

  core = entity.surface.create_entity{
    name = C.AI_SERVER_HEAT_CORE_NAME,
    position = entity.position,
    force = entity.force,
  }
  if core then
    core.destructible = false
    -- Only a genuinely new child starts at ambient. Registry rebuilds must
    -- preserve stored heat so a settings change cannot become a free reset.
    core.temperature = C.AI_SERVER_AMBIENT_TEMPERATURE
  end
  return core
end

local function track_entity(entity)
  M.ensure_storage()
  local core = ensure_heat_core(entity)
  storage.ai_servers[entity.unit_number] = {entity = entity, core = core}
  set_status(entity, "idle", defines.entity_status_diode.yellow)
  return core
end

-------------------------------------------------------------------------------
-- LIFECYCLE
-------------------------------------------------------------------------------

function M.ensure_storage()
  storage.ai_servers = storage.ai_servers or {}
end

function M.on_entity_built(entity)
  if not M.is_ai_server(entity) then return end
  track_entity(entity)
end

function M.on_entity_removed(entity)
  if not M.is_ai_server(entity) then return end
  M.ensure_storage()

  local core = find_heat_core(entity)
  if core and core.valid then core.destroy() end
  storage.ai_servers[entity.unit_number] = nil
end

-------------------------------------------------------------------------------
-- HEAT
-------------------------------------------------------------------------------

--- A server that cannot dump its heat stops. Not a throttle -- a hard stop.
--- The player either builds real heat infrastructure or accepts a dead server.
function M.on_tick(_event)
  M.ensure_storage()

  for unit_number, entry in pairs(storage.ai_servers) do
    local entity = entry.entity
    if not entity or not entity.valid then
      storage.ai_servers[unit_number] = nil
      goto next_server
    end

    local core = entry.core
    if not core or not core.valid then
      core = find_heat_core(entity)
      entry.core = core
    end
    if not core or not core.valid then goto next_server end

    if core.temperature >= C.AI_SERVER_STALL_TEMPERATURE then
      -- Held inactive until the heat network draws the core back down.
      entity.active = false
      set_status(entity, "overheated", defines.entity_status_diode.red)
    else
      if not entity.active then
        entity.active = true
      end

      if entity.status == defines.entity_status.working then
        local next_temperature = math.min(
          core.temperature + C.AI_SERVER_HEAT_PER_TICK * C.AI_SERVER_CHECK_TICKS,
          C.AI_SERVER_MAX_TEMPERATURE
        )
        core.temperature = next_temperature
        set_status(entity, "computing", defines.entity_status_diode.green)
      else
        set_status(entity, "idle", defines.entity_status_diode.yellow)
      end
    end

    ::next_server::
  end
end

-------------------------------------------------------------------------------
-- REBUILD
-------------------------------------------------------------------------------

function M.rebuild_registry()
  M.ensure_storage()
  storage.ai_servers = {}

  -- The AI Server is a Space Age (Aquilo) entity. find_entities_filtered
  -- errors on an unknown prototype name, so skip entirely without it.
  if prototypes and prototypes.entity and not prototypes.entity[C.AI_SERVER_NAME] then
    return
  end

  for _, surface in pairs(game.surfaces) do
    for _, entity in ipairs(surface.find_entities_filtered{name = C.AI_SERVER_NAME}) do
      if entity.valid then
        track_entity(entity)
      end
    end
  end

  -- Sweep heat cores whose server is gone; they would otherwise keep feeding a
  -- heat network from a building that no longer exists.
  for _, surface in pairs(game.surfaces) do
    for _, core in ipairs(surface.find_entities_filtered{name = C.AI_SERVER_HEAT_CORE_NAME}) do
      local owners = surface.find_entities_filtered{
        name = C.AI_SERVER_NAME,
        position = core.position,
        radius = 0.5,
      }
      if not owners[1] then core.destroy() end
    end
  end
end

return M
