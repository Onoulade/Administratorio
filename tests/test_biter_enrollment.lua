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

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or "assertion failed") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

local noop = function() end

local function load_biters_module()
  package.loaded["scripts.constants"] = {
    BITER_MAX_TIER = {
      ["small-biter"] = 1,
      ["small-spitter"] = 1,
    },
    IS_SPITTER = {
      ["small-spitter"] = true,
    },
    BITER_PAYOUT = {
      ["small-biter"] = 5,
      ["small-spitter"] = 5,
    },
    PROTEST_THRESHOLD = 600,
    ENROLLMENT_OFFER_LOW_FRUSTRATION_RATIO = 0.25,
    ENROLLMENT_OFFER_MEDIUM_FRUSTRATION_RATIO = 0.50,
    ENROLLMENT_OFFER_LOW_CHANCE = 0.05,
    ENROLLMENT_OFFER_MEDIUM_CHANCE = 0.01,
    RETURN_WALK_DISTANCE = 200,
    RETURN_DESPAWN_TICKS = 30 * 60,
    DESK_SLOT_COMMAND_RADIUS = 0.5,
    DESK_SLOT_ARRIVAL_DISTANCE = 1.0,
    ZONE_DIRECTIONS = {},
    ZONE_DIR_NAMES = {},
    ZONE_SAFE_TYPES = {},
  }
  package.loaded["scripts.zones"] = {
    ensure_desk_runtime_state = noop,
    get_available_slots = function() return 0 end,
    release_slot = function() end,
    decrement_desk_occupants = noop,
  }
  package.loaded["scripts.working_hours"] = {}
  package.loaded["scripts.biters_rendering"] = {
    new = function()
      return {}
    end,
  }
  package.loaded["scripts.biters_protests"] = {
    new = function()
      return {
        reset_protest_targeting = noop,
        refresh_protest_notifications = noop,
        on_protest_target_removed = noop,
        reroute_desk_biters = noop,
        trigger_immediate_protest = noop,
        process_frustration_and_protests = noop,
        process_protest_pacing = noop,
        on_ai_command_completed = noop,
        on_script_path_request_finished = noop,
        on_script_trigger_effect = noop,
        on_biter_died = noop,
      }
    end,
  }

  return dofile(mod_root .. "scripts/biters.lua")
end

defines = {
  inventory = {
    chest = 1,
  },
  command = {
    stop = 1,
    go_to_location = 2,
  },
  distraction = {
    none = 1,
  },
}

local biters = load_biters_module()

local function new_inventory(opts)
  opts = opts or {}
  local stack = {
    valid_for_read = true,
    name = "resolved-landscape",
    count = 1,
  }
  local counts = {
    ["job-offer"] = opts.job_offer_count or 0,
  }
  local added = {}
  local removed = {}

  local inventory = {
    [1] = stack,
  }

  function inventory.is_empty()
    return false
  end

  function inventory.insert(spec)
    local count = spec.count or 1
    if spec.name == "enrolled-biter" and opts.enrolled_room == false then
      return 0
    end
    if spec.name == "taxpayer-money" and opts.taxpayer_room == false then
      return 0
    end
    counts[spec.name] = (counts[spec.name] or 0) + count
    added[spec.name] = (added[spec.name] or 0) + count
    return count
  end

  function inventory.can_insert(spec)
    if spec.name == "enrolled-biter" then
      return opts.enrolled_room ~= false
    end
    if spec.name == "taxpayer-money" then
      return opts.taxpayer_room ~= false
    end
    return true
  end

  function inventory.remove(spec)
    local count = spec.count or 1
    if spec.name == "resolved-landscape" then
      local removed_count = stack.valid_for_read and math.min(stack.count, count) or 0
      stack.count = stack.count - removed_count
      if stack.count <= 0 then
        stack.valid_for_read = false
      end
      removed[spec.name] = (removed[spec.name] or 0) + removed_count
      return removed_count
    end

    local available = counts[spec.name] or 0
    local removed_count = math.min(available, count)
    counts[spec.name] = available - removed_count
    removed[spec.name] = (removed[spec.name] or 0) + removed_count
    return removed_count
  end

  inventory._added = added
  inventory._removed = removed
  return inventory
end

local function with_random(value, fn)
  local original_random = math.random
  math.random = function()
    return value
  end
  local ok, err = pcall(fn)
  math.random = original_random
  if not ok then
    error(err, 0)
  end
end

local function new_context(opts)
  opts = opts or {}
  local inventory = new_inventory(opts)
  local last_command = nil
  local desk_id = 71

  local entity = {
    valid = true,
    name = opts.entity_name or "small-biter",
    unit_number = opts.unit_number or 11,
    position = {x = 0, y = 0},
    force = {name = "neutral"},
    active = false,
  }
  local surface = {
    index = 1,
    find_non_colliding_position = function(_, pos) return pos end,
  }
  entity.surface = surface
  entity.commandable = {
    set_command = function(command)
      last_command = command
    end,
  }
  entity.destroy = function()
    entity.valid = false
  end

  local desk = {
    valid = true,
    unit_number = desk_id,
    get_inventory = function(_, _)
      return inventory
    end,
  }

  game = {
    tick = 0,
    connected_players = {},
    surfaces = {[1] = surface},
    forces = {
      neutral = {name = "neutral"},
    },
  }

  storage = {
    waiting_biters = {},
    waiting_biter_state_index = {
      waiting = {},
      pathfinding = {},
      protesting = {},
      pacified = {},
      returning_home = {},
    },
    waiting_biter_state_index_built = true,
    desk_biters = {
      [desk_id] = {},
    },
    admin_desks = {},
    desk_circuit_dirty = {},
    achievements = {},
    stats = {
      cases_resolved = 0,
      money_earned = 0,
    },
  }

  local info = {
    entity = entity,
    desk_id = desk_id,
    complaints = {"ticket-landscape"},
    complaints_total = 1,
    complaints_filed = true,
    frustration = opts.frustration or 0,
    state = "waiting",
    tracked_unit_number = entity.unit_number,
  }

  storage.waiting_biters[entity.unit_number] = info
  storage.waiting_biter_state_index.waiting[entity.unit_number] = true
  storage.desk_biters[desk_id][entity.unit_number] = true

  return {
    desk = desk,
    desk_id = desk_id,
    entity = entity,
    info = info,
    inventory = inventory,
    last_command = function()
      return last_command
    end,
  }
