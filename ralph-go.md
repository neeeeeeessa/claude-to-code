---
description: Start the autonomous Ralph loop. Usage: /ralph-go [cautious|standard|trusting]
---

Start the Ralph autonomous execution loop.

The user may have passed a preset (cautious / standard / trusting). If no
preset is given, default to standard and tell them you're doing so.

## Pre-flight checks

### 1. Branch check

We are on a `ralph/*` branch or worktree, not `main` or `master`. If on
main, stop and instruct the user to run:
`git checkout -b ralph/$(date +%Y%m%d)` or `git worktree add ...`.

### 2. Pre-commit hook active

`git config --get core.hooksPath` should return `.githooks`. If not,
instruct the user to run `git config core.hooksPath .githooks` first.

### 3. Spec validation

Delegate to the A3 `validate-specs` skill if installed. In order of preference:

**Option A — skill installed (preferred):**
```bash
bash ~/.claude/skills/validate-specs/validate.sh
```
Then interpret the exit code:
- Exit 0: all clean, proceed
- Exit 1: hard issues found, STOP and relay the report to the operator
- Exit 2: warnings only, proceed but mention what was flagged
- Exit 3: validator couldn't run, fall back to manual checks below

**Option B — skill not installed (fallback):**
Run basic manual checks:
- `specs/spec.md`, `specs/plan.md`, `specs/tasks.md`, and
  `.specify/memory/constitution.md` all exist and have real content
- Each task in `specs/tasks.md` has `Description`, `Acceptance`, and
  `Verify` sub-elements
- No task has a placeholder verify command like `# TODO` or `<...>`

If manual checks find problems, STOP and list them.

### 4. Operator confirmation

The operator understands this will run autonomously with
`--dangerously-skip-permissions` (or the equivalent flag for the configured
agent) until one of:
- All tasks are done
- The consecutive-failure cap is hit
- `MAX_ITERATIONS` is reached
- Claude session/weekly usage hits the stop threshold
- A rate limit occurs and `AUTO_RESUME_ON_429=0`

If this is their first Ralph run on this project, ask for a yes/no
confirmation before starting and recommend the `cautious` preset.

## Run the loop

If all pre-flight checks pass:

```bash
bash scripts/ralph/ralph.sh <preset>
```

Where `<preset>` is what the user passed (or `standard` if none).

## If any check fails

Explain the failure clearly and stop. Do not run the loop until the
operator has fixed the issue. For A3 failures, the validator output is
already human-readable — show it verbatim rather than re-summarizing.
