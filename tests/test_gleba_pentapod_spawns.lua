local mod_root = debug.getinfo(1, "S").source:match("@(.*/)"):gsub("tests/$", "")
package.path = mod_root .. "?.lua;" .. package.path

local apply = require("prototypes.final_fixes.gleba_pentapods").apply
local egg_hatch = {
  type = "create-entity",
  entity_name = "big-wriggler-pentapod-premature",
  non_colliding_fail_result = {
    type = "direct",
    action_delivery = {
      source_effects = {{type = "create-entity", entity_name = "big-wriggler-pentapod-premature"}},
    },
  },
}
local data_stage = {raw = {
  ["unit-spawner"] = {
    ["gleba-spawner"] = {
      result_units = {{"big-stomper-pentapod", {{0, 0}, {1, 1}}}},
      spawning_cooldown = {360, 150},
    },
    ["gleba-spawner-small"] = {
      result_units = {{"medium-wriggler-pentapod", {{0, 0}, {1, 1}}}},
      spawning_cooldown = {360, 150},
    },
  },
  item = {
    ["pentapod-egg"] = {
      spoil_to_trigger_result = {trigger = {action_delivery = {source_effects = {egg_hatch}}}},
    },
  },
}}

apply(data_stage)

local expected = {
  ["gleba-spawner"] = {
    ["small-wriggler-pentapod"] = 0.4,
    ["small-strafer-pentapod"] = 0.4,
    ["small-stomper-pentapod"] = 0.2,
  },
  ["gleba-spawner-small"] = {["small-wriggler-pentapod"] = 0.9},
}

for name, units in pairs(expected) do
  local spawner = data_stage.raw["unit-spawner"][name]
  assert(spawner.spawning_cooldown[1] == 360 and spawner.spawning_cooldown[2] == 150,
    name .. " must spawn faster as evolution rises")
  local seen = {}
  for _, result in ipairs(spawner.result_units) do
    local unit, curve = result[1], result[2]
    assert(units[unit], name .. " spawned a non-small pentapod: " .. unit)
    assert(curve[1][2] == units[unit] and curve[#curve][2] == units[unit],
      name .. " changed its small-unit mix with evolution")
    seen[unit] = true
  end
  for unit in pairs(units) do assert(seen[unit], name .. " is missing " .. unit) end
end

assert(egg_hatch.entity_name == "small-wriggler-pentapod-premature")
assert(egg_hatch.non_colliding_fail_result.action_delivery.source_effects[1].entity_name
  == "small-wriggler-pentapod-premature")

apply({raw = {}}) -- Base-only startup has none of these Space Age prototypes.
print("Gleba pentapod spawns: passed")
