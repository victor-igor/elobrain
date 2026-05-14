# 14 — Armadilhas e lições aprendidas

> Catálogo das pegadinhas que aparecem com mais frequência. Antes de "isso não funciona" — confira aqui.

## 14.1. `docker compose restart` ≠ recreate

**Sintoma:** Adicionei nova chave no `.env`, fiz `restart`, gateway não enxerga a chave.

**Causa:** `restart` mantém env vars antigos.

**Solução:** Sempre `docker compose up -d --force-recreate openclaw` quando `.env` mudou.

## 14.2. `openclaw config set` no container reseta owner

**Sintoma:** Após `docker exec ... openclaw config set X`, o watcher do JSON quebra (logs com `EACCES`).

**Causa:** O CLI escreve como root, mas o gateway roda como UID 1000 e o watcher precisa permissão de leitura/notify.

**Solução:**
```bash
$PFX docker exec $OC_CONTAINER chown 1000:1000 /data/.openclaw/openclaw.json
```

**Prevenção:** preferir editar JSON via `python3` no host (`scripts/oc-json-patch.py`).

## 14.3. Frontmatter ausente em skill custom

**Sintoma:** Skill criada não aparece em `openclaw skills list`.

**Causa:** SKILL.md sem `---\nname: …\ndescription: …\n---` no início.

**Solução:** adicionar frontmatter conforme `references/09-skills-customizadas.md §9.2`.

## 14.4. Plugin config no nível errado

**Sintoma:** Boot quebra em cascata. Até telegram para de habilitar.

**Causa:** Você pôs `plugins.entries.X.queryMode` direto, em vez de `plugins.entries.X.config.queryMode`.

**Solução:** sempre estrutura `entries.X.enabled` no nível raiz; tudo mais em `entries.X.config`.

```json
{
  "plugins": {
    "entries": {
      "active-memory": {
        "enabled": true,
        "config": {
          "queryMode": "recent"
        }
      }
    }
  }
}
```

## 14.5. `active-memory.config` tem limites estritos

**Sintoma:** `openclaw config validate` rejeita a config.

**Causa (descoberto via tentativa e erro):**
- `queryMode` ∈ `{message, recent, full}` — NÃO aceita `"auto"`.
- `maxSummaryChars` ≤ `1000`.
- `recentUserTurns` ≤ `3`, `recentAssistantTurns` ≤ `3`.
- `logging` é boolean (não string).

## 14.6. Cron expression vs shorthand

**Sintoma:** `dreaming.frequency: "1d"` é rejeitado com erro `CronPattern`.

**Causa:** Campos cron exigem 5/6/7 partes (formato cron clássico).

**Solução:** `"0 3 * * *"` (todo dia às 3h), `"0 * * * *"` (de hora em hora), etc.

## 14.7. Sessão com system prompt cacheado

**Sintoma:** Adicionei skill nova, mas no Telegram o agente diz "não tenho essa skill".

**Causa:** Sessão Telegram já aberta tem snapshot de skills/tools/modelos do momento da abertura.

**Solução:** user envia `/start` no bot, OU pede explicitamente "liste suas skills" pra forçar reload.

## 14.8. Heartbeat parece não disparar

**Sintoma:** Configurei `every: "1h"`, esperei 2h, nenhum log de heartbeat.

**Causa:** `HEARTBEAT.md` no workspace está vazio. Heartbeat só dispara LLM se houver tarefas.

**Solução:** popular `HEARTBEAT.md` com instruções/itens. (Ou aceitar que vazio = zero custo, comportamento esperado.)

## 14.9. `tools.profile: messaging` (default ≥ v2026.3.2)

**Sintoma:** Bot responde mas não executa nada ("não consigo fazer isso").

**Causa:** A partir de v2026.3.2, default é `messaging` (só conversa).

**Solução:**
```bash
./scripts/oc-wrap.sh "config set tools.profile full"
./scripts/oc-wrap.sh "config validate"
./scripts/oc-reload.sh restart
```

## 14.10. Timezone — crons disparam em UTC

**Sintoma:** Cron "todo dia às 9h" dispara às 12h.

**Causa:** Sem `OPENCLAW_TZ`, default = UTC (Brasil = UTC-3).

**Solução:** `references/03-providers-modelos.md §Timezone`.

## 14.11. `agents.list[*].model` vs `agents.defaults.model.primary`

**Sintoma:** `Unknown model: ChatGPT 4.1` quando bate o gateway.

**Causa:** Confusão de formatos:
- `agents.list[*].model` usa `provider/modelo` em minúsculo (ex: `openai/gpt-4.1`).
- `agents.defaults.model.primary` usa nome humano com case (ex: `"ChatGPT 4.1"`).

**Solução:** Confira nomes via `openclaw models list --all`.

## 14.12. Provider não registrado no boot

**Sintoma:** `Gemini 2.5 Flash` não aparece em `models list --all`.

**Causa:** `GEMINI_API_KEY` ausente no `.env` — provider `google` não é registrado no boot do `server.mjs`.

**Solução:** adicionar a chave + `recreate`.

## 14.13. UFW preso fora

**Sintoma:** Liguei UFW, perdi acesso SSH.

**Causa:** SSH key não estava configurada / autorizada antes de `ufw enable`.

**Prevenção:**
```bash
ssh -o BatchMode=yes -o ConnectTimeout=5 $OC_HOST true && echo OK   # antes de ufw
ssh $OC_HOST 'sudo ufw allow ssh'                                    # antes de enable
```

Se já preso: usar terminal do painel hPanel (Hostinger) para reverter UFW.

## 14.14. WhatsApp/Telegram allowlist com username em vez de ID

**Sintoma:** `dmPolicy: allowlist` com `["@kelvin"]` — todo mundo é bloqueado, inclusive eu.

**Causa:** Allowlist aceita só IDs (Telegram) ou telefones E.164 (WhatsApp). Usernames falham silenciosamente.

**Solução:** descobrir ID via logs (ver `references/10-canais.md §10.2`).

## 14.15. `extraDirs` adicionado mas skill não descoberta

**Sintoma:** Adicionei `skills.load.extraDirs`, hot reload não aplicou.

**Causa:** Mudanças em `skills.load.extraDirs` exigem **restart** do gateway (não só hot reload).

**Solução:** `./scripts/oc-reload.sh restart`.

## 14.16. systemd override sobrescrevendo secrets

**Sintoma:** Troquei a chave via `openclaw secrets set`, mas o gateway continua usando a antiga.

**Causa:** systemd override em `/etc/systemd/system/openclaw.service.d/override.conf` tem prioridade — se a chave estiver lá, vence o secrets.

**Solução:** remover/atualizar a chave do override:
```bash
sudo systemctl edit openclaw
sudo systemctl daemon-reload
sudo systemctl restart openclaw
```

## 14.17. JSON inválido = boot quebra TUDO

**Sintoma:** Tudo para de funcionar de uma vez.

**Causa:** JSON inválido (vírgula a mais, aspas erradas, plugin config no lugar errado).

**Solução imediata:**
```bash
./scripts/oc-rollback.sh openclaw.json
./scripts/oc-reload.sh recreate
```

**Prevenção:** sempre `openclaw config validate` antes de qualquer recreate.
