package.path = "./?.lua;./?/init.lua;" .. package.path

defines = {
  direction = {north = 0, east = 2, south = 4, west = 6},
}

local C = require("scripts.constants")

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local expected_by_size = {
  small = 1,
  medium = 2,
  big = 3,
  behemoth = 4,
}

for size, expected in pairs(expected_by_size) do
  for _, kind in ipairs({"biter", "spitter"}) do
    local entity_name = size .. "-" .. kind
    assert_eq(C.BITER_COMPLAINT_COUNT[entity_name], expected, entity_name .. " complaint count")
    assert_eq(#C.generate_complaints(entity_name), expected, entity_name .. " generated complaint count")
  end
end

print("Complaint count tests passed.")
