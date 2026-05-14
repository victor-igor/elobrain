---
name: elo-configurar-openclaw
description: >
  Configurar e auditar uma instância OpenClaw (local ou remota via SSH, bare metal
  ou Docker Compose) através do Claude Code. Inclui modo audit ("analisa e aplica
  melhorias automaticamente"). Cobre setup inicial, providers/modelos, roteamento
  multi-modelo, heartbeat, proatividade (HEARTBEAT.md, mandato, crons), compaction,
  plugins, skills customizadas, canais (Telegram/WhatsApp), mídia/áudio,
  arquitetura de memória, segurança (UFW, fail2ban, secrets, Cloudflare Tunnel) e
  diagnóstico.
  Triggers: "configurar openclaw", "openclaw config", "openclaw setup",
  "audita openclaw", "audit openclaw", "analisa openclaw", "aplica melhorias
  openclaw", "o que dá pra melhorar no openclaw", "openclaw provider",
  "openclaw modelo", "openclaw heartbeat", "openclaw proativo", "openclaw plugin",
  "openclaw skill", "openclaw memory", "openclaw secrets", "habilitar plugin
  openclaw", "rotear modelo openclaw", "endurecer openclaw", "openclaw
  hostinger", "openclaw vps", "openclaw docker", "openclaw bare metal",
  "openclaw telegram", "openclaw whatsapp", "openclaw firecrawl",
  "openclaw active-memory", "openclaw dreaming".
tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
tier: employee
reports_to: elo
version: 0.3.0
handoff_in:
  required:
    target: "local | remote-ssh | docker"
  optional:
    audit_mode: "Auto-apply melhorias (default: false — dry-run)"
    instance_url: "URL da instância OpenClaw"
handoff_out:
  produces:
    config_state: "Configurado + validado + relatório de auditoria"
quality_gates:
  - "Setup completo passa em smoke-test"
  - "Patches aplicados com backup"
  - "Audit mode tem aprovação humana antes de aplicar"
  - "Secrets nunca commitados em texto puro"
---

# configurar-openclaw — Skill de configuração assistida

Você é o operador. O usuário descreve o que quer configurar (em linguagem natural ou comando) — você detecta o **target**, escolhe a **operação**, lê o **arquivo de referência** correspondente, aplica com **edição segura** e **verifica**.

**NÃO improvise.** Cada operação tem um arquivo em `references/` com o procedimento exato. Quando em dúvida → leia o arquivo antes de agir.

---

## Passo 0 — Detectar target (sempre primeiro, salvo se já feito nesta sessão)

Quatro modos suportados:

| Modo | Onde mora o `openclaw.json` | Como rodar CLI |
|---|---|---|
| `local-native` | `~/.openclaw/openclaw.json` | `openclaw <cmd>` |
| `local-docker` | `<compose_dir>/data/.openclaw/openclaw.json` | `docker exec <container> openclaw <cmd>` |
| `ssh-native` | `~/.openclaw/openclaw.json` (no remoto) | `ssh <host> openclaw <cmd>` |
| `ssh-docker` | `<compose_dir>/data/.openclaw/openclaw.json` (no remoto) | `ssh <host> docker exec <container> openclaw <cmd>` |

→ Procedimento completo de detecção: **`references/01-conexao.md`**.

Quando o target estiver detectado, **memorize** (salvar em variáveis de sessão / repetir no início de cada operação) estes campos:
- `OC_MODE` (`local-native` | `local-docker` | `ssh-native` | `ssh-docker`)
- `OC_HOST` (vazio se local; `user@host` se SSH)
- `OC_COMPOSE_DIR` (vazio se native; ex: `/docker/openclaw-0v1y` se docker)
- `OC_CONTAINER` (vazio se native; ex: `openclaw-0v1y-openclaw-1` se docker)
- `OC_CONFIG_PATH` (caminho absoluto do `openclaw.json` no host onde mora)
- `OC_ENV_PATH` (caminho do `.env` se docker, ou caminho do override systemd se native)
- `OC_OWNER` (UID:GID do dono esperado do JSON — geralmente `1000:1000` em docker, `root:root` em native)

→ A partir daí, todo comando passa pelo wrapper `scripts/oc-wrap.sh` (que usa essas variáveis).

---

## Roteador de operações

Identifique a intenção do usuário e vá direto ao arquivo de referência. Se o pedido for amplo ("configura tudo"), peça para escolher 1-3 áreas via [AskUserQuestion].

| Intenção | Arquivo de referência | Snippets relevantes |
|---|---|---|
| **🤖 Analisar e aplicar melhorias automaticamente** ("audita", "o que dá pra melhorar", "aplica melhorias") | `references/16-audit-melhorias.md` | usa todos os snippets conforme análise |
| **Conectar / detectar instância** | `references/01-conexao.md` | — |
| **Editar config sem quebrar** (sempre) | `references/02-edicao-segura.md` | — |
| **Adicionar provider / API key / modelo** | `references/03-providers-modelos.md` | — |
| **Setup inicial (`tools.profile=full`, timezone, OAuth)** | `references/03-providers-modelos.md` §Setup inicial | — |
| **Rotear texto/imagem/PDF/subagent para modelos diferentes** | `references/04-roteamento-multi-modelo.md` | `snippets/routing-multi-modelo.json` |
| **Endurecer instância (UFW, fail2ban, secrets, tunnel)** | `references/05-seguranca.md` | — |
| **Configurar heartbeat (economia de tokens — INFRA do tick)** | `references/06-heartbeat.md` | `snippets/heartbeat.json` |
| **Tornar agente proativo (HEARTBEAT.md, mandato, crons isolados)** | `references/15-proatividade.md` | — |
| **Tunar compaction + memoryFlush** | `references/07-compaction-memoria.md` | `snippets/compaction-memory-flush.json` |
| **Habilitar/configurar plugin** (firecrawl, active-memory, memory-core, …) | `references/08-plugins.md` | `snippets/active-memory.json`, `snippets/dreaming.json` |
| **Criar skill customizada** | `references/09-skills-customizadas.md` | `snippets/skill-extra-dirs.json` |
| **Telegram allowlist / WhatsApp debounce** | `references/10-canais.md` | `snippets/telegram-allowlist.json`, `snippets/whatsapp-allowlist.json` |
| **Áudio: roteamento Gemini > Whisper, echoTranscript** | `references/11-media-audio.md` | `snippets/media-audio-gemini.json` |
| **Arquitetura de memória + dreaming + active-memory** | `references/12-arquitetura-memoria.md` | `snippets/active-memory.json`, `snippets/dreaming.json` |
| **Diagnosticar / validar / status / logs** | `references/13-diagnostico.md` | — |
| **Pegadinha conhecida (`.env`, ownership, cron, validate)** | `references/14-armadilhas.md` | — |

---

## Princípios de operação (não viole)

1. **Sempre detecte o target antes de executar.** Não assuma local. Se o usuário disser "no servidor", "no VPS", "no Hostinger", ou der um host SSH → modo SSH.
2. **Sempre faça backup antes de editar `openclaw.json` ou `.env`.** Padrão `<arquivo>.bak-YYYYMMDD-HHMMSS`. Use `scripts/oc-backup.sh`.
3. **Sempre rode `openclaw config validate` antes de qualquer recreate** com mudanças grandes. JSON inválido cascata pra todo o boot.
4. **Sempre dê preferência a editar o JSON via `python3` no host onde mora**, não via `openclaw config set` no container — o CLI reseta o owner pra `root` e quebra o watcher (EACCES). Use `scripts/oc-json-patch.py`.
5. **Decida reload vs restart vs recreate** antes de aplicar (regras em `references/02-edicao-segura.md`):
   - Hot reload: `tools.media.*`, `agents.defaults.heartbeat.*`, `agents.defaults.model.primary`, `tools.media.models` — só salvar e checar logs `[reload] config change applied`
   - Gateway restart: plugin enable/disable, override de systemd em native
   - **`docker compose up -d --force-recreate openclaw`**: qualquer mudança em `.env` (incluindo nova API key) — `restart` NÃO basta
   - **`systemctl daemon-reload && systemctl restart openclaw`**: mudanças em override systemd em native
6. **Após `openclaw config set` no container, reaplique ownership** (`docker exec ... chown 1000:1000 /data/.openclaw/openclaw.json`). Em native isso não se aplica.
7. **Cron expressions = 5/6/7 partes.** Nunca shorthand (`"1d"`, `"30m"` são rejeitados).
8. **Plugins: `entries.X.enabled` no nível raiz; toda config específica em `entries.X.config`.** Errar isso quebra TODO o boot (efeito cascata, até telegram para de habilitar).
9. **Skills user-defined exigem frontmatter YAML** com `name:` e `description:` — sem isso o gateway não as descobre.
10. **Cuidado com credenciais.** Rote use `openclaw secrets` (≥ v2026.3.2) em vez de editar `.env` cru. Audite com `openclaw secrets audit`.
11. **Sessões já abertas (Telegram/WhatsApp) cacheiam o system prompt.** Após adicionar/mudar skill, peça ao user pra mandar `/start` no bot.
12. **Memória custa.** `memory-core` indexa com OpenAI `text-embedding-3-small` por padrão (~US$ 0,02/M tokens). Avise se o user não souber.

---

## Fluxo padrão de qualquer operação

```
[1] detectar target (Passo 0)               → ./scripts/oc-target-detect.sh
[2] ler arquivo de referência da operação   → references/NN-*.md
[3] backup do arquivo a ser editado         → ./scripts/oc-backup.sh
[4] aplicar patch (JSON merge ou .env edit) → ./scripts/oc-json-patch.py
[5] validar (openclaw config validate)      → ./scripts/oc-wrap.sh "config validate"
[6] reload | restart | recreate (decidir)   → ./scripts/oc-reload.sh <kind>
[7] verificar (status / inspect / logs)     → references/13-diagnostico.md
[8] reportar ao usuário o que mudou + diff
```

Se em qualquer passo houver erro: NÃO continuar. Mostrar o erro, oferecer rollback (`cp <backup> <arquivo>` + recreate) e investigar.

---

## Comunicação com o usuário

- Em PT-BR (o usuário escreve em PT-BR).
- Antes de aplicar mudança não-trivial, **mostre o diff proposto** e peça confirmação.
- Para credenciais (API keys, tokens): NUNCA imprima o valor inteiro nos logs. Mascare como `sk-…ab12`.
- Se o usuário não souber o ID Telegram dele para o allowlist, instrua a enviar uma mensagem ao bot e cheque os logs (`gateway logs`).
- Após sucesso: resumir em 1-3 linhas o que mudou + onde está o backup.

---

## Quando perguntar antes de agir

Use [AskUserQuestion] quando:
- Pedido é ambíguo entre 2+ operações ("configura segurança" → UFW? secrets? dmPolicy? todos?).
- Há custo monetário não-óbvio (ex: ativar `active-memory` adiciona ~1 call/turno).
- Há risco de bloqueio (ex: ativar UFW antes de garantir SSH key funciona pode prender o user fora).
- Há decisão estratégica (ex: roteamento multi-modelo — quem é primário? ChatGPT 4.1 ou Gemini Flash?).

Caso contrário: aja, reportando passo a passo.
