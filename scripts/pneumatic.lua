-- Pneumatic form transport: hidden inserter management
local C = require("scripts.constants")
local M = {}

function M.is_pneumatic_building(entity)
  return entity and C.PNEUMATIC_BUILDINGS[entity.name]
end

function M.add_pneumatic_inserter(entity)
  local inserter_name = C.PNEUMATIC_BUILDINGS[entity.name]
  if not inserter_name then return end
  local new_inserter = entity.surface.create_entity{
    name = inserter_name,
    type = "inserter",
    position = entity.position,
    direction = entity.direction,
    force = entity.force,
  }
  if new_inserter then
    new_inserter.destructible = false
    new_inserter.inserter_stack_size_override = 1
  end
end

function M.update_pneumatic_inserter_direction(entity)
  local inserters = entity.surface.find_entities_filtered{
    type = "inserter",
    name = {"pneumatic-hidden-intake", "pneumatic-hidden-outtake"},
    position = entity.position,
    radius = 0.5
  }
  for _, ins in ipairs(inserters) do
    ins.direction = entity.direction
  end
end

function M.delete_pneumatic_inserters(entity, buffer)
  local inserters = entity.surface.find_entities_filtered{
    type = "inserter",
    name = {"pneumatic-hidden-intake", "pneumatic-hidden-outtake"},
    position = entity.position,
    radius = 0.5
  }
  for _, ins in ipairs(inserters) do
    if buffer and ins.held_stack and ins.held_stack.valid_for_read then
      buffer.insert(ins.held_stack)
    end
    ins.destroy()
  end
end

return M
