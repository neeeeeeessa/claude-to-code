---
description: Start the autonomous Ralph loop. Usage: /ralph-go [cautious|standard|trusting]
---

Start the Ralph autonomous execution loop.

The user may have passed a preset (cautious / standard / trusting). If no
preset is given, default to standard and tell them you're doing so.

**Before running, verify:**

1. We are on a `ralph/*` branch or worktree, not `main` or `master`. If on
   main, stop and instruct the user to run:
   `git checkout -b ralph/$(date +%Y%m%d)` or `git worktree add ...`.
2. `specs/spec.md`, `specs/plan.md`, and `specs/tasks.md` all exist and have
   real content (not the placeholder `specs/README.md`).
3. Each task in `specs/tasks.md` has a **verification command**. If any task
   is missing one, stop and list those tasks for the operator to fix.
4. The pre-commit hook is active: `git config --get core.hooksPath` should
   return `.githooks`. If not, instruct the user to run
   `git config core.hooksPath .githooks` first.
5. The operator understands this will run autonomously with
   `--dangerously-skip-permissions` (or the equivalent flag for the configured
   agent) until either all tasks are done, the consecutive-failure cap is hit,
   or MAX_ITERATIONS is reached.

**If all checks pass**, run:

```bash
bash scripts/ralph/ralph.sh <preset>
```

Where `<preset>` is the one the user passed (or `standard` if none).

**If this is their first Ralph run on this project**, ask for a yes/no
confirmation before starting and recommend the `cautious` preset.

**If any check fails**, explain the failure and stop. Do not run the loop
until the operator has fixed the issue.
