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
# Presets:
#   cautious  — first run on a new project, or first Ralph run ever
#               MAX_ITERATIONS=20  CONSECUTIVE_FAILURES=3
#   standard  — a few loops in, trust is reasonable          [default]
#               MAX_ITERATIONS=50  CONSECUTIVE_FAILURES=5
#   trusting  — solid specs, stable stack, let it grind
#               MAX_ITERATIONS=100 CONSECUTIVE_FAILURES=0 (no early exit)
#
# Environment overrides:
#   MAX_ITERATIONS              override preset default
#   MAX_CONSECUTIVE_FAILURES    override preset default (0 to disable)
#   AGENT_CMD                   agent CLI to invoke (default: claude -p ...)
#   SESSION_STOP_PCT            stop if session usage % reaches this (default 85)
#   WEEKLY_STOP_PCT             stop if weekly usage % reaches this (default 75)
#   AUTO_RESUME_ON_429          1 = pause+resume on rate limit (default 1)
#   HEARTBEAT_MINUTES           send heartbeat every N minutes (default 0 = off)
#   TELEGRAM_BOT_TOKEN          enables notifications (see notify.sh)
#   TELEGRAM_CHAT_ID            enables notifications (see notify.sh)

set -euo pipefail

# --- Load .env.local if present (for Telegram secrets) -----------------------

if [[ -f .env.local ]]; then
  set -a; . .env.local; set +a
fi

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
    : "${MAX_CONSECUTIVE_FAILURES:=0}"
    ;;
  *)
    echo "error: unknown preset '$PRESET'. use: cautious | standard | trusting" >&2
    exit 1
    ;;
esac

# --- Configuration -----------------------------------------------------------

COMPLETION_PROMISE="${COMPLETION_PROMISE:-COMPLETE}"
TASK_PROMISE="${TASK_PROMISE:-TASK_DONE}"
PROMPT_FILE="${PROMPT_FILE:-scripts/ralph/prompt.md}"
LOG_DIR="${LOG_DIR:-.ralph-logs}"
SESSION_STOP_PCT="${SESSION_STOP_PCT:-85}"
WEEKLY_STOP_PCT="${WEEKLY_STOP_PCT:-75}"
AUTO_RESUME_ON_429="${AUTO_RESUME_ON_429:-1}"
HEARTBEAT_MINUTES="${HEARTBEAT_MINUTES:-0}"
AGENT_CMD="${AGENT_CMD:-claude --dangerously-skip-permissions -p}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTIFY_SCRIPT="$SCRIPT_DIR/notify.sh"
USAGE_HELPERS="$SCRIPT_DIR/usage.sh"

# Source usage helpers
# shellcheck disable=SC1090
. "$USAGE_HELPERS"

# --- Preflight checks ---------------------------------------------------------

agent_bin="${AGENT_CMD%% *}"
if ! command -v "$agent_bin" >/dev/null 2>&1; then
  echo "error: agent binary '$agent_bin' not found on PATH." >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh CLI not found. install GitHub CLI first." >&2
  exit 1
fi

# curl is needed by notify.sh (Telegram notifications). Without it, notifications
# silently skip, which is fine — but warn once so the operator knows.
if ! command -v curl >/dev/null 2>&1; then
  echo "warn: curl not found. Telegram notifications will be silently skipped." >&2
fi

# 'timeout' is used by usage.sh to bound /status calls. On Git Bash and Linux
# it's available as 'timeout'; on macOS (without coreutils) as 'gtimeout' or
# not at all. We warn, then let usage.sh degrade gracefully if it's missing.
if ! command -v timeout >/dev/null 2>&1 && ! command -v gtimeout >/dev/null 2>&1; then
  echo "warn: 'timeout' not found. /status queries will not have a time bound." >&2
  echo "      (macOS: brew install coreutils; Windows Git Bash: should be present)" >&2
fi

