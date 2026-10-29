# Floating Camera — MIT License. See LICENSE.
"""Compose assets/hero.png from the real product screenshot.

Layout (3200x1800): dark gradient wallpaper + the actual app screenshot
(screenshots/camera+menu.png) in a rounded frame + wordmark block.

Usage:
    python3 assets/compose_hero.py
"""

import os

from PIL import Image, ImageDraw, ImageFilter

from generate import font, translucent, wallpaper

HERE = os.path.dirname(os.path.abspath(__file__))
SHOT = os.path.join(HERE, "screenshots", "camera+menu.png")

W, H = 3200, 1800


def main():
    img = wallpaper(W, H).convert("RGBA")

    # Real screenshot, framed.
    shot = Image.open(SHOT).convert("RGBA")
    target_h = 1500
    scale = target_h / shot.height
    shot = shot.resize((int(shot.width * scale), target_h), Image.LANCZOS)
    sw, sh = shot.size
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, sw - 1, sh - 1], radius=36, fill=255)
    frame = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    frame.paste(shot, (0, 0), mask)

    fx, fy = 140, (H - sh) // 2
    shade = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shade.paste(Image.new("RGBA", (sw, sh), (0, 0, 0, 130)),
                (fx, fy + 30), mask)
    img.alpha_composite(shade.filter(ImageFilter.GaussianBlur(45)))
    img.paste(frame, (fx, fy), mask)

    # Wordmark block on the right.
    tx = fx + sw + 190
    d = ImageDraw.Draw(img)
    d.text((tx, 560), "Floating", font=font("demi", 118),
           fill=(255, 255, 255, 255))
    d.text((tx, 700), "Camera", font=font("demi", 118),
           fill=(255, 255, 255, 255))
    d.text((tx + 4, 880), "Your face, everywhere. Literally.",
           font=font("helv", 40), fill=(195, 201, 214, 255))
    d = translucent(img, lambda g: g.rounded_rectangle(
        [tx, 990, tx + 560, 990 + 52], radius=26,
        fill=(255, 255, 255, 28)))
    d.text((tx + 28, 1001), "macOS 14+  ·  Free  ·  MIT",
           font=font("helv_b", 26), fill=(255, 255, 255, 230))
    d.ellipse([tx + 4, 1096, tx + 28, 1096 + 24], fill=(74, 222, 128, 255))
    d.text((tx + 44, 1092), "New in 1.1.0: Vertical Rectangle",
           font=font("helv", 30), fill=(195, 201, 214, 255))

    img.convert("RGB").save(os.path.join(HERE, "hero.png"), optimize=True)
    print("wrote hero.png")


if __name__ == "__main__":
    main()
