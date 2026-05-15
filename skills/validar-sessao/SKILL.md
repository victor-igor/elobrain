---
name: validar-sessao
description: Valida o trabalho da sessão contra ClickUp — compara projetos, usuário, tarefas, subtarefas e prazos. Marca tasks completas como done, atualiza parciais com comentário, cria as que faltam, identifica e remove duplicatas. Roda antes do /salve para garantir que o ClickUp reflita o que foi feito de verdade. Triggers — "valida sessão", "valida clickup", "/validar-sessao", "/valida".
---

# /validar-sessao

Valida o trabalho da sessão atual contra o ClickUp. Garante que tarefas concluídas sejam marcadas como done, parciais sejam atualizadas, novas sejam criadas e duplicatas sejam removidas — antes de fechar a sessão com `/salve`.

**Pré-requisito:** MCP do ClickUp ativo (`mcp__claude_ai_ClickUp__*`).

---

## Por que existe

Sem essa skill, todo membro tem que lembrar manualmente de:
- Marcar tasks como done depois de fazer
- Criar tasks pro que foi feito sem registro
- Evitar duplicatas (problema já observado: criar macro-task quando já existem subtarefas detalhadas)
- Bumpar prazos de tasks vencidas

Resultado: ClickUp fica desatualizado, weekly precisa de cleanup manual, tasks duplicadas poluem listas.

A skill faz isso automaticamente em batch, com aprovação do usuário antes de executar.

---

## Quando rodar

- **Antes do `/salve`** — para que os IDs das tasks já fiquem registrados na sessão
- **Durante o dia** — para validar progresso intermediário sem fechar a sessão
- **Após uma execução longa** — quando completou um bloco grande de trabalho

Não rodar:
- Sessões puramente exploratórias (sem ação concreta)
- Quando ClickUp MCP está fora do ar

---

## Passo 1 — Identificar usuário

Mapear quem está operando para o ClickUp user correto. Funciona para **qualquer membro do time**.

```bash
echo $ELOBRAIN_USER   # victor / lucas / hugo / ...
```

Carregar o `clickup_id` do membro em `memory/context/people.md`:

1. Buscar entrada onde `slug == $ELOBRAIN_USER`
2. Ler campo `clickup_id` (ou variantes: `clickup_user_id`, `clickup`)
3. **Em qualquer caso de dúvida, PERGUNTAR ao usuário antes de seguir.** Cenários:
   - `$ELOBRAIN_USER` vazio ou ausente → perguntar quem está operando, listar os membros conhecidos do `people.md`
   - Membro não encontrado em `people.md` → perguntar nome e oferecer cadastrar
   - Múltiplos IDs registrados (conta duplicada) → mostrar as opções com contexto (qual conta tem mais tasks, qual está marcada como primary) e pedir confirmação
   - Match fuzzy ambíguo (ex: dois membros com slugs parecidos) → mostrar candidatos e pedir confirmação
   - ID encontrado mas não usado há muito tempo → confirmar se ainda está correto
4. Confirmar com o usuário em uma mensagem clara:
   ```
   Detectei que você é [Nome] (ClickUp #[id]). Confirma? [s/n]
   ```
5. Salvar a escolha em `people.md` se foi novo cadastro ou se houve resolução de ambiguidade

**Regra:** nunca chutar. Na menor dúvida, pergunte. Vale mais 1 pergunta extra do que executar ações no ClickUp em conta errada.

---

## Passo 2 — Revisar a sessão

Revisar mentalmente TUDO que aconteceu na conversa atual e extrair as **ações concretas** — não pensamentos, não dúvidas, só o que foi efetivamente executado.

Agrupar por dimensão:

| Dimensão | O que coletar |
|---|---|
| **Projeto / Cliente** | A qual cliente, projeto ou frente cada ação pertence (ex: Campos Joias, Maqlam, ReabilitaCão, Eloscope interno) |
| **Tipo de ação** | Ajuste, criação, reorganização, decisão, entrega, fix |
| **Owner** | Quem fez (default: $ELOBRAIN_USER) |
| **Prazo** | Se a ação tem deadline mencionado ou se conclui task vencida |

