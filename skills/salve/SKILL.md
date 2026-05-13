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

**Pré-requisito:** `$SECOND_BRAIN_PATH` configurado e repositório Git acessível.

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
