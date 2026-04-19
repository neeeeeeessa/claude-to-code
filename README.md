# Claude-to-Code

A template repo for turning ideas into shipped code via the
**idea → spec → autonomous loop** pipeline. Iterate on what you want in a
chat agent for as long as you need, then hand off to an execution loop
that builds it.

The template defines the **pipeline**, not the product. It contains no app
code, no stack preferences, and no opinions about what you're building. It
defines how work flows from a locked-in spec to a shipped feature.

**Agent-agnostic by design.** Claude Code, Cursor, Codex, Gemini CLI, or
Antigravity can all drive this pipeline — the `AGENTS.md` file is the
portable convention they all read.

---

## The Workflow This Enables

```
┌─────────────────────────────────────────────────────────────┐
│  1. IDEATE (hours, conversational, human-led)               │
│     Use Claude.ai, ChatGPT, Gemini — whichever thinks best. │
│     Output: constitution.md, spec.md, plan.md, tasks.md     │
└─────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│  2. SCAFFOLD from this template                             │
│     gh repo create my-thing --template <user>/claude-to-    │
│                              code --clone                   │
└─────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│  3. INGEST the four markdown files into the right places    │
│     (via the spec-ingest skill, or manually)                │
└─────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│  4. VALIDATE — run `validate-specs` skill (A3)              │
│     Catches ambiguities and weak tasks before the loop      │
│     starts thrashing. Also auto-runs inside /ralph-go.      │
└─────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│  5. EXECUTE in either pattern:                              │
│     A) Autonomous loop via /ralph-go  (AFK, overnight)      │
│     B) Interactive in your IDE        (feature-at-a-time)   │
│     Both read the same files. Switch between them freely.   │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

Assumes you've already produced the four markdown files during ideation.

### First time on a new machine

Before bootstrapping any project, verify your environment. Open Claude Code
and run:

```
> check setup
```

Or directly: `bash ~/.claude/skills/check-setup/doctor.sh`

The `check-setup` skill (if installed) reports missing tools, auth issues,
and uninstalled skills with explicit install commands. Fix anything red
before proceeding.

### Every new project

```bash
# 1. Create a new project from this template
gh repo create my-new-thing --template <your-user>/claude-to-code --clone
cd my-new-thing

# 2. Activate the pre-commit hook (one command, one time)
git config core.hooksPath .githooks

# 3. Drop your four files in place
#    - specs/spec.md
#    - specs/plan.md
#    - specs/tasks.md
#    - .specify/memory/constitution.md
#    Delete specs/README.md once the real files are in.

# 4. Create a branch (the loop refuses to run on main)
git checkout -b ralph/initial-build

# 5. Open Claude Code and run
claude
> validate specs                        # via the validate-specs skill (A3)
> /ralph-go cautious                    # start the loop (first run)
#   Note: /ralph-go auto-runs validation as pre-flight; the separate
#   "validate specs" call is only needed if you want to check mid-project.
```

## The Two Execution Patterns

Both patterns read the same `specs/` files and respect the same `- [x]`
checkbox state. You can switch between them mid-project — nothing gets
built twice.

### Pattern A — Autonomous Loop (AFK)

Run `./scripts/ralph/ralph.sh <preset>` or `/ralph-go <preset>` from inside
Claude Code. The loop picks one task at a time, implements it, verifies,
commits, opens a draft PR, exits with fresh context, and picks the next.
You review PRs in the morning.

Best for: greenfield projects, large batches of mechanical work, overnight
grind sessions.

### Pattern B — Interactive (Feature-at-a-time)

Open Cursor, Claude Code, Codex, or any agent-aware IDE. Tell it "do the
next task from `specs/tasks.md`." Review as it goes. Commit when done.
Close the session.

Best for: ongoing projects where each feature warrants attention, when you
want to steer the implementation as it happens, when you're sitting there
anyway.

## Presets: How Much to Trust the Loop

Three presets, pickable at launch. Pick based on (a) how experienced you
are with this pipeline, and (b) how solid you believe your specs are.

| Preset | Max iterations | Consecutive failure cap | Use when |
|---|---|---|---|
| `cautious` | 20 | 3 | First run on a new project, or first Ralph run ever |
| `standard` | 50 | 5 | A few loops in, trust is reasonable (default) |
| `trusting` | 100 | off | Solid specs, stable stack, let it grind |

```bash
./scripts/ralph/ralph.sh cautious       # or: standard, trusting
```

**Worktree requirement is always on**, regardless of preset. This isn't a
trust setting — it's the security boundary for `--dangerously-skip-permissions`.
Losing it means a runaway loop could corrupt `main`.

## Agent-Agnostic: Swap the Agent

The loop is hardcoded to nothing. Swap the agent via the `AGENT_CMD` env var:

```bash
# Default (Claude Code)
./scripts/ralph/ralph.sh

