"""Inspect sprite metadata and build an offline scale viewer; never modify pixels."""
import json
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
export_path = ROOT / 'graphics/entities/reworked-base/game-size/sprites.json'
exports = json.loads(export_path.read_text())['assets'] if export_path.exists() else {}
records = {}
for path in sorted(HERE.glob('prompts*.json')):
    data = json.loads(path.read_text())
    for job in data.get('jobs', []) if isinstance(data, dict) else data:
        records[job['name']] = job

assets = []
for name, job in sorted(records.items(), key=lambda pair: (pair[1]['footprint'][0], pair[0])):
    output = ROOT / 'graphics/entities/reworked-base' / f'{name}.png'
    if not output.exists():
        raise RuntimeError(f'Missing master: {name}')
    with Image.open(output) as im:
        assert im.mode == 'RGBA', (name, im.mode)
        alpha = im.getchannel('A')
        assert alpha.getextrema() == (0, 255), name
        bbox = alpha.point(lambda v: 255 if v >= 128 else 0).getbbox()
        assert bbox and bbox[0] > 0 and bbox[1] > 0 and bbox[2] < im.width and bbox[3] < im.height, (name, 'clipped silhouette', bbox)
        size = list(im.size)
        transparent_fraction = alpha.histogram()[0] / (im.width * im.height)
    with Image.open(ROOT / job['source']) as old:
        frame = [180, 185] if name == 'corporate-breakroom' else list(old.size)
    revision_file = HERE / f'{name}-framing.json'
    revision = json.loads(revision_file.read_text()) if revision_file.exists() else None
    assets.append({
        'name': name, 'footprint_tiles': job['footprint'],
        'intended_height_m': job['height'], 'master': str(output.relative_to(ROOT)),
        'size_px': size, 'opaque_bounds_px': list(bbox),
        'fully_transparent_fraction': round(transparent_fraction, 4),
        'original': job['source'], 'original_frame_px': frame,
        'preview_scale_at_32px_per_tile': round(job['footprint'][0] * 32 / (bbox[2] - bbox[0]), 6),
        'prompt': job['prompt'], 'framing_revision': revision,
        'game_size': exports.get(name),
    })
assert len(assets) == 20, len(assets)
manifest = {'generator': 'built-in image_gen', 'status': 'base animation masters; not wired into runtime',
            'scale_note': 'Tile footprints from entity prototypes. Heights are art-direction targets, not measured 3D geometry. Preview normalizes silhouette width to footprint width; final runtime ground anchors need placement QA.',
            'assets': assets}
(HERE / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
template = (HERE / 'preview-template.html').read_text()
(HERE / 'index.html').write_text(template.replace('__ASSETS__', json.dumps(assets)))
print(f'Validated {len(assets)} RGBA masters: nonempty alpha, transparent backgrounds, no opaque silhouette touching canvas edges.')
print('Built manifest.json and index.html. No pixels changed.')
