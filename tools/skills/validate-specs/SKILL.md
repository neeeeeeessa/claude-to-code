---
name: validate-specs
description: |
  Validates the claude-to-code spec files in the current project to catch
  problems before a Ralph loop wastes tokens on them. Use whenever the user
  wants to check specs are ready, audit their spec quality, or verify before
  starting a loop. Phrases that trigger this: "validate specs", "check specs",
  "are my specs ready", "audit specs", "spec quality check", "pre-flight
  check", "validate the specs". Also auto-invoked by /ralph-go and the
  bootstrap-project skill as a pre-flight. Reads specs/spec.md, specs/plan.md,
  specs/tasks.md, and .specify/memory/constitution.md. Produces a report of
  structural issues, heuristic warnings, and an overall verdict (pass / fix
  issues / warnings only). Exit code: 0 = clean, 1 = must fix, 2 = warnings only.
---

# Validate Specs Skill

Runs pre-flight validation on the current project's specs. This is the
cheap insurance that prevents Ralph loops from thrashing on under-specified
or ambiguous work.

## Steps

1. **Verify we are inside a claude-to-code project.**
   Check that `specs/tasks.md` exists in the current working directory.
   If not, tell the operator they need to `cd` into a project directory first.

2. **Run the validator script.**
   Execute `bash ~/.claude/skills/validate-specs/validate.sh` (Unix) or the
   equivalent path on Windows (`%USERPROFILE%\.claude\skills\validate-specs\validate.sh`
   via Git Bash).

   The script runs all structural and heuristic checks. It prints a full
   report and returns:
   - Exit 0: clean — ready for Ralph
   - Exit 1: hard issues found — must fix before Ralph
   - Exit 2: only soft warnings — safe to proceed but worth reviewing

3. **Relay the script output verbatim.**
   The validator's report is designed for humans. Don't re-interpret it —
   just show what it said and state the verdict clearly.

4. **If the operator wants a deeper check**, offer to run the LLM-based
   audit by executing `bash ~/.claude/skills/validate-specs/llm-audit.sh`.
   This is slower (uses API calls) and checks consistency between the
   constitution, plan, and tasks — things regex can't see. Only offer this
   if the operator explicitly asks for a deeper check or if the fast
   validator passes but the operator seems uncertain.
