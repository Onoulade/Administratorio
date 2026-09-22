local icon_layers = require("prototypes.shared.icon_layers")
local feature_flags = require("feature_flags")

local complaint_signals = {
  { name = "signal-complaint-l",  ticket = "ticket-landscape",     order = "z[admin]-a[l]" },
  { name = "signal-complaint-s",  ticket = "ticket-smog",          order = "z[admin]-c[s]" },
  { name = "signal-complaint-n",  ticket = "ticket-noise",         order = "z[admin]-e[n]" },
  { name = "signal-complaint-u",  ticket = "ticket-unemployment",  order = "z[admin]-f[u]" },
  { name = "signal-complaint-lt", ticket = "ticket-littering",     order = "z[admin]-g[lt]" },
  { name = "signal-complaint-h",  ticket = "ticket-hazmat",        order = "z[admin]-h[h]" },
  { name = "signal-complaint-lo", ticket = "ticket-loitering",     order = "z[admin]-i[lo]" },
  { name = "signal-complaint-v",  ticket = "ticket-vagrancy",      order = "z[admin]-j[v]" },
}

local signals = {}

for _, def in ipairs(complaint_signals) do
  signals[#signals + 1] = {
    type = "virtual-signal",
    name = def.name,
    icons = icon_layers.complaint_signal_icons(icon_layers.ticket_icon(def.ticket)),
    icon_size = 64,
    subgroup = "virtual-signal",
    order = def.order,
  }
end

signals[#signals + 1] = {
  type = "virtual-signal",
  name = "signal-available-slots",
  icon = icon_layers.ticket_icon("ticket-landscape"),
  icon_size = 64,
  subgroup = "virtual-signal",
  order = "z[admin]-x",
}
for _, signal in ipairs({
  {name = "signal-train-passengers", icon = "__base__/graphics/icons/signal/signal_P.png", order = "z[admin]-pa"},
  {name = "signal-train-free-seats", icon = "__base__/graphics/icons/signal/signal_F.png", order = "z[admin]-pb"},
  {name = "signal-boarders-waiting", icon = "__base__/graphics/icons/signal/signal_Q.png", order = "z[admin]-pc"},
  {name = "signal-passenger-outbreak", icon = "__administratorio__/graphics/icons/protest-cross.png", order = "z[admin]-pd"},
  {name = "signal-boarding-enabled", icon = "__base__/graphics/icons/signal/signal_green.png", order = "z[admin]-pe"},
  {name = "signal-passenger-highest-frustration", icon = "__base__/graphics/icons/signal/signal_H.png", order = "z[admin]-pf"},
  {name = "signal-deboarding-closed", icon = "__base__/graphics/icons/signal/signal_red.png", order = "z[admin]-pg"},
}) do
  signals[#signals + 1] = {
    type = "virtual-signal", name = signal.name, icon = signal.icon, icon_size = 64,
    subgroup = "virtual-signal", order = signal.order,
  }
end
signals[#signals + 1] = {
  type = "virtual-signal",
  name = "signal-total-waiting",
  icon = "__administratorio__/graphics/icons/admin-desk.png",
  icon_size = 64,
  subgroup = "virtual-signal",
  order = "z[admin]-y",
}
signals[#signals + 1] = {
  type = "virtual-signal",
  name = "signal-protest-alert",
  icon = "__administratorio__/graphics/icons/protest-cross.png",
  icon_size = 64,
  subgroup = "virtual-signal",
  order = "z[admin]-z",
}

if feature_flags.working_hours_enabled() then
  signals[#signals + 1] = {
    type = "virtual-signal",
    name = "signal-daytime",
    icon = "__base__/graphics/icons/signal/signal-hourglass.png",
    icon_size = 64,
    subgroup = "virtual-signal",
    order = "z[admin]-za",
  }
  signals[#signals + 1] = {
    type = "virtual-signal",
    name = "signal-working-hours",
    icon = "__base__/graphics/icons/signal/signal_green.png",
    icon_size = 64,
    subgroup = "virtual-signal",
    order = "z[admin]-zb",
  }
  signals[#signals + 1] = {
    type = "virtual-signal",
    name = "signal-day-shift-start",
    icon = "__base__/graphics/icons/signal/signal_1.png",
    icon_size = 64,
    subgroup = "virtual-signal",
    order = "z[admin]-zc",
  }
  signals[#signals + 1] = {
    type = "virtual-signal",
    name = "signal-day-shift-end",
    icon = "__base__/graphics/icons/signal/signal_2.png",
    icon_size = 64,
    subgroup = "virtual-signal",
    order = "z[admin]-zd",
  }
end

data:extend(signals)
