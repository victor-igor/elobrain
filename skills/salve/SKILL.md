---
name: salve
description: >
  Flush de fim de sessão — captura tudo que aconteceu e atualiza o segundo cérebro.
  Percorre todas as áreas (pendências, decisões, pessoas, projetos, métricas, skills)
  e garante que nada se perde entre sessões. Sempre rodar antes de fechar.
  Triggers: "salve", "salva", "salva a sessão", "flush", "fecha a sessão".
---

# /salve

Flush completo de fim de sessão. Captura o contexto da conversa e persiste no segundo cérebro.

**Pré-requisito:** `$SECOND_BRAIN_PATH` configurado e repositório Git acessível. Cofre (`Eloscope-Cofre`) clonado como irmão do Cerebro.

---

## Passo 0 — Blindagem de dados sensíveis (NOVO)

**Executar ANTES de tudo.** Detecta dados confidenciais no Cerebro e oferece mover pro Cofre automaticamente. Bloqueia /salve se houver sensível não-blindado.

### 0.1 — Verificar pré-requisitos

```bash
cd "$SECOND_BRAIN_PATH"

# Cofre deve estar clonado como irmão
cofre_path="$(dirname "$SECOND_BRAIN_PATH")/Eloscope-Cofre"
if [[ ! -d "$cofre_path/.git" ]]; then
  echo "⚠️  Cofre não encontrado em: $cofre_path"
  echo "   Clone o Cofre como irmão do Cerebro:"
  echo "   git clone git@github-eloscope:eloscopecoo-rgb/Eloscope-Cofre.git ../Eloscope-Cofre"
  exit 1
fi

echo "🔍 Escaneando dados sensíveis..."
```

### 0.2 — Detectar arquivos com dados confidenciais

```bash
# Arquivos modified, staged, untracked nesta sessão
modified=$(git diff --name-only 2>/dev/null)
staged=$(git diff --cached --name-only 2>/dev/null)
untracked=$(git ls-files --others --exclude-standard 2>/dev/null)

all_changed="$modified
$staged
$untracked"

sensitive_files=()
reason_map=()

# Lista de clientes (atualizar conforme crescer)
CLIENTES="voltrucks|bravo|hugo"

while IFS= read -r file; do
  [[ -z "$file" || ! -f "$file" ]] && continue
  
  reason=""
  
  # Regra 1: pasta de cliente/oportunidade/reunião
  if [[ "$file" =~ areas/vendas/(clientes|oportunidades)/ ]] || \
     [[ "$file" =~ areas/reunioes/clientes/ ]]; then
    reason="📁 pasta confidencial (cliente/oportunidade)"
  # Regra 2: dados financeiros/operacionais
  elif [[ "$file" =~ areas/operacoes/(custos|auditoria) ]] || \
       [[ "$file" =~ financeiro/ ]] || \
       [[ "$file" =~ seguranca/hostinger ]]; then
    reason="📁 pasta confidencial (financeiro)"
  fi
  
  # Se já tem reason por pasta, pula conteúdo
  if [[ -n "$reason" ]]; then
    sensitive_files+=("$file")
    reason_map+=("$reason")
    continue
  fi
  
  # Regra 3: procurar padrões no conteúdo (CPF, CNPJ, nomes clientes)
  if grep -qiE "CPF|CNPJ|[0-9]{3}\.[0-9]{3}\.[0-9]{3}-[0-9]{2}|[0-9]{2}\.[0-9]{3}\.[0-9]{3}/[0-9]{4}-[0-9]{2}|($CLIENTES)|valor (fechado|total|unitário)" "$file" 2>/dev/null; then
    sensitive_files+=("$file")
    reason_map+=("🔐 contém PII/CFO (CPF/CNPJ/valor)")
  fi
done <<< "$all_changed"
```

### 0.3 — Relatar e oferecer blindagem