current_branch=$(git rev-parse --abbrev-ref HEAD)
if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
  echo "error: refusing to run on $current_branch." >&2
  echo "       create a worktree or branch first:" >&2
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

# --- Helpers -----------------------------------------------------------------

# Best-effort notify (always exits 0, never blocks loop).
notify() {
  if [[ -f "$NOTIFY_SCRIPT" ]]; then
    bash "$NOTIFY_SCRIPT" "$@" || true
  fi
}

# Figure out the project name from git remote, for nicer notifications.
get_project_name() {
  local remote
  remote=$(git remote get-url origin 2>/dev/null || true)
  if [[ -n "$remote" ]]; then
    basename -s .git "$remote"
  else
    basename "$PWD"
  fi
}

get_repo_url() {
  local remote
  remote=$(git remote get-url origin 2>/dev/null || true)
  if [[ -z "$remote" ]]; then
    echo ""
    return
  fi
  # Convert git@github.com:user/repo.git or https://github.com/user/repo.git
  # to https://github.com/user/repo
  echo "$remote" \
    | sed -e 's|git@github\.com:|https://github.com/|' \
    | sed -e 's|\.git$||'
}

count_tasks() {
  local total done_count
  total=$(grep -cE '^- \[[ x]\]' specs/tasks.md 2>/dev/null || echo 0)
  done_count=$(grep -cE '^- \[x\]' specs/tasks.md 2>/dev/null || echo 0)
  echo "$done_count $total"
}

# Extract task ID from iteration log (e.g. T008) for notifications.
# Looks for "TNNN" patterns in the log.
extract_task_id() {
  local log_file="$1"
  grep -oE 'T[0-9]{3}' "$log_file" 2>/dev/null | head -1 || true
}

# --- Initialize --------------------------------------------------------------

PROJECT_NAME=$(get_project_name)
REPO_URL=$(get_repo_url)
START_TIME=$(date +%s)
LAST_NOTIFY_TIME=$START_TIME

iteration=0
consecutive_failures=0

read -r tasks_done_initial tasks_total <<< "$(count_tasks)"

echo "ralph: starting loop (preset: $PRESET)"
echo "  project:              $PROJECT_NAME"
echo "  branch:               $current_branch"
echo "  max iterations:       $MAX_ITERATIONS"
echo "  consecutive fail cap: $MAX_CONSECUTIVE_FAILURES (0 = disabled)"
echo "  agent:                $AGENT_CMD"
echo "  session cap:          ${SESSION_STOP_PCT}%"
echo "  weekly cap:           ${WEEKLY_STOP_PCT}%"
echo "  auto-resume on 429:   $AUTO_RESUME_ON_429"
echo "  heartbeat interval:   ${HEARTBEAT_MINUTES}m (0 = off)"
echo "  logs:                 $LOG_DIR/"
echo ""

notify start "$PROJECT_NAME" "$PRESET" "$tasks_total"

# --- Heartbeat scheduler -----------------------------------------------------

# Send a heartbeat notification if enough time has passed since the last
# outbound message. Called after each iteration.
maybe_heartbeat() {
  [[ "$HEARTBEAT_MINUTES" -le 0 ]] && return 0

  local now elapsed
  now=$(date +%s)
  elapsed=$((now - LAST_NOTIFY_TIME))
  local threshold=$((HEARTBEAT_MINUTES * 60))

  if [[ $elapsed -ge $threshold ]]; then
    local runtime_s=$((now - START_TIME))
    local runtime; runtime=$(format_runtime "$runtime_s")
    read -r done_count total <<< "$(count_tasks)"
    local session_pct weekly_pct
    local status_out; status_out=$(query_status)
    session_pct=$(get_session_pct "$status_out")
    weekly_pct=$(get_weekly_pct "$status_out")
    notify heartbeat "$PROJECT_NAME" "$runtime" "$done_count" "$total" \
      "${session_pct:-?}" "${weekly_pct:-?}"
    LAST_NOTIFY_TIME=$now
  fi
}

