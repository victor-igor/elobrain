# 07 — Compaction + memoryFlush

## 7.1. O que é

`compaction` é o subsistema que mantém a conversa abaixo do limite de contexto. Sem isso, sessões longas estouram tokens e o agente trava.

`memoryFlush` (sub-config) força a extração de memórias relevantes ANTES de compactar — assim o que importa vai pra `memory/` e não some.

## 7.2. Modos

| Mode | Comportamento |
|---|---|
| `default` | Compacta automaticamente quando passa do limite |
| `safeguard` | Compacta com margem de segurança (recomendado) |
| `aggressive` | Compacta cedo, ideal pra economia extrema |

## 7.3. Snippet recomendado

`snippets/compaction-memory-flush.json`:

```json
{
  "agents": {
    "defaults": {
      "compaction": {
        "mode": "safeguard",
        "memoryFlush": {
          "enabled": true,
          "softThresholdTokens": 8000,
          "forceFlushTranscriptBytes": "2mb"
        }
      },
      "contextTokens": 160000,
      "reserveTokensFloor": 30000
    }
  }
}
```

### Por que

- `memoryFlush.enabled: true` — extração ANTES de compactar, garantindo persistência além do AGENTS.md textual.
- `softThresholdTokens: 8000` — começa a flush em ~8k tokens da extração (margem confortável).
- `forceFlushTranscriptBytes: "2mb"` — fallback se a transcrição ficar grande demais.
- `contextTokens: 160000` / `reserveTokensFloor: 30000` — manter margem segura no provider (Claude tem 200k, GPT-4.1 tem 1M, mas reservar 30k é prudente).

## 7.4. Aplicação

```bash
./scripts/oc-backup.sh openclaw.json
./scripts/oc-json-patch.py "$OC_CONFIG_PATH" snippets/compaction-memory-flush.json
./scripts/oc-wrap.sh "config validate"
./scripts/oc-reload.sh hot-reload
```

## 7.5. Verificação

```bash
./scripts/oc-wrap.sh "config get agents.defaults.compaction"
./scripts/oc-wrap.sh "config get agents.defaults.contextTokens"
```

Confirmar nos logs ao fim de uma sessão grande: `[compaction] flushed memories before compact: N items`.

## 7.6. Pegadinha

- `memoryFlush` exige `memory-core` plugin habilitado. Se não estiver, o flush não persiste — só tira do contexto.
- `contextTokens` muito alto (sem reserve adequado) causa timeout/erro no provider quando a janela enche.
