-- Player-facing acceptance checks for the concise custom-mechanics guides.
-- Run: lua tests/test_tips_and_tricks.lua
local passed, failed = 0, 0
local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then passed = passed + 1 else
    failed = failed + 1
    print("FAIL " .. name .. ": " .. tostring(err))
  end
end
local function check(value, message)
  assert(value, message)
end
local root = (debug.getinfo(1, "S").source:match("@(.*/)") or "./"):gsub("tests/$", "")
package.path = root .. "?.lua;" .. root .. "?/init.lua;" .. package.path
local locale = require("tests.locale_helpers")
local localized = {}
for _, language in ipairs({"en", "fr", "ru"}) do
  localized[language] = {
    names = locale.section(root, language, "tips-and-tricks-item-name"),
    descriptions = locale.section(root, language, "tips-and-tricks-item-description"),
    categories = locale.section(root, language, "tips-and-tricks-category-name"),
  }
end
local function load_tips(space_age, working_hours, quality)
  mods = { ["space-age"] = space_age and "2.0.0" or nil, quality = quality and "2.0.0" or nil }
  settings = {startup = {["administratorio-enable-working-hours"] = {value = working_hours}}}
  local tips, categories = {}, {}
  data = {raw = {}}
  function data:extend(entries)
    for _, entry in ipairs(entries) do
      local collection = entry.type == "tips-and-tricks-item" and tips or categories
      check(not collection[entry.name], "duplicate prototype " .. entry.name)
      collection[entry.name] = entry
    end
  end
  dofile(root .. "prototypes/tips-and-tricks.lua")
  return tips, categories
end
local function contains(trigger, kind, key, value)
  if not trigger then return false end
  if trigger.type == kind and trigger[key] == value then return true end
  for _, child in ipairs(trigger.triggers or {}) do
    if contains(child, kind, key, value) then return true end
  end
  return false
