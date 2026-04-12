-------------------------------------------------------------------------------
-- RESOURCES
-- Bullshit Ore:     solid, mineable, starting area -- base of BS economy
-- Politician Fluid: infinite fluid, pumpjack -- yields lies + credentials
-- Redundant Rubble: solid, mineable, starting area -- bureaucratic filler
-------------------------------------------------------------------------------
local feature_flags = require("feature_flags")
local resource_autoplace = require("resource-autoplace")
local planets = require("prototypes.shared.space_age_planets")

data:extend({
  {
    type = "resource", name = "bullshit-ore",
    icon = "__administratorio__/graphics/icons/bullshit-ore.png", icon_size = 64,
    flags = {"placeable-neutral"}, order="a-b-a",
    tree_removal_probability = 0.7, tree_removal_max_distance = 32 * 32,
    minable = {mining_particle = "stone-particle", mining_time = 1, result = "bullshit-ore"},
    collision_box = {{-0.1, -0.1}, {0.1, 0.1}},
    selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
    autoplace = resource_autoplace.resource_autoplace_settings{
      name = "bullshit-ore",
      order = "b-a",
      base_density = 8,
      base_spots_per_km2 = 2.0,
      has_starting_area_placement = true,
      regular_rq_factor_multiplier = 1.1,
      starting_rq_factor_multiplier = 1.5,
      candidate_spot_count = 20,
    },
    stage_counts = {15000, 8000, 2400, 800, 400, 150, 80, 20},
    stages = {
      sheet = {
        filename = "__administratorio__/graphics/entities/bullshit-ore/rare-metal-ore.png",
        priority = "extra-high",
        width = 128, height = 128,
        frame_count = 8, variation_count = 8,
        scale = 0.5
      }
    },
    map_color = {r=0.6, g=0.2, b=0.8}
  },
  {
    type = "resource", name = "politician-fluid",
    icon = "__administratorio__/graphics/icons/politician-fluid.png", icon_size = 64,
    flags = {"placeable-neutral"}, category = "basic-fluid", order="a-b-b",
    infinite = true, highlight = true,
    minimum = 60000, normal = 300000,
    infinite_depletion_amount = 10, resource_patch_search_radius = 12,
    map_grid = false,
    minable = {mining_time = 1, results = {{type="fluid", name="politician-fluid", amount_min=10, amount_max=10, probability=1}}},
    collision_box = {{-1.4, -1.4}, {1.4, 1.4}},
    selection_box = {{-1, -1}, {1, 1}},
    autoplace = resource_autoplace.resource_autoplace_settings{
      name = "politician-fluid",
      order = "b-b",
      base_density = 8.2,
      base_spots_per_km2 = 1.8,
      random_probability = 1 / 48,
      random_spot_size_minimum = 1,
      random_spot_size_maximum = 1,
      additional_richness = 220000,
      has_starting_area_placement = false,
      regular_rq_factor_multiplier = 1,
    },
    stage_counts = {0},
    stages = {
      sheet = {
        filename = "__base__/graphics/entity/crude-oil/crude-oil.png",
        priority = "extra-high",
        width = 148, height = 120,
        frame_count = 1, variation_count = 1,
        scale = 0.5, tint = {r=0.7, g=0.1, b=0.1}
      }
    },
    map_color = {r=0, g=0.4, b=1}
  },
  {
    type = "resource", name = "redundant-rubble",
    icon = "__administratorio__/graphics/icons/redundant-rubble.png", icon_size = 64,
    flags = {"placeable-neutral"}, order="a-b-c",
    tree_removal_probability = 1.0, tree_removal_max_distance = 32 * 32,
    minable = {mining_particle = "stone-particle", mining_time = 1.5, result = "redundant-rubble"},
    collision_box = {{-0.1, -0.1}, {0.1, 0.1}},
    selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
    autoplace = resource_autoplace.resource_autoplace_settings{
      name = "redundant-rubble",
      order = "b-c",
      base_density = 4,
      base_spots_per_km2 = 2.0,
      has_starting_area_placement = true,
      regular_rq_factor_multiplier = 0.7,
      starting_rq_factor_multiplier = 1.0,
      candidate_spot_count = 15,
      additional_richness = 100,
    },
    stage_counts = {10000, 5000, 1500, 500, 200, 100, 50, 10},
    stages = {
      sheet = {
        filename = "__base__/graphics/entity/stone/stone.png",
        priority = "extra-high",
        width = 128, height = 128,
        frame_count = 8, variation_count = 8,
        scale = 0.5, tint = {r=0.8, g=0.2, b=0.2}
      }
    },
    map_color = {r=1, g=0.3, b=0.3}
  }
})

