# Como representar cada alimento

Serve para o Codex decidir o que mostrar em cada imagem (campo `mostrar` da ficha, **em inglês**). A imagem é um ícone pequeno: tem de se reconhecer à primeira, mesmo com 30 pt.

## Regras gerais

- **Uma forma simples e reconhecível**: uma peça inteira, um montinho arrumado ou um recipiente simples.
- **Sem marcas nem embalagens.** Um produto de marca (ex.: "Whey Myprotein baunilha") mostra-se pelo que é (pó de proteína numa colher-medida), nunca pela embalagem.
- **Recipientes só quando fazem falta** (líquidos, pós, cremes, iogurtes, molhos): taça, copo ou frasco simples, branco ou de vidro transparente, sem padrões.
- **Mostrar o alimento como é usado nas receitas**: "flocos de aveia" são flocos, não papas; "peito de frango" é peito cru, não cozinhado, a não ser que o nome diga o contrário ("frango grelhado").
- **Variantes com o mesmo aspeto** (ex.: "iogurte grego natural" e "iogurte grego magro"): a mesma imagem serve para as duas; avisa o utilizador em vez de gerar duas quase iguais.
- **Se o nome for ambíguo** (ex.: "natas", "queijo", "farinha", "proteína"), pergunta que tipo é antes de gerar.

## Por categoria (ponto de partida)

| Categoria | Como mostrar |
|---|---|
| Carne, peixe e ovos | Peça crua inteira e limpa (peito de frango, lombo de salmão, bife); ovos: um ovo inteiro, com meio ovo cozido ao lado só se ajudar; atum: lombos numa pequena taça, sem lata. |
| Laticínios e bebidas vegetais | Iogurtes e queijo fresco numa pequena taça branca com uma colherada visível; leites e bebidas num copo de vidro; queijos em bloco ou fatias simples. |
| Cereais, pão e tubérculos | Aveia, arroz, massa, quinoa: montinho arrumado ou pequena taça; pão: uma fatia ou um pão pequeno; batata/batata-doce: uma peça inteira com meia cortada. |
| Fruta | Peça inteira e fresca (com uma metade cortada se isso a tornar mais reconhecível: kiwi, abacate, manga); frutos vermelhos: pequeno grupo arrumado. |
| Legumes e verduras | Peça inteira ou pequeno molho (espinafres, rúcula); tomate cherry: 3 a 5 tomates juntos. |
| Gorduras, frutos secos e sementes | Azeite: pequeno frasco ou garrafa de vidro sem rótulo; manteiga de amendoim: pequeno frasco aberto com uma colher; frutos secos e sementes: montinho arrumado. |
| Suplementos | Pó (whey, caseína, creatina): colher-medida cheia com um pouco de pó; barras: uma barra sem embalagem, partida ao meio. |
| Temperos, molhos e doces | Especiarias: montinho de pó ou pau (canela); molhos: pequena taça; mel: frasco com pau de mel; adoçantes e cacau: montinho de pó. |

## Exemplos de "mostrar"

- Flocos de aveia → `a neat small heap of rolled oat flakes`
- Banana → `one whole ripe yellow banana, slightly curved, lying on its side`
- Proteína whey de baunilha → `a white measuring scoop filled with pale vanilla protein powder, a little powder spilled next to it`
- Iogurte grego natural magro → `a small white ceramic bowl of thick Greek yogurt with a smooth swirl on top`
- Azeite → `a small clear glass cruet of golden olive oil, no label`
- Ovo → `one whole brown egg with a halved hard-boiled egg beside it`
