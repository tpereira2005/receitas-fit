# Prompts para o Codex

Abre o Codex **dentro da pasta `fotos-receitas`**. O Codex lê sozinho o `AGENTS.md` com o fluxo completo. Depois usa um destes prompts.

---

## Foto nova (o normal)

```
Tenho uma foto nova em 1-originais. Analisa-a e dá-me sugestões para a melhorar, seguindo o AGENTS.md.
```

Com o nome da receita:
```
Pus a foto IMG_1234 em 1-originais. É o "Gelado proteico de banana e amendoim" feito na Ninja CREAMi. Analisa-a e dá-me sugestões.
```

---

## Responder às sugestões

O Codex mostra sugestões numeradas e fica à espera. Responde de forma natural:
```
Quero a 1 e a 3. Na 3 põe só meia bolacha espetada. Tira também a colher.
```
```
Só a base, sem mudar nada na comida.
```
```
Tudo menos a 2. E quero um ambiente mais de verão, com luz de fim de tarde.
```

---

## Depois de ver o resultado

```
Ficou ótimo, está aprovada.
```
```
Quase. O copo está grande demais e a bolacha parece falsa. Refaz com o copo mais pequeno e bolacha mais natural.
```

---

## Imagens dos alimentos

```
Cria imagens para estes alimentos: flocos de aveia, banana, proteína whey de baunilha, azeite e ovo.
```
Com indicações:
```
Cria a imagem do iogurte grego natural magro, numa taça branca pequena com uma colherada por cima.
```
```
Cria imagens para todos os legumes da minha biblioteca: brócolos, espinafres, curgete, tomate cherry e pimento vermelho.
```
Depois de ver o resumo:
```
Ficaram ótimas. Só a banana: mais amarela e sem manchas, e o azeite num frasco mais baixo.
```

---

## Outras situações

**Retomar uma foto que ficou a meio** (o Codex vê o estado na ficha):
```
Continua a foto IMG_1234 a partir de onde ficou.
```

**Refazer uma foto antiga com outra ideia:**
```
Quero refazer a foto IMG_1180. Analisa de novo e dá-me sugestões diferentes das da última vez.
```

**Ver o estado de tudo:**
```
Mostra-me o estado das fotos e a folha _todas.jpg.
```

---

## Prompt completo (se o Codex não carregar o AGENTS.md)

```
Estás na pasta fotos-receitas. Lê o AGENTS.md e os ficheiros de referencias/ (composicao.md, ideias-apresentacao.md e modelo-analise.md) e segue o fluxo à risca, uma foto de cada vez:

1. python scripts/fotos.py estado. Pega na primeira foto por tratar.
2. Observa a foto, cria e preenche a ficha (python scripts/fotos.py ficha <nome>) e mostra-me a análise no formato do modelo-analise.md, com 3 a 5 sugestões personalizadas e as perguntas sobre acrescentar, remover ou alterar. Para e espera pela minha resposta.
3. Regista a minha resposta na ficha (acrescentar / alterar / remover / ambiente).
4. Obtém o prompt com python scripts/fotos.py prompt <nome> e gera a imagem com a geração de imagens do Codex (GPT-Images 2.5, gpt-image-2.5-sunburst), a partir da foto original, em formato quadrado. Não uses a API da OpenAI.
5. Guarda a imagem em 4-arquivo e corre python scripts/fotos.py finalizar <nome> <imagem>. Revê 3-revisao/<nome>-revisao.jpg: receita fiel, comida no tracejado verde (18–82% × 28–60%, centro a 44%), nada fora da zona comum (9–91% × 16–84%), cantos superior direito e inferior esquerdo livres, terço de baixo calmo, sem texto. Corrige uma vez se falhar.
6. Mostra-me o resultado e pergunta se quero ajustar alguma coisa.

Fala comigo em português de Portugal. Nunca alteres nem apagues os originais.
```

---

## Prompt completo para imagens de alimentos (se o Codex não carregar o AGENTS.md)

```
Estás na pasta fotos-receitas. Lê o AGENTS.md (secção "Imagens dos alimentos") e referencias/alimentos-representacao.md. Quero imagens para: <lista de alimentos>.

1. python scripts/alimentos.py novo "<Nome 1>" "<Nome 2>" … e preenche em cada ficha a categoria e o "mostrar" (em inglês).
2. Para cada um: python scripts/alimentos.py prompt <nome-curto>, gera uma imagem nova, quadrada e já sem fundo (transparente) com a geração de imagens do Codex (GPT-Images 2.5), sem a API da OpenAI.
3. Guarda em alimentos/arquivo e corre python scripts/alimentos.py finalizar <nome-curto> <imagem>. Revê a folha em alimentos/revisao e corrige uma vez se falhar.
4. No fim, python scripts/alimentos.py rever e mostra-me alimentos/revisao/_todos.png.

Fala comigo em português de Portugal.
```
