-------------------------------------------------------------------------------
-- INTERPLANETARY TUBE RUNTIME TESTS
--
-- The trunk's load-bearing invariants: it is a separate pool from the local
-- pneumatic network, capacity limits how many items are in flight, transit is
-- per item, colored paperwork waits for the chromatic tier, arrivals are never
-- auto-fed anywhere, and one planet hosts one Terminus.
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

defines = {
  inventory = {furnace_source = 1, furnace_result = 2, chest = 3},
  entity_status_diode = {red = 1, yellow = 2, green = 3},
  direction = {north = 0, east = 2, south = 4, west = 6},
  wire_connector_id = {circuit_red = 1, circuit_green = 2},
}
game = {surfaces = {}, tick = 0, connected_players = {}}
storage = {}

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

package.loaded["scripts.interplanetary_tube"] = nil
local tube = require("scripts.interplanetary_tube")
local C = require("scripts.constants")

-------------------------------------------------------------------------------
-- FAKES
-------------------------------------------------------------------------------

local function new_inventory(capacity)
  local inventory = {valid = true, contents = {}, capacity = capacity or 10}

  local function key(name, quality)
    return name .. "/" .. (quality or "normal")
  end

  function inventory.total()
    local total = 0
    for _, count in pairs(inventory.contents) do total = total + count end
    return total
  end

  function inventory.is_full()
    return inventory.total() >= inventory.capacity
  end

  function inventory.insert(stack)
    local room = inventory.capacity - inventory.total()
    local inserted = math.min(room, stack.count or 1)
    if inserted <= 0 then return 0 end
    local k = key(stack.name, stack.quality)
    inventory.contents[k] = (inventory.contents[k] or 0) + inserted
    return inserted
  end

  function inventory.remove(stack)
    local k = key(stack.name, stack.quality)
    local held = inventory.contents[k] or 0
    local removed = math.min(held, stack.count or 1)
    if removed <= 0 then return 0 end
    inventory.contents[k] = held - removed
    if inventory.contents[k] == 0 then inventory.contents[k] = nil end
    return removed
  end

  function inventory.get_item_count(spec)
    if type(spec) == "table" then return inventory.contents[key(spec.name, spec.quality)] or 0 end
    local total = 0
    for k, count in pairs(inventory.contents) do
      if k:match("^(.*)/") == spec then total = total + count end
    end
    return total
  end

  return inventory
end

local next_unit_number = 0

local function new_terminus(planet_name, researched, requests)
  next_unit_number = next_unit_number + 1

  local technologies = {}
  for _, name in ipairs(researched or {}) do
    technologies[name] = {researched = true}
  end

  local entity
  entity = {
    valid = true,
    name = C.TERMINUS_NAME,
    unit_number = next_unit_number,
    position = {x = 0, y = 0},
    active = true,
    custom_status = nil,
    force = {valid = true, index = 1, technologies = technologies},
    outbound = new_inventory(4),
    arrivals = new_inventory(8),
    requests = requests or {},
  }
  entity.surface = {
    valid = true,
    platform = nil,
    planet = {valid = true, name = planet_name},
    spill_item_stack = function() end,
  }
  entity.surface.planet.surface = entity.surface

  function entity.get_inventory(which)
    if which == defines.inventory.furnace_source then return entity.outbound end
    if which == defines.inventory.furnace_result then return entity.arrivals end
    return nil
  end

  function entity.get_control_behavior() return {} end

  function entity.get_circuit_network(connector)
    if connector ~= defines.wire_connector_id.circuit_red then return nil end
    local signals = {}
    for _, request in ipairs(entity.requests) do
      signals[#signals + 1] = {
        signal = {type = "item", name = request.name, quality = request.quality},
        count = request.count or 1,
      }
    end
    if #signals == 0 then return nil end
    return {signals = signals}
  end

  return entity
end

local function register(entity)
  tube.ensure_storage()
  storage.terminus_registry[entity.unit_number] = {
    entity = entity,
    planet = entity.surface.planet.name,
    force_index = entity.force.index,
  }
end

local function reset()
  storage = {}
  next_unit_number = 0
  tube.ensure_storage()
end

