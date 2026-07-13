local passed, failed, errors = 0, 0, {}

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then passed = passed + 1 else failed = failed + 1; errors[#errors + 1] = name .. ": " .. tostring(err) end
end

local function assert_true(value, message)
  if not value then error(message or "assertion failed", 2) end
end

local function assert_eq(actual, expected, message)
  if actual ~= expected then error((message or "assertion failed") .. " - expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end

local root = debug.getinfo(1, "S").source:match("@(.*/)"):gsub("tests/$", "")
package.path = root .. "?.lua;" .. root .. "?/init.lua;" .. package.path

storage = {}
defines = {
  inventory = {lab_input = 1},
  entity_status_diode = {red = 1, yellow = 2, green = 3},
}
prototypes = {entity = {}}

local rules = require("scripts.archive_recombination_rules")
local archive = require("scripts.archive_recombination")

local function researched_force()
  local technologies = setmetatable({}, {
    __index = function(table_value, key)
      local value = {researched = true}
      rawset(table_value, key, value)
      return value
    end,
  })
  return {valid = true, index = 1, technologies = technologies}
end

local function stack(name, quality, count)
  return {
    name = name,
    quality = quality or "normal",
    count = count or 1,
    valid_for_read = true,
  }
end

local function successful_unit(left, right, wanted_success)
  for unit_number = 1, 10000 do
    local succeeds = rules.deterministic_roll(unit_number, 1, left, right, "success") < rules.SUCCESS_PERCENT
    if succeeds == wanted_success then return unit_number end
  end
  error("could not find deterministic test unit")
end

local function new_state(stacks, unit_number)
  local inventory = stacks or {}
  local spilled = {}
  local created_sinks = {}
  local surface = {}
  surface.create_entity = function(spec)
    local sink = {
      valid = true,
      name = spec.name,
      energy = archive.POWER_READY_ENERGY,
    }
    sink.destroy = function() sink.valid = false end
    created_sinks[#created_sinks + 1] = sink
    return sink
  end
  surface.spill_item_stack = function(spec)
    spilled[#spilled + 1] = spec
    return {{valid = true}}
  end
  local entity = {
    valid = true,
    name = archive.ENTITY_NAME,
    unit_number = unit_number or 42,
    force = researched_force(),
    position = {x = 10, y = 20},
    get_inventory = function() return inventory end,
    surface = surface,
  }
  return {
    attempts = 0,
    successes = 0,
    failures = 0,
    entity = entity,
  }, inventory, spilled
end

local function run_attempt(state)
  for _ = 1, archive.PROCESS_TICKS / archive.UPDATE_TICKS do
    archive.process_state(state)
  end
end

test("bureau automatically detects and consumes two compatible forms", function()
  local state, inventory = new_state({
    stack("carbon-offset-certificate-basic"),
    stack("work-order"),
  })
  archive.process_state(state)
  assert_true(state.working)
  assert_eq(state.left, "carbon-offset-certificate-basic")
  assert_eq(state.right, "work-order")
  assert_eq(inventory[1].count, 0)
  assert_eq(inventory[2].count, 0)
end)

test("successful attempts emit exactly one legal third form at the east chute", function()
  local left, right = "carbon-offset-certificate-basic", "work-order"
  local state, _, spilled = new_state({stack(left, "rare"), stack(right, "rare")}, successful_unit(left, right, true))
  run_attempt(state)
  assert_eq(state.attempts, 1)
  assert_eq(state.successes, 1)
  assert_eq(state.failures, 0)
  assert_eq(#spilled, 1)
  assert_eq(spilled[1].position.x, 12)
  assert_eq(spilled[1].position.y, 20)
  assert_eq(spilled[1].stack.quality, "rare")
  assert_true(spilled[1].stack.name ~= left and spilled[1].stack.name ~= right)
  local legal = false
  for _, candidate in ipairs(rules.generate_candidates(left, right)) do
    if candidate.name == spilled[1].stack.name then legal = true end
  end
  assert_true(legal, "output must belong to the pair's candidate set")
end)

test("failed attempts yield nothing", function()
  local left, right = "carbon-offset-certificate-basic", "work-order"
  local state, _, spilled = new_state({stack(left), stack(right)}, successful_unit(left, right, false))
  run_attempt(state)
  assert_eq(state.attempts, 1)
  assert_eq(state.successes, 0)
  assert_eq(state.failures, 1)
  assert_eq(#spilled, 0)
end)

test("different qualities do not form a pair", function()
  local state, inventory = new_state({
    stack("carbon-offset-certificate-basic", "normal"),
    stack("work-order", "rare"),
  })
  archive.process_state(state)
  assert_true(not state.working)
  assert_eq(inventory[1].count, 1)
  assert_eq(inventory[2].count, 1)
end)

test("processing pauses without power after reserving its forms", function()
  local state = new_state({stack("carbon-offset-certificate-basic"), stack("work-order")})
  state.power_sink = {valid = true, energy = 0, destroy = function() end}
  archive.process_state(state)
  assert_true(state.working)
  assert_eq(state.remaining_ticks, archive.PROCESS_TICKS)
  assert_eq(state.attempts, 0)
  assert_eq(state.entity.custom_status.label[1], "entity-status.archive-recombination-no-power")
end)

test("identical forms are not a valid pair", function()
  local state = new_state({stack("work-order", "normal", 2)})
  archive.process_state(state)
  assert_true(not state.working)
  assert_eq(state.attempts, 0)
end)

print(("Archive recombination runtime tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do io.stderr:write(err .. "\n") end
  os.exit(1)
end
