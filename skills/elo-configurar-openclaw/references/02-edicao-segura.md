# 02 — Edição segura de `openclaw.json` e `.env`

> Toda mudança passa por: **backup → patch → validate → reload/restart/recreate → verify**.

## 2.1. Backup (sempre)

Padrão: `<arquivo>.bak-YYYYMMDD-HHMMSS`. Use `scripts/oc-backup.sh`:

```bash
./scripts/oc-backup.sh openclaw.json    # gera .bak-... do JSON
./scripts/oc-backup.sh env              # gera .bak-... do .env
```

Em `*-docker`: backup é do arquivo no host (não dentro do container — eles são bind-mount, mesmo arquivo).

## 2.2. Patch JSON (deep-merge, preservando o resto)

NUNCA reescreva o `openclaw.json` inteiro. Use deep-merge via Python (`scripts/oc-json-patch.py`):

```bash
./scripts/oc-json-patch.py "$OC_CONFIG_PATH" snippets/heartbeat.json
```

O script:
1. Carrega o JSON original
2. Deep-merge do snippet (objetos mesclam recursivo; arrays substituem)
3. Escreve em `<arquivo>.tmp` e renomeia atomicamente
4. Reaplica owner (`OC_OWNER`) — crítico em docker pra não quebrar o watcher

Para mudanças muito específicas (set de um único campo), use também o script — passe um JSON minimal:

```bash
echo '{"agents":{"defaults":{"thinkingDefault":"medium"}}}' | \
  ./scripts/oc-json-patch.py "$OC_CONFIG_PATH" -
```

## 2.3. Edição de `.env`

```bash
./scripts/oc-env-set.sh OPENAI_API_KEY 'sk-...'
./scripts/oc-env-set.sh GEMINI_API_KEY 'AIza...'
```

Regras:
- Aspas simples no valor para evitar expansão.
- Valores com `=` no meio são suportados (split apenas no primeiro `=`).
- Mascarar nos logs (`sk-…últimos4`).
- Em `*-native`: o equivalente é editar override systemd (`/etc/systemd/system/openclaw.service.d/override.conf`) — use `oc-systemd-env-set.sh`.

## 2.4. Validar

**SEMPRE** antes de qualquer recreate / restart:

```bash
./scripts/oc-wrap.sh "config validate"
```

Saída esperada: `✅ Configuration valid — 0 warnings` (ou similar).

Se inválido: rollback e investigar (a saída traz o path + regra violada).

## 2.5. Decidir: reload | restart | recreate

| Mudança | O que aplicar |
|---|---|
| `tools.media.*`, `tools.media.models` | **Hot reload** — só salvar e checar logs |
| `agents.defaults.heartbeat.*` | **Hot reload** |
| `agents.defaults.model.primary` | **Hot reload** |
| `agents.defaults.model.fallbacks` | **Hot reload** |
| `agents.defaults.thinkingDefault` | **Hot reload** |
| `agents.defaults.compaction.*` | **Hot reload** (na maioria dos casos) |
| Mudança em `.env` (qualquer chave) | **Recreate** (`docker compose up -d --force-recreate openclaw`) |
| Mudança em override systemd (native) | `daemon-reload` + `systemctl restart openclaw` |
| `plugins.entries.X.enabled` (toggle) | **Restart** do gateway (CLI mostra "Restart the gateway to apply") |
| `plugins.entries.X.config.*` em plugin já habilitado | **Hot reload** geralmente; se em dúvida, restart |
| `skills.load.extraDirs` (novo dir) | **Restart** do gateway |
| `skills.entries.X.enabled` | Hot reload — mas sessões já abertas não veem (ver 2.7) |

Use `scripts/oc-reload.sh <kind>`:

```bash
./scripts/oc-reload.sh hot-reload          # apenas espera 2-3s e checa logs
./scripts/oc-reload.sh restart             # gateway restart (CLI)
./scripts/oc-reload.sh recreate            # docker compose recreate
./scripts/oc-reload.sh systemd-restart     # native
```

## 2.6. Verificar logs do reload

Hot reload bem sucedido:
```
[reload] config change applied (dynamic reads: agents.defaults.heartbeat)
```

Se não aparecer em 5-10s: provavelmente a mudança precisa restart. Cair pra `restart`/`recreate`.

```bash
# docker
$PFX docker logs $OC_CONTAINER --tail 100 | grep -iE 'reload|error'

# native
$PFX journalctl -u openclaw -n 100 --no-pager | grep -iE 'reload|error'
```

## 2.7. Sessões cacheadas

- Sessões Telegram/WhatsApp já abertas têm o system prompt cacheado (skills, tools, modelos do momento da abertura).
- Para refletir mudanças em skills/tools NESSAS sessões, peça ao usuário enviar `/start` no bot (reseta a sessão).

## 2.8. Rollback rápido

Se algo deu errado:

```bash
# JSON
./scripts/oc-rollback.sh openclaw.json     # cp do .bak mais recente
# .env
./scripts/oc-rollback.sh env

# Recreate (.env mudou) ou hot-reload (apenas JSON)
./scripts/oc-reload.sh recreate
```

## 2.9. Lista de pegadinhas (resumo)

1. `docker compose restart` ≠ `recreate`. Sempre `up -d --force-recreate` quando `.env` mudou.
2. `openclaw config set` no container reseta owner pra root e quebra o watcher (EACCES). Se usar, `chown 1000:1000` depois.
3. Cron expressions = 5/6/7 partes. NUNCA shorthand (`"1d"`, `"30m"` rejeitados).
4. Plugins: `entries.X.enabled` no nível raiz; tudo mais em `entries.X.config`. Errar isso quebra TODO o boot.
5. `openclaw config validate` = seu amigo. Roda antes de QUALQUER recreate.