local BASE = {C.TRUNK_BASE_TECH}

local payloads = require("prototypes.shared.interplanetary_payloads")

local function contains(list, value)
  for _, entry in ipairs(list) do
    if entry == value then return true end
  end
  return false
end

-------------------------------------------------------------------------------
-- PAYLOAD TIERS
-------------------------------------------------------------------------------

test("the base trunk tier carries regular paperwork and no colored forms", function()
  local chromatic = payloads.chromatic_set()
  for _, name in ipairs(payloads.regular) do
    assert_true(not chromatic[name], name .. " is a regular payload and must not be chromatic")
  end
  assert_true(contains(payloads.regular, "blank-form"), "regular payloads should carry blank forms")
  assert_true(contains(payloads.regular, "taxpayer-money"), "regular payloads should carry taxpayer money")
end)

test("colored paperwork and Space Age charters are chromatic-tier only", function()
  local regular = {}
  for _, name in ipairs(payloads.regular) do regular[name] = true end
  for _, name in ipairs({
    "blank-cyan-form", "blank-yellow-form", "blank-magenta-form",
    "cyan-yellow-form", "cyan-magenta-form", "yellow-magenta-form",
    "trichromatic-permit", "unified-operations-charter", "promethium-research-charter",
  }) do
    assert_true(not regular[name], name .. " must not ride the base trunk tier")
    assert_true(payloads.chromatic_set()[name], name .. " should be a chromatic payload")
  end
end)

