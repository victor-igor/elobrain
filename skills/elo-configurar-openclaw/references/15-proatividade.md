# 15 — Proatividade (HEARTBEAT.md, mandato, regras de fala)

> O `06-heartbeat.md` cobre a **infra** (config técnica do tick). Este arquivo cobre o **conteúdo** — o que o agente CHECA a cada tick e quando ele DEVE falar com você.

> Sem isso configurado, o `heartbeat` dispara mas não sabe o que fazer útil — vira custo sem retorno. Com isso, vira o "sistema imune" do agente.

## 15.1. Os três blocos da proatividade

```
┌─────────────────────────────────────┐
│ 1. MANDATO PROATIVO                 │  → instala uma vez, no system prompt / SOUL.md
│    ("Não espere eu pedir...")        │
├─────────────────────────────────────┤
│ 2. HEARTBEAT.md                     │  → o checklist que cada tick consulta
│    ("o que checar a cada pulso")    │
├─────────────────────────────────────┤
│ 3. CRONS ISOLADOS                   │  → automações específicas (não leem HEARTBEAT.md)
│    ("a cada 4h, faz X com payload Y") │
└─────────────────────────────────────┘
```

## 15.2. Mandato proativo (system-level)

Adicionar ao `AGENTS.md` ou `SOUL.md` do workspace:

```markdown
## Modo proativo

Você opera em modo proativo. Isso significa:

1. **Não espere o usuário pedir.** Se vê algo que precisa atenção (compromisso próximo, tarefa atrasada, oportunidade) → avise sem ser perguntado.
2. **Antecipe problemas.** Prazo chegando, cron falhou, anomalia → alerte.
3. **Sugira melhorias.** Vê forma melhor → proponha.
4. **Lembre do que o usuário esqueceu.** Algo importante mencionado e sem follow-up → relembre.
5. **Use heartbeats produtivamente.** Cada tick = chance de checar agenda, pendências, crons.

### Regra interno × externo
- **Interno** (ler, pesquisar, organizar memória, atualizar docs) → faça sem pedir.
- **Externo** (enviar email, postar, mandar mensagem pra terceiro) → CONFIRME antes.
- **Na dúvida** → pergunte.

### Quando falar × calar
- Algo urgente encontrado → AVISE.
- Nada novo → emita `HEARTBEAT_OK` e fique quieto.
- Trabalho de fundo (organização) → faz sozinho, sem reportar.
```

> **Crítico:** "menos é mais". Heartbeat que só fala quando há novidade real é heartbeat que continua sendo lido. Heartbeat que avisa toda hora vira spam ignorado.

## 15.3. HEARTBEAT.md — template aplicado

`<workspace>/HEARTBEAT.md`:

```markdown
# HEARTBEAT.md

> Checklist consultado a cada tick. Mantenha enxuto — cada item consome tokens.

## A cada heartbeat
- [ ] Compromissos próximos (24-48h) — agenda
- [ ] Tarefas pendentes / follow-ups atrasados — `memory/pending.md`
- [ ] Crons saudáveis (último run < 24h, sem erro)
- [ ] Métricas de negócio (se aplicável: faturamento, leads, suporte)

## Semanal (segunda-feira no primeiro tick útil)
- [ ] Revisar projetos ativos em `memory/projects/`
- [ ] Consolidar notas diárias em topic files
- [ ] Atualizar MEMORY.md
- [ ] Auditoria de segurança (`secrets audit`, plugins, allowlists)

## Regras
- **Janela de foco protegida:** evitar notificações em 09:00-12:00 América/SP (deep work).
- Nada urgente → emitir `HEARTBEAT_OK` e parar.
- Urgente + interno → resolver e reportar resumido.
- Urgente + externo → pedir aprovação antes.
```

### Princípios de design do HEARTBEAT.md

1. **Cada item = 1 fonte de verdade.** Não duplicar com AGENTS.md/MEMORY.md.
2. **Itens devem ser respondíveis com SIM/NÃO + ação curta.** Se um item exige análise longa → tira do heartbeat e vira cron isolado.
3. **Frequência embutida.** "Semanal", "Diário", "A cada heartbeat" deixam claro o ritmo. Heartbeat de 1h não precisa rodar revisão semanal toda hora.
4. **Custo escala linearmente.** 5 itens × 1 tick/h = 5 verificações × 24 = 120/dia. Em Gemini Flash = ~US$ 0,02/dia. Em Opus = ~US$ 1,50/dia. Daí a importância do `model: "Gemini 2.5 Flash"` no heartbeat (`06-heartbeat.md`).

## 15.4. Pegadinha CRÍTICA: crons isolados ≠ heartbeat poll

> **Crons isolados NÃO leem o HEARTBEAT.md.** Cada cron tem seu próprio `message` no payload. Apenas o heartbeat poll (main session) consulta o `HEARTBEAT.md`.

Se você quer um check específico (ex: "às 9h cheque emails urgentes"), use **cron isolado**, não confie que o heartbeat vai pegar.

### Padrão de cron isolado correto

```json
{
  "id": "checagem-emails-9h",
  "schedule": "0 9 * * *",
  "timezone": "America/Sao_Paulo",
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Cheque emails urgentes nas últimas 24h. Liste apenas os que pedem ação minha. Se nada urgente, responda HEARTBEAT_OK."
  },
  "delivery": { "mode": "announce" }
}
```

