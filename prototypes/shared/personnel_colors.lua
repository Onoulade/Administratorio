-- Walking personnel use the existing item colors where supplied. Other roles
-- receive stable colors; legacy worker items represent the same green worker.
local function rgb(r, g, b) return {r = r, g = g, b = b, a = 1} end
local M = {colors = {
  ["worker-biter"] = rgb(0.75, 0.95, 0.65),
  ["biter-worker"] = rgb(0.75, 0.95, 0.65),
  ["biter-logistics-formation"] = rgb(0.45, 0.85, 0.55),
  ["enrolled-biter"] = rgb(0.68, 0.82, 1.00),
  ["clerical-trainee"] = rgb(0.72, 0.88, 1.00),
  ["management-trainee"] = rgb(1.00, 0.72, 0.34),
  ["union-delegate"] = rgb(0.45, 0.55, 1.00),
  ["chemical-operator"] = rgb(1.00, 0.75, 0.25),
  ["nuclear-technician"] = rgb(0.35, 1.00, 0.85),
  ["astronaut"] = rgb(0.90, 0.94, 1.00),
  ["licensed-notary"] = rgb(0.80, 0.62, 0.36),
  ["conciliation-officer"] = rgb(1.00, 0.55, 0.68),
  ["relay-clerk"] = rgb(0.35, 0.55, 0.90),
  ["cryoprint-technician"] = rgb(0.65, 1.00, 0.95),
  ["voluntary-exploration-space-miner"] = rgb(0.90, 0.35, 0.20),
  ["middle-management-managing-manager"] = rgb(0.72, 0.42, 0.90),
  ["training-briefed-middle-management-managing-manager"] = rgb(0.95, 0.48, 0.20),
  ["staffing-briefed-middle-management-managing-manager"] = rgb(0.30, 0.78, 0.38),
  ["compliance-briefed-middle-management-managing-manager"] = rgb(0.96, 0.92, 0.48),
  ["liaison-briefed-middle-management-managing-manager"] = rgb(0.25, 0.72, 0.74),
  ["orbital-briefed-middle-management-managing-manager"] = rgb(0.45, 0.34, 0.82),
  ["missionary-manager"] = rgb(0.92, 0.72, 0.88),
  ["voluntary-research-subject"] = rgb(0.90, 0.30, 0.58),
  ["geotechnical-assessment-manager"] = rgb(0.60, 0.66, 0.28),
  ["small-space-tourist"] = rgb(0.55, 0.90, 1.00),
  ["medium-space-tourist"] = rgb(0.35, 0.75, 0.95),
  ["big-space-tourist"] = rgb(0.25, 0.55, 0.90),
  ["behemoth-space-tourist"] = rgb(0.55, 0.35, 0.85),
}}
return M
