#!/usr/bin/env bash
# validate.sh — pre-flight validation for claude-to-code specs
#
# Runs structural and heuristic checks on specs. Fast, deterministic, no API.
#
# Exit codes:
#   0 = clean, ready for Ralph
#   1 = hard issues found, must fix before Ralph
#   2 = only soft warnings, safe to proceed
#   3 = validator itself couldn't run (missing files, not a project dir)

set -uo pipefail

# --- File locations ----------------------------------------------------------

CONSTITUTION=".specify/memory/constitution.md"
SPEC="specs/spec.md"
PLAN="specs/plan.md"
TASKS="specs/tasks.md"

# --- Tracking ---------------------------------------------------------------

ISSUES=()    # Hard issues — block the loop
WARNINGS=()  # Soft warnings — worth reviewing but not blocking

issue()    { ISSUES+=("$1"); }
warn()     { WARNINGS+=("$1"); }

# --- Preflight: are we in a project? ----------------------------------------

if [[ ! -f "$TASKS" ]]; then
  echo "error: $TASKS not found." >&2
  echo "       are you inside a claude-to-code project directory?" >&2
  exit 3
fi

# --- Structural checks: required files --------------------------------------

for f in "$CONSTITUTION" "$SPEC" "$PLAN" "$TASKS"; do
  if [[ ! -f "$f" ]]; then
    issue "required file missing: $f"
  elif [[ ! -s "$f" ]]; then
    issue "required file is empty: $f"
  fi
done

