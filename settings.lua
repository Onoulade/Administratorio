data:extend({
  {
    type = "bool-setting",
    name = "administratorio-enable-working-hours",
    setting_type = "startup",
    default_value = true,
    order = "z[administratorio]-a[working-hours]",
  },
  {
    type = "bool-setting",
    name = "administratorio-debug-protest-belts-and-inserters",
    setting_type = "startup",
    default_value = false,
    order = "z[administratorio]-b[debug-protest-belts-inserters]",
  },
  {
    type = "bool-setting",
    name = "administratorio-debug-hard-mode",
    setting_type = "startup",
    default_value = false,
    order = "z[administratorio]-c[debug-hard-mode]",
  },
})
