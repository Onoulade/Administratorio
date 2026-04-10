local M = {}

M.BASIC_PLANET_PROPERTIES = {
  nauvis = {pressure = 1000, gravity = 10},
  vulcanus = {pressure = 4000, gravity = 40},
  gleba = {pressure = 2000, gravity = 20},
  fulgora = {pressure = 800, gravity = 8},
}

M.BASIC_PLANET_ABUNDANCE = {
  vulcanus = "lie",
  gleba = "dubious-data",
  fulgora = "useless-documentation",
}

local function clone_surface_conditions(conditions)
  local cloned = {}
  for index, condition in ipairs(conditions or {}) do
    cloned[index] = {
      property = condition.property,
      min = condition.min,
      max = condition.max,
    }
  end
  return cloned
end

function M.surface_conditions_for_planet(planet_name)
  local properties = M.BASIC_PLANET_PROPERTIES[planet_name]
  if not properties then return nil end

  return {
    {
      property = "pressure",
      min = properties.pressure,
      max = properties.pressure,
    },
    {
      property = "gravity",
      min = properties.gravity,
      max = properties.gravity,
    },
  }
end

function M.apply_surface_conditions(prototype, conditions)
  if not prototype or not conditions then return prototype end
  prototype.surface_conditions = clone_surface_conditions(conditions)
  return prototype
end

function M.apply_planet_surface_conditions(prototype, planet_name)
  return M.apply_surface_conditions(prototype, M.surface_conditions_for_planet(planet_name))
end

return M
