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

local function make_simulation(filename, duration, logo_position)
  local move_logo = ""
  if logo_position then
    move_logo = ("logo.teleport({%s, %s})\n"):format(logo_position[1], logo_position[2])
  end

  return {
    checkboard = false,
    save = "__administratorio__/menu-simulations/" .. filename .. ".zip",
    length = 60 * duration,
    mods = {"administratorio"},
    init = [[
      local surface = game.surfaces.nauvis
      local logo = surface.find_entities_filtered{name = "factorio-logo-11tiles", limit = 1}[1]
    ]] .. move_logo .. [[
      logo.destructible = false
      game.simulation.camera_surface_index = surface.index
      game.simulation.camera_position = {logo.position.x, logo.position.y + 9.75}
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

local function apply(raw)
  local simulations = raw["utility-constants"]["default"].main_menu_simulations or {}
  for name, simulation in pairs(simulations) do
    if is_builtin(simulation) then simulations[name] = nil end
  end

  simulations.administratorio = make_simulation("administratorio", 20)
  simulations.administratorio_biterport = make_simulation("biterport", 20)
  simulations.administratorio_saghetti = make_simulation("saghetti", 20)
  -- The biter station save was captured with its viewpoint below the logo.
  simulations.administratorio_biter_station = make_simulation("biter-station", 20, {-4.1484375, 15.51953125})
  -- The train save's original logo is centered between its two tracks.
  simulations.administratorio_passenger_train = make_simulation("passenger-train", 20)

  raw["utility-constants"]["default"].main_menu_simulations = simulations
end

return {apply = apply}
