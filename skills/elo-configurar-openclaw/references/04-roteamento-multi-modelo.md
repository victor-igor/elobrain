# 04 — Roteamento multi-modelo

> Estratégia: usar modelos diferentes para tipos de conteúdo diferentes (texto, imagem, PDF, subagents) e cair em fallback APENAS em falha. Não é roteamento por complexidade.

## 4.1. Pré-requisito

Mais de um provider configurado (`OPENAI_API_KEY` + `GEMINI_API_KEY` no mínimo). Sem isso, o provider secundário não é registrado no boot e os fallbacks ficam órfãos.

## 4.2. Estratégia recomendada (por tipo de conteúdo)

- **Texto padrão →** `ChatGPT 4.1` (≈ 10× mais barato que 5.4)
- **Imagem (input) →** `Gemini 2.5 Flash`
- **PDF →** `ChatGPT 4.1`
- **Subagents →** `ChatGPT 4.1` com `thinking: off`
- **Fallback chain global:** OpenAI ↔ Gemini

## 4.3. Snippet (deep-merge no openclaw.json)

Use `snippets/routing-multi-modelo.json`. Conteúdo:

```json
{
  "agents": {
    "list": [
      { "id": "main", "name": "main", "model": "openai/gpt-4.1" }
    ],
    "defaults": {
      "model": {
        "primary": "ChatGPT 4.1",
        "fallbacks": ["ChatGPT 5.2", "Gemini 2.5 Flash"]
      },
      "imageModel": {
        "primary": "Gemini 2.5 Flash",
        "fallbacks": ["ChatGPT 4.1"]
      },
      "pdfModel": {
        "primary": "ChatGPT 4.1",
        "fallbacks": ["Gemini 2.5 Flash"]
      },
      "subagents": {
        "model": {
          "primary": "ChatGPT 4.1",
          "fallbacks": ["Gemini 2.5 Flash"]
        },
        "thinking": "off",
        "maxConcurrent": 2,
        "maxChildrenPerAgent": 5,
        "maxSpawnDepth": 1
      },
      "thinkingDefault": "low"
    }
  }
}
```

## 4.4. Aplicação

```bash
./scripts/oc-backup.sh openclaw.json
./scripts/oc-json-patch.py "$OC_CONFIG_PATH" snippets/routing-multi-modelo.json
./scripts/oc-wrap.sh "config validate"
./scripts/oc-reload.sh hot-reload
./scripts/oc-wrap.sh "models status"
```

(Hot reload — só pede `recreate` se você adicionou nova API key no `.env` ao mesmo tempo.)

## 4.5. Estratégia 2 — Subagents baratos, principal forte

Quando: a qualidade de GPT-4.1 começou a doer — você quer Opus/5.4 no canal direto, mas as delegações vão ficar muito caras.

```json
{
  "agents": {
    "defaults": {
      "model":     { "primary": "ChatGPT 5.4", "fallbacks": ["ChatGPT 4.1", "Gemini 2.5 Flash"] },
      "subagents": {
        "model":   { "primary": "ChatGPT 4.1", "fallbacks": ["Gemini 2.5 Flash"] },
        "thinking": "off"
      }
    }
  }
}
```

## 4.6. Estratégia 3 — Múltiplos agentes por canal

Quando: WhatsApp do cliente deve ser leve/seguro; Telegram da equipe deve ser potente.

```bash
# Criar agentes
./scripts/oc-wrap.sh "agents add whatsapp-light --model openai/gpt-4o-mini"
./scripts/oc-wrap.sh "agents add webchat-heavy  --model openai/gpt-5.4"

# Bind a canais
./scripts/oc-wrap.sh "agents bind --agent whatsapp-light --bind whatsapp"
./scripts/oc-wrap.sh "agents bind --agent webchat-heavy  --bind webchat"
```

## 4.7. Verificação

```bash
./scripts/oc-wrap.sh "models status"
./scripts/oc-wrap.sh "config get agents.defaults.model"
./scripts/oc-wrap.sh "config get agents.defaults.imageModel"
./scripts/oc-wrap.sh "config get agents.defaults.pdfModel"
./scripts/oc-wrap.sh "config get agents.defaults.subagents.model"
```

## 4.8. Pegadinhas

- Ordene fallbacks **realisticamente.** Cair pra OpenAI → OpenAI não te protege contra falha sistêmica do provider.
- `agents.list[*].model` usa formato `provider/modelo` (ex: `openai/gpt-4.1`); `agents.defaults.model.primary` usa o nome humano (ex: `ChatGPT 4.1`). É confuso mas correto.
- Se o gateway recusar a chave humana (`Unknown model: ChatGPT 4.1`), confira no `models list --all` o nome exato esperado.
