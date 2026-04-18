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
    error((msg or "") .. " expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local resources = {}

data = {
  raw = {
    resource = resources,
  },
}

function data:extend(prototypes)
  for _, proto in ipairs(prototypes) do
    if proto.type == "resource" then
      resources[proto.name] = proto
    end
  end
end

package.preload["resource-autoplace"] = function()
  return {
    resource_autoplace_settings = function(settings)
      return settings
    end,
  }
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

dofile(mod_root .. "prototypes/resources.lua")

test("redundant rubble resource uses the redundant rubble icon", function()
  local rubble = resources["redundant-rubble"]
  assert_eq(rubble.icon, "__administratorio__/graphics/icons/redundant-rubble.png")
  assert_eq(rubble.icon_size, 64)
end)

print(("Resource prototype tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
