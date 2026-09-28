-- Data/runtime contract for protected, two-tile personnel lanes.
local M = {
  INPUT = "personnel-deployment-office",
  OUTPUT = "personnel-reception-office",
  SIGN = "personnel-routing-sign",
  MULTISIGN = "personnel-routing-multisign",
  MULTISIGN_SCALE = 1.2,
  PORT = "personnel-routing-filter-port",
  SPEED_100 = "personnel-routing-speed-1",
  SPEED_150 = "personnel-routing-speed-2",
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
M.roles = {[M.INPUT] = "input", [M.OUTPUT] = "output", [M.SIGN] = "sign", [M.MULTISIGN] = "sign", [M.ROAD] = "road"}
M.names = {M.INPUT, M.OUTPUT, M.SIGN, M.MULTISIGN, M.ROAD}
M.cargo = require("prototypes.shared.relocation_cargo").as_set()
M.cargo["rideable-biter"] = nil
M.cargo["hired-biter-capsule"] = nil -- Field Agents keep their dedicated deployment system.
M.cargo["biter-logistics-formation"] = true
M.cargo["voluntary-exploration-space-miner"] = true
function M.is_port(name) return name == M.PORT .. "-left" or name == M.PORT .. "-straight" or name == M.PORT .. "-right" end
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
M.exits = {"left", "straight", "right"}
function M.exit_direction(direction, exit)
  return (direction + (exit == "left" and -4 or exit == "right" and 4 or 0)) % 16
end
function M.directions(node)
  if node.entity.name ~= M.MULTISIGN then return {node.entity.direction} end
  local result = {}
  for _,exit in ipairs(M.exits) do result[#result+1] = M.exit_direction(node.entity.direction, exit) end
  return result
end
function M.direction_for(node, item)
  if node.entity.name ~= M.MULTISIGN then return node.entity.direction end
  for _,exit in ipairs(M.exits) do
    if node.filters and node.filters[exit] and node.filters[exit][item] then
      return M.exit_direction(node.entity.direction, exit)
    end
  end
end
function M.speed_multiplier(force)
  local technologies = force.technologies
  if technologies[M.SPEED_150] and technologies[M.SPEED_150].researched then return 3 end
  if technologies[M.SPEED_100] and technologies[M.SPEED_100].researched then return 2 end
  return 1
end
return M
