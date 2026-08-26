-------------------------------------------------------------------------------
-- ADMINISTRATORIO MILITARY HIDING TESTS
--
-- The final-fixes pass removes conventional combat from this mod. Verify that
-- it removes the associated item/recipe/technology shells too, while keeping
-- the custom trajectory-compliance defense surface visible.
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

local function assert_true(value, msg)
  if not value then error(msg or "assertion failed", 2) end
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

local military_hiding = require("prototypes.final_fixes.military_hiding")

local data = {
  raw = {
    gun = {
      pistol = {name = "pistol"},
    },
    ammo = {
      bullets = {name = "bullets"},
      ["orbital-deviation-order"] = {name = "orbital-deviation-order"},
    },
    ["ammo-turret"] = {
      ["rocket-turret"] = {name = "rocket-turret"},
      ["trajectory-compliance-array"] = {name = "trajectory-compliance-array"},
    },
    item = {
      ["rocket-turret"] = {name = "rocket-turret"},
      ["personal-laser-defense-equipment"] = {name = "personal-laser-defense-equipment"},
      ["discharge-defense-equipment"] = {name = "discharge-defense-equipment"},
    },
    recipe = {
      ["rocket-turret"] = {name = "rocket-turret"},
      ["personal-laser-defense-equipment"] = {name = "personal-laser-defense-equipment"},
      ["discharge-defense-equipment"] = {name = "discharge-defense-equipment"},
    },
    technology = {
      ["rocket-turret"] = {name = "rocket-turret", enabled = true},
      ["personal-laser-defense-equipment"] = {name = "personal-laser-defense-equipment", enabled = true},
      ["discharge-defense-equipment"] = {name = "discharge-defense-equipment", enabled = true},
    },
    ["electric-turret"] = {},
    ["fluid-turret"] = {},
  },
}

military_hiding.apply(data)

test("conventional combat prototypes are hidden", function()
  assert_true(data.raw.gun.pistol.hidden, "guns should be hidden")
  assert_true(data.raw.ammo.bullets.hidden, "ammunition should be hidden")
  assert_true(data.raw["ammo-turret"]["rocket-turret"].hidden, "turrets should be hidden")
end)

test("removed combat shells are hidden and disabled", function()
  for _, prototype_type in ipairs({"item", "recipe", "technology"}) do
    for _, name in ipairs({"rocket-turret", "personal-laser-defense-equipment", "discharge-defense-equipment"}) do
      local prototype = data.raw[prototype_type][name]
      assert_true(prototype.hidden, prototype_type .. " " .. name .. " should be hidden")
      assert_true(prototype.enabled == false, prototype_type .. " " .. name .. " should be disabled")
    end
  end
end)

test("Administratorio defense exceptions remain visible", function()
  assert_true(not data.raw.ammo["orbital-deviation-order"].hidden,
    "orbital deviation orders should remain visible")
  assert_true(not data.raw["ammo-turret"]["trajectory-compliance-array"].hidden,
    "trajectory compliance arrays should remain visible")
end)

print(("Military hiding tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
