# Elobrain Installation Guide for AI Agents

Read this entire file, then follow the steps. Ask the user for API keys when needed.

---

## Which scenario applies?

**Ask the user before anything else:**
> "Você está instalando o elobrain do zero para uma empresa/equipe, ou está se conectando a um brain que já existe?"

| Resposta | Trilha | Tempo estimado |
|---|---|---|
| **Do zero** — nova empresa ou nova equipe, sem brain existente | Siga todos os passos (1 → 9) | ~30 min |
| **Conectando** — brain já existe, você só está entrando na equipe | Siga apenas os passos 1, 2, 2.1-A, 3 (init only), 5, 6 | ~10 min |

### Trilha: Conectando a um brain existente (resumo)

Se o brain já existe (Supabase já provisionado, dados já indexados), o membro da equipe precisa apenas:

1. **Step 1** — instalar o CLI (`git clone + bun link`)
2. **Step 2** — chaves OpenAI/Anthropic (pedir ao gestor da equipe ou usar as da empresa)
3. **Step 2.1-A** — chaves Supabase do projeto existente (pedir ao gestor: `SUPABASE_URL` + `SERVICE_ROLE_KEY`)
4. **Step 3** — rodar `gbrain init` para aplicar migrations pendentes (dados preservados) + `gbrain doctor`
5. Rodar `gbrain sync` uma vez para puxar o estado atual do brain
6. **Step 5** — carregar skills
7. **Step 6** — identidade pessoal (soul-audit cria perfil individual, não afeta os dados compartilhados)

Pule Steps 4, 4.5, 7, 8, 9 — esses são de setup inicial e já foram feitos pelo instalador original.

---

## Step 0: If you are not Claude Code

Read `AGENTS.md` at the repo root first. It's the non-Claude-agent operating
protocol (install, read order, trust boundary, common tasks). Claude Code reads
`CLAUDE.md` automatically and can skip ahead.

If you fetched this file by URL without cloning yet, the companion files live at:
- `https://raw.githubusercontent.com/victor-igor/elobrain/main/AGENTS.md` — start here
- `https://raw.githubusercontent.com/victor-igor/elobrain/main/llms.txt` — full doc map
- `https://raw.githubusercontent.com/victor-igor/elobrain/main/llms-full.txt` — same map, inlined

## Step 1: Install GBrain

```bash
git clone https://github.com/victor-igor/elobrain.git ~/elobrain && cd ~/elobrain
curl -fsSL https://bun.sh/install | bash
export PATH="$HOME/.bun/bin:$PATH"
bun install && bun link
```

Verify: `gbrain --version` should print a version number. If `gbrain` is not found,
restart the shell or add the PATH export to the shell profile.

