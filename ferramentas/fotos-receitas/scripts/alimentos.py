#!/usr/bin/env python3
"""Imagens dos alimentos para a app Receitas (não chama nenhuma API).

  python scripts/alimentos.py novo "Flocos de aveia" "Banana" --categoria cereais
  python scripts/alimentos.py estado
  python scripts/alimentos.py prompt flocos-de-aveia [--fundo branco] [--ajuste "..."]
  python scripts/alimentos.py finalizar flocos-de-aveia caminho/da/imagem.png
  python scripts/alimentos.py rever [flocos-de-aveia]
  python scripts/alimentos.py estado-ficha flocos-de-aveia concluída

A app mostra estas imagens como ícones pequenos (30 a 70 pt) num quadrado de cantos
arredondados, por cima de um tom suave da cor da categoria. Por isso o resultado final é
um PNG quadrado de 1024 px, com fundo transparente e o alimento centrado com margem.
"""
import argparse
import datetime
import json
import re
import shutil
import sys
import unicodedata
import uuid
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

sys.path.insert(0, str(Path(__file__).resolve().parent))
from zonas import _rounded, font  # noqa: E402

BASE = Path(__file__).resolve().parent.parent
PASTA = BASE / "alimentos"
FICHAS = PASTA / "fichas"
FINAIS = PASTA / "finais"
REVISAO = PASTA / "revisao"
ARQUIVO = PASTA / "arquivo"
REFERENCIAS = BASE / "referencias"
REGISTO = PASTA / "registo.jsonl"
ESTADOS = ("por gerar", "gerada", "concluída")

LADO = 1024        # tamanho final (a app reduz para 512 px)
OCUPACAO = 0.76    # o alimento ocupa 76% do lado maior: igual em todas as imagens

# Cores das categorias na app (cores do sistema iOS) e nomes aceites na ficha.
CATEGORIAS = {
    "proteinas": (255, 59, 48), "laticinios": (0, 122, 255), "cereais": (162, 132, 94),
    "fruta": (255, 45, 85), "legumes": (52, 199, 89), "gorduras": (255, 204, 0),
    "suplementos": (175, 82, 222), "temperos": (255, 149, 0), "outros": (142, 142, 147),
}

NOMES_CATEGORIAS = {
    "proteinas": "Proteínas", "laticinios": "Laticínios", "cereais": "Cereais", "fruta": "Fruta",
    "legumes": "Legumes", "gorduras": "Gorduras", "suplementos": "Suplementos", "temperos": "Temperos",
    "outros": "Outros",
}

FUNDOS = {
    "transparente": (
        "Fully transparent background: output a PNG with an alpha channel. Only the food (and its container, "
        "if any) is opaque; everything around it is 100% transparent. No shadow, no floor, no backdrop."
    ),
    "branco": (
        "Plain, perfectly flat pure white background (#FFFFFF), uniform edge to edge. No shadow, no gradient, "
        "no floor, no texture, no vignette. The food must not touch the edges."
    ),
    "cinzento": (
        "Plain, perfectly flat neutral mid-grey background (#8A8A8A), uniform edge to edge. No shadow, no gradient, "
        "no floor, no texture, no vignette. The food must not touch the edges."
    ),
}


# MARK: - Fichas

def slug(nome):
    texto = unicodedata.normalize("NFKD", nome).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", texto.lower()).strip("-") or "alimento"


def caminho_ficha(nome_ficha):
    return FICHAS / f"{nome_ficha}.txt"


def ler_ficha(nome_ficha):
    path = caminho_ficha(nome_ficha)
    if not path.exists():
        sys.exit(f"Não encontrei a ficha '{nome_ficha}' em alimentos/fichas. Cria-a com: novo \"Nome\".")
    dados = {}
    for linha in path.read_text(encoding="utf-8").splitlines():
        texto = linha.strip()
        if texto and not texto.startswith("#") and ":" in texto:
            chave, valor = texto.split(":", 1)
            dados[chave.strip().lower()] = valor.strip()
    return dados


def definir(nome_ficha, chave, valor):
    path = caminho_ficha(nome_ficha)
    texto = path.read_text(encoding="utf-8")
    padrao = rf"(?m)^{re.escape(chave)}:.*$"
    if re.search(padrao, texto):
        texto = re.sub(padrao, lambda _m: f"{chave}: {valor}", texto, count=1)
    else:
        texto += f"\n{chave}: {valor}\n"
    path.write_text(texto, encoding="utf-8")


