# Installing the `resume-project` skill

Claude Code skill that produces a "where did we leave off" briefing when
you come back to a project after time away.

## Install on Windows (Git Bash)

```bash
mkdir -p ~/.claude/skills/resume-project

# Copy into it:
#   - SKILL.md
#   - resume.sh       (fast deterministic briefing — always safe)
#   - deep-resume.sh  (optional Claude-analyzed briefing)

chmod +x ~/.claude/skills/resume-project/*.sh
```

## Install on Unix (Mac or Linux)

```bash
mkdir -p ~/.claude/skills/resume-project
# copy the three files into that directory
chmod +x ~/.claude/skills/resume-project/*.sh
```

## Requirements

- `git` — for log and branch info
- `gh` (optional) — for open PR listing; the briefing works without it
- `jq` (optional) — for cleaner PR formatting; falls back to raw `gh pr list` without it
- `claude` (optional) — only for the deep-resume variant

## How it triggers

In Claude Code, say one of:

- "resume"
- "where did we leave off"
- "project status"
- "status"
- "catch me up"
- "recap"
- "where am I on this"

For the deeper Claude-analyzed briefing:

- "deep resume"
- "smart resume"
- "suggest what's next"

Or run directly:

```bash
bash ~/.claude/skills/resume-project/resume.sh
# Optional deeper briefing:
bash ~/.claude/skills/resume-project/deep-resume.sh
```

## What it shows

- **Last activity** — most recent commit, most recent iteration entry, current branch
- **Progress** — tasks done / total, percentage
- **Recently completed** — last 5 task-tagged commits with timestamps
- **In progress / stuck** — failure entries from `progress.txt`, status of most recent iteration log
- **Next up** — first 5 unchecked tasks from `tasks.md`
- **Open PRs** — draft and non-draft PRs awaiting review (requires `gh`)
- **Recent learnings** — last 3 dated entries from `LEARNINGS.md`
- **Suggested next actions** — rule-based suggestions based on current state

## Deterministic vs deep

| | Deterministic (`resume.sh`) | Deep (`deep-resume.sh`) |
|---|---|---|
| Speed | Instant | ~30-60s |
| Cost | Free | Uses Claude API calls |
| Suggestions | Rule-based, predictable | Claude-judged, richer |
| Good for | Daily "where am I" checks | Returning after weeks away, or when things feel stuck |

## What it will NOT do

- Execute any action. This skill is strictly read-only.
- Merge PRs, resume loops, or run Ralph. It tells you what you could do;
  you decide what to do.
- Modify any files. Even LEARNINGS.md and progress.txt are only read.

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Report produced successfully |
| 3 | Not inside a claude-to-code project (missing `specs/tasks.md`) |

## Uninstall

```bash
rm -rf ~/.claude/skills/resume-project
```
