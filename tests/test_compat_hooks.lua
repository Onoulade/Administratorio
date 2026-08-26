-------------------------------------------------------------------------------
-- COMPATIBILITY HOOK ENGINE TESTS
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

test("an unregistered point resolves to nil so the caller keeps its default", function()
  hooks.reset()

  assert_eq(hooks.resolve("time_of_day_surface", "surface"), nil, "nobody answered")
end)

test("the first handler with an answer wins", function()
  hooks.reset()
  hooks.register("point", function() return nil end)
  hooks.register("point", function(value) return value .. "-first" end)
  hooks.register("point", function(value) return value .. "-second" end)

  assert_eq(hooks.resolve("point", "x"), "x-first", "registration order decides")
end)

test("a handler can pass a second value along", function()
  hooks.reset()
  hooks.register("point", function() return "surface", true end)

  local answer, extra = hooks.resolve("point")
  assert_eq(answer, "surface", "first return value")
  assert_eq(extra, true, "second return value")
end)

test("handlers of one point do not answer another", function()
  hooks.reset()
  hooks.register("point", function() return "answer" end)

  assert_eq(hooks.resolve("other_point"), nil, "points are independent")
end)

test("collect unions every registered set into the base", function()
  hooks.reset()
  hooks.register("set", function() return {b = true} end)
  hooks.register("set", function() return {c = true} end)

  local collected = hooks.collect("set", {a = true})
  assert_eq(collected.a, true, "base entries survive")
  assert_eq(collected.b, true, "first handler contributes")
  assert_eq(collected.c, true, "second handler contributes")
end)

test("collect on an unregistered point returns the base untouched", function()
  hooks.reset()
  local base = {a = true}

  assert_eq(hooks.collect("set", base), base, "the base table itself comes back")
  assert_eq(next(base), "a", "with nothing added")
end)

test("registering after the point was read is a hard error", function()
  hooks.reset()
  hooks.collect("set", {})

  local ok, err = pcall(hooks.register, "set", function() return {} end)
  assert_eq(ok, false, "a late registration must not be silently dropped")
  assert_eq(err:find("already read") ~= nil, true, "the error names the cause: " .. tostring(err))
end)

test("reading one point does not seal another", function()
  hooks.reset()
  hooks.resolve("point")

  hooks.register("other_point", function() return "answer" end)
  assert_eq(hooks.resolve("other_point"), "answer", "unrelated points stay open")
end)

print(("Compat hook tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
