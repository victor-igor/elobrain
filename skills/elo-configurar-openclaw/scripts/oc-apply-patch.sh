#!/usr/bin/env bash
# oc-apply-patch.sh — high-level wrapper que aplica um snippet JSON em $OC_CONFIG_PATH,
# cobrindo os 4 modos. Faz: backup → fetch → patch → push → chown.
#
# Uso:
#   ./oc-apply-patch.sh ../snippets/heartbeat.json
#
# Requer:
#   OC_MODE, OC_HOST, OC_CONFIG_PATH, OC_OWNER

set -euo pipefail

SNIPPET="${1:?uso: $0 <snippet.json>}"
[ -f "$SNIPPET" ] || { echo "Snippet não encontrado: $SNIPPET" >&2; exit 1; }

: "${OC_MODE:?defina OC_MODE}"
: "${OC_CONFIG_PATH:?defina OC_CONFIG_PATH}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYPATCH="$SCRIPT_DIR/oc-json-patch.py"
BACKUP="$SCRIPT_DIR/oc-backup.sh"

# 1. Backup
"$BACKUP" openclaw.json

case "$OC_MODE" in
  local-*)
    # patch direto no path
    python3 "$PYPATCH" "$OC_CONFIG_PATH" "$SNIPPET"
    ;;
  ssh-*)
    : "${OC_HOST:?OC_HOST vazio}"
    TMP_LOCAL="$(mktemp /tmp/openclaw.XXXXXX.json)"
    trap "rm -f $TMP_LOCAL" EXIT

    # 2. fetch
    scp -q "$OC_HOST:$OC_CONFIG_PATH" "$TMP_LOCAL"

    # 3. patch (sem chown local, faremos via ssh depois)
    OC_MODE_ORIG="$OC_MODE"; unset OC_MODE
    python3 "$PYPATCH" "$TMP_LOCAL" "$SNIPPET"
    export OC_MODE="$OC_MODE_ORIG"

    # 4. push
    scp -q "$TMP_LOCAL" "$OC_HOST:$OC_CONFIG_PATH"

    # 5. chown remoto
    if [ -n "${OC_OWNER:-}" ] && [ "$OC_OWNER" != "0:0" ]; then
      ssh "$OC_HOST" "chown $OC_OWNER '$OC_CONFIG_PATH'"
    fi
    ;;
esac

echo "Patch aplicado. Próximo passo: ./oc-wrap.sh \"config validate\" → ./oc-reload.sh <kind>"
