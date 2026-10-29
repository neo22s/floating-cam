# Floating Camera — MIT License. See LICENSE.
"""Regenerate README artwork (hero.png, shapes.png) with Pillow.

Usage:
    python3 assets/generate.py

Everything is drawn in code (no photo assets needed): dark gradient
wallpaper, bokeh-filled floating shapes with white borders and soft
shadows, Avenir/Helvetica labels. Rendered at 2x for retina crispness.
"""

import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SS = 2  # render scale (2x retina)
RND = random.Random(7)

AVENIR_BOLD = "/System/Library/Fonts/Avenir Next.ttc"
AVENIR_DEMI = "/System/Library/Fonts/Avenir Next.ttc"
AVENIR_MED = "/System/Library/Fonts/Avenir Next.ttc"
AVENIR_REG = "/System/Library/Fonts/Avenir Next.ttc"
HELV = "/System/Library/Fonts/HelveticaNeue.ttc"

IDX = {"bold": 0, "demi": 2, "med": 5, "reg": 7, "helv": 0, "helv_b": 1}


def font(kind, size):
    if kind == "helv":
        return ImageFont.truetype(HELV, size, index=IDX["helv"])
    if kind == "helv_b":
        return ImageFont.truetype(HELV, size, index=IDX["helv_b"])
    return ImageFont.truetype(AVENIR_BOLD, size, index=IDX[kind])


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vgradient(size, top, bottom):
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    for y in range(h):
        c = lerp(top, bottom, y / max(1, h - 1))
        for x in range(w):
            px[x, y] = c
    return img


def wallpaper(w, h):
    """Dark gradient + soft color blobs, rendered small then upscaled."""
    sw, sh = w // 4, h // 4
    base = vgradient((sw, sh), (26, 31, 52), (9, 12, 24))
    blobs = Image.new("RGB", (sw, sh), (0, 0, 0))
    d = ImageDraw.Draw(blobs)
    for (bx, by, br, col) in [
        (0.22, 0.30, 0.42, (79, 70, 229)),
        (0.80, 0.22, 0.36, (14, 165, 233)),
        (0.62, 0.85, 0.44, (217, 70, 239)),
        (0.10, 0.90, 0.30, (16, 122, 120)),
    ]:
        d.ellipse(
            [sw * bx - sw * br, sh * by - sh * br,
             sw * bx + sw * br, sh * by + sh * br],
            fill=col,
        )
    blobs = blobs.filter(ImageFilter.GaussianBlur(18))
    base_arr = np.array(vgradient((sw, sh), (26, 31, 52), (9, 12, 24)),
                        dtype=int)
    blob_arr = (np.array(blobs, dtype=int) * 0.5).astype(int)
    base = Image.fromarray((base_arr + blob_arr).clip(0, 255).astype("uint8"))
    return base.resize((w, h), Image.BICUBIC)


# ---------------------------------------------------------------- shapes

def shape_mask(kind, box, radius=0, supersample=4):
    """White shape on black, supersampled for smooth edges."""
    x0, y0, x1, y1 = box
    w, h = int(x1 - x0), int(y1 - y0)
    s = supersample
    img = Image.new("L", (w * s, h * s), 0)
    d = ImageDraw.Draw(img)
    cx, cy = w * s / 2, h * s / 2

    def pt(angle, r):
        return (cx + math.cos(angle) * r, cy + math.sin(angle) * r)

    if kind in ("rect", "rounded", "square", "capsule", "vertical"):
        r = radius * s
        if kind == "capsule":
            r = min(w, h) * s / 2
        d.rounded_rectangle([0, 0, w * s - 1, h * s - 1], radius=r, fill=255)
    elif kind == "circle":
        d.ellipse([0, 0, w * s - 1, h * s - 1], fill=255)
    elif kind in ("hexagon", "pentagon", "diamond"):
        sides = {"hexagon": 6, "pentagon": 5, "diamond": 4}[kind]
        start = {"hexagon": 0.0, "pentagon": -math.pi / 2,
                 "diamond": -math.pi / 2}[kind]
        R = min(w, h) * s / 2
        d.polygon([pt(start + i * 2 * math.pi / sides, R)
                   for i in range(sides)], fill=255)
    elif kind == "star":
        R = min(w, h) * s / 2
        r = R * 0.44
        pts = []
        for i in range(10):
            rr = R if i % 2 == 0 else r
            pts.append(pt(-math.pi / 2 + i * math.pi / 5, rr))
        d.polygon(pts, fill=255)
    elif kind == "heart":
        # Same cubic curves as ShapeGeometry.heart. The app draws in
        # y-up coordinates, so flip y for the y-down image space.
        segs = [
            ((0.5, 0.03), (0.16, 0.27), (0.03, 0.51), (0.03, 0.68)),
            ((0.03, 0.68), (0.03, 0.98), (0.30, 0.99), (0.5, 0.86)),
            ((0.5, 0.86), (0.70, 0.99), (0.97, 0.98), (0.97, 0.68)),
            ((0.97, 0.68), (0.97, 0.51), (0.84, 0.27), (0.5, 0.03)),
        ]
        pts = []
        for (p0, p1, p2, p3) in segs:
            for i in range(32):
                t = i / 32
                mt = 1 - t
                x = (mt ** 3 * p0[0] + 3 * mt * mt * t * p1[0]
                     + 3 * mt * t * t * p2[0] + t ** 3 * p3[0])
                y = (mt ** 3 * p0[1] + 3 * mt * mt * t * p1[1]
                     + 3 * mt * t * t * p2[1] + t ** 3 * p3[1])
                pts.append((x * w * s, (1 - y) * h * s))
        d.polygon(pts, fill=255)
    return img.resize((w, h), Image.LANCZOS)


