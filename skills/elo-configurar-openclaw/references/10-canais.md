# 10 — Canais (Telegram, WhatsApp)

## 10.1. Telegram — setup do bot

```bash
# 1. No celular, falar com @BotFather → /newbot → guardar token
# 2. Adicionar token
./scripts/oc-env-set.sh TELEGRAM_BOT_TOKEN '...'

# 3. Habilitar plugin (se não estiver)
./scripts/oc-wrap.sh "plugins enable telegram"

# 4. Recreate (mexeu .env)
./scripts/oc-reload.sh recreate

# 5. Mandar /start no bot
```

## 10.2. Telegram — config recomendada

`snippets/telegram-allowlist.json`:

```json
{
  "plugins": {
    "entries": {
      "telegram": {
        "enabled": true,
        "config": {
          "dmPolicy": "allowlist",
          "allowlist": [<SEU_TELEGRAM_ID>],
          "streaming": true,
          "topicsEnabled": true
        }
      }
    }
  }
}
```

| Campo | Valor recomendado | Razão |
|---|---|---|
| `dmPolicy` | `allowlist` | Só IDs autorizados podem falar com o bot |
| `allowlist` | `[seu_id_telegram]` | Lista de IDs numéricos |
| `streaming` | `true` (default ≥ v2026.3.2) | Mostra "digitando..." em tempo real |
| `topicsEnabled` | `true` | Permite usar grupos com tópicos (1 sessão por tópico) |

### Como descobrir seu Telegram ID

```bash
# Mandar uma mensagem no bot, depois:
./scripts/oc-wrap.sh "gateway logs" | grep -iE 'from_id|chat_id|telegram'
```

ID aparece como número (ex: `123456789`).

## 10.3. WhatsApp — setup

```bash
# 1. (Hostinger / WhatsApp Business / Meta Cloud API)
./scripts/oc-env-set.sh WHATSAPP_TOKEN '...'
./scripts/oc-env-set.sh WHATSAPP_PHONE_ID '...'

# 2. Habilitar
./scripts/oc-wrap.sh "plugins enable whatsapp"

# 3. Recreate
./scripts/oc-reload.sh recreate
```

## 10.4. WhatsApp — config crítica

`snippets/whatsapp-allowlist.json`:

```json
{
  "plugins": {
    "entries": {
      "whatsapp": {
        "enabled": true,
        "config": {
          "dmPolicy": "allowlist",
          "allowlist": ["+5511999999999"],
          "debounceMs": 4000,
          "groupPolicy": "deny"
        }
      }
    }
  }
}
```

| Campo | Recomendado | Razão |
|---|---|---|
| `dmPolicy` | `allowlist` | WhatsApp é público — sem allowlist, qualquer um conversa |
| `allowlist` | `["+55..."]` | Telefones em E.164 |
| `debounceMs` | `3000-5000` | Agrupa mensagens rápidas (1 LLM call em vez de N) |
| `groupPolicy` | `deny` ou `allowlist` | Sem isso, qualquer grupo vira sessão |

## 10.5. Aplicação

```bash
./scripts/oc-backup.sh openclaw.json
./scripts/oc-json-patch.py "$OC_CONFIG_PATH" snippets/telegram-allowlist.json
./scripts/oc-json-patch.py "$OC_CONFIG_PATH" snippets/whatsapp-allowlist.json
./scripts/oc-wrap.sh "config validate"
./scripts/oc-reload.sh hot-reload
```

(Em geral hot reload basta para mudanças em `dmPolicy/allowlist/debounceMs`.)

## 10.6. Verificação

```bash
./scripts/oc-wrap.sh "config get plugins.entries.telegram.config"
./scripts/oc-wrap.sh "config get plugins.entries.whatsapp.config"
./scripts/oc-wrap.sh "channels status --probe"
```

Teste: peça pro user enviar uma mensagem do número/ID autorizado E de outro não autorizado. Esperado: o autorizado responde, o outro é silenciosamente ignorado (e log mostra `denied: not in allowlist`).

## 10.7. Telegram com tópicos (avançado)

Habilitar `topicsEnabled: true`. Cada tópico = sessão isolada (memória, agente, contexto). Útil para separar "trabalho" / "pessoal" / "projeto X" no mesmo grupo.

## 10.8. Pegadinhas

- `dmPolicy: "open"` é o default — **MUDE imediatamente.**
- `allowlist` aceita só IDs/telefones, não usernames Telegram. Se digitar `@kelvin_cleto`, falha silenciosamente.
- WhatsApp Business sem `groupPolicy` = qualquer grupo onde o número for adicionado vira sessão (custo + risco).
- Sessões já abertas continuam autorizadas mesmo após mudança de allowlist (cacheado). Para invalidar: o user que está sendo bloqueado precisa tentar nova sessão (ou reiniciar o gateway).