def nome_ficheiro_final(nome):
    """Nome legível para escolher no iPhone (ex.: "Flocos de aveia.png")."""
    return re.sub(r'[\\/:*?"<>|]+', "", nome).strip() or "alimento"


def cmd_novo(args):
    FICHAS.mkdir(parents=True, exist_ok=True)
    modelo = (REFERENCIAS / "alimento-modelo.txt").read_text(encoding="utf-8")
    for nome in args.nomes:
        nome = nome.strip()
        if not nome:
            continue
        s = slug(nome)
        path = caminho_ficha(s)
        if path.exists():
            print(f"· {s} já existe ({ler_ficha(s).get('estado', '?')})")
            continue
        path.write_text(modelo, encoding="utf-8")
        definir(s, "nome", nome)
        if args.categoria:
            definir(s, "categoria", args.categoria)
        print(f"✓ {s}  ←  {nome}")


def cmd_estado(_args):
    if not FICHAS.exists() or not any(FICHAS.glob("*.txt")):
        print("Ainda não há alimentos. Cria com: python scripts/alimentos.py novo \"Nome\"")
        return
    for path in sorted(FICHAS.glob("*.txt")):
        f = ler_ficha(path.stem)
        final = "sim" if (FINAIS / f"{nome_ficheiro_final(f.get('nome', path.stem))}.png").exists() else "não"
        print(f"{path.stem:28} estado: {f.get('estado', '?'):10} final: {final:4} {f.get('nome', '')}"
              f"{'' if f.get('mostrar') else '   (falta: mostrar)'}")


def cmd_estado_ficha(args):
    if args.estado not in ESTADOS:
        sys.exit(f"Estado inválido. Usa um destes: {', '.join(ESTADOS)}")
    ler_ficha(args.nome)
    definir(args.nome, "estado", args.estado)
    print(f"✓ {args.nome}: {args.estado}")


# MARK: - Prompt

def construir_prompt(nome_ficha, fundo="transparente", ajuste=None):
    f = ler_ficha(nome_ficha)
    if not f.get("mostrar"):
        sys.exit(f"A ficha '{nome_ficha}' ainda não tem o campo 'mostrar' (o que mostrar, em inglês).")
    modelo = (REFERENCIAS / "alimentos-prompt.txt").read_text(encoding="utf-8")
    estilo = (REFERENCIAS / "alimentos-estilo.txt").read_text(encoding="utf-8").strip()
    extra = []
    if f.get("notas"):
        extra.append("Owner's requests for this image (take priority over the style where they differ): " + f["notas"])
    if ajuste:
        extra.append("IMPORTANT CORRECTION FOR THIS ATTEMPT: " + ajuste)
    return modelo.format(
        nome=f.get("nome", nome_ficha),
        mostrar=f["mostrar"],
        estilo=estilo,
        fundo=FUNDOS[fundo],
        extra="\n".join(extra),
    ).strip()


def cmd_prompt(args):
    print(construir_prompt(args.nome, args.fundo, args.ajuste))


# MARK: - Fundo transparente

