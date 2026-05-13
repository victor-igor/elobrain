---
name: post-instagram
version: 1.1.0
description: |
  Produz conteúdo completo para Instagram — carrossel ou post estático — para a própria
  empresa ou para clientes. Identifica o destino, carrega o padrão de design correto
  (brandbook da empresa via brain ou padrão do cliente via brain), cria ou valida a copy,
  e entrega o conteúdo estruturado pronto para diagramação. Company-agnostic: funciona
  para qualquer empresa que use o elobrain.
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

- Identifica destino (empresa vs cliente) antes de qualquer produção
- Carrega o padrão de design correto via brain (nunca inventa padrão)
- Cria copy completa se não fornecida; usa a fornecida se já existir
- Entrega estrutura de slides (carrossel) ou composição (post estático) com referências visuais
- Salva artefato no brain e sincroniza

---

## Fase 0 — Identificar destino e formato

**Passo 0.0 — Carregar identidade do operador**

```python
user_slug = os.environ.get("ELOBRAIN_USER", "default")
user_profile = mcp__elobrain__get_page(f"memory/users/{user_slug}/USER")
agent_soul   = mcp__elobrain__get_page(f"memory/users/{user_slug}/SOUL")
```

Usar `user_profile` para personalizar tom e contexto da sessão.

**Perguntar uma de cada vez, aguardar resposta:**

**0.1 — Para quem é o conteúdo?**
> "Esse conteúdo é pra sua empresa ou pra um cliente?"
> Se cliente: "Qual o nome do cliente?"

Salvar como `DESTINO` (empresa | nome-do-cliente).

**0.2 — Qual formato?**
> "Carrossel (múltiplos slides) ou post estático (imagem única)?"

Salvar como `FORMATO` (carrossel | post-estatico).

**0.3 — Já tem copy?**
> "Você já tem o texto/copy ou quer que eu crie?"

- `SIM` → pedir a copy agora. Salvar como `COPY_FORNECIDA = true`
- `NÃO` → seguir para Fase 2 (criação de copy). Salvar `COPY_FORNECIDA = false`

---

## Fase 1 — Carregar padrão de design

### Se DESTINO = empresa

Carregar brandbook da própria empresa via MCP:

```python
brandbook = mcp__elobrain__get_page("memory/context/company-brandbook")
```

Se não encontrar `company-brandbook`, tentar:
```python
brandbook = mcp__elobrain__query("identidade visual da empresa cores fontes logo estilo")
```

Se ainda não encontrar, perguntar:
> "Não encontrei o brandbook da empresa no brain. Pode me passar:
> - Cores principais (hex ou nome)
> - Fonte(s) usada(s)
> - Handle do Instagram
> - Estilo visual (clean, bold, minimalista, etc.)?"

Salvar padrão coletado via `mcp__elobrain__put_page` em `memory/context/company-brandbook` para uso futuro.

### Se DESTINO = cliente

Buscar padrão do cliente no brain:

```python
design_padrao  = mcp__elobrain__search(f"padrão design {CLIENTE} instagram")
perfil_cliente = mcp__elobrain__query(f"quem é {CLIENTE}, identidade visual, cores, fontes")
```

Se não encontrar padrão no brain:
> "Não encontrei o padrão de design de {CLIENTE} no brain. Pode me passar:
> - Cores principais (hex ou nome)
> - Fonte(s) usada(s)
> - Handle do Instagram
> - Estilo visual (clean, bold, minimalista, etc.)
> - Exemplo de post anterior (link ou descrição)?"

Salvar padrão coletado via `mcp__elobrain__put_page` em `clientes/{cliente}/design-padrao` para reuso futuro.

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

Aplicar o padrão de design carregado na Fase 1 (fontes, cores, handle, logo).

### Carrossel

Entregar estrutura completa de cada slide:

```
SLIDE 01 — GANCHO
Texto: "[headline]"
Visual: [orientação: fundo, elemento central, destaque]
Fonte: [tamanho, peso — conforme brandbook]
Cor fundo: [conforme brandbook]
Header: logo + handle (sempre — conforme brandbook)

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

Headline: "[texto]"  → posição, tamanho, fonte (conforme brandbook)
Subhead: "[texto]"   → posição, tamanho, fonte
Visual principal: [orientação: imagem, ilustração, fundo]
Logo/handle: [posição — conforme brandbook]
CTA: "[texto]" → posição, estilo
```

---

## Fase 4 — Entrega e persistência

**4.1 — Salvar artefato no brain**

```python
# Slug dinâmico baseado no destino
destino_slug = "empresa" if DESTINO == "empresa" else f"clientes/{CLIENTE_SLUG}"

mcp__elobrain__put_page(
  slug=f"marketing/instagram/{destino_slug}/{FORMATO}-{slug}",
  content=artefato_completo
)
```

**4.2 — Checklist de entrega**

```
✓ POST INSTAGRAM — {DESTINO} — {FORMATO}

Destino: {empresa | cliente: nome}
Formato: {carrossel N slides | post estático}
Copy: {criada | fornecida}
Padrão de design: {company-brandbook | padrão {cliente}}

Artefato: marketing/instagram/{destino}/{formato}-{slug}
Próximo passo: levar estrutura para diagramação (Canva | Figma | Adobe)
```

---

## Anti-Patterns

- ❌ Nunca hardcodar nome de empresa — usar `memory/context/company-brandbook` genérico
- ❌ Nunca inventar padrão de design — sempre buscar no brain primeiro
- ❌ Não pular validação de copy — aprovação explícita antes de ir pro design
- ❌ Não fazer tudo de uma vez — perguntas uma a uma, aguardar resposta
- ❌ Não usar copy longa demais por slide — carrossel: máx 30 palavras/slide; post: máx 15 palavras
- ❌ Não salvar padrão de cliente só na sessão — persistir no brain para reuso futuro

---

## Tools Used

- `mcp__elobrain__get_page` — carregar brandbook da empresa e perfis de clientes
- `mcp__elobrain__search` — buscar padrão de design do cliente
- `mcp__elobrain__query` — contexto do cliente (identidade, posicionamento)
- `mcp__elobrain__put_page` — salvar artefato + padrão de cliente/empresa novo

---

## Relação com skills existentes

- **carrossel-eloscope**: skill legada focada só em carrossel para a Eloscope. `post-instagram` é o substituto company-agnostic (multi-formato + multi-cliente). Para novos conteúdos, usar `post-instagram`.
- **elo-content**: Director que roteia para `post-instagram` quando intent é conteúdo Instagram.
