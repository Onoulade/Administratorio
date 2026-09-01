#!/usr/bin/env python3
"""
Administratorio Icon Generator
===============================
Generates distinct 64x64 paperwork icons from a base paper sheet image
by applying overlays, symbols, tints, stamps, and colored accents.

Usage:
    python generate_icons.py [--base PATH] [--output DIR] [--preview]
    python generate_icons.py --technology [--output graphics/technology]

Requirements:
    pip install Pillow

Parameters per icon (defined in ICON_DEFS below):
    base          - Base image: "paper", "form", "stack", "folder", "envelope"
    tint          - Overall RGBA tint applied to the paper body
    stripe        - Colored horizontal band: (color, position) where position is "top"/"bottom"
    stamp         - Circular stamp overlay: (color, position) e.g. ("red", "tr") for top-right
    symbol        - Drawn symbol: one of the SYMBOL_* constants
    symbol_color  - Color of the drawn symbol
    symbol_pos    - Position: "center", "br", "bl", "tr", "tl"
    corner_tab    - Colored corner fold: (color, corner) e.g. ("#ff0000", "tr")
    lines_color   - Color of fake text lines on the form (None = no lines)
    clip          - Draw a paper clip or staple at top
    watermark     - Faint background symbol
    badge         - Small colored circle badge with a letter
    header_bands  - One or more family colors split across the document header

Every item in a ``forms-*`` subgroup must have a dedicated entry in
``ICON_DEFS``.  The generator validates this contract before writing icons so
Space Age documents cannot silently fall back to unrelated layered artwork.
"""

import argparse
import math
import os
import re
import sys
from pathlib import Path

try:
    from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont
except ImportError:
    print("Error: Pillow is required. Install with: pip install Pillow")
    sys.exit(1)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
SIZE = 64
HALF = SIZE // 2
PAD = 3  # padding from edges (small = bigger icons)

# Symbol names
SYM_CHECKMARK = "checkmark"
SYM_CROSS = "cross"
SYM_GEAR = "gear"
SYM_PICKAXE = "pickaxe"
SYM_SHIELD = "shield"
SYM_STAR = "star"
SYM_TRAIN = "train"
SYM_FLASK = "flask"
SYM_HAMMER = "hammer"
SYM_SCALES = "scales"
SYM_LEAF = "leaf"
SYM_LIGHTNING = "lightning"
SYM_SPEECH = "speech"
SYM_HANDSHAKE = "handshake"
SYM_LOCK = "lock"
SYM_DOLLAR = "dollar"
SYM_EXCLAIM = "exclaim"
SYM_QUESTION = "question"
SYM_STAMP_CIRCLE = "stamp_circle"
SYM_ARROW_UP = "arrow_up"
SYM_ARROW_DOWN = "arrow_down"
SYM_MAGNIFIER = "magnifier"
SYM_PEN = "pen"
SYM_SCROLL = "scroll"
SYM_GAVEL = "gavel"
SYM_MEGAPHONE = "megaphone"
SYM_COFFEE = "coffee"
SYM_HARDHAT = "hardhat"
SYM_CHAIN = "chain"
SYM_CROWN = "crown"
SYM_BIOHAZARD = "biohazard"
SYM_TREE = "tree"
SYM_SMOKE = "smoke"
SYM_SOUND = "sound"
SYM_PERSON = "person"
SYM_WARNING = "warning"
SYM_ARCHIVE = "archive"
SYM_ASTEROID = "asteroid"
SYM_ATOM = "atom"
SYM_CIRCUIT = "circuit"
SYM_HEAT = "heat"
SYM_INK = "ink"
SYM_SEAL = "seal"
SYM_SNOWFLAKE = "snowflake"
SYM_VAULT = "vault"

# Colors (More saturated/distinct)
C_WHITE = (255, 255, 255, 255)
C_CREAM = (255, 235, 180, 255)
C_LIGHT_YELLOW = (255, 240, 150, 255)
C_LIGHT_BLUE = (180, 210, 255, 255)
C_LIGHT_GREEN = (180, 255, 190, 255)
C_LIGHT_RED = (255, 180, 180, 255)
C_LIGHT_PURPLE = (220, 180, 255, 255)
C_LIGHT_ORANGE = (255, 210, 140, 255)
C_LIGHT_PINK = (255, 180, 210, 255)
C_LIGHT_GRAY = (200, 200, 210, 255)
C_MANILA = (235, 205, 150, 255)
C_TAN = (210, 180, 140, 255)

# Stripe / accent colors (more saturated)
S_RED = (220, 40, 40, 230)
S_BLUE = (40, 100, 220, 230)
S_GREEN = (40, 180, 80, 230)
S_ORANGE = (240, 120, 20, 230)
S_PURPLE = (160, 50, 210, 230)
S_YELLOW = (230, 200, 20, 230)
S_TEAL = (20, 180, 180, 230)
S_BROWN = (130, 80, 40, 230)
S_PINK = (220, 60, 140, 230)
S_GRAY = (110, 110, 120, 230)
S_DARK_RED = (140, 20, 20, 240)
S_DARK_BLUE = (20, 40, 140, 240)
S_DARK_GREEN = (20, 90, 40, 240)
S_GOLD = (210, 160, 20, 230)
S_CYAN = (20, 190, 205, 235)
S_MAGENTA = (205, 45, 145, 235)

# Symbol colors (high contrast)
SC_RED = (180, 20, 20, 240)
SC_BLUE = (20, 40, 160, 240)
SC_GREEN = (20, 130, 40, 240)
SC_ORANGE = (200, 90, 10, 240)
SC_PURPLE = (120, 20, 160, 240)
SC_GRAY = (70, 70, 80, 220)
SC_DARK = (40, 35, 30, 240)
SC_TEAL = (10, 120, 120, 240)
SC_GOLD = (180, 140, 10, 240)
SC_BROWN = (100, 60, 20, 240)
SC_PINK = (180, 30, 90, 240)
SC_BLACK = (10, 10, 10, 250)


def _load_lua_color_constants():
    """Import shared RGBA color constants from the Lua prototype tint map."""
    tint_path = Path(__file__).resolve().parents[1] / "prototypes" / "shared" / "icon_tints.lua"
    if not tint_path.exists():
        return

    source = tint_path.read_text(encoding="utf-8")
    colors_match = re.search(r"M\.colors\s*=\s*\{(?P<body>.*?)\n\}", source, re.S)
    if not colors_match:
        return

    for name, values in re.findall(r"([A-Z][A-Z0-9_]*)\s*=\s*\{([^{}]+)\}", colors_match.group("body")):
        channels = [int(value.strip()) for value in values.split(",")]
        if len(channels) == 4:
            globals()[name] = tuple(channels)

_load_lua_color_constants()


# ---------------------------------------------------------------------------
# Base image generators (procedural - no external file needed)
# Each returns (img, geometry) where geometry is a dict with:
#   "corners": [TL, TR, BR, BL] of the top sheet (for tilted overlays)
#   "tilted": bool (whether stripes should follow the tilt)
#   "bbox": (x0, y0, x1, y1) axis-aligned bounding box of the main body
#
# All coordinates are expressed as fractions of SIZE so they scale with
# supersampling. Helper _s(frac) converts to pixel coords.
# ---------------------------------------------------------------------------

def _s(frac):
    """Convert a 0..1 fraction to a pixel coordinate in current SIZE."""
    return int(frac * SIZE)

def _sp(x_frac, y_frac):
    """Convert fractional (x, y) to pixel tuple."""
    return (_s(x_frac), _s(y_frac))

# Paper corners as fractions (slightly tilted)
_P_TL = (0.078, 0.016)
_P_TR = (0.953, 0.078)
_P_BR = (0.922, 0.984)
_P_BL = (0.047, 0.922)

def _paper_corners():
    return [_sp(*_P_TL), _sp(*_P_TR), _sp(*_P_BR), _sp(*_P_BL)]

def _lerp(p1, p2, t):
    """Linear interpolation between two points."""
    return (p1[0] + (p2[0] - p1[0]) * t, p1[1] + (p2[1] - p1[1]) * t)


def make_base_paper(tint=C_CREAM):
    """Single sheet of paper, slightly angled."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    pts = _paper_corners()
    sh = max(1, _s(0.03))
    shadow = [(p[0] + sh, p[1] + sh) for p in pts]
    draw.polygon(shadow, fill=(0, 0, 0, 35))
    draw.polygon(pts, fill=tint, outline=(180, 170, 155, 200))
    geo = {"corners": pts, "tilted": True, "bbox": (_s(0.05), _s(0.02), _s(0.95), _s(0.98))}
    return img, geo


def make_base_form(tint=C_WHITE):
    """Formal form - rectangular, straight, with header area."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    x0, y0, x1, y1 = _s(0.06), _s(0.03), _s(0.92), _s(0.95)
    r = max(1, _s(0.03))
    sh = max(1, _s(0.03))
    draw.rounded_rectangle([(x0 + sh, y0 + sh), (x1 + sh, y1 + sh)], radius=r, fill=(0, 0, 0, 40))
    draw.rounded_rectangle([(x0, y0), (x1, y1)], radius=r, fill=tint, outline=(170, 165, 155, 200))
    corners = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    geo = {"corners": corners, "tilted": False, "bbox": (x0, y0, x1, y1)}
    return img, geo