# Cursor
AGENT_CMD="cursor-agent -p" ./scripts/ralph/ralph.sh

# Codex
AGENT_CMD="codex -p --auto-edit" ./scripts/ralph/ralph.sh

# Gemini CLI
AGENT_CMD="gemini --yolo" ./scripts/ralph/ralph.sh
```

Any CLI that accepts a prompt on stdin and runs autonomously works. The
`AGENTS.md` file is read by all of them (it's the emerging universal
convention); `CLAUDE.md` is a thin pointer kept for Claude Code's auto-discovery.

## What's In Here

```
.
├── AGENTS.md                      ← primary operator file (all agents read this)
├── CLAUDE.md                      ← thin pointer → AGENTS.md
├── LEARNINGS.md                   ← append-only discoveries (persistent memory)
├── progress.txt                   ← append-only iteration log
├── .specify/
│   └── memory/
│       └── constitution.md        ← project non-negotiables (from ideation)
├── specs/                         ← spec.md, plan.md, tasks.md land here
├── scripts/ralph/
│   ├── ralph.sh                   ← the autonomous loop (preset-aware, agent-agnostic)
│   └── prompt.md                  ← per-iteration prompt
├── .claude/commands/
│   └── ralph-go.md                ← slash command to launch the loop
├── .github/workflows/ci.yml       ← CI = external backpressure signal for the loop
├── .githooks/pre-commit           ← blocks destructive ops & secret leaks
├── LICENSE                        ← MIT
└── .gitignore
```

## What's Deliberately NOT In Here

- No app code. The agent generates all of that from `specs/plan.md`.
- No stack-specific config (`tsconfig.json`, `vite.config.ts`, etc.). Decided per project.
- No framework preferences in `AGENTS.md`. Every project gets the right stack for
  that project, decided with full context — not the habitual one.

## Why Promises, Not Status Flags

The loop uses a verbal contract: the agent must emit
`<promise>TASK_DONE</promise>` or `<promise>COMPLETE</promise>` for the
loop to count the iteration as successful.

This isn't cargo-cult syntax. It's a deliberate choice:

- A **status flag** (a file, a git state, an exit code) can be set accidentally
  by a half-finished iteration. An agent that bailed halfway through might still
  leave a "done" marker behind.
- A **promise** is something the agent has to *say* as its last act. It's a
  conscious declaration: "I verified this task is complete." If the agent didn't
  emit the promise, something went wrong — either it crashed, got blocked, or
  didn't finish.

This is a small thing that prevents a large class of "loop thinks it succeeded
but didn't" bugs. Other Ralph implementations have converged on the same
pattern for the same reason.

## Spec Validation (A3)

The `validate-specs` skill catches problems in your spec files *before* Ralph
burns tokens on them. It runs automatically as pre-flight inside `/ralph-go`
and the `bootstrap-project` skill; you can also invoke it manually with
phrases like "validate specs" or "check specs" in Claude Code.

Two layers of checks:

**Fast structural + heuristic checks (always run, no API cost):**
- All required files exist with required sections
- Minimum 3 user stories, minimum 5 tasks
- Every task has Description, Acceptance, and Verify
- No placeholder verify commands (`# TODO`, `<...>`, etc.)
- No subjective language in acceptance criteria ("feels clean," "user-friendly")
- No oversized tasks (>100 words — usually means mixed concerns)

**Optional LLM-based semantic audit (opt-in, costs ~30-60s of API calls):**
- Constitution violations in the plan
- User stories not traced to tasks
- Stack contradictions
- Implausible acceptance criteria that regex missed

The LLM audit is worth running on important projects or when the fast
validator passes but you want extra confidence. Trigger it with "run deep
audit" or "llm audit" in Claude Code.

Exit codes from the validator: `0` = clean, `1` = hard issues (blocks loop),
`2` = warnings only (proceeds).

## Safety Defaults

The template assumes you will run Pattern A (the loop) AFK. The non-negotiables:

