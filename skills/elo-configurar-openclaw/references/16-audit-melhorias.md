# 16 — Audit & melhorias automáticas

> Modo "analisar e aplicar melhorias" — usuário diz "audita meu openclaw" / "analisa e aplica melhorias" / "o que dá pra melhorar". Você roda um snapshot, cruza com este rulebook, propõe um plano categorizado e aplica com aprovação.

## 16.1. Fluxo

```
[1] detectar target          → references/01-conexao.md
[2] coletar snapshot         → scripts/oc-audit.sh /tmp/audit.txt
[3] analisar (Claude lê o snapshot + este rulebook)
[4] mostrar relatório scoreado
[5] perguntar quais áreas aplicar (3 modos: críticos / recomendado completo / escolher)
[6] aplicar selecionados (cada um: backup → patch → validate → reload → verify)
[7] gerar diff antes/depois
```

## 16.2. Categorias

Cada item do audit é classificado em uma destas:

| Severidade | Símbolo | Significado | Ação default |
|---|---|---|---|
| **Crítico** | 🔴 | Risco de segurança ou bug latente que pode quebrar o agente | Aplicar sempre (com aprovação explícita) |
| **Recomendado** | 🟡 | Best practice estabelecida que reduz custo, melhora UX ou previne dor futura | Aplicar se usuário aceita o catálogo recomendado |
| **Opcional** | 🔵 | Estratégia situacional — depende de uso/orçamento | Mostrar e perguntar |
| **OK** | ✅ | Já está conforme | Só listar pra dar feedback |

## 16.3. Rulebook (a planilha de checagens)

### A. Setup baseline

| # | Checagem | Esperado | Severidade | Ação se falhar | Custo da ação |
|---|---|---|---|---|---|
| A1 | `tools.profile` | `full` (não `messaging`) | 🔴 | `config set tools.profile full` + `config validate` + `restart` | $0 |
| A2 | Timezone configurado | `OPENCLAW_TZ=America/Sao_Paulo` no env | 🔴 | adicionar via `oc-env-set.sh` ou systemd override | $0 |
| A3 | `agents.defaults.thinkingDefault` | `low` (default sensato) | 🔵 | patch `{thinkingDefault: "low"}` | $0 |
| A4 | `agents.defaults.contextTokens` definido | `>=160000` | 🟡 | patch `snippets/setup-inicial.json` | $0 |
| A5 | `agents.defaults.compaction.mode` | `safeguard` ou `default` | 🟡 | patch `snippets/compaction-memory-flush.json` | $0 |
| A6 | `config validate` | sem warnings/erros | 🔴 | reverter última mudança e investigar | depende |

### B. Segurança

| # | Checagem | Esperado | Severidade | Ação se falhar | Custo |
|---|---|---|---|---|---|
| B1 | Telegram `dmPolicy` | `allowlist` (não `open`) | 🔴 | `snippets/telegram-allowlist.json` (perguntar IDs) | $0 |
| B2 | Telegram `allowlist` não vazia | `[<id>]` | 🔴 | descobrir ID via logs e adicionar | $0 |
| B3 | WhatsApp `dmPolicy` | `allowlist` | 🔴 | `snippets/whatsapp-allowlist.json` | $0 |
| B4 | WhatsApp `debounceMs` | `>= 3000` | 🟡 | patch `{debounceMs: 4000}` | reduz LLM calls |
| B5 | WhatsApp `groupPolicy` | `deny` ou `allowlist` | 🟡 | patch `{groupPolicy: "deny"}` | $0 |
| B6 | `secrets audit` | "No exposed credentials" | 🔴 | `secrets apply` (migrar pro cofre) | $0 |
| B7 | UFW ativo (só ssh-native VPS) | `Status: active` | 🟡 | seção §5.2 de `05-seguranca.md` | $0 |
| B8 | fail2ban ativo (só ssh-native) | `Status: enabled` | 🟡 | seção §5.3 | $0 |
| B9 | SSH `PermitRootLogin` | `prohibit-password` | 🟡 | seção §5.5 (com confirmação extra) | $0 |
| B10 | SSH `PasswordAuthentication` | `no` | 🟡 | seção §5.5 | $0 |

### C. Performance / economia

