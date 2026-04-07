data:extend({
  {
    type = "sound",
    name = "administratorio-protest-alert",
    allow_random_repeat = true,
    variations = {
      { filename = "__administratorio__/sound/alerts/protest-alert.ogg", volume = 0.65 },
      { filename = "__administratorio__/sound/alerts/protest-crowd-outdoor.ogg", volume = 0.58 },
      { filename = "__administratorio__/sound/alerts/protest-angry-crowd.ogg", volume = 0.62 },
    },
    aggregation = {
      max_count = 2,
      remove = true,
      count_already_playing = true,
    },
  },
})
