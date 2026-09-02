#!/usr/bin/env lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local reference_docs = require("tools.reference_docs")
local check_only = false
local root = "."

local index = 1
while index <= #arg do
  if arg[index] == "--check" then
    check_only = true
  elseif arg[index] == "--repo-root" then
    index = index + 1
    root = assert(arg[index], "--repo-root requires a path")
  else
    error("unknown argument: " .. tostring(arg[index]))
  end
  index = index + 1
end

if check_only then
  local ok, problems = reference_docs.check(root)
  if not ok then
    for _, problem in ipairs(problems) do io.stderr:write(problem .. "\n") end
    os.exit(1)
  end
  print("Generated reference documentation is current.")
  os.exit(0)
end

local ok, err = reference_docs.update(root)
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  os.exit(1)
end
print("Generated reference documentation updated.")
