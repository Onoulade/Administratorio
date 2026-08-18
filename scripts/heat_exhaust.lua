-- Heat Exhaust configuration.
--
-- A heat-interface defaults to maintaining a minimum temperature, which would
-- make this hidden-GUI building a heat source. Configure every instance as an
-- at-most interface instead so it is an actual heat sink.

local C = require("scripts.constants")

local M = {}

function M.is_heat_exhaust(entity)
  return entity ~= nil and entity.valid and entity.name == C.HEAT_EXHAUST_NAME
end

function M.configure(entity)
  if not M.is_heat_exhaust(entity) or not entity.set_heat_setting then return false end
  entity.set_heat_setting{
    mode = "at-most",
    temperature = C.AI_SERVER_AMBIENT_TEMPERATURE,
  }
  return true
end

function M.on_entity_built(entity)
  return M.configure(entity)
end

function M.rebuild_registry()
  -- Heat Exhaust is a Space Age (Aquilo) entity. find_entities_filtered
  -- errors on an unknown prototype name, so skip entirely without it.
  if prototypes and prototypes.entity and not prototypes.entity[C.HEAT_EXHAUST_NAME] then
    return
  end
  for _, surface in pairs(game.surfaces or {}) do
    if surface.valid and surface.find_entities_filtered then
      for _, entity in ipairs(surface.find_entities_filtered{name = C.HEAT_EXHAUST_NAME}) do
        M.configure(entity)
      end
    end
  end
end

return M
