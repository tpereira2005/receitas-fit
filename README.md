# Receitas

App pessoal para iPhone para guardar e organizar receitas fit e saudáveis, feita em **SwiftUI + SwiftData** com o design **Liquid Glass** do iOS 26+.

<p>
  <img src="https://github.com/tpereira2005/receitas-fit/releases/download/latest/1-inicio.png" width="200">
  <img src="https://github.com/tpereira2005/receitas-fit/releases/download/latest/2-receita.png" width="200">
  <img src="https://github.com/tpereira2005/receitas-fit/releases/download/latest/3-pesquisa.png" width="200">
  <img src="https://github.com/tpereira2005/receitas-fit/releases/download/latest/7-inicio-escuro.png" width="200">
</p>

## Funcionalidades

- **Início**: carrossel de receitas recentes, filtros por categoria em Liquid Glass e grelha de cartões com fotografia, calorias e proteína
- **Receita**: fotografia em destaque, ingredientes com escala de porções e checklist, passos numerados que podes ir marcando, gráfico de macros, notas e link para a publicação original
- **Pesquisa**: separador próprio na barra inferior (lupa à direita), pesquisa por nome, ingrediente e etiqueta, sem distinguir acentos, e filtros rápidos (alta proteína, até 400 kcal, até 20 min, favoritas)
- **Explorar**: categorias, coleções inteligentes e etiquetas
- **Favoritas**
- **Importar receitas**: cola a legenda de uma publicação do Instagram ou TikTok, ou escolhe uma captura de ecrã (OCR no próprio iPhone), e a app preenche ingredientes, passos, porções e macros
- **Cópias de segurança** em JSON para a app Ficheiros ou iCloud Drive

## Como instalar no iPhone (SideStore)

1. No iPhone, abre **[github.com/tpereira2005/receitas-fit/releases/latest](https://github.com/tpereira2005/receitas-fit/releases/latest)** no Safari.
2. Toca em **ReceitasFit.ipa** para descarregar.
3. Abre o **SideStore** → separador **My Apps** → **+** → escolhe o `ReceitasFit.ipa` nas Transferências.

Para atualizar, repete os passos. As receitas mantêm-se porque a app é substituída, não apagada.

> Com um Apple ID gratuito, a assinatura dura 7 dias. O SideStore renova-a sozinho, desde que o abras de vez em quando (ou uses o atalho de atualização automática).

## Como funciona a compilação

Não é preciso Mac. Cada `push` para `main` corre o workflow [`.github/workflows/build.yml`](.github/workflows/build.yml) num Mac do GitHub Actions:

1. Gera o projeto Xcode a partir de [`project.yml`](project.yml) (XcodeGen).
2. Compila a app sem assinatura e empacota o `ReceitasFit.ipa`. O SideStore assina-o no iPhone.
3. Publica o IPA na release `latest`.
4. Abre a app no Simulador de iOS e tira capturas de ecrã, que ficam anexadas à release.

## Estrutura

```
ReceitasFit/
  App/            Entrada da app e TabView (Liquid Glass + separador de pesquisa)
  Models/         Recipe (SwiftData), categorias, filtros, rascunho de edição, backup, exemplos
  Utilities/      Formatação, imagens, OCR e parser de texto de receitas
  Views/          Início, Detalhe, Editor, Favoritas, Explorar, Pesquisa, Definições
  Resources/      Ícone e cor de destaque
```
