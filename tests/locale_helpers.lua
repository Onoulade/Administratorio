-- Locale files are intentionally split by player-facing domain. Tests read
-- the directory just as Factorio does, not a retired config.cfg monolith.
local M = {}

local locale_files = {
  "achievements.cfg", "catalog.cfg", "entities.cfg", "factoriopedia.cfg",
  "gameplay.cfg", "interface.cfg", "items.cfg", "recipes.cfg", "settings.cfg",
  "technologies.cfg", "tips.cfg",
}

function M.load(root, language)
  local sections = {}
  for _, file_name in ipairs(locale_files) do
    local file = io.open(root .. "locale/" .. language .. "/" .. file_name, "r")
    if file then
      local current = nil
      for line in file:lines() do
        local header = line:match("^%[([^%]]+)%]$")
        if header then
          current = header
          sections[current] = sections[current] or {}
        elseif current then
          local key, value = line:match("^([^=]+)=(.*)$")
          if key then sections[current][key] = value end
        end
      end
      file:close()
    end
  end
  return sections
end

function M.section(root, language, section_name)
  return M.load(root, language)[section_name] or {}
end

return M
