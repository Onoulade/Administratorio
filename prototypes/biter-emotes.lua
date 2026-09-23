local names = {
  "protesting",
  "waiting-slot",
  "to-field-office",
  "to-station",
  "working",
  "pacified-returning",
}

local sprites = {}
for _, name in ipairs(names) do
  sprites[#sprites + 1] = {
    type = "sprite",
    name = "administratorio-biter-emote-" .. name,
    filename = "__administratorio__/graphics/emotes/" .. name .. ".png",
    width = 64,
    height = 64,
  }
end

data:extend(sprites)
