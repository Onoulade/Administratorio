-- ADMINISTRATORIO: COMPATIBILITY HOOKS
--
-- Named extension points.  Compat modules register handlers at load time; the
-- core reads a point without knowing who, if anyone, answered.  Nothing here
-- knows about any particular mod, and no core module names one.

local M = {}

local handlers = {}  -- point -> ordered list of handlers
local sealed = {}    -- point -> true once its value has been read

--- Registration order is the require order in compat/init.lua: deterministic,
--- and identical for every peer in a multiplayer game.
function M.register(point, handler)
  if sealed[point] then
    -- A silent misordering would silently disable compatibility, so this is a
    -- hard error: compat.init must load before whatever reads the point.
    error("compat hook '" .. point .. "' was already read before this registration")
  end
  local list = handlers[point]
  if not list then
    list = {}
    handlers[point] = list
  end
  list[#list + 1] = handler
  return M
end

--- Ask a point for an answer.  The first handler returning non-nil wins; nil
--- when nobody claims the case, so the caller keeps its own default.
function M.resolve(point, ...)
  sealed[point] = true
  local list = handlers[point]
  if not list then return nil end
  for i = 1, #list do
    local answer, extra = list[i](...)
    if answer ~= nil then return answer, extra end
  end
  return nil
end

--- Union of `base` with every registered set.  Read once, at load time, so the
--- result stays a plain table the caller can index in a hot loop.
function M.collect(point, base)
  sealed[point] = true
  for _, handler in ipairs(handlers[point] or {}) do
    for key, value in pairs(handler()) do
      base[key] = value
    end
  end
  return base
end

--- Tests only: forget every registration.
function M.reset()
  handlers = {}
  sealed = {}
end

return M
