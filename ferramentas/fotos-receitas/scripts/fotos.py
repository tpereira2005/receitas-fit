#!/usr/bin/env python3
"""Ferramentas de apoio ao fluxo das fotografias (não chama nenhuma API).

  python scripts/fotos.py estado                        # em que passo está cada foto
  python scripts/fotos.py ficha IMG_1234                # cria a ficha a partir do modelo
  python scripts/fotos.py prompt IMG_1234               # prompt final para a geração de imagem
  python scripts/fotos.py prompt IMG_1234 --ajuste "..."  # com uma correção extra
  python scripts/fotos.py finalizar IMG_1234 caminho/da/imagem-gerada.png
  python scripts/fotos.py rever [IMG_1234]              # folhas de revisão e resumo
  python scripts/fotos.py estado-ficha IMG_1234 concluída
"""
import argparse
import datetime
import json
import re
import shutil
import sys
import uuid
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps

try:  # fotografias HEIC do iPhone
    from pillow_heif import register_heif_opener

    register_heif_opener()
except ImportError:
    pass

# Consola do Windows: mostrar acentos e símbolos sem erros.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

sys.path.insert(0, str(Path(__file__).resolve().parent))
from zonas import _crop, _rounded, font, overlay, review_sheet  # noqa: E402

BASE = Path(__file__).resolve().parent.parent
ORIGINAIS = BASE / "1-originais"
FINAIS = BASE / "2-finais"
REVISAO = BASE / "3-revisao"
ARQUIVO = BASE / "4-arquivo"
REFERENCIAS = BASE / "referencias"
REGISTO = BASE / "registo.jsonl"
EXTENSOES = {".jpg", ".jpeg", ".png", ".heic", ".heif", ".webp"}
LISTAS = ("acrescentar", "alterar", "remover")
ESTADOS = ("por analisar", "a aguardar decisão", "aprovada", "gerada", "concluída")


def config():
    with open(BASE / "config.json", encoding="utf-8") as f:
        return json.load(f)


def originais():
    return sorted(p for p in ORIGINAIS.iterdir() if p.suffix.lower() in EXTENSOES)


def original(stem):
    for p in originais():
        if p.stem == stem:
            return p
    sys.exit(f"Não encontrei a foto '{stem}' em 1-originais.")


def caminho_ficha(stem):
    return ORIGINAIS / f"{stem}.txt"


def ler_ficha(stem):
    """Lê a ficha: linhas 'chave: valor' e listas com '- ' por baixo de acrescentar/alterar/remover."""
    dados = {k: [] for k in LISTAS}
    path = caminho_ficha(stem)
    if not path.exists():
        return dados
    lista_atual = None
    for linha in path.read_text(encoding="utf-8").splitlines():
        texto = linha.strip()
        if not texto or texto.startswith("#"):
            continue
        if texto.startswith("- ") and lista_atual:
            item = texto[2:].strip()
            if item:
                dados[lista_atual].append(item)
            continue
        if ":" in texto:
            chave, valor = texto.split(":", 1)
            chave = chave.strip().lower()
            valor = valor.strip()
            if chave in LISTAS:
                lista_atual = chave
                if valor:
                    dados[chave].append(valor)
            else:
                lista_atual = None
                dados[chave] = valor
    return dados


def definir_estado(stem, estado):
    path = caminho_ficha(stem)
    if not path.exists():
        return
    texto = path.read_text(encoding="utf-8")
    if re.search(r"(?m)^estado:.*$", texto):
        texto = re.sub(r"(?m)^estado:.*$", f"estado: {estado}", texto, count=1)
    else:
        texto = f"estado: {estado}\n" + texto
    path.write_text(texto, encoding="utf-8")


def cmd_estado(_args):
    fotos = originais()
    if not fotos:
        print("Não há fotografias em 1-originais.")
        return
    for p in fotos:
        ficha = ler_ficha(p.stem)
        estado = ficha.get("estado") or ("por analisar" if not caminho_ficha(p.stem).exists() else "?")
        final = "sim" if (FINAIS / f"{p.stem}.jpg").exists() else "não"
        print(f"{p.name:36} estado: {estado:20} final: {final:4} {ficha.get('prato', '')}")


