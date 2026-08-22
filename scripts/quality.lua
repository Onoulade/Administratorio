-- Shared runtime Quality helpers.  The formulas deliberately mirror native
-- Quality: facilities use 1 + 0.3 * level and bespoke infrastructure uses
-- the narrower 1 + 0.1 * level curve.
local M = {}

local FALLBACK_LEVELS = {
  normal = 0,
  uncommon = 1,
  rare = 2,
  epic = 3,
  legendary = 5,
}

local function safe_field(subject, field)
  if subject == nil then return nil end
  local ok, value = pcall(function() return subject[field] end)
  return ok and value or nil
end

function M.name(subject)
  if not subject then return "normal" end
  if type(subject) == "string" then return subject end
  -- Factorio API objects throw when an unsupported property is read.  A
  -- LuaQualityPrototype is already the quality, so probing .quality on it
  -- must be guarded before falling back to its own name and level.
  local direct_quality = safe_field(subject, "quality")
  local quality = direct_quality
  if quality == nil then
    -- Quality prototypes carry a level; ordinary entities and item stacks do
    -- not.  Treat those missing/legacy values as normal rather than mistaking
    -- an item name for a quality name.
    local level = safe_field(subject, "level")
    if type(level) == "number" then
      quality = subject
    else
      local name = safe_field(subject, "name")
      if name and (FALLBACK_LEVELS[name] ~= nil
          or (prototypes and prototypes.quality and prototypes.quality[name])) then
        quality = subject
      else
        return "normal"
      end
    end
  end
  if type(quality) == "string" then return quality end
  return safe_field(quality, "name") or "normal"
end

function M.level(subject)
  local quality = subject and (safe_field(subject, "quality") or subject) or nil
  if quality and type(quality) ~= "string" then
    local level = safe_field(quality, "level")
    if type(level) == "number" then return level end
  end

  local name = M.name(subject)
  if prototypes and prototypes.quality and prototypes.quality[name] then
    local prototype = prototypes.quality[name]
    if prototype.level ~= nil then return prototype.level end
  end
  return FALLBACK_LEVELS[name] or 0
end

function M.native_speed_multiplier(subject)
  return 1 + 0.3 * M.level(subject)
end

function M.infrastructure_multiplier(subject)
  return 1 + 0.1 * M.level(subject)
end

function M.scaled_ticks(base_ticks, subject)
  return math.ceil(base_ticks / M.native_speed_multiplier(subject))
end

return M