# --- Pre-iteration limit check -----------------------------------------------

# Before each iteration, check whether we should stop pre-emptively.
# Returns 0 if OK to proceed, 1 if we should stop (and prints reason).
check_limits_before_iteration() {
  # Only query Claude Code; skip for other agents.
  local agent_bin="${AGENT_CMD%% *}"
  if [[ "$agent_bin" != "claude" ]]; then
    return 0
  fi

  # Only poll /status occasionally — it costs tokens too.
  # Check on iteration 1, then every 5th iteration.
  if [[ "$iteration" -ne 1 ]] && [[ $((iteration % 5)) -ne 0 ]]; then
    return 0
  fi

  local status_out; status_out=$(query_status)
  local session_pct; session_pct=$(get_session_pct "$status_out")
  local weekly_pct;  weekly_pct=$(get_weekly_pct "$status_out")

  # Save for later use in this iteration
  CURRENT_SESSION_PCT="$session_pct"
  CURRENT_WEEKLY_PCT="$weekly_pct"

  local reason
  if reason=$(should_stop_for_limit "$session_pct" "$weekly_pct"); then
    echo "ralph: stopping pre-emptively — $reason"
    local runtime; runtime=$(format_runtime "$(($(date +%s) - START_TIME))")
    read -r done_count total <<< "$(count_tasks)"
    notify exit_stopped "$PROJECT_NAME" "$runtime" "$done_count" "$total" \
      "$reason" "$REPO_URL"
    return 1
  fi
  return 0
}

# --- The loop -----------------------------------------------------------------

CURRENT_SESSION_PCT=""
CURRENT_WEEKLY_PCT=""

