---
name: check-setup
description: |
  Verifies the claude-to-code pipeline environment is fully set up and ready
  to use. Checks all required and recommended tools, Claude Code
  authentication, GitHub authentication, installed skills, and shell
  compatibility. Use whenever the user says "check setup", "am I ready",
  "doctor", "health check", "check dependencies", "verify install",
  "is everything installed", or anything similar. Also good to run after
  installing a new tool or before starting on a new laptop.
  Produces a report with an actionable "what to install" list for anything
  missing. Exits 0 if all required tools present, 1 if something required
  is missing.
---

# Check Setup (Doctor) Skill

Runs the claude-to-code setup health check.

## Steps

1. **Execute the doctor script.**
   Run `bash ~/.claude/skills/check-setup/doctor.sh` (on Unix) or the
   equivalent Windows path through Git Bash.

2. **Relay the output verbatim.**
   The doctor's report is designed for humans — don't re-summarize. Show
   it exactly.

3. **If items are missing, confirm the next actionable step.**
   The doctor lists install commands. Ask the operator if they'd like you
   to walk through any of them, but don't execute install commands without
   explicit permission — installing system tools is out of scope for the
   skill.

4. **If everything is green**, confirm:
   *"Setup is clean — you can bootstrap projects and run Ralph loops."*
