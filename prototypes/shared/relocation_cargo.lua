-- Involuntary Relocation Cannon cargo: biter-family personnel only.
--
-- Restricting the cannon to biter-family cargo keeps rockets relevant for
-- everything else and gives the cannon a clear identity. Its permanent job is
-- courier traffic: one-tonne Missionary and Geotechnical managers outbound,
-- spent managers inbound.
--
-- Biter eggs are deliberately absent. Eggs never leave Nauvis; that is the
-- entire reason the couriers exist, and a cannon that shipped eggs would
-- reintroduce the problem it was built to solve.

local manager_briefings = require("prototypes.shared.manager_briefings")
local manager_couriers = require("prototypes.shared.manager_couriers")

local M = {}

M.TRANSFER_FORM = "involuntary-transfer-order"

-- Items per shot. Unlike the interplanetary trunk, which times every item
-- separately, the cannon moves a batch at once.
M.PAYLOAD_PER_SHOT = 5
M.SHOT_TICKS = 10 * 60

local function collect()
  local names = {
    manager_briefings.REGULAR_MANAGER,
    "biter-worker",
    "worker-biter",
    "enrolled-biter",
    "rideable-biter",
    "hired-biter-capsule",
    "clerical-trainee",
    "management-trainee",
    "union-delegate",
    "chemical-operator",
    "nuclear-technician",
    "astronaut",
    "licensed-notary",
    "conciliation-officer",
    "relay-clerk",
    "cryoprint-technician",
  }
  for _, briefing in ipairs(manager_briefings.BRIEFINGS) do
    names[#names + 1] = briefing.item
  end
  for _, courier in ipairs(manager_couriers.COURIERS) do
    names[#names + 1] = courier.item
  end
  table.sort(names)
  return names
end

M.names = collect()

function M.as_set()
  local set = {}
  for _, name in ipairs(M.names) do
    set[name] = true
  end
  return set
end

--- What a cannon will accept into its single slot: the shippable cargo above,
--- plus the transfer orders a receiving cannon files. The orders are loadable
--- but never shippable, so they cannot be fired at another planet.
function M.loadable_names()
  local names = {}
  for _, name in ipairs(M.names) do names[#names + 1] = name end
  names[#names + 1] = M.TRANSFER_FORM
  table.sort(names)
  return names
end

function M.load_recipe_name(item_name)
  return "relocation-payload-" .. item_name
end

return M
