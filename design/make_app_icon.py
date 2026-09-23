#!/usr/bin/env python3
"""Gera o ícone da app no formato Icon Composer (AppIcon.icon).

Camadas vetoriais (SVG, 1024×1024) com cores definidas no icon.json para cada aparência.
O iOS aplica o Liquid Glass e gera os modos escuro, transparente e matizado a partir destas camadas.

Uso: python design/make_app_icon.py   (a partir da raiz do repositório)
"""
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON = os.path.join(ROOT, "AppIcon.icon")
ASSETS = os.path.join(ICON, "Assets")


def fmt(x):
    return f"{x:.1f}"


def rotate(point, angle, origin):
    a = math.radians(angle)
    x, y = point[0], point[1]
    return (origin[0] + x * math.cos(a) - y * math.sin(a), origin[1] + x * math.sin(a) + y * math.cos(a))


def leaf(base, length, width, angle):
    """Folha pontiaguda com a nervura central recortada (evenodd)."""
    def p(x, y):
        return rotate((x, y), angle, base)

    def path(points):
        start, *curves = points
        d = f"M{fmt(start[0])} {fmt(start[1])}"
        for c1, c2, end in curves:
            d += f" C{fmt(c1[0])} {fmt(c1[1])} {fmt(c2[0])} {fmt(c2[1])} {fmt(end[0])} {fmt(end[1])}"
        return d + " Z"

    L, w = length, width
    outline = path([
        p(0, 0),
        (p(w, -L * 0.22), p(w * 0.95, -L * 0.72), p(0, -L)),
        (p(-w * 0.95, -L * 0.72), p(-w, -L * 0.22), p(0, 0)),
    ])
    v = max(7.0, w * 0.075)
    vein = path([
        p(0, -L * 0.16),
        (p(v, -L * 0.40), p(v * 0.8, -L * 0.66), p(0, -L * 0.86)),
        (p(-v * 0.8, -L * 0.66), p(-v, -L * 0.40), p(0, -L * 0.16)),
    ])
    return outline + " " + vein


def svg(paths, evenodd=False):
    rule = ' fill-rule="evenodd"' if evenodd else ""
    body = "".join(f'<path d="{d}"{rule}/>' for d in paths)
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">'
            f'<g fill="#000000">{body}</g></svg>\n')


# --- Formas -----------------------------------------------------------------

LEAVES = [
    leaf((508, 610), 410, 118, 3),     # central, alta
    leaf((486, 624), 318, 108, -47),   # esquerda
    leaf((538, 624), 300, 104, 45),    # direita
]

BOWL_BODY = "M232 604 H792 C792 752 668 846 512 846 C356 846 232 752 232 604 Z"
BOWL_RIM = ("M240 568 H784 C805 568 820 583 820 602 C820 621 805 636 784 636 "
            "H240 C219 636 204 621 204 602 C204 583 219 568 240 568 Z")

# --- Cores ------------------------------------------------------------------


def p3(r, g, b, a=1.0):
    return f"display-p3:{r:.5f},{g:.5f},{b:.5f},{a:.5f}"


def srgb(r, g, b, a=1.0):
    return f"srgb:{r:.5f},{g:.5f},{b:.5f},{a:.5f}"


BACKGROUND_LIGHT = {
    "linear-gradient": [p3(0.36, 0.86, 0.52), p3(0.05, 0.60, 0.36)],
    "orientation": {"start": {"x": 0.5, "y": 0}, "stop": {"x": 0.5, "y": 0.85}},
}
LEAVES_LIGHT = {
    "linear-gradient": [p3(0.90, 1.00, 0.93), p3(0.70, 0.96, 0.80)],
    "orientation": {"start": {"x": 0.5, "y": 0}, "stop": {"x": 0.5, "y": 1}},
}
LEAVES_DARK = {
    "linear-gradient": [p3(0.45, 0.95, 0.60), p3(0.13, 0.72, 0.42)],
    "orientation": {"start": {"x": 0.5, "y": 0}, "stop": {"x": 0.5, "y": 1}},
}
BOWL_LIGHT = {"solid": srgb(1, 1, 1)}
BOWL_DARK = {"solid": srgb(0.93, 0.96, 0.94)}
RIM_LIGHT = {"solid": p3(0.86, 0.97, 0.90)}
RIM_DARK = {"solid": p3(0.78, 0.90, 0.83)}


def layer(name, light, dark):
    return {
        "fill-specializations": [
            {"value": light},
            {"appearance": "dark", "value": dark},
        ],
        "glass": True,
        "hidden": False,
        "image-name": f"{name}.svg",
        "name": name,
        "position": {"scale": 1, "translation-in-points": [0, 0]},
    }


def group(layers, translucency, shadow_opacity):
    return {
        "layers": layers,
        "lighting": "combined",
        "shadow": {"kind": "neutral", "opacity": shadow_opacity},
        "specular": True,
        "translucency": {"enabled": True, "value": translucency},
    }


icon = {
    "fill-specializations": [
        {"value": BACKGROUND_LIGHT},
        {"appearance": "dark", "value": "system-dark"},
    ],
    # O primeiro grupo fica à frente.
    "groups": [
        group([layer("bowl-rim", RIM_LIGHT, RIM_DARK), layer("bowl", BOWL_LIGHT, BOWL_DARK)], 0.2, 0.55),
        group([layer("leaves", LEAVES_LIGHT, LEAVES_DARK)], 0.45, 0.4),
    ],
    "supported-platforms": {"circles": ["watchOS"], "squares": "shared"},
}

os.makedirs(ASSETS, exist_ok=True)
with open(os.path.join(ASSETS, "leaves.svg"), "w", encoding="utf-8") as f:
    f.write(svg(LEAVES, evenodd=True))
with open(os.path.join(ASSETS, "bowl.svg"), "w", encoding="utf-8") as f:
    f.write(svg([BOWL_BODY]))
with open(os.path.join(ASSETS, "bowl-rim.svg"), "w", encoding="utf-8") as f:
    f.write(svg([BOWL_RIM]))
with open(os.path.join(ICON, "icon.json"), "w", encoding="utf-8") as f:
    json.dump(icon, f, indent=2)
    f.write("\n")
print("AppIcon.icon gerado")
