# 03 — Providers, modelos e setup inicial

## 3.1. Setup inicial (instância nova)

### Bare-metal (Ubuntu 24.04)
```bash
curl -fsSL https://openclaw.ai/install.sh | bash
openclaw onboard --install-daemon
```

O wizard pergunta:
1. Gateway mode → `Local`
2. AI Provider → `OpenAI` (ou outro)
3. OAuth → fluxo no browser (ChatGPT Plus/Pro). Sem precisar de API key.
4. Model → `GPT-5.4` (recomendado) ou `GPT-4o`
5. Instalar como serviço? → Sim (24/7)

### Docker Compose (Hostinger HVPS One-Click)
- Já vem provisionado. Diretório típico: `/docker/openclaw-XXXX/`.
- Container: `openclaw-XXXX-openclaw-1`.
- Imagem: `ghcr.io/hostinger/hvps-openclaw:latest`.
- `data/.openclaw/` é o bind do `/data` interno.

### Pós-instalação OBRIGATÓRIO (≥ v2026.3.2)
```bash
./scripts/oc-wrap.sh "config set tools.profile full"
./scripts/oc-wrap.sh "config validate"
```
Sem isso, o agente só responde mensagens — **não executa nada**.

### Timezone (≥ v2026.3.13) — OBRIGATÓRIO se for usar crons

**Native (systemd):**
```bash
sudo systemctl edit openclaw
# adicionar dentro de [Service]:
# Environment="OPENCLAW_TZ=America/Sao_Paulo"
sudo systemctl daemon-reload
sudo systemctl restart openclaw
```

**Docker Compose:**
- Editar `.env` no compose dir, adicionar `TZ=America/Sao_Paulo`.
- `docker compose up -d --force-recreate openclaw`.

Verificar:
```bash
./scripts/oc-wrap.sh "gateway status"
```

---

## 3.2. Adicionar provider via API key

### .env (docker)
```bash
./scripts/oc-env-set.sh OPENAI_API_KEY     'sk-...'
./scripts/oc-env-set.sh GEMINI_API_KEY     'AIza...'
./scripts/oc-env-set.sh ANTHROPIC_API_KEY  'sk-ant-...'
./scripts/oc-env-set.sh XAI_API_KEY        '...'
./scripts/oc-env-set.sh FIRECRAWL_API_KEY  'fc-...'
./scripts/oc-env-set.sh SCRAPECREATORS_API_KEY '...'
./scripts/oc-env-set.sh TELEGRAM_BOT_TOKEN '...'
./scripts/oc-env-set.sh OPENCLAW_GATEWAY_TOKEN '...'
```

### systemd override (native)
```bash
./scripts/oc-systemd-env-set.sh OPENAI_API_KEY 'sk-...'
```

### Aplicar
```bash
./scripts/oc-reload.sh recreate          # docker
./scripts/oc-reload.sh systemd-restart   # native
```

### Verificar
```bash
./scripts/oc-wrap.sh "models status"
# nos logs:
$PFX docker logs $OC_CONTAINER --tail 200 | grep -iE 'Adding model config'
# Esperado: "Adding model config: \"google/gemini-2.5-flash\" (provider: google)"
```

> **Catálogo de modelos é reconstruído a cada boot** com base nas chaves presentes no env. Adicionar uma chave nova já expande automaticamente o `models` disponível em `agents.defaults`.

---

## 3.3. Setar modelo primário (sem mexer em fallbacks)

```bash
echo '{"agents":{"defaults":{"model":{"primary":"ChatGPT 4.1"}}}}' \
  | ./scripts/oc-json-patch.py "$OC_CONFIG_PATH" -
```

Hot reload — não precisa restart.

## 3.4. Setar `thinkingDefault`

| Nível | Quando | Custo |
|---|---|---|
| `off` | Tarefas simples, respostas rápidas | $ |
| `low` | Dia a dia, maioria | $$ |
| `medium` | Análise, planejamento, conteúdo | $$$ |
| `high` | Coding complexo, estratégia | $$$$ |

```bash
echo '{"agents":{"defaults":{"thinkingDefault":"low"}}}' \
  | ./scripts/oc-json-patch.py "$OC_CONFIG_PATH" -
```

## 3.5. `tools.profile`

| Profile | Efeito |
|---|---|
| `messaging` | DEFAULT a partir de v2026.3.2 — só responde mensagens |
| `lite` | Tools básicas, system prompt menor (boa pra economizar tokens) |
| `full` | Todas as tools — recomendado pro curso e uso geral |

```bash
./scripts/oc-wrap.sh "config set tools.profile full"
./scripts/oc-wrap.sh "config validate"
```

(Após `config set` no container, lembrar do `chown 1000:1000` — ver `02-edicao-segura.md §2.9`.)

## 3.6. Catálogo recomendado por uso

| Uso | Modelo recomendado | Razão |
|---|---|---|
| Interação direta | `Claude Opus 4.7` ou `ChatGPT 5.4` | Melhor raciocínio |
| Texto padrão (econômico) | `ChatGPT 4.1` | ~10x mais barato que 5.4 |
| Crons / automação | `Claude Sonnet 4.6` | 90% mais barato que Opus, suficiente |
| Heartbeats | `Claude Haiku 4.5` ou `Gemini 2.5 Flash` | Custo mínimo |
| Imagem (input) | `Gemini 2.5 Flash` | Multi-modal nativo barato |
| PDF | `ChatGPT 4.1` | Boa extração estruturada |
| Áudio (input) | `Gemini 2.5 Flash` | Entende áudio nativo (~40x mais barato que Whisper) |
| Geração de imagem | `Gemini 3 Pro (image-preview)` | Melhor qualidade |
| Subagents | `ChatGPT 4.1` ou `Claude Haiku 4.5` | Tarefas delegadas baratas |

Para roteamento por tipo de conteúdo → `04-roteamento-multi-modelo.md`.

## 3.7. Verificações pós-mudança

```bash
./scripts/oc-wrap.sh "models status"     # provider X model X status
./scripts/oc-wrap.sh "models list --all" # catálogo completo
./scripts/oc-wrap.sh "config get agents.defaults.model"
```
