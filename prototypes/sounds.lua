data:extend({
  {
    type = "sound",
    name = "administratorio-protest-alert",
    filename = "__base__/sound/silo-alarm-short.ogg",
    volume = 0.8,
    aggregation = {
      max_count = 2,
      remove = true,
      count_already_playing = true,
    },
  },
})
