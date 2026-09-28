local M = {}
-- Deliberately separate from ordinary worker collision rules.
local passable = require("prototypes.shared.personnel_routing").passable_types

function M.apply(data)
  local R = require("prototypes.shared.personnel_routing")
  if not (data.raw.tile and data.raw.tile[R.TILE]) then return end
  local masks = require("collision-mask-util")
  for name, tile in pairs(data.raw.tile) do
    if name == R.TILE then
      tile.collision_mask.layers.administratorio_personnel_pavement = true
    else
      tile.collision_mask = table.deepcopy(tile.collision_mask or {layers = {}})
      tile.collision_mask.layers.administratorio_personnel_offroad = true
    end
  end
  for _, set in pairs(data.raw) do
    for _, p in pairs(set) do
      if R.roles[p.name] then
        p.collision_mask = {layers = {administratorio_personnel_reserved = true}, not_colliding_with_itself = true}
      elseif not passable[p.type] and p.collision_box then
        local b = p.collision_box
        if b[1][1] ~= b[2][1] and b[1][2] ~= b[2][2] then
          local ok, default = pcall(masks.get_default_mask, p.type)
          if ok then
            local mask = p.collision_mask or default
            -- Only extend a class that already collides with itself. Adding
            -- one universal layer to trains, ramps and ordinary structures
            -- would change their collisions everywhere, not just on lanes.
            if mask.layers.administratorio_passenger_platform and not mask.not_colliding_with_itself then
              p.collision_mask = table.deepcopy(mask)
              p.collision_mask.layers.administratorio_personnel_reserved = true
              p.collision_mask.layers.administratorio_personnel_obstacle = true
            end
            p.tile_buildability_rules = table.deepcopy(p.tile_buildability_rules or {})
            p.tile_buildability_rules[#p.tile_buildability_rules + 1] = {
              area = table.deepcopy(b), colliding_tiles = {layers = {administratorio_personnel_pavement = true}},
            }
          end
        end
      end
    end
  end
end
return M
