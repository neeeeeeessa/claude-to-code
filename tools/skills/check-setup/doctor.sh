#!/usr/bin/env bash
# doctor.sh — verify the claude-to-code pipeline environment is ready
#
# Checks:
#   - Core required tools (bash, git, gh, claude, curl, python3)
#   - Optional/recommended tools (timeout, jq, pnpm)
#   - Authentication (gh, claude)
#   - Installed skills (bootstrap-project, validate-specs, check-setup, ...)
#   - Shell compatibility
#
# Exit codes:
#   0 = all required tools present
#   1 = something required is missing
#   2 = warnings only (recommended tools missing but pipeline works)

set -uo pipefail

# --- Tracking -----------------------------------------------------------------

MISSING_REQUIRED=()
MISSING_RECOMMENDED=()
WARNINGS=()

# --- ANSI colors (graceful fallback to plain) ---------------------------------

if [[ -t 1 ]]; then
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  RED=$'\033[0;31m'
  DIM=$'\033[2m'
  BOLD=$'\033[1m'
  RESET=$'\033[0m'
else
  GREEN="" ; YELLOW="" ; RED="" ; DIM="" ; BOLD="" ; RESET=""
fi

check_mark()  { printf "  ${GREEN}✓${RESET} %s\n" "$1"; }
cross_mark()  { printf "  ${RED}✗${RESET} %s\n" "$1"; }
warn_mark()   { printf "  ${YELLOW}!${RESET} %s\n" "$1"; }
hint()        { printf "    ${DIM}%s${RESET}\n" "$1"; }
section()     { printf "\n${BOLD}%s${RESET}\n" "$1"; }

# --- Tool check helpers -------------------------------------------------------

# check_tool <binary> <label> <install_hint>
check_required() {
  local bin="$1" label="$2" install="$3"
  if command -v "$bin" >/dev/null 2>&1; then
    local version
    version=$("$bin" --version 2>&1 | head -1 | tr -d '\r' || true)
    check_mark "$label ${DIM}${version}${RESET}"
  else
    cross_mark "$label — NOT installed"
    hint "install: $install"
    MISSING_REQUIRED+=("$label")
  fi
}

check_recommended() {
  local bin="$1" label="$2" install="$3"
  if command -v "$bin" >/dev/null 2>&1; then
    local version
    version=$("$bin" --version 2>&1 | head -1 | tr -d '\r' || true)
    check_mark "$label ${DIM}${version}${RESET}"
  else
    warn_mark "$label — not installed (recommended)"
    hint "install: $install"
    MISSING_RECOMMENDED+=("$label")
  fi
}

# --- Start --------------------------------------------------------------------

printf "${BOLD}Claude-to-Code Setup Check${RESET}\n"
printf "${DIM}$(date)${RESET}\n"

# --- Core required tools ------------------------------------------------------

section "Core tools (required)"

check_required "bash"    "bash"    "preinstalled on Mac/Linux; Git Bash on Windows"
check_required "git"     "git"     "https://git-scm.com/downloads"
check_required "gh"      "gh (GitHub CLI)" "https://cli.github.com/ (then: gh auth login)"
check_required "claude"  "claude (Claude Code CLI)" "https://docs.claude.com/claude-code"
check_required "curl"    "curl"    "preinstalled almost everywhere; if missing, install via your package manager"
check_required "python3" "python3" "https://www.python.org/downloads/ or winget install Python.Python.3.12"

# --- Recommended tools --------------------------------------------------------

section "Recommended tools (nice to have)"

# 'timeout' or 'gtimeout' — for bounding /status calls
if command -v timeout >/dev/null 2>&1; then
  check_mark "timeout (GNU coreutils)"
elif command -v gtimeout >/dev/null 2>&1; then
  check_mark "gtimeout (coreutils on macOS)"
else
  warn_mark "timeout — not installed (recommended)"
  hint "macOS: brew install coreutils"
  hint "Linux: apt install coreutils"
  hint "Windows Git Bash: should be bundled; reinstall Git if missing"
  MISSING_RECOMMENDED+=("timeout")
fi

check_recommended "jq"    "jq"    "https://jqlang.github.io/jq/download/ (winget install jqlang.jq / brew install jq)"
check_recommended "pnpm"  "pnpm"  "npm install -g pnpm  (or: corepack enable)"

# --- Authentication -----------------------------------------------------------

section "Authentication"

if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    local_user=$(gh api user --jq .login 2>/dev/null || echo "unknown")
    check_mark "gh authenticated as $local_user"
  else
    cross_mark "gh NOT authenticated"
    hint "run: gh auth login"
    MISSING_REQUIRED+=("gh authentication")
  fi
else
  warn_mark "gh not installed — skipping auth check"
fi

if command -v claude >/dev/null 2>&1; then
  # There's no universal "am I logged in?" flag, but /status output contains
  # subscription or auth hints. Run it briefly and see if it returns something.
  if command -v timeout >/dev/null 2>&1; then
    status_probe=$(timeout 10 claude -p "/status" 2>/dev/null || true)
  else
    status_probe=$(claude -p "/status" 2>/dev/null || true)
  fi
  if [[ -n "$status_probe" ]]; then
    check_mark "claude responds (auth appears OK)"
  else
    warn_mark "claude installed but /status returned nothing"
    hint "try: claude /login (or run 'claude' interactively once)"
    WARNINGS+=("claude authentication status unclear")
  fi
