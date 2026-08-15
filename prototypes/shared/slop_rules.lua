-- Which documents an AI Server may fabricate, derived from the paperwork
-- taxonomy rather than from a parallel list. The precedent is
-- generate_all_reassignments in scripts/archive_recombination_rules.lua: read
-- rank, family and colors from the one source of truth so a document added to
-- the taxonomy is covered here without further work.

local taxonomy = require("prototypes.shared.paperwork_taxonomy")

local M = {}

M.BASE_TECH = "aquilo-ai-inference"
M.ADVANCED_TECH = "administratorium-slop-synthesis"

M.CITATION_ITEM = "fabricated-citations"
M.SLOP_ITEM = "administrative-slop"
M.TOKEN_ITEM = "inference-token"

--- Colored paperwork is never producible from slop, at any tier. This is what
--- preserves the ink economy, the chromatic printer chain, and the planetary
--- import loop that the whole Space Age pass rests on. Restricted documents are
--- excluded for the same reason the recycler refuses them.
local function is_sloppable(name, entry)
  if entry == nil then return false end
  if entry.restricted then return false end
  if taxonomy.restricted_documents[name] then return false end
  if entry.colors and next(entry.colors) ~= nil then return false end
  return true
end

--- Rank 0-1 at the Aquilo tier, rank 2-3 at the Administratorium tier.
function M.tier_for(name)
  local entry = taxonomy.get(name)
  if not is_sloppable(name, entry) then return nil end
  if entry.rank <= 1 then return "base" end
  if entry.rank <= 3 then return "advanced" end
  return nil
end

function M.documents_for_tier(tier)
  local names = {}
  for name in pairs(taxonomy.documents) do
    if M.tier_for(name) == tier then
      names[#names + 1] = name
    end
  end
  table.sort(names)
  return names
end

function M.technology_for_tier(tier)
  if tier == "advanced" then return M.ADVANCED_TECH end
  return M.BASE_TECH
end

--- Slop cost and hallucination volume both scale with the rank being slopped.
--- The harder the document, the more the machine invents; that is simultaneously
--- the balance governor for the late tier and thematically exact.
function M.slop_cost(name)
  local entry = taxonomy.get(name)
  if not entry then return nil end
  return 2 + entry.rank * 3
end

function M.citation_yield(name)
  local entry = taxonomy.get(name)
  if not entry then return nil end
  if entry.rank <= 1 then return 1 + entry.rank end
  return 4 + (entry.rank - 2) * 6
end

function M.recipe_name(name)
  return "slop-synthesis-" .. name
end

return M
