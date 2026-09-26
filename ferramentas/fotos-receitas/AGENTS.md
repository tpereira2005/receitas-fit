# Instruções para o Codex: imagens da app Receitas

Esta pasta serve para duas coisas, na app **Receitas** (iPhone). Fala sempre em **português de Portugal**.

1. **Fotografias das receitas:** transformar, uma foto de cada vez, fotografias caseiras das receitas em fotografias de comida profissionais. Fluxo abaixo.
2. **Imagens dos alimentos:** o utilizador diz nomes de alimentos ou ingredientes e tu crias uma imagem para cada um, de raiz. Fluxo na secção **"Imagens dos alimentos"**, mais abaixo.

Percebe pelo pedido qual das duas é: se fala de uma foto, de um prato ou de `1-originais`, são fotografias de receitas; se dá nomes de alimentos ou ingredientes ("cria imagens para aveia, banana e whey"), são imagens de alimentos.

**Geração de imagens:** usa a **geração de imagens nativa do Codex** com o modelo **GPT-Images 2.5 (`gpt-image-2.5-sunburst`)**, a que o utilizador tem acesso pelo ChatGPT Plus. **Nunca uses a API da OpenAI**, nem chaves de API, nem pacotes ou scripts que façam chamadas pagas.

## Pastas

| Pasta / ficheiro | Para que serve |
|---|---|
| `1-originais/` | Fotos do utilizador (JPG, PNG, HEIC) e a ficha de cada uma, `<nome>.txt`. **Nunca alterar nem apagar as fotos.** |
| `2-finais/` | Imagens prontas para a app: `<nome>.jpg`, 1800 × 1800 px. |
| `3-revisao/` | Folhas com os recortes reais da app, para verificar a composição. |
| `4-arquivo/` | Imagens geradas (todas as versões) e finais substituídas. Nunca apagar. |
| `referencias/` | Prompt base, estilo, ângulos, zonas seguras, ideias de apresentação e modelo da análise. |
| `scripts/fotos.py` | Apoio local, sem API: `estado`, `ficha`, `prompt`, `finalizar`, `rever`, `estado-ficha`. |

Antes da primeira utilização: `pip install -r scripts/requirements.txt` (só Pillow; não precisa de chave).

## Fluxo para cada foto (em 3 passos, com uma pausa obrigatória)

Começa sempre com `python scripts/fotos.py estado` e trata **uma foto de cada vez**. Se houver várias por tratar, pega na primeira e diz quantas faltam. Se o utilizador indicar uma foto, trata só essa.

### Passo 1 · Analisar e sugerir (sem gerar nada)
1. Abre a foto e **observa-a com atenção**.
2. Cria a ficha com `python scripts/fotos.py ficha <nome>` e preenche `prato`, `angulo` (recomendado), `manter` (o que tem de ficar igual) e `notas` (o que observaste). Se o utilizador já deu o nome da receita, usa-o.
3. Lê `referencias/ideias-apresentacao.md` e `referencias/composicao.md`.
4. Mostra a análise **no formato de `referencias/modelo-analise.md`**: o que vês, o que falta para ficar profissional, 3 a 5 sugestões personalizadas e numeradas, e as perguntas (acrescentar, remover, alterar).
5. Muda o estado para `a aguardar decisão` (`python scripts/fotos.py estado-ficha <nome> "a aguardar decisão"`).
6. **Para aqui e espera pela resposta.** Não geres nenhuma imagem neste passo.

Se não conseguires perceber que prato é, pergunta antes de fazer sugestões.

### Passo 2 · Registar a direção aprovada
1. Traduz a resposta do utilizador para a ficha: `acrescentar`, `alterar`, `remover` (um item por linha, com "- ") e `ambiente`, se for o caso. Sê concreto (quantidades, posição, recipiente).
2. Se a resposta for ambígua ou contraditória, faz **uma** pergunta curta para esclarecer. Se for clara, não voltes a pedir confirmação: a resposta já é a aprovação.
3. Se as alterações acrescentarem ou tirarem ingredientes, lembra o utilizador de atualizar também a receita na app, para os macros ficarem certos.
4. Muda o estado para `aprovada`.