def make_base_stack(tint=C_CREAM):
    """Stack of 2-3 papers."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    pts = _paper_corners()
    tl, tr, br, bl = pts
    off1, off2 = max(1, _s(0.09)), max(1, _s(0.05))
    # Bottom sheet
    pts3 = [(tl[0] + off1, tl[1] + off1), (tr[0] + off2, tr[1] + off1),
            (br[0] + off2, br[1] + 1), (bl[0] + off1, bl[1] + 1)]
    draw.polygon(pts3, fill=_dim(tint, 0.82), outline=(170, 165, 155, 140))
    # Middle sheet
    off3, off4 = max(1, _s(0.05)), max(1, _s(0.02))
    pts2 = [(tl[0] + off3, tl[1] + off3), (tr[0] + off4, tr[1] + off3),
            (br[0] + off4, br[1] + 1), (bl[0] + off3, bl[1] + 1)]
    draw.polygon(pts2, fill=_dim(tint, 0.91), outline=(175, 168, 155, 165))
    # Top sheet
    draw.polygon(pts, fill=tint, outline=(180, 172, 158, 200))
    geo = {"corners": pts, "tilted": True, "bbox": (_s(0.05), _s(0.02), _s(0.95), _s(0.98))}
    return img, geo


def make_base_folder(tint=C_MANILA):
    """Manila folder with paper sticking out."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Paper sticking out the top
    draw.polygon([_sp(0.19, 0.03), _sp(0.84, 0.03), _sp(0.81, 0.31), _sp(0.16, 0.31)],
                 fill=C_WHITE, outline=(180, 175, 165, 150))
    # Shadow
    sh = max(1, _s(0.03))
    folder_shadow = [_sp(0.08, 0.23), _sp(0.30, 0.23), _sp(0.33, 0.16), _sp(0.66, 0.16),
                     _sp(0.95, 0.23), _sp(0.94, 0.97), _sp(0.11, 0.97)]
    draw.polygon([(p[0]+sh, p[1]+sh) for p in folder_shadow], fill=(0, 0, 0, 30))
    # Folder body
    folder_pts = [_sp(0.05, 0.20), _sp(0.27, 0.20), _sp(0.30, 0.13), _sp(0.63, 0.13),
                  _sp(0.94, 0.20), _sp(0.91, 0.95), _sp(0.08, 0.95)]
    draw.polygon(folder_pts, fill=tint, outline=(170, 150, 120, 200))
    # A darker tab and front lip preserve the folder silhouette even when a
    # pale case tint is used.  Previously the body blended into the paper sheet
    # and the result looked like another loose document.
    lw = max(1, _s(0.03))
    folder_edge = _dim(tint, 0.70)
    draw.line([_sp(0.30, 0.13), _sp(0.63, 0.13)], fill=folder_edge, width=lw)
    draw.line([_sp(0.06, 0.31), _sp(0.92, 0.31)], fill=(*folder_edge[:3], 150), width=max(1, lw // 2))
    corners = [_sp(0.05, 0.20), _sp(0.94, 0.20), _sp(0.91, 0.95), _sp(0.08, 0.95)]
    geo = {"corners": corners, "tilted": False, "bbox": (_s(0.05), _s(0.13), _s(0.94), _s(0.95))}
    return img, geo


def make_base_envelope(tint=C_CREAM):
    """Sealed envelope."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    r = max(1, _s(0.05))
    sh = max(1, _s(0.03))
    # Shadow
    draw.rounded_rectangle([_sp(0.08, 0.19), _sp(0.95, 0.88)], radius=r, fill=(0, 0, 0, 35))
    # Body
    draw.rounded_rectangle([_sp(0.05, 0.16), _sp(0.94, 0.84)], radius=r, fill=tint, outline=(180, 170, 155, 200))
    # Flap (triangle)
    draw.polygon([_sp(0.05, 0.16), _sp(0.50, 0.53), _sp(0.94, 0.16)],
                 fill=_dim(tint, 0.88), outline=(180, 170, 155, 200))
    corners = [_sp(0.05, 0.16), _sp(0.94, 0.16), _sp(0.94, 0.84), _sp(0.05, 0.84)]
    geo = {"corners": corners, "tilted": False, "bbox": (_s(0.05), _s(0.16), _s(0.94), _s(0.84))}
    return img, geo


def make_base_ticket(tint=C_WHITE):
    """A narrow ticket/receipt strip."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    x0, y0, x1, y1 = _s(0.25), _s(0.05), _s(0.75), _s(0.95)
    sh = max(1, _s(0.02))
    draw.rectangle([(x0 + sh, y0 + sh), (x1 + sh, y1 + sh)], fill=(0, 0, 0, 40))
    draw.rectangle([(x0, y0), (x1, y1)], fill=tint, outline=(170, 165, 155, 200))
    # Jagged bottom
    jw = (x1 - x0) // 6
    for i in range(7):
        jx = x0 + i * jw
        draw.polygon([(jx, y1), (jx + jw // 2, y1 - _s(0.04)), (jx + jw, y1)], fill=(0, 0, 0, 0))

    corners = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    geo = {"corners": corners, "tilted": False, "bbox": (x0, y0, x1, y1)}
    return img, geo


def make_base_ledger(tint=C_WHITE):
    """A bound ledger or thick report."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    x0, y0, x1, y1 = _s(0.12), _s(0.08), _s(0.88), _s(0.92)
    sh = max(1, _s(0.03))
    # Shadow
    draw.rectangle([(x0 + sh, y0 + sh), (x1 + sh, y1 + sh)], fill=(0, 0, 0, 45))
    # Pages
    draw.rectangle([(x0 + _s(0.02), y0), (x1, y1)], fill=tint, outline=(170, 165, 155, 200))
    # Binding
    binding_w = _s(0.08)
    draw.rectangle([(x0, y0), (x0 + binding_w, y1)], fill=_dim(tint, 0.6), outline=(120, 110, 100, 200))
    for i in range(5):
        by = y0 + (y1 - y0) * (i + 1) / 6
        draw.line([(x0, by), (x0 + binding_w, by)], fill=(0, 0, 0, 60), width=max(1, _s(0.01)))

    corners = [(x0 + binding_w, y0), (x1, y0), (x1, y1), (x0 + binding_w, y1)]
    geo = {"corners": corners, "tilted": False, "bbox": (x0, y0, x1, y1)}
    return img, geo


def make_base_flask(tint=C_LIGHT_BLUE):
    """A science pack flask shape."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Coordinates for a flask
    # Neck: 0.4 to 0.6 width, top 0.1 to 0.3
    # Body: 0.2 to 0.8 width, 0.3 to 0.9
    
    sh = max(1, _s(0.03))
    # Shadow
    draw.polygon([_sp(0.35+0.03, 0.05+0.03), _sp(0.65+0.03, 0.05+0.03), 
                  _sp(0.65+0.03, 0.30+0.03), _sp(0.90+0.03, 0.85+0.03),
                  _sp(0.10+0.03, 0.85+0.03), _sp(0.35+0.03, 0.30+0.03)], fill=(0, 0, 0, 50))
    
    # Liquid (tinted part)
    draw.polygon([_sp(0.35, 0.45), _sp(0.65, 0.45), 
                  _sp(0.85, 0.82), _sp(0.15, 0.82)], fill=tint)
    
    # Glass Outline
    glass_pts = [_sp(0.35, 0.05), _sp(0.65, 0.05), _sp(0.65, 0.30), 
                 _sp(0.90, 0.85), _sp(0.10, 0.85), _sp(0.35, 0.30)]
    draw.polygon(glass_pts, outline=(200, 220, 255, 180), width=max(2, _s(0.02)))
    
    # Rim
    draw.line([_sp(0.32, 0.05), _sp(0.68, 0.05)], fill=(200, 220, 255, 200), width=max(2, _s(0.03)))
    
    # Shine
    draw.line([_sp(0.40, 0.15), _sp(0.40, 0.25)], fill=(255, 255, 255, 150), width=max(1, _s(0.01)))
    draw.arc([_sp(0.25, 0.50), _sp(0.45, 0.75)], 150, 210, fill=(255, 255, 255, 120), width=max(2, _s(0.02)))

    geo = {"corners": [_sp(0.1, 0.05), _sp(0.9, 0.05), _sp(0.9, 0.85), _sp(0.1, 0.85)], "tilted": False, "bbox": (_s(0.1), _s(0.05), _s(0.9), _s(0.85))}
    return img, geo


BASE_GENERATORS = {
    "paper": make_base_paper,
    "form": make_base_form,
    "stack": make_base_stack,
    "folder": make_base_folder,
    "envelope": make_base_envelope,
    "ticket": make_base_ticket,
    "ledger": make_base_ledger,
    "flask": make_base_flask,
}


# ---------------------------------------------------------------------------
# Drawing helpers
# ---------------------------------------------------------------------------

def _dim(color, factor):
    """Dim/brighten a color by a factor."""
    return tuple(max(0, min(255, int(c * factor))) for c in color[:3]) + (color[3],)


def apply_material_finish(img, geo):
    """Give every document a warm, lightly worn, dimensional finish.

    The generator works at a larger resolution and downsamples at the end, so
    a restrained amount of grain and edge work survives as material rather than
    visual noise.  Keeping this pass shared is important: paper, folders,
    ledgers, and tickets should feel manufactured by the same bureaucracy.
    """
    pixels = img.load()
    width, height = img.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a < 70:
                continue
            diagonal_light = 1.055 - 0.105 * ((x + y) / max(1, width + height - 2))
            paper_grain = 0.014 * math.sin(x * 0.23 + y * 0.11)
            paper_grain += 0.010 * math.sin(x * 0.07 - y * 0.19)
            # A deterministic hash-like term breaks up the overly regular
            # sine pattern without introducing a random, non-reproducible build.
            paper_grain += 0.008 * math.sin((x * 12.9898 + y * 78.233) * 0.17)
            factor = diagonal_light + paper_grain
            pixels[x, y] = (
                max(0, min(255, int(r * factor))),
                max(0, min(255, int(g * factor))),
                max(0, min(255, int(b * factor))),
                a,
            )

    # Add a few long, translucent fibers.  They are deliberately sparse and
    # clipped to the existing silhouette so the marks read as paper texture,
    # not as a generic crosshatch overlay.
    texture = Image.new("RGBA", img.size, (0, 0, 0, 0))
    texture_draw = ImageDraw.Draw(texture)
    fiber_count = max(8, SIZE // 14)
    for i in range(fiber_count):
        x = int((i * 47 + 11) % max(1, width - 8))
        y = int((i * 71 + 17) % max(1, height - 8))
        length = int(SIZE * (0.16 + (i % 5) * 0.035))
        color = (255, 255, 255, 15) if i % 3 else (92, 73, 54, 10)
        texture_draw.line([(x, y), (min(width - 1, x + length), y + (i % 3) - 1)],
                          fill=color, width=max(1, SIZE // 192))
    texture.putalpha(ImageChops.multiply(texture.getchannel("A"), img.getchannel("A")))
    img.alpha_composite(texture)

    # A shared bevel makes stacks, ledgers, blanks, and permits feel like one set.
    draw = ImageDraw.Draw(img)
    tl, tr, br, bl = geo["corners"]
    edge = max(1, SIZE // 96)
    draw.line([tl, tr], fill=(255, 250, 225, 150), width=edge)
    draw.line([tl, bl], fill=(255, 248, 220, 105), width=edge)
    draw.line([tr, br], fill=(75, 60, 48, 105), width=edge)
    draw.line([bl, br], fill=(65, 52, 42, 125), width=edge)

    # The lower/right edge gets a soft secondary rim at high resolution.  It
    # produces a readable bevel after downsampling without a cartoon outline.
    rim = Image.new("RGBA", img.size, (0, 0, 0, 0))
    rim_draw = ImageDraw.Draw(rim)
    rim_draw.line([tr, br], fill=(48, 38, 30, 55), width=max(1, SIZE // 48))
    rim_draw.line([bl, br], fill=(48, 38, 30, 65), width=max(1, SIZE // 48))
    rim = rim.filter(ImageFilter.GaussianBlur(max(1, SIZE // 128)))
    rim.putalpha(ImageChops.multiply(rim.getchannel("A"), img.getchannel("A")))
    img.alpha_composite(rim)


def _pos_offset(pos, symbol_size=16):
    """Get (x, y) center for a named position."""
    hs = symbol_size // 2
    positions = {
        "center": (HALF, HALF),
        "tr": (SIZE - PAD - hs, PAD + hs),
        "tl": (PAD + hs, PAD + hs),
        "br": (SIZE - PAD - hs, SIZE - PAD - hs),
        "bl": (PAD + hs, SIZE - PAD - hs),
        "tc": (HALF, PAD + hs + 2),
        "bc": (HALF, SIZE - PAD - hs),
        "cr": (SIZE - PAD - hs, HALF),
        "cl": (PAD + hs, HALF),
    }
    return positions.get(pos, positions["center"])


def _shift_mask(mask, dx, dy):
    """Translate an L-mode mask without wrapping at the canvas edge."""
    shifted = Image.new("L", mask.size, 0)
    shifted.paste(mask, (int(dx), int(dy)))
    return shifted


def draw_stripe(img, color, position="top", thickness=7, geo=None):
    """Draw a colored stripe that follows the paper geometry."""
    draw = ImageDraw.Draw(img)
    corners = geo["corners"] if geo else [(4, 2), (59, 2), (59, 61), (4, 61)]
    tl, tr, br, bl = corners

    if position == "top":
        # Stripe along the top edge, inset by thickness
        t = thickness / max(1, ((bl[1] - tl[1]) + (br[1] - tr[1])) / 2)
        p0 = tl
        p1 = tr
        p2 = _lerp(tr, br, t)
        p3 = _lerp(tl, bl, t)
        draw.polygon([p0, p1, p2, p3], fill=color)
        draw.line([p0, p1], fill=(*color[:3], min(255, color[3] + 20)), width=max(1, SIZE // 96))
        draw.line([p3, p2], fill=(*_dim(color, 0.62)[:3], min(255, color[3] + 10)), width=max(1, SIZE // 96))
    elif position == "bottom":
        t = thickness / max(1, ((bl[1] - tl[1]) + (br[1] - tr[1])) / 2)
        p0 = _lerp(tl, bl, 1 - t)
        p1 = _lerp(tr, br, 1 - t)
        p2 = br
        p3 = bl
        draw.polygon([p0, p1, p2, p3], fill=color)
        draw.line([p0, p1], fill=(*_dim(color, 0.62)[:3], min(255, color[3] + 10)), width=max(1, SIZE // 96))
        draw.line([p3, p2], fill=(*color[:3], min(255, color[3] + 20)), width=max(1, SIZE // 96))
    elif position == "left":
        t = thickness / max(1, ((tr[0] - tl[0]) + (br[0] - bl[0])) / 2)
        p0 = tl
        p1 = _lerp(tl, tr, t)
        p2 = _lerp(bl, br, t)
        p3 = bl
        draw.polygon([p0, p1, p2, p3], fill=color)
        draw.line([p0, p3], fill=(*color[:3], min(255, color[3] + 20)), width=max(1, SIZE // 96))
        draw.line([p1, p2], fill=(*_dim(color, 0.62)[:3], min(255, color[3] + 10)), width=max(1, SIZE // 96))
    elif position == "right":
        t = thickness / max(1, ((tr[0] - tl[0]) + (br[0] - bl[0])) / 2)
        p0 = _lerp(tl, tr, 1 - t)
        p1 = tr
        p2 = br
        p3 = _lerp(bl, br, 1 - t)
        draw.polygon([p0, p1, p2, p3], fill=color)
        draw.line([p0, p3], fill=(*_dim(color, 0.62)[:3], min(255, color[3] + 10)), width=max(1, SIZE // 96))
        draw.line([p1, p2], fill=(*color[:3], min(255, color[3] + 20)), width=max(1, SIZE // 96))


def draw_header_bands(img, colors, thickness=7, geo=None):
    """Split the top document band into stable family-color segments."""
    if not colors:
        return
    draw = ImageDraw.Draw(img)
    corners = geo["corners"] if geo else [(4, 2), (59, 2), (59, 61), (4, 61)]
    tl, tr, br, bl = corners
    vertical_span = ((bl[1] - tl[1]) + (br[1] - tr[1])) / 2
    t = thickness / max(1, vertical_span)
    lower_left = _lerp(tl, bl, t)
    lower_right = _lerp(tr, br, t)

    count = len(colors)
    for index, color in enumerate(colors):
        start = index / count
        end = (index + 1) / count
        pts = [
            _lerp(tl, tr, start),
            _lerp(tl, tr, end),
            _lerp(lower_left, lower_right, end),
            _lerp(lower_left, lower_right, start),
        ]
        draw.polygon(pts, fill=color)
        if index:
            draw.line([pts[0], pts[3]], fill=(45, 38, 34, 150), width=max(1, SIZE // 128))
        draw.line([pts[0], pts[1]], fill=(*color[:3], min(255, color[3] + 18)), width=max(1, SIZE // 128))
        draw.line([pts[3], pts[2]], fill=(*_dim(color, 0.62)[:3], min(255, color[3] + 12)), width=max(1, SIZE // 128))


def draw_lines(img, color=(180, 175, 165, 120), count=5, geo=None):
    """Draw fake text lines that follow the paper geometry."""
    draw = ImageDraw.Draw(img)
    corners = geo["corners"] if geo else [(4, 2), (59, 2), (59, 61), (4, 61)]
    tl, tr, br, bl = corners

    # Inset the lines area
    inset_x = 0.12
    inset_top = 0.25  # leave room for stripe
    inset_bot = 0.12

    for i in range(count):
        t = inset_top + (1 - inset_top - inset_bot) * (i + 1) / (count + 1)
        left = _lerp(tl, bl, t)
        right = _lerp(tr, br, t)
        # Inset horizontally
        start = _lerp(left, right, inset_x)
        # Vary line length
        length_pct = 0.55 + (i % 3) * 0.15
        end = _lerp(left, right, inset_x + (1 - 2 * inset_x) * length_pct)
        draw.line([start, end], fill=color, width=max(1, SIZE // 64))


def draw_stamp(img, color, pos="tr", radius=9):
    """Draw a circular stamp mark."""
    draw = ImageDraw.Draw(img)
    cx, cy = _pos_offset(pos, radius * 2)
    sw = max(2, radius // 4)
    
    # Ink bleed and a tiny southeast impression shadow keep stamps on the paper.
    bleed = max(1, radius // 7)
    draw.ellipse([(cx - radius + bleed, cy - radius + bleed),
                  (cx + radius + bleed, cy + radius + bleed)],
                 outline=(35, 28, 24, 80), width=sw)

    # Outer ring
    draw.ellipse([(cx - radius, cy - radius), (cx + radius, cy + radius)],
                 outline=color, width=sw)
    # Inner smaller circle
    r2 = radius - sw * 2
    if r2 > 2:
        draw.ellipse([(cx - r2, cy - r2), (cx + r2, cy + r2)],
                     outline=(*color[:3], color[3] // 2), width=max(1, sw // 2))

    # Small broken segments make the mark feel inked onto a rough surface,
    # instead of a perfect vector circle.  The pattern is fixed for stable PNGs.
    for start, end in ((18, 46), (112, 142), (205, 232), (286, 316)):
        draw.arc([(cx - radius, cy - radius), (cx + radius, cy + radius)],
                 start, end, fill=(*color[:3], max(35, color[3] // 3)), width=max(1, sw // 2))


def draw_corner_tab(img, color, corner="tr", tab_size=14, geo=None):
    """Draw a colored corner fold/tab following paper geometry."""
    draw = ImageDraw.Draw(img)
    corners = geo["corners"] if geo else [(4, 2), (59, 2), (59, 61), (4, 61)]
    tl, tr, br, bl = corners
    t = tab_size / SIZE
    if corner == "tr":
        pts = [_lerp(tr, tl, t), tr, _lerp(tr, br, t)]
    elif corner == "tl":
        pts = [tl, _lerp(tl, tr, t), _lerp(tl, bl, t)]
    elif corner == "br":
        pts = [_lerp(br, bl, t), br, _lerp(br, tr, t)]
    elif corner == "bl":
        pts = [bl, _lerp(bl, br, t), _lerp(bl, tl, t)]
    
    # Muted edge instead of a sticker-like white halo.
    draw.polygon(pts, outline=(55, 45, 38, 190), width=max(1, SIZE // 48))
    draw.polygon(pts, fill=color)


def draw_clip(img, color=(150, 150, 160, 200)):
    """Draw a paper clip at the top."""
    draw = ImageDraw.Draw(img)
    cx = HALF
    s = max(1, SIZE // 64)  # scale factor
    # A dark offset and a narrow highlight give the clip a metal edge without
    # the old sticker-like white halo.
    draw.rounded_rectangle([(cx - 4*s + s, 1*s + s), (cx + 4*s + s, 18*s + s)], radius=3*s,
                           outline=(35, 30, 28, 120), width=2*s)
    draw.rounded_rectangle([(cx - 4*s, 1*s), (cx + 4*s, 18*s)], radius=3*s,
                           outline=color, width=2*s)
    draw.rounded_rectangle([(cx - 2*s, 4*s), (cx + 2*s, 14*s)], radius=2*s,
                           outline=color, width=1*s)
    draw.line([(cx - 2*s, 2*s), (cx + 2*s, 2*s)], fill=(245, 248, 255, 170), width=max(1, s))


def draw_hole_punches(img, count=2, geo=None):
    """Draw hole punches along the left edge."""
    draw = ImageDraw.Draw(img)
    corners = geo["corners"] if geo else [(4, 2), (59, 2), (59, 61), (4, 61)]
    tl, tr, br, bl = corners
    r = _s(0.03)
    for i in range(count):
        t = (i + 1) / (count + 1)
        pos = _lerp(tl, bl, t)
        # Offset slightly into the paper
        p = (pos[0] + _s(0.04), pos[1])
        # Punches are holes with a paper rim, not black screws pasted on top.
        draw.ellipse([(p[0] - r - 1, p[1] - r - 1), (p[0] + r + 1, p[1] + r + 1)],
                     fill=(241, 237, 225, 210), outline=(95, 82, 70, 150), width=max(1, SIZE // 128))
        draw.ellipse([(p[0] - r, p[1] - r), (p[0] + r, p[1] + r)], fill=(35, 31, 29, 205))
        draw.arc([(p[0] - r, p[1] - r), (p[0] + r, p[1] + r)], 200, 330,
                 fill=(255, 255, 255, 135), width=max(1, SIZE // 128))


def draw_post_it(img, color=(255, 255, 50, 255)):
    """Draw a small yellow post-it note in the bottom right corner."""
    draw = ImageDraw.Draw(img)
    x0, y0, x1, y1 = _s(0.60), _s(0.65), _s(0.92), _s(0.92)
    # Shadow
    sh = max(1, _s(0.01))
    draw.rectangle([(x0 + sh, y0 + sh), (x1 + sh, y1 + sh)], fill=(0, 0, 0, 80))
    # Note
    draw.rectangle([(x0, y0), (x1, y1)], fill=color, outline=(150, 130, 20, 235), width=max(1, _s(0.015)))
    # Folded lower-right corner and a top-edge highlight sell the note as a
    # second physical layer rather than a floating UI badge.
    fold = max(2, _s(0.07))
    draw.polygon([(x1 - fold, y1), (x1, y1 - fold), (x1, y1)], fill=_dim(color, 0.72))
    draw.line([(x0 + _s(0.02), y0 + _s(0.02)), (x1 - _s(0.03), y0 + _s(0.02))],
              fill=(255, 255, 220, 145), width=max(1, _s(0.01)))
    # Fake text on note
    for i in range(3):
        ly = y0 + (y1 - y0) * (i + 1) / 5
        draw.line([(x0 + _s(0.04), ly), (x1 - _s(0.04), ly)], fill=(0, 0, 0, 100), width=max(1, _s(0.01)))


def draw_badge(img, letter, bg_color, text_color=(255, 255, 255, 255), pos="bl", size_mult=1.0):
    """Draw a colored circle badge with a letter."""
    draw = ImageDraw.Draw(img)
    s = max(1, SIZE // 64)
    r = 7 * s * size_mult
    cx, cy = _pos_offset(pos, r * 2)
    
    # Black border for corner badges (thinner)
    bw = max(1, int(1.5 * s * size_mult))
    draw.ellipse([(cx - r - bw, cy - r - bw), (cx + r + bw, cy + r + bw)], fill=(0, 0, 0, 255))
    
    draw.ellipse([(cx - r, cy - r), (cx + r, cy + r)], fill=bg_color)
    draw.arc([(cx - r + bw, cy - r + bw), (cx + r - bw, cy + r - bw)], 195, 330,
             fill=(255, 255, 255, 100), width=max(1, bw))
    # Draw letter
    font_size = int(11 * s * size_mult)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
    except (OSError, IOError):
        font = ImageFont.load_default()
    bbox = draw.textbbox((0, 0), letter, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    
    # Clean black shadow
    draw.text((cx - tw // 2 + 1, cy - th // 2 - 1*s + 1), letter, fill=(0, 0, 0, 255), font=font)
    draw.text((cx - tw // 2, cy - th // 2 - 1*s), letter, fill=text_color, font=font)


# ---------------------------------------------------------------------------
# Symbol drawing functions
# ---------------------------------------------------------------------------

def _draw_symbol(draw, name, cx, cy, color, size=14):

    """Draw a named symbol centered at (cx, cy)."""
    hs = size // 2
    r = hs
    w = max(1, size // 7)  # line width scales with symbol size

    if name == SYM_CHECKMARK:
        pts = [(cx - hs, cy), (cx - hs // 3, cy + hs), (cx + hs, cy - hs)]
        draw.line(pts, fill=color, width=w)

    elif name == SYM_CROSS:
        draw.line([(cx - hs, cy - hs), (cx + hs, cy + hs)], fill=color, width=w)
        draw.line([(cx + hs, cy - hs), (cx - hs, cy + hs)], fill=color, width=w)

    elif name == SYM_GEAR:
        # A real stepped silhouette is much more legible than a circle with
        # eight radial spokes, especially when used as the tiny work-order cue.
        tooth = max(2, size // 8)
        gear_pts = []
        for index in range(32):
            angle = math.radians(index * 11.25 - 5.625)
            radius = r if index % 4 in (1, 2) else r - tooth
            gear_pts.append((cx + int(radius * math.cos(angle)),
                             cy + int(radius * math.sin(angle))))
        draw.polygon(gear_pts, fill=color, outline=color)
        hub = max(2, size // 5)
        draw.ellipse([(cx - hub, cy - hub), (cx + hub, cy + hub)],
                     fill=(*color[:3], 65), outline=color, width=max(1, w // 2))

    elif name == SYM_PICKAXE:
        handle_w = max(2, size // 8)
        head_x, head_y = cx + hs // 4, cy - hs // 3
        draw.line([(cx - hs // 2, cy + hs), (head_x, head_y)], fill=color, width=handle_w)
        # Two distinct pick points make this read as mining equipment rather
        # than a random slash or arrow.
        draw.line([(head_x, head_y), (cx + hs, cy - hs // 2)], fill=color, width=w + max(1, w // 2))
        draw.line([(head_x, head_y), (cx + hs // 3, cy - hs)], fill=color, width=w + max(1, w // 2))

    elif name == SYM_SHIELD:
        pts = [(cx, cy - hs), (cx + hs, cy - hs // 3), (cx + hs - w, cy + hs // 2),
               (cx, cy + hs), (cx - hs + w, cy + hs // 2), (cx - hs, cy - hs // 3)]
        draw.polygon(pts, fill=(*color[:3], 55), outline=color, width=w)
        draw.line([(cx - hs // 2, cy - hs // 5), (cx + hs // 2, cy - hs // 5)],
                  fill=color, width=max(1, w // 2))

    elif name == SYM_STAR:
        pts = []
        for i in range(10):
            angle = math.radians(i * 36 - 90)
            radius = r if i % 2 == 0 else r // 2
            pts.append((cx + int(radius * math.cos(angle)),
                        cy + int(radius * math.sin(angle))))
        draw.polygon(pts, fill=color)

    elif name == SYM_TRAIN:
        draw.rectangle([(cx - hs, cy - hs // 2), (cx + hs, cy + hs // 3)], outline=color, width=w)
        draw.rectangle([(cx - hs + w, cy - hs), (cx, cy - hs // 2)], fill=color)
        wr = max(2, size // 6)
        for wx in [cx - hs // 2, cx + hs // 2]:
            draw.ellipse([(wx - wr, cy + hs // 3), (wx + wr, cy + hs // 3 + wr * 2)], fill=color)

    elif name == SYM_FLASK:
        # Erlenmeyer flask: narrow neck, distinct shoulders, broad base, and
        # a visible liquid line.  The previous triangle lost the neck at 64px.
        neck = max(2, size // 8)
        shoulder_y = cy - hs // 4
        bottom_y = cy + hs
        flask = [
            (cx - neck, cy - hs), (cx + neck, cy - hs),
            (cx + neck, shoulder_y), (cx + hs * 3 // 4, cy + hs // 2),
            (cx + hs // 2, bottom_y), (cx - hs // 2, bottom_y),
            (cx - hs * 3 // 4, cy + hs // 2), (cx - neck, shoulder_y),
        ]
        draw.polygon(flask, fill=(*color[:3], 65), outline=color, width=w)
        draw.line([(cx - neck - w, cy - hs), (cx + neck + w, cy - hs)], fill=color, width=w)
        liquid_y = cy + hs // 3
        draw.line([(cx - hs * 2 // 3, liquid_y), (cx + hs * 2 // 3, liquid_y)],
                  fill=color, width=max(1, w // 2))
        draw.line([(cx - hs // 3, cy + hs * 3 // 5), (cx - hs // 5, cy + hs * 3 // 5)],
                  fill=(255, 250, 225, 100), width=max(1, w // 2))

    elif name == SYM_HAMMER:
        handle_w = max(2, size // 9)
        # Classic carpenter's hammer: an unmistakable horizontal head plus a
        # single diagonal handle.  Avoiding a claw keeps it readable at 16px.
        handle_top = (cx, cy - hs // 4)
        handle_bottom = (cx + hs // 3, cy + hs)
        draw.line([handle_top, handle_bottom], fill=color, width=handle_w)
        head_box = [(cx - hs, cy - hs // 2), (cx + hs // 2, cy - hs // 5)]
        draw.rounded_rectangle(head_box, radius=max(1, w), fill=color, outline=color)
        draw.line([(cx - hs + w, cy - hs // 2 + w), (cx + hs // 3, cy - hs // 2 + w)],
                  fill=(255, 250, 225, 85), width=max(1, w // 2))

    elif name == SYM_SCALES:
        beam_y = cy - hs // 4
        pan_y = cy + hs // 4
        draw.line([(cx, cy - hs), (cx, cy + hs // 2)], fill=color, width=w)
        draw.line([(cx - hs, beam_y), (cx + hs, beam_y)], fill=color, width=w)
        for side in (-1, 1):
            pan_x = cx + side * (hs - w)
            draw.line([(pan_x, beam_y), (pan_x, pan_y)], fill=color, width=max(1, w // 2))
            pan = [(pan_x - hs // 3, pan_y), (pan_x + hs // 3, pan_y),
                   (pan_x + hs // 5, pan_y + hs // 4), (pan_x - hs // 5, pan_y + hs // 4)]
            draw.polygon(pan, fill=(*color[:3], 65), outline=color, width=max(1, w // 2))
        base_w = max(3, size // 5)
        draw.rectangle([(cx - base_w, cy + hs // 2), (cx + base_w, cy + hs)], fill=color)

    elif name == SYM_LEAF:
        # Pointed, diagonal leaf with an off-centre vein; the old vertical
        # oval was easily mistaken for an eye or an oval badge.
        leaf = [(cx - hs, cy + hs // 3), (cx - hs // 2, cy - hs // 2),
                (cx + hs, cy - hs), (cx + hs // 2, cy + hs // 3),
                (cx, cy + hs), (cx - hs // 2, cy + hs // 2)]
        draw.polygon(leaf, fill=(*color[:3], 85), outline=color, width=w)
        draw.line([(cx - hs // 2, cy + hs // 2), (cx + hs // 2, cy - hs // 2)],
                  fill=color, width=max(1, w // 2))

    elif name == SYM_LIGHTNING:
        d = max(2, size // 5)
        pts = [(cx + d, cy - hs), (cx - d, cy), (cx + d, cy), (cx - d, cy + hs)]
        draw.line(pts, fill=color, width=w)

    elif name == SYM_SPEECH:
        draw.ellipse([(cx - hs, cy - hs), (cx + hs, cy + hs // 3)], outline=color, width=w)
        tail = max(2, size // 6)
        draw.polygon([(cx - tail, cy + hs // 3), (cx - hs // 2, cy + hs), (cx + tail * 2, cy + hs // 3 - 1)], fill=color)
        dot = max(1, size // 12)
        for offset in (-hs // 3, 0, hs // 3):
            draw.ellipse([(cx + offset - dot, cy - hs // 4 - dot),
                          (cx + offset + dot, cy - hs // 4 + dot)], fill=color)

    elif name == SYM_LOCK:
        draw.rectangle([(cx - hs // 2, cy), (cx + hs // 2, cy + hs)], fill=color)
        draw.arc([(cx - hs // 2, cy - hs), (cx + hs // 2, cy + w)], 180, 0, fill=color, width=w)

    elif name == SYM_DOLLAR:
        draw.ellipse([(cx - hs + w, cy - hs + w), (cx + hs - w, cy + hs - w)], outline=color, width=w)
        draw.arc([(cx - hs // 2, cy - hs // 2), (cx + hs // 2, cy)], 180, 0, fill=color, width=w)
        draw.arc([(cx - hs // 2, cy), (cx + hs // 2, cy + hs // 2)], 0, 180, fill=color, width=w)
        draw.line([(cx, cy - hs + w), (cx, cy + hs - w)], fill=color, width=max(1, w // 2))

    elif name == SYM_EXCLAIM:
        ew = max(2, size // 7)
        draw.rectangle([(cx - ew, cy - hs), (cx + ew, cy + hs // 3)], fill=color)
        draw.ellipse([(cx - ew, cy + hs // 2), (cx + ew, cy + hs)], fill=color)

    elif name == SYM_QUESTION:
        # Construct the glyph as one continuous rounded hook plus one round
        # dot.  A polyline is more stable at tiny sizes than a clipped arc.
        q_width = max(2, size // 7)
        hook = [
            (cx - hs // 2, cy - hs // 3), (cx - hs // 2, cy - hs // 2),
            (cx - hs // 4, cy - hs), (cx + hs // 4, cy - hs),
            (cx + hs // 2, cy - hs // 2), (cx + hs // 2, cy - hs // 4),
            (cx + hs // 5, cy), (cx, cy + hs // 5),
        ]
        draw.line(hook, fill=color, width=q_width, joint="curve")
        for point in hook[1:-1]:
            draw.ellipse([(point[0] - q_width // 2, point[1] - q_width // 2),
                          (point[0] + q_width // 2, point[1] + q_width // 2)], fill=color)
        dot_r = max(2, size // 10)
        dot_y = cy + hs * 3 // 4
        draw.ellipse([(cx - dot_r, dot_y - dot_r), (cx + dot_r, dot_y + dot_r)], fill=color)

    elif name == SYM_STAMP_CIRCLE:
        draw.ellipse([(cx - r, cy - r), (cx + r, cy + r)], outline=color, width=w + max(1, w // 2))
        draw.line([(cx - r + w * 2, cy), (cx + r - w * 2, cy)], fill=color, width=w)

    elif name == SYM_MAGNIFIER:
        draw.ellipse([(cx - hs + w, cy - hs + w), (cx + hs // 3, cy + hs // 3)], outline=color, width=w)
        draw.line([(cx + hs // 3, cy + hs // 3), (cx + hs, cy + hs)], fill=color, width=w)

    elif name == SYM_PEN:
        body_w = max(2, size // 6)
        body = [(cx - hs, cy + hs // 2), (cx - hs // 2, cy + hs),
                (cx + hs // 2, cy - hs // 2), (cx + hs // 4, cy - hs)]
        draw.polygon(body, fill=color, outline=color)
        nib = [(cx - hs, cy + hs // 2), (cx - hs // 2, cy + hs), (cx - hs + w, cy + hs // 3)]
        draw.polygon(nib, fill=color)
        draw.line([(cx - hs // 3, cy + hs // 2), (cx + hs // 3, cy - hs // 3)],
                  fill=(255, 250, 225, 100), width=max(1, body_w // 2))

    elif name == SYM_GAVEL:
        handle_w = max(2, size // 9)
        draw.line([(cx - hs // 2, cy + hs // 3), (cx + hs // 4, cy - hs // 4)], fill=color, width=handle_w)
        draw.rounded_rectangle([(cx - hs // 2, cy - hs), (cx + hs, cy - hs // 2)],
                               radius=max(1, w), fill=color, outline=color)
        draw.rectangle([(cx - hs // 3, cy + hs // 3), (cx + hs // 2, cy + hs // 2)], fill=color)

    elif name == SYM_MEGAPHONE:
        draw.polygon([(cx - hs, cy - w), (cx - hs, cy + w), (cx + hs, cy + hs), (cx + hs, cy - hs)], outline=color, width=w)
        mw = max(2, size // 5)
        draw.rectangle([(cx - hs - mw, cy - mw), (cx - hs, cy + mw)], fill=color)

    elif name == SYM_COFFEE:
        draw.rectangle([(cx - hs // 2, cy - hs // 3), (cx + hs // 3, cy + hs)], outline=color, width=w)
        draw.arc([(cx + hs // 3, cy - hs // 3 + w), (cx + hs, cy + hs // 2)], -90, 90, fill=color, width=w)
        for dx in [-w, w]:
            draw.line([(cx + dx, cy - hs // 3 - 1), (cx + dx - 1, cy - hs)], fill=(*color[:3], 100), width=max(1, w // 2))

    elif name == SYM_HARDHAT:
        draw.arc([(cx - hs, cy - hs), (cx + hs, cy + hs // 3)], 180, 0, fill=color, width=w + max(1, w // 2))
        brim = max(2, size // 8)
        draw.rectangle([(cx - hs - 1, cy + hs // 3 - brim), (cx + hs + 1, cy + hs // 3 + brim)], fill=color)

    elif name == SYM_CHAIN:
        link_h = max(4, size // 3)
        for i in range(3):
            y_off = cy - hs + i * (link_h - w)
            draw.ellipse([(cx - w * 2, y_off), (cx + w * 2, y_off + link_h)], outline=color, width=w)

    elif name == SYM_CROWN:
        pts = [(cx - hs, cy + hs // 2), (cx - hs + w * 2, cy - hs // 2),
               (cx - hs // 3, cy), (cx, cy - hs), (cx + hs // 3, cy),
               (cx + hs - w * 2, cy - hs // 2), (cx + hs, cy + hs // 2)]
        draw.polygon(pts, outline=color, fill=(*color[:3], 80), width=max(1, w // 2))

    elif name == SYM_TREE:
        tw = max(2, size // 8)
        draw.rectangle([(cx - tw, cy + hs // 3), (cx + tw, cy + hs)], fill=(*color[:3], 200))
        draw.polygon([(cx, cy - hs), (cx - hs + w, cy + w), (cx + hs - w, cy + w)], fill=color)
        draw.polygon([(cx, cy - hs // 2), (cx - hs, cy + hs // 3), (cx + hs, cy + hs // 3)], fill=color)

    elif name == SYM_SMOKE:
        base_r = max(3, size // 3)
        for i, (fx, fy, fr) in enumerate([(0, 0, 1.0), (-0.5, -0.4, 0.8), (0.4, -0.65, 0.8), (-0.1, -0.9, 0.6)]):
            alpha = 160 - i * 30
            r2 = int(base_r * fr)
            dx, dy = int(base_r * fx), int(base_r * fy)
            draw.ellipse([(cx + dx - r2, cy + dy - r2), (cx + dx + r2, cy + dy + r2)],
                         fill=(*color[:3], alpha))

    elif name == SYM_SOUND:
        sw = max(2, size // 7)
        draw.rectangle([(cx - hs, cy - sw), (cx - hs + sw * 2, cy + sw)], fill=color)
        draw.polygon([(cx - hs + sw * 2, cy - sw), (cx - hs + sw * 4, cy - hs // 2),
                       (cx - hs + sw * 4, cy + hs // 2), (cx - hs + sw * 2, cy + sw)], fill=color)
        for i in range(3):
            r2 = sw * 2 + i * sw * 2
            draw.arc([(cx - hs + sw * 4 - r2, cy - r2), (cx - hs + sw * 4 + r2, cy + r2)],
                     -60, 60, fill=(*color[:3], 180 - i * 50), width=w)

    elif name == SYM_PERSON:
        head_r = max(3, size // 5)
        draw.ellipse([(cx - head_r, cy - hs), (cx + head_r, cy - hs + head_r * 2)], fill=color)
        draw.line([(cx, cy - hs + head_r * 2), (cx, cy + w)], fill=color, width=w)
        draw.line([(cx - hs // 2, cy - w), (cx + hs // 2, cy - w)], fill=color, width=w)
        draw.line([(cx, cy + w), (cx - hs // 2, cy + hs)], fill=color, width=w)
        draw.line([(cx, cy + w), (cx + hs // 2, cy + hs)], fill=color, width=w)

    elif name == SYM_ARCHIVE:
        lid_h = max(3, size // 5)
        draw.rectangle([(cx - hs, cy - hs), (cx + hs, cy - hs + lid_h)], fill=color)
        draw.rectangle([(cx - hs + w, cy - hs + lid_h), (cx + hs - w, cy + hs)], outline=color, width=w)
        slot_w = max(3, size // 4)
        draw.line([(cx - slot_w, cy), (cx + slot_w, cy)], fill=color, width=w)

    elif name == SYM_ASTEROID:
        pts = [
            (cx - hs, cy - hs // 4), (cx - hs // 2, cy - hs),
            (cx + hs // 3, cy - hs + w), (cx + hs, cy - hs // 3),
            (cx + hs - w, cy + hs // 2), (cx + hs // 4, cy + hs),
            (cx - hs // 2, cy + hs - w),
        ]
        draw.polygon(pts, outline=color, fill=(*color[:3], 75), width=w)
        crater = max(2, size // 7)
        draw.ellipse([(cx - crater * 2, cy - crater), (cx, cy + crater)], outline=color, width=max(1, w // 2))
        draw.ellipse([(cx + crater // 2, cy - crater * 2),
                      (cx + crater * 2, cy - crater // 2)], outline=color, width=max(1, w // 2))

    elif name == SYM_ATOM:
        orbit_w = max(1, w // 2)
        draw.ellipse([(cx - hs, cy - hs // 2), (cx + hs, cy + hs // 2)], outline=color, width=orbit_w)
        draw.ellipse([(cx - hs // 2, cy - hs), (cx + hs // 2, cy + hs)], outline=color, width=orbit_w)
        draw.line([(cx - hs * 3 // 4, cy + hs * 3 // 4),
                   (cx + hs * 3 // 4, cy - hs * 3 // 4)], fill=color, width=orbit_w)
        nucleus = max(2, size // 9)
        draw.ellipse([(cx - nucleus, cy - nucleus), (cx + nucleus, cy + nucleus)], fill=color)

    elif name == SYM_CIRCUIT:
        chip = max(3, size // 4)
        draw.rectangle([(cx - chip, cy - chip), (cx + chip, cy + chip)], outline=color, width=w)
        lead = max(2, size // 5)
        for offset in (-chip // 2, chip // 2):
            draw.line([(cx + offset, cy - chip), (cx + offset, cy - chip - lead)], fill=color, width=max(1, w // 2))
            draw.line([(cx + offset, cy + chip), (cx + offset, cy + chip + lead)], fill=color, width=max(1, w // 2))
            draw.line([(cx - chip, cy + offset), (cx - chip - lead, cy + offset)], fill=color, width=max(1, w // 2))
            draw.line([(cx + chip, cy + offset), (cx + chip + lead, cy + offset)], fill=color, width=max(1, w // 2))
        dot = max(1, size // 12)
        draw.ellipse([(cx - dot, cy - dot), (cx + dot, cy + dot)], fill=color)

    elif name == SYM_HEAT:
        for offset in (-hs // 2, 0, hs // 2):
            pts = [
                (cx + offset, cy + hs),
                (cx + offset - w, cy + hs // 3),
                (cx + offset + w, cy - hs // 3),
                (cx + offset, cy - hs),
            ]
            draw.line(pts, fill=color, width=max(1, w // 2))

    elif name == SYM_INK:
        drop_top = (cx, cy - hs)
        drop_left = (cx - hs * 3 // 4, cy + hs // 3)
        drop_right = (cx + hs * 3 // 4, cy + hs // 3)
        draw.polygon([drop_top, drop_left, drop_right], fill=(*color[:3], 180))
        draw.ellipse([(cx - hs * 3 // 4, cy - hs // 4),
                      (cx + hs * 3 // 4, cy + hs)], fill=(*color[:3], 180), outline=color, width=w)

    elif name == SYM_SEAL:
        seal_r = max(3, size // 3)
        draw.polygon([(cx - seal_r, cy + seal_r // 2), (cx - hs, cy + hs),
                      (cx - w, cy + seal_r), (cx + w, cy + seal_r),
                      (cx + hs, cy + hs), (cx + seal_r, cy + seal_r // 2)], fill=color)
        draw.ellipse([(cx - seal_r, cy - seal_r), (cx + seal_r, cy + seal_r)],
                     fill=(*color[:3], 120), outline=color, width=w)
        inner = max(2, seal_r - w * 2)
        draw.ellipse([(cx - inner, cy - inner), (cx + inner, cy + inner)], outline=color, width=max(1, w // 2))

    elif name == SYM_SNOWFLAKE:
        for angle in (0, 60, 120):
            rad = math.radians(angle)
            dx = int(hs * math.cos(rad))
            dy = int(hs * math.sin(rad))
            draw.line([(cx - dx, cy - dy), (cx + dx, cy + dy)], fill=color, width=w)
        branch = max(2, size // 5)
        for dx, dy in ((0, -hs), (0, hs), (-hs, 0), (hs, 0)):
            sx = -1 if dx > 0 else 1 if dx < 0 else 0
            sy = -1 if dy > 0 else 1 if dy < 0 else 0
            draw.line([(cx + dx, cy + dy), (cx + dx + sy * branch, cy + dy + sx * branch)],
                      fill=color, width=max(1, w // 2))

    elif name == SYM_VAULT:
        radius = max(1, size // 8)
        draw.rounded_rectangle([(cx - hs, cy - hs), (cx + hs, cy + hs)],
                               radius=radius, outline=color, width=w)
        wheel_r = max(3, size // 4)
        draw.ellipse([(cx - wheel_r, cy - wheel_r), (cx + wheel_r, cy + wheel_r)], outline=color, width=w)
        for angle in (0, 90, 180, 270):
            rad = math.radians(angle)
            draw.line([(cx, cy),
                       (cx + int(wheel_r * math.cos(rad)), cy + int(wheel_r * math.sin(rad)))],
                      fill=color, width=max(1, w // 2))

    elif name == SYM_WARNING:
        draw.polygon([(cx, cy - hs), (cx - hs, cy + hs), (cx + hs, cy + hs)],
                     outline=color, fill=(*color[:3], 60), width=w)
        ew = max(1, size // 10)
        draw.rectangle([(cx - ew, cy - hs // 3), (cx + ew, cy + hs // 3)], fill=color)
        draw.ellipse([(cx - ew, cy + hs // 2), (cx + ew, cy + hs - w)], fill=color)

    elif name == SYM_SCROLL:
        draw.rectangle([(cx - hs + w, cy - hs + w), (cx + hs - w, cy + hs - w)], outline=color, width=max(1, w // 2))
        scroll_r = max(3, size // 5)
        draw.arc([(cx - hs, cy - hs), (cx - hs + scroll_r, cy - hs + scroll_r + w)], 90, 270, fill=color, width=w)
        draw.arc([(cx + hs - scroll_r, cy + hs - scroll_r - w), (cx + hs, cy + hs)], -90, 90, fill=color, width=w)

    elif name == SYM_HANDSHAKE:
        # Two cuffs and two interlocking palms.  The centre seam is intentional:
        # without it the old mark collapsed into a pair of random chevrons.
        cuff = max(2, size // 5)
        left_hand = [
            (cx - hs, cy - hs // 3), (cx - hs // 2, cy - hs // 2),
            (cx - w, cy - hs // 8), (cx + hs // 5, cy + hs // 5),
            (cx - hs // 5, cy + hs // 2), (cx - hs // 2, cy + hs // 4),
            (cx - hs, cy + hs // 3),
        ]
        right_hand = [
            (cx + hs, cy + hs // 3), (cx + hs // 2, cy + hs // 2),
            (cx + w, cy + hs // 8), (cx - hs // 5, cy - hs // 5),
            (cx + hs // 5, cy - hs // 2), (cx + hs // 2, cy - hs // 4),
            (cx + hs, cy - hs // 3),
        ]
        draw.polygon(left_hand, fill=(*color[:3], 80), outline=color, width=w)
        draw.polygon(right_hand, fill=(*color[:3], 80), outline=color, width=w)
        draw.rectangle([(cx - hs, cy - hs // 3), (cx - hs + cuff, cy + hs // 3)], fill=color)
        draw.rectangle([(cx + hs - cuff, cy - hs // 3), (cx + hs, cy + hs // 3)], fill=color)
        draw.line([(cx, cy - hs // 5), (cx - hs // 6, cy + hs // 6)],
                  fill=(*color[:3], 35), width=max(1, w // 2))

    elif name == SYM_BIOHAZARD:
        for angle in [0, 120, 240]:
            rad = math.radians(angle - 90)
            ex = cx + int(hs * 0.6 * math.cos(rad))
            ey = cy + int(hs * 0.6 * math.sin(rad))
            lr = max(3, size // 4)
            draw.ellipse([(ex - lr, ey - lr), (ex + lr, ey + lr)], outline=color, width=max(1, w // 2))
        cr = max(2, size // 5)
        draw.ellipse([(cx - cr, cy - cr), (cx + cr, cy + cr)], outline=color, width=max(1, w // 2))


def draw_symbol(img, name, color, pos="center", size=14):
    """Draw a compact, inked symbol with a soft cast shadow and keyline."""
    cx, cy = _pos_offset(pos, size)

    # Render through an alpha mask so every symbol—lines and filled shapes—gets
    # the same material treatment.  This is more legible at 64x64 than trying
    # to add a separate hand-written outline case to each symbol.
    symbol_layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    _draw_symbol(ImageDraw.Draw(symbol_layer), name, cx, cy, (255, 255, 255, 255), size)
    mask = symbol_layer.getchannel("A")
    shadow_mask = _shift_mask(mask, max(1, SIZE // 80), max(1, SIZE // 64))
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(max(1, SIZE // 72)))
    shadow = Image.new("RGBA", img.size, (30, 24, 20, 0))
    shadow.putalpha(shadow_mask.point(lambda value: int(value * 0.48)))
    img.alpha_composite(shadow)

    outline_width = max(1, SIZE // 96)
    outline_mask = mask.filter(ImageFilter.MaxFilter(outline_width * 2 + 1))
    outline = Image.new("RGBA", img.size, (48, 37, 30, 0))
    outline.putalpha(outline_mask.point(lambda value: int(value * 0.78)))
    img.alpha_composite(outline)

    ink = Image.new("RGBA", img.size, (*color[:3], 0))
    ink.putalpha(mask.point(lambda value: int(value * color[3] / 255)))
    img.alpha_composite(ink)

    # A narrow upper-left highlight gives filled marks a printed/raised edge
    # while staying almost invisible on thin line symbols.
    highlight_mask = ImageChops.subtract(mask, _shift_mask(mask, max(1, SIZE // 160), max(1, SIZE // 160)))
    highlight = Image.new("RGBA", img.size, (255, 250, 225, 0))
    highlight.putalpha(highlight_mask.point(lambda value: int(value * 0.24)))
    img.alpha_composite(highlight)

def draw_watermark(img, name, color):
    """Draw a large, faint symbol as watermark."""
    faint = (*color[:3], 30)
    draw = ImageDraw.Draw(img)
    _draw_symbol(draw, name, HALF, HALF, faint, size=28)


# ---------------------------------------------------------------------------
# Icon definitions
# ---------------------------------------------------------------------------

ICON_DEFS = {
    # ===== BASE FORMS & PERMITS (Straight Form, Top Stripe) =====
    "blank-form": {
        "base": "form", "tint": C_WHITE,
        "lines_color": (200, 195, 185, 120),
        "desc": "Clean white form with faint lines",
    },
    "blank-approval": {
        "base": "form", "tint": (235, 245, 255, 255),
        "stripe": (S_BLUE, "top"),
        "symbol": SYM_CHECKMARK, "symbol_color": SC_BLUE, "symbol_pos": "center",
        "lines_color": (180, 190, 210, 100),
        "desc": "Light blue form with blue stripe — approval template",
    },
    "blank-directive": {
        "base": "form", "tint": C_LIGHT_PURPLE,
        "stripe": (S_PURPLE, "top"),
        "symbol": SYM_SCROLL, "symbol_color": SC_PURPLE, "symbol_pos": "center",
        "lines_color": (190, 180, 210, 100),
        "desc": "Purple form with directive symbol",
    },
    "carbon-offset-certificate-basic": {
        "base": "form", "tint": C_LIGHT_GREEN,
        "stripe": (S_GREEN, "top"),
        "symbol": SYM_LEAF, "symbol_color": SC_GREEN, "symbol_pos": "center",
        "lines_color": (160, 190, 160, 100),
        "desc": "Green form with centered leaf",
    },
    "provisional-approval": {
        "base": "form", "tint": C_LIGHT_RED,
        "stripe": (S_RED, "top"),
        "symbol": SYM_EXCLAIM, "symbol_color": SC_RED, "symbol_pos": "center",
        "desc": "Red form with centered exclamation",
    },
    "safety-waiver": {
        "base": "form", "tint": C_LIGHT_BLUE,
        "stripe": (S_DARK_BLUE, "top"),
        "symbol": SYM_SHIELD, "symbol_color": SC_BLUE, "symbol_pos": "center",
        "lines_color": (160, 170, 200, 100),
        "desc": "Blue form with centered shield",
    },
    "construction-permit": {
        "base": "form", "tint": C_LIGHT_ORANGE,
        "stripe": (S_ORANGE, "top"),
        "symbol": SYM_HAMMER, "symbol_color": SC_ORANGE, "symbol_pos": "center",
        "lines_color": (200, 180, 150, 100),
        "desc": "Orange form with centered hammer",
    },
    "management-approval-verbal": {
        "base": "form", "tint": C_LIGHT_YELLOW,
        "stripe": (S_GOLD, "top"),
        "symbol": SYM_SPEECH, "symbol_color": SC_GOLD, "symbol_pos": "center",
        "desc": "Yellow paper with centered speech bubble",
    },
    "management-approval-written": {
        "base": "form", "tint": C_LIGHT_PURPLE,
        "stripe": (S_PURPLE, "top"),
        "symbol": SYM_PEN, "symbol_color": SC_PURPLE, "symbol_pos": "center",
        "lines_color": (180, 170, 200, 100),
        "desc": "Purple form with centered pen",
    },
    "transit-authorization": {
        "base": "form", "tint": (220, 255, 235, 255),
        "stripe": (S_TEAL, "top"),
        "symbol": SYM_TRAIN, "symbol_color": SC_TEAL, "symbol_pos": "center",
        "lines_color": (160, 190, 180, 100),
        "desc": "Teal form with centered train",
    },
    "research-grant-approval": {
        "base": "form", "tint": (230, 240, 255, 255),
        "stripe": (S_BLUE, "top"),
        "symbol": SYM_FLASK, "symbol_color": SC_BLUE, "symbol_pos": "center",
        "lines_color": (170, 180, 200, 100),
        "desc": "Blue-white form with centered flask",
    },
    # ===== DRAFTS & PROPOSALS (Tilted Paper, Pen icon, Post-it) =====
    "safety-waiver-draft": {
        "base": "paper", "tint": C_LIGHT_BLUE,
        "symbol": SYM_SHIELD, "symbol_color": SC_GRAY, "symbol_pos": "center",
        "symbol2": SYM_PEN, "symbol2_color": SC_DARK, "symbol2_pos": "br",
        "post_it": True,
        "desc": "Blue paper, centered shield + pen + post-it (draft)",
    },
    "construction-permit-draft": {
        "base": "paper", "tint": C_LIGHT_ORANGE,
        "symbol": SYM_HAMMER, "symbol_color": SC_GRAY, "symbol_pos": "center",
        "symbol2": SYM_PEN, "symbol2_color": SC_DARK, "symbol2_pos": "br",
        "post_it": True,
        "desc": "Orange paper, centered hammer + pen + post-it (draft)",
    },
    "management-verbal-draft": {
        "base": "paper", "tint": C_LIGHT_YELLOW,
        "symbol": SYM_SPEECH, "symbol_color": SC_GRAY, "symbol_pos": "center",
        "symbol2": SYM_PEN, "symbol2_color": SC_DARK, "symbol2_pos": "br",
        "post_it": True,
        "desc": "Yellow paper, centered speech + pen + post-it (draft)",
    },
    "management-written-proposal": {
        "base": "paper", "tint": C_LIGHT_PURPLE,
        "symbol": SYM_PEN, "symbol_color": SC_GRAY, "symbol_pos": "center",
        "symbol2": SYM_QUESTION, "symbol2_color": SC_DARK, "symbol2_pos": "br",
        "post_it": True,
        "desc": "Purple paper, centered pen + question + post-it (proposal)",
    },
    # ===== WORK ORDERS (Form + Hole Punches + Gear icon) =====
    "work-order": {
        "base": "form", "tint": C_LIGHT_YELLOW,
        "symbol": SYM_GEAR, "symbol_color": SC_DARK, "symbol_pos": "center",
        "hole_punches": 2,
        "desc": "Yellow form with centered gear and hole punches",
    },
    "form-27b-6": {
        "base": "form", "tint": C_LIGHT_PINK,
        "stripe": (S_RED, "top"),
        "stripe2": (S_RED, "bottom"),
        "symbol": SYM_LOCK, "symbol_color": SC_RED, "symbol_pos": "center",
        "hole_punches": 2,
        "desc": "Pink form with lock and hole punches",
    },
    "safety-work-order": {
        "base": "form", "tint": C_LIGHT_BLUE,
        "symbol": SYM_SHIELD, "symbol_color": SC_BLUE, "symbol_pos": "center",
        "symbol2": SYM_GEAR, "symbol2_color": SC_DARK, "symbol2_pos": "tr",
        "hole_punches": 2,
        "desc": "Blue form, shield + top-right gear + hole punches",
    },
    "construction-work-order": {
        "base": "form", "tint": C_LIGHT_ORANGE,
        "symbol": SYM_HAMMER, "symbol_color": SC_ORANGE, "symbol_pos": "center",
        "symbol2": SYM_GEAR, "symbol2_color": SC_DARK, "symbol2_pos": "tr",
        "hole_punches": 2,
        "desc": "Orange form, hammer + top-right gear + hole punches",
    },
    "management-verbal-work-order": {
        "base": "form", "tint": C_LIGHT_YELLOW,
        "symbol": SYM_SPEECH, "symbol_color": SC_GOLD, "symbol_pos": "center",
        "symbol2": SYM_GEAR, "symbol2_color": SC_DARK, "symbol2_pos": "tr",
        "hole_punches": 2,
        "desc": "Yellow form, speech + top-right gear + hole punches",
    },
    "management-written-work-order": {
        "base": "form", "tint": C_LIGHT_PURPLE,
        "symbol": SYM_PEN, "symbol_color": SC_PURPLE, "symbol_pos": "center",
        "symbol2": SYM_GEAR, "symbol2_color": SC_DARK, "symbol2_pos": "tr",
        "hole_punches": 2,
        "desc": "Purple form, pen + top-right gear + hole punches",
    },
    "research-grant-work-order": {
        "base": "form", "tint": (230, 240, 255, 255),
        "symbol": SYM_FLASK, "symbol_color": SC_BLUE, "symbol_pos": "center",
        "symbol2": SYM_GEAR, "symbol2_color": SC_DARK, "symbol2_pos": "tr",
        "hole_punches": 2,
        "desc": "Blue form, flask + top-right gear + hole punches",
    },
    "chemical-handling-work-order": {
        "base": "form", "tint": (220, 245, 245, 255),
        "stripe": (S_TEAL, "top"),
        "symbol": SYM_FLASK, "symbol_color": SC_TEAL, "symbol_pos": "center",
        "symbol2": SYM_GEAR, "symbol2_color": SC_DARK, "symbol2_pos": "tr",
        "badge": ("C", S_TEAL, "bl"),
        "hole_punches": 2,
        "desc": "Teal chemistry work order with flask, top-right gear, and C badge",
    },
    "radiological-work-order": {
        "base": "form", "tint": (240, 255, 230, 255),
        "stripe": (S_DARK_RED, "top"),
        "symbol": SYM_BIOHAZARD, "symbol_color": SC_DARK, "symbol_pos": "center",
        "symbol2": SYM_GEAR, "symbol2_color": SC_DARK, "symbol2_pos": "tr",
        "badge": ("R", S_DARK_RED, "bl"),
        "hole_punches": 2,
        "desc": "Radiological work order with biohazard, top-right gear, and R badge",
    },

    # ===== REPORTS & PRINTED (Stack or Ledger, Stamps, Clips) =====
    "carbon-offset-certificate-verified": {
        "base": "ledger", "tint": C_LIGHT_GREEN,
        "symbol": SYM_LEAF, "symbol_color": SC_GREEN, "symbol_pos": "center",
        "stamp": (SC_GREEN, "tr"),
        "desc": "Green ledger with leaf + verification stamp",
    },
    "environmental-impact-report": {
        "base": "stack", "tint": C_LIGHT_GREEN,
        "stripe": (S_GREEN, "top"),
        "symbol": SYM_TREE, "symbol_color": SC_GREEN, "symbol_pos": "center",
        "clip": True,
        "desc": "Green stack with tree + clip",
    },
    "white-paper": {
        "base": "stack", "tint": C_WHITE,
        "symbol": SYM_MAGNIFIER, "symbol_color": SC_DARK, "symbol_pos": "center",
        "clip": True,
        "desc": "White stack with magnifier + clip",
    },
    "crappy-report": {
        "base": "stack", "tint": C_CREAM,
        "stripe": (S_RED, "top"),
        "symbol": SYM_CROSS, "symbol_color": SC_RED, "symbol_pos": "center",
        "desc": "Cream stack with red X",
    },
    "narrative": {
        "base": "ledger", "tint": C_LIGHT_GRAY,
        "symbol": SYM_SCROLL, "symbol_color": SC_DARK, "symbol_pos": "center",
        "desc": "Gray ledger with scroll",
    },
    "policy": {
        "base": "ledger", "tint": C_WHITE,
        "stripe": (S_DARK_BLUE, "top"),
        "symbol": SYM_GAVEL, "symbol_color": SC_BLUE, "symbol_pos": "center",
        "desc": "White ledger with gavel",
    },
    "regulation": {
        "base": "ledger", "tint": C_LIGHT_RED,
        "stripe": (S_DARK_RED, "top"),
        "symbol": SYM_STAMP_CIRCLE, "symbol_color": SC_RED, "symbol_pos": "center",
        "desc": "Red ledger with official stamp",
    },
    "justification": {
        "base": "form", "tint": C_LIGHT_GRAY,
        "symbol": SYM_SCALES, "symbol_color": SC_GRAY, "symbol_pos": "center",
        "hole_punches": 3,
        "desc": "Gray form with scales and 3 hole punches",
    },
    "promise": {
        "base": "form", "tint": C_LIGHT_YELLOW,
        "stripe": (S_GREEN, "top"),
        "symbol": SYM_HANDSHAKE, "symbol_color": SC_GREEN, "symbol_pos": "center",
        "symbol2": SYM_SPEECH, "symbol2_color": SC_GOLD, "symbol2_pos": "br",
        "desc": "Yellow form with handshake and speech bubble",
    },

    # ===== ECONOMY & MISC =====
    "paper": {
        "base": "paper", "tint": C_WHITE,
        "desc": "Blank sheet of paper",
    },
    "watercooler-gossip": {
        "base": "paper", "tint": (220, 245, 255, 255),
        "symbol": SYM_SPEECH, "symbol_color": SC_TEAL, "symbol_pos": "center",
        "desc": "Light blue paper with speech bubble",
    },
    "useless-documentation": {
        "base": "stack", "tint": C_LIGHT_YELLOW,
        "symbol": SYM_CROSS, "symbol_color": SC_GRAY, "symbol_pos": "center",
        "desc": "Yellow stack with gray X",
    },
    "treasury-bond": {
        "base": "form", "tint": (235, 250, 230, 255),
        "stripe": (S_DARK_GREEN, "top"),
        "stripe2": (S_DARK_GREEN, "bottom"),
        "symbol": SYM_DOLLAR, "symbol_color": SC_GREEN, "symbol_pos": "center",
        "desc": "Green form with dollar sign",
    },
    "government-grant": {
        "base": "ledger", "tint": (245, 240, 255, 255),
        "stripe": (S_GOLD, "top"),
        "symbol": SYM_CROWN, "symbol_color": SC_GOLD, "symbol_pos": "center",
        "desc": "Purple ledger with gold crown",
    },

    # ===== RESOLUTION: TICKETS (Narrow strips) =====
    "ticket-landscape": {
        "base": "ticket", "tint": (235, 255, 225, 255),
        "symbol": SYM_TREE, "symbol_color": SC_GREEN, "symbol_pos": "center",
        "desc": "Green ticket strip",
    },
    "ticket-smog": {
        "base": "ticket", "tint": (245, 245, 245, 255),
        "symbol": SYM_SMOKE, "symbol_color": SC_GRAY, "symbol_pos": "center",
        "desc": "Gray ticket strip",
    },
    "ticket-noise": {
        "base": "ticket", "tint": (245, 235, 255, 255),
        "symbol": SYM_SOUND, "symbol_color": SC_PURPLE, "symbol_pos": "center",
        "desc": "Purple ticket strip",
    },
    "ticket-unemployment": {
        "base": "ticket", "tint": (255, 240, 230, 255),
        "symbol": SYM_PERSON, "symbol_color": SC_ORANGE, "symbol_pos": "center",
        "desc": "Orange ticket strip",
    },
    "ticket-littering": {
        "base": "ticket", "tint": (225, 255, 255, 255),
        "symbol": SYM_LEAF, "symbol_color": SC_TEAL, "symbol_pos": "center",
        "desc": "Teal ticket strip",
    },
    "ticket-hazmat": {
        "base": "ticket", "tint": (255, 255, 225, 255),
        "symbol": SYM_BIOHAZARD, "symbol_color": SC_GOLD, "symbol_pos": "center",
        "desc": "Yellow ticket strip",
    },
    "ticket-loitering": {
        "base": "ticket", "tint": (230, 240, 255, 255),
        "symbol": SYM_CHAIN, "symbol_color": SC_BLUE, "symbol_pos": "center",
        "desc": "Blue ticket strip",
    },
    "ticket-vagrancy": {
        "base": "ticket", "tint": (255, 235, 245, 255),
        "symbol": SYM_QUESTION, "symbol_color": SC_PINK, "symbol_pos": "center",
        "desc": "Pink ticket strip",
    },

    # ===== RESOLUTION: FILINGS (Form + Badge) =====
    "filing-l": {
        "base": "form", "tint": (235, 255, 225, 255),
        "badge": ("L", S_GREEN, "bl"),
        "symbol": SYM_TREE, "symbol_color": SC_GREEN, "symbol_pos": "center",
        "desc": "Landscape filing form",
    },
    "filing-s": {
        "base": "form", "tint": (245, 245, 245, 255),
        "badge": ("S", S_GRAY, "bl"),
        "symbol": SYM_SMOKE, "symbol_color": SC_GRAY, "symbol_pos": "center",
        "desc": "Smog filing form",
    },
    "filing-n": {
        "base": "form", "tint": (245, 235, 255, 255),
        "badge": ("N", S_PURPLE, "bl"),
        "symbol": SYM_SOUND, "symbol_color": SC_PURPLE, "symbol_pos": "center",
        "desc": "Noise filing form",
    },
    "filing-u": {
        "base": "form", "tint": (255, 240, 230, 255),
        "badge": ("U", S_ORANGE, "bl"),
        "symbol": SYM_PERSON, "symbol_color": SC_ORANGE, "symbol_pos": "center",
        "desc": "Unemployment filing form",
    },
    "filing-lt": {
        "base": "form", "tint": (225, 255, 255, 255),
        "badge": ("LT", S_TEAL, "bl"),
        "symbol": SYM_LEAF, "symbol_color": SC_TEAL, "symbol_pos": "center",
        "desc": "Littering filing form",
    },
    "filing-h": {
        "base": "form", "tint": (255, 255, 225, 255),
        "badge": ("H", S_YELLOW, "bl"),
        "symbol": SYM_BIOHAZARD, "symbol_color": SC_GOLD, "symbol_pos": "center",
        "desc": "Hazmat filing form",
    },
    "filing-lo": {
        "base": "form", "tint": (230, 240, 255, 255),
        "badge": ("LO", S_BLUE, "bl"),
        "symbol": SYM_CHAIN, "symbol_color": SC_BLUE, "symbol_pos": "center",
        "desc": "Loitering filing form",
    },
    "filing-v": {
        "base": "form", "tint": (255, 235, 245, 255),
        "badge": ("V", S_PINK, "bl"),
        "symbol": SYM_QUESTION, "symbol_color": SC_PINK, "symbol_pos": "center",
        "desc": "Vagrancy filing form",
    },

    # ===== RESOLUTION: CASES (Folder + Badge) =====
    "case-s": {
        "base": "folder", "tint": (235, 235, 230, 255),
        "badge": ("S", S_GRAY, "bl"),
        "symbol": SYM_SMOKE, "symbol_color": SC_GRAY, "symbol_pos": "center",
        "desc": "Smog case folder",
    },
    "case-n": {
        "base": "folder", "tint": (235, 225, 240, 255),
        "badge": ("N", S_PURPLE, "bl"),
        "symbol": SYM_SOUND, "symbol_color": SC_PURPLE, "symbol_pos": "center",
        "desc": "Noise case folder",
    },
    "case-u": {
        "base": "folder", "tint": (245, 235, 220, 255),
        "badge": ("U", S_ORANGE, "bl"),
        "symbol": SYM_PERSON, "symbol_color": SC_ORANGE, "symbol_pos": "center",
        "desc": "Unemployment case folder",
    },
    "case-h": {
        "base": "folder", "tint": (245, 245, 210, 255),
        "badge": ("H", S_YELLOW, "bl"),
        "symbol": SYM_BIOHAZARD, "symbol_color": SC_GOLD, "symbol_pos": "center",
        "desc": "Hazmat case folder",
    },
    "case-lo": {
        "base": "folder", "tint": (210, 225, 245, 255),
        "badge": ("LO", S_BLUE, "bl"),
        "symbol": SYM_CHAIN, "symbol_color": SC_BLUE, "symbol_pos": "center",
        "desc": "Loitering case folder",
    },
    "case-v": {
        "base": "folder", "tint": (245, 220, 235, 255),
        "badge": ("V", S_PINK, "bl"),
        "symbol": SYM_QUESTION, "symbol_color": SC_PINK, "symbol_pos": "center",
        "desc": "Vagrancy case folder",
    },

    # ===== RESOLUTION: RESOLVED (Form + Big Green Stamp) =====
    "resolved-landscape": {
        "base": "form", "tint": (235, 255, 225, 255),
        "stamp": (SC_GREEN, "center"),
        "symbol": SYM_CHECKMARK, "symbol_color": SC_GREEN, "symbol_pos": "center",
        "desc": "Resolved landscape",
    },
    "resolved-smog": {
        "base": "form", "tint": (245, 245, 245, 255),
        "stamp": (SC_GREEN, "center"),
        "symbol": SYM_CHECKMARK, "symbol_color": SC_GREEN, "symbol_pos": "center",
        "desc": "Resolved smog",
    },
    "resolved-noise": {
        "base": "form", "tint": (245, 235, 255, 255),
        "stamp": (SC_GREEN, "center"),
        "symbol": SYM_CHECKMARK, "symbol_color": SC_GREEN, "symbol_pos": "center",
        "desc": "Resolved noise",
    },
    "resolved-unemployment": {
        "base": "form", "tint": (255, 240, 230, 255),
        "stamp": (SC_GREEN, "center"),
        "symbol": SYM_CHECKMARK, "symbol_color": SC_GREEN, "symbol_pos": "center",
        "desc": "Resolved unemployment",
    },
    "resolved-littering": {
        "base": "form", "tint": (225, 255, 255, 255),
        "stamp": (SC_GREEN, "center"),
        "symbol": SYM_CHECKMARK, "symbol_color": SC_GREEN, "symbol_pos": "center",
        "desc": "Resolved littering",
    },
    "resolved-hazmat": {
        "base": "form", "tint": (255, 255, 225, 255),
        "stamp": (SC_GREEN, "center"),
        "symbol": SYM_CHECKMARK, "symbol_color": SC_GREEN, "symbol_pos": "center",
        "desc": "Resolved hazmat",
    },
    "resolved-loitering": {
        "base": "form", "tint": (230, 240, 255, 255),
        "stamp": (SC_GREEN, "center"),
        "symbol": SYM_CHECKMARK, "symbol_color": SC_GREEN, "symbol_pos": "center",
        "desc": "Resolved loitering",
    },
    "resolved-vagrancy": {
        "base": "form", "tint": (255, 235, 245, 255),
        "stamp": (SC_GREEN, "center"),
        "symbol": SYM_CHECKMARK, "symbol_color": SC_GREEN, "symbol_pos": "center",
        "desc": "Resolved vagrancy",
    },

    # ===== OSHA =====
    "osha-violation": {
        "base": "form", "tint": (255, 210, 210, 255),
        "stripe": (S_DARK_RED, "top"),
        "stripe2": (S_DARK_RED, "bottom"),
        "symbol": SYM_WARNING, "symbol_color": SC_RED, "symbol_pos": "center",
        "badge": ("!", S_DARK_RED, "tr"),
        "desc": "Red OSHA violation form",
    },
}

# Space Age paperwork uses the same lifecycle grammar as the Nauvis set:
# stacks are unprinted stock, tilted sheets are drafts, punched forms are work
# orders, straight forms are permits/certificates, and bound ledgers are
# charters/deeds.  Header colors identify the planet or chromatic lineage:
# cyan=Vulcanus, yellow=Gleba, magenta=Fulgora, CMY=Aquilo convergence.
SPACE_AGE_FORM_ICON_DEFS = {
    "heatproof-form-stock": {
        "base": "stack", "tint": (205, 240, 235, 255),
        "header_bands": [S_CYAN],
        "symbol": SYM_HEAT, "symbol_color": SC_ORANGE, "symbol_pos": "center", "symbol_size": 22,
        "corner_tab": (S_ORANGE, "br"),
        "desc": "Cyan Vulcanus stock with heat treatment mark",
    },
    "blank-cyan-form": {
        "base": "form", "tint": (218, 248, 246, 255),
        "header_bands": [S_CYAN],
        "lines_color": (90, 145, 145, 95),
        "symbol2": SYM_INK, "symbol2_color": SC_TEAL, "symbol2_pos": "br", "symbol2_size": 14,
        "desc": "Blank cyan form with a cyan registration band",
    },
    "mycelial-form-stock": {
        "base": "stack", "tint": (238, 226, 160, 255),
        "header_bands": [S_YELLOW],
        "symbol": SYM_LEAF, "symbol_color": SC_GREEN, "symbol_pos": "center", "symbol_size": 22,
        "corner_tab": (S_GREEN, "br"),
        "desc": "Organic yellow Gleba stock with mycelial mark",
    },
    "blank-yellow-form": {
        "base": "form", "tint": (250, 239, 178, 255),
        "header_bands": [S_YELLOW],
        "lines_color": (155, 135, 60, 95),
        "symbol2": SYM_INK, "symbol2_color": SC_GOLD, "symbol2_pos": "br", "symbol2_size": 14,
        "desc": "Blank yellow form with a yellow registration band",
    },
    "signal-form-stock": {
        "base": "stack", "tint": (239, 214, 232, 255),
        "header_bands": [S_MAGENTA],
        "symbol": SYM_CIRCUIT, "symbol_color": SC_PURPLE, "symbol_pos": "center", "symbol_size": 22,
        "corner_tab": (S_BLUE, "br"),
        "desc": "Magenta Fulgora stock with embedded signal traces",
    },
    "blank-magenta-form": {
        "base": "form", "tint": (247, 224, 240, 255),
        "header_bands": [S_MAGENTA],
        "lines_color": (155, 95, 135, 95),
        "symbol2": SYM_INK, "symbol2_color": SC_PINK, "symbol2_pos": "br", "symbol2_size": 14,
        "desc": "Blank magenta form with a magenta registration band",
    },
    "cyan-yellow-form": {
        "base": "form", "tint": (235, 242, 215, 255),
        "header_bands": [S_CYAN, S_YELLOW],
        "symbol": SYM_STAMP_CIRCLE, "symbol_color": SC_DARK, "symbol_pos": "center", "symbol_size": 24,
        "lines_color": (125, 125, 100, 85),
        "desc": "Registered cyan-yellow dual-planet form",
    },
    "cyan-magenta-form": {
        "base": "form", "tint": (235, 228, 242, 255),
        "header_bands": [S_CYAN, S_MAGENTA],
        "symbol": SYM_STAMP_CIRCLE, "symbol_color": SC_DARK, "symbol_pos": "center", "symbol_size": 24,
        "lines_color": (120, 105, 135, 85),
        "desc": "Registered cyan-magenta dual-planet form",
    },
    "yellow-magenta-form": {
        "base": "form", "tint": (244, 226, 210, 255),
        "header_bands": [S_YELLOW, S_MAGENTA],
        "symbol": SYM_STAMP_CIRCLE, "symbol_color": SC_DARK, "symbol_pos": "center", "symbol_size": 24,
        "lines_color": (140, 105, 105, 85),
        "desc": "Registered yellow-magenta dual-planet form",
    },
    "permit-draft": {
        "base": "paper", "tint": (205, 238, 235, 255),
        "header_bands": [S_CYAN],
        "symbol": SYM_HAMMER, "symbol_color": SC_GRAY, "symbol_pos": "center",
        "symbol2": SYM_PEN, "symbol2_color": SC_DARK, "symbol2_pos": "br",
        "post_it": True, "post_it_color": (115, 225, 225, 255),
        "desc": "Tilted cyan Vulcanus permit draft",
    },
    "inspection-docket": {
        "base": "stack", "tint": (213, 242, 238, 255),
        "header_bands": [S_CYAN],
        "symbol": SYM_MAGNIFIER, "symbol_color": SC_TEAL, "symbol_pos": "center",
        "clip": True,
        "desc": "Clipped cyan Vulcanus inspection docket",
    },
    "symbiosis-record": {
        "base": "form", "tint": (245, 232, 170, 255),
        "header_bands": [S_YELLOW],
        "symbol": SYM_LEAF, "symbol_color": SC_GREEN, "symbol_pos": "center",
        "symbol2": SYM_HANDSHAKE, "symbol2_color": SC_GOLD, "symbol2_pos": "br",
        "desc": "Yellow Gleba biological symbiosis record",
    },
    "conciliation-order": {
        "base": "form", "tint": (247, 232, 170, 255),
        "header_bands": [S_YELLOW],
        "symbol": SYM_HANDSHAKE, "symbol_color": SC_GREEN, "symbol_pos": "center",
        "symbol2": SYM_GAVEL, "symbol2_color": SC_GOLD, "symbol2_pos": "br",
        "stamp": (SC_GREEN, "tr"),
        "desc": "Stamped yellow Gleba conciliation order",
    },
    "archive-recovery-permit": {
        "base": "form", "tint": (241, 222, 236, 255),
        "header_bands": [S_MAGENTA],
        "symbol": SYM_ARCHIVE, "symbol_color": SC_PURPLE, "symbol_pos": "center",
        "symbol2": SYM_MAGNIFIER, "symbol2_color": SC_BLUE, "symbol2_pos": "br",
        "desc": "Magenta Fulgora archive recovery permit",
    },
    "digital-processing-certificate": {
        "base": "form", "tint": (242, 220, 238, 255),
        "header_bands": [S_MAGENTA],
        "symbol": SYM_CIRCUIT, "symbol_color": SC_PURPLE, "symbol_pos": "center",
        "stamp": (SC_GREEN, "tr"),
        "desc": "Verified magenta digital processing certificate",
    },
    "electromagnetic-operating-license": {
        "base": "form", "tint": (232, 222, 241, 255),
        "header_bands": [S_MAGENTA, S_BLUE],
        "symbol": SYM_LIGHTNING, "symbol_color": SC_PURPLE, "symbol_pos": "center",
        "stamp": (SC_PURPLE, "tr"),
        "desc": "Magenta-blue electromagnetic operating license",
    },
    "data-recovery-order": {
        "base": "form", "tint": (238, 218, 234, 255),
        "header_bands": [S_MAGENTA],
        "symbol": SYM_ARCHIVE, "symbol_color": SC_PURPLE, "symbol_pos": "center",
        "symbol2": SYM_GEAR, "symbol2_color": SC_DARK, "symbol2_pos": "tr",
        "hole_punches": 2,
        "desc": "Punched magenta archive recovery work order",
    },
    "hardened-data-vault": {
        "base": "form", "tint": (218, 225, 236, 255),
        "header_bands": [S_CYAN, S_MAGENTA],
        "symbol": SYM_VAULT, "symbol_color": SC_DARK, "symbol_pos": "center",
        "symbol2": SYM_GEAR, "symbol2_color": SC_PURPLE, "symbol2_pos": "tr",
        "hole_punches": 2,
        "desc": "Hardened cyan-magenta data vault order",
    },
    "trichromatic-permit": {
        "base": "form", "tint": (236, 234, 225, 255),
        "header_bands": [S_CYAN, S_YELLOW, S_MAGENTA],
        "symbol": SYM_SEAL, "symbol_color": SC_DARK, "symbol_pos": "center",
        "stamp": (SC_PURPLE, "tr"),
        "desc": "Official three-color convergence permit",
    },
    "unified-operations-charter": {
        "base": "ledger", "tint": (226, 224, 220, 255),
        "header_bands": [S_CYAN, S_YELLOW, S_MAGENTA],
        "symbol": SYM_CROWN, "symbol_color": SC_GOLD, "symbol_pos": "center",
        "symbol2": SYM_GEAR, "symbol2_color": SC_DARK, "symbol2_pos": "br",
        "desc": "Bound CMY unified operations charter",
    },
    "public-transportation-contract": {
        "base": "form", "tint": (232, 239, 205, 255),
        "header_bands": [S_CYAN, S_YELLOW],
        "symbol": SYM_TRAIN, "symbol_color": SC_TEAL, "symbol_pos": "center",
        "symbol2": SYM_HANDSHAKE, "symbol2_color": SC_GOLD, "symbol2_pos": "br",
        "desc": "Cyan-yellow public transportation contract",
    },
    "cryogenic-operations-license": {
        "base": "form", "tint": (222, 239, 246, 255),
        "header_bands": [S_CYAN, S_YELLOW, S_MAGENTA],
        "symbol": SYM_SNOWFLAKE, "symbol_color": SC_BLUE, "symbol_pos": "center",
        "stamp": (SC_TEAL, "tr"),
        "desc": "Frost-blue Aquilo operations license with CMY authority",
    },
    "promethium-research-charter": {
        "base": "ledger", "tint": (226, 216, 238, 255),
        "header_bands": [S_CYAN, S_YELLOW, S_MAGENTA],
        "symbol": SYM_ATOM, "symbol_color": SC_PURPLE, "symbol_pos": "center",
        "symbol2": SYM_FLASK, "symbol2_color": SC_BLUE, "symbol2_pos": "br",
        "desc": "Bound CMY Administratorium expedition charter",
    },
    "embossed-seal": {
        "base": "form", "tint": (244, 229, 193, 255),
        "header_bands": [S_GOLD],
        "symbol": SYM_SEAL, "symbol_color": SC_GOLD, "symbol_pos": "center", "symbol_size": 30,
        "stamp": (SC_PURPLE, "tr"),
        "desc": "Heavy gold embossed notarial seal",
    },
    "industrial-charter": {
        "base": "ledger", "tint": (214, 234, 225, 255),
        "header_bands": [S_CYAN, S_ORANGE],
        "symbol": SYM_GEAR, "symbol_color": SC_ORANGE, "symbol_pos": "center",
        "stamp": (SC_GOLD, "tr"),
        "desc": "Bound cyan-bronze Vulcanus industrial charter",
    },
    "territorial-resettlement-order": {
        "base": "form", "tint": (220, 234, 220, 255),
        "header_bands": [S_CYAN, S_ORANGE],
        "symbol": SYM_GAVEL, "symbol_color": SC_BROWN, "symbol_pos": "center",
        "symbol2": SYM_PERSON, "symbol2_color": SC_ORANGE, "symbol2_pos": "br",
        "desc": "Cyan-bronze territorial resettlement order",
    },
    "territorial-deed": {
        "base": "ledger", "tint": (226, 232, 211, 255),
        "header_bands": [S_CYAN, S_ORANGE],
        "symbol": SYM_SCALES, "symbol_color": SC_BROWN, "symbol_pos": "center",
        "symbol2": SYM_SEAL, "symbol2_color": SC_GOLD, "symbol2_pos": "br",
        "desc": "Bound cyan-bronze territorial deed",
    },
    "thermal-process-license": {
        "base": "form", "tint": (218, 235, 225, 255),
        "header_bands": [S_CYAN, S_ORANGE],
        "symbol": SYM_HEAT, "symbol_color": SC_ORANGE, "symbol_pos": "center",
        "stamp": (SC_GOLD, "tr"),
        "desc": "Cyan-bronze thermal process license",
    },
    "calcite-reagent-waiver": {
        "base": "form", "tint": (221, 240, 228, 255),
        "header_bands": [S_CYAN, S_ORANGE],
        "symbol": SYM_FLASK, "symbol_color": SC_TEAL, "symbol_pos": "center",
        "symbol2": SYM_SHIELD, "symbol2_color": SC_ORANGE, "symbol2_pos": "br",
        "desc": "Cyan Vulcanus calcite reagent waiver",
    },
    "offworld-metallurgy-charter": {
        "base": "ledger", "tint": (216, 231, 231, 255),
        "header_bands": [S_CYAN, S_DARK_BLUE],
        "symbol": SYM_HAMMER, "symbol_color": SC_TEAL, "symbol_pos": "center",
        "symbol2": SYM_STAR, "symbol2_color": SC_BLUE, "symbol2_pos": "br",
        "desc": "Bound cyan offworld metallurgy charter",
    },
    "asteroid-processing-docket": {
        "base": "form", "tint": (218, 228, 239, 255),
        "header_bands": [S_DARK_BLUE, S_CYAN],
        "symbol": SYM_ASTEROID, "symbol_color": SC_GRAY, "symbol_pos": "center",
        "symbol2": SYM_GEAR, "symbol2_color": SC_BLUE, "symbol2_pos": "tr",
        "hole_punches": 2,
        "desc": "Punched orbital asteroid processing docket",
    },
    "orbital-infrastructure-permit": {
        "base": "form", "tint": (218, 228, 239, 255),
        "header_bands": [S_DARK_BLUE, S_CYAN],
        "symbol": SYM_HAMMER, "symbol_color": SC_BLUE, "symbol_pos": "center",
        "symbol2": SYM_STAR, "symbol2_color": SC_TEAL, "symbol2_pos": "br",
        "stamp": (SC_BLUE, "tr"),
        "lines_color": (125, 145, 175, 90),
        "desc": "Blue-cyan orbital infrastructure permit with hammer, star, and approval stamp",
    },
    "provisional-work-order": {
        "base": "form", "tint": (248, 222, 178, 255),
        "header_bands": [S_RED, S_YELLOW],
        "symbol": SYM_EXCLAIM, "symbol_color": SC_RED, "symbol_pos": "center",
        "symbol2": SYM_GEAR, "symbol2_color": SC_DARK, "symbol2_pos": "tr",
        "hole_punches": 2,
        "desc": "Provisional punched work order",
    },
}

ICON_DEFS.update(SPACE_AGE_FORM_ICON_DEFS)

# Technology icons generated from the administrative-bureaucracy paper base.
# The source icon is projected onto the visible sheet so it sits with the same
# perspective as the base artwork instead of looking like a flat UI overlay.
TECH_ICON_DEFS = {
    "littering-resolution": "ticket-littering",
    "streamlined-work-orders": "work-order",
    "smog-abatement": "ticket-smog",
    "hazmat-response": "ticket-hazmat",
    "radiological-compliance": "radiological-work-order",
    "noise-ordinances": "ticket-noise",
    "loitering-ordinances": "ticket-loitering",
    "vagrancy-ordinances": "ticket-vagrancy",
    "board-meetings": "management-written-proposal",
    "executive-review": "management-approval-written",
    "work-order-duplication": "work-order",
    "federal-regulation": "regulation"
}

# ---------------------------------------------------------------------------
# Icon generation
# ---------------------------------------------------------------------------

# Supersample factor: draw at Nx size, then downscale with LANCZOS for anti-aliasing
SUPERSAMPLE = 4


def _find_perspective_coeffs(src, dst):
    """Return PIL perspective coefficients mapping dst pixels back to src."""
    matrix = []
    vector = []
    for (x, y), (u, v) in zip(dst, src):
        matrix.append([x, y, 1, 0, 0, 0, -u * x, -u * y])
        matrix.append([0, 0, 0, x, y, 1, -v * x, -v * y])
        vector.extend([u, v])

    # Gaussian elimination for the 8x8 system. This keeps the generator's
    # runtime dependency to Pillow only.
    for col in range(8):
        pivot = max(range(col, 8), key=lambda row: abs(matrix[row][col]))
        if abs(matrix[pivot][col]) < 1e-12:
            raise RuntimeError("degenerate perspective transform")
        if pivot != col:
            matrix[col], matrix[pivot] = matrix[pivot], matrix[col]
            vector[col], vector[pivot] = vector[pivot], vector[col]

        scale = matrix[col][col]
        matrix[col] = [value / scale for value in matrix[col]]
        vector[col] /= scale

        for row in range(8):
            if row == col:
                continue
            factor = matrix[row][col]
            if factor == 0:
                continue
            matrix[row] = [
                value - factor * pivot_value
                for value, pivot_value in zip(matrix[row], matrix[col])
            ]
            vector[row] -= factor * vector[col]

    return vector


def _content_icon_path(icon_name, root_dir):
    return root_dir / "graphics" / "icons" / f"{icon_name}.png"


def _extract_content_mark(content):
    """Remove generated paperwork bodies so only the meaningful mark remains."""
    content = content.convert("RGBA")
    pixels = content.load()
    width, height = content.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue

            brightness = max(r, g, b)
            darkness = min(r, g, b)
            saturation = brightness - darkness

            # The item paperwork generator creates light paper/form/ticket bodies.
            # Tech icons reuse the tech base paper, so drop those pale surfaces and
            # their soft shadows while keeping saturated/dark symbols, stamps, and badges.
            if brightness > 170 and darkness >= 135:
                pixels[x, y] = (r, g, b, 0)
            elif a < 120 and saturation < 45:
                pixels[x, y] = (r, g, b, 0)

    return content


def generate_technology_icon(name, content_icon_name, output_dir, root_dir):
    """Generate a technology icon by projecting an item icon onto the base paper."""
    base_path = root_dir / "graphics" / "technology" / "administrative-bureaucracy.png"
    content_path = _content_icon_path(content_icon_name, root_dir)

    base = Image.open(base_path).convert("RGBA")
    content = _extract_content_mark(Image.open(content_path))
    canvas_size = base.size[0]
    source = content.resize((canvas_size, canvas_size), Image.LANCZOS)

    src_quad = [(0, 0), (canvas_size, 0), (canvas_size, canvas_size), (0, canvas_size)]
    dst_quad = [(14, 16), (105, 3), (118, 75), (29, 89)]
    coeffs = _find_perspective_coeffs(src_quad, dst_quad)
    projected = source.transform(base.size, Image.PERSPECTIVE, coeffs, Image.BICUBIC)
    base.alpha_composite(projected)

    out_path = os.path.join(output_dir, f"{name}.png")
    base.save(out_path, "PNG")
    return out_path

def generate_icon(name, defn, output_dir):
    """Generate a single icon from its definition."""
    global SIZE, HALF, PAD

    # Scale up for supersampling
    orig_SIZE = defn.get("size", 64)
    SIZE = orig_SIZE * SUPERSAMPLE
    HALF = SIZE // 2
    PAD = 3 * SUPERSAMPLE

    base_type = defn.get("base", "paper")
    tint = defn.get("tint", C_CREAM)

    # Generate base image at supersampled size
    generator = BASE_GENERATORS.get(base_type, make_base_paper)
    img, geo = generator(tint)
    apply_material_finish(img, geo)

    # Draw text lines
    if "lines_color" in defn:
        draw_lines(img, defn["lines_color"], geo=geo)

    # Watermark (behind everything)
    if "watermark" in defn:
        wm_sym, wm_color = defn["watermark"]
        draw_watermark(img, wm_sym, wm_color)

    # Stripes
    if "stripe" in defn:
        color, pos = defn["stripe"]
        draw_stripe(img, color, pos, thickness=_s(0.11), geo=geo)
    if "stripe2" in defn:
        color, pos = defn["stripe2"]
        draw_stripe(img, color, pos, thickness=_s(0.11), geo=geo)
    if "header_bands" in defn:
        draw_header_bands(img, defn["header_bands"], thickness=_s(0.12), geo=geo)

    # Corner tab
    if "corner_tab" in defn:
        color, corner = defn["corner_tab"]
        draw_corner_tab(img, color, corner, tab_size=_s(0.22), geo=geo)

    # Stamp
    if "stamp" in defn:
        color, pos = defn["stamp"]
        draw_stamp(img, color, pos, radius=_s(0.18))

    # Symbols — main symbol is BIG (40% of canvas), secondary is corner hint
    if "symbol" in defn:
        sym_size = defn.get("symbol_size", 28) * SUPERSAMPLE
        draw_symbol(img, defn["symbol"], defn.get("symbol_color", SC_DARK),
                    defn.get("symbol_pos", "center"), sym_size)
    if "symbol2" in defn:
        sym2_size = defn.get("symbol2_size", 16) * SUPERSAMPLE
        draw_symbol(img, defn["symbol2"], defn.get("symbol2_color", SC_DARK),
                    defn.get("symbol2_pos", "br"), sym2_size)

    # Paper clip
    if defn.get("clip"):
        draw_clip(img)

    # Hole punches
    if defn.get("hole_punches"):
        draw_hole_punches(img, count=defn.get("hole_punches", 2), geo=geo)

    # Post-it
    if defn.get("post_it"):
        draw_post_it(img, color=defn.get("post_it_color", (255, 255, 50, 255)))

    # Badge
    if "badge" in defn:
        letter, bg, pos = defn["badge"]
        draw_badge(img, letter, bg, pos=pos, size_mult=1.3)

    # Downscale with LANCZOS anti-aliasing
    img = img.resize((orig_SIZE, orig_SIZE), Image.LANCZOS)

    # Restore globals
    SIZE = orig_SIZE
    HALF = SIZE // 2
    PAD = 3

    # Save
    out_path = os.path.join(output_dir, f"{name}.png")
    img.save(out_path, "PNG")
    return out_path


def generate_preview(icons, output_dir):
    """Generate a preview grid of all icons."""
    cols = 8
    rows = math.ceil(len(icons) / cols)
    # Item icons are 64px while technology artwork is normally 128px.  Use the
    # actual largest render size so --technology --preview remains useful for
    # visual QA instead of overlapping every tile.
    icon_size = max((Image.open(path).size[0] for _, path in icons), default=SIZE)
    cell = icon_size + 20
    label_h = 14
    preview = Image.new("RGBA", (cols * cell, rows * (cell + label_h)), (40, 40, 40, 255))
    draw = ImageDraw.Draw(preview)

    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 9)
    except (OSError, IOError):
        font = ImageFont.load_default()

    for i, (name, path) in enumerate(icons):
        col = i % cols
        row = i // cols
        x = col * cell + 10
        y = row * (cell + label_h) + 5

        icon = Image.open(path)
        preview.paste(icon, (x, y), icon)

        # Truncate label
        label = name[:14]
        draw.text((x, y + icon_size + 2), label, fill=(200, 200, 200, 255), font=font)

    preview_path = os.path.join(output_dir, "_preview.png")
    preview.save(preview_path, "PNG")
    return preview_path


def discover_form_items(root_dir):
    """Return forms-* item names and their dedicated generated icon stems."""
    items = {}
    item_dir = root_dir / "prototypes" / "item"
    name_pattern = re.compile(r'\bname\s*=\s*"([^"]+)"')
    subgroup_pattern = re.compile(r'\bsubgroup\s*=\s*"(forms-[^"]+)"')
    icon_pattern = re.compile(r'\bicon\s*=\s*item_icons\s*\.\.\s*"([^"]+)\.png"')

    for item_path in sorted(item_dir.glob("*.lua")):
        current_name = None
        current_icon = None
        for line in item_path.read_text(encoding="utf-8").splitlines():
            name_match = name_pattern.search(line)
            if name_match:
                current_name = name_match.group(1)
                current_icon = None
            icon_match = icon_pattern.search(line)
            if icon_match:
                current_icon = icon_match.group(1)
            if subgroup_pattern.search(line):
                if not current_name:
                    raise RuntimeError(f"form subgroup without preceding item name in {item_path}")
                items[current_name] = current_icon
    return items


def validate_form_icon_coverage(root_dir, require_files=False):
    """Fail when a forms-* item lacks a generated definition or committed PNG."""
    form_items = discover_form_items(root_dir)
    form_names = set(form_items)
    missing_defs = sorted(form_names - set(ICON_DEFS))
    if missing_defs:
        raise RuntimeError(
            "form items missing from ICON_DEFS: " + ", ".join(missing_defs)
        )

    indirect_icons = sorted(
        name for name, icon_name in form_items.items() if icon_name != name
    )
    if indirect_icons:
        raise RuntimeError(
            "form items not using their dedicated generated PNG: "
            + ", ".join(indirect_icons)
        )

    if require_files:
        icon_dir = root_dir / "graphics" / "icons"
        missing_files = sorted(
            name for name in form_names if not (icon_dir / f"{name}.png").is_file()
        )
        if missing_files:
            raise RuntimeError(
                "generated form PNGs missing: " + ", ".join(missing_files)
            )
    return form_names


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Generate Administratorio paperwork icons")
    parser.add_argument("--output", "-o", default=None,
                        help="Output directory (default: graphics/icons/generated/)")
    parser.add_argument("--preview", "-p", action="store_true",
                        help="Generate a preview grid image")
    parser.add_argument("--only", nargs="*",
                        help="Only generate specific icon names")
    parser.add_argument("--technology", action="store_true",
                        help="Generate technology icons instead of item icons")
    parser.add_argument("--list", action="store_true",
                        help="List all available icon names")
    parser.add_argument("--check-coverage", action="store_true",
                        help="Verify every forms-* item has a definition and generated PNG")
    args = parser.parse_args()

    script_dir = Path(__file__).parent.parent
    form_names = validate_form_icon_coverage(script_dir, require_files=args.check_coverage)

    if args.check_coverage:
        print(f"Form icon coverage complete: {len(form_names)} items")
        return

    if args.list:
        if args.technology:
            for name, source in sorted(TECH_ICON_DEFS.items()):
                print(f"  {name:40s} from {source}")
        else:
            for name, defn in sorted(ICON_DEFS.items()):
                print(f"  {name:40s} {defn.get('desc', '')}")
        return

    # Default output to graphics/icons/ or graphics/technology relative to script
    if args.output:
        output_dir = args.output
    elif args.technology:
        output_dir = str(script_dir / "graphics" / "technology")
    else:
        output_dir = str(script_dir / "graphics" / "icons")

    os.makedirs(output_dir, exist_ok=True)

    # Filter icons if --only specified
    defs = TECH_ICON_DEFS if args.technology else ICON_DEFS
    if args.only:
        defs = {k: v for k, v in defs.items() if k in args.only}
        missing = set(args.only) - set(defs.keys())
        if missing:
            print(f"Warning: unknown icon names: {', '.join(sorted(missing))}")

    # Generate
    generated = []
    for name, defn in sorted(defs.items()):
        if args.technology:
            path = generate_technology_icon(name, defn, output_dir, script_dir)
        else:
            path = generate_icon(name, defn, output_dir)
        generated.append((name, path))
        print(f"  Generated: {name}")

    print(f"\n{len(generated)} icons written to {output_dir}")

    if args.preview:
        preview_path = generate_preview(generated, output_dir)
        print(f"Preview grid: {preview_path}")


if __name__ == "__main__":
    main()
