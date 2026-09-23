local M = {}

local PREFIX = "administratorio-biter-emote-"
local DEFAULT_RENDER_FIELD = "emote_render_id"
local DEFAULT_SPRITE_FIELD = "emote_sprite"

local function get_render_object(render_id)
  if not render_id or not rendering or not rendering.get_object_by_id then return nil end
  return rendering.get_object_by_id(render_id)
end

function M.clear(owner, render_field, sprite_field)
  if not owner then return end
  render_field = render_field or DEFAULT_RENDER_FIELD
  sprite_field = sprite_field or DEFAULT_SPRITE_FIELD
  local object = get_render_object(owner[render_field])
  if object then object.destroy() end
  owner[render_field] = nil
  owner[sprite_field] = nil
end

function M.set(owner, entity, emote, render_field, sprite_field)
  if not owner then return end
  render_field = render_field or DEFAULT_RENDER_FIELD
  sprite_field = sprite_field or DEFAULT_SPRITE_FIELD

  local current = get_render_object(owner[render_field])
  if not emote or not entity or not entity.valid or not rendering or not rendering.draw_sprite then
    M.clear(owner, render_field, sprite_field)
    return
  end

  if owner[sprite_field] == emote and current then return end
  M.clear(owner, render_field, sprite_field)

  local render = rendering.draw_sprite{
    sprite = PREFIX .. emote,
    surface = entity.surface,
    target = {entity = entity, offset = {0, -1.8}},
    x_scale = 0.45,
    y_scale = 0.45,
    render_layer = "air-object",
  }
  if render then
    owner[render_field] = render.id
    owner[sprite_field] = emote
  end
end

return M
