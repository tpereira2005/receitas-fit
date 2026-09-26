# Imagens com o Codex

As fotografias das receitas e as imagens dos alimentos são criadas com o **Codex** (app do ChatGPT), com a geração de imagens incluída no plano, **sem API e sem custos extra**. O kit está em [`ferramentas/fotos-receitas`](../ferramentas/fotos-receitas):

| Ficheiro | Para que serve |
|---|---|
| [`AGENTS.md`](../ferramentas/fotos-receitas/AGENTS.md) | Instruções que o Codex lê sozinho: os dois fluxos, passo a passo. |
| [`PROMPT-CODEX.md`](../ferramentas/fotos-receitas/PROMPT-CODEX.md) | Mensagens prontas a enviar ao Codex. |
| [`README.md`](../ferramentas/fotos-receitas/README.md) | Como usar o kit e levar as imagens para o iPhone. |
| `referencias/` | Estilo, composição, zonas seguras dos recortes da app e prompts base. |
| `scripts/` | Apoio local, sem API: recortar, rever contra as zonas da app, tirar fundos e montar os prompts. |

## Os dois fluxos

**Fotografias das receitas.** Pões uma fotografia tua em `1-originais/`; o Codex analisa-a, sugere melhorias (apresentação, recipiente, fundo) e espera pela tua resposta. Depois gera a imagem a partir da fotografia, recorta-a para 1800 × 1800 e verifica se a comida fica nas zonas visíveis em todos os recortes da app.

**Imagens dos alimentos.** Dizes os nomes ("aveia, banana, whey") e o Codex cria uma imagem quadrada, com fundo transparente, para cada um, todas com o mesmo estilo. Na app aparecem sobre a cor da categoria.

## Onde estão as imagens

O repositório só guarda o kit. As fotografias originais, as imagens geradas e os registos ficam na pasta de trabalho no PC (fora do repositório, pelo [`.gitignore`](../ferramentas/fotos-receitas/.gitignore) do kit). As imagens aprovadas chegam à app pelo iCloud Drive e, quando passam a fazer parte do conteúdo de origem, pelo [`ConteudoBase.json`](conteudo-de-origem.md).
