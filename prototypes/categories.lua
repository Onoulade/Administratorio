-------------------------------------------------------------------------------
-- RECIPE & FUEL CATEGORIES
-- All custom crafting categories defined in one place. Each category maps to
-- specific buildings (see entity definitions).
--
-- Category                    | Used by
-- ----------------------------|----------------------------------------
-- bureaucracy-registration    | Office Desk + Field Office (filing, permits, work-orders)
-- bureaucracy-modules         | Office Desk (subpoena/audit/embezzlement module drafting)
-- bureaucratic-bootstrap      | Player character + Office Desk + Field Office (Nauvis/shared bootstrap)
-- *-<planet>                  | Office Desk; player character for bootstrap variants
-- bureaucracy-resolution      | Resolution Office (all complaint processing: filing, case, brief, final)
-- resolution-handcraft        | Player character + Resolution Office (landscape complaint only)
-- bureaucracy-policy          | Union Headquarters (policies, regulations, audits, written approvals)
-- biter-training              | Formation Center (all biter worker assignments and specialist training)
-- admin-greenhouse            | Greenhouse (wood, coffee)
-- watercooler-gossip          | Corporate Breakroom (gossip, coffee, promises, transit-auth)
-- union-negotiation           | Union Headquarters (union approval, grants, narrative, OSHA)
-- smelting-basic              | Stone Furnace (batch smelting w/ certificates)
-- printing                    | Printer T1 (ink-based documents)
-- printing-advanced           | Printer T2 (document duplication/copying)
-- printing-workorder          | Printer T1/T2 (direct draft-to-work-order printing)
-- orbital-printing            | Printer T2/Laser Printer (advanced asteroid paperwork)
-- propaganda-distillery        | Propaganda Distillery (admin fluid processing)
-- pneumatic-intake            | Tube Intake (hidden no-output intake validation)
-- interplanetary-dispatch     | Interplanetary Terminus (hidden outbound payload validation)
-- ai-inference                | AI Server (tokens and slop from a training corpus)
-- slop-refining               | AI Server (slop into fabricated paperwork)
-- citation-handling           | AI Server (venting and fact-checking hallucinations)
-------------------------------------------------------------------------------
local feature_flags = require("feature_flags")
local bureaucracy_categories = require("prototypes.shared.bureaucracy_categories")
local working_hours_enabled = feature_flags.working_hours_enabled()
local space_age_enabled = feature_flags.space_age_enabled()

local categories = {
  {type = "recipe-category", name = "bureaucracy-registration"},
  {type = "recipe-category", name = "bureaucracy-modules"},
  {type = "recipe-category", name = "bureaucratic-bootstrap"},
  {type = "recipe-category", name = "bureaucracy-resolution"},
  {type = "recipe-category", name = "resolution-handcraft"},
  {type = "recipe-category", name = "bureaucracy-policy"},
  {type = "recipe-category", name = "biter-training"},
  {type = "recipe-category", name = "admin-greenhouse"},
  {type = "recipe-category", name = "watercooler-gossip"},
  {type = "recipe-category", name = "union-negotiation"},
  {type = "recipe-category", name = "smelting-basic"},
  {type = "recipe-category", name = "printing"},
  {type = "recipe-category", name = "printing-advanced"},
  {type = "recipe-category", name = "printing-workorder"},
  {type = "recipe-category", name = "propaganda-distillery"},
  {type = "recipe-category", name = "pneumatic-intake"},
}

if space_age_enabled then
  for _, planet_name in ipairs(bureaucracy_categories.OFFWORLD_PLANETS) do
    categories[#categories + 1] = {
      type = "recipe-category",
      name = bureaucracy_categories.bootstrap_for_planet(planet_name),
    }
    categories[#categories + 1] = {
      type = "recipe-category",
      name = bureaucracy_categories.registration_for_planet(planet_name),
    }
  end

  categories[#categories + 1] = {type = "recipe-category", name = "interplanetary-dispatch"}
  categories[#categories + 1] = {type = "recipe-category", name = "ai-inference"}
  categories[#categories + 1] = {type = "recipe-category", name = "slop-refining"}
  categories[#categories + 1] = {type = "recipe-category", name = "citation-handling"}
  categories[#categories + 1] = {type = "recipe-category", name = "printing-chromatic"}
  categories[#categories + 1] = {type = "recipe-category", name = "printing-multicolor"}
  categories[#categories + 1] = {type = "recipe-category", name = "archive-reassignment"}
  categories[#categories + 1] = {type = "recipe-category", name = "bureaucracy-certification"}
  categories[#categories + 1] = {type = "recipe-category", name = "bureaucracy-conciliation"}
  categories[#categories + 1] = {type = "recipe-category", name = "hostile-acquisition"}
  categories[#categories + 1] = {type = "recipe-category", name = "capture-bureau-runtime"}
  categories[#categories + 1] = {type = "recipe-category", name = "territorial-arbitration"}
  categories[#categories + 1] = {type = "recipe-category", name = "workforce-formation"}
  categories[#categories + 1] = {type = "recipe-category", name = "orbital-bureaucracy"}
  categories[#categories + 1] = {type = "recipe-category", name = "orbital-printing"}
end

if working_hours_enabled then
  categories[#categories + 1] = {type = "module-category", name = "night-work"}
  categories[#categories + 1] = {type = "module-category", name = "unstaffed-operations"}
end

data:extend(categories)

local character = data.raw["character"] and data.raw["character"]["character"]
if character then
  character.crafting_categories = character.crafting_categories or {"crafting"}

  local required_categories = {
    ["bureaucratic-bootstrap"] = true,
    ["resolution-handcraft"] = true,
  }

  if space_age_enabled then
    for _, planet_name in ipairs(bureaucracy_categories.OFFWORLD_PLANETS) do
      required_categories[bureaucracy_categories.bootstrap_for_planet(planet_name)] = true
    end
  end

  for _, category in ipairs(character.crafting_categories) do
    required_categories[category] = nil
  end

  for category_name in pairs(required_categories) do
    table.insert(character.crafting_categories, category_name)
  end
end
