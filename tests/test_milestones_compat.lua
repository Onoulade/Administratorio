local root = debug.getinfo(1, "S").source:match("@(.*/)"):gsub("tests/$", "")
package.path = root .. "?.lua;" .. package.path

local interfaces = {}
remote = {add_interface = function(name, interface) interfaces[name] = interface end}
script = {active_mods = {administratorio = "0.8.2"}}
local integration = require("compat.milestones.runtime")
assert(next(interfaces) == nil, "no interface needed without Milestones")
script.active_mods.Milestones = "1.5.2"
package.loaded["compat.milestones.runtime"] = nil
require("compat.milestones.runtime")
assert(interfaces["administratorio-milestones"].milestones_presets == integration.presets)

prototypes = {
  item = { ["solar-panel"] = {}, ["worker-biter"] = {}, ["administrative-science-pack"] = {},
    ["ai-server"] = {}, ["quality-module"] = {}, ["power-armor-mk2"] = {},
    ["resolved-landscape"] = {}, ["overtime-exemption"] = {} },
  fluid = {["petroleum-gas"] = {}},
  technology = {}, quality = {normal = {}, rare = {}},
}

local function find(preset, kind, name, quality)
  for _, milestone in ipairs(preset.milestones) do
    if milestone.type == kind and milestone.name == name and milestone.quality == quality then return milestone end
  end
end

local presets = integration.presets()
local base = assert(presets.Administratorio)
assert(#base.required_mods == 1 and base.required_mods[1] == "administratorio")
assert(find(base, "item", "solar-panel"))
assert(find(base, "fluid", "petroleum-gas"))
assert(find(base, "item_consumption", "resolved-landscape"), "cases track closure, not just production")
assert(not find(base, "item", "ai-server"), "exclude expansion placeholders in base-only")
assert(not find(base, "item", "quality-module", "rare"), "Quality is optional")
assert(not find(base, "item", "paper"), "missing prototypes must not create impossible goals")

script.active_mods.quality = "2.0.77"
local quality = integration.presets().Administratorio
assert(find(quality, "item", "power-armor-mk2", "rare"), "Quality also works without Space Age")
assert(not find(quality, "item", "quality-module", "rare"), "do not duplicate Milestones' built-in Quality addon")
assert(#quality.required_mods == 2)
script.active_mods["space-age"] = "2.0.77"
local expanded = integration.presets()["Administratorio (Space Age)"]
assert(expanded and #expanded.required_mods == 3, "expansion preset wins over native presets")
assert(find(expanded, "item", "ai-server"))
assert(find(expanded, "item", "quality-module", "rare"), "Space Age disables the native Quality addon")

-- The remote caller may mutate its return value; subsequent calls must get
-- fresh milestone tables, including repeating thresholds and optional flags.
expanded.milestones[1].name = "mutated"
assert(integration.presets()["Administratorio (Space Age)"].milestones[1].name == "Science")
prototypes.item["overtime-exemption"] = nil
assert(not find(integration.presets()["Administratorio (Space Age)"], "item", "overtime-exemption"),
  "Working Hours-disabled content must be omitted")

print("Milestones compatibility: optional loading, base/Space Age/Quality selection, prototype guards and fresh tables passed")