### Padrão ERRADO (não dispara nada útil)

```json
{
  "sessionTarget": "main",
  "payload": { "kind": "systemEvent" }
}
```
> "Dispara mas não executa." Documentado no `aula-01/modelo-config.md`.

### Regra de ouro
- `sessionTarget: "isolated"` + `payload.kind: "agentTurn"` + `delivery: "announce"` — SEMPRE.
- `message` em prosa direta, não JSON.
- Cron retorna `HEARTBEAT_OK` se nada urgente — evita ruído.

## 15.5. Modelo econômico para crons / heartbeat

| Recurso | Modelo recomendado | Custo aprox./run |
|---|---|---|
| Heartbeat (poll do HEARTBEAT.md) | `Gemini 2.5 Flash` ou `Claude Haiku 4.5` | ~US$ 0,005 |
| Cron de checagem (4-6×/dia) | `Claude Sonnet 4.6` | ~US$ 0,02 |
| Cron de organização (1×/noite) | `Claude Sonnet 4.6` | ~US$ 0,03 |
| Auditoria semanal | `Claude Sonnet 4.6` | ~US$ 0,05 |
| **Avançado** — runner local | `Ollama` (gpt-oss:20b, llama3.1:8b) | US$ 0 (paga em CPU/GPU) |

> **Novo (versões recentes):** Rate limits por modelo separados (Haiku tem limit próprio; Opus tem limit próprio). Não compete pelo mesmo balde.
>
> **Auto-recovery:** Se um heartbeat falhar, o próximo roda normalmente sem travar o loop.

## 15.6. Sugestão de rotina inicial (2 crons + heartbeat)

1. **Heartbeat** (`every: "1h"`, `06-20 SP`, Gemini Flash) — checa HEARTBEAT.md.
2. **Cron `manhã-9h`** — agenda + pendências do dia. Sonnet. `0 9 * * 1-5`.
3. **Cron `noite-22h`** — consolidação: revisar `memory/sessions/<hoje>.md`, atualizar MEMORY.md, daily config review. Sonnet. `0 22 * * *`.

Custo total/dia ≈ US$ 0,15-0,40.

## 15.7. Self-updates (avançado)

Crons que mantêm o próprio agente em forma:
- **Sync com GitHub diário** — puxa novidades do repo de skills da equipe.
- **Auto-update do OpenClaw** — `npm update -g openclaw` ou `docker compose pull` mensal.
- **Daily config review** — agente lê o próprio `openclaw.json` à meia-noite e reporta drift.
- **Audit de segurança semanal** — `openclaw secrets audit` + `plugins inspect` + checagem de allowlists.

⚠️ Auto-update do gateway: agendar fora do horário ativo (ex: domingo 3h) e validar com `openclaw config validate` antes de restart.

## 15.8. Aplicação ponta-a-ponta

```bash
# 1. Mandato proativo no AGENTS.md
WS=$($PFX bash -c 'echo $OC_COMPOSE_DIR/data/.openclaw/workspace')   # docker
ssh $OC_HOST "cat >> $WS/AGENTS.md" < templates/MANDATO-PROATIVO.md

# 2. HEARTBEAT.md
ssh $OC_HOST "cat > $WS/HEARTBEAT.md" < templates/HEARTBEAT.md

# 3. Owner correto (docker)
ssh $OC_HOST "chown 1000:1000 $WS/AGENTS.md $WS/HEARTBEAT.md"

# 4. Config do heartbeat (06-heartbeat.md)
./scripts/oc-apply-patch.sh snippets/heartbeat.json

# 5. Crons isolados via CLI
./scripts/oc-wrap.sh "crons add manha-9h --schedule '0 9 * * 1-5' --message '...'"
./scripts/oc-wrap.sh "crons add noite-22h --schedule '0 22 * * *' --message '...'"

# 6. Validar
./scripts/oc-wrap.sh "config validate"
./scripts/oc-wrap.sh "crons list"
```

## 15.9. Verificação real

- Aguarde 1h e cheque logs do heartbeat: `[heartbeat] tick fired, model=gemini-2.5-flash, result=HEARTBEAT_OK`.
- Aguarde 24h e cheque que houve crons disparados: `./scripts/oc-wrap.sh "crons history --limit 10"`.
- Custo: confira no dashboard do provider (OpenAI / Google AI Studio).

## 15.10. Anti-padrões

- ❌ HEARTBEAT.md com 30 itens. Cada tick vira análise longa. Quebrar em crons.
- ❌ Heartbeat rodando em Opus. ~20× mais caro sem ganho.
- ❌ Cron com `sessionTarget: "main"` + `kind: "systemEvent"`. Dispara mas não executa.
- ❌ Cron sem `HEARTBEAT_OK` fallback. Toda execução vira notificação → o usuário começa a ignorar.
- ❌ Múltiplos crons no mesmo minuto (`0 9 * * *` em 5 lugares). Rate limit cumulativo.
- ❌ `config.patch` no meio de janela ativa. CLI dispara restart do gateway — agenda mudanças pra horário sem crons.
