local feature_flags = require("feature_flags")
local facts = require("prototypes.shared.evolution_milestones")

local M = {}

local NATIVE_SPAWNERS = {"biter-spawner", "spitter-spawner"}
local EPSILON = 0.000001
local INTERNAL_FORCE_NAMES = {
  enemy = true,
  neutral = true,
  ["administratorio-biters"] = true,
  ["administratorio-hard-mode-biters"] = true,
  ["administratorio-pentapods"] = true,
}

local function state()
  storage.evolution_gating = storage.evolution_gating or {}
  local value = storage.evolution_gating
  value.eligible_surfaces = value.eligible_surfaces or {}
  value.cap_notifications = value.cap_notifications or {}
  value.level = value.level or 0
  value.cap = value.cap or facts.BASE_CAP
  return value
end

local function researched(force, technology_name)
  local technology = force and force.technologies and force.technologies[technology_name]
  return technology and technology.valid ~= false and technology.researched == true
end

local function participant_forces()
  local result = {}
  local seen = {}
  local function add(force)
    if not force or force.valid == false then return end
    if INTERNAL_FORCE_NAMES[force.name] then return end
    if force.name and force.name:sub(1, 16) == "administratorio-" then return end
    if seen[force.index] then return end
    seen[force.index] = true
    result[#result + 1] = force
  end
  local default = game.forces and game.forces["player"]
  add(default)
  for _, player in pairs(game.players or {}) do
    add(player.force)
  end
  return result
end

function M.highest_researched_level()
  local highest = 0
  for _, force in ipairs(participant_forces()) do
    for index, milestone in ipairs(facts.MILESTONES) do
      if index > highest and researched(force, milestone.technology) then
        highest = index
      end
    end
  end
  return highest
end

local function cap_for_level(level)
  local milestone = facts.MILESTONES[level]
  return milestone and milestone.cap or facts.BASE_CAP
end

local function print_release_messages(previous_level, level)
  if not game or not game.print or level <= previous_level then return end
  for index = previous_level + 1, level do
    local milestone = facts.MILESTONES[index]
    game.print({
      "message.evolution-milestone-released",
      {"technology-name." .. milestone.technology},
      string.format("%.0f", milestone.cap * 100),
    })
  end
end

function M.recalculate(notify)
  local value = state()
  local previous_level = value.level or 0
  local level = M.highest_researched_level()
  value.level = level
  value.cap = cap_for_level(level)
  if notify then print_release_messages(previous_level, level) end
  return level, value.cap
end

local function surface_excluded(surface)
  if not surface or surface.valid == false then return true end
  if surface.platform then return true end
  local planet = surface.planet
  return planet and planet.name == "gleba"
end

local function surface_has_native_spawner(surface, area)
  if surface_excluded(surface) then return false end
  if surface.name == "nauvis" then return true end
  local filter = {name = NATIVE_SPAWNERS, limit = 1}
  if area then filter.area = area end
  local ok, entities = pcall(surface.find_entities_filtered, filter)
  return ok and entities and entities[1] ~= nil
end

function M.refresh_surface(surface, area)
  local value = state()
  if not surface or surface.valid == false then return false end
  local eligible = value.eligible_surfaces[surface.index] == true
  if surface_excluded(surface) then
    value.eligible_surfaces[surface.index] = nil
    return false
  end
  if eligible or surface_has_native_spawner(surface, area) then
    value.eligible_surfaces[surface.index] = true
    return true
  end
  return false
end

function M.rebuild_surfaces()
  local value = state()
  value.eligible_surfaces = {}
  for _, surface in pairs(game.surfaces or {}) do
    M.refresh_surface(surface)
  end
end

local function clamp_surface(surface, cap)
  local enemy = game.forces and game.forces["enemy"]
  if not enemy or enemy.valid == false then return false, false end
  local evolution = enemy.get_evolution_factor(surface) or 0
  local reached = evolution >= cap - EPSILON
  if evolution > cap then
    enemy.set_evolution_factor(cap, surface)
    return true, reached
  end
  return false, reached
end

function M.clamp_all(notify)
  local value = state()
  local clamped = false
  local reached = false
  for surface_index in pairs(value.eligible_surfaces) do
    local surface = game.surfaces[surface_index]
    if surface and surface.valid ~= false and not surface_excluded(surface) then
      local did_clamp, did_reach = clamp_surface(surface, value.cap)
      clamped = did_clamp or clamped
      reached = did_reach or reached
    else
      value.eligible_surfaces[surface_index] = nil
    end
  end

  if notify and reached and value.level < #facts.MILESTONES
      and not value.cap_notifications[value.level] then
    value.cap_notifications[value.level] = true
    local next_milestone = facts.MILESTONES[value.level + 1]
    game.print({
      "message.evolution-milestone-capped",
      string.format("%.0f", value.cap * 100),
      {"technology-name." .. next_milestone.technology},
    })
  end
  return clamped
end

function M.on_tick()
  M.clamp_all(true)
end

function M.on_chunk_generated(event)
  if event and event.surface then M.refresh_surface(event.surface, event.area) end
end

function M.on_surface_changed(event)
  local surface = event and event.surface
  if not surface and event and event.surface_index then
    surface = game.surfaces[event.surface_index]
  end
  if surface then M.refresh_surface(surface) end
end

function M.on_surface_deleted(event)
  if event and event.surface_index then
    state().eligible_surfaces[event.surface_index] = nil
  end
end

function M.on_research_changed()
  M.recalculate(true)
  M.clamp_all(true)
end

function M.on_force_changed()
  M.recalculate(false)
  M.clamp_all(true)
end

function M.reject_disallowed_spawn(event)
  local entity = event and event.entity
  local spawner = event and event.spawner
  if not entity or entity.valid == false or not spawner or spawner.valid == false then return false end
  if spawner.name ~= "biter-spawner" and spawner.name ~= "spitter-spawner" then return false end
  if not entity.force or entity.force.name ~= "enemy" then return false end
  if not M.refresh_surface(entity.surface) then return false end
  local required_level = facts.ENEMY_SIZE_LEVEL[entity.name]
  if required_level and required_level > state().level then
    entity.destroy()
    return true
  end
  return false
end

local function set_milestone_researched(force, index)
  local milestone = facts.MILESTONES[index]
  local technology = force.technologies and force.technologies[milestone.technology]
  local changed = false
  if technology and technology.valid ~= false and not technology.researched then
    technology.researched = true
    changed = true
  end
  for _, recipe_name in ipairs(milestone.recipes) do
    local recipe = force.recipes and force.recipes[recipe_name]
    if recipe and recipe.valid ~= false then recipe.enabled = true end
  end
  return changed
end

local function migration_level(force)
  local level = 0
  local medium = facts.MILESTONES[1]
  local large = facts.MILESTONES[2]
  local behemoth = facts.MILESTONES[3]
  if researched(force, "chemical-science-pack")
      or researched(force, medium.legacy_technologies[1])
      or researched(force, medium.legacy_technologies[2]) then
    level = 1
  end
  if researched(force, "production-science-pack")
      or researched(force, "utility-science-pack")
      or researched(force, large.legacy_technologies[1])
      or researched(force, large.legacy_technologies[2]) then
    level = 2
  end
  local final_progress = feature_flags.space_age_enabled()
      and researched(force, "planet-discovery-aquilo")
      or (not feature_flags.space_age_enabled() and researched(force, "space-science-pack"))
  if final_progress
      or researched(force, behemoth.legacy_technologies[1])
      or researched(force, behemoth.legacy_technologies[2]) then
    level = 3
  end
  return level
end

function M.migrate_existing_save()
  local changed = false
  for _, force in ipairs(participant_forces()) do
    local level = migration_level(force)
    for index = 1, level do
      changed = set_milestone_researched(force, index) or changed
    end
  end
  M.rebuild_surfaces()
  M.recalculate(false)
  local clamped = M.clamp_all(false)
  if (changed or clamped) and game.print then
    game.print({"message.evolution-milestone-migrated", string.format("%.0f", state().cap * 100)})
  end
  return changed, clamped
end

function M.on_init()
  state()
  M.rebuild_surfaces()
  M.recalculate(false)
  M.clamp_all(false)
end

M._cap_for_level = cap_for_level
M._migration_level = migration_level

return M
