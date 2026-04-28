data:extend({
  {
    type = "sound",
    name = "administratorio-protest-alert",
    allow_random_repeat = true,
    variations = {
      { filename = "__administratorio__/sound/alerts/protest-1.ogg", volume = 0.4 },
      { filename = "__administratorio__/sound/alerts/protest-2.ogg", volume = 0.4 },
      { filename = "__administratorio__/sound/alerts/protest-3.ogg", volume = 0.4 },
    },
    aggregation = {
      max_count = 8,
      remove = true,
      count_already_playing = false,
    },
  },
})
