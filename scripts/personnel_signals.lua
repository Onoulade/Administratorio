-- Each exit has an identical, independently selectable circuit socket.
-- The sign body is decorative infrastructure and has no signal editor.
local R = require("prototypes.shared.personnel_routing")
local M = {}
function M.ensure_ports(record)
  if record.entity.name ~= R.MULTISIGN then return end
  record.entity.operable = false
  local rotated = record.port_direction ~= record.entity.direction
  record.port_direction = record.entity.direction
  record.ports = record.ports or {}
  for _,exit in ipairs(R.exits) do
    local direction = R.exit_direction(record.entity.direction, exit)
    local dx,dy = R.vector(direction)
    local p = record.entity.position
    local socket_offset=0.4*R.MULTISIGN_SCALE
    local position = {x=p.x+dx*socket_offset,y=p.y+dy*socket_offset}
    local port = record.ports[exit]
    if not port or not port.valid then
      port = record.entity.surface.create_entity{name=R.PORT .. "-" .. exit,position=position,force=record.entity.force}
      record.ports[exit] = port
    elseif port.position.x ~= position.x or port.position.y ~= position.y then
      port.teleport(position)
    end
    if port then
      port.destructible,port.minable_flag,port.rotatable,port.operable = false,false,false,false
    end
  end
  return rotated
end
function M.remove_ports(record)
  for _,port in pairs(record.ports or {}) do if port.valid then port.destroy() end end
  record.ports = nil
end
function M.read_filters(record)
  local filters, signatures = {}, {}
  for _,exit in ipairs(R.exits) do
    local port = record.ports[exit]
    local totals = {}
    if port and port.valid then
      local ids = defines.wire_connector_id
      for _,entry in ipairs(port.get_signals(ids.circuit_red, ids.circuit_green) or {}) do
        local signal = entry.signal
        if (signal.type or "item") == "item" and R.cargo[signal.name] then
          totals[signal.name] = (totals[signal.name] or 0) + entry.count
        end
      end
    end
    filters[exit] = {}
    local names = {}
    for name,count in pairs(totals) do
      if count > 0 then filters[exit][name] = true; names[#names+1] = name end
    end
    table.sort(names)
    signatures[#signatures+1] = table.concat(names, ",")
  end
  local signature = table.concat(signatures, "/")
  local changed = signature ~= record.filter_signature
  record.filters,record.filter_signature = filters,signature
  return changed
end
function M.update(records, jobs, changed)
  local counts = {}
  -- A job belongs to precisely its immediate incoming segment, regardless of
  -- how many older blocks its trailing body still reserves. Merge all arrivals.
  for _,job in pairs(jobs) do
    local route = job.route
    local terminal = route and route[#route]
    local node = terminal and terminal.node
    if job.state ~= "recovery" and node and node.entity.valid and node.entity.name == R.SIGN
      and job.cargo[1].valid_for_read then
      local id,item = node.entity.unit_number,job.cargo[1].name
      counts[id] = counts[id] or {}
      counts[id][item] = (counts[id][item] or 0) + 1
    end
  end
  for id,record in pairs(records) do
    local entity = record.entity
    if entity.valid and entity.name == R.MULTISIGN then
      local rotated = M.ensure_ports(record)
      local filtered = M.read_filters(record)
      if rotated or filtered then changed(record, rotated) end
    elseif entity.valid and entity.name == R.SIGN then
      local values,names = counts[id] or {},{}
      for name in pairs(values) do names[#names+1] = name end
      table.sort(names)
      local filters = {}
      for index,name in ipairs(names) do
        filters[index] = {value={type="item",name=name,quality="normal"},min=values[name]}
      end
      local control = entity.get_or_create_control_behavior()
      for index=control.sections_count,2,-1 do control.remove_section(index) end
      local section = control.get_section(1) or control.add_section()
      section.group = ""
      section.filters = filters
      section.active = true
      control.enabled = true
    end
  end
end
return M
