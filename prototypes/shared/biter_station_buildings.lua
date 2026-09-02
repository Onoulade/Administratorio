-- Buildings that idle without a biter dispatched from a biter-station.
--
-- Keep the underlying gameplay_facts module free of Factorio globals: this
-- compatibility wrapper is loaded in both the data stage and the runtime.
-- scripts/constants.lua re-exports it so runtime code has one place to look.
--
-- Note: union-headquarters is intentionally absent. It consumes a biter as a
-- recipe ingredient, so it does not also need ongoing dispatch.

local gameplay_facts = require("prototypes.shared.gameplay_facts")
local M = {}

M.names = gameplay_facts.biter_station.managed_buildings

function M.as_set()
  return gameplay_facts.as_set(M.names)
end

return M