### Passo 3 · Gerar, finalizar e rever
1. Obtém o prompt com `python scripts/fotos.py prompt <nome>`.
2. Gera a imagem com a **geração de imagens do Codex**, modelo `gpt-image-2.5-sunburst`:
   - usa a **foto original como imagem de entrada** (edição a partir da foto, não uma imagem nova do zero);
   - usa o **prompt completo** devolvido pelo script, sem o resumir;
   - pede um formato **quadrado (1:1)**, na maior resolução disponível.
3. Guarda a imagem gerada como `4-arquivo/<nome>-gerada.png` (ou onde a ferramenta a deixar) e corre `python scripts/fotos.py finalizar <nome> <caminho-da-imagem>`. O script renomeia-a com data e hora, recorta para 1800 × 1800, grava `2-finais/<nome>.jpg`, cria `3-revisao/<nome>-revisao.jpg` e regista a versão.
   - Se a ferramenta só mostrar a imagem na conversa e não a conseguires guardar em ficheiro, pede ao utilizador para a guardar em `4-arquivo/` e continua quando ele confirmar.
4. **Revê** `3-revisao/<nome>-revisao.jpg` com esta lista:
   1. **Receita fiel:** os ingredientes e o recipiente respeitam a ficha, com as alterações aprovadas aplicadas e nada mais inventado.
   2. **Composição:** a comida está dentro do tracejado verde (18–82% × 28–60%), com o centro por volta de 44% da altura.
   3. **Zona comum:** nada importante fora do retângulo verde contínuo (9–91% × 16–84%).
   4. **Cantos com selos** (superior direito e inferior esquerdo) livres.
   5. **Terço de baixo** calmo.
   6. **Qualidade:** aspeto fotográfico realista, sem texto, logótipos, mãos, nem comida deformada ou duplicada.
   7. **Consistência** com o estilo das outras imagens em `2-finais/`.
5. Se falhar a composição ou a fidelidade, faz **uma** correção automática: gera de novo com `python scripts/fotos.py prompt <nome> --ajuste "<correção concreta em inglês>"` e volta a finalizar. Exemplo de correção: *"Zoom out: make the container 20% smaller and move it up so the food center is at 44% from the top."*
6. Muda o estado para `gerada` (o `finalizar` já o faz) e **mostra ao utilizador** a imagem final e a folha de revisão, com uma frase sobre o que foi aplicado e o resultado da verificação.
7. Pergunta: **"Ficou como querias, ou queres ajustar alguma coisa?"**
   - Se pedir ajustes, acrescenta-os à ficha (ou usa `--ajuste`), gera de novo e mostra outra vez. As versões anteriores ficam em `4-arquivo/`.
   - Se aprovar, muda o estado para `concluída`, corre `python scripts/fotos.py rever` e lembra como levar a imagem para o iPhone (secção do `README.md`).
8. Se houver mais fotos por tratar, pergunta se queres passar à seguinte.

## Imagens dos alimentos

O utilizador diz uma lista de alimentos ou ingredientes e tu crias uma imagem para cada um, **de raiz** (sem foto de partida). Na app, estas imagens aparecem como **ícones pequenos** (30 a 70 pt) num quadrado de cantos arredondados, por cima de um tom suave da cor da categoria. Por isso têm de ser: **um só alimento, centrado, fundo transparente, fácil de reconhecer em pequeno** e com o mesmo estilo em todas.

| Pasta / ficheiro | Para que serve |
|---|---|
| `alimentos/fichas/` | Uma ficha por alimento (`<nome-curto>.txt`): nome, categoria, o que mostrar, notas e estado. |
| `alimentos/finais/` | Imagens prontas: `<Nome do alimento>.png`, 1024 × 1024 px, fundo transparente. |
| `alimentos/revisao/` | Folha de cada alimento com os ícones nos tamanhos reais da app (claro e escuro) e o resumo `_todos.png`. |
| `alimentos/arquivo/` | Todas as imagens geradas. Nunca apagar. |
| `referencias/alimentos-*.txt/.md` | Estilo, prompt base e guia de como representar cada tipo de alimento. |
| `scripts/alimentos.py` | Apoio local, sem API: `novo`, `estado`, `prompt`, `finalizar`, `rever`, `estado-ficha`. |

