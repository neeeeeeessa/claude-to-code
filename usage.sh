#!/usr/bin/env bash
# usage.sh — Claude Code session/weekly limit tracking and 429 detection
#
# This file provides functions sourced by ralph.sh. Not meant to be run directly.
#
# Exposes:
#   query_status()          — runs `claude /status`, returns parseable output
#   get_session_pct()       — parses session usage % from /status output
#   get_weekly_pct()        — parses weekly usage % from /status output
#   extract_tokens()        — parses token counts from an iteration log
#   detect_rate_limit()     — returns 0 if rate limit hit, prints wait seconds
#   should_stop_for_limit() — returns 0 if we should stop pre-emptively
#   append_usage_log()      — writes a JSON-Lines entry to .ralph-logs/usage.jsonl

# --- /status parsing ---------------------------------------------------------

# Calls `claude /status` and returns its output. Silently returns empty if
# the agent isn't Claude Code or /status isn't available.
query_status() {
  # Only Claude Code has /status. Skip for other agents.
  local agent_bin="${AGENT_CMD%% *}"
  if [[ "$agent_bin" != "claude" ]]; then
    return 0
  fi

  # Run in non-interactive mode with a short timeout.
  # Claude /status output typically includes lines like:
  #   Session usage: 34% (2h 14m remaining)
  #   Weekly usage: 12%
  # We're tolerant of format changes — we look for the words loosely.
  timeout 30 claude -p "/status" 2>/dev/null || true
}

# Parses session usage percentage from /status output. Outputs a bare integer
# (e.g. "34") or empty string if unparseable.
get_session_pct() {
  local status_output="$1"
  # Match: "session" (case-insensitive) ... number followed by %
  echo "$status_output" \
    | grep -iE 'session' \
    | grep -oE '[0-9]+%' \
    | head -1 \
    | tr -d '%' \
    || true
}

get_weekly_pct() {
  local status_output="$1"
  echo "$status_output" \
    | grep -iE 'weekly|week' \
    | grep -oE '[0-9]+%' \
    | head -1 \
    | tr -d '%' \
    || true
}

# --- Token extraction from iteration logs ------------------------------------

# Claude Code prints a "Usage:" or "Tokens:" line at end of -p runs.
# We extract input and output token counts if present.
# Output format: "INPUT OUTPUT" (space-separated), empty if not found.
extract_tokens() {
  local log_file="$1"
  # Try common patterns: "Input: N", "N input tokens", "in: N", etc.
  local input output
  input=$(grep -iE 'input.*tokens?|tokens?.*input' "$log_file" 2>/dev/null \
    | grep -oE '[0-9]+' | head -1 || true)
  output=$(grep -iE 'output.*tokens?|tokens?.*output' "$log_file" 2>/dev/null \
    | grep -oE '[0-9]+' | head -1 || true)
  if [[ -n "$input" || -n "$output" ]]; then
    echo "${input:-0} ${output:-0}"
  fi
}

# --- Rate limit detection ----------------------------------------------------

# Scans an iteration log for rate limit indicators.
# Returns:
#   0 if rate limit detected — prints wait seconds to stdout
#   1 if no rate limit
detect_rate_limit() {
  local log_file="$1"

  # Patterns that indicate rate limit from Claude Code:
  #   "rate limit"
  #   "Rate limit reached"
  #   "429"
  #   "retry-after" header value
  if ! grep -iE 'rate.?limit|429|too.?many.?requests' "$log_file" >/dev/null 2>&1; then
    return 1
  fi

  # Try to extract wait time from retry-after header or explicit wait message.
  # Defaults to 5 minutes if we can't determine.
  local wait_seconds
  wait_seconds=$(grep -iE 'retry.?after[^0-9]*([0-9]+)' "$log_file" 2>/dev/null \
    | grep -oE '[0-9]+' | head -1 || true)

  if [[ -z "$wait_seconds" ]]; then
    # Check for "reset in X minutes" or "wait X minutes"
    local minutes
    minutes=$(grep -iE '(reset|wait).*([0-9]+).*minute' "$log_file" 2>/dev/null \
      | grep -oE '[0-9]+' | head -1 || true)
    if [[ -n "$minutes" ]]; then
      wait_seconds=$((minutes * 60))
    fi
  fi

  # Fallback: 5 minutes
  echo "${wait_seconds:-300}"
  return 0
}

# --- Pre-emptive stop check --------------------------------------------------

# Returns 0 if we should stop pre-emptively because we're approaching limits.
# Prints the reason to stdout.
should_stop_for_limit() {
  local session_pct="$1"
  local weekly_pct="$2"
  local session_stop="${SESSION_STOP_PCT:-85}"
  local weekly_stop="${WEEKLY_STOP_PCT:-75}"

  if [[ -n "$session_pct" ]] && [[ "$session_pct" -ge "$session_stop" ]]; then
    echo "session usage at ${session_pct}% (cap: ${session_stop}%)"
    return 0
  fi
  if [[ -n "$weekly_pct" ]] && [[ "$weekly_pct" -ge "$weekly_stop" ]]; then
    echo "weekly usage at ${weekly_pct}% (cap: ${weekly_stop}%)"
    return 0
  fi
  return 1
}

# --- Structured usage log ----------------------------------------------------

# Append a JSON-Lines entry to .ralph-logs/usage.jsonl with the current
# iteration's usage info. Fields are all optional — empty ones are omitted.
append_usage_log() {
  local iteration="$1"
  local input_tokens="$2"
  local output_tokens="$3"
  local session_pct="$4"
  local weekly_pct="$5"
  local outcome="$6"  # "task_done" | "task_failed" | "rate_limited" | "resumed"

  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Build JSON manually to avoid needing jq
  local json="{\"ts\":\"${ts}\",\"iteration\":${iteration}"
  [[ -n "$input_tokens" ]] && json="${json},\"input_tokens\":${input_tokens}"
  [[ -n "$output_tokens" ]] && json="${json},\"output_tokens\":${output_tokens}"
  [[ -n "$session_pct" ]] && json="${json},\"session_pct\":${session_pct}"
  [[ -n "$weekly_pct" ]] && json="${json},\"weekly_pct\":${weekly_pct}"
  json="${json},\"outcome\":\"${outcome}\"}"

  echo "$json" >> "${LOG_DIR}/usage.jsonl"
}

# --- Runtime formatter -------------------------------------------------------

# Convert a duration in seconds to "HhMm" format, e.g. 7340 -> "2h 2m"
format_runtime() {
  local seconds="$1"
  local h=$((seconds / 3600))
  local m=$(((seconds % 3600) / 60))
  if [[ "$h" -gt 0 ]]; then
    echo "${h}h ${m}m"
  else
    echo "${m}m"
  fi
}