def cmd_ficha(args):
    original(args.nome)
    destino = caminho_ficha(args.nome)
    if destino.exists():
        print(f"A ficha já existe: {destino.relative_to(BASE)}")
        return
    shutil.copy(REFERENCIAS / "ficha-modelo.txt", destino)
    print(f"✓ {destino.relative_to(BASE)}")


def construir_prompt(stem, ajuste=None):
    ficha = ler_ficha(stem)
    modelo = (REFERENCIAS / "prompt-base.txt").read_text(encoding="utf-8")
    estilo = (REFERENCIAS / "estilo.txt").read_text(encoding="utf-8").strip()
    with open(REFERENCIAS / "angulos.json", encoding="utf-8") as f:
        angulos = json.load(f)
    angulo = (ficha.get("angulo") or "auto").lower()

    alteracoes = []
    for chave, rotulo in (("acrescentar", "ADD"), ("alterar", "CHANGE"), ("remover", "REMOVE")):
        alteracoes += [f"- {rotulo}: {item}" for item in ficha[chave]]
    if not alteracoes:
        alteracoes = ["- None. Keep the food exactly as it is in the photo; only improve the presentation and photography."]
    extra = []
    if ficha.get("ambiente"):
        extra.append("Scene and mood requested by the owner for this photo (takes priority over the general style where they differ): " + ficha["ambiente"])
    if ajuste:
        extra.append("IMPORTANT CORRECTION FOR THIS ATTEMPT: " + ajuste)

    return modelo.format(
        prato=ficha.get("prato") or "the dish shown in the photo",
        manter=ficha.get("manter") or "every ingredient, topping and the type of plate or bowl visible in the photo",
        alteracoes="\n".join(alteracoes),
        estilo=estilo,
        angulo=angulos.get(angulo, angulos["auto"]),
        extra="\n".join(extra),
    ).strip()


def cmd_prompt(args):
    original(args.nome)
    print(construir_prompt(args.nome, args.ajuste))


def novo_carimbo():
    return datetime.datetime.now().strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:4]


def gerar_revisao(img, stem, titulo):
    REVISAO.mkdir(exist_ok=True)
    destino = REVISAO / f"{stem}-revisao.jpg"
    review_sheet(img, titulo).save(destino, quality=88)
    return destino


def cmd_finalizar(args):
    original(args.nome)
    gerada = Path(args.imagem).expanduser().resolve()
    if not gerada.exists():
        sys.exit(f"Não encontrei a imagem gerada: {gerada}")
    cfg = config()
    ARQUIVO.mkdir(exist_ok=True)
    FINAIS.mkdir(exist_ok=True)
    carimbo = novo_carimbo()

    # Guarda a imagem gerada, tal como veio, no arquivo e com data e hora no nome,
    # para uma nova geração nunca sobrescrever a anterior.
    bruto = ARQUIVO / f"{args.nome}-{carimbo}-gerada{gerada.suffix.lower()}"
    if ARQUIVO.resolve() in gerada.parents:
        shutil.move(str(gerada), bruto)
    else:
        shutil.copy(gerada, bruto)

    img = ImageOps.exif_transpose(Image.open(bruto)).convert("RGB")
    lado = cfg.get("tamanho_final", 1800)
    final_img = ImageOps.fit(img, (lado, lado), Image.LANCZOS, centering=(0.5, 0.5))

    final = FINAIS / f"{args.nome}.jpg"
    if final.exists():
        shutil.move(str(final), ARQUIVO / f"{args.nome}-{carimbo}-final-anterior.jpg")
    final_img.save(final, quality=cfg.get("qualidade_jpeg", 90), optimize=True)
    ficha = ler_ficha(args.nome)
    revisao = gerar_revisao(final_img, args.nome, f"{args.nome} · {ficha.get('prato', '')}")
    definir_estado(args.nome, "gerada")

    with open(REGISTO, "a", encoding="utf-8") as f:
        f.write(json.dumps({
            "data": carimbo, "foto": args.nome, "prato": ficha.get("prato"),
            "alteracoes": {k: ficha[k] for k in LISTAS}, "gerada": str(bruto.relative_to(BASE)),
            "tamanho_gerado": list(img.size),
        }, ensure_ascii=False) + "\n")

    aviso = ""
    if abs(img.size[0] - img.size[1]) > 2:
        aviso = f"  (a imagem gerada era {img.size[0]}×{img.size[1]}; foi recortada ao centro para quadrado)"
    print(f"✓ final:   {final.relative_to(BASE)}{aviso}")
    print(f"✓ revisão: {revisao.relative_to(BASE)}")
    print(f"✓ arquivo: {bruto.relative_to(BASE)}")


