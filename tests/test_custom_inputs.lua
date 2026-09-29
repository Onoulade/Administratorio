-- Linked controls must leave native actions available, including cursor rotation.
local inputs = {}
local env = setmetatable({
  data = {raw = {}, extend = function(_, prototypes)
    for _, prototype in ipairs(prototypes) do
      if prototype.type == "custom-input" then inputs[prototype.name] = prototype end
    end
  end},
  -- Isolate data.lua's registrations from unrelated prototype modules.
  require = function(name)
    if name == "feature_flags" then return {space_age_enabled = function() return false end} end
    if name == "prototypes.shared" then return {register_admin_recipe_prototypes = function() end} end
    return {}
  end,
}, {__index = _G})
assert(loadfile("data.lua", "t", env))()

assert(not inputs["administratorio-rotate-personnel-sign"], "multisign still intercepts native rotation")
assert(not inputs["administratorio-reverse-rotate-personnel-sign"], "multisign still intercepts native reverse rotation")
for name, input in pairs(inputs) do
  if input.linked_game_control then
    assert(input.consuming == nil or input.consuming == "none",
      "linked input blocks native game actions: " .. name)
  end
end
print("Custom inputs: linked rotation bindings preserve native game actions")
