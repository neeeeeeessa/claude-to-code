#!/usr/bin/env bash
# ralph.sh — autonomous task execution loop
# Based on Geoffrey Huntley's Ralph Wiggum pattern, snarktank/ralph variant.
#
# Fresh context per iteration (state lives in git + LEARNINGS.md + progress.txt).
# One task per iteration. Verification command in each task is the backpressure.
# Draft PR per task. Operator reviews in the morning.
#
# Usage:
#   ./scripts/ralph/ralph.sh [preset]
#
# Presets (pick based on how much you trust the specs + your experience):
#   cautious  — first run on a new project, or first Ralph run ever
#               MAX_ITERATIONS=20  CONSECUTIVE_FAILURES=3
#   standard  — a few loops in, trust is reasonable          [default]
#               MAX_ITERATIONS=50  CONSECUTIVE_FAILURES=5
#   trusting  — solid specs, stable stack, let it grind
#               MAX_ITERATIONS=100 CONSECUTIVE_FAILURES=0 (no early exit)
#
# Override any setting via env var, e.g.:
#   MAX_ITERATIONS=30 ./scripts/ralph/ralph.sh cautious
#   AGENT_CMD="cursor-agent -p" ./scripts/ralph/ralph.sh

set -euo pipefail

# --- Preset selection ---------------------------------------------------------

PRESET="${1:-standard}"

case "$PRESET" in
  cautious)
    : "${MAX_ITERATIONS:=20}"
    : "${MAX_CONSECUTIVE_FAILURES:=3}"
    ;;
  standard)
    : "${MAX_ITERATIONS:=50}"
    : "${MAX_CONSECUTIVE_FAILURES:=5}"
    ;;
  trusting)
    : "${MAX_ITERATIONS:=100}"
    : "${MAX_CONSECUTIVE_FAILURES:=0}"  # 0 = no early exit on consecutive failures
    ;;
  *)
    echo "error: unknown preset '$PRESET'. use: cautious | standard | trusting" >&2
    exit 1
    ;;
esac

# --- Configuration (further overridable via env) ------------------------------

COMPLETION_PROMISE="${COMPLETION_PROMISE:-COMPLETE}"
TASK_PROMISE="${TASK_PROMISE:-TASK_DONE}"
PROMPT_FILE="${PROMPT_FILE:-scripts/ralph/prompt.md}"
LOG_DIR="${LOG_DIR:-.ralph-logs}"

# AGENT_CMD is what gets the prompt piped into it. Default is Claude Code.
# Swap for any agent CLI that accepts a prompt on stdin and runs autonomously:
#   claude --dangerously-skip-permissions -p       (Claude Code)
#   cursor-agent -p                                (Cursor)
#   codex -p --auto-edit                           (Codex)
#   gemini --yolo                                  (Gemini CLI)
AGENT_CMD="${AGENT_CMD:-claude --dangerously-skip-permissions -p}"

# --- Preflight checks ---------------------------------------------------------

# Extract the first word of AGENT_CMD for the "is it installed" check.
agent_bin="${AGENT_CMD%% *}"
if ! command -v "$agent_bin" >/dev/null 2>&1; then
  echo "error: agent binary '$agent_bin' not found on PATH." >&2
  echo "       set AGENT_CMD to the CLI you actually have installed." >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh CLI not found. install GitHub CLI first." >&2
  exit 1
fi

# Worktree requirement is non-negotiable. This is the security boundary for
# --dangerously-skip-permissions, not a trust setting. Losing it means a
# runaway loop could corrupt main.
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
  echo "error: refusing to run on $current_branch." >&2
  echo "       create a worktree or branch first:" >&2
  echo "         git worktree add ../\$(basename \$PWD)-ralph -b ralph/\$(date +%Y%m%d)" >&2
  echo "       or:" >&2
  echo "         git checkout -b ralph/\$(date +%Y%m%d)" >&2
  exit 1
fi

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "error: prompt file $PROMPT_FILE not found." >&2
  exit 1
fi

if [[ ! -f "specs/tasks.md" ]]; then
  echo "error: specs/tasks.md not found. run ingestion first." >&2
  exit 1
fi

mkdir -p "$LOG_DIR"

# --- The loop -----------------------------------------------------------------

iteration=0
consecutive_failures=0

echo "ralph: starting loop (preset: $PRESET)"
echo "  branch:               $current_branch"
echo "  max iterations:       $MAX_ITERATIONS"
echo "  consecutive fail cap: $MAX_CONSECUTIVE_FAILURES (0 = disabled)"
echo "  agent:                $AGENT_CMD"
echo "  prompt:               $PROMPT_FILE"
echo "  logs:                 $LOG_DIR/"
echo ""

while [[ $iteration -lt $MAX_ITERATIONS ]]; do
  iteration=$((iteration + 1))
  ts=$(date +%Y%m%d-%H%M%S)
  log_file="$LOG_DIR/iter-$(printf '%03d' $iteration)-$ts.log"

  echo "ralph: iteration $iteration/$MAX_ITERATIONS → $log_file"

  # Check if all tasks are already done before spawning a new agent.
  unchecked=$(grep -c '^- \[ \]' specs/tasks.md || true)
  if [[ "$unchecked" == "0" ]]; then
    echo "ralph: no unchecked tasks remain. done."
    exit 0
  fi

  # Fresh context: every iteration is a new agent invocation.
  set +e
  cat "$PROMPT_FILE" | $AGENT_CMD 2>&1 | tee "$log_file"
  set -e

  if grep -q "<promise>$COMPLETION_PROMISE</promise>" "$log_file"; then
    echo "ralph: completion promise detected. loop ending."
    exit 0
  fi

  if grep -q "<promise>$TASK_PROMISE</promise>" "$log_file"; then
    consecutive_failures=0
    echo "ralph: task completed, opening draft PR if new commits exist"
    if [[ -n "$(git log @{u}..HEAD 2>/dev/null || git log --oneline -1)" ]]; then
      gh pr create --draft --fill 2>/dev/null || true
    fi
  else
    consecutive_failures=$((consecutive_failures + 1))
    echo "ralph: no task-done signal (consecutive failures: $consecutive_failures)"
    if [[ $MAX_CONSECUTIVE_FAILURES -gt 0 && $consecutive_failures -ge $MAX_CONSECUTIVE_FAILURES ]]; then
      echo "ralph: $MAX_CONSECUTIVE_FAILURES consecutive failures. stopping for operator review."
      exit 2
    fi
  fi

  # Tiny pause so Ctrl-C works cleanly between iterations.
  sleep 1
done

echo "ralph: hit max iterations ($MAX_ITERATIONS). stopping."
echo "ralph: review progress in $LOG_DIR/, specs/tasks.md, and progress.txt"
exit 0
