package.path = "./?.lua;./?/init.lua;" .. package.path

local reference_docs = require("tools.reference_docs")
local ok, problems = reference_docs.check(".")

if not ok then
  error("reference documentation check failed:\n- " .. table.concat(problems, "\n- "), 0)
end

print("Reference documentation tests passed.")
