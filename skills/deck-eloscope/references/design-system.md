# Eloscope — design system do deck

Fonte canônica completa: `eloscope.design.md` no repo ReabilitaCao. Este arquivo é o recorte que importa pra slides.

## Mood

"AI command center meets editorial magazine". Fundo de espaço profundo com **uma única fonte de luz fria** cortando o escuro. Tensão deliberada entre vazio e impacto. Densidade 4 / Variância 7 / Movimento 7.

## Tokens (copiar de `assets/deck.css`, bloco `:root`)

| Token | Valor | Uso |
|---|---|---|
| `--canvas` | `#07080c` | Fundo. Deep Space, **nunca** `#000` |
| `--surface` / `--surface-ink` | `#0a0b11` / `#111118` | Cards, superfícies elevadas |
| `--ink` | `#F2F2F0` | Texto forte, headlines, `<strong>` |
| `--muted` / `--faint` | `rgba(255,255,255,.42)` / `.58` | Corpo e legendas |
| `--cyan` | `#00D4FF` | **A única voltagem.** CTA, estado ativo, glow, divisor |
| `--cyan-tip` | `#00ffcc` | Só no pico do LED divider |
| `--magenta` | `#D946EF` | **Só glow ambiente.** Nunca texto, borda ou botão |
| `--hair` → `--hair-3` | `rgba(255,255,255,.06/.10/.16)` | Hairlines estruturais |
| `--glass` / `--glass-2` | `rgba(255,255,255,.03/.05)` | Fundo de card glass |
| `--ease` | `cubic-bezier(.16,1,.3,1)` | Toda transição |

## Tipografia

- **Display:** Syne 700, `letter-spacing: -0.025em`, `line-height: 1.08`, `clamp(2rem, 3.6vw, 3.3rem)`, `max-width: 20ch`, `text-wrap: balance`.
- **Body:** Inter, `line-height: 1.7–1.8`, `max-width: 54ch`. Leading relaxado é assinatura.
- **Mono:** JetBrains Mono 500, 11px, `letter-spacing: .22em`, uppercase — exclusivo do `.kicker` e de rótulos técnicos.
- `.hl` pinta uma palavra da headline de cyan. **Uma por headline**, no máximo.

## Assinaturas visuais (não negociáveis)

1. **Grid assimétrico 2 colunas, left-biased.** Nunca 3 cards iguais.
2. **LED divider** — `--led`, gradiente transparente → cyan → `#00ffcc` no centro → cyan → transparente.
3. **Glass cards** com borda cyan-tinted (`--cyan-border`) e `--shadow-glass`.
4. **Kicker com hairline** — `.kicker::before` é um traço de 34px; o número vem em `.n` cyan.
5. **Glow radial reposicionado por slide** — cada `#sN` define `--glow-x` / `--glow-y`. É o que dá ritmo à sequência: alterna canto direito-alto → esquerdo-baixo → direito-alto. Nunca dois slides seguidos com o glow no mesmo canto.

## Glow duplo = pico emocional

Máximo 2 por deck. Cyan grande no topo + magenta embaixo:

```css
#s6::before { background:
  radial-gradient(1100px 700px at 50% 22%, rgba(0,212,255,0.14), transparent 60%),
  radial-gradient(820px 560px at 50% 100%, rgba(217,70,239,0.10), transparent 60%); }
```

Reserve para: (a) o slide de virada — "e se…" / a promessa; (b) o fechamento / CTA.

## Shell e navegação

- `.deck` ocupa `100vh/100vw`; `.slide` é `position:absolute; inset:0`, só `.active` aparece.
- Transição: `opacity` + `translateY(14px)` em 360ms com `--ease`.
- Padding de slide: `92px 8.5vw 88px`; `.slide-inner` com `max-width: 1120px`.
- `.deck-chrome` fixo: contador `01 / N`, dots clicáveis, botões ‹ ›.
- `assets/deck.js` liga: setas/espaço, teclas `1–9`, dots, progress bar. Copie sem alterar.
- `@media (prefers-reduced-motion: reduce)` já desliga tudo — mantenha.

## Acessibilidade

- Contraste: `--muted` em `--canvas` é o piso. Não desça de `.42` alpha em texto corrido.
- Botões de nav têm `aria-label`. Dots idem.
- Slides rolam (`overflow-y:auto`) quando o conteúdo estoura — não encolha fonte pra caber.
