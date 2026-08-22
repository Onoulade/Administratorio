-- Buildings that idle without a biter dispatched from a biter-station.
--
-- Keep this module dependency-free: Factorio loads it in both the data stage
-- and the runtime, the same way prototypes/shared/pneumatic_items.lua is used.
-- scripts/constants.lua re-exports it so runtime code has one place to look.
--
-- Note: union-headquarters is intentionally absent. It consumes a biter as a
-- recipe ingredient, so it does not also need ongoing dispatch.

local M = {}

M.names = {
  "propaganda-distillery",
  "corporate-breakroom",
  "centrifuge",
  "oil-refinery",
  "printer-t2",
}

function M.as_set()
  local set = {}
  for _, name in ipairs(M.names) do
    set[name] = true
  end
  return set
end

return M
