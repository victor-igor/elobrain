---
name: elo-setup
description: Onboarding completo do sistema /elo para novo membro do time Eloscope. Instala elobrain, configura MCP, plugins, skills e cria perfil no brain compartilhado.
triggers:
  - "elo setup"
  - "instalar elo"
  - "onboarding elo"
  - "setup eloscope"
  - "novo membro"
mutating: true
---

# /elo-setup — Onboarding Eloscope

Instala e configura o sistema `/elo` completo para um novo membro do time.
Target: `/elo` funcionando em menos de 30 minutos.

## Contrato

- elobrain CLI instalado e conectado ao Supabase compartilhado do time
- MCP `elobrain` configurado no `~/.claude.json`
- Plugins obrigatórios instalados
- Skills do `/elo` copiadas para `~/.claude/skills/`
- Perfil do usuário criado no brain via `/soul-audit`
- Verificação final com `/elo` → "me prepara pro dia"

---

## Fase A — Coletar credenciais

Antes de qualquer coisa, perguntar ao usuário:

> "Vou precisar de algumas informações que o Victor deve ter te passado. Pode ir respondendo:"

1. **Seu slug no time** (lucas | hugo | outro):
   - Salvar como `USER_SLUG`

2. **GBRAIN_DATABASE_URL** — a connection string do Supabase:
   - Formato: `postgresql://postgres.[ref]:[senha]@aws-1-sa-east-1.pooler.supabase.com:6543/postgres?options=-c%20search_path%3Delobrain%2Cpublic`
   - Salvar como `DB_URL`

3. **OPENAI_API_KEY** — chave da OpenAI:
   - Salvar como `OPENAI_KEY`

4. **FATHOM_API_TOKEN** — token do Fathom (para reuniões):
   - Opcional. Se não tiver, pular por agora.
   - Salvar como `FATHOM_TOKEN`

5. **URL do repositório cerebro** — o vault de markdown do time:
   - Ex: `https://github.com/victor-igor/cerebro.git`
   - Salvar como `CEREBRO_REPO`

Se o usuário não tiver alguma credencial, orientar: *"Pede pro Victor via DM — não compartilha em canal aberto."*

---

## Fase B — Configurar variáveis de ambiente

Adicionar ao `~/.zshrc`:

```bash
# Verificar se já existe bloco Eloscope
grep -q "Eloscope Brain" ~/.zshrc && echo "já existe" || echo "não existe"
```

Se não existe, adicionar:

```bash
cat >> ~/.zshrc << 'EOF'

# --- Eloscope Brain ---
export ELOBRAIN_USER={USER_SLUG}
export OPENAI_API_KEY={OPENAI_KEY}
export GBRAIN_DATABASE_URL="{DB_URL}"
export GBRAIN_DIRECT_DATABASE_URL="$GBRAIN_DATABASE_URL"
export SECOND_BRAIN_PATH="$HOME/cerebro"
EOF
```

Se já existe, editar as linhas existentes para não duplicar.

Recarregar:
```bash
source ~/.zshrc
```

Verificar:
```bash
echo "USER: $ELOBRAIN_USER | DB: ${GBRAIN_DATABASE_URL:0:30}..."
```

---

## Fase C — Clonar o vault (cerebro)

```bash
if [ -d "$HOME/cerebro/.git" ]; then
  echo "cerebro já existe, fazendo pull..."
  git -C "$HOME/cerebro" pull
else
  git clone {CEREBRO_REPO} "$HOME/cerebro"
fi
```

Verificar:
```bash
ls "$HOME/cerebro" | head -5
```

---

## Fase D — Instalar elobrain (via /setup)

Chamar o skill `/setup` que trata automaticamente:
- Instalação do bun
- Clone do repositório elobrain
- `elobrain init --non-interactive --url $GBRAIN_DATABASE_URL`
- `elobrain doctor --json`
- Configuração do autopilot

> Instrução ao executar: invocar o skill `setup` passando que já temos a connection string
> nas env vars. Quando o `/setup` perguntar pela connection string, usar o valor de
> `$GBRAIN_DATABASE_URL`.

Se `/setup` já foi rodado antes e elobrain está instalado, verificar apenas:
```bash
elobrain --version && elobrain doctor --json
```

---

## Fase E — Configurar MCP no Claude Code

Verificar se `~/.claude.json` existe e se já tem o bloco `elobrain`:

```bash
[ -f ~/.claude.json ] && grep -q "elobrain" ~/.claude.json && echo "já configurado" || echo "precisa configurar"
```

Se não configurado, fazer merge do bloco abaixo em `~/.claude.json` dentro de `"mcpServers"`:

```json
"elobrain": {
  "command": "elobrain",
  "args": ["serve"],
  "env": {
    "OPENAI_API_KEY": "${OPENAI_API_KEY}",
    "GBRAIN_DATABASE_URL": "${GBRAIN_DATABASE_URL}",
    "GBRAIN_DIRECT_DATABASE_URL": "${GBRAIN_DIRECT_DATABASE_URL}"
  }
}
```

**CUIDADO:** não sobrescrever outros MCPs existentes — fazer merge no JSON.

Orientar o usuário: *"Reinicia o Claude Code para o MCP elobrain ser carregado."*