def tem_transparencia(img):
    """A imagem já vem recortada? (cantos e bordas transparentes)"""
    if img.mode != "RGBA":
        return False
    alpha = img.getchannel("A")
    w, h = img.size
    borda = [alpha.getpixel((x, y)) for x in range(0, w, max(1, w // 40)) for y in (0, h - 1)]
    borda += [alpha.getpixel((x, y)) for y in range(0, h, max(1, h // 40)) for x in (0, w - 1)]
    return sum(1 for a in borda if a < 20) > len(borda) * 0.8


def remover_fundo_rembg(img):
    try:
        from rembg import remove  # opcional: pip install "rembg[cpu]" (corre no PC, sem API)
    except ImportError:
        return None
    return remove(img.convert("RGB")).convert("RGBA")


def remover_fundo_uniforme(img, tolerancia=26):
    """Fundo liso (branco ou cinzento): apaga a zona da cor das bordas ligada às margens.

    Só se apaga o que toca nas margens, por isso um alimento claro no meio (iogurte, arroz)
    não desaparece, desde que tenha contorno.
    """
    rgb = img.convert("RGB")
    w, h = rgb.size
    amostras = [rgb.getpixel((x, y)) for x in range(0, w, max(1, w // 60)) for y in (0, h - 1)]
    amostras += [rgb.getpixel((x, y)) for y in range(0, h, max(1, h // 60)) for x in (0, w - 1)]
    fundo = tuple(sorted(c[i] for c in amostras)[len(amostras) // 2] for i in range(3))

    # Máscara das cores parecidas com o fundo.
    diff = ImageChops.difference(rgb, Image.new("RGB", rgb.size, fundo)).convert("L")
    parecido = diff.point(lambda v: 255 if v <= tolerancia else 0)

    # Só a parte ligada às margens: enche a partir de uma moldura de 1 px.
    marcado = parecido.copy()
    pixels = marcado.load()
    fila = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    visto = set()
    while fila:
        x, y = fila.pop()
        if (x, y) in visto or pixels[x, y] != 255:
            continue
        visto.add((x, y))
        pixels[x, y] = 128
        if x > 0: fila.append((x - 1, y))
        if x < w - 1: fila.append((x + 1, y))
        if y > 0: fila.append((x, y - 1))
        if y < h - 1: fila.append((x, y + 1))
    alpha = marcado.point(lambda v: 0 if v == 128 else 255)
    # Borda suave (sem serrilhado nem halo branco).
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(1.2))
    resultado = rgb.convert("RGBA")
    resultado.putalpha(alpha)
    return resultado


def recortado(img):
    # PNG com paleta ou tons de cinzento com transparência: passa a RGBA antes de verificar.
    if img.mode in ("P", "LA", "PA") or "transparency" in img.info:
        img = img.convert("RGBA")
    if tem_transparencia(img):
        return img.convert("RGBA"), "transparente de origem"
    via_rembg = remover_fundo_rembg(img)
    if via_rembg is not None:
        return via_rembg, "fundo removido com rembg"
    # Para trabalhar depressa em imagens grandes, reduz antes de encher.
    pequeno = img.convert("RGB")
    if max(pequeno.size) > 1400:
        pequeno.thumbnail((1400, 1400), Image.LANCZOS)
    return remover_fundo_uniforme(pequeno), "fundo liso removido localmente"


def enquadrar(img):
    """Corta ao alimento e centra-o num quadrado de 1024 px com a mesma ocupação em todas as imagens."""
    alpha = img.getchannel("A")
    caixa = alpha.point(lambda v: 255 if v > 12 else 0).getbbox()
    if not caixa:
        return None, None
    peca = img.crop(caixa)
    escala = (LADO * OCUPACAO) / max(peca.size)
    peca = peca.resize((max(1, round(peca.width * escala)), max(1, round(peca.height * escala))), Image.LANCZOS)
    tela = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
    tela.alpha_composite(peca, ((LADO - peca.width) // 2, (LADO - peca.height) // 2))
    return tela, caixa


# MARK: - Revisão

def _xadrez(tamanho, lado=24):
    im = Image.new("RGB", (tamanho, tamanho), (255, 255, 255))
    d = ImageDraw.Draw(im)
    for y in range(0, tamanho, lado):
        for x in range(0, tamanho, lado):
            if (x // lado + y // lado) % 2:
                d.rectangle((x, y, x + lado - 1, y + lado - 1), fill=(228, 228, 232))
    return im


def icone(img, tamanho, cor, fundo):
    """Como a FoodIcon da app: cor cheia da categoria (gradiente ligeiro, mais claro em cima),
    o alimento com uma sombra suave por baixo e cantos a 28%. É igual em claro e em escuro."""
    im = Image.new("RGBA", (tamanho, tamanho))
    d = ImageDraw.Draw(im)
    topo = tuple(round(cor[i] * 0.82 + 255 * 0.18) for i in range(3))
    for y in range(tamanho):
        t = y / max(1, tamanho - 1)
        d.line((0, y, tamanho, y), fill=tuple(round(topo[i] * (1 - t) + cor[i] * t) for i in range(3)) + (255,))
    alimento = img.resize((tamanho, tamanho), Image.LANCZOS)
    sombra = Image.new("RGBA", (tamanho, tamanho), (0, 0, 0, 0))
    sombra.putalpha(alimento.getchannel("A").point(lambda v: round(v * 0.25)))
    sombra = sombra.filter(ImageFilter.GaussianBlur(tamanho * 0.05))
    im.alpha_composite(sombra, (0, round(tamanho * 0.025)))
    im.alpha_composite(alimento)
    return _rounded(im, round(tamanho * 0.28))


def folha_revisao(img, nome, categoria):
    cor = CATEGORIAS.get((categoria or "outros").lower(), CATEGORIAS["outros"])
    folha = Image.new("RGB", (1740, 620), (242, 242, 247))
    d = ImageDraw.Draw(folha)
    d.text((30, 22), nome, font=font(34, True), fill=(20, 20, 20))
    d.text((30, 66), "fundo transparente · tamanhos reais na app (3×) em claro e escuro", font=font(20), fill=(110, 110, 115))

    xadrez = _xadrez(420)
    xadrez.paste(img.resize((420, 420), Image.LANCZOS), (0, 0), img.resize((420, 420), Image.LANCZOS))
    folha.paste(_rounded(xadrez.convert("RGBA"), 24), (30, 120), _rounded(xadrez.convert("RGBA"), 24))

    for i, (fundo, texto, secundario) in enumerate([((255, 255, 255), (20, 20, 20), (120, 120, 125)),
                                                   ((28, 28, 30), (245, 245, 247), (150, 150, 155))]):
        x0, y0 = 490 + i * 620, 120
        painel = Image.new("RGB", (600, 420), fundo)
        pd = ImageDraw.Draw(painel)
        # Linha da lista de alimentos (ícone de 32 pt).
        ic = icone(img, 96, cor, fundo)
        painel.paste(ic, (24, 24), ic)
        pd.text((140, 34), nome[:22], font=font(30, True), fill=texto)
        pd.text((140, 76), NOMES_CATEGORIAS.get((categoria or "outros").lower(), "Outros"), font=font(22), fill=secundario)
        # Tamanhos usados: 30 pt (editor), 44 pt (quantidade), 68 pt (página do alimento).
        x = 24
        for pt in (30, 44, 68):
            ic = icone(img, pt * 3, cor, fundo)
            painel.paste(ic, (x, 170), ic)
            pd.text((x, 180 + pt * 3), f"{pt} pt", font=font(20), fill=secundario)
            x += pt * 3 + 24
        folha.paste(_rounded(painel.convert("RGBA"), 24), (x0, y0), _rounded(painel.convert("RGBA"), 24))
    return folha


def gerar_revisao(nome_ficha):
    f = ler_ficha(nome_ficha)
    final = FINAIS / f"{nome_ficheiro_final(f.get('nome', nome_ficha))}.png"
    if not final.exists():
        return None
    REVISAO.mkdir(parents=True, exist_ok=True)
    destino = REVISAO / f"{nome_ficha}-revisao.png"
    folha_revisao(Image.open(final).convert("RGBA"), f.get("nome", nome_ficha), f.get("categoria")).save(destino)
    return destino


def resumo():
    finais = sorted(FINAIS.glob("*.png"))
    if not finais:
        return None
    fichas = {ler_ficha(p.stem).get("nome", p.stem): ler_ficha(p.stem) for p in FICHAS.glob("*.txt")}
    cols, cel = 6, 230
    linhas = (len(finais) + cols - 1) // cols
    folha = Image.new("RGB", (cols * cel + 30, linhas * (cel + 40) + 30), (242, 242, 247))
    d = ImageDraw.Draw(folha)
    for i, path in enumerate(finais):
        img = Image.open(path).convert("RGBA")
        categoria = fichas.get(path.stem, {}).get("categoria")
        cor = CATEGORIAS.get((categoria or "outros").lower(), CATEGORIAS["outros"])
        x = 15 + (i % cols) * cel
        y = 15 + (i // cols) * (cel + 40)
        ic = icone(img, 200, cor, (255, 255, 255))
        folha.paste(ic, (x + 15, y), ic)
        d.text((x + 15, y + 206), path.stem[:18], font=font(20), fill=(40, 40, 40))
    destino = REVISAO / "_todos.png"
    folha.save(destino)
    return destino


# MARK: - Finalizar

def cmd_finalizar(args):
    f = ler_ficha(args.nome)
    gerada = Path(args.imagem).expanduser().resolve()
    if not gerada.exists():
        sys.exit(f"Não encontrei a imagem gerada: {gerada}")
    for pasta in (FINAIS, ARQUIVO, REVISAO):
        pasta.mkdir(parents=True, exist_ok=True)

    carimbo = datetime.datetime.now().strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:4]
    bruto = ARQUIVO / f"{args.nome}-{carimbo}-gerada{gerada.suffix.lower()}"
    if ARQUIVO.resolve() in gerada.parents:
        shutil.move(str(gerada), bruto)
    else:
        shutil.copy(gerada, bruto)

    original = ImageOps.exif_transpose(Image.open(bruto))
    sem_fundo, metodo = recortado(original)
    final_img, caixa = enquadrar(sem_fundo)
    if final_img is None:
        sys.exit("Não ficou nada visível depois de tirar o fundo. Gera de novo com --fundo cinzento.")

    avisos = []
    w, h = sem_fundo.size
    if caixa and (caixa[0] <= 2 or caixa[1] <= 2 or caixa[2] >= w - 2 or caixa[3] >= h - 2):
        avisos.append("o alimento toca na borda da imagem gerada (pode estar cortado ou o fundo não saiu todo)")
    opacos = final_img.getchannel("A").resize((64, 64)).point(lambda v: 255 if v > 128 else 0).histogram()[255]
    cobertura = opacos / 4096
    if cobertura > 0.62:
        avisos.append("a zona opaca é muito grande: o fundo pode não ter sido removido")

    final = FINAIS / f"{nome_ficheiro_final(f.get('nome', args.nome))}.png"
    if final.exists():
        shutil.move(str(final), ARQUIVO / f"{args.nome}-{carimbo}-final-anterior.png")
    final_img.save(final, optimize=True)
    definir(args.nome, "estado", "gerada")
    revisao = gerar_revisao(args.nome)
    resumo()

    with open(REGISTO, "a", encoding="utf-8") as reg:
        reg.write(json.dumps({"data": carimbo, "alimento": args.nome, "nome": f.get("nome"),
                              "mostrar": f.get("mostrar"), "gerada": str(bruto.relative_to(BASE)),
                              "fundo": metodo}, ensure_ascii=False) + "\n")

    print(f"✓ final:   {final.relative_to(BASE)}  ({metodo})")
    print(f"✓ revisão: {revisao.relative_to(BASE)}")
    print(f"✓ arquivo: {bruto.relative_to(BASE)}")
    for aviso in avisos:
        print(f"! atenção: {aviso}")


def cmd_rever(args):
    fichas = [args.nome] if args.nome else [p.stem for p in sorted(FICHAS.glob("*.txt"))]
    for nome_ficha in fichas:
        destino = gerar_revisao(nome_ficha)
        if destino:
            print(f"✓ {destino.relative_to(BASE)}")
    todos = resumo()
    if todos:
        print(f"✓ {todos.relative_to(BASE)}")
    else:
        print("Ainda não há imagens em alimentos/finais.")


def main():
    parser = argparse.ArgumentParser(description="Imagens dos alimentos para a app Receitas.")
    sub = parser.add_subparsers(dest="comando", required=True)
    p = sub.add_parser("novo", help="cria as fichas de um ou mais alimentos")
    p.add_argument("nomes", nargs="+")
    p.add_argument("--categoria", choices=sorted(CATEGORIAS))
    p.set_defaults(func=cmd_novo)
    sub.add_parser("estado", help="lista os alimentos e o estado").set_defaults(func=cmd_estado)
    p = sub.add_parser("prompt", help="prompt para a geração de imagem")
    p.add_argument("nome")
    p.add_argument("--fundo", choices=sorted(FUNDOS), default="transparente")
    p.add_argument("--ajuste", help="correção extra para esta tentativa")
    p.set_defaults(func=cmd_prompt)
    p = sub.add_parser("finalizar", help="tira o fundo, centra e cria a revisão")
    p.add_argument("nome")
    p.add_argument("imagem")
    p.set_defaults(func=cmd_finalizar)
    p = sub.add_parser("rever", help="folhas de revisão e resumo _todos.png")
    p.add_argument("nome", nargs="?")
    p.set_defaults(func=cmd_rever)
    p = sub.add_parser("estado-ficha", help="atualiza o estado")
    p.add_argument("nome")
    p.add_argument("estado")
    p.set_defaults(func=cmd_estado_ficha)
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
