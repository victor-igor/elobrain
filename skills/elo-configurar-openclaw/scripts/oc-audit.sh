#!/usr/bin/env bash
# oc-audit.sh — coleta snapshot READ-ONLY do estado da instância OpenClaw.
# Saída é um único arquivo de texto que o Claude lê + cruza com
# references/16-audit-melhorias.md pra propor melhorias categorizadas.
#
# Uso:
#   ./oc-audit.sh                # imprime no stdout
#   ./oc-audit.sh /tmp/audit.txt # grava em arquivo
#
# Requer:
#   OC_MODE, OC_HOST, OC_CONTAINER, OC_CONFIG_PATH, OC_ENV_PATH

set -euo pipefail

OUT="${1:-/dev/stdout}"
[ "$OUT" != "/dev/stdout" ] && exec > "$OUT"

: "${OC_MODE:?defina OC_MODE (eval \"\$(oc-target-detect.sh ...)\")}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAP="$SCRIPT_DIR/oc-wrap.sh"

# Função: rodar local ou via SSH
run_remote() {
  if [[ "$OC_MODE" == ssh-* ]]; then
    : "${OC_HOST:?OC_HOST vazio}"
    ssh -o BatchMode=yes "$OC_HOST" "$@" 2>&1 || true
  else
    eval "$@" 2>&1 || true
  fi
}

# Wrap CLI sem falhar
wrap_or_skip() {
  "$WRAP" "$1" 2>&1 || echo "<command failed: $1>"
}

# Header
echo "=== AUDIT SNAPSHOT — $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
echo

# 1. Target
echo "=== TARGET ==="
echo "OC_MODE=$OC_MODE"
echo "OC_HOST=${OC_HOST:-}"
echo "OC_CONTAINER=${OC_CONTAINER:-}"
echo "OC_COMPOSE_DIR=${OC_COMPOSE_DIR:-}"
echo "OC_CONFIG_PATH=${OC_CONFIG_PATH:-}"
echo "OC_ENV_PATH=${OC_ENV_PATH:-}"
echo "OC_OWNER=${OC_OWNER:-}"
echo

# 2. Versão do gateway
echo "=== VERSION ==="
wrap_or_skip "--version"
echo

# 3. Gateway status
echo "=== GATEWAY STATUS ==="
wrap_or_skip "gateway status"
echo

# 4. Config validate
echo "=== CONFIG VALIDATE ==="
wrap_or_skip "config validate"
echo

# 5. Modelos
echo "=== MODELS STATUS ==="
wrap_or_skip "models status"
echo
echo "=== MODELS LIST (primeiros 30) ==="
wrap_or_skip "models list --all" | head -50
echo

# 6. Plugins
echo "=== PLUGINS LIST ==="
wrap_or_skip "plugins list"
echo

# 7. Skills
echo "=== SKILLS LIST -v ==="
wrap_or_skip "skills list -v"
echo

# 8. Canais
echo "=== CHANNELS STATUS --probe ==="
wrap_or_skip "channels status --probe"
echo

# 9. Memória
echo "=== MEMORY STATUS ==="
wrap_or_skip "memory status"
echo

# 10. Secrets audit
echo "=== SECRETS AUDIT ==="
wrap_or_skip "secrets audit"
echo

# 11. Crons
echo "=== CRONS LIST ==="
wrap_or_skip "crons list"
echo

