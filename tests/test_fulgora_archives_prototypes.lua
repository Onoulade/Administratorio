local passed, failed, errors = 0, 0, {}

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    errors[#errors + 1] = name .. ": " .. tostring(err)
  end
end

local function assert_true(value, message)
  if not value then error(message or "assertion failed", 2) end
end

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function deepcopy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local result = {}
  seen[value] = result
  for key, entry in pairs(value) do result[deepcopy(key, seen)] = deepcopy(entry, seen) end
  return result
end

table.deepcopy = deepcopy

local raw = {
  item = {},
  recipe = {
    ["amber-sap-nonsense-seeding"] = {
      type = "recipe",
      name = "amber-sap-nonsense-seeding",
      results = {{type = "item", name = "bullshit-ore", amount = 1}},
    },
  },
  furnace = {
    recycler = {
      type = "furnace",
      name = "recycler",
      crafting_categories = {"recycling"},
      source_inventory_size = 1,
      result_inventory_size = 12,
      energy_usage = "180kW",
      module_slots = 4,
      allowed_effects = {"quality"},
      minable = {mining_time = 0.2, result = "recycler"},
    },
  },
  lab = {
    lab = {
      type = "lab",
      name = "lab",
      inputs = {"automation-science-pack"},
      energy_usage = "60kW",
      energy_source = {type = "electric", usage_priority = "secondary-input"},
      researching_speed = 1,
      module_slots = 2,
      allowed_effects = {"consumption", "speed", "productivity", "pollution", "quality"},
      minable = {mining_time = 0.2, result = "lab"},
    },
  },
  technology = {
    recycling = {type = "technology", name = "recycling", effects = {}},
  },
}

data = {raw = raw}
function data:extend(prototypes)
  for _, prototype in ipairs(prototypes) do
    self.raw[prototype.type] = self.raw[prototype.type] or {}
    assert_true(self.raw[prototype.type][prototype.name] == nil, "duplicate prototype " .. prototype.name)
    self.raw[prototype.type][prototype.name] = prototype
  end
end

local root = debug.getinfo(1, "S").source:match("@(.*/)"):gsub("tests/$", "")
package.path = root .. "?.lua;" .. root .. "?/init.lua;" .. package.path

local taxonomy = require("prototypes.shared.paperwork_taxonomy")
dofile(root .. "prototypes/item/paperwork.lua")
for _, item in ipairs({
  {type = "item", name = "heatproof-form-stock", subgroup = "forms-printed"},
  {type = "item", name = "data-recovery-order", subgroup = "forms-work-orders"},
  {type = "item", name = "territorial-deed", subgroup = "forms-permits"},
}) do
  item.stack_size = 100
  data:extend({item})
end
dofile(root .. "prototypes/item/fulgora_archives.lua")
dofile(root .. "prototypes/recipe/fulgora_archives.lua")
dofile(root .. "prototypes/recipe/planetary_abundance.lua")
dofile(root .. "prototypes/entity/archive_recombination.lua")
dofile(root .. "prototypes/technology/fulgora_archives.lua")

local function ingredient_amount(recipe, item_name)
  for _, ingredient in ipairs(recipe and recipe.ingredients or {}) do
    if ingredient.name == item_name then return ingredient.amount end
  end
  return nil
end

local function result(recipe, item_name)
  for _, product in ipairs(recipe and recipe.results or {}) do
    if product.name == item_name then return product end
  end
  return nil
end

test("old archives recycle quickly into forms only", function()
  local recipe = assert(raw.recipe["old-archive-recycling"])
  assert_eq(recipe.energy_required, 0.5)
  assert_eq(#recipe.results, 8)
  for _, product in ipairs(recipe.results) do
    assert_true(taxonomy.is_recyclable(product.name), product.name .. " is not an eligible form")
    assert_eq(product.probability, 0.125)
  end
  assert_true(result(recipe, "redundant-rubble") == nil, "old archives must not return rubble")
end)

test("all paperwork forms recycle to paper at twenty-five percent", function()
  local paperwork_subgroups = {
    ["forms-base"] = true,
    ["forms-permits"] = true,
    ["forms-work-orders"] = true,
    ["forms-printed"] = true,
  }
  local checked = 0
  for item_name, item in pairs(raw.item) do
    if paperwork_subgroups[item.subgroup] then
      local recipe = assert(raw.recipe[item_name .. "-recycling"], item_name .. " recycling recipe missing")
      assert_eq(#recipe.ingredients, 1)
      assert_eq(recipe.ingredients[1].name, item_name)
      assert_eq(#recipe.results, 1)
      assert_eq(recipe.results[1].name, "paper")
      assert_eq(recipe.results[1].probability, 0.25)
      checked = checked + 1
    end
  end
  assert_true(checked > 0)
  for _, item_name in ipairs({
    "blank-directive",
    "management-written-proposal",
    "provisional-work-order",
    "heatproof-form-stock",
    "data-recovery-order",
    "territorial-deed",
  }) do
    assert_true(raw.recipe[item_name .. "-recycling"] ~= nil,
      item_name .. " must recycle even though it is outside Bureau eligibility")
  end
end)

test("archive-specific data and excuse recovery recipes are gone", function()
  assert_true(raw.recipe["dubious-data-recovery-fulgora"] == nil)
  assert_true(raw.recipe["basic-excuse-recovery-fulgora"] == nil)
  local salvage = assert(raw.recipe["salvaged-data-analysis-fulgora"])
  assert_true(ingredient_amount(salvage, "redundant-rubble") ~= nil)
  assert_true(ingredient_amount(salvage, "old-archive") == nil)
end)

test("archival substrate and residue no longer exist", function()
  assert_true(raw.item["archival-substrate"] == nil)
  assert_true(raw.item["archive-residue"] == nil)
  assert_true(raw.recipe["archival-substrate-production"] == nil)
  assert_true(raw.recipe["archive-residue-reprocessing"] == nil)
end)

test("bureau is an employee-built automatic multi-input processor", function()
  local bureau = assert(raw.lab["archive-recombination-bureau"])
  assert_eq(#bureau.inputs, #taxonomy.recyclable_names())
  assert_eq(bureau.module_slots, 0)
  assert_eq(bureau.energy_usage, "1W")
  assert_eq(bureau.energy_source.buffer_capacity, "2MJ")
  local sink = assert(raw["electric-energy-interface"]["archive-recombination-power-sink"])
  assert_eq(sink.energy_usage, "1MW")
  assert_eq(sink.energy_source.usage_priority, "secondary-input")
  assert_true(sink.hidden and sink.selectable_in_game == false)
  assert_true(raw.furnace["archive-recombination-bureau"] == nil)
  assert_true(raw["assembling-machine"] == nil or raw["assembling-machine"]["archive-recombination-bureau"] == nil)

  local construction = assert(raw.recipe["archive-recombination-bureau"])
  assert_eq(ingredient_amount(construction, "relay-clerk"), 1)
  assert_true(raw.recipe["archive-recombination-001"] == nil, "automatic Bureau should not expose pair recipes")
  assert_true(raw.item["archive-attempt-record"] == nil)
  assert_true(raw.item["recombination-envelope"] == nil)
end)

print(("Fulgora archive prototype tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do io.stderr:write(err .. "\n") end
  os.exit(1)
end
