-- Admin-station collision and module-category final pass.
-- Kept separate because it mutates entity prototypes independently of recipe
-- regulation and needs a narrow, focused compatibility test surface.

local M = {}

local ADMIN_STATION_COLLISION_LAYER = "administratorio_station_footprint"
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
  for _, prototype_set in pairs(data.raw) do
    for _, prototype in pairs(prototype_set) do
      if should_add_admin_station_layer(prototype) then
        prototype.collision_mask = normalize_collision_mask(prototype.collision_mask)
        prototype.collision_mask.layers[ADMIN_STATION_COLLISION_LAYER] = true
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