# 12. Config: trechos relevantes
echo "=== CONFIG: tools.profile ==="
wrap_or_skip "config get tools.profile"
echo
echo "=== CONFIG: agents.defaults.model ==="
wrap_or_skip "config get agents.defaults.model"
echo
echo "=== CONFIG: agents.defaults.imageModel ==="
wrap_or_skip "config get agents.defaults.imageModel"
echo
echo "=== CONFIG: agents.defaults.pdfModel ==="
wrap_or_skip "config get agents.defaults.pdfModel"
echo
echo "=== CONFIG: agents.defaults.subagents ==="
wrap_or_skip "config get agents.defaults.subagents"
echo
echo "=== CONFIG: agents.defaults.thinkingDefault ==="
wrap_or_skip "config get agents.defaults.thinkingDefault"
echo
echo "=== CONFIG: agents.defaults.heartbeat ==="
wrap_or_skip "config get agents.defaults.heartbeat"
echo
echo "=== CONFIG: agents.defaults.compaction ==="
wrap_or_skip "config get agents.defaults.compaction"
echo
echo "=== CONFIG: agents.defaults.contextTokens ==="
wrap_or_skip "config get agents.defaults.contextTokens"
echo
echo "=== CONFIG: tools.media ==="
wrap_or_skip "config get tools.media"
echo
echo "=== CONFIG: plugins.entries (chaves) ==="
wrap_or_skip "config get plugins.entries"
echo
echo "=== CONFIG: skills.load ==="
wrap_or_skip "config get skills.load"
echo

# 13. Workspace files presence
echo "=== WORKSPACE FILES ==="
case "$OC_MODE" in
  *-docker)
    : "${OC_COMPOSE_DIR:?}"
    WS="$OC_COMPOSE_DIR/data/.openclaw/workspace"
    ;;
  *-native)
    WS="\$HOME/.openclaw/workspace"
    ;;
esac
run_remote "ls -la $WS 2>/dev/null | head -30"
echo "--- HEARTBEAT.md size ---"
run_remote "wc -l $WS/HEARTBEAT.md 2>/dev/null"
echo "--- AGENTS.md tem 'Memory Architecture'? ---"
run_remote "grep -c 'Memory Architecture' $WS/AGENTS.md 2>/dev/null || echo 0"
echo "--- AGENTS.md tem 'proativo'? ---"
run_remote "grep -ic 'proativo\\|proactive' $WS/AGENTS.md 2>/dev/null || echo 0"
echo "--- memory/ subdirs ---"
run_remote "ls -la $WS/memory 2>/dev/null"
echo

# 14. .env keys (nomes apenas, sem valores)
echo "=== ENV KEYS (sem valores) ==="
case "$OC_MODE" in
  *-docker)
    : "${OC_ENV_PATH:?}"
    run_remote "grep -oE '^[A-Z_]+=' $OC_ENV_PATH 2>/dev/null | tr -d '='"
    ;;
  *-native)
    run_remote "sudo grep -oE 'Environment=\"[A-Z_]+=' /etc/systemd/system/openclaw.service.d/override.conf 2>/dev/null | sed 's/Environment=\"//;s/=$//'"
    ;;
esac
echo

# 15. UFW / fail2ban (só native VPS)
if [[ "$OC_MODE" == ssh-* ]]; then
  echo "=== UFW STATUS ==="
  run_remote "sudo ufw status 2>/dev/null | head -10"
  echo "=== FAIL2BAN STATUS ==="
  run_remote "sudo fail2ban-client status sshd 2>/dev/null | head -10"
  echo "=== SSH CONFIG (PermitRootLogin / PasswordAuthentication) ==="
  run_remote "grep -E '^(PermitRootLogin|PasswordAuthentication)' /etc/ssh/sshd_config 2>/dev/null"
  echo
fi

# 16. Logs recentes (errors only)
echo "=== ERROS RECENTES (últimos 200 linhas, filtrado) ==="
case "$OC_MODE" in
  *-docker)
    : "${OC_CONTAINER:?}"
    run_remote "docker logs $OC_CONTAINER --tail 200 2>&1 | grep -iE 'error|fatal|denied' | tail -30"
    ;;
  *-native)
    run_remote "journalctl -u openclaw -n 200 --no-pager 2>&1 | grep -iE 'error|fatal|denied' | tail -30"
    ;;
esac
echo

echo "=== END OF AUDIT SNAPSHOT ==="
