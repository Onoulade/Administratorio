-- Sign facings share the same aligned shadow artwork.
-- Multisign layers inherit the runtime artwork scale in personnel_routing.lua.
return {
  ["sign-north"] = {filename="__administratorio__/graphics/entities/personnel-routing/sign-shadow.png", width=180, height=63, scale=0.5, shift={0.8,0}, draw_as_shadow=true},
  ["sign-east"] = {filename="__administratorio__/graphics/entities/personnel-routing/sign-shadow.png", width=180, height=63, scale=0.5, shift={0.4,0}, draw_as_shadow=true},
  ["sign-south"] = {filename="__administratorio__/graphics/entities/personnel-routing/sign-shadow.png", width=180, height=63, scale=0.5, shift={0.8,0}, draw_as_shadow=true},
  ["sign-west"] = {filename="__administratorio__/graphics/entities/personnel-routing/sign-shadow.png", width=180, height=63, scale=0.5, shift={1.2,0}, draw_as_shadow=true},
  ["multisign-north"] = {filename="__administratorio__/graphics/entities/personnel-routing/multisign-north-shadow.png", width=117, height=75, scale=0.5, shift={0.1953125,-0.0703125}, draw_as_shadow=true},
  ["multisign-east"] = {filename="__administratorio__/graphics/entities/personnel-routing/multisign-east-shadow.png", width=88, height=94, scale=0.5, shift={0.421875,0.09375}, draw_as_shadow=true},
  ["multisign-south"] = {filename="__administratorio__/graphics/entities/personnel-routing/multisign-south-shadow.png", width=117, height=72, scale=0.5, shift={0.1953125,0.265625}, draw_as_shadow=true},
  ["multisign-west"] = {filename="__administratorio__/graphics/entities/personnel-routing/multisign-west-shadow.png", width=85, height=94, scale=0.5, shift={-0.0703125,0.09375}, draw_as_shadow=true},
  ["input-north"] = {filename="__administratorio__/graphics/entities/personnel-routing/input-north-shadow.png", width=232, height=151, scale=0.5, shift={0.6875,-0.1171875}, draw_as_shadow=true},
  ["input-east"] = {filename="__administratorio__/graphics/entities/personnel-routing/input-east-shadow.png", width=212, height=139, scale=0.5, shift={0.515625,-0.0234375}, draw_as_shadow=true},
  ["input-south"] = {filename="__administratorio__/graphics/entities/personnel-routing/input-south-shadow.png", width=227, height=139, scale=0.5, shift={0.6484375,-0.0234375}, draw_as_shadow=true},
  ["input-west"] = {filename="__administratorio__/graphics/entities/personnel-routing/input-west-shadow.png", width=218, height=139, scale=0.5, shift={0.5625,0.0078125}, draw_as_shadow=true},
  ["output"] = {filename="__administratorio__/graphics/entities/personnel-routing/output-shadow.png", width=214, height=145, scale=0.5, shift={0.484375,-0.0859375}, draw_as_shadow=true},
}
