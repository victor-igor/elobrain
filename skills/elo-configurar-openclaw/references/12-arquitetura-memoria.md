# 12 — Arquitetura de memória

> Combina: estrutura de arquivos no workspace + plugin `memory-core` (vector + FTS + dreaming) + plugin `active-memory` (proativo).

## 12.1. Estrutura recomendada do workspace

```
<workspace>/
├── MEMORY.md                    ← índice geral (always-loaded)
├── AGENTS.md                    ← + seção "Memory Architecture" anexada
└── memory/
    ├── pending.md
    ├── context/
    │   ├── decisions.md          (5 decisões pré-populadas: infra, modelos, segurança)
    │   ├── lessons.md            (4 estratégicas + 2 táticas)
    │   ├── people.md             (placeholder vazio — preencher)
    │   └── business-context.md   (placeholder vazio)
    ├── projects/
    │   └── EXEMPLO-projeto.md    (template)
    ├── sessions/
    │   └── YYYY-MM-DD.md         (diário raw por sessão)
    ├── integrations/
    │   └── openclaw-stack.md     (mapa do stack)
    └── feedback/
        ├── content.json
        ├── tasks.json
        └── tone.json
```

`memory-core` indexa **recursivamente** qualquer arquivo dentro do workspace `memory/`. Subpastas funcionam sem config extra.

## 12.2. Como criar a estrutura

```bash
WS=$($PFX bash -c 'echo $OC_COMPOSE_DIR/data/.openclaw/workspace')   # docker
# WS=~/.openclaw/workspace                                            # native

ssh $OC_HOST "mkdir -p $WS/memory/{context,projects,sessions,integrations,feedback}"
ssh $OC_HOST "touch $WS/memory/pending.md"
ssh $OC_HOST "touch $WS/memory/context/{decisions,lessons,people,business-context}.md"
ssh $OC_HOST "echo '{}' > $WS/memory/feedback/content.json"
ssh $OC_HOST "echo '{}' > $WS/memory/feedback/tasks.json"
ssh $OC_HOST "echo '{}' > $WS/memory/feedback/tone.json"

# Owner em docker
ssh $OC_HOST "chown -R 1000:1000 $WS/memory"
```

## 12.3. Anexar seção em AGENTS.md

Adicionar no fim do `AGENTS.md`:

```markdown
## Memory Architecture

Workspace memory lives in `memory/` (subdiretórios indexados recursivamente):

- `pending.md` — itens em aberto que precisam follow-up
- `context/` — fatos sobre decisões, lições, pessoas, contexto do negócio
- `projects/` — um arquivo por projeto ativo
- `sessions/` — diário raw por sessão
- `integrations/` — mapa de stack/sistemas
- `feedback/` — JSONs estruturados (content/tasks/tone)

Para acessar:
- `memory_search("<termo>")` → semantic + FTS combinados
- `memory_get("<path>")` → leitura direta
- Editar arquivos diretamente é OK; o índice reindexa automaticamente

Ao final de cada sessão útil:
1. Anotar decisão/lição/projeto novo no arquivo correto
2. Limpar `pending.md` (mover concluídos pra `sessions/<data>.md`)
```

## 12.4. Plugin `memory-core` + dreaming

Ver `references/08-plugins.md §8.6`. Snippet em `snippets/dreaming.json`.

Dreaming roda 1×/dia (default `0 3 * * *` America/Sao_Paulo), escaneia memórias recentes, promove relevantes pro `MEMORY.md` e gera Dream Diary em `DREAMS.md`.

## 12.5. Plugin `active-memory` (proativo)

Ver `references/08-plugins.md §8.5`. Snippet em `snippets/active-memory.json`.

Sem isso, memória é "passiva" (só consulta quando AGENTS.md instrui ou usuário pede). Com o plugin, um subagent injeta memórias relevantes ANTES de cada resposta automaticamente.

## 12.6. Compaction memoryFlush

Ver `references/07-compaction-memoria.md`. Garante extração de memória ANTES de compactar (não dependendo só do AGENTS.md textual).

## 12.7. Verificações

```bash
./scripts/oc-wrap.sh "memory status"
# Esperado:
#  - 9/9 arquivos indexados, N chunks
#  - Vector search: ✅ ready (sqlite-vec, dims 1536)
#  - FTS: ✅ ready
#  - Provider de embeddings: openai/text-embedding-3-small
#  - Dreaming agendado: 0 3 * * * America/Sao_Paulo

./scripts/oc-wrap.sh "memory search 'termo'"
./scripts/oc-wrap.sh "memory index"          # forçar reindex
./scripts/oc-wrap.sh "memory promote"        # forçar dreaming agora
./scripts/oc-wrap.sh "memory rem-harness"    # preview dreaming sem escrever
```

## 12.8. Custo de embeddings

`memory-core` usa **OpenAI `text-embedding-3-small`** por padrão (~US$ 0,02/M tokens). Custo baixo mas não zero.

Para zerar:
- Trocar provider de embeddings pra Gemini ou backend local (config no `memory-core.config.embeddings`).
- Ou usar `memory-lancedb` (alternativa local) — vale a pena se acumular >1k arquivos de memória (~60-90 dias).

## 12.9. Pegadinhas

- `memory-core` indexa após salvar — se editar arquivo via `docker exec` com root, watcher pode falhar (volta pro problema de owner).
- Subpastas em `memory/` são livres — mas mantenha consistência: o agente aprende a buscar com base nos paths.
- Dreaming exige `frequency` em cron expression (5/6/7 partes), nunca shorthand.
- `dreaming.phases.deep` só roda em memórias com `minRecallCount ≥ 1` — se nada foi acessado em 14 dias, deep não promove.
