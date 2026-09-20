# Custom building base stills

Twenty transparent PNG animation masters were regenerated with the built-in
imagegen tool, using the existing artwork as structural references. The PNGs
are in `graphics/entities/reworked-base/`. Open `index.html` for an offline
old/new comparison at a shared tile scale. The slider includes 32 px/tile.

## Game-size exports

`graphics/entities/reworked-base/game-size/` contains the 20 downscaled PNGs
at **32 pixels per tile**, with a 2-pixel transparent border on each side.
Thus a 2×2 machine has 64 pixels of artwork width in a 68-pixel canvas; a
7×7 building has 224 pixels of artwork width in a 228-pixel canvas. Heights
preserve the generated proportions rather than being forced to square.
The original high-resolution masters remain untouched.

The `game-size/hr/` folder contains matching 64-pixels-per-tile textures for
use with Factorio sprite `scale = 0.5`; the standard exports use `scale = 1`.
`game-size/sprites.json` records each exact frame size and scale. Both variants
have the same intended in-game width. Near-invisible outer generation specks
are excluded from cropping, and reduction uses premultiplied alpha with
Lanczos filtering. These exports are not yet installed as live entity sprites.

The comparison page now opens at 32 px/tile using the actual downscaled PNGs.
To re-export after editing the masters, run `export_game_size.py` followed by
`build_preview.py`, both in this directory.

The small 1×1 terminals and 2×2 presses have fewer competing mechanical parts.
The 3×3 planetary machines retain their dominant functional modules. The 5×5
facilities and 7×7 institutional buildings have architectural subdivision,
service access, and more deliberate detail placement. The 9×9 administration
platform retains its central waiting area. Materials, major silhouettes and
functional identities follow the original designs.

## Scope and integration

This delivery contains **base stills only**, ready for subsequent animation.
Existing entity prototypes, live sprites, animation sheets, shadows, emission
layers, icons and animation definitions have not been replaced. The new masters
have different geometry and canvas dimensions, so they are not drop-in frames
for the old animation sheets. Keeping them separate avoids mixing misaligned
old overlays with the new artwork.

For integration, establish the ground-footprint anchor for each master, then
choose its in-game scale and upward shift together. Separate roof and floor
layers for the walk-through biter facilities, rebuild matching shadows, and
remap animation regions. Existing `Internal/animations/*.json` coordinates
refer to the old artwork and must not be applied unchanged. Do not scale every
full canvas to the same dimensions: transparent padding differs.

`manifest.json` contains source paths, actual PNG dimensions and opaque bounds,
prototype footprints, target heights, the generation prompts, framing revisions,
and approximate width-normalized preview scale. Heights are art-direction
targets, not measured 3D geometry. The preview is for comparing art readability;
it does not establish exact runtime collision or fluid-connection alignment.

Credited third-party buildings (including the Office Desk, Greenhouse,
Resolution Office, Propaganda Distillery, AI Server, Slop Refinery, Synthetic
Personnel Bureau, Interplanetary Terminus and Relocation Receiver) are outside
this custom-art pass. Vanilla-derived entities are also outside this pass.

## Verification

All outputs were visually inspected. Seven received additional framing passes
to restore room around tall fittings or remove a detached speck. The metadata
check validates all 20 PNGs as RGBA with fully transparent background pixels,
opaque content, and no majority-opaque silhouette touching the canvas edge.
Some fine colored edge pixels remain visible at extreme enlargement; final
sprite reduction and in-game placement should be checked during animation
integration.

Rebuild the read-only image audit and comparison page with:

```sh
python3 Internal/building-graphics-rework/build_preview.py
```

This script reads PNGs and writes JSON/HTML; it does not modify image pixels.
No runtime tests are needed for this source-art-only delivery.
