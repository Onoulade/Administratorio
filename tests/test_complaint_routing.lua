local passed, failed, errors = 0, 0, {}
local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then passed = passed + 1 else failed = failed + 1; errors[#errors + 1] = name .. ": " .. tostring(err) end
end
local function eq(actual, expected, message)
  if actual ~= expected then error((message or "unexpected value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end

local root = debug.getinfo(1, "S").source:match("@(.*/)"):gsub("tests/$", "")
package.path = root .. "?.lua;" .. root .. "?/init.lua;" .. package.path
mods = {}
defines = {command = {go_to_location = 1, stop = 2, wander = 3}, distraction = {none = 0}}
local deps
local available = {}
local platform_candidates = {}
local reserved = {}
local reserve_fail_id
package.loaded["scripts.constants"] = {
  DESK_SLOT_COMMAND_RADIUS = 0.5, DESK_SLOT_ARRIVAL_DISTANCE = 1,
  FRUST_PROTEST_PROCESS_SHARDS = 4,
}
package.loaded["scripts.zones"] = {
  increment_desk_occupants = function() end,
  decrement_desk_occupants = function() end,
  get_available_slots = function(id) return available[id] or 0 end,
  reserve_slot = function(id, unit)
    if id == reserve_fail_id then return nil end
    if (available[id] or 0) <= 0 then return nil end
    reserved[id] = unit
    return 1
  end,
  release_slot_by_index = function(id) reserved[id] = nil end,
  get_zone_position = function(_, id) return {x = storage.admin_desks[id].position.x, y = 0} end,
  get_queue_pos = function(desk) return desk.position end,
}
package.loaded["scripts.working_hours"] = {}
package.loaded["scripts.biters_rendering"] = {new = function() return {} end}
package.loaded["scripts.biters_protests"] = {new = function(args)
  deps = args
  return {reset_protest_targeting = function() end}
end}
package.loaded["scripts.unit_ai_settings"] = {apply_managed_unit_settings = function() end}
package.loaded["scripts.protest_targets"] = {
  get_target_types = function() return {} end,
  get_target_names = function() return {} end,
  get_protected_names = function() return {} end,
}
package.loaded["scripts.spawner_population"] = {}
package.loaded["scripts.pentapods"] = {is_pentapod = function() return false end}
package.loaded["scripts.passenger_trains"] = {
  find_candidates = function() return platform_candidates end,
  reserve_platform = function(info, _, platform)
    if not available[platform.unit_number] then return false end
    info.platform_id = platform.unit_number
    info.state = "pathfinding_to_platform"
    return true
  end,
}

dofile(root .. "scripts/biters.lua")

local default_find_non_colliding_position = function(_, pos) return pos end
local surface = {
  index = 1,
  find_non_colliding_position = default_find_non_colliding_position,
  create_entity = function(params) return params end,
}
local function desk(id, x)
  return {valid = true, name = "admin-station", unit_number = id, position = {x = x, y = 0}, surface = surface}
end
local function setup(desks)
  available, reserved, platform_candidates, reserve_fail_id = {}, {}, {}, nil
  surface.last_command = nil
  surface.find_non_colliding_position = default_find_non_colliding_position
  storage = {admin_desks = {}, waiting_biters = {}, achievements = {}}
  for _, d in ipairs(desks) do storage.admin_desks[d.unit_number] = d end
  game = {tick = 0, connected_players = {}, forces = {neutral = {name = "neutral"}}}
  local biter = {
    valid = true, name = "small-biter", unit_number = 99,
    position = {x = 0, y = 0}, surface = surface, active = true,
    commandable = {set_command = function(command) surface.last_command = command end},
  }
  local info = {entity = biter, tracked_unit_number = 99, state = "seeking_slot", frustration = 37}
  storage.waiting_biters[99] = info
  return info, biter
end

test("with no destinations a tracked visitor patrols while active", function()
  local info, biter = setup({})
  deps.route_or_seek_slot(info, biter)
  eq(info.state, "seeking_slot")
  eq(info.slot_search_target_id, nil)
  eq(info.slot_search_retry_tick, nil)
  eq(surface.last_command.type, defines.command.go_to_location)
  eq(info.slot_search_wander_anchor.x, 0)
  eq(biter.active, true)
end)

test("an old saved inactive seeker wakes without the removed delay", function()
  local info, biter = setup({})
  info.slot_search_retry_tick = 180
  biter.active = false
  deps.process_slot_search(info, biter)
  eq(biter.active, true)
  eq(info.slot_search_retry_tick, nil)
  eq(surface.last_command.type, defines.command.go_to_location)
end)

test("fallback patrol remains anchored across repeated searches", function()
  local info, biter = setup({})
  deps.route_or_seek_slot(info, biter)
  local anchor = info.slot_search_wander_anchor
  for tick = 1, 12 do
    biter.position = surface.last_command.destination
    game.tick = tick
    deps.process_slot_search(info, biter)
    eq(info.slot_search_wander_anchor, anchor)
    local dest = surface.last_command.destination
    local distance_sq = (dest.x - anchor.x)^2 + (dest.y - anchor.y)^2
    eq(distance_sq <= 100, true)
    eq(biter.active, true)
  end
end)

test("a full local desk prevents routing to a distant free desk", function()
  local nearby, distant = desk(1, 40), desk(2, 300)
  local info, biter = setup({nearby, distant})
  available[2] = 1
  deps.route_or_seek_slot(info, biter)
  eq(info.state, "seeking_slot")
  eq(info.slot_search_target_id, 1)
  eq(reserved[2], nil)
  eq(surface.last_command.type, defines.command.go_to_location)
end)

test("a free destination inside eight chunks wins over full closer desks", function()
  local info, biter = setup({desk(1, 40), desk(2, 200), desk(3, 300)})
  available[2], available[3] = 1, 1
  deps.route_or_seek_slot(info, biter)
  eq(info.state, "pathfinding")
  eq(info.desk_id, 2)
  eq(info.frustration, 37)
  eq(reserved[2], 99)
end)

test("a lost slot reservation tries the next nearby opening", function()
  local info, biter = setup({desk(1, 40), desk(2, 80)})
  available[1], available[2] = 1, 1
  reserve_fail_id = 1
  deps.route_or_seek_slot(info, biter)
  eq(info.state, "pathfinding")
  eq(info.desk_id, 2)
  eq(reserved[1], nil)
  eq(reserved[2], 99)
end)

test("without local destinations the first distant free desk is selected", function()
  local info, biter = setup({desk(1, 300), desk(2, 400)})
  available[1], available[2] = 1, 1
  deps.route_or_seek_slot(info, biter)
  eq(info.desk_id, 1)
end)

test("without any free destination the outward search approaches the first desk", function()
  local info, biter = setup({desk(1, 300), desk(2, 600), desk(3, 900)})
  deps.route_or_seek_slot(info, biter)
  eq(info.state, "seeking_slot")
  eq(info.slot_search_target_id, 1)
end)

test("roaming picks second or third closest and retries after arriving", function()
  local info, biter = setup({desk(1, 20), desk(2, 40), desk(3, 60)})
  local old_random = math.random
  math.random = function(a, b) return b and 2 or 1 end
  local ok, err = pcall(function()
    deps.route_or_seek_slot(info, biter)
    eq(info.slot_search_target_id, 2)
    biter.position = surface.last_command.destination
    available[3] = 1
    game.tick = 10
    deps.process_slot_search(info, biter)
    eq(info.slot_search_target_id, nil)
    eq(info.slot_search_retry_tick, nil)
    eq(info.desk_id, 3)
    eq(info.frustration, 37)
    eq(biter.active, true)
  end)
  math.random = old_random
  if not ok then error(err) end
end)

test("a waiting visitor approaches beside a desk rather than its center", function()
  local info, biter = setup({desk(1, 20)})
  deps.route_or_seek_slot(info, biter)
  local dest = surface.last_command.destination
  local dx, dy = dest.x - 20, dest.y
  local distance_sq = dx * dx + dy * dy
  eq(distance_sq >= 49 and distance_sq <= 100, true)
  eq(info.slot_search_position_attempts, 1)
  eq(info.slot_search_dest.x, dest.x)
end)

test("a collision probe returning the desk center is rejected", function()
  local info, biter = setup({desk(1, 20)})
  local probes = 0
  surface.find_non_colliding_position = function(_, pos)
    probes = probes + 1
    if probes == 1 then return {x = 20, y = 0} end
    return pos
  end
  deps.route_or_seek_slot(info, biter)
  eq(probes, 2)
  eq(info.slot_search_position_attempts, 2)
  local dest = surface.last_command.destination
  eq((dest.x - 20)^2 + dest.y^2 >= 49, true)
end)

test("a failed approach tries three other spots then patrols", function()
  local info, biter = setup({desk(1, 20)})
  deps.route_or_seek_slot(info, biter)
  local tried = {}
  for attempt = 1, 4 do
    local dest = info.slot_search_dest
    local key = dest.x .. "," .. dest.y
    eq(tried[key], nil)
    tried[key] = true
    deps.finish_slot_search_move(info, biter, true)
    if attempt < 4 then
      eq(info.slot_search_target_id, 1)
      eq(info.slot_search_position_attempts, attempt + 1)
    end
  end
  eq(info.slot_search_target_id, nil)
  eq(info.slot_search_retry_tick, nil)
  eq(info.slot_search_failed_until[1], 10 * 60 * 60)
  eq(surface.last_command.type, defines.command.go_to_location)
  eq(biter.active, true)
end)

test("four blocked approach spots wander without routing onto the desk", function()
  local info, biter = setup({desk(1, 20)})
  local probes = 0
  surface.find_non_colliding_position = function()
    probes = probes + 1
    return nil
  end
  deps.route_or_seek_slot(info, biter)
  eq(probes, 8)
  eq(info.slot_search_target_id, nil)
  eq(info.slot_search_retry_tick, 60)
  eq(surface.last_command.type, defines.command.wander)
  eq(biter.active, true)
end)

test("the three roaming choices must all be within three chunks", function()
  local info, biter = setup({desk(1, 16), desk(2, 48), desk(3, 96), desk(4, 97)})
  local old_random = math.random
  math.random = function(a, b) return b and 3 or 1 end
  local ok, err = pcall(function()
    deps.route_or_seek_slot(info, biter)
    eq(info.state, "seeking_slot")
    eq(info.slot_search_target_id, 3)
  end)
  math.random = old_random
  if not ok then error(err) end
end)

test("a fourth-chunk desk cannot become a roaming fallback", function()
  local info, biter = setup({desk(1, 16), desk(2, 96), desk(3, 97)})
  deps.route_or_seek_slot(info, biter)
  eq(info.slot_search_target_id, 2)
end)

test("without a three-chunk roaming target the visitor patrols but still checks eight chunks", function()
  local info, biter = setup({desk(1, 97), desk(2, 200)})
  deps.route_or_seek_slot(info, biter)
  eq(info.state, "seeking_slot")
  eq(info.slot_search_target_id, nil)
  eq(info.slot_search_retry_tick, nil)
  eq(surface.last_command.type, defines.command.go_to_location)
  available[1] = 1
  game.tick = 10
  deps.process_slot_search(info, biter)
  eq(info.state, "pathfinding")
  eq(info.desk_id, 1)
end)

test("a stalled roam gives up, while real progress extends its route", function()
  local info, biter = setup({desk(1, 80)})
  deps.route_or_seek_slot(info, biter)
  game.tick = 590
  biter.position = {x = 40, y = 0}
  deps.process_slot_search(info, biter)
  eq(info.slot_search_target_id, 1)
  game.tick = 1190
  deps.process_slot_search(info, biter)
  eq(info.slot_search_target_id, 1)
  eq(info.slot_search_position_attempts, 2)
  deps.finish_slot_search_move(info, biter, true)
  deps.finish_slot_search_move(info, biter, true)
  eq(info.slot_search_position_attempts, 4)
  deps.finish_slot_search_move(info, biter, true)
  eq(info.slot_search_target_id, nil)
  eq(info.slot_search_retry_tick, nil)
  eq(info.slot_search_failed_until[1], 1190 + 10 * 60 * 60)
end)

test("a usable but full local platform keeps the visitor local", function()
  local info, biter = setup({desk(1, 350)})
  available[1] = 1
  platform_candidates = {{
    entity = {valid = true, unit_number = 10, position = {x = 30, y = 0}, surface = surface},
    kind = "platform", available = false,
  }}
  deps.route_or_seek_slot(info, biter)
  eq(info.state, "seeking_slot")
  eq(info.slot_search_target_id, 10)
  eq(reserved[1], nil)
  local dest = surface.last_command.destination
  local distance_sq = (dest.x - 30)^2 + dest.y^2
  eq(distance_sq >= 49 and distance_sq <= 100, true)
end)

for _, err in ipairs(errors) do io.stderr:write("FAIL " .. err .. "\n") end
print(("Complaint routing tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
