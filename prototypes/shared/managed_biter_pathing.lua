-- Collision rules shared by Administratorio workers and native complaint biters.
-- Only the worker obstacle layer is attached to solid machinery and walls;
-- terrain and light infrastructure have no matching layer.

local M = {}

function M.apply(unit)
  if not unit then return end
  unit.collision_mask = {
    layers = {
      administratorio_worker_obstacle = true,
      administratorio_biter_rolling_stock = true,
    },
    not_colliding_with_itself = true,
  }
  unit.has_belt_immunity = true
end

return M