end

test("low-frustration resolved biter can accept a job offer", function()
  with_random(0.04, function()
    local ctx = new_context({job_offer_count = 1, frustration = 100})
    biters.process_resolutions({ctx.desk})

    assert_true(storage.waiting_biters[ctx.entity.unit_number] == nil, "accepted biter should be untracked")
    assert_true(storage.desk_biters[ctx.desk_id][ctx.entity.unit_number] == nil, "accepted biter should leave the desk index")
    assert_true(ctx.entity.valid == false, "accepted biter should be removed from the world")
    assert_eq(ctx.inventory._removed["job-offer"], 1, "job offer should be consumed on acceptance")
    assert_eq(ctx.inventory._added["enrolled-biter"], 1, "accepted biter should produce enrolled-biter")
    assert_true(ctx.inventory._added["taxpayer-money"] == nil, "accepted biter should not pay taxpayer money")
    assert_eq(storage.stats.cases_resolved, 1, "accepted biter should still count as a resolved case")
  end)
end)

test("mid-frustration resolved biter can only accept at the reduced chance", function()
  with_random(0.005, function()
    local ctx = new_context({job_offer_count = 1, frustration = 200})
    biters.process_resolutions({ctx.desk})

    assert_true(storage.waiting_biters[ctx.entity.unit_number] == nil, "accepted mid-frustration biter should be untracked")
    assert_eq(ctx.inventory._removed["job-offer"], 1, "mid-frustration success should still consume the offer")
    assert_eq(ctx.inventory._added["enrolled-biter"], 1, "mid-frustration success should produce enrolled-biter")
    assert_true(ctx.inventory._added["taxpayer-money"] == nil, "mid-frustration success should skip taxpayer payout")
  end)
end)

test("failed job offer keeps the normal return-home payout path", function()
  with_random(0.50, function()
    local ctx = new_context({job_offer_count = 1, frustration = 100})
    biters.process_resolutions({ctx.desk})

    assert_true(storage.waiting_biters[ctx.entity.unit_number] == ctx.info, "failed offer should keep the biter tracked for return-home cleanup")
    assert_true(storage.desk_biters[ctx.desk_id][ctx.entity.unit_number] == nil, "failed offer should still remove the biter from the desk index")
    assert_eq(ctx.info.state, "returning_home", "failed offer should send the biter home")
    assert_eq(ctx.inventory._removed["job-offer"], 1, "failed offer should still be consumed")
    assert_eq(ctx.inventory._added["taxpayer-money"], 5, "failed offer should still pay taxpayer money")
    assert_true(ctx.inventory._added["enrolled-biter"] == nil, "failed offer should not produce enrolled-biter")
    assert_true(ctx.last_command() ~= nil, "failed offer should issue a return-home movement command")
  end)
end)

test("high-frustration biter consumes the offer but cannot convert", function()
  with_random(0.0, function()
    local ctx = new_context({job_offer_count = 1, frustration = 400})
    biters.process_resolutions({ctx.desk})

    assert_eq(ctx.info.state, "returning_home", "high-frustration biter should follow the normal return-home path")
    assert_eq(ctx.inventory._removed["job-offer"], 1, "high-frustration offer should still be consumed")
    assert_eq(ctx.inventory._added["taxpayer-money"], 5, "high-frustration biter should still pay taxpayer money")
    assert_true(ctx.inventory._added["enrolled-biter"] == nil, "high-frustration biter should never convert")
  end)
end)

test("spitters do not consume job offers", function()
  with_random(0.0, function()
    local ctx = new_context({job_offer_count = 1, entity_name = "small-spitter", frustration = 0})
    biters.process_resolutions({ctx.desk})

    assert_eq(ctx.inventory._removed["job-offer"] or 0, 0, "spitters should not consume job offers")
    assert_eq(ctx.inventory._added["taxpayer-money"], 5, "spitters should still pay the normal payout")
    assert_true(ctx.inventory._added["enrolled-biter"] == nil, "spitters should not produce enrolled-biter")
  end)
end)

test("job offer is not consumed when there is no room for enrolled-biter", function()
  with_random(0.0, function()
    local ctx = new_context({job_offer_count = 1, frustration = 0, enrolled_room = false})
    biters.process_resolutions({ctx.desk})

    assert_eq(ctx.inventory._removed["job-offer"] or 0, 0, "job offer should be preserved if enrolled-biter cannot be inserted")
    assert_eq(ctx.inventory._added["taxpayer-money"], 5, "no-room case should keep the normal taxpayer payout")
    assert_true(ctx.inventory._added["enrolled-biter"] == nil, "no-room case should not produce enrolled-biter")
  end)
end)

if failed > 0 then
  io.stderr:write(("Failed %d/%d tests\n"):format(failed, passed + failed))
  for _, err in ipairs(errors) do
    io.stderr:write(err, "\n")
  end
  os.exit(1)
end

print(("Passed %d tests"):format(passed))