| # | Checagem | Esperado | Severidade | Ação | Economia esperada |
|---|---|---|---|---|---|
| C1 | Modelo primário | NÃO `ChatGPT 5.4` (a menos que justificado) | 🔵 | propor roteamento multi-modelo (`04-*.md`) | ~10× em texto |
| C2 | `imageModel.primary` | `Gemini 2.5 Flash` | 🟡 | patch `routing-multi-modelo.json` | ~5× em imagem |
| C3 | `pdfModel.primary` | `ChatGPT 4.1` ou `Gemini 2.5 Flash` | 🟡 | patch | ~5-10× em PDF |
| C4 | `subagents.model.primary` | barato (`ChatGPT 4.1` / `Haiku 4.5`) | 🟡 | patch | depende do volume |
| C5 | `subagents.thinking` | `off` | 🟡 | patch | reduz tokens de raciocínio |
| C6 | Heartbeat configurado | tem `every` definido | 🔵 | `snippets/heartbeat.json` | habilita proatividade |
| C7 | Heartbeat `model` | `Gemini 2.5 Flash` ou `Haiku 4.5` | 🟡 | patch | ~20× vs Opus |
| C8 | Heartbeat `activeHours` | janela < 24h (ex: 06-20) | 🟡 | patch | ~40% menos ticks |
| C9 | Heartbeat `lightContext` | `true` | 🟡 | patch | reduz prompt |
| C10 | Heartbeat `isolatedSession` | `true` | 🟡 | patch | sem acúmulo histórico |
| C11 | Heartbeat `includeSystemPromptSection` | `false` | 🟡 | patch | -800 a -1500 tokens/tick |
| C12 | Áudio `models[0]` | `provider:google, model:gemini-2.5-flash` | 🟡 | `snippets/media-audio-gemini.json` | ~40× vs Whisper |
| C13 | Áudio `echoTranscript` | `false` | 🔵 | patch | melhora UX |
| C14 | `compaction.memoryFlush.enabled` | `true` | 🟡 | `snippets/compaction-memory-flush.json` | preserva memória |

### D. Memória

| # | Checagem | Esperado | Severidade | Ação |
|---|---|---|---|---|
| D1 | `workspace/memory/` existe | dir presente | 🔵 | criar estrutura (`12-arquitetura-memoria.md §12.2`) |
| D2 | Subdirs (`context/projects/sessions/integrations/feedback`) | presentes | 🔵 | criar |
| D3 | `MEMORY.md` existe | arquivo presente | 🔵 | criar índice mínimo |
| D4 | `AGENTS.md` tem seção "Memory Architecture" | sim | 🔵 | anexar (`12-*.md §12.3`) |
| D5 | Plugin `memory-core` | enabled | 🟡 | `plugins enable memory-core` |
| D6 | `memory-core.config.dreaming.enabled` | `true` | 🔵 | `snippets/dreaming.json` |
| D7 | Plugin `active-memory` | enabled | 🔵 | `snippets/active-memory.json` (avisar custo +1 call/turno) |
| D8 | `memory status` reporta índice OK | `Vector search: ✅ ready` | 🟡 | reindex (`memory index`) |

### E. Plugins úteis

| # | Plugin | Esperado | Severidade | Ação |
|---|---|---|---|---|
| E1 | `firecrawl` (web search) | enabled (se houver `FIRECRAWL_API_KEY`) | 🔵 | `plugins enable firecrawl` |
| E2 | `telegram` enabled | sim, se `TELEGRAM_BOT_TOKEN` no env | 🟡 | enable |
| E3 | `whatsapp` enabled | só se quiser | 🔵 | sob demanda |
| E4 | `memory-core` enabled | sim | 🟡 | enable |

### F. Skills

| # | Checagem | Esperado | Severidade | Ação |
|---|---|---|---|---|
| F1 | `skills.load.extraDirs` | inclui dir do workspace de skills | 🔵 | `snippets/skill-extra-dirs.json` |
| F2 | Skills custom têm frontmatter válido | `name:` + `description:` | 🟡 | corrigir cada SKILL.md |
| F3 | Owner correto em docker (`1000:1000`) | sim | 🟡 | `chown -R 1000:1000` no dir de skills |

### G. Proatividade (HEARTBEAT.md content)

| # | Checagem | Esperado | Severidade | Ação |
|---|---|---|---|---|
| G1 | `HEARTBEAT.md` existe | sim | 🔵 | template (`15-proatividade.md §15.3`) |
| G2 | `HEARTBEAT.md` tem checklist (não vazio) | linhas > 5 | 🔵 | popular template |
| G3 | `AGENTS.md` tem mandato proativo | grep "proativo\|proactive" | 🔵 | anexar (`15-*.md §15.2`) |
| G4 | Crons isolados existem | `crons list` retorna ≥ 1 | 🔵 | sugerir 2 crons base (manhã + noite) |
| G5 | Crons com `sessionTarget: isolated` | sim | 🟡 | corrigir (regra de ouro) |

## 16.4. Formato do relatório (você gera após análise)

