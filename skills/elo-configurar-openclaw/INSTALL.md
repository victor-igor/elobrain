# Instalação — configurar-openclaw

## Onde mora

A fonte canônica desta skill vive em:
```
~/Desenvolvimento/PoCs/claude-code/tests/open-claw-config/auto-config/configurar-openclaw/
```

Para o Claude Code descobrir a skill, criamos um **symlink** em `~/.claude/skills/`:
```
~/.claude/skills/configurar-openclaw → <fonte acima>
```

(Já feito durante a criação inicial. Confira com `ls -la ~/.claude/skills/configurar-openclaw`.)

## Como invocar

Em uma sessão do Claude Code, a skill é descoberta automaticamente pelo `description`
no frontmatter do `SKILL.md`. Triggers (em PT-BR e EN) incluem:

- "configurar openclaw"
- "openclaw config", "openclaw setup"
- "openclaw provider", "openclaw modelo", "openclaw heartbeat"
- "openclaw plugin", "openclaw skill", "openclaw memory"
- "openclaw secrets", "openclaw firecrawl"
- "openclaw hostinger", "openclaw vps", "openclaw docker", "openclaw bare metal"

Ou explicitamente: `/configurar-openclaw` (se Claude Code expuser slash command).

## Estrutura

```
configurar-openclaw/
├── SKILL.md                # entrypoint + router
├── INSTALL.md              # este arquivo
├── references/             # detalhes operacionais (16 arquivos)
│   ├── 01-conexao.md
│   ├── 02-edicao-segura.md
│   ├── 03-providers-modelos.md
│   ├── 04-roteamento-multi-modelo.md
│   ├── 05-seguranca.md
│   ├── 06-heartbeat.md                # INFRA do tick (config técnica)
│   ├── 07-compaction-memoria.md
│   ├── 08-plugins.md
│   ├── 09-skills-customizadas.md
│   ├── 10-canais.md
│   ├── 11-media-audio.md
│   ├── 12-arquitetura-memoria.md
│   ├── 13-diagnostico.md
│   ├── 14-armadilhas.md
│   ├── 15-proatividade.md             # CONTEÚDO proativo (HEARTBEAT.md, mandato, crons isolados)
│   └── 16-audit-melhorias.md          # 🤖 modo "analisa e aplica melhorias" (rulebook + scoring)
├── snippets/               # JSONs prontos pra deep-merge no openclaw.json
│   ├── setup-inicial.json
│   ├── routing-multi-modelo.json
│   ├── heartbeat.json
│   ├── compaction-memory-flush.json
│   ├── media-audio-gemini.json
│   ├── active-memory.json
│   ├── dreaming.json
│   ├── skill-extra-dirs.json
│   ├── telegram-allowlist.json
│   └── whatsapp-allowlist.json
└── scripts/                # helpers shell/python
    ├── oc-target-detect.sh    # descobre modo de deploy
    ├── oc-wrap.sh             # wrapper unificado de CLI
    ├── oc-backup.sh           # backup datado
    ├── oc-json-patch.py       # deep-merge no openclaw.json
    ├── oc-apply-patch.sh      # high-level: backup + patch + push (4 modos)
    ├── oc-env-set.sh          # set KEY=VALUE no .env / systemd override
    ├── oc-reload.sh           # hot-reload | restart | recreate | systemd-restart
    ├── oc-rollback.sh         # restaura backup mais recente
    └── oc-audit.sh            # 🤖 snapshot read-only do estado (alimenta o modo audit)
```

## Modos de deploy suportados

| Modo | Quando | Como rodar CLI |
|---|---|---|
| `local-native` | Ubuntu na máquina, instalado via `curl install.sh` | `openclaw <cmd>` |
| `local-docker` | Docker Compose nesta máquina | `docker exec <container> openclaw <cmd>` |
| `ssh-native` | VPS bare-metal (curso) | `ssh <host> openclaw <cmd>` |
| `ssh-docker` | VPS Hostinger HVPS One-Click ou Docker Compose remoto | `ssh <host> docker exec <container> openclaw <cmd>` |

## Requisitos da máquina local (onde Claude Code roda)

- `bash`, `python3` (3.8+)
- `ssh` configurado para o(s) host(s) remotos (ideal: chave + `~/.ssh/config` alias)
- `scp` (para sync de `openclaw.json` em modo SSH)

Para target docker remoto, o usuário SSH deve ter acesso ao docker (no grupo `docker` ou sudo).

## Atualização

Edite os arquivos em `auto-config/configurar-openclaw/` — o symlink em `~/.claude/skills/` reflete imediatamente.

Para versionar com git:
```bash
cd ~/Desenvolvimento/PoCs/claude-code/tests/open-claw-config
git add auto-config/configurar-openclaw
git commit -m "skill configurar-openclaw: ..."
```

## Desinstalar

```bash
rm ~/.claude/skills/configurar-openclaw
# (a fonte original em auto-config/ permanece intacta)
```
