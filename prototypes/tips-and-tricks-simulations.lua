-- ADMINISTRATORIO: TIPS & TRICKS SIMULATIONS
--
-- The individual tips use small declarative scenes. A single update script
-- renders and animates those scenes at runtime, which keeps the prototype
-- definitions compact and gives every demonstration the same visual language.

local update_file = "__administratorio__/prototypes/tips-and-tricks-simulation-update.lua"

local colors = {
  white = {r = 1, g = 1, b = 1, a = 1},
  muted = {r = 0.72, g = 0.75, b = 0.78, a = 1},
  green = {r = 0.35, g = 1, b = 0.38, a = 1},
  yellow = {r = 1, g = 0.82, b = 0.2, a = 1},
  red = {r = 1, g = 0.2, b = 0.18, a = 1},
  cyan = {r = 0.15, g = 0.9, b = 1, a = 1},
  magenta = {r = 1, g = 0.25, b = 0.82, a = 1},
  orange = {r = 1, g = 0.55, b = 0.16, a = 1},
  blue = {r = 0.35, g = 0.62, b = 1, a = 1},
  black = {r = 0.12, g = 0.12, b = 0.14, a = 1},
}

local function entity(name, x, y, label, scale)
  return {name = name, x = x, y = y, label = label, scale = scale}
end

local function sprite(path, x, y, scale, options)
  local result = {sprite = path, x = x, y = y, scale = scale or 0.55}
  for key, value in pairs(options or {}) do result[key] = value end
  return result
end

local function item(name, x, y, scale, options)
  return sprite("item/" .. name, x, y, scale, options)
end

local function label(text, x, y, color, options)
  local result = {text = text, x = x, y = y, color = color or colors.white, scale = 0.9}
  for key, value in pairs(options or {}) do result[key] = value end
  return result
end

local function line(x1, y1, x2, y2, color, options)
  local result = {from = {x1, y1}, to = {x2, y2}, color = color or colors.muted, width = 2}
  for key, value in pairs(options or {}) do result[key] = value end
  return result
end

local function move_item(name, start_tick, finish_tick, x1, y1, x2, y2, options)
  local result = {
    sprite = "item/" .. name,
    start = start_tick,
    finish = finish_tick,
    points = {{tick = start_tick, x = x1, y = y1}, {tick = finish_tick, x = x2, y = y2}},
    scale = 0.48,
  }
  for key, value in pairs(options or {}) do result[key] = value end
  return result
end

local function move_actor(name, start_tick, finish_tick, x1, y1, x2, y2, options)
  local result = {
    entity = name,
    force = "enemy",
    start = start_tick,
    finish = finish_tick,
    points = {{tick = start_tick, x = x1, y = y1}, {tick = finish_tick, x = x2, y = y2}},
    scale = 0.8,
  }
  for key, value in pairs(options or {}) do result[key] = value end
  return result
end

local function bar(x, y, width, color, keyframes, options)
  local result = {x = x, y = y, width = width, height = 0.28, color = color, keyframes = keyframes}
  for key, value in pairs(options or {}) do result[key] = value end
  return result
end

