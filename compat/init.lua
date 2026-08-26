-- ADMINISTRATORIO: COMPATIBILITY LOADER
--
-- Factorio cannot enumerate a directory, so every compat module is named here.
-- This list only says which files exist and in which stage they run; each
-- module gates itself on its own mod being present.
--
-- Adding compatibility with another mod means adding a directory under compat/
-- and one line below.  Core modules stay untouched as long as the new module
-- fits an existing hook point in compat/hooks.lua.

local COMPAT = {
  {mod = "factorissimo", stages = {data = true, runtime = true}},
}

local M = {}

--- stage is "data" (called from data-final-fixes) or "runtime" (from control).
--- Must run before any module that reads a hook point.
function M.load(stage)
  for _, entry in ipairs(COMPAT) do
    if entry.stages[stage] then
      require("compat." .. entry.mod .. "." .. stage)
    end
  end
end

return M
