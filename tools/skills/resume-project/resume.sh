#!/usr/bin/env bash
# resume.sh — "where did we leave off" briefing for the current project
#
# Aggregates state from:
#   - specs/tasks.md       (task completion state)
#   - LEARNINGS.md          (accumulated knowledge)
#   - progress.txt          (recent iteration history)
#   - .ralph-logs/          (iteration logs if present)
#   - git log               (commit history)
#   - gh pr list            (open PRs)
#
# Read-only. Never modifies state.

set -uo pipefail

# --- Preflight ---------------------------------------------------------------

if [[ ! -f "specs/tasks.md" ]]; then
  echo "error: specs/tasks.md not found." >&2
  echo "       are you inside a claude-to-code project directory?" >&2
  exit 3
fi

# --- ANSI colors -------------------------------------------------------------

if [[ -t 1 ]]; then
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  BLUE=$'\033[0;34m'
  RESET=$'\033[0m'
else
  BOLD="" ; DIM="" ; GREEN="" ; YELLOW="" ; BLUE="" ; RESET=""
fi

section() { printf "\n${BOLD}%s${RESET}\n" "$1"; }

# --- Project identity --------------------------------------------------------

project_name() {
  local remote
  remote=$(git remote get-url origin 2>/dev/null || true)
  if [[ -n "$remote" ]]; then
    basename -s .git "$remote"
  else
    basename "$PWD"
  fi
}

repo_url() {
  local remote
  remote=$(git remote get-url origin 2>/dev/null || true)
  if [[ -z "$remote" ]]; then
    echo ""
    return
  fi
  echo "$remote" | sed -e 's|git@github\.com:|https://github.com/|' -e 's|\.git$||'
}

# --- Time-ago formatter ------------------------------------------------------

# Seconds-since-epoch → "3 days ago" / "2h ago" / "just now"
time_ago() {
  local then="$1"
  local now; now=$(date +%s)
  local diff=$((now - then))

  if [[ $diff -lt 60 ]]; then echo "just now"
  elif [[ $diff -lt 3600 ]]; then echo "$((diff / 60))m ago"
  elif [[ $diff -lt 86400 ]]; then echo "$((diff / 3600))h ago"
  elif [[ $diff -lt 604800 ]]; then echo "$((diff / 86400))d ago"
  elif [[ $diff -lt 2592000 ]]; then echo "$((diff / 604800))w ago"
  else echo "$((diff / 2592000))mo ago"
  fi
}

# --- Start -------------------------------------------------------------------

PROJECT=$(project_name)
REPO=$(repo_url)
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")

printf "${BOLD}Claude-to-Code project status: %s${RESET}\n" "$PROJECT"
printf "${DIM}%s${RESET}\n" "$(date)"

# --- Last activity -----------------------------------------------------------

section "Last activity"

# Find last commit
LAST_COMMIT_TS=$(git log -1 --format="%ct" 2>/dev/null || echo "")
if [[ -n "$LAST_COMMIT_TS" ]]; then
  LAST_COMMIT_MSG=$(git log -1 --format="%s" 2>/dev/null || echo "")
  printf "  Last commit: %s %s\"%s\"%s\n" \
    "$(time_ago "$LAST_COMMIT_TS")" "$DIM" "$LAST_COMMIT_MSG" "$RESET"
fi

# Find last progress.txt entry
if [[ -f "progress.txt" ]]; then
  LAST_PROGRESS=$(grep -E '^\[[0-9]{4}-[0-9]{2}-[0-9]{2}' progress.txt 2>/dev/null | tail -1 || true)
  if [[ -n "$LAST_PROGRESS" ]]; then
    printf "  Last iteration: %s%s%s\n" "$DIM" "$LAST_PROGRESS" "$RESET"
  fi
fi

printf "  Current branch: %s%s%s\n" "$BLUE" "$BRANCH" "$RESET"
if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
  printf "  %s! on main — create a ralph branch before running the loop%s\n" "$YELLOW" "$RESET"
fi

# --- Progress ----------------------------------------------------------------

section "Progress"