**Exemplo extraído:**
```
- [Campos Joias] Ajuste no system prompt BDR (FAQ gate + placeholder rule)
- [Campos Joias] Reorganização cerebro: clientes/campos-joias/agente/bdr/
- [Maqlam] Regeneração do playbook HTML + PDF
- [Maqlam] Ajuste prompt SDR (chat_ia_memory logic)
- [Maqlam] Reorganização cerebro: elite-maqlam/agente/sdr/
```

---

## Passo 3 — Buscar no ClickUp

### 3a — OBRIGATÓRIO: listar TODAS as tarefas das listas dos clientes mencionados

**Sempre fazer ANTES de buscar por nome.** O `clickup_search` é fuzzy, retorna no máximo ~18 resultados e pode esconder tasks concluídas há tempo. O `filter_tasks` mostra tudo.

```
mcp__claude_ai_ClickUp__clickup_filter_tasks
  list_id: <id_da_lista_do_cliente>
  subtasks: true
  include_closed: true
```

Para cada cliente mencionado na sessão, listar a lista correspondente. Construir um mapa mental: *"essas são TODAS as tasks que existem para esse cliente"*.

**Listas conhecidas (Eloscope workspace):**
| Cliente | List ID | Folder ID |
|---|---|---|
| Elite Maqlam — Denis | `901713180067` | `90178371123` |
| Campos Joia — Matheus | `901713180081` | `90178371131` |
| ReabilitaCão — Franciele | `901713180071` | `90178371124` |
| Gestão Interna / Geral | `901713180052` | — |
| Pipeline | `901713180050` | — |
| Redes Sociais | `901713531658` | — |
| Financeiro | `901713180286` | — |
| Bravo Agency | `901713503273` | — |
| Morgana | `901713294075` | — |

Se cliente não está no mapeamento → perguntar ao usuário antes de prosseguir.

### 3b — Buscar por nome (complementar, opcional)

Depois de ter o universo completo, pode usar `clickup_search` como complemento. Mas é **complemento, não substituto** — search nunca é a fonte primária.

```
mcp__claude_ai_ClickUp__clickup_search
  query: "<nome da ação ou cliente>"
```

Buscar também:
- **Tasks pai** (epic/macro) que podem ter subtasks relacionadas
- **Tasks vencidas** do mesmo cliente — podem ser o que a ação concluiu

---

## Passo 4 — Classificar cada ação em 4 buckets

| Bucket | Critério | Ação |
|---|---|---|
| ✅ **Completa** | Task existe e a ação executou ela inteira | Marcar `done` + comentário com referência (commit, arquivo) |
| 🟡 **Parcial** | Task existe mas só parte foi feita | Atualizar status (in progress) + comentário com avanço |
| 🆕 **Nova** | Ação foi feita sem task — gap no ClickUp | Criar task (status: done se já concluída, ou aberta com prazo) |
| ⏭️ **Operacional** | Commit menor, fix pontual, exploração | Pular — não cria task |

**Antes de classificar como 🆕 Nova, perguntar 3 coisas:**

1. **A ação é um refinamento de uma task já existente** (mesmo concluída)? → ✅ adicionar comentário na task original, NÃO criar nova.
2. **A ação é output derivado de uma task pai** (PDF, HTML, regeneração, análise interna de algo já entregue)? → ✅ adicionar comentário na pai.
3. **A ação tem PAI semântico** (mesmo cliente + mesmo escopo)? → criar como **subtask** da pai, não como task standalone.

**Só classificar como 🆕 Nova se NENHUMA das 3 condições for verdadeira.**

**Exemplo prático (lição aprendida 15/05):**
- Regerar PDF do playbook Maqlam → output derivado de "Playbook comercial Maqlam criado" (concluído) → **comentário**, não task nova.
- Refinar prompt Campos com FAQ gate → refinamento de "Prompt agente Campos Joia criado e testado" (concluído) → **comentário**, não task nova.

**Casos especiais:**

- **Duplicata detectada:** se a ação executada já está coberta por **subtasks** existentes de uma macro, NÃO criar nova macro. Em vez disso, marcar as subtasks específicas como done.
- **Task vencida:** se uma task aberta tem prazo passado e foi concluída hoje, marcar done e ajustar `due_date` para hoje (registro correto).
- **Subtask órfã:** se foi feito algo que parece subtask mas a macro não existe, criar macro + subtask juntas.

---

## Passo 5 — Apresentar aprovação em batch

