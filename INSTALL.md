# Installing the `check-setup` skill

Claude Code skill that verifies your environment is ready to use the
claude-to-code pipeline. Run it on a new machine, after installing new
tools, or whenever something breaks mysteriously.

## Install on Windows (Git Bash)

```bash
mkdir -p ~/.claude/skills/check-setup

# Copy into it:
#   - SKILL.md
#   - doctor.sh

chmod +x ~/.claude/skills/check-setup/doctor.sh
```

## Install on Unix (Mac or Linux)

```bash
mkdir -p ~/.claude/skills/check-setup
# copy the two files into that directory
chmod +x ~/.claude/skills/check-setup/doctor.sh
```

## How it triggers

In Claude Code, say one of:

- "check setup"
- "doctor"
- "health check"
- "am I ready"
- "check dependencies"
- "verify install"
- "is everything installed"

Or run directly:

```bash
bash ~/.claude/skills/check-setup/doctor.sh
```

## What it checks

**Core (required):**
- bash, git, gh, claude, curl, python3

**Recommended (nice to have):**
- timeout (GNU coreutils), jq, pnpm

**Authentication:**
- `gh auth status`
- `claude /status` probe

**Installed skills** (in `~/.claude/skills/`):
- bootstrap-project, validate-specs, check-setup, resume-project

**Shell / OS compatibility:**
- Detects Git Bash on Windows, macOS, Linux, WSL
- Suggests `brew install coreutils` on macOS if `timeout` missing
- Notes when running native Windows without WSL

## Exit codes

| Code | Meaning |
|------|---------|
| 0    | All checks passed. Ready to use the pipeline. |
| 1    | Something required is missing. Pipeline will not work. |
| 2    | Only recommended items missing. Pipeline works. |

## What it will NOT do

- Install anything automatically. The report lists install commands but
  you run them. Installing system tools is out of scope for a skill.
- Configure auth. The report tells you to run `gh auth login` etc.
- Create repos, run Ralph, or touch your code. This skill is read-only.

## Uninstall

```bash
rm -rf ~/.claude/skills/check-setup
```
