-- Replace the built-in title scenes after base, elevated rails, and Space Age
-- have registered theirs. Keep scenes supplied by unrelated mods.
local builtin_save_prefixes = {
  "__base__/",
  "__elevated-rails__/",
  "__space-age__/",
}

local function is_builtin(simulation)
  local save = simulation.save
  if type(save) ~= "string" then return false end
  for _, prefix in ipairs(builtin_save_prefixes) do
    if save:sub(1, #prefix) == prefix then return true end
  end
  return false
end

local function make_simulation(filename, duration, fallback_position, override_position)
  return {
    checkboard = false,
    save = "__administratorio__/menu-simulations/" .. filename .. ".zip",
    length = 60 * duration,
    mods = {"administratorio"},
    init = [[
      local surface = game.surfaces.nauvis
      local logos = {}
      for _, name in ipairs({"factorio-logo-11tiles", "factorio-logo-16tiles", "factorio-logo-22tiles"}) do
        if prototypes.entity[name] then
          for _, entity in pairs(surface.find_entities_filtered{name = name}) do
            logos[#logos + 1] = entity
          end
        end
      end
    ]] .. ("local position = {%s, %s}\n"):format(fallback_position[1], fallback_position[2]) .. [[
      if logos[1] then position = logos[1].position end
    ]] .. (override_position and ("position = {%s, %s}\n"):format(fallback_position[1], fallback_position[2]) or "") .. [[
      -- Base and Space Age share this prototype name; the enabled expansion
      -- supplies its artwork. Larger saved logos retain their scene anchor.
      local logo
      for _, entity in ipairs(logos) do
        if entity.name == "factorio-logo-11tiles" and not logo then
          logo = entity
        else
          entity.destroy()
        end
      end
      if logo then
        logo.teleport(position)
      elseif prototypes.entity["factorio-logo-11tiles"] then
        logo = surface.create_entity{
          name = "factorio-logo-11tiles", position = position, force = "neutral", snap_to_grid = false,
        }
      end
      if logo then
        logo.destructible = false
        logo.minable = false
        logo.operable = false
        position = logo.position
      end
      game.simulation.camera_surface_index = surface.index
      game.simulation.camera_position = {position.x or position[1], (position.y or position[2]) + 9.75}
      game.simulation.camera_zoom = 1
      for _, player in pairs(game.players) do
        player.game_view_settings.show_controller_gui = false
        player.game_view_settings.show_quickbar = false
        player.game_view_settings.show_shortcut_bar = false
      end
      game.tick_paused = false
    ]],
  }
end

local function apply(raw, space_age_enabled)
  local simulations = raw["utility-constants"]["default"].main_menu_simulations or {}
  for name, simulation in pairs(simulations) do
    if is_builtin(simulation) then simulations[name] = nil end
  end

  simulations.administratorio = make_simulation("administratorio", 20, {0.5, -11})
  simulations.administratorio_biterport = make_simulation("biterport", 20, {0.5, -11})
  simulations.administratorio_saghetti = make_simulation("saghetti", 20, {0.5, 0})
  simulations.administratorio_protest = make_simulation("protest", 20, {-25, -21})
  -- The biter station save was captured with its viewpoint below the logo.
  simulations.administratorio_biter_station = make_simulation("biter-station", 20, {-4.1484375, 15.51953125}, true)
  -- The train save's original logo is centered between its two tracks.
  simulations.administratorio_passenger_train = make_simulation("passenger-train", 20, {-6.5, 0})

  if space_age_enabled then
    simulations.administratorio_pathways = make_simulation("space-age/pathways", 20, {4, -19.5})
    simulations.administratorio_pathways.mods = {"administratorio", "space-age"}
  end

  raw["utility-constants"]["default"].main_menu_simulations = simulations
end

return {apply = apply}