---

## Fase F — Instalar plugins obrigatórios

Verificar quais plugins já estão instalados:
```bash
cat ~/.claude/plugins/installed_plugins.json 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
plugins = d.get('plugins', {})
print(list(plugins.keys()))
" 2>/dev/null
```

Instalar os que estiverem faltando. Orientar o usuário a rodar no Claude Code (não no terminal):

**Obrigatórios:**
```
/plugin install superpowers@claude-plugins-official
/plugin install context-mode@context-mode
```

**Recomendados:**
```
/plugin install context7@claude-plugins-official
/plugin install claude-mem@thedotmack
/plugin install supabase@claude-plugins-official
```

Aguardar confirmação do usuário que rodou os comandos.

---

## Fase G — Instalar skills do /elo

Verificar se as skills já estão presentes:
```bash
ls ~/.claude/skills/ | grep -E "^elo" | sort
```

Skills obrigatórias que precisam existir:
- `elo`, `elo-brain`, `elo-ops`, `elo-content`, `elo-vendas`
- `soul-audit`, `briefing`, `rotina`, `salve`, `maintain`
- `carrossel-eloscope`, `meeting-ingestion`, `ingest`, `query`

Se alguma estiver faltando, orientar:

> "Pede pro Victor o arquivo `elo-skills.zip` e rode:"
> ```bash
> unzip ~/Downloads/elo-skills.zip -d ~/.claude/skills/
> ```

Após extrair, verificar novamente:
```bash
ls ~/.claude/skills/ | grep -E "^elo"
```

---

## Fase H — Configurar settings.json base

Verificar se `~/.claude/settings.json` tem as env vars necessárias:
```bash
cat ~/.claude/settings.json 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
env = d.get('env', {})
print('SECOND_BRAIN_PATH:', env.get('SECOND_BRAIN_PATH', 'FALTANDO'))
print('FATHOM_API_TOKEN:', 'ok' if env.get('FATHOM_API_TOKEN') else 'FALTANDO')
" 2>/dev/null
```

Se `SECOND_BRAIN_PATH` ou `FATHOM_API_TOKEN` estiverem faltando, fazer merge em `~/.claude/settings.json`:

```json
{
  "env": {
    "SECOND_BRAIN_PATH": "/Users/{SEU_USUARIO}/cerebro",
    "FATHOM_API_TOKEN": "{FATHOM_TOKEN}"
  }
}
```

Substituir `{SEU_USUARIO}` pelo usuário real do sistema:
```bash
echo $USER
```

---

## Fase I — Criar perfil no brain (/soul-audit)

Verificar se o perfil já existe no brain:
```
mcp__elobrain__get_page(slug: "memory/users/{USER_SLUG}/USER")
```

Se não existir (404 ou vazio), orientar:

> "Agora vamos criar seu perfil no brain. São ~6 perguntas, leva uns 10 minutos."
> "Chame: `/soul-audit`"

Aguardar o usuário confirmar que rodou e o perfil foi criado.

Se já existir, informar: *"Seu perfil já está no brain — pulando esta etapa."*

---

## Fase J — Verificação final

Checar todos os componentes:

```bash
# 1. elobrain CLI
elobrain --version

# 2. Env vars
echo "USER=$ELOBRAIN_USER | PATH=$(which elobrain)"

# 3. Cerebro
ls "$SECOND_BRAIN_PATH" | wc -l

# 4. MCP
grep -q "elobrain" ~/.claude.json && echo "MCP: ok" || echo "MCP: FALTANDO"

# 5. Skills
ls ~/.claude/skills/ | grep -c "^elo"
```

Checar perfil no brain:
```
mcp__elobrain__get_page(slug: "memory/users/{USER_SLUG}/USER")
```

Se tudo OK, orientar o teste final:

> "Reinicia o Claude Code e escreve: `/elo` → 'me prepara pro dia'"
> "Se aparecer um briefing com pendências e projetos, está tudo funcionando."

---

## Checklist de saída

Reportar ao usuário o status de cada item:

```
ELO-SETUP COMPLETO
==================
[ ] elobrain CLI instalado (versão X)
[ ] Supabase conectado (doctor: all OK)
[ ] MCP elobrain no ~/.claude.json
[ ] Plugins: superpowers, context-mode, context7, claude-mem
[ ] Skills /elo instaladas (N skills)
[ ] settings.json configurado
[ ] Perfil memory/users/{slug}/* criado
[ ] Teste /elo: OK

Próximo passo: chame /elo e escreva "me prepara pro dia"
```

---

## Erros comuns

| Erro | Causa | Fix |
|---|---|---|
| `elobrain: command not found` | bun não no PATH | `export PATH="$HOME/.bun/bin:$PATH"` + reiniciar terminal |
| `connection refused` | URL errada ou porta errada | Confirmar que usa porta 6543 (Session pooler) |
| `mcp__elobrain__*` não aparece | MCP não carregado | Reiniciar o Claude Code |
| Skills não encontradas | zip não extraído corretamente | Verificar se estão em `~/.claude/skills/elo/SKILL.md` |
| `/soul-audit` falha | MCP não conectado | Reiniciar Claude Code e tentar novamente |