# If core files are missing, no point running further checks.
if [[ ${#ISSUES[@]} -gt 0 ]]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Spec Validation: aborted"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Hard issues preventing further checks:"
  for msg in "${ISSUES[@]}"; do
    echo "  ✗ $msg"
  done
  echo ""
  echo "Fix these, then re-run validation."
  exit 1
fi

# --- Structural checks: constitution sections --------------------------------

check_section() {
  local file="$1"
  local section="$2"
  local severity="${3:-issue}"  # issue | warn
  if ! grep -qE "^##[[:space:]]+${section}" "$file"; then
    if [[ "$severity" == "warn" ]]; then
      warn "$file missing recommended section: ## $section"
    else
      issue "$file missing required section: ## $section"
    fi
  fi
}

# Required constitution sections
check_section "$CONSTITUTION" "Purpose"
check_section "$CONSTITUTION" "Non-Negotiables"
check_section "$CONSTITUTION" "Testing Philosophy"
check_section "$CONSTITUTION" "Out of Scope"
check_section "$CONSTITUTION" "Success Criteria"
# Recommended
check_section "$CONSTITUTION" "Performance" warn
check_section "$CONSTITUTION" "Accessibility" warn

# Required spec sections
check_section "$SPEC" "Primary User"
check_section "$SPEC" "User Stories"
check_section "$SPEC" "Non-Goals"
# Recommended
check_section "$SPEC" "Edge Cases" warn
check_section "$SPEC" "Error States" warn

# Required plan sections
check_section "$PLAN" "Stack"
check_section "$PLAN" "High-Level Architecture"
check_section "$PLAN" "External Dependencies"
# Recommended
check_section "$PLAN" "Data Model" warn
check_section "$PLAN" "Auth" warn
check_section "$PLAN" "Deployment" warn
check_section "$PLAN" "Known Technical Risks" warn

# --- Structural checks: user story count -----------------------------------

# User stories in the template format are: "- **[US-001]** ..." inside a list.
# The leading "- " is part of the bullet, followed by optional bold markers.
user_story_count=$(grep -E '^\s*-?\s*\*\*?\[US-[0-9]+\]' "$SPEC" 2>/dev/null | wc -l | tr -d ' ')
user_story_count="${user_story_count:-0}"
if [[ "$user_story_count" -lt 3 ]]; then
  issue "spec.md has only $user_story_count user stories (minimum 3 required)"
fi

# --- Structural checks: task parsing --------------------------------------

# Parse tasks and verify each has Description, Acceptance, Verify.
# A task block starts with "- [ ]" or "- [x]" and continues until the next
# top-level task or heading.

python_check() {
  # Use python3 if available for reliable parsing; fall back to awk.
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$@" <<'PYEOF'
import sys, re, pathlib

tasks_file = pathlib.Path(sys.argv[1])
text = tasks_file.read_text()

# Split on task starts: lines like "- [ ] **T001: ...**" or "- [x] ..."
task_re = re.compile(r'^- \[([ x])\]\s+\*?\*?(T\d+)', re.MULTILINE)
matches = list(task_re.finditer(text))

if len(matches) == 0:
    print("PARSE_NO_TASKS")
    sys.exit(0)

total = len(matches)
done = sum(1 for m in matches if m.group(1) == 'x')
print(f"COUNT {total} {done}")

# Check each task block
for i, m in enumerate(matches):
    start = m.start()
    end = matches[i+1].start() if i+1 < len(matches) else len(text)
    block = text[start:end]
    task_id = m.group(2)

    # Required sub-elements
    has_desc = bool(re.search(r'^\s*-\s+Description:', block, re.MULTILINE | re.IGNORECASE))
    has_accept = bool(re.search(r'^\s*-\s+Acceptance:', block, re.MULTILINE | re.IGNORECASE))
    has_verify = bool(re.search(r'^\s*-\s+Verify:', block, re.MULTILINE | re.IGNORECASE))

    if not has_desc:
        print(f"MISSING_SUB {task_id} Description")
    if not has_accept:
        print(f"MISSING_SUB {task_id} Acceptance")
    if not has_verify:
        print(f"MISSING_SUB {task_id} Verify")

    # Extract the verify line
    vmatch = re.search(r'^\s*-\s+Verify:\s*`?([^`\n]*)`?', block, re.MULTILINE | re.IGNORECASE)
    if vmatch:
        verify_cmd = vmatch.group(1).strip()
        # Check for placeholders. Note: \b word boundaries don't work for <...>
        # because < is not a word character; use a separate alternation for it.
        if not verify_cmd or re.search(r'(\b(TODO|FIXME|XXX|placeholder)\b|<[^>]+>)', verify_cmd, re.IGNORECASE):
            print(f"BAD_VERIFY {task_id} placeholder: '{verify_cmd}'")
        elif verify_cmd.startswith('#') or len(verify_cmd) < 3:
            print(f"BAD_VERIFY {task_id} too short or commented: '{verify_cmd}'")

    # Extract acceptance line and check for subjective words
    amatch = re.search(r'^\s*-\s+Acceptance:\s*(.+)$', block, re.MULTILINE | re.IGNORECASE)
    if amatch:
        accept_text = amatch.group(1).strip()
        subjective = []
        for word in ['nice', 'clean', 'good', 'simple', 'intuitive', 'elegant',
                     'beautiful', 'feels right', 'user-friendly', 'robust',
                     'efficient', 'optimized', 'professional']:
            if re.search(r'\b' + re.escape(word) + r'\b', accept_text, re.IGNORECASE):
                subjective.append(word)
        if subjective:
            print(f"SUBJECTIVE_ACCEPT {task_id} {','.join(subjective)}")

    # Size check: word count of the whole task block
    words = len(block.split())
    if words > 100:
        print(f"OVERSIZE_TASK {task_id} {words}")
PYEOF
  else
    echo "error: python3 required for task parsing" >&2
    return 1
  fi
}

task_output=$(python_check "$TASKS" 2>&1 || echo "PARSE_FAIL")

if [[ "$task_output" == *"PARSE_NO_TASKS"* ]]; then
  issue "tasks.md contains no parseable tasks (expected format: '- [ ] **TNNN: ...**')"
elif [[ "$task_output" == *"PARSE_FAIL"* ]]; then
  issue "could not parse tasks.md (python3 required, or file malformed)"
else
  # Parse the python output
  total_tasks=0
  done_tasks=0
  while IFS= read -r line; do
    case "$line" in
      COUNT*)
        total_tasks=$(echo "$line" | awk '{print $2}')
        done_tasks=$(echo "$line" | awk '{print $3}')
        ;;
      MISSING_SUB*)
        task_id=$(echo "$line" | awk '{print $2}')
        sub=$(echo "$line" | awk '{print $3}')
        issue "task $task_id missing required sub-element: $sub"
        ;;
      BAD_VERIFY*)
        task_id=$(echo "$line" | awk '{print $2}')
        rest=$(echo "$line" | cut -d' ' -f3-)
        issue "task $task_id has a bad verification command — $rest"
        ;;
      SUBJECTIVE_ACCEPT*)
        task_id=$(echo "$line" | awk '{print $2}')
        words=$(echo "$line" | awk '{print $3}')
        warn "task $task_id uses subjective language in Acceptance: $words"
        ;;
      OVERSIZE_TASK*)
        task_id=$(echo "$line" | awk '{print $2}')
        wc=$(echo "$line" | awk '{print $3}')
        warn "task $task_id is $wc words long — probably too big, consider splitting"
        ;;
    esac
  done <<< "$task_output"

  if [[ "$total_tasks" -lt 5 ]]; then
    issue "tasks.md has only $total_tasks tasks (minimum 5 required)"
  fi
fi

# --- Report ------------------------------------------------------------------

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Spec Validation Report"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Quick stats
if [[ "${total_tasks:-0}" -gt 0 ]]; then
  echo "Tasks: ${done_tasks:-0} done / $total_tasks total"
  echo "User stories: $user_story_count"
  echo ""
fi

if [[ ${#ISSUES[@]} -eq 0 && ${#WARNINGS[@]} -eq 0 ]]; then
  echo "✓ All checks passed. Specs are ready for Ralph."
  echo ""
  exit 0
fi

if [[ ${#ISSUES[@]} -gt 0 ]]; then
  echo "Hard issues (must fix): ${#ISSUES[@]}"
  for msg in "${ISSUES[@]}"; do
    echo "  ✗ $msg"
  done
  echo ""
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  echo "Soft warnings (review recommended): ${#WARNINGS[@]}"
  for msg in "${WARNINGS[@]}"; do
    echo "  ! $msg"
  done
  echo ""
fi

if [[ ${#ISSUES[@]} -gt 0 ]]; then
  echo "Verdict: FIX ISSUES before running Ralph."
  echo ""
  exit 1
else
  echo "Verdict: warnings only — safe to proceed, but worth reviewing."
  echo ""
  exit 2
fi
