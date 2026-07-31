#!/usr/bin/env python3
"""Mede densidade de texto por slide e aponta quem estourou o teto do modo.

Uso:  python3 check-density.py deck.html [--modo apresentado|enviado|hibrido]
      (default: hibrido)

Tetos:
  apresentado  45 palavras/slide  — você fala por cima
  enviado     140 palavras/slide  — cliente lê sozinho
  hibrido      45, exceto slides de dinheiro (180)

Sai com código 1 se algum slide estourou.
"""
import pathlib
import re
import sys

TETOS = {'apresentado': (45, 45), 'enviado': (140, 140), 'hibrido': (45, 180)}
# Slides de dinheiro: relidos sozinhos depois, densidade extra é blindagem.
# Detecta pelas CLASSES do componente, nunca pela prosa — "custo" aparece no
# texto de slides de problema/implicação, que NÃO ganham teto estendido.
DINHEIRO = re.compile(r'class="[^"]*\b(?:cost-\w+|payback|pb-\w+|up-note|roi-\w+)\b')

args = [a for a in sys.argv[1:] if not a.startswith('--')]
if not args:
    sys.exit(__doc__)
modo = 'hibrido'
if '--modo' in sys.argv:
    modo = sys.argv[sys.argv.index('--modo') + 1]
if modo not in TETOS:
    sys.exit(f'modo inválido: {modo}. Use: {", ".join(TETOS)}')
teto_padrao, teto_dinheiro = TETOS[modo]

html = pathlib.Path(args[0]).read_text(encoding='utf-8')
html = re.sub(r'<style.*?</style>', '', html, flags=re.S)
html = re.sub(r'<script.*?</script>', '', html, flags=re.S)
html = re.sub(r'<!--.*?-->', '', html, flags=re.S)

estourados, palavras = [], []
print(f'modo: {modo}  (teto {teto_padrao}, dinheiro {teto_dinheiro})\n')

for m in re.finditer(r'<section[^>]*id="([^"]+)"[^>]*>(.*?)</section>', html, re.S):
    sid, corpo = m.group(1), m.group(2)
    texto = re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', ' ', corpo)).strip()
    n = len(texto.split())
    palavras.append(n)
    money = bool(DINHEIRO.search(corpo))
    teto = teto_dinheiro if (money and modo == 'hibrido') else teto_padrao
    if n > teto:
        estourados.append((sid, n, teto))
        marca, tag = '  ESTOUROU', f'  (teto {teto})'
    else:
        marca, tag = 'ok', '  $' if money else ''
    print(f'  {sid:9} {n:4} palavras  {marca}{tag}')

if palavras:
    med = sorted(palavras)[len(palavras) // 2]
    print(f'\ntotal {sum(palavras)} palavras · {len(palavras)} slides · mediana {med}')

if estourados:
    print(f'\n{len(estourados)} slide(s) acima do teto:')
    for sid, n, teto in estourados:
        print(f'  {sid}: {n} palavras, corte {n - teto} ou divida em dois slides')
    print('\nNunca diminua a fonte pra caber.')
    sys.exit(1)
print('\nTodos dentro do teto.')
