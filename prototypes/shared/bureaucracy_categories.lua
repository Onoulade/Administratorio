local M = {}

M.OFFWORLD_PLANETS = {"vulcanus", "gleba", "fulgora", "aquilo"}

function M.bootstrap_for_planet(planet_name)
  return "bureaucratic-bootstrap-" .. planet_name
end

function M.registration_for_planet(planet_name)
  return "bureaucracy-registration-" .. planet_name
end

function M.field_office()
  return {
    "bureaucracy-registration",
    "bureaucratic-bootstrap",
    "resolution-handcraft",
  }
end

function M.office_desk(space_age_enabled)
  local categories = {
    "bureaucracy-registration",
    "bureaucracy-modules",
    "bureaucratic-bootstrap",
  }

  if space_age_enabled then
    for _, planet_name in ipairs(M.OFFWORLD_PLANETS) do
      categories[#categories + 1] = M.registration_for_planet(planet_name)
      categories[#categories + 1] = M.bootstrap_for_planet(planet_name)
    end
  end

  return categories
end

return M