data:extend({
  planets.apply_planet_surface_conditions({
    type = "resource", name = "amber-sap-seep",
    icon = "__administratorio__/graphics/icons/coffee.png", icon_size = 64,
    flags = {"placeable-neutral"}, category = "basic-fluid", order = "a-b-d",
    infinite = true, highlight = true,
    minimum = 60000, normal = 300000,
    infinite_depletion_amount = 10, resource_patch_search_radius = 12,
    map_grid = false,
    minable = {
      mining_time = 1,
      results = {{
        type = "fluid",
        name = "amber-sap",
        amount_min = 10,
        amount_max = 10,
        probability = 1
      }}
    },
    collision_box = {{-1.4, -1.4}, {1.4, 1.4}},
    selection_box = {{-1, -1}, {1, 1}},
    autoplace = resource_autoplace.resource_autoplace_settings{
      name = "amber-sap-seep",
      autoplace_control_name = "gleba_amber_sap_seep",
      order = "b-d",
      base_density = 7.5,
      base_spots_per_km2 = 1.8,
      random_probability = 1 / 48,
      random_spot_size_minimum = 1,
      random_spot_size_maximum = 1,
      additional_richness = 220000,
      has_starting_area_placement = false,
      regular_rq_factor_multiplier = 1.0,
    },
    stage_counts = {0},
    stages = {
      sheet = {
        filename = "__base__/graphics/entity/crude-oil/crude-oil.png",
        priority = "extra-high",
        width = 148, height = 120,
        frame_count = 1, variation_count = 1,
        scale = 0.5, tint = {r=0.9, g=0.65, b=0.15}
      }
    },
    map_color = {r=0.85, g=0.55, b=0.12}
  }, "gleba"),
  planets.apply_planet_surface_conditions({
    type = "resource", name = "verdigris-crust",
    icons = {
      {icon = "__administratorio__/graphics/icons/bullshit-ore.png", icon_size = 64, tint = {r = 0.25, g = 0.9, b = 0.75, a = 1}},
    },
    flags = {"placeable-neutral"}, order="a-b-d",
    tree_removal_probability = 0.5, tree_removal_max_distance = 32 * 32,
    minable = {mining_particle = "stone-particle", mining_time = 1.2, result = "verdigris-crust"},
    collision_box = {{-0.1, -0.1}, {0.1, 0.1}},
    selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
    autoplace = resource_autoplace.resource_autoplace_settings{
      name = "verdigris-crust",
      autoplace_control_name = "vulcanus_verdigris_crust",
      order = "b-d",
      base_density = 6,
      base_spots_per_km2 = 2.0,
      has_starting_area_placement = true,
      regular_rq_factor_multiplier = 1.0,
      starting_rq_factor_multiplier = 1.0,
      candidate_spot_count = 15,
    },
    stage_counts = {12000, 6000, 1800, 600, 240, 100, 50, 12},
    stages = {
      sheet = {
        filename = "__administratorio__/graphics/entities/bullshit-ore/rare-metal-ore.png",
        priority = "extra-high",
        width = 128, height = 128,
        frame_count = 8, variation_count = 8,
        scale = 0.5,
        tint = {r = 0.25, g = 0.9, b = 0.75, a = 1},
      }
    },
    map_color = {r=0.1, g=0.8, b=0.7}
  }, "vulcanus"),
})
