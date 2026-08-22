-------------------------------------------------------------------------------
-- ADMINISTRATORIUM LOCALE OVERRIDE TESTS
--
-- Space Age's native promethium IDs are a compatibility contract. Administratorio
-- rethemes their player-facing locale while leaving those prototype IDs intact.
-------------------------------------------------------------------------------

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

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end

local function read_file(path)
  local file = assert(io.open(path, "r"))
  local contents = file:read("*a")
  file:close()
  return contents
end

local required_overrides = {
  ["asteroid-chunk-name"] = {"promethium-asteroid-chunk"},
  ["item-name"] = {
    "promethium-asteroid-chunk",
    "promethium-science-pack",
    "promethium-research-charter",
  },
  ["item-description"] = {
    "promethium-asteroid-chunk",
    "promethium-science-pack",
    "promethium-research-charter",
  },
  ["entity-name"] = {
    "huge-promethium-asteroid",
    "big-promethium-asteroid",
    "medium-promethium-asteroid",
    "small-promethium-asteroid",
  },
  ["recipe-name"] = {"promethium-science-pack", "promethium-research-charter-production"},
  ["recipe-description"] = {"promethium-science-pack", "promethium-research-charter-production"},
  ["technology-name"] = {"promethium-science-pack"},
  ["technology-description"] = {"promethium-science-pack"},
  ["achievement-name"] = {"research-with-promethium"},
  ["achievement-description"] = {"research-with-promethium"},
}

for language, marker in pairs({
  en = "Administratorium",
  fr = "Administratorium",
  ru = "Администраториум",
}) do
  test(language .. " locale overrides every visible promethium surface", function()
    local locale = require("tests.locale_helpers").load(mod_root, language)
    for section_name, keys in pairs(required_overrides) do
      local section = locale[section_name] or {}
      for _, key in ipairs(keys) do
        local value = section[key]
        assert_true(value ~= nil, language .. " missing [" .. section_name .. "] " .. key)
        assert_true(value:find(marker, 1, true) ~= nil,
          language .. " [" .. section_name .. "] " .. key .. " does not use " .. marker)
      end
    end
  end)
end

test("mod-owned prototype IDs remain promethium-compatible", function()
  local item_prototypes = read_file(mod_root .. "prototypes/item/space_age.lua")
  local recipe_prototypes = read_file(mod_root .. "prototypes/recipe/space_age.lua")
  local gating = read_file(mod_root .. "prototypes/final_fixes/colored_ink_gating.lua")

  assert_true(item_prototypes:find('name = "promethium-research-charter"', 1, true) ~= nil,
    "charter item ID should remain promethium-research-charter")
  assert_true(recipe_prototypes:find('name = "promethium-research-charter-production"', 1, true) ~= nil,
    "charter recipe ID should remain promethium-research-charter-production")
  assert_true(gating:find('["promethium-science-pack"] = "promethium-research-charter"', 1, true) ~= nil,
    "native science recipe should keep its promethium ID integration")
  assert_true(not item_prototypes:find('name = "administratorium-', 1, true),
    "the retheme must not introduce replacement Administratorium prototype IDs")
  assert_true(not recipe_prototypes:find('name = "administratorium-', 1, true),
    "the retheme must not introduce replacement Administratorium recipe IDs")
end)

print(string.format("\nAdministratorium retheme tests: %d passed, %d failed", passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do print("  FAIL: " .. err) end
  os.exit(1)
end