```bash
if [[ ${#sensitive_files[@]} -eq 0 ]]; then
  echo "✅ Nenhum dado confidencial detectado — prosseguindo"
  echo ""
else
  echo ""
  echo "⚠️  BLINDAGEM: ${#sensitive_files[@]} arquivo(s) com dados sensíveis:"
  echo ""
  for i in "${!sensitive_files[@]}"; do
    printf "  %-40s  %s\n" "${sensitive_files[$i]}" "${reason_map[$i]}"
  done
  echo ""
  echo "Mover para o Cofre automaticamente? (s/n)"
  
  # Leitura da decisão do usuário
  read -r response
  
  if [[ "$response" != "s" ]]; then
    echo ""
    echo "❌ /salve bloqueado — dados sensíveis detectados"
    echo ""
    echo "Resolva manualmente:"
    echo "  1. git rm <arquivo> (deletar do Cerebro)"
    echo "  2. Verificar se arquivo já está no Cofre"
    echo "  3. Rodar /salve novamente quando limpo"
    echo ""
    exit 1
  fi
fi
```

### 0.4 — Mover para o Cofre (se confirmado)

```bash
if [[ "$response" == "s" && ${#sensitive_files[@]} -gt 0 ]]; then
  echo ""
  echo "🚀 Movendo para o Cofre..."
  
  moved=0
  failed=0
  
  for file in "${sensitive_files[@]}"; do
    target="$cofre_path/$file"
    target_dir=$(dirname "$target")
    
    # Criar diretórios no Cofre
    mkdir -p "$target_dir"
    
    # Mover arquivo
    if git -C "$SECOND_BRAIN_PATH" mv "$file" "$target" 2>/dev/null; then
      echo "  ✓ $file"
      ((moved++))
    else
      # Fallback: cp + rm se git mv falhar
      cp "$file" "$target" 2>/dev/null && rm "$file" 2>/dev/null && \
        echo "  ✓ $file (fallback)" && ((moved++)) || \
        { echo "  ✗ $file (ERRO)"; ((failed++)); }
    fi
  done
  
  echo ""
  if [[ $failed -eq 0 ]]; then
    echo "✅ Blindagem concluída — $moved arquivo(s) movidos pro Cofre"
    echo ""
    echo "Próximas etapas:"
    echo "  • /salve vai commitar no Cerebro (remoções) + Cofre (adições)"
  else
    echo "⚠️  Blindagem parcial — $moved movidos, $failed falharam"
    echo "   Revise os erros antes de continuar"
    exit 1
  fi
fi

echo ""
```

---

## Passo 1 — Revisar a sessão (sem output)

Revisar mentalmente TUDO que aconteceu nesta conversa:
- Decisões tomadas
- Pendências criadas ou resolvidas
- Pessoas mencionadas (novas ou com role atualizado)
- Projetos com status alterado
- Métricas atualizadas
- Deadlines novos ou concluídos
- Skills criadas, editadas ou removidas
- Arquivos criados ou movidos
- Ideias mencionadas (conteúdo, produto, negócio)

---

## Passo 2 — Atualizar arquivos conforme PROPAGATION.md

Ler `$SECOND_BRAIN_PATH/PROPAGATION.md` e seguir a tabela completa.

Resumo rápido:

| Mudou? | Atualizar |
|--------|-----------|
| Pendência criada/resolvida | `memory/context/pendencias.md` |
| Decisão tomada | `memory/context/decisoes/YYYY-MM.md` |
| Decisão afeta negócio/equipe/foco | também `memory/context/business-context.md` |
| Pessoa nova ou role mudou | `memory/context/people.md` |
| Pessoa é da equipe principal | também `memory/context/business-context.md` |
| Projeto novo | `memory/projects/{nome}.md` + `memory/projects/_index.md` |
| Projeto mudou de status | `memory/projects/{nome}.md` + `_index.md` |
| Métrica atualizada | `memory/projects/{nome}.md` |
| Métrica-chave (MRR, usuários, receita) | também `memory/context/business-context.md` |
| Deadline novo ou concluído | `memory/context/deadlines.md` |
| Ideia mencionada | arquivo de ideias (crie onde fizer sentido) |

**Lembrete:** `business-context.md` é cache compilado — atualizar sempre que qualquer dado de negócio mudar. Em conflito, as fontes individuais prevalecem.