local function stages(...)
  local values = {...}
  local result = {}
  for index = 1, #values, 2 do
    result[#result + 1] = {at = values[index], text = values[index + 1]}
  end
  return result
end

local function scene(duration, zoom, definition)
  definition.duration = duration
  definition.zoom = zoom
  definition.camera = definition.camera or {0, 0}
  return definition
end

local scenes = {}

scenes.welcome = scene(600, 1.05, {
  entities = {entity("admin-station", 0, 0, "ADMIN STATION")},
  sprites = {
    item("ticket-littering", -1.1, -0.2, 0.52, {show = {{150, 330}}}),
    item("resolved-littering", 0, -0.2, 0.52, {show = {{270, 430}}}),
    item("taxpayer-money", 1.1, -0.2, 0.52, {show = {{390, 520}}, pulse = true}),
  },
  movers = {
    move_actor("small-biter", 0, 120, -6, 1.7, -2.5, 1.2, {hold_until = 500}),
    move_actor("small-biter", 500, 590, -2.5, 1.2, 6, 1.7),
  },
  texts = {label("ticket  >  resolution  >  money", 0, -3.6, colors.muted, {alignment = "center"})},
  stage = stages(0, "A complaint arrives", 150, "Ticket filed", 270, "Resolution supplied", 390, "Taxpayer money earned", 500, "Citizen released"),
})

scenes.work_orders = scene(720, 0.78, {
  entities = {
    entity("assembling-machine-1", -6, 0.5, "GREEN"),
    entity("assembling-machine-2", -2, 0.5, "YELLOW"),
    entity("assembling-machine-3", 2, 0.5, "RED"),
    entity("oil-refinery", 6, 0.5, "NO PAPERWORK"),
  },
  sprites = {
    item("construction-work-order", -6, -1.1, 0.46, {pulse = true}),
    item("transit-authorization", -2, -1.1, 0.46, {pulse = true}),
    item("management-approval-written", 2, -1.1, 0.46, {pulse = true}),
    sprite("utility/status_not_working", 6, -1.1, 0.62, {tint = colors.green}),
  },
  movers = {
    move_item("iron-plate", 0, 150, -8, 2.7, -6, 1.3),
    move_item("construction-work-order", 70, 180, -8, -1.1, -6, -0.2),
    move_item("iron-gear-wheel", 180, 330, -4, 2.7, -2, 1.3),
    move_item("transit-authorization", 250, 360, -4, -1.1, -2, -0.2),
    move_item("electronic-circuit", 360, 510, 0, 2.7, 2, 1.3),
    move_item("management-approval-written", 430, 540, 0, -1.1, 2, -0.2),
    move_item("plastic-bar", 540, 690, 4, 2.7, 6, 1.3),
  },
  bars = {
    bar(-6, 3.4, 2.6, colors.green, {{at = 0, value = 0}, {at = 180, value = 1}, {at = 360, value = 0}}),
    bar(-2, 3.4, 2.6, colors.yellow, {{at = 180, value = 0}, {at = 360, value = 1}, {at = 540, value = 0}}),
    bar(2, 3.4, 2.6, colors.red, {{at = 360, value = 0}, {at = 540, value = 1}, {at = 720, value = 0}}),
  },
  stage = stages(0, "Ingredients + operating paperwork", 540, "Refineries remain exempt"),
})

scenes.complaints = scene(660, 0.95, {
  entities = {
    entity("admin-station", -3.1, 0.5, "DESK"),
    entity("resolution-office", 3.2, 0.5, "RESOLUTION OFFICE"),
    entity("inserter", 0.2, 0.5, nil),
  },
  lines = {line(-2, -1.8, 3, -1.8, colors.green, {dash_length = 0.25, gap_length = 0.18})},
  movers = {
    move_actor("small-biter", 0, 120, -7, 2.5, -4.6, 1.6, {hold_until = 540}),
    move_item("ticket-landscape", 130, 245, -3.2, 0.2, 2.9, 0.2),
    move_item("resolved-landscape", 300, 410, 3, 0.2, -2.7, 0.2),
    move_item("taxpayer-money", 430, 520, -3, 0.2, -0.7, 2.7),
    move_actor("small-biter", 540, 650, -4.6, 1.6, -7, 2.5),
  },
  sprites = {
    sprite("virtual-signal/signal-L", -0.9, -1.8, 0.42, {show = {{120, 290}}, pulse = true}),
    sprite("virtual-signal/signal-M", 1.1, -1.8, 0.42, {show = {{410, 550}}, pulse = true}),
  },
  texts = {
    label("tickets_landscape", -2.4, -2.65, colors.green, {show = {{120, 290}}, alignment = "center"}),
    label("money_earned: 0", 2.5, -2.65, colors.yellow, {frames = {{at = 0, text = "money_earned: 0"}, {at = 430, text = "money_earned: 1"}, {at = 600, text = "money_earned: 0"}}, alignment = "center"}),
  },
  stage = stages(0, "Complaint signal", 245, "Resolution crafted", 410, "Resolution inserted", 540, "Citizen released"),
})

scenes.frustration = scene(720, 0.92, {
  entities = {
    entity("admin-station", -3.5, -0.2, "4 / 4"),
    entity("electric-mining-drill", 4, 0.5, "MINER"),
  },
  sprites = {
    item("ticket-littering", -4.4, -0.5, 0.38), item("ticket-vagrancy", -3.8, -0.5, 0.38),
    item("ticket-loitering", -3.2, -0.5, 0.38), item("ticket-landscape", -2.6, -0.5, 0.38),
    sprite("utility/danger_icon", 0, -2.3, 0.7, {show = {{70, 350}}, blink = 18}),
    sprite("utility/status_not_working", 4, 0.4, 0.75, {show = {{300, 570}}, tint = colors.red}),
    item("promise", 0.6, 2.6, 0.54, {show = {{420, 530}}, pulse = true}),
  },
  movers = {
    move_actor("medium-biter", 70, 290, 0, 1.5, 3.1, 1.2, {hold_until = 520}),
    move_item("promise", 420, 500, 0.6, 2.6, 3.1, 1.2),
    move_actor("medium-biter", 520, 680, 3.1, 1.2, -1.5, 1.5),
  },
  bars = {
    bar(0, -1.5, 3, colors.red, {{at = 0, value = 1}, {at = 510, value = 1}, {at = 540, value = 0.5}, {at = 720, value = 0.5}}),
  },
  texts = {
    label("FRUSTRATION 100%", 0, -2.1, colors.red, {frames = {{at = 0, text = "FRUSTRATION 100%"}, {at = 520, text = "PROMISE: 50%"}}, alignment = "center"}),
  },
  stage = stages(0, "Desk full", 70, "Protest begins", 300, "Building disabled", 420, "Promise deployed", 520, "Rerouted to desk", 620, "Building restored"),
})

scenes.complaint_chain = scene(780, 0.88, {
  entities = {entity("admin-station", 0, 0.8, "COMPLAINT SLOTS"), entity("resolution-office", 6, 0.8, "PROCESS")},
  movers = {
    move_actor("small-biter", 0, 100, -8, -2.2, -3.2, -2.2, {hold_until = 690}),
    move_actor("medium-biter", 120, 220, -8, 0.2, -3.2, 0.2, {hold_until = 690}),
    move_actor("behemoth-biter", 240, 340, -8, 2.8, -3.2, 2.8, {hold_until = 690}),
    move_item("ticket-littering", 350, 430, -2.2, -2, 5.3, -1.5),
    move_item("ticket-landscape", 430, 510, -2.2, 0.2, 5.3, 0.4),
    move_item("ticket-vagrancy", 510, 590, -2.2, 2.4, 5.3, 2.3),
  },
  sprites = {
    item("ticket-littering", -1.5, -2.4, 0.36),
    item("ticket-landscape", -1.8, -0.1, 0.36), item("ticket-landscape", -1.15, -0.1, 0.36),
    item("ticket-vagrancy", -2.6, 2.2, 0.34), item("ticket-vagrancy", -1.95, 2.2, 0.34),
    item("ticket-vagrancy", -1.3, 2.2, 0.34), item("ticket-vagrancy", -0.65, 2.2, 0.34), item("ticket-vagrancy", 0, 2.2, 0.34),
  },
  texts = {
    label("1 ticket", -4.6, -3.2, colors.green, {alignment = "center"}),
    label("2 tickets", -4.6, -0.8, colors.yellow, {alignment = "center"}),
    label("5 tickets", -4.6, 1.8, colors.red, {alignment = "center"}),
    label("EVOLUTION 0%", 6, -3.5, colors.orange, {frames = {{at = 0, text = "EVOLUTION 0%"}, {at = 240, text = "EVOLUTION 33%"}, {at = 480, text = "EVOLUTION 66%"}, {at = 690, text = "EVOLUTION 100%"}}, alignment = "center"}),
  },
  stage = stages(0, "Small complaint", 120, "Medium complaint", 240, "Behemoth complaint", 350, "Resolution chain scales with evolution", 690, "New ticket types unlocked"),
})

scenes.hush_eviction = scene(780, 0.72, {
  entities = {entity("biter-spawner", -5, 0.3, "HUSH MONEY"), entity("biter-spawner", 5, 0.3, "EVICTION")},
  lines = {line(0, -4.2, 0, 4.2, colors.muted, {width = 3})},
  sprites = {
    item("hush-money", -8, 2.8, 0.55, {show = {{40, 180}}, pulse = true}),
    item("eviction-notice", 2, 2.8, 0.55, {show = {{300, 440}}, pulse = true}),
    sprite("utility/clock", -5, -2.2, 0.66, {show = {{170, 690}}, blink = 30}),
    sprite("utility/danger_icon", 5, 0, 0.9, {show = {{430, 620}}, tint = colors.red}),
  },
  movers = {
    move_item("hush-money", 40, 170, -8, 2.8, -5, 0.3),
    move_item("eviction-notice", 300, 430, 2, 2.8, 5, 0.3),
    move_actor("small-biter", 470, 690, 6.5, -1.5, 1, -3.3),
    move_actor("medium-biter", 500, 720, 7, 0.4, 1, -1.6),
    move_actor("big-biter", 530, 750, 6.5, 2.3, 1, 0.2),
  },
  bars = {bar(5, 3.1, 5.5, colors.green, {{at = 0, value = 0.8}, {at = 430, value = 0.8}, {at = 620, value = 0.8}}, {step = true})},
  texts = {
    label("SPAWN TIMER PAUSED", -5, -3.2, colors.green, {show = {{170, 690}}, alignment = "center"}),
    label("EVOLUTION FLAT", 5, 3.7, colors.green, {show = {{430, 690}}, alignment = "center"}),
    label("HIGH FRUSTRATION", 4, -3.4, colors.red, {show = {{470, 760}}, alignment = "center"}),
  },
  stage = stages(0, "Temporary suppression", 300, "Permanent expropriation", 430, "Spawner removed", 470, "Displaced citizens flood the desks"),
})

scenes.field_office = scene(780, 0.88, {
  entities = {entity("field-office", 0, 0.5, "FIELD OFFICE"), entity("biter-spawner", 6.5, 0.5, "NEST")},
  sprites = {
    item("provisional-approval", -0.6, 0.2, 0.44, {show = {{240, 360}}}),
    item("taxpayer-money", 0.6, 0.2, 0.44, {show = {{330, 450}}}),
  },
  movers = {
    move_actor("small-biter", 0, 190, 5.3, 1.2, 1.7, 1.1, {hold_until = 470}),
    move_actor("small-biter", 470, 560, 1.7, 1.1, 5.3, 1.2),
    move_actor("small-biter", 560, 690, 5.3, 1.2, 1.7, 1.1, {hold_until = 760}),
  },
  bars = {bar(0, 2.7, 3.4, colors.green, {{at = 190, value = 0}, {at = 320, value = 0.5}, {at = 450, value = 1}, {at = 500, value = 0}, {at = 690, value = 0}, {at = 760, value = 0.5}})},
  overlays = {{start = 520, finish = 760, color = {r = 0.02, g = 0.05, b = 0.16, a = 0.58}}},
  texts = {
    label("CRAFT 1", -0.8, -1.8, colors.green, {show = {{240, 330}}, alignment = "center"}),
    label("CRAFT 2", 0.8, -1.8, colors.green, {show = {{330, 450}}, alignment = "center"}),
    label("OPEN ALL NIGHT", 0, -2.4, colors.green, {show = {{520, 760}}, alignment = "center"}),
  },
  stage = stages(0, "Citizen intake", 190, "Two field-office crafts", 470, "Citizen released", 520, "Night operations", 560, "Replacement intake"),
})

scenes.biter_employment = scene(720, 0.88, {
  entities = {entity("admin-station", -4.8, 0.3, "JOB OFFER"), entity("biter-station", 1, 0.3, "BITER STATION"), entity("oil-refinery", 6.4, 0.3, "1 CYCLE")},
  sprites = {
    item("job-offer", -4.8, -0.1, 0.5, {show = {{0, 260}}, pulse = true}),
    item("worker-biter", -2.5, 2.4, 0.4, {show = {{260, 440}}}), item("worker-biter", -1.7, 2.4, 0.4, {show = {{260, 440}}}),
    item("worker-biter", -0.9, 2.4, 0.4, {show = {{260, 440}}}), item("worker-biter", -0.1, 2.4, 0.4, {show = {{260, 440}}}),
    item("worker-biter", 0.7, 2.4, 0.4, {show = {{260, 440}}}),
  },
  movers = {
    move_actor("behemoth-biter", 0, 150, -8, 1.3, -6.2, 1.2, {hold_until = 260}),
    move_item("job-offer", 150, 250, -4.8, -0.1, -6.2, 1.2),
    move_item("worker-biter", 300, 440, -2.5, 2.4, 1, 0.4),
    move_item("worker-biter", 450, 590, 1, 0.4, 6.4, 0.4),
  },
  bars = {bar(6.4, 2.8, 3.1, colors.green, {{at = 500, value = 0}, {at = 650, value = 1}, {at = 710, value = 0}})},
  stage = stages(0, "Behemoth resolves", 150, "Job offer accepted", 260, "5 workers enrolled", 440, "Worker dispatched", 590, "Refinery cycle"),
})

scenes.workers = scene(720, 0.86, {
  entities = {entity("formation-center", -3.8, 0.5, "FORMATION CENTER"), entity("chemical-plant", 4.5, 0.5, "PLACEMENT GHOST")},
  sprites = {
    item("worker-biter", -6.2, 2.7, 0.45), item("management-approval-written", -5.2, 2.7, 0.45),
    item("chemical-operator", -3.8, -0.1, 0.56, {show = {{260, 520}}, pulse = true}),
    sprite("utility/indication_arrow", 0.4, 0.4, 0.7, {orientation = 0.25}),
  },
  movers = {
    move_item("worker-biter", 0, 130, -6.2, 2.7, -4.2, 0.8),
    move_item("management-approval-written", 60, 190, -5.2, 2.7, -3.5, 0.8),
    move_item("chemical-operator", 300, 520, -3.3, 0.4, 4.5, 0.4),
  },
  texts = {
    label("CHEMICAL OPERATOR", -3.8, -2.2, colors.cyan, {show = {{250, 520}}, alignment = "center"}),
    label("6 SPECIALIST RECIPES", -3.8, 3.6, colors.muted, {frames = {{at = 0, text = "CLERK"}, {at = 100, text = "CHEM OP"}, {at = 200, text = "NOTARY"}, {at = 300, text = "CONCILIATOR"}, {at = 400, text = "RELAY"}, {at = 500, text = "CRYOPRINT"}, {at = 620, text = "6 SPECIALIST RECIPES"}}, alignment = "center"}),
    label("SPECIALIST CONSUMED", 4.5, -2.2, colors.green, {show = {{520, 700}}, alignment = "center"}),
  },
  stage = stages(0, "Choose a profession", 60, "Worker + paperwork", 250, "Specialist trained", 300, "Place specialist building", 520, "Staffing consumed"),
})

scenes.biter_station = scene(840, 0.78, {
  entities = {
    entity("biter-station", 0, 0, "LABOR EFFICIENCY 1"),
    entity("assembling-machine-1", -6, -2.2, "A"), entity("assembling-machine-2", 6, -2.2, "B"), entity("chemical-plant", 0, 3.1, "C"),
  },
  lines = {line(0, 0, -6, -2.2, colors.green), line(0, 0, 6, -2.2, colors.green), line(0, 0, 0, 3.1, colors.green)},
  movers = {
    {entity = "small-biter", force = "player", start = 0, finish = 800, scale_frames = {{at = 0, scale = 0.55}, {at = 250, scale = 0.7}, {at = 500, scale = 0.9}}, points = {
      {tick = 0, x = 0, y = 0.8}, {tick = 140, x = -5, y = -1.5}, {tick = 250, x = 0, y = 0.8},
      {tick = 390, x = 5, y = -1.5}, {tick = 500, x = 0, y = 0.8}, {tick = 650, x = 0, y = 2.2}, {tick = 780, x = 0, y = 0.8},
    }},
  },
  sprites = {item("worker-biter", 0, 0.3, 0.38, {pulse = true}), sprite("fluid/liquid-coffee", 3.1, 3.5, 0.45, {show = {{650, 820}}})},
  overlays = {{start = 650, finish = 820, color = {r = 0.02, g = 0.05, b = 0.16, a = 0.52}}},
  texts = {
    label("1 craft", -6, -3.8, colors.green, {show = {{110, 250}}, alignment = "center"}),
    label("1 craft", 6, -3.8, colors.green, {show = {{360, 500}}, alignment = "center"}),
    label("1 craft", 0, 4.7, colors.green, {show = {{620, 780}}, alignment = "center"}),
    label("EFFICIENCY 1 > 2 > 3", 0, -4.4, colors.yellow, {alignment = "center"}),
    label("COFFEE DISPATCH", 3.1, 4.2, colors.cyan, {show = {{650, 820}}, alignment = "center"}),
  },
  stage = stages(0, "Dispatch to Building A", 250, "Return, then Building B", 500, "Return, then Building C", 650, "Night dispatch consumes coffee"),
})

scenes.rideable = scene(720, 0.88, {
  entities = {entity("admin-station", 5.5, 1.2, "COMPLAINT DESK")},
  sprites = {sprite("entity/rideable-biter", -2, 0.5, 0.9, {show = {{0, 250}}}), item("rocket-fuel", -2, -1.3, 0.45, {show = {{0, 300}}}), sprite("entity/character", -2, 0.1, 0.46, {show = {{0, 250}}})},
  movers = {{entity = "small-biter", force = "player", start = 260, finish = 710, scale = 0.8, points = {{tick = 260, x = -2, y = 0.5}, {tick = 400, x = 0.2, y = 1.3}, {tick = 640, x = 0.2, y = 1.3}, {tick = 710, x = 3.8, y = 1.2}}}},
  bars = {
    bar(-2, 2.3, 3.5, colors.orange, {{at = 0, value = 1}, {at = 250, value = 0.45}, {at = 300, value = 0}}),
    bar(2.8, -2.1, 4.5, colors.red, {{at = 400, value = 1}, {at = 650, value = 0}, {at = 710, value = 0}}),
  },
  texts = {
    label("FUEL", -2, 2.9, colors.orange, {alignment = "center"}),
    label("10:00", 2.8, -2.8, colors.red, {frames = {{at = 0, text = ""}, {at = 400, text = "10:00"}, {at = 460, text = "08:00"}, {at = 520, text = "05:00"}, {at = 580, text = "02:00"}, {at = 640, text = "00:00"}}, alignment = "center"}),
    label("WILD", 2.8, -1.3, colors.red, {show = {{640, 710}}, alignment = "center"}),
  },
  stage = stages(0, "Mounted: fuel drains", 250, "Player dismounts", 300, "Fuel removed", 400, "Ten-minute timer", 640, "Returns to the complaint system"),
})

scenes.biterport = scene(840, 0.72, {
  entities = {entity("biterport", -5, 0, "BITERPORT A"), entity("biterport", 5, 0, "BITERPORT B"), entity("logistic-chest-passive-provider", -8, 3, "PROVIDER"), entity("logistic-chest-requester", 8, 3, "REQUESTER")},
  lines = {line(-5, 0, 5, 0, colors.orange, {dash_length = 0.35, gap_length = 0.2}), line(-3, -3, 3, -3, colors.green, {dash_length = 0.2, gap_length = 0.2})},
  sprites = {
    sprite("utility/ghost_cursor", -3, -3, 0.45), sprite("utility/ghost_cursor", 0, -3, 0.45), sprite("utility/ghost_cursor", 3, -3, 0.45),
    sprite("fluid/liquid-coffee", 5, 2, 0.45, {show = {{650, 820}}, pulse = true}),
  },
  movers = {
    move_item("worker-biter", 0, 190, -5, 0.5, -3, -3),
    move_item("worker-biter", 190, 350, -3, -3, -5, 0.5),
    move_item("worker-biter", 380, 570, -8, 3, 8, 3),
  },
  overlays = {{start = 650, finish = 820, color = {r = 0.02, g = 0.05, b = 0.16, a = 0.5}}},
  texts = {
    label("NETWORKED", 0, -0.8, colors.orange, {alignment = "center"}),
    label("1 > 2 > 5 > 10 > 25 ITEMS", 0, 3.9, colors.yellow, {alignment = "center"}),
    label("GHOST BUILT", 0, -3.8, colors.green, {show = {{170, 350}}, alignment = "center"}),
    label("NIGHT: COFFEE / DISPATCH", 5, 2.8, colors.cyan, {show = {{650, 820}}, alignment = "center"}),
  },
  stage = stages(0, "Construction dispatch", 190, "Return to port", 380, "Logistics transfer", 650, "Night dispatch"),
})

scenes.hired = scene(780, 0.82, {
  entities = {entity("hired-biter-supply-chest", -2, 2.6, "SUPPLY"), entity("biter-spawner", 6, -1.8, "TARGET")},
  sprites = {item("hired-biter-command-capsule", -6, 2.5, 0.5, {show = {{0, 190}}, pulse = true}), item("eviction-notice", -2, 2.2, 0.4)},
  lines = {line(-5, 0, -1, -2, colors.green, {dash_length = 0.2, gap_length = 0.15}), line(-1, -2, -2, 2.6, colors.green, {dash_length = 0.2, gap_length = 0.15}), line(-2, 2.6, 6, -1.8, colors.red, {dash_length = 0.2, gap_length = 0.15})},
  movers = {
    {entity = "hired-biter-unit", force = "player", start = 0, finish = 730, points = {{tick = 0, x = -5, y = 0}, {tick = 190, x = -1, y = -2}, {tick = 360, x = -2, y = 2.1}, {tick = 590, x = 5.1, y = -1.3}, {tick = 730, x = 6, y = -1.8}}},
    move_item("eviction-notice", 350, 520, -2, 2.2, 4.7, -1.1),
  },
  texts = {label("SELECT", -5, -1.1, colors.green, {show = {{0, 160}}, alignment = "center"}), label("WAYPOINT", -1, -3, colors.green, {show = {{160, 320}}, alignment = "center"}), label("SHIFT: SUPPLY STOP", -2, 3.6, colors.cyan, {show = {{320, 500}}, alignment = "center"}), label("NOTICE LOADED", 2, 2, colors.yellow, {show = {{430, 590}}, alignment = "center"}), label("EXPROPRIATED", 6, -3.1, colors.red, {show = {{650, 760}}, alignment = "center"})},
  stage = stages(0, "Left-click selects", 160, "Right-click waypoint", 320, "Shift-right-click supply", 500, "Agent finds target", 650, "Spawner destroyed"),
})

scenes.pneumatic = scene(660, 0.88, {
  entities = {entity("tube-intake", -5, 0, "INTAKE"), entity("tube-outtake", 5, 0, "OUTTAKE"), entity("inserter", 7.4, 0, nil)},
  lines = {line(-4, 0.3, 4, 0.3, {r = 0.85, g = 0.72, b = 0.45, a = 1}, {width = 7})},
  movers = {
    move_item("blank-form", 0, 150, -8, 0.8, -5, 0.3),
    move_item("blank-form", 150, 205, -4.2, 0.3, 4.2, 0.3),
    move_item("blank-form", 205, 330, 5, 0.3, 8, 0.8),
    move_item("transit-authorization", 350, 500, -8, 0.8, -5, 0.3),
    move_item("transit-authorization", 500, 555, -4.2, 0.3, 4.2, 0.3),
  },
  sprites = {item("blank-form", 5, -1.5, 0.45, {show = {{0, 330}}}), item("transit-authorization", 5, -1.5, 0.45, {show = {{350, 630}}, pulse = true})},
  bars = {bar(0, 2.6, 8, colors.orange, {{at = 0, value = 0}, {at = 205, value = 0.45}, {at = 330, value = 0}, {at = 350, value = 0}, {at = 555, value = 0.75}, {at = 650, value = 0}})},
  texts = {label("FILTER: ANY", 5, -2.5, colors.muted, {frames = {{at = 0, text = "FILTER: ANY"}, {at = 350, text = "FILTER: FORM 12-T"}}, alignment = "center"}), label("NETWORK CAPACITY", 0, 3.2, colors.orange, {alignment = "center"})},
  stage = stages(0, "Paperwork enters", 150, "Instant tube transfer", 205, "Inserter extracts", 350, "Filter changed", 500, "Only requested form passes"),
})

scenes.working_hours = scene(840, 0.68, {
  entities = {
    entity("office-desk", -6, 0, "DESK"), entity("union-headquarters", -2, 0, "UNION"), entity("biter-station", 2, 0, "STATION"),
    entity("biterport", 6, 0, "PORT"), entity("electric-mining-drill", 0, 4, "PROTEST TARGET"),
  },
  sprites = {
    item("overtime-exemption", -6, 2.1, 0.42), item("overtime-exemption", -2, 2.1, 0.42),
    sprite("fluid/liquid-coffee", 2, 2.1, 0.42), sprite("fluid/liquid-coffee", 6, 2.1, 0.42),
    sprite("utility/status_not_working", 0, 4, 0.75, {show = {{650, 820}}, tint = colors.red}),
  },
  overlays = {{start = 250, finish = 820, color = {r = 0.01, g = 0.03, b = 0.12, a = 0.58}}},
  texts = {
    label("DAY: ACTIVE", 0, -4, colors.yellow, {show = {{0, 250}}, alignment = "center"}),
    label("NIGHT", 0, -4, colors.blue, {show = {{250, 820}}, alignment = "center"}),
    label("OPEN", -6, -2, colors.green, {show = {{390, 820}}, alignment = "center"}), label("OPEN", -2, -2, colors.green, {show = {{390, 820}}, alignment = "center"}),
    label("COFFEE", 2, -2, colors.cyan, {show = {{500, 820}}, alignment = "center"}), label("COFFEE", 6, -2, colors.cyan, {show = {{500, 820}}, alignment = "center"}),
    label("CLOSED", -2, -2, colors.red, {show = {{250, 390}}, alignment = "center"}), label("CLOSED", 2, -2, colors.red, {show = {{250, 500}}, alignment = "center"}),
    label("PROTEST OVERRIDES OVERTIME", 0, 5.2, colors.red, {show = {{650, 820}}, alignment = "center"}),
  },
  movers = {move_actor("small-biter", 580, 680, 6, 4, 1.3, 4, {hold_until = 820})},
  stage = stages(0, "Day shift", 250, "Night closure", 390, "Overtime offices reopen", 500, "Coffee dispatches workers", 650, "Protest still disables buildings"),
})

scenes.propaganda = scene(720, 0.78, {
  entities = {entity("propaganda-distillery", 0, 0.3, "PROPAGANDA DISTILLERY"), entity("chemical-plant", 7, 0.3, "NOT COMPATIBLE")},
  lines = {line(-8, -1.8, -2, -1.8, colors.cyan, {width = 6}), line(2, -1.8, 5, -1.8, colors.magenta, {width = 6})},
  movers = {
    move_item("dubious-data", 180, 300, -5, 2.7, -1.5, 0.7),
    move_item("refined-nonsense", 360, 480, -5, 2.7, -1.5, 0.7),
    move_item("credentials", 480, 600, 1.5, 0.7, 4.5, 2.7),
  },
  sprites = {sprite("fluid/politician-fluid", -6.5, -1.8, 0.48), sprite("fluid/lie", 3.5, -1.8, 0.48), sprite("utility/status_not_working", 7, 0.2, 0.9, {tint = colors.red})},
  texts = {
    label("POLITICIAN FLUID", -6.5, -2.8, colors.cyan, {alignment = "center"}), label("LIES", 3.5, -2.8, colors.magenta, {alignment = "center"}),
    label("+ DUBIOUS DATA", -4.8, 3.5, colors.yellow, {show = {{180, 360}}, alignment = "center"}),
    label("MISINFORMATION", 0, 3.5, colors.magenta, {show = {{300, 480}}, alignment = "center"}),
    label("+ REFINED NONSENSE", -4.8, 3.5, colors.yellow, {show = {{360, 540}}, alignment = "center"}),
    label("CREDENTIALS", 4.5, 3.5, colors.green, {show = {{480, 680}}, alignment = "center"}),
  },
  stage = stages(0, "Politician fluid becomes lies", 180, "Add dubious data", 300, "Misinformation", 360, "Add refined nonsense", 480, "Credentials"),
})

scenes.economy = scene(840, 0.62, {
  sprites = {
    item("bullshit-ore", -8, -3, 0.54), item("dubious-data", -5.3, -3, 0.48), item("basic-excuse", -2.6, -3, 0.48),
    item("crappy-report", -5.3, -0.8, 0.48), item("justification", -2.6, -0.8, 0.48), item("narrative", 0.1, -0.8, 0.48), item("white-paper", 2.8, -0.8, 0.48), item("policy", 5.5, -0.8, 0.48), item("regulation", 8.2, -0.8, 0.48),
    item("redundant-rubble", -8, 1.7, 0.54), item("useless-documentation", -4.5, 1.7, 0.46), item("compacted-rubble", -1, 1.7, 0.46), item("refined-nonsense", 2.5, 1.7, 0.46),
    item("taxpayer-money", -8, 4, 0.5), item("treasury-bond", -4.5, 4, 0.48), item("government-grant", -1, 4, 0.48),
  },
  lines = {
    line(-7.3, -3, -6, -3, colors.green), line(-4.6, -3, -3.3, -3, colors.green),
    line(-4.6, -0.8, -3.3, -0.8, colors.yellow), line(-1.9, -0.8, -0.6, -0.8, colors.yellow), line(0.8, -0.8, 2.1, -0.8, colors.yellow), line(3.5, -0.8, 4.8, -0.8, colors.yellow), line(6.2, -0.8, 7.5, -0.8, colors.yellow),
    line(-7.3, 1.7, -5.2, 1.7, colors.orange), line(-3.8, 1.7, -1.7, 1.7, colors.orange), line(-0.3, 1.7, 1.8, 1.7, colors.orange),
    line(-7.3, 4, -5.2, 4, colors.cyan), line(-3.8, 4, -1.7, 4, colors.cyan),
  },
  texts = {
    label("ORE  >  DATA  >  EXCUSE", -5.3, -4, colors.green, {alignment = "center"}),
    label("REPORT  >  JUSTIFICATION  >  NARRATIVE  >  WHITE PAPER  >  POLICY  >  REGULATION", 1.4, -1.8, colors.yellow, {scale = 0.68, alignment = "center"}),
    label("RUBBLE DERIVATIVES", -2.7, 0.7, colors.orange, {alignment = "center"}), label("PUBLIC FINANCE", -4.5, 3, colors.cyan, {alignment = "center"}),
    label("DESK", 4.5, 3.3, colors.white), label("BREAKROOM", 4.5, 4, colors.white), label("UNION HQ", 4.5, 4.7, colors.white),
  },
  movers = {move_item("bullshit-ore", 0, 180, -8, -3, -2.6, -3), move_item("crappy-report", 180, 430, -5.3, -0.8, 8.2, -0.8), move_item("redundant-rubble", 430, 620, -8, 1.7, 2.5, 1.7), move_item("taxpayer-money", 620, 800, -8, 4, -1, 4)},
  stage = stages(0, "Excuse chain", 180, "Policy chain", 430, "Rubble derivatives", 620, "Money > bond > grant"),
})

scenes.transit = scene(660, 0.82, {
  entities = {entity("train-stop", 1.5, 0, "REGULATED STOP"), entity("transit-permit-chest", -1.4, 1.8, "FORMS")},
  lines = {line(-9, -2.2, 9, -2.2, colors.muted, {width = 8})},
  sprites = {item("transit-authorization", -1.4, 1.4, 0.45, {frames = {{at = 0, sprite = "item/transit-authorization"}, {at = 430, sprite = "utility/status_not_working"}}})},
  movers = {move_item("locomotive", 80, 280, -9, -2.2, 1.5, -2.2), move_item("locomotive", 480, 630, -9, -2.2, 9, -2.2)},
  bars = {bar(1.5, 3, 4, colors.green, {{at = 0, value = 1}, {at = 280, value = 0.5}, {at = 430, value = 0}, {at = 650, value = 0}}, {step = true})},
  texts = {label("TRAIN LIMIT: 1", 1.5, 3.7, colors.green, {frames = {{at = 0, text = "TRAIN LIMIT: 1"}, {at = 280, text = "FORM CONSUMED"}, {at = 430, text = "TRAIN LIMIT: 0"}}, alignment = "center"}), label("PASS BY", 5, -3.2, colors.red, {show = {{480, 650}}, alignment = "center"})},
  stage = stages(0, "Integrated form chest", 80, "Train arrives", 280, "Authorization consumed", 430, "Forms depleted", 480, "Station closed; train passes"),
})

scenes.science = scene(660, 0.82, {
  entities = {entity("office-desk", -3.5, 0, "OFFICE DESK"), entity("lab", 4.8, 0, "TECH TREE")},
  sprites = {item("blank-form", -6.5, 2.5, 0.42), item("provisional-approval", -5.3, 2.5, 0.42), item("basic-excuse", -4.1, 2.5, 0.42), item("research-grant-approval", -2.9, 2.5, 0.42), item("administrative-science-pack", -3.5, -0.4, 0.58, {show = {{280, 620}}, pulse = true}), item("military-science-pack", 4.8, 1.6, 0.48, {tint = {r = 0.3, g = 0.3, b = 0.3, a = 0.45}}), sprite("utility/status_not_working", 4.8, 1.6, 0.65, {tint = colors.red})},
  movers = {move_item("blank-form", 0, 140, -6.5, 2.5, -3.8, 0.4), move_item("provisional-approval", 40, 180, -5.3, 2.5, -3.6, 0.4), move_item("basic-excuse", 80, 220, -4.1, 2.5, -3.4, 0.4), move_item("research-grant-approval", 120, 260, -2.9, 2.5, -3.2, 0.4), move_item("administrative-science-pack", 300, 500, -3, 0, 4.8, 0)},
  texts = {label("4 INGREDIENTS", -4.7, 3.4, colors.muted, {alignment = "center"}), label("PINK PACK", -3.5, -2, colors.magenta, {show = {{280, 620}}, alignment = "center"}), label("REPLACES MILITARY SCIENCE", 4.8, 2.8, colors.green, {show = {{430, 640}}, alignment = "center"})},
  stage = stages(0, "Four administrative inputs", 260, "Pink science crafted", 300, "Research supplied", 430, "Military science replaced"),
})

local function manifest_scene(planet, color, staff_a, local_item, paperwork, milestone)
  return scene(780, 0.72, {
    entities = {entity("rocket-silo", 6.8, 0.4, "ROCKET SILO")},
    sprites = {
      item(staff_a, -8, -2.8, 0.46), item("chemical-operator", -8, -0.9, 0.46), item(local_item, -4.2, 1.3, 0.48), item(paperwork, 0, 1.3, 0.5), item(milestone, 3.6, 1.3, 0.5),
    },
    lines = {line(-7, 0.8, 5.6, 0.8, color, {width = 4})},
    movers = {move_item(local_item, 150, 300, -4.2, 1.3, 0, 1.3), move_item(paperwork, 300, 480, 0, 1.3, 3.6, 1.3), move_item(milestone, 480, 680, 3.6, 1.3, 6.2, 0.5)},
    texts = {label(string.upper(planet) .. " MANIFEST", 0, -4, color, {alignment = "center"}), label("STAFF", -8, -4, colors.muted, {alignment = "center"}), label("LOCAL INPUT", -4.2, 2.2, colors.muted, {alignment = "center"}), label("PAPERWORK", 0, 2.2, colors.muted, {alignment = "center"}), label("MILESTONE", 3.6, 2.2, colors.muted, {alignment = "center"})},
    stage = stages(0, "Check specialist manifest", 150, "Establish local production", 300, "Complete planet paperwork", 480, "Deliver escape milestone", 680, "Silo authorized"),
  })
end

scenes.manifest_vulcanus = manifest_scene("Vulcanus", colors.cyan, "licensed-notary", "blank-cyan-form", "territorial-resettlement-order", "territorial-deed")
scenes.manifest_gleba = manifest_scene("Gleba", colors.yellow, "clerical-trainee", "bullshit-ore", "blank-yellow-form", "management-approval-written")
scenes.manifest_fulgora = manifest_scene("Fulgora", colors.magenta, "relay-clerk", "old-archive", "digital-processing-certificate", "archive-recovery-permit")
scenes.manifest_aquilo = manifest_scene("Aquilo", colors.blue, "cryoprint-technician", "thermal-transfer-sheet", "composite-chroma-ribbon", "government-grant")

scenes.workforce = scene(780, 0.68, {
  entities = {entity("formation-center", -6.5, 0, "FORMATION"), entity("administrative-space-station", 6.5, 0, "PLATFORM")},
  sprites = {
    item("worker-biter", -9, 2.7, 0.4), item("orbital-operations-form", -8, 2.7, 0.4),
    item("middle-management-managing-manager", -3.8, -2, 0.42), item("voluntary-exploration-space-miner", -2.5, -2, 0.42), item("astronaut", -1.2, -2, 0.42),
    item("chemical-operator", 0.1, -2, 0.42), item("licensed-notary", 1.4, -2, 0.42), item("relay-clerk", 2.7, -2, 0.42), item("cryoprint-technician", 4, -2, 0.42),
  },
  movers = {move_item("middle-management-managing-manager", 250, 500, -3.8, -2, 6.5, 0), move_item("voluntary-exploration-space-miner", 360, 610, -2.5, -2, 5.5, 1)},
  bars = {bar(-3.8, -3.2, 3, colors.red, {{at = 500, value = 1}, {at = 730, value = 0}, {at = 770, value = 0}})},
  texts = {label("7 SPECIALISTS + MMMM + VESM", 0, -4.3, colors.cyan, {alignment = "center"}), label("BRIEFED MMMM 03:00", -3.8, -3.9, colors.red, {frames = {{at = 0, text = ""}, {at = 500, text = "BRIEFED MMMM 03:00"}, {at = 580, text = "BRIEFED MMMM 02:00"}, {at = 660, text = "BRIEFED MMMM 01:00"}, {at = 730, text = "BRIEFING EXPIRED"}}, alignment = "center"}), label("SPECIALISTS CONSUMED ON PLACEMENT", 6.5, 3.2, colors.green, {show = {{500, 760}}, alignment = "center"})},
  stage = stages(0, "Select formation recipe", 120, "Worker + paperwork", 250, "Specialist trained", 360, "Move to platform", 500, "Place and consume specialist"),
})

scenes.trajectory = scene(720, 0.7, {
  entities = {entity("trajectory-compliance-array", -6, 2, "JUNIOR"), entity("senior-trajectory-compliance-array", 0, 2, "SENIOR"), entity("executive-trajectory-compliance-array", 6, 2, "EXECUTIVE")},
  sprites = {item("orbital-deviation-order", -6, 0.3, 0.4), item("priority-orbital-deviation-order", 0, 0.3, 0.4), item("voluntary-exploration-space-miner", 6, 0.3, 0.4, {show = {{420, 690}}, pulse = true}), sprite("entity/small-metallic-asteroid", -6, -2.6, 0.7), sprite("entity/medium-metallic-asteroid", 0, -2.6, 0.7), sprite("entity/big-metallic-asteroid", 6, -2.6, 0.7)},
  lines = {line(-6, 1.2, -4, -2.3, colors.green), line(0, 1.2, 2.7, -2.3, colors.yellow), line(6, 1.2, 9, -2.3, colors.red)},
  movers = {move_item("orbital-deviation-order", 0, 180, -6, 0.3, -4, -2.3), move_item("priority-orbital-deviation-order", 160, 340, 0, 0.3, 2.7, -2.3), move_item("orbital-deviation-order", 320, 500, 6, 0.3, 9, -2.3)},
  texts = {label("1x ARC", -6, -3.8, colors.green, {alignment = "center"}), label("PRIORITY = 2x ARC", 0, -3.8, colors.yellow, {alignment = "center"}), label("VESM RETARGET", 6, -3.8, colors.cyan, {show = {{420, 690}}, alignment = "center"}), label("COOLDOWN 4.5s > 0.5s", 0, 4, colors.magenta, {alignment = "center"})},
  stage = stages(0, "Junior array pushes small asteroid", 160, "Senior priority order doubles arc", 320, "Executive array handles large target", 420, "VESM retargets arrays", 560, "Speed research reduces cooldown"),
})

scenes.cannon = scene(780, 0.75, {
  entities = {entity("orbital-employment-cannon", -6, 1, "18 DEGREE CONE"), entity("asteroid-collector", 6.5, 2.6, "COLLECTOR")},
  sprites = {sprite("entity/big-metallic-asteroid", 5, -1.2, 1.0), item("voluntary-exploration-space-miner", -5.7, 0.7, 0.46), item("metallic-asteroid-chunk", 5.2, 0.1, 0.42, {show = {{570, 750}}}), item("worker-biter", 6, 0.1, 0.42, {show = {{570, 750}}})},
  lines = {line(-5, 0.3, 5, -1.2, colors.red, {width = 3}), line(-5, 0.3, 4, -3, {r = 1, g = 0.3, b = 0.2, a = 0.45}), line(-5, 0.3, 5, 1.1, {r = 1, g = 0.3, b = 0.2, a = 0.45})},
  movers = {move_item("voluntary-exploration-space-miner", 80, 260, -5.7, 0.7, 4.3, -1.2), move_item("worker-biter", 260, 430, -2, 3.5, 4.6, -0.7), move_item("worker-biter", 310, 480, -1, 3.5, 4.8, -0.9), move_item("worker-biter", 360, 530, 0, 3.5, 5, -1.1), move_item("voluntary-exploration-space-miner", 610, 750, 5, -1.2, -5.7, 0.7)},
  bars = {bar(5, -2.8, 4.8, colors.red, {{at = 260, value = 1}, {at = 570, value = 0}, {at = 750, value = 0}})},
  texts = {label("MINING DAMAGE", 5, -3.5, colors.red, {show = {{260, 570}}, alignment = "center"}), label("1 > 5 MINERS", 0, 4.2, colors.yellow, {show = {{260, 570}}, alignment = "center"}), label("CHUNKS + EMPLOYEE CHUNKS", 5.5, 0.8, colors.green, {show = {{570, 750}}, alignment = "center"}), label("AMMO RETURNED", -4, -2, colors.cyan, {show = {{650, 770}}, alignment = "center"})},
  stage = stages(0, "Cannon acquires asteroid", 80, "VESM fired", 260, "Mining beam attaches workers", 570, "Asteroid yields chunks", 610, "Collector returns VESM"),
})

scenes.space_station = scene(720, 0.76, {
  entities = {entity("administrative-space-station", -3.8, 0, "SPACE STATION"), entity("trajectory-compliance-array", 5.5, 0, "ORBITAL BUILDING")},
  sprites = {item("carbon", -7, 2.7, 0.4), item("water-barrel", -5.8, 2.7, 0.4), item("iron-plate", -4.6, 2.7, 0.4), item("paper", -4.2, -0.3, 0.43, {show = {{160, 320}}}), item("ink", -3.3, -0.3, 0.43, {show = {{160, 320}}}), item("orbital-operations-form", -2.4, -0.3, 0.46, {show = {{300, 500}}}), sprite("fluid/thruster-fuel", -1.5, -1.5, 0.4, {show = {{320, 500}}}), sprite("fluid/thruster-oxidizer", -0.4, -1.5, 0.4, {show = {{320, 500}}}), item("asteroid-processing-docket", 0.7, -1.5, 0.4, {show = {{320, 500}}}), item("orbital-infrastructure-permit", 1.2, 2.5, 0.5, {show = {{440, 620}}, pulse = true})},
  movers = {move_item("carbon", 0, 130, -7, 2.7, -4.2, 0.3), move_item("water-barrel", 30, 160, -5.8, 2.7, -3.8, 0.3), move_item("iron-plate", 60, 190, -4.6, 2.7, -3.4, 0.3), move_item("orbital-operations-form", 300, 440, -2.4, -0.3, 1.2, 2.5), move_item("orbital-infrastructure-permit", 440, 620, 1.2, 2.5, 5.5, 0)},
  texts = {label("CARBON + WATER > PAPER", -4.2, -2.2, colors.white, {show = {{130, 300}}, alignment = "center"}), label("+ IRON > INK", -3.4, -2.9, colors.white, {show = {{160, 320}}, alignment = "center"}), label("OPERATIONS FORM", -2.4, -1.6, colors.cyan, {show = {{300, 500}}, alignment = "center"}), label("PERMIT CONSUMED", 5.5, -2.3, colors.green, {show = {{620, 700}}, alignment = "center"})},
  stage = stages(0, "Orbital paper and ink", 160, "Print operations forms", 300, "Craft infrastructure permit", 440, "Place orbital building", 620, "Permit consumed"),
})

scenes.chromatic = scene(780, 0.75, {
  entities = {entity("chromatic-printer", 0, 0.5, "CHROMATIC PRINTER")},
  sprites = {sprite("fluid/cyan-ink", -6, -1.8, 0.5), sprite("fluid/yellow-ink", -2, -1.8, 0.5), sprite("fluid/magenta-ink", 2, -1.8, 0.5), item("ink", 6, -1.8, 0.5), item("blank-cyan-form", -4.5, 2.8, 0.46, {show = {{150, 300}}}), item("cyan-yellow-form", -1.5, 2.8, 0.46, {show = {{300, 450}}}), item("trichromatic-permit", 1.5, 2.8, 0.46, {show = {{450, 610}}}), item("composite-chroma-ribbon", 4.5, 2.8, 0.5, {show = {{610, 760}}, pulse = true})},
  bars = {bar(-6, -2.7, 2.2, colors.cyan, {{at = 0, value = 1}, {at = 610, value = 0.15}}), bar(-2, -2.7, 2.2, colors.yellow, {{at = 0, value = 1}, {at = 300, value = 1}, {at = 610, value = 0.25}}), bar(2, -2.7, 2.2, colors.magenta, {{at = 0, value = 1}, {at = 450, value = 1}, {at = 610, value = 0.35}}), bar(6, -2.7, 2.2, colors.black, {{at = 0, value = 1}, {at = 450, value = 1}, {at = 610, value = 0.55}})},
  movers = {move_item("blank-cyan-form", 150, 280, 0, 0.5, -4.5, 2.8), move_item("cyan-yellow-form", 300, 430, 0, 0.5, -1.5, 2.8), move_item("trichromatic-permit", 450, 590, 0, 0.5, 1.5, 2.8), move_item("composite-chroma-ribbon", 610, 750, 0, 0.5, 4.5, 2.8)},
  texts = {label("CYAN", -6, -3.5, colors.cyan, {alignment = "center"}), label("YELLOW", -2, -3.5, colors.yellow, {alignment = "center"}), label("MAGENTA", 2, -3.5, colors.magenta, {alignment = "center"}), label("BLACK", 6, -3.5, colors.white, {alignment = "center"})},
  stage = stages(0, "Four ink tanks", 150, "Single-color form", 300, "Dual-color form", 450, "Trichromatic + black", 610, "CMY forms + emulsion > ribbon"),
})

scenes.notary = scene(720, 0.8, {
  entities = {entity("notary-office", 0, 0.4, "NOTARY OFFICE")},
  sprites = {item("licensed-notary", -5.5, 2.5, 0.5), sprite("fluid/cyan-ink", -5.5, -1.5, 0.48), sprite("fluid/lie", 5.5, -1.5, 0.48), item("embossed-seal", -4, 3, 0.4), item("industrial-charter", -2, 3, 0.4), item("good-excuse", 0, 3, 0.4), item("management-approval-written", 2, 3, 0.4), item("inspection-docket", 4, 3, 0.4)},
  movers = {move_item("licensed-notary", 0, 150, -5.5, 2.5, -1.3, 0.7), move_item("embossed-seal", 180, 300, 0, 0.4, -4, 3), move_item("industrial-charter", 290, 410, 0, 0.4, -2, 3), move_item("good-excuse", 400, 520, 0, 0.4, 0, 3), move_item("management-approval-written", 510, 630, 0, 0.4, 2, 3)},
  texts = {label("CYAN IN", -5.5, -2.4, colors.cyan, {alignment = "center"}), label("LIES OUT", 5.5, -2.4, colors.magenta, {alignment = "center"}), label("SPECIALIST CONSUMED", -4, 1.5, colors.green, {show = {{150, 280}}, alignment = "center"})},
  stage = stages(0, "Place with Licensed Notary", 150, "Staffing consumed", 180, "Seal", 290, "Charter", 400, "Excuse", 510, "Written approval", 630, "Inspection docket"),
})

scenes.arbitration = scene(720, 0.8, {
  entities = {entity("territorial-arbitration-post", -3.5, 0.4, "ARBITRATION POST")},
  sprites = {item("territorial-resettlement-order", -7, 2.6, 0.48), sprite("fluid/lie", -5.7, 2.6, 0.48), item("territorial-deed", 5.5, 0, 0.58, {show = {{560, 690}}, pulse = true})},
  lines = {line(0.5, -2.7, 7.5, -2.7, colors.red, {width = 5}), line(0.5, -0.9, 7.5, -0.9, colors.red, {width = 5}), line(0.5, 0.9, 7.5, 0.9, colors.red, {width = 5}), line(0.5, 2.7, 7.5, 2.7, colors.red, {width = 5})},
  movers = {move_item("territorial-resettlement-order", 0, 150, -7, 2.6, -3.8, 0.5), move_item("territorial-deed", 560, 680, -1.5, 0.5, 5.5, 0)},
  bars = {bar(4, 3.7, 7.2, colors.green, {{at = 0, value = 1}, {at = 560, value = 0}, {at = 700, value = 0}})},
  texts = {label("TERRITORY CHUNKS: 12", 4, 4.3, colors.red, {frames = {{at = 0, text = "TERRITORY CHUNKS: 12"}, {at = 180, text = "TERRITORY CHUNKS: 8"}, {at = 340, text = "TERRITORY CHUNKS: 4"}, {at = 500, text = "TERRITORY CHUNKS: 0"}}, alignment = "center"}), label("DECAY IF UNFED", -3.5, -2.2, colors.orange, {show = {{240, 340}}, alignment = "center"}), label("DEED", 5.5, -1.1, colors.green, {show = {{560, 690}}, alignment = "center"})},
  stage = stages(0, "Orders + lies supplied", 150, "Territory shrinks", 240, "Supply pause: progress decays", 340, "Processing resumes", 500, "Territory cleared", 560, "Deed issued"),
})

scenes.charters = scene(660, 0.82, {
  entities = {entity("foundry", 5.2, 0, "OFF-WORLD FOUNDRY")},
  sprites = {item("thermal-process-license", -6, -2.2, 0.5), item("calcite-reagent-waiver", -6, 0, 0.5), item("offworld-metallurgy-charter", -6, 2.2, 0.5), sprite("utility/status_not_working", 5.2, 0, 0.75, {show = {{0, 300}}, tint = colors.red}), sprite("utility/status_working", 5.2, 0, 0.75, {show = {{430, 640}}, tint = colors.green})},
  movers = {move_item("thermal-process-license", 180, 330, -6, -2.2, 3.7, -1), move_item("calcite-reagent-waiver", 230, 380, -6, 0, 3.7, 0), move_item("offworld-metallurgy-charter", 280, 430, -6, 2.2, 3.7, 1)},
  texts = {label("OFF-WORLD", 5.2, -2.5, colors.cyan, {alignment = "center"}), label("VULCANUS RECIPES LOCKED", 5.2, 2.6, colors.red, {show = {{0, 430}}, alignment = "center"}), label("RECIPES ENABLED", 5.2, 2.6, colors.green, {show = {{430, 640}}, alignment = "center"})},
  stage = stages(0, "Off-world metallurgy blocked", 180, "Deliver three export charters", 430, "Vulcanus recipes authorized"),
})

scenes.conciliation = scene(680, 0.82, {
  entities = {entity("conciliation-desk", 0, 0.4, "CONCILIATION DESK")},
  sprites = {item("conciliation-officer", -6, 2.5, 0.5), sprite("fluid/yellow-ink", -5.5, -1.8, 0.48), sprite("fluid/amber-sap", 5.5, -1.8, 0.48), item("blank-yellow-form", -3.5, 2.8, 0.46), item("conciliation-order", 0, 2.8, 0.46), item("symbiosis-record", 3.5, 2.8, 0.46)},
  movers = {move_item("conciliation-officer", 0, 130, -6, 2.5, -1.2, 0.7), move_item("blank-yellow-form", 160, 300, 0, 0.4, -3.5, 2.8), move_item("conciliation-order", 300, 440, 0, 0.4, 0, 2.8), move_item("symbiosis-record", 440, 580, 0, 0.4, 3.5, 2.8)},
  texts = {label("YELLOW INK", -5.5, -2.7, colors.yellow, {alignment = "center"}), label("AMBER SAP", 5.5, -2.7, colors.orange, {alignment = "center"}), label("OFFICER CONSUMED", -3.8, 1.4, colors.green, {show = {{130, 260}}, alignment = "center"})},
  stage = stages(0, "Place with Conciliation Officer", 130, "Staffing consumed", 160, "Yellow form", 300, "Conciliation order", 440, "Symbiosis record"),
})

scenes.capture = scene(780, 0.76, {
  entities = {entity("capture-bureau", 0, 0.3, "CAPTURE BUREAU"), entity("rocket-silo", 7, 1.5, "TO NAUVIS")},
  sprites = {sprite("fluid/workforce-lure-spores", -7, -2.7, 0.43), sprite("fluid/tourism-lure-spores", -5.5, -2.7, 0.43), sprite("fluid/oviposition-lure-spores", -4, -2.7, 0.43), item("job-offer", -3.5, 2.8, 0.5), item("worker-biter", 3.2, -2, 0.46, {show = {{250, 480}}}), item("public-transportation-contract", 3.2, 0, 0.46, {show = {{390, 650}}}), item("captured-pentapod-specimen", 3.2, 2, 0.46, {show = {{520, 730}}})},
  movers = {move_actor("small-biter", 0, 190, -8, -0.8, -1.7, -0.2, {hold_until = 300}), move_item("job-offer", 120, 250, -3.5, 2.8, -1, 0.5), move_item("worker-biter", 250, 390, 0.8, 0.3, 3.2, -2), move_actor("small-spitter", 300, 470, -8, 0.8, -1.7, 0.2), move_item("public-transportation-contract", 470, 650, 0.8, 0.3, 6.2, 1.5), move_actor("small-stomper-pentapod", 500, 690, -8, 2.4, -1.7, 0.8)},
  texts = {label("3 LURE FLUIDS", -5.5, -3.5, colors.yellow, {alignment = "center"}), label("WORKER", 3.2, -2.8, colors.green, {show = {{250, 480}}, alignment = "center"}), label("TOURIST CONTRACT", 3.2, -0.8, colors.cyan, {show = {{390, 650}}, alignment = "center"}), label("PENTAPOD INTAKE", 3.2, 2.8, colors.orange, {show = {{520, 730}}, alignment = "center"})},
  stage = stages(0, "Workforce lure attracts biter", 120, "Job offer processed", 250, "Worker output", 300, "Tourism lure attracts spitter", 470, "Contract to Nauvis", 520, "Oviposition lure attracts pentapod"),
})

local function cross_planet_scene(form, use_item, color)
  return scene(600, 0.9, {
    entities = {entity("chromatic-printer", -3, 0.4, "DUAL-COLOR PRINT" )},
    sprites = {item(form, -3, 0, 0.56, {show = {{180, 560}}, pulse = true}), item(use_item, 4.5, 0, 0.58, {show = {{360, 560}}})},
    movers = {move_item(form, 180, 360, -2.5, 0.4, 4.5, 0)},
    lines = {line(-1, 0, 3, 0, color, {width = 5})},
    texts = {label("TWO PLANETS, ONE FORM", 0, -3, color, {alignment = "center"}), label("USE CASE", 4.5, -1.4, colors.green, {show = {{360, 560}}, alignment = "center"})},
    stage = stages(0, "Two ink colors supplied", 180, "Dual form printed", 360, "Cross-planet recipe enabled"),
  })
end

scenes.cross_cy = cross_planet_scene("cyan-yellow-form", "public-transportation-contract", colors.yellow)
scenes.cross_cm = cross_planet_scene("cyan-magenta-form", "hardened-data-vault", colors.magenta)
scenes.cross_ym = cross_planet_scene("yellow-magenta-form", "dubious-data", colors.orange)

scenes.digital = scene(700, 0.8, {
  entities = {entity("digital-services-bureau", 0, 0.4, "DIGITAL SERVICES BUREAU")},
  sprites = {item("relay-clerk", -6, 2.5, 0.5), sprite("fluid/lubricant", -5.5, -1.7, 0.48), item("digital-processing-certificate", -4, 2.8, 0.4), item("electromagnetic-operating-license", -2, 2.8, 0.4), item("data-recovery-order", 0, 2.8, 0.4), item("archive-recovery-permit", 2, 2.8, 0.4), item("permit-draft", 4, 2.8, 0.4)},
  overlays = {{start = 350, finish = 680, color = {r = 0.02, g = 0.03, b = 0.14, a = 0.5}}},
  movers = {move_item("relay-clerk", 0, 130, -6, 2.5, -1.3, 0.7), move_item("digital-processing-certificate", 150, 270, 0, 0.4, -4, 2.8), move_item("electromagnetic-operating-license", 260, 380, 0, 0.4, -2, 2.8), move_item("data-recovery-order", 370, 490, 0, 0.4, 0, 2.8), move_item("archive-recovery-permit", 480, 600, 0, 0.4, 2, 2.8)},
  texts = {label("24 / 7", 0, -2.7, colors.green, {alignment = "center"}), label("RELAY CLERK CONSUMED", -4, 1.5, colors.green, {show = {{130, 260}}, alignment = "center"}), label("NIGHT: STILL ONLINE", 0, -3.5, colors.cyan, {show = {{350, 680}}, alignment = "center"})},
  stage = stages(0, "Place with Relay Clerk", 130, "Staffing consumed", 150, "Certificate", 260, "License", 370, "Recovery order", 480, "Archive permit", 600, "Bootstrap"),
})

scenes.archive = scene(700, 0.86, {
  entities = {entity("archive-recombination-bureau", -3.5, 0.3, "RECOMBINATION")},
  sprites = {item("construction-permit", -7, 0.3, 0.52), item("safety-waiver", 2, -2, 0.48, {show = {{300, 620}}}), item("transit-authorization", 2, 0.3, 0.48, {show = {{360, 620}}}), item("filing-lt", 2, 2.6, 0.48, {show = {{430, 620}}})},
  movers = {move_item("construction-permit", 0, 180, -7, 0.3, -3.5, 0.3), move_item("safety-waiver", 240, 360, -3, 0.3, 2, -2), move_item("transit-authorization", 300, 420, -3, 0.3, 2, 0.3), move_item("filing-lt", 360, 480, -3, 0.3, 2, 2.6)},
  texts = {label("3 x 25% ROLLS", -3.5, -2.4, colors.yellow, {show = {{180, 540}}, alignment = "center"}), label("NO INPUT RETURN", 5.5, -2.4, colors.red, {alignment = "center"}), label("NO RANK JUMP", 5.5, 0, colors.red, {alignment = "center"}), label("NO COLOR INVENT", 5.5, 2.4, colors.red, {alignment = "center"}), label("0 - 3 OUTPUTS", 0, 3.8, colors.green, {show = {{300, 620}}, alignment = "center"})},
  stage = stages(0, "One form enters", 180, "Three independent rolls", 300, "Candidate 1", 360, "Candidate 2", 430, "Candidate 3"),
})

scenes.fax = scene(720, 0.82, {
  entities = {entity("fax-emitter", -4.5, 0.4, "FAX EMITTER"), entity("interplanetary-fax-exchange", 4.5, 0.4, "TARGET PLANET")},
  sprites = {item("management-approval-written", -7.5, 2.6, 0.5), sprite("virtual-signal/signal-fax-queue-size", 0, -2.3, 0.48, {pulse = true})},
  movers = {move_item("management-approval-written", 0, 130, -7.5, 2.6, -4.5, 0.5), move_item("management-approval-written", 250, 310, -3.8, 0.4, 3.8, 0.4)},
  bars = {bar(-4.5, 2.2, 3.5, colors.cyan, {{at = 130, value = 0}, {at = 250, value = 1}, {at = 300, value = 0}}), bar(4.5, 2.2, 3.5, colors.yellow, {{at = 0, value = 0.2}, {at = 310, value = 0.4}, {at = 680, value = 0.4}}, {step = true})},
  texts = {label("60 TICKS", -4.5, 2.9, colors.cyan, {alignment = "center"}), label("TARGET: VULCANUS", -4.5, -2.3, colors.yellow, {frames = {{at = 0, text = "TARGET: VULCANUS"}, {at = 420, text = "TARGET: GLEBA"}, {at = 560, text = "TARGET: FULGORA"}}, alignment = "center"}), label("QUEUE SLOT RESERVED", 4.5, 2.9, colors.green, {show = {{310, 680}}, alignment = "center"}), label("CIRCUIT SIGNALS", 0, -3.2, colors.green, {alignment = "center"})},
  stage = stages(0, "Document inserted", 130, "Transmission bar", 250, "Fax crosses planets", 310, "Queue slot reserved", 420, "Destination selector cycles"),
})

scenes.fax_exchange = scene(720, 0.82, {
  entities = {entity("interplanetary-fax-exchange", 0, 0.4, "FAX EXCHANGE")},
  sprites = {item("thermal-transfer-sheet", -6, 2.5, 0.48), item("composite-chroma-ribbon", -4.5, 2.5, 0.48), item("cyan-yellow-form", 5.2, 0.3, 0.52, {show = {{430, 680}}, pulse = true}), sprite("virtual-signal/signal-R", -5.2, -1.8, 0.46)},
  movers = {move_item("thermal-transfer-sheet", 220, 360, -6, 2.5, -1, 0.5), move_item("composite-chroma-ribbon", 270, 410, -4.5, 2.5, -0.6, 0.5), move_item("cyan-yellow-form", 430, 600, 0.8, 0.4, 5.2, 0.3)},
  bars = {bar(0, -2.5, 7, colors.yellow, {{at = 0, value = 1}, {at = 430, value = 0.8}, {at = 700, value = 0.8}}, {step = true})},
  texts = {label("QUEUE 5 + QUALITY + RESEARCH", 0, -3.2, colors.yellow, {alignment = "center"}), label("REQUEST SIGNAL", -5.2, -2.7, colors.green, {alignment = "center"}), label("SHEETS + RIBBON", -5.2, 3.4, colors.cyan, {alignment = "center"}), label("PRINTED DOCUMENT", 5.2, -1.1, colors.green, {show = {{430, 680}}, alignment = "center"})},
  stage = stages(0, "Incoming queue full", 120, "Requested document selected", 220, "Solid media supplied", 430, "Document reconstructed", 600, "Queue slot released"),
})

scenes.laser = scene(640, 0.84, {
  entities = {entity("laser-printer", 0, 0.3, "LASER PRINTER")},
  sprites = {item("thermal-transfer-sheet", -6, 2.4, 0.5), item("composite-chroma-ribbon", -4.5, 2.4, 0.5), item("trichromatic-permit", 5.2, 0.3, 0.56, {show = {{350, 610}}, pulse = true}), sprite("fluid/cyan-ink", 0, -1.4, 0.45, {tint = {r = 0.3, g = 0.3, b = 0.3, a = 0.4}}), sprite("utility/status_not_working", 0, -1.4, 0.6, {tint = colors.red})},
  movers = {move_item("thermal-transfer-sheet", 0, 170, -6, 2.4, -1, 0.4), move_item("composite-chroma-ribbon", 80, 250, -4.5, 2.4, -0.5, 0.4), move_item("trichromatic-permit", 350, 520, 0.8, 0.3, 5.2, 0.3)},
  texts = {label("NO LIQUID INK", 0, -2.4, colors.red, {alignment = "center"}), label("CRYOGENIC + VACUUM", 0, 3.4, colors.cyan, {alignment = "center"}), label("SOLID MEDIA", -5.2, 3.3, colors.yellow, {alignment = "center"})},
  stage = stages(0, "Thermal sheets supplied", 80, "Chroma ribbon supplied", 250, "Vacuum-safe printing", 350, "Color form output"),
})

scenes.color_fax = scene(620, 0.86, {
  entities = {entity("fax-emitter", -3.8, 0.4, "COLOR FAX: OFF"), entity("interplanetary-fax-exchange", 4.5, 0.4, "RECEIVER")},
  sprites = {item("cyan-yellow-form", -7, 2.6, 0.52), sprite("utility/status_not_working", -3.8, 0.4, 0.7, {show = {{0, 200}}, tint = colors.red}), item("composite-chroma-ribbon", 4.5, 2.5, 0.48, {show = {{330, 590}}, pulse = true})},
  movers = {move_item("cyan-yellow-form", 220, 330, -7, 2.6, -3.8, 0.4), move_item("cyan-yellow-form", 330, 400, -3, 0.4, 3.8, 0.4)},
  texts = {label("MULTICOLOR REJECTED", -3.8, -2.1, colors.red, {show = {{0, 200}}, alignment = "center"}), label("COLOR FAX: ON", -3.8, -2.1, colors.green, {show = {{200, 590}}, alignment = "center"}), label("RIBBON CHARGES / COLOR", 4.5, 3.3, colors.magenta, {show = {{330, 590}}, alignment = "center"})},
  stage = stages(0, "Color document rejected", 200, "Color Faxing enabled", 220, "Multicolor accepted", 330, "Ribbon charges consumed"),
})

scenes.fax_capacity = scene(640, 0.88, {
  entities = {entity("interplanetary-fax-exchange", 0, 0.5, "FAX QUEUE")},
  bars = {bar(0, 2.8, 10, colors.cyan, {{at = 0, value = 0.25}, {at = 150, value = 0.5}, {at = 300, value = 0.75}, {at = 450, value = 1}, {at = 620, value = 1}}, {step = true})},
  texts = {label("5 SLOTS", 0, 3.6, colors.cyan, {frames = {{at = 0, text = "5 SLOTS"}, {at = 150, text = "10 SLOTS"}, {at = 300, text = "15 SLOTS"}, {at = 450, text = "20 SLOTS"}}, alignment = "center"}), label("+ RECEIVER QUALITY", 0, -2.4, colors.yellow, {alignment = "center"}), label("CAPACITY I", -5, 1.8, colors.green, {show = {{150, 300}}, alignment = "center"}), label("CAPACITY II", 0, 1.8, colors.green, {show = {{300, 450}}, alignment = "center"}), label("CAPACITY III", 5, 1.8, colors.green, {show = {{450, 620}}, alignment = "center"})},
  stage = stages(0, "Base queue", 150, "+5 capacity", 300, "+5 capacity", 450, "+5 capacity"),
})

scenes.transcendence = scene(720, 0.78, {
  entities = {entity("public-train-stop", 1.5, 0, "PUBLIC TRAIN STOP")},
  lines = {line(-9, -1.8, 9, -1.8, colors.muted, {width = 8})},
  sprites = {item("transit-authorization", -4.5, 2.4, 0.48, {tint = {r = 0.35, g = 0.35, b = 0.35, a = 0.45}}), sprite("utility/status_working", -4.5, 2.4, 0.65, {tint = colors.green}), item("blank-cyan-form", -4, -2.9, 0.34), item("blank-yellow-form", -2.7, -2.9, 0.34), item("blank-magenta-form", -1.4, -2.9, 0.34), item("composite-chroma-ribbon", -0.1, -2.9, 0.34)},
  movers = {move_item("locomotive", 100, 300, -9, -1.8, 1.5, -1.8), move_item("locomotive", 420, 650, 1.5, -1.8, 9, -1.8)},
  texts = {label("NO CHEST", -4.5, 3.3, colors.green, {alignment = "center"}), label("NO FORM CONSUMED", 1.5, 2.7, colors.green, {show = {{300, 650}}, alignment = "center"}), label("TRAIN LIMIT: UNCHANGED", 1.5, 3.5, colors.green, {show = {{300, 650}}, alignment = "center"}), label("FAX NETWORK COMPLETE", -2.1, -3.7, colors.cyan, {alignment = "center"}), label("EXEMPTION GRANTED", 5.2, -3.1, colors.yellow, {show = {{300, 680}}, alignment = "center"})},
  stage = stages(0, "Four-planet fax prerequisite complete", 100, "Train arrives", 300, "Standing exemption applies", 420, "Train departs without paperwork"),
})

local tip_scene = {
  ["administratorio-welcome"] = "welcome",
  ["administratorio-work-orders"] = "work_orders",
  ["administratorio-biter-complaints"] = "complaints",
  ["administratorio-frustration"] = "frustration",
  ["administratorio-complaint-chain"] = "complaint_chain",
  ["administratorio-hush-money"] = "hush_eviction",
  ["administratorio-nest-expropriation"] = "hush_eviction",
  ["administratorio-field-office"] = "field_office",
  ["administratorio-biter-employment"] = "biter_employment",
  ["administratorio-biter-workers"] = "workers",
  ["administratorio-biter-station"] = "biter_station",
  ["administratorio-rideable-biter"] = "rideable",
  ["administratorio-biterport"] = "biterport",
  ["administratorio-hired-biter"] = "hired",
  ["administratorio-pneumatic-transport"] = "pneumatic",
  ["administratorio-working-hours"] = "working_hours",
  ["administratorio-propaganda-distillery"] = "propaganda",
  ["administratorio-bullshit-economy"] = "economy",
  ["administratorio-transit-authorization"] = "transit",
  ["administratorio-admin-science"] = "science",
  ["administratorio-vulcanus-manifest"] = "manifest_vulcanus",
  ["administratorio-gleba-manifest"] = "manifest_gleba",
  ["administratorio-fulgora-archives"] = "manifest_fulgora",
  ["administratorio-aquilo-manifest"] = "manifest_aquilo",
  ["administratorio-workforce-formation-title"] = "workforce",
  ["administratorio-workforce-formation"] = "workforce",
  ["administratorio-orbital-specialists"] = "workforce",
  ["administratorio-trajectory-compliance-arrays"] = "trajectory",
  ["administratorio-senior-trajectory-compliance-array"] = "trajectory",
  ["administratorio-executive-trajectory-compliance-array"] = "trajectory",
  ["administratorio-trajectory-compliance-speed"] = "trajectory",
  ["administratorio-orbital-employment-cannon"] = "cannon",
  ["administratorio-orbital-employment-damage"] = "cannon",
  ["administratorio-orbital-employment-capacity"] = "cannon",
  ["administratorio-administrative-space-station"] = "space_station",
  ["administratorio-orbital-infrastructure-permit"] = "space_station",
  ["administratorio-chromatic-printing"] = "chromatic",
  ["administratorio-chromatic-printer"] = "chromatic",
  ["administratorio-chromatic-inks"] = "chromatic",
  ["administratorio-multicolor-forms"] = "chromatic",
  ["administratorio-vulcanus-certification"] = "notary",
  ["administratorio-notary-office"] = "notary",
  ["administratorio-territorial-arbitration"] = "arbitration",
  ["administratorio-vulcanus-export-charters"] = "charters",
  ["administratorio-gleba-conciliation"] = "conciliation",
  ["administratorio-conciliation-desk"] = "conciliation",
  ["administratorio-capture-bureau"] = "capture",
  ["administratorio-cross-planet-bureaucracy"] = "cross_cy",
  ["administratorio-cyan-yellow-bureaucracy"] = "cross_cy",
  ["administratorio-cyan-magenta-bureaucracy"] = "cross_cm",
  ["administratorio-yellow-magenta-bureaucracy"] = "cross_ym",
  ["administratorio-fulgora-digital-services"] = "digital",
  ["administratorio-digital-services-bureau"] = "digital",
  ["administratorio-archive-recombination"] = "archive",
  ["administratorio-aquilo-fax-network"] = "fax",
  ["administratorio-fax-emitter"] = "fax",
  ["administratorio-interplanetary-fax-exchange"] = "fax_exchange",
  ["administratorio-laser-printer"] = "laser",
  ["administratorio-color-faxing"] = "color_fax",
  ["administratorio-fax-queue-capacity"] = "fax_capacity",
  ["administratorio-bureaucratic-transcendence"] = "transcendence",
  ["administratorio-public-train-stop"] = "transcendence",
}

local function is_array(value)
  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" then return false end
    count = count + 1
  end
  return count == #value
end

local function serialize(value)
  local value_type = type(value)
  if value_type == "string" then return string.format("%q", value) end
  if value_type == "number" or value_type == "boolean" then return tostring(value) end
  if value_type ~= "table" then error("unsupported simulation value type: " .. value_type) end

  local parts = {}
  if is_array(value) then
    for index, child in ipairs(value) do parts[index] = serialize(child) end
  else
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
      parts[#parts + 1] = "[" .. serialize(key) .. "]=" .. serialize(value[key])
    end
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

local simulations = {}
for tip_name, scene_name in pairs(tip_scene) do
  local definition = scenes[scene_name]
  assert(definition, "missing tips simulation scene " .. scene_name)
  simulations[tip_name] = {
    checkboard = true,
    hide_health_bars = true,
    mute_alert_sounds = true,
    mute_technology_finished_sound = true,
    game_view_settings = {
      default_show_value = false,
      show_alert_gui = false,
      show_controller_gui = false,
      show_entity_info = false,
      show_quickbar = false,
      show_shortcut_bar = false,
      show_tool_bar = false,
    },
    init_update_count = 1,
    length = definition.duration,
    init = "storage.administratorio_tip_scene=" .. serialize(definition),
    update_file = update_file,
  }
end

return simulations
