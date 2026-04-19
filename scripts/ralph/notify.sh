#!/usr/bin/env bash
# notify.sh — send Telegram notifications from the Ralph loop
#
# Usage:
#   notify.sh <event> [extra-args...]
#
# Events:
#   start <project> <preset> <tasks_total>
#   task_done <project> <task_id> <tasks_done> <tasks_total>
#   task_failed <project> <task_id> <consecutive_failures>
#   rate_limit_pause <project> <wait_minutes> <reason>
#   rate_limit_resume <project>
#   heartbeat <project> <runtime> <tasks_done> <tasks_total> <session_pct> <weekly_pct>
#   exit_success <project> <runtime> <tasks_done> <tasks_total> <repo_url>
#   exit_stopped <project> <runtime> <tasks_done> <tasks_total> <reason> <repo_url>
#
# Requires TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID in env or .env.local.
# Fails silently if either is missing — notifications are best-effort and
# must never break the loop.

set -uo pipefail

# --- Load credentials from layered config ------------------------------------
#
# Priority: .env.local (per-project) > ~/.claude/operator.env (operator-wide)
# Per-project can override operator-wide. If neither has Telegram credentials,
# notifications are silently disabled.

# 1. Operator-wide defaults
if [[ -f "$HOME/.claude/operator.env" ]]; then
  # shellcheck disable=SC1091
  set -a; . "$HOME/.claude/operator.env"; set +a
fi

# 2. Per-project overrides
if [[ -f .env.local ]]; then
  # shellcheck disable=SC1091
  set -a; . .env.local; set +a
fi

TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

if [[ -z "$TELEGRAM_BOT_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]]; then
  # Notifications disabled — exit cleanly, do not fail the loop.
  exit 0
fi

# curl is required to reach Telegram. If it's missing, skip silently rather
# than erroring. Notifications are strictly additive — their absence should
# never block the loop.
if ! command -v curl >/dev/null 2>&1; then
  exit 0
fi

# --- Format the message based on event type ----------------------------------

EVENT="${1:-}"
shift || true

case "$EVENT" in
  start)
    project="$1"; preset="$2"; tasks_total="$3"
    MESSAGE="▶ ${project}
starting · preset: ${preset} · ${tasks_total} tasks"
    ;;
  task_done)
    project="$1"; task_id="$2"; done="$3"; total="$4"
    MESSAGE="✓ ${project}
${task_id} complete · ${done}/${total}"
    ;;
  task_failed)
    project="$1"; task_id="$2"; fails="$3"
    MESSAGE="⚠ ${project}
${task_id} failed ${fails}x — loop continues"
    ;;
  rate_limit_pause)
    project="$1"; wait_min="$2"; reason="$3"
    MESSAGE="⏸ ${project}
rate limit: ${reason}
resuming in ${wait_min}m"
    ;;
  rate_limit_resume)
    project="$1"
    MESSAGE="▶ ${project}
resumed after rate limit"
    ;;
  heartbeat)
    project="$1"; runtime="$2"; done="$3"; total="$4"
    session_pct="${5:-?}"; weekly_pct="${6:-?}"
    MESSAGE="⏳ ${project} · ${runtime}
${done}/${total} done
session ${session_pct}% · weekly ${weekly_pct}%"
    ;;
  exit_success)
    project="$1"; runtime="$2"; done="$3"; total="$4"; repo="${5:-}"
    MESSAGE="✅ ${project}
COMPLETE · ${done}/${total} tasks · ${runtime}"
    if [[ -n "$repo" ]]; then
      MESSAGE="${MESSAGE}

review PRs: ${repo}/pulls"
    fi
    ;;
  exit_stopped)
    project="$1"; runtime="$2"; done="$3"; total="$4"; reason="$5"; repo="${6:-}"
    MESSAGE="⏹ ${project}
STOPPED: ${reason}
progress: ${done}/${total} · ${runtime}"
    if [[ -n "$repo" ]]; then
      MESSAGE="${MESSAGE}

partial PRs: ${repo}/pulls"
    fi
    ;;
  *)
    # Unknown event — silently ignore to avoid breaking the loop.
    exit 0
    ;;
esac

# --- Send the message --------------------------------------------------------

# Best-effort POST with a short timeout. Never fail the caller.
curl -s --max-time 10 \
  -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "text=${MESSAGE}" \
  >/dev/null 2>&1 || true

exit 0
