# 05 — Segurança

> Ordem importa. Faça nesta sequência. Pular passos = ficar exposto.

## 5.1. Allowlist de canais ANTES de qualquer coisa

> 🔴 PRIMEIRO. UFW não protege Telegram (conexão de SAÍDA).

### Telegram (`dmPolicy: "allowlist"`)

```bash
# Descobrir o ID do user (mandar mensagem ao bot e olhar logs):
./scripts/oc-wrap.sh "gateway logs" | grep -iE 'from_id|chat_id'
```

Snippet: `snippets/telegram-allowlist.json`. Substitua `<SEU_TELEGRAM_ID>`:

```json
{
  "plugins": {
    "entries": {
      "telegram": {
        "config": {
          "dmPolicy": "allowlist",
          "allowlist": [<SEU_TELEGRAM_ID>]
        }
      }
    }
  }
}
```

```bash
./scripts/oc-json-patch.py "$OC_CONFIG_PATH" snippets/telegram-allowlist.json
./scripts/oc-wrap.sh "config validate"
./scripts/oc-reload.sh restart
```

### WhatsApp (mais crítico — exposto a spam)

`snippets/whatsapp-allowlist.json`:
```json
{
  "plugins": {
    "entries": {
      "whatsapp": {
        "config": {
          "dmPolicy": "allowlist",
          "allowlist": ["+5511999999999"],
          "debounceMs": 4000
        }
      }
    }
  }
}
```

> `debounceMs: 3000-5000` evita disparar 1 LLM call por mensagem rápida — agrupa.

## 5.2. UFW (firewall — só native VPS)

```bash
ssh $OC_HOST '
  sudo apt install -y ufw
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow ssh
  sudo ufw --force enable
  sudo ufw status
'
```

> ⚠️ **NÃO ative UFW antes de garantir que SSH key funciona.** Senha SSH + UFW + chave inválida = preso fora.

## 5.3. fail2ban

```bash
ssh $OC_HOST '
  sudo apt install -y fail2ban
  sudo tee /etc/fail2ban/jail.local >/dev/null <<EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
findtime = 600
EOF
  sudo systemctl enable fail2ban
  sudo systemctl restart fail2ban
  sudo fail2ban-client status sshd
'
```

## 5.4. Cloudflare Tunnel (acesso remoto ao painel)

> ≥ v2026.3.2: WebSocket do painel é loopback-only (`127.0.0.1`). Sem tunnel não dá pra acessar Mission Control de fora.

```bash
ssh $OC_HOST '
  curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cloudflared.deb
  sudo dpkg -i /tmp/cloudflared.deb
  cloudflared tunnel login        # interativo
  cloudflared tunnel create meu-tunnel
'
```

Editar `~/.cloudflared/config.yml`:
```yaml
tunnel: meu-tunnel
credentials-file: /root/.cloudflared/<TUNNEL_ID>.json
ingress:
  - hostname: painel.meudominio.com
    service: http://127.0.0.1:18789
  - service: http_status:404
```

```bash
ssh $OC_HOST '
  sudo cloudflared service install
  sudo systemctl enable cloudflared
  sudo systemctl start cloudflared
'
```

## 5.5. SSH hardening

```bash
ssh $OC_HOST 'grep "PermitRootLogin" /etc/ssh/sshd_config'
# Ideal: PermitRootLogin prohibit-password
```

Se ainda permite senha:
```bash
ssh $OC_HOST '
  sudo sed -i "s/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/" /etc/ssh/sshd_config
  sudo sed -i "s/^#*PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config
  sudo systemctl restart sshd
'
```

⚠️ Confirme que sua chave funciona ANTES (`ssh -o BatchMode=yes $OC_HOST true`).

## 5.6. Portas em 127.0.0.1 (não 0.0.0.0)

Para qualquer app web extra (Mission Control, dashboards), garanta binding em `127.0.0.1`. Tunnel acima dá o acesso externo.

## 5.7. `openclaw secrets` (≥ v2026.3.2)

A CVE de fev/2026 explorou API keys hardcoded em config. Use `secrets` — não edite `.env` cru.

```bash
# Audit (encontrar chaves expostas)
./scripts/oc-wrap.sh "secrets audit"

# Migrar pro cofre criptografado
./scripts/oc-wrap.sh "secrets apply"

# Audit de novo — esperado: zero
./scripts/oc-wrap.sh "secrets audit"

# Setar/rotacionar
./scripts/oc-wrap.sh "secrets set ANTHROPIC_API_KEY=sk-ant-nova-chave"
```

## 5.8. Sync systemd ↔ secrets (armadilha)

systemd override tem prioridade sobre secrets. Se trocar só o secret e o override tiver valor antigo, continua usando o antigo.

```bash
ssh $OC_HOST '
  sudo systemctl edit openclaw     # editar override e remover ou atualizar a chave
  sudo systemctl daemon-reload
  sudo systemctl restart openclaw
'
```

## 5.9. Manter atualizado

```bash
# native
ssh $OC_HOST 'npm update -g openclaw && openclaw gateway restart && openclaw gateway status'

# docker compose (puxar imagem nova)
ssh $OC_HOST 'cd /docker/openclaw-XXXX && docker compose pull openclaw && docker compose up -d openclaw'
```

## 5.10. Checklist final

- [ ] Telegram dmPolicy = allowlist com IDs corretos
- [ ] WhatsApp dmPolicy = allowlist + debounceMs ≥ 3000
- [ ] UFW ativo (apenas em VPS native)
- [ ] fail2ban ativo
- [ ] Cloudflare Tunnel configurado
- [ ] Painel em 127.0.0.1 (não 0.0.0.0)
- [ ] SSH key-only
- [ ] `openclaw secrets audit` retorna 0
- [ ] `openclaw secrets apply` rodou
- [ ] Rotação trimestral agendada (cron próprio)
- [ ] systemd override sincronizado com secrets
