-- Shared runtime renderer for the declarative Tips & Tricks scenes.
-- This file is executed once per simulation update, so persistent values live
-- in storage.administratorio_tip_runtime.

local scene = storage.administratorio_tip_scene
if not scene then return end

local runtime = storage.administratorio_tip_runtime
local surface = game.surfaces[1]

local function valid_sprite(path)
  return path and helpers.is_valid_sprite_path(path)
end

local function draw_sprite(definition, position)
  if not valid_sprite(definition.sprite) then return nil end
  local scale = definition.scale or 0.5
  return rendering.draw_sprite{
    sprite = definition.sprite,
    target = position or {definition.x, definition.y},
    surface = surface,
    x_scale = scale,
    y_scale = scale,
    tint = definition.tint,
    orientation = definition.orientation,
    blink_interval = definition.blink,
    render_layer = definition.render_layer or "object",
  }
end

local function draw_text(definition)
  return rendering.draw_text{
    text = definition.text or "",
    target = {definition.x, definition.y},
    surface = surface,
    color = definition.color or {1, 1, 1, 1},
    scale = definition.scale or 0.9,
    alignment = definition.alignment or "left",
    vertical_alignment = definition.vertical_alignment or "middle",
    use_rich_text = false,
  }
end

local function within(intervals, tick)
  if not intervals then return true end
  for _, interval in ipairs(intervals) do
    if tick >= interval[1] and tick <= interval[2] then return true end
  end
  return false
end

local function frame_value(frames, tick, key, fallback)
  local value = fallback
  for _, frame in ipairs(frames or {}) do
    if tick < frame.at then break end
    if frame[key] ~= nil then value = frame[key] end
  end
  return value
end

local function interpolated_value(keyframes, tick, stepped)
  if not keyframes or #keyframes == 0 then return 0 end
  local previous = keyframes[1]
  if tick <= previous.at then return previous.value end
  for index = 2, #keyframes do
    local following = keyframes[index]
    if tick <= following.at then
      if stepped or following.at == previous.at then return previous.value end
      local progress = (tick - previous.at) / (following.at - previous.at)
      return previous.value + (following.value - previous.value) * progress
    end
    previous = following
  end
  return previous.value
end

local function path_position(points, tick)
  if not points or #points == 0 then return {0, 0} end
  local previous = points[1]
  if tick <= previous.tick then return {previous.x, previous.y} end
  for index = 2, #points do
    local following = points[index]
    if tick <= following.tick then
      local progress = (tick - previous.tick) / math.max(1, following.tick - previous.tick)
      return {
        previous.x + (following.x - previous.x) * progress,
        previous.y + (following.y - previous.y) * progress,
      }
    end
    previous = following
  end
  return {previous.x, previous.y}
end

local function mover_visible(definition, tick)
  local start_tick = definition.start or 0
  local finish_tick = definition.hold_until or definition.finish or scene.duration
  return tick >= start_tick and tick <= finish_tick
end

