#!/usr/bin/env python3
"""Gera as imagens de referência para as fotografias das receitas.

Os valores vêm do código da app (iPhone 14 Pro, 393 pt de largura). Todas as vistas preenchem
a moldura e cortam a partir do centro (scaledToFill), por isso numa imagem quadrada:

  Cartão da grelha   174 × 212 pt  (0,82)  → corta dos lados
  Recentes           290 × 200 pt  (1,45)  → corta em cima e em baixo
  Página da receita  393 × 440 pt  (0,89)  → corta dos lados; desvanece na parte de baixo
  Listas             60 × 60 pt    (1:1)   → imagem inteira
  Editor             361 × 220 pt  (1,64)  → só pré-visualização

Uso: python design/make_photo_guides.py   (gera os ficheiros em design/imagens-receitas/)
"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "design", "imagens-receitas")
S = 1800  # tamanho máximo guardado pela app

# --- Geometria (frações da imagem quadrada) -------------------------------------------

SCREEN_W = 393
CARD = (174, 212)          # (393 - 2×16 - 14) / 2 = 173,5 pt; altura = largura / 0,82
FEATURED = (290, 200)
HERO = (393, 440)
EDITOR = (361, 220)


def crop_box(aspect):
    """Zona visível (x0, y0, x1, y1) de uma imagem quadrada numa moldura com esta proporção (largura/altura)."""
    if aspect < 1:
        margin = (1 - aspect) / 2
        return (margin, 0.0, 1 - margin, 1.0)
    margin = (1 - 1 / aspect) / 2
    return (0.0, margin, 1.0, 1 - margin)


FRAMES = {
    "card": crop_box(CARD[0] / CARD[1]),
    "featured": crop_box(FEATURED[0] / FEATURED[1]),
    "hero": crop_box(HERO[0] / HERO[1]),
    "editor": crop_box(EDITOR[0] / EDITOR[1]),
}

# Página da receita (frações da altura): valores de RecipeDetailView
HERO_BARS = 120 / 440        # barra de estado e botões por cima
HERO_FADE_START = 0.42       # começa a dissolver-se
HERO_TITLE = (440 - 96) / 440  # o título começa por cima da foto
HERO_FADE_END = 0.93         # já não se vê

# Zona comum a cartão, Recentes, página da receita e listas
COMMON = (
    max(FRAMES["card"][0], FRAMES["hero"][0]),
    FRAMES["featured"][1],
    min(FRAMES["card"][2], FRAMES["hero"][2]),
    FRAMES["featured"][3],
)
# Zona ideal para o prato: dentro da zona comum, abaixo dos botões da receita,
# acima do título dos Recentes e da zona onde a receita desvanece.
IDEAL = (0.18, 0.28, 0.82, 0.60)


def to_px(box):
    return tuple(int(round(v * S)) for v in box)


def sub_box(frame, frame_size, rect_pt):
    """Converte um retângulo em pontos dentro de uma moldura para frações da imagem."""
    x0, y0, x1, y1 = frame
    fw, fh = frame_size
    rx0, ry0, rx1, ry1 = rect_pt
    return (x0 + (x1 - x0) * rx0 / fw, y0 + (y1 - y0) * ry0 / fh,
            x0 + (x1 - x0) * rx1 / fw, y0 + (y1 - y0) * ry1 / fh)


# Selos que tapam a foto (em pontos, medidos no código)
BADGES = [
    sub_box(FRAMES["card"], CARD, (CARD[0] - 40, 0, CARD[0], 40)),           # coração
    sub_box(FRAMES["card"], CARD, (0, CARD[1] - 36, 100, CARD[1])),          # kcal
    sub_box(FRAMES["featured"], FEATURED, (FEATURED[0] - 92, 0, FEATURED[0], 42)),  # kcal
]
# Faixas com texto ou botões por cima (a foto continua visível, mas menos)
BANDS = [
    sub_box(FRAMES["featured"], FEATURED, (0, FEATURED[1] - 88, FEATURED[0], FEATURED[1])),  # título dos Recentes
    sub_box(FRAMES["hero"], HERO, (0, 0, HERO[0], 120)),                                    # barra de estado e botões
]

# --- Cores e letras -------------------------------------------------------------------

COLORS = {
    "card": (10, 132, 255),
    "featured": (255, 149, 0),
    "hero": (175, 82, 222),
    "editor": (120, 120, 128),
    "common": (40, 190, 90),
    "covered": (255, 59, 48),
}
NAMES = {
    "card": "Cartão da grelha",
    "featured": "Recentes",
    "hero": "Página da receita",
    "editor": "Editor (pré-visualização)",
}


def font(size, bold=False):
    candidates = (
        ["C:/Windows/Fonts/segoeuib.ttf", "/System/Library/Fonts/SFNS.ttf", "DejaVuSans-Bold.ttf"]
        if bold else
        ["C:/Windows/Fonts/segoeui.ttf", "/System/Library/Fonts/SFNS.ttf", "DejaVuSans.ttf"]
    )
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def dashed_rect(draw, box, color, width, dash=36, gap=22):
    x0, y0, x1, y1 = box
    for (ax, ay, bx, by) in ((x0, y0, x1, y0), (x1, y0, x1, y1), (x1, y1, x0, y1), (x0, y1, x0, y0)):
        length = max(abs(bx - ax), abs(by - ay))
        steps = int(length // (dash + gap)) + 1
        for i in range(steps):
            t0 = i * (dash + gap) / length
            t1 = min(1, (i * (dash + gap) + dash) / length)
            if t0 >= 1:
                break
            draw.line((ax + (bx - ax) * t0, ay + (by - ay) * t0, ax + (bx - ax) * t1, ay + (by - ay) * t1),
                      fill=color, width=width)


def dashed_hline(draw, y, x0, x1, color, width, dash=30, gap=18):
    x = x0
    while x < x1:
        draw.line((x, y, min(x + dash, x1), y), fill=color, width=width)
        x += dash + gap


def hatch(draw, box, color, spacing=28, width=4):
    x0, y0, x1, y1 = box
    layer_w = x1 - x0
    for k in range(-int(y1 - y0), int(layer_w), spacing):
        ax, ay = x0 + k, y0
        bx, by = x0 + k + (y1 - y0), y1
        # recorta a linha ao retângulo
        if ax < x0:
            ay += x0 - ax
            ax = x0
        if bx > x1:
            by -= bx - x1
            bx = x1
        if ay < by:
            draw.line((ax, ay, bx, by), fill=color, width=width)


def label(draw, xy, text, color, size=34, anchor="la", pad=10):
    f = font(size, bold=True)
    bbox = draw.textbbox(xy, text, font=f, anchor=anchor)
    draw.rounded_rectangle((bbox[0] - pad, bbox[1] - pad * 0.6, bbox[2] + pad, bbox[3] + pad * 0.6),
                           radius=12, fill=color)
    draw.text(xy, text, font=f, fill=(255, 255, 255), anchor=anchor)


# --- 1. Imagem de teste -----------------------------------------------------------------


def make_test_image():
    img = Image.new("RGB", (S, S), (246, 244, 239))
    d = ImageDraw.Draw(img)
    cell = S / 10
    cols = "ABCDEFGHIJ"
    for r in range(10):
        for c in range(10):
            box = (c * cell, r * cell, (c + 1) * cell, (r + 1) * cell)
            if (r + c) % 2 == 0:
                d.rectangle(box, fill=(236, 233, 226))
            d.text((box[0] + cell / 2, box[1] + cell / 2), f"{cols[c]}{r + 1}",
                   font=font(46, bold=True), fill=(200, 196, 188), anchor="mm")
    for i in range(1, 20):
        v = i * S / 20
        w = 3 if i % 2 == 0 else 1
        d.line((v, 0, v, S), fill=(214, 210, 202), width=w)
        d.line((0, v, S, v), fill=(214, 210, 202), width=w)

    # Zona ideal preenchida e alvo central
    ideal = to_px(IDEAL)
    overlay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    od.rounded_rectangle(ideal, radius=40, fill=COLORS["common"] + (60,))
    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(ideal, radius=40, outline=COLORS["common"], width=8)
    cx, cy = (ideal[0] + ideal[2]) / 2, (ideal[1] + ideal[3]) / 2
    for r in (70, 140):
        d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=COLORS["common"], width=6)
    d.line((cx - 200, cy, cx + 200, cy), fill=COLORS["common"], width=4)
    d.line((cx, cy - 200, cx, cy + 200), fill=COLORS["common"], width=4)
    label(d, (cx, ideal[1] + 34), "PRATO AQUI", COLORS["common"], size=42, anchor="mt")

    # Molduras de cada contexto
    for key in ("editor", "hero", "featured", "card"):
        box = to_px(FRAMES[key])
        if key == "editor":
            dashed_rect(d, box, COLORS[key], 6)
        else:
            d.rectangle(box, outline=COLORS[key], width=10)
    eb = to_px(FRAMES["editor"])
    label(d, (S * 0.30, eb[1] + 14), "Editor", COLORS["editor"], size=24, anchor="mt")

    # Zona comum (desenhada por dentro, porque coincide com as bordas das molduras)
    common = to_px(COMMON)
    inset = 18
    d.rectangle((common[0] + inset, common[1] + inset, common[2] - inset, common[3] - inset),
                outline=COLORS["common"], width=8)
    label(d, (common[0] + 40, common[3] - 40), "Visível em todo o lado", COLORS["common"], size=30, anchor="lb")

    fb = to_px(FRAMES["featured"])
    label(d, (S / 2, fb[1] + 20), "Recentes: limite de cima", COLORS["featured"], size=30, anchor="mt")
    label(d, (S / 2, fb[3] - 20), "Recentes: limite de baixo", COLORS["featured"], size=30, anchor="mb")
    cb = to_px(FRAMES["card"])
    label(d, (cb[0] + 20, S * 0.30), "‹ Cartão", COLORS["card"], size=30)
    label(d, (cb[2] - 20, S * 0.30), "Cartão ›", COLORS["card"], size=30, anchor="ra")
    hb = to_px(FRAMES["hero"])
    label(d, (hb[0] + 20, S * 0.72), "‹ Receita", COLORS["hero"], size=30)
    label(d, (hb[2] - 20, S * 0.72), "Receita ›", COLORS["hero"], size=30, anchor="ra")

    # Linhas da página da receita
    for frac, text in ((HERO_BARS, "Receita: abaixo dos botões"),
                       (HERO_FADE_START, "Receita: começa a desvanecer"),
                       (HERO_TITLE, "Receita: título por cima")):
        y = frac * S
        dashed_hline(d, y, hb[0], hb[2], COLORS["hero"], 6)
        label(d, (hb[2] - 24, y - 10), text, COLORS["hero"], size=26, anchor="rb")

    # Réguas com percentagens
    for i in range(0, 11):
        v = i * S / 10
        d.text((v + 6, 6), f"{i * 10}%", font=font(24, bold=True), fill=(120, 116, 108))
        if i:
            d.text((6, v - 30), f"{i * 10}%", font=font(24, bold=True), fill=(120, 116, 108))
    return img


# --- 2. Sobreposição transparente -----------------------------------------------------------------


def make_overlay():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    shade = Image.new("L", (S, S), 120)
    ImageDraw.Draw(shade).rectangle(to_px(COMMON), fill=0)
    img.paste((0, 0, 0, 255), (0, 0), shade)

    bands = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bands)
    for box in BANDS:
        bd.rectangle(to_px(box), fill=COLORS["covered"] + (30,))
    img = Image.alpha_composite(img, bands)
    d = ImageDraw.Draw(img)
    for box in BADGES:
        px = to_px(box)
        hatch(d, px, COLORS["covered"] + (210,), spacing=22, width=4)
        d.rectangle(px, outline=COLORS["covered"] + (235,), width=4)
    for key in ("card", "featured", "hero"):
        d.rectangle(to_px(FRAMES[key]), outline=COLORS[key] + (230,), width=6)
    hb = to_px(FRAMES["hero"])
    for frac in (HERO_FADE_START, HERO_TITLE):
        dashed_hline(d, frac * S, hb[0], hb[2], COLORS["hero"] + (230,), 5)
    d.rectangle(to_px(COMMON), outline=COLORS["common"] + (255,), width=8)
    ideal = to_px(IDEAL)
    dashed_rect(d, ideal, COLORS["common"] + (255,), 8)
    cx, cy = (ideal[0] + ideal[2]) / 2, (ideal[1] + ideal[3]) / 2
    d.line((cx - 60, cy, cx + 60, cy), fill=(255, 255, 255, 230), width=5)
    d.line((cx, cy - 60, cx, cy + 60), fill=(255, 255, 255, 230), width=5)
    return img


# --- 3. Folha de referência com cada contexto --------------------------------------------------


def rounded(im, radius):
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.size[0] - 1, im.size[1] - 1), radius=radius, fill=255)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(im, (0, 0), mask)
    return out


def crop_to(test, key, scale):
    size = {"card": CARD, "featured": FEATURED, "hero": HERO}[key]
    box = to_px(FRAMES[key])
    return test.crop(box).resize((int(size[0] * scale), int(size[1] * scale)), Image.LANCZOS).convert("RGBA")


def pill(draw, box, text, size):
    draw.rounded_rectangle(box, radius=(box[3] - box[1]) / 2, fill=(255, 255, 255, 215))
    draw.text(((box[0] + box[2]) / 2, (box[1] + box[3]) / 2), text, font=font(size, bold=True),
              fill=(20, 20, 20), anchor="mm")


def make_sheet(test):
    k = 2.0  # 2 px por ponto
    W, H = 2600, 2280
    sheet = Image.new("RGBA", (W, H), (242, 242, 247, 255))
    d = ImageDraw.Draw(sheet)
    d.text((70, 60), "Fotografias das receitas: recortes da app", font=font(64, bold=True), fill=(20, 20, 20))
    d.text((70, 150), "Imagem quadrada · a app guarda até 1800 × 1800 px · todas as vistas cortam a partir do centro",
           font=font(34), fill=(90, 90, 96))

    # Imagem completa com sobreposição
    guide = Image.alpha_composite(test.convert("RGBA"), make_overlay()).resize((900, 900), Image.LANCZOS)
    sheet.alpha_composite(rounded(guide, 30), (70, 240))
    d.text((70, 1160), "Imagem completa · o escuro é cortado em algum sítio", font=font(30, bold=True), fill=(60, 60, 66))

    x = 1040
    # Cartão
    card = crop_to(test, "card", k)
    cd = ImageDraw.Draw(card)
    cd.ellipse((card.width - 16 - 60, 16, card.width - 16, 76), fill=(255, 255, 255, 215))
    cd.text((card.width - 46, 46), "♥", font=font(34, bold=True), fill=(255, 45, 85), anchor="mm")
    pill(cd, (16, card.height - 16 - 52, 196, card.height - 16), "318 kcal", 26)
    sheet.alpha_composite(rounded(card, 44), (x, 240))
    d.text((x, 240 + card.height + 20), "Cartão da grelha", font=font(34, bold=True), fill=COLORS["card"])
    d.text((x, 240 + card.height + 64), "174 × 212 pt · 0,82 · 521 × 635 px", font=font(28), fill=(90, 90, 96))

    # Recentes
    fx = x + card.width + 70
    feat = crop_to(test, "featured", k)
    fd = ImageDraw.Draw(feat)
    grad = Image.new("L", (1, feat.height))
    for yy in range(feat.height):
        t = max(0.0, (yy / feat.height - 0.45) / 0.55)
        grad.putpixel((0, yy), int(150 * t))
    feat.paste((0, 0, 0), (0, 0), grad.resize(feat.size))
    fd = ImageDraw.Draw(feat)
    fd.text((28, feat.height - 110), "PEQUENO-ALMOÇO", font=font(22, bold=True), fill=(255, 255, 255))
    fd.text((28, feat.height - 76), "Título da receita", font=font(36, bold=True), fill=(255, 255, 255))
    pill(fd, (feat.width - 20 - 170, 20, feat.width - 20, 72), "318 kcal", 26)
    sheet.alpha_composite(rounded(feat, 52), (fx, 240))
    d.text((fx, 240 + feat.height + 20), "Recentes", font=font(34, bold=True), fill=COLORS["featured"])
    d.text((fx, 240 + feat.height + 64), "290 × 200 pt · 1,45 · 870 × 600 px", font=font(28), fill=(90, 90, 96))

    # Página da receita (com o desvanecimento real)
    hy = 900
    hero = crop_to(test, "hero", k * 1.05)
    alpha = Image.new("L", (1, hero.height))
    for yy in range(hero.height):
        t = yy / hero.height
        if t <= HERO_FADE_START:
            a = 1.0
        elif t >= HERO_FADE_END:
            a = 0.0
        else:
            u = (t - HERO_FADE_START) / (HERO_FADE_END - HERO_FADE_START)
            a = 1 - u * u * u * (u * (u * 6 - 15) + 10)
        alpha.putpixel((0, yy), int(255 * a))
    bg = Image.new("RGBA", hero.size, (255, 255, 255, 255))
    glow = hero.filter(ImageFilter.GaussianBlur(40))
    bg = Image.alpha_composite(bg, Image.blend(bg, glow, 0.4))
    hero.putalpha(alpha.resize(hero.size))
    hero = Image.alpha_composite(bg, hero)
    hd = ImageDraw.Draw(hero)
    top = int(hero.height * HERO_BARS)
    veil = Image.new("RGBA", (hero.width, top), (255, 255, 255, 110))
    hero.alpha_composite(veil, (0, 0))
    hd.ellipse((30, 90, 118, 178), fill=(255, 255, 255, 220))
    hd.rounded_rectangle((hero.width - 230, 90, hero.width - 30, 178), radius=44, fill=(255, 255, 255, 220))
    title_y = int(hero.height * HERO_TITLE)
    hd.text((36, title_y), "Título da receita", font=font(52, bold=True), fill=(20, 20, 20))
    hero = hero.crop((0, 0, hero.width, int(hero.height * 0.98)))
    sheet.alpha_composite(rounded(hero, 36), (x, hy))
    tx = x + hero.width + 50
    d.text((tx, hy), "Página da receita", font=font(34, bold=True), fill=COLORS["hero"])
    lines = [
        "393 × 440 pt · 0,89 · 1179 × 1320 px",
        "",
        "• 0–27%: por baixo da barra de estado",
        "   e dos botões",
        "• 27–42%: totalmente nítida",
        "• 42–93%: dissolve-se no fundo",
        "• a partir de 78%: título por cima",
        "",
        "Listas: 60 × 60 pt (imagem inteira)",
        "Editor: 361 × 220 pt (só pré-visualização)",
    ]
    for i, line in enumerate(lines):
        d.text((tx, hy + 56 + i * 44), line, font=font(28), fill=(60, 60, 66))

    # Legenda
    ly = 1830
    legend = [
        (COLORS["common"], "Zona comum: visível no cartão, nos Recentes, na receita e nas listas (9–91% × 16–84%)"),
        (COLORS["common"], "Zona ideal para o prato (tracejado): 18–82% × 28–60%, com o centro a cerca de 44% da altura"),
        (COLORS["covered"], "Vermelho: riscado = selos por cima da foto · faixa clara = título dos Recentes e botões da receita"),
        (COLORS["card"], "Azul: limites do cartão (corta os lados)"),
        (COLORS["featured"], "Laranja: limites dos Recentes (corta em cima e em baixo)"),
        (COLORS["hero"], "Roxo: limites da página da receita e linhas onde desvanece / entra o título"),
    ]
    for i, (color, text) in enumerate(legend):
        y = ly + i * 52
        d.rounded_rectangle((70, y + 6, 106, y + 42), radius=8, fill=color)
        d.text((124, y), text, font=font(30), fill=(40, 40, 46))
    d.text((70, ly + len(legend) * 52 + 30),
           "Dica: prato centrado na horizontal e ligeiramente acima do meio; deixa margem à volta e evita "
           "informação importante no terço de baixo.", font=font(28, bold=True), fill=(40, 40, 46))
    return sheet


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    test = make_test_image()
    test.save(os.path.join(OUT, "teste-recortes.png"), optimize=True)
    make_overlay().save(os.path.join(OUT, "sobreposicao-zonas.png"), optimize=True)
    make_sheet(test).convert("RGB").save(os.path.join(OUT, "referencia-recortes.png"), optimize=True)
    print("Zona comum:", tuple(round(v, 3) for v in COMMON))
    print("Imagens geradas em", OUT)