Mostrar tudo em uma única lista, formatada para revisão rápida:

```
📋 Validação de Sessão — DD/MM/YYYY HH:MM
Usuário: [nome] (ClickUp #[id])

═══ ✅ Completar (3) ═══
[1] 86e1d9uxx — "Ajustar prompt Grau 10K BDR" → done
    Cliente: Campos Joia · Vencimento: 14/05 (atrasada)
[2] 86e1d9uxy — "Reorganizar clientes cerebro" → done
    Cliente: Eloscope interno · Vencimento: 15/05
[3] ...

═══ 🟡 Atualizar (1) ═══
[4] 86e1d9uxz — "Maqlam SDR setup" → 60%
    Comentário: "Playbook regenerado (HTML+PDF), prompt ajustado (chat_ia_memory).
                 Pendente: saudação P1 + conflito emojis."

═══ 🆕 Criar (2) ═══
[5] [NOVA] "Regenerar playbook PDF Maqlam" 
    Lista: Maqlam · Status: done · Subtask de: [auto-detect]
[6] [NOVA] "Análise prompt × playbook Maqlam" 
    Lista: Maqlam · Status: done · Owner: Victor

═══ ⏭️ Ignorar (4) ═══
- Commit "fix typo prompt"
- Read PROPAGATION.md
- ...

────────────────────────
Aprovar tudo? [s/n] · Editar item: [número] · Remover: [-número]
```

Aguardar input do usuário. Se quiser editar, abrir o item específico, ajustar, voltar à lista.

---

## Passo 5.5 — Estimativa de tempo (se habilitado)

**Verificar config do usuário em `people.md`:** procurar campo `track_time: true/false` na entrada do membro ativo.

- `track_time: true` → executar este passo
- `track_time: false` ou ausente → PULAR direto pro Passo 6

### 5.5.a — Heurística de sugestão automática

Para cada ação ✅/🟡/🆕 aprovada, sugerir uma estimativa baseada no tipo:

| Tipo de ação | Estimativa sugerida |
|---|---|
| Skill nova ou framework (criar do zero) | 45min |
| Refactor/evolução grande (Passo novo, regras novas) | 30min |
| Refinamento (FAQ gate, regra anti-placeholder, ajuste de lógica) | 15min |
| Comentário/comprovante de output derivado (PDF, HTML, análise) | 10min |
| Reorganização de pasta/arquivos | 10min |
| Análise/research interno | 20min |
| Configuração/setup pontual | 15min |

### 5.5.b — Apresentação para aprovação

```
⏱️  Estimativa de tempo — DD/MM/YYYY

✅ Completar (3):
[1] 86e1d9uxx — Ajustar prompt Grau 10K BDR
    Tempo: [15min] ← refinamento
[2] 86e1d9uxy — Reorganizar clientes cerebro
    Tempo: [10min] ← reorganização

🆕 Criar (2):
[5] [NOVA] Skill /validar-sessao criada
    Tempo: [45min] ← skill nova framework

────────────────────────────
Total da sessão: 70min
Aprovar tempos? [s/edit/n]
Editar item: [número] [Xmin]
```

### 5.5.c — Edição manual

Se o usuário digitar `[3] 25min`, ajustar a estimativa do item 3 e re-mostrar. Loop até `s`.

### 5.5.d — Idempotência

Antes de registrar, checar se já existe time entry recente para a task na mesma data — evitar duplicar tempo se a skill rodar 2x.

```
mcp__claude_ai_ClickUp__clickup_get_task_time_entries
  task_id: <id>
```

Se há entry com `description` contendo "via /validar-sessao" da mesma data → pular.

---

## Passo 6 — Executar em paralelo

Após aprovação, executar em batch (paralelo onde possível):

**Completar:**
```
mcp__claude_ai_ClickUp__clickup_update_task
  taskId: <id>
  status: "done"
  
mcp__claude_ai_ClickUp__clickup_create_task_comment
  taskId: <id>
  text: "Concluído em <data>. Ref: <commit/arquivo>"
```

**Atualizar parcial:**
```
mcp__claude_ai_ClickUp__clickup_update_task
  taskId: <id>
  status: "in progress"

mcp__claude_ai_ClickUp__clickup_create_task_comment
  taskId: <id>
  text: "<comentário do avanço>"
```

