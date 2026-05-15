---
name: criar-skill
description: >
  Meta-skill orquestradora pra criar skills novas seguindo TODOS os processos certos: classificação
  framework vs cliente-only, path correto (elobrain ou cerebro), frontmatter padronizado, atualização
  do manifest.json, integração com /elo (coordinator) e Directors (/elo-ops, /elo-content, /elo-vendas),
  sync pra ~/.claude/skills/, commit + push no repo certo, criação de task no ClickUp e notificação
  do time. Substitui a disciplina manual por checklist auditável.
  Triggers: "criar skill", "/criar-skill", "nova skill", "skill nova", "skillify",
  "preciso criar uma skill", "como crio uma skill".
---

# /criar-skill

Meta-skill que cria outras skills seguindo todos os processos da arquitetura 3 camadas (elobrain / cerebro / ~/.claude). Garante que nenhuma skill nasce incompleta ou desalinhada.

**Pré-requisito:** repos `~/elobrain` e `$SECOND_BRAIN_PATH` configurados, MCP do ClickUp ativo.

---

## Por que existe

Sem essa skill, criar uma skill nova exige lembrar manualmente de:
- Decidir entre elobrain (framework) ou cerebro (Eloscope-only)
- Criar SKILL.md no path certo com frontmatter padronizado
- Adicionar entry no `manifest.json` (se framework)
- Atualizar triggers do `/elo` no bucket correto
- Atualizar `members` do Director apropriado (/elo-ops, etc.)
- Criar state dir se necessário
- Sincronizar pra `~/.claude/skills/`
- Commit + push no repo correto (1 ou 2 repos)
- Criar task no ClickUp pra registro
- Notificar o time

Erros frequentes: skill em 2 lugares (duplicata), esquecer manifest, não integrar com `/elo`, deixar a skill funcionar isolada mas não no fluxo natural.

A skill faz tudo isso em batch com aprovação por etapa.

---

## Pipeline (12 passos)

### Passo 1 — Coletar requirements (interativo, 1 pergunta por vez)

Perguntar em sequência. Não pular pra próxima sem ter resposta clara.

```
1.1 Qual o nome da skill? (kebab-case, sem espaços)
    Ex: "validar-tarefas", "cronometro", "post-linkedin"

1.2 Descreve em 1 frase o que ela faz:
    Ex: "Valida tarefas da sessão contra o ClickUp"

1.3 Quais triggers em linguagem natural?
    Ex: "valida tarefas", "/validar-tarefas", "reconcilia clickup"

1.4 Essa skill é:
    [a] Framework genérico — qualquer empresa usaria igual (vai pra elobrain)
    [b] Eloscope-only — depende dos nossos dados/clientes (fica no cerebro)
    
    Se você não sabe: pergunte "isso faria sentido pra um cliente que comprasse o Elo OS?"
    - Sim → framework (a)
    - Não → Eloscope-only (b)

1.5 Tipo de execução:
    [1] Standalone simples (skill atômica, sem orquestração)
    [2] Ops curtas (cockpit, salve, rotina, validar) — INLINE
    [3] Ops longas (reuniao, processamento) — SUB-AGENT
    [4] Content curto (carrossel, PDF)
    [5] Content longo (book-mirror)
    [6] Vendas (LP, deck, GTM, agente builder)
    [7] Meta (configuração, audit)

1.6 Integra com /elo (coordinator)?
    - Se [1] (atômica) → não precisa, usuário chama direto
    - Se [2-7] → sim, precisa de trigger no /elo

1.7 Qual Director executa? (apenas se for [2-7])
    /elo-ops | /elo-content | /elo-vendas

1.8 Usa MCP tools? Quais? (lista, vazio se não)
    Ex: "clickup, elobrain"

1.9 Tem state persistente? (sim/não)
    Se sim → cria ~/.claude/state/<name>/

1.10 Tem hook em outras skills? (sim/não)
     Se sim → quais skills + qual ação
     Ex: "salve avisa se tem timer ativo"
```

### Passo 2 — Resumo antes de gerar

Mostrar tudo coletado pra confirmação:

