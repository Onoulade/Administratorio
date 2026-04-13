-------------------------------------------------------------------------------
-- RECIPE & FUEL CATEGORIES
-- All custom crafting categories defined in one place. Each category maps to
-- specific buildings (see entity definitions).
--
-- Category                    | Used by
-- ----------------------------|----------------------------------------
-- bureaucracy-registration    | Office Desk (all desk work: filing, permits, work-orders, modules)
-- bureaucratic-bootstrap     | Player character + Office Desk (starter paperwork bridge)
-- bureaucracy-resolution      | Resolution Office (all complaint processing: filing, case, brief, final)
-- resolution-handcraft        | Player character + Resolution Office (landscape complaint only)
-- bureaucracy-policy          | Union Headquarters (policies, regulations, audits, written approvals)
-- admin-greenhouse            | Greenhouse (wood, coffee)
-- watercooler-gossip          | Corporate Breakroom (gossip, coffee, promises, transit-auth)
-- union-negotiation           | Union Headquarters (union approval, grants, narrative, OSHA)
-- smelting-basic              | Stone Furnace (batch smelting w/ certificates)
-- printing                    | Printer T1 (ink-based documents)
-- printing-advanced           | Printer T2 (document duplication/copying)
-- printing-workorder          | Printer T1/T2 (direct draft-to-work-order printing)
-- pneumatic-liquify           | Form Liquifier (item -> pneumatic fluid)
-- pneumatic-solidify          | Form Solidifier (pneumatic fluid -> item)
-- propaganda-distillery        | Propaganda Distillery (admin fluid processing)
-------------------------------------------------------------------------------
local feature_flags = require("feature_flags")
local working_hours_enabled = feature_flags.working_hours_enabled()

local categories = {
  {type = "recipe-category", name = "bureaucracy-registration"},
  {type = "recipe-category", name = "bureaucratic-bootstrap"},
  {type = "recipe-category", name = "bureaucracy-resolution"},
  {type = "recipe-category", name = "resolution-handcraft"},
  {type = "recipe-category", name = "bureaucracy-policy"},
  {type = "recipe-category", name = "admin-greenhouse"},
  {type = "recipe-category", name = "watercooler-gossip"},
  {type = "recipe-category", name = "union-negotiation"},
  {type = "recipe-category", name = "smelting-basic"},
  {type = "recipe-category", name = "printing"},
  {type = "recipe-category", name = "printing-advanced"},
  {type = "recipe-category", name = "printing-workorder"},
  {type = "recipe-category", name = "pneumatic-liquify"},
  {type = "recipe-category", name = "pneumatic-solidify"},
  {type = "recipe-category", name = "propaganda-distillery"},
}

if working_hours_enabled then
  categories[#categories + 1] = {type = "module-category", name = "night-work"}
end

data:extend(categories)

local character = data.raw["character"] and data.raw["character"]["character"]
if character then
  character.crafting_categories = character.crafting_categories or {"crafting"}

  local required_categories = {
    ["bureaucratic-bootstrap"] = true,
    ["resolution-handcraft"] = true,
  }

  for _, category in ipairs(character.crafting_categories) do
    required_categories[category] = nil
  end

  for category_name in pairs(required_categories) do
    table.insert(character.crafting_categories, category_name)
  end
end