### Template para novo project file

Quando um projeto novo foi mencionado:

```markdown
# [Nome do Projeto]

> Status: [emoji + status]

## O que é
[1-2 frases]

## Responsáveis
- **[Nome]:** [role]

## Timeline
| Data | Evento |
|------|--------|
| [data] | Projeto criado |

## Decisões Tomadas
- [DD/MM/YYYY] [decisão]

## Pendências
- [ ] [próxima ação]

---
*Criado: DD/MM/YYYY*
```

---

## Passo 3 — Criar/atualizar sessão do dia

Escrever em `$SECOND_BRAIN_PATH/memory/sessions/YYYY-MM-DD.md`:

```markdown
# Sessão — YYYY-MM-DD

## O que foi feito
- [lista de ações principais, 1 linha cada]

## Decisões
- [decisões tomadas, se houver]
- (omitir seção se não houve decisões)

## Em aberto
- [o que ficou pendente para a próxima sessão]
```

Se o arquivo já existir (outra sessão do dia), **adicionar** nova seção no final:

```markdown
## Sessão [HH:MM]

### O que foi feito
- ...

### Em aberto
- ...
```

---

## Passo 4 — Verificação rápida

```bash
# Nenhum arquivo novo na raiz que deveria estar em subpasta?
ls "$SECOND_BRAIN_PATH"/*.md 2>/dev/null | grep -v "^$SECOND_BRAIN_PATH/CLAUDE.md\|PROPAGATION.md\|README.md\|MAPA.md"

# _index.md existe e lista os projetos ativos?
head -5 "$SECOND_BRAIN_PATH/memory/projects/_index.md" 2>/dev/null || echo "AVISO: _index.md não encontrado"
```

Se encontrar inconsistência óbvia, corrigir antes de commitar.

---

## Passo 4.5 — Verificar mudanças no repo elobrain (skills)

```bash
git -C ~/elobrain status --short
```

Se houver arquivos modificados ou não-trackeados:

1. Mostrar ao usuário a lista de mudanças
2. **Pausar e perguntar:** "Detectei mudanças no repo elobrain (skills). Quer commitar e fazer push agora?"
3. Se confirmar → pedir mensagem de commit ou sugerir uma baseada no que mudou
4. Commitar e fazer push:
```bash
git -C ~/elobrain add .
git -C ~/elobrain commit -m "[mensagem confirmada pelo usuário]"
git -C ~/elobrain push origin main
```

Se não houver mudanças ou usuário recusar → pular silenciosamente.

---

## Passo 4.55 — Verificar timer ativo do /cronometro

Antes de fechar a sessão, checar se há timer rodando que pode ter sido esquecido.

```bash
state_file=~/.claude/state/cronometro.json
if [[ -f "$state_file" ]]; then
  active=$(jq -r '.active_task' "$state_file" 2>/dev/null)
  if [[ "$active" != "null" && -n "$active" ]]; then
    task_name=$(jq -r '.active_task.name' "$state_file")
    task_id=$(jq -r '.active_task.id' "$state_file")
    started=$(jq -r '.active_task.started_at' "$state_file")
    paused=$(jq -r '.active_task.paused' "$state_file")
    echo "⚠️ TIMER ATIVO detectado"
    echo "   Task: $task_id — $task_name"
    echo "   Iniciado: $started"
    echo "   Estado: $([[ "$paused" == "true" ]] && echo "pausado" || echo "rodando")"
    echo ""
    echo "Quer parar o timer antes de salvar a sessão? [s/n]"
  fi
fi
```

Se o usuário responder `s` → invocar `/cronometro stop` antes de prosseguir.
Se `n` → seguir, mas registrar warning no resumo do Passo 6.

---

## Passo 4.6 — Sync skills + Audit drift

Garante que `~/.claude/skills/` (cache do Claude Code) reflete `~/elobrain/skills/` (source canônica do framework) + `$SECOND_BRAIN_PATH/skills/` (Eloscope-only). OpenClaw não precisa de sync — lê de elobrain direto.

