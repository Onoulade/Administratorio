"""Export the requested exact-size sprites, retaining untouched generation masters."""
import json
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
BASE = ROOT / 'graphics/entities/reworked-base'
OUT = BASE / 'game-size'
manifest = json.loads((HERE / 'manifest.json').read_text())
exports = {}

for asset in manifest['assets']:
    name = asset['name']
    with Image.open(ROOT / asset['master']) as source:
        assert source.mode == 'RGBA'
        visible = source.getchannel('A').point(lambda a: 255 if a >= 8 else 0).getbbox()
        # Ignore near-invisible generation specks in the outer canvas, retaining
        # two source pixels around the silhouette for its antialiased edge.
        bounds = (max(0, visible[0] - 2), max(0, visible[1] - 2),
                  min(source.width, visible[2] + 2), min(source.height, visible[3] + 2))
        # Uniform scaling preserves projected height; never force a square.
        cropped = source.crop(bounds)
        versions = {}
        for key, density, scale, padding, directory in [
            ('standard', 32, 1, 2, OUT),
            ('high_resolution', 64, 0.5, 4, OUT / 'hr'),
        ]:
            width = asset['footprint_tiles'][0] * density
            height = max(1, round(cropped.height * width / cropped.width))
            # Premultiplied alpha avoids blending hidden background colors
            # into translucent outline pixels during reduction.
            reduced = cropped.convert('RGBa').resize((width, height), Image.Resampling.LANCZOS).convert('RGBA')
            sprite = Image.new('RGBA', (width + 2 * padding, height + 2 * padding))
            sprite.paste(reduced, (padding, padding))
            directory.mkdir(parents=True, exist_ok=True)
            path = directory / f'{name}.png'
            sprite.save(path, optimize=True)
            with Image.open(path) as check:
                assert check.size == (width + 2 * padding, height + 2 * padding)
                assert check.mode == 'RGBA'
                bbox = check.getchannel('A').getbbox()
                assert bbox and bbox[0] >= padding and bbox[1] >= padding
                assert bbox[2] <= check.width - padding and bbox[3] <= check.height - padding
            versions[key] = {
                'file': str(path.relative_to(ROOT)), 'width': sprite.width,
                'height': sprite.height, 'scale': scale, 'frame_count': 1,
                'content_rect': [padding, padding, width + padding, height + padding],
                'pixels_per_tile': density,
            }
        exports[name] = {'source_crop': list(bounds), **versions}

assert len(exports) == 20
(OUT / 'sprites.json').write_text(json.dumps({
    'note': 'Standard sprites use scale=1; hr sprites use scale=0.5. Width follows prototype tile footprint, height preserves generated aspect ratio. Transparent border is 2 game pixels. Ground-anchor shifts and runtime installation are separate from this size export.',
    'assets': exports,
}, indent=2) + '\n')
print(f'Exported and verified {len(exports)} standard and {len(exports)} high-resolution sprites.')
for name, entry in exports.items():
    s = entry['standard']
    print(f"{name}: {s['width']} x {s['height']} px (including 2 px transparent border)")
