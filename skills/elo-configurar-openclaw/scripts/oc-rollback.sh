#!/usr/bin/env bash
# oc-rollback.sh — reverte openclaw.json ou .env para o backup mais recente.
#
# Uso:
#   ./oc-rollback.sh openclaw.json
#   ./oc-rollback.sh env
#
# Requer:
#   OC_MODE, OC_HOST, OC_CONFIG_PATH, OC_ENV_PATH

set -euo pipefail

WHAT="${1:?uso: $0 [openclaw.json|env]}"

: "${OC_MODE:?defina OC_MODE}"

run_remote() {
  if [[ "$OC_MODE" == ssh-* ]]; then
    : "${OC_HOST:?OC_HOST vazio}"
    ssh "$OC_HOST" "$@"
  else
    eval "$@"
  fi
}

case "$WHAT" in
  openclaw.json|json)
    : "${OC_CONFIG_PATH:?OC_CONFIG_PATH vazio}"
    SRC="$OC_CONFIG_PATH"
    ;;
  env|.env)
    : "${OC_ENV_PATH:?OC_ENV_PATH vazio}"
    SRC="$OC_ENV_PATH"
    ;;
  *)
    echo "uso: $0 [openclaw.json|env]" >&2; exit 1 ;;
esac

LATEST=$(run_remote "ls -1t '${SRC}'.bak-* 2>/dev/null | head -1")
if [ -z "$LATEST" ]; then
  echo "ERRO: nenhum backup encontrado para $SRC" >&2
  exit 2
fi

echo "Vou restaurar:"
echo "  $LATEST → $SRC"
read -r -p "Confirmar? [y/N] " ANS
if [[ "$ANS" != "y" && "$ANS" != "Y" ]]; then
  echo "Cancelado."
  exit 0
fi

run_remote "cp -p '$LATEST' '$SRC'"
echo "OK: rollback aplicado."
echo "Próximo passo: ./oc-reload.sh recreate (docker) | systemd-restart (native)"
