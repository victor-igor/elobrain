# 08 — Plugins

> 🔴 Pegadinha global: `plugins.entries.X.enabled` no nível RAIZ; toda config específica em `plugins.entries.X.config`. Errar isso quebra TODO o boot (efeito cascata — até telegram para de habilitar).

## 8.1. Listar / inspecionar

```bash
./scripts/oc-wrap.sh "plugins list"
./scripts/oc-wrap.sh "plugins inspect firecrawl"
```

## 8.2. Habilitar / desabilitar (CLI)

```bash
./scripts/oc-wrap.sh "plugins enable firecrawl"
./scripts/oc-wrap.sh "plugins disable firecrawl"
```

CLI mostra "Restart the gateway to apply" — é hint pra restart. Use:
```bash
./scripts/oc-reload.sh restart
```

(Se mudou `.env` no meio — caso de plugin que precisa de chave nova — use `recreate`.)

## 8.3. Estrutura de config

```json
{
  "plugins": {
    "entries": {
      "<plugin-id>": {
        "enabled": true,
        "config": {
          /* config específica do plugin */
        }
      }
    }
  }
}
```

## 8.4. Plugin: `firecrawl` (web search/scrape)

Já vem bundled, disabled por padrão.

```bash
# 1. Adicionar chave
./scripts/oc-env-set.sh FIRECRAWL_API_KEY 'fc-...'

# 2. Habilitar
./scripts/oc-wrap.sh "plugins enable firecrawl"

# 3. Recreate (porque mexeu no .env)
./scripts/oc-reload.sh recreate

# 4. Verificar
./scripts/oc-wrap.sh "plugins inspect firecrawl"
# Esperado: Status: loaded
```

Tools registradas: `firecrawl_search`, `firecrawl_scrape`. Capability: `web-search: firecrawl`.

> Plano gratuito: 500 req/mês em https://www.firecrawl.dev/app.

## 8.5. Plugin: `active-memory` (memória proativa)

Subagent que injeta memórias relevantes antes de cada resposta automaticamente. Sem isso, memória é "passiva".

`snippets/active-memory.json`:

```json
{
  "plugins": {
    "entries": {
      "active-memory": {
        "enabled": true,
        "config": {
          "enabled": true,
          "model": "ChatGPT 4.1",
          "modelFallback": "Gemini 2.5 Flash",
          "thinking": "off",
          "timeoutMs": 15000,
          "queryMode": "recent",
          "maxSummaryChars": 1000,
          "recentUserTurns": 3,
          "recentAssistantTurns": 3,
          "logging": false
        }
      }
    }
  }
}
```

### Limites estritos do `active-memory.config`

Descobertos via `openclaw config validate`:
- `queryMode` ∈ `{message, recent, full}` — NÃO aceita `"auto"`.
- `maxSummaryChars` ≤ `1000`.
- `recentUserTurns` ≤ `3`.
- `recentAssistantTurns` ≤ `3`.
- `logging` é boolean (não string).

### Aplicar

```bash
./scripts/oc-json-patch.py "$OC_CONFIG_PATH" snippets/active-memory.json
./scripts/oc-wrap.sh "config validate"
./scripts/oc-reload.sh restart
```

> Custo: ~1 chamada adicional/turno em GPT-4.1 (centavos por interação). Avise o usuário.

## 8.6. Plugin: `memory-core` (com dreaming)

Indexa o workspace `memory/` (vector + FTS) e roda dreaming (consolidação noturna).

`snippets/dreaming.json`:

```json
{
  "plugins": {
    "entries": {
      "memory-core": {
        "enabled": true,
        "config": {
          "dreaming": {
            "enabled": true,
            "frequency": "0 3 * * *",
            "timezone": "America/Sao_Paulo",
            "verboseLogging": false,
            "storage": { "mode": "separate", "separateReports": true },
            "phases": {
              "light": { "enabled": true, "lookbackDays": 1, "limit": 50, "dedupeSimilarity": 0.85 },
              "deep":  { "enabled": true, "limit": 10, "minScore": 0.5, "minRecallCount": 1, "minUniqueQueries": 1, "recencyHalfLifeDays": 14, "maxAgeDays": 90 },
              "rem":   { "enabled": true, "lookbackDays": 7, "limit": 5, "minPatternStrength": 0.3 }
            }
          }
        }
      }
    }
  }
}
```

> `frequency` exige cron expression (5/6/7 partes). Strings tipo `"1d"` ou `"30m"` são rejeitadas.

```bash
./scripts/oc-json-patch.py "$OC_CONFIG_PATH" snippets/dreaming.json
./scripts/oc-wrap.sh "config validate"
./scripts/oc-reload.sh restart
```

Verificar:
```bash
./scripts/oc-wrap.sh "memory status"      # mostra "dreaming agendado"
./scripts/oc-wrap.sh "memory promote"     # forçar dreaming agora
./scripts/oc-wrap.sh "memory rem-harness" # preview sem escrever
```

## 8.7. Plugin: `telegram` / `whatsapp`

Ver `references/10-canais.md` para dmPolicy e config completa.

## 8.8. Plugin: `deepgram` (transcrição alternativa)

Existe mas geralmente sem chave. Se quiser usar:
```bash
./scripts/oc-env-set.sh DEEPGRAM_API_KEY '...'
./scripts/oc-wrap.sh "plugins enable deepgram"
./scripts/oc-reload.sh recreate
```

## 8.9. Procedimento padrão pra habilitar qualquer plugin

```
1. (se precisar chave) → oc-env-set.sh CHAVE valor
2. plugins enable <id>
3. (se houver config customizada) → oc-json-patch.py snippet
4. config validate
5. reload (recreate se .env mudou; restart caso contrário)
6. plugins inspect <id> (Status: loaded)
```