def resumo(paths):
    cols, cell_w, cell_h = 3, 620, 380
    rows = (len(paths) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell_w + 40, rows * cell_h + 40), (242, 242, 247))
    d = ImageDraw.Draw(sheet)
    for i, path in enumerate(paths):
        img = Image.open(path).convert("RGB")
        x = 20 + (i % cols) * cell_w
        y = 20 + (i // cols) * cell_h
        guia = _rounded(Image.alpha_composite(img.resize((300, 300)).convert("RGBA"), overlay(300)), 16)
        sheet.paste(guia, (x, y), guia)
        card = _rounded(_crop(img, "card", 1.4), 24)
        sheet.paste(card, (x + 320, y), card)
        d.text((x, y + 310), path.stem, font=font(24, True), fill=(30, 30, 30))
    return sheet


def cmd_rever(args):
    paths = sorted(FINAIS.glob("*.jpg"))
    if args.nome:
        paths = [p for p in paths if p.stem == args.nome]
    if not paths:
        print("Não há imagens em 2-finais.")
        return
    for p in paths:
        destino = gerar_revisao(Image.open(p), p.stem, f"{p.stem} · {ler_ficha(p.stem).get('prato', '')}")
        print(f"✓ {destino.relative_to(BASE)}")
    todas = sorted(FINAIS.glob("*.jpg"))
    resumo(todas).save(REVISAO / "_todas.jpg", quality=85)
    print("✓ 3-revisao/_todas.jpg")


def cmd_estado_ficha(args):
    if args.estado not in ESTADOS:
        sys.exit(f"Estado inválido. Usa um destes: {', '.join(ESTADOS)}")
    definir_estado(args.nome, args.estado)
    print(f"✓ {args.nome}: {args.estado}")


def main():
    parser = argparse.ArgumentParser(description="Apoio ao fluxo das fotografias das receitas.")
    sub = parser.add_subparsers(dest="comando", required=True)
    sub.add_parser("estado", help="mostra o passo em que está cada foto").set_defaults(func=cmd_estado)
    p = sub.add_parser("ficha", help="cria a ficha de uma foto a partir do modelo")
    p.add_argument("nome")
    p.set_defaults(func=cmd_ficha)
    p = sub.add_parser("prompt", help="mostra o prompt final para a geração de imagem")
    p.add_argument("nome")
    p.add_argument("--ajuste", help="correção extra para esta tentativa")
    p.set_defaults(func=cmd_prompt)
    p = sub.add_parser("finalizar", help="prepara a imagem gerada para a app")
    p.add_argument("nome")
    p.add_argument("imagem", help="caminho da imagem gerada pelo Codex")
    p.set_defaults(func=cmd_finalizar)
    p = sub.add_parser("rever", help="folhas de revisão e resumo")
    p.add_argument("nome", nargs="?")
    p.set_defaults(func=cmd_rever)
    p = sub.add_parser("estado-ficha", help="atualiza o estado na ficha")
    p.add_argument("nome")
    p.add_argument("estado")
    p.set_defaults(func=cmd_estado_ficha)
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
