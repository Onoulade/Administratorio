local facts = require("prototypes.shared.gameplay_facts")
local obsolete = require("prototypes.shared.obsolete_identifiers")

local M = {}

local function title_case(value)
  return (value:gsub("^%l", string.upper))
end

local function markdown_table(headers, rows)
  local lines = {
    "| " .. table.concat(headers, " | ") .. " |",
  }
  local dividers = {}
  for _ = 1, #headers do dividers[#dividers + 1] = "---" end
  lines[#lines + 1] = "| " .. table.concat(dividers, " | ") .. " |"
  for _, row in ipairs(rows) do
    lines[#lines + 1] = "| " .. table.concat(row, " | ") .. " |"
  end
  return table.concat(lines, "\n")
end

local function complaint_size_table()
  local rows = {}
  local additions = {
    "landscape / littering",
    "adds smog / hazmat",
    "adds noise / loitering",
    "adds unemployment / vagrancy",
  }
  for index, size in ipairs(facts.biter_sizes) do
    rows[#rows + 1] = {
      title_case(size.name),
      tostring(size.complaint_count),
      tostring(size.max_tier) .. " (" .. additions[index] .. ")",
      tostring(size.payout) .. " taxpayer-money",
    }
  end
  return markdown_table({"Biter Size", "Complaint Count", "Max Tier", "Payout"}, rows)
end

local function worker_yield_table()
  local rows = {}
  for _, size in ipairs(facts.biter_sizes) do
    rows[#rows + 1] = {
      title_case(size.name) .. " biter / spitter",
      tostring(size.worker_yield),
      size.name == "big" and "Large" or title_case(size.name),
    }
  end
  return markdown_table({"Biter Type", "Workers Hired", "Size Category"}, rows)
end

local function admin_station_table()
  local station = facts.admin_station
  return markdown_table({"Property", "Value"}, {
    {"Inventory size", tostring(station.inventory_size)},
    {"Base waiting slots", tostring(station.base_waiting_capacity)},
    {"Maximum waiting slots", tostring(station.max_waiting_capacity)},
    {"Capacity upgrades", tostring(station.max_waiting_capacity - station.base_waiting_capacity)
      .. " (`" .. station.capacity_technology_prefix .. "1` through `"
      .. station.capacity_technology_prefix .. (station.max_waiting_capacity - station.base_waiting_capacity) .. "`)"},
  })
end

local function managed_building_table()
  local rows = {}
  for _, name in ipairs(facts.biter_station.managed_buildings) do
    rows[#rows + 1] = {"`" .. name .. "`"}
  end
  return markdown_table({"Managed Building"}, rows)
end

local function biter_station_table()
  local station = facts.biter_station
  return markdown_table({"Property", "Value"}, {
    {"Inventory slots", tostring(station.inventory_size)},
    {"Taxpayer-money slots", tostring(station.money_slots)},
    {"Worker slots", tostring(station.worker_slots)},
    {"Dispatch range", tostring(station.range) .. " tiles"},
    {"Salary", tostring(station.salary_per_dispatch) .. " taxpayer-money per dispatch"},
    {"Night-shift coffee", tostring(station.night_coffee_per_dispatch) .. " liquid-coffee per dispatch"},
  })
end

local function labor_efficiency_table()
  local station = facts.biter_station
  local rows = {
    {"Base", tostring(station.base_visits_per_trip), "`" .. station.base_worker_entity .. "`"},
  }
  for _, tier in ipairs(station.labor_efficiency) do
    rows[#rows + 1] = {
      "`" .. tier.technology .. "`",
      tostring(tier.visits_per_trip),
      "`" .. tier.worker_entity .. "`",
    }
  end
  return markdown_table({"Technology", "Managed-machine Visits per Trip", "Worker Entity"}, rows)
end

local function biterport_configuration_table()
  local port = facts.biterport
  return markdown_table({"Property", "Value"}, {
    {"Worker slots", tostring(port.worker_slots)},
    {"Inventory slots", tostring(port.inventory_size)},
    {"Logistics radius", tostring(port.logistics_radius) .. " tiles"},
    {"Network connection distance", tostring(port.connection_distance) .. " tiles"},
    {"Construction radius", tostring(port.construction_radius) .. " tiles"},
    {"Salary", tostring(port.salary_per_dispatch) .. " taxpayer-money per dispatch"},
    {"Night-shift coffee", tostring(port.night_coffee_per_dispatch) .. " liquid-coffee per dispatch"},
  })
end

local function biterport_transport_table()
  local port = facts.biterport
  local rows = {{"Base", tostring(port.base_transport_capacity)}}
  for _, tier in ipairs(port.transport_capacity) do
    rows[#rows + 1] = {"`" .. tier.technology .. "`", tostring(tier.items_per_worker)}
  end
  return markdown_table({"Technology", "Items per Worker"}, rows)
end

local function biterport_speed_table()
  local port = facts.biterport
  local rows = {{"Base", "1.00×", "`" .. port.base_worker_entity .. "`"}}
  for _, tier in ipairs(port.worker_speed) do
    rows[#rows + 1] = {
      "`" .. tier.technology .. "`",
      string.format("%.2f×", tier.multiplier),
      "`" .. tier.worker_entity .. "`",
    }
  end
  return markdown_table({"Technology", "Movement Multiplier", "Worker Entity"}, rows)
end

local function pneumatic_capacity_table()
  local pneumatic = facts.pneumatic
  local rows = {{"Base", tostring(pneumatic.base_capacity)}}
  for _, tier in ipairs(pneumatic.capacity) do
    rows[#rows + 1] = {"`" .. tier.technology .. "`", tostring(tier.total)}
  end
  return markdown_table({"Technology", "Total Network Capacity"}, rows)
end

local function hired_biter_capacity_table()
  return markdown_table({"Property", "Value"}, {
    {"Eviction-notice capacity", tostring(facts.hired_biter.eviction_notice_capacity)},
  })
end

local function working_hours_table()
  local working_hours = facts.working_hours
  local rows = {}
  for _, name in ipairs(working_hours.managed_buildings) do
    rows[#rows + 1] = {"`" .. name .. "`"}
  end
  local building_table = markdown_table({"Night-shutdown Building"}, rows)
  local duration = (working_hours.night_end - working_hours.night_start) * 100
  local window_table = markdown_table({"Property", "Value"}, {
    {"Night window", string.format("%.2f–%.2f daytime", working_hours.night_start, working_hours.night_end)},
    {"Cycle closed", string.format("%.0f%%", duration)},
  })
  return building_table .. "\n\n" .. window_table
end

M.sections = {
  {path = "Internal/docs/core-mechanics.md", name = "complaint-size-facts", render = complaint_size_table},
  {path = "Internal/docs/core-mechanics.md", name = "admin-station-facts", render = admin_station_table},
  {path = "Internal/docs/buildings-and-structures.md", name = "admin-station-facts", render = admin_station_table},
  {path = "Internal/docs/buildings-and-structures.md", name = "pneumatic-capacity-facts", render = pneumatic_capacity_table},
  {path = "Internal/docs/biter-employment.md", name = "worker-yield-facts", render = worker_yield_table},
  {path = "Internal/docs/biter-employment.md", name = "managed-building-facts", render = managed_building_table},
  {path = "Internal/docs/biter-employment.md", name = "biter-station-facts", render = biter_station_table},
  {path = "Internal/docs/biter-employment.md", name = "labor-efficiency-facts", render = labor_efficiency_table},
  {path = "Internal/docs/biter-employment.md", name = "biterport-configuration-facts", render = biterport_configuration_table},
  {path = "Internal/docs/biter-employment.md", name = "biterport-transport-facts", render = biterport_transport_table},
  {path = "Internal/docs/biter-employment.md", name = "biterport-speed-facts", render = biterport_speed_table},
  {path = "Internal/docs/technology-tree.md", name = "labor-efficiency-facts", render = labor_efficiency_table},
  {path = "Internal/docs/technology-tree.md", name = "biterport-transport-facts", render = biterport_transport_table},
  {path = "Internal/docs/technology-tree.md", name = "biterport-speed-facts", render = biterport_speed_table},
  {path = "Internal/docs/technology-tree.md", name = "pneumatic-capacity-facts", render = pneumatic_capacity_table},
  {path = "Internal/progression-system.md", name = "complaint-size-facts", render = complaint_size_table},
  {path = "Internal/progression-system.md", name = "admin-station-facts", render = admin_station_table},
  {path = "Internal/docs/advanced-topics.md", name = "hired-biter-capacity-facts", render = hired_biter_capacity_table},
  {path = "Internal/docs/advanced-topics.md", name = "working-hours-facts", render = working_hours_table},
}

local function generated_block(section)
  return "<!-- BEGIN GENERATED: " .. section.name .. " -->\n"
    .. "<!-- Generated by tools/generate-reference-docs.lua; do not edit by hand. -->\n"
    .. section.render() .. "\n"
    .. "<!-- END GENERATED: " .. section.name .. " -->"
end

local function read_file(path)
  local handle, err = io.open(path, "rb")
  if not handle then return nil, err end
  local content = handle:read("*a")
  handle:close()
  return content
end

local function write_file(path, content)
  local handle, err = io.open(path, "wb")
  if not handle then return nil, err end
  handle:write(content)
  handle:close()
  return true
end

local function replace_section(content, section)
  local start_marker = "<!-- BEGIN GENERATED: " .. section.name .. " -->"
  local end_marker = "<!-- END GENERATED: " .. section.name .. " -->"
  local first = content:find(start_marker, 1, true)
  if not first then return nil, "missing " .. start_marker end
  local last = content:find(end_marker, first + #start_marker, true)
  if not last then return nil, "missing " .. end_marker end
  return content:sub(1, first - 1) .. generated_block(section)
    .. content:sub(last + #end_marker)
end

local function root_path(root, relative)
  if not root or root == "" or root == "." then return relative end
  return root:gsub("/$", "") .. "/" .. relative
end

function M.update(root)
  local contents = {}
  for _, section in ipairs(M.sections) do
    local path = root_path(root, section.path)
    if contents[path] == nil then
      local content, err = read_file(path)
      if not content then return nil, path .. ": " .. tostring(err) end
      contents[path] = content
    end
    local updated, err = replace_section(contents[path], section)
    if not updated then return nil, section.path .. ": " .. err end
    contents[path] = updated
  end
  for path, content in pairs(contents) do
    local ok, err = write_file(path, content)
    if not ok then return nil, path .. ": " .. tostring(err) end
  end
  return true
end

local function shell_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function maintained_reference_files(root)
  local internal_root = root_path(root, "Internal")
  local locale_root = root_path(root, "locale")
  local command = "find " .. shell_quote(internal_root) .. " " .. shell_quote(locale_root)
    .. " -type f \\( -name '*.md' -o -name '*.cfg' \\) -print"
  local pipe, err = io.popen(command, "r")
  if not pipe then return nil, err end

  local prefix = (root and root ~= "" and root ~= ".")
    and root:gsub("/$", "") .. "/"
    or ""
  local paths = {}
  for discovered_path in pipe:lines() do
    local path = discovered_path
    if prefix ~= "" and path:sub(1, #prefix) == prefix then
      path = path:sub(#prefix + 1)
    end
    paths[#paths + 1] = path
  end
  local ok = pipe:close()
  if not ok then return nil, "could not enumerate maintained references" end
  table.sort(paths)
  return paths
end

function M.check(root)
  local problems = {}
  local expected_by_path = {}
  for _, section in ipairs(M.sections) do
    local path = root_path(root, section.path)
    if expected_by_path[path] == nil then
      local content, err = read_file(path)
      if not content then
        problems[#problems + 1] = section.path .. ": " .. tostring(err)
        expected_by_path[path] = false
      else
        expected_by_path[path] = content
      end
    end
    local content = expected_by_path[path]
    if content then
      local updated, err = replace_section(content, section)
      if not updated then
        problems[#problems + 1] = section.path .. ": " .. err
      elseif updated ~= content then
        problems[#problems + 1] = section.path .. ": stale generated section " .. section.name
      end
    end
  end

  local reference_files, list_err = maintained_reference_files(root)
  if not reference_files then
    problems[#problems + 1] = tostring(list_err)
    return false, problems
  end
  for _, relative in ipairs(reference_files) do
    local content, err = read_file(root_path(root, relative))
    if not content then
      problems[#problems + 1] = relative .. ": " .. tostring(err)
    else
      for _, identifier in ipairs(obsolete.technologies) do
        if content:find(identifier, 1, true) then
          problems[#problems + 1] = relative .. ": obsolete technology identifier " .. identifier
        end
      end
    end
  end

  return #problems == 0, problems
end

return M