else
  warn_mark "claude not installed — skipping auth check"
fi

# --- Operator config ---------------------------------------------------------

section "Operator configuration"

OPERATOR_ENV="$HOME/.claude/operator.env"
if [[ -f "$OPERATOR_ENV" ]]; then
  check_mark "operator.env found at $OPERATOR_ENV"

  # Source it into a subshell to check for required fields without polluting
  # the current env.
  (
    set -a
    # shellcheck disable=SC1090
    . "$OPERATOR_ENV" 2>/dev/null || true
    set +a

    for field in OPERATOR_NAME GITHUB_USERNAME; do
      if [[ -z "${!field:-}" ]]; then
        echo "  ! ${field} is empty in operator.env"
      fi
    done

    if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
      echo "  ✓ telegram credentials set"
    else
      echo "  (i) telegram not set — notifications disabled (that's fine)"
    fi
  )
else
  warn_mark "operator.env not found at $OPERATOR_ENV"
  hint "bootstrap-project skill offers to create it on first use"
  hint "or copy from <your-clone>/tools/operator.env.example"
  WARNINGS+=("operator.env not configured — new projects won't have operator-context.md")
fi

# --- Installed skills ---------------------------------------------------------

section "Skills installed in ~/.claude/skills/"

SKILLS_DIR="$HOME/.claude/skills"
EXPECTED_SKILLS=("bootstrap-project" "validate-specs" "check-setup" "resume-project")

for skill in "${EXPECTED_SKILLS[@]}"; do
  skill_path="$SKILLS_DIR/$skill"
  if [[ -d "$skill_path" ]] && [[ -f "$skill_path/SKILL.md" ]]; then
    check_mark "$skill"
  else
    # Not all skills are required — only flag as warning
    warn_mark "$skill — not installed"
    case "$skill" in
      bootstrap-project) hint "install: copy files from a2-bootstrap-skill/" ;;
      validate-specs)    hint "install: copy files from a3-validate-skill/" ;;
      check-setup)       hint "install: copy files from the doctor skill" ;;
      resume-project)    hint "install: copy files from the a5 skill when built" ;;
    esac
    WARNINGS+=("$skill skill not installed")
  fi
done

# --- Shell / OS ---------------------------------------------------------------

section "Shell and OS"

uname_out=$(uname -s 2>/dev/null || echo "unknown")
case "$uname_out" in
  MINGW*|MSYS*|CYGWIN*)
    check_mark "Git Bash on Windows detected"
    warn_mark "running on native Windows without WSL"
    hint "some operations may be slower than on WSL or Mac"
    hint "if you hit bash-related issues, consider: wsl --install"
    ;;
  Darwin*)
    check_mark "macOS detected"
    if ! command -v timeout >/dev/null 2>&1 && ! command -v gtimeout >/dev/null 2>&1; then
      hint "tip: brew install coreutils  — gives you gtimeout/gdate/etc"
    fi
    ;;
  Linux*)
    check_mark "Linux detected"
    # WSL detection
    if grep -qEi "microsoft|wsl" /proc/version 2>/dev/null; then
      hint "(WSL detected — good choice for this pipeline)"
    fi
    ;;
  *)
    warn_mark "unknown OS: $uname_out"
    ;;
esac

# --- Summary ------------------------------------------------------------------

section "Summary"

if [[ ${#MISSING_REQUIRED[@]} -eq 0 && ${#MISSING_RECOMMENDED[@]} -eq 0 && ${#WARNINGS[@]} -eq 0 ]]; then
  printf "${GREEN}✓ All checks passed.${RESET} Ready to bootstrap projects and run Ralph loops.\n\n"
  exit 0
fi

if [[ ${#MISSING_REQUIRED[@]} -gt 0 ]]; then
  printf "${RED}✗ Required items missing (${#MISSING_REQUIRED[@]}):${RESET}\n"
  for item in "${MISSING_REQUIRED[@]}"; do
    printf "    - %s\n" "$item"
  done
  echo ""
fi

if [[ ${#MISSING_RECOMMENDED[@]} -gt 0 ]]; then
  printf "${YELLOW}! Recommended items missing (${#MISSING_RECOMMENDED[@]}):${RESET}\n"
  for item in "${MISSING_RECOMMENDED[@]}"; do
    printf "    - %s\n" "$item"
  done
  echo ""
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  printf "${YELLOW}! Warnings (${#WARNINGS[@]}):${RESET}\n"
  for item in "${WARNINGS[@]}"; do
    printf "    - %s\n" "$item"
  done
  echo ""
fi

if [[ ${#MISSING_REQUIRED[@]} -gt 0 ]]; then
  printf "${RED}Verdict: install the required items above before using the pipeline.${RESET}\n\n"
  exit 1
else
  printf "${YELLOW}Verdict: pipeline will work, but installing the recommended items above is suggested.${RESET}\n\n"
  exit 2
fi
