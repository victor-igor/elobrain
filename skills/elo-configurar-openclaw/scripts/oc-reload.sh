#!/usr/bin/env bash
# oc-reload.sh — aplica a mudança da forma certa para cada tipo.
#
# Uso:
#   ./oc-reload.sh hot-reload       # apenas espera 3s e checa logs
#   ./oc-reload.sh restart          # gateway restart via CLI
#   ./oc-reload.sh recreate         # docker compose up -d --force-recreate openclaw
#   ./oc-reload.sh systemd-restart  # native: daemon-reload + restart openclaw
#
# Requer:
#   OC_MODE, OC_HOST, OC_CONTAINER (docker), OC_COMPOSE_DIR (docker)

set -euo pipefail

KIND="${1:?uso: $0 [hot-reload|restart|recreate|systemd-restart]}"

: "${OC_MODE:?defina OC_MODE}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OC_WRAP="$SCRIPT_DIR/oc-wrap.sh"

run_remote() {
  if [[ "$OC_MODE" == ssh-* ]]; then
    : "${OC_HOST:?OC_HOST vazio}"
    ssh "$OC_HOST" "$@"
  else
    eval "$@"
  fi
}

check_logs() {
  local LINES=200
  echo "Checando logs (últimas $LINES linhas para reload/error)..."
  case "$OC_MODE" in
    *-docker)
      : "${OC_CONTAINER:?OC_CONTAINER vazio}"
      run_remote "docker logs $OC_CONTAINER --tail $LINES 2>&1 | grep -iE 'reload|error|fatal|loaded' | tail -20" || true
      ;;
    *-native)
      run_remote "journalctl -u openclaw -n $LINES --no-pager 2>&1 | grep -iE 'reload|error|fatal|loaded' | tail -20" || true
      ;;
  esac
}

case "$KIND" in
  hot-reload)
    sleep 3
    check_logs
    ;;
  restart)
    "$OC_WRAP" "gateway restart"
    sleep 5
    check_logs
    ;;
  recreate)
    case "$OC_MODE" in
      *-docker)
        : "${OC_COMPOSE_DIR:?OC_COMPOSE_DIR vazio}"
        run_remote "cd '$OC_COMPOSE_DIR' && docker compose up -d --force-recreate openclaw"
        echo "Aguardando container saudável..."
        sleep 8
        check_logs
        ;;
      *)
        echo "ERRO: 'recreate' só vale em modo docker. Use 'systemd-restart' para native." >&2
        exit 2
        ;;
    esac
    ;;
  systemd-restart)
    case "$OC_MODE" in
      *-native)
        run_remote "sudo systemctl daemon-reload && sudo systemctl restart openclaw && sleep 3 && systemctl is-active openclaw"
        check_logs
        ;;
      *)
        echo "ERRO: 'systemd-restart' só vale em modo native. Use 'recreate' para docker." >&2
        exit 2
        ;;
    esac
    ;;
  *)
    echo "uso: $0 [hot-reload|restart|recreate|systemd-restart]" >&2
    exit 1
    ;;
esac

echo "OK: $KIND aplicado."
