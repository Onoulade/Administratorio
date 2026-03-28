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

local function assert_true(value, msg)
  if not value then
    error(msg or "assertion failed", 2)
  end
end

local item_subgroups = {}
local fluids = {}

data = {
  raw = {
    ["item-subgroup"] = item_subgroups,
    fluid = fluids,
  },
}

function data:extend(prototypes)
  for _, proto in ipairs(prototypes) do
    if proto.type == "item-subgroup" then
      item_subgroups[proto.name] = proto
    elseif proto.type == "fluid" then
      fluids[proto.name] = proto
    end
  end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

dofile(mod_root .. "prototypes/item/groups.lua")
dofile(mod_root .. "prototypes/item/capsules-and-fluids.lua")

test("admin-fluids subgroup exists", function()
  assert_true(item_subgroups["admin-fluids"] ~= nil, "admin-fluids subgroup missing")
end)

test("administrative fluids are assigned to admin-fluids subgroup", function()
  local names = {
    "slush-fund",
    "politician-fluid",
    "lie",
    "misinformation",
    "union-approval",
    "liquid-coffee",
  }

  for _, name in ipairs(names) do
    local fluid = fluids[name]
    assert_true(fluid ~= nil, name .. " fluid missing")
    assert_eq(fluid.subgroup, "admin-fluids", name .. " subgroup")
  end
end)

print(("Prototype grouping tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
