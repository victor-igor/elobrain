---
name: deck-eloscope
description: Use when creating, editing, or restyling any slide deck / apresentação / proposta visual for Eloscope — sales decks, upsell/expansion proposals, QBR delivery reports, institutional pitches. Produces a single self-contained HTML deck in the Eloscope visual language (Deep Space canvas, Quantum Cyan accent, Syne/Inter/JetBrains Mono, keyboard-navigated slides). Triggers on "criar slide", "criar deck", "montar apresentação", "proposta visual", "pitch deck", "slides pra reunião", "/deck-eloscope".
---

# deck-eloscope

Monta decks HTML de slide único-arquivo no design system Eloscope. O visual é fixo e não se negocia; o que muda é **qual blueprint** e **qual conteúdo**.

## Contrato

**Entrada:** o objetivo do deck (pra quem, pra quê), o conteúdo bruto (números, features, preço, histórico do cliente).
**Saída:** UM arquivo `.html` autocontido, navegável por teclado, que abre no browser e pode virar artifact.
**Nunca:** inventar número, preço, prazo, métrica ou case. Se não veio do usuário ou de um arquivo do repo, o slide não existe — pergunte.

## Fase 1 — Classificar o deck

Antes de escrever qualquer HTML, decida o blueprint. A pergunta que separa tudo: **existe relação prévia com quem vai assistir?**

| Situação | Blueprint | Arquivo |
|---|---|---|
| Cliente que já paga, vendendo um módulo/fase novo | `expansao` (SPIN completo) | `references/blueprints.md` |
| Prospect frio / primeira reunião comercial | `primeira-venda` | `references/blueprints.md` |
| Prestação de contas, sem preço no fim | `qbr` | `references/blueprints.md` |
| Posicionamento institucional / produto | `pitch` | `references/blueprints.md` |

Se o usuário não disse, **pergunte** — o blueprint errado gera um deck que soa desonesto (falar "o que já entregamos" pra quem nunca comprou, ou fazer diagnóstico de dor com quem já é cliente há 2 anos).

## Fase 2 — Escolher o modo (densidade de texto)

O blueprint define a **sequência**. O modo define **quanto texto cabe em cada slide** — e essa é a decisão que separa um deck premium de um relatório bonito. Pergunte: **o deck vai ser apresentado ao vivo, ou mandado por link pro cliente ler sozinho?**

| Modo | Quando | Teto por slide | Onde vai o resto |
|---|---|---|---|
| `apresentado` | Você fala por cima, em call ou sala | **45 palavras** | Nota de fala no `.md` irmão |
| `enviado` | Link que o cliente abre sozinho, sem você | **140 palavras** | Nada — o slide se explica sozinho |
| `hibrido` **(default)** | Apresenta ao vivo *e* deixa o link depois | **45**, exceto slides de dinheiro: **180** | Notas de fala nos slides de argumento |

"Slides de dinheiro" = investimento, payback, valor em jogo. Eles são relidos sozinhos depois — printados, mandados pro sócio, usados pra justificar a compra. Detalhe ali é blindagem contra objeção, não excesso.

**Por que o teto existe:** ao vivo, o cliente lê mais rápido do que você fala. Slide de 100 palavras faz você competir com o próprio slide — e perder. O deck de referência tem mediana de 101 palavras/slide: densidade de deck-documento, não de palco. Correto se enviado, caro se apresentado.

Rode `python3 assets/check-density.py <arquivo>.html --modo hibrido` antes de entregar. Ele mede e aponta os slides estourados.

## Fase 3 — Escrever a espinha antes do HTML

Liste, em texto, a sequência de slides: `nº / kicker / headline / componente / nº de palavras previsto`. Confirme com o usuário. Só depois abra o editor.

Regras de espinha:
- **8–20 slides.** Abaixo de 8 é one-pager, acima de 20 ninguém aguenta.
- **Um argumento por slide.** Se o slide precisa de dois kickers, são dois slides.
- **Todo número precisa de fonte.** `.statband-src` existe pra isso. Sem fonte, corte o número.
- **Picos emocionais recebem glow duplo** (cyan + magenta). No máximo 2 por deck: o slide de virada e o fechamento.
- **Estourou o teto do modo?** A saída é cortar ou dividir em dois slides — nunca diminuir a fonte pra caber.

## Fase 4 — Montar

1. Leia `assets/reference-deck.html` — é o deck de expansão real, completo e funcionando (screenshots do produto trocados por `ASSET_PLACEHOLDER.png`; a marca está intacta). Ele é a documentação de markup de todos os 86 componentes.
2. Copie a shell junto ao diretório `assets/`: `<style>` (`deck.css` + `@import "fonts.css"`), os `<section class="slide">`, o `.deck-chrome` e o `<script>` (`deck.js`).
3. Escolha componentes pelo `assets/component-index.md` (classe → em qual slide do reference-deck ver o markup).
4. Regras visuais e tokens: `references/design-system.md`. Não invente cor, fonte nem espaçamento fora dela.

## Marca — sempre presente, sempre nos mesmos 4 lugares

`assets/brand/` é fixo. Todo deck carrega a marca; não pergunte se deve incluir.

| Arquivo | Onde entra | Classe |
|---|---|---|
| `brand/logo-wordmark.png` (1088×109) | topo fixo, em todos os slides | `.brand-header img` |
| `brand/logo-wordmark.png` | capa | `.cover-logo` |
| `brand/logo-wordmark.png` | fechamento | `.close-mark` |
| `brand/hero-mark.png` (293×173) | slide de abertura da tese | `.hero-mark` |

Use `src="brand/logo-wordmark.png"` relativo e copie a pasta `brand/` junto do `.html`. Nunca substitua por texto, SVG improvisado ou emoji.

## Fase 5 — Entregar

- Salve em `docs/propostas/<AAAA-MM-DD>-<slug>/` (ou onde o usuário pedir), com `assets/` do lado.
- **Rode `python3 assets/check-density.py <arquivo>.html --modo <modo>`.** Se estourou, corte antes de mostrar — não entregue com aviso pendente.
- `open <arquivo>.html` pra conferir.
- **Só se for virar artifact:** rode `python3 assets/brand/inline-brand.py <arquivo>.html` — a CSP do artifact bloqueia host externo *e* caminho relativo, então fontes e imagens têm que ir inline em base64. Gera `<arquivo>.artifact.html`. Para uso local, pule; o relativo funciona.
- Nos modos `apresentado` e `hibrido`, entregue o **`.md` de notas de fala** junto — é ele que carrega o argumento que saiu do slide. Sem ele, o deck enxuto fica oco.
- Ofereça o script de fala (SPIN) como `.md` irmão quando o blueprint for comercial.

## Anti-padrões

| Não faça | Por quê |
|---|---|
| 3 cards iguais lado a lado | O sistema é grid assimétrico 2 colunas, left-biased |
| Magenta em texto, borda ou botão | Magenta é só glow ambiente |
| Cyan em mais de ~3 elementos por slide | A voltagem única perde força se espalhada |
| Preto puro `#000` | Canvas é Deep Space `#07080c` |
| Bullet list genérica | Use `.prob-row`, `.imp-row`, `.feat-row`, `.checklist` — cada uma carrega semântica |
| Emoji | O sistema não usa. Kicker mono + hairline faz o trabalho |
| Slide de preço sem slide de payback antes | Preço sem âncora de retorno mata a proposta |