if [[ -f "specs/tasks.md" ]]; then
  TOTAL=$(grep -cE '^- \[[ x]\]' specs/tasks.md 2>/dev/null | tr -d ' \n' || echo 0)
  DONE=$(grep -cE '^- \[x\]' specs/tasks.md 2>/dev/null | tr -d ' \n' || echo 0)
  TOTAL="${TOTAL:-0}"
  DONE="${DONE:-0}"
  REMAINING=$((TOTAL - DONE))

  if [[ "$TOTAL" -gt 0 ]]; then
    PCT=$((DONE * 100 / TOTAL))
    printf "  %s%d/%d tasks complete (%d%%)%s\n" "$BOLD" "$DONE" "$TOTAL" "$PCT" "$RESET"
  else
    printf "  ${DIM}no tasks parsed from tasks.md${RESET}\n"
  fi
fi

# --- Recently completed tasks -----------------------------------------------

if [[ -f "specs/tasks.md" ]] && [[ "${DONE:-0}" -gt 0 ]]; then
  section "Recently completed (last 5 by commit order)"

  # Use git log to find the most recent commits that look like they reference
  # task IDs. The prompt asks Ralph to commit as "<task-id>: <what you did>".
  RECENT_TASKS=$(git log --format="%ct|%s" -50 2>/dev/null \
    | grep -iE 'T[0-9]{3}' \
    | head -5 || true)

  if [[ -n "$RECENT_TASKS" ]]; then
    while IFS='|' read -r ts msg; do
      [[ -z "$ts" ]] && continue
      when=$(time_ago "$ts")
      printf "  ${GREEN}✓${RESET} %s ${DIM}(%s)${RESET}\n" "$msg" "$when"
    done <<< "$RECENT_TASKS"
  else
    printf "  ${DIM}no task-tagged commits found${RESET}\n"
  fi
fi

# --- In-progress / stuck -----------------------------------------------------

section "In progress / stuck"

# Look for recent failure entries in progress.txt
STUCK_REPORTED=0
if [[ -f "progress.txt" ]]; then
  RECENT_FAILURES=$(grep -iE 'failed|blocked|error|stuck|stopped' progress.txt 2>/dev/null | tail -3 || true)
  if [[ -n "$RECENT_FAILURES" ]]; then
    STUCK_REPORTED=1
    while IFS= read -r line; do
      printf "  ${YELLOW}!${RESET} %s\n" "$line"
    done <<< "$RECENT_FAILURES"
  fi
fi

# Check .ralph-logs for last iteration status
if [[ -d ".ralph-logs" ]]; then
  LAST_LOG=$(ls -t .ralph-logs/iter-*.log 2>/dev/null | head -1 || true)
  if [[ -n "$LAST_LOG" ]]; then
    LAST_LOG_TS=$(stat -c '%Y' "$LAST_LOG" 2>/dev/null || stat -f '%m' "$LAST_LOG" 2>/dev/null || echo 0)
    printf "  Last iter log: %s ${DIM}(%s)${RESET}\n" "$LAST_LOG" "$(time_ago "$LAST_LOG_TS")"
    if grep -q "<promise>TASK_DONE</promise>" "$LAST_LOG" 2>/dev/null; then
      printf "  ${GREEN}✓${RESET} last iteration completed cleanly\n"
    elif grep -qiE 'rate.?limit|429' "$LAST_LOG" 2>/dev/null; then
      printf "  ${YELLOW}!${RESET} last iteration hit a rate limit\n"
      STUCK_REPORTED=1
    elif grep -q "<promise>COMPLETE</promise>" "$LAST_LOG" 2>/dev/null; then
      printf "  ${GREEN}✓${RESET} last iteration emitted COMPLETE (loop finished)\n"
    else
      printf "  ${YELLOW}!${RESET} last iteration did not emit a success promise\n"
      STUCK_REPORTED=1
    fi
  fi
fi

if [[ "$STUCK_REPORTED" == "0" ]]; then
  printf "  ${DIM}nothing flagged as stuck${RESET}\n"
fi

# --- Next up in tasks.md -----------------------------------------------------

if [[ -f "specs/tasks.md" ]] && [[ "${REMAINING:-0}" -gt 0 ]]; then
  section "Next up (first 5 unchecked)"

  # Extract unchecked tasks, strip the checkbox and bold markers, show first 5.
  grep -E '^- \[ \]' specs/tasks.md | head -5 | while IFS= read -r line; do
    # Strip "- [ ] " prefix (6 chars)
    line="${line#- \[ \] }"
    # Strip surrounding ** ** bold markers (if the whole thing is wrapped)
    line="${line#\*\*}"
    line="${line%\*\*}"
    # Also handle cases where ** appears at the end after a colon
    line="${line//\*\*/}"
    printf "  ${BLUE}☐${RESET} %s\n" "$line"
  done
fi

# --- Open PRs ----------------------------------------------------------------