**Criar nova:**
```
mcp__claude_ai_ClickUp__clickup_create_task
  list_id: <id_da_lista>
  name: <nome>
  status: <done|open|in progress>
  assignees: [<user_id>]
  due_date: <timestamp_ms>
  parent: <id_macro_se_for_subtask>
  description: "Criada via /validar-sessao em <data>. Ref: <commit>"
```

**Registrar tempo (se Passo 5.5 foi executado):**

Para cada task tocada com estimativa aprovada, adicionar time entry:

```
mcp__claude_ai_ClickUp__clickup_add_time_entry
  task_id: <id>
  duration: <ms>           # minutos * 60 * 1000
  description: "Trabalho registrado via /validar-sessao em <data>"
  assignee: <user_id>
  start: <timestamp_ms>    # ~hora aproximada da sessão (now - duration)
```

Executar em paralelo com os updates/comments — não bloquear se time entry falhar (alguns workspaces ClickUp têm time tracking desativado, é OK).

---

## Passo 7 — Resultado

Mostrar resumo curto:

```
✓ Validação concluída — DD/MM/YYYY HH:MM

✅ 3 tasks marcadas done:
  86e1d9uxx — Ajustar prompt Grau 10K BDR (15min)
  86e1d9uxy — Reorganizar clientes cerebro (10min)
  86e1d9uxw — ... (Xmin)

🟡 1 task atualizada:
  86e1d9uxz — Maqlam SDR setup (60%) (20min)

🆕 2 tasks criadas:
  86e1d9aaa — Regenerar playbook PDF Maqlam (done, 10min)
  86e1d9aab — Análise prompt × playbook Maqlam (done, 25min)

⏱️ Tempo total registrado: 80min (se track_time habilitado)

⏭️ 4 ações operacionais ignoradas.

Próximo passo sugerido: rodar /salve para registrar a sessão.
```

---

## Passo 8 — Anexar à sessão (opcional)

Se o usuário rodar `/salve` em seguida, a seção da sessão deve mencionar os IDs das tasks alteradas, pra rastreabilidade:

```markdown
### Tasks ClickUp tocadas

- ✅ 86e1d9uxx, 86e1d9uxy, 86e1d9uxw
- 🟡 86e1d9uxz
- 🆕 86e1d9aaa, 86e1d9aab
```

---

## Regras

- **Nunca executar sem aprovação** — sempre mostrar lista no Passo 5 e esperar `s` antes de tocar no ClickUp
- **Sempre `filter_tasks` antes de `search`** — filter mostra TUDO da lista, search é fuzzy e pode esconder tasks concluídas relevantes. Search é complementar, não substituto (regra confirmada 15/05).
- **Refinamento ≠ task nova** — se ação aprimora algo já entregue, é comentário na task original, não task separada (regra confirmada 15/05).
- **Output derivado ≠ task nova** — PDF/HTML regenerado, análise interna de algo já feito, são comentários na task pai (regra confirmada 15/05).
- **Nunca criar duplicata** — se houver subtasks existentes que cobrem a ação, atualizá-las em vez de criar nova macro (regra confirmada 15/05)
- **Sempre mencionar commit/arquivo no comentário** — facilita auditoria futura
- **Membros com múltiplas contas ClickUp:** consultar `people.md` — usar a marcada como `primary: true`. Nunca chutar.
- **Lista desconhecida:** se cliente não está no mapeamento, perguntar — nunca criar task em lista aleatória
- **Idempotência:** rodar a skill duas vezes na mesma sessão não deve duplicar nada (checar comentários antes de adicionar)

---

## Convenções

### Status ClickUp

| Status | Quando usar |
|---|---|
| `open` / `to do` | Task aberta, ainda não iniciada |
| `in progress` | Em execução |
| `published` | Listas Redes Sociais e Guia de Modelos (descoberto em 15/05) |
| `done` | Concluída |

### Comentários

Formato sugerido:
```
✅ Concluído em <data>
Ref: <commit-hash | arquivo:linha | URL>
Detalhes: <1 linha do que foi feito>
```

### Prazos (due_date)

- Timestamp em milissegundos (epoch * 1000)
- Para tasks vencidas concluídas: ajustar para hoje
- Para tasks novas: usar data mencionada na conversa, ou perguntar
