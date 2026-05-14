#!/usr/bin/env bash
# oc-wrap.sh — wrapper unificado para chamar o CLI `openclaw` em qualquer modo.
#
# Requer estas variáveis de ambiente (vindas de oc-target-detect.sh):
#   OC_MODE       (local-native | local-docker | ssh-native | ssh-docker)
#   OC_HOST       (vazio se local; user@host se SSH)
#   OC_CONTAINER  (vazio se native)
#
# Uso:
#   ./oc-wrap.sh "config validate"
#   ./oc-wrap.sh "models status"
#   ./oc-wrap.sh "plugins inspect firecrawl"
#   ./oc-wrap.sh "config get agents.defaults.model"
#
# Stdin/stdout passam pelo wrapper sem alteração.

set -euo pipefail

CMD="${*:-}"
if [ -z "$CMD" ]; then
  echo "uso: $0 \"<subcomando openclaw>\"" >&2
  exit 1
fi

: "${OC_MODE:?defina OC_MODE (use: eval \"\$(oc-target-detect.sh)\")}"

case "$OC_MODE" in
  local-native)
    eval "openclaw $CMD"
    ;;
  ssh-native)
    : "${OC_HOST:?OC_HOST vazio}"
    ssh "$OC_HOST" "openclaw $CMD"
    ;;
  local-docker)
    : "${OC_CONTAINER:?OC_CONTAINER vazio}"
    eval "docker exec $OC_CONTAINER openclaw $CMD"
    ;;
  ssh-docker)
    : "${OC_HOST:?OC_HOST vazio}"
    : "${OC_CONTAINER:?OC_CONTAINER vazio}"
    ssh "$OC_HOST" "docker exec $OC_CONTAINER openclaw $CMD"
    ;;
  *)
    echo "OC_MODE inválido: $OC_MODE" >&2
    exit 2
    ;;
esac
