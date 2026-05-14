# 11 — Mídia / Áudio

## 11.1. Descobertas-chave

- **Não existe plugin "whisper" isolado** — capability já vem dentro do plugin `openai`.
- O plugin `openai` declara `realtime-transcription: openai` automaticamente quando há `OPENAI_API_KEY`.
- O plugin `google` declara `media-understanding: google` — **Gemini 2.5 Flash entende áudio nativamente** (sem etapa separada de transcrição).
- Plugin `deepgram` também existe (sem chave configurada por padrão).
- `audio.transcription.command` no schema é para Whisper LOCAL (ex: whisper.cpp via CLI) — self-hosted, zero custo de API.

## 11.2. Custos comparados

| Opção | Provider | Custo aprox. |
|---|---|---|
| A | OpenAI Whisper API | ~US$ 0,006/min |
| B | Gemini 2.5 Flash (nativo) | ~US$ 0,00014/min (~40× mais barato) |
| C | whisper.cpp local | US$ 0/min, paga em CPU |

## 11.3. Snippet recomendado (Gemini primário, Whisper fallback)

`snippets/media-audio-gemini.json`:

```json
{
  "tools": {
    "media": {
      "audio": { "echoTranscript": false },
      "models": [
        { "provider": "google", "model": "gemini-2.5-flash", "capabilities": ["audio"], "type": "provider" },
        { "provider": "openai", "model": "whisper-1",        "capabilities": ["audio"], "type": "provider" }
      ]
    }
  }
}
```

### `echoTranscript`

| Valor | Comportamento |
|---|---|
| `true` | Bot envia a transcrição como mensagem ANTES da resposta (útil pra debug, ruim pra UX) |
| `false` | Transcrição interna apenas; usuário só vê a resposta final (recomendado) |

## 11.4. Aplicação

```bash
./scripts/oc-backup.sh openclaw.json
./scripts/oc-json-patch.py "$OC_CONFIG_PATH" snippets/media-audio-gemini.json
./scripts/oc-wrap.sh "config validate"
./scripts/oc-reload.sh hot-reload
```

Hot reload — `tools.media.*` aplica sem restart.

Logs esperados:
```
[reload] config change applied (dynamic reads: tools.media.models)
```

## 11.5. Verificação

```bash
./scripts/oc-wrap.sh "config get tools.media"
./scripts/oc-wrap.sh "models status"
```

Teste: enviar um áudio pro bot (Telegram/WhatsApp) e conferir nos logs qual modelo processou.

## 11.6. Whisper local (whisper.cpp) — opção C

Se quiser zerar custo de transcrição:

```bash
ssh $OC_HOST '
  apt install -y build-essential
  git clone https://github.com/ggerganov/whisper.cpp /opt/whisper.cpp
  cd /opt/whisper.cpp && make && bash ./models/download-ggml-model.sh base
'
```

Config:
```json
{
  "tools": {
    "media": {
      "audio": {
        "transcription": {
          "command": "/opt/whisper.cpp/main -m /opt/whisper.cpp/models/ggml-base.bin -f {{file}} -otxt -of /tmp/out && cat /tmp/out.txt"
        }
      }
    }
  }
}
```

⚠️ Em docker compose, mapear o binário do whisper.cpp dentro do container OU rodar como sidecar.

## 11.7. Pegadinhas

- Ordem dos `models[]` IMPORTA — primeiro tenta o primeiro, cai pra próximo se erro.
- `provider` em minúsculo (`"google"`, `"openai"`), `model` em minúsculo também (`"gemini-2.5-flash"`, `"whisper-1"`).
- `capabilities: ["audio"]` é obrigatório — sem isso, o gateway não escolhe esse modelo para áudio.
- Se mudar de provider e o anterior não tiver chave, o gateway pula silenciosamente — confira `models status`.
