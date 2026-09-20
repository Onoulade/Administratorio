-------------------------------------------------------------------------------
-- ADMINISTRATORIO ORPHANED WORKER TESTS
-------------------------------------------------------------------------------

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

defines = {
  direction = {north = 0, east = 2, south = 4, west = 6},
  alert_type = {custom = 1},
}

local C = require("scripts.constants")
local orphaned_worker = require("scripts.orphaned_worker")

local function assert_true(value, message)
  if not value then error(message or "assertion failed", 2) end
end

local alert, removed = nil, false
local player = {valid = true}
function player.add_custom_alert(entity, icon, message, show_on_map)
  alert = {entity = entity, icon = icon, message = message, show_on_map = show_on_map}
end
function player.remove_alert(params)
  removed = params.entity ~= nil and params.type == defines.alert_type.custom
end

local force = {players = {player}}
local entity = {
  valid = true,
  position = {x = 12.5, y = -4.25},
  surface = {name = "nauvis"},
}
local state = {}

orphaned_worker.begin(state, entity, "logistics", 100, force)
assert_true(alert ~= nil, "orphaning should raise a custom player alert")
assert_true(alert.icon.name == "biter-logistics-formation", "alert should identify the stranded worker type")
assert_true(alert.message[1] == "message.orphaned-worker-alert", "alert should use the orphan recovery message")
assert_true(alert.show_on_map == true, "orphan alert should be visible on the map")

state.orphan_frustration = C.PROTEST_THRESHOLD - 1
state.orphan_frust_accum = 0
state.orphan_last_frustration_tick = 100
assert_true(not orphaned_worker.update(state, entity, "logistics", 160, force),
  "the slowest frustration tier should not protest before earning a full point")
assert_true(orphaned_worker.update(state, entity, "logistics", 220, force),
  "the orphan should protest after the normal frustration threshold is reached")

assert_true(not orphaned_worker.should_retry(state, 699), "blocked homes should wait for the retry interval")
assert_true(orphaned_worker.should_retry(state, 700), "blocked homes should retry after ten seconds")

orphaned_worker.clear(state, entity, force)
assert_true(removed, "recovering or protesting should remove the orphan alert")
assert_true(state.orphan_frustration == nil and state.orphan_worker_kind == nil,
  "clearing recovery should discard orphan frustration state")

print("Orphaned worker tests: 1 passed, 0 failed")
