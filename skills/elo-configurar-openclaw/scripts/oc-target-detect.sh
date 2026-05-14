#!/usr/bin/env bash
# oc-target-detect.sh — detecta o modo de deploy do OpenClaw e imprime variáveis exportáveis.
#
# Uso:
#   ./oc-target-detect.sh                    # detecta local
#   ./oc-target-detect.sh user@host          # detecta via SSH
#
# Saída (eval-friendly):
#   OC_MODE=local-docker
#   OC_HOST=
#   OC_CONTAINER=openclaw-0v1y-openclaw-1
#   OC_COMPOSE_DIR=/docker/openclaw-0v1y
#   OC_CONFIG_PATH=/docker/openclaw-0v1y/data/.openclaw/openclaw.json
#   OC_ENV_PATH=/docker/openclaw-0v1y/.env
#   OC_OWNER=1000:1000
#
# Para usar:
#   eval "$(./oc-target-detect.sh root@srv991685.hstgr.cloud)"

set -euo pipefail

HOST="${1:-}"
PFX=""
if [ -n "$HOST" ]; then
  PFX="ssh -o BatchMode=yes -o ConnectTimeout=8 $HOST --"
fi

# Função: rodar comando local ou remoto
run() { if [ -n "$PFX" ]; then $PFX "$@"; else "$@"; fi }

# Sanity: SSH funciona?
if [ -n "$HOST" ]; then
  if ! ssh -o BatchMode=yes -o ConnectTimeout=8 "$HOST" true 2>/dev/null; then
    echo "ERRO: SSH para $HOST falhou (BatchMode). Configure ~/.ssh/config ou use chave." >&2
    exit 2
  fi
fi

# (a) CLI nativo no PATH?
HAS_CLI="false"
if run bash -c 'command -v openclaw >/dev/null 2>&1'; then
  HAS_CLI="true"
fi

# (b) container do openclaw rodando?
CONTAINER=""
COMPOSE_DIR=""
if run bash -c 'command -v docker >/dev/null 2>&1'; then
  CONTAINER=$(run bash -c "docker ps --format '{{.Names}}\t{{.Image}}' 2>/dev/null | grep -E 'openclaw|hvps-openclaw' | head -1 | awk '{print \$1}'")
  if [ -n "$CONTAINER" ]; then
    COMPOSE_DIR=$(run bash -c "docker inspect '$CONTAINER' --format '{{ index .Config.Labels \"com.docker.compose.project.working_dir\" }}' 2>/dev/null")
  fi
fi

# Decidir modo
MODE=""
if [ -n "$CONTAINER" ]; then
  if [ -n "$HOST" ]; then MODE="ssh-docker"; else MODE="local-docker"; fi
elif [ "$HAS_CLI" = "true" ]; then
  if [ -n "$HOST" ]; then MODE="ssh-native"; else MODE="local-native"; fi
else
  echo "ERRO: nem 'openclaw' CLI nem container OpenClaw foram encontrados em ${HOST:-localhost}." >&2
  echo "      Verifique a instalação ou passe um host SSH correto." >&2
  exit 3
fi

# Resolver paths
CONFIG_PATH=""
ENV_PATH=""
OWNER=""

case "$MODE" in
  *-docker)
    if [ -z "$COMPOSE_DIR" ]; then
      echo "ERRO: container detectado ($CONTAINER) mas sem label com.docker.compose.project.working_dir." >&2
      echo "      Rodar manualmente para descobrir: docker inspect $CONTAINER" >&2
      exit 4
    fi
    CONFIG_PATH="$COMPOSE_DIR/data/.openclaw/openclaw.json"
    ENV_PATH="$COMPOSE_DIR/.env"
    OWNER=$(run bash -c "stat -c '%u:%g' '$CONFIG_PATH' 2>/dev/null || echo 0:0")
    ;;
  *-native)
    USER_HOME=$(run bash -c 'echo $HOME')
    CONFIG_PATH="$USER_HOME/.openclaw/openclaw.json"
    ENV_PATH="/etc/systemd/system/openclaw.service.d/override.conf"
    OWNER=$(run bash -c "stat -c '%u:%g' '$CONFIG_PATH' 2>/dev/null || echo 0:0")
    ;;
esac

# Imprimir
echo "OC_MODE=$MODE"
echo "OC_HOST=${HOST:-}"
echo "OC_CONTAINER=${CONTAINER:-}"
echo "OC_COMPOSE_DIR=${COMPOSE_DIR:-}"
echo "OC_CONFIG_PATH=${CONFIG_PATH:-}"
echo "OC_ENV_PATH=${ENV_PATH:-}"
echo "OC_OWNER=${OWNER:-0:0}"
