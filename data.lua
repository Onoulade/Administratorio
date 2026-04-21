-- ADMINISTRATORIO: CENTRAL DATA DEFINITION
--
-- This file does three things in order:
--   1. Registers autoplace controls and loads all mod prototypes
--   2. Enforces the administrative paradigm via vanilla overrides
--   3. Registers debug-only custom input

-------------------------------------------------------------------------------
-- 1. AUTOPLACE CONTROLS (must be registered before resources reference them)
-------------------------------------------------------------------------------
local ADMIN_STATION_COLLISION_LAYER = "administratorio_station_footprint"

data:extend({
  {
    type = "collision-layer",
    name = ADMIN_STATION_COLLISION_LAYER
  },
  {
    type = "autoplace-control",
    name = "bullshit-ore",
    icon = "__administratorio__/graphics/icons/bullshit-ore.png",
    icon_size = 64,
    richness = true,
    order = "b-a",
    category = "resource"
  },
  {
    type = "autoplace-control",
    name = "politician-fluid",
    icon = "__administratorio__/graphics/icons/politician-fluid.png",
    icon_size = 64,
    richness = true,
    order = "b-b",
    category = "resource"
  },
  {
    type = "autoplace-control",
    name = "redundant-rubble",
    icon = "__administratorio__/graphics/icons/redundant-rubble.png",
    icon_size = 64,
    richness = true,
    order = "b-c",
    category = "resource"
  }
})

-------------------------------------------------------------------------------
-- 2. LOAD ALL MOD PROTOTYPES
-------------------------------------------------------------------------------
require("prototypes.item")
require("prototypes.tiles")
require("prototypes.entity")
require("prototypes.recipe")
require("prototypes.technology")
require("prototypes.signals")
require("prototypes.sounds")
require("prototypes.tips-and-tricks")
require("prototypes.achievements")

-------------------------------------------------------------------------------
-- 3. VANILLA OVERRIDES (hide military, pacify biters, replace science, etc.)
-------------------------------------------------------------------------------
require("overrides.vanilla")

-------------------------------------------------------------------------------
-- 4. CUSTOM INPUTS
-------------------------------------------------------------------------------
data:extend({{
  type = "custom-input",
  name = "administratorio-toggle-runtime-debug",
  key_sequence = "CONTROL + SHIFT + D",
  consuming = "none"
}, {
  type = "custom-input",
  name = "administratorio-field-agent-toggle-select",
  key_sequence = "mouse-button-1",
  consuming = "none",
  action = "lua"
}, {
  type = "custom-input",
  name = "administratorio-field-agent-set-waypoint",
  key_sequence = "mouse-button-2",
  consuming = "none",
  action = "lua"
}, {
  type = "custom-input",
  name = "administratorio-field-agent-append-waypoint",
  key_sequence = "SHIFT + mouse-button-2",
  consuming = "none",
  action = "lua"
}})
