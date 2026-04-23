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

data = {
  raw = {
    item = {
      ["behemoth-biter"] = {
        type = "item",
        name = "behemoth-biter",
        icon = "__base__/graphics/icons/behemoth-biter.png",
        icon_size = 64,
      },
    },
    ["selection-tool"] = {
      ["copy-paste-tool"] = {
        type = "selection-tool",
        name = "copy-paste-tool",
        select = {},
        alt_select = {},
        stack_size = 1,
      },
    },
  },
}

function data:extend(prototypes)
  for _, proto in ipairs(prototypes) do
    data.raw[proto.type] = data.raw[proto.type] or {}
    data.raw[proto.type][proto.name] = proto
  end
end

util = {
  table = {
    deepcopy = function(tbl)
      if type(tbl) ~= "table" then return tbl end
      local copy = {}
      for k, v in pairs(tbl) do
        copy[util.table.deepcopy(k)] = util.table.deepcopy(v)
      end
      return setmetatable(copy, getmetatable(tbl))
    end,
  },
}

if not table.deepcopy then
  table.deepcopy = util.table.deepcopy
end

local mod_root = debug.getinfo(1, "S").source:match("@(.*/)")
if mod_root then
  mod_root = mod_root:gsub("Internal/tests/$", ""):gsub("tests/$", "")
else
  mod_root = "./"
end
package.path = mod_root .. "?.lua;" .. mod_root .. "?/init.lua;" .. package.path

dofile(mod_root .. "prototypes/item/economy.lua")
dofile(mod_root .. "prototypes/item/buildings.lua")
dofile(mod_root .. "prototypes/item/capsules-and-fluids.lua")

local function first_icon(item_name)
  local item = data.raw.item[item_name]
  assert_true(item ~= nil, item_name .. " item missing")
  assert_true(item.icons ~= nil and item.icons[1] ~= nil, item_name .. " should use layered icons")
  return item.icons[1]
end

test("worker and formed biter items lead with tinted biter icons", function()
  for _, item_name in ipairs({
    "biter-worker",
    "biter-logistics-formation",
    "rideable-biter",
    "union-delegate",
    "chemical-operator",
    "nuclear-technician",
    "hired-biter-capsule",
  }) do
    local icon = first_icon(item_name)
    assert_true(icon.icon:find("biter", 1, true) ~= nil, item_name .. " should lead with a biter icon")
    assert_true(icon.tint ~= nil, item_name .. " biter icon should be tinted")
  end
end)

test("specialists and rideable biter use medium biter icon tier", function()
  for _, item_name in ipairs({
    "rideable-biter",
    "union-delegate",
    "chemical-operator",
    "nuclear-technician",
  }) do
    local icon = first_icon(item_name)
    assert_true(icon.icon == "__base__/graphics/icons/medium-biter.png", item_name .. " should lead with a medium biter icon")
  end
end)

test("biter administration buildings use building-derived icons", function()
  local expected = {
    ["biterport"] = "__administratorio__/graphics/icons/biterport.png",
    ["formation-center"] = "__administratorio__/graphics/icons/formation-center.png",
    ["biter-station"] = "__administratorio__/graphics/icons/biter-station.png",
  }

  for item_name, icon_path in pairs(expected) do
    local item = data.raw.item[item_name]
    assert_true(item ~= nil, item_name .. " item missing")
    assert_true(item.icon == icon_path, item_name .. " should use its building-derived icon")
    assert_true(item.icon_size == 64, item_name .. " icon should be 64px")
  end
end)

print(("Biter item icon tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
