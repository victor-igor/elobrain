# elobrain

> Segundo cérebro operacional pra PMEs — código + skills + orquestração.
> Construído sobre [gbrain](https://github.com/garrytan/gbrain) (Garry Tan), com a camada de orquestração Eloscope.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Built on gbrain](https://img.shields.io/badge/built%20on-gbrain-blue)](https://github.com/garrytan/gbrain)

---

## O que é

**elobrain** é um produto comercial da [Eloscope](https://eloscope.com.br) que entrega segundo cérebro operacional pra PMEs. Combina:

- **Storage**: Postgres (Supabase) com pgvector pra vector search + knowledge graph
- **Sync**: daemon background mantém vault markdown ↔ banco em sincronia automática
- **Skills**: 48 skills atômicas + 4 Directors temáticos + 1 Coordinator único (`/elo`)
- **MCP**: integração nativa com Claude Code (e qualquer cliente MCP)
- **Time compartilhado**: múltiplas pessoas no mesmo brain via Supabase compartilhado

A camada de **orquestração `/elo`** segue o pattern Anthropic orchestrator-worker: você fala em PT-BR natural, o Coordinator classifica intent e delega ao Director certo, que invoca skills atômicas em contexto isolado.

---

## Quem usa

| Perfil | Use case |
|---|---|
| **PME com 3-10 pessoas** | Pendências, decisões, projetos, reuniões — sincronizadas entre o time |
| **Founder solo** | Memória persistente entre sessões + skills GTM (LP, deck, GTM) |
| **Agências** | Múltiplos clientes em vaults isolados, fluxos comerciais padronizados |
| **Operadores Eloscope** | Cliente nº 0 do produto (testa em si mesmo antes de vender) |

---

## Arquitetura

```
┌────────────────────────────────────────────────────────┐
│  Camada 5 — Interface (Claude Code chat)               │
│  → /elo "qualquer coisa em PT-BR"                       │
├────────────────────────────────────────────────────────┤
│  Camada 4 — Coordinator (elo) — classifica intent      │
├────────────────────────────────────────────────────────┤
│  Camada 3 — 4 Directors:                               │
│    /elo-brain    (memória/conhecimento)                │
│    /elo-ops      (operação interna)                    │
│    /elo-content  (produção de conteúdo)                │
│    /elo-vendas   (sales — delega ao gos-mission-control)│
├────────────────────────────────────────────────────────┤
│  Camada 2 — 48 Skills atômicas (briefing, query,       │
│    ingest, enrich, carrossel, salve, rotina, ...)       │
├────────────────────────────────────────────────────────┤
│  Camada 1 — Tools MCP (mcp__elobrain__*)               │
├────────────────────────────────────────────────────────┤
│  Camada 0 — Infra (Postgres + pgvector + OpenAI        │
│    embeddings + daemon sync 15/15min)                  │
└────────────────────────────────────────────────────────┘
```

Documentação completa: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — overview da stack + fluxos + multi-operador + cross-refs aos sub-docs especializados.

---

## Quick start

### Pré-requisitos
- macOS ou Linux
- [Bun](https://bun.sh) (`curl -fsSL https://bun.sh/install | bash`)
- Conta Supabase (free tier funciona — depois Pro $25/mês quando crescer)
- API key OpenAI (`text-embedding-3-large` — ~$0.13 / 1M tokens)

### Setup

```bash
# 1. Clone
git clone https://github.com/victor-igor/elobrain.git ~/elobrain
cd ~/elobrain && bun install && bun link

# 2. Configurar env
cat > ~/.elobrain.env <<'EOF'
export OPENAI_API_KEY="sk-..."
export GBRAIN_DATABASE_URL="postgresql://postgres.<project>:<pass>@aws-1-<region>.pooler.supabase.com:6543/postgres?options=-c%20search_path%3Delobrain%2Cpublic"
EOF
chmod 600 ~/.elobrain.env

# 3. Habilitar pgvector no Supabase (1x)
# No painel SQL editor:
# CREATE SCHEMA IF NOT EXISTS elobrain;
# CREATE EXTENSION IF NOT EXISTS vector;

# 4. Inicializar
source ~/.elobrain.env
elobrain init

# 5. Importar seu vault markdown
elobrain sync --repo ~/seu-vault

# 6. (Opcional) Configurar MCP no Claude Code
claude mcp add elobrain --scope user \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  -e GBRAIN_DATABASE_URL="$GBRAIN_DATABASE_URL" \
  -- elobrain serve

# 7. (Opcional) Daemon de sync background a cada 15 min
# Ver docs/DAEMON.md
```

---

## Uso

### Modo natural — via Coordinator

```bash
/elo me prepara pro dia
# → /elo-ops → /rotina (cockpit matinal: emails + agenda + top 3)

/elo busca decisões sobre Morgana
# → /elo-brain → /query (busca semântica + citações)

/elo salva esse link <url>
# → /elo-brain → /idea-ingest (cria page, cross-link entidades)

/elo carrossel sobre IA pra PMEs
# → /elo-content → /carrossel-eloscope (HTML 6 slides com design system)

/elo LP pra Clínica X com ângulo DOR
# → /elo-vendas → /gos-mission-control (pipeline LP completo)

/elo salva sessão
# → /elo-ops → /salve (flush + commit + push + sync)
```

### Modo expert — skill direta

```bash
/briefing                # briefing do dia
/query "morgana"         # busca semântica
/idea-ingest <url>       # captura link
/salve                   # flush sessão
/carrossel-eloscope ...  # carrossel
/maintain                # audit brain health
# ... e mais 42 skills
```

---

## Diferenças em relação ao gbrain

| | gbrain (upstream) | elobrain (este fork) |
|---|---|---|
| Coordinator único | ❌ Resolver direto | ✅ `/elo` com 7 buckets PT-BR |
| Directors temáticos | ❌ skills "achatadas" | ✅ 4 Directors (brain/ops/content/vendas) |
| Skills custom Eloscope | — | ✅ cerebro, salve, rotina, reuniao, carrossel-eloscope |
| Integração growth-os-skills | — | ✅ `/elo-vendas` delega pro `/gos-mission-control` |
| Branding | gbrain (Garry Tan) | elobrain (Eloscope) |
| Schema banco | `public.*` | `elobrain.*` (isolado, multi-tenant ready) |
| Idioma | EN | PT-BR primary |
| Daemon sync | manual ou opcional | LaunchAgent macOS pré-configurado |

**Compatibilidade upstream**: este fork mantém intacto o código core. Atualizações do gbrain (Garry) podem ser puxadas via `git pull upstream main`.

---

## Stack técnico

- **Runtime**: Bun (TypeScript)
- **DB**: PostgreSQL 17 + pgvector (PGLite local OU Supabase hosted)
- **Embeddings**: OpenAI `text-embedding-3-large` (default) ou Voyage/Ollama/etc
- **MCP**: stdio + HTTP/OAuth (Claude Code, Cursor, ChatGPT, Claude Desktop)
- **Vault**: markdown plain (compatible Obsidian, VS Code, etc)
- **Sync**: git diff → embeddings incrementais

---

## Status

**Alpha**. Em uso interno na Eloscope (cliente nº 0). Vai entrar em beta privado com 1-2 clientes próximos antes de lançamento público. **Não usar em produção sem alinhamento.**

---

## Atribuição

elobrain é um fork comercial de [**gbrain**](https://github.com/garrytan/gbrain) por [Garry Tan](https://github.com/garrytan) (CEO, Y Combinator).

O gbrain é licenciado MIT — veja [`LICENSE`](LICENSE). O README original do gbrain está preservado em [`README-gbrain-upstream.md`](README-gbrain-upstream.md) com toda a história, benchmarks e detalhes técnicos do projeto upstream.

A Eloscope adiciona:
- Camada de orquestração `/elo` (Coordinator + 4 Directors)
- Skills custom (cerebro, salve, rotina, reuniao, carrossel-eloscope)
- Integração com growth-os-skills (`/elo-vendas`)
- Daemon de sync pré-configurado pra macOS
- Distribuição como produto comercial pra PMEs brasileiras

A relação com o upstream:
```bash
git remote -v
# origin    https://github.com/victor-igor/elobrain.git  (este repo)
# upstream  https://github.com/garrytan/gbrain.git      (gbrain canônico)
```

---

## Roadmap

| Versão | Foco | Status |
|---|---|---|
| v0.1 | Coordinator + 4 Directors + 48 skills | ✅ shipped |
| v0.2 | `elobrain init` wizard, INSTALL.md, RLS multi-tenant | em planejamento |
| v0.3 | OpenClaw integration, cliente onboarding self-service | futuro |
| v0.4 | Cloud-hosted opcional, billing, dashboard cliente | futuro |

---

## Suporte

- **Eloscope contato**: [eloscope.com.br](https://eloscope.com.br) · eloscope.coo@gmail.com
- **Bugs / features do fork**: [issues neste repo](https://github.com/victor-igor/elobrain/issues)
- **Bugs do gbrain upstream**: [garrytan/gbrain issues](https://github.com/garrytan/gbrain/issues)

---

## License

MIT (igual ao upstream gbrain). Veja [`LICENSE`](LICENSE).

A Eloscope mantém o copyright original do Garry Tan no LICENSE e adiciona seu copyright sobre as contribuições próprias (camada de orquestração, skills custom, distribuição comercial).
