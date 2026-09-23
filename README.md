# Receitas

App pessoal para iPhone para guardar e organizar receitas fit e saudáveis, feita em **SwiftUI + SwiftData** com o design **Liquid Glass** do iOS 26+.

<p>
  <img src="https://github.com/tpereira2005/receitas-fit/releases/download/latest/1-inicio.png" width="200">
  <img src="https://github.com/tpereira2005/receitas-fit/releases/download/latest/2-receita.png" width="200">
  <img src="https://github.com/tpereira2005/receitas-fit/releases/download/latest/4-alimentos.png" width="200">
  <img src="https://github.com/tpereira2005/receitas-fit/releases/download/latest/10-receita-escuro.png" width="200">
</p>

## Funcionalidades

- **Início**: carrossel de receitas recentes, filtros por categoria em Liquid Glass e grelha de cartões com fotografia, calorias e proteína
- **Receita**: fotografia em destaque que se dissolve no conteúdo, ingredientes com escala de porções e checklist, passos que podes ir marcando, nutrição por porção ou da receita toda, e link para a publicação original
- **Alimentos**: biblioteca de alimentos com os valores do rótulo por 100 g ou 100 ml (energia, lípidos, saturados, hidratos, açúcares, fibra, proteína e sal) e peso por unidade opcional
- **Macros automáticos**: as receitas usam ingredientes da biblioteca (g, ml, unidades, colheres ou q.b.) e a app calcula as calorias e os macros. Quando editas um alimento, as receitas que o usam atualizam-se.
- **Pesquisa**: separador próprio na barra inferior, com filtros rápidos (alta proteína, até 400 kcal, até 20 min, favoritas)
- **Explorar**: categorias (incluindo Gelados), coleções inteligentes e etiquetas
- **Cópias de segurança** em JSON, com receitas e alimentos

## Instalar e atualizar com o SideStore

### Fonte do SideStore (recomendado)

1. No iPhone, abre o **SideStore** → separador **Sources** → **+**.
2. Cola este link e confirma:

   ```
   https://raw.githubusercontent.com/tpereira2005/receitas-fit/sidestore/source.json
   ```

3. Abre a fonte **Receitas** e toca em **Get**/**Update**.

A partir daí, cada versão nova aparece em **My Apps → Updates**. Atualizar mantém as receitas, porque a app é substituída e não apagada.

### À mão

Abre [a última versão](https://github.com/tpereira2005/receitas-fit/releases/latest) no Safari, descarrega o `ReceitasFit.ipa` e abre-o no SideStore (**My Apps → +**).

> Com um Apple ID gratuito, a assinatura dura 7 dias. O SideStore renova-a sozinho, desde que o abras de vez em quando.

## Como funciona a compilação

Não é preciso Mac. Cada `push` para `main` corre o workflow [`.github/workflows/build.yml`](.github/workflows/build.yml) num Mac do GitHub Actions:

1. Gera o projeto Xcode a partir de [`project.yml`](project.yml) (XcodeGen) e define a versão `1.1.<número da build>`.
2. Compila a app sem assinatura e empacota o `ReceitasFit.ipa`. O SideStore assina-o no iPhone.
3. Publica o IPA numa release `v1.1.N` (mantém as 5 mais recentes) e na release `latest`.
4. Gera a fonte do SideStore com [`scripts/make_source.py`](scripts/make_source.py) e publica-a no ramo `sidestore`. A mensagem do commit aparece como nota da versão.
5. Abre a app no Simulador de iOS e tira capturas de ecrã, que ficam na release `latest`.

## Estrutura

```
ReceitasFit/
  App/            Entrada da app, TabView (Liquid Glass + separador de pesquisa) e preparação dos dados
  Models/         Recipe e Food (SwiftData), cálculo nutricional, biblioteca de origem, migração, backup, exemplos
  Utilities/      Formatação e imagens
  Views/          Início, Receita, Editor, Alimentos, Favoritas, Explorar, Pesquisa, Definições
  Resources/      Ícone e cor de destaque
scripts/          Gerador da fonte do SideStore
```
