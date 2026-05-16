-- ADMINISTRATORIO: DATA UPDATES - REGISTER SPACE AGE RESOURCES TO PLANETS
-- Runs after base and space-age mods' data.lua but before data-final-fixes.lua
-- Directly injects administratorio resources into planet generation settings

local feature_flags = require("feature_flags")

if not feature_flags.space_age_enabled() then
  return
end

-- Inject amber-sap-seep into Gleba's map generation
local gleba = data.raw.planet["gleba"]
if gleba then
  gleba.map_gen_settings.autoplace_controls["gleba_amber_sap_seep"] = {}
  if not gleba.map_gen_settings.autoplace_settings.entity then
    gleba.map_gen_settings.autoplace_settings.entity = { settings = {} }
  end
  gleba.map_gen_settings.autoplace_settings.entity.settings["amber-sap-seep"] = {}
end

-- Inject verdigris-crust into Vulcanus' map generation
local vulcanus = data.raw.planet["vulcanus"]
if vulcanus then
  vulcanus.map_gen_settings.autoplace_controls["vulcanus_verdigris_crust"] = {}
  if not vulcanus.map_gen_settings.autoplace_settings.entity then
    vulcanus.map_gen_settings.autoplace_settings.entity = { settings = {} }
  end
  vulcanus.map_gen_settings.autoplace_settings.entity.settings["verdigris-crust"] = {}
end
