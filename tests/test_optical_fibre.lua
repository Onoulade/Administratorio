-------------------------------------------------------------------------------
-- OPTIC FIBRE TESTS
--
-- Inference Tokens are a fluid and optic fibre is the only thing that moves
-- them. Guards the three ways that could quietly stop being true: the fluid
-- gaining a barrel recipe, the fibre connecting to ordinary pipes, and a
-- consumer taking tokens as an item again.
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

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or "assertion failed") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
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

local function read_file(path)
  local handle = assert(io.open(mod_root .. path, "r"))
  local contents = handle:read("*a")
  handle:close()
  return contents
end

local fluids = read_file("prototypes/item/capsules-and-fluids.lua")
local fibre = read_file("prototypes/entity/optical_fiber.lua")
local entities = read_file("prototypes/entity/space_age.lua")
local recipes = read_file("prototypes/recipe/space_age.lua")
local pneumatic = read_file("prototypes/entity/pneumatic.lua")

local FIBRE_CATEGORY = "optical-data"
local PNEUMATIC_CATEGORY = "pneumatic-forms"

-------------------------------------------------------------------------------
-- THE FLUID
-------------------------------------------------------------------------------

test("inference tokens are a fluid, not an item", function()
  assert_true(fluids:find('type = "fluid", name = "inference-token"', 1, true) ~= nil,
    "inference-token should be declared as a fluid")
  local items = read_file("prototypes/item/space_age.lua")
  assert_true(items:find('name = "inference-token"', 1, true) == nil,
    "no item form of inference-token should survive")
end)

test("inference tokens cannot be barrelled out of the fibre", function()
  local declaration = fluids:match('([^\n]*name = "inference%-token"[^\n]*)')
  assert_true(declaration ~= nil, "the fluid declaration should be findable")
  assert_true(declaration:find("auto_barrel = false", 1, true) ~= nil,
    "a barrel recipe would let tokens travel by belt, chest, train and rocket")
end)

-------------------------------------------------------------------------------
-- THE FIBRE
-------------------------------------------------------------------------------

test("the fibre uses its own connection category", function()
  assert_true(fibre:find('FIBRE_CONNECTION_CATEGORY = "' .. FIBRE_CATEGORY .. '"', 1, true) ~= nil,
    "the fibre should declare its own connection category")
end)

local function strip_comments(source)
  return (source:gsub("%-%-[^\n]*", ""))
end

test("the fibre is isolated from ordinary pipes and from pneumatic tubes", function()
  assert_true(strip_comments(fibre):find(PNEUMATIC_CATEGORY, 1, true) == nil,
    "the fibre must not share the pneumatic tube category")
  assert_true(strip_comments(pneumatic):find(FIBRE_CATEGORY, 1, true) == nil,
    "the pneumatic tubes must not share the fibre category")
  -- A pipe with no connection_category joins the ordinary fluid network, so
  -- every fibre connection has to be categorised.
  assert_true(fibre:find("connection.connection_category = FIBRE_CONNECTION_CATEGORY", 1, true) ~= nil,
    "normal connections should be categorised")
  assert_true(fibre:find("underground", 1, true) ~= nil,
    "underground connections should be categorised too")
end)

test("both a surface and an underground fibre exist", function()
  assert_true(fibre:find('optical_fibre.name = "optical-fibre"', 1, true) ~= nil, "surface fibre missing")
  assert_true(fibre:find('optical_fibre_underground.name = "optical-fibre-to-ground"', 1, true) ~= nil,
    "underground fibre missing")
end)

-------------------------------------------------------------------------------
-- PRODUCERS AND CONSUMERS
-------------------------------------------------------------------------------

test("every machine that touches tokens does so through a fibre port", function()
  local ports = 0
  for _ in entities:gmatch('connection_category = "optical%-data"') do
    ports = ports + 1
  end
  assert_true(ports >= 3,
    "the AI Server needs an output and an input, and the Bureau needs an input")
  local filters = 0
  for _ in entities:gmatch('filter = "inference%-token"') do
    filters = filters + 1
  end
  assert_eq(filters, ports, "every fibre port should be filtered to the token fluid")
end)

test("token recipes move fluid rather than items", function()
  assert_true(recipes:find('results = {{type = "fluid", name = "inference-token", amount = 10}}', 1, true) ~= nil,
    "token production should output a fluid")
  assert_true(recipes:find('{type = "fluid", name = "inference-token", amount = 10},', 1, true) ~= nil,
    "slop production should consume the fluid")
  assert_true(recipes:find('{type = "fluid", name = "inference-token", amount = 40},', 1, true) ~= nil,
    "personnel synthesis should consume the fluid")
  assert_true(recipes:find('{type = "item", name = "inference-token"', 1, true) == nil,
    "no recipe should still treat tokens as an item")
end)

test("the fibre ports avoid the AI Server heat connection tiles", function()
  -- Heat takes -2, 0 and +2 on every side of the 7x7 footprint. A fibre port on
  -- one of those tiles would contest it with a heat pipe.
  for coordinate in entities:gmatch("position = {(-?%d+), %-3},\n%s*connection_category") do
    local value = tonumber(coordinate)
    assert_true(value ~= -2 and value ~= 0 and value ~= 2,
      "fibre port at " .. tostring(value) .. " collides with a heat connection tile")
  end
end)

print(string.format("\n=== OPTIC FIBRE TESTS ==="))
print(string.format("Passed: %d  Failed: %d  Total: %d", passed, failed, passed + failed))

if #errors > 0 then
  print("\nFAILURES:")
  for i, err in ipairs(errors) do
    print(string.format("  %d) %s", i, err))
  end
  os.exit(1)
end

print("\nAll tests passed!")
