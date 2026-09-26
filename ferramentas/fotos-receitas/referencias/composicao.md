# Composição das fotografias para a app

Todas as imagens são **quadradas** e a app guarda-as com até 1800 × 1800 px. Cada ecrã **corta a partir do centro**:

| Contexto | Tamanho no ecrã | Proporção | O que corta |
|---|---|---|---|
| Cartão da grelha | 174 × 212 pt | 0,82 | 9% de cada lado |
| Recentes | 290 × 200 pt | 1,45 | 15,5% em cima e em baixo |
| Página da receita | 393 × 440 pt | 0,89 | 5% de cada lado; a parte de baixo dissolve-se no fundo |
| Listas (Pesquisa e "Usado em") | 60 × 60 pt | 1:1 | nada |

## Zonas (em % da imagem, a partir do canto superior esquerdo)

- **Zona ideal para a comida: 18–82% × 28–60%**, com o centro em **50% × 44%**. É aqui que tem de estar o que identifica a receita.
- **Zona comum: 9–91% × 16–84%**. É visível em todos os contextos. O prato, a taça ou o copo podem entrar aqui, mas não mais longe.
- **Margens** (fora da zona comum): só fundo ou superfície desfocada.
- **Cantos com selos**: canto superior direito (coração e calorias) e canto inferior esquerdo (calorias no cartão). Devem ficar sem comida.
- **Terço de baixo**: nos Recentes leva o título por cima, e na página da receita a foto dissolve-se a partir de 42% da altura. Tem de ficar calmo.
- **Topo da página da receita** (0–27%): fica por baixo da barra de estado e dos botões.

## Por ângulo

| Ângulo | Quando | Como fica |
|---|---|---|
| `topo` | Bowls, taças, pratos rasos, saladas | Prato redondo com 55–60% da largura, centrado em 50% × 44% |
| `45` | Pratos montados, pilhas de panquecas, sobremesas, gelados em taça | Prato em elipse com 60–65% da largura; a comida sobe dentro da zona ideal |
| `frontal` | Batidos, bebidas, sobremesas em copo | Copo centrado, do topo a cerca de 22% até à base a cerca de 72% |

Os esquemas `layout-topo.png`, `layout-45.png` e `layout-frontal.png` mostram estas posições. A versão com as zonas desenhadas está em `layouts-com-zonas.png`.

## Ficheiros de referência

- `referencia-recortes.png`: folha com todos os recortes e zonas.
- `sobreposicao-zonas.png`: PNG transparente para pôr por cima de uma imagem num editor.
- `teste-recortes.png`: imagem de teste para adicionar à app e confirmar os recortes no iPhone.