```
📋 Skill: /<name>
Descrição: <desc>
Triggers: <list>
Source canônica: ~/elobrain/skills/<name>/  OR  cerebro/skills/<name>/
Tipo: <classificação>
Integração /elo: <sim/não, qual bucket>
Director: <nome ou —>
MCP tools: <list>
State persistente: <sim/não>
Hooks em outras skills: <list ou —>

Aprovar? [s/edit/n]
```

### Passo 3 — Gerar SKILL.md no template padrão

Estrutura mínima:

```markdown
---
name: <name>
description: >
  <descrição completa em 2-3 linhas>
  Triggers: <list>.
---

# /<name>

<paragrafo introdutório>

**Pré-requisito:** <pré-requisitos se houver>

---

## Por que existe

<problema que resolve>

---

## Quando rodar

- <gatilhos de uso>

Não rodar:
- <anti-patterns>

---

## Passo 1 — <primeira etapa>

<conteúdo>

---

## Passo N — <última etapa>

<conteúdo>

---

## Regras

- <regra 1>
- <regra 2>

---

## Convenções

<formatação, status, datas, etc.>
```

Salvar no path correto:
- Framework → `~/elobrain/skills/<name>/SKILL.md`
- Eloscope-only → `$SECOND_BRAIN_PATH/skills/<name>/SKILL.md`

### Passo 4 — Atualizar manifest.json (se framework)

Apenas se a skill foi pro elobrain.

Adicionar entry antes do `]` final do array `skills`:

```json
{
  "name": "<name>",
  "path": "<name>/SKILL.md",
  "description": "<descrição completa do frontmatter>"
}
```

### Passo 5 — Integrar com /elo (se aplicável)

Apenas se respondeu `sim` em 1.6.

Editar `~/elobrain/skills/elo/SKILL.md`:

1. Adicionar trigger no bucket correto (Bucket 2 Ops, Bucket 3 Content, Bucket 4 Vendas, etc.)
2. Adicionar linha na tabela "Exemplos práticos" com formato:
   ```
   | "<frase do usuário>" | <bucket> | INLINE/SUB-AGENT | invoca /<skill> |
   ```

### Passo 6 — Integrar com Director (se aplicável)

Apenas se o tipo for [2-7].

Editar `~/elobrain/skills/<director>/SKILL.md`:

1. Adicionar a skill na lista `members:`
2. Atualizar `handoff_in.pipeline` se a skill define um novo modo
3. Bumpar `version` (patch ou minor conforme escopo)

### Passo 7 — Criar state dir (se aplicável)

Apenas se respondeu `sim` em 1.9.

```bash
mkdir -p ~/.claude/state/<name>
# Não cria arquivo — skill cria quando primeiro estado é gravado
```

### Passo 8 — Criar hooks em outras skills (se aplicável)

Apenas se respondeu `sim` em 1.10.

Para cada hook listado:
1. Identificar Passo apropriado na skill target
2. Adicionar bloco de check ao final do passo (não bloqueante por padrão)
3. Mencionar a skill nova como contexto no comentário

### Passo 9 — Sync local (~/.claude/skills/)

```bash
mkdir -p ~/.claude/skills/<name>
# Se framework:
rsync -a --delete ~/elobrain/skills/<name>/ ~/.claude/skills/<name>/
# Se Eloscope-only:
rsync -a --delete $SECOND_BRAIN_PATH/skills/<name>/ ~/.claude/skills/<name>/
```

### Passo 10 — Commit + push

**Se framework:**
```bash
git -C ~/elobrain add skills/<name>/ skills/manifest.json skills/elo/SKILL.md skills/<director>/SKILL.md
git -C ~/elobrain commit -m "feat: skill /<name> (+ integração elo/<director> se aplicável)"
git -C ~/elobrain push origin main
```

**Se Eloscope-only:**
```bash
cd $SECOND_BRAIN_PATH
git add skills/<name>/
# Se editou /elo (que mora no elobrain) — commitar também no elobrain
git commit -m "feat: skill Eloscope /<name>"
git pull --rebase origin main
git push origin main
```

### Passo 11 — Criar task no ClickUp (opcional, perguntar)

```
Criar task no ClickUp pra registro? [s/n]
```