def shape_fill(size, c1, c2, bokeh=True, seed=1):
    """Glossy gradient fill with bokeh dots, returns RGBA."""
    w, h = size
    rnd = random.Random(seed)
    base = vgradient((w, h), c1, c2).convert("RGBA")
    if bokeh:
        dots = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(dots)
        for _ in range(26):
            r = rnd.randint(max(4, w // 70), max(10, w // 22))
            x, y = rnd.randint(0, w), rnd.randint(0, h)
            d.ellipse([x - r, y - r, x + r, y + r],
                      fill=(255, 255, 255, rnd.randint(8, 26)))
        dots = dots.filter(ImageFilter.GaussianBlur(max(3, w // 36)))
        base = Image.alpha_composite(base, dots)
    topmask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(topmask).rectangle([0, 0, w, int(h * 0.4)], fill=255)
    base = Image.composite(
        Image.alpha_composite(base, Image.new("RGBA", (w, h), (255, 255, 255, 32))),
        base, topmask.filter(ImageFilter.GaussianBlur(30)))
    botmask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(botmask).rectangle([0, int(h * 0.65), w, h], fill=255)
    base = Image.composite(
        Image.alpha_composite(base, Image.new("RGBA", (w, h), (0, 0, 20, 48))),
        base, botmask.filter(ImageFilter.GaussianBlur(30)))
    return base


def floating_shape(canvas, xy, size, kind, c1, c2, radius=0, border=4,
                   seed=1, shadow_alpha=105, shadow_blur=20, shadow_dy=22):
    """Paste a floating app-like shape onto canvas. xy = top-left (2x px)."""
    w, h = size
    mask = shape_mask(kind, (0, 0, w, h), radius=radius)
    # shadow
    sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    black = Image.new("RGBA", (w, h), (0, 0, 0, shadow_alpha))
    sh.paste(black, (xy[0], xy[1] + shadow_dy), mask)
    sh = sh.filter(ImageFilter.GaussianBlur(shadow_blur))
    canvas.alpha_composite(sh)
    # fill
    fill = shape_fill((w, h), c1, c2, seed=seed)
    canvas.paste(fill, xy, mask)
    # white border ring
    ring = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    bw = border
    inset = bw // 2
    if kind in ("rect", "rounded", "square", "capsule", "vertical"):
        r = radius if kind != "capsule" else min(w, h) / 2
        rd.rounded_rectangle([inset, inset, w - inset - 1, h - inset - 1],
                             radius=max(0, r - inset), outline=(255, 255, 255, 235),
                             width=bw)
    elif kind == "circle":
        rd.ellipse([inset, inset, w - inset - 1, h - inset - 1],
                   outline=(255, 255, 255, 235), width=bw)
    else:
        # polygon outline from mask edge
        edge = mask.filter(ImageFilter.FIND_EDGES)
        edge = edge.filter(ImageFilter.GaussianBlur(1.2))
        white = Image.new("RGBA", (w, h), (255, 255, 255, 235))
        canvas.paste(white, xy, edge.point(lambda v: min(255, v * 3)))
        return
    canvas.alpha_composite(ring, xy)


def centered_text(draw, cx, y, text, fnt, fill):
    l, t, r, b = draw.textbbox((0, 0), text, font=fnt)
    draw.text((cx - (r - l) / 2, y), text, font=fnt, fill=fill)


def translucent(canvas, draw_fn):
    """Run draw_fn on a transparent overlay and composite it over canvas.

    (Pillow's ImageDraw does not blend alpha onto the target, so all
    translucent UI is drawn on a separate layer.)
    """
    ov = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(ov))
    canvas.alpha_composite(ov)
    return ImageDraw.Draw(canvas)


# ---------------------------------------------------------------- hero

def make_hero(path):
    S = SS
    W, H = 1600 * S, 900 * S
    img = wallpaper(W, H).convert("RGBA")

    # ghost windows behind
    def ghosts(g):
        for (x, y, w, h, a) in [(140 * S, 210 * S, 420 * S, 300 * S, 16),
                                (1050 * S, 620 * S, 520 * S, 200 * S, 12)]:
            g.rounded_rectangle([x, y, x + w, y + h], radius=18 * S,
                                fill=(255, 255, 255, a),
                                outline=(255, 255, 255, 34), width=2 * S)
    d = translucent(img, ghosts)

    # menu bar
    bar_h = 34 * S
    d = translucent(img, lambda g: g.rectangle(
        [0, 0, W, bar_h], fill=(5, 6, 12, 165)))
    d.text((18 * S, 7 * S), "Floating Camera", font=font("demi", 21 * S),
           fill=(255, 255, 255, 255))
    right = "Tue 9:41   "
    f_small = font("helv", 20 * S)
    l, t, r, b = d.textbbox((0, 0), right, font=f_small)
    d.text((W - (r - l) - 120 * S, 8 * S), right, font=f_small,
           fill=(255, 255, 255, 220))
    # active camera pill (aperture-ish dot)
    px, py, pw, ph = W - 104 * S, 6 * S, 88 * S, 22 * S
    d.rounded_rectangle([px, py, px + pw, py + ph], radius=11 * S,
                        fill=(10, 132, 255, 255))
    d.ellipse([px + 8 * S, py + 4 * S, px + 26 * S, py + ph - 4 * S],
              outline=(255, 255, 255, 255), width=3 * S)
    d.ellipse([px + 13 * S, py + 8 * S, px + 21 * S, py + ph - 8 * S],
              fill=(255, 255, 255, 255))

    # floating shapes
    floating_shape(img, (150 * S, 330 * S), (300 * S, 300 * S), "circle",
                   (244, 63, 94), (159, 18, 57), seed=11)
    floating_shape(img, (560 * S, 300 * S), (300 * S, 300 * S), "rounded",
                   (236, 72, 153), (157, 23, 77), radius=52 * S, seed=12)
    floating_shape(img, (960 * S, 170 * S), (212 * S, 377 * S), "vertical",
                   (192, 132, 252), (109, 40, 217), radius=30 * S, seed=13)
    floating_shape(img, (1260 * S, 420 * S), (200 * S, 133 * S), "capsule",
                   (148, 163, 184), (71, 85, 105), seed=14)

    # wordmark
    d.text((80 * S, 690 * S), "Floating Camera", font=font("demi", 62 * S),
           fill=(255, 255, 255, 255))
    d.text((82 * S, 772 * S), "Your face, everywhere. Literally.",
           font=font("helv", 32 * S), fill=(195, 201, 214, 255))
    # platform pill
    pill = "macOS 14+  ·  Free  ·  MIT"
    fp = font("helv_b", 22 * S)
    l, t, r, b = d.textbbox((0, 0), pill, font=fp)
    tw = (r - l) + 44 * S
    px0, py0 = W - tw - 60 * S, 780 * S
    d = translucent(img, lambda g: g.rounded_rectangle(
        [px0, py0, px0 + tw, py0 + 44 * S], radius=22 * S,
        fill=(255, 255, 255, 28)))
    d.text((px0 + 22 * S, py0 + 9 * S), pill, font=fp,
           fill=(255, 255, 255, 230))

    img.convert("RGB").save(path, optimize=True)


# ---------------------------------------------------------------- grid

SHAPES = [
    # key, label, sub, colors, kind, box-fit w/h, radius(logical), seed
    ("rect", "Rectangle", "16:9 · native", ((79, 140, 255), (30, 80, 200)),
     "rect", (340, 191), 40, 21, False),
    ("vertical", "Vertical Rectangle", "9:16", ((192, 132, 252), (109, 40, 217)),
     "vertical", (135, 240), 30, 22, True),
    ("rounded", "Rounded Square", "1:1", ((236, 72, 153), (157, 23, 77)),
     "rounded", (240, 240), 56, 23, False),
    ("square", "Square", "1:1", ((239, 68, 68), (153, 27, 27)),
     "square", (240, 240), 0, 24, False),
    ("circle", "Circle", "1:1", ((251, 113, 133), (190, 18, 60)),
     "circle", (240, 240), 0, 25, False),
    ("heart", "Heart", "1:1", ((251, 146, 60), (194, 65, 12)),
     "heart", (240, 240), 0, 26, False),
    ("star", "Star", "1:1", ((251, 191, 36), (180, 83, 9)),
     "star", (250, 250), 0, 27, False),
    ("hexagon", "Hexagon", "1:1", ((74, 222, 128), (21, 128, 61)),
     "hexagon", (250, 240), 0, 28, False),
    ("pentagon", "Pentagon", "1:1", ((34, 211, 238), (14, 116, 144)),
     "pentagon", (250, 240), 0, 29, False),
    ("diamond", "Diamond", "1:1", ((129, 140, 248), (67, 56, 202)),
     "diamond", (240, 240), 0, 30, False),
    ("capsule", "Capsule", "3:2", ((203, 213, 225), (71, 85, 105)),
     "capsule", (340, 227), 0, 31, False),
]


def make_shapes(path):
    S = SS
    COLS = 4
    CELL_W, SHAPE_H, LABEL_H = 400 * S, 270 * S, 96 * S
    PAD, HEAD = 48 * S, 190 * S
    rows = (len(SHAPES) + COLS - 1) // COLS
    W = COLS * CELL_W + PAD * 2
    H = HEAD + rows * (SHAPE_H + LABEL_H) + PAD

    img = wallpaper(W, H).convert("RGBA")
    d = ImageDraw.Draw(img)

    centered_text(d, W / 2, 52 * S, "Pick your shape.", font("demi", 54 * S),
                  (255, 255, 255, 255))
    centered_text(d, W / 2, 122 * S, "11 shapes · one floating camera",
                  font("helv", 28 * S), (160, 167, 184, 255))

    for i, (key, label, sub, (c1, c2), kind, (bw, bh), rad, seed, new) in \
            enumerate(SHAPES):
        row, col = divmod(i, COLS)
        # center last row
        per_row = COLS if row < rows - 1 else len(SHAPES) - (rows - 1) * COLS
        xoff = (W - per_row * CELL_W) / 2
        cx = xoff + col * CELL_W + CELL_W / 2
        top = HEAD + row * (SHAPE_H + LABEL_H)
        w, h = bw * S, bh * S
        floating_shape(img, (int(cx - w / 2), int(top + (SHAPE_H - h) / 2)),
                       (w, h), kind, c1, c2, radius=rad * S,
                       border=4 * S, seed=seed,
                       shadow_alpha=110, shadow_blur=32, shadow_dy=22)
        ly = top + SHAPE_H + 8 * S
        centered_text(d, cx, ly, label, font("med", 27 * S),
                      (255, 255, 255, 255))
        centered_text(d, cx, ly + 36 * S, sub, font("helv", 23 * S),
                      (150, 157, 172, 255))
        if new:
            pill, fnt = "NEW", font("helv_b", 19 * S)
            l, t, r, b = d.textbbox((0, 0), pill, font=fnt)
            tw, th = (r - l) + 24 * S, (b - t) + 16 * S
            bx = cx + w / 2 - tw + 6 * S
            by = top + (SHAPE_H - h) / 2 - th / 2
            d.rounded_rectangle([bx, by, bx + tw, by + th], radius=th / 2,
                                fill=(249, 115, 22, 255))
            d.text((bx + 12 * S, by + 7 * S), pill, font=fnt,
                   fill=(255, 255, 255, 255))

    img.convert("RGB").save(path, optimize=True)


if __name__ == "__main__":
    import os
    here = os.path.dirname(os.path.abspath(__file__))
    make_hero(os.path.join(here, "hero.png"))
    print("wrote hero.png")
    make_shapes(os.path.join(here, "shapes.png"))
    print("wrote shapes.png")
