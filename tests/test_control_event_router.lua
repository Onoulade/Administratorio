-------------------------------------------------------------------------------
-- CONTROL EVENT ROUTER TESTS
-------------------------------------------------------------------------------

local passed, failed, errors = 0, 0, {}
local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then passed = passed + 1 else failed = failed + 1; errors[#errors + 1] = name .. ": " .. tostring(err) end
end
local function assert_true(value, message) if not value then error(message or "assertion failed", 2) end end
local function assert_eq(actual, expected, message)
  if actual ~= expected then error((message or "") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)"):gsub("tests/$", "")
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

local registrations, ticks = {}, {}
script = {
  on_init = function(handler) registrations.init = handler end,
  on_configuration_changed = function(handler) registrations.configuration = handler end,
  on_load = function(handler) registrations.load = handler end,
  on_event = function(event, handler) registrations[event] = handler end,
  on_nth_tick = function(interval, handler) ticks[interval] = handler end,
}
defines = {events = setmetatable({}, {__index = function(table, key) table[key] = key; return key end})}

local function handler(name)
  return function() registrations.called = (registrations.called or "") .. name end
end

test("router registers lifecycle, event, and custom handlers", function()
  local router = require("scripts.control_event_router")
  router.register({
    on_init = handler("init"), on_configuration_changed = handler("config"), on_load = handler("load"),
    on_runtime_mod_setting_changed = handler("setting"), on_player_created = handler("created"),
    on_player_respawned = handler("respawn"), on_player_joined_game = handler("join"), on_player_left_game = handler("left"),
    on_player_crafted_item = handler("craft"), on_player_cursor_stack_changed = handler("cursor"),
    on_selected_entity_changed = handler("selected"), on_player_selected_area = handler("area"), on_pre_build = handler("prebuild"),
    on_entity_built = handler("built"), on_entity_removed = handler("removed"), on_toggle_runtime_debug = handler("debug"),
    on_toggle_complaint_locator = handler("locator"), on_unit_group_created = handler("group"), on_entity_died = handler("died"),
    on_script_trigger_effect = handler("effect"), on_ai_command_completed = handler("ai"), on_tick = handler("tick"),
    on_train_changed_state = handler("train"), on_rocket_launched = handler("rocket"), on_gui_click = handler("click"),
    on_gui_closed = handler("closed"), on_research_finished = handler("research"),
    on_pneumatic_tick = handler("pneumatic"), terminus_check_ticks = 15, on_interplanetary_tube_tick = handler("tube"),
    ai_server_check_ticks = 15, on_ai_server_tick = handler("ai-server"), on_main_tick = handler("main"),
  })
  assert_true(registrations.init and registrations.configuration and registrations.load)
  assert_true(registrations[defines.events.on_entity_died] ~= nil)
  assert_true(registrations["administratorio-toggle-runtime-debug"] ~= nil)
end)

test("router fan-outs handlers sharing a cadence", function()
  assert_true(ticks[15] ~= nil, "shared cadence should have a dispatcher")
  registrations.called = ""
  ticks[15]({tick = 15})
  assert_true(registrations.called:find("pneumatic", 1, true) ~= nil)
  assert_true(registrations.called:find("tube", 1, true) ~= nil)
  assert_true(registrations.called:find("ai-server", 1, true) ~= nil)
end)

print(("Control event router tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then for _, err in ipairs(errors) do print(" - " .. err) end; os.exit(1) end
