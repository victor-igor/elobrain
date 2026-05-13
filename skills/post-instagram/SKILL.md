---
name: post-instagram
version: 1.0.0
description: |
  Produz conteúdo completo para Instagram — carrossel ou post estático — para a Eloscope
  ou para clientes. Identifica o destino, carrega o padrão de design correto (brandbook
  Eloscope ou padrão do cliente via brain), cria ou valida a copy, e entrega o conteúdo
  estruturado pronto para diagramação.
triggers:
  - "post instagram"
  - "post estático"
  - "cria post"
  - "conteúdo instagram"
  - "carrossel para cliente"
  - "post para cliente"
  - "feed instagram"
tools:
  - query
  - search
  - get_page
  - put_page
mutating: true
---

# Post Instagram — Produção Completa

## Contract

- Identifica destino (Eloscope vs cliente) antes de qualquer produção
- Carrega o padrão de design correto via brain (nunca inventa padrão)
- Cria copy completa se não fornecida; usa a fornecida se já existir
- Entrega estrutura de slides (carrossel) ou composição (post estático) com referências visuais
- Salva artefato no cerebro e sincroniza no elobrain

---

## Fase 0 — Identificar destino e formato

Perguntar **uma de cada vez**, aguardar resposta:

**0.1 — Para quem é o conteúdo?**
> "Esse conteúdo é pra Eloscope ou pra um cliente?"
> Se cliente: "Qual o nome do cliente?"

Salvar como `DESTINO` (eloscope | nome-do-cliente).

**0.2 — Qual formato?**
> "Carrossel (múltiplos slides) ou post estático (imagem única)?"

Salvar como `FORMATO` (carrossel | post-estatico).

**0.3 — Já tem copy?**
> "Você já tem o texto/copy ou quer que eu crie?"

- `SIM` → pedir a copy agora. Salvar como `COPY_FORNECIDA = true`
- `NÃO` → seguir para Fase 1 (criação de copy). Salvar `COPY_FORNECIDA = false`

---

## Fase 1 — Carregar padrão de design

### Se DESTINO = eloscope

Carregar padrão do brandbook via MCP:

```python
brandbook = mcp__elobrain__get_page("memory/context/eloscope-brandbook")
soul = mcp__elobrain__get_page("memory/users/victor/SOUL")
```

Padrões fixos da Eloscope:
- **Fontes**: Syne (display/títulos), Inter (corpo)
- **Cores**: conforme brandbook carregado
- **Header**: logo + "eloscope" + "@eloscope.ai" — idêntico em todos os slides
- **Tom**: direto, sem floreio, sem hype — cada palavra paga aluguel

### Se DESTINO = cliente

Buscar padrão do cliente no brain:

```python
# Busca o padrão de design do cliente
design_padrao = mcp__elobrain__search(f"padrão design {CLIENTE} instagram")
perfil_cliente = mcp__elobrain__query(f"quem é {CLIENTE}, identidade visual, cores, fontes")
```

Se não encontrar padrão no brain:
> "Não encontrei o padrão de design de {CLIENTE} no brain. Você pode me passar:
> - Cores principais (hex ou nome)
> - Fonte(s) usada(s)
> - Estilo visual (clean, bold, minimalista, etc.)
> - Exemplo de post anterior (link ou descrição)?"

Salvar padrão coletado via `mcp__elobrain__put_page` em `clientes/{cliente}/design-padrao.md` para uso futuro.

---

## Fase 2 — Copy

### Se COPY_FORNECIDA = true

> "Cola a copy aqui e eu estruturo nos formatos certos."

Receber copy, fazer apenas ajustes de fit (tamanho por slide, punch de abertura).

### Se COPY_FORNECIDA = false

**2.1 — Brief**

Perguntar **uma de cada vez**:
1. "Qual o tema ou assunto do post?"
2. "Qual o objetivo? (engajamento, educação, venda, autoridade)"
3. "Quem é o avatar — pra quem esse post fala diretamente?"
4. "Tem algum ângulo ou insight específico que quer explorar?"

