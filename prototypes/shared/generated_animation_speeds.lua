local M = {}

-- Single shared source for every building whose sprite sheet comes out of
-- the animation pipeline, regardless of which entity file it's defined in --
-- these values apply mod-wide, so they don't belong duplicated per file.
-- Kept in sync with Internal/animation_pipeline/animations.json by
-- Internal/animation_pipeline/sync_lua_animation_speed.py (runs on webUI save).

M.FRAME_COUNT = 24
M.LINE_LENGTH = 6
M.DEFAULT_ANIMATION_SPEED = 1.0

-- BEGIN GENERATED ANIMATION_SPEEDS
M.ANIMATION_SPEEDS = {
  ["administrative-space-station"] = 0.15,
  ["biter-station-roof"] = 0.2,
  ["biterport-roof"] = 0.19,
  ["chromatic-printer"] = 0.05,
  ["digital-services-bureau"] = 0.3,
  ["formation-center"] = 0.25,
  ["interplanetary-terminus"] = 0.22,
  ["laser-printer"] = 0.15,
  ["notary-office"] = 0.4,
  ["printer-t2"] = 0.5,
  ["territorial-arbitration-post"] = 0.25,
  ["union-headquarters"] = 0.6,
}
-- END GENERATED ANIMATION_SPEEDS

function M.speed(name)
  return M.ANIMATION_SPEEDS[name] or M.DEFAULT_ANIMATION_SPEED
end

return M