end
local function rich_tags(text)
  local tags = {}
  for tag in text:gmatch("%[[%w%-]+=[^%]]+%]") do tags[#tags + 1] = tag end
  table.sort(tags)
  return table.concat(tags, "\n")
end

for _, space_age in ipairs({false, true}) do
  for _, working_hours in ipairs({false, true}) do
    for _, quality in ipairs({false, true}) do
      local label = ("SA=%s hours=%s quality=%s"):format(tostring(space_age), tostring(working_hours), tostring(quality))
      test("complete, localized, feature-safe catalog: " .. label, function()
        local tips, categories = load_tips(space_age, working_hours, quality)
        local function present(id) return tips["administratorio-" .. id] ~= nil end
        check(present("working-hours") == working_hours, "night guide feature gate")
        check(present("administrative-clock") == working_hours, "clock feature gate")
        check(present("quality") == quality, "Quality must work independently of Space Age")
        check(present("unstaffed-operations") == (space_age and working_hours), "waiver technology feature gate")
        check(present("personnel-routing") == space_age, "signed paths feature gate")
        check(present("interplanetary-terminus") == space_age, "trunk feature gate")
        local titles = {}
        for name, item in pairs(tips) do
          check(categories[item.category], name .. " has no category")
          local visual = name == "administratorio-pneumatic-transport" or name == "administratorio-passenger-boarding" or name == "administratorio-personnel-routing" or name == "administratorio-personnel-multisign"
          check((item.simulation ~= nil) == visual, name .. " has an unexpected scene")
          if item.is_title then
            titles[item.category] = (titles[item.category] or 0) + 1
            check(item.indent == 0, "title indentation")
          else check(item.indent == 1, "child indentation") end
          check(item.trigger or item.starting_status == "unlocked", name .. " has no unlock")
          for language, text in pairs(localized) do
            local description_key = item.localised_description and item.localised_description[1]:match("%.(.+)") or name
            local description = text.descriptions[description_key]
            check(description and #description > 0, language .. " missing description " .. description_key)
            if item.localised_name then
              local category_key = item.localised_name[1]:match("%.(.+)")
              check(text.categories[category_key], language .. " missing category " .. category_key)
            else check(text.names[name], language .. " missing name " .. name) end
            -- Rich references to optional entities must not leak into base-only tips.
            if not space_age then
              for _, forbidden in ipairs({"interplanetary-terminus", "personnel-routing-sign", "capture-bureau", "foundry", "public-train-stop"}) do
                check(not description:find("[entity=" .. forbidden .. "]", 1, true), name .. " references optional " .. forbidden)
              end
            end
          end
        end
        for name in pairs(categories) do check(titles[name] == 1, name .. " needs exactly one title") end
        local hiring = tips["administratorio-biter-employment"].localised_description[1]
        check(hiring:find(space_age and "space-age-enrollment" or "biter-employment", 1, true), "hiring rules must match installed game")
      end)
    end
  end
end

local tips = load_tips(true, true, true)
test("custom rules unlock when usable, including early train and egg setup", function()
  local expected = {
    ["transit-authorization"] = "railway",
    ["passenger-rail-service"] = "passenger-rail-service",
    ["passenger-boarding"] = "passenger-rail-service",
    ["passenger-unboarding"] = "passenger-rail-service",
    ["passenger-signals"] = "passenger-rail-service",
    ["tube-circuits"] = "pneumatic-form-transport",
    ["tube-limits"] = "pneumatic-form-transport",
    ["tube-pump"] = "tube-pump",
    ["personnel-counts"] = "personnel-routing",
    ["personnel-circuits"] = "personnel-routing-multisign",
    ["pentapod-bargaining"] = "planet-discovery-gleba",
    ["ai-cooling"] = "aquilo-ai-inference",
    ["biter-employment"] = "biter-employment",
  }
  for id, technology in pairs(expected) do
    check(contains(tips["administratorio-" .. id].trigger, "research", "technology", technology), id .. " unlocks too late or from wrong technology")
  end
  for _, id in ipairs({"biter-complaints", "visitor-routing", "desk-signals", "frustration", "hard-mode", "evolution-approvals"}) do
    check(contains(tips["administratorio-" .. id].trigger, "unlock-recipe", "recipe", "admin-station"), id .. " must explain service before placing the first desk")
  end
end)

local function unlocked(trigger, technologies, recipes)
  if trigger.type == "research" then return technologies[trigger.technology] == true end
  if trigger.type == "unlock-recipe" then return recipes[trigger.recipe] == true end
  if trigger.type == "and" then
    for _, child in ipairs(trigger.triggers) do
      if not unlocked(child, technologies, recipes) then return false end
    end
    return true
  end
  if trigger.type == "or" then
    for _, child in ipairs(trigger.triggers) do
      if unlocked(child, technologies, recipes) then return true end
    end
    return false
  end
  error("unexpected progression trigger " .. trigger.type)
end

test("placement guides precede construction and circuit guides require wires", function()
  for id, recipe in pairs({["field-office"] = "field-office", ["administrative-clock"] = "administrative-clock", ["biter-station"] = "biter-station", ["worker-machines"] = "biter-station"}) do
    local trigger = tips["administratorio-" .. id].trigger
    check(not unlocked(trigger, {}, {}), id .. " appears before availability")
    check(unlocked(trigger, {}, {[recipe] = true}), id .. " requires building before teaching layout")
  end
  for _, id in ipairs({"desk-signals", "tube-circuits", "passenger-signals", "personnel-counts", "terminus-circuits"}) do
    local trigger = tips["administratorio-" .. id].trigger
    local subjects = { ["circuit-network"] = false }
    local recipes = {}
    local function learn(t)
      if t.type == "research" and t.technology ~= "circuit-network" then subjects[t.technology] = true end
      if t.type == "unlock-recipe" then recipes[t.recipe] = true end
      for _, child in ipairs(t.triggers or {}) do learn(child) end
    end
    learn(trigger)
    check(not unlocked(trigger, subjects, recipes), id .. " appears before circuit access")
    check(not unlocked(trigger, {["circuit-network"] = true}, {}), id .. " appears before its system")
    subjects["circuit-network"] = true
    check(unlocked(trigger, subjects, recipes), id .. " stays locked when usable")
  end
end)

test("advanced rules wait for the relevant activity", function()
  local travel = tips["administratorio-offworld-economy"].trigger
  check(not unlocked(travel, {["space-platform"] = true}, {}), "platform bootstrap is too early for planetary funding")
  for _, planet in ipairs({"vulcanus", "gleba", "fulgora", "aquilo"}) do
    check(unlocked(travel, {["planet-discovery-" .. planet] = true}, {}), "funding missing before departure to " .. planet)
  end
  local spoilage = tips["administratorio-personnel-spoilage"].trigger
  check(not unlocked(spoilage, {["personnel-routing"] = true}, {}), "path setup has no expiring personnel yet")
  for _, technology in ipairs({"management-formation", "egg-courier-formation"}) do
    check(not unlocked(spoilage, {[technology] = true}, {}), "walking rules need signed paths")
    check(unlocked(spoilage, {[technology] = true, ["personnel-routing"] = true}, {}), "missing spoilage rules for " .. technology)
  end
end)

test("recipe catalogs, packing lists and upgrade tables are retired", function()
  for _, id in ipairs({"bullshit-economy", "admin-science", "propaganda-distillery", "vulcanus-manifest", "gleba-manifest", "aquilo-manifest", "chromatic-inks", "multicolor-forms", "orbital-employment-damage", "orbital-employment-capacity", "trajectory-compliance-speed", "trunk-capacity"}) do
    check(not tips["administratorio-" .. id], "recipe/stat tip still registered: " .. id)
  end
end)

test("translations have matching keys and rich references", function()
  for _, language in ipairs({"fr", "ru"}) do
    for _, section in ipairs({"names", "descriptions", "categories"}) do
      for key, value in pairs(localized.en[section]) do
        local translated = localized[language][section][key]
        check(translated, language .. " missing " .. key)
        check(rich_tags(value) == rich_tags(translated), language .. " reference mismatch " .. key)
      end
      for key in pairs(localized[language][section]) do
        check(localized.en[section][key], language .. " stale key " .. key)
      end
    end
  end
end)

test("tips remain brief and avoid recipe lists", function()
  for language, text in pairs(localized) do
    for key, description in pairs(text.descriptions) do
      local plain = description:gsub("%[[^%]]+%]", " item "):gsub("\\n", " ")
      local words = 0
      for _ in plain:gmatch("%S+") do words = words + 1 end
      check(words <= 110, language .. " " .. key .. " has " .. words .. " words; split by task")
      check(not description:find("[recipe=", 1, true), key .. " should explain behavior, not list recipes")
    end
  end
end)

test("layout-critical measurements survive the rewrite", function()
  local text = localized.en.descriptions
  local required = {
    ["visitor-routing"] = {"256 tiles", "96 tiles"},
    ["field-office"] = {"200 tiles", "2 crafts", "10 field workers"},
    ["biter-station"] = {"30 tiles", "closest station"},
    ["biterport"] = {"25 tiles", "55", "50 tiles", "each axis"},
    ["tube-limits"] = {"120 tiles", "10 items"},
    ["passenger-rail-service"] = {"2.75 tiles", "4 tiles", "24 tiles", "24 unresolved"},
    ["passenger-boarding"] = {"0.85 tiles", "24 waiting", "does not hard-close"},
    ["capture-bureau"] = {"32 tiles", "48 tiles"},
    ["ai-cooling"] = {"950", "4 MW"},
  }
  for id, phrases in pairs(required) do
    for _, phrase in ipairs(phrases) do
      check(text["administratorio-" .. id]:find(phrase, 1, true), id .. " omits " .. phrase)
    end
  end
end)

print(("Tips & Tricks tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
