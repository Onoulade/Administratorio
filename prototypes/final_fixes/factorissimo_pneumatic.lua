-- ADMINISTRATORIO: FACTORISSIMO PNEUMATIC COMPATIBILITY
--
-- Factorissimo carries fluids through a factory wall with a pair of hidden
-- pumps linked across surfaces.  Those pumps only accept the "default" pipe
-- connection category, so a pneumatic tube -- which lives in the isolated
-- "pneumatic-forms" category -- stops dead at the wall while a water pipe walks
-- straight through.
--
-- Giving the pumps both categories is the whole patch: Factorissimo already
-- recognises pneumatic pipes as a fluid connection (they are prototype type
-- "pipe"), builds the linked pump pair for them, and the tube network BFS in
-- scripts/pneumatic.lua walks that linked pair into the inside surface.
--
-- The pumps now accept a plain fluid pipe on one side and a tube on the other.
-- Nothing flows across such a mismatch -- tubes never carry fluid -- and the
-- BFS whitelist in scripts/pneumatic.lua refuses to walk out of the pump into a
-- foreign fluid network.

local M = {}

-- A pipeline's extent is the min extent of every fluidbox in it, measured in
-- raw coordinates with no regard for which surface each one sits on.  A tube
-- crossing a factory wall continues on the factory floor surface, thousands of
-- tiles away on the virtual map, so both the tubes' own 120-tile bound and the
-- pumps' 320-tile default report "pipeline overextended" the moment two
-- factories are wired together.  Hand the bound to scripts/pneumatic.lua, which
-- measures the network radius on the surface the network starts from and
-- ignores factory interiors entirely.
local UNBOUNDED_PIPELINE_EXTENT = 1000000

local PNEUMATIC_TUBES = {
  ["pipe"] = {"pneumatic-pipe", "pneumatic-hidden-network-pipe"},
  ["pipe-to-ground"] = {"pneumatic-pipe-to-ground"},
}

local FACTORY_PUMPS = {
  "factory-inside-pump-input",
  "factory-inside-pump-output",
  "factory-outside-pump-input",
  "factory-outside-pump-output",
}

function M.apply(data)
  local pumps = data.raw.pump
  if not (pumps and pumps["factory-inside-pump-input"]) then return end -- no Factorissimo

  for _, name in ipairs(FACTORY_PUMPS) do
    local fluid_box = pumps[name] and pumps[name].fluid_box
    if fluid_box then
      fluid_box.max_pipeline_extent = UNBOUNDED_PIPELINE_EXTENT
      for _, connection in pairs(fluid_box.pipe_connections or {}) do
        -- The linked connection is the surface-to-surface hop between the two
        -- pumps; only the outward-facing one meets player-built pipes.
        if connection.connection_type ~= "linked" then
          connection.connection_category = {"default", "pneumatic-forms"}
        end
      end
    end
  end

  for prototype_type, names in pairs(PNEUMATIC_TUBES) do
    for _, name in ipairs(names) do
      local tube = data.raw[prototype_type] and data.raw[prototype_type][name]
      if tube and tube.fluid_box then
        tube.fluid_box.max_pipeline_extent = UNBOUNDED_PIPELINE_EXTENT
      end
    end
  end
end

return M
