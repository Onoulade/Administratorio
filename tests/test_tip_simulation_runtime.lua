-------------------------------------------------------------------------------
-- ADMINISTRATORIO TIPS SIMULATION RUNTIME TESTS
--
-- Executes every unique declarative scene through a complete loop using small
-- mocks of the Factorio rendering/runtime API. This catches broken timelines,
-- invalid state transitions, and drift between the data-stage serializer and
-- the shared runtime update file without needing to open the Tips GUI.
-------------------------------------------------------------------------------

local passed, failed, errors = 0, 0, {}

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    errors[#errors + 1] = name .. ": " .. tostring(err)
  end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

local function new_render_object()
  return {
    valid = true,
    set_corners = function(left_top, right_bottom)
      assert(type(left_top) == "table" and type(right_bottom) == "table", "bar corners must be positions")
    end,
  }
end

local function reset_runtime()
  storage = {}
  helpers = {is_valid_sprite_path = function() return true end}
  rendering = {
    draw_sprite = function() return new_render_object() end,
    draw_text = function() return new_render_object() end,
    draw_line = function() return new_render_object() end,
    draw_rectangle = function() return new_render_object() end,
  }

  local entity_prototypes = setmetatable({}, {
    __index = function(_, name)
      local prototype_type = (name:find("biter", 1, true) and "unit") or "assembling-machine"
      return {name = name, type = prototype_type}
    end,
  })
  prototypes = {entity = entity_prototypes}

  local surface = {
    create_entity = function(options)
      return {
        name = options.name,
        valid = true,
        destructible = true,
        operable = true,
        rotatable = true,
        active = true,
      }
    end,
  }
  local force = {set_cease_fire = function() end}
  game = {
    surfaces = {[1] = surface},
    forces = {player = force, enemy = force},
    simulation = {},
    tick_paused = false,
  }
end

local simulations = require("prototypes.tips-and-tricks-simulations")
local update_path = mod_root .. "prototypes/tips-and-tricks-simulation-update.lua"
local unique_scenes = {}
for tip_name, simulation in pairs(simulations) do
  unique_scenes[simulation.init] = unique_scenes[simulation.init] or {tip_name = tip_name, simulation = simulation}
end

for _, entry in pairs(unique_scenes) do
  test(entry.tip_name .. " completes a full animation loop", function()
    reset_runtime()
    local init_chunk = assert(load(entry.simulation.init, "tips-simulation-init"))
    init_chunk()
    for _ = 1, entry.simulation.length + 1 do dofile(update_path) end
    assert(storage.administratorio_tip_runtime, "scene should initialize runtime state")
    assert(storage.administratorio_tip_runtime.tick == 1, "scene should wrap cleanly to tick 1")
  end)
end

print(("Tips simulation runtime tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do print(" - " .. err) end
  os.exit(1)
end