**2.2 — Criar copy**

Persona de copy: **Gary Halbert + David Ogilvy** — resposta direta, sem hype.

Para **carrossel** (estrutura padrão de slides):

| Slide | Função | Regra |
|---|---|---|
| 01 | GANCHO | Interrompe o scroll — promessa ou provocação |
| 02 | PROBLEMA | Dor real do avatar |
| 03 | AGITAÇÃO | Por que isso é grave / custoso |
| 04 | SOLUÇÃO | O que muda com a solução |
| 05 | PROVA | Evidência, resultado, diagnóstico |
| 06 | CTA | Ação clara e específica |

Para **post estático**:
- Headline (até 8 palavras) — o que para o scroll
- Subhead (opcional, até 15 palavras) — complementa sem repetir
- CTA (até 5 palavras) — ação direta

**2.3 — Validar copy**

Apresentar copy estruturada e perguntar:
> "Quer ajustar algo antes de seguir para o design?"

Só avança com aprovação explícita.

---

## Fase 3 — Estrutura de produção

### Carrossel

Entregar estrutura completa de cada slide:

```
SLIDE 01 — GANCHO
Texto: "[headline]"
Visual: [orientação: fundo, elemento central, destaque]
Fonte: [tamanho, peso]
Header: logo + handle (sempre)

SLIDE 02 — PROBLEMA
Texto: "[copy]"
Visual: [orientação]
...
```

Referência de proporção: **1080x1080px** (feed quadrado) ou **1080x1350px** (portrait).

### Post estático

Entregar composição:

```
COMPOSIÇÃO — POST ESTÁTICO
Proporção: 1080x1080px | 1080x1350px

Headline: "[texto]"  → posição, tamanho, fonte
Subhead: "[texto]"   → posição, tamanho, fonte
Visual principal: [orientação: imagem, ilustração, fundo]
Logo/handle: [posição]
CTA: "[texto]" → posição, estilo
```

---

## Fase 4 — Entrega e persistência

**4.1 — Salvar artefato no cerebro**

```python
# Caminho físico
path = f"cerebro/areas/marketing/projetos/instagram/{DESTINO}/{FORMATO}-{slug}.md"

# Sincronizar no elobrain
mcp__elobrain__put_page(
  slug=f"areas/marketing/projetos/instagram/{DESTINO}/{FORMATO}-{slug}",
  content=artefato_completo
)
```

**4.2 — Checklist de entrega**

```
✓ POST INSTAGRAM — {DESTINO} — {FORMATO}

Destino: {eloscope | cliente}
Formato: {carrossel N slides | post estático}
Copy: {criada | fornecida}
Padrão de design: {brandbook eloscope | padrão {cliente}}

Artefato: {path}
Próximo passo: levar estrutura para diagramação ({Canva | Figma | Adobe})
```

---

## Anti-Patterns

- ❌ Nunca inventar padrão de design de cliente — sempre buscar no brain primeiro
- ❌ Não pular validação de copy — aprovação explícita antes de ir pro design
- ❌ Não fazer tudo de uma vez — perguntas uma a uma, aguardar resposta
- ❌ Não usar copy longa demais por slide — carrossel: máx 30 palavras/slide; post: máx 15 palavras
- ❌ Não salvar padrão de cliente só na sessão — persistir no brain para reuso futuro

---

## Tools Used

- `mcp__elobrain__get_page` — carregar brandbook Eloscope e perfis de clientes
- `mcp__elobrain__search` — buscar padrão de design do cliente
- `mcp__elobrain__query` — contexto do cliente (identidade, posicionamento)
- `mcp__elobrain__put_page` — salvar artefato + padrão de cliente novo

---

## Relação com skills existentes

- **carrossel-eloscope**: skill legada focada só em carrossel Eloscope. `post-instagram` é o substituto completo (multi-formato + multi-cliente). Para novos conteúdos, usar `post-instagram`.
- **elo-content**: Director que roteia para `post-instagram` quando intent é conteúdo Instagram.
