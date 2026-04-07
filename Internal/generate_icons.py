#!/usr/bin/env python3
"""
Administratorio Icon Generator
===============================
Generates distinct 64x64 paperwork icons from a base paper sheet image
by applying overlays, symbols, tints, stamps, and colored accents.

Usage:
    python generate_icons.py [--base PATH] [--output DIR] [--preview]

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
"""

import argparse
import math
import os
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
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
    # Tab highlight
    lw = max(1, _s(0.03))
    draw.line([_sp(0.30, 0.13), _sp(0.63, 0.13)], fill=(190, 170, 140, 200), width=lw)
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
    elif position == "bottom":
        t = thickness / max(1, ((bl[1] - tl[1]) + (br[1] - tr[1])) / 2)
        p0 = _lerp(tl, bl, 1 - t)
        p1 = _lerp(tr, br, 1 - t)
        p2 = br
        p3 = bl
        draw.polygon([p0, p1, p2, p3], fill=color)
    elif position == "left":
        t = thickness / max(1, ((tr[0] - tl[0]) + (br[0] - bl[0])) / 2)
        p0 = tl
        p1 = _lerp(tl, tr, t)
        p2 = _lerp(bl, br, t)
        p3 = bl
        draw.polygon([p0, p1, p2, p3], fill=color)
    elif position == "right":
        t = thickness / max(1, ((tr[0] - tl[0]) + (br[0] - bl[0])) / 2)
        p0 = _lerp(tl, tr, 1 - t)
        p1 = tr
        p2 = br
        p3 = _lerp(bl, br, 1 - t)
        draw.polygon([p0, p1, p2, p3], fill=color)


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
    
    # Thick pure white background halo
    hw = max(2, radius // 5)
    draw.ellipse([(cx - radius - hw, cy - radius - hw), (cx + radius + hw, cy + radius + hw)],
                 outline=(255, 255, 255, 255), width=sw + hw*2)

    # Outer ring
    draw.ellipse([(cx - radius, cy - radius), (cx + radius, cy + radius)],
                 outline=color, width=sw)
    # Inner smaller circle
    r2 = radius - sw * 2
    if r2 > 2:
        draw.ellipse([(cx - r2, cy - r2), (cx + r2, cy + r2)],
                     outline=(*color[:3], color[3] // 2), width=max(1, sw // 2))


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
    
    # Thick pure white border for the tab
    draw.polygon(pts, outline=(255, 255, 255, 255), width=max(2, SIZE // 32))
    draw.polygon(pts, fill=color)


def draw_clip(img, color=(150, 150, 160, 200)):
    """Draw a paper clip at the top."""
    draw = ImageDraw.Draw(img)
    cx = HALF
    s = max(1, SIZE // 64)  # scale factor
    # Thick pure white halo
    draw.rounded_rectangle([(cx - 4*s - 2*s, 1*s - 2*s), (cx + 4*s + 2*s, 18*s + 2*s)], radius=4*s,
                           outline=(255, 255, 255, 255), width=4*s)
    
    draw.rounded_rectangle([(cx - 4*s, 1*s), (cx + 4*s, 18*s)], radius=3*s,
                           outline=color, width=2*s)
    draw.rounded_rectangle([(cx - 2*s, 4*s), (cx + 2*s, 14*s)], radius=2*s,
                           outline=color, width=1*s)


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
        # Thick pure white highlight
        draw.ellipse([(p[0] - r - 2, p[1] - r - 2), (p[0] + r + 2, p[1] + r + 2)], fill=(255, 255, 255, 255))
        draw.ellipse([(p[0] - r, p[1] - r), (p[0] + r, p[1] + r)], fill=(0, 0, 0, 200))


def draw_post_it(img, color=(255, 255, 50, 255)):
    """Draw a small yellow post-it note in the bottom right corner."""
    draw = ImageDraw.Draw(img)
    x0, y0, x1, y1 = _s(0.60), _s(0.65), _s(0.92), _s(0.92)
    # Shadow
    sh = max(1, _s(0.01))
    draw.rectangle([(x0 + sh, y0 + sh), (x1 + sh, y1 + sh)], fill=(0, 0, 0, 80))
    # Thick pure white border
    bw = max(2, _s(0.02))
    draw.rectangle([(x0 - bw, y0 - bw), (x1 + bw, y1 + bw)], outline=(255, 255, 255, 255), width=bw)
    # Note
    draw.rectangle([(x0, y0), (x1, y1)], fill=color, outline=(150, 150, 0, 255))
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
        inset = max(2, size // 5)
        draw.ellipse([(cx - r + inset, cy - r + inset), (cx + r - inset, cy + r - inset)], outline=color, width=w)
        tooth = max(2, size // 8)
        for angle in range(0, 360, 45):
            rad = math.radians(angle)
            x1 = cx + int((r - tooth) * math.cos(rad))
            y1 = cy + int((r - tooth) * math.sin(rad))
            x2 = cx + int(r * math.cos(rad))
            y2 = cy + int(r * math.sin(rad))
            draw.line([(x1, y1), (x2, y2)], fill=color, width=w)

    elif name == SYM_PICKAXE:
        draw.line([(cx - hs, cy + hs), (cx + hs // 2, cy - hs // 2)], fill=color, width=w)
        d = max(2, size // 4)
        draw.line([(cx + hs // 2 - d, cy - hs // 2 - d // 2), (cx + hs, cy - hs + d // 2)], fill=color, width=w)
        draw.line([(cx + hs // 2 + d // 2, cy - hs // 2 + d), (cx + hs - d // 2, cy + d // 2)], fill=color, width=w)

    elif name == SYM_SHIELD:
        pts = [(cx, cy - hs), (cx + hs, cy - hs // 3), (cx + hs - w, cy + hs // 2),
               (cx, cy + hs), (cx - hs + w, cy + hs // 2), (cx - hs, cy - hs // 3)]
        draw.polygon(pts, outline=color, width=w)

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
        neck = max(2, size // 8)
        draw.line([(cx - neck, cy - hs), (cx + neck, cy - hs)], fill=color, width=w)
        draw.line([(cx - neck, cy - hs), (cx - hs + w, cy + hs - w)], fill=color, width=w)
        draw.line([(cx + neck, cy - hs), (cx + hs - w, cy + hs - w)], fill=color, width=w)
        draw.line([(cx - hs + w, cy + hs - w), (cx + hs - w, cy + hs - w)], fill=color, width=w)
        draw.rectangle([(cx - hs + w + 2, cy + 1), (cx + hs - w - 2, cy + hs - w - 1)], fill=(*color[:3], 80))

    elif name == SYM_HAMMER:
        draw.line([(cx - 1, cy - hs), (cx - 1, cy + hs)], fill=color, width=w)
        head_h = max(4, size // 3)
        draw.rectangle([(cx - hs, cy - hs), (cx + w, cy - hs + head_h)], fill=color)

    elif name == SYM_SCALES:
        draw.line([(cx, cy - hs), (cx, cy + hs // 2)], fill=color, width=w)
        draw.line([(cx - hs, cy - hs // 3), (cx + hs, cy - hs // 3)], fill=color, width=w)
        draw.arc([(cx - hs - w, cy - hs // 3), (cx - hs // 3, cy + hs // 3)], 0, 180, fill=color, width=max(1, w // 2))
        draw.arc([(cx + hs // 3, cy - hs // 3), (cx + hs + w, cy + hs // 3)], 0, 180, fill=color, width=max(1, w // 2))
        base_w = max(3, size // 5)
        draw.rectangle([(cx - base_w, cy + hs // 2), (cx + base_w, cy + hs)], fill=color)

    elif name == SYM_LEAF:
        draw.ellipse([(cx - hs + w, cy - hs + w), (cx + hs - w, cy + hs - w * 2)], fill=(*color[:3], 100))
        draw.arc([(cx - hs + w, cy - hs + w), (cx + hs - w, cy + hs - w * 2)], 0, 360, fill=color, width=w)
        draw.line([(cx, cy - hs + w * 2), (cx, cy + hs - w * 2)], fill=color, width=max(1, w // 2))

    elif name == SYM_LIGHTNING:
        d = max(2, size // 5)
        pts = [(cx + d, cy - hs), (cx - d, cy), (cx + d, cy), (cx - d, cy + hs)]
        draw.line(pts, fill=color, width=w)

    elif name == SYM_SPEECH:
        draw.ellipse([(cx - hs, cy - hs), (cx + hs, cy + hs // 3)], outline=color, width=w)
        tail = max(2, size // 6)
        draw.polygon([(cx - tail, cy + hs // 3), (cx - hs // 2, cy + hs), (cx + tail * 2, cy + hs // 3 - 1)], fill=color)

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
        draw.arc([(cx - hs // 2, cy - hs), (cx + hs // 2, cy + hs // 4)], 180, 45, fill=color, width=w)
        draw.line([(cx, cy + hs // 4 - w), (cx, cy + hs // 3 + w)], fill=color, width=w)
        ew = max(2, size // 7)
        draw.ellipse([(cx - ew, cy + hs // 2), (cx + ew, cy + hs)], fill=color)

    elif name == SYM_STAMP_CIRCLE:
        draw.ellipse([(cx - r, cy - r), (cx + r, cy + r)], outline=color, width=w + max(1, w // 2))
        draw.line([(cx - r + w * 2, cy), (cx + r - w * 2, cy)], fill=color, width=w)

    elif name == SYM_MAGNIFIER:
        draw.ellipse([(cx - hs + w, cy - hs + w), (cx + hs // 3, cy + hs // 3)], outline=color, width=w)
        draw.line([(cx + hs // 3, cy + hs // 3), (cx + hs, cy + hs)], fill=color, width=w)

    elif name == SYM_PEN:
        draw.line([(cx - hs, cy + hs), (cx + hs // 2, cy - hs)], fill=color, width=w)
        nib = max(2, size // 5)
        draw.polygon([(cx - hs, cy + hs), (cx - hs + nib, cy + hs - w), (cx - hs + w, cy + hs - nib)], fill=color)

    elif name == SYM_GAVEL:
        draw.line([(cx - hs + w, cy + hs - w), (cx + w, cy - w)], fill=color, width=w)
        head_h = max(4, size // 3)
        draw.rectangle([(cx - w, cy - hs), (cx + hs - w, cy - hs + head_h)], fill=color)

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
        draw.line([(cx - hs, cy), (cx - w, cy + w * 2)], fill=color, width=w)
        draw.line([(cx + hs, cy), (cx + w, cy + w * 2)], fill=color, width=w)
        draw.line([(cx - w, cy + w * 2), (cx + w, cy + w * 2)], fill=color, width=w + max(1, w // 2))

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
    """Draw a symbol on the image."""
    draw = ImageDraw.Draw(img)
    cx, cy = _pos_offset(pos, size)

    # Use a single, high-contrast halo
    # Center symbols get white (pops against saturated paper)
    # Corner symbols get black (appendix look)
    if pos == "center":
        halo_color = (255, 255, 255, 255)
        off = max(1, SIZE // 64)
    else:
        halo_color = (0, 0, 0, 255)
        off = max(1, SIZE // 128) # Thinner for corner elements
        
    # Draw 8-way halo
    for dx in [-off, 0, off]:
        for dy in [-off, 0, off]:
            if dx == 0 and dy == 0: continue
            _draw_symbol(draw, name, cx + dx, cy + dy, halo_color, size)

    _draw_symbol(draw, name, cx, cy, color, size)

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
    "petrochemical-operating-permit": {
        "base": "ledger", "tint": C_LIGHT_GREEN,
        "symbol": SYM_FLASK, "symbol_color": SC_GREEN, "symbol_pos": "center",
        "symbol2": SYM_WARNING, "symbol2_color": SC_ORANGE, "symbol2_pos": "br",
        "badge": ("P", S_DARK_GREEN, "bl"),
        "desc": "Green ledger permit with flask, warning, and P badge",
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
        "symbol2": SYM_GEAR, "symbol2_color": SC_DARK, "symbol2_pos": "br",
        "hole_punches": 2,
        "desc": "Blue form, shield + gear + hole punches",
    },
    "construction-work-order": {
        "base": "form", "tint": C_LIGHT_ORANGE,
        "symbol": SYM_HAMMER, "symbol_color": SC_ORANGE, "symbol_pos": "center",
        "symbol2": SYM_GEAR, "symbol2_color": SC_DARK, "symbol2_pos": "br",
        "hole_punches": 2,
        "desc": "Orange form, hammer + gear + hole punches",
    },
    "management-verbal-work-order": {
        "base": "form", "tint": C_LIGHT_YELLOW,
        "symbol": SYM_SPEECH, "symbol_color": SC_GOLD, "symbol_pos": "center",
        "symbol2": SYM_GEAR, "symbol2_color": SC_DARK, "symbol2_pos": "br",
        "hole_punches": 2,
        "desc": "Yellow form, speech + gear + hole punches",
    },
    "management-written-work-order": {
        "base": "form", "tint": C_LIGHT_PURPLE,
        "symbol": SYM_PEN, "symbol_color": SC_PURPLE, "symbol_pos": "center",
        "symbol2": SYM_GEAR, "symbol2_color": SC_DARK, "symbol2_pos": "br",
        "hole_punches": 2,
        "desc": "Purple form, pen + gear + hole punches",
    },
    "research-grant-work-order": {
        "base": "form", "tint": (230, 240, 255, 255),
        "symbol": SYM_FLASK, "symbol_color": SC_BLUE, "symbol_pos": "center",
        "symbol2": SYM_GEAR, "symbol2_color": SC_DARK, "symbol2_pos": "br",
        "hole_punches": 2,
        "desc": "Blue form, flask + gear + hole punches",
    },
    "chemical-handling-work-order": {
        "base": "form", "tint": (220, 245, 245, 255),
        "stripe": (S_TEAL, "top"),
        "symbol": SYM_FLASK, "symbol_color": SC_TEAL, "symbol_pos": "center",
        "symbol2": SYM_GEAR, "symbol2_color": SC_DARK, "symbol2_pos": "br",
        "badge": ("C", S_TEAL, "bl"),
        "hole_punches": 2,
        "desc": "Teal chemistry work order with flask, gear, and C badge",
    },
    "radiological-work-order": {
        "base": "form", "tint": (240, 255, 230, 255),
        "stripe": (S_DARK_RED, "top"),
        "symbol": SYM_BIOHAZARD, "symbol_color": SC_DARK, "symbol_pos": "center",
        "symbol2": SYM_GEAR, "symbol2_color": SC_DARK, "symbol2_pos": "br",
        "badge": ("R", S_DARK_RED, "bl"),
        "hole_punches": 2,
        "desc": "Radiological work order with biohazard, gear, and R badge",
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

# ---------------------------------------------------------------------------
# Icon generation
# ---------------------------------------------------------------------------

# Supersample factor: draw at Nx size, then downscale with LANCZOS for anti-aliasing
SUPERSAMPLE = 3

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
    cell = SIZE + 20
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
        draw.text((x, y + SIZE + 2), label, fill=(200, 200, 200, 255), font=font)

    preview_path = os.path.join(output_dir, "_preview.png")
    preview.save(preview_path, "PNG")
    return preview_path


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
    parser.add_argument("--list", action="store_true",
                        help="List all available icon names")
    args = parser.parse_args()

    if args.list:
        for name, defn in sorted(ICON_DEFS.items()):
            print(f"  {name:40s} {defn.get('desc', '')}")
        return

    # Default output to graphics/icons/ relative to script
    if args.output:
        output_dir = args.output
    else:
        script_dir = Path(__file__).parent.parent
        output_dir = str(script_dir / "graphics" / "icons")

    os.makedirs(output_dir, exist_ok=True)

    # Filter icons if --only specified
    defs = ICON_DEFS
    if args.only:
        defs = {k: v for k, v in ICON_DEFS.items() if k in args.only}
        missing = set(args.only) - set(defs.keys())
        if missing:
            print(f"Warning: unknown icon names: {', '.join(sorted(missing))}")

    # Generate
    generated = []
    for name, defn in sorted(defs.items()):
        path = generate_icon(name, defn, output_dir)
        generated.append((name, path))
        print(f"  Generated: {name}")

    print(f"\n{len(generated)} icons written to {output_dir}")

    if args.preview:
        preview_path = generate_preview(generated, output_dir)
        print(f"Preview grid: {preview_path}")


if __name__ == "__main__":
    main()
