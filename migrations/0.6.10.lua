-- Unify the old base-mode biter-worker item with the canonical worker-biter.
-- The legacy prototype remains hidden so migrations and old station contents
-- can still be read safely while every new recipe and runtime path uses one
-- item name.
local LEGACY = "biter-worker"
local CANONICAL = "worker-biter"

local function migrate_inventory(inventory)
  if not inventory or not inventory.valid then return end
  local count = inventory.get_item_count(LEGACY)
  if count <= 0 then return end

  -- A stack of legacy workers may need several one-item slots after the
  -- unification. Leave it untouched if this inventory cannot hold all of it;
  -- the hidden compatibility item and station runtime keep it usable.
  if inventory.can_insert and not inventory.can_insert({name = CANONICAL, count = count}) then
    return
  end

  local removed = inventory.remove({name = LEGACY, count = count})
  if removed > 0 then
    inventory.insert({name = CANONICAL, count = removed})
  end
end

local function migrate_entity(entity)
  if not entity or not entity.valid then return end
  -- Workers are normally stored in the employment office. The other common
  -- inventories cover players and cargo/container storage without scanning
  -- every machine on large existing factories.
  for _, inventory_id in pairs({
    defines.inventory.chest,
    defines.inventory.cargo_wagon,
    defines.inventory.car_trunk,
    defines.inventory.spider_trunk,
    defines.inventory.character_main,
  }) do
    local inventory = entity.get_inventory(inventory_id)
    migrate_inventory(inventory)
  end
end

for _, player in pairs(game.players) do
  migrate_inventory(player.get_main_inventory())
end

for _, surface in pairs(game.surfaces) do
  for _, station in pairs(surface.find_entities_filtered{name = "biter-station"}) do
    migrate_entity(station)
  end
  for _, entity in pairs(surface.find_entities_filtered{type = {"container", "logistic-container", "cargo-wagon", "car", "spider-vehicle"}}) do
    migrate_entity(entity)
  end
end
