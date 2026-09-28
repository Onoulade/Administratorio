"""Export the built-in ImageGen multisign atlas without repainting its art.

The master is a true RGBA 2x2 atlas in north/east/south/west order. All
facings use one scale and align their circular hub to the entity center.
Premultiplied-alpha resampling avoids dark fringes on Factorio terrain.
"""
from pathlib import Path
import json
from PIL import Image

HERE = Path(__file__).resolve().parent
OUTPUT = HERE.parents[1] / 'graphics/entities/personnel-routing'
SOURCE = Image.open(HERE / 'multisign-master.png').convert('RGBA')
assert SOURCE.getchannel('A').getextrema() == (0, 255), 'Master must have real transparency'
W, H = SOURCE.size
REGIONS = {
    'north': ((0, 0, W//2, H//2), (379, 269)),
    'east': ((W//2, 0, W, H//2), (343, 269)),
    'south': ((0, H//2, W//2, H), (385, 243)),
    'west': ((W//2, H//2, W, H), (361, 254)),
}
SCALE = 0.23
metadata = {}
for name, (region, hub) in REGIONS.items():
    quadrant = SOURCE.crop(region)
    bounds = quadrant.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
    assert bounds
    x0, y0, x1, y1 = bounds
    bounds = (max(0, x0-2), max(0, y0-2), min(quadrant.width, x1+2), min(quadrant.height, y1+2))
    source = quadrant.crop(bounds)
    size = (round(source.width*SCALE), round(source.height*SCALE))
    reduced = source.convert('RGBa').resize(size, Image.Resampling.LANCZOS).convert('RGBA')
    position = (round(80-(hub[0]-bounds[0])*SCALE), round(80-(hub[1]-bounds[1])*SCALE))
    assert position[0] >= 0 and position[1] >= 0
    assert position[0]+size[0] < 160 and position[1]+size[1] < 160
    canvas = Image.new('RGBA', (160, 160))
    canvas.alpha_composite(reduced, position)
    canvas.save(OUTPUT / f'multisign-{name}.png')
    assert canvas.getchannel('A').getextrema() == (0, 255)
    metadata[name] = {'filename': f'multisign-{name}.png', 'width': 160, 'height': 160,
                      'scale': 0.6, 'shift': [0, 0], 'visible_bounds': canvas.getchannel('A').getbbox()}
    if name == 'north':
        icon_source = canvas.crop(canvas.getchannel('A').getbbox())
        ratio = min(60/icon_source.width, 60/icon_source.height)
        icon_sprite = icon_source.convert('RGBa').resize((round(icon_source.width*ratio), round(icon_source.height*ratio)), Image.Resampling.LANCZOS).convert('RGBA')
        icon = Image.new('RGBA', (64, 64))
        icon.alpha_composite(icon_sprite, ((64-icon_sprite.width)//2, (64-icon_sprite.height)//2))
        icon.save(OUTPUT / 'multisign-icon.png')
(HERE / 'multisign-sprites.json').write_text(json.dumps(metadata, indent=2)+'\n')
print('Exported four transparent 160x160 HR multisigns and 64x64 icon')
