-------------------------------------------------------------------------------
-- FACTORISSIMO COMPATIBILITY TESTS
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
local factorissimo = require("compat.factorissimo.runtime")

-- Factorissimo freezes the daytime of a factory floor: noon with the interior
-- lights upgrade, midnight without.
local LIT_FLOOR = 1
local DARK_FLOOR = 0.5

local function new_surface(index, daytime)
  return {valid = true, index = index, daytime = daytime, dusk = 0.25, dawn = 0.75}
end

local function new_factory(outside_surface, lights_researched)
  return {
    force = {
      valid = true,
      technologies = {["factory-interior-upgrade-lights"] = {researched = lights_researched}},
    },
    outside_surface = outside_surface,
    outside_x = 10,
    outside_y = 20,
  }
end

--- factories_by_surface: surface index -> factory enclosing everything on it.
--- methods: interface listing, defaults to a complete one.
local function mock_remote(factories_by_surface, methods)
  local calls = 0
  remote = {
    interfaces = {
      factorissimo = methods or {
        is_factorissimo_surface = true,
        find_surrounding_factory_by_surface_index = true,
      },
    },
    call = function(_, method, surface_index)
      calls = calls + 1
      if method == "is_factorissimo_surface" then
        return factories_by_surface[surface_index] ~= nil
      end
      if method == "find_surrounding_factory_by_surface_index" then
        return factories_by_surface[surface_index]
      end
      error("unexpected factorissimo call: " .. tostring(method))
    end,
  }
  return function() return calls end
end

local ORIGIN = {x = 0, y = 0}

test("a lit factory resolves to its outside surface", function()
  local nauvis = new_surface(1, 0.5)
  mock_remote({[2] = new_factory(nauvis, true)})

  local outside, unlit = factorissimo.resolve_outside_surface(new_surface(2, LIT_FLOOR), ORIGIN)

  assert_eq(outside, nauvis, "a lit factory should hand back the surface it stands on")
  assert_eq(unlit, false, "a lit factory is not dark")
  remote = nil
end)

test("an unlit factory reports itself as dark", function()
  local floor = new_surface(2, DARK_FLOOR)
  mock_remote({[2] = new_factory(new_surface(1, 0.0), false)})

  local outside, unlit = factorissimo.resolve_outside_surface(floor, ORIGIN)

  assert_eq(outside, floor, "an unlit factory stops the walk at its own floor")
  assert_eq(unlit, true, "a factory without the interior lights upgrade is dark")
  remote = nil
end)

test("nested factories resolve to the outermost surface", function()
  local nauvis = new_surface(1, 0.5)
  local outer_floor = new_surface(2, LIT_FLOOR)
  mock_remote({
    [3] = new_factory(outer_floor, true),
    [2] = new_factory(nauvis, true),
  })

  local outside, unlit = factorissimo.resolve_outside_surface(new_surface(3, LIT_FLOOR), ORIGIN)

  assert_eq(outside, nauvis, "the walk should continue out of every enclosing factory")
  assert_eq(unlit, false, "lit factories all the way out are not dark")
  remote = nil
end)

test("an unlit factory outside a lit one still reports dark", function()
  local outer_floor = new_surface(2, DARK_FLOOR)
  mock_remote({
    [3] = new_factory(outer_floor, true),
    [2] = new_factory(new_surface(1, 0.0), false),
  })

  local _, unlit = factorissimo.resolve_outside_surface(new_surface(3, LIT_FLOOR), ORIGIN)

  assert_eq(unlit, true, "a dark factory anywhere on the way out counts as dark")
  remote = nil
end)

test("a surface with no enclosing factory comes back unchanged", function()
  local nauvis = new_surface(1, 0.5)
  mock_remote({})

  local outside, unlit = factorissimo.resolve_outside_surface(nauvis, ORIGIN)

  assert_eq(outside, nauvis, "a plain surface should not be rewritten")
  assert_eq(unlit, false, "a plain surface is not dark")
  remote = nil
end)

test("without factorissimo the surface comes back unchanged", function()
  local nauvis = new_surface(1, 0.5)
  remote = {interfaces = {}}

  local outside, unlit = factorissimo.resolve_outside_surface(nauvis, ORIGIN)

  assert_eq(outside, nauvis, "no factorissimo means no resolution")
  assert_eq(unlit, false, "no factorissimo means never dark")
  assert_eq(factorissimo.available(), false, "the interface is absent")
  remote = nil
end)

test("an older factorissimo without the needed methods is never called", function()
  local floor = new_surface(2, LIT_FLOOR)
  local calls = mock_remote({[2] = new_factory(new_surface(1, 0.5), true)}, {get_factory_by_entity = true})

  local outside, unlit = factorissimo.resolve_outside_surface(floor, ORIGIN)

  assert_eq(outside, floor, "an unusable interface behaves like an absent one")
  assert_eq(unlit, false, "an unusable interface never reports dark")
  assert_eq(calls(), 0, "remote.call must not run against a missing method")
  assert_eq(factorissimo.available(), false, "an incomplete interface is not available")
  remote = nil
end)

test("a missing position or surface is handled", function()
  local floor = new_surface(2, LIT_FLOOR)
  local calls = mock_remote({[2] = new_factory(new_surface(1, 0.5), true)})

  local outside = factorissimo.resolve_outside_surface(floor, nil)
  assert_eq(outside, floor, "without a position there is nothing to resolve")
  assert_eq(calls(), 0, "a missing position should not reach the interface")

  local invalid = {valid = false}
  assert_eq(factorissimo.resolve_outside_surface(invalid, ORIGIN), invalid, "an invalid surface is handed straight back")
  assert_eq(factorissimo.resolve_outside_surface(nil, ORIGIN), nil, "a nil surface is handed straight back")
  remote = nil
end)

-------------------------------------------------------------------------------
-- HOOK REGISTRATION
-------------------------------------------------------------------------------

test("the module registers itself into the time of day point", function()
  local nauvis = new_surface(1, 0.5)
  mock_remote({[2] = new_factory(nauvis, true)})

  local outside, unlit = hooks.resolve("time_of_day_surface", new_surface(2, LIT_FLOOR), ORIGIN)

  assert_eq(outside, nauvis, "the core should reach the resolution through the hook")
  assert_eq(unlit, false, "a lit factory is not dark")
  remote = nil
end)

test("the time of day point declines a surface it has nothing to say about", function()
  mock_remote({})

  assert_eq(hooks.resolve("time_of_day_surface", new_surface(1, 0.5), ORIGIN), nil,
    "a plain surface must fall through to the core default instead of being rewritten")
  remote = nil
end)

test("the module registers the factory wall pumps as traversable", function()
  local collected = hooks.collect("tube_traversable_entities", {["pneumatic-pipe"] = true})

  assert_eq(collected["pneumatic-pipe"], true, "the core entries survive")
  assert_eq(collected["factory-inside-pump-input"], true, "inside pump is traversable")
  assert_eq(collected["factory-inside-pump-output"], true, "inside pump is traversable")
  assert_eq(collected["factory-outside-pump-input"], true, "outside pump is traversable")
  assert_eq(collected["factory-outside-pump-output"], true, "outside pump is traversable")
end)

print(("Factorissimo compatibility tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
