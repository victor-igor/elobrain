---
name: cronometro
description: >
  Cronômetro de tarefas com integração ClickUp. Inicia timer real quando você começa uma tarefa,
  para e adiciona comentário quando termina. Inverso do /validar-sessao (que estima tempo no fim
  do dia). Sub-comandos: start, stop, pause, resume, status, switch. Estado persistente em
  ~/.claude/state/cronometro.json sobrevive entre sessões.
  Triggers: "cronometro", "/cronometro", "iniciar tarefa", "parar timer", "começar tarefa",
  "vou começar X", "parar tarefa", "pausar timer".
---

# /cronometro

Cronômetro real-time de tarefas integrado ao ClickUp. Mede tempo de verdade (não estimado) e adiciona automaticamente como time entry na task certa. Funciona em par com `/validar-sessao` — este pega o início, aquele pega o que escapou.

**Pré-requisito:** MCP do ClickUp ativo. Workspace com time tracking habilitado.

---

## Sub-comandos

| Comando | Descrição |
|---|---|
| `/cronometro start <descrição>` | Inicia timer pra uma task (busca no ClickUp ou cria) |
| `/cronometro stop [comentário]` | Para timer ativo + adiciona comentário na task |
| `/cronometro pause` | Pausa timer ativo (preserva tempo acumulado) |
| `/cronometro resume` | Retoma timer pausado |
| `/cronometro status` | Mostra qual task tá rodando e há quanto tempo |
| `/cronometro switch <descrição>` | Para o atual + inicia outro (troca rápida) |

Sem sub-comando → mostra status (ou ajuda se nada rodando).

---

## Estado persistente

Arquivo: `~/.claude/state/cronometro.json`

```json
{
  "active_task": {
    "id": "86e1b9h43",
    "name": "Terminar configuração dos agentes Campos",
    "list_id": "901713180081",
    "started_at": "2026-05-15T13:50:00-03:00",
    "elapsed_before_pause_ms": 0,
    "paused": false,
    "paused_at": null,
    "user_id": 156603223,
    "clickup_timer_id": null,
    "description": "ajuste lógica chat_ia_memory"
  }
}
```

Quando não há timer ativo: `{"active_task": null}` ou arquivo ausente.

**Por que estado próprio (não só ClickUp):**
1. Sobrevive entre sessões do Claude Code
2. Permite pause local sem mexer no ClickUp (timer ClickUp não tem pause nativo)
3. Suporta workspaces sem time tracking habilitado (registra local, sync no stop)

---

## Identificação do usuário

Mesmo padrão do `/validar-sessao`:
1. `echo $ELOBRAIN_USER`
2. Buscar entrada em `memory/context/people.md`
3. Pegar `clickup_id`
4. **Em qualquer dúvida, perguntar antes de prosseguir**

---

## start — Iniciar timer

### Pipeline

1. **Verificar se já tem timer ativo**
   ```bash
   cat ~/.claude/state/cronometro.json 2>/dev/null
   ```
   - Se tem ativo (não pausado) → avisar e perguntar: "Já tem timer rodando em [task]. Quer parar e iniciar novo (use `switch` ao invés)?"
   - Se tem pausado → perguntar: "Tem timer pausado em [task]. Retomar ele ou começar outro?"
   - Se vazio → seguir

2. **Parse da descrição** — extrair cliente e escopo
   - Heurísticas: nome de cliente conhecido (Campos, Maqlam, ReabilitaCão, Bravo, Morgana, etc.) → mapeia pra list_id
   - Sem cliente claro → perguntar qual lista

3. **filter_tasks da lista do cliente**
   ```
   mcp__claude_ai_ClickUp__clickup_filter_tasks
     list_id: <id>
     subtasks: true
     include_closed: false   # só tasks abertas/pendentes
   ```

4. **Fuzzy match** das tasks com a descrição do usuário

