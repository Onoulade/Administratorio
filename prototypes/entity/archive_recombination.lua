local planets = require("prototypes.shared.space_age_planets")
local taxonomy = require("prototypes.shared.paperwork_taxonomy")

local bureau = table.deepcopy(data.raw.lab["lab"])
bureau.name = "archive-recombination-bureau"
bureau.icons = {
  {icon = "__administratorio__/graphics/icons/office-building.png", icon_size = 64, tint = {r = 0.75, g = 0.58, b = 0.86, a = 1}},
  {icon = "__administratorio__/graphics/icons/redundant-rubble.png", icon_size = 64, scale = 0.32, shift = {8, 8}},
}
bureau.icon = nil
bureau.minable = {mining_time = 0.5, result = "archive-recombination-bureau"}
bureau.placeable_by = {{item = "archive-recombination-bureau", count = 1}}
bureau.inputs = taxonomy.recyclable_names()
bureau.researching_speed = 1
bureau.energy_usage = "1W"
bureau.energy_source.buffer_capacity = "2MJ"
bureau.energy_source.input_flow_limit = "1W"
bureau.energy_source.drain = "0W"
bureau.module_slots = 0
bureau.allowed_effects = {}
bureau.fast_replaceable_group = nil
bureau.next_upgrade = nil
bureau.rotatable = false
bureau.trash_inventory_size = 0
bureau.localised_name = {"entity-name.archive-recombination-bureau"}
bureau.localised_description = {"entity-description.archive-recombination-bureau"}
planets.require_non_vacuum_surface(bureau)

local power_sink = {
  type = "electric-energy-interface",
  name = "archive-recombination-power-sink",
  icons = bureau.icons,
  flags = {"not-on-map", "not-blueprintable", "not-deconstructable", "not-flammable"},
  hidden = true,
  selectable_in_game = false,
  max_health = 1,
  collision_mask = {layers = {}},
  collision_box = {{0, 0}, {0, 0}},
  selection_box = {{0, 0}, {0, 0}},
  gui_mode = "none",
  allow_copy_paste = false,
  energy_source = {
    type = "electric",
    usage_priority = "secondary-input",
    buffer_capacity = "1MJ",
    input_flow_limit = "1MW",
    drain = "0W",
  },
  energy_production = "0W",
  energy_usage = "1MW",
  picture = {
    filename = "__core__/graphics/empty.png",
    width = 1,
    height = 1,
  },
}

data:extend({bureau, power_sink})