### 4.6.a — Atualizar elobrain (puxar framework atualizado)

```bash
git -C ~/elobrain pull origin main 2>&1 | tail -3
```

### 4.6.b — Sync framework (elobrain → cache local)

```bash
for skill_dir in ~/elobrain/skills/*/; do
  name=$(basename "$skill_dir")
  # Ignora arquivos não-skill (RESOLVER, _brain-filing-rules, _output-rules, conventions, etc)
  [[ "$name" == "_"* ]] && continue
  [[ "$name" == "conventions" || "$name" == "migrations" || "$name" == "recipes" ]] && continue
  # Só sincroniza se tem SKILL.md
  [[ ! -f "$skill_dir/SKILL.md" ]] && continue
  mkdir -p ~/.claude/skills/"$name"
  rsync -a --delete "$skill_dir" ~/.claude/skills/"$name"/
done
```

### 4.6.c — Sync Eloscope-only (cerebro → cache, sem sobrescrever framework)

```bash
for skill_dir in "$SECOND_BRAIN_PATH"/skills/*/; do
  name=$(basename "$skill_dir")
  [[ ! -f "$skill_dir/SKILL.md" ]] && continue
  # Se já veio do elobrain, é duplicata — pula com warning
  if [[ -f ~/elobrain/skills/"$name"/SKILL.md ]]; then
    echo "⚠️  DUPLICATA: '$name' existe em elobrain E cerebro — decidir source canônica e remover do outro"
    continue
  fi
  mkdir -p ~/.claude/skills/"$name"
  rsync -a --delete "$skill_dir" ~/.claude/skills/"$name"/
done
```

### 4.6.d — Audit: órfãos e symlinks quebrados

```bash
# Skills em ~/.claude/skills/ que não existem em nenhuma source
for skill_dir in ~/.claude/skills/*/; do
  name=$(basename "$skill_dir")
  [[ ! -f "$skill_dir/SKILL.md" ]] && continue
  if [[ ! -d ~/elobrain/skills/"$name" ]] && [[ ! -d "$SECOND_BRAIN_PATH"/skills/"$name" ]]; then
    echo "🟡 ÓRFÃ: '$name' está só em ~/.claude/skills — sem source. Manter ou remover?"
  fi
done

# Symlinks quebrados
find ~/.claude/skills -type l ! -exec test -e {} \; -print 2>/dev/null | while read link; do
  echo "❌ SYMLINK QUEBRADO: $link"
done
```

### 4.6.d.2 — Audit: drift entre manifest.json e RESOLVER.md

Detecta skills que estão registradas em só um dos dois lugares — ambos precisam estar em sync pra OpenClaw + gbrain runtime + Claude Code verem a skill.

```bash
# Skills no manifest mas faltando no RESOLVER.md
manifest_skills=$(jq -r '.skills[].name' ~/elobrain/skills/manifest.json 2>/dev/null)
for skill in $manifest_skills; do
  if ! grep -q "skills/$skill/SKILL.md" ~/elobrain/skills/RESOLVER.md 2>/dev/null; then
    echo "🟠 DRIFT: '$skill' está em manifest.json mas NÃO em RESOLVER.md — OpenClaw fica cego"
  fi
done

# Skills no RESOLVER.md mas faltando no manifest
# Skills Eloscope-only moram no cerebro e NÃO devem estar no manifest do elobrain — pular (linha do RESOLVER contém "Eloscope-only").
eloscope_only=$(grep -iE 'Eloscope-only' ~/elobrain/skills/RESOLVER.md | grep -oE 'skills/[a-z-]+/SKILL\.md' | sed 's|skills/||; s|/SKILL.md||' | sort -u)
resolver_skills=$(grep -oE 'skills/[a-z-]+/SKILL\.md' ~/elobrain/skills/RESOLVER.md | sed 's|skills/||; s|/SKILL.md||' | sort -u)
for skill in $resolver_skills; do
  echo "$eloscope_only" | grep -qx "$skill" && continue  # Eloscope-only: correto estar fora do manifest
  if ! echo "$manifest_skills" | grep -qx "$skill"; then
    echo "🟠 DRIFT: '$skill' está em RESOLVER.md mas NÃO em manifest.json — gbrain runtime fica cego"
  fi
done
```

