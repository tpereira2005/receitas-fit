#!/usr/bin/env python3
"""Gera os ícones vetoriais da app (SVG em modo template) para as categorias e o sal.

São usados quando não existe um SF Symbol adequado. Uso: python design/make_glyphs.py
"""
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Receitas", "Resources", "Assets.xcassets")


def circle(cx, cy, r):
    return f"M{cx - r:.2f} {cy:.2f} a{r} {r} 0 1 0 {2 * r} 0 a{r} {r} 0 1 0 {-2 * r} 0 Z"


def ellipse(cx, cy, rx, ry, deg):
    t = math.radians(deg)
    vx, vy = rx * math.cos(t), rx * math.sin(t)
    x0, y0, x1, y1 = cx - vx, cy - vy, cx + vx, cy + vy
    return (f"M{x0:.2f} {y0:.2f} A{rx} {ry} {deg} 1 0 {x1:.2f} {y1:.2f} "
            f"A{rx} {ry} {deg} 1 0 {x0:.2f} {y0:.2f} Z")


def polygon(points):
    return "M" + " L".join(f"{x:.2f} {y:.2f}" for x, y in points) + " Z"


def svg(paths, evenodd=False):
    rule = ' fill-rule="evenodd"' if evenodd else ""
    body = "".join(f'<path d="{p}"{rule}/>' for p in paths)
    # 22 pt de tamanho natural, como um SF Symbol; o desenho usa uma grelha de 100.
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 100 100">'
            f'<g fill="#000000">{body}</g></svg>')


# Coxa de frango (Proteínas)
d = (-0.7071, 0.7071)
n = (0.7071, 0.7071)
start, end = (47, 57), (25, 79)
w = 5.5
shaft = polygon([
    (start[0] + n[0] * w, start[1] + n[1] * w),
    (end[0] + n[0] * w, end[1] + n[1] * w),
    (end[0] - n[0] * w, end[1] - n[1] * w),
    (start[0] - n[0] * w, start[1] - n[1] * w),
])
tip = (end[0] + d[0] * 4, end[1] + d[1] * 4)
drumstick = svg([
    "M40 60 C27 46 33 13 58 7 C80 2 97 19 92 41 C88 60 67 71 50 65 Z",
    shaft,
    circle(tip[0] + n[0] * 6.5, tip[1] + n[1] * 6.5, 7.5),
    circle(tip[0] - n[0] * 6.5, tip[1] - n[1] * 6.5, 7.5),
])

# Espiga de trigo (Cereais)
grains = [ellipse(50, 17, 11, 6.2, 90)]
for y in (33, 50, 67):
    grains.append(ellipse(39.5, y, 12, 6.2, 40))
    grains.append(ellipse(60.5, y, 12, 6.2, 140))
wheat = svg(["M47.5 38 L52.5 38 L52.5 92 Q52.5 96 50 96 Q47.5 96 47.5 92 Z"] + grains)

# Maçã (Fruta)
apple = svg([
    "M50 31 C40 22 17 22 15 47 C13 71 31 93 44 93 C47 93 48 91 50 91 "
    "C52 91 53 93 56 93 C69 93 87 71 85 47 C83 22 60 22 50 31 Z",
    polygon([(48, 30), (46.5, 12), (51.5, 11.5), (53, 29.5)]),
    ellipse(66, 15, 11, 5.5, -28),
])

# Saleiro (Sal)
holes = " ".join(circle(x, y, 2.8) for x, y in ((42, 27), (50, 23), (58, 27)))
saltshaker = svg([
    "M31 37 C31 12 69 12 69 37 Z " + holes,
    "M30 39 L70 39 Q72 39 72 41 L72 45 Q72 47 70 47 L30 47 Q28 47 28 45 L28 41 Q28 39 30 39 Z",
    "M31 50 L69 50 L75 88 Q76 95 69 95 L31 95 Q24 95 25 88 Z",
], evenodd=True)

# Taça com bolinhas energéticas (Snacks)
snack = svg([
    "M10 57 H90 C90 77 73 91 50 91 C27 91 10 77 10 57 Z",
    circle(29, 43.5, 10),
    circle(50, 36, 11),
    circle(71, 43.5, 10),
])

# Pacote de leite (Laticínios)
drop = "M50 55 C50 55 40.5 66 40.5 72 C40.5 77.5 44.8 81.5 50 81.5 C55.2 81.5 59.5 77.5 59.5 72 C59.5 66 50 55 50 55 Z"
milk = svg([
    "M30 95 Q25 95 25 90 L25 43 L36 25 L64 25 L75 43 L75 90 Q75 95 70 95 Z "
    "M25 44 L75 44 L75 48 L25 48 Z " + drop,
    "M37 8 L63 8 Q65 8 65 10 L65 20 L35 20 L35 10 Q35 8 37 8 Z",
], evenodd=True)

GLYPHS = {
    "glyph.drumstick": drumstick,
    "glyph.wheat": wheat,
    "glyph.apple": apple,
    "glyph.saltshaker": saltshaker,
    "glyph.snack": snack,
    "glyph.milk": milk,
}

CONTENTS = """{
  "images" : [ { "filename" : "%s.svg", "idiom" : "universal" } ],
  "info" : { "author" : "xcode", "version" : 1 },
  "properties" : { "preserves-vector-representation" : true, "template-rendering-intent" : "template" }
}
"""

if __name__ == "__main__":
    for name, data in GLYPHS.items():
        folder = os.path.join(OUT, f"{name}.imageset")
        os.makedirs(folder, exist_ok=True)
        with open(os.path.join(folder, f"{name}.svg"), "w", encoding="utf-8") as f:
            f.write(data)
        with open(os.path.join(folder, "Contents.json"), "w", encoding="utf-8") as f:
            f.write(CONTENTS % name)
    print(f"{len(GLYPHS)} ícones gerados")