- Refuses to run on `main`. Always uses a `ralph/*` branch or worktree.
- Pre-commit hook blocks secret leaks (`.env` files, API key patterns) and
  destructive commands in diffs.
- With `cautious` or `standard`, exits after N consecutive iterations without a
  `TASK_DONE` promise — stops the thrashing, hands back to you.
- Every task must have a **verification command**. No verification = no
  backpressure = no convergence.
- Draft PRs per task. You review in the morning; nothing auto-merges.

## Environment Variables

Override anything. Secrets go in `.env.local` (gitignored); see `.env.local.example`.

| Variable | Default | Purpose |
|---|---|---|
| `MAX_ITERATIONS` | preset-dependent | Hard ceiling on iterations |
| `MAX_CONSECUTIVE_FAILURES` | preset-dependent | `0` to disable early exit |
| `COMPLETION_PROMISE` | `COMPLETE` | Signals all tasks done |
| `TASK_PROMISE` | `TASK_DONE` | Signals one task done |
| `PROMPT_FILE` | `scripts/ralph/prompt.md` | Per-iteration prompt |
| `AGENT_CMD` | `claude --dangerously-skip-permissions -p` | Agent CLI to invoke |
| `LOG_DIR` | `.ralph-logs` | Where iteration logs go |
| `SESSION_STOP_PCT` | `85` | Stop if Claude session usage ≥ this % (Claude Code only) |
| `WEEKLY_STOP_PCT` | `75` | Stop if Claude weekly usage ≥ this % (Claude Code only) |
| `AUTO_RESUME_ON_429` | `1` | `1` = pause and resume on rate limit; `0` = exit |
| `HEARTBEAT_MINUTES` | `0` | Send a status Telegram every N minutes (`0` = off) |
| `TELEGRAM_BOT_TOKEN` | — | Enables Telegram notifications (see `.env.local.example`) |
| `TELEGRAM_CHAT_ID` | — | Required with `TELEGRAM_BOT_TOKEN` |

## Rate Limit Awareness

When running on Claude Code with a Pro or Max subscription, the loop tracks your
5-hour session window and 7-day weekly cap. It:

- Queries `/status` on iteration 1 and every 5th iteration after
- Stops pre-emptively if session usage ≥ `SESSION_STOP_PCT` or weekly ≥ `WEEKLY_STOP_PCT`
- Detects HTTP 429 / rate-limit errors in iteration logs
- When `AUTO_RESUME_ON_429=1` (the default), sleeps until the window resets
  and retries the same iteration — overnight runs no longer die on rate limits,
  they pause and resume

Per-iteration usage is logged to `.ralph-logs/usage.jsonl` (one JSON object
per line) for post-hoc analysis. Non-Claude agents skip the session/weekly
tracking but still get token counts where available.

## Telegram Notifications

Optional. Fill in `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` in `.env.local`
to enable. Event-driven by default; a periodic heartbeat is opt-in via
`HEARTBEAT_MINUTES`.

Events that trigger notifications:

- **Start** — loop starting, preset, total tasks
- **Task done** — task ID, progress (e.g. `7/15`)
- **Task failed 3+ times** — warns loop is struggling on a specific task
- **Rate limit pause** — which cap was hit and estimated resume time
- **Rate limit resume** — when the loop picks back up
- **Heartbeat** (optional) — every `HEARTBEAT_MINUTES`, compact status
- **Exit** — success, consecutive failures, max iterations, or rate-limit-stop

Setup walkthrough is in `.env.local.example`. Use a **dedicated** bot — don't
reuse one from another project.

## When NOT to Use the Loop

Pattern A (autonomous loop) is for mechanical execution of well-specified work.
Drop to Pattern B (interactive) when:

- The work is exploratory ("figure out why the app is slow")
- Architectural decisions are still open
- Security-sensitive code (auth, payments, data handling) — human review per
  step is worth it
- The verification would be subjective ("does this feel right?")

## Credits & Prior Art

This template stitches together work from:

- **Geoffrey Huntley** — [original Ralph Wiggum technique](https://ghuntley.com/loop/)
- **Anthropic** — Claude Code and the official Ralph Wiggum plugin
- **snarktank/ralph** — spec-aware Ralph variant with fresh context per task
- **GitHub Spec Kit** — the `/speckit.*` slash commands and scaffold conventions
- The emerging `AGENTS.md` convention — portable agent instructions across
  Claude Code, Cursor, Codex, Gemini CLI, and others

## License

MIT. See [LICENSE](./LICENSE).
