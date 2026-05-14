# 09 — Skills customizadas

> Skills user-defined são markdown estruturado que ensinam o agente a fazer algo específico (chamar uma API, seguir um workflow, etc.). Sem plugin nativo, sem código — só prompt + estrutura.

## 9.1. Local físico

```
<workspace>/.openclaw/skills/<nome>/SKILL.md
```

Em docker:
```
$OC_COMPOSE_DIR/data/.openclaw/skills/<nome>/SKILL.md
```

Em native:
```
~/.openclaw/skills/<nome>/SKILL.md
```

## 9.2. Frontmatter OBRIGATÓRIO (descoberta falha sem isso)

```yaml
---
name: <id-da-skill>
description: <descrição completa do que faz, com keywords PT-BR + EN>
---
```

`description` deve incluir:
- O que a skill faz
- Quando usar (triggers / palavras-chave)
- Saída típica

Sem `description` rica, o gateway não escolhe a skill — o triage é por descrição.

## 9.3. Estrutura recomendada do SKILL.md

```markdown
---
name: minha-skill
description: ...
---

# Minha Skill

## When to use
Triggers (PT-BR + EN), keywords, casos de uso.

## Authentication / setup
Ex.: header, env var, paths.

## Templates / patterns
Snippet de comando padrão (ex: curl, jq), com placeholders claros.

## Endpoints / actions
Tabela das ações suportadas.

## Examples
Exemplos prontos.

## Errors / edge cases
Códigos esperados, paginação, alertas.
```

## 9.4. Permissões corretas

Em docker: o gateway roda como UID `1000:1000` (ubuntu). Arquivos da skill devem ter:
```bash
chown 1000:1000 SKILL.md   # dentro do bind do data dir
chmod 644 SKILL.md
```

Em native: dono é o user que rodou o daemon (geralmente `root` ou `<seu-user>`).

## 9.5. Habilitar diretório customizado

Snippet `snippets/skill-extra-dirs.json`:

```json
{
  "skills": {
    "load": {
      "extraDirs": ["/data/.openclaw/skills"]
    },
    "entries": {
      "<id-da-skill>": { "enabled": true }
    }
  }
}
```

> Em native, o caminho é `/home/<user>/.openclaw/skills` (ou onde estiver). Em docker, `/data/.openclaw/skills` (caminho INTERNO do container, que mapeia pro bind do host).

```bash
./scripts/oc-json-patch.py "$OC_CONFIG_PATH" snippets/skill-extra-dirs.json
./scripts/oc-wrap.sh "config validate"
./scripts/oc-reload.sh restart
```

## 9.6. Verificação

```bash
./scripts/oc-wrap.sh "skills list -v"
./scripts/oc-wrap.sh "skills info <id>"
./scripts/oc-wrap.sh "skills list --eligible"   # confirma que está apta a ser invocada
```

Esperado:
- Status: `✓ ready`
- Source: `openclaw-managed`
- A descrição completa aparece em `skills info`.

## 9.7. Sessão cacheada — pegadinha clássica

Após adicionar a skill, sessões Telegram/WhatsApp já abertas **não a conhecem** (system prompt cacheado). Solução: peça ao usuário enviar `/start` no bot ou perguntar "Liste suas skills" pra forçar reload.

## 9.8. Procedimento end-to-end (criar skill nova)

```bash
# 1. Criar diretório no host (path varia: docker vs native)
ssh $OC_HOST "mkdir -p $OC_COMPOSE_DIR/data/.openclaw/skills/minha-skill"

# 2. Escrever SKILL.md com frontmatter
ssh $OC_HOST "cat > $OC_COMPOSE_DIR/data/.openclaw/skills/minha-skill/SKILL.md" <<'EOF'
---
name: minha-skill
description: ...
---

# Minha Skill
...
EOF

# 3. Permissões
ssh $OC_HOST "chown -R 1000:1000 $OC_COMPOSE_DIR/data/.openclaw/skills/minha-skill"
ssh $OC_HOST "chmod 644 $OC_COMPOSE_DIR/data/.openclaw/skills/minha-skill/SKILL.md"

# 4. Habilitar via openclaw.json
./scripts/oc-json-patch.py "$OC_CONFIG_PATH" snippets/skill-extra-dirs.json

# 5. Reload
./scripts/oc-wrap.sh "config validate"
./scripts/oc-reload.sh restart

# 6. Verificar
./scripts/oc-wrap.sh "skills list -v"
./scripts/oc-wrap.sh "skills info minha-skill"
```

## 9.9. Pegadinhas

- Nome da skill no diretório, no frontmatter (`name:`) e no `entries.<id>` precisam BATER. Diferença = skill não habilita.
- Owner errado em docker (root em vez de 1000:1000) = watcher quebra com EACCES e a skill não é reindexada após edição.
- Adicionar nova `extraDirs` exige restart (não só hot reload).
- ClawHub (catálogo público): se a skill já existe lá, prefira instalar via `openclaw skills install <id>` em vez de criar local — recebe updates.
