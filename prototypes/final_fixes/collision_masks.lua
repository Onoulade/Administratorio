-- Admin-station collision and module-category final pass.
-- Kept separate because it mutates entity prototypes independently of recipe
-- regulation and needs a narrow, focused compatibility test surface.

local M = {}

local ADMIN_STATION_COLLISION_LAYER = "administratorio_station_footprint"
local WORKER_TERRAIN_COLLISION_LAYER = "administratorio_worker_terrain"
local WORKER_OBSTACLE_COLLISION_LAYER = "administratorio_worker_obstacle"
local RIDEABLE_BITER_COLLISION_LAYER = "administratorio_rideable_biter_collision"
local RIDEABLE_BITER_TERRAIN_LAYER = "administratorio_rideable_biter_terrain"
local PASSENGER_PLATFORM_COLLISION_LAYER = "administratorio_passenger_platform"
local NIGHT_WORK_BUILDINGS = {
  ["office-desk"] = true,
  ["corporate-breakroom"] = true,
  ["union-headquarters"] = true,
}
local ADMIN_STATION_NON_BLOCKING_NAMES = {
  ["admin-station-combinator"] = true,
  ["biterport-hidden-roboport"] = true,
  ["biter-station-wall-blocker"] = true,
  ["biterport-wall-blocker"] = true,
  ["transit-permit-chest"] = true,
  ["pneumatic-hidden-network-pipe"] = true,
}
local ADMIN_STATION_EXCLUDED_TYPES = {
  ["character"] = true, ["combat-robot"] = true, ["construction-robot"] = true,
  ["corpse"] = true, ["entity-ghost"] = true, ["explosion"] = true,
  ["fire"] = true, ["highlight-box"] = true, ["item-entity"] = true,
  ["logistic-robot"] = true, ["optimized-decorative"] = true, ["particle"] = true,
  ["particle-source"] = true, ["projectile"] = true, ["rocket-silo-rocket"] = true,
  ["segment"] = true, ["segmented-unit"] = true, ["smoke"] = true,
  ["smoke-with-trigger"] = true, ["speech-bubble"] = true, ["spider-leg"] = true,
  ["spider-unit"] = true, ["stream"] = true, ["tile-ghost"] = true,
  ["unit"] = true,
  ["resource"] = true, ["tree"] = true, ["simple-entity"] = true,
  ["simple-entity-with-force"] = true, ["simple-entity-with-owner"] = true,
  ["cliff"] = true, ["fish"] = true, ["unit-spawner"] = true, ["turret"] = true,
  ["transport-belt"] = true, ["underground-belt"] = true, ["splitter"] = true,
  ["loader"] = true, ["loader-1x1"] = true, ["linked-belt"] = true,
  ["lane-splitter"] = true, ["inserter"] = true, ["land-mine"] = true,
  ["straight-rail"] = true, ["curved-rail-a"] = true, ["curved-rail-b"] = true,
  ["half-diagonal-rail"] = true, ["elevated-straight-rail"] = true,
  ["elevated-curved-rail-a"] = true, ["elevated-curved-rail-b"] = true,
  ["elevated-half-diagonal-rail"] = true, ["rail-ramp"] = true,
  ["rail-support"] = true, ["legacy-straight-rail"] = true,
  ["legacy-curved-rail"] = true, ["rail-signal"] = true,
  ["rail-chain-signal"] = true, ["display-panel"] = true,
  ["car"] = true, ["spider-vehicle"] = true, ["locomotive"] = true,
  ["cargo-wagon"] = true, ["fluid-wagon"] = true,
}
local ADMIN_STATION_EXCLUDED_FLAGS = {
  ["not-on-map"] = true,
  ["placeable-off-grid"] = true,
}
-- Passenger platforms are solid reservation markers for every physical thing
-- except the two populations that must cross their queue apron: characters
-- and enemy units. Unlike the broader admin-station rule, rails and rolling
-- stock intentionally remain in this set, which prevents overlap placement.
local PASSENGER_PLATFORM_PASSABLE_NAMES = {
  ["boarding-platform"] = true,
  ["deboarding-platform"] = true,
}
local PASSENGER_PLATFORM_PASSABLE_TYPES = {
  ["character"] = true, ["unit"] = true, ["combat-robot"] = true,
  ["construction-robot"] = true, ["corpse"] = true, ["entity-ghost"] = true,
  ["explosion"] = true, ["fire"] = true, ["highlight-box"] = true,
  ["item-entity"] = true, ["logistic-robot"] = true,
  ["optimized-decorative"] = true, ["particle"] = true,
  ["particle-source"] = true, ["projectile"] = true,
  ["rocket-silo-rocket"] = true, ["segment"] = true,
  ["segmented-unit"] = true, ["smoke"] = true,
  ["smoke-with-trigger"] = true, ["speech-bubble"] = true,
  ["spider-leg"] = true, ["stream"] = true, ["tile-ghost"] = true,
  -- Ore deposits must retain their native resource-only mask so drills and
  -- ordinary buildings can still be placed over them.
  ["resource"] = true,
}
local WORKER_PASSABLE_NAMES = {
  -- These buildings use hidden blockers to model walls while keeping their
  -- waiting/work areas navigable to managed biters.
  ["admin-station"] = true,
  ["capture-bureau"] = true,
  ["biter-station"] = true,
  ["biterport"] = true,
  ["biterport-placement-preview"] = true,
  -- These use the train layer to remain solid to managed biters. Do not add
  -- the general worker-obstacle layer, because trees also carry that layer
  -- and the mounted biter must be able to step through them.
  ["rideable-biter"] = true,
  ["rideable-biter-mounted"] = true,
}
local WORKER_PASSABLE_TYPES = {
  ["character"] = true, ["combat-robot"] = true, ["construction-robot"] = true,
  ["corpse"] = true, ["entity-ghost"] = true, ["explosion"] = true,
  ["fire"] = true, ["highlight-box"] = true, ["item-entity"] = true,
  ["logistic-robot"] = true, ["optimized-decorative"] = true, ["particle"] = true,
  ["particle-source"] = true, ["projectile"] = true, ["rocket-silo-rocket"] = true,
  ["segment"] = true, ["segmented-unit"] = true, ["smoke"] = true,
  ["smoke-with-trigger"] = true, ["speech-bubble"] = true, ["spider-leg"] = true,
  ["spider-unit"] = true, ["stream"] = true, ["tile-ghost"] = true,
  ["unit"] = true, ["resource"] = true, ["fish"] = true,

  -- Narrow factory infrastructure is intentionally traversable.
  ["transport-belt"] = true, ["underground-belt"] = true, ["splitter"] = true,
  ["loader"] = true, ["loader-1x1"] = true, ["linked-belt"] = true,
  ["lane-splitter"] = true, ["inserter"] = true, ["electric-pole"] = true,
  ["land-mine"] = true, ["display-panel"] = true,

  -- Workers may cross rails, but the train collision layer still blocks trains.
  ["straight-rail"] = true, ["curved-rail-a"] = true, ["curved-rail-b"] = true,
  ["half-diagonal-rail"] = true, ["elevated-straight-rail"] = true,
  ["elevated-curved-rail-a"] = true, ["elevated-curved-rail-b"] = true,
  ["elevated-half-diagonal-rail"] = true, ["rail-ramp"] = true,
  ["rail-support"] = true, ["legacy-straight-rail"] = true,
  ["legacy-curved-rail"] = true, ["rail-signal"] = true,
  ["rail-chain-signal"] = true,
}
local RIDEABLE_BITER_PASSABLE_TYPES = {
  ["tree"] = true,
  ["inserter"] = true,
  ["electric-pole"] = true,
  -- Rolling stock must keep its vanilla mask. The rideable biter already
  -- collides with trains via the train layer, and rail ramps/supports gain
  -- the rideable layer (cars are blocked by them). Giving stock the same
  -- layer would make locomotives/wagons collide with ramps/supports and
  -- block elevated rail access.
  ["locomotive"] = true,
  ["cargo-wagon"] = true,
  ["fluid-wagon"] = true,
  ["artillery-wagon"] = true,
  ["infinity-cargo-wagon"] = true,
  -- Spider legs are transient walkers, not solid building footprints.
  ["spider-leg"] = true,
  -- Asteroid collectors are only placeable on space platforms, where the
  -- rideable biter cannot travel. Keep their native overlap rules intact.
  ["asteroid-collector"] = true,
}

