# 13 — Diagnóstico, validação e logs

## 13.1. Validação de config

```bash
./scripts/oc-wrap.sh "config validate"
```

Saída boa: `✅ Configuration valid — 0 warnings`.
Saída ruim: traz `path` exato + regra violada (use isso pra corrigir o JSON).

> **Sempre rodar antes de qualquer recreate/restart com mudanças grandes.**

## 13.2. Status geral

```bash
./scripts/oc-wrap.sh "gateway status"     # running / stopped / error
./scripts/oc-wrap.sh "models status"      # provider × modelo × status
./scripts/oc-wrap.sh "models list --all"  # catálogo completo (todos os providers)
./scripts/oc-wrap.sh "plugins list"       # plugins disponíveis × habilitados
./scripts/oc-wrap.sh "skills list -v"     # skills com source e status
./scripts/oc-wrap.sh "channels status --probe"  # canais ativos com healthcheck
./scripts/oc-wrap.sh "memory status"      # índice + dreaming + embeddings
```

## 13.3. Inspeção pontual

```bash
./scripts/oc-wrap.sh "config get <path.dot.notation>"
./scripts/oc-wrap.sh "plugins inspect <id>"
./scripts/oc-wrap.sh "skills info <id>"
```

Exemplos comuns:
```bash
./scripts/oc-wrap.sh "config get agents.defaults.model"
./scripts/oc-wrap.sh "config get agents.defaults.heartbeat"
./scripts/oc-wrap.sh "config get tools.media"
./scripts/oc-wrap.sh "config get plugins.entries.firecrawl"
./scripts/oc-wrap.sh "plugins inspect active-memory"
./scripts/oc-wrap.sh "skills info scrapecreators"
```

## 13.4. Schema (gigante — só pra desenvolvimento)

```bash
./scripts/oc-wrap.sh "config schema" | python3 -c '
import json, sys
s = json.load(sys.stdin)
# navegar como dicionário
print(list(s.keys())[:20])
'
```

## 13.5. Logs ao vivo

### Docker
```bash
$PFX docker logs $OC_CONTAINER -f
$PFX docker logs $OC_CONTAINER --tail 100
```

### Native (systemd)
```bash
$PFX journalctl -u openclaw -f
$PFX journalctl -u openclaw -n 100 --no-pager
```

### Filtrar por tópico
```bash
$PFX docker logs $OC_CONTAINER --tail 200 | grep -iE 'reload|model|plugin|skill|error'
```

Tópicos comuns:
- `reload` — hot reload aplicado
- `model` — adição/seleção de modelo
- `plugin` — habilitar/carregar plugin
- `skill` — descoberta/registro de skill
- `error` — qualquer erro

## 13.6. Rotinas de saúde

```bash
# 1. Validar config
./scripts/oc-wrap.sh "config validate"

# 2. Gateway up?
./scripts/oc-wrap.sh "gateway status"

# 3. Providers respondendo?
./scripts/oc-wrap.sh "models status"

# 4. Canais conectados?
./scripts/oc-wrap.sh "channels status --probe"

# 5. Memória indexando?
./scripts/oc-wrap.sh "memory status"

# 6. Sem erros recentes?
$PFX docker logs $OC_CONTAINER --since 1h | grep -iE 'error|fatal' | head -50
```

Se algum item falhar — não continuar até resolver.

## 13.7. Painel web

```bash
./scripts/oc-wrap.sh "dashboard"
# Acesso local: http://127.0.0.1:18789
# Acesso remoto: via Cloudflare Tunnel (ver references/05-seguranca.md §5.4)
```

## 13.8. Limpeza / reset

> 🔴 Destrutivo. Pedir confirmação SEMPRE antes.

```bash
./scripts/oc-wrap.sh "memory clear"           # apaga índice (não os arquivos)
./scripts/oc-wrap.sh "channels logout <id>"   # desconecta canal
./scripts/oc-wrap.sh "plugins disable <id>"
```

## 13.9. Relatório padrão pós-mudança

Sempre que aplicar mudança, gerar este resumo pro user:

```
✅ Mudança aplicada
   Arquivos editados: <lista>
   Backup em:         <path>.bak-YYYYMMDD-HHMMSS
   Tipo de reload:    hot-reload | restart | recreate
   Validação:         OK
   Estado pós-mudança:
     - models status: ✓
     - plugins:        ✓ (X habilitados)
     - canais:         ✓
     - memória:        ✓ (N arquivos, M chunks)
   
   Próximo passo sugerido: <ação>
```
