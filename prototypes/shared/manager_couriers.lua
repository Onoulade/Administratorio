-- Egg couriers: a distinct second class of Middle-Management Managing Manager.
--
-- Rule: biter eggs never leave Nauvis. Spoiled eggs hatch hostile biters, and
-- off Nauvis there is no Administration Desk, no complaint pipeline, and no way
-- to handle them. Every vanilla recipe that consumed eggs offworld is rerouted
-- through a courier instead, at exactly the vanilla egg cost.
--
-- These are not roster bloat next to the briefed managers in
-- manager_briefings.lua. Different source (eggs, not meetings), different
-- duration (30 minutes, not 3), different purpose (crossing space, not local
-- staffing).

local manager_briefings = require("prototypes.shared.manager_briefings")

local M = {}

M.REGULAR_MANAGER = manager_briefings.REGULAR_MANAGER
M.EGG_ITEM = "biter-egg"
M.EGGS_PER_COURIER = 10

-- An expired courier costs the eggs and the trip, never the manager.
M.SPOIL_TICKS = 30 * 60 * 60
M.SPOIL_RESULT = manager_briefings.REGULAR_MANAGER

M.COURIERS = {
  {
    key = "missionary",
    item = "missionary-manager",
    recipe = "missionary-manager-formation",
    destination = "aquilo",
    fate = "consumed",
    order = "j-k1",
  },
  {
    key = "cobaye",
    item = "voluntary-research-subject",
    recipe = "voluntary-research-subject-formation",
    destination = "nauvis-orbit",
    fate = "consumed",
    order = "j-k2",
  },
  {
    key = "geotechnical",
    item = "geotechnical-assessment-manager",
    recipe = "geotechnical-assessment-manager-formation",
    destination = "gleba",
    fate = "returned",
    order = "j-k3",
  },
}

M.BY_KEY = {}
for _, courier in ipairs(M.COURIERS) do
  M.BY_KEY[courier.key] = courier
end

M.ITEM_SET = {}
for _, courier in ipairs(M.COURIERS) do
  M.ITEM_SET[courier.item] = true
end

return M
