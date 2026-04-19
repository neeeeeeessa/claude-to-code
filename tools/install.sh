#!/usr/bin/env bash
# tools/install.sh — install all claude-to-code skills to ~/.claude/skills/
#
# Usage:
#   bash install.sh                   # install everything
#   bash install.sh --dry-run         # show what would happen, don't do it
#   bash install.sh --skills-only     # skip the doctor run at the end
#
# Works on: Git Bash (Windows), WSL, macOS, Linux.

set -euo pipefail

# --- Parse args --------------------------------------------------------------

DRY_RUN=0
SKILLS_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --skills-only) SKILLS_ONLY=1 ;;
    -h|--help)
      grep '^# ' "$0" | sed 's/^# //'
      exit 0
      ;;
    *)
      echo "error: unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

# --- ANSI colors -------------------------------------------------------------

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

# --- Locate skills directory (sibling of this script in tools/) --------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SOURCE="$SCRIPT_DIR/skills"

if [[ ! -d "$SKILLS_SOURCE" ]]; then
  echo "error: skills directory not found at $SKILLS_SOURCE" >&2
  echo "       this installer expects to live in tools/ alongside tools/skills/" >&2
  exit 1
fi

TARGET="$HOME/.claude/skills"

# --- Verify sources before doing anything ------------------------------------

EXPECTED_SKILLS=("bootstrap-project" "validate-specs" "resume-project" "check-setup")
MISSING=()

for skill in "${EXPECTED_SKILLS[@]}"; do
  if [[ ! -d "$SKILLS_SOURCE/$skill" ]]; then
    MISSING+=("$skill")
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "error: missing skill directories in $SKILLS_SOURCE:" >&2
  for s in "${MISSING[@]}"; do
    echo "  - $s" >&2
  done
  exit 1
fi

# --- Report what we're about to do -------------------------------------------

printf "${BOLD}Claude-to-Code skills installer${RESET}\n"
printf "${DIM}%s${RESET}\n\n" "$(date)"

if [[ "$DRY_RUN" == "1" ]]; then
  printf "${YELLOW}DRY RUN — nothing will actually be installed.${RESET}\n\n"
fi

printf "Source: %s\n" "$SKILLS_SOURCE"
printf "Target: %s\n\n" "$TARGET"

printf "Will install:\n"
for skill in "${EXPECTED_SKILLS[@]}"; do
  printf "  ${DIM}→${RESET} %s\n" "$skill"
done
echo ""

# --- Prompt for confirmation -------------------------------------------------

if [[ "$DRY_RUN" == "0" ]]; then
  read -rp "Proceed? [Y/n]: " confirm
  confirm="${confirm:-Y}"
  if [[ "$confirm" != "Y" && "$confirm" != "y" ]]; then
    echo "aborted."
    exit 1
  fi
  echo ""
fi

# --- Do the installs ---------------------------------------------------------

mkdir -p "$TARGET"

for skill in "${EXPECTED_SKILLS[@]}"; do
  src="$SKILLS_SOURCE/$skill"
  dst="$TARGET/$skill"

  if [[ -d "$dst" ]]; then
    # Existing install — preserve .config, replace the rest
    if [[ "$DRY_RUN" == "0" ]]; then
      config_backup=""
      if [[ -f "$dst/.config" ]]; then
        config_backup=$(mktemp)
        cp "$dst/.config" "$config_backup"
      fi

      rm -rf "$dst"
      cp -r "$src" "$dst"

      if [[ -n "$config_backup" && -f "$config_backup" ]]; then
        cp "$config_backup" "$dst/.config"
        rm -f "$config_backup"
        printf "  ${GREEN}✓${RESET} %s ${DIM}(updated, config preserved)${RESET}\n" "$skill"
      else
        printf "  ${GREEN}✓${RESET} %s ${DIM}(updated)${RESET}\n" "$skill"
      fi
    else
      printf "  ${DIM}would update${RESET} %s\n" "$skill"
    fi
  else
    if [[ "$DRY_RUN" == "0" ]]; then
      cp -r "$src" "$dst"
      printf "  ${GREEN}✓${RESET} %s ${DIM}(new)${RESET}\n" "$skill"
    else
      printf "  ${DIM}would install${RESET} %s\n" "$skill"
    fi
  fi

  if [[ "$DRY_RUN" == "0" ]]; then
    find "$dst" -name "*.sh" -exec chmod +x {} + 2>/dev/null || true
  fi
done

echo ""

# --- Run the doctor to verify ------------------------------------------------

if [[ "$DRY_RUN" == "1" || "$SKILLS_ONLY" == "1" ]]; then
  if [[ "$DRY_RUN" == "1" ]]; then
    printf "${DIM}(would run doctor at end)${RESET}\n\n"
  fi
  printf "${BOLD}Done.${RESET}\n"
  exit 0
fi

printf "${BOLD}Running setup check...${RESET}\n"
printf "${DIM}(If required tools are missing, the doctor will list them with install commands.)${RESET}\n\n"

if [[ -x "$TARGET/check-setup/doctor.sh" ]]; then
  bash "$TARGET/check-setup/doctor.sh" || true
else
  echo "warn: check-setup skill installed but doctor.sh not executable" >&2
fi

echo ""
printf "${BOLD}Install complete.${RESET}\n"
printf "Open Claude Code and say ${BOLD}\"check setup\"${RESET} anytime to re-run this check.\n"
printf "See the ${BOLD}User Guide${RESET} section of the README for next steps.\n"
