#!/usr/bin/env bash
# llm-audit.sh — deeper spec audit using Claude Code for semantic checks
#
# Reads all four spec files and asks Claude to analyze consistency between
# them. Catches things regex can't: constitution violations in the plan,
# tasks that don't trace to user stories, stack contradictions, etc.
#
# This is slower (uses API calls) than validate.sh. Run it when the fast
# validator passes but you want an extra layer of confidence before Ralph.

set -uo pipefail

CONSTITUTION=".specify/memory/constitution.md"
SPEC="specs/spec.md"
PLAN="specs/plan.md"
TASKS="specs/tasks.md"

# --- Preflight ---------------------------------------------------------------

if ! command -v claude >/dev/null 2>&1; then
  echo "error: claude CLI required for llm-audit." >&2
  exit 3
fi

for f in "$CONSTITUTION" "$SPEC" "$PLAN" "$TASKS"; do
  if [[ ! -f "$f" ]]; then
    echo "error: $f not found." >&2
    exit 3
  fi
done

# --- Build the audit prompt --------------------------------------------------

PROMPT=$(cat <<EOF
You are auditing a claude-to-code project's specifications for semantic
consistency. The four files below will drive an autonomous Ralph loop, so
inconsistencies between them cause the loop to thrash.

Your job: find real semantic problems that regex and heuristics can't catch.

Check for:

1. Constitution violations in the plan
   (e.g., constitution says "no third-party analytics" but plan mentions
   Google Analytics)

2. User stories not traced to tasks
   (every US-NNN in spec.md should have at least one task addressing it)

3. Tasks not traced to user stories
   (every task should map to a user story, an explicit non-functional
   requirement, or project infrastructure setup)

4. Stack contradictions
   (e.g., plan says "offline-first" but chose a framework that needs a server,
   or stack choices that don't work together)

5. Verification commands that don't match the stack
   (e.g., \`pnpm test\` in a Python project)

6. Implausible or unverifiable acceptance criteria
   (vague phrasing that regex missed)

7. Missing or contradictory non-goals
   (spec says "login is out of scope" but plan describes auth, or similar)

Output format (strict):

For each real issue found, write one line:
  [SEVERITY] <file>: <one-line description>

Where SEVERITY is one of:
  CRITICAL — blocks the loop, must fix
  MAJOR    — will likely cause problems, should fix
  MINOR    — worth noting but not blocking

If there are NO issues worth flagging, write exactly:
  AUDIT_CLEAN

Do not write any preamble, summary, or closing text. One issue per line,
or the single word AUDIT_CLEAN.

=========================================================================
FILE: .specify/memory/constitution.md
=========================================================================
$(cat "$CONSTITUTION")

=========================================================================
FILE: specs/spec.md
=========================================================================
$(cat "$SPEC")

=========================================================================
FILE: specs/plan.md
=========================================================================
$(cat "$PLAN")

=========================================================================
FILE: specs/tasks.md
=========================================================================
$(cat "$TASKS")
EOF
)

# --- Run the audit -----------------------------------------------------------

echo "Running LLM audit — this may take 30-60 seconds..."
echo ""

RESULT=$(echo "$PROMPT" | claude -p 2>/dev/null || true)

if [[ -z "$RESULT" ]]; then
  echo "error: empty response from claude. skipping LLM audit." >&2
  exit 3
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  LLM Audit Report"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ "$RESULT" == *"AUDIT_CLEAN"* ]]; then
  echo "✓ LLM audit found no semantic issues."
  echo ""
  exit 0
fi

# Count severities
critical_count=$(echo "$RESULT" | grep -cE '^\[CRITICAL\]' || echo 0)
major_count=$(echo "$RESULT" | grep -cE '^\[MAJOR\]' || echo 0)
minor_count=$(echo "$RESULT" | grep -cE '^\[MINOR\]' || echo 0)

echo "Findings: $critical_count critical, $major_count major, $minor_count minor"
echo ""
echo "$RESULT" | grep -E '^\[(CRITICAL|MAJOR|MINOR)\]' || echo "$RESULT"
echo ""

if [[ "$critical_count" -gt 0 ]]; then
  echo "Verdict: CRITICAL issues — fix before running Ralph."
  exit 1
elif [[ "$major_count" -gt 0 ]]; then
  echo "Verdict: major issues — review before running Ralph."
  exit 2
else
  echo "Verdict: only minor findings — safe to proceed."
  exit 0
fi