5. **Apresentar 3-5 candidatos** (priorizar atribuídas ao membro + com vencimento próximo):
   ```
   Você quer começar: "ajustar prompt Campos"
   
   Top tasks que combinam:
   [1] 86e1b9h43 — Terminar configuração dos agentes e nova campanha
       Campos · pendente · vence 15/05 🔴 (atrasada)
   [2] 86e1b9h4k — Verificar disponibilidade dos chips
       Campos · pendente · vence 15/05
   [3] [NOVA] Criar task "ajustar prompt Campos" como subtask
   [4] [NOVA] Criar task standalone
   
   Qual? [1-4]
   ```

6. **Se [NOVA]** → criar com `clickup_create_task` (status: in progress, sem due_date)

7. **Iniciar timer**
   ```
   mcp__claude_ai_ClickUp__clickup_start_time_tracking
     task_id: <id>
     description: "<descrição original do usuário>"
   ```

8. **Salvar estado** em `~/.claude/state/cronometro.json`

9. **Confirmar**
   ```
   ⏱️ Timer iniciado às HH:MM
   Task: <id> — <nome>
   Cliente: <cliente>
   
   Quando terminar: /cronometro stop [comentário opcional]
   ```

---

## stop — Parar timer

### Pipeline

1. **Ler estado** — se não tem timer ativo → avisar e sair

2. **Calcular tempo total**
   ```
   total_ms = (now - started_at) - tempo_em_pausa
   ```

3. **Parar timer ClickUp**
   ```
   mcp__claude_ai_ClickUp__clickup_stop_time_tracking
   ```

4. **Pegar comentário do usuário**
   - Se passou `[comentário]` no comando → usar
   - Se não → perguntar: "O que foi feito? (vai pra task como comentário)"

5. **Adicionar comentário**
   ```
   mcp__claude_ai_ClickUp__clickup_create_task_comment
     task_id: <id>
     text: "⏱️ Trabalhado por Xmin via /cronometro\n\n<comentário>"
   ```

6. **Perguntar status final**
   ```
   Marcar a task como done agora? [s/n/parcial]
   - s: marca done
   - parcial: mantém pendente, deixa anotação de % progresso
   - n: mantém como estava
   ```

7. **Update status se aplicável**
   ```
   mcp__claude_ai_ClickUp__clickup_update_task
     task_id: <id>
     status: "done" | "in progress"
   ```

8. **Limpar estado** → `~/.claude/state/cronometro.json` = `{"active_task": null}`

9. **Confirmar**
   ```
   ⏱️ Timer parado às HH:MM
   Tempo total: Xmin
   Task: <id> — <nome> (<status final>)
   Comentário adicionado ✓
   ```

---

## pause / resume

### pause

1. Ler estado — exige timer ativo não-pausado
2. Calcular tempo decorrido até agora → somar em `elapsed_before_pause_ms`
3. Parar timer ClickUp temporariamente (`clickup_stop_time_tracking`)
4. Marcar estado como `paused: true`, `paused_at: now`
5. Confirmar: "⏸️ Timer pausado. Acumulado: Xmin. Retomar: /cronometro resume"

### resume

1. Ler estado — exige timer pausado
2. Reiniciar timer ClickUp (`clickup_start_time_tracking`) com mesma task
3. Atualizar estado: `paused: false`, novo `started_at: now` (mas mantém `elapsed_before_pause_ms`)
4. Confirmar: "▶️ Timer retomado. Total acumulado até agora: Xmin"

---

## status

Mostra estado atual sem mexer em nada:

```
⏱️ Status do cronômetro

Ativo desde: 13:50 (2h12min)
Task: 86e1b9h43 — Terminar configuração dos agentes Campos
Cliente: Campos Joia
Estado: rodando ▶️

Tempo acumulado: 2h12min
```

Se pausado:
```
⏱️ Status do cronômetro

Pausado às: 14:30
Task: 86e1b9h43 — Terminar configuração dos agentes Campos
Estado: pausado ⏸️

Tempo antes da pausa: 40min
Retomar: /cronometro resume
```

Se nada rodando:
```
⏱️ Nenhum timer ativo.
Iniciar: /cronometro start <descrição>
```

---

## switch — Troca rápida

