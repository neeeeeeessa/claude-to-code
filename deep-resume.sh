#!/usr/bin/env bash
# deep-resume.sh — Claude-analyzed project status and suggested next actions
#
# Reads the same state as resume.sh but feeds it to Claude for a richer,
# judgment-based briefing. Uses API calls.
#
# Run this when the fast resume.sh report doesn't give you enough signal.

set -uo pipefail

# --- Preflight ---------------------------------------------------------------

if [[ ! -f "specs/tasks.md" ]]; then
  echo "error: not inside a claude-to-code project." >&2
  exit 3
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "error: claude CLI required for deep-resume." >&2
  exit 3
fi

# --- Gather state ------------------------------------------------------------

PROJECT=$(basename -s .git "$(git remote get-url origin 2>/dev/null || echo "$PWD")" 2>/dev/null || basename "$PWD")

LEARNINGS=""
if [[ -f "LEARNINGS.md" ]]; then
  LEARNINGS=$(cat LEARNINGS.md)
fi

PROGRESS=""
if [[ -f "progress.txt" ]]; then
  # Last 30 lines is enough for recency without bloat
  PROGRESS=$(tail -30 progress.txt)
fi

TASKS=""
if [[ -f "specs/tasks.md" ]]; then
  TASKS=$(cat specs/tasks.md)
fi

SPEC_SUMMARY=""
if [[ -f "specs/spec.md" ]]; then
  # Just the first 80 lines — we want gist, not everything
  SPEC_SUMMARY=$(head -80 specs/spec.md)
fi

GIT_LOG=$(git log --format="%h %ci %s" -20 2>/dev/null || echo "")

OPEN_PRS=""
if command -v gh >/dev/null 2>&1; then
  OPEN_PRS=$(gh pr list --state open --limit 10 2>/dev/null || echo "")
fi

LAST_ITER_LOG_SNIPPET=""
if [[ -d ".ralph-logs" ]]; then
  LAST_LOG=$(ls -t .ralph-logs/iter-*.log 2>/dev/null | head -1 || true)
  if [[ -n "$LAST_LOG" ]]; then
    # Last 60 lines of the most recent iteration log
    LAST_ITER_LOG_SNIPPET=$(tail -60 "$LAST_LOG")
  fi
fi

# --- Build the prompt --------------------------------------------------------

PROMPT=$(cat <<EOF
You are helping the operator resume work on a claude-to-code project after
time away. Produce a structured briefing:

1. What state the project is in (one paragraph)
2. What's blocking or at risk (bullet list, or "nothing flagged")
3. 2-3 specific next actions, ranked by what makes most sense first

Be direct and concise. No preamble, no ceremony. Don't repeat what's
obvious from the data — surface what takes judgment to see.

If nothing interesting stands out, say so. Don't invent problems.

PROJECT: $PROJECT

=== specs/tasks.md (current state) ===
$TASKS

=== specs/spec.md (first 80 lines) ===
$SPEC_SUMMARY

=== LEARNINGS.md (what iterations have discovered) ===
$LEARNINGS

=== progress.txt (last 30 lines) ===
$PROGRESS

=== git log (last 20 commits) ===
$GIT_LOG

=== open PRs ===
$OPEN_PRS

=== last iteration log (tail) ===
$LAST_ITER_LOG_SNIPPET
EOF
)

# --- Run -----------------------------------------------------------------------

echo "Running deep analysis — this may take 30-60 seconds..."
echo ""

if command -v timeout >/dev/null 2>&1; then
  RESULT=$(echo "$PROMPT" | timeout 90 claude -p 2>/dev/null || true)
elif command -v gtimeout >/dev/null 2>&1; then
  RESULT=$(echo "$PROMPT" | gtimeout 90 claude -p 2>/dev/null || true)
else
  RESULT=$(echo "$PROMPT" | claude -p 2>/dev/null || true)
fi

if [[ -z "$RESULT" ]]; then
  echo "error: empty response from claude." >&2
  echo "       check your claude CLI auth with: claude /status" >&2
  exit 3
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Deep Resume Briefing"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "$RESULT"
echo ""
exit 0
