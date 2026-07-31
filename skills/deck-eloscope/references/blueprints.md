# Blueprints de deck

Cada blueprint é uma **sequência de argumentos**, não um molde rígido. Corte slides que não têm conteúdo real; nunca preencha um slide pra cumprir o blueprint.

Notação: `nº · kicker · headline (exemplo) · componente`

---

## 1. `expansao` — upsell pra cliente ativo

Estrutura SPIN precedida de prova de relação. É o deck de `docs/propostas/2026-07-27-fase-financeiro-estoque-metas/` — veja `assets/reference-deck.html` pra markup 1:1.

| # | kicker | função do slide | componente |
|---|---|---|---|
| 00 | — | capa: logo, título, cliente, data | `.cover` + `.cover-led` |
| 01 | — | tese em uma frase + 3 números âncora | `.hero-mark`, `.statband` |
| 02 | evolução | de onde partiu → onde chegou (a relação) | `.evo` (`.evo-from` → `.evo-arrow` → `.evo-to`) |
| 03 | o que já entregamos | prometido vs entregue, lado a lado | `.compare` / `.cmp-col` |
| 04 | em operação | cada peça no ar + impacto medido | `.feat-list` / `.feat-row` + `.statband` |
| 05 | **situação** | como a operação roda hoje, sem juízo | `.grid-2x2` / `.sit-card` |
| 06 | **problema** | o que está quebrado nisso | `.prob-list` / `.prob-row` |
| 07 | **implicação** | o que isso custa por mês, em R$ e em horas | `.imp-list` / `.imp-row` |
| 08 | o que muda | "e se…" — a virada. **glow duplo** | `.whatif` / `.whatif-q` |
| 09–12 | a solução · 0N de 0M | um módulo por slide: problema → solução → prova | `.sol-grid`, `.sol-tabs`, `.checklist`, `.impact` |
| 13 | arquitetura | por que é barato: roda no que já existe | `.arch-grid` / `.arch-node` / `.arch-base` |
| 14 | benefícios | o que muda na prática, por papel | `.ben-grid` / `.ben-row` |
| 15 | cronograma | fases, uma de cada vez, com ETA | `.road-grid` / `.road-step` / `.road-eta` |
| 16 | o valor em jogo | âncora: custo é uma vez, ganho é todo mês | `.imp-list` + `.up-note` |
| 17 | investimento | preço, com as cartas na mesa | `.cost-grid` / `.cost-card` / `.cost-price` |
| 18 | retorno | payback: quando o valor volta | `.payback` / `.pb-grid` |
| 19 | — | fechamento + CTA. **glow duplo** | `.close-mark`, `.cta-row` |
| anexo | flexibilidade | modularização: comece por onde dói mais | `.modsplit-grid` / `.modsplit-card` |

**Regra de ouro:** 16 (valor) vem **antes** de 17 (preço), e 18 (payback) logo depois. Preço solto no meio do deck destrói a proposta.

---

## 2. `primeira-venda` — prospect frio

Sem histórico, a credibilidade tem que ser emprestada de terceiros. Trocas em relação ao `expansao`:

| # | kicker | função | componente |
|---|---|---|---|
| 00 | — | capa | `.cover` |
| 01 | — | tensão de abertura: a frase que o prospect já pensou | `.hero-mark` + `.lead` |
| 02 | contexto | o que mudou no mercado dele | `.statband` (com `.statband-src` obrigatório) |
| 03 | quem somos | 4 linhas, não 4 slides | `.glass` + `.feat-list` |
| 04 | prova | case real: antes → depois, com número | `.evo` + `.statband` |
| 05 | **situação** | diagnóstico do que ele contou na call | `.grid-2x2` / `.sit-card` |
| 06 | **problema** | ↑ mesmo do expansao | `.prob-list` |
| 07 | **implicação** | ↑ | `.imp-list` |
| 08 | o que muda | virada. **glow duplo** | `.whatif` |
| 09–N | a solução | módulos | `.sol-grid` |
| N+1 | como entra | onboarding e cronograma | `.road-grid` |
| N+2 | investimento | preço | `.cost-grid` |
| N+3 | retorno | payback **projetado** — rotule como projeção | `.payback` |
| N+4 | — | próximo passo concreto (não "vamos conversar") | `.cta-row` |

**Nunca** use os slides 02–04 do `expansao` ("o que já entregamos") aqui. Não existe histórico.
**Payback aqui é projeção**, não fato — o rótulo tem que dizer isso.

---

## 3. `qbr` — relatório de entrega / prestação de contas

Sem preço. O objetivo é renovar confiança, não vender.

| # | kicker | função | componente |
|---|---|---|---|
| 00 | — | capa: cliente + período | `.cover` |
| 01 | — | o período em 3 números | `.statband` |
| 02 | o que foi prometido | escopo acordado | `.cmp-col` (esquerda) |
| 03 | o que foi entregue | prometido vs entregue | `.compare` completo |
| 04 | em operação | cada peça no ar + uso real | `.feat-list` |
| 05 | impacto | métrica antes → depois | `.evo` + `.statband` |
| 06 | o que travou | honestidade sobre o que não saiu e por quê | `.prob-list` |
| 07 | próximo ciclo | o que entra a seguir | `.road-grid` |
| 08 | — | fechamento. **glow duplo** | `.close-mark` |

**Slide 06 não é opcional.** QBR sem o que travou lê como marketing e queima a confiança do resto.

---

## 4. `pitch` — institucional / produto

Curto por definição: 8–10 slides. Ninguém pede um pitch de 20.

| # | kicker | função | componente |
|---|---|---|---|
| 00 | — | capa | `.cover` |
| 01 | — | a tese, uma frase, tipo grande | `.hero-mark` |
| 02 | o problema | a dor da categoria, não de um cliente | `.prob-list` |
| 03 | o que fazemos | a solução em uma frase + 3 pilares | `.sol-lede` + `.grid-2x2` |
| 04–06 | como funciona | um pilar por slide | `.sol-grid` |
| 07 | arquitetura | por que é defensável | `.arch-grid` |
| 08 | prova | números + fonte | `.statband` + `.statband-src` |
| 09 | — | CTA. **glow duplo** | `.cta-row` |

Sem preço, sem cronograma. Preço em pitch institucional mata a conversa antes do diagnóstico.

---

## Escolhendo componentes por tipo de conteúdo

| Conteúdo | Componente |
|---|---|
| Transformação A → B | `.evo` |
| Comparação lado a lado | `.compare` / `.cmp-col` |
| Lista de dores | `.prob-list` / `.prob-row` |
| Lista de custos/consequências | `.imp-list` / `.imp-row` |
| Features entregues | `.feat-list` / `.feat-row` |
| Estado atual em 4 quadrantes | `.grid-2x2` / `.sit-card` |
| Módulo de solução (problema + solução + prova) | `.sol-grid` + `.sol-tabs` |
| Camadas técnicas | `.arch-grid` / `.arch-node` |
| Timeline com ETA | `.road-grid` / `.road-step` |
| Preço | `.cost-grid` / `.cost-card` |
| Conta de retorno | `.payback` / `.pb-grid` |
| Números âncora com fonte | `.statband` + `.statband-src` |
| Escolher por onde começar | `.modsplit-grid` |