local function collision_box_is_zero(box)
  return box and box[1] and box[2]
    and box[1][1] == 0 and box[1][2] == 0
    and box[2][1] == 0 and box[2][2] == 0
end

local function normalize_collision_mask(mask)
  if not mask then
    return {layers = {item = true, object = true, player = true, water_tile = true}}
  end
  if mask.layers then
    mask.layers = mask.layers or {}
    return mask
  end

  local normalized = {layers = {}}
  for key, value in pairs(mask) do
    if key == "not_colliding_with_itself" or key == "consider_tile_transitions" or key == "colliding_with_tiles_only" then
      normalized[key] = value
    elseif type(key) == "number" and type(value) == "string" then
      normalized.layers[value] = true
    elseif type(key) == "string" and value == true then
      normalized.layers[key] = true
    end
  end
  return normalized
end

local collision_mask_util
local default_collision_masks = {}
local function default_collision_mask_for(prototype_type)
  if not prototype_type then return nil end
  local cached = default_collision_masks[prototype_type]
  if cached ~= nil then return cached or nil end

  collision_mask_util = collision_mask_util or require("collision-mask-util")
  local ok, mask = pcall(collision_mask_util.get_default_mask, prototype_type)
  default_collision_masks[prototype_type] = ok and mask or false
  return ok and mask or nil
end

local function materialize_collision_mask(prototype)
  if prototype.collision_mask then
    return normalize_collision_mask(prototype.collision_mask)
  end
  return normalize_collision_mask(default_collision_mask_for(prototype.type))
end

