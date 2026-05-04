local M = {}

M.colors = {
  C_WHITE = {255, 255, 255, 255},
  C_CREAM = {255, 235, 180, 255},
  C_LIGHT_YELLOW = {255, 240, 150, 255},
  C_LIGHT_BLUE = {180, 210, 255, 255},
  C_LIGHT_GREEN = {180, 255, 190, 255},
  C_LIGHT_RED = {255, 180, 180, 255},
  C_LIGHT_PURPLE = {220, 180, 255, 255},
  C_LIGHT_ORANGE = {255, 210, 140, 255},
  C_LIGHT_PINK = {255, 180, 210, 255},
  C_LIGHT_GRAY = {200, 200, 210, 255},
  C_MANILA = {235, 205, 150, 255},
  C_TAN = {210, 180, 140, 255},

  S_RED = {220, 40, 40, 230},
  S_BLUE = {40, 100, 220, 230},
  S_GREEN = {40, 180, 80, 230},
  S_ORANGE = {240, 120, 20, 230},
  S_PURPLE = {160, 50, 210, 230},
  S_YELLOW = {230, 200, 20, 230},
  S_TEAL = {20, 180, 180, 230},
  S_BROWN = {130, 80, 40, 230},
  S_PINK = {220, 60, 140, 230},
  S_GRAY = {110, 110, 120, 230},
  S_DARK_RED = {140, 20, 20, 240},
  S_DARK_BLUE = {20, 40, 140, 240},
  S_DARK_GREEN = {20, 90, 40, 240},
  S_GOLD = {210, 160, 20, 230},

  SC_RED = {180, 20, 20, 240},
  SC_BLUE = {20, 40, 160, 240},
  SC_GREEN = {20, 130, 40, 240},
  SC_ORANGE = {200, 90, 10, 240},
  SC_PURPLE = {120, 20, 160, 240},
  SC_GRAY = {70, 70, 80, 220},
  SC_DARK = {40, 35, 30, 240},
  SC_TEAL = {10, 120, 120, 240},
  SC_GOLD = {180, 140, 10, 240},
  SC_BROWN = {100, 60, 20, 240},
  SC_PINK = {180, 30, 90, 240},
  SC_BLACK = {10, 10, 10, 250},
}

local function rgba_from_color(name, alpha)
  local color = M.colors[name]
  return {
    r = color[1] / 255,
    g = color[2] / 255,
    b = color[3] / 255,
    a = alpha or color[4] / 255,
  }
end

local function tint(primary, secondary, tertiary, quaternary)
  return {
    primary = primary,
    secondary = secondary or primary,
    tertiary = tertiary or secondary or primary,
    quaternary = quaternary or tertiary or secondary or primary,
  }
end

M.recipe_tints = {
  ["government-grant-production"] = tint(rgba_from_color("SC_GOLD", 1)),
  ["tax-audit"] = tint(rgba_from_color("S_DARK_GREEN", 1)),
  ["narrative-production"] = tint(rgba_from_color("SC_GRAY", 1)),
  ["white-paper-production"] = tint({r = 0.86, g = 0.9, b = 1.0, a = 1}),
  ["policy-production"] = tint(rgba_from_color("SC_BLUE", 1)),
  ["regulation-production"] = tint(rgba_from_color("SC_RED", 1)),
  ["management-written-proposal"] = tint(rgba_from_color("SC_PURPLE", 1)),
  ["union-approval-production"] = tint({r = 0.4, g = 0.6, b = 1.0, a = 1}),
  ["osha-scrubbing"] = tint(rgba_from_color("S_DARK_RED", 1)),
  ["osha-violation-recycling"] = tint(rgba_from_color("SC_RED", 1)),
  ["overtime-exemption"] = tint(rgba_from_color("S_PINK", 1)),
}

local function copy_color(color)
  return {r = color.r, g = color.g, b = color.b, a = color.a}
end

function M.recipe_tint(recipe_name)
  local source = M.recipe_tints[recipe_name]
  if not source then return nil end
  return {
    primary = copy_color(source.primary),
    secondary = copy_color(source.secondary),
    tertiary = copy_color(source.tertiary),
    quaternary = copy_color(source.quaternary),
  }
end

return M
