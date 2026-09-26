# Fotografias das receitas e imagens dos alimentos

Transforma, **uma de cada vez**, as fotos que tiras às tuas receitas em fotografias de comida com aspeto profissional, já compostas para ficarem bem em todos os sítios da app **Receitas**. E cria as **imagens dos alimentos** da biblioteca a partir só dos nomes (secção [Imagens dos alimentos](#imagens-dos-alimentos)). Usa o **Codex** e o **GPT-Images 2.5** do teu ChatGPT Plus, **sem API e sem custos extra**.

```
1-originais/   ← pões aqui a foto (e o Codex cria a ficha <nome>.txt ao lado)
2-finais/      ← imagem pronta para a app (1800 × 1800 px)
3-revisao/     ← folha com os recortes da app, para confirmar
4-arquivo/     ← todas as versões geradas
referencias/   ← estilo, zonas seguras, ideias de apresentação e prompt base
scripts/       ← apoio local (recortar, rever, montar o prompt)
```

## Como funciona

1. **Tiras a foto** e copias para `1-originais/`. Não precisa de estar bonita, basta ver-se bem a comida.
2. **Abres o Codex nesta pasta** e dizes, por exemplo, *"Tenho uma foto nova, analisa-a"* (há mais exemplos em `PROMPT-CODEX.md`).
3. **O Codex analisa e sugere, sem gerar nada.** Mostra o que vê, o que falta para ficar profissional e 3 a 5 sugestões numeradas: apresentação, toppings, recipiente, ângulo e ambiente. Pergunta se queres acrescentar, remover ou alterar alguma coisa.
   > Exemplo: um gelado da Ninja CREAMi numa taça simples → sugere servir no copo da CREAMi com uma bola por cima, bolacha triturada ou meia bolacha espetada, um fio de manteiga de amendoim, fundo fresco em tons de menta…
4. **Respondes à tua maneira** (*"a 1 e a 3, e tira a colher"*). O Codex regista a direção na ficha da foto.
5. **O Codex gera a imagem** com o GPT-Images 2.5 (`gpt-image-2.5-sunburst`), a partir da tua foto, com o estilo da casa e as regras de composição da app. Depois recorta, revê contra as zonas seguras e corrige uma vez se for preciso.
6. **Vês o resultado** e aprovas, ou pedes ajustes até ficar como queres.

Cada foto tem uma ficha (`1-originais/<nome>.txt`) com o estado: *por analisar → a aguardar decisão → aprovada → gerada → concluída*. Podes parar a meio e continuar noutro dia.

## Primeira configuração (uma vez)

1. **Python 3.10 ou mais recente** ([python.org](https://www.python.org/downloads/), marca "Add to PATH").
2. Instala as dependências (o Codex também o faz sozinho). É só o Pillow, para recortar imagens:
   ```powershell
   pip install -r scripts/requirements.txt
   ```
3. No Codex, confirma que tens a geração de imagens disponível (GPT-Images 2.5). **Não é preciso chave de API.**

## Dicas para as fotos originais

- Fotografa o prato inteiro, com alguma margem à volta.
- A luz natural ajuda o modelo a perceber as cores e texturas reais.
- Se já sabes o que queres (*"quero no copo da CREAMi"*), diz logo ao Codex na primeira mensagem.

## Levar as imagens para o iPhone

Na app, a fotografia da receita escolhe-se na app **Fotos**. Do PC para o iPhone:
- **iCloud para Windows** com Fotos em iCloud: copia a imagem de `2-finais/` para a pasta de carregamento do iCloud Fotos; ou
- **OneDrive, Google Drive ou iCloud Drive**: abre a imagem no iPhone → Partilhar → **Guardar imagem**.

Depois, na app: Receita → ⋯ → Editar → toca na fotografia → escolhe a imagem.

## Imagens dos alimentos

Também serve para criar as **imagens dos alimentos** da biblioteca (as que aparecem em vez do ícone da categoria). Aqui não precisas de foto: **dizes os nomes e o Codex cria as imagens.**

```
alimentos/
  fichas/    ← uma ficha por alimento (o Codex preenche)
  finais/    ← "Flocos de aveia.png", 1024 × 1024, fundo transparente
  revisao/   ← como fica na app (tamanhos reais, claro e escuro) e o resumo _todos.png
  arquivo/   ← todas as versões geradas
```

1. **Abres o Codex nesta pasta** e dizes, por exemplo: *"Cria imagens para flocos de aveia, banana, whey de baunilha e azeite."*
2. **O Codex decide como mostrar cada um** (um montinho de aveia, uma banana inteira, uma colher-medida com pó, um pequeno frasco de azeite sem rótulo…). Só te pergunta quando o nome é ambíguo ("queijo" de que tipo?).
3. **Gera as imagens uma a uma**, já **sem fundo**, com o mesmo estilo; o script centra-as todas à mesma escala e confirma que se reconhecem mesmo em pequeno.
4. **No fim mostra-te todas juntas** (`alimentos/revisao/_todos.png`). Pedes ajustes às que quiseres (*"a banana mais amarela, sem manchas"*).

**Para pôr na app:** copia as imagens de `alimentos/finais/` para o **iCloud Drive** (ou OneDrive/Google Drive). No iPhone: Alimentos → escolhe o alimento → ⋯ → **Editar** → Imagem → **Escolher dos Ficheiros**. Usa Ficheiros e não Fotos, para manter o fundo transparente.

## Personalizar

| Quero… | Ficheiro |
|---|---|
| Mudar o estilo de todas as fotos (fundo, luz, cores) | `referencias/estilo.txt` |
| Mais ou outras ideias nas sugestões | `referencias/ideias-apresentacao.md` |
| Mudar o formato da análise | `referencias/modelo-analise.md` |
| Mudar as regras gerais dadas ao modelo | `referencias/prompt-base.txt` |
| Afinar os ângulos (de cima, 45°, frontal) | `referencias/angulos.json` |
| Mudar o estilo das imagens dos alimentos | `referencias/alimentos-estilo.txt` |
| Mudar como cada tipo de alimento é mostrado | `referencias/alimentos-representacao.md` |

## Comandos de apoio (o Codex usa-os por ti)

```powershell
python scripts/fotos.py estado                      # passo em que está cada foto
python scripts/fotos.py prompt IMG_1234             # prompt que vai para o GPT-Images
python scripts/fotos.py finalizar IMG_1234 4-arquivo/IMG_1234-gerada.png
python scripts/fotos.py rever                       # folhas de revisão e resumo _todas.jpg

python scripts/alimentos.py novo "Flocos de aveia" "Banana"   # fichas dos alimentos
python scripts/alimentos.py estado                           # alimentos e estado
python scripts/alimentos.py finalizar banana imagem.png      # tira o fundo, centra e revê
python scripts/alimentos.py rever                            # folhas e resumo _todos.png
```

Estes scripts trabalham só no teu PC: não chamam nenhuma API.