if command -v gh >/dev/null 2>&1 && [[ -n "$REPO" ]]; then
  section "Open PRs awaiting review"
  PR_LIST=$(gh pr list --state open --limit 10 --json number,title,isDraft,updatedAt 2>/dev/null || echo "")
  if [[ -z "$PR_LIST" || "$PR_LIST" == "[]" ]]; then
    printf "  ${DIM}none${RESET}\n"
  elif command -v jq >/dev/null 2>&1; then
    # Use jq for clean formatting
    echo "$PR_LIST" | jq -r '.[] | "  #\(.number) \(.title)|\(.isDraft)|\(.updatedAt)"' \
      | while IFS='|' read -r prline isdraft updated; do
        tag=""
        if [[ "$isdraft" == "true" ]]; then tag=" ${DIM}[draft]${RESET}"; fi
        when=""
        if [[ -n "$updated" ]]; then
          # Parse ISO datetime to epoch (GNU date vs macOS date are different)
          if ts=$(date -d "$updated" +%s 2>/dev/null); then
            when=" ${DIM}($(time_ago "$ts"))${RESET}"
          elif ts=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$updated" +%s 2>/dev/null); then
            when=" ${DIM}($(time_ago "$ts"))${RESET}"
          fi
        fi
        printf "%s%s%s\n" "$prline" "$tag" "$when"
      done
  else
    # No jq — simpler output
    gh pr list --state open --limit 10 2>/dev/null | while IFS= read -r line; do
      printf "  %s\n" "$line"
    done
  fi
fi

# --- Recent learnings --------------------------------------------------------

if [[ -f "LEARNINGS.md" ]]; then
  # Count entries (look for date-stamped lines)
  LEARNINGS_COUNT=$(grep -cE '^\s*-.*\[[0-9]{4}-[0-9]{2}-[0-9]{2}\]' LEARNINGS.md 2>/dev/null || echo 0)
  if [[ "$LEARNINGS_COUNT" -gt 0 ]]; then
    section "Recent learnings worth reading (most recent 3)"
    grep -E '^\s*-.*\[[0-9]{4}-[0-9]{2}-[0-9]{2}\]' LEARNINGS.md 2>/dev/null | tail -3 | while IFS= read -r line; do
      printf "  %s\n" "$line"
    done
  fi
fi

# --- Suggested next actions (deterministic) ---------------------------------

section "Suggested next actions"

# Rule-based suggestions — not magic, just heuristics on state.
# 1. If on main → create a ralph branch
# 2. If open draft PRs → review them
# 3. If last iter hit rate limit → wait or switch preset
# 4. If last iter failed without success promise → investigate manually
# 5. If all tasks done → review and merge PRs
# 6. Otherwise → run the loop

printed_suggestion=0

if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
  printf "  ${BLUE}→${RESET} Create a working branch: ${BOLD}git checkout -b ralph/resume-\$(date +%%Y%%m%%d)${RESET}\n"
  printed_suggestion=1
fi

if [[ "${TOTAL:-0}" -eq 0 ]]; then
  printf "  ${BLUE}→${RESET} No tasks parsed. Check ${BOLD}specs/tasks.md${RESET} format.\n"
  printed_suggestion=1
elif [[ "${DONE:-0}" == "${TOTAL:-0}" ]]; then
  printf "  ${BLUE}→${RESET} All tasks complete. Review open PRs and merge what's good.\n"
  printed_suggestion=1
elif [[ "$STUCK_REPORTED" == "1" ]]; then
  printf "  ${BLUE}→${RESET} Review the last iteration log before resuming: ${BOLD}cat %s${RESET}\n" "${LAST_LOG:-.ralph-logs/iter-*.log}"
  printf "  ${BLUE}→${RESET} If it was a rate limit, wait or lower ${BOLD}SESSION_STOP_PCT${RESET}.\n"
  printf "  ${BLUE}→${RESET} If a task keeps failing, consider splitting it in ${BOLD}specs/tasks.md${RESET}.\n"
  printed_suggestion=1
else
  printf "  ${BLUE}→${RESET} Resume the loop: ${BOLD}/ralph-go cautious${RESET} (or standard/trusting)\n"
  printf "  ${BLUE}→${RESET} Or work interactively on the next task in your IDE.\n"
  printed_suggestion=1
fi

# Always offer the deep option
printf "\n  ${DIM}For Claude's take on this project's state: say \"deep resume\"${RESET}\n"

echo ""
exit 0
