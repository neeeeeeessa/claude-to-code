---
name: resume-project
description: |
  Produces a "where did we leave off" briefing for the current claude-to-code
  project. Aggregates state from LEARNINGS.md, progress.txt, specs/tasks.md,
  git log, and open GitHub PRs to show what was done, what's in progress,
  what's stuck, and what could happen next. Use when coming back to a
  project after time away — hours, days, or months. Triggers on phrases
  like "resume", "where did we leave off", "project status", "status",
  "catch me up", "recap", "where am I on this". Exits cleanly with a
  structured report — does not execute any actions, only reports.
  Optional deeper briefing available via "deep resume" which uses Claude
  to propose specific next steps.
---

# Resume Project Skill

Produces a structured status briefing for the current claude-to-code project.

## Steps

1. **Verify we are inside a claude-to-code project.**
   Check that `specs/tasks.md` exists in the current directory. If not, tell
   the operator they need to `cd` into a project directory first.

2. **Run the resume script.**
   Execute `bash ~/.claude/skills/resume-project/resume.sh`. This produces
   the briefing using only local state and `gh` CLI — no API calls.

3. **If the operator asked for a deeper briefing** (phrases like "deep resume",
   "smart resume", "suggest what's next", or if they explicitly mention they
   want suggestions rather than just a report), also run
   `bash ~/.claude/skills/resume-project/deep-resume.sh` to get Claude's
   analysis of the state and proposed next actions.

4. **Relay the output verbatim.**
   The briefing is designed to be read directly — don't re-summarize. The
   operator knows their project better than you do; let them read the raw
   state and decide.

5. **Don't execute actions based on the briefing.**
   This skill is strictly read-only. Even if the briefing suggests "run
   /ralph-go" or "review PR #4", don't do those things automatically. Wait
   for explicit operator instruction.
