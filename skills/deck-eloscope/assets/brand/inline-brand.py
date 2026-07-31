#!/usr/bin/env python3
"""Inline brand PNGs (and any other local image) as base64 data URIs.

Necessário antes de publicar como artifact — a CSP bloqueia qualquer host
externo E qualquer arquivo relativo. Para abrir só no browser local, pule isto:
os src="brand/*.png" relativos funcionam direto.

Uso:  python3 inline-brand.py deck.html [saida.html]
      (sem saida.html, escreve deck.artifact.html ao lado)
"""
import base64
import mimetypes
import pathlib
import re
import sys

if len(sys.argv) < 2:
    sys.exit(__doc__)

src = pathlib.Path(sys.argv[1]).resolve()
dst = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else src.with_suffix('.artifact.html')
html = src.read_text(encoding='utf-8')
missing = []


def repl(m):
    ref = m.group(2)
    if ref.startswith(('data:', 'http://', 'https://')):
        return m.group(0)
    path = (src.parent / ref).resolve()
    if not path.is_file():
        missing.append(ref)
        return m.group(0)
    mime = mimetypes.guess_type(path.name)[0] or 'application/octet-stream'
    b64 = base64.b64encode(path.read_bytes()).decode()
    return f'{m.group(1)}="data:{mime};base64,{b64}"'


html = re.sub(r'\b(src|href)="([^"]+\.(?:png|jpg|jpeg|gif|webp|svg))"', repl, html)

# fonts.css é @import relativo — a CSP também bloqueia; inline o conteúdo
fonts = src.parent / 'fonts.css'
if '@import url("fonts.css")' in html and fonts.is_file():
    html = html.replace('@import url("fonts.css");', fonts.read_text(encoding='utf-8'))

dst.write_text(html, encoding='utf-8')
print(f'{dst}  ({dst.stat().st_size / 1_048_576:.1f} MB)')
if missing:
    print('NÃO encontrados (deixados como estavam):', *missing, sep='\n  ')
