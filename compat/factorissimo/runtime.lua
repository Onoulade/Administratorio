-- ADMINISTRATORIO: FACTORISSIMO RUNTIME COMPATIBILITY
--
-- Control-stage half of the Factorissimo compatibility, loaded from
-- compat/init.lua.  The data-stage half -- the pneumatic tube patch for the
-- wall pumps -- sits next door in data.lua; the two never share a Lua state,
-- hence the two files.

local hooks = require("compat.hooks")

local M = {}

local INTERFACE = "factorissimo"
local LIGHTS_TECH = "factory-interior-upgrade-lights"
-- Factorissimo 2 releases predate these; without them we behave as if the mod
-- were absent rather than crash inside remote.call.
local REQUIRED_METHODS = {
  "is_factorissimo_surface",
  "find_surrounding_factory_by_surface_index",
}
-- ponytail: nesting cap, a factory nested deeper keeps the inner answer
local MAX_NESTING = 8

function M.available()
  local interface = remote and remote.interfaces and remote.interfaces[INTERFACE]
  if not interface then return false end
  for _, method in ipairs(REQUIRED_METHODS) do
    if not interface[method] then return false end
  end
  return true
end

--- Walks out of a factory to the surface that carries the real time of day.
--- Factorissimo freezes the daytime of a factory floor (noon with the interior
--- lights upgrade, midnight without), so a building inside never sees the day
--- and night of the planet its factory stands on.
---
--- Returns the outermost surface plus an "unlit" flag: a factory without the
--- interior lights upgrade is genuinely dark, and the caller should treat it as
--- night whatever the surface says. Surfaces outside a factory come back
--- unchanged, so callers need no Factorissimo check of their own.
function M.resolve_outside_surface(surface, position)
  if not (surface and surface.valid) then return surface, false end
  if not position or not M.available() then return surface, false end

  for _ = 1, MAX_NESTING do
    if not remote.call(INTERFACE, "is_factorissimo_surface", surface.index) then break end
    local factory = remote.call(INTERFACE, "find_surrounding_factory_by_surface_index", surface.index, position)
    if not factory then break end

    local force = factory.force
    local lights = force and force.valid and force.technologies[LIGHTS_TECH]
    if not (lights and lights.researched) then return surface, true end

    local outside = factory.outside_surface
    if not (outside and outside.valid) then break end
    surface = outside
    position = {x = factory.outside_x, y = factory.outside_y}
  end

  return surface, false
end

-- Returning nil means "not my case": the core keeps its own answer and the next
-- handler, if any, gets a turn.
hooks.register("time_of_day_surface", function(surface, position)
  if not M.available() then return nil end
  local outside, unlit = M.resolve_outside_surface(surface, position)
  if outside == surface and not unlit then return nil end
  return outside, unlit
end)

-- The wall pumps accept our connection category because of data.lua, so the
-- tube network has to be told they are safe to walk through.  Not gated on the
-- mod being present: an entry for an entity that does not exist is inert, and
-- remote interfaces are not up yet at load time anyway.
hooks.register("tube_traversable_entities", function()
  return {
    ["factory-inside-pump-input"] = true,
    ["factory-inside-pump-output"] = true,
    ["factory-outside-pump-input"] = true,
    ["factory-outside-pump-output"] = true,
  }
end)

return M