```markdown
# 🔍 Audit do OpenClaw — <data>

**Target:** <mode>@<host> · OpenClaw v<X> · <plugins ativos>/<total>
**Score:** <ok>/<total> conforme (<%>%)

## 🔴 Críticos (<N>)
- [ ] **B1** — Telegram dmPolicy = "open" (qualquer um pode comandar o bot)
      → Aplicar `snippets/telegram-allowlist.json` (preciso do seu Telegram ID)
- [ ] **B6** — `secrets audit` encontrou 3 chaves expostas
      → `secrets apply` migra pro cofre (zero downtime)

## 🟡 Recomendados (<N>)
- [ ] **C7** — Heartbeat usando Opus (~$0.10/tick × 24/dia = $72/mês)
      → Trocar pra Gemini 2.5 Flash (~20× mais barato)
- [ ] **C12** — Áudio em Whisper como primário (~$0.006/min)
      → Mover Gemini Flash pra primário (~40× mais barato)

## 🔵 Opcionais (<N>)
- [ ] **D7** — Plugin `active-memory` desabilitado (memória passiva)
      → Habilitar adiciona ~1 call/turno (centavos), torna proativo
- [ ] **G3** — Sem mandato proativo no AGENTS.md
      → Anexar template (`15-*.md §15.2`)

## ✅ Já OK (<N>)
A1, A4, B7, B8, C2, D1, D5, …

---

**Aplicar:**
1. Apenas críticos (B1, B6)
2. Críticos + Recomendados (B1, B6, C7, C12, …)
3. Tudo (incluindo opcionais)
4. Escolher manualmente
```

Apresente com [AskUserQuestion] dando essas 4 opções.

## 16.5. Aplicação em batch

Após o usuário escolher, processar UM por vez (não em paralelo — pra cada um precisa backup individual):

```
para cada item selecionado:
  1. anunciar: "Aplicando <ID>: <descrição curta>"
  2. backup: ./scripts/oc-backup.sh openclaw.json
  3. patch: ./scripts/oc-apply-patch.sh <snippet> OU comando CLI específico
  4. validate: ./scripts/oc-wrap.sh "config validate"
     se falhar: ./scripts/oc-rollback.sh openclaw.json E parar (avisar usuário)
  5. (acumular: muitos itens são hot-reload — aplicar JSON e seguir; reload no fim do batch)
fim
[reload final]: ./scripts/oc-reload.sh hot-reload (ou recreate, se .env mudou no batch)
[verify]: rodar oc-audit.sh de novo e mostrar diff (ok antes vs depois)
```

> **Otimização:** se ≥ 3 itens forem patches no mesmo `openclaw.json` sem mudança de `.env`, mesclar todos em um único deep-merge antes do `validate` — UM hot reload no fim em vez de N.

## 16.6. Itens que precisam confirmação extra

Mesmo aprovados em massa, NÃO aplicar sem confirmação adicional:

- **B7-B10 (UFW/SSH hardening em VPS native)** — risco de prender o user fora. Antes: pré-checar `BatchMode=yes ssh true` e `ufw status` atual. Pedir confirmação explícita pra cada.
- **B6 secrets apply** — operação que altera o `.env`. Mostrar quais chaves vão migrar antes.
- **D7 active-memory** — adiciona custo recorrente. Mostrar estimativa mensal.
- **Mudança de modelo primário** (C1) — afeta qualidade percebida. Sugerir teste A/B antes do switch definitivo.

## 16.7. Saída final

Após aplicação:

```markdown
## ✅ Audit aplicado

| Item | Status | Backup |
|---|---|---|
| B1 | aplicado | openclaw.json.bak-20260425-093012 |
| B6 | aplicado | .env.bak-20260425-093045 |
| C7 | aplicado | (mesmo backup do JSON acima) |
| C12 | aplicado | (idem) |

**Reload:** hot-reload (não precisou recreate)
**Validate pós-mudança:** ✅
**Score:** 14/20 → 18/20 (+4 itens conforme)

**Restaurar tudo:** `./scripts/oc-rollback.sh openclaw.json && ./scripts/oc-rollback.sh env`

**Próximo audit sugerido:** em 30 dias OU quando subir versão do OpenClaw.
```

## 16.8. Variantes do comando

- "Audita meu openclaw" → audit completo, todos os itens
- "Audita só segurança" → só categoria B
- "Audita custo" → só categoria C
- "Aplica os críticos" → audit + aplica todos os 🔴 sem perguntar (mas confirmar antes do batch)
- "Reaudit" → roda audit de novo após mudanças (mostra diff)

## 16.9. Pegadinhas

- Audit é READ-ONLY. Nunca aplicar nada na fase de coleta.
- Score deve ser determinístico — se rodar 2× sem mudar nada, mesmo score.
- Items "OK" listar de forma compacta (só IDs) — não inflar o relatório.
- Em ssh-* o snapshot pode demorar 30-60s. Avisar o user que vai aguardar.
- Se `secrets audit` reportar chaves: ANTES de mostrar IDs, lembre que migração pra cofre é one-way (não reversível trivialmente).
