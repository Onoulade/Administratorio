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

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

defines = {
  direction = {
    north = 0,
    east = 2,
    south = 4,
    west = 6,
  },
}

local frustration = require("scripts.frustration")

local function new_gui_element(name)
  local element = {
    name = name,
    children = {},
    style = {},
  }

  element.add = function(spec)
    local child = new_gui_element(spec.name)
    child.parent = element
    child.type = spec.type
    child.caption = spec.caption
    element.children[#element.children + 1] = child
    if spec.name then
      element[spec.name] = child
    end
    return child
  end

  element.destroy = function()
    element.destroyed = true
    if element.parent and element.name then
      element.parent[element.name] = nil
    end
  end

  return element
end

local function collect_captions(element, captions)
  captions = captions or {}
  if element.caption then captions[#captions + 1] = element.caption end
  for _, child in ipairs(element.children or {}) do
    collect_captions(child, captions)
  end
  return captions
end

local function panel_captions_for(state)
  local left = new_gui_element("left")
  local player = {gui = {left = left}}
  local entity = {valid = true, unit_number = 42}

  storage = {
    waiting_biters = {
      [42] = {
        state = state,
        frustration = 300,
        complaints = {"ticket-landscape"},
      },
    },
  }

  frustration.update_biter_info_gui(player, entity)
  return collect_captions(left["administratorio-biter-info"])
end

local function has_caption(captions, expected)
  for _, caption in ipairs(captions) do
    if caption == expected then return true end
  end
  return false
end

test("protesting hover explains promise action", function()
  local captions = panel_captions_for("protesting")
  assert_true(has_caption(captions, "Protesting because the queue failed; use a Bureaucratic Promise so it stops and returns to a desk."),
    "protesting biter should explain why it protests and how to stop it")
end)

test("pacified hover explains desk requirement", function()
  local captions = panel_captions_for("pacified")
  assert_true(has_caption(captions, "It accepted a Bureaucratic Promise and is waiting for an open desk slot before the promise expires."),
    "pacified biter should explain that it is waiting for desk capacity")
end)

print(string.format("\n=== FRUSTRATION GUI TESTS ==="))
print(string.format("Passed: %d  Failed: %d  Total: %d", passed, failed, passed + failed))

if #errors > 0 then
  print("\nFAILURES:")
  for i, err in ipairs(errors) do
    print(string.format("  %d) %s", i, err))
  end
  os.exit(1)
else
  print("\nAll tests passed!")
  os.exit(0)
end
