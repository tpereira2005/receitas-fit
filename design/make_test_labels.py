"""Gera fotografias sintéticas de rótulos nutricionais para os testes de leitura de embalagens.

As imagens ficam em ReceitasFitTests/Labels e são lidas pelo reconhecimento de texto do iOS
(Vision) no simulador, para confirmar que a app extrai os valores certos.
Uso: python design/make_test_labels.py
"""
from pathlib import Path
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = Path(__file__).resolve().parent.parent / "ReceitasFitTests" / "Labels"
FONT = "C:/Windows/Fonts/arial.ttf"
BOLD = "C:/Windows/Fonts/arialbd.ttf"


def font(size, bold=False):
    return ImageFont.truetype(BOLD if bold else FONT, size)


def table(title, header, rows, size=(1200, 1000), tilt=0.0, seed=1, name="label"):
    random.seed(seed)
    img = Image.new("RGB", size, (250, 248, 242))
    d = ImageDraw.Draw(img)
    x0, y = 60, 50
    d.text((x0, y), title, fill=(20, 20, 20), font=font(44, True))
    y += 80
    widths = [460] + [(size[0] - 120 - 460) // (len(header) - 1)] * (len(header) - 1)
    def row(cells, bold=False, line=True):
        nonlocal y
        x = x0
        for i, (cell, w) in enumerate(zip(cells, widths)):
            f = font(36, bold)
            if i == 0:
                d.text((x + 8, y), cell, fill=(15, 15, 15), font=f)
            else:
                tw = d.textlength(cell, font=f)
                d.text((x + w - tw - 12, y), cell, fill=(15, 15, 15), font=f)
            x += w
        y += 58
        if line:
            d.line((x0, y - 8, size[0] - 60, y - 8), fill=(40, 40, 40), width=2)
    row(header, bold=True)
    for cells in rows:
        row(cells)
    img = img.rotate(tilt, resample=Image.BICUBIC, expand=True, fillcolor=(200, 196, 188))
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    # Grão leve, como numa fotografia.
    px = img.load()
    for _ in range(img.width * img.height // 25):
        i, j = random.randrange(img.width), random.randrange(img.height)
        v = random.randint(-25, 25)
        r, g, b = px[i, j]
        px[i, j] = (max(0, min(255, r + v)), max(0, min(255, g + v)), max(0, min(255, b + v)))
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / f"{name}.jpg", quality=88)
    print("ok", name, img.size)


# 1. Aveia com proteína: por 100 g e por dose, energia em kJ/kcal na mesma linha.
table(
    "Declaração nutricional",
    ["", "Por 100 g", "Por dose (40 g)"],
    [
        ["Energia", "1569 kJ / 375 kcal", "628 kJ / 150 kcal"],
        ["Lípidos", "6,5 g", "2,6 g"],
        ["dos quais saturados", "1,2 g", "0,5 g"],
        ["Hidratos de carbono", "55 g", "22 g"],
        ["dos quais açúcares", "12 g", "4,8 g"],
        ["Fibra", "8,5 g", "3,4 g"],
        ["Proteínas", "20 g", "8,0 g"],
        ["Sal", "0,35 g", "0,14 g"],
    ],
    tilt=1.5, seed=3, name="aveia-proteica",
)

# 2. Whey multilingue, com %DR e sem linha de fibra.
table(
    "Informação nutricional / Nutrition facts",
    ["", "100 g", "30 g", "%DR*"],
    [
        ["Energia / Energy", "1620 kJ", "486 kJ", ""],
        ["", "383 kcal", "115 kcal", "6%"],
        ["Lípidos / Fat", "5,6 g", "1,7 g", "2%"],
        ["dos quais saturados / saturates", "3,4 g", "1,0 g", "5%"],
        ["Hidratos de carbono / Carbohydrate", "6,2 g", "1,9 g", "1%"],
        ["dos quais açúcares / sugars", "4,1 g", "1,2 g", "1%"],
        ["Proteínas / Protein", "76 g", "23 g", "46%"],
        ["Sal / Salt", "0,48 g", "0,14 g", "2%"],
    ],
    size=(1400, 1000), tilt=-2.0, seed=5, name="whey",
)

# 3. Bebida por 100 ml, com "<0,5 g" e vírgulas.
table(
    "Valores médios por 100 ml",
    ["", "100 ml", "1 copo (250 ml)"],
    [
        ["Valor energético", "188 kJ / 45 kcal", "470 kJ / 112 kcal"],
        ["Lípidos", "1,5 g", "3,8 g"],
        ["dos quais saturados", "0,3 g", "0,8 g"],
        ["Hidratos de carbono", "5,9 g", "15 g"],
        ["dos quais açúcares", "2,6 g", "6,5 g"],
        ["Fibra", "<0,5 g", "<0,5 g"],
        ["Proteínas", "1,9 g", "4,8 g"],
        ["Sal", "0,13 g", "0,33 g"],
    ],
    tilt=0.8, seed=7, name="bebida-aveia",
)
