-- Data/runtime contract for protected, two-tile personnel lanes.
local M = {
  INPUT = "personnel-deployment-office",
  OUTPUT = "personnel-reception-office",
  SIGN = "personnel-routing-sign",
  ROAD = "personnel-path",
  TILE = "personnel-path-concrete",
  RECOVERY = "personnel-recovery-crate",
  CATEGORY = "personnel-routing-cargo",
  MAX_ROUTE_CELLS = 512,
  UPDATE_TICKS = 1,
  RETRY_TICKS = 60,
  DISPATCH_TICKS = 5,
  STALL_TICKS = 600,
}
M.passable_types = {
  ["transport-belt"] = true, ["underground-belt"] = true, ["splitter"] = true,
  ["linked-belt"] = true, ["loader"] = true, ["loader-1x1"] = true,
  ["inserter"] = true, ["electric-pole"] = true,
  ["unit"] = true, ["character"] = true, ["resource"] = true,
  ["construction-robot"] = true, ["logistic-robot"] = true, ["combat-robot"] = true,
  ["entity-ghost"] = true, ["tile-ghost"] = true, ["corpse"] = true,
  ["item-entity"] = true, ["fish"] = true, ["highlight-box"] = true,
  ["spider-leg"] = true, ["projectile"] = true, ["particle"] = true,
  ["explosion"] = true, ["fire"] = true, ["smoke-with-trigger"] = true,
}
M.roles = {[M.INPUT] = "input", [M.OUTPUT] = "output", [M.SIGN] = "sign", [M.ROAD] = "road"}
M.names = {M.INPUT, M.OUTPUT, M.SIGN, M.ROAD}
M.cargo = require("prototypes.shared.relocation_cargo").as_set()
M.cargo["rideable-biter"] = nil
M.cargo["hired-biter-capsule"] = nil -- Field Agents keep their dedicated deployment system.
M.cargo["biter-logistics-formation"] = true
M.cargo["voluntary-exploration-space-miner"] = true
function M.unit_name(item) return "personnel-in-transit-" .. item end
function M.load_recipe(item) return "personnel-routing-load-" .. item end
function M.key(x, y) return x .. ":" .. y end
function M.vector(direction)
  local d = defines.direction
  if direction == d.north then return 0, -2 end
  if direction == d.east then return 2, 0 end
  if direction == d.south then return 0, 2 end
  if direction == d.west then return -2, 0 end
end
return M
