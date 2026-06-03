#!/usr/bin/env python3
"""Compose App Store marketing screenshots: purple gradient + headline + framed app screenshot.
Outputs 1320x2868 (6.9") PNGs to Screenshots/AppStore/. Does not touch the raw captures.
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "Screenshots")
OUT = os.path.join(ROOT, "Screenshots", "AppStore")
os.makedirs(OUT, exist_ok=True)

W, H = 1320, 2868
TOP = (109, 40, 217)      # #6D28D9 deep purple
BOT = (168, 85, 247)      # #A855F7 light purple

SHOTS = [
    ("home.png",      "01-home.png",      "Know the best card\nbefore you pay"),
    ("recommend.png", "02-recommend.png", "Smart picks for\nevery merchant"),
    ("cards.png",     "03-cards.png",     "All your cards,\none simple wallet"),
    ("spending.png",  "04-spending.png",  "Track the rewards\nyou actually earn"),
]

def load_font(size):
    for path, kw in [
        ("/System/Library/Fonts/SFNS.ttf", "Bold"),
        ("/Library/Fonts/Roboto-Bold.ttf", None),
        ("/System/Library/Fonts/Supplemental/Arial Bold.ttf", None),
    ]:
        if os.path.exists(path):
            f = ImageFont.truetype(path, size)
            if kw:
                try:
                    f.set_variation_by_name(kw)
                except Exception:
                    pass
            return f
    return ImageFont.load_default()

def gradient(w, h, top, bot):
    base = Image.new("RGB", (w, h), top)
    draw = ImageDraw.Draw(base)
    for y in range(h):
        t = y / (h - 1)
        r = int(top[0] + (bot[0] - top[0]) * t)
        g = int(top[1] + (bot[1] - top[1]) * t)
        b = int(top[2] + (bot[2] - top[2]) * t)
        draw.line([(0, y), (w, y)], fill=(r, g, b))
    return base

def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0], img.size[1]], radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out

def draw_centered(draw, lines, font, y, color, line_gap=24):
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        draw.text(((W - tw) / 2, y), line, font=font, fill=color)
        y += th + line_gap
    return y

font = load_font(96)

for src_name, out_name, headline in SHOTS:
    canvas = gradient(W, H, TOP, BOT).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    # headline
    lines = headline.split("\n")
    draw_centered(draw, lines, font, 175, (255, 255, 255, 255), line_gap=30)

    # screenshot framed
    shot = Image.open(os.path.join(SRC, src_name)).convert("RGBA")
    sw = 980
    sh = int(sw * shot.size[1] / shot.size[0])
    shot = shot.resize((sw, sh), Image.LANCZOS)
    shot = rounded(shot, 56)
    sx = (W - sw) // 2
    sy = 600

    # drop shadow
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sh_rect = Image.new("RGBA", (sw, sh), (0, 0, 0, 130))
    sh_rect = rounded(sh_rect, 56)
    shadow.paste(sh_rect, (sx, sy + 26), sh_rect)
    shadow = shadow.filter(ImageFilter.GaussianBlur(40))
    canvas = Image.alpha_composite(canvas, shadow)

    canvas.paste(shot, (sx, sy), shot)
    canvas.convert("RGB").save(os.path.join(OUT, out_name), "PNG")
    print("wrote", out_name, canvas.size)

print("done ->", OUT)
