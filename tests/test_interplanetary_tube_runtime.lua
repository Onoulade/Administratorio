-------------------------------------------------------------------------------
-- INTERPLANETARY TUBE RUNTIME TESTS
--
-- The trunk's load-bearing invariants: it is a separate pool from the local
-- pneumatic network, capacity limits how many items are pending + pooled,
-- transit is per item, colored paperwork waits for the chromatic tier,
-- loading is unconditional (no request required), a planet can claim back
-- what it contributed itself, arrivals are never auto-fed anywhere, and one
-- planet hosts one Terminus (before the additional-terminus tech).
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

local function key(name, quality)
  return name .. "/" .. (quality or "normal")
end

local function parse_key(k)
  local name, quality = k:match("^(.-)/(.*)$")
  return name, quality
end

local function new_inventory(capacity)
  local inventory = {valid = true, contents = {}, capacity = capacity or 10}

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

  function inventory.get_contents()
    local list = {}
    for k, count in pairs(inventory.contents) do
      if count > 0 then
        local name, quality = parse_key(k)
        list[#list + 1] = {name = name, quality = quality, count = count}
      end
    end
    return list
  end

  return inventory
end

-- A fake constant-combinator control behavior supporting the Factorio 2.0
-- sections API subset the trunk actually uses.
local function new_fake_behavior()
  local behavior = {sections = {}}
  function behavior.get_section(idx) return behavior.sections[idx] end
  function behavior.add_section()
    local section = {slots = {}, filters_count = 1000}
    function section.set_slot(idx, def) section.slots[idx] = def end
    function section.clear_slot(idx) section.slots[idx] = nil end
    behavior.sections[#behavior.sections + 1] = section
    return section
  end
  return behavior
end

-- A fake wire connector: production code only ever calls .connect_to() on it.
local function new_fake_wire_connector()
  local connector = {}
  function connector.connect_to(_) end
  return connector
end

-- A fake surface supporting only what the trunk needs from it: spilling,
-- and creating/finding the hidden pool combinator.
local function new_fake_surface(planet_name)
  local surface
  surface = {
    valid = true,
    platform = nil,
    planet = {valid = true, name = planet_name},
    spawned = {},
  }
  surface.planet.surface = surface

  function surface.spill_item_stack(_) end

  function surface.create_entity(params)
    local ent = {valid = true, name = params.name, position = params.position, force = params.force}
    function ent.destroy() ent.valid = false end
    function ent.get_or_create_control_behavior()
      ent.behavior = ent.behavior or new_fake_behavior()
      return ent.behavior
    end
    function ent.get_wire_connector(_, _) return new_fake_wire_connector() end
    surface.spawned[#surface.spawned + 1] = ent
    return ent
  end

  function surface.find_entities_filtered(filters)
    local results = {}
    for _, ent in ipairs(surface.spawned) do
      if ent.valid and (not filters.name or ent.name == filters.name) then
        results[#results + 1] = ent
      end
    end
    return results
  end

  return surface
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
  entity.surface = new_fake_surface(planet_name)

  function entity.destroy() entity.valid = false end

  function entity.get_inventory(which)
    if which == defines.inventory.furnace_source then return entity.outbound end
    if which == defines.inventory.furnace_result then return entity.arrivals end
    return nil
  end

  function entity.get_control_behavior() return {} end
  function entity.get_wire_connector(_, _) return new_fake_wire_connector() end

  function entity.get_circuit_network(connector)
    -- Requests are read from GREEN only; see M.collect_requests.
    if connector ~= defines.wire_connector_id.circuit_green then return nil end
    local signals = {}
    for _, request in ipairs(entity.requests) do
      signals[#signals + 1] = {
        -- Real Factorio reports item-type signals with type == nil on read.
        signal = {type = nil, name = request.name, quality = request.quality},
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
  assert_eq(capacity, 3, "a single pending document empire-wide would read as a broken machine")
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
-- LOAD (input -> pre-pool phase, unconditional on any request existing)
-------------------------------------------------------------------------------

test("loading happens with no request in sight, freeing the input slot", function()
  reset()
  local nauvis = new_terminus("nauvis", BASE)
  nauvis.outbound.insert{name = "blank-form", count = 1}
  register(nauvis)

  tube.on_tick{tick = 0}
  assert_eq(nauvis.outbound.get_item_count("blank-form"), 0,
    "the input slot should empty on its own timer, with nobody asking for it yet")
  assert_eq(#storage.terminus_flights, 1, "the item should be pending in the pre-pool phase")
end)

test("the base tier will not load a colored form even when asked", function()
  reset()
  local nauvis = new_terminus("nauvis", BASE)
  nauvis.outbound.insert{name = "cyan-yellow-form", count = 1}
  local vulcanus = new_terminus("vulcanus", BASE, {{name = "cyan-yellow-form", quality = "normal", count = 1}})
  register(nauvis)
  register(vulcanus)

  tube.on_tick{tick = 0}
  assert_eq(#storage.terminus_flights, 0, "colored paperwork must not enter the base trunk at all")
  assert_eq(nauvis.outbound.get_item_count("cyan-yellow-form"), 1, "the form should stay put")
end)

test("transit is per item, so several may be pending at once", function()
  reset()
  local nauvis = new_terminus("nauvis", BASE)
  nauvis.outbound.insert{name = "blank-form", count = 3}
  register(nauvis)

  tube.on_tick{tick = 0}
  tube.on_tick{tick = 1}
  tube.on_tick{tick = 2}
  assert_eq(#storage.terminus_flights, 3, "three separate items should each carry their own timer")
end)

-------------------------------------------------------------------------------
-- CAPACITY (spans the pre-pool phase and the pool together)
-------------------------------------------------------------------------------

test("capacity caps how many items are pending, source outbound holds the rest", function()
  reset()
  local nauvis = new_terminus("nauvis", BASE)
  nauvis.outbound.insert{name = "blank-form", count = 4}
  register(nauvis)

  for tick = 0, 10 do tube.on_tick{tick = tick} end
  assert_eq(#storage.terminus_flights, C.TRUNK_BASE_CAPACITY,
    "the trunk should refuse to exceed its capacity")
  assert_eq(nauvis.outbound.get_item_count("blank-form"), 1,
    "the item that didn't fit should stay in the input slot")
end)

test("capacity is charged against the pool too, not just pending flights", function()
  reset()
  local nauvis = new_terminus("nauvis", BASE)
  register(nauvis)

  -- Fill the pool to capacity via three full load-then-land round trips.
  for i = 1, C.TRUNK_BASE_CAPACITY do
    nauvis.outbound.insert{name = "blank-form", count = 1}
    tube.on_tick{tick = (i - 1) * C.TRUNK_BASE_TRANSIT_TICKS}
    tube.on_tick{tick = (i - 1) * C.TRUNK_BASE_TRANSIT_TICKS + C.TRUNK_BASE_TRANSIT_TICKS}
  end
  assert_eq(#storage.terminus_flights, 0, "everything loaded so far should have landed in the pool")

  -- A fourth item has nowhere to go: the pool alone is already at capacity.
  nauvis.outbound.insert{name = "blank-form", count = 1}
  tube.on_tick{tick = C.TRUNK_BASE_CAPACITY * C.TRUNK_BASE_TRANSIT_TICKS + 100}
  assert_eq(#storage.terminus_flights, 0, "a full pool should block a new load just like a full pending list")
  assert_eq(nauvis.outbound.get_item_count("blank-form"), 1, "the blocked item should stay in the input slot")
end)

-------------------------------------------------------------------------------
-- CLAIM (pool -> arrivals, matched against every Terminus's own request)
-------------------------------------------------------------------------------

test("a requested form crosses from another planet's pool contribution", function()
  reset()
  local nauvis = new_terminus("nauvis", BASE)
  nauvis.outbound.insert{name = "blank-form", count = 1}
  local vulcanus = new_terminus("vulcanus", BASE, {{name = "blank-form", quality = "normal", count = 1}})
  register(nauvis)
  register(vulcanus)

  tube.on_tick{tick = 0}
  assert_eq(#storage.terminus_flights, 1, "loading should start the item's transit timer")
  assert_eq(nauvis.outbound.get_item_count("blank-form"), 0, "the source should have handed the form over")
  assert_eq(vulcanus.arrivals.get_item_count("blank-form"), 0, "the form should still be pending")

  tube.on_tick{tick = C.TRUNK_BASE_TRANSIT_TICKS}
  assert_eq(#storage.terminus_flights, 0, "the pending item should have landed in the pool and been claimed")
  assert_eq(vulcanus.arrivals.get_item_count("blank-form"), 1, "the claim should land in the arrivals buffer")
end)

test("a planet can claim back what it contributed itself", function()
  reset()
  local nauvis = new_terminus("nauvis", BASE, {{name = "blank-form", quality = "normal", count = 1}})
  nauvis.outbound.insert{name = "blank-form", count = 1}
  register(nauvis)

  tube.on_tick{tick = 0}
  tube.on_tick{tick = C.TRUNK_BASE_TRANSIT_TICKS}

  assert_eq(nauvis.arrivals.get_item_count("blank-form"), 1,
    "reclaiming your own pooled contribution is a withdrawal, not a shortcut, and should succeed")
end)

test("any planet's request may be served regardless of who contributed", function()
  reset()
  local nauvis = new_terminus("nauvis", BASE)
  nauvis.outbound.insert{name = "blank-form", count = 1}
  local vulcanus = new_terminus("vulcanus", BASE, {{name = "blank-form", quality = "normal", count = 1}})
  register(nauvis)
  register(vulcanus)

  tube.on_tick{tick = 0}
  tube.on_tick{tick = C.TRUNK_BASE_TRANSIT_TICKS}

  assert_eq(vulcanus.arrivals.get_item_count("blank-form"), 1,
    "a different planet's request should be served from the same pool entry")
end)

test("nothing crosses between two Terminuses that never load anything", function()
  reset()
  local a = new_terminus("nauvis", BASE)
  local b = new_terminus("nauvis", BASE, {{name = "blank-form", quality = "normal", count = 1}})
  register(a)
  register(b)

  tube.on_tick{tick = 0}
  assert_eq(#storage.terminus_flights, 0, "an empty pool has nothing for anyone to claim")
end)

test("a full arrivals buffer stalls the claim, not the load", function()
  reset()
  local nauvis = new_terminus("nauvis", BASE)
  nauvis.outbound.insert{name = "blank-form", count = 1}
  local vulcanus = new_terminus("vulcanus", BASE, {{name = "blank-form", quality = "normal", count = 1}})
  vulcanus.arrivals.capacity = 0
  register(nauvis)
  register(vulcanus)

  tube.on_tick{tick = 0}
  assert_eq(#storage.terminus_flights, 1, "loading does not check any destination's state at all")
  assert_eq(nauvis.outbound.get_item_count("blank-form"), 0, "the source slot still empties on schedule")

  tube.on_tick{tick = C.TRUNK_BASE_TRANSIT_TICKS}
  assert_eq(vulcanus.arrivals.get_item_count("blank-form"), 0, "the claim should be held back, not voided")
  assert_eq(vulcanus.custom_status.diode, defines.entity_status_diode.red,
    "a stalled claim should signal the back-pressure")

  -- The item is still sitting in the pool, not lost, and lands once there's room.
  vulcanus.arrivals.capacity = 8
  tube.on_tick{tick = C.TRUNK_BASE_TRANSIT_TICKS + 30}
  assert_eq(vulcanus.arrivals.get_item_count("blank-form"), 1, "clearing room should let the claim go through")
end)

-------------------------------------------------------------------------------
-- REMOVAL
-------------------------------------------------------------------------------

test("removing a Terminus refunds its own still-pending cargo", function()
  reset()
  local nauvis = new_terminus("nauvis", BASE)
  register(nauvis)
  storage.terminus_flights = {
    {
      item = "blank-form",
      quality = "normal",
      count = 1,
      force_index = nauvis.force.index,
      from_entity = nauvis,
      arrive_tick = C.TRUNK_BASE_TRANSIT_TICKS,
    },
  }

  tube.on_entity_removed(nauvis, nil)

  assert_eq(#storage.terminus_flights, 0, "removal should resolve the origin's own pending flights immediately")
  assert_eq(nauvis.arrivals.get_item_count("blank-form"), 1,
    "the origin should recover its own paperwork instead of losing it")
end)

test("removing a Terminus leaves the shared pool untouched", function()
  reset()
  local nauvis = new_terminus("nauvis", BASE)
  register(nauvis)
  storage.trunk_pool[nauvis.force.index] = {
    ["blank-form/normal"] = 2,
  }

  tube.on_entity_removed(nauvis, nil)

  assert_eq(storage.trunk_pool[nauvis.force.index]["blank-form/normal"], 2,
    "the pool is force-owned, not entity-owned, and must survive any single Terminus's removal")
end)

-------------------------------------------------------------------------------
-- ARRIVALS ARE NEVER AUTO-FED
-------------------------------------------------------------------------------

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
-- POOL CONTENT COMBINATOR
-------------------------------------------------------------------------------

test("the pool combinator broadcasts current force-wide pool contents", function()
  reset()
  local nauvis = new_terminus("nauvis", BASE)
  nauvis.outbound.insert{name = "blank-form", count = 1}
  assert_true(tube.on_entity_built(nauvis, nil), "the Terminus should be accepted")

  tube.on_tick{tick = 0}
  tube.on_tick{tick = C.TRUNK_BASE_TRANSIT_TICKS}

  local entry = storage.terminus_registry[nauvis.unit_number]
  assert_true(entry.combinator ~= nil and entry.combinator.valid, "a pool combinator should exist")
  local behavior = entry.combinator.get_or_create_control_behavior()
  local section = behavior.get_section(1)
  assert_true(section ~= nil, "the combinator should have written a section")
  assert_eq(section.slots[1].value.name, "blank-form", "the pool combinator should show what's pooled")
  assert_eq(section.slots[1].min, 1, "the pool combinator should show the current pooled count")
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

test("the default cap is one Terminus per planet", function()
  local capacity = tube.max_terminus_per_planet({valid = true, technologies = {}})
  assert_eq(capacity, 1, "with no research, a planet should host exactly one Terminus")
end)

test("the additional-terminus tech raises the cap by its researched level", function()
  local force = {
    valid = true,
    technologies = {[C.TERMINUS_ADDITIONAL_TECH] = {researched = true, level = 3}},
  }
  assert_eq(tube.max_terminus_per_planet(force), 4,
    "the cap should be the base plus the tech's current level")
end)

test("an unresearched additional-terminus tech grants nothing", function()
  local force = {
    valid = true,
    technologies = {[C.TERMINUS_ADDITIONAL_TECH] = {researched = false, level = 3}},
  }
  assert_eq(tube.max_terminus_per_planet(force), 1,
    "an infinite tech's level should not count until it is actually researched")
end)

test("a second Terminus is rejected on a planet at capacity", function()
  reset()
  local first = new_terminus("nauvis", BASE)
  assert_true(tube.on_entity_built(first, nil), "the first Terminus should be accepted")

  local second = new_terminus("nauvis", BASE)
  assert_true(not tube.on_entity_built(second, nil),
    "a second Terminus should be rejected while the cap is still one")
  assert_true(not second.valid, "the rejected Terminus should be destroyed and refunded")
end)

test("researching the additional-terminus tech allows a second Terminus on the same planet", function()
  reset()
  local first = new_terminus("nauvis", BASE)
  first.force.technologies[C.TERMINUS_ADDITIONAL_TECH] = {researched = true, level = 3}
  assert_true(tube.on_entity_built(first, nil), "the first Terminus should be accepted")

  local second = new_terminus("nauvis", BASE)
  second.force.technologies[C.TERMINUS_ADDITIONAL_TECH] = {researched = true, level = 3}
  assert_true(tube.on_entity_built(second, nil),
    "a second Terminus should be accepted once research raises the cap")
  assert_eq(tube.count_planet_terminus(1, "nauvis"), 2, "both Terminuses should be registered")
end)

-------------------------------------------------------------------------------
-- POOL SEPARATION
-------------------------------------------------------------------------------

test("the trunk keeps its own storage, entirely separate from the local pool", function()
  reset()
  tube.ensure_storage()
  assert_true(storage.terminus_flights ~= nil, "the trunk should own its pre-pool flight list")
  assert_true(storage.trunk_pool ~= nil, "the trunk should own its shared pool")
  assert_true(storage.tube_signals == nil,
    "the trunk must never touch the local pneumatic signal pool")
end)

test("two forces' pools never bleed into each other", function()
  reset()
  storage.trunk_pool[1] = {["blank-form/normal"] = 1}
  storage.trunk_pool[2] = {["blank-form/normal"] = 5}
  assert_eq(storage.trunk_pool[1]["blank-form/normal"], 1, "force 1's pool should be untouched by force 2's")
  assert_eq(storage.trunk_pool[2]["blank-form/normal"], 5, "force 2's pool should be untouched by force 1's")
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
