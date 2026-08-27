-------------------------------------------------------------------------------
-- AAI LOADERS COMPATIBILITY TESTS
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

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

local hooks = require("compat.hooks")

local function load_module(mod_present)
  hooks.reset()
  package.loaded["compat.aai_loaders.data"] = nil
  mods = mod_present and {["aai-loaders"] = "0.5.0"} or {}
  require("compat.aai_loaders.data")
end

test("absent AAI Loaders leaves core answers untouched", function()
  load_module(false)
  assert_eq(hooks.resolve("recipe_required_form", "aai-loader"), nil, "no form override")
  assert_eq(hooks.resolve("recipe_batch_multiplier", "aai-loader"), nil, "no batch override")
end)

test("AAI loaders register the safety and batch overrides", function()
  load_module(true)
  assert_eq(hooks.resolve("recipe_required_form", "aai-loader"), "safety-waiver", "regular loader form")
  assert_eq(hooks.resolve("recipe_required_form", "aai-fast-loader"), "safety-waiver", "fast loader form")
  assert_eq(hooks.resolve("recipe_required_form", "aai-express-loader"), "safety-waiver", "express loader form")
  assert_eq(hooks.resolve("recipe_batch_multiplier", "aai-loader"), 2, "regular loader batch")
  assert_eq(hooks.resolve("recipe_batch_multiplier", "aai-fast-loader"), 1, "fast loader batch")
  assert_eq(hooks.resolve("recipe_batch_multiplier", "aai-express-loader"), 1, "express loader batch")
end)

print(("AAI Loaders compatibility tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