Se `s`:
- Lista: Geral / Gestão Interna (`901713180052`)
- Status: complete
- Assignee: usuário ativo (consulta people.md como /validar-sessao)
- Description: descrição da skill + commit refs + path
- Time entry: se `track_time: true` → adicionar (estimativa default: 30min pra skill nova framework)

### Passo 12 — Notificar grupo Squad Eloscope (opcional, perguntar)

```
Mandar mensagem no grupo Squad Eloscope explicando a skill nova? [s/n]
```

Se `s`:
- Texto pré-formatado com: nome, descrição, triggers, exemplo de uso, commits, "pra ativar: roda /salve"
- Mention Lucas e Hugo (5517920008791 e 5521981792857)
- Via mcp__whatsapp-uazapi__enviar_mensagem
- Grupo JID: `120363423380286175@g.us`

### Passo 13 — Resumo final

```
✓ Skill /<name> criada

📁 Arquivos criados/atualizados:
  ~/elobrain/skills/<name>/SKILL.md (X linhas)
  ~/elobrain/skills/manifest.json (entry adicionada)
  ~/elobrain/skills/elo/SKILL.md (trigger no bucket Y)
  ~/elobrain/skills/<director>/SKILL.md (member adicionado)
  ~/.claude/skills/<name>/ (sync local)

🔗 Commits:
  elobrain: <hash>
  cerebro:  <hash> (se aplicável)

📋 ClickUp:
  Task <id> criada (se aplicável)
  Time entry: Xmin (se track_time)

📱 Notificação:
  Squad Eloscope notificado (se aplicável)

Próximo passo: testar a skill rodando /<name> em uma sessão real.
```

---

## Regras

- **Nunca pular o Passo 1** — mesmo que pareça óbvio, perguntar tudo garante consistência
- **Nunca criar skill em 2 lugares** — escolher elobrain OU cerebro, nunca os dois
- **Nunca pular o sync** — sem `~/.claude/skills/<name>/`, Claude Code não acha a skill
- **Sempre commitar tudo junto** — manifest + /elo + Director no mesmo commit pra atomicidade
- **Sempre confirmar antes de criar ClickUp task ou enviar WhatsApp** — são ações externas com efeito
- **Use a heurística da replicabilidade** — "outra empresa que comprou Elo OS usaria essa skill?" Sim = framework, Não = Eloscope-only
- **Bumpar versão do Director** — toda vez que adicionar member, é minor bump (0.3.0 → 0.4.0)
- **Use `criar-skill` pra criar `criar-skill`** — depois que ela existe, qualquer nova skill (inclusive uma evolução dela mesma) passa por ela

---

## Convenções

### Naming

- **kebab-case obrigatório** — `validar-sessao` não `validarSessao` nem `validar_sessao`
- **Verbo no início** quando ação — `validar-sessao`, `criar-skill`, `processar-reuniao`
- **Substantivo** quando estado/recurso — `cronometro`, `briefing`, `cockpit`
- **Sem prefixo de plataforma** — não `claude-validar` ou `cc-validar`. A skill é da Eloscope, não do Claude Code.

### Triggers

- **Pelo menos 3-4 frases naturais** — usuário não vai sempre lembrar nome exato
- **PT-BR como default** + EN se a skill tem audience internacional
- **Incluir o slash command** entre as triggers — `/validar-sessao`, `/cronometro`

### Frontmatter

- `name` é obrigatório
- `description` em 2-4 linhas usando `>` (YAML folded)
- `description` inclui as triggers no fim

### Estrutura do corpo

- Passos numerados (`## Passo 1 — ...`)
- Subpassos com letras (`### 1.a`, `### 1.b`)
- Bloco `## Regras` sempre presente
- Bloco `## Convenções` sempre presente

### Heurísticas de classificação framework vs Eloscope-only

| Pergunta | Resposta → Onde |
|---|---|
| Depende de cliente específico nosso (Maqlam, Campos, etc.)? | Sim → cerebro |
| Depende dos nossos fluxos comerciais específicos? | Sim → cerebro |
| Faz operação genérica (timer, validador, briefing)? | Sim → elobrain |
| Outra empresa de IA usaria igual? | Sim → elobrain |
| Tem hardcode de IDs nossos (Workspace ID, list IDs)? | Sim → cerebro (ou refatorar pra config) |
