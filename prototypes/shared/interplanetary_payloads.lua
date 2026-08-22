-- Interplanetary trunk payloads shared by the data stage and runtime.
-- Keep this module dependency-free: Factorio loads it in both contexts.
--
-- The base tier carries exactly the local pneumatic payload set: ~80 black-ink
-- forms, tickets, filings, cases, briefs, paper, ink, and taxpayer money.  The
-- chromatic tier adds the colored set on Aquilo.  Nothing else ever crosses the
-- trunk: rockets keep every other cargo.

local pneumatic_items = require("prototypes.shared.pneumatic_items")

local M = {}

-- Regular black-ink paperwork. Identical to the local tube payload by design;
-- a second taxonomy would drift from the first one the moment either changed.
M.regular = pneumatic_items.names

M.chromatic = {
  "blank-cyan-form", "blank-yellow-form", "blank-magenta-form",
  "cyan-yellow-form", "cyan-magenta-form", "yellow-magenta-form",
  "cryogenic-operations-license", "hardened-data-vault",
  "trichromatic-permit", "unified-operations-charter",
  "promethium-research-charter",
}

function M.all()
  local names = {}
  for _, name in ipairs(M.regular) do names[#names + 1] = name end
  for _, name in ipairs(M.chromatic) do names[#names + 1] = name end
  table.sort(names)
  return names
end

function M.as_set()
  local set = {}
  for _, name in ipairs(M.all()) do
    set[name] = true
  end
  return set
end

function M.chromatic_set()
  local set = {}
  for _, name in ipairs(M.chromatic) do
    set[name] = true
  end
  return set
end

function M.dispatch_recipe_name(item_name)
  return "interplanetary-dispatch-" .. item_name
end

return M