### Fluxo (sem pausa obrigatória: o utilizador já disse o que quer)

1. **Criar as fichas:** `python scripts/alimentos.py novo "Nome 1" "Nome 2" …` com os nomes **tal como aparecem na app** (ex.: "Flocos de aveia", "Proteína whey de baunilha"). Se o utilizador escrever de forma abreviada ("whey"), usa um nome claro e diz-lhe qual usaste.
2. **Decidir o que mostrar:** lê `referencias/alimentos-representacao.md` e preenche em cada ficha `categoria` e `mostrar` (em inglês, concreto: forma, quantidade, recipiente se for preciso). Se um nome for **ambíguo** (ex.: "queijo", "natas", "farinha", "proteína"), faz **uma** pergunta curta sobre esse alimento e continua com os outros enquanto esperas. Se dois alimentos ficarem visualmente iguais, avisa em vez de gerar duas imagens quase idênticas.
3. **Para cada alimento, um de cada vez:**
   1. `python scripts/alimentos.py prompt <nome-curto>` e gera com a **geração de imagens do Codex** (`gpt-image-2.5-sunburst`): **imagem nova (sem imagem de entrada)**, **quadrada (1:1)** e **com fundo transparente** (PNG com canal alfa; a ferramenta do Codex faz isto diretamente), usando o prompt completo.
      - Só se, por alguma razão, a imagem vier com fundo: gera de novo com `--fundo branco` (ou `--fundo cinzento` para alimentos brancos ou muito claros) e o `finalizar` tira o fundo no PC.
   2. Guarda a imagem em `alimentos/arquivo/` e corre `python scripts/alimentos.py finalizar <nome-curto> <caminho-da-imagem>`. O script tira o fundo se for preciso, centra o alimento sempre com a mesma escala, grava `alimentos/finais/<Nome>.png` e cria a folha de revisão. Se o script mostrar "atenção", resolve antes de continuar.
   3. **Revê** `alimentos/revisao/<nome-curto>-revisao.png`:
      1. **Reconhece-se** o alimento a 30 pt, em claro e em escuro.
      2. **Fundo** totalmente transparente, sem restos, halo branco ou sombras.
      3. **Inteiro**: nada cortado nem a tocar nas bordas.
      4. **Sem texto**, marcas, embalagens ou mãos; aspeto fotográfico realista.
      5. **Consistente** com as outras imagens em `alimentos/finais/` (luz, ângulo, estilo, escala).
   4. Se falhar, faz **uma** correção automática com `--ajuste "<correção concreta em inglês>"` (ex.: *"Show only one banana, larger and fully visible, no shadow."*) e volta a finalizar.
4. **No fim**, corre `python scripts/alimentos.py rever` e mostra ao utilizador `alimentos/revisao/_todos.png`, com uma linha por alimento (o que mostraste e se houve correções). Pergunta: **"Queres ajustar alguma?"**
   - Ajustes: escreve-os em `notas` na ficha (em inglês), gera de novo só esses e mostra outra vez.
   - Aprovadas: muda o estado para `concluída` (`python scripts/alimentos.py estado-ficha <nome-curto> concluída`) e lembra como pôr as imagens na app (secção "Imagens dos alimentos" do `README.md`).

Se o utilizador pedir para refazer um alimento que já existe, usa a ficha que lá está (o `novo` não a apaga) e gera de novo; a imagem anterior vai para o arquivo.

## Regras
- **Fotografias das receitas:** uma foto de cada vez. Nunca saltes a pausa do Passo 1.
- **Imagens dos alimentos:** gera-as seguidas, mas finaliza e revê cada uma antes de passar à seguinte.
- Nunca uses a API da OpenAI nem instales o pacote `openai`. Toda a geração é feita pela ferramenta de imagens do Codex.
- Nunca alteres nem apagues as fotos em `1-originais/`, nem apagues nada em `4-arquivo/` ou `alimentos/arquivo/`.
- Não instales pacotes para tirar fundos: o Codex gera as imagens já sem fundo.
- Não alteres `referencias/` nem os scripts, a não ser que o utilizador peça.
- Se a ferramenta de imagens não permitir escolher o modelo, usa a que estiver disponível no Codex (GPT-Images 2.5) e diz isso ao utilizador.