Atalho pra `stop` + `start` sem precisar digitar duas vezes.

1. Pede comentário rápido do que foi feito até agora (1 linha)
2. Executa stop completo (com tempo + comentário + pergunta status)
3. Executa start com nova descrição
4. Confirma: "🔄 Trocou: <task antiga> (Xmin) → <task nova>"

---

## Integração com /validar-sessao

Quando `/validar-sessao` roda no fim do dia, ele consulta as tasks que **tiveram time entries via cronometro** e:

1. **Pula a estimativa do Passo 5.5** pra essas tasks (já tem tempo real registrado)
2. Mostra como bucket especial:
   ```
   ⏱️ Já cronometradas (tempo real):
   [1] 86e1b9h43 — Terminar configuração agentes Campos (2h12min real)
   [2] 86e1b9gdd — Agente Maq ajustes (45min real)
   ```
3. Aplica fluxo normal (status, comentário) — só pula estimativa

Como detectar: `clickup_get_task_time_entries` na task — se tem entry com `description` contendo "via /cronometro" daquele dia, considera como já medido.

---

## Integração com /salve

No Passo 4.5 (verificar mudanças elobrain), `/salve` também checa o estado do cronometro:

```bash
state_file=~/.claude/state/cronometro.json
if [[ -f "$state_file" ]] && [[ "$(jq -r '.active_task' "$state_file")" != "null" ]]; then
  task_name=$(jq -r '.active_task.name' "$state_file")
  started_at=$(jq -r '.active_task.started_at' "$state_file")
  echo "⚠️ TIMER ATIVO desde $started_at"
  echo "   Task: $task_name"
  echo "   Quer parar antes de fechar a sessão? [s/n]"
fi
```

Se o usuário responder `s` → invocar `/cronometro stop` antes de prosseguir.

---

## Regras

- **Um timer por vez** — não suporta múltiplos timers simultâneos. Use `switch` pra trocar
- **Sempre confirmar a task** — não chuta match fuzzy. Se ambíguo, pergunta
- **Estado é a fonte de verdade local** — `~/.claude/state/cronometro.json` sobrevive entre sessões
- **ClickUp é a fonte de verdade canônica** — sempre faz sync (start/stop reais no ClickUp também)
- **Pause é local** — ClickUp não tem pause nativo, então pause = stop + retoma com start novo, mas mantém acumulado no JSON
- **Falha em rede:** se ClickUp tá fora, salva estado local e tenta sync depois (no stop ou no próximo comando)
- **Idempotência:** rodar `start` 2x na mesma task não cria 2 timers. Avisa que já tá rodando.

---

## Convenções

### Formato de comentário no stop

```
⏱️ Trabalhado por <X>min via /cronometro
<comentário do que foi feito>

Ref: <commit-hash | arquivo:linha | URL> (se aplicável)
```

### Listas conhecidas (mapeamento cliente → list_id)

| Cliente / Categoria | List ID |
|---|---|
| Elite Maqlam — Denis | `901713180067` |
| Campos Joia — Matheus | `901713180081` |
| ReabilitaCão — Franciele | `901713180071` |
| Gestão Interna / Geral | `901713180052` |
| Pipeline | `901713180050` |
| Redes Sociais | `901713531658` |
| Financeiro | `901713180286` |
| Bravo Agency | `901713503273` |
| Morgana | `901713294075` |

### Estado

| Campo | Tipo | Descrição |
|---|---|---|
| `active_task.id` | string | ClickUp task ID |
| `active_task.name` | string | Nome da task (cache local) |
| `active_task.list_id` | string | ID da lista (pra context) |
| `active_task.started_at` | ISO 8601 | Timestamp de início (ou retomada) |
| `active_task.elapsed_before_pause_ms` | number | Tempo acumulado de pausas anteriores |
| `active_task.paused` | boolean | Se está pausado |
| `active_task.paused_at` | ISO 8601 \| null | Timestamp da pausa (se aplicável) |
| `active_task.user_id` | number | ClickUp user ID do operador |
| `active_task.description` | string | Descrição original passada no start |
