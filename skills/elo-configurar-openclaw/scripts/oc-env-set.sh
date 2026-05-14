#!/usr/bin/env bash
# oc-env-set.sh — set/update KEY=VALUE no .env do compose (modo docker)
# ou no override systemd (modo native).
#
# Uso:
#   ./oc-env-set.sh OPENAI_API_KEY 'sk-...'
#   ./oc-env-set.sh GEMINI_API_KEY 'AIza...'
#
# Requer:
#   OC_MODE, OC_HOST, OC_ENV_PATH

set -euo pipefail

KEY="${1:?uso: $0 KEY VALUE}"
VALUE="${2:?uso: $0 KEY VALUE}"

: "${OC_MODE:?defina OC_MODE}"
: "${OC_ENV_PATH:?defina OC_ENV_PATH}"

# Função: rodar local ou via SSH
run_remote() {
  if [[ "$OC_MODE" == ssh-* ]]; then
    : "${OC_HOST:?OC_HOST vazio}"
    ssh "$OC_HOST" "$@"
  else
    eval "$@"
  fi
}

# Mascarar valor pra log (mostra só primeiros e últimos 4 chars)
mask() {
  local v="$1"
  local n=${#v}
  if (( n <= 8 )); then echo "***"; return; fi
  echo "${v:0:4}…${v: -4}"
}

case "$OC_MODE" in
  *-docker)
    # Edição do .env (formato KEY=VALUE em linha simples)
    SCRIPT=$(cat <<EOF
set -e
ENV_FILE="$OC_ENV_PATH"
KEY="$KEY"
VALUE='$VALUE'
[ -f "\$ENV_FILE" ] || touch "\$ENV_FILE"
# remove existente
grep -v "^\${KEY}=" "\$ENV_FILE" > "\${ENV_FILE}.tmp" || true
echo "\${KEY}=\${VALUE}" >> "\${ENV_FILE}.tmp"
mv "\${ENV_FILE}.tmp" "\$ENV_FILE"
EOF
)
    run_remote "$SCRIPT"
    ;;
  *-native)
    # systemd override: precisa sudo + Environment="KEY=VALUE"
    SCRIPT=$(cat <<EOF
set -e
OVR_DIR="/etc/systemd/system/openclaw.service.d"
OVR_FILE="\$OVR_DIR/override.conf"
sudo mkdir -p "\$OVR_DIR"
sudo touch "\$OVR_FILE"
# remove linha existente
sudo sed -i '/^Environment="$KEY=/d' "\$OVR_FILE"
# garantir [Service]
grep -q "^\[Service\]" "\$OVR_FILE" || echo "[Service]" | sudo tee -a "\$OVR_FILE" >/dev/null
echo 'Environment="$KEY=$VALUE"' | sudo tee -a "\$OVR_FILE" >/dev/null
EOF
)
    run_remote "$SCRIPT"
    ;;
  *)
    echo "OC_MODE inválido: $OC_MODE" >&2; exit 2 ;;
esac

echo "OK: $KEY=$(mask "$VALUE") gravado em $OC_ENV_PATH (modo $OC_MODE)"
echo "Aplicar: ./oc-reload.sh recreate         # docker"
echo "         ./oc-reload.sh systemd-restart  # native"
