-- Exercise generated menu init code, including the logo sizes in supplied saves.
package.path = './?.lua;' .. package.path
local menu = require('prototypes.final_fixes.menu_simulations')

local function scenes(space_age)
  local raw = {['utility-constants'] = {default = {main_menu_simulations = {
    vanilla = {save = '__base__/menu-simulations/example.zip'},
    other_mod = {save = '__other__/example.zip'},
  }}}}
  menu.apply(raw, space_age)
  local result = raw['utility-constants'].default.main_menu_simulations
  assert(not result.vanilla and result.other_mod)
  assert((result.administratorio_pathways ~= nil) == space_age)
  return result
end

local function run_init(scene, saved_names, available, creation_fails)
  local entities = {}
  local function entity(name, position)
    local e = {name = name, position = {x = position.x or position[1], y = position.y or position[2]}, valid = true}
    e.destroy = function() e.valid = false end
    e.teleport = function(p) e.position = {x = p.x or p[1], y = p.y or p[2]}; return true end
    entities[#entities + 1] = e
    return e
  end
  for _, name in ipairs(saved_names) do entity(name, {12, -30}) end
  local surface = {index = 1}
  surface.find_entities_filtered = function(filter)
    assert(available[filter.name], 'unknown prototype queried')
    local found = {}
    for _, e in ipairs(entities) do
      if e.valid and e.name == filter.name then found[#found + 1] = e end
    end
    return found
  end
  surface.create_entity = function(args)
    assert(available[args.name])
    if not creation_fails then return entity(args.name, args.position) end
  end
  local game = {surfaces = {nauvis = surface}, simulation = {}, players = {{game_view_settings = {}}}, tick_paused = true}
  local env = setmetatable({game = game, prototypes = {entity = available}}, {__index = _G})
  assert(load(scene.init, 'menu init', 't', env))()
  assert(not game.tick_paused and game.simulation.camera_surface_index == 1)
  assert(game.simulation.camera_zoom == 1)
  assert(game.players[1].game_view_settings.show_controller_gui == false)
  local live = {}
  for _, e in ipairs(entities) do if e.valid then live[#live + 1] = e end end
  if available['factorio-logo-11tiles'] and not creation_fails then
    assert(#live == 1 and live[1].name == 'factorio-logo-11tiles')
    assert(live[1].destructible == false and live[1].minable == false and live[1].operable == false)
    assert(game.simulation.camera_position[1] == live[1].position.x)
    assert(game.simulation.camera_position[2] == live[1].position.y + 9.75)
  end
  return game, live
end

local available = {['factorio-logo-11tiles'] = true, ['factorio-logo-16tiles'] = true, ['factorio-logo-22tiles'] = true}
for _, enabled in ipairs({false, true}) do
  for name, scene in pairs(scenes(enabled)) do
    if name ~= 'other_mod' then
      assert(scene.length == 1200)
      for _, names in ipairs({{'factorio-logo-11tiles'}, {'factorio-logo-16tiles'}, {'factorio-logo-22tiles'}, {}, {'factorio-logo-22tiles', 'factorio-logo-11tiles', 'factorio-logo-16tiles'}}) do
        local game = run_init(scene, names, available)
        if #names > 0 and name ~= 'administratorio_biter_station' then
          assert(game.simulation.camera_position[1] == 12 and game.simulation.camera_position[2] == -20.25, 'saved anchor moved')
        end
      end
      run_init(scene, {}, {}, false)
      run_init(scene, {}, available, true)
    end
  end
end
local base = scenes(false)
local game = run_init(base.administratorio_passenger_train, {}, available)
assert(game.simulation.camera_position[1] == -6.5 and game.simulation.camera_position[2] == 9.75)
game = run_init(base.administratorio_biter_station, {'factorio-logo-11tiles'}, available)
assert(game.simulation.camera_position[1] == -4.1484375 and game.simulation.camera_position[2] == 25.26953125)
print('Menu simulation logo initialization: PASS')
