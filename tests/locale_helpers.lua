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

local name_sections = {
  recipe = "recipe-name",
  technology = "technology-name",
  item = "item-name",
  tool = "item-name",
  module = "item-name",
  capsule = "item-name",
  ammo = "item-name",
  gun = "item-name",
  armor = "item-name",
  ["selection-tool"] = "item-name",
  fluid = "fluid-name",
  ["virtual-signal"] = "virtual-signal-name",
  ["recipe-category"] = "recipe-category-name",
  ["module-category"] = "module-category-name",
  ["fuel-category"] = "fuel-category-name",
  ["item-group"] = "item-group-name",
  ["item-subgroup"] = "item-subgroup-name",
  ["tips-and-tricks-item"] = "tips-and-tricks-item-name",
  ["simple-entity-with-owner"] = "entity-name",
  ["assembling-machine"] = "entity-name",
  furnace = "entity-name",
  ["constant-combinator"] = "entity-name",
  ["train-stop"] = "entity-name",
  car = "entity-name",
  projectile = "entity-name",
  ["asteroid-chunk"] = "asteroid-chunk-name",
}

function M.missing_prototype_names(root, language, prototypes)
  local locale = M.load(root, language)
  local missing = {}
  local seen = {}
  for _, prototype in ipairs(prototypes) do
    local section = name_sections[prototype.type]
    if section and prototype.name then
      local localised_name = prototype.localised_name
      local key
      if type(localised_name) == "table" then
        key = localised_name[1]
      elseif type(localised_name) == "string" then
        key = localised_name
      else
        key = section .. "." .. prototype.name
      end
      if type(key) == "string" and key ~= "" then
        local key_section, key_name = key:match("^([^%.]+)%.(.+)$")
        -- This one explicit reference belongs to Factorio's base locale.
        local vanilla_key = key == "item-name.plastic-bar"
        if key_section and not vanilla_key and not (locale[key_section] or {})[key_name] then
          local entry = prototype.type .. "." .. prototype.name .. " -> " .. key
          if not seen[entry] then
            missing[#missing + 1] = entry
            seen[entry] = true
          end
        end
      end
    end
  end
  table.sort(missing)
  return missing
end

return M
