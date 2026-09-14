-------------------------------------------------------------------------------
-- RESEARCH-GATED EVOLUTION UNIT TESTS
-------------------------------------------------------------------------------
local passed, failed, errors = 0, 0, {}

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then passed = passed + 1 else
    failed = failed + 1
    errors[#errors + 1] = name .. ": " .. tostring(err)
  end
end

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function assert_near(actual, expected, message)
  if math.abs(actual - expected) > 0.000001 then
    error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
mod_root = mod_root and mod_root:gsub("tests/$", "") or "./"
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

script = {active_mods = {}}

local facts = require("prototypes.shared.evolution_milestones")
local gating = require("scripts.evolution_gating")

local function technology(researched)
  return {valid = true, researched = researched == true}
end

local function new_force(index, researched_names)
  local technologies = {}
  local recipes = {}
  for _, milestone in ipairs(facts.MILESTONES) do
    technologies[milestone.technology] = technology(false)
    for _, legacy in ipairs(milestone.legacy_technologies) do
      technologies[legacy] = technology(false)
    end
    for _, recipe in ipairs(milestone.recipes) do
      recipes[recipe] = {valid = true, enabled = false}
    end
  end
  for _, name in ipairs({
    "chemical-science-pack", "production-science-pack", "utility-science-pack",
    "space-science-pack", "planet-discovery-aquilo",
  }) do
    technologies[name] = technology(false)
  end
  for _, name in ipairs(researched_names or {}) do technologies[name] = technology(true) end
  return {index = index, valid = true, technologies = technologies, recipes = recipes}
end

local function new_surface(index, name, evolution, options)
  options = options or {}
  local surface = {
    index = index,
    name = name,
    valid = true,
    planet = options.planet and {name = options.planet} or nil,
    platform = options.platform and {} or nil,
    evolution = evolution,
    has_spawner = options.has_spawner == true,
  }
  surface.find_entities_filtered = function(_filter)
    return surface.has_spawner and {{valid = true}} or {}
  end
  return surface
end

local function install_world(forces, surfaces)
  storage = {}
  local messages = {}
  local enemy = {index = 99, valid = true}
  enemy.get_evolution_factor = function(surface) return surface.evolution end
  enemy.set_evolution_factor = function(value, surface) surface.evolution = value end
  game = {
    players = {},
    forces = {enemy = enemy, player = forces[1]},
    surfaces = {},
    print = function(message) messages[#messages + 1] = message end,
  }
  for index, force in ipairs(forces) do
    game.forces["player-" .. index] = force
    game.players[index] = {force = force}
  end
  for _, surface in ipairs(surfaces) do
    game.surfaces[surface.index] = surface
    game.surfaces[surface.name] = surface
  end
  return messages
end

local function spawned_entity(name, surface)
  local entity = {name = name, valid = true, force = {name = "enemy"}, surface = surface, destroyed = false}
  entity.destroy = function()
    entity.destroyed = true
    entity.valid = false
  end
  return entity
end

test("ceilings rise without catch-up and the most advanced player force wins", function()
  local force_a = new_force(1)
  local force_b = new_force(2)
  local nauvis = new_surface(1, "nauvis", 0.75)
  local gleba = new_surface(2, "gleba", 0.95, {planet = "gleba", has_spawner = true})
  install_world({force_a, force_b}, {nauvis, gleba})

  gating.on_init()
  assert_near(nauvis.evolution, 0.20, "initial evolution should clamp at 20%")
  assert_near(gleba.evolution, 0.95, "Gleba should keep independent evolution")

  local medium = spawned_entity("medium-biter", nauvis)
  assert_eq(gating.reject_disallowed_spawn({entity = medium, spawner = {valid = true, name = "biter-spawner"}}), true)
  local small_spitter = spawned_entity("small-spitter", nauvis)
  assert_eq(gating.reject_disallowed_spawn({entity = small_spitter, spawner = {valid = true, name = "spitter-spawner"}}), false)

  force_a.technologies["administratorio-medium-complaints"].researched = true
  gating.on_research_changed()
  assert_near(storage.evolution_gating.cap, 0.45)
  assert_near(nauvis.evolution, 0.20, "raising a ceiling should not raise current evolution")
  nauvis.evolution = 0.80
  gating.on_tick()
  assert_near(nauvis.evolution, 0.45, "blocked evolution should be discarded")

  force_b.technologies["administratorio-large-complaints"].researched = true
  gating.on_research_changed()
  assert_near(storage.evolution_gating.cap, 0.60, "another player faction may release the shared cap")
  assert_near(nauvis.evolution, 0.45, "the released cap should not cause catch-up")

  local behemoth = spawned_entity("behemoth-spitter", nauvis)
  assert_eq(gating.reject_disallowed_spawn({entity = behemoth, spawner = {valid = true, name = "spitter-spawner"}}), true)
  force_b.technologies["administratorio-behemoth-complaints"].researched = true
  gating.on_research_changed()
  assert_near(storage.evolution_gating.cap, 1.00)
end)

test("modded biter surfaces are discovered while empty planets and platforms are ignored", function()
  local force = new_force(1)
  local modded = new_surface(3, "modded-biter-world", 0.7, {has_spawner = true})
  local empty = new_surface(4, "empty-world", 0.7)
  local platform = new_surface(5, "platform", 0.7, {platform = true, has_spawner = true})
  install_world({force}, {modded, empty, platform})
  gating.on_init()
  assert_near(modded.evolution, 0.20)
  assert_near(empty.evolution, 0.70)
  assert_near(platform.evolution, 0.70)
end)

test("migration derives milestones only from research and is idempotent", function()
  local force = new_force(1, {"production-science-pack"})
  local nauvis = new_surface(1, "nauvis", 0.90)
  install_world({force}, {nauvis})
  local changed, clamped = gating.migrate_existing_save()
  assert_eq(changed, true)
  assert_eq(clamped, true)
  assert_eq(force.technologies["administratorio-medium-complaints"].researched, true)
  assert_eq(force.technologies["administratorio-large-complaints"].researched, true)
  assert_eq(force.technologies["administratorio-behemoth-complaints"].researched, false)
  assert_near(nauvis.evolution, 0.60)
  assert_eq(force.recipes["noise-final"].enabled, true)

  local changed_again, clamped_again = gating.migrate_existing_save()
  assert_eq(changed_again, false)
  assert_eq(clamped_again, false)

  force.technologies["constitutional-law"].researched = true
  local changed_final = gating.migrate_existing_save()
  assert_eq(changed_final, true)
  assert_eq(force.technologies["administratorio-behemoth-complaints"].researched, true)
end)

if failed > 0 then
  io.stderr:write(string.format("Evolution gating tests: %d passed, %d failed\n", passed, failed))
  for _, err in ipairs(errors) do io.stderr:write(" - " .. err .. "\n") end
  os.exit(1)
end

print(string.format("Evolution gating tests: %d passed", passed))
