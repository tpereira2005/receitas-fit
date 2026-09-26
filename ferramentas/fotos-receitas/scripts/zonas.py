"""Geometria das molduras da app Receitas e folhas de revisão.

Os valores vêm do código da app (iPhone 14 Pro, 393 pt de largura). Todas as vistas preenchem a
moldura e cortam a partir do centro, por isso numa imagem quadrada (frações de 0 a 1):
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont

CARD = (174, 212)      # cartão da grelha (pt)
FEATURED = (290, 200)  # cartão dos Recentes (pt)
HERO = (393, 440)      # fotografia no topo da página da receita (pt)


def crop_box(aspect):
    """Zona visível (x0, y0, x1, y1) de uma imagem quadrada numa moldura com esta proporção."""
    if aspect < 1:
        m = (1 - aspect) / 2
        return (m, 0.0, 1 - m, 1.0)
    m = (1 - 1 / aspect) / 2
    return (0.0, m, 1.0, 1 - m)


FRAMES = {
    "card": crop_box(CARD[0] / CARD[1]),
    "featured": crop_box(FEATURED[0] / FEATURED[1]),
    "hero": crop_box(HERO[0] / HERO[1]),
}

HERO_BARS = 120 / 440          # barra de estado e botões por cima da foto
HERO_FADE_START = 0.42         # a foto começa a dissolver-se
HERO_TITLE = (440 - 96) / 440  # o título começa por cima
HERO_FADE_END = 0.93           # já não se vê

# Visível em todos os contextos: 9–91% × 16–84%
COMMON = (FRAMES["card"][0], FRAMES["featured"][1], FRAMES["card"][2], FRAMES["featured"][3])
# Onde deve ficar a comida (o que identifica a receita): 18–82% × 28–60%
IDEAL = (0.18, 0.28, 0.82, 0.60)
IDEAL_CENTER = (0.50, 0.44)


def _sub(frame, size, rect):
    x0, y0, x1, y1 = frame
    return (x0 + (x1 - x0) * rect[0] / size[0], y0 + (y1 - y0) * rect[1] / size[1],
            x0 + (x1 - x0) * rect[2] / size[0], y0 + (y1 - y0) * rect[3] / size[1])


BADGES = [
    _sub(FRAMES["card"], CARD, (CARD[0] - 40, 0, CARD[0], 40)),
    _sub(FRAMES["card"], CARD, (0, CARD[1] - 36, 100, CARD[1])),
    _sub(FRAMES["featured"], FEATURED, (FEATURED[0] - 92, 0, FEATURED[0], 42)),
]
BANDS = [
    _sub(FRAMES["featured"], FEATURED, (0, FEATURED[1] - 88, FEATURED[0], FEATURED[1])),
    _sub(FRAMES["hero"], HERO, (0, 0, HERO[0], 120)),
]

GREEN = (40, 190, 90)
RED = (255, 59, 48)
FRAME_COLORS = {"card": (10, 132, 255), "featured": (255, 149, 0), "hero": (175, 82, 222)}


def font(size, bold=False):
    names = (["segoeuib.ttf", "C:/Windows/Fonts/segoeuib.ttf", "Arial Bold.ttf", "DejaVuSans-Bold.ttf"] if bold
             else ["segoeui.ttf", "C:/Windows/Fonts/segoeui.ttf", "Arial.ttf", "DejaVuSans.ttf"])
    for name in names:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def _px(box, s):
    return tuple(int(round(v * s)) for v in box)


def _dashed(draw, box, color, width, dash=28, gap=16):
    x0, y0, x1, y1 = box
    for ax, ay, bx, by in ((x0, y0, x1, y0), (x1, y0, x1, y1), (x1, y1, x0, y1), (x0, y1, x0, y0)):
        length = max(abs(bx - ax), abs(by - ay)) or 1
        t = 0.0
        while t < length:
            a, b = t / length, min(1.0, (t + dash) / length)
            draw.line((ax + (bx - ax) * a, ay + (by - ay) * a, ax + (bx - ax) * b, ay + (by - ay) * b),
                      fill=color, width=width)
            t += dash + gap


def overlay(size):
    """Sobreposição transparente: escurece o que é cortado e marca as zonas."""
    s = size
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    shade = Image.new("L", (s, s), 120)
    ImageDraw.Draw(shade).rectangle(_px(COMMON, s), fill=0)
    img.paste((0, 0, 0, 255), (0, 0), shade)
    bands = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bands)
    for box in BANDS:
        bd.rectangle(_px(box, s), fill=RED + (34,))
    img = Image.alpha_composite(img, bands)
    d = ImageDraw.Draw(img)
    w = max(2, s // 300)
    for box in BADGES:
        d.rectangle(_px(box, s), outline=RED + (235,), width=w)
    for key, color in FRAME_COLORS.items():
        d.rectangle(_px(FRAMES[key], s), outline=color + (220,), width=w)
    d.rectangle(_px(COMMON, s), outline=GREEN + (255,), width=w + 1)
    _dashed(d, _px(IDEAL, s), GREEN + (255,), w + 1, dash=s // 60, gap=s // 110)
    cx, cy = IDEAL_CENTER[0] * s, IDEAL_CENTER[1] * s
    r = s * 0.025
    d.line((cx - r, cy, cx + r, cy), fill=(255, 255, 255, 230), width=w)
    d.line((cx, cy - r, cx, cy + r), fill=(255, 255, 255, 230), width=w)
    return img


def _rounded(im, radius):
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.size[0] - 1, im.size[1] - 1), radius=radius, fill=255)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(im, (0, 0), mask)
    return out


def _crop(img, key, scale):
    size = {"card": CARD, "featured": FEATURED, "hero": HERO}[key]
    s = img.size[0]
    return img.crop(_px(FRAMES[key], s)).resize((int(size[0] * scale), int(size[1] * scale)),
                                                 Image.LANCZOS).convert("RGBA")


def _pill(draw, box, text, size):
    draw.rounded_rectangle(box, radius=(box[3] - box[1]) / 2, fill=(255, 255, 255, 215))
    draw.text(((box[0] + box[2]) / 2, (box[1] + box[3]) / 2), text, font=font(size, True),
              fill=(20, 20, 20), anchor="mm")


def review_sheet(img, title):
    """Folha de revisão: imagem com as zonas e os recortes simulados da app."""
    img = img.convert("RGB")
    side = min(img.size)
    left = (img.size[0] - side) // 2
    top = (img.size[1] - side) // 2
    img = img.crop((left, top, left + side, top + side))
    k = 1.6
    W, H = 1900, 1060
    sheet = Image.new("RGBA", (W, H), (242, 242, 247, 255))
    d = ImageDraw.Draw(sheet)
    d.text((40, 26), title, font=font(40, True), fill=(20, 20, 20))

    guide = img.resize((900, 900), Image.LANCZOS).convert("RGBA")
    guide = Image.alpha_composite(guide, overlay(900))
    sheet.alpha_composite(_rounded(guide, 24), (40, 110))

    x = 980
    card = _crop(img, "card", k)
    cd = ImageDraw.Draw(card)
    cd.ellipse((card.width - 12 - 46, 12, card.width - 12, 58), fill=(255, 255, 255, 215))
    cd.text((card.width - 35, 35), "♥", font=font(26, True), fill=(255, 45, 85), anchor="mm")
    _pill(cd, (12, card.height - 12 - 40, 150, card.height - 12), "318 kcal", 20)
    sheet.alpha_composite(_rounded(card, 34), (x, 110))
    d.text((x, 110 + card.height + 10), "Cartão", font=font(26, True), fill=FRAME_COLORS["card"])

    fx = x + card.width + 40
    feat = _crop(img, "featured", k)
    grad = Image.new("L", (1, feat.height))
    for yy in range(feat.height):
        grad.putpixel((0, yy), int(150 * max(0.0, (yy / feat.height - 0.45) / 0.55)))
    feat.paste((0, 0, 0), (0, 0), grad.resize(feat.size))
    fd = ImageDraw.Draw(feat)
    fd.text((22, feat.height - 58), "Título da receita", font=font(28, True), fill=(255, 255, 255))
    _pill(fd, (feat.width - 16 - 130, 16, feat.width - 16, 56), "318 kcal", 20)
    sheet.alpha_composite(_rounded(feat, 40), (fx, 110))
    d.text((fx, 110 + feat.height + 10), "Recentes", font=font(26, True), fill=FRAME_COLORS["featured"])

    hy = 110 + card.height + 60
    hero = _crop(img, "hero", 1.1)
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
    bg = Image.alpha_composite(bg, Image.blend(bg, hero.filter(ImageFilter.GaussianBlur(30)), 0.4))
    hero.putalpha(alpha.resize(hero.size))
    hero = Image.alpha_composite(bg, hero)
    hd = ImageDraw.Draw(hero)
    hero.alpha_composite(Image.new("RGBA", (hero.width, int(hero.height * HERO_BARS * 0.6)), (255, 255, 255, 90)))
    hd.ellipse((20, 60, 80, 120), fill=(255, 255, 255, 220))
    hd.rounded_rectangle((hero.width - 150, 60, hero.width - 20, 120), radius=30, fill=(255, 255, 255, 220))
    hd.text((24, int(hero.height * HERO_TITLE)), "Título da receita", font=font(34, True), fill=(20, 20, 20))
    hero = hero.crop((0, 0, hero.width, min(hero.height, H - hy - 20)))
    sheet.alpha_composite(_rounded(hero, 28), (x, hy))
    d.text((x + hero.width + 24, hy), "Página da receita", font=font(26, True), fill=FRAME_COLORS["hero"])
    notes = [
        "Verificar:",
        "• comida dentro do tracejado verde",
        "• nada importante no escuro",
        "• cantos com selos livres",
        "• terço de baixo calmo",
        "• prato igual ao original",
    ]
    for i, line in enumerate(notes):
        d.text((x + hero.width + 24, hy + 50 + i * 36), line, font=font(22, i == 0), fill=(60, 60, 66))
    return sheet.convert("RGB")
