# Claude-to-Code

A template repo for turning ideas into shipped code via the
**idea → spec → autonomous loop** pipeline. Iterate on what you want in a
chat agent for as long as you need, then hand off to an execution loop
that builds it.

> **Already have this set up?** If you're pulling down an updated version
> of this repo, see [`UPDATE.md`](UPDATE.md) for what changed and how to
> apply the update without losing your existing config.

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

## User Guide

This guide takes you from "nothing installed" to "running your first autonomous
loop," then explains every command you can trigger afterward. Read it in
order the first time. Skip to the section you need later.

### Table of contents

1. [Prerequisites — what to install](#1-prerequisites--what-to-install)
2. [First-time setup — one-time per machine](#2-first-time-setup--one-time-per-machine)
3. [Set up the Spec Factory (Claude.ai)](#3-set-up-the-spec-factory-claudeai)
4. [Start a new project](#4-start-a-new-project)
5. [Commands you can trigger](#5-commands-you-can-trigger)
6. [Resume a project later](#6-resume-a-project-later)
7. [Troubleshooting](#7-troubleshooting)

---

### 1. Prerequisites — what to install

Install these on every machine where you'll run the pipeline. Skip any that
you already have.

#### Required

| Tool | Purpose | Install |
|---|---|---|
| **Git for Windows** (or git on Mac/Linux) | Version control + Git Bash shell | [git-scm.com/downloads](https://git-scm.com/downloads) |
| **GitHub CLI (`gh`)** | Create repos from the command line | [cli.github.com](https://cli.github.com/) — Windows: `winget install GitHub.cli` |
| **Claude Code (`claude`)** | The CLI that runs the loop | [docs.claude.com/claude-code](https://docs.claude.com/claude-code) |
| **Python 3** | Used by the spec validator | [python.org/downloads](https://www.python.org/downloads/) — Windows: `winget install Python.Python.3.12` |
| **curl** | Sends Telegram notifications (if used) | Pre-installed almost everywhere |

#### Recommended

| Tool | Purpose | Install |
|---|---|---|
| **jq** | Prettier PR listing in the resume skill | [jqlang.github.io/jq](https://jqlang.github.io/jq/) — Windows: `winget install jqlang.jq` |
| **pnpm** | Default JS package manager for many stacks | `npm install -g pnpm` |

#### Authenticate

Once everything is installed, sign in:

```bash
gh auth login        # follow prompts; pick HTTPS + browser auth
claude /login        # run this once in Claude Code
```

---

### 2. First-time setup — one-time per machine

This is a single repo that serves two purposes: it's a **template** that new
projects clone from, and it contains the **tools** (skills, installer,
Spec Factory prompt) that run the pipeline.

You'll do four things once per machine:
1. Clone this repo
2. Install the skills
3. Create your `~/.claude/operator.env` (your identity + Telegram)
4. If this is the first time your account has this repo, push it to GitHub

#### Step 2.1 — Clone this repo

```bash
cd <wherever you keep source repos>
gh repo clone <your-user>/claude-to-code
```

If the repo doesn't exist on your GitHub account yet, skip to
[step 2.4](#step-24--push-this-repo-to-github-first-time-only) to create
it first, then come back here.

#### Step 2.2 — Install the skills

```bash
cd claude-to-code/tools
bash install.sh
```

The installer:
- Copies the four skills into `~/.claude/skills/`
- Preserves any existing `.config` files (so reinstalling doesn't wipe
  your bootstrap skill preferences)
- Runs the `check-setup` doctor at the end to verify your environment

If the doctor reports anything missing, follow its install hints.

#### Step 2.3 — Create your `operator.env` (files you must create yourself)

The pipeline has **two files you must create yourself** because they
contain personal info or secrets and are gitignored / not in the repo:

| File | Where | What it holds | How to create |
|---|---|---|---|
| `operator.env` | `~/.claude/operator.env` | Your name, location, GitHub user, Telegram credentials | Bootstrap skill offers to create it on first run, or copy manually (below) |
| `.env.local` | inside each project | Per-project loop overrides (optional) | Copy `.env.local.example` to `.env.local` inside the project |

**`operator.env` is the important one.** Without it:
- New projects won't get a `specs/operator-context.md` (agents work without
  knowing your name, location, or jurisdiction)
- Telegram notifications won't fire

**To create it now** (recommended — the bootstrap skill can also do this
interactively on its first run):

```bash
# From inside your cloned claude-to-code directory:
mkdir -p ~/.claude
cp tools/operator.env.example ~/.claude/operator.env

# Edit the file with your info — at minimum, set:
#   OPERATOR_NAME
#   OPERATOR_LOCATION
#   OPERATOR_JURISDICTION
#   GITHUB_USERNAME
#   DEFAULT_TEMPLATE_REPO (e.g. neeeeeeessa/claude-to-code)
#   TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID (optional)
```

To get your Telegram values (optional):

1. In Telegram, chat with **@BotFather**, send `/newbot`
2. Pick a name (e.g. `claude-to-code-yourname-bot`) and save the token
3. Send any message to your new bot from your own Telegram
4. In a browser, visit `https://api.telegram.org/bot<TOKEN>/getUpdates`
5. Find `"chat":{"id": NNNNNNN}` in the JSON response — that's `TELEGRAM_CHAT_ID`

Secure the file so only you can read it:

```bash
chmod 600 ~/.claude/operator.env
```

Verify it's picked up:

```bash
# In Claude Code:
> check setup
# Should show: ✓ operator.env found at ~/.claude/operator.env
```

#### Step 2.4 — Push this repo to GitHub (first time only)

Skip this entirely if the repo already exists on your account. Only run
this if you're the one setting up `<your-user>/claude-to-code` for the
first time:

```bash
cd claude-to-code
git init                    # if not already a git repo
git add .
git commit -m "initial: claude-to-code"

gh repo create <your-user>/claude-to-code \
  --public \
  --source=. \
  --description "Idea to spec to autonomous loop pipeline." \
  --push

# Mark as a GitHub template so 'gh repo create --template' works later
gh repo edit <your-user>/claude-to-code --template
```

---

### 3. Set up the Spec Factory (Claude.ai)

The Spec Factory is where hours of iteration happen before any code.

1. Open [Claude.ai](https://claude.ai) → **Projects** → **Create Project**
2. Name it: `Claude-to-Code Spec Factory`
3. Open `tools/spec-factory/spec-factory-system-prompt.md` from your cloned repo
4. Copy its entire contents
5. Paste into the Project's **Custom Instructions** field
6. Save

That's it. The Spec Factory is ready. Every new project idea starts as a
new conversation *inside* this Project.

---

### 4. Start a new project

#### Phase 1: Ideate (hours, in Claude.ai)

Open the Spec Factory Project → start a new conversation → describe your
idea. Claude will walk you through five phases (Framing, Ideation,
Constitution, Spec & Plan, Task Breakdown), proposing ideas and challenging
your assumptions along the way.

When the task list feels solid, say **"lock it in"**. Claude will produce
five artifacts:

- `constitution.md`
- `spec.md`
- `plan.md`
- `tasks.md`
- `handoff-summary.md`

Download all five. They typically land in `~/Downloads/` (or wherever your
browser saves).

#### Phase 2: Bootstrap (1 minute, in Claude Code)

Open a terminal (Git Bash on Windows). You don't need to be in any
particular directory — the bootstrap skill will ask you where to create
the project.

```bash
claude
```

Then type any of:

- *"bootstrap a new project"*
- *"set up a new claude-to-code project"*
- *"scaffold a new project"*

The bootstrap skill runs. **On first invocation, it asks a one-time setup
wizard** for:

- Your GitHub username (e.g. `neeeeeeessa`)
- Your template repo (defaults to `<username>/claude-to-code`)
- A list of folders where you typically create projects (e.g.
  `C:\Users\simoe\Projects`)
- Default source folder for spec files (defaults to `~/Downloads`)

After the wizard saves your preferences, this one-time setup never runs
again on this machine.

For every project after that, the skill asks (in this order):

1. **Project name** (always asked, never inferred) — use kebab-case like
   `icoffee-v2`
2. **Target folder** — pick from your stored options or type a custom path
3. **Source folder** — defaults to your stored default; press Enter
4. **Privacy** — private by default, type `public` to override

The skill then:

- Creates the GitHub repo from your template
- Clones it locally
- Activates the pre-commit hook
- Moves the 5 spec files into correct locations
- Creates a `ralph/initial-build` branch
- Commits the specs
- Runs the spec validator as a pre-flight

If validation fails with hard issues, the skill reports them and stops. Fix
the spec files, then say *"validate specs"* to re-check.

#### Phase 3: Execute

You have two execution patterns:

**Pattern A — Autonomous loop (AFK):**

From inside Claude Code, in the project directory:

```
> /ralph-go cautious
```

Ralph runs one task per iteration, commits, opens draft PRs, and keeps
going until all tasks are done, the consecutive-failure cap is hit, or
Claude session usage reaches the stop threshold.

Close the laptop. Wake up to:
- A Telegram notification telling you what happened (if configured)
- Draft PRs to review

**Pattern B — Interactive (feature-at-a-time):**

Open Claude Code, Cursor, or any IDE. Tell the agent:

> Read AGENTS.md, then do the next task from specs/tasks.md.

The agent does one task, you review, you commit. No loop.

Both patterns read the same `specs/tasks.md` — you can switch between them
mid-project and nothing gets built twice.

#### Configure Telegram notifications (optional, one-time)

Telegram credentials live in `~/.claude/operator.env` (operator-wide, set
once per machine). See [Section 2](#2-first-time-setup--one-time-per-machine)
for where to add them. Once set, they work for every project you bootstrap.

There is no per-project Telegram setup — simpler that way. If you have a
good reason to need different channels per project, that's a future change
we can revisit.

---

### 5. Commands you can trigger

A reference of everything the pipeline exposes. All triggers are case-
insensitive natural language — you don't need to match them exactly.

#### In Claude.ai (Spec Factory Project)

| Say this | What happens |
|---|---|
| *"lock it in"* / *"ship it"* / *"generate the files"* | Produces the 5 spec artifacts if the Minimum Viable Spec is complete |
| *"where are we?"* | Compact status of current phase, decisions locked in, open questions |
| *"rethink"* / *"back up"* | Steps back to revisit a previous phase |

#### In Claude Code (anywhere)

| Say this | Skill | What happens |
|---|---|---|
| *"check setup"* / *"doctor"* / *"health check"* | `check-setup` | Verifies tools, auth, installed skills |
| *"bootstrap a new project"* / *"scaffold a new project"* | `bootstrap-project` | Creates a new repo from template + imports specs |
| *"validate specs"* / *"check specs"* | `validate-specs` | Runs structural + heuristic checks on specs |
| *"deep audit"* / *"llm audit"* | `validate-specs` | Optional LLM-based semantic audit |
| *"resume"* / *"where did we leave off"* / *"status"* | `resume-project` | Full project status briefing |
| *"deep resume"* / *"smart resume"* | `resume-project` | Claude-analyzed state + suggested next actions |

#### In Claude Code (inside a project)

| Command | What happens |
|---|---|
| `/ralph-go cautious` | Start loop with `MAX_ITERATIONS=20`, exit after 3 consecutive failures |
| `/ralph-go standard` | Start loop with `MAX_ITERATIONS=50`, exit after 5 consecutive failures |
| `/ralph-go trusting` | Start loop with `MAX_ITERATIONS=100`, no consecutive-failure cap |

#### From a shell (anywhere)

| Command | Purpose |
|---|---|
| `bash ~/.claude/skills/check-setup/doctor.sh` | Run the setup check directly |
| `bash ~/.claude/skills/validate-specs/validate.sh` | Run spec validation directly (must be in a project dir) |
| `bash ~/.claude/skills/resume-project/resume.sh` | Status briefing directly |

#### From a shell (inside a project)

| Command | Purpose |
|---|---|
| `bash scripts/ralph/ralph.sh cautious` | Same as `/ralph-go cautious` but from the shell |
| `HEARTBEAT_MINUTES=30 bash scripts/ralph/ralph.sh` | Add periodic Telegram heartbeats |
| `AGENT_CMD="cursor-agent -p" bash scripts/ralph/ralph.sh` | Use Cursor instead of Claude Code |

See [Environment Variables](#environment-variables) further down for all tunable settings.

---

### 6. Resume a project later

When you come back to a project after hours, days, or months:

```bash
cd /path/to/your/project
claude
```

Then say:

> resume

The `resume-project` skill produces a structured briefing: last activity,
progress (N/M tasks), recently completed tasks, what's stuck, what's next,
open PRs awaiting review, recent learnings, and suggested next actions.

For a Claude-analyzed briefing with judgment-based suggestions (takes
30-60s and some API tokens):

> deep resume

---

### 7. Troubleshooting

**"command not found: claude" / "gh" / "python3"**
Re-run `check setup` in Claude Code to see which tool is missing, then
install from the links in [Section 1](#1-prerequisites--what-to-install).

**"Windows Subsystem for Linux has no installed distributions"**
You're running `bash install.sh` in PowerShell, which routes `bash` to
WSL. Either use Git Bash directly (Windows key → "Git Bash"), or call
Git Bash from PowerShell explicitly:
```powershell
& "C:\Program Files\Git\bin\bash.exe" install.sh
```

**Bootstrap skill says "project name required"**
You skipped the name prompt. Try again with *"bootstrap a new project
called <name>"*.

**`/ralph-go` refuses to run on main**
Intentional. Create a branch: `git checkout -b ralph/$(date +%Y%m%d)`.

**Pre-commit hook blocks a commit that should be fine**
Bypass with `git commit --no-verify` — but read the error first, it's
usually catching something real (secret leak, direct commit to main).

**Loop thrashes on one task**
Run *"deep audit"* to see if Claude can spot what's wrong. Usually the task
needs splitting or the verification command is wrong.

**Telegram notifications not arriving**
Check `~/.claude/operator.env` has both `TELEGRAM_BOT_TOKEN` and
`TELEGRAM_CHAT_ID` filled in, and that `curl` is installed. The loop
silently skips notifications if either is missing. Telegram credentials
are no longer read from per-project `.env.local` — they live in
`operator.env` only.

**New project doesn't have `specs/operator-context.md`**
Your `~/.claude/operator.env` wasn't set up (or was empty) when bootstrap
ran. Either delete the project and re-bootstrap after creating
`operator.env`, or create `specs/operator-context.md` manually using
`tools/operator.env.example` as a guide.

**Rate limit hit overnight**
That's fine. With `AUTO_RESUME_ON_429=1` (default), the loop sleeps until
the window resets and continues. Telegram will tell you it paused and
resumed.

---

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

## Resume After Time Away (A5)

The `resume-project` skill produces a "where did we leave off" briefing
when you return to a project after hours, days, or months. It aggregates
state from `LEARNINGS.md`, `progress.txt`, `specs/tasks.md`, git log, and
open PRs into a single structured report.

Trigger with any of: "resume", "where did we leave off", "project status",
"catch me up", "recap".

The briefing shows:
- Last activity (most recent commit, last iteration, current branch)
- Progress (N/M tasks done, percentage)
- Recently completed tasks (last 5 with timestamps)
- What's stuck (failure entries from `progress.txt`, last iteration outcome)
- Next up (first 5 unchecked tasks)
- Open PRs awaiting review
- Recent learnings worth re-reading
- Suggested next actions (rule-based)

For a Claude-analyzed briefing with richer suggestions, say "deep resume" —
costs API calls but reads all the state and gives you judgment-based advice.

The skill is strictly read-only. It tells you what you could do next; you
decide what to actually do.

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
