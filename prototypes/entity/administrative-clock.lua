-- A circuit-facing clock for the Working Hours system. Its visual and wiring
-- behaviour come from the vanilla constant combinator; control.lua keeps its
-- Four circuit outputs synchronized with the resolved surface daytime and
-- the configured Working Hours shift boundaries.
local CLOCK_TINT = {r = 0.25, g = 0.75, b = 1.0, a = 1.0}

local function tint_sprites(sprite)
  if type(sprite) ~= "table" then return end
  if sprite.filename and not sprite.draw_as_shadow then
    sprite.tint = CLOCK_TINT
  end
  for _, value in pairs(sprite) do
    if type(value) == "table" then
      tint_sprites(value)
    end
  end
end

local base_clock = data.raw["constant-combinator"] and data.raw["constant-combinator"]["constant-combinator"]
if not base_clock then return end

local administrative_clock = table.deepcopy(base_clock)
administrative_clock.name = "administrative-clock"
administrative_clock.icon = "__base__/graphics/icons/constant-combinator.png"
administrative_clock.icon_size = 64
administrative_clock.icons = nil
administrative_clock.minable = {mining_time = 0.2, result = "administrative-clock"}
administrative_clock.placeable_by = {{item = "administrative-clock", count = 1}}
administrative_clock.localised_name = {"entity-name.administrative-clock"}
administrative_clock.localised_description = {"entity-description.administrative-clock"}
administrative_clock.fast_replaceable_group = "administrative-clock"
administrative_clock.max_health = 100
administrative_clock.selection_priority = 51
tint_sprites(administrative_clock.sprites)
tint_sprites(administrative_clock.activity_led_sprites)

data:extend({administrative_clock})
