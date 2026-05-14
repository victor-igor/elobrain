# 06 — Heartbeat (economia de tokens — INFRA do tick)

> Este arquivo cobre **só a infra** (config técnica de quando/como o tick dispara). Para o **conteúdo proativo** (o que o agente checa, mandato, regras de fala, crons isolados) → `references/15-proatividade.md`.

## 6.1. O que é

`heartbeat` é o subsistema que dispara um "tick" periódico do agente — útil para tarefas proativas (monitorar e-mail, rever pendências, lembrar o user). Cada tick é uma chamada LLM completa.

> **Importante:** Se `HEARTBEAT.md` no workspace estiver vazio, **nenhum tick LLM dispara** (comportamento documentado pelo template). Mas vale deixar a config armada para quando você ativar.

## 6.2. Snippet recomendado

`snippets/heartbeat.json`:

```json
{
  "agents": {
    "defaults": {
      "heartbeat": {
        "every": "1h",
        "activeHours": {
          "start": "06:00",
          "end": "20:00",
          "timezone": "America/Sao_Paulo"
        },
        "model": "Gemini 2.5 Flash",
        "lightContext": true,
        "isolatedSession": true,
        "includeReasoning": false,
        "includeSystemPromptSection": false,
        "suppressToolErrorWarnings": true
      }
    }
  }
}
```

### Por que cada campo

| Campo | Razão |
|---|---|
| `every: "1h"` | 1 tick/hora — boa frequência baseline |
| `activeHours 06-20 / America/Sao_Paulo` | Corta ~40% dos ticks teóricos (sem ticks de madrugada) |
| `model: "Gemini 2.5 Flash"` | Mais barato disponível |
| `lightContext: true` | Não injeta arquivos bootstrap pesados |
| `isolatedSession: true` | Cada tick é stateless — não acumula histórico |
| `includeReasoning: false` | Pula o trace de raciocínio (economia) |
| `includeSystemPromptSection: false` | Remove ~800-1500 tokens do system prompt (validar com áudio/conversa real) |
| `suppressToolErrorWarnings: true` | Não polui prompt com erros transitórios |

> Nada disso afeta as conversas principais com o usuário — o escopo é só o tick do heartbeat.

## 6.3. Aplicação

```bash
./scripts/oc-backup.sh openclaw.json
./scripts/oc-json-patch.py "$OC_CONFIG_PATH" snippets/heartbeat.json
./scripts/oc-wrap.sh "config validate"
./scripts/oc-reload.sh hot-reload
```

Hot reload — sem restart.

## 6.4. Verificação

```bash
./scripts/oc-wrap.sh "config get agents.defaults.heartbeat"
$PFX docker logs $OC_CONTAINER --tail 200 | grep -iE 'heartbeat'   # docker
$PFX journalctl -u openclaw -n 200 | grep -iE 'heartbeat'           # native
```

## 6.5. Quando ajustar

- **Custo subiu sem motivo:** subir `every` para `2h`, encurtar `activeHours` (ex: `08:00-18:00`).
- **Quero mais reações proativas:** descer `every` para `30m` mas usar Haiku 4.5 / Gemini Flash.
- **Heartbeat travou no debug:** desligar `every` e popular `HEARTBEAT.md` vazio (zero custo).

## 6.6. Pegadinha

`heartbeat.model` precisa estar disponível no catálogo (provider habilitado). Se setar `"Gemini 2.5 Flash"` sem `GEMINI_API_KEY`, o heartbeat tenta o fallback — mas se não houver, o tick falha silenciosamente. Confirmar:

```bash
./scripts/oc-wrap.sh "models status" | grep -i gemini
```
