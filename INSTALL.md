# Installing the `validate-specs` skill

Claude Code skill that validates claude-to-code spec files before Ralph runs.
Installs once per machine.

## On the Windows laptop (Git Bash)

```bash
mkdir -p ~/.claude/skills/validate-specs

# Copy the three files into it:
#   - SKILL.md      (trigger definition)
#   - validate.sh   (fast structural + heuristic checks, always runs)
#   - llm-audit.sh  (optional deeper audit using Claude)

chmod +x ~/.claude/skills/validate-specs/validate.sh
chmod +x ~/.claude/skills/validate-specs/llm-audit.sh
```

## On the Unix machine (Mac or Linux)

```bash
mkdir -p ~/.claude/skills/validate-specs
# copy all three files into that directory
chmod +x ~/.claude/skills/validate-specs/*.sh
```

## Requirements

- `python3` on PATH (Git Bash on Windows usually has access to system Python;
  if not, install from python.org)
- `claude` CLI for the optional LLM audit (not needed for the fast validator)

## How it triggers

Three ways:

**1. Automatically by other skills.**

- A2 (`bootstrap-project`) runs it right after placing the spec files
- `/ralph-go` runs it as pre-flight before starting the loop

**2. Explicitly in Claude Code.**

Phrases like:
- "validate specs"
- "check specs"
- "are my specs ready"
- "audit specs"
- "spec quality check"
- "pre-flight check"

**3. Directly from a shell.**

```bash
bash ~/.claude/skills/validate-specs/validate.sh
# Exit code: 0 clean, 1 must fix, 2 warnings only, 3 not a project dir
```

## Exit codes

| Code | Meaning |
|------|---------|
| 0    | All checks pass. Ready for Ralph. |
| 1    | Hard issues found. Must fix before Ralph. |
| 2    | Only soft warnings. Safe to proceed. |
| 3    | Validator couldn't run (not a project dir, missing files). |

## Running the deeper LLM audit

```bash
bash ~/.claude/skills/validate-specs/llm-audit.sh
```

Or in Claude Code:
- "run deep audit"
- "llm audit"
- "semantic check on specs"

Costs ~30-60 seconds of API calls. Looks for constitution violations in the
plan, user stories not traced to tasks, stack contradictions, and other
semantic issues regex can't catch.

## Updating the skill

Replace files in `~/.claude/skills/validate-specs/` with new versions. No
config to preserve.

## Uninstalling

```bash
rm -rf ~/.claude/skills/validate-specs
```

When A3 is uninstalled:
- A2 (`bootstrap-project`) silently skips validation in its workflow
- `/ralph-go` falls back to manual checks for required files and task fields
