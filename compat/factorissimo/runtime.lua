-- ADMINISTRATORIO: FACTORISSIMO RUNTIME COMPATIBILITY
--
-- Control-stage half of the Factorissimo compatibility, loaded from
-- compat/init.lua.  The data-stage half -- the pneumatic tube patch for the
-- wall pumps -- sits next door in data.lua; the two never share a Lua state,
-- hence the two files.

local hooks = require("compat.hooks")

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
