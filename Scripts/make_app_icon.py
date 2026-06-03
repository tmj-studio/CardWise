#!/usr/bin/env python3
"""Draw the CardWise app icon: purple gradient + white card + gold chip + green check + number dots.
Renders at 2048 (supersampled) then downscales to 1024. Outputs a flat RGB PNG (no alpha, no rounded
corners) as required by App Store. Overwrites AppIcon-1024.png in the asset catalog.
"""
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "CardWise/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")

S = 2048                      # supersample canvas
TOP = (124, 58, 237)         # #7C3AED
BOT = (168, 85, 247)         # #A855F7

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

# diagonal gradient background (top-left -> bottom-right)
bg = Image.new("RGB", (S, S))
px = bg.load()
for y in range(S):
    for x in range(S):
        t = (x + y) / (2 * (S - 1))
        px[x, y] = lerp(TOP, BOT, t)

canvas = bg.convert("RGBA")

# ---- card geometry (in supersampled px) ----
cx0, cy0, cx1, cy1 = int(0.16*S), int(0.30*S), int(0.84*S), int(0.70*S)
radius = int(0.05*S)

# drop shadow
shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
off = int(0.012*S)
sd.rounded_rectangle([cx0+off, cy0+off, cx1+off, cy1+off], radius, fill=(0, 0, 0, 110))
shadow = shadow.filter(ImageFilter.GaussianBlur(int(0.02*S)))
canvas = Image.alpha_composite(canvas, shadow)

d = ImageDraw.Draw(canvas)

# white card
d.rounded_rectangle([cx0, cy0, cx1, cy1], radius, fill=(255, 255, 255, 255))

# gold chip (top-left of card)
chx0 = cx0 + int(0.055*S); chy0 = cy0 + int(0.055*S)
chx1 = chx0 + int(0.135*S); chy1 = chy0 + int(0.105*S)
d.rounded_rectangle([chx0, chy0, chx1, chy1], int(0.018*S), fill=(245, 197, 24, 255))
# chip lines
for i in range(1, 4):
    ly = chy0 + (chy1 - chy0) * i // 4
    d.line([chx0+int(0.012*S), ly, chx1-int(0.012*S), ly], fill=(214, 168, 12, 255), width=max(2, int(0.003*S)))

# green check circle (top-right of card)
gr = int(0.085*S)
gcx = cx1 - int(0.06*S) - gr
gcy = cy0 + int(0.055*S) + gr
d.ellipse([gcx-gr, gcy-gr, gcx+gr, gcy+gr], fill=(52, 199, 89, 255))
# white checkmark
cw = max(6, int(0.016*S))
d.line([gcx-int(0.040*S), gcy+int(0.002*S),
        gcx-int(0.008*S), gcy+int(0.035*S)], fill=(255, 255, 255, 255), width=cw, joint="curve")
d.line([gcx-int(0.008*S), gcy+int(0.035*S),
        gcx+int(0.045*S), gcy-int(0.030*S)], fill=(255, 255, 255, 255), width=cw, joint="curve")

# number dots: 4 groups of 4, evenly contained within the card
dot_r = int(0.0135*S)
row_y = cy0 + int(0.255*S)
inset = int(0.065*S)
avail = (cx1 - cx0) - 2*inset
dot_gap = avail / 16.8                 # 12 intra + 3 group gaps (gg = 1.6*dg)
group_gap = 1.6 * dot_gap
gx = cx0 + inset + dot_r
for g in range(4):
    for i in range(4):
        cxp = gx + i*dot_gap
        d.ellipse([cxp-dot_r, row_y-dot_r, cxp+dot_r, row_y+dot_r], fill=(43, 43, 43, 255))
    gx += 3*dot_gap + group_gap

# downscale to 1024, flatten to RGB (no alpha)
final = canvas.convert("RGB").resize((1024, 1024), Image.LANCZOS)
final.save(OUT, "PNG")
print("wrote", OUT, final.size, final.mode)
