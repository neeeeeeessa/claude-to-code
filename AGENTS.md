# Agent Instructions

This file is the primary source of truth for any coding agent working in this
project — Claude Code, Cursor, Codex, Gemini CLI, Antigravity, or anything
else that reads `AGENTS.md`. It describes **who the operator is and how they
like to work**. It does **not** describe the product — that lives in `specs/`.

---

## Operator

Based in Amsterdam. GDPR and Dutch law are the defaults unless `specs/spec.md`
says otherwise. The operator cares about shipping, not about ceremony.

## Working Principles

- **Prefer well-established libraries over custom implementations.** When in
  doubt, pick the most-downloaded option on npm/PyPI that has had a release
  in the last six months. Don't reinvent.
- **TypeScript strict mode is on** for any TS project, always.
- **One task per iteration.** Small, focused commits. If a task wants to grow,
  split it.
- **Use `gh` CLI** for all PR operations. Draft PRs by default — they're the
  review gate, not the ship gate.
- **When uncertain, STOP and ask.** Do not guess. A blocked loop the operator
  can unblock in 30 seconds is better than a confident wrong implementation
  that takes an hour to unwind.

## Quality Gates (non-negotiable)

- Tests pass before any commit (enforced via pre-commit hook).
- Lint passes (eslint + prettier for JS/TS; ruff for Python; equivalents
  elsewhere).
- No secrets in code. Use `.env.local` and read from the environment.
- No direct commits to `main` — always via PR from a branch or worktree.

## Stack

**Decided per-project in `specs/plan.md`. Do not assume — read `plan.md` first.**

If `plan.md` is silent on a technical choice, stop and ask the operator rather
than reaching for a default. This is deliberate: the template has no stack
defaults because every project deserves the right tool, not the habitual one.

## How Work Flows Here

This project runs one of two patterns, and both read the same files:

### Pattern A — Autonomous loop (AFK)

`scripts/ralph/ralph.sh` runs the execution loop: picks the next unchecked
task from `specs/tasks.md`, implements it, verifies, commits, exits with
fresh context for the next iteration. Draft PR per task. Operator reviews
in the morning.

### Pattern B — Interactive (feature-at-a-time)

Operator opens Cursor / Claude Code / Codex / any IDE, tells the agent "do
the next task from `specs/tasks.md`," reviews as it goes, commits when done,
closes the session. No loop — just one task, supervised.

Both patterns use the same `specs/` structure and the same `- [x]` checkbox
state in `tasks.md`. You can switch between them mid-project; nothing gets
built twice.

## Reading Order for Every Session

When any agent starts a session in this project, read in this order:

1. `AGENTS.md` — this file (how the operator works)
2. `LEARNINGS.md` — accumulated discoveries from previous iterations
3. `progress.txt` — log of what was attempted recently
4. `.specify/memory/constitution.md` — project non-negotiables
5. `specs/spec.md` — what we're building
6. `specs/plan.md` — technical approach
7. `specs/tasks.md` — what to do next

## Files You Are Allowed To Modify

- `LEARNINGS.md` — append only (never rewrite existing entries)
- `progress.txt` — append only
- `specs/tasks.md` — only to flip `- [ ]` → `- [x]` when a task verifies
- Everything in the application code, per your task

## Files You Are NOT Allowed To Modify

- `AGENTS.md`, `CLAUDE.md` — operator-owned
- `.specify/memory/constitution.md` — operator-owned
- `specs/spec.md`, `specs/plan.md` — operator-owned, describe intent
- `scripts/ralph/*` — operator-owned, defines the loop itself
