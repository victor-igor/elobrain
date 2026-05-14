# 01 — Detectar e conectar ao target

> Sempre o **primeiro passo** de qualquer sessão. Sem isso, comandos vão para o lugar errado.

## 1.1. Pergunte ao usuário (se ambíguo)

Se o usuário não disse onde está o OpenClaw, pergunte com **AskUserQuestion**:

- "VPS remota via SSH" (ex: Hostinger)
- "Esta máquina (local)"
- "Não sei / quero descobrir"

Se SSH: peça `user@host` e (opcional) `~/.ssh/config` alias.
Se local: prossiga com detecção automática.

## 1.2. Descobrir variante (native vs docker)

Em qualquer um dos lados (local ou remoto), rode os checks na seguinte ordem:

```bash
# Em local-* o prefixo é vazio. Em ssh-* o prefixo é: ssh user@host --
PFX=""              # ou: PFX="ssh $OC_HOST --"

# (a) CLI nativo no PATH?
$PFX command -v openclaw && echo "native_candidate"

# (b) Docker e algum container do OpenClaw?
$PFX docker ps --format '{{.Names}}\t{{.Image}}' 2>/dev/null \
  | grep -E 'openclaw|hvps-openclaw' \
  | head -1
```

Decisão:

| Output | OC_MODE |
|---|---|
| Só `native_candidate`, sem container | `local-native` ou `ssh-native` |
| Container detectado, sem CLI no host | `local-docker` ou `ssh-docker` |
| Ambos (raro) | Pergunte ao user qual usar |
| Nenhum | OpenClaw não está instalado — orientar `references/03-providers-modelos.md §Setup inicial` |

## 1.3. Resolver paths (depende do modo)

### Modo `*-native`

```bash
$PFX bash -c '
  CFG="$HOME/.openclaw/openclaw.json"
  [ -f "$CFG" ] && echo "OC_CONFIG_PATH=$CFG"
  ENV_OVERRIDE="/etc/systemd/system/openclaw.service.d/override.conf"
  [ -f "$ENV_OVERRIDE" ] && echo "OC_ENV_PATH=$ENV_OVERRIDE"
  echo "OC_OWNER=$(stat -c "%u:%g" "$CFG" 2>/dev/null || echo 0:0)"
'
```

### Modo `*-docker`

```bash
$PFX bash -c '
  for CTR in $(docker ps --format "{{.Names}}" | grep -E "openclaw"); do
    LBL=$(docker inspect "$CTR" --format "{{ index .Config.Labels \"com.docker.compose.project.working_dir\" }}")
    [ -n "$LBL" ] && echo "OC_CONTAINER=$CTR"
    [ -n "$LBL" ] && echo "OC_COMPOSE_DIR=$LBL"
    [ -n "$LBL" ] && [ -f "$LBL/data/.openclaw/openclaw.json" ] \
       && echo "OC_CONFIG_PATH=$LBL/data/.openclaw/openclaw.json"
    [ -n "$LBL" ] && [ -f "$LBL/.env" ] && echo "OC_ENV_PATH=$LBL/.env"
    OWNER=$(stat -c "%u:%g" "$LBL/data/.openclaw/openclaw.json" 2>/dev/null)
    [ -n "$OWNER" ] && echo "OC_OWNER=$OWNER"
    break
  done
'
```

## 1.4. Persistir no contexto da skill

Salve as variáveis no estado da sessão (na sua memória conversacional). Reapresente-as ao usuário ANTES de qualquer mudança:

```
🔌 Target detectado:
   Modo:      ssh-docker
   Host:      root@srv991685.hstgr.cloud
   Container: openclaw-0v1y-openclaw-1
   Compose:   /docker/openclaw-0v1y
   Config:    /docker/openclaw-0v1y/data/.openclaw/openclaw.json
   .env:      /docker/openclaw-0v1y/.env
   Owner JSON: 1000:1000
```

E pergunte: **"Confirma este target?"** Se o usuário disser não, refaça a detecção.

## 1.5. Wrapper unificado

A partir daqui, NUNCA chame `openclaw` diretamente. Use `scripts/oc-wrap.sh`, que recebe um subcomando e escolhe o transporte:

```bash
./scripts/oc-wrap.sh "config validate"
./scripts/oc-wrap.sh "models status"
./scripts/oc-wrap.sh "plugins list"
```

Ele lê `OC_MODE`, `OC_HOST`, `OC_CONTAINER` do ambiente e monta a chamada certa.

## 1.6. SSH: pré-checagens recomendadas

Antes de executar mudanças num target SSH:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=5 $OC_HOST true && echo "ssh: ok"
ssh $OC_HOST 'sudo -n true 2>/dev/null && echo sudo:nopasswd || echo sudo:askpw'
ssh $OC_HOST 'docker ps >/dev/null 2>&1 && echo docker:ok || echo docker:missing'
```

Se `sudo:askpw`: avise que mudanças em UFW/fail2ban/systemd vão pedir senha — considere rodar manualmente.

## 1.7. Pegadinhas

- Hostinger HVPS: o template "One-Click OpenClaw" usa Docker Compose; instalações pelo curso são bare-metal — verifique antes de assumir.
- O label `com.docker.compose.project.working_dir` só existe se o container subiu via `docker compose`. Se foi `docker run` direto, peça o caminho ao usuário.
- Em `ssh-docker`, o usuário SSH precisa ser membro do grupo `docker` ou ter sudo — caso contrário, `docker exec` falha.