### 4.6.e — Audit: plugins externos atrasados

```bash
# Plugins consumidos via symlink (ver CLAUDE.md do cerebro para lista atualizada)
for plugin_repo in claude-uazapi-elo; do
  path="$HOME/$plugin_repo"
  [[ ! -d "$path" ]] && continue
  git -C "$path" fetch origin main --quiet 2>/dev/null
  behind=$(git -C "$path" rev-list HEAD..origin/main --count 2>/dev/null)
  if [[ "$behind" -gt 0 ]]; then
    echo "🔄 PLUGIN ATRASADO: '$plugin_repo' tem $behind commit(s) novo(s) no remote — rodar git pull"
  fi
done
```

### 4.6.f — Resumo final do sync

Mostrar ao usuário:

```
✓ Sync skills concluído
  Framework (elobrain → ~/.claude/skills): N skills
  Eloscope-only (cerebro → ~/.claude/skills): M skills
  Duplicatas detectadas: X (precisa limpar)
  Órfãs: Y (revisar manualmente)
  Plugins atrasados: Z (rodar git pull)
```

Se houver duplicatas ou plugins atrasados, **NÃO bloquear** o salve — só sinalizar. Resolver na próxima sessão.

---

## Passo 5 — Commit e push

### 5a — Verificar divergência com o remoto

```bash
cd "$SECOND_BRAIN_PATH"
git fetch origin main
git log HEAD..origin/main --oneline
```

Se o comando retornar commits (remoto tem novidades que o local não tem):
- Listar os arquivos afetados: `git diff HEAD..origin/main --name-only`
- Mostrar ao usuário o que mudou no remoto
- **Pausar e perguntar:** "O remoto tem X commit(s) novo(s). Quer revisar antes de continuar?"
- Só prosseguir com o commit após confirmação explícita do usuário

Se não retornar nada (remoto e local sincronizados) → prosseguir direto.

### 5b — Commitar, integrar e publicar

```bash
cd "$SECOND_BRAIN_PATH"
git add .
git commit -m "sessao: [resumo do que foi feito em 1 linha]"
git pull --rebase origin main
git push origin main
```

Se o push falhar com "rejected":
```bash
git pull --rebase origin main
git push origin main
```

---

## Passo 6 — Confirmar

```
✓ Sessão salva — DD/MM/YYYY

Atualizado:
  [arquivo 1]
  [arquivo 2]
  ...

Não precisou atualizar:
  [categorias sem mudanças]

Pushed para origin/main.
```

---

## Regras

- **Nunca pular o Passo 2** — mesmo que pareça que nada mudou, revisar cada categoria
- **Nunca sobrescrever sessão existente** — se arquivo existe, adicionar seção no final
- **Commits específicos** — "sessao: reunião com cliente X + decisão sobre preço" > "sessao: updates"
- **Conflito no push** → sempre usar `pull --rebase`, nunca `push --force`
- Tom direto no output, sem explicação desnecessária

### Convenção de skills (3 camadas)

- **`~/elobrain/skills/`** = source canônica do **framework** (skills genéricas/replicáveis). Lido nativamente pelo OpenClaw. Vai pro cliente quando replicar Elo OS.
- **`$SECOND_BRAIN_PATH/skills/`** = skills **Eloscope-only** (dependem dos NOSSOS clientes/dados/fluxos). Não vai pro cliente.
- **`~/.claude/skills/`** = cache local do Claude Code de cada membro. Sync automático no Passo 4.6. Nunca editar direto.

**Skill nova framework (genérica/replicável):** criar em `~/elobrain/skills/<name>/` + adicionar no `manifest.json`.

**Skill nova Eloscope-only:** criar em `$SECOND_BRAIN_PATH/skills/<name>/`.

**Em conflito (mesma skill em elobrain E cerebro):** elobrain ganha por padrão. Passo 4.6.c sinaliza pra decidir e limpar duplicata.