while [[ $iteration -lt $MAX_ITERATIONS ]]; do
  iteration=$((iteration + 1))
  ts=$(date +%Y%m%d-%H%M%S)
  log_file="$LOG_DIR/iter-$(printf '%03d' $iteration)-$ts.log"

  echo "ralph: iteration $iteration/$MAX_ITERATIONS → $log_file"

  # Early termination: all tasks done?
  read -r done_count total <<< "$(count_tasks)"
  if [[ "$done_count" == "$total" && "$total" -gt 0 ]]; then
    echo "ralph: all $total tasks complete. done."
    local runtime; runtime=$(format_runtime "$(($(date +%s) - START_TIME))")
    notify exit_success "$PROJECT_NAME" "$runtime" "$done_count" "$total" "$REPO_URL"
    exit 0
  fi

  # Check rate limits before spending tokens.
  if ! check_limits_before_iteration; then
    exit 3
  fi

  # Fresh context: every iteration is a new agent invocation.
  set +e
  cat "$PROMPT_FILE" | $AGENT_CMD 2>&1 | tee "$log_file"
  agent_exit=${PIPESTATUS[1]}
  set -e

  # --- Handle rate limit in the response ---
  if detect_rate_limit "$log_file" >/dev/null 2>&1; then
    wait_seconds=$(detect_rate_limit "$log_file")
    wait_minutes=$(( (wait_seconds + 59) / 60 ))
    echo "ralph: rate limit detected. wait time: ${wait_minutes}m"

    # Extract tokens for logging before we pause
    tokens=$(extract_tokens "$log_file" || true)
    ti="${tokens%% *}"; to="${tokens##* }"
    append_usage_log "$iteration" "${ti:-}" "${to:-}" \
      "$CURRENT_SESSION_PCT" "$CURRENT_WEEKLY_PCT" "rate_limited"

    if [[ "$AUTO_RESUME_ON_429" == "1" ]]; then
      notify rate_limit_pause "$PROJECT_NAME" "$wait_minutes" "claude usage cap"
      LAST_NOTIFY_TIME=$(date +%s)
      echo "ralph: sleeping ${wait_seconds}s"
      sleep "$wait_seconds"
      notify rate_limit_resume "$PROJECT_NAME"
      LAST_NOTIFY_TIME=$(date +%s)
      append_usage_log "$iteration" "" "" "" "" "resumed"
      # Retry the same iteration on next loop pass by decrementing counter
      iteration=$((iteration - 1))
      continue
    else
      echo "ralph: AUTO_RESUME_ON_429=0, stopping."
      local runtime; runtime=$(format_runtime "$(($(date +%s) - START_TIME))")
      read -r done_count total <<< "$(count_tasks)"
      notify exit_stopped "$PROJECT_NAME" "$runtime" "$done_count" "$total" \
        "rate limit, auto-resume disabled" "$REPO_URL"
      exit 4
    fi
  fi

  # --- Completion promise? ---
  if grep -q "<promise>$COMPLETION_PROMISE</promise>" "$log_file"; then
    echo "ralph: completion promise detected. loop ending."
    read -r done_count total <<< "$(count_tasks)"
    local runtime; runtime=$(format_runtime "$(($(date +%s) - START_TIME))")
    notify exit_success "$PROJECT_NAME" "$runtime" "$done_count" "$total" "$REPO_URL"
    exit 0
  fi

  # --- Task promise? ---
  tokens=$(extract_tokens "$log_file" || true)
  ti="${tokens%% *}"; to="${tokens##* }"

  if grep -q "<promise>$TASK_PROMISE</promise>" "$log_file"; then
    consecutive_failures=0
    task_id=$(extract_task_id "$log_file")
    read -r done_count total <<< "$(count_tasks)"

    append_usage_log "$iteration" "${ti:-}" "${to:-}" \
      "$CURRENT_SESSION_PCT" "$CURRENT_WEEKLY_PCT" "task_done"

    echo "ralph: task ${task_id:-?} completed ($done_count/$total)"
    notify task_done "$PROJECT_NAME" "${task_id:-task}" "$done_count" "$total"
    LAST_NOTIFY_TIME=$(date +%s)

    # Open draft PR for new commits
    if [[ -n "$(git log @{u}..HEAD 2>/dev/null || git log --oneline -1)" ]]; then
      gh pr create --draft --fill 2>/dev/null || true
    fi
  else
    consecutive_failures=$((consecutive_failures + 1))
    task_id=$(extract_task_id "$log_file")

    append_usage_log "$iteration" "${ti:-}" "${to:-}" \
      "$CURRENT_SESSION_PCT" "$CURRENT_WEEKLY_PCT" "task_failed"

    echo "ralph: no task-done signal (consecutive failures: $consecutive_failures)"

    # Notify on meaningful failure milestone (3+ consecutive failures)
    if [[ $consecutive_failures -ge 3 ]]; then
      notify task_failed "$PROJECT_NAME" "${task_id:-task}" "$consecutive_failures"
      LAST_NOTIFY_TIME=$(date +%s)
    fi

    if [[ $MAX_CONSECUTIVE_FAILURES -gt 0 && $consecutive_failures -ge $MAX_CONSECUTIVE_FAILURES ]]; then
      echo "ralph: $MAX_CONSECUTIVE_FAILURES consecutive failures. stopping."
      read -r done_count total <<< "$(count_tasks)"
      local runtime; runtime=$(format_runtime "$(($(date +%s) - START_TIME))")
      notify exit_stopped "$PROJECT_NAME" "$runtime" "$done_count" "$total" \
        "${MAX_CONSECUTIVE_FAILURES} consecutive failures" "$REPO_URL"
      exit 2
    fi
  fi

  # Heartbeat check
  maybe_heartbeat

  sleep 1
done

echo "ralph: hit max iterations ($MAX_ITERATIONS). stopping."
read -r done_count total <<< "$(count_tasks)"
runtime=$(format_runtime "$(($(date +%s) - START_TIME))")
notify exit_stopped "$PROJECT_NAME" "$runtime" "$done_count" "$total" \
  "max iterations ($MAX_ITERATIONS)" "$REPO_URL"
exit 0
