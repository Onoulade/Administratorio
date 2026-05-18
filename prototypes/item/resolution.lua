local item_icons = "__administratorio__/graphics/icons/"
local icon_layers = require("prototypes.shared.icon_layers")

local function resolved_icons(ticket_name)
  return icon_layers.resolved_complaint_icons(icon_layers.ticket_icon(ticket_name))
end

data:extend({
  -- Landscape tier (T0): ticket → filing → resolved
  { type = "item", name = "ticket-landscape",     icon = item_icons .. "ticket-landscape.png",     icon_size = 64, subgroup = "resolution-landscape", order = "a", stack_size = 50 },
  { type = "item", name = "filing-l",             icon = item_icons .. "filing-l.png",             icon_size = 64, subgroup = "resolution-landscape", order = "b", stack_size = 50 },
  { type = "item", name = "resolved-landscape",   icons = resolved_icons("ticket-landscape"),       icon_size = 64, subgroup = "resolution-landscape", order = "c", stack_size = 50 },

  -- Smog tier (T1): ticket → filing → case → resolved
  { type = "item", name = "ticket-smog",          icon = item_icons .. "ticket-smog.png",          icon_size = 64, subgroup = "resolution-smog", order = "a", stack_size = 50 },
  { type = "item", name = "filing-s",             icon = item_icons .. "filing-s.png",             icon_size = 64, subgroup = "resolution-smog", order = "b", stack_size = 50 },
  { type = "item", name = "case-s",               icon = item_icons .. "case-s.png",               icon_size = 64, subgroup = "resolution-smog", order = "c", stack_size = 20 },
  { type = "item", name = "resolved-smog",        icons = resolved_icons("ticket-smog"),          icon_size = 64, subgroup = "resolution-smog", order = "d", stack_size = 50 },

  -- Noise tier (T2): ticket → filing → case → brief → resolved
  { type = "item", name = "ticket-noise",         icon = item_icons .. "ticket-noise.png",         icon_size = 64, subgroup = "resolution-noise", order = "a", stack_size = 50 },
  { type = "item", name = "filing-n",             icon = item_icons .. "filing-n.png",             icon_size = 64, subgroup = "resolution-noise", order = "b", stack_size = 50 },
  { type = "item", name = "case-n",               icon = item_icons .. "case-n.png",               icon_size = 64, subgroup = "resolution-noise", order = "c", stack_size = 20 },
  { type = "item", name = "brief-n",              icon = item_icons .. "case-n.png",               icon_size = 64, subgroup = "resolution-noise", order = "d", stack_size = 10, hidden = true, hidden_in_factoriopedia = true },
  { type = "item", name = "resolved-noise",       icons = resolved_icons("ticket-noise"),         icon_size = 64, subgroup = "resolution-noise", order = "e", stack_size = 50 },

  -- Unemployment tier (T3): ticket → filing → case → brief → resolved
  { type = "item", name = "ticket-unemployment",  icon = item_icons .. "ticket-unemployment.png",  icon_size = 64, subgroup = "resolution-unemployment", order = "a", stack_size = 50 },
  { type = "item", name = "filing-u",             icon = item_icons .. "filing-u.png",             icon_size = 64, subgroup = "resolution-unemployment", order = "b", stack_size = 50 },
  { type = "item", name = "case-u",               icon = item_icons .. "case-u.png",               icon_size = 64, subgroup = "resolution-unemployment", order = "c", stack_size = 20 },
  { type = "item", name = "brief-u",              icon = item_icons .. "case-u.png",               icon_size = 64, subgroup = "resolution-unemployment", order = "d", stack_size = 10, hidden = true, hidden_in_factoriopedia = true },
  { type = "item", name = "resolved-unemployment", icons = resolved_icons("ticket-unemployment"), icon_size = 64, subgroup = "resolution-unemployment", order = "e", stack_size = 50 },

  -- OSHA violation (goes with smog tier)
  { type = "item", name = "osha-violation",       icon = item_icons .. "osha-violation.png",       icon_size = 64, subgroup = "resolution-smog", order = "z", stack_size = 5 },

  -- ===== SPITTER COMPLAINTS =====

  -- Littering tier (T1): ticket → filing → resolved
  { type = "item", name = "ticket-littering",     icon = item_icons .. "ticket-littering.png",     icon_size = 64, subgroup = "resolution-littering", order = "a", stack_size = 50 },
  { type = "item", name = "filing-lt",            icon = item_icons .. "filing-lt.png",            icon_size = 64, subgroup = "resolution-littering", order = "b", stack_size = 50 },
  { type = "item", name = "resolved-littering",   icons = resolved_icons("ticket-littering"),     icon_size = 64, subgroup = "resolution-littering", order = "c", stack_size = 50 },

  -- Hazmat tier (T2): ticket → filing → case → resolved
  { type = "item", name = "ticket-hazmat",        icon = item_icons .. "ticket-hazmat.png",        icon_size = 64, subgroup = "resolution-hazmat", order = "a", stack_size = 50 },
  { type = "item", name = "filing-h",             icon = item_icons .. "filing-h.png",             icon_size = 64, subgroup = "resolution-hazmat", order = "b", stack_size = 50 },
  { type = "item", name = "case-h",               icon = item_icons .. "case-h.png",               icon_size = 64, subgroup = "resolution-hazmat", order = "c", stack_size = 20 },
  { type = "item", name = "resolved-hazmat",      icons = resolved_icons("ticket-hazmat"),        icon_size = 64, subgroup = "resolution-hazmat", order = "d", stack_size = 50 },

  -- Loitering tier (T3): ticket → filing → case → brief → resolved
  { type = "item", name = "ticket-loitering",     icon = item_icons .. "ticket-loitering.png",     icon_size = 64, subgroup = "resolution-loitering", order = "a", stack_size = 50 },
  { type = "item", name = "filing-lo",            icon = item_icons .. "filing-lo.png",            icon_size = 64, subgroup = "resolution-loitering", order = "b", stack_size = 50 },
  { type = "item", name = "case-lo",              icon = item_icons .. "case-lo.png",              icon_size = 64, subgroup = "resolution-loitering", order = "c", stack_size = 20 },
  { type = "item", name = "brief-lo",             icon = item_icons .. "case-lo.png",              icon_size = 64, subgroup = "resolution-loitering", order = "d", stack_size = 10, hidden = true, hidden_in_factoriopedia = true },
  { type = "item", name = "resolved-loitering",   icons = resolved_icons("ticket-loitering"),     icon_size = 64, subgroup = "resolution-loitering", order = "e", stack_size = 50 },

  -- Vagrancy tier (T4): ticket → filing → case → brief → resolved
  { type = "item", name = "ticket-vagrancy",      icon = item_icons .. "ticket-vagrancy.png",      icon_size = 64, subgroup = "resolution-vagrancy", order = "a", stack_size = 50 },
  { type = "item", name = "filing-v",             icon = item_icons .. "filing-v.png",             icon_size = 64, subgroup = "resolution-vagrancy", order = "b", stack_size = 50 },
  { type = "item", name = "case-v",               icon = item_icons .. "case-v.png",               icon_size = 64, subgroup = "resolution-vagrancy", order = "c", stack_size = 20 },
  { type = "item", name = "brief-v",              icon = item_icons .. "case-v.png",               icon_size = 64, subgroup = "resolution-vagrancy", order = "d", stack_size = 10, hidden = true, hidden_in_factoriopedia = true },
  { type = "item", name = "resolved-vagrancy",    icons = resolved_icons("ticket-vagrancy"),      icon_size = 64, subgroup = "resolution-vagrancy", order = "e", stack_size = 50 },
})
