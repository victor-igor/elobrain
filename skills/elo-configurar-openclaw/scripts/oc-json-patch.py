#!/usr/bin/env python3
"""
oc-json-patch.py — Deep-merge de um snippet JSON dentro do openclaw.json.

Uso:
  ./oc-json-patch.py /path/to/openclaw.json snippets/heartbeat.json
  cat snippet.json | ./oc-json-patch.py /path/to/openclaw.json -

Comportamento:
  - Carrega o JSON original.
  - Deep-merge: dict mescla recursivo, tudo mais (lista/escalar) substitui.
  - Remove chaves cujo nome começa com `_` (ex: `_comment`) do snippet antes do merge.
  - Escreve em <arquivo>.tmp e renomeia atomicamente.
  - Reaplica owner usando $OC_OWNER (ex: 1000:1000), se a variável estiver presente
    e estivermos rodando em local-* (em ssh-* o caller deve aplicar via SSH).

Em ssh-*: este script roda LOCALMENTE editando uma cópia que você precisa ter
sincronizado primeiro (ou rodar este script via ssh).

A forma idiomática de uso em ssh-docker é:
  scp $OC_HOST:$OC_CONFIG_PATH /tmp/openclaw.json
  ./oc-json-patch.py /tmp/openclaw.json snippets/heartbeat.json
  scp /tmp/openclaw.json $OC_HOST:$OC_CONFIG_PATH
  ssh $OC_HOST "chown $OC_OWNER $OC_CONFIG_PATH"

Ou, mais simples, rodar via `ssh $OC_HOST python3 - < script.py + args` — não
implementado aqui pra manter o script trivial.
"""
from __future__ import annotations
import json
import os
import sys
from pathlib import Path
from typing import Any


def deep_merge(base: Any, patch: Any) -> Any:
    """Merge `patch` into `base`. Dicts merge recursively; everything else replaces."""
    if isinstance(base, dict) and isinstance(patch, dict):
        out = dict(base)
        for k, v in patch.items():
            if k.startswith("_"):  # skip _comment etc.
                continue
            if k in out:
                out[k] = deep_merge(out[k], v)
            else:
                out[k] = strip_underscored(v)
        return out
    return strip_underscored(patch)


def strip_underscored(obj: Any) -> Any:
    """Recursivamente remove chaves que começam com `_`."""
    if isinstance(obj, dict):
        return {k: strip_underscored(v) for k, v in obj.items() if not k.startswith("_")}
    if isinstance(obj, list):
        return [strip_underscored(x) for x in obj]
    return obj


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 1

    cfg_path = Path(sys.argv[1]).resolve()
    snippet_arg = sys.argv[2]

    # Validar que cfg_path não escapa do diretório de trabalho
    cwd = Path.cwd().resolve()
    try:
        cfg_path.relative_to(cwd)
    except ValueError:
        print(f"ERRO: {cfg_path} está fora do diretório de trabalho.", file=sys.stderr)
        return 6

    if not cfg_path.exists():
        print(f"ERRO: {cfg_path} não existe.", file=sys.stderr)
        return 2

    # Carrega snippet
    if snippet_arg == "-":
        snippet_data = sys.stdin.read()
    else:
        snippet_path = Path(snippet_arg).resolve()
        try:
            snippet_path.relative_to(cwd)
        except ValueError:
            print(f"ERRO: {snippet_path} está fora do diretório de trabalho.", file=sys.stderr)
            return 6
        snippet_data = snippet_path.read_text(encoding="utf-8")

    try:
        snippet = json.loads(snippet_data)
    except json.JSONDecodeError as e:
        print(f"ERRO: snippet JSON inválido: {e}", file=sys.stderr)
        return 3

    # Carrega base
    try:
        base = json.loads(cfg_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        print(f"ERRO: openclaw.json inválido: {e}", file=sys.stderr)
        print("DICA: rode oc-rollback.sh openclaw.json para reverter.", file=sys.stderr)
        return 4

    # Merge
    merged = deep_merge(base, snippet)

    # Escrever atomicamente
    tmp = cfg_path.with_suffix(cfg_path.suffix + ".tmp")
    tmp.write_text(json.dumps(merged, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    # Validar JSON sintático
    try:
        json.loads(tmp.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        print(f"ERRO interno: tmp inválido: {e}", file=sys.stderr)
        tmp.unlink()
        return 5

    os.replace(tmp, cfg_path)

    # Reaplicar owner se OC_OWNER e modo local-*
    owner = os.environ.get("OC_OWNER", "")
    mode = os.environ.get("OC_MODE", "")
    if owner and mode.startswith("local-") and owner != "0:0":
        try:
            uid_str, gid_str = owner.split(":", 1)
            os.chown(cfg_path, int(uid_str), int(gid_str))
        except Exception as e:
            print(f"AVISO: não consegui reaplicar owner {owner}: {e}", file=sys.stderr)

    print(f"OK: patch aplicado em {cfg_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