test("every trunk payload has a dispatch recipe name and the set covers both tiers", function()
  local all = payloads.all()
  assert_eq(#all, #payloads.regular + #payloads.chromatic, "all() should be the union of both tiers")
  local set = payloads.as_set()
  for _, name in ipairs(all) do
    assert_true(set[name], name .. " should be in the payload set")
  end
  assert_eq(payloads.dispatch_recipe_name("blank-form"), "interplanetary-dispatch-blank-form",
    "dispatch recipes should be prefixed per item")
end)

-------------------------------------------------------------------------------
-- TIER LADDERS
-------------------------------------------------------------------------------

test("the base tier opens at capacity three, not one", function()
  local capacity, transit = tube.get_tier({valid = true, index = 1, technologies = {}})
  assert_eq(capacity, 3, "a single in-flight document empire-wide would read as a broken machine")
  assert_eq(transit, 30 * 60, "the base tier should take 30 seconds per item")
end)

test("each capacity tier raises capacity and cuts transit together", function()
  local previous_capacity, previous_transit = C.TRUNK_BASE_CAPACITY, C.TRUNK_BASE_TRANSIT_TICKS
  local technologies = {}
  for _, tier in ipairs(C.TRUNK_TIERS) do
    technologies[tier.technology] = {researched = true}
    local capacity, transit = tube.get_tier({valid = true, index = 1, technologies = technologies})
    assert_true(capacity > previous_capacity, tier.technology .. " should widen the trunk")
    assert_true(transit < previous_transit, tier.technology .. " should shorten transit")
    previous_capacity, previous_transit = capacity, transit
  end
  assert_eq(previous_capacity, 20, "the top tier should carry 20 items")
  assert_eq(previous_transit, 60, "the top tier should take one second per item")
end)

test("the trunk stays far narrower than the local pneumatic pool", function()
  local top = C.TRUNK_TIERS[#C.TRUNK_TIERS].capacity
  local local_pool = C.TUBE_BASE_CAPACITY
  for _, bonus in pairs(C.TUBE_CAPACITY_TECHS) do local_pool = local_pool + bonus end
  assert_true(top < local_pool,
    "a fully researched trunk must never rival the local pool, or rockets stop mattering")
end)

-------------------------------------------------------------------------------
-- PAYLOAD GATING
-------------------------------------------------------------------------------

test("the base tier refuses colored paperwork", function()
  local force = {valid = true, index = 1, technologies = {[C.TRUNK_BASE_TECH] = {researched = true}}}
  assert_true(tube.can_force_carry(force, "blank-form"), "regular paperwork should cross the base trunk")
  assert_true(not tube.can_force_carry(force, "cyan-yellow-form"),
    "colored paperwork must wait for the chromatic tier")
end)

test("the chromatic tier admits the colored set", function()
  local force = {valid = true, index = 1, technologies = {[C.TRUNK_CHROMATIC_TECH] = {researched = true}}}
  assert_true(tube.can_force_carry(force, "cyan-yellow-form"), "the chromatic tier should carry colored forms")
  assert_true(tube.can_force_carry(force, "promethium-research-charter"), "charters should cross once chromatic")
end)

test("the trunk refuses anything that is not a payload", function()
  local force = {valid = true, index = 1, technologies = {[C.TRUNK_CHROMATIC_TECH] = {researched = true}}}
  for _, name in ipairs({"iron-plate", "biter-egg", "ai-server"}) do
    assert_true(not tube.can_force_carry(force, name), name .. " is not trunk payload")
  end
end)

-------------------------------------------------------------------------------
-- TRANSFER
-------------------------------------------------------------------------------

test("a requested form crosses from another planet and lands in the arrivals buffer", function()
  reset()
  local nauvis = new_terminus("nauvis", BASE)
  nauvis.outbound.insert{name = "blank-form", count = 1}
  local vulcanus = new_terminus("vulcanus", BASE, {{name = "blank-form", quality = "normal", count = 1}})
  register(nauvis)
  register(vulcanus)

  tube.on_tick{tick = 0}
  assert_eq(#storage.terminus_flights, 1, "a request should put one item in flight")
  assert_eq(nauvis.outbound.get_item_count("blank-form"), 0, "the source should have handed the form over")
  assert_eq(vulcanus.arrivals.get_item_count("blank-form"), 0, "the form should still be travelling")

  tube.on_tick{tick = C.TRUNK_BASE_TRANSIT_TICKS}
  assert_eq(#storage.terminus_flights, 0, "the flight should have landed")
  assert_eq(vulcanus.arrivals.get_item_count("blank-form"), 1, "the form should land in the arrivals buffer")
end)

test("transit is per item, so several may be in flight at once", function()
  reset()
  local nauvis = new_terminus("nauvis", BASE)
  nauvis.outbound.insert{name = "blank-form", count = 3}
  local vulcanus = new_terminus("vulcanus", BASE, {{name = "blank-form", quality = "normal", count = 3}})
  register(nauvis)
  register(vulcanus)

  tube.on_tick{tick = 0}
  tube.on_tick{tick = 1}
  tube.on_tick{tick = 2}
  assert_eq(#storage.terminus_flights, 3, "three separate items should be crossing simultaneously")
end)

test("capacity caps how many items are in flight", function()
  reset()
  local nauvis = new_terminus("nauvis", BASE)
  nauvis.outbound.insert{name = "blank-form", count = 4}
  local vulcanus = new_terminus("vulcanus", BASE, {{name = "blank-form", quality = "normal", count = 4}})
  register(nauvis)
  register(vulcanus)

  for tick = 0, 10 do tube.on_tick{tick = tick} end
  assert_eq(#storage.terminus_flights, C.TRUNK_BASE_CAPACITY,
    "the trunk should refuse to exceed its capacity")
end)

test("the base tier will not move a colored form even when asked", function()
  reset()
  local nauvis = new_terminus("nauvis", BASE)
  nauvis.outbound.insert{name = "cyan-yellow-form", count = 1}
  local vulcanus = new_terminus("vulcanus", BASE, {{name = "cyan-yellow-form", quality = "normal", count = 1}})
  register(nauvis)
  register(vulcanus)

  tube.on_tick{tick = 0}
  assert_eq(#storage.terminus_flights, 0, "colored paperwork must not cross the base trunk")
  assert_eq(nauvis.outbound.get_item_count("cyan-yellow-form"), 1, "the form should stay put")
end)

test("nothing crosses between two Terminuses on the same planet", function()
  reset()
  local a = new_terminus("nauvis", BASE)
  a.outbound.insert{name = "blank-form", count = 1}
  local b = new_terminus("nauvis", BASE, {{name = "blank-form", quality = "normal", count = 1}})
  register(a)
  register(b)

  tube.on_tick{tick = 0}
  assert_eq(#storage.terminus_flights, 0, "the trunk links planets, not buildings on one planet")
end)

test("the trunk will not dispatch into a full arrivals buffer", function()
  reset()
  local nauvis = new_terminus("nauvis", BASE)
  nauvis.outbound.insert{name = "blank-form", count = 1}
  local vulcanus = new_terminus("vulcanus", BASE, {{name = "blank-form", quality = "normal", count = 1}})
  vulcanus.arrivals.capacity = 0
  register(nauvis)
  register(vulcanus)

  tube.on_tick{tick = 0}
  assert_eq(#storage.terminus_flights, 0, "back-pressure should stop the dispatch at the source")
  assert_eq(nauvis.outbound.get_item_count("blank-form"), 1, "the form should stay in the outbound buffer")
end)

test("a buffer that fills mid-flight holds the item rather than voiding it", function()
  reset()
  local nauvis = new_terminus("nauvis", BASE)
  nauvis.outbound.insert{name = "blank-form", count = 1}
  local vulcanus = new_terminus("vulcanus", BASE, {{name = "blank-form", quality = "normal", count = 1}})
  register(nauvis)
  register(vulcanus)

  tube.on_tick{tick = 0}
  assert_eq(#storage.terminus_flights, 1, "the form should be crossing")

  -- The player fills the arrivals buffer while the form is still in transit.
  vulcanus.arrivals.capacity = 0

  tube.on_tick{tick = C.TRUNK_BASE_TRANSIT_TICKS}
  assert_eq(#storage.terminus_flights, 1, "the flight should wait rather than be destroyed")
  assert_eq(vulcanus.custom_status.diode, defines.entity_status_diode.red,
    "a stalled trunk should signal the back-pressure")
end)

test("arrivals are never auto-fed anywhere", function()
  reset()
  local nauvis = new_terminus("nauvis", BASE)
  nauvis.outbound.insert{name = "blank-form", count = 1}
  local vulcanus = new_terminus("vulcanus", BASE, {{name = "blank-form", quality = "normal", count = 1}})
  register(nauvis)
  register(vulcanus)

  tube.on_tick{tick = 0}
  tube.on_tick{tick = C.TRUNK_BASE_TRANSIT_TICKS}
  for tick = C.TRUNK_BASE_TRANSIT_TICKS + 1, C.TRUNK_BASE_TRANSIT_TICKS + 20 do
    tube.on_tick{tick = tick}
  end
  assert_eq(vulcanus.arrivals.get_item_count("blank-form"), 1,
    "moving arrivals onward is the player's explicit step, never the trunk's")
end)

-------------------------------------------------------------------------------
-- UNIQUENESS
-------------------------------------------------------------------------------

test("one planet hosts one Terminus", function()
  reset()
  local first = new_terminus("nauvis", BASE)
  register(first)

  local found = tube.find_planet_terminus(1, "nauvis")
  assert_true(found ~= nil, "the registered Terminus should be found for its planet")

  local second = new_terminus("nauvis", BASE)
  local other = tube.find_planet_terminus(1, "nauvis", second.unit_number)
  assert_true(other ~= nil, "a second Terminus on the same planet should see the first one")
end)

test("a space platform is not a planet", function()
  reset()
  local platform_surface = {valid = true, platform = {}, planet = nil}
  assert_eq(tube.get_planet_name(platform_surface), nil, "platforms must not host a Terminus")
end)

-------------------------------------------------------------------------------
-- POOL SEPARATION
-------------------------------------------------------------------------------

test("the trunk keeps its own storage, entirely separate from the local pool", function()
  reset()
  tube.ensure_storage()
  assert_true(storage.terminus_flights ~= nil, "the trunk should own its flight list")
  assert_true(storage.tube_signals == nil,
    "the trunk must never touch the local pneumatic signal pool")
end)

print(string.format("\n=== INTERPLANETARY TUBE RUNTIME TESTS ==="))
print(string.format("Passed: %d  Failed: %d  Total: %d", passed, failed, passed + failed))

if #errors > 0 then
  print("\nFAILURES:")
  for i, err in ipairs(errors) do
    print(string.format("  %d) %s", i, err))
  end
  os.exit(1)
end

print("\nAll tests passed!")
