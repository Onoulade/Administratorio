-- ADMINISTRATORIO: MENU SIMULATIONS
--
-- Adds a custom title-screen background using a mod save file.

local simulations_path = "__administratorio__/menu-simulations/"

local menu_sims = data.raw["utility-constants"]["default"].main_menu_simulations

menu_sims.administratorio_title = {
  checkboard = false,
  game_view_settings = {
    default_show_value = false,
    show_shortcut_bar = false,
    show_quickbar = false,
    show_tool_bar = false,
  },
  init_update_count = 60,
  save = simulations_path .. "administratorio-title.zip",
  length = 20 * second,
  init = [[
    game.simulation.camera_zoom = 1
    game.simulation.camera_alt_info = false
    game.simulation.hide_cursor = true
    game.tick_paused = false
  ]],
}
