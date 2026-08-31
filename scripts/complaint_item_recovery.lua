local C = require("scripts.constants")
local quality = require("scripts.quality")

local M = {}

local function quality_name(stack)
  return quality.name(stack)
end

local function add_recovered(recovered, item_name, quality, count)
  if not item_name or not C.COMPLAINT_PIPELINE_ITEMS[item_name] or not count or count <= 0 then return end
  local by_quality = recovered[item_name]
  if not by_quality then
    by_quality = {}
    recovered[item_name] = by_quality
  end
  by_quality[quality or "normal"] = (by_quality[quality or "normal"] or 0) + count
end

local function recover_inventory(inventory, recovered)
  if not inventory then return end
  for slot_index = 1, #inventory do
    local stack = inventory[slot_index]
    if stack and stack.valid_for_read and C.COMPLAINT_PIPELINE_ITEMS[stack.name] then
      add_recovered(recovered, stack.name, quality_name(stack), stack.count)
      stack.clear()
    end
  end
end

local function recover_active_craft(entity, recovered)
  if not entity.get_recipe or (entity.crafting_progress or 0) <= 0 then return end
  local recipe = entity.get_recipe()
  if not recipe then return end

  -- Assembling machines consume a craft's ingredients when progress starts, so
  -- its complaint/intermediate no longer exists in crafter_input. Reconstitute
  -- that one irreplaceable ingredient without refunding the expendable inputs.
  for _, ingredient in pairs(recipe.ingredients or {}) do
    if ingredient.type == "item" and C.COMPLAINT_PIPELINE_ITEMS[ingredient.name] then
      add_recovered(recovered, ingredient.name, "normal", ingredient.amount or 1)
    end
  end
end

local function alert_players(entity, dropped_entity, item_name, count)
  if not dropped_entity or not dropped_entity.valid then return end
  local position = entity.position
  local surface_name = entity.surface and entity.surface.name or ""
  local gps = "[gps=" .. math.floor(position.x) .. "," .. math.floor(position.y) .. "," .. surface_name .. "]"
  local players = entity.force and entity.force.players or (game and game.connected_players) or {}

  for _, player in pairs(players) do
    if player.valid then
      player.add_custom_alert(
        dropped_entity,
        {type = "item", name = item_name},
        {"message.complaint-paperwork-recovered", count, {"item-name." .. item_name}, gps},
        true
      )
    end
  end
end

local function spill_recovered(entity, recovered)
  local total = 0
  for item_name, qualities in pairs(recovered) do
    for quality, count in pairs(qualities) do
      local dropped = entity.surface.spill_item_stack{
        position = entity.position,
        stack = {name = item_name, quality = quality, count = count},
        enable_looted = true,
        allow_belts = false,
      }
      alert_players(entity, dropped and dropped[1], item_name, count)
      total = total + count
    end
  end
  return total
end

function M.on_entity_died(event)
  local entity = event and event.entity
  if not entity or not entity.valid or entity.name ~= "resolution-office" then return 0 end

  local recovered = {}
  recover_inventory(entity.get_inventory(defines.inventory.crafter_input), recovered)
  recover_inventory(entity.get_inventory(defines.inventory.crafter_output), recovered)
  recover_active_craft(entity, recovered)
  return spill_recovered(entity, recovered)
end

M._test = {
  add_recovered = add_recovered,
  recover_inventory = recover_inventory,
  recover_active_craft = recover_active_craft,
}

return M
