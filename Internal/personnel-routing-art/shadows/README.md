# Personnel infrastructure cast shadows

All four regular-sign facings, four multisign facings, four deployment-office
facings and the fixed reception office have separate ImageGen shadow masks.
The original colored sprites and entity footprints are unchanged.

`selected-prompts.json` records the final prompts used with built-in imagegen.
The four `*-shadow-master.png` images are the selected transparent masters.
Reference sheets preserve the original sprites' ground origin and use vanilla
small-electric-pole and stone-furnace shadows as the lighting reference.

Run `python3 Internal/personnel-routing-art/shadows/export_shadows.py` from the
repository root to regenerate the 13 runtime PNGs, `sprites.json`,
`prototypes/shared/personnel_shadow_sprites.lua` and the registration preview.
The exporter splits the atlases, resamples their alpha masks, normalizes RGB to
black and applies measured registration offsets; it does not paint silhouettes.

The native `draw_as_shadow` layers use Factorio's opacity and fixed eastward
projection. Tall signs have long pole projections, offices have moderate casts,
and the flat multisign has a short outline close to its footprint. Both its
shadow scale and shadow shift inherit `MULTISIGN_SCALE`, preserving the current
20% enlargement and alignment with the three wire sockets.

`in-game-preview.png` shows all 13 facings beside vanilla pole/furnace references
in a disposable Factorio 2.0.77 scene. The first multisign has three attached
circuit wires. `registration-preview.png` provides a larger alignment view at
the source atlas scale, before the multisign's runtime enlargement.