local function initialize()
  runtime = {
    tick = 0,
    entities = {},
    sprites = {},
    texts = {},
    movers = {},
    lines = {},
    bars = {},
    overlays = {},
  }
  storage.administratorio_tip_runtime = runtime

  game.simulation.camera_position = scene.camera or {0, 0}
  game.simulation.camera_zoom = scene.zoom or 1
  game.simulation.camera_alt_info = false
  game.simulation.hide_cursor = true
  game.tick_paused = false

  if game.forces.player and game.forces.enemy then
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
  end

  for _, definition in ipairs(scene.entities or {}) do
    local force = definition.force or "player"
    local prototype = prototypes.entity[definition.name]
    if prototype and (prototype.type == "unit-spawner" or prototype.type == "unit") then force = definition.force or "enemy" end

    local created = nil
    if prototype then
      local ok, result = pcall(function()
        return surface.create_entity{
          name = definition.name,
          position = {definition.x, definition.y},
          force = force,
          create_build_effect_smoke = false,
          raise_built = false,
        }
      end)
      if ok then created = result end
    end

    if created then
      pcall(function() created.destructible = false end)
      pcall(function() created.operable = false end)
      pcall(function() created.rotatable = false end)
      pcall(function() created.active = false end)
      runtime.entities[#runtime.entities + 1] = created
    else
      runtime.sprites[#runtime.sprites + 1] = {
        definition = definition,
        object = draw_sprite({sprite = "entity/" .. definition.name, scale = definition.scale or 0.85}, {definition.x, definition.y}),
      }
    end

    if definition.label then
      runtime.texts[#runtime.texts + 1] = {
        definition = {text = definition.label, x = definition.x, y = definition.y - 2.15, color = {0.9, 0.92, 0.95, 1}, scale = 0.72, alignment = "center"},
        object = draw_text{text = definition.label, x = definition.x, y = definition.y - 2.15, color = {0.9, 0.92, 0.95, 1}, scale = 0.72, alignment = "center"},
      }
    end
  end

  for _, definition in ipairs(scene.lines or {}) do
    local object = rendering.draw_line{
      color = definition.color or {1, 1, 1, 1},
      width = definition.width or 2,
      gap_length = definition.gap_length or 0,
      dash_length = definition.dash_length or 0,
      from = definition.from,
      to = definition.to,
      surface = surface,
      draw_on_ground = definition.draw_on_ground ~= false,
    }
    runtime.lines[#runtime.lines + 1] = {definition = definition, object = object}
  end

  for _, definition in ipairs(scene.sprites or {}) do
    runtime.sprites[#runtime.sprites + 1] = {definition = definition, object = draw_sprite(definition)}
  end

  for _, definition in ipairs(scene.texts or {}) do
    runtime.texts[#runtime.texts + 1] = {definition = definition, object = draw_text(definition)}
  end

  for _, definition in ipairs(scene.movers or {}) do
    local path = definition.sprite or (definition.entity and "entity/" .. definition.entity)
    local render_definition = {
      sprite = path,
      scale = definition.scale or 0.5,
      tint = definition.tint,
      orientation = definition.orientation,
      render_layer = "object",
    }
    runtime.movers[#runtime.movers + 1] = {
      definition = definition,
      object = draw_sprite(render_definition, path_position(definition.points, definition.start or 0)),
    }
  end

  for _, definition in ipairs(scene.bars or {}) do
    local half_width = definition.width / 2
    local half_height = (definition.height or 0.28) / 2
    rendering.draw_rectangle{
      color = {0.05, 0.05, 0.06, 0.9},
      filled = true,
      left_top = {definition.x - half_width, definition.y - half_height},
      right_bottom = {definition.x + half_width, definition.y + half_height},
      surface = surface,
    }
    local fill = rendering.draw_rectangle{
      color = definition.color,
      filled = true,
      left_top = {definition.x - half_width, definition.y - half_height},
      right_bottom = {definition.x - half_width, definition.y + half_height},
      surface = surface,
    }
    runtime.bars[#runtime.bars + 1] = {definition = definition, object = fill}
  end

  for _, definition in ipairs(scene.overlays or {}) do
    local object = rendering.draw_rectangle{
      color = definition.color,
      filled = true,
      left_top = {-20, -10},
      right_bottom = {20, 10},
      surface = surface,
    }
    runtime.overlays[#runtime.overlays + 1] = {definition = definition, object = object}
  end

  if scene.stage and #scene.stage > 0 then
    runtime.stage = rendering.draw_text{
      text = scene.stage[1].text,
      target = {0, -5.25},
      surface = surface,
      color = {1, 0.82, 0.25, 1},
      scale = 0.92,
      alignment = "center",
      vertical_alignment = "middle",
    }
  end
end

if not runtime then initialize() end

runtime.tick = (runtime.tick + 1) % scene.duration
local tick = runtime.tick

for _, entry in ipairs(runtime.sprites) do
  local definition = entry.definition
  local object = entry.object
  if object and object.valid then
    object.visible = within(definition.show, tick)
    if definition.frames then
      local next_sprite = frame_value(definition.frames, tick, "sprite", definition.sprite)
      if valid_sprite(next_sprite) then object.sprite = next_sprite end
    end
    if definition.pulse then
      local base_scale = definition.scale or 0.5
      local pulse = 1 + 0.1 * math.sin(tick / 8)
      object.x_scale = base_scale * pulse
      object.y_scale = base_scale * pulse
    end
  end
end

for _, entry in ipairs(runtime.texts) do
  local definition = entry.definition
  local object = entry.object
  if object and object.valid then
    object.visible = within(definition.show, tick)
    if definition.frames then object.text = frame_value(definition.frames, tick, "text", definition.text or "") end
  end
end

for _, entry in ipairs(runtime.lines) do
  if entry.object and entry.object.valid then entry.object.visible = within(entry.definition.show, tick) end
end

for _, entry in ipairs(runtime.movers) do
  local object = entry.object
  if object and object.valid then
    local definition = entry.definition
    object.visible = mover_visible(definition, tick)
    object.target = path_position(definition.points, tick)
    if definition.scale_frames then
      local scale = frame_value(definition.scale_frames, tick, "scale", definition.scale or 0.5)
      object.x_scale = scale
      object.y_scale = scale
    end
  end
end

for _, entry in ipairs(runtime.bars) do
  local definition = entry.definition
  local object = entry.object
  if object and object.valid then
    local value = math.max(0, math.min(1, interpolated_value(definition.keyframes, tick, definition.step)))
    local half_width = definition.width / 2
    local half_height = (definition.height or 0.28) / 2
    object.set_corners(
      {definition.x - half_width, definition.y - half_height},
      {definition.x - half_width + definition.width * value, definition.y + half_height}
    )
  end
end

for _, entry in ipairs(runtime.overlays) do
  local definition = entry.definition
  local object = entry.object
  if object and object.valid then object.visible = tick >= definition.start and tick <= definition.finish end
end

if runtime.stage and runtime.stage.valid then
  runtime.stage.text = frame_value(scene.stage, tick, "text", scene.stage[1].text)
end
