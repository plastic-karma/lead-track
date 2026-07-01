#!/usr/bin/env python3
"""Generate the lead-track app icon (1024x1024) and its dark/tinted variants.

The design: a warm radial-gradient background with three concentric,
round-capped arcs (outer gray, middle khaki, inner cream) arranged as an
aperture/pinwheel, plus a small gold dot in the centre.

Rendered at 4x supersampling then downscaled for clean anti-aliasing.
"""
import math
import sys
from PIL import Image, ImageDraw

SIZE = 1024
SS = 4  # supersample factor
S = SIZE * SS
CX = CY = S / 2


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def radial_background(inner, outer, glow=(24, 14, 6), glow_sigma=0.20,
                      glow_shift=(0.0, -0.05), gamma=1.25):
    """Radial gradient inner->outer, plus a soft additive core halo."""
    import numpy as np
    gx = CX + glow_shift[0] * S
    gy = CY + glow_shift[1] * S
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    dx, dy = xx - gx, yy - gy
    dist = np.sqrt(dx * dx + dy * dy)
    maxd = math.hypot(max(gx, S - gx), max(gy, S - gy))
    t = np.clip(dist / maxd, 0, 1) ** gamma
    base = np.stack([inner[i] + (outer[i] - inner[i]) * t for i in range(3)], -1)
    halo = np.exp(-(dist / (glow_sigma * S)) ** 2)[..., None]
    arr = np.clip(base + halo * np.array(glow, np.float32), 0, 255)
    return Image.fromarray(arr.astype("uint8"), "RGB")


def draw_arc(draw, cx, cy, radius, width, gap_center_deg, gap_width_deg, color):
    """Round-capped arc by stamping overlapping discs along the centreline.

    Angles are clock-style: 0 deg = top (12 o'clock), increasing clockwise.
    A gap of `gap_width_deg` is centred on `gap_center_deg`; the solid arc is
    the remaining sweep.
    """
    r = width / 2
    start = gap_center_deg + gap_width_deg / 2
    sweep = 360 - gap_width_deg
    steps = max(2, int(radius * math.radians(sweep) / (SS * 0.6)))
    for i in range(steps + 1):
        a = math.radians(start + sweep * i / steps)
        x = cx + radius * math.sin(a)
        y = cy - radius * math.cos(a)
        draw.ellipse((x - r, y - r, x + r, y + r), fill=color)


# Ring geometry (in 1x px, scaled by SS). (radius, width, gap_center, gap_width)
RINGS = [
    dict(radius=332, width=34, gap_center=180, gap_width=98),  # outer gray
    dict(radius=250, width=34, gap_center=70,  gap_width=98),  # middle khaki
    dict(radius=168, width=42, gap_center=286, gap_width=98),  # inner cream
]
DOT = dict(radius=44)


def compose(bg, ring_colors, dot_color):
    img = bg.copy()
    draw = ImageDraw.Draw(img)
    for ring, color in zip(RINGS, ring_colors):
        draw_arc(draw, CX, CY,
                 ring["radius"] * SS, ring["width"] * SS,
                 ring["gap_center"], ring["gap_width"], color)
    r = DOT["radius"] * SS
    draw.ellipse((CX - r, CY - r, CX + r, CY + r), fill=dot_color)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def build_light():
    bg = radial_background(inner=(210, 139, 80), outer=(148, 83, 39))
    return compose(bg,
                   ring_colors=[(131, 126, 126), (180, 166, 120), (241, 234, 222)],
                   dot_color=(233, 166, 66))


def build_dark():
    bg = radial_background(inner=(150, 92, 46), outer=(74, 41, 20))
    return compose(bg,
                   ring_colors=[(150, 146, 146), (190, 176, 128), (244, 238, 228)],
                   dot_color=(236, 170, 72))


def build_tinted():
    """Grayscale-on-black source; iOS multiplies by the user's tint colour."""
    bg = Image.new("RGB", (S, S), (0, 0, 0))
    return compose(bg,
                   ring_colors=[(120, 120, 120), (175, 175, 175), (240, 240, 240)],
                   dot_color=(235, 235, 235))


BUILDERS = {"light": build_light, "dark": build_dark, "tinted": build_tinted}

if __name__ == "__main__":
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    which = sys.argv[2:] or list(BUILDERS)
    for name in which:
        path = f"{out_dir}/icon_{name}.png"
        BUILDERS[name]().save(path)
        print("wrote", path)
