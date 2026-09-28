"""Export the transparent four-direction sign atlas as native HR sprites.

The built-in imagegen background-extraction edit used the user attachment
'ChatGPT Image Sep 28, 2026 at 01_42_33 PM.png'. Final edit prompt:
BACKGROUND REMOVAL ONLY. Return transparent PNG with true alpha channel.
Keep original four sign sprites exactly unchanged, do not redraw the signs.
Erase the ENTIRE brown and black photographic background and all glow so
 every pixel outside the objects is alpha=0, fully transparent. No gradient,
backdrop, checkerboard, solid color, shadows outside sprites or floor.
The required output is a transparent cutout sprite atlas for a video game,
showing only the four existing industrial sign objects with UP RIGHT LEFT
DOWN cream arrows. Same positions, proportions and rusty blue/bronze metal
textures as the original.

This export only crops, aligns and resamples that generated RGBA atlas.
Premultiplied resampling prevents hidden backdrop RGB bleeding at edges.
"""
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
OUTPUT=ROOT/'graphics/entities/personnel-routing'
ATLAS=Image.open(Path(__file__).with_name('signs-cutout.png')).convert('RGBA')
W,H=ATLAS.size
assert ATLAS.getchannel('A').getextrema()[0]==0, 'Atlas must be transparent'
REGIONS={'north':(0,0,W//2,H//2),'east':(W//2,0,W,H//2),
         'west':(0,H//2,W//2,H),'south':(W//2,H//2,W,H)}
for name,box in REGIONS.items():
    quadrant=ATLAS.crop(box)
    bounds=quadrant.getchannel('A').point(lambda a:255 if a>8 else 0).getbbox()
    assert bounds
    x0,y0,x1,y1=bounds
    source=quadrant.crop((max(0,x0-2),max(0,y0-2),min(quadrant.width,x1+2),min(quadrant.height,y1+2)))
    height=240
    width=round(source.width*height/source.height)
    resized=source.convert('RGBa').resize((width,height),Image.Resampling.LANCZOS).convert('RGBA')
    canvas=Image.new('RGBA',(160,256))
    assert width<=152, 'Sprite would clip the side fittings'
    canvas.alpha_composite(resized,((160-width)//2,8))
    canvas.save(OUTPUT/f'sign-{name}.png')
    if name=='north':
        face=source.crop((0,0,source.width,round(source.height*.48)))
        scale=min(60/face.width,60/face.height)
        face=face.convert('RGBa').resize((round(face.width*scale),round(face.height*scale)),Image.Resampling.LANCZOS).convert('RGBA')
        icon=Image.new('RGBA',(64,64))
        icon.alpha_composite(face,((64-face.width)//2,(64-face.height)//2))
        icon.save(OUTPUT/'sign-icon.png')
print('Exported four transparent 160x256 HR signs and 64x64 icon')