> **Do NOT use `bun install -g github:victor-igor/elobrain`.** Bun blocks the top-level
> postinstall hook on global installs, so schema migrations never run and the CLI
> aborts with `Aborted()` when it opens PGLite. Use the `git clone + bun link` path
> above. Tracking issue: [#218](https://github.com/victor-igor/elobrain/issues/218).

## Step 2: API Keys

Ask the user for these:

```bash
export OPENAI_API_KEY=sk-...          # required for vector search
export ANTHROPIC_API_KEY=sk-ant-...   # optional, improves search quality
```

Save to shell profile or `.env`. Without OpenAI, keyword search still works.
Without Anthropic, search works but skips query expansion.

### Step 2.1: Supabase Backend (optional)

If the user wants a Postgres-backed brain instead of the default PGLite (recommended
for multi-agent setups, large brains, or remote access), follow the decision flow
below before asking for credentials.

**Ask the user:**
> "Você já tem um projeto Supabase criado para o elobrain?"

---

#### Caminho A — Projeto já existe (resposta: SIM)

Ask for the two required values (Supabase dashboard → Project Settings → API):

```bash
export SUPABASE_URL=https://<project-ref>.supabase.co
export SUPABASE_SERVICE_ROLE_KEY=eyJ...   # service role key (not anon key)
export GBRAIN_DB_BACKEND=supabase
```

Save to shell profile or `.env`, then proceed to Step 3.
`gbrain init` will detect the existing schema and apply only missing migrations —
**existing data is preserved.**

---

#### Caminho B — Projeto ainda não existe (resposta: NÃO)

Guide the user through project creation first, then collect credentials.

**Option B1 — Supabase Console (no CLI needed):**
1. Go to https://supabase.com/dashboard → "New project"
2. Choose org, set a project name (e.g. `elobrain`), region, and password
3. Wait for provisioning (~1 min)
4. Go to Project Settings → API → copy **Project URL** and **service_role** key

**Option B2 — Supabase CLI:**
```bash
brew install supabase/tap/supabase   # or see supabase.com/docs/guides/cli
supabase login
supabase projects create elobrain --org-id <your-org-id> --region us-east-1 \
  --db-password <strong-password>
# After creation, retrieve the keys:
supabase projects list               # find the project ref
supabase projects api-keys --project-ref <ref>
```

Once the project exists, set the env vars and proceed to Step 3.
`gbrain init` will create all tables, indexes, and RLS policies from scratch
in the new project — **nothing needs to be done manually in Supabase SQL editor.**

---

**Why service role key (not anon key):** gbrain needs full schema access to apply
migrations and manage RLS policies. The anon key is read-limited and will fail.

**Why Supabase:** PGLite is local-only. Supabase enables multi-device sync,
multi-agent reads, and pgvector for native embedding search without OpenAI.
If the user is unsure, default to PGLite (Step 3) and migrate later with
`gbrain migrate-backend --to supabase`.

## Step 3: Create the Brain

```bash
gbrain init                           # PGLite, no server needed
gbrain doctor --json                  # verify all checks pass
```

The user's markdown files (notes, docs, brain repo) are SEPARATE from this tool repo.
Ask the user where their files are, or create a new brain repo:

```bash
mkdir -p ~/brain && cd ~/brain && git init
```

Read `~/elobrain/docs/GBRAIN_RECOMMENDED_SCHEMA.md` and set up the MECE directory
structure (people/, companies/, concepts/, etc.) inside the user's brain repo,
NOT inside ~/elobrain.

## Step 4: Import and Index

```bash
gbrain import ~/brain/ --no-embed     # import markdown files
gbrain embed --stale                  # generate vector embeddings
gbrain query "key themes across these documents?"
```

## Step 4.5: Wire the Knowledge Graph

If the user already had a brain repo (Step 3 imported existing markdown), backfill
the typed-link graph and structured timeline. This populates the `links` and
`timeline_entries` tables that future writes will maintain automatically.

```bash
gbrain extract links --source db --dry-run | head -20    # preview
gbrain extract links --source db                         # commit
gbrain extract timeline --source db                      # dated events
gbrain stats                                             # verify links > 0
```

For brand-new empty brains, skip this step — auto-link populates the graph as the
agent writes pages going forward. There is nothing to backfill yet.

After this step:
- `gbrain graph-query <slug> --depth 2` works (relationship traversal)
- Search ranks well-connected entities higher (backlink boost)
- Every future `put_page` auto-creates typed links and reconciles stale ones

If a user has a very large brain (>10K pages), `extract --source db` is idempotent
and supports `--since YYYY-MM-DD` for incremental runs.

## Step 5: Load Skills

Read `~/elobrain/skills/RESOLVER.md`. This is the skill dispatcher. It tells you which
skill to read for any task. Save this to your memory permanently.

The three most important skills to adopt immediately:

1. **Signal detector** (`skills/signal-detector/SKILL.md`) — fire this on EVERY
   inbound message. It captures ideas and entities in parallel. The brain compounds.

2. **Brain-ops** (`skills/brain-ops/SKILL.md`) — brain-first lookup on every response.
   Check the brain before any external API call.

3. **Conventions** (`skills/conventions/quality.md`) — citation format, back-linking
   iron law, source attribution. These are non-negotiable quality rules.

## Step 6: Identity (optional)

Run the soul-audit skill to customize the agent's identity:

```
Read skills/soul-audit/SKILL.md and follow it.
```

This generates SOUL.md (agent identity), USER.md (user profile), ACCESS_POLICY.md
(who sees what), and HEARTBEAT.md (operational cadence) from the user's answers.

If skipped, minimal defaults are installed automatically.

## Step 7: Recurring Jobs

Set up using your platform's scheduler (OpenClaw cron, Railway cron, crontab):

- **Live sync** (every 15 min): `gbrain sync --repo ~/brain && gbrain embed --stale`
- **Auto-update** (daily): `gbrain check-update --json` (tell user, never auto-install)
- **Dream cycle** (nightly): read `docs/guides/cron-schedule.md` for the full protocol.
  Entity sweep, citation fixes, memory consolidation, plus (v0.23+) overnight conversation
  synthesis and cross-session pattern detection. 8 phases, one cron-friendly command. This
  is what makes the brain compound. Do not skip it.
- **Weekly**: `gbrain doctor --json && gbrain embed --stale`

## Step 8: Integrations

Run `gbrain integrations list`. Each recipe in `~/elobrain/recipes/` is a self-contained
installer. It tells you what credentials to ask for, how to validate, and what cron
to register. Ask the user which integrations they want (email, calendar, voice, Twitter).

Verify: `gbrain integrations doctor` (after at least one is configured)

## Step 9: Verify

Read `docs/GBRAIN_VERIFY.md` and run all 7 verification checks. Check #4 (live sync
actually works) is the most important.

## Upgrade

```bash
cd ~/elobrain && git pull origin main && bun install
gbrain init                           # apply schema migrations (idempotent)
gbrain post-upgrade                   # show migration notes for the version range
```

Then read `~/elobrain/skills/migrations/v<NEW_VERSION>.md` (and any intermediate
versions you skipped) and run any backfill or verification steps it lists. Skipping
this is how features ship in the binary but stay dormant in the user's brain.

For v0.12.0+ specifically: if your brain was created before v0.12.0, run
`gbrain extract links --source db && gbrain extract timeline --source db` to
backfill the new graph layer (see Step 4.5 above).

For v0.12.2+ specifically: if your brain is Postgres- or Supabase-backed and
predates v0.12.2, the `v0_12_2` migration runs `gbrain repair-jsonb`
automatically during `gbrain post-upgrade` to fix the double-encoded JSONB
columns. PGLite brains no-op. If wiki-style imports were truncated by the old
`splitBody` bug, run `gbrain sync --full` after upgrading to rebuild
`compiled_truth` from source markdown.
