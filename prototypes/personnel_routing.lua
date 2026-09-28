-- Native units provide walking animations; runtime owns lane motion and cargo.
if not require("feature_flags").space_age_enabled() then return end
local R = require("prototypes.shared.personnel_routing")
local personnel_colors = require("prototypes.shared.personnel_colors")
local office_sprites = require("prototypes.shared.personnel_office_sprites")
local graphics = "__administratorio__/graphics/entities/personnel-routing/"
local function sprite(name)
  if office_sprites[name] then return table.deepcopy(office_sprites[name]) end
  local sign=name:find("^sign%-")
  return {filename = graphics .. name .. ".png", width = sign and 160 or 128, height = sign and 256 or 128,
    scale = 0.5, shift = sign and {0,-1.5} or nil}
end
local function directions(name)
  return {north = sprite(name .. "-north"), east = sprite(name .. "-east"),
    south = sprite(name .. "-south"), west = sprite(name .. "-west")}
end
local prototypes_to_add = {
  {type = "collision-layer", name = "administratorio_personnel_reserved"},
  {type = "collision-layer", name = "administratorio_personnel_obstacle"},
  {type = "collision-layer", name = "administratorio_personnel_offroad"},
  {type = "collision-layer", name = "administratorio_personnel_unit"},
  {type = "collision-layer", name = "administratorio_personnel_pavement"},
  {type = "recipe-category", name = R.CATEGORY},
}
local tile = table.deepcopy(data.raw.tile["concrete"])
tile.name = R.TILE
tile.localised_name = {"entity-name." .. R.ROAD}
tile.minable = nil
tile.next_direction = nil
tile.placeable_by = nil
tile.map_color = {r = 0.40, g = 0.65, b = 0.61}
tile.tint = {r = 0.55, g = 0.82, b = 0.75, a = 1}
tile.decorative_removal_probability = 1
tile.autoplace = nil
tile.hidden_in_factoriopedia = true
prototypes_to_add[#prototypes_to_add + 1] = tile
local effects = {}
for i, name in ipairs(R.names) do
  local role = R.roles[name]
  local entity = {
    type = (role == "input" or role == "output") and "furnace" or "simple-entity-with-owner",
    name = name, icon = graphics .. role .. "-icon.png", icon_size = 64,
    flags = {"placeable-player", "player-creation"},
    minable = {mining_time = 0.2, result = name},
    max_health = 350,
    collision_box = {{-0.99, -0.99}, {0.99, 0.99}},
    selection_box = {{-1, -1}, {1, 1}},
    -- Keep signs and office inventories selectable under waiting proxies.
    selection_priority = role ~= "road" and 60 or nil,
    hidden_in_factoriopedia = role == "road",
    tile_width = 2, tile_height = 2,
    build_grid_size = 2,
    collision_mask = {layers = {administratorio_personnel_reserved = true}, not_colliding_with_itself = true},
    tile_buildability_rules = {{area = {{-0.99, -0.99}, {0.99, 0.99}},
      required_tiles = {layers = {ground_tile = true}}, colliding_tiles = {layers = {water_tile = true}}}},
    map_color = {r = 0.55, g = 0.80, b = 0.70},
  }
  if role == "road" then
    entity.icon = "__base__/graphics/icons/concrete.png"
    entity.icons = {{icon = entity.icon, icon_size = 64, tint = table.deepcopy(tile.tint)}}
  end
  if role=="output" then entity.flags[#entity.flags+1]="not-rotatable" end
  if entity.type == "furnace" then
    entity.crafting_categories = {R.CATEGORY}
    entity.crafting_speed = 0.001
    entity.energy_usage = "1W"
    entity.energy_source = {type = "void"}
    if role=="input" then
      -- Only deployment needs a direction. Reception accepts all four sides.
      entity.fluid_boxes = {{production_type = "input", volume = 1, hide_connection_info = true,
        pipe_connections = {{flow_direction = "input", direction = defines.direction.north, position = {-0.5, -0.5}}}}}
      entity.fluid_boxes_off_when_no_fluid_recipe = true
    end
    entity.source_inventory_size = 1
    entity.result_inventory_size = 8
    entity.module_slots = 0
    entity.allowed_effects = {}
    entity.show_recipe_icon = false
    entity.show_recipe_icon_on_map = false
    entity.graphics_set = {animation = role=="output" and sprite("output") or directions(role)}
  else
    -- The actual vanilla concrete tile supplies texture and seamless borders.
    -- This selectable entity only owns the protected 2x2 pavement block.
    entity.picture = role == "road" and {filename = "__core__/graphics/empty.png", width = 1, height = 1} or directions(role)
    entity.render_layer = role == "road" and "floor" or "object"
    if role == "road" then entity.flags[#entity.flags + 1] = "not-rotatable" end
  end
  prototypes_to_add[#prototypes_to_add + 1] = entity
  prototypes_to_add[#prototypes_to_add + 1] = {
    type = "item", name = name, icon = entity.icon, icon_size = 64,
    icons = entity.icons and table.deepcopy(entity.icons),
    subgroup = "admin-biter-logistics", order = "z-routing-" .. i, stack_size = 100,
    hidden = role == "road", hidden_in_factoriopedia = role == "road",
    place_result = role ~= "road" and name or nil,
  }
  local ingredients = (role == "input" or role == "output") and {
    {type = "item", name = "steel-plate", amount = 10},
    {type = "item", name = "advanced-circuit", amount = 5},
    {type = "item", name = "yellow-magenta-form", amount = 2},
  } or role == "sign" and {
    {type = "item", name = "iron-plate", amount = 2},
    {type = "item", name = "yellow-magenta-form", amount = 1},
  } or {
    {type = "item", name = "concrete", amount = 4},
    {type = "item", name = "iron-stick", amount = 2},
  }
  prototypes_to_add[#prototypes_to_add + 1] = {
    type = "recipe", name = name, enabled = false, energy_required = 2,
    ingredients = ingredients, results = {{type = "item", name = name, amount = 1}},
    hidden = role == "road", hidden_in_factoriopedia = role == "road",
  }
  if role ~= "road" then effects[#effects + 1] = {type = "unlock-recipe", recipe = name} end
end
local recovery = table.deepcopy(data.raw.container["steel-chest"])
recovery.name = R.RECOVERY
recovery.localised_name = {"entity-name." .. R.RECOVERY}
recovery.localised_description = {"entity-description." .. R.RECOVERY}
recovery.minable = {mining_time = 0.2, result = "steel-chest"}
recovery.hidden_in_factoriopedia = true
recovery.inventory_size = 48
prototypes_to_add[#prototypes_to_add + 1] = recovery
local cargo_names = {}
for item in pairs(R.cargo) do if data.raw.item[item] then cargo_names[#cargo_names + 1] = item end end
table.sort(cargo_names)
local function tint_body(animation, color)
  if type(animation) ~= "table" then return end
  local filename = animation.filename or (animation.filenames and animation.filenames[1])
  if filename and filename:find("biter%-.*%-mask[12]") and not animation.draw_as_shadow then
    -- Native units do not support runtime colors. Recolor their carapace
    -- masks while preserving body detail, shadows and the worker's helmet.
    animation.tint = table.deepcopy(color)
    animation.apply_runtime_tint = nil
  end
  for _, child in pairs(animation) do
    if type(child) == "table" then tint_body(child, color) end
  end
end
for _, item in ipairs(cargo_names) do
  assert(personnel_colors.colors[item], "Personnel tint missing for " .. item)
  local unit = table.deepcopy(data.raw.unit["worker-biter-t1"] or data.raw.unit["small-biter"])
  unit.name = R.unit_name(item)
  unit.localised_name = {"item-name." .. item}
  unit.localised_description = {"entity-description.personnel-in-transit"}
  unit.minable = nil
  unit.placeable_by = nil
  unit.flags = {"placeable-off-grid", "not-on-map"}
  unit.hidden_in_factoriopedia = true
  tint_body(unit.run_animation, personnel_colors.colors[item])
  tint_body(unit.attack_parameters.animation, personnel_colors.colors[item])
  -- Keep the walking body visible when waiting over office/sign artwork.
  unit.render_layer = "higher-object-above"
  -- The native animation proxy has a narrow navigation core. Saved lane
  -- positions and reservations enforce the full 2x2 body independently.
  unit.collision_box = {{-0.01, -0.01}, {0.01, 0.01}}
  unit.selection_box = {{-1, -1}, {1, 1}}
  unit.collision_mask = {layers = {
    administratorio_personnel_unit = true, administratorio_personnel_offroad = true,
    administratorio_personnel_obstacle = true,
  }}
  unit.has_belt_immunity = true
  unit.movement_speed = data.raw.unit["small-biter"].movement_speed
  unit.vision_distance = 0
  unit.max_pursue_distance = 0
  unit.min_pursue_time = 0
  unit.ai_settings = {destroy_when_commands_fail = false, allow_try_return_to_spawner = false, join_attacks = false, do_separation = false, path_resolution_modifier = 0}
  unit.attack_parameters.range = 0.01
  unit.attack_parameters.damage_modifier = 0
  unit.attack_parameters.cooldown = 216000
  prototypes_to_add[#prototypes_to_add + 1] = unit
  prototypes_to_add[#prototypes_to_add + 1] = {
    type = "recipe", name = R.load_recipe(item), category = R.CATEGORY,
    enabled = false, hidden = true, hide_from_player_crafting = true,
    hide_from_signal_gui = true, hidden_in_factoriopedia = true,
    allow_productivity = false, auto_recycle = false, energy_required = 1000000,
    ingredients = {{type = "item", name = item, amount = 1}},
    results = {{type = "item", name = item, amount = 1}},
  }
  effects[#effects + 1] = {type = "unlock-recipe", recipe = R.load_recipe(item), hidden = true}
end
prototypes_to_add[#prototypes_to_add + 1] = {
  type = "technology", name = "personnel-routing",
  icon = graphics .. "sign-icon.png", icon_size = 64,
  prerequisites = {"yellow-magenta-bureaucracy", "biter-employment", "utility-science-pack"},
  unit = {count = 400, time = 45, ingredients = {
    {"administrative-science-pack", 1}, {"utility-science-pack", 1}, {"agricultural-science-pack", 1}, {"electromagnetic-science-pack", 1},
  }}, effects = effects, order = "h-e4",
}
data:extend(prototypes_to_add)
