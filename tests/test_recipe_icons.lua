-------------------------------------------------------------------------------
-- RECIPE ICON TESTS
--
-- Factorio infers a recipe's icon from its main product. A recipe that produces
-- nothing has no main product, and the engine refuses to load it with
-- 'Key "icon" not found in property tree'. This walks every recipe the mod
-- declares and fails on any no-output recipe that has not set one explicitly.
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

local function assert_true(value, msg)
  if not value then error(msg or "assertion failed", 2) end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end

local recipe_sources = {
  "prototypes/recipe/space_age.lua",
  "prototypes/recipe/buildings.lua",
  "prototypes/recipe/modules.lua",
  "prototypes/recipe/resolution.lua",
  "prototypes/recipe/economy.lua",
  "prototypes/recipe/paperwork.lua",
  "prototypes/recipe/production.lua",
  "prototypes/recipe/fulgora_archives.lua",
  "prototypes/recipe/planetary_abundance.lua",
}

local function read_file(path)
  local handle = io.open(mod_root .. path, "r")
  if not handle then return nil end
  local contents = handle:read("*a")
  handle:close()
  return contents
end

--- Recipes are declared across generated loops and literal tables, so this
--- looks for the empty-results marker and checks that an icon is assigned
--- within the same declaration.
local function declarations_with_empty_results(source)
  local found = {}
  for position in source:gmatch("()results = {}") do
    -- Take the surrounding declaration: back to the previous "type = \"recipe\""
    -- and forward to the end of that table entry.
    local head = source:sub(1, position)
    local start = head:reverse():find('"epicer" = epyt', 1, true)
    local from = start and (#head - start - 13) or 1
    local chunk = source:sub(from, position + 600)
    found[#found + 1] = chunk
  end
  return found
end

test("every no-output recipe assigns an icon", function()
  local checked = 0
  for _, path in ipairs(recipe_sources) do
    local source = read_file(path)
    if source then
      for _, chunk in ipairs(declarations_with_empty_results(source)) do
        checked = checked + 1
        local name = chunk:match('name = "([^"]+)"') or "<unnamed>"
        local has_literal_icon = chunk:find("icon = ", 1, true) or chunk:find("icons = ", 1, true)
        local has_helper_icon = chunk:find("recipe_icons.from_item", 1, true)
        assert_true(has_literal_icon or has_helper_icon,
          path .. ": no-output recipe " .. name .. " must set an icon explicitly")
      end
    end
  end
  assert_true(checked >= 4,
    "the audit should reach every no-output family: intake, dispatch, payload and venting")
end)

test("the icon helper is shared rather than duplicated", function()
  local helper = read_file("prototypes/shared/recipe_icons.lua")
  assert_true(helper ~= nil, "the shared recipe icon helper should exist")

  local copies = 0
  for _, path in ipairs(recipe_sources) do
    local source = read_file(path)
    if source and source:find("local function set_recipe_icon_from_item", 1, true) then
      copies = copies + 1
    end
  end
  assert_true(copies == 0, "recipe files should require the shared helper, not redefine it")
end)

test("the helper falls back rather than erroring on an unknown prototype", function()
  local helper = read_file("prototypes/shared/recipe_icons.lua")
  assert_true(helper:find("__core__/graphics/empty.png", 1, true) ~= nil,
    "a missing prototype should degrade to an empty icon, never to a load failure")
end)

print(string.format("\n=== RECIPE ICON TESTS ==="))
print(string.format("Passed: %d  Failed: %d  Total: %d", passed, failed, passed + failed))

if #errors > 0 then
  print("\nFAILURES:")
  for i, err in ipairs(errors) do
    print(string.format("  %d) %s", i, err))
  end
  os.exit(1)
end

print("\nAll tests passed!")
