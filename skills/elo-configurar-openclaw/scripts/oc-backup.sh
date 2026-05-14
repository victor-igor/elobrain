#!/usr/bin/env bash
# oc-backup.sh — gera backup datado de openclaw.json ou .env.
#
# Requer:
#   OC_MODE, OC_HOST, OC_CONFIG_PATH, OC_ENV_PATH
#
# Uso:
#   ./oc-backup.sh openclaw.json     # backup do JSON
#   ./oc-backup.sh env               # backup do .env
#   ./oc-backup.sh both              # backup dos dois
#
# Saída: imprime o(s) caminho(s) do backup gerado.

set -euo pipefail

WHAT="${1:-openclaw.json}"
TS=$(date +%Y%m%d-%H%M%S)
: "${OC_MODE:?defina OC_MODE}"

# Função: roda local ou via ssh
run_remote() {
  if [[ "$OC_MODE" == ssh-* ]]; then
    : "${OC_HOST:?OC_HOST vazio}"
    ssh "$OC_HOST" "$@"
  else
    eval "$@"
  fi
}

backup_one() {
  local SRC="$1"
  local DST="$1.bak-$TS"
  if [ -z "$SRC" ]; then
    echo "ERRO: caminho vazio." >&2
    return 1
  fi
  run_remote "test -f '$SRC' && cp -p '$SRC' '$DST' && echo '$DST'"
}

case "$WHAT" in
  openclaw.json|json|cfg|config)
    : "${OC_CONFIG_PATH:?OC_CONFIG_PATH vazio}"
    backup_one "$OC_CONFIG_PATH"
    ;;
  env|.env)
    : "${OC_ENV_PATH:?OC_ENV_PATH vazio}"
    backup_one "$OC_ENV_PATH"
    ;;
  both)
    : "${OC_CONFIG_PATH:?OC_CONFIG_PATH vazio}"
    : "${OC_ENV_PATH:?OC_ENV_PATH vazio}"
    backup_one "$OC_CONFIG_PATH"
    backup_one "$OC_ENV_PATH"
    ;;
  *)
    echo "uso: $0 [openclaw.json|env|both]" >&2
    exit 1
    ;;
esac
