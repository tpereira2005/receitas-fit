#!/usr/bin/env python3
"""Gera a fonte (source.json) do SideStore/AltStore para a versão acabada de compilar.

Variáveis de ambiente: REPO, APP_VERSION, BUILD, IPA_SIZE, NOTES.
"""
import datetime
import json
import os
import sys

repo = os.environ["REPO"]
version = os.environ["APP_VERSION"]
build = os.environ["BUILD"]
size = int(os.environ["IPA_SIZE"])
notes = os.environ.get("NOTES", "").strip() or f"Versão {version}"

bundle_id = "com.tpereira.receitasfit"
raw = f"https://raw.githubusercontent.com/{repo}/main"
releases = f"https://github.com/{repo}/releases/download"
download_url = f"{releases}/v{version}/ReceitasFit.ipa"
icon_url = f"{releases}/latest/AppIcon.png"
screenshots = [f"{releases}/latest/{name}.png" for name in ("1-inicio", "2-receita", "4-alimentos", "3-pesquisa")]
date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
description = (
    "App pessoal para guardar e organizar receitas fit e saudáveis, com biblioteca de alimentos, "
    "cálculo automático de calorias e macros e o design Liquid Glass do iOS."
)

version_entry = {
    "version": version,
    "buildVersion": build,
    "date": date,
    "localizedDescription": notes,
    "downloadURL": download_url,
    "size": size,
    "minOSVersion": "26.0",
}

app = {
    "name": "Receitas",
    "bundleIdentifier": bundle_id,
    "developerName": repo.split("/")[0],
    "subtitle": "Receitas fit com macros automáticos",
    "localizedDescription": description,
    "iconURL": icon_url,
    "tintColor": "#10B062",
    "category": "lifestyle",
    "screenshots": screenshots,
    "versions": [version_entry],
    "appPermissions": {"entitlements": [], "privacy": {}},
    # Campos antigos, para versões mais velhas do SideStore/AltStore.
    "version": version,
    "versionDate": date,
    "versionDescription": notes,
    "downloadURL": download_url,
    "size": size,
    "screenshotURLs": screenshots,
}

source = {
    "name": "Receitas",
    "identifier": f"{bundle_id}.source",
    "subtitle": "Atualizações da app Receitas",
    "description": description,
    "iconURL": icon_url,
    "website": f"https://github.com/{repo}",
    "tintColor": "#10B062",
    "apps": [app],
    "news": [],
}

sys.stdout.reconfigure(encoding="utf-8")
json.dump(source, sys.stdout, ensure_ascii=False, indent=2)
sys.stdout.write("\n")
