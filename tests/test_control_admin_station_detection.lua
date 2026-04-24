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

test("control admin station detector uses the configured station name", function()
  local admin_station_names = "admin-station"

  local function get_entity_name(entity_or_name)
    if type(entity_or_name) == "string" then
      return entity_or_name
    end
    if entity_or_name and entity_or_name.name then
      return entity_or_name.name
    end
    return nil
  end

  local function is_admin_station(entity_or_name)
    local name = get_entity_name(entity_or_name)
    return name == admin_station_names
  end

  assert_true(is_admin_station("admin-station"), "string admin-station should be detected")
  assert_true(is_admin_station({name = "admin-station"}), "entity admin-station should be detected")
  assert_true(not is_admin_station("office-desk"), "non-admin entities should not match")
end)

print(("Control admin station detection tests: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
  for _, err in ipairs(errors) do
    print(" - " .. err)
  end
  os.exit(1)
end
