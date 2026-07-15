local M = {}

M.REGULAR_MANAGER = "middle-management-managing-manager"
M.VESM = "voluntary-exploration-space-miner"
M.SPOIL_TICKS = 3 * 60 * 60

M.BRIEFINGS = {
  {
    key = "training",
    item = "training-briefed-middle-management-managing-manager",
    recipe = "middle-management-training-briefing",
    material = "iron-gear-wheel",
    material_amount = 5,
    order = "j-j1",
  },
  {
    key = "staffing",
    item = "staffing-briefed-middle-management-managing-manager",
    recipe = "middle-management-staffing-briefing",
    material = "repair-pack",
    material_amount = 5,
    order = "j-j2",
  },
  {
    key = "compliance",
    item = "compliance-briefed-middle-management-managing-manager",
    recipe = "middle-management-compliance-briefing",
    material = "blank-form",
    material_amount = 5,
    order = "j-j3",
  },
  {
    key = "liaison",
    item = "liaison-briefed-middle-management-managing-manager",
    recipe = "middle-management-liaison-briefing",
    material = "electronic-circuit",
    material_amount = 5,
    order = "j-j4",
  },
  {
    key = "orbital",
    item = "orbital-briefed-middle-management-managing-manager",
    recipe = "middle-management-orbital-briefing",
    material = "rocket-fuel",
    material_amount = 1,
    order = "j-j5",
  },
}

M.BY_KEY = {}
for _, briefing in ipairs(M.BRIEFINGS) do
  M.BY_KEY[briefing.key] = briefing
end

return M