local function masks_collide(mask_a, mask_b)
  if collision_mask_util and collision_mask_util.masks_collide then
    return collision_mask_util.masks_collide(mask_a, mask_b)
  end
  for layer in pairs(mask_a.layers or {}) do
    if mask_b.layers and mask_b.layers[layer] then return true end
  end
  return false
end

local function collides_with_standard_car(mask)
  local car_mask = normalize_collision_mask(default_collision_mask_for("car"))
  return car_mask and masks_collide(normalize_collision_mask(mask), car_mask)
end

local function has_excluded_flag(prototype)
  for _, flag in ipairs(prototype.flags or {}) do
    if ADMIN_STATION_EXCLUDED_FLAGS[flag] then return true end
  end
  return false
end

local function should_add_admin_station_layer(prototype)
  return prototype
    and not ADMIN_STATION_NON_BLOCKING_NAMES[prototype.name]
    and not ADMIN_STATION_EXCLUDED_TYPES[prototype.type]
    and not has_excluded_flag(prototype)
    and prototype.collision_mask
    and prototype.collision_box
    and not collision_box_is_zero(prototype.collision_box)
end

local function should_add_worker_obstacle_layer(prototype)
  return prototype
    and not WORKER_PASSABLE_NAMES[prototype.name]
    and not WORKER_PASSABLE_TYPES[prototype.type]
    and not has_excluded_flag(prototype)
    and prototype.collision_box
    and not collision_box_is_zero(prototype.collision_box)
    and (prototype.collision_mask or default_collision_mask_for(prototype.type))
end

local function should_add_rideable_biter_layer(prototype)
  if not prototype
    or RIDEABLE_BITER_PASSABLE_TYPES[prototype.type]
    or not prototype.collision_box
    or collision_box_is_zero(prototype.collision_box)
  then
    return false
  end

  local mask = prototype.collision_mask or default_collision_mask_for(prototype.type)
  if not mask then return false end
  mask = normalize_collision_mask(mask)
  -- The mounted biter already has the train layer. Entities carrying it
  -- need no extra layer, which would otherwise change their collisions with
  -- walkable infrastructure such as underground pipes.
  return not mask.layers.train and collides_with_standard_car(mask)
end

local function should_add_passenger_platform_layer(prototype)
  return prototype
    and not PASSENGER_PLATFORM_PASSABLE_NAMES[prototype.name]
    and not PASSENGER_PLATFORM_PASSABLE_TYPES[prototype.type]
    and not has_excluded_flag(prototype)
    and prototype.collision_box
    and not collision_box_is_zero(prototype.collision_box)
    and (prototype.collision_mask or default_collision_mask_for(prototype.type))
end

local function build_standard_module_categories(data)
  local categories = {}
  for name in pairs(data.raw["module-category"] or {}) do
    if name ~= "night-work" then categories[#categories + 1] = name end
  end
  table.sort(categories)
  return categories
end

local function copy_array(values)
  local copy = {}
  for index, value in ipairs(values) do copy[index] = value end
  return copy
end

function M.apply(data, working_hours_enabled)
  local standard_module_categories = build_standard_module_categories(data)

  -- Employment workers ignore factory footprints, including the Employment
  -- Office they spawn inside. Give water tiles a worker-only layer instead of
  -- putting water_tile on the workers, which also collides with the Office.
  for _, tile in pairs(data.raw.tile or {}) do
    if tile.collision_mask then
      local mask = normalize_collision_mask(tile.collision_mask)
      if mask.layers.water_tile then
        mask.layers[WORKER_TERRAIN_COLLISION_LAYER] = true
      end
      if collides_with_standard_car(mask) then
        mask.layers[RIDEABLE_BITER_TERRAIN_LAYER] = true
      end
      tile.collision_mask = mask
    end
  end

  for _, prototype_set in pairs(data.raw) do
    for _, prototype in pairs(prototype_set) do
      if should_add_admin_station_layer(prototype) then
        prototype.collision_mask = normalize_collision_mask(prototype.collision_mask)
        prototype.collision_mask.layers[ADMIN_STATION_COLLISION_LAYER] = true
      end

      if should_add_worker_obstacle_layer(prototype) then
        prototype.collision_mask = materialize_collision_mask(prototype)
        prototype.collision_mask.layers[WORKER_OBSTACLE_COLLISION_LAYER] = true
      end

      if should_add_rideable_biter_layer(prototype) then
        prototype.collision_mask = materialize_collision_mask(prototype)
        prototype.collision_mask.layers[RIDEABLE_BITER_COLLISION_LAYER] = true
      end

      if should_add_passenger_platform_layer(prototype) then
        prototype.collision_mask = materialize_collision_mask(prototype)
        prototype.collision_mask.layers[PASSENGER_PLATFORM_COLLISION_LAYER] = true
      end

      if prototype and type(prototype.module_slots) == "number" and prototype.module_slots > 0 then
        local categories = copy_array(standard_module_categories)
        if working_hours_enabled and NIGHT_WORK_BUILDINGS[prototype.name] then
          categories[#categories + 1] = "night-work"
        end
        prototype.allowed_module_categories = categories
      end
    end
  end
end

return M
