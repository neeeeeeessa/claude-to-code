# Updating an existing clone

If you already have `claude-to-code` cloned and set up, and you're pulling
down a new version of this bundle, here's how to apply the update.

## What changed in this version

The pipeline now uses `~/.claude/operator.env` (operator-wide config) to
eliminate hardcoded operator identity from the template. Key changes:

- `AGENTS.md` no longer hardcodes any operator info (was "Based in
  Amsterdam. GDPR and Dutch law…")
- New file: `~/.claude/operator.env` holds name, location, jurisdiction,
  GitHub user, **and Telegram credentials** (all in one place, once per machine)
- `.env.local.example` no longer has Telegram — those moved to `operator.env`
- `bootstrap-project` skill now reads `operator.env` and snapshots identity
  into `specs/operator-context.md` on each new project
- `notify.sh` reads Telegram from `operator.env` (not from `.env.local`)
- `check-setup` (doctor) now checks for `operator.env` presence and warns
  if fields are empty

## How to apply the update

### 1. Replace the repo contents

You extracted `claude-to-code.zip` somewhere (let's call it `$EXTRACT`).
The files you have locally should be fully replaced by the extracted
version — no merging needed.

**If your local clone has no uncommitted work:**

```bash
# On Windows Git Bash; adjust paths for your system
cd /c/Users/simoe/Projects/claude-to-code

# Delete everything except the .git folder
# (this preserves commit history and remote config)
find . -mindepth 1 -not -path './.git*' -delete

# Copy in the new content
cp -r "$EXTRACT"/claude-to-code/. .

# Commit and push
git add -A
git commit -m "update: operator.env layer, cleaner template"
git push
```

**If you have uncommitted work** (you probably don't, since this is a
template repo): stash or commit it first.

### 2. Replace the installed skills

The skills in `~/.claude/skills/` need to be updated too. Re-run the
installer from the tools folder in your (now-updated) clone:

```bash
cd /c/Users/simoe/Projects/claude-to-code/tools
bash install.sh
```

The installer detects the existing skills and updates them in place.
Your bootstrap `.config` file (with your target folders and default
source) is preserved automatically.

### 3. Create `~/.claude/operator.env`

This is the new file. Two ways:

**Option A — let the bootstrap skill prompt you.**
The next time you say "bootstrap a new project" in Claude Code, the skill
will notice `operator.env` is missing and offer to create it interactively.

**Option B — create it now manually.**

```bash
mkdir -p ~/.claude
cp /c/Users/simoe/Projects/claude-to-code/tools/operator.env.example ~/.claude/operator.env
chmod 600 ~/.claude/operator.env

# Edit it with your info (nano, vim, Notepad, VS Code — whatever you prefer)
notepad ~/.claude/operator.env
# or
code ~/.claude/operator.env
```

Fill in at least:
- `OPERATOR_NAME`
- `OPERATOR_LOCATION`
- `OPERATOR_JURISDICTION`
- `GITHUB_USERNAME`
- `DEFAULT_TEMPLATE_REPO` (e.g. `neeeeeeessa/claude-to-code`)
- `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` (optional, for notifications)

### 4. Migrate Telegram credentials from any existing `.env.local`

If you'd set up Telegram in `.env.local` in a previous version, move
those two values:

```bash
# In any project where you had .env.local configured:
grep TELEGRAM .env.local
# Copy the TOKEN and CHAT_ID values into ~/.claude/operator.env

# You can now delete Telegram lines from .env.local — it no longer reads
# them (they're ignored silently in this version, but might as well clean up).
```

### 5. Verify

In Claude Code:

```
> check setup
```

You should see green checks across the board, including:

```
Operator configuration
  ✓ operator.env found at /home/you/.claude/operator.env
  ✓ telegram credentials set (operator-wide)
```

Now when you bootstrap a new project, the skill will automatically
generate `specs/operator-context.md` from your operator.env values.
Existing projects (created before this update) won't get
`operator-context.md` — that's fine, agents just fall back to universal
principles in `AGENTS.md`.

---

## Files you must create yourself (because they're gitignored)

The repo has `.gitignore` rules that exclude files containing personal
data or secrets. **You must create these yourself** on each machine or
for each project:

| File | Scope | Created by | Contains |
|---|---|---|---|
| `~/.claude/operator.env` | Machine-wide | You (or bootstrap wizard) | Identity + Telegram secrets |
| `<project>/.env.local` | Per project | You (only if you need loop overrides) | Loop behavior overrides |

All other files needed by the pipeline are in the repo and get copied
automatically when you clone or bootstrap.

## Files automatically generated (you don't create these)

| File | Scope | Generated when | Contains |
|---|---|---|---|
| `<project>/specs/operator-context.md` | Per project | Bootstrap creates new project | Snapshot of your identity at bootstrap time |
| `<project>/.ralph-logs/iter-*.log` | Per project | Ralph runs | Iteration logs |
| `<project>/progress.txt` | Per project | Ralph runs | Human-readable progress |
| `~/.claude/skills/*/config` | Per machine | Skills prompt on first run | Per-skill preferences |

## Troubleshooting the update

**"check setup" still shows operator.env missing after creating it**

Check the file path. On Windows Git Bash, `~/.claude/` resolves to
`/c/Users/<you>/.claude/`. Make sure the file is at:

```
C:\Users\<you>\.claude\operator.env
```

**Telegram stopped working after update**

Move your `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` from any project's
`.env.local` into `~/.claude/operator.env`. The loop no longer reads
Telegram credentials from `.env.local`.

**Bootstrap complains my existing `.config` is in a bad format**

The `.config` format changed slightly — `github_user` and `template_repo`
are no longer stored there (they're in `operator.env` now). Delete the
old `.config` and let the bootstrap skill recreate it:

```bash
rm ~/.claude/skills/bootstrap-project/.config
```

Next bootstrap run will recreate it with just the path-related fields.
