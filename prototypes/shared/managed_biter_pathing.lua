-- Collision rules shared by Administratorio workers and native complaint biters.
-- Solid machinery and walls use the worker obstacle layer. Water tiles and
-- cliffs use separate layers so light infrastructure stays traversable.

local M = {}

function M.apply(unit)
  if not unit then return end
  unit.collision_mask = {
    layers = {
      administratorio_worker_obstacle = true,
      administratorio_worker_terrain = true,
      administratorio_biter_rolling_stock = true,
      cliff = true,
    },
    not_colliding_with_itself = true,
  }
  unit.has_belt_immunity = true
end

return M
